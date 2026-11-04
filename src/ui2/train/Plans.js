.pragma library
.import "../Format.js" as Format
.import "../today/Coach.js" as Coach

// Training plans: a number of weeks with three rides each, made of the coach's workouts at the
// rider's training levels (train/Levels.js). A plan counts the rides of the week, not set days:
// the next ride is the first one the week has not had yet (every ride of 20 minutes or more
// counts), and a week that ends short simply ends, the plan goes on with the next one. Every
// fourth week is easier, and an event plan rests in its last week. Stored as ui2/trainingPlan:
// { id, startMs, weeks }.

var dayMs = 86400000

function list() {
    return [
        { id: "habit", name: qsTr("3 rides a week, 8 weeks"), weeks: 8,
          detail: qsTr("A habit first: easy rides that grow a little, and one with some effort each week.") },
        { id: "first40", name: qsTr("First 40 km"), weeks: 6,
          detail: qsTr("One longer ride a week, up to 40 km in the last week.") },
        { id: "event", name: qsTr("Event in a few weeks"), weeks: 8,
          detail: qsTr("Build, sharpen, then rest the week before the day.") }
    ]
}

function info(id) {
    var all = list()
    for (var i = 0; i < all.length; i++)
        if (all[i].id === id)
            return all[i]
    return null
}

function parse(text) {
    try {
        var p = JSON.parse(text || "")
        return p && p.id && info(p.id) !== null && p.startMs > 0 ? p : null
    } catch (e) {
        return null
    }
}

// the week of the plan now is in, from 0 (weeks start on the rider's first day, Format.weekStart)
function weekIndex(p, now) {
    return Math.floor((Format.weekStart(now) - Format.weekStart(p.startMs) + dayMs / 2) / (7 * dayMs))
}

function easierWeek(p, w) {
    return p.weeks >= 5 && (w + 1) % 4 === 0 && w < p.weeks - 1
}

function named(workout, name, detail) {
    workout.name = name
    if (detail)
        workout.detail = detail
    return workout
}

// the three rides of week w (Coach.plan objects), at the levels
function week(p, w, lv) {
    var levels = lv || {}
    var easy = easierWeek(p, w)
    var last = w === p.weeks - 1
    if (p.id === "habit") {
        var base = 25 + 5 * Math.floor(w / 2)
        if (easy)
            return [Coach.endurance(1, 25), Coach.endurance(1, 30), Coach.endurance(1, 25)]
        return [Coach.endurance(1, base), w < 2 ? Coach.endurance(1, base + 5) : Coach.tempo(levels.tempo), Coach.endurance(1, base + 10)]
    }
    if (p.id === "first40") {
        // the long ride grows to about 100 minutes, the time 40 km takes at an easy 24 km/h
        var long = Math.round((45 + (100 - 45) * w / Math.max(1, p.weeks - 1)) / 5) * 5
        if (easy)
            long = Math.max(45, long - 20)
        var longRide = last ? named(Coach.endurance(1, 100), qsTr("Your 40 km"), qsTr("Ride 40 km, steady and easy"))
                            : named(Coach.endurance(1, long), qsTr("Long ride %1").arg(long), qsTr("Steady, the longest of the week"))
        return [Coach.endurance(1, easy ? 30 : 35), easy ? Coach.endurance(1, 30) : Coach.tempo(levels.tempo), longRide]
    }
    // event: build, then the last week rests with short openers
    if (last)
        return [Coach.endurance(1, 30),
                Coach.plan("openers", qsTr("Openers"), qsTr("3 short efforts to feel sharp"), [[10, 2], [1, 5], [3, 1], [1, 5], [3, 1], [1, 5], [6, 1]]),
                named(Coach.endurance(1, 25), qsTr("Easy spin"), qsTr("Rest for the day"))]
    if (easy)
        return [Coach.endurance(1, 35), Coach.tempo(1), Coach.endurance(1, 40)]
    return [Coach.endurance(levels.endurance), Coach.threshold(levels.threshold), w % 2 === 0 ? Coach.vo2(levels.vo2) : Coach.endurance(levels.endurance, 75)]
}

// rides of the week now that count for the plan (rides: newest first, from the library), since
// the plan started: rides before it are not part of it
function ridesThisWeek(rides, now, since) {
    var from = Math.max(Format.weekStart(now), since || 0)
    var n = 0
    for (var i = 0; i < rides.length; i++) {
        if (rides[i].start < from)
            break
        if ((rides[i].duration || 0) >= 20 * 60)
            n++
    }
    return n
}

// where the plan stands now: { week, weeks, done, workout (the next ride or null), over, easy }
function now(p, rides, nowMs, lv) {
    var w = weekIndex(p, nowMs)
    if (w >= p.weeks)
        return { week: p.weeks - 1, weeks: p.weeks, done: 3, workout: null, over: true, easy: false }
    var rideList = week(p, Math.max(0, w), lv)
    var done = Math.min(rideList.length, ridesThisWeek(rides, nowMs, p.startMs))
    return { week: Math.max(0, w), weeks: p.weeks, done: done, workout: done < rideList.length ? rideList[done] : null,
             over: false, easy: easierWeek(p, Math.max(0, w)), rides: rideList }
}
