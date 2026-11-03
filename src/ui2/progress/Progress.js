.pragma library

// Small helpers shared by the Progress cards: chart scales, curve drawing and the words for
// durations and ages.

var monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

// the top of a chart scale, rounded up to a value that reads well
function niceTop(v) {
    var steps = [5, 10, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 1200, 1500, 2000]
    for (var i = 0; i < steps.length; i++)
        if (v <= steps[i])
            return steps[i]
    return Math.ceil(v / 500) * 500
}

// 5 s, 1 min 30 s, 20 min, 1 h, 1 h 30 min: the length of a power record
function effort(seconds) {
    var s = Math.round(seconds)
    if (s < 60)
        return s + " s"
    if (s < 3600) {
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + " min" + (r > 0 ? " " + r + " s" : "")
    }
    var h = Math.floor(s / 3600)
    var rest = Math.round((s % 3600) / 60)
    return h + " h" + (rest > 0 ? " " + rest + " min" : "")
}

// noon of the day holding ms: the JavaScript engine of Qt 5 can read local midnight of a DST
// change as 23:00 of the day before, noon is never on the wrong day
function noon(ms) {
    var d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12)
}

// whole days from the day of a to the day of b
function daysBetween(a, b) {
    return Math.round((noon(b).getTime() - noon(a).getTime()) / 86400000)
}

// how long a record has stood, in the largest unit that fits
function stood(ms, now) {
    var days = daysBetween(ms, now)
    if (days <= 0)
        return "today"
    if (days === 1)
        return "1 day"
    if (days < 14)
        return days + " days"
    if (days < 61)
        return Math.floor(days / 7) + " weeks"
    if (days < 365)
        return Math.floor(days / 30.44) + " months"
    var years = Math.floor(days / 365.25)
    return years === 1 ? "1 year" : years + " years"
}

// 4 Nov, or 4 Nov 2025 in another year
function shortDate(ms) {
    var d = new Date(ms)
    var text = d.getDate() + " " + monthShort[d.getMonth()]
    if (d.getFullYear() !== new Date().getFullYear())
        text += " " + d.getFullYear()
    return text
}

// Slopes of a monotone cubic through the points (Fritsch and Carlson): the curve between two
// points never goes above or below them, so a power curve never bumps up with duration.
function monotoneSlopes(xs, ys) {
    var n = xs.length
    var m = []
    if (n < 2)
        return [0]
    var d = []
    for (var i = 0; i < n - 1; i++)
        d.push((ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]))
    m.push(d[0])
    for (var j = 1; j < n - 1; j++)
        m.push(d[j - 1] * d[j] <= 0 ? 0 : (d[j - 1] + d[j]) / 2)
    m.push(d[n - 2])
    for (var k = 0; k < n - 1; k++) {
        if (d[k] === 0) {
            m[k] = 0
            m[k + 1] = 0
            continue
        }
        var a = m[k] / d[k]
        var b = m[k + 1] / d[k]
        var s = a * a + b * b
        if (s > 9) {
            var t = 3 / Math.sqrt(s)
            m[k] = t * a * d[k]
            m[k + 1] = t * b * d[k]
        }
    }
    return m
}

// the value of that curve at x, inside the first and the last point
function monotoneAt(xs, ys, m, x) {
    var n = xs.length
    if (n === 0)
        return 0
    if (x <= xs[0] || n === 1)
        return ys[0]
    if (x >= xs[n - 1])
        return ys[n - 1]
    var i = 0
    while (i < n - 2 && x > xs[i + 1])
        i++
    var h = xs[i + 1] - xs[i]
    var t = (x - xs[i]) / h
    var t2 = t * t
    var t3 = t2 * t
    return (2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * m[i]
            + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * m[i + 1]
}

// The cards of the Progress screen as the rider set them: the setting is JSON
// {"order": [ids], "hidden": [ids]}. Unknown ids are dropped and ids the setting does not know
// yet (a card added in a later version) go at the end, shown.
function cardList(json, known) {
    var saved = {}
    try {
        saved = JSON.parse(json || "{}") || {}
    } catch (e) {
        saved = {}
    }
    var order = []
    var savedOrder = saved.order || []
    for (var i = 0; i < savedOrder.length; i++)
        if (known.indexOf(savedOrder[i]) >= 0 && order.indexOf(savedOrder[i]) < 0)
            order.push(savedOrder[i])
    for (var j = 0; j < known.length; j++)
        if (order.indexOf(known[j]) < 0)
            order.push(known[j])
    var hidden = saved.hidden || []
    var out = []
    for (var k = 0; k < order.length; k++)
        out.push({ id: order[k], shown: hidden.indexOf(order[k]) < 0 })
    return out
}

function cardJson(list) {
    var order = []
    var hidden = []
    for (var i = 0; i < list.length; i++) {
        order.push(list[i].id)
        if (!list[i].shown)
            hidden.push(list[i].id)
    }
    return JSON.stringify({ order: order, hidden: hidden })
}
