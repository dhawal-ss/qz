.pragma library

// A workout from the coach's plan (today/Coach.js plan(): blocks of [minutes, zone]) as steps to
// ride: when each one starts, how long it lasts, its zone and what to aim for. With the rider's
// own FTP a step has a watt band (from the zone starts of Theme.powerZoneStarts, rounded to 5 W);
// without one it has only how it should feel, never a number worked out from a guess.
// Bikemodo never sets the resistance: the ride screen says what to do (WorkoutPanel.qml).

// how each zone should feel, for riding by feel
function feel(zone) {
    if (zone <= 1)
        return qsTr("Very easy, just spin")
    if (zone === 2)
        return qsTr("Easy, you can talk")
    if (zone === 3)
        return qsTr("Steady, short sentences")
    if (zone === 4)
        return qsTr("Hard, a few words")
    if (zone === 5)
        return qsTr("Very hard, no talking")
    return qsTr("All out")
}

function round5(w) {
    return Math.round(w / 5) * 5
}

// [{ start, seconds, zone, low, high, words }]; low and high 0 without an FTP of the rider's own.
// A block may carry its own target and words ([minutes, zone, watts, words], train/Ftp.js): an FTP
// test steps by watts it sets itself, and its all-out block has words and no band.
function steps(plan, ftp, ftpSet, starts) {
    var out = []
    if (!plan || !plan.blocks)
        return out
    var t = 0
    for (var i = 0; i < plan.blocks.length; i++) {
        var seconds = Math.max(30, Math.round(plan.blocks[i][0] * 60))
        var zone = Math.max(1, Math.min(7, plan.blocks[i][1]))
        var low = 0
        var high = 0
        var own = plan.blocks[i].length > 2 ? plan.blocks[i][2] : -1
        if (own > 0) {
            low = own - 5
            high = own + 5
        } else if (own < 0 && ftpSet && ftp > 0) {
            low = round5(ftp * (zone <= 1 ? 0.45 : starts[zone - 2]))
            high = round5(ftp * (zone >= 7 ? starts[5] * 1.2 : starts[zone - 1]) - 1)
        }
        var words = plan.blocks[i].length > 3 ? plan.blocks[i][3] : feel(zone)
        out.push({ start: t, seconds: seconds, zone: zone, low: low, high: high, words: words })
        t += seconds
    }
    return out
}

function total(list) {
    return list.length > 0 ? list[list.length - 1].start + list[list.length - 1].seconds : 0
}

// where the workout is t seconds in: { index, left, done } (index -1 before it, list.length after)
function at(list, t) {
    if (list.length === 0)
        return { index: -1, left: 0, done: false }
    for (var i = 0; i < list.length; i++) {
        var end = list[i].start + list[i].seconds
        if (t < end)
            return { index: i, left: Math.max(0, end - t), done: false }
    }
    return { index: list.length, left: 0, done: true }
}

// "187–217 W", or the words when there is no band
function target(step) {
    if (!step)
        return ""
    if (step.high > 0 && step.high - step.low <= 10)
        return (step.low + 5) + " W"
    return step.high > 0 ? step.low + "–" + step.high + " W" : step.words
}

// -1 below the band, 0 in it, 1 above it, for watts held over the last seconds (0 without a band)
function side(step, watts) {
    if (!step || step.high <= 0)
        return 0
    if (watts < step.low)
        return -1
    if (watts > step.high)
        return 1
    return 0
}

// the blocks of the plan with the done part, for WorkoutShape: [[minutes, zone]]
function blocks(list) {
    return list.map(function (s) { return [s.seconds / 60, s.zone] })
}
