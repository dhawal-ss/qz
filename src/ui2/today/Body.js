.pragma library

// Readiness from the body (Health Connect, BikemodoHealth.kt): last night's heart rate variability
// (RMSSD), resting heart rate and sleep, each against the rider's own baseline (the mean and spread
// of the 28 days before; 7 days at least). Higher HRV and lower resting heart rate than usual point
// to a body that has recovered; the reverse, or a short night, to one that has not. The answer is a
// plain band with every input shown, never a score made up from what is missing.
// days: [{ day: "2026-11-03", hrv, rhr, sleepMin }] oldest first.

function parse(text) {
    try {
        var o = JSON.parse(text || "")
        return o && typeof o === "object" ? o : null
    } catch (e) {
        return null
    }
}

function stats(values) {
    if (values.length === 0)
        return null
    var sum = 0
    for (var i = 0; i < values.length; i++)
        sum += values[i]
    var mean = sum / values.length
    var sq = 0
    for (var k = 0; k < values.length; k++)
        sq += (values[k] - mean) * (values[k] - mean)
    return { mean: mean, sd: Math.sqrt(sq / Math.max(1, values.length - 1)), n: values.length }
}

function key(ms) {
    var d = new Date(ms)
    var m = d.getMonth() + 1
    var day = d.getDate()
    return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day
}

// { state: "none" | "building" | "good" | "normal" | "easy", words, inputs: [{ name, value, usual, tone }],
//   need } for today. need: days still missing for a baseline while building.
function today(days, now) {
    var todayKey = key(now)
    var last = null
    var before = []
    for (var i = 0; i < days.length; i++) {
        if (days[i].day === todayKey)
            last = days[i]
        else if (days[i].day < todayKey)
            before.push(days[i])
    }
    // the last 28 days before today are the baseline; today's values, or yesterday's for what is not in yet
    before = before.slice(Math.max(0, before.length - 28))
    if (!last && before.length > 0 && before[before.length - 1].day === key(now - 86400000))
        last = before.pop()
    if (!last)
        return { state: "none", words: qsTr("Nothing from last night yet."), inputs: [], need: 0 }

    var hrvBase = stats(before.filter(function (d) { return d.hrv > 0 }).map(function (d) { return d.hrv }))
    var rhrBase = stats(before.filter(function (d) { return d.rhr > 0 }).map(function (d) { return d.rhr }))
    var inputs = []
    var score = 0
    var counted = 0
    var building = 0
    if (last.hrv > 0) {
        var hz = hrvBase && hrvBase.n >= 7 && hrvBase.sd > 0 ? (last.hrv - hrvBase.mean) / hrvBase.sd : null
        if (hz === null)
            building = Math.max(building, 7 - (hrvBase ? hrvBase.n : 0))
        else {
            score += hz
            counted++
        }
        inputs.push({ name: qsTr("HRV"), value: Math.round(last.hrv) + " ms",
                      usual: hrvBase ? qsTr("usual %1").arg(Math.round(hrvBase.mean)) : "", tone: hz === null ? 0 : (hz > 0.5 ? 1 : (hz < -1 ? -1 : 0)) })
    }
    if (last.rhr > 0) {
        var rz = rhrBase && rhrBase.n >= 7 && rhrBase.sd > 0 ? (last.rhr - rhrBase.mean) / rhrBase.sd : null
        if (rz === null)
            building = Math.max(building, 7 - (rhrBase ? rhrBase.n : 0))
        else {
            score -= rz
            counted++
        }
        inputs.push({ name: qsTr("Resting HR"), value: Math.round(last.rhr) + " bpm",
                      usual: rhrBase ? qsTr("usual %1").arg(Math.round(rhrBase.mean)) : "", tone: rz === null ? 0 : (rz < -0.5 ? 1 : (rz > 1 ? -1 : 0)) })
    }
    if (last.sleepMin > 0) {
        var h = last.sleepMin / 60
        var short = h < 6
        if (short) {
            score -= 1
            counted++
        }
        inputs.push({ name: qsTr("Sleep"), value: Math.floor(h) + " h " + Math.round(last.sleepMin % 60) + " min",
                      usual: "", tone: short ? -1 : (h >= 7 ? 1 : 0) })
    }
    if (counted === 0)
        return { state: "building", words: qsTr("Learning what is usual for you: %1 more days.").arg(Math.max(1, building)),
                 inputs: inputs, need: Math.max(1, building) }
    var avg = score / counted
    if (avg <= -0.8)
        return { state: "easy", words: qsTr("Your body says take it easy today."), inputs: inputs, need: 0 }
    if (avg >= 0.5)
        return { state: "good", words: qsTr("Well recovered. A good day for a hard ride."), inputs: inputs, need: 0 }
    return { state: "normal", words: qsTr("About as usual."), inputs: inputs, need: 0 }
}
