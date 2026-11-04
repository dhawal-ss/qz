.pragma library
.import "../Format.js" as Format
.import "../moments/Moments.js" as Moments

// What a ride analysis says about one ride: its best stretch, how it held up aerobically, the
// coach headline with its hero number, what changed against similar rides before it, its work
// blocks, and the totals of a month of rides. Pure functions of plain data (library.ride(),
// library.samples(), library.rides(), library.powerCurve()), so they can be tested alone.

var dayMs = 86400000

// spelled out for a headline: "Your strongest five minutes yet."
var effortWordList = [
                      [5, QT_TR_NOOP("five seconds")],
                      [10, QT_TR_NOOP("ten seconds")],
                      [15, QT_TR_NOOP("fifteen seconds")],
                      [20, QT_TR_NOOP("twenty seconds")],
                      [30, QT_TR_NOOP("thirty seconds")],
                      [45, QT_TR_NOOP("forty-five seconds")],
                      [60, QT_TR_NOOP("minute")],
                      [90, QT_TR_NOOP("ninety seconds")],
                      [120, QT_TR_NOOP("two minutes")],
                      [180, QT_TR_NOOP("three minutes")],
                      [240, QT_TR_NOOP("four minutes")],
                      [300, QT_TR_NOOP("five minutes")],
                      [420, QT_TR_NOOP("seven minutes")],
                      [600, QT_TR_NOOP("ten minutes")],
                      [900, QT_TR_NOOP("fifteen minutes")],
                      [1200, QT_TR_NOOP("twenty minutes")],
                      [1800, QT_TR_NOOP("half hour")],
                      [2700, QT_TR_NOOP("forty-five minutes")],
                      [3600, QT_TR_NOOP("hour")],
                      [5400, QT_TR_NOOP("ninety minutes")],
                      [7200, QT_TR_NOOP("two hours")]]

function effortWords(seconds) {
    for (var i = 0; i < effortWordList.length; i++)
        if (effortWordList[i][0] === seconds)
            return qsTr(effortWordList[i][1])
    return Format.effort(seconds)
}

// "5 minute best", "30 second best", "1 hour best"
function effortLabel(seconds) {
    if (seconds < 60)
        return qsTr("%1 second best").arg(seconds)
    if (seconds < 3600)
        return qsTr("%1 minute best").arg(Math.round(seconds / 60))
    var hours = seconds / 3600
    return hours === 1 ? qsTr("1 hour best") : qsTr("%1 hour best").arg(hours)
}

// 45:12 under an hour, 1:34 h above: short enough for a row
function shortDuration(seconds) {
    var s = Math.max(0, Math.round(seconds || 0))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    if (h > 0)
        return h + ":" + (m < 10 ? "0" : "") + m + " h"
    var r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
}

// the zone a ride counts in, from its intensity, as Today's week does (a ride without power
// counts as endurance)
var intensityStarts = [0.555, 0.755, 0.905, 1.055, 1.205, 1.505]
function rideZone(intensity) {
    if (!(intensity > 0))
        return 2
    var zone = 1
    for (var i = 0; i < intensityStarts.length; i++)
        if (intensity >= intensityStarts[i])
            zone = i + 2
    return zone
}

function wattsAt(list, seconds) {
    return Moments.wattsAt(list || [], seconds)
}

// The strongest stretch of n samples of the power: { from, to (sample indexes, inclusive),
// watts, start, end (ride seconds) }, or null when the ride is shorter.
function bestWindow(samples, n) {
    var power = samples.power || []
    var seconds = samples.seconds || []
    if (n < 1 || power.length < n)
        return null
    var run = 0
    var top = -1
    var at = 0
    for (var i = 0; i < power.length; i++) {
        run += power[i] || 0
        if (i >= n)
            run -= power[i - n] || 0
        if (i >= n - 1 && run > top) {
            top = run
            at = i - n + 1
        }
    }
    var to = at + n - 1
    return { from: at, to: to, watts: top / n, start: seconds[at] !== undefined ? seconds[at] : at,
             end: seconds[to] !== undefined ? seconds[to] : to }
}

// normalized power of a list of 1 Hz watts: the 30 s rolling average to the fourth power
function normalized(power) {
    if (!power || power.length < 30)
        return 0
    var run = 0
    var sum = 0
    var count = 0
    for (var i = 0; i < power.length; i++) {
        run += power[i] || 0
        if (i >= 30)
            run -= power[i - 30] || 0
        if (i >= 29) {
            sum += Math.pow(run / 30, 4)
            count++
        }
    }
    return count > 0 ? Math.pow(sum / count, 0.25) : 0
}

// Aerobic durability from the samples where the rider pedaled with a heart rate: the power to
// heart rate of the first half against the second (decoupling, %), and the efficiency factor
// (normalized power over average heart rate). The first 10 minutes (the warm up, while heart
// rate catches up) stay out. Needs 20 minutes after that.
function durability(samples) {
    var power = samples.power || []
    var heart = samples.heart || []
    var p = []
    var h = []
    for (var i = 600; i < Math.min(power.length, heart.length); i++) {
        if (power[i] > 0 && heart[i] > 0) {
            p.push(power[i])
            h.push(heart[i])
        }
    }
    if (p.length < 1200)
        return null
    var half = Math.floor(p.length / 2)
    var p1 = 0, h1 = 0, p2 = 0, h2 = 0
    for (var k = 0; k < p.length; k++) {
        if (k < half) {
            p1 += p[k]
            h1 += h[k]
        } else {
            p2 += p[k]
            h2 += h[k]
        }
    }
    var first = p1 / Math.max(1, h1)
    var second = p2 / Math.max(1, h2)
    var heartSum = h1 + h2
    return {
        decoupling: first > 0 ? (first - second) / first * 100 : 0,
        ef: normalized(p) / Math.max(1, heartSum / p.length)
    }
}

// what the decoupling says, in one line
function durabilityWords(decoupling) {
    if (decoupling < 0)
        return qsTr("Heart rate held steady while power rose. Common when the hard part comes late.")
    if (decoupling < 5)
        return qsTr("Under 5% drift means a solid aerobic base.")
    if (decoupling < 8)
        return qsTr("Some drift late in the ride. More long easy miles bring it down.")
    return qsTr("Heart rate drifted up a lot. Heat, fatigue or a pace above your aerobic base can do that.")
}

// how evenly the rider pedaled: the spread (standard deviation) of cadence while pedaling
function cadenceSpread(samples) {
    var cadence = samples.cadence || []
    var power = samples.power || []
    var sum = 0
    var squares = 0
    var n = 0
    for (var i = 0; i < cadence.length; i++) {
        var c = cadence[i]
        if (!(c > 20) || (power.length > i && !(power[i] > 0)))
            continue
        sum += c
        squares += c * c
        n++
    }
    if (n < 300)
        return 0
    var mean = sum / n
    return Math.sqrt(Math.max(0, squares / n - mean * mean))
}

// The most recent ride before this one that is like it: within six weeks, about as long and,
// when both have power, about as hard. rides: newest first.
function similarRide(ride, rides) {
    for (var i = 0; i < rides.length; i++) {
        var r = rides[i]
        if (r.id === ride.id || r.start >= ride.start)
            continue
        if (ride.start - r.start > 42 * dayMs)
            break
        if (Math.abs(r.duration - ride.duration) > ride.duration * 0.35)
            continue
        if (ride.intensity > 0 && r.intensity > 0 && Math.abs(r.intensity - ride.intensity) > 0.08)
            continue
        return r
    }
    return null
}

// "yesterday", "last week", "two weeks ago" for a ride of the last week; "on 14 Oct" before
function whenWords(then, ride, now) {
    var back = Math.round((Format.startOfDay(ride.start) - Format.startOfDay(then)) / dayMs)
    var recent = now - ride.start < 7 * dayMs
    if (recent) {
        var days = Math.round((Format.startOfDay(now) - Format.startOfDay(then)) / dayMs)
        if (days <= 1)
            return qsTr("yesterday")
        if (days < 7)
            return qsTr("%1 days ago").arg(days)
        if (days < 14)
            return qsTr("last week")
        if (days < 21)
            return qsTr("two weeks ago")
        if (days < 28)
            return qsTr("three weeks ago")
        return qsTr("%1 weeks ago").arg(Math.round(days / 7))
    }
    if (back === 1)
        return qsTr("the day before")
    var d = new Date(then)
    return qsTr("on %1 %2").arg(d.getDate()).arg(Format.monthShort[d.getMonth()])
}

// Plain sentences against the similar ride: heart rate at the same watts, more watts at the
// same heart rate, a steadier cadence, a longer ride. At most three, each { icon, text }.
function changes(ride, similar, spread, similarSpread, now) {
    var out = []
    if (!similar)
        return out
    var when = whenWords(similar.start, ride, now)
    if (ride.avgPower > 0 && similar.avgPower > 0) {
        var dp = (ride.avgPower - similar.avgPower) / similar.avgPower
        var watts = Math.round(Math.abs(ride.avgPower - similar.avgPower))
        var hasHeart = ride.avgHr > 0 && similar.avgHr > 0
        var dh = hasHeart ? Math.round(ride.avgHr - similar.avgHr) : 0
        if (Math.abs(dp) <= 0.04 && hasHeart && dh <= -3)
            out.push({ icon: "heart", text: qsTr("Same watts as %1 at %2 bpm lower heart rate.").arg(when).arg(-dh) })
        else if (Math.abs(dp) <= 0.04 && hasHeart && dh >= 3)
            out.push({ icon: "heart", text: qsTr("Same watts as %1, heart rate %2 bpm higher. Fatigue or heat can do that.").arg(when).arg(dh) })
        else if (dp > 0.04 && hasHeart && Math.abs(dh) <= 3)
            out.push({ icon: "bolt", text: qsTr("%1 W more than %2 at the same heart rate.").arg(watts).arg(when) })
        else if (dp > 0.04)
            out.push({ icon: "bolt", text: qsTr("%1 W more on average than %2.").arg(watts).arg(when) })
        else if (dp < -0.04)
            out.push({ icon: "bolt", text: qsTr("An easier ride than %1, %2 W less on average.").arg(when).arg(watts) })
    }
    if (spread > 0 && similarSpread > 0) {
        var a = Math.round(spread)
        var b = Math.round(similarSpread)
        if (b - a >= 1)
            out.push({ icon: "cadence", text: qsTr("Cadence steadier than %1, %2 vs %3 rpm spread.").arg(when).arg(a).arg(b) })
        else if (a - b >= 1)
            out.push({ icon: "cadence", text: qsTr("Cadence less even than %1, %2 vs %3 rpm spread.").arg(when).arg(a).arg(b) })
    }
    if (out.length < 2 && ride.duration > similar.duration * 1.15)
        out.push({ icon: "clock", text: qsTr("%1 min longer than %2.").arg(Math.round((ride.duration - similar.duration) / 60)).arg(when) })
    return out.slice(0, 3)
}

// minutes as the hero shows them: 92 min, or 1:32 h from 100 minutes
function minutesHero(seconds) {
    var minutes = Math.round(seconds / 60)
    if (minutes < 100)
        return { value: String(minutes), unit: qsTr("min") }
    var h = Math.floor(minutes / 60)
    var m = minutes % 60
    return { value: h + ":" + (m < 10 ? "0" : "") + m, unit: qsTr("h") }
}

// The coach headline of a ride and its hero number: the record it set, else the most notable
// thing about it. input:
//   ride          library.ride(): best, records, duration, kj, avgPower, np, intensity, start
//   before        library.powerCurve(0, ride.start): every ride before it
//   prior90       library.powerCurve(ride.start - 90 days, ride.start)
//   month         the rides of the same month (library.rides() rows), this one too
//   spread, similarSpread   cadence spread of this ride and of the similar ride before it
//   ftp
// Returns { sentence, value, unit, label, sub, zone, seconds (the effort, 0 for none), power }.
// zone is the power zone of the number, 0 when it has no zone (the screen keeps the ride's).
function headline(input) {
    var ride = input.ride
    var best = ride.best || []
    var ftp = input.ftp > 0 ? input.ftp : 0

    function recordHero(hero) {
        hero.record = true
        return hero
    }
    function effortHero(seconds, watts, previous, sentence, sub) {
        return { sentence: sentence, value: String(Math.round(watts)), unit: "W", label: effortLabel(seconds),
                 sub: sub, zone: ftp > 0 ? powerZone(watts, ftp) : 0, seconds: seconds, power: true }
    }

    // a record: the biggest gain on the best before it, 5 s and longer
    var records = ride.records || []
    var pick = null
    for (var i = 0; i < records.length; i++) {
        var s = records[i]
        var w = wattsAt(best, s)
        var p = wattsAt(input.before, s)
        if (s < 5 || w <= 0 || p <= 0 || w <= p)
            continue
        var gain = (w - p) / p
        if (pick === null || gain > pick.gain)
            pick = { seconds: s, watts: w, previous: p, gain: gain }
    }
    if (pick !== null)
        return recordHero(effortHero(pick.seconds, pick.watts, pick.previous,
                          qsTr("Your strongest %1 yet.").arg(effortWords(pick.seconds)),
                          qsTr("Previous %1, up %2").arg(Math.round(pick.previous)).arg(Math.round(pick.watts) - Math.round(pick.previous))))

    // the best of the last 90 days, a minute or longer
    var top90 = null
    for (var k = 0; k < best.length; k++) {
        var sec = best[k].seconds
        var prior = wattsAt(input.prior90, sec)
        if (sec < 60 || prior <= 0 || best[k].watts <= prior)
            continue
        var g = (best[k].watts - prior) / prior
        if (top90 === null || g > top90.gain)
            top90 = { seconds: sec, watts: best[k].watts, previous: prior, gain: g }
    }
    if (top90 !== null)
        return effortHero(top90.seconds, top90.watts, top90.previous,
                          qsTr("Your best %1 in 90 days.").arg(effortWords(top90.seconds)),
                          qsTr("90-day best %1, up %2").arg(Math.round(top90.previous)).arg(Math.round(top90.watts) - Math.round(top90.previous)))

    // the biggest of the month, among three rides or more
    var month = input.month || []
    var thisMonth = Format.monthKey(ride.start) === Format.monthKey(input.now || Date.now())
    var monthName = Format.monthNames[new Date(ride.start).getMonth()]
    if (month.length >= 3) {
        var longest = 0
        var most = 0
        for (var m = 0; m < month.length; m++) {
            if (month[m].id === ride.id)
                continue
            longest = Math.max(longest, month[m].duration || 0)
            most = Math.max(most, month[m].kj || 0)
        }
        if (ride.duration > longest) {
            var shown = minutesHero(ride.duration)
            var next = minutesHero(longest)
            return { sentence: thisMonth ? qsTr("Your longest ride this month.") : qsTr("Your longest ride of %1.").arg(monthName), value: shown.value, unit: shown.unit,
                     label: qsTr("Ride time"), sub: qsTr("Next longest %1 %2").arg(next.value).arg(next.unit),
                     zone: 0, seconds: 0, power: false }
        }
        if (ride.kj > most && most > 0)
            return { sentence: thisMonth ? qsTr("The most work you have done this month.") : qsTr("Your biggest day of work in %1.").arg(monthName), value: String(Math.round(ride.kj)), unit: "kJ",
                     label: qsTr("Work"), sub: qsTr("Next most %1 kJ").arg(Math.round(most)), zone: 0, seconds: 0, power: true }
    }

    // pedaling smoother than the ride like it before
    if (input.spread > 0 && input.similarSpread > 0 && input.similarSpread - input.spread >= 1.5)
        return { sentence: qsTr("Smooth, even pedaling today."), value: input.spread.toFixed(1), unit: "rpm",
                 label: qsTr("Cadence spread"), sub: qsTr("Similar ride before %1 rpm").arg(input.similarSpread.toFixed(1)),
                 zone: 0, seconds: 0, power: false }

    // what kind of ride it was
    if (ride.np > 0 || ride.avgPower > 0) {
        var zone = rideZone(ride.intensity)
        var words = [qsTr("An easy spin. Recovery counts too."), qsTr("Steady endurance in the bank."),
                     qsTr("A solid tempo ride."), qsTr("Right at threshold. Hard work."),
                     qsTr("You went deep today."), qsTr("You went deep today."), qsTr("All out. Well done.")]
        var useNp = ride.np > 0
        // how hard it was comes from FTP: with no FTP of the rider's own (input.ftpSet false) no
        // effort is named
        return { sentence: input.ftpSet === false ? qsTr("Watts in the bank.") : words[zone - 1], value: String(Math.round(useNp ? ride.np : ride.avgPower)), unit: "W",
                 label: useNp ? qsTr("Normalized power") : qsTr("Average power"),
                 sub: useNp && ride.avgPower > 0 ? qsTr("Average %1 W").arg(Math.round(ride.avgPower)) : "",
                 zone: 0, seconds: 0, power: true }
    }
    var time = minutesHero(ride.duration || 0)
    return { sentence: qsTr("Time on the bike, well spent."), value: time.value, unit: time.unit, label: qsTr("Ride time"),
             sub: "", zone: 0, seconds: 0, power: false }
}

// the zone of a watts value, as Theme.powerZone
function powerZone(watts, ftp) {
    var zone = 1
    for (var i = 0; i < intensityStarts.length; i++)
        if (watts >= Math.round(ftp * intensityStarts[i]))
            zone = i + 2
    return zone
}

// The laps as work blocks: when some laps are clearly harder (a minute or more, well over the
// ride average), only those, named Block 1, 2...; else every lap. Each block has its change
// from the one before; the strongest is marked. { blocks: [{ index, name, duration, hr, watts,
// delta, first, best }], work: bool }
function workBlocks(laps, avgPower, ftp) {
    var out = { blocks: [], work: false }
    if (!laps || laps.length < 2)
        return out
    var line = Math.max(avgPower * 1.05, ftp > 0 ? ftp * 0.85 : 0)
    var hard = []
    for (var i = 0; i < laps.length; i++)
        if (laps[i].duration >= 60 && laps[i].avgPower >= line)
            hard.push(i)
    var picked = []
    if (hard.length >= 2 && hard.length < laps.length) {
        picked = hard
        out.work = true
    } else {
        for (var k = 0; k < laps.length; k++)
            picked.push(k)
    }
    var strongest = -1
    for (var j = 0; j < picked.length; j++) {
        var lap = laps[picked[j]]
        if (strongest < 0 || (lap.duration >= 60 && lap.avgPower > laps[picked[strongest]].avgPower))
            strongest = j
    }
    for (var n = 0; n < picked.length; n++) {
        var l = laps[picked[n]]
        var before = n > 0 ? laps[picked[n - 1]] : null
        out.blocks.push({
            index: picked[n],
            name: out.work ? qsTr("Block %1").arg(n + 1) : qsTr("Lap %1").arg(n + 1),
            duration: l.duration, hr: l.avgHr || 0, watts: l.avgPower || 0,
            delta: before ? Math.round(l.avgPower) - Math.round(before.avgPower) : 0,
            first: n === 0, best: n === strongest && picked.length > 1
        })
    }
    return out
}

// rides, seconds and kJ of every month, keyed by Format.month() as the list sections are
function monthTotals(rides) {
    var out = {}
    for (var i = 0; i < rides.length; i++) {
        var key = Format.month(rides[i].start)
        var t = out[key] || { rides: 0, seconds: 0, kj: 0, distance: 0 }
        t.rides++
        t.seconds += rides[i].duration || 0
        t.kj += rides[i].kj || 0
        t.distance += rides[i].distance || 0
        out[key] = t
    }
    return out
}

// a list cut into count equal parts, each its average
function buckets(values, count) {
    var out = []
    if (!values || values.length === 0 || count < 1)
        return out
    var per = values.length / count
    for (var i = 0; i < count; i++) {
        var from = Math.floor(i * per)
        var to = Math.max(from + 1, Math.floor((i + 1) * per))
        var sum = 0
        for (var k = from; k < Math.min(values.length, to); k++)
            sum += values[k] || 0
        out.push(sum / Math.max(1, Math.min(values.length, to) - from))
    }
    return out
}

// the rides of the calendar month of a ride (rides: newest first)
function sameMonth(rides, ride) {
    var key = Format.monthKey(ride.start)
    var out = []
    for (var i = 0; i < rides.length; i++)
        if (Format.monthKey(rides[i].start) === key)
            out.push(rides[i])
    return out
}
