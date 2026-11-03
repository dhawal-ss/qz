.pragma library
.import "../Format.js" as Format
.import "../moments/Moments.js" as Moments

// The insight cards of Today: small true things about the rider's own riding, worked out from
// the library. Pure functions of plain data, so they can be tested without the library.
// An insight is { id, rank, title, detail, value, unit, tone, action }: value is always text,
// tone is the 1-based zone whose color it takes, action says where a tap goes:
// { kind: "ride" } starts a ride, { kind: "openRide", rideId } opens one, { kind: "tab", tab }.
// Only good news makes a card: a number that went down makes none.
// Days are worked out at noon: the JavaScript engine of Qt 5 can read local midnight of a DST
// change as 23:00 of the day before, noon is never on the wrong day.

var dayMs = 86400000
var sixWeeks = 42 * dayMs
var dayNames = [qsTr("Sunday"), qsTr("Monday"), qsTr("Tuesday"), qsTr("Wednesday"), qsTr("Thursday"),
                qsTr("Friday"), qsTr("Saturday")]
var zoneWords = [qsTr("recovery"), qsTr("endurance"), qsTr("tempo"), qsTr("threshold"), qsTr("VO2 max"),
                 qsTr("anaerobic"), qsTr("sprint")]
// where each power zone starts, as a share of FTP, as in Theme.powerZoneStarts
var zoneStarts = [0.555, 0.755, 0.905, 1.055, 1.205, 1.505]
// the efforts the comparisons look at; peaks under 5 s are mostly sensor noise
var efforts = [5, 60, 300, 1200]
var reachEfforts = [5, 60, 300, 600, 1200, 3600]
// ranks under 10 are news of the day and always lead; the others take turns
var pinnedRank = 10

function insight(id, rank, tone, title, detail, value, unit, action) {
    return { id: id, rank: rank, tone: tone, title: title, detail: detail, value: String(value),
             unit: unit, action: action }
}

function noon(ms) {
    var d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12)
}

// whole days from the day of a to the day of b
function daysBetween(a, b) {
    return Math.round((noon(b).getTime() - noon(a).getTime()) / dayMs)
}

// a number that goes up by exactly one every local day, whatever the time zone or DST
function dayNumber(ms) {
    var d = new Date(ms)
    return Math.round(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / dayMs)
}

function wattsAt(list, seconds) {
    for (var i = 0; i < (list || []).length; i++)
        if (list[i].seconds === seconds)
            return list[i].watts
    return 0
}

function pointAt(list, seconds) {
    for (var i = 0; i < (list || []).length; i++)
        if (list[i].seconds === seconds)
            return list[i]
    return null
}

// the power zone of a ride from its intensity (NP over FTP)
function zoneOfIntensity(intensity) {
    var zone = 1
    for (var i = 0; i < zoneStarts.length; i++)
        if (intensity >= zoneStarts[i])
            zone = i + 2
    return zone
}

// weeks in a row with at least one ride: this week counts once it has one, and until then the
// streak is the weeks before it
function rideWeekStreak(days, now) {
    var weeks = Moments.perWeek(days)
    var start = Moments.weekOf(now)
    if (!(weeks[start] > 0))
        start = Moments.weekOf(start - 7 * dayMs)
    var count = 0
    while (weeks[start] > 0) {
        count++
        start = Moments.weekOf(start - 7 * dayMs)
    }
    return count
}

// The best effort of the latest ride that came within 3% of the all time best, without beating
// it: { seconds, watts, best, gap, target, rideId (the latest ride), recordRideId }, or null.
// The closest one, as a share of the best, wins.
function reach(curveAll, latestBest, latestId) {
    var found = null
    for (var i = 0; i < reachEfforts.length; i++) {
        var seconds = reachEfforts[i]
        var record = pointAt(curveAll, seconds)
        var watts = wattsAt(latestBest, seconds)
        if (!record || watts <= 0 || record.rideId === latestId || watts >= record.watts)
            continue
        var share = (record.watts - watts) / record.watts
        if (share > 0.03)
            continue
        if (found === null || share < found.share)
            found = { seconds: seconds, watts: Math.round(watts), best: Math.round(record.watts),
                      gap: Math.max(1, Math.round(record.watts - watts)), target: Math.floor(record.watts) + 1,
                      rideId: latestId, recordRideId: record.rideId, share: share }
    }
    return found
}

// the longest ride of this date one year ago, else of the day before or after it:
// { ride, offset } or null; offset is -1, 0 or 1 day from the date
function onThisDay(rides, now) {
    var d = new Date(now)
    var offsets = [0, -1, 1]
    for (var k = 0; k < offsets.length; k++) {
        var day = new Date(d.getFullYear() - 1, d.getMonth(), d.getDate() + offsets[k], 12).getTime()
        var found = null
        for (var i = 0; i < rides.length; i++)
            if (daysBetween(rides[i].start, day) === 0 && (found === null || rides[i].duration > found.duration))
                found = rides[i]
        if (found !== null)
            return { ride: found, offset: offsets[k] }
    }
    return null
}

// the next rung of the distance ladder: { rung, remaining, from } or null when every rung is done
function nextRung(rungs, value) {
    var from = 0
    for (var i = 0; i < rungs.length; i++) {
        if (value < rungs[i])
            return { rung: rungs[i], remaining: rungs[i] - value, from: from }
        from = rungs[i]
    }
    return null
}

// Everything the cards of Today need. data:
//   rides        library.rides(), newest first
//   days         library.days(0, 0)
//   curveAll     library.powerCurve(0, 0)
//   curveRecent  library.powerCurve() of the last 6 weeks, curvePrior of the 6 weeks before
//   latestBest   library.ride(id of the newest ride).best
//   lifetime     library.totals(0, 0)
//   goalStreak   the streak of weekly goals, as on Goals (goals/Streak.js run().streak)
//   miles
// Returns { list (ranked insights), reach, onThisDay, goalStreak, rideStreak, milestone }.
function build(data, now) {
    var rides = data.rides || []
    var days = data.days || []
    var latest = rides.length > 0 ? rides[0] : null
    var out = {
        list: [],
        reach: null,
        onThisDay: null,
        goalStreak: data.goalStreak || 0,
        rideStreak: rideWeekStreak(days, now),
        milestone: nextRung(Moments.distanceRungs, (data.lifetime || {}).distance || 0)
    }
    if (latest === null)
        return out
    var list = []
    var unit = data.miles ? "mi" : "km"
    var toUnit = data.miles ? 0.621371 : 1

    // a week or more off: a warm word and an easy ride to come back with
    var away = daysBetween(latest.start, now)
    if (away >= 7) {
        var ftp = latest.intensity > 0 ? latest.np / latest.intensity : 0
        list.push(insight("welcome", 1, 2, qsTr("Welcome back"),
                          ftp > 0 ? qsTr("%1 days since your last ride. An easy 30 minutes around %2 W is a great way back in.")
                                    .arg(away).arg(Math.round(ftp * 0.6 / 5) * 5)
                                  : qsTr("%1 days since your last ride. An easy 30 minutes is a great way back in.").arg(away),
                          away, qsTr("days"), { kind: "ride" }))
    }

    // a record the latest ride set in the last two days, the longest effort first
    var records = latest.records || []
    if (away <= 2) {
        var longest = 0
        for (var r = 0; r < records.length; r++)
            if (records[r] >= 5 && records[r] > longest && wattsAt(data.latestBest, records[r]) > 0)
                longest = records[r]
        if (longest > 0)
            list.push(insight("record", 2, Moments.recordTone(longest), qsTr("New %1 record").arg(Format.effort(longest)),
                              away === 0 ? qsTr("Set on your ride today. Nicely done.")
                                         : (away === 1 ? qsTr("Set on your ride yesterday. Nicely done.")
                                                       : qsTr("Set on your ride on %1. Nicely done.").arg(dayNames[new Date(latest.start).getDay()])),
                              Math.round(wattsAt(data.latestBest, longest)), "W", { kind: "openRide", rideId: latest.id }))
    }

    out.onThisDay = onThisDay(rides, now)
    if (out.onThisDay !== null) {
        var past = out.onThisDay.ride
        list.push(insight("onThisDay", 3, 2,
                          out.onThisDay.offset === 0 ? qsTr("On this day last year") : qsTr("This time last year"),
                          past.avgPower > 0 ? qsTr("You rode %1 at %2 W.").arg(Format.hours(past.duration)).arg(Math.round(past.avgPower))
                                            : qsTr("You rode %1.").arg(Format.hours(past.duration)),
                          Math.round(past.duration / 60), qsTr("min"), { kind: "openRide", rideId: past.id }))
    }

    // the effort that grew the most in the last 6 weeks against the 6 weeks before
    var bestGain = 0
    var grown = 0
    for (var e = 0; e < efforts.length; e++) {
        var recent = wattsAt(data.curveRecent, efforts[e])
        var prior = wattsAt(data.curvePrior, efforts[e])
        if (recent <= 0 || prior <= 0)
            continue
        var gain = (recent - prior) / prior
        if (gain >= 0.03 && gain > bestGain) {
            bestGain = gain
            grown = efforts[e]
        }
    }
    if (grown > 0)
        list.push(insight("powerUp", 20, Moments.recordTone(grown),
                          qsTr("Your %1 power is up %2%").arg(Format.effort(grown)).arg(Math.round(bestGain * 100)),
                          qsTr("%1 W in the last 6 weeks, from %2 W the 6 weeks before.")
                            .arg(Math.round(wattsAt(data.curveRecent, grown))).arg(Math.round(wattsAt(data.curvePrior, grown))),
                          "+" + Math.round(bestGain * 100) + "%", "", { kind: "tab", tab: "progress" }))

    out.reach = reach(data.curveAll, data.latestBest, latest.id)
    if (out.reach !== null)
        list.push(insight("reach", 21, Moments.recordTone(out.reach.seconds), qsTr("A record is within reach"),
                          qsTr("%1 W off your %2 best. Try %2 at %3 W.").arg(out.reach.gap)
                            .arg(Format.effort(out.reach.seconds)).arg(out.reach.target),
                          out.reach.gap, "W", { kind: "ride" }))

    // weeks in a row: of the goal when there is a run of it, else of riding at all
    if (out.goalStreak >= 2)
        list.push(insight("streak", 22, 5, qsTr("%1 week streak").arg(out.goalStreak),
                          qsTr("Your weekly goal, week after week. Keep it going."),
                          out.goalStreak, qsTr("weeks"), { kind: "tab", tab: "goals" }))
    else if (out.rideStreak >= 3)
        list.push(insight("streak", 22, 5, qsTr("You have ridden %1 weeks in a row").arg(out.rideStreak),
                          qsTr("At least one ride every week."), out.rideStreak, qsTr("weeks"), { kind: "tab", tab: "goals" }))

    // the best month, once there are two months before it to beat
    var months = {}
    for (var m = 0; m < days.length; m++) {
        var key = Format.monthKey(noon(days[m].day).getTime())
        months[key] = (months[key] || 0) + days[m].seconds
    }
    var thisMonth = Format.monthKey(now)
    var monthSeconds = months[thisMonth] || 0
    var before = 0
    var monthMax = 0
    for (var mk in months) {
        if (Number(mk) >= thisMonth)
            continue
        before++
        monthMax = Math.max(monthMax, months[mk])
    }
    if (before >= 2 && monthSeconds >= 3600 && monthSeconds > monthMax)
        list.push(insight("bestMonth", 23, 4, qsTr("Best month yet"),
                          qsTr("%1 in %2, more than any month before.").arg(Format.hours(monthSeconds))
                            .arg(Format.monthNames[new Date(now).getMonth()]),
                          Math.round(monthSeconds / 360) / 10, "h", { kind: "tab", tab: "progress" }))

    // the zone most of the last 30 days was ridden in, by time
    var zoneSeconds = [0, 0, 0, 0, 0, 0, 0]
    var zoneRides = 0
    var zoneTotal = 0
    for (var z = 0; z < rides.length; z++) {
        if (daysBetween(rides[z].start, now) >= 30)
            break
        if (!(rides[z].intensity > 0))
            continue
        zoneSeconds[zoneOfIntensity(rides[z].intensity) - 1] += rides[z].duration
        zoneTotal += rides[z].duration
        zoneRides++
    }
    var topZone = 0
    for (var t = 1; t < 7; t++)
        if (zoneSeconds[t] > zoneSeconds[topZone])
            topZone = t
    if (zoneRides >= 3 && zoneSeconds[topZone] >= zoneTotal * 0.5)
        list.push(insight("zone", 24, topZone + 1, qsTr("Most of your riding is %1").arg(zoneWords[topZone]),
                          qsTr("%1% of your time in the last 30 days, over %2 rides.")
                            .arg(Math.round(zoneSeconds[topZone] / zoneTotal * 100)).arg(zoneRides),
                          Math.round(zoneSeconds[topZone] / zoneTotal * 100) + "%", "", { kind: "tab", tab: "progress" }))

    // the day of the week of most rides in the last 12 weeks, when one stands out
    var perDay = [0, 0, 0, 0, 0, 0, 0]
    var counted = 0
    for (var w = 0; w < rides.length; w++) {
        if (daysBetween(rides[w].start, now) >= 84)
            break
        perDay[new Date(rides[w].start).getDay()]++
        counted++
    }
    var busiest = 0
    var second = 0
    for (var b = 1; b < 7; b++)
        if (perDay[b] > perDay[busiest])
            busiest = b
    for (var c = 0; c < 7; c++)
        if (c !== busiest)
            second = Math.max(second, perDay[c])
    if (counted >= 8 && perDay[busiest] > second) {
        var isToday = new Date(now).getDay() === busiest
        list.push(insight("busiestDay", 25, 1, qsTr("Your busiest day is %1").arg(dayNames[busiest]),
                          (isToday ? qsTr("%1 of your last %2 rides. That is today.") : qsTr("%1 of your last %2 rides."))
                            .arg(perDay[busiest]).arg(counted),
                          Format.dayShort[busiest], "", { kind: "tab", tab: "rides" }))
    }

    // the next rung of the distance ladder
    if (out.milestone !== null && ((data.lifetime || {}).distance || 0) > 0) {
        var rungText = out.milestone.rung === 40075 ? qsTr("around the world")
                                                    : Format.big(out.milestone.rung * toUnit) + " " + unit
        list.push(insight("milestone", 26, 2, qsTr("Next milestone"),
                          qsTr("%1 %2 to go to %3.").arg(Format.big(out.milestone.remaining * toUnit)).arg(unit).arg(rungText),
                          Format.big(out.milestone.remaining * toUnit), unit, { kind: "tab", tab: "goals" }))
    }

    out.list = ranked(list, now)
    return out
}

// The news of the day first by rank, then the others in turns: a different one leads each day,
// the same all day long.
function ranked(list, now) {
    var indexed = list.map(function (x, i) { return { x: x, i: i } })
    indexed.sort(function (a, b) { return a.x.rank - b.x.rank || a.i - b.i })
    var pinned = []
    var rest = []
    for (var i = 0; i < indexed.length; i++) {
        if (indexed[i].x.rank < pinnedRank)
            pinned.push(indexed[i].x)
        else
            rest.push(indexed[i].x)
    }
    if (rest.length > 1) {
        var turn = dayNumber(now) % rest.length
        rest = rest.slice(turn).concat(rest.slice(0, turn))
    }
    return pinned.concat(rest)
}

// the list without the insights a shown card already tells
function without(list, ids) {
    return list.filter(function (x) { return ids.indexOf(x.id) < 0 })
}
