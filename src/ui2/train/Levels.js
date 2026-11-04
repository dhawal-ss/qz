.pragma library

// Training levels: one for each kind of workout, from 1 to 10, worked out from the log of workouts
// (ui2/workoutLog, written when a ride with a workout ends): a finished one raises its level by
// half a step, one left before 90% of it lowers it by half. Easy spins, first rides and FTP tests
// do not count. The coach (today/Coach.js) picks how long and how many blocks from them.

var kinds = ["endurance", "tempo", "threshold", "vo2"]

function names() {
    return { endurance: qsTr("Endurance"), tempo: qsTr("Tempo"), threshold: qsTr("Threshold"), vo2: qsTr("VO2 max") }
}

// the kind a workout counts for, from its hardest zone; "" for none
function kindOf(entry) {
    if (!entry || entry.test || entry.id === "first" || entry.id === "recovery" || entry.id === "easy")
        return ""
    var z = entry.zone || 0
    if (z <= 1)
        return ""
    if (z === 2)
        return "endurance"
    if (z === 3)
        return "tempo"
    if (z === 4)
        return "threshold"
    return "vo2"
}

function parse(text) {
    try {
        var list = JSON.parse(text || "[]")
        return Array.isArray(list) ? list : []
    } catch (e) {
        return []
    }
}

// { endurance, tempo, threshold, vo2 } from the log, oldest first; the last 180 days count
function levels(log, now) {
    var out = { endurance: 1, tempo: 1, threshold: 1, vo2: 1 }
    var from = now - 180 * 86400000
    for (var i = 0; i < log.length; i++) {
        var e = log[i]
        if (!e || e.ms < from)
            continue
        var k = kindOf(e)
        if (k === "")
            continue
        out[k] = Math.max(1, Math.min(10, out[k] + (e.finished ? 0.5 : -0.5)))
    }
    return out
}

// the log with one more entry, the last 200 kept
function add(log, entry) {
    var list = log.slice()
    list.push(entry)
    return list.length > 200 ? list.slice(list.length - 200) : list
}
