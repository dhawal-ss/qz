.pragma library

// Small pure helpers of the Progress hub: the period the page shows, hours as h:mm, the 4 week
// average of the volume, the estimated FTP of each month and the words of the insight block.
// Days are worked out at noon: the JavaScript engine of Qt 5 can read local midnight of a DST
// change as 23:00 of the day before, noon is never on the wrong day.

var dayMs = 86400000
var periods = ["4w", "3m", "1y"]
var monthLong = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                 "October", "November", "December"]
var monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

// the period setting, "3m" when it holds anything else
function period(text) {
    return periods.indexOf(text) >= 0 ? text : "3m"
}

// how many days a period shows
function days(p) {
    if (p === "4w")
        return 28
    if (p === "1y")
        return 365
    return 91
}

// how many months the FTP trend shows, the current one included: a few months even for four
// weeks, an estimate per month needs a span to read
function ftpMonths(p) {
    if (p === "1y")
        return 13
    return 5
}

// how many weeks the volume shows
function volumeWeeks(p) {
    return p === "1y" ? 52 : 12
}

function noon(ms) {
    var d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12)
}

// 2:48 for 2 h 48 min
function hm(seconds) {
    var m = Math.round(Math.max(0, seconds || 0) / 60)
    var h = Math.floor(m / 60)
    var rest = m % 60
    return h + ":" + (rest < 10 ? "0" : "") + rest
}

// the average of each value with the n - 1 before it (fewer at the start of the list)
function rolling(values, n) {
    var out = []
    var sum = 0
    for (var i = 0; i < values.length; i++) {
        sum += values[i]
        if (i >= n)
            sum -= values[i - n]
        out.push(sum / Math.min(n, i + 1))
    }
    return out
}

// the first day (noon) of each of the last count months, the current one last
function monthStarts(nowMs, count) {
    var t = new Date(nowMs)
    var out = []
    for (var i = count - 1; i >= 0; i--)
        out.push(new Date(t.getFullYear(), t.getMonth() - i, 1, 12).getTime())
    return out
}

// The estimated FTP of each month: 95% of the best 20 minutes of the 90 days up to the end of
// the month (up to now for the current one), so a month of easy riding does not read as lost
// fitness. best20: the best 20 min watts of each window, 0 when it had no 20 min effort; a month
// without one keeps the estimate before it. Returns [{start, value}], value 0 before the first
// estimate.
function ftpSteps(starts, best20) {
    var out = []
    var last = 0
    for (var i = 0; i < starts.length; i++) {
        if (best20[i] > 0)
            last = Math.round(best20[i] * 0.95)
        out.push({ start: starts[i], value: last })
    }
    return out
}

// the steps that have an estimate, each month that changed it
function ftpChanges(steps) {
    var out = []
    for (var i = 0; i < steps.length; i++) {
        if (steps[i].value <= 0)
            continue
        if (out.length === 0 || out[out.length - 1].value !== steps[i].value)
            out.push(steps[i])
    }
    return out
}

// "since August", "in four weeks", "in a year": the start of the period in words
function since(p, startMs) {
    if (p === "4w")
        return qsTr("in four weeks")
    if (p === "1y")
        return qsTr("in a year")
    return qsTr("since %1").arg(monthLong[new Date(startMs).getMonth()])
}

// The insight of the period from fitness then and now and the form of today (see Fitness.js
// formLabel): a sentence a coach would say and what to do next. Falling fitness is said plainly,
// never as a fault.
function insight(p, startMs, before, now, state) {
    var change = Math.round(now - before)
    var when = since(p, startMs)
    // time off took the fitness there was: say so, and how it comes back
    if (state === "start" && change <= -2)
        return { headline: qsTr("Fitness is down %1 %2. Time off rests the legs.").arg(-change).arg(when),
                 line: qsTr("A few easy rides a week bring it back.") }
    if (state === "start")
        return { headline: qsTr("Fitness shows after a few weeks of riding."),
                 line: qsTr("Three rides a week is a good start.") }
    var first
    if (change >= 2)
        first = qsTr("Fitness is up %1 %2.").arg(change).arg(when)
    else if (change <= -2)
        first = qsTr("Fitness is down %1 %2.").arg(-change).arg(when)
    else
        first = qsTr("Fitness is holding at %1.").arg(Math.round(now))
    var second = {
        veryFresh: qsTr("Well rested, maybe more than you need."),
        fresh: change <= -2 ? qsTr("Rested legs are ready to build again.") : qsTr("Your legs are fresh."),
        steady: qsTr("Training and rest are in balance."),
        building: qsTr("A little fatigue means it is working."),
        overreaching: qsTr("Fatigue is running high.")
    }
    var lines = {
        veryFresh: qsTr("A few harder rides bring fitness back up."),
        fresh: qsTr("A good week for a hard ride or a long one."),
        steady: qsTr("One harder ride this week keeps fitness rising."),
        building: qsTr("An easy spin tomorrow keeps you productive."),
        overreaching: qsTr("Two easy days let the work land.")
    }
    return { headline: first + " " + (second[state] || ""), line: lines[state] || "" }
}

// how hard a day was for the consistency strip, 0 (no ride) to 4, by its training load
function level(tss, seconds) {
    if (!(seconds > 0) && !(tss > 0))
        return 0
    if (tss < 30)
        return 1
    if (tss < 60)
        return 2
    if (tss < 100)
        return 3
    return 4
}
