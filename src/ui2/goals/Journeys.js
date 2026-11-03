.pragma library

// Journeys: the distance ridden since a journey started, laid along a real route. Each route is a
// list of waypoints [name, km from the start, latitude, longitude]. The km are approximate road
// or cycle route distances and the coordinates are the towns, rounded: enough to draw the shape
// of the route and say which town comes next, not to navigate by. Around the world follows the
// equator, 40 075 km, so its km come from the longitude (111.32 km a degree).

var journeys = [
    { id: "ams-paris", name: qsTr("Amsterdam to Paris"), tone: 2, ring: false, points: [
        ["Amsterdam", 0, 52.37, 4.90], ["Rotterdam", 75, 51.92, 4.48], ["Antwerp", 175, 51.22, 4.40],
        ["Brussels", 220, 50.85, 4.35], ["Lille", 335, 50.63, 3.06], ["Arras", 385, 50.29, 2.78],
        ["Compiegne", 500, 49.42, 2.83], ["Paris", 570, 48.86, 2.35]] },
    { id: "lejog", name: qsTr("Land's End to John o'Groats"), tone: 1, ring: false, points: [
        ["Land's End", 0, 50.07, -5.71], ["Plymouth", 140, 50.38, -4.14], ["Exeter", 210, 50.72, -3.53],
        ["Bristol", 340, 51.45, -2.59], ["Shrewsbury", 540, 52.71, -2.75], ["Lancaster", 720, 54.05, -2.80],
        ["Carlisle", 830, 54.89, -2.93], ["Glasgow", 990, 55.86, -4.25], ["Perth", 1090, 56.40, -3.43],
        ["Inverness", 1270, 57.48, -4.22], ["John o'Groats", 1460, 58.64, -3.07]] },
    { id: "italy", name: qsTr("Length of Italy"), tone: 3, ring: false, points: [
        ["Aosta", 0, 45.74, 7.32], ["Turin", 115, 45.07, 7.69], ["Genoa", 285, 44.41, 8.93],
        ["Pisa", 445, 43.72, 10.40], ["Florence", 530, 43.77, 11.26], ["Siena", 600, 43.32, 11.33],
        ["Rome", 830, 41.90, 12.50], ["Naples", 1055, 40.85, 14.27], ["Salerno", 1110, 40.68, 14.77],
        ["Cosenza", 1340, 39.30, 16.25], ["Reggio Calabria", 1530, 38.11, 15.65]] },
    { id: "paris-rome", name: qsTr("Paris to Rome"), tone: 4, ring: false, points: [
        ["Paris", 0, 48.86, 2.35], ["Dijon", 315, 47.32, 5.04], ["Lyon", 510, 45.76, 4.84],
        ["Chambery", 610, 45.56, 5.92], ["Turin", 820, 45.07, 7.69], ["Genoa", 990, 44.41, 8.93],
        ["Florence", 1220, 43.77, 11.26], ["Rome", 1495, 41.90, 12.50]] },
    { id: "route66", name: qsTr("Route 66"), tone: 5, ring: false, points: [
        ["Chicago", 0, 41.88, -87.63], ["St. Louis", 480, 38.63, -90.20], ["Springfield", 830, 37.21, -93.29],
        ["Tulsa", 1130, 36.15, -95.99], ["Oklahoma City", 1310, 35.47, -97.52], ["Amarillo", 1760, 35.22, -101.83],
        ["Santa Fe", 2280, 35.69, -105.94], ["Albuquerque", 2390, 35.08, -106.65], ["Gallup", 2620, 35.53, -108.74],
        ["Flagstaff", 2950, 35.20, -111.65], ["Kingman", 3230, 35.19, -114.05], ["Barstow", 3690, 34.90, -117.02],
        ["Santa Monica", 3940, 34.02, -118.49]] },
    { id: "world", name: qsTr("Around the world"), tone: 7, ring: true, points: [
        ["Quito", 0, -0.18, -78.47], ["Macapa", 3050, 0.03, -51.07], ["Sao Tome", 9480, 0.34, 6.73],
        ["Kampala", 12360, 0.35, 32.58], ["Kismayo", 13460, -0.36, 42.54], ["Pontianak", 20900, -0.03, 109.34],
        ["Galapagos", 38750, -0.74, -90.31], ["Quito", 40075, -0.18, -78.47]] }
]

function byId(id) {
    for (var i = 0; i < journeys.length; i++)
        if (journeys[i].id === id)
            return journeys[i]
    return null
}

function total(journey) {
    return journey.points[journey.points.length - 1][1]
}

function from(journey) {
    return journey.points[0][0]
}

function to(journey) {
    return journey.points[journey.points.length - 1][0]
}

// where the rider is after riding km: { km, fraction, percent, passed, next, toNext, done }.
// passed is the index of the last waypoint behind, the start counts as passed; next is the index
// of the one ahead, -1 when the journey is done.
function progress(journey, km) {
    var length = total(journey)
    var ridden = Math.max(0, Math.min(length, km || 0))
    var passed = 0
    for (var i = 1; i < journey.points.length; i++)
        if (ridden >= journey.points[i][1])
            passed = i
    var done = ridden >= length
    var next = done ? -1 : passed + 1
    return {
        km: ridden,
        fraction: ridden / length,
        percent: Math.floor(100 * ridden / length),
        passed: passed,
        next: next,
        toNext: done ? 0 : journey.points[next][1] - ridden,
        done: done
    }
}

// The route fitted into a w x h box with pad around it: [{x, y, km}], dense enough to draw.
// A line route is its waypoints, longitude scaled by the cosine of the mean latitude; the world
// is a ring starting at the top and going round clockwise.
function route(journey, w, h, pad) {
    var out = []
    var length = total(journey)
    if (journey.ring) {
        var r = Math.max(1, Math.min(w, h) / 2 - pad)
        var steps = 96
        for (var s = 0; s <= steps; s++) {
            var a = 2 * Math.PI * s / steps
            out.push({ x: w / 2 + r * Math.sin(a), y: h / 2 - r * Math.cos(a), km: length * s / steps })
        }
        return out
    }
    var meanLat = 0
    for (var i = 0; i < journey.points.length; i++)
        meanLat += journey.points[i][2] / journey.points.length
    var squeeze = Math.cos(meanLat * Math.PI / 180)
    var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9
    var raw = []
    for (var j = 0; j < journey.points.length; j++) {
        var x = journey.points[j][3] * squeeze
        var y = -journey.points[j][2]
        raw.push({ x: x, y: y, km: journey.points[j][1] })
        minX = Math.min(minX, x)
        maxX = Math.max(maxX, x)
        minY = Math.min(minY, y)
        maxY = Math.max(maxY, y)
    }
    var spanX = Math.max(1e-6, maxX - minX)
    var spanY = Math.max(1e-6, maxY - minY)
    var scale = Math.min((w - 2 * pad) / spanX, (h - 2 * pad) / spanY)
    var offX = (w - spanX * scale) / 2
    var offY = (h - spanY * scale) / 2
    for (var k = 0; k < raw.length; k++)
        out.push({ x: offX + (raw[k].x - minX) * scale, y: offY + (raw[k].y - minY) * scale, km: raw[k].km })
    return out
}

// the point km along a route() list
function position(points, km) {
    if (points.length === 0)
        return { x: 0, y: 0 }
    if (km <= points[0].km)
        return { x: points[0].x, y: points[0].y }
    for (var i = 1; i < points.length; i++) {
        var a = points[i - 1]
        var b = points[i]
        if (km <= b.km) {
            var t = b.km > a.km ? (km - a.km) / (b.km - a.km) : 1
            return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t }
        }
    }
    var last = points[points.length - 1]
    return { x: last.x, y: last.y }
}

// the part of a route() list from the start to km, ending exactly at km
function ridden(points, km) {
    var out = []
    for (var i = 0; i < points.length && points[i].km < km; i++)
        out.push({ x: points[i].x, y: points[i].y })
    out.push(position(points, km))
    if (out.length === 1)
        out.push(out[0])
    return out
}

// the start of the ride on which the distance ridden since startMs reached the length of the
// journey, 0 when it has not; rides are oldest first
function finishedOn(rides, startMs, length) {
    var sum = 0
    for (var i = 0; i < rides.length; i++) {
        if (rides[i].start < startMs)
            continue
        sum += rides[i].distance || 0
        if (sum >= length)
            return rides[i].start
    }
    return 0
}

function isDone(done, id) {
    for (var i = 0; i < done.length; i++)
        if (done[i].id === id)
            return true
    return false
}
