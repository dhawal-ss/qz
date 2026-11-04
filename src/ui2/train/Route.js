.pragma library

// Routes: an elevation profile ridden by distance. Three are made up here (no real place is
// claimed), others come from .gpx files (homeform::routeFile). A route is
// { id, name, detail, points: [[km, elevation m], ...] }. Bikemodo never sets the resistance: on a
// climb it says what the climb takes at the speed now (watts from the rider's weight and the
// gradient), and on an Echelon the level for it.

// a profile from pieces of [km, gradient %], a point every 50 m
function build(id, name, detail, pieces) {
    var pts = [[0, 100]]
    var km = 0
    var ele = 100
    for (var i = 0; i < pieces.length; i++) {
        var steps = Math.max(1, Math.round(pieces[i][0] / 0.05))
        for (var s = 0; s < steps; s++) {
            km += pieces[i][0] / steps
            ele += pieces[i][0] / steps * 1000 * pieces[i][1] / 100
            pts.push([Math.round(km * 1000) / 1000, Math.round(ele * 10) / 10])
        }
    }
    return { id: id, name: name, detail: detail, points: pts }
}

function library() {
    return [
        build("rolling", qsTr("Rolling hills, 20 km"), qsTr("Short rises and dips, nothing long"),
              [[2, 0.5], [0.8, 4], [1, -3], [1.5, 1], [0.6, 6], [1.2, -4], [2, 0], [1, 3], [0.8, -2], [1.5, 2], [0.7, 5], [1.4, -4], [2.5, 0.5], [3, -0.5]]),
        build("climb", qsTr("One long climb, 15 km"), qsTr("5 km flat, 6 km up at 5 to 7%, then down"),
              [[5, 0.5], [2, 5], [2, 7], [2, 6], [4, -6]]),
        build("flat", qsTr("Flat and steady, 30 km"), qsTr("For a long steady ride"),
              [[10, 0.3], [10, -0.2], [10, 0.1]])
    ]
}

function total(route) {
    var p = route.points
    return p.length > 0 ? p[p.length - 1][0] : 0
}

// where km is on the route: { index, ele, grade (%), done }
function at(route, km) {
    var p = route.points
    if (p.length < 2)
        return { index: 0, ele: 0, grade: 0, done: true }
    if (km >= p[p.length - 1][0])
        return { index: p.length - 1, ele: p[p.length - 1][1], grade: 0, done: true }
    for (var i = 1; i < p.length; i++) {
        if (km < p[i][0]) {
            var d = p[i][0] - p[i - 1][0]
            var f = d > 0 ? (km - p[i - 1][0]) / d : 0
            // the gradient over the next 200 m or so, steadier than point to point
            var j = i
            while (j < p.length - 1 && p[j][0] - p[i - 1][0] < 0.2)
                j++
            var span = p[j][0] - p[i - 1][0]
            var grade = span > 0 ? (p[j][1] - p[i - 1][1]) / (span * 1000) * 100 : 0
            return { index: i, ele: p[i - 1][1] + f * (p[i][1] - p[i - 1][1]), grade: Math.round(grade * 10) / 10, done: false }
        }
    }
    return { index: p.length - 1, ele: p[p.length - 1][1], grade: 0, done: true }
}

// the next climb of 3% or more for 300 m or more ahead of km: { inKm, lengthKm, grade } or null
function nextClimb(route, km) {
    var p = route.points
    var start = -1
    for (var i = 1; i < p.length; i++) {
        if (p[i][0] <= km)
            continue
        var d = p[i][0] - p[i - 1][0]
        var g = d > 0 ? (p[i][1] - p[i - 1][1]) / (d * 1000) * 100 : 0
        if (g >= 3 && start < 0)
            start = i - 1
        if ((g < 3 || i === p.length - 1) && start >= 0) {
            var len = p[i - 1][0] - p[start][0]
            if (len >= 0.3) {
                var rise = p[i - 1][1] - p[start][1]
                return { inKm: Math.max(0, p[start][0] - km), lengthKm: len, grade: Math.round(rise / (len * 1000) * 1000) / 10 }
            }
            start = -1
        }
    }
    return null
}

// the watts that hold speed (km/h) on this gradient (%), for a rider and bike of mass kg: rolling
// resistance, the climb and the air, with ordinary values for a road position
function watts(grade, kmh, kg) {
    var v = Math.max(0, kmh) / 3.6
    var m = (kg > 30 ? kg : 75) + 9
    var theta = Math.atan(grade / 100)
    var force = m * 9.81 * (Math.sin(theta) + 0.004 * Math.cos(theta)) + 0.5 * 1.2 * 0.32 * v * v
    return Math.max(0, Math.round(force * v))
}
