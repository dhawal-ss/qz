.pragma library
.import "../Format.js" as Format

// The weekly goal and its streak, as pure functions of library.days() so they can be tested
// without the library. The rules, which Moments.js should follow by importing this file:
//   - A week runs from the first day the rider picked (ui2/weekStart, Format.firstDay: Monday
//     by default, or Sunday) for 7 days in local time. Its key is the date of the Monday inside
//     it as the number yyyymmdd (20261102), taken at noon so a DST change cannot move it to
//     another day. A Monday week starts on its Monday, a Sunday week the day before its Monday,
//     so the keys stored before weeks could start on Sunday (restWeeks, restReasons, goalsPause)
//     stay valid with either setting, and a week marked rest keeps 6 of its 7 days when the
//     setting changes. Keys are only made by weekKey(); never store the key of a Sunday.
//   - The goal is minutes, kJ, km or rides in a week. The goal of today applies to every past
//     week too, so changing it can make the streak longer or shorter.
//   - A week that meets the goal adds one to the streak. Every 4th goal week earns a freeze, and
//     up to 2 stay banked; a 4th goal week while 2 are banked earns nothing more.
//   - A missed week spends a banked freeze when there is a streak to save: the streak goes on
//     without the week adding to it. With no freeze the streak ends and the count to the next
//     freeze starts again; freezes already earned stay banked.
//   - A week the rider marked as rest, sick, injured, travel or other (the Pause goals sheet)
//     pauses everything: no freeze is spent, the streak neither grows nor ends. A marked week
//     that still meets the goal counts as met.
//   - The week in progress never spends a freeze or ends the streak; it counts once it is met.
//   - Weeks before the first ride are not missed, they had not started yet.

var dayMs = 86400000
var freezeEvery = 4
var freezeMax = 2
var kinds = ["minutes", "kj", "km", "rides"]
// the ui2 setting holding the goal of each kind; weeklyGoalMinutes is the old minutes goal
var settingKeys = { minutes: "weeklyGoalMinutes", kj: "weeklyGoalKj", km: "weeklyGoalKm", rides: "weeklyGoalRides" }
var defaults = { minutes: 120, kj: 1500, km: 60, rides: 3 }
var choices = {
    minutes: [60, 90, 120, 180, 240, 300],
    kj: [500, 1000, 1500, 2000, 3000, 4000],
    km: [25, 50, 75, 100, 150, 200],
    rides: [1, 2, 3, 4, 5, 6]
}
// distance goals for riders who see miles, stored in km
var mileChoices = [15, 30, 50, 75, 100, 125]
var reasons = ["rest", "sick", "injured", "travel", "other"]

function noon(ms) {
    var d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12).getTime()
}

// 20261102 for 2 Nov 2026, from the local date of ms
function dayKey(ms) {
    var d = new Date(ms)
    return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()
}

// noon of the day of a key (for a week key, its Monday; weekStartOf() of it is the week's first day)
function keyDay(key) {
    var k = Number(key)
    return new Date(Math.floor(k / 10000), Math.floor(k / 100) % 100 - 1, k % 100, 12).getTime()
}

// noon of the first day of the week holding ms (a Monday, or a Sunday when weeks start on Sunday)
function weekStartOf(ms) {
    var d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() - Format.weekday(ms), 12).getTime()
}

// noon of the first day of the week n weeks after the week of ms (n can be negative)
function addWeeks(ms, n) {
    var d = new Date(weekStartOf(ms))
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 7 * n, 12).getTime()
}

// the key of the week holding ms: the date of the Monday inside it
function weekKey(ms) {
    var d = new Date(weekStartOf(ms))
    return dayKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() + (d.getDay() === 0 ? 1 : 0), 12).getTime())
}

// the first day of the week of a key, as words: "Monday 9 November", or "Sunday 8 November"
function weekWords(key) {
    var d = new Date(weekStartOf(keyDay(key)))
    return qsTr("%1 %2 %3").arg(Format.dayNames[d.getDay()]).arg(d.getDate()).arg(Format.monthNames[d.getMonth()])
}

// totals per week from library.days(), by week key: { key: { seconds, kj, km, rides, tss, lastDay } }
function perWeek(days) {
    var weeks = {}
    for (var i = 0; i < days.length; i++) {
        // a day is its local midnight: read 6 h in, as the JavaScript engine of Qt 5 can read a
        // midnight of the other half of the DST year as 23:00 of the day before
        var key = weekKey(days[i].day + 6 * 3600000)
        var w = weeks[key]
        if (!w) {
            w = { seconds: 0, kj: 0, km: 0, rides: 0, tss: 0, lastDay: 0 }
            weeks[key] = w
        }
        w.seconds += days[i].seconds || 0
        w.kj += days[i].kj || 0
        w.km += days[i].distance || 0
        w.rides += days[i].rides || 0
        w.tss += days[i].tss || 0
        w.lastDay = Math.max(w.lastDay, days[i].day)
    }
    return weeks
}

// how much of a goal of this kind a week holds, in the goal's own unit
function measure(week, kind) {
    if (!week)
        return 0
    if (kind === "kj")
        return week.kj
    if (kind === "km")
        return week.km
    if (kind === "rides")
        return week.rides
    return week.seconds / 60
}

function met(week, kind, goal) {
    return goal > 0 && measure(week, kind) >= goal - 1e-9
}

// JSON helpers for the stored lists, forgiving of empty or broken text
function parseList(text) {
    try {
        var v = JSON.parse(text || "[]")
        return Array.isArray(v) ? v : []
    } catch (e) {
        return []
    }
}

function parseMap(text) {
    try {
        var v = JSON.parse(text || "{}")
        return v && typeof v === "object" && !Array.isArray(v) ? v : {}
    } catch (e) {
        return {}
    }
}

// Replays every week from the first ride to now. input:
//   weeks   perWeek(days)
//   kind    "minutes", "kj", "km" or "rides"
//   goal    the weekly goal in that unit
//   rest    keys of the weeks marked rest, sick or injured
//   now     ms, the week holding it is the week in progress
// Returns { streak, best, freezes, toNextFreeze, frozenUsed, welcomeBack, current, timeline,
// reached }: timeline is one entry per week, oldest first, { key, monday, value, status,
// streak } with monday the noon of the week's first day (a Sunday when weeks start on Sunday;
// the name is from before) and status met, frozen, rest, missed or current; reached maps 4, 12, 26 and 52 to the
// day the streak first got there.
function run(weeks, input) {
    var rest = {}
    for (var r = 0; r < (input.rest || []).length; r++)
        rest[Number(input.rest[r])] = true
    var thisMonday = weekStartOf(input.now)
    var first = 0
    for (var k in weeks) {
        var m = weekStartOf(keyDay(k))
        if (first === 0 || m < first)
            first = m
    }
    if (first === 0 || first > thisMonday)
        first = thisMonday

    var out = { streak: 0, best: 0, freezes: 0, toNextFreeze: freezeEvery, frozenUsed: 0, welcomeBack: false,
                current: null, timeline: [], reached: {} }
    var counted = 0          // goal weeks toward the next freeze
    var lastStatus = ""
    var marks = [4, 12, 26, 52]
    for (var monday = first; monday <= thisMonday; monday = addWeeks(monday, 1)) {
        var key = weekKey(monday)
        var week = weeks[key]
        var isCurrent = monday === thisMonday
        var status
        if (met(week, input.kind, input.goal)) {
            status = "met"
            out.streak++
            counted++
            if (counted >= freezeEvery) {
                counted = 0
                if (out.freezes < freezeMax)
                    out.freezes++
            }
            for (var i = 0; i < marks.length; i++)
                if (out.streak === marks[i] && !out.reached[marks[i]])
                    out.reached[marks[i]] = week.lastDay
        } else if (rest[key]) {
            status = "rest"
        } else if (isCurrent) {
            status = "current"
        } else if (out.streak > 0 && out.freezes > 0) {
            status = "frozen"
            out.freezes--
            out.frozenUsed++
        } else {
            status = "missed"
            out.streak = 0
            counted = 0
        }
        out.best = Math.max(out.best, out.streak)
        var entry = { key: key, monday: monday, value: measure(week, input.kind), status: status, streak: out.streak }
        if (isCurrent) {
            // back after a streak ended: the last finished week ended it and there was one before
            out.welcomeBack = status !== "met" && lastStatus === "missed" && out.best > 0
            out.current = entry
        }
        out.timeline.push(entry)
        lastStatus = status
    }
    out.toNextFreeze = out.freezes >= freezeMax ? 0 : freezeEvery - counted
    return out
}

// the last n weeks of a timeline, oldest first, padded in front with weeks before the first ride
function lastWeeks(timeline, n, now) {
    var out = timeline.slice(Math.max(0, timeline.length - n))
    while (out.length < n) {
        var monday = addWeeks(out.length > 0 ? out[0].monday : now, out.length > 0 ? -1 : 0)
        out.unshift({ key: weekKey(monday), monday: monday, value: 0, status: "none", streak: 0 })
    }
    return out
}

// marks or clears a week: rest is the stored list of keys, reasonsMap key -> reason
function mark(rest, reasonsMap, key, reason) {
    var list = []
    for (var i = 0; i < rest.length; i++)
        if (Number(rest[i]) !== Number(key))
            list.push(Number(rest[i]))
    var map = {}
    for (var k in reasonsMap)
        if (Number(k) !== Number(key))
            map[k] = reasonsMap[k]
    if (reasons.indexOf(reason) >= 0) {
        list.push(Number(key))
        map[String(key)] = reason
    }
    list.sort(function (a, b) { return a - b })
    return { rest: list, reasons: map }
}

// ---- the pause of the Pause goals sheet, stored as the ui2 setting goalsPause:
// { from: week key it started, until: week key of the week the rider expects to be back, or 0
// while open, reason }. Every week from `from` up to the week before `until` (while open: up to
// the week holding now) is a rest week, written into restWeeks so every screen sees it.

function parsePause(text) {
    var v = parseMap(text)
    return v.from ? v : null
}

// paused right now: started, and the week of return not reached yet
function pausedNow(pause, now) {
    return pause !== null && pause !== undefined && Number(pause.from) > 0
           && (!(Number(pause.until) > 0) || weekKey(now) < Number(pause.until))
}

// the week keys a pause covers so far, oldest first (at most a year)
function pauseKeys(pause, now) {
    var out = []
    if (!pause || !(Number(pause.from) > 0))
        return out
    var last = Number(pause.until) > 0 ? addWeeks(keyDay(pause.until), -1) : weekStartOf(now)
    var monday = weekStartOf(keyDay(pause.from))
    for (var n = 0; n < 53 && monday <= last; n++) {
        out.push(weekKey(monday))
        monday = addWeeks(monday, 1)
    }
    return out
}

// the stored rest weeks with every week of the pause marked; a week already marked keeps its reason
function withPause(rest, reasonsMap, pause, now) {
    var out = { rest: rest.slice(), reasons: {} }
    for (var k in reasonsMap)
        out.reasons[k] = reasonsMap[k]
    var keys = pauseKeys(pause, now)
    for (var i = 0; i < keys.length; i++) {
        var have = false
        for (var j = 0; j < out.rest.length; j++)
            if (Number(out.rest[j]) === keys[i])
                have = true
        if (have)
            continue
        out.rest.push(keys[i])
        out.reasons[String(keys[i])] = reasons.indexOf(pause.reason) >= 0 ? pause.reason : "rest"
    }
    out.rest.sort(function (a, b) { return a - b })
    return out
}

// back early: the weeks after this one that the pause marked ahead are free again; this week
// stays a rest week (it still counts as met if the goal is met)
function endPause(rest, reasonsMap, pause, now) {
    var thisWeek = weekKey(now)
    var ahead = {}
    var marked = pauseKeys(pause, addWeeks(now, 60))
    for (var i = 0; i < marked.length; i++)
        if (marked[i] > thisWeek)
            ahead[marked[i]] = true
    var out = { rest: [], reasons: {} }
    for (var j = 0; j < rest.length; j++)
        if (!ahead[Number(rest[j])])
            out.rest.push(Number(rest[j]))
    for (var k in reasonsMap)
        if (!ahead[Number(k)])
            out.reasons[k] = reasonsMap[k]
    return out
}
