.pragma library
.import "../Format.js" as Format
.import "../Metrics.js" as Metrics

// The moments of a finished ride: records, milestones, goals and the warm word when nothing
// special happened. Pure functions of plain data, so they can be tested without the library.
// A moment is { key, kind, title, detail, value, unit, tone, rank }: value is always text, tone is
// the 1-based zone whose color it takes, and the lowest rank is the biggest moment.

var dayMs = 86400000
var rideRungs = [10, 25, 50, 100, 250, 500, 1000]
var distanceRungs = [100, 250, 500, 1000, 2500, 5000, 10000, 20000, 40075]
var workRungs = [1000, 5000, 10000, 25000, 50000, 100000, 250000]
var kindWords = [qsTr("Consistency builds fitness."), qsTr("Another one in the bank."),
                 qsTr("Showing up is the hard part. Done."), qsTr("Every ride adds up.")]

function moment(key, kind, rank, tone, title, detail, value, unit) {
    return { key: key, kind: kind, rank: rank, tone: tone, title: title, detail: detail,
             value: String(value), unit: unit }
}

// the highest rung passed on the way from before to after, or 0
function rungCrossed(rungs, before, after) {
    var crossed = 0
    for (var i = 0; i < rungs.length; i++)
        if (before < rungs[i] && after >= rungs[i])
            crossed = rungs[i]
    return crossed
}

// Monday of the week of a day, taken at noon so a DST change cannot move it to the day before
function weekOf(dayMsValue) {
    return Format.weekStart(Format.startOfDay(dayMsValue) + 12 * 3600000)
}

// seconds ridden per week (keyed by Monday) from library.days()
function perWeek(days) {
    var weeks = {}
    for (var i = 0; i < days.length; i++) {
        var w = weekOf(days[i].day)
        weeks[w] = (weeks[w] || 0) + days[i].seconds
    }
    return weeks
}

// weeks in a row meeting the goal, counting back from the week of monday, as GoalsScreen does
function streak(weeks, monday, goalSeconds) {
    var count = 0
    var start = monday
    while ((weeks[start] || 0) >= goalSeconds) {
        count++
        start = weekOf(start - 7 * dayMs)
    }
    return count
}

// the library ride that is this finished ride: started about elapsed seconds before it ended,
// about as long; rides are newest first
function match(rides, finishedAt, elapsed) {
    var expected = finishedAt - elapsed * 1000
    for (var i = 0; i < rides.length; i++) {
        var r = rides[i]
        var startOk = r.start >= expected - 5 * 60000 && r.start <= finishedAt + 60000
        var durationOk = Math.abs(r.duration - elapsed) <= Math.max(180, elapsed * 0.15)
        if (startOk && durationOk)
            return r
    }
    return null
}

// the ride the library just read: a newest ride that was not there when the summary opened and
// started within the ride, with up to 2 h of pauses (the ride time leaves the pauses out)
function arrived(rides, knownId, finishedAt, elapsed) {
    if (rides.length === 0 || rides[0].id === knownId)
        return null
    var r = rides[0]
    if (r.start >= finishedAt - elapsed * 1000 - 2 * 3600000 && r.start <= finishedAt + 60000)
        return r
    return null
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
        var percent = Math.max(1, Math.round(f.gain * 100))
        out.push(moment("record" + f.seconds, "record", 2 + j * 0.01, recordTone(f.seconds),
                        qsTr("New %1 record").arg(Format.effort(f.seconds)),
                        qsTr("Up %1% on your best of %2 W").arg(percent).arg(Math.round(f.previous)),
                        Math.round(f.watts), "W"))
    }
    if (found.length > 3) {
        var rest = found.slice(3).sort(function (a, b) { return a.seconds - b.seconds })
        var names = rest.map(function (f) { return Format.effort(f.seconds) })
        out.push(moment("recordsMore", "records", 2.05, 7,
                        qsTr("More new records"),
                        names.join(", "), rest.length, rest.length === 1 ? qsTr("record") : qsTr("records")))
    }
    return out
}

// Everything but the records. input:
//   elapsed, km, kj        this ride
//   start                  when it started (ms)
//   before                 totals of the rides before it: { rides, distance, kj }
//   days                   library.days() of the rides before it
//   previousStart          start of the ride before it, 0 when there is none
//   longestBefore          the longest ride before it, in seconds
//   goalMinutes, miles
function detect(input) {
    var out = []
    var count = (input.before.rides || 0) + 1
    var history = count > 1

    if (count === 1)
        out.push(moment("first", "first", 0, 7, qsTr("Your first ride"),
                        qsTr("The first one is the hardest. Welcome to Bikemodo."),
                        Metrics.clock(input.elapsed), ""))
    else if (rideRungs.indexOf(count) >= 0)
        out.push(moment("rides" + count, "rides", 3, 7, qsTr("Milestone ride"),
                        qsTr("Every single one of them counts."), count, qsTr("rides")))

    // a week or more since the last ride: the return is worth a word
    if (history && input.previousStart > 0) {
        var away = Math.floor((input.start - input.previousStart) / dayMs)
        if (away >= 7)
            out.push(moment("back", "back", 2.5, 4, qsTr("Welcome back"),
                            qsTr("%1 days off, and you came back. That is the part that matters.").arg(away),
                            away, qsTr("days")))
    }

    // lifetime ladders
    var beforeKm = input.before.distance || 0
    var km = rungCrossed(distanceRungs, beforeKm, beforeKm + input.km)
    if (km > 0) {
        var world = km === 40075
        var shown = input.miles ? Math.round(km * 0.621371) : km
        out.push(moment("km" + km, "distance", km >= 10000 ? 1 : 4, 2,
                        world ? qsTr("Around the world") : qsTr("Lifetime distance"),
                        world ? qsTr("You have ridden the length of the equator.") : qsTr("A new rung on the distance ladder."),
                        Format.big(shown), input.miles ? "mi" : "km"))
    }
    var beforeKj = input.before.kj || 0
    var kj = rungCrossed(workRungs, beforeKj, beforeKj + input.kj)
    if (kj > 0)
        out.push(moment("kj" + kj, "work", kj >= 100000 ? 1 : 5, 4, qsTr("Lifetime work"),
                        qsTr("A new rung on the work ladder."), Format.big(kj), "kJ"))

    // the weekly goal, met by this ride, and the weeks in a row it extends
    var weeks = perWeek(input.days)
    // a ride counts in the week it started, as in the library and on Goals
    var monday = weekOf(input.start)
    var weekBefore = weeks[monday] || 0
    var weekAfter = weekBefore + input.elapsed
    var goal = input.goalMinutes * 60
    if (goal > 0 && weekBefore < goal && weekAfter >= goal) {
        var past = {}
        for (var w in weeks)
            past[w] = weeks[w]
        past[monday] = weekAfter
        var run = streak(past, monday, goal)
        if (run > 1)
            out.push(moment("goal", "streak", 6, 5, qsTr("Weekly streak"),
                            qsTr("Weekly goal met, %1 weeks in a row.").arg(run), run, qsTr("weeks")))
        else
            out.push(moment("goal", "goal", 6, 3, qsTr("Weekly goal met"),
                            qsTr("%1 minutes this week. A streak starts here.").arg(Math.round(weekAfter / 60)),
                            Math.round(weekAfter / 60), qsTr("min")))
    }

    // longest ride and biggest week, once there is a history to beat
    if (count > 3 && input.longestBefore > 0 && input.elapsed > input.longestBefore) {
        var longer = input.elapsed - input.longestBefore
        out.push(moment("longest", "longest", 7, 3, qsTr("Your longest ride"),
                        longer >= 60 ? qsTr("%1 longer than ever before.").arg(Format.hours(longer))
                                     : qsTr("Longer than ever before."),
                        Metrics.clock(input.elapsed), ""))
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
