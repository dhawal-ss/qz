.pragma library
.import "../Format.js" as Format
.import "Insights.js" as Insights

// The patterns of the new Today visuals, pure functions of library.rides() (newest first: id,
// start, duration, avgPower, np, intensity, tss, avgHr and records; never best or ftp, those come
// from library.ride() only), so they can be tested without the library. Each has a sample() for
// a rider with no rides yet: a friendly picture of what it will show, drawn in graphite.

var dayMs = 86400000
// Monday first
var dayNames = [qsTr("Monday"), qsTr("Tuesday"), qsTr("Wednesday"), qsTr("Thursday"), qsTr("Friday"), qsTr("Saturday"), qsTr("Sunday")]
var slotNames = [qsTr("morning"), qsTr("midday"), qsTr("afternoon"), qsTr("evening")]

// the day of the week of ms, Monday 0
function weekday(ms) {
    return (new Date(ms).getDay() + 6) % 7
}

// morning before 11, midday to 14, afternoon to 17, evening after
function slot(ms) {
    var h = new Date(ms).getHours()
    if (h < 11)
        return 0
    if (h < 14)
        return 1
    if (h < 17)
        return 2
    return 3
}

// the Monday k weeks before the Monday of ms, at local midnight (by date, so DST never shifts it)
function mondayBack(ms, k) {
    var d = new Date(Format.weekStart(ms))
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() - 7 * k).getTime()
}

// This week so far against the usual week at the same point: the average of the last 8 weeks
// (fewer when the rider started later), each counted from its Monday to the same weekday and time.
// { weekSeconds, weekRides, weekLoad, usualSeconds, usualRides, usualLoad, weeks, dayName }
function usual(rides, now) {
    var monday = Format.weekStart(now)
    var elapsed = now - monday
    var out = { weekSeconds: 0, weekRides: 0, weekLoad: 0, usualSeconds: 0, usualRides: 0, usualLoad: 0, weeks: 0,
                dayName: dayNames[weekday(now)] }
    if (!rides || rides.length === 0)
        return out
    var firstStart = rides[rides.length - 1].start
    var sums = []
    for (var k = 1; k <= 8; k++) {
        var from = mondayBack(now, k)
        // a week before the first ride says nothing about the usual
        if (from + 7 * dayMs <= firstStart)
            break
        sums.push({ from: from, to: from + elapsed, seconds: 0, rides: 0, load: 0 })
    }
    for (var i = 0; i < rides.length; i++) {
        var r = rides[i]
        if (r.start >= monday) {
            out.weekSeconds += r.duration || 0
            out.weekRides++
            out.weekLoad += r.tss || 0
            continue
        }
        for (var j = 0; j < sums.length; j++)
            if (r.start >= sums[j].from && r.start < sums[j].to) {
                sums[j].seconds += r.duration || 0
                sums[j].rides++
                sums[j].load += r.tss || 0
            }
        if (sums.length > 0 && r.start < sums[sums.length - 1].from)
            break
    }
    out.weeks = sums.length
    for (var s = 0; s < sums.length; s++) {
        out.usualSeconds += sums[s].seconds / sums.length
        out.usualRides += sums[s].rides / sums.length
        out.usualLoad += sums[s].load / sums.length
    }
    return out
}

function usualSample() {
    return { weekSeconds: 5400, weekRides: 2, weekLoad: 110, usualSeconds: 4800, usualRides: 2, usualLoad: 95, weeks: 8,
             dayName: dayNames[3], sample: true }
}

// The bars of a usual(): time, rides and load, with their words
function usualRows(u) {
    var rows = [{ label: qsTr("Time"), value: u.weekSeconds, usual: u.usualSeconds,
                  valueText: Format.hours(u.weekSeconds), usualText: Format.hours(u.usualSeconds) },
                { label: qsTr("Rides"), value: u.weekRides, usual: u.usualRides,
                  valueText: String(u.weekRides), usualText: u.usualRides < 1 ? qsTr("under 1") : String(Math.round(u.usualRides * 2) / 2) }]
    if (u.weekLoad > 0 || u.usualLoad > 0)
        rows.push({ label: qsTr("Training load"), value: u.weekLoad, usual: u.usualLoad,
                    valueText: String(Math.round(u.weekLoad)), usualText: String(Math.round(u.usualLoad)) })
    return rows
}

// a short sentence about a usual(): "Ahead of your usual."
function usualWords(u) {
    if (u.sample)
        return qsTr("Your week, next to your usual.")
    if (u.usualSeconds <= 0)
        return u.weekSeconds > 0 ? qsTr("Your usual shows after a couple of weeks.") : qsTr("A fresh week.")
    var ratio = u.weekSeconds / u.usualSeconds
    if (ratio > 1.15)
        return qsTr("Ahead of your usual.")
    if (ratio < 0.85)
        return u.weekSeconds > 0 ? qsTr("A lighter week so far.") : qsTr("A fresh week, plenty of it left.")
    return qsTr("Right on your usual.")
}

// When the rider rides best, over the last 182 days: per weekday and per time of day, every
// ride and the strongest third of them by power (normalized power, else average power). It needs
// 8 rides with power at least ("enough").
// { days: [{ all, strong }] Monday first, slots: [{ all, strong }], bestDay, bestSlot, enough, rides }
function whenBest(rides, now) {
    var out = { days: [], slots: [], bestDay: -1, bestSlot: -1, enough: false, rides: 0 }
    for (var d = 0; d < 7; d++)
        out.days.push({ all: 0, strong: 0 })
    for (var t = 0; t < 4; t++)
        out.slots.push({ all: 0, strong: 0 })
    var list = []
    for (var i = 0; rides && i < rides.length; i++) {
        var r = rides[i]
        if (r.start < now - 182 * dayMs)
            break
        var score = r.np > 0 ? r.np : (r.avgPower || 0)
        if (score > 0)
            list.push({ start: r.start, score: score })
    }
    out.rides = list.length
    if (list.length < 8)
        return out
    out.enough = true
    var sorted = list.map(function (x) { return x.score }).sort(function (a, b) { return b - a })
    var cut = sorted[Math.max(0, Math.ceil(sorted.length / 3) - 1)]
    for (var j = 0; j < list.length; j++) {
        var day = out.days[weekday(list[j].start)]
        var part = out.slots[slot(list[j].start)]
        day.all++
        part.all++
        if (list[j].score >= cut) {
            day.strong++
            part.strong++
        }
    }
    out.bestDay = pick(out.days)
    out.bestSlot = pick(out.slots)
    return out
}

// the bucket with the most strong rides; on a tie the one where more of its rides are strong
function pick(list) {
    var best = -1
    for (var i = 0; i < list.length; i++) {
        if (list[i].strong === 0)
            continue
        if (best < 0 || list[i].strong > list[best].strong
                || (list[i].strong === list[best].strong && list[i].strong / list[i].all > list[best].strong / list[best].all))
            best = i
    }
    return best
}

function whenSample() {
    var all = [2, 3, 2, 3, 1, 4, 4]
    var strong = [0, 2, 1, 1, 0, 2, 1]
    var out = { days: [], slots: [], bestDay: 1, bestSlot: 3, enough: true, rides: 19, sample: true }
    for (var d = 0; d < 7; d++)
        out.days.push({ all: all[d], strong: strong[d] })
    var sAll = [6, 2, 3, 8]
    var sStrong = [2, 0, 1, 4]
    for (var t = 0; t < 4; t++)
        out.slots.push({ all: sAll[t], strong: sStrong[t] })
    return out
}

function whenWords(w) {
    if (!w.enough)
        return qsTr("After a few more rides this finds your best days.")
    if (w.sample)
        return qsTr("Your best days and times, found for you.")
    var day = dayNames[w.bestDay]
    return w.bestSlot >= 0 ? qsTr("%1s, in the %2.").arg(day).arg(slotNames[w.bestSlot]) : qsTr("%1s.").arg(day)
}

// The effort mix of the last 30 days: riding time as easy (zones 1 and 2), moderate (zone 3)
// and hard (zone 4 and up), each ride by its intensity; a ride without power counts as easy,
// as on the week shapes. { easy, moderate, hard, total, rides } in seconds.
function mix(rides, now) {
    var out = { easy: 0, moderate: 0, hard: 0, total: 0, rides: 0 }
    for (var i = 0; rides && i < rides.length; i++) {
        var r = rides[i]
        if (r.start < now - 30 * dayMs)
            break
        var zone = r.intensity > 0 ? Insights.zoneOfIntensity(r.intensity) : 2
        var s = r.duration || 0
        if (zone <= 2)
            out.easy += s
        else if (zone === 3)
            out.moderate += s
        else
            out.hard += s
        out.total += s
        out.rides++
    }
    return out
}

function mixSample() {
    return { easy: 27000, moderate: 5400, hard: 3600, total: 36000, rides: 12, sample: true }
}

function mixWords(m) {
    if (m.sample)
        return qsTr("Easy, moderate and hard, at a glance.")
    if (m.total <= 0)
        return qsTr("No rides in the last 30 days.")
    var e = m.easy / m.total
    var h = m.hard / m.total
    if (e >= 0.7)
        return qsTr("Mostly easy. A strong base.")
    if (h >= 0.3)
        return qsTr("A lot of hard riding lately.")
    if (m.moderate / m.total >= 0.5)
        return qsTr("Mostly in the middle.")
    return qsTr("A good spread of efforts.")
}
