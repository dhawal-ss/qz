.pragma library

// Words and numbers for the data screens: durations, distances, dates.

var monthNames = ["January", "February", "March", "April", "May", "June", "July", "August",
                  "September", "October", "November", "December"]
var monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var dayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

// 45:12 under an hour, 1 h 05 min above
function duration(seconds) {
    var s = Math.max(0, Math.round(seconds || 0))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    if (h > 0)
        return h + " h " + (m < 10 ? "0" : "") + m + " min"
    var r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
}

// 12 h 40 min, 40 min: for totals, never with seconds
function hours(seconds) {
    // rounded to whole minutes first, so 1 h 59 min 30 s reads 2 h 0 min, not 1 h 60 min
    var total = Math.round(Math.max(0, seconds || 0) / 60)
    var h = Math.floor(total / 60)
    var m = total % 60
    if (h > 0)
        return h + " h " + m + " min"
    return m + " min"
}

function distance(km, miles) {
    var v = (km || 0) * (miles ? 0.621371 : 1)
    return (v >= 100 ? Math.round(v) : v.toFixed(1)) + (miles ? " mi" : " km")
}

// For values in km/h and kg only. The live ride's numbers from rideMetrics are already in the
// rider's unit (ridemetrics.cpp converts them), so they must not go through these again.

// 32.4 km/h, or 20.1 mph
function speed(kmh, miles) {
    var v = (kmh || 0) * (miles ? 0.621371 : 1)
    return v.toFixed(1) + (miles ? " mph" : " km/h")
}

// 75.5 kg, or 166 lb. lbs is QZ's rule: miles_unit and not weight_kg_unit
function weight(kg, lbs) {
    if (lbs)
        return Math.round((kg || 0) * 2.20462) + " lb"
    return (Math.round((kg || 0) * 10) / 10) + " kg"
}

function distanceUnit(miles) {
    return miles ? "mi" : "km"
}

function speedUnit(miles) {
    return miles ? "mph" : "km/h"
}

function weightUnit(lbs) {
    return lbs ? "lb" : "kg"
}

// km to the rider's distance unit, and back
function toDistance(km, miles) {
    return (km || 0) * (miles ? 0.621371 : 1)
}

function fromDistance(value, miles) {
    return (value || 0) / (miles ? 0.621371 : 1)
}

function whole(v) {
    return v === undefined || v === null || isNaN(v) ? "0" : String(Math.round(v))
}

// thousands with a thin separator: 12 450
function big(v) {
    var s = String(Math.round(v || 0))
    var out = ""
    for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 === 0)
            out += " "
        out += s[i]
    }
    return out
}

function startOfDay(ms) {
    var d = new Date(ms)
    d.setHours(0, 0, 0, 0)
    return d.getTime()
}

// Today, Yesterday, Tue 4 Nov, or 4 Nov 2025 in another year
function day(ms) {
    var d = new Date(ms)
    var today = startOfDay(Date.now())
    var that = startOfDay(ms)
    if (that === today)
        return "Today"
    if (today - that === 86400000)
        return "Yesterday"
    var text = dayShort[d.getDay()] + " " + d.getDate() + " " + monthShort[d.getMonth()]
    if (d.getFullYear() !== new Date().getFullYear())
        text = d.getDate() + " " + monthShort[d.getMonth()] + " " + d.getFullYear()
    return text
}

function time(ms) {
    var d = new Date(ms)
    var m = d.getMinutes()
    return d.getHours() + ":" + (m < 10 ? "0" : "") + m
}

function month(ms) {
    var d = new Date(ms)
    return monthNames[d.getMonth()] + (d.getFullYear() !== new Date().getFullYear() ? " " + d.getFullYear() : "")
}

function monthKey(ms) {
    var d = new Date(ms)
    return d.getFullYear() * 12 + d.getMonth()
}

// The first day of the week, the ui2 setting weekStart: 1 for Monday (the default), 0 for Sunday.
// Theme keeps it in step with the setting (Theme.weekStart, which QML bindings read so they
// update); every week of the app is counted from it, here and in goals/Streak.js.
var firstDay = 1
var dayLetters = [qsTr("S"), qsTr("M"), qsTr("T"), qsTr("W"), qsTr("T"), qsTr("F"), qsTr("S")]
var dayNames = [qsTr("Sunday"), qsTr("Monday"), qsTr("Tuesday"), qsTr("Wednesday"), qsTr("Thursday"),
                qsTr("Friday"), qsTr("Saturday")]

function setFirstDay(day) {
    firstDay = Number(day) === 0 ? 0 : 1
}

// 0 for Sunday or 1 for Monday: the one asked for, else the setting
function firstDayOf(day) {
    if (day === undefined || day === null || day === "")
        return firstDay
    return Number(day) === 0 ? 0 : 1
}

// how many days ms is after the first day of its week, 0 to 6
function weekday(ms, day) {
    return (new Date(ms).getDay() - firstDayOf(day) + 7) % 7
}

// 00:00 of the first day of the week holding ms; day is 0 for Sunday, 1 for Monday, left out for
// the setting. Stepped back by date from the day's own midnight: the JavaScript engine of Qt 5
// can read a midnight built with new Date(y, m, d) in summer time as 23:00 of the day before.
function weekStart(ms, day) {
    var d = new Date(startOfDay(ms))
    d.setDate(d.getDate() - (d.getDay() - firstDayOf(day) + 7) % 7)
    return d.getTime()
}

// the weekday letters and names in the order of the week
function inWeekOrder(list, day) {
    var first = firstDayOf(day)
    var out = []
    for (var i = 0; i < 7; i++)
        out.push(list[(i + first) % 7])
    return out
}
function weekLetters(day) {
    return inWeekOrder(dayLetters, day)
}
function weekDayNames(day) {
    return inWeekOrder(dayNames, day)
}

// 5 s, 1 min, 20 min, 1 h
function effort(seconds) {
    if (seconds < 60)
        return seconds + " s"
    if (seconds < 3600)
        return Math.round(seconds / 60) + " min"
    return (seconds / 3600) + " h"
}

// a ride title QZ leaves empty or generic becomes the time of day
function title(ride) {
    var t = ride.title || ""
    if (t !== "" && t.toLowerCase() !== "workout" && t.toLowerCase() !== "bike")
        return t
    var h = new Date(ride.start).getHours()
    if (h < 5)
        return "Night ride"
    if (h < 12)
        return "Morning ride"
    if (h < 17)
        return "Afternoon ride"
    if (h < 21)
        return "Evening ride"
    return "Night ride"
}
