.pragma library

// Pro numbers, worked out from what the library has. Each one says what it rests on, and
// estimated watts stay estimated: a model fitted to them is an estimate too.

// Critical power and W′ (the two parameter model, work = CP × t + W′) fitted to the best powers
// of 3 to 20 minutes (curve: [{ seconds, watts }] of the last 90 days, library.powerCurve).
// null when there are fewer than three of those, or the fit makes no sense (a curve of easy
// rides gives a flat line, not a model).
function criticalPower(curve) {
    var pts = []
    for (var i = 0; i < curve.length; i++) {
        var s = curve[i].seconds
        if (s >= 180 && s <= 1200 && curve[i].watts > 0)
            pts.push({ t: s, work: curve[i].watts * s })
    }
    if (pts.length < 3)
        return null
    var n = pts.length, st = 0, sw = 0, stt = 0, stw = 0
    for (var k = 0; k < n; k++) {
        st += pts[k].t
        sw += pts[k].work
        stt += pts[k].t * pts[k].t
        stw += pts[k].t * pts[k].work
    }
    var d = n * stt - st * st
    if (d <= 0)
        return null
    var cp = (n * stw - st * sw) / d
    var wprime = (sw - cp * st) / n
    if (cp <= 0 || wprime < 2000 || wprime > 60000)
        return null
    return { cp: Math.round(cp), wprime: Math.round(wprime) }
}

// W′ balance through a ride (Skiba's differential form, 1 Hz): the joules of W′ left, from full at
// the start. power: watts every second. { series, lowest, lowestAt }
function wbal(power, cp, wprime) {
    var bal = wprime
    var out = []
    var lowest = wprime
    var at = 0
    for (var i = 0; i < power.length; i++) {
        var p = power[i] || 0
        if (p > cp)
            bal -= p - cp
        else
            bal += (wprime - bal) * (cp - p) / wprime
        bal = Math.max(0, Math.min(wprime, bal))
        out.push(bal / 1000)
        if (bal < lowest) {
            lowest = bal
            at = i
        }
    }
    return { series: out, lowest: lowest, lowestAt: at }
}

// VO2 max from the best 5 minutes (about 10.8 ml/kg/min per W/kg, plus 7 at rest, as the ACSM
// formula for cycling has it), with how far off it can be: ±10%, ±15% on estimated watts.
// null without a weight or 5 minutes of power.
function vo2max(best5, weightKg, estimated) {
    if (!(best5 > 0) || !(weightKg > 30))
        return null
    // the formula holds for an all-out 5 minutes: under 1.5 W/kg it was an easy one, and says nothing
    if (best5 / weightKg < 1.5)
        return null
    var v = 10.8 * best5 / weightKg + 7
    var spread = estimated ? 0.15 : 0.10
    return { value: Math.round(v), low: Math.round(v * (1 - spread)), high: Math.round(v * (1 + spread)) }
}

// how fast fitness rises: the change of CTL over the last 7 days (series: Fitness.series, a day
// each). A rise of more than 8 a week is a build too steep to keep for long.
function rampRate(series) {
    var n = series.length
    if (n < 8)
        return null
    var change = series[n - 1].ctl - series[n - 8].ctl
    return { perWeek: Math.round(change * 10) / 10, steep: change > 8 }
}

// time at each cadence band while pedaling: [{ label, share }] (share 0 to 1)
function cadenceProfile(cadence) {
    var bands = [[0, 60, "< 60"], [60, 75, "60–75"], [75, 85, "75–85"], [85, 95, "85–95"], [95, 105, "95–105"], [105, 999, "105+"]]
    var counts = [0, 0, 0, 0, 0, 0]
    var total = 0
    for (var i = 0; i < cadence.length; i++) {
        var c = cadence[i] || 0
        if (c <= 0)
            continue
        total++
        for (var b = 0; b < bands.length; b++)
            if (c >= bands[b][0] && c < bands[b][1]) {
                counts[b]++
                break
            }
    }
    if (total < 300)
        return []
    return bands.map(function (band, j) { return { label: band[2], share: counts[j] / total } })
}

// a steady ride, the only kind decoupling says something about: 40 minutes or more, and normalized
// power close to the average (a variability index of 1.06 or less)
function steady(ride) {
    return (ride.duration || 0) >= 40 * 60 && ride.avgPower > 0 && ride.np > 0 && ride.np / ride.avgPower <= 1.06
}
