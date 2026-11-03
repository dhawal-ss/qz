.pragma library

// Fitness, fatigue and form from the training load (TSS) of every day, as in the performance
// manager charts of other training apps:
//   fitness (CTL)  the daily load averaged over about 42 days, recent days weighing more:
//                  every day, fitness += (load of the day - fitness) / 42
//   fatigue (ATL)  the same over 7 days
//   form (TSB)     fitness minus fatigue of the day before: how fresh the legs are today
// Both start at 0 on the first day given; days before the first ride add nothing, so that is the
// same as starting at 0 on the first ride. Days are stepped as dates at noon: the JavaScript
// engine of Qt 5 can read local midnight of a DST change as 23:00 of the day before.

var fitnessDays = 42
var fatigueDays = 7

function noon(ms) {
    var d = new Date(ms)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12)
}

function keyOf(date) {
    return date.getFullYear() * 10000 + date.getMonth() * 100 + date.getDate()
}

// days: the list of library.days() (each day at local midnight); firstMs, lastMs: the first and
// the last day to work out. Returns one entry a day: noon of the day, its load, fitness, fatigue
// and form.
function series(days, firstMs, lastMs) {
    var load = {}
    for (var i = 0; i < days.length; i++) {
        var key = keyOf(new Date(days[i].day + 12 * 3600000))
        load[key] = (load[key] || 0) + (days[i].tss || 0)
    }
    var out = []
    var first = noon(firstMs)
    var last = keyOf(noon(lastMs))
    var ctl = 0
    var atl = 0
    for (var n = 0; n < 5000; n++) {
        var date = new Date(first.getFullYear(), first.getMonth(), first.getDate() + n, 12)
        var key2 = keyOf(date)
        if (key2 > last)
            break
        var tss = load[key2] || 0
        var form = ctl - atl
        ctl += (tss - ctl) / fitnessDays
        atl += (tss - atl) / fatigueDays
        out.push({ day: date.getTime(), tss: tss, ctl: ctl, atl: atl, tsb: form })
    }
    return out
}

// What the form of today means, by its value (TSB):
//   above 25        very fresh: rested for long, fitness starts to fade
//   5 to 25         fresh: ready for a hard day or an event
//   -10 to 5        steady: training and recovering in balance
//   -30 to -10      building: the load that raises fitness
//   below -30       overreaching: more load than the legs can take for long
// With almost no fitness yet (under 5) there is nothing to read: "start". The screen words each key.
function formLabel(ctl, tsb) {
    if (ctl < 5)
        return "start"
    if (tsb > 25)
        return "veryFresh"
    if (tsb >= 5)
        return "fresh"
    if (tsb > -10)
        return "steady"
    if (tsb > -30)
        return "building"
    return "overreaching"
}

// "rising", "falling" or "steady": fitness of the last entry against two weeks before
function trend(list) {
    if (list.length < 2)
        return "steady"
    var now = list[list.length - 1].ctl
    var before = list[Math.max(0, list.length - 15)].ctl
    if (now - before > 1.5)
        return "rising"
    if (before - now > 1.5)
        return "falling"
    return "steady"
}
