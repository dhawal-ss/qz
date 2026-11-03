.pragma library
.import "../Format.js" as Format
.import "../Metrics.js" as Metrics
.import "../goals/Streak.js" as Streak

// The moments of a finished ride: records, milestones, goals and the warm word when nothing
// special happened. Pure functions of plain data, so they can be tested without the library.
// A moment is { key, kind, title, detail, value, unit, tone, rank }: value is always text, tone is
// the 1-based zone whose color it takes, and the lowest rank is the biggest moment. A record also
// carries { seconds, previous, gain } and the weekly goal { week } for the Week closed screen.

var dayMs = 86400000
var rideRungs = [10, 25, 50, 100, 250, 500, 1000]
// The lifetime distance ladder, in round numbers of the rider's unit; the last rung is the length
// of the equator. The rungs are compared in km: distanceLadder() gives the ladder of a rider in km.
var distanceRungs = [100, 250, 500, 1000, 2500, 5000, 10000, 20000, 40075]
var mileRungs = [50, 100, 250, 500, 1000, 2500, 5000, 10000, 24901]
var workRungs = [1000, 5000, 10000, 25000, 50000, 100000, 250000]
var kindWords = [qsTr("Consistency builds fitness."), qsTr("Another one in the bank."),
                 qsTr("Showing up is the hard part. Done."), qsTr("Every ride adds up.")]

function moment(key, kind, rank, tone, title, detail, value, unit) {
    return { key: key, kind: kind, rank: rank, tone: tone, title: title, detail: detail,
             value: String(value), unit: unit }
}

// the distance ladder of a rider, in km
function distanceLadder(miles) {
    return miles ? mileRungs.map(function (m) { return m / 0.621371 }) : distanceRungs
}

// a rung of distanceLadder() in the rider's unit, a round number: 500 for 500 mi
function rungShown(km, miles) {
    return Math.round(km * (miles ? 0.621371 : 1))
}

// the last rung, around the world
function isWorldRung(km) {
    return km >= distanceRungs[distanceRungs.length - 1] - 1
}

// the highest rung passed on the way from before to after, or 0
function rungCrossed(rungs, before, after) {
    var crossed = 0
    for (var i = 0; i < rungs.length; i++)
        if (before < rungs[i] && after >= rungs[i])
            crossed = rungs[i]
    return crossed
}

// the first day of the week of a day (Monday, or Sunday when weeks start on Sunday: Format.firstDay),
// taken at noon so a DST change cannot move it to the day before
function weekOf(dayMsValue) {
    return Format.weekStart(Format.startOfDay(dayMsValue) + 12 * 3600000)
}

// seconds ridden per week (keyed by weekOf()) from library.days()
function perWeek(days) {
    var weeks = {}
    for (var i = 0; i < days.length; i++) {
        // read 6 h into the day: Qt 5 can read a midnight of the other half of the DST year as
        // 23:00 of the day before
        var w = weekOf(days[i].day + 6 * 3600000)
        weeks[w] = (weeks[w] || 0) + days[i].seconds
    }
    return weeks
}

// weeks in a row meeting the goal, counting back from the week of monday (weekOf()), as GoalsScreen does
function streak(weeks, monday, goalSeconds) {
    var count = 0
    var start = monday
    while ((weeks[start] || 0) >= goalSeconds) {
        count++
        start = weekOf(start - 7 * dayMs)
    }
    return count
}

// The library ride that holds this finished ride, rides newest first. A ride saved soon after the
// one before joins it (ridelibrary.h: ui2/mergeGapMinutes), so the ride may keep the id of a ride
// that was already there, start well before this session and last longer: only its end (the end
// of its last second) says it is this one. It is the newest ride that ends within 90 s of endedAt,
// when the ride ended (when it was paused, for a ride ended while paused: the file holds no
// second after that). A short ride also cannot be taken for the ride before it: the end has to
// fall in the second half of this ride at least. known is { id, end } of the newest ride when the
// summary opened, or null: until the library has read this ride, that ride is not this one, even
// when it ends close by.
function match(rides, endedAt, elapsed, known) {
    var earliest = endedAt - Math.min(90000, (elapsed || 0) * 500)
    for (var i = 0; i < rides.length; i++) {
        var r = rides[i]
        if (!(r.end > 0) || r.end < earliest || r.end > endedAt + 90000)
            continue
        if (known && r.id === known.id && !(r.end > known.end))
            continue
        return r
    }
    return null
}

// What a library ride holds from before this session, when this session joined it (a merge):
// the ride without this session, { seconds, km, kj, tss }, or null when the ride is this session
// alone. session is { elapsed, km, kj, tss } of the finished ride.
function earlierPart(saved, session) {
    if (!saved || !((saved.parts || 1) > 1))
        return null
    var seconds = (saved.duration || 0) - (session.elapsed || 0)
    // the parts are all this session (saved twice while it lasted)
    if (seconds < 60)
        return null
    return { seconds: seconds, km: Math.max(0, (saved.distance || 0) - (session.km || 0)),
             kj: Math.max(0, (saved.kj || 0) - (session.kj || 0)), tss: Math.max(0, (saved.tss || 0) - (session.tss || 0)) }
}

// totals of library.totals() with the earlier part of a merged ride added as the ride it was
function totalsWith(totals, part) {
    return { rides: (totals.rides || 0) + 1, seconds: (totals.seconds || 0) + part.seconds,
             distance: (totals.distance || 0) + part.km, kj: (totals.kj || 0) + part.kj, tss: (totals.tss || 0) + part.tss }
}

// days of library.days() with the earlier part of a merged ride added on the day it started
function daysWith(days, startMs, part) {
    var day = Format.startOfDay(startMs)
    var out = []
    var added = false
    for (var i = 0; i < days.length; i++) {
        var d = days[i]
        if (Format.startOfDay(d.day + 12 * 3600000) === day) {
            out.push({ day: d.day, rides: (d.rides || 0) + 1, seconds: (d.seconds || 0) + part.seconds,
                       distance: (d.distance || 0) + part.km, kj: (d.kj || 0) + part.kj, tss: (d.tss || 0) + part.tss })
            added = true
        } else {
            out.push(d)
        }
    }
    if (!added)
        out.push({ day: day, rides: 1, seconds: part.seconds, distance: part.km, kj: part.kj, tss: part.tss })
    return out
}

// the color of a power record: short efforts glow hot, long ones calm
function recordTone(seconds) {
    if (seconds <= 15)
        return 7
    if (seconds <= 120)
        return 5
    if (seconds <= 480)
        return 4
    if (seconds <= 1800)
        return 3
    return 2
}

function wattsAt(list, seconds) {
    for (var i = 0; i < list.length; i++)
        if (list[i].seconds === seconds)
            return list[i].watts
    return 0
}

// "5 minute", "20 second", "1 hour": an effort as words, for "New 5 minute best"
function effortWords(seconds) {
    if (seconds < 60)
        return seconds === 1 ? qsTr("1 second") : qsTr("%1 second").arg(seconds)
    if (seconds < 3600) {
        var m = Math.round(seconds / 60)
        return m === 1 ? qsTr("1 minute") : qsTr("%1 minute").arg(m)
    }
    var h = seconds / 3600
    return h === 1 ? qsTr("1 hour") : qsTr("%1 hour").arg(h)
}

// New power records of a ride: records are the durations the library marked, best the ride's
// own best watts, previousCurve the best watts of every ride before it. Peaks under 5 s are
// mostly sensor noise and stay out. The 3 biggest gains get a moment each, the rest one more.
function recordMoments(records, best, previousCurve) {
    var found = []
    for (var i = 0; i < records.length; i++) {
        var seconds = records[i]
        var watts = wattsAt(best, seconds)
        var previous = wattsAt(previousCurve, seconds)
        if (seconds < 5 || watts <= 0 || previous <= 0 || watts <= previous)
            continue
        found.push({ seconds: seconds, watts: watts, previous: previous, gain: (watts - previous) / previous })
    }
    found.sort(function (a, b) { return b.gain - a.gain })
    var out = []
    for (var j = 0; j < found.length && j < 3; j++) {
        var f = found[j]
        var up = Math.max(1, Math.round(f.watts) - Math.round(f.previous))
        var m = moment("record" + f.seconds, "record", 2 + j * 0.01, recordTone(f.seconds),
                       qsTr("New %1 best").arg(effortWords(f.seconds)),
                       up === 1 ? qsTr("Previous %1. Up 1 watt.").arg(Math.round(f.previous))
                                : qsTr("Previous %1. Up %2 watts.").arg(Math.round(f.previous)).arg(up),
                       Math.round(f.watts), "W")
        m.seconds = f.seconds
        m.previous = Math.round(f.previous)
        m.gain = up
        out.push(m)
    }
    if (found.length > 3) {
        var rest = found.slice(3).sort(function (a, b) { return a.seconds - b.seconds })
        var names = rest.map(function (f) { return Format.effort(f.seconds) })
        out.push(moment("recordsMore", "records", 2.05, 7,
                        qsTr("More new bests"),
                        names.join(", "), rest.length, rest.length === 1 ? qsTr("best") : qsTr("bests")))
    }
    return out
}

// the goal in words: "3 rides", "120 min", "1 500 kJ", "60 km"
function goalAmount(kind, value, miles) {
    if (kind === "rides")
        return Math.round(value) === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(Math.round(value))
    if (kind === "kj")
        return Format.big(value) + " kJ"
    if (kind === "km")
        return Format.distance(value, miles)
    return qsTr("%1 min").arg(Math.round(value))
}

// the average of a measure over the 4 weeks before monday that had riding, 0 when none did
function usual(weeks, monday, measure) {
    var sum = 0
    var n = 0
    for (var i = 1; i <= 4; i++) {
        var w = weeks[Streak.weekKey(Streak.addWeeks(monday, -i))]
        if (!w || w.rides === 0)
            continue
        sum += measure(w)
        n++
    }
    return n > 0 ? sum / n : 0
}

// Everything but the records. input:
//   elapsed, km, kj        this ride
//   start                  when it started (ms)
//   before                 totals of the rides before it: { rides, distance, kj }
//   days                   library.days() of the rides before it
//   previousStart          start of the ride before it, 0 when there is none
//   longestBefore          the longest ride before it, in seconds
//   tss                    the training load of this ride, 0 when unknown
//   goalKind, goalValue    the weekly goal (Streak.kinds), as set on Goals
//   restWeeks              the week keys marked rest (Streak.js)
//   miles
//   continued              earlierPart() when this session joined a ride from before (a merge),
//                          else left out: then before and days leave out the whole merged ride
//                          (they are of the rides that started before it), and start is its start.
//                          It is the same ride, so the ride count does not grow.
function detect(input) {
    var out = []
    var earlier = input.continued || null
    if (earlier !== null) {
        var copy = {}
        for (var field in input)
            copy[field] = input[field]
        copy.before = totalsWith(input.before || {}, earlier)
        copy.days = daysWith(input.days || [], input.start, earlier)
        input = copy
    }
    var count = (input.before.rides || 0) + (earlier !== null ? 0 : 1)
    var history = count > 1
    var rideSeconds = input.elapsed + (earlier !== null ? earlier.seconds : 0)

    // the ride count, the first ride and the welcome back belong to the ride a merged one joined
    if (earlier === null && count === 1)
        out.push(moment("first", "first", 0, 7, qsTr("Your first ride"),
                        qsTr("The first one is the hardest. Welcome to Bikemodo."),
                        Metrics.clock(input.elapsed), ""))
    else if (earlier === null && rideRungs.indexOf(count) >= 0)
        out.push(moment("rides" + count, "rides", 3, 7, qsTr("Milestone ride"),
                        qsTr("Every single one of them counts."), count, qsTr("rides")))

    // a week or more since the last ride: the return is worth a word, and the streak with it
    if (history && earlier === null && input.previousStart > 0) {
        var away = Math.floor((input.start - input.previousStart) / dayMs)
        if (away >= 7) {
            var kindNow = Streak.kinds.indexOf(input.goalKind) >= 0 ? input.goalKind : "minutes"
            var before = Streak.run(Streak.perWeek(input.days), { kind: kindNow, goal: Number(input.goalValue) || 0,
                                                                  rest: input.restWeeks || [], now: input.start })
            var lastWeek = before.timeline.length > 1 ? before.timeline[before.timeline.length - 2].status : ""
            var said = qsTr("%1 days off, and you came back. That is the part that matters.").arg(away)
            if (before.streak > 0 && lastWeek === "frozen")
                said = qsTr("Your %1 week streak is safe. A freeze covered last week.").arg(before.streak)
            else if (before.streak > 0 && lastWeek === "rest")
                said = qsTr("Your %1 week streak waited for you.").arg(before.streak)
            out.push(moment("back", "back", 2.5, 4, qsTr("Welcome back"), said, away, qsTr("days")))
        }
    }

    // lifetime ladders
    var beforeKm = input.before.distance || 0
    var ladder = distanceLadder(input.miles)
    var km = rungCrossed(ladder, beforeKm, beforeKm + input.km)
    if (km > 0) {
        var world = isWorldRung(km)
        var shown = rungShown(km, input.miles)
        // the top three rungs are the biggest moments
        out.push(moment((input.miles ? "mi" : "km") + shown, "distance", ladder.indexOf(km) >= ladder.length - 3 ? 1 : 4, 2,
                        world ? qsTr("Around the world") : qsTr("Lifetime distance"),
                        world ? qsTr("You have ridden the length of the equator.") : qsTr("A new rung on the distance ladder."),
                        Format.big(shown), input.miles ? "mi" : "km"))
    }
    var beforeKj = input.before.kj || 0
    var kj = rungCrossed(workRungs, beforeKj, beforeKj + input.kj)
    if (kj > 0)
        out.push(moment("kj" + kj, "work", kj >= 100000 ? 1 : 5, 4, qsTr("Lifetime work"),
                        qsTr("A new rung on the work ladder."), Format.big(kj), "kJ"))

    // the weekly goal (rules in goals/Streak.js), closed by this ride, and the weeks in a row
    var kind = Streak.kinds.indexOf(input.goalKind) >= 0 ? input.goalKind : "minutes"
    var goalValue = Number(input.goalValue) || 0
    var byWeek = Streak.perWeek(input.days)
    var thisKey = Streak.weekKey(input.start)
    var thisMonday = Streak.weekStartOf(input.start)
    var was = byWeek[thisKey] || { seconds: 0, kj: 0, km: 0, rides: 0, tss: 0, lastDay: 0 }
    var withThis = { seconds: was.seconds + input.elapsed, kj: was.kj + (input.kj || 0), km: was.km + (input.km || 0),
                     rides: was.rides + (earlier !== null ? 0 : 1), tss: (was.tss || 0) + (input.tss || 0),
                     lastDay: Math.max(was.lastDay, Format.startOfDay(input.start)) }
    if (goalValue > 0 && !Streak.met(was, kind, goalValue) && Streak.met(withThis, kind, goalValue)) {
        var withRide = {}
        for (var wk in byWeek)
            withRide[wk] = byWeek[wk]
        withRide[thisKey] = withThis
        var result = Streak.run(withRide, { kind: kind, goal: goalValue, rest: input.restWeeks || [], now: input.start })
        var run = result.streak
        var amount = goalAmount(kind, Streak.measure(withThis, kind), input.miles)
        var goalMoment = run > 1
            ? moment("goal", "streak", 6, 5, qsTr("Week closed"),
                     qsTr("%1 this week. Weekly goal met, %2 weeks in a row.").arg(amount).arg(run), run, qsTr("weeks"))
            : moment("goal", "goal", 6, 3, qsTr("Weekly goal met"),
                     qsTr("%1 this week. A streak starts here.").arg(amount), run, run === 1 ? qsTr("week") : qsTr("weeks"))
        goalMoment.week = {
            kind: kind, goal: goalValue, monday: thisMonday, streak: run, freezes: result.freezes, toNextFreeze: result.toNextFreeze,
            rides: withThis.rides, minutes: withThis.seconds / 60, kj: withThis.kj, km: withThis.km, tss: withThis.tss,
            usualRides: usual(byWeek, thisMonday, function (w) { return w.rides }),
            usualMinutes: usual(byWeek, thisMonday, function (w) { return w.seconds / 60 }),
            usualTss: usual(byWeek, thisMonday, function (w) { return w.tss || 0 })
        }
        out.push(goalMoment)
    }
    var weeks = perWeek(input.days)
    var monday = weekOf(input.start)
    var weekBefore = weeks[monday] || 0
    var weekAfter = weekBefore + input.elapsed

    // longest ride and biggest week, once there is a history to beat
    if (count > 3 && input.longestBefore > 0 && rideSeconds > input.longestBefore) {
        var longer = rideSeconds - input.longestBefore
        out.push(moment("longest", "longest", 7, 3, qsTr("Your longest ride"),
                        longer >= 60 ? qsTr("%1 longer than ever before.").arg(Format.hours(longer))
                                     : qsTr("Longer than ever before."),
                        Metrics.clock(rideSeconds), ""))
    }
    var maxBefore = 0
    var ridden = 0
    for (var key in weeks) {
        if (Number(key) === monday)
            continue
        ridden++
        maxBefore = Math.max(maxBefore, weeks[key])
    }
    if (ridden >= 3 && weekBefore <= maxBefore && weekAfter > maxBefore)
        out.push(moment("week", "week", 8, 5, qsTr("Biggest week yet"),
                        qsTr("More riding than any week before."), Math.round(weekAfter / 60), qsTr("min")))

    if (out.length === 0)
        out.push(fallback(count, input.elapsed))
    return sorted(out)
}

// the plain word when nothing special happened: the ride number and a kind line
function fallback(count, elapsed) {
    return moment("plain", "plain", 100, 2, qsTr("Ride %1").arg(count), kindWords[count % kindWords.length],
                  Metrics.clock(elapsed), "")
}

function demo(elapsed) {
    return [moment("demo", "demo", 100, 1, qsTr("Demo ride"),
                   qsTr("Not saved, so it stays out of your records and goals."), Metrics.clock(elapsed), "")]
}

// adds moments that came later (the records) to a list; the plain word leaves once there is more
function merge(list, extra) {
    var out = []
    var keys = {}
    var all = list.concat(extra)
    for (var i = 0; i < all.length; i++) {
        if (keys[all[i].key])
            continue
        keys[all[i].key] = true
        out.push(all[i])
    }
    if (out.length > 1)
        out = out.filter(function (m) { return m.kind !== "plain" })
    return sorted(out)
}

// by rank, keeping the order of equal ranks
function sorted(list) {
    var indexed = list.map(function (m, i) { return { m: m, i: i } })
    indexed.sort(function (a, b) { return a.m.rank - b.m.rank || a.i - b.i })
    return indexed.map(function (x) { return x.m })
}

// values averaged into n buckets in order (fewer values than n stay as they are)
function buckets(values, n) {
    var count = values.length
    if (count <= n)
        return values.slice()
    var out = []
    for (var b = 0; b < n; b++) {
        var from = Math.floor(b * count / n)
        var to = Math.max(from + 1, Math.floor((b + 1) * count / n))
        var sum = 0
        for (var i = from; i < to; i++)
            sum += Number(values[i]) || 0
        out.push(sum / (to - from))
    }
    return out
}
