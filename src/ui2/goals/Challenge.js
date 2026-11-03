.pragma library

// The monthly challenge: a personal target in minutes, worked out from the rider's own months.
// The rules:
//   - The target of a month is the average of the up to 3 months before it, counted from the
//     month of the first ride (months without rides count as 0, so after a break it is gentler),
//     plus 10%, rounded up to 30 min (60 min from 10 h), and never under 2 h.
//   - The first month, with nothing before it, gets 4 h.
//   - A month is met once its minutes reach its target; the day it got there is the day it was met.

var starter = 240
var floorMinutes = 120

function monthKey(ms) {
    var d = new Date(ms)
    return d.getFullYear() * 12 + d.getMonth()
}

// noon of the first day of a month key
function monthStart(key) {
    return new Date(Math.floor(key / 12), key % 12, 1, 12).getTime()
}

function daysIn(key) {
    return new Date(Math.floor(key / 12), key % 12 + 1, 0, 12).getDate()
}

function nice(minutes) {
    var step = minutes < 600 ? 30 : 60
    return Math.max(floorMinutes, Math.ceil(minutes / step) * step)
}

// minutes ridden per month key from library.days()
function perMonth(days) {
    var months = {}
    for (var i = 0; i < days.length; i++) {
        var key = monthKey(days[i].day)
        months[key] = (months[key] || 0) + (days[i].seconds || 0) / 60
    }
    return months
}

function target(months, key, firstKey) {
    var sum = 0
    var count = 0
    for (var k = key - 3; k < key; k++) {
        if (k < firstKey)
            continue
        sum += months[k] || 0
        count++
    }
    if (count === 0)
        return starter
    return nice(sum / count * 1.1)
}

// Every month from the first ride to the month of now, oldest first:
// [{ key, target, minutes, met, metOn }]. days must be oldest first, as library.days() gives them.
function history(days, now) {
    var months = perMonth(days)
    var current = monthKey(now)
    var firstKey = current
    for (var k in months)
        firstKey = Math.min(firstKey, Number(k))
    var targets = {}
    var out = []
    for (var key = firstKey; key <= current; key++) {
        targets[key] = target(months, key, firstKey)
        out.push({ key: key, target: targets[key], minutes: months[key] || 0, met: false, metOn: 0 })
    }
    // the day each month got there
    var sums = {}
    for (var i = 0; i < days.length; i++) {
        var m = monthKey(days[i].day)
        if (targets[m] === undefined)
            continue
        var before = sums[m] || 0
        sums[m] = before + (days[i].seconds || 0) / 60
        if (before < targets[m] && sums[m] >= targets[m]) {
            var entry = out[m - firstKey]
            entry.met = true
            entry.metOn = days[i].day
        }
    }
    return out
}

// how the month in progress is going: { daysLeft, expected, onTrack, perWeek }; perWeek is the
// minutes a week that reach the target from here, 0 when it is reached
function pace(minutes, targetMinutes, now) {
    var key = monthKey(now)
    var length = daysIn(key)
    var today = new Date(now).getDate()
    var daysLeft = length - today
    var expected = targetMinutes * today / length
    var remaining = Math.max(0, targetMinutes - minutes)
    // today still counts as a day to ride
    var weeksLeft = Math.max(1, (daysLeft + 1) / 7)
    return {
        daysLeft: daysLeft,
        expected: expected,
        onTrack: minutes >= expected,
        perWeek: remaining > 0 ? remaining / weeksLeft : 0
    }
}

// the months met, oldest first
function metMonths(list) {
    return list.filter(function (m) { return m.met })
}
