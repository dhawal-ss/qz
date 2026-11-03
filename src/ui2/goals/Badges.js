.pragma library
.import "../Format.js" as Format
.import "Streak.js" as Streak
.import "Journeys.js" as Journeys

// Badges, earned from the ride history. Pure functions of plain data, so they can be tested
// without the library. A badge is { id, name, how, tone, tier, glyph, earned, date, have, need,
// progress }: tone is the 1-based zone whose color it takes, tier how spiky its Pulse is (1 to 7),
// date the ms it was earned (0 when locked), have and need the numbers toward it in unit (rides,
// km, kJ, h, weeks, records, percent or months), progress the share done (0 to 1).
// The rules:
//   - ride counts, early bird (starts before 7:00), night owl (starts at 21:00 or later), 7 rides
//     in one week (from the first day of the week the rider picked, Streak.js): earned on the ride
//     that got there
//   - 100 km, 1000 kJ or 2 h in one ride: earned on the first ride that did it. The distance
//     stays 100 km for every rider, so switching units never takes the badge away; a rider who
//     sees miles reads it in miles, as the metric century it is (62 mi)
//   - week streaks: earned on the last riding day of the week the streak got there (Streak.js)
//   - power record hat-trick: 3 new power records of 5 s or more in one ride, each beating an
//     earlier best, from the 11th ride on: the first rides beat each other at almost every
//     duration, so they do not count
//   - journeys: one badge each, earned on the day it was finished (stored, as a journey can be
//     ridden again)
//   - monthly challenges: 1, 3, 6 and 12 months met (Challenge.js)

var rideRungs = [[10, 2], [50, 3], [100, 4], [250, 5], [500, 6]]
var streakRungs = [[4, 3], [12, 4], [26, 5], [52, 6]]
var challengeRungs = [[1, 2], [3, 3], [6, 4], [12, 5]]
var hatTrickAfter = 10

function badge(id, name, how, tone, tier, glyph, have, need, date, unit) {
    var earned = date > 0
    return { id: id, name: name, how: how, tone: tone, tier: tier, glyph: glyph, unit: unit, earned: earned,
             date: earned ? date : 0, have: earned ? need : Math.min(have, need), need: need,
             progress: earned ? 1 : Math.max(0, Math.min(1, have / need)) }
}

// how many rides there are and on which one the count reached n
function nth(list, n) {
    return list.length >= n ? list[n - 1].start : 0
}

// new power records of 5 s or more per ride id, from recordHistory() of each duration:
// histories is { seconds: [{start, rideId}] } in start order; the first entry set the record,
// it did not beat one
function recordCounts(histories) {
    var counts = {}
    for (var s in histories) {
        if (Number(s) < 5)
            continue
        var list = histories[s] || []
        for (var i = 1; i < list.length; i++)
            counts[list[i].rideId] = (counts[list[i].rideId] || 0) + 1
    }
    return counts
}

// input: { rides (oldest first: start, duration, distance, kj, id), recordCounts, streak
// (Streak.run), journeysDone [{id, date}], journeyId, journeyPercent, challenges
// (Challenge.history), now, miles }
function evaluate(input) {
    var rides = input.rides || []
    var out = []

    out.push(badge("first", qsTr("First ride"), qsTr("Finish your first ride."), 1, 1, "spark",
                   rides.length, 1, nth(rides, 1), "rides"))
    for (var i = 0; i < rideRungs.length; i++) {
        var n = rideRungs[i][0]
        out.push(badge("rides" + n, qsTr("%1 rides").arg(n), qsTr("Finish %1 rides.").arg(n), 7, rideRungs[i][1],
                       "wheel", rides.length, n, nth(rides, n), "rides"))
    }

    var early = rides.filter(function (r) { return new Date(r.start).getHours() < 7 })
    out.push(badge("earlyBird", qsTr("Early bird"), qsTr("Start 5 rides before 7:00 in the morning."), 4, 3, "sun",
                   early.length, 5, nth(early, 5), "rides"))
    var late = rides.filter(function (r) { return new Date(r.start).getHours() >= 21 })
    out.push(badge("nightOwl", qsTr("Night owl"), qsTr("Start 5 rides at 21:00 or later."), 1, 3, "moon",
                   late.length, 5, nth(late, 5), "rides"))

    var longest = 0, farthest = 0, most = 0
    var century = 0, work = 0, twoHours = 0
    var weekCounts = {}
    var busiest = 0, busyDate = 0
    for (var j = 0; j < rides.length; j++) {
        var r = rides[j]
        farthest = Math.max(farthest, r.distance || 0)
        most = Math.max(most, r.kj || 0)
        longest = Math.max(longest, r.duration || 0)
        if (century === 0 && r.distance >= 100)
            century = r.start
        if (work === 0 && r.kj >= 1000)
            work = r.start
        if (twoHours === 0 && r.duration >= 7200)
            twoHours = r.start
        var w = Streak.weekKey(r.start)
        weekCounts[w] = (weekCounts[w] || 0) + 1
        busiest = Math.max(busiest, weekCounts[w])
        if (busyDate === 0 && weekCounts[w] >= 7)
            busyDate = r.start
    }
    out.push(badge("century", input.miles ? qsTr("Metric century") : qsTr("Century"),
                   input.miles ? qsTr("Ride 62 miles in one ride, that is 100 km.") : qsTr("Ride 100 km in one ride."),
                   2, 5, "road", farthest, 100, century, "km"))
    out.push(badge("kj1000", qsTr("1000 kJ"), qsTr("Do 1000 kJ of work in one ride."), 5, 5, "bolt",
                   most, 1000, work, "kJ"))
    out.push(badge("twoHours", qsTr("Two hours"), qsTr("Ride for 2 hours in one ride."), 3, 4, "clock",
                   longest / 3600, 2, twoHours, "h"))
    var weekWords = Format.firstDay === 0 ? qsTr("Ride 7 times in one week, Sunday to Saturday.")
                                          : qsTr("Ride 7 times in one week, Monday to Sunday.")
    out.push(badge("busyWeek", qsTr("Seven in a week"), weekWords, 2, 5, "week", busiest, 7, busyDate, "rides"))

    var streak = input.streak || { best: 0, reached: {} }
    for (var s = 0; s < streakRungs.length; s++) {
        var weeks = streakRungs[s][0]
        out.push(badge("streak" + weeks, qsTr("%1 week streak").arg(weeks),
                       qsTr("Meet your weekly goal %1 weeks in a row. Freezes and rest weeks keep it going.").arg(weeks),
                       5, streakRungs[s][1], "flame", streak.best, weeks, streak.reached[weeks] || 0, "weeks"))
    }

    var counts = input.recordCounts || {}
    var hatTrick = 0, bestCount = 0
    for (var k = hatTrickAfter; k < rides.length; k++) {
        var c = counts[rides[k].id] || 0
        bestCount = Math.max(bestCount, c)
        if (hatTrick === 0 && c >= 3)
            hatTrick = rides[k].start
    }
    out.push(badge("hatTrick", qsTr("Hat-trick"), qsTr("Set 3 new power records in one ride."), 7, 7, "trophy",
                   bestCount, 3, hatTrick, "records"))

    var done = input.journeysDone || []
    for (var q = 0; q < Journeys.journeys.length; q++) {
        var journey = Journeys.journeys[q]
        var date = 0
        for (var d = 0; d < done.length; d++)
            if (done[d].id === journey.id && (date === 0 || done[d].date < date))
                date = Number(done[d].date) || 1
        var have = input.journeyId === journey.id ? (input.journeyPercent || 0) : 0
        out.push(badge("journey-" + journey.id, journey.name,
                       qsTr("Ride the whole journey, %1 to %2.").arg(Journeys.from(journey)).arg(Journeys.to(journey)),
                       journey.tone, journey.ring ? 7 : 4, journey.ring ? "globe" : "route", have, 100, date, "percent"))
    }

    var met = (input.challenges || []).filter(function (m) { return m.met })
    for (var t = 0; t < challengeRungs.length; t++) {
        var months = challengeRungs[t][0]
        out.push(badge("challenge" + months,
                       months === 1 ? qsTr("Challenge met") : qsTr("%1 challenges").arg(months),
                       months === 1 ? qsTr("Finish a monthly challenge.") : qsTr("Finish %1 monthly challenges.").arg(months),
                       3, challengeRungs[t][1], "target", met.length, months, met.length >= months ? met[months - 1].metOn : 0, "months"))
    }
    return out
}

// earned badges, newest first
function earned(list) {
    var out = list.filter(function (b) { return b.earned })
    out.sort(function (a, b) { return b.date - a.date })
    return out
}

// the locked badges closest to being earned, n of them
function next(list, n) {
    var out = list.filter(function (b) { return !b.earned })
    out.sort(function (a, b) { return b.progress - a.progress })
    return out.slice(0, n)
}

function byId(list, id) {
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id)
            return list[i]
    return null
}

// how far a locked badge is, as words: "37 of 50 rides"
function progressText(b, miles) {
    var have = b.have
    if (b.unit === "km") {
        var f = miles ? 0.621371 : 1
        return qsTr("%1 of %2 %3").arg(Math.floor(have * f)).arg(Math.round(b.need * f)).arg(miles ? "mi" : "km")
    }
    if (b.unit === "kJ")
        return qsTr("%1 of %2 kJ").arg(Format.big(Math.floor(have))).arg(Format.big(b.need))
    if (b.unit === "h")
        return qsTr("%1 of %2 h").arg(Format.hours(have * 3600)).arg(b.need)
    if (b.unit === "percent")
        return qsTr("%1% ridden").arg(Math.floor(have))
    var words = { rides: qsTr("rides"), weeks: qsTr("weeks"), records: qsTr("records"), months: qsTr("months") }
    return qsTr("%1 of %2 %3").arg(Math.floor(have)).arg(b.need).arg(words[b.unit] || "")
}
