.pragma library
.import "../Metrics.js" as Metrics

// What the share card of a ride shows (moments/ShareCard.qml), the same from the end of a ride
// (RideSummary) and from a ride in Rides (RideDetail): the fingerprint bars, the numbers, and what
// the ride achieved. Pure functions of plain data, so they can be tested without the library.

var maxBars = 120

// the minutes one bar stands for: one a minute, a few for rides over two hours
function minutesPerBar(seconds) {
    var minutes = Math.max(1, Math.round((seconds || 0) / 60))
    return Math.max(1, Math.round(minutes / Math.min(maxBars, minutes)))
}

// the number of bars of a ride
function barCount(seconds) {
    return Math.min(maxBars, Math.max(1, Math.round((seconds || 0) / 60)))
}

// the bars from power, already one value a bar: [{ watts, zone }]; zone 0 (the card's tint)
// until the rider has set an FTP
function bars(power, ftp, ftpSet, zoneOf) {
    return power.map(function (w) { return { watts: w, zone: ftp > 0 && ftpSet ? zoneOf(w, ftp) : 0 } })
}

// Bars from the zones the ride screen kept, one each 30 s, for the moment before the saved ride
// is read: as many bars as the ride has minutes, each the highest zone of its time, as long as
// its zone. Without an FTP they all take the tint.
function zoneBars(zones, seconds, ftpSet) {
    var count = barCount(seconds)
    var out = []
    if (!zones || zones.length === 0)
        return out
    for (var b = 0; b < count; b++) {
        var from = Math.floor(b * zones.length / count)
        var to = Math.max(from + 1, Math.floor((b + 1) * zones.length / count))
        var top = 0
        for (var i = from; i < Math.min(zones.length, to); i++)
            top = Math.max(top, Number(zones[i]) || 0)
        if (from < zones.length)
            out.push({ watts: top, zone: ftpSet ? top : 0 })
    }
    return out
}

// The numbers of the card, two rows of three: time, distance, average power, then calories,
// training load and work. ride is { elapsed, distance (in the rider's unit), miles, avgPower,
// calories, tss, kilojoules, powerEstimated }. Training load needs the rider's FTP: without it,
// work takes its place. Numbers worked out from estimated power say "est.".
function numbers(ride, ftpSet) {
    var est = ride.powerEstimated === true
    var out = [
        { label: qsTr("Time"), value: Metrics.clock(ride.elapsed || 0), unit: "", est: false },
        { label: qsTr("Distance"), value: (ride.distance || 0).toFixed(1), unit: ride.miles ? "mi" : "km", est: false },
        { label: qsTr("Avg power"), value: Metrics.whole(ride.avgPower), unit: "W", est: est },
        // calories always come from a formula
        { label: qsTr("Calories"), value: Metrics.whole(ride.calories), unit: "kcal", est: true }
    ]
    if (ftpSet)
        out.push({ label: qsTr("Load"), value: Metrics.whole(ride.tss), unit: "", est: true })
    else
        out.push({ label: qsTr("Work"), value: Metrics.whole(ride.kilojoules), unit: "kJ", est: est })
    return out
}

// What the ride achieved, for the lit lines of the card, at most two, biggest first: a new
// power best, the weekly goal met or a week closed, the longest ride, the first ride.
// moments are those of Moments.js (moments.recordMoments, moments.detect), biggest first.
function achievements(moments) {
    var proud = ["record", "records", "goal", "streak", "longest", "first"]
    var out = []
    for (var i = 0; i < moments.length && out.length < 2; i++) {
        var m = moments[i]
        if (proud.indexOf(m.kind) < 0)
            continue
        var line = m.title
        if (m.kind === "record")
            line = qsTr("%1, %2 W").arg(m.title).arg(m.value)
        else if (m.kind === "records")
            line = qsTr("%1 more new %2").arg(m.value).arg(m.unit)
        else if (m.kind === "streak")
            line = qsTr("Weekly goal met, %1 weeks in a row").arg(m.value)
        out.push({ text: line, tone: m.tone || 1, kind: m.kind })
    }
    return out
}
