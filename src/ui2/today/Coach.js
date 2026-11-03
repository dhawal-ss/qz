.pragma library
.import "../Format.js" as Format
.import "../progress/Fitness.js" as Fitness
.import "Insights.js" as Insights
.import "../moments/Moments.js" as Moments

// The coach of Today: how ready the rider is, what a coach would say about it, and a ride to
// suggest. Pure functions of plain data (library.days(), library.rides()), so they can be tested
// without the library.
//
// Ready, 0 to 100, from the form (TSB) of Fitness.js: fitness minus fatigue, worked out from
// the training load of every day. The hero shows the form the rider woke up with, before any
// ride of today, so a ride today does not pull the number down in the middle of the day:
//   ready = 65 + 1.6 * form, kept within 5 and 99
// so the bands of Fitness.formLabel read as
//   fresh        form  5 to 25   ready 73 to 99   "Ready"
//   very fresh   form over 25    ready 99         "Fresh"
//   steady       form -10 to 5   ready 49 to 73   "Steady"
//   building     form -30 to -10 ready 17 to 49   "Building"
//   overreaching form under -30  ready 5 to 17    "Tired"
// Form says nothing yet when there is almost no fitness (under 5, the first weeks): the hero
// then shows the week against the weekly goal instead ("start"), as for a rider with no rides
// ("new"). A week or more without riding also raises the form, but that is rest, not freshness:
// "away" welcomes the rider back with an easy ride whatever the number says.

var dayMs = 86400000
var numberWords = [qsTr("no"), qsTr("one"), qsTr("two"), qsTr("three"), qsTr("four"), qsTr("five"), qsTr("six"), qsTr("seven")]
// the share of FTP each zone is ridden at, to estimate the load of a suggested ride
var zoneIntensity = [0.5, 0.68, 0.83, 0.98, 1.12, 1.3, 1.5]
// a day under this load counts as easy
var easyLoad = 45

function noon(ms) {
    var d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12).getTime()
}

function readyOf(tsb) {
    return Math.max(5, Math.min(99, Math.round(65 + 1.6 * tsb)))
}

function signed(v) {
    var r = Math.round(v)
    return r > 0 ? "+" + r : String(r)
}

function count(n) {
    return n < numberWords.length ? numberWords[n] : String(n)
}

// the days before today, newest first, as easy (or off) or hard: "after two easy days"
function recentDays(series) {
    // series ends with today; look from yesterday back, at most a week
    var off = 0
    var easy = 0
    var hard = 0
    var kind = ""
    for (var i = series.length - 2; i >= 0 && i >= series.length - 8; i--) {
        var load = series[i].tss
        var thisKind = load >= easyLoad ? "hard" : "easy"
        if (kind === "")
            kind = thisKind
        if (thisKind !== kind)
            break
        if (thisKind === "hard")
            hard++
        else {
            easy++
            if (load < 1)
                off++
        }
    }
    if (kind === "hard")
        return hard === 1 ? qsTr("a hard day") : qsTr("%1 hard days").arg(count(hard))
    if (easy === 0)
        return ""
    if (off === easy)
        return easy === 1 ? qsTr("a day off") : qsTr("%1 days off").arg(count(easy))
    return easy === 1 ? qsTr("an easy day") : qsTr("%1 easy days").arg(count(easy))
}

// days: library.days(0, 0); latestStart: start of the newest ride (0 for none); now in ms.
// Returns { state, hasForm, ready, word, tsb, ctl, rodeToday, todaySeconds, away, recent };
// state is new, start, away, veryFresh, fresh, steady, building or overreaching, and hasForm
// says if there is fitness enough to show the form at all.
function readiness(days, latestStart, now) {
    var out = { state: "new", hasForm: false, ready: 0, word: "", tsb: 0, ctl: 0, rodeToday: false, todaySeconds: 0, away: 0, recent: "" }
    if (!days || days.length === 0 || !latestStart)
        return out
    var first = days[0].day
    for (var i = 1; i < days.length; i++)
        first = Math.min(first, days[i].day)
    var series = Fitness.series(days, first, now)
    var today = series[series.length - 1]
    out.tsb = today.tsb
    // fitness of this morning, before any ride of today
    out.ctl = series.length > 1 ? series[series.length - 2].ctl : 0
    out.ready = readyOf(today.tsb)
    for (var j = 0; j < days.length; j++)
        if (noon(days[j].day + 12 * 3600000) === noon(now))
            out.todaySeconds += days[j].seconds || 0
    out.rodeToday = out.todaySeconds > 0
    out.away = Insights.daysBetween(latestStart, now)
    out.recent = recentDays(series)
    // a long break first: after months off the fitness is under 5 again, but the rider is back,
    // not new. The form shows only once there is fitness to read it from.
    var label = Fitness.formLabel(out.ctl, today.tsb)
    out.hasForm = label !== "start"
    if (out.away >= 7)
        out.state = "away"
    else
        out.state = label
    out.word = { veryFresh: qsTr("Fresh"), fresh: qsTr("Ready"), steady: qsTr("Steady"), building: qsTr("Building"),
                 overreaching: qsTr("Tired"), away: qsTr("Rested") }[out.state] || ""
    return out
}

// The coach sentence and the plain line under it.
function words(r) {
    if (r.state === "new")
        return { headline: qsTr("Your first ride starts here."),
                 line: qsTr("Ride once and Today fills in with your form, your week and your records.") }
    if (r.state === "start")
        return { headline: qsTr("Every ride builds the base."),
                 line: qsTr("Your form shows after a few weeks of riding. Until then, here is your week.") }
    if (r.state === "away")
        return { headline: qsTr("Welcome back."),
                 line: r.away === 1 ? qsTr("A day since your last ride.")
                                    : qsTr("%1 days since your last ride. Ease back in, the legs remember.").arg(r.away) }
    var form = signed(r.tsb)
    if (r.rodeToday)
        return { headline: qsTr("Nicely ridden today."),
                 line: qsTr("Your form was %1 this morning, then you rode %2.").arg(form).arg(Format.hours(r.todaySeconds)) }
    var headlines = {
        veryFresh: qsTr("Fresh legs. Time to test them."),
        fresh: qsTr("A good day to go hard."),
        steady: qsTr("A good day for a steady ride."),
        building: qsTr("Easy does it today."),
        overreaching: qsTr("Rest is training too.")
    }
    var line = r.recent !== "" ? qsTr("Your form is %1 after %2.").arg(form).arg(r.recent)
                               : qsTr("Your form is %1.").arg(form)
    if (r.state === "overreaching")
        line += " " + qsTr("A spin or a day off lets the work land.")
    return { headline: headlines[r.state] || "", line: line }
}

// a ride in blocks of [minutes, zone], with its name and what it holds
function plan(id, name, detail, blocks) {
    var minutes = 0
    var load = 0
    for (var i = 0; i < blocks.length; i++) {
        minutes += blocks[i][0]
        load += blocks[i][0] / 60 * Math.pow(zoneIntensity[blocks[i][1] - 1], 2) * 100
    }
    var top = 1
    for (var j = 0; j < blocks.length; j++)
        top = Math.max(top, blocks[j][1])
    return { id: id, name: name, detail: detail, blocks: blocks, minutes: Math.round(minutes), tss: Math.round(load), zone: top }
}

function repeats(count, work, zone, rest) {
    var out = []
    for (var i = 0; i < count; i++) {
        out.push([work, zone])
        if (i < count - 1)
            out.push([rest, 1])
    }
    return out
}

function easySpin() {
    return plan("easy", qsTr("Easy spin"), qsTr("Light pedaling, all endurance"), [[5, 1], [20, 2], [5, 1]])
}

// A free ride to suggest from the readiness, and the one to swap it for. reach is
// Insights.reach() (a record the latest ride came close to) or null; effortName names its length.
function suggest(r, reach, effortName) {
    var main
    if (r.state === "new" || r.state === "start")
        main = plan("first", qsTr("Easy 20"), qsTr("Find your rhythm, nothing hard"), [[5, 1], [10, 2], [5, 1]])
    else if (r.state === "away" || r.state === "overreaching" || r.rodeToday)
        main = plan("recovery", qsTr("Recovery spin"), qsTr("Easy pedaling, legs only"), [[5, 1], [15, 1], [5, 1]])
    else if ((r.state === "fresh" || r.state === "veryFresh") && reach)
        main = plan("record", qsTr("Go for your %1 best").arg(effortName),
                    qsTr("%1 at %2 W beats it").arg(effortName).arg(reach.target),
                    [[12, 2], [3, 3], [4, 1], [Math.max(1, reach.seconds / 60), Moments.recordTone(reach.seconds)], [8, 1], [10, 2]])
    else if (r.state === "veryFresh")
        main = plan("vo2", qsTr("VO2 builder 4x4"), qsTr("4 blocks at VO2 max"), [[12, 2]].concat(repeats(4, 4, 5, 4)).concat([[10, 2]]))
    else if (r.state === "fresh")
        main = plan("threshold", qsTr("Threshold 3x8"), qsTr("3 blocks at threshold"), [[12, 2]].concat(repeats(3, 8, 4, 4)).concat([[10, 2]]))
    else if (r.state === "steady")
        main = plan("tempo", qsTr("Tempo 2x15"), qsTr("2 blocks at tempo"), [[10, 2]].concat(repeats(2, 15, 3, 5)).concat([[10, 2]]))
    else
        main = plan("endurance", qsTr("Endurance 45"), qsTr("Steady endurance, easy to hold"), [[5, 1], [35, 2], [5, 1]])
    var other
    if (main.zone <= 2)
        other = plan("longer", qsTr("Endurance 60"), qsTr("A longer steady ride"), [[5, 1], [50, 2], [5, 1]])
    else
        other = easySpin()
    return { main: main, other: other, otherLabel: main.zone <= 2 ? qsTr("Swap for a longer ride") : qsTr("Swap for an easy spin") }
}

// This week as Pulse shapes: [{ zone, today }] from the first day of the week (Monday, or Sunday:
// Format.firstDay). zone is the zone the most time of
// the day was ridden in (from each ride's intensity), 0 for no ride. rides: newest first.
function weekDays(rides, now) {
    var monday = Format.weekStart(now)
    var seconds = []
    for (var d = 0; d < 7; d++)
        seconds.push([0, 0, 0, 0, 0, 0, 0])
    var ridden = [false, false, false, false, false, false, false]
    for (var i = 0; i < rides.length; i++) {
        if (rides[i].start < monday)
            break
        var slot = Insights.daysBetween(monday, rides[i].start)
        if (slot < 0 || slot > 6)
            continue
        // a ride without power counts as endurance
        var zone = rides[i].intensity > 0 ? Insights.zoneOfIntensity(rides[i].intensity) : 2
        seconds[slot][zone - 1] += Math.max(1, rides[i].duration || 0)
        ridden[slot] = true
    }
    var todaySlot = Insights.daysBetween(monday, now)
    var out = []
    for (var k = 0; k < 7; k++) {
        var top = 0
        for (var z = 1; z < 7; z++)
            if (seconds[k][z] > seconds[k][top])
                top = z
        out.push({ zone: ridden[k] ? top + 1 : 0, today: k === todaySlot })
    }
    return out
}

// "3 of 4 rides", "84 of 120 min": the week against the weekly goal
function goalText(value, goal, kind, miles) {
    if (kind === "rides")
        return goal === 1 ? qsTr("%1 of 1 ride").arg(Math.round(value)) : qsTr("%1 of %2 rides").arg(Math.round(value)).arg(Math.round(goal))
    if (kind === "kj")
        return qsTr("%1 of %2 kJ").arg(Format.big(value)).arg(Format.big(goal))
    if (kind === "km") {
        var f = miles ? 0.621371 : 1
        return qsTr("%1 of %2 %3").arg(Math.round(value * f)).arg(Math.round(goal * f)).arg(miles ? "mi" : "km")
    }
    return qsTr("%1 of %2 min").arg(Math.round(value)).arg(Math.round(goal))
}

// the hero for a rider without form yet: the week in the unit of the goal, and its word
function weekHero(value, goal, kind, miles) {
    if (kind === "rides")
        return { value: String(Math.round(value)), word: Math.round(goal) === 1 ? qsTr("of 1 ride") : qsTr("of %1 rides").arg(Math.round(goal)) }
    if (kind === "kj")
        return { value: Format.big(value), word: qsTr("of %1 kJ").arg(Format.big(goal)) }
    if (kind === "km") {
        var f = miles ? 0.621371 : 1
        return { value: String(Math.round(value * f)), word: qsTr("of %1 %2").arg(Math.round(goal * f)).arg(miles ? "mi" : "km") }
    }
    return { value: String(Math.round(value)), word: qsTr("of %1 min").arg(Math.round(goal)) }
}
