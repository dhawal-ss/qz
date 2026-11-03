.pragma library

// How far a weekly goal can be set, in the unit the rider sees: rides 1 to 14, minutes 10 to
// 2000 in steps of 10, kJ 100 to 20000 in steps of 100, distance 5 to 1000 km (or 5 to 600 mi)
// in steps of 5. Goals are stored as Streak.js keeps them: minutes, kJ, km or rides.

var kmPerMile = 1.609344

function range(kind, miles) {
    if (kind === "rides")
        return { from: 1, to: 14, step: 1 }
    if (kind === "kj")
        return { from: 100, to: 20000, step: 100 }
    if (kind === "km")
        return miles ? { from: 5, to: 600, step: 5 } : { from: 5, to: 1000, step: 5 }
    return { from: 10, to: 2000, step: 10 }
}

// a stored goal as the rider sees it
function toShown(kind, value, miles) {
    if (kind === "km" && miles)
        return Math.round((value || 0) / kmPerMile)
    return Math.round(value || 0)
}

// a goal as the rider sees it, in the unit Streak.js stores
function toStored(kind, shown, miles) {
    if (kind === "km" && miles)
        return shown * kmPerMile
    return shown
}

// a stored goal kept inside the range
function clampStored(kind, value, miles) {
    var r = range(kind, miles)
    var shown = Math.max(r.from, Math.min(r.to, toShown(kind, value, miles)))
    return toStored(kind, shown, miles)
}
