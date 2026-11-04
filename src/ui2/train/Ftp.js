.pragma library
.import "../today/Coach.js" as Coach

// The FTP tests, as workouts (Coach.plan) the ride screen runs like any other, with kind set so it
// also measures them (RideScreen: testWatts()). Each block is [minutes, zone, watts, words]:
// watts -1 for the zone's band, 0 for no number (an all-out effort), else the target itself.
//  - ramp: a warm-up, then one minute steps that rise until the rider cannot hold them; FTP is
//    75% of the best minute. On a hand-knob bike the screen says which level each minute needs.
//  - twenty: a warm-up with two short openers, 20 minutes as hard as can be held; FTP is 95% of
//    its average.
// The watts of the ramp start from the FTP there is (QZ's 200 W guess when the rider has none),
// low enough for anyone: the steps carry on past it, so the guess only sets where it starts.

function round5(w) {
    return Math.round(w / 5) * 5
}

function rampPlan(ftp) {
    var base = ftp > 0 ? ftp : 200
    var start = Math.max(50, round5(base * 0.45))
    var step = Math.max(10, round5(base * 0.08))
    var blocks = [[5, 1, -1, qsTr("Warm up, easy")], [3, 2, -1, qsTr("Easy, you can talk")]]
    // up to twice the FTP it starts from (at least 15 steps): hardly anyone gets there
    for (var w = start, i = 0; i < 40 && (i < 15 || w <= base * 2); w += step, i++) {
        var zone = w < base * 0.75 ? 2 : (w < base * 0.9 ? 3 : (w < base * 1.05 ? 4 : (w < base * 1.2 ? 5 : 6)))
        blocks.push([1, zone, w, ""])
    }
    blocks.push([5, 1, -1, qsTr("Spin easy, you are done")])
    var p = Coach.plan("ramp", qsTr("Ramp test"), qsTr("One minute steps until you cannot hold them"), blocks)
    p.kind = "ramp"
    // the steps that are the test, by index
    p.testFrom = 2
    p.testTo = blocks.length - 2
    return p
}

function twentyPlan() {
    var blocks = [[10, 2, -1, qsTr("Warm up, easy")], [1, 4, -1, qsTr("Hard for a minute")], [2, 1, -1, qsTr("Easy")],
                  [1, 4, -1, qsTr("Hard for a minute")], [5, 1, -1, qsTr("Easy, get ready")],
                  [20, 4, 0, qsTr("As hard as you can hold for 20 minutes")], [5, 1, -1, qsTr("Spin easy, you are done")]]
    var p = Coach.plan("twenty", qsTr("20 minute FTP test"), qsTr("20 minutes as hard as you can hold"), blocks)
    p.kind = "twenty"
    p.testFrom = 5
    p.testTo = 5
    return p
}

// FTP from what the test measured: the best minute of a ramp, the average of the 20 minutes
function result(kind, bestMinute, average) {
    if (kind === "ramp")
        return bestMinute > 0 ? Math.round(bestMinute * 0.75) : 0
    if (kind === "twenty")
        return average > 0 ? Math.round(average * 0.95) : 0
    return 0
}

function isTest(plan) {
    return plan !== null && plan !== undefined && (plan.kind === "ramp" || plan.kind === "twenty")
}
