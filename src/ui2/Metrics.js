.pragma library

// Every metric the ride screen can show. `m` is a ride source (LiveSource or RideSim).
// tag: a quiet note after the label. Watts and everything made from watts are estimates on a
// bike that computes power from level and cadence, speed and distance are virtual.

var order = ["power", "heart", "cadence", "np", "tss", "kcal", "time", "dist", "level", "avgpower", "kj", "speed"]

function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var sec = s % 60
    var mm = (h > 0 && m < 10) ? "0" + m : "" + m
    var ss = sec < 10 ? "0" + sec : "" + sec
    return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
}

function whole(v) {
    return (v === undefined || v === null || isNaN(v)) ? "0" : "" + Math.round(v)
}

function powerTag(m) {
    return m.powerEstimated ? qsTr("est.") : ""
}

function info(id, m) {
    switch (id) {
    case "power":
        return { label: qsTr("Power"), value: whole(m.power), unit: "W", tag: powerTag(m),
                 frac: m.power / (m.ftp * 1.5), trail: "powerTrail" }
    case "heart":
        return { label: qsTr("Heart rate"), value: m.heartRate > 0 ? whole(m.heartRate) : "--", unit: "bpm",
                 tag: m.heartSource, frac: m.heartRate / m.maxHeartRate, trail: "heartTrail" }
    case "cadence":
        return { label: qsTr("Cadence"), value: whole(m.cadence), unit: "rpm", tag: "",
                 frac: m.cadence / 120, trail: "cadenceTrail" }
    case "np":
        return { label: qsTr("Live NP"), value: whole(m.normalizedPower), unit: "W", tag: powerTag(m),
                 frac: m.normalizedPower / (m.ftp * 1.5), trail: "powerTrail" }
    case "tss":
        // a dash while FTP is still a guess (LiveSource.ftpSet)
        return { label: qsTr("TSS so far"), value: m.ftpSet === false ? "–" : whole(m.tss), unit: "", tag: powerTag(m),
                 frac: m.tss / 100, trail: "powerTrail" }
    case "kcal":
        return { label: qsTr("Calories"), value: whole(m.calories), unit: "kcal", tag: powerTag(m),
                 frac: m.calories / 800, trail: "powerTrail" }
    case "time":
        return { label: qsTr("Ride time"), value: clock(m.elapsed), unit: "",
                 tag: m.plannedSeconds > 0 ? qsTr("of %1").arg(clock(m.plannedSeconds)) : "",
                 frac: m.plannedSeconds > 0 ? m.elapsed / m.plannedSeconds : (m.elapsed % 3600) / 3600,
                 trail: "cadenceTrail" }
    case "dist":
        return { label: qsTr("Distance"), value: m.distance.toFixed(1), unit: m.miles ? "mi" : "km",
                 tag: qsTr("virtual"), frac: m.distance / 40, trail: "powerTrail" }
    case "level":
        return { label: qsTr("Level"), value: whole(m.level), unit: qsTr("of %1").arg(m.levelMax), tag: "",
                 frac: m.level / m.levelMax, trail: "cadenceTrail" }
    case "avgpower":
        return { label: qsTr("Average power"), value: whole(m.avgPower), unit: "W", tag: powerTag(m),
                 frac: m.avgPower / (m.ftp * 1.5), trail: "powerTrail" }
    case "kj":
        return { label: qsTr("Work"), value: whole(m.kilojoules), unit: "kJ", tag: powerTag(m),
                 frac: m.kilojoules / 800, trail: "powerTrail" }
    case "speed":
        return { label: qsTr("Speed"), value: m.speed.toFixed(1), unit: m.miles ? "mph" : "km/h",
                 tag: qsTr("virtual"), frac: m.speed / 50, trail: "cadenceTrail" }
    }
    return { label: "", value: "", unit: "", tag: "", frac: 0, trail: "" }
}

// Ride screen layouts: the first slot is the big number, the others are rows.
// style is "number", "trend" or "bar". "empty" keeps a space free.
var presets = {
    power: [["power", "number"], ["cadence", "number"], ["heart", "number"], ["np", "number"], ["kcal", "number"]],
    simple: [["time", "number"], ["kcal", "bar"], ["dist", "number"], ["cadence", "number"], ["heart", "trend"]],
    heart: [["heart", "number"], ["power", "bar"], ["cadence", "trend"], ["time", "number"], ["kcal", "number"]],
    // one big number: the ride screen hides the rows
    focus: [["power", "number"], ["cadence", "number"], ["heart", "number"], ["np", "number"], ["kcal", "number"]]
}
var presetOrder = ["power", "simple", "heart", "focus"]

function presetName(id) {
    if (id === "simple")
        return qsTr("Simple")
    if (id === "heart")
        return qsTr("Heart")
    if (id === "power")
        return qsTr("Power")
    if (id === "focus")
        return qsTr("Focus")
    return qsTr("Custom")
}

function presetSlots(id) {
    return presets[id].map(function (a) { return { m: a[0], st: a[1] } })
}

function copySlots(slots) {
    return slots.map(function (s) { return { m: s.m, st: s.st } })
}

// a saved layout, or the preset when the text is missing or broken
function parseLayout(text, fallback) {
    if (!text)
        return presetSlots(fallback)
    try {
        var saved = JSON.parse(text)
        if (saved.length === 5) {
            var ok = true
            for (var i = 0; i < saved.length; i++) {
                var known = saved[i].m === "empty" || order.indexOf(saved[i].m) >= 0
                if (!known || ["number", "trend", "bar"].indexOf(saved[i].st) < 0)
                    ok = false
            }
            if (ok && saved[0].m !== "empty")
                return copySlots(saved)
        }
    } catch (e) {
    }
    return presetSlots(fallback)
}
