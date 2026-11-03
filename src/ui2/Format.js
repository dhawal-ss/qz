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
    var s = Math.max(0, Math.round(seconds || 0))
    var h = Math.floor(s / 3600)
    var m = Math.round((s % 3600) / 60)
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

// 00:00 of the first day of the week holding ms. firstDay is the ui2 setting weekStart: 0 for
// Sunday, anything else (1, or left out) for Monday
function weekStart(ms, firstDay) {
    var d = new Date(startOfDay(ms))
    var back = Number(firstDay) === 0 && firstDay !== null && firstDay !== "" ? d.getDay() : (d.getDay() + 6) % 7
    d.setDate(d.getDate() - back)
    return d.getTime()
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
