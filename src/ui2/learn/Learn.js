.pragma library
.import "../Format.js" as Format

// Tap to learn: a plain-language page for every chart and number of the app. Each entry has
//   title    what it is called (a jargon word comes once, with its plain name: "Training load (TSS)")
//   what     one line on what it is
//   yours    what the rider's own numbers say, worked out from facts the screen passes in;
//            without data it says what it will show after the first rides
//   why      why it matters, in one sentence
//   tryThis  one thing to try
//   related  ids of other entries the sheet links to
// entry(id, facts) never returns empty strings: a fact that is missing falls back to plain words.

var ids = ["readiness", "fitness", "fatigue", "form", "tss", "week", "usual", "whenbest", "mix", "reach", "bests",
           "lifetime", "heatmap", "period", "ftp", "curve", "volume", "year", "consistency", "streak", "freezes",
           "records", "compare", "rideusual", "ridechart", "record", "effort", "time", "work", "distance", "avgpower",
           "np", "if", "avghr", "cadence", "speed", "level", "zones", "ridecurve", "changes", "decoupling", "ef",
           "workblocks", "challenge", "journey", "badges", "ladders", "recap"]

function has(v) {
    return v !== undefined && v !== null && !isNaN(v)
}

function round(v) {
    return Math.round(v || 0)
}

function signed(v) {
    var r = Math.round(v || 0)
    return r > 0 ? "+" + r : String(r)
}

function hm(seconds) {
    return Format.hours(seconds || 0)
}

function percent(part, whole) {
    return whole > 0 ? Math.round(100 * part / whole) : 0
}

function weeksText(days) {
    var w = Math.max(1, Math.round((days || 28) / 7))
    return w === 1 ? qsTr("a week") : qsTr("%1 weeks").arg(w)
}

// the plain words of a form band (progress/Fitness.js formLabel)
function bandWords(state) {
    var words = {
        veryFresh: qsTr("very fresh. You are well rested, and fitness starts to fade if it lasts."),
        fresh: qsTr("fresh, ready for a hard day or an event."),
        steady: qsTr("steady, training and recovering in balance."),
        building: qsTr("building: this is the load that raises fitness."),
        overreaching: qsTr("more load than your legs can take for long. Time for easy days.")
    }
    return words[state] || qsTr("not shown yet: it needs a few weeks of riding to read from.")
}

// how hard a ride was, from its intensity factor
function intensityWords(v) {
    if (v < 0.75)
        return qsTr("an easy ride")
    if (v < 0.85)
        return qsTr("a steady endurance ride")
    if (v < 0.95)
        return qsTr("a solid tempo ride, comfortably hard")
    if (v < 1.05)
        return qsTr("right at your threshold, hard work")
    return qsTr("above threshold, the kind of effort you hold only for a short while")
}

function loadWords(v) {
    if (v < 50)
        return qsTr("an easy day, recovered by tomorrow")
    if (v < 100)
        return qsTr("a solid day of work")
    if (v < 200)
        return qsTr("a big day, you may feel it tomorrow")
    return qsTr("a very big day, give it a couple of easy days")
}

function make(title, what, yours, why, tryThis, related) {
    return { title: title, what: what, yours: yours, why: why, tryThis: tryThis, related: related || [] }
}

function entry(id, facts) {
    var f = facts || {}
    var first = f.rides > 0 ? qsTr("Not enough rides here yet to say. It fills in as you ride.")
                            : qsTr("After your first ride, this shows your own numbers.")
    var e = null

    if (id === "readiness") {
        var readyYours
        if (f.hasForm)
            readyYours = qsTr("You are at %1 of 100. Your form is %2%3: %4")
                .arg(round(f.ready)).arg(signed(f.tsb))
                .arg(f.recent ? " " + qsTr("after %1").arg(f.recent) : "").arg(bandWords(f.state))
        else if (f.rides > 0)
            readyYours = qsTr("Your number shows after a few weeks of riding. Until then the circle shows your week: %1.").arg(f.weekText || qsTr("this week so far"))
        else
            readyYours = qsTr("After your first rides this becomes your daily number. Until then the circle shows your week against your goal.")
        e = make(qsTr("Readiness"),
                 qsTr("One number from 5 to 100 for how ready your legs are today, worked out from the riding of the last weeks."),
                 readyYours,
                 qsTr("Hard days land best on fresh legs, and easy days let the work sink in."),
                 f.state === "fresh" || f.state === "veryFresh" ? qsTr("You are fresh: today is a good day for your hardest ride of the week.")
                 : (f.state === "building" || f.state === "overreaching" ? qsTr("Under 50 for a few days? Swap in an easy spin and watch it climb.")
                                                                          : qsTr("Check it before you ride and let it pick hard or easy for you.")),
                 ["form", "fitness", "fatigue"])
    } else if (id === "fitness") {
        var c = f.change || 0
        var fitYours
        if (!has(f.ctl) || f.ctl < 1)
            fitYours = f.rides > 0 ? qsTr("Your fitness is just getting started. A few weeks of regular riding and it starts to climb.") : first
        else if (c > 8)
            fitYours = qsTr("Your fitness rose %1 in %2 to %3. A big climb: keep an eye on how tired you feel.").arg(round(c)).arg(weeksText(f.days)).arg(round(f.ctl))
        else if (c >= 2)
            fitYours = qsTr("Your fitness rose %1 in %2 to %3, that is a healthy climb.").arg(round(c)).arg(weeksText(f.days)).arg(round(f.ctl))
        else if (c > -2)
            fitYours = qsTr("Your fitness is holding steady at %1 over %2.").arg(round(f.ctl)).arg(weeksText(f.days))
        else
            fitYours = qsTr("Your fitness eased %1 in %2 to %3. A few steady weeks bring it back.").arg(round(-c)).arg(weeksText(f.days)).arg(round(f.ctl))
        e = make(qsTr("Fitness"),
                 qsTr("How much riding your body is used to: the load of your rides, averaged over about six weeks."),
                 fitYours,
                 qsTr("Fitness rises slowly and fades slowly, so it shows whether your weeks are adding up."),
                 qsTr("Aim for a gentle climb of 3 to 6 a month: steady weeks beat one huge week."),
                 ["fatigue", "form", "tss"])
    } else if (id === "fatigue") {
        var fatYours
        if (!has(f.atl) || (f.atl < 1 && (f.ctl || 0) < 1))
            fatYours = f.rides > 0 ? qsTr("Your fatigue is low: your legs have had plenty of rest.") : first
        else if (f.atl > f.ctl + 10)
            fatYours = qsTr("Your fatigue is %1, well above your fitness of %2: you have trained hard this week.").arg(round(f.atl)).arg(round(f.ctl))
        else if (f.atl < f.ctl - 10)
            fatYours = qsTr("Your fatigue is %1, below your fitness of %2: your legs have had time to recover.").arg(round(f.atl)).arg(round(f.ctl))
        else
            fatYours = qsTr("Your fatigue is %1, close to your fitness of %2: a balanced week.").arg(round(f.atl)).arg(round(f.ctl))
        e = make(qsTr("Fatigue"),
                 qsTr("How tired your legs are from the last week: the load of your rides, averaged over about seven days."),
                 fatYours,
                 qsTr("Fatigue rises fast and falls fast. It is the price of training, and it pays out as fitness."),
                 qsTr("After two or three hard days, one easy day brings it down quickly."),
                 ["fitness", "form"])
    } else if (id === "form") {
        e = make(qsTr("Form"),
                 qsTr("Fitness minus fatigue: above zero you are fresh, below zero you are carrying work."),
                 has(f.tsb) && f.state && f.state !== "start" ? qsTr("Your form is %1: %2").arg(signed(f.tsb)).arg(bandWords(f.state))
                                                             : (f.rides > 0 ? qsTr("Your form shows once there is some fitness to read it from, after a few weeks of riding.") : first),
                 qsTr("It tells you when to push and when to back off."),
                 qsTr("Plan your big efforts for days when form is between 5 and 25."),
                 ["fitness", "fatigue", "readiness"])
    } else if (id === "tss") {
        e = make(qsTr("Training load (TSS)"),
                 qsTr("How much a ride asked of you, from how long and how hard it was. An hour flat out at your limit is about 100."),
                 has(f.tss) && f.tss > 0 ? qsTr("This ride was %1%2: %3.").arg(round(f.tss)).arg(f.estimated ? " " + qsTr("(estimated)") : "").arg(loadWords(f.tss))
                                         : qsTr("Every ride gets a load. Added up day by day they make your fitness and your fatigue."),
                 qsTr("The load of every ride adds up to your fitness, and to how tired you feel."),
                 qsTr("Mix a few big days with plenty of small ones."),
                 ["fitness", "if", "np"])
    } else if (id === "week") {
        var weekYours
        if (f.rodeDays > 0)
            weekYours = (f.rodeDays === 1 ? qsTr("1 day ridden so far: %1.") : qsTr("%1 days ridden so far: %2.").arg(f.rodeDays)).arg(f.goalText || "")
                        + (f.met ? " " + qsTr("Goal met, everything else is extra.") : "")
        else
            weekYours = f.goalText ? qsTr("Nothing ridden yet this week. Your goal: %1.").arg(f.goalText) : qsTr("Nothing ridden yet this week.")
        e = make(qsTr("Your week"),
                 qsTr("Each day of this week as a shape in the color of its main effort. A dot is a day off, a dashed ring is today, still to ride."),
                 weekYours,
                 qsTr("Seeing the week at a glance makes it easy to spread hard and easy days."),
                 qsTr("Try not to put two spiky, hard shapes side by side."),
                 ["zones", "usual", "streak"])
    } else if (id === "usual") {
        var usualYours
        if (f.sample || !(f.usualSeconds > 0))
            usualYours = f.sample ? qsTr("After a couple of weeks of riding, this shows your week against your own usual week.")
                                  : qsTr("Ride for a couple of weeks and your usual shows here.")
        else {
            var ratio = (f.weekSeconds || 0) / f.usualSeconds
            if (ratio > 1.15)
                usualYours = qsTr("Ahead of your usual: %1 so far against %2 by %3.").arg(hm(f.weekSeconds)).arg(hm(f.usualSeconds)).arg(f.dayName || qsTr("today"))
            else if (ratio < 0.85)
                usualYours = qsTr("A lighter week so far: %1 against a usual %2 by %3. There is plenty of week left.").arg(hm(f.weekSeconds)).arg(hm(f.usualSeconds)).arg(f.dayName || qsTr("today"))
            else
                usualYours = qsTr("Right on your usual: %1 so far against %2 by %3.").arg(hm(f.weekSeconds)).arg(hm(f.usualSeconds)).arg(f.dayName || qsTr("today"))
        }
        e = make(qsTr("This week vs your usual"),
                 qsTr("This week so far, next to your average of the last 8 weeks at the same point of the week. The line on each bar is your usual."),
                 usualYours,
                 qsTr("Your own usual is the fairest yardstick: it shows a change before your fitness does."),
                 qsTr("Keep most weeks within a fifth of your usual, and grow it slowly."),
                 ["volume", "week", "fitness"])
    } else if (id === "whenbest") {
        e = make(qsTr("When you ride best"),
                 qsTr("Which days and times of day your strongest rides happen, from your rides of the last six months. The bright part of each bar is your strongest rides."),
                 !f.sample && f.dayName ? qsTr("Your strongest rides land on %1s, most often in the %2.").arg(f.dayName).arg(f.slotName || qsTr("evening"))
                                        : qsTr("After about ten rides this shows the days and times you ride strongest."),
                 qsTr("Putting your hardest ride where you are usually strongest makes it more likely to go well."),
                 !f.sample && f.dayName ? qsTr("Plan your next hard ride for a %1 %2.").arg(f.dayName).arg(f.slotName || "")
                                        : qsTr("Ride at the times that suit you; the pattern finds itself."),
                 ["mix", "records", "readiness"])
    } else if (id === "mix") {
        var mixYours
        var total = (f.easy || 0) + (f.moderate || 0) + (f.hard || 0)
        if (f.sample || total <= 0)
            mixYours = f.sample ? qsTr("After your first rides this shows how your time splits into easy, moderate and hard.")
                                : qsTr("No rides in the last 30 days. One ride and the ring fills in.")
        else {
            var e1 = percent(f.easy, total), m1 = percent(f.moderate, total), h1 = percent(f.hard, total)
            if (e1 >= 70)
                mixYours = qsTr("Mostly easy: %1% easy, %2% hard. A strong base; one harder ride a week would sharpen it.").arg(e1).arg(h1)
            else if (h1 >= 30)
                mixYours = qsTr("%1% of your time was hard. That is a lot: more easy time helps it pay off.").arg(h1)
            else if (m1 >= 50)
                mixYours = qsTr("Most of your time is moderate (%1%). Many riders improve faster with easier easy days and harder hard days.").arg(m1)
            else
                mixYours = qsTr("A good spread: %1% easy, %2% moderate, %3% hard.").arg(e1).arg(m1).arg(h1)
        }
        e = make(qsTr("Effort mix"),
                 qsTr("Your riding time of the last 30 days split into easy, moderate and hard, by how hard each ride was."),
                 mixYours,
                 qsTr("Most fitness comes from lots of easy riding plus a little hard work."),
                 qsTr("Aim for about four fifths easy and one fifth moderate or hard."),
                 ["zones", "if", "whenbest"])
    } else if (id === "reach") {
        e = make(qsTr("Record within reach"),
                 qsTr("A best effort your latest ride came close to, and what it would take to beat it."),
                 has(f.target) && f.effort ? qsTr("Your %1 best is %2 W. Hold %3 W for %1 and it is yours.").arg(f.effort).arg(round(f.current)).arg(round(f.target))
                                           : qsTr("When a ride comes close to a record, it shows here with the number to beat."),
                 qsTr("Records you can almost touch are the ones worth chasing on fresh legs."),
                 qsTr("Go for it on a day your readiness is over 73."),
                 ["bests", "records", "readiness"])
    } else if (id === "bests") {
        var parts = []
        if (f.b5 > 0)
            parts.push(qsTr("%1 W for 5 seconds").arg(round(f.b5)))
        if (f.b300 > 0)
            parts.push(qsTr("%1 W for 5 minutes").arg(round(f.b300)))
        if (f.b1200 > 0)
            parts.push(qsTr("%1 W for 20 minutes").arg(round(f.b1200)))
        e = make(qsTr("Best power"),
                 qsTr("The most power you have ever held for 5 seconds, 1, 5 and 20 minutes."),
                 parts.length > 0 ? qsTr("Your bests: %1.").arg(parts.join(", ")) : first,
                 qsTr("Short bests show your punch, long bests your engine. Each one grows in its own way."),
                 qsTr("Tap a number to open the ride that set it."),
                 ["curve", "records", "ftp"])
    } else if (id === "lifetime") {
        e = make(qsTr("All your rides"),
                 qsTr("Everything you have ridden, and the next milestone of the distance ladder."),
                 f.rides > 0 ? qsTr("%1 rides and %2 in the saddle.").arg(round(f.rides)).arg(hm(f.seconds))
                               + (f.nextText ? " " + f.nextText : "") : first,
                 qsTr("Big totals are built one ordinary ride at a time."),
                 qsTr("Pick a journey on Goals and ride it across a map."),
                 ["ladders", "journey", "heatmap"])
    } else if (id === "heatmap") {
        e = make(qsTr("Your year"),
                 qsTr("Every day of the last year as a square: the brighter it is, the more you rode that day."),
                 f.rideDays > 0 ? qsTr("You rode on %1 days in the last year.").arg(round(f.rideDays)) : first,
                 qsTr("Gaps and runs show up at once, long before they show in your fitness."),
                 qsTr("Tap a day to open its ride."),
                 ["consistency", "streak", "year"])
    } else if (id === "period") {
        e = make(qsTr("This period"),
                 qsTr("What the period you picked means, in one sentence, from your fitness and form."),
                 f.headline ? f.headline + (f.line ? " " + f.line : "") : first,
                 qsTr("A trend over weeks says more than any single ride."),
                 qsTr("Switch between 4 weeks, 3 months and 1 year to see short and long trends."),
                 ["fitness", "form", "volume"])
    } else if (id === "ftp") {
        var ftpYours = first
        if (f.current > 0) {
            ftpYours = qsTr("Your estimate is %1 W").arg(round(f.current))
            if (f.firstValue > 0 && round(f.current) !== round(f.firstValue))
                ftpYours += qsTr(", %1 %2 W since %3").arg(f.current > f.firstValue ? qsTr("up") : qsTr("down"))
                    .arg(Math.abs(round(f.current) - round(f.firstValue))).arg(f.sinceText || qsTr("the start of the period"))
            ftpYours += "."
            if (f.setting > 0 && Math.abs(f.setting - f.current) >= 5)
                ftpYours += " " + qsTr("Your FTP setting is %1 W: zones are cut from the setting.").arg(round(f.setting))
        }
        e = make(qsTr("FTP"),
                 qsTr("Functional threshold power: about the most power you could hold for an hour. Your zones are cut from it."),
                 ftpYours,
                 qsTr("When FTP rises, everything from your easy pace to your hardest efforts gets faster."),
                 qsTr("A hard 20 minute effort every month or two keeps the estimate honest."),
                 ["zones", "curve", "if"])
    } else if (id === "curve") {
        var curveYours = first
        if (f.w300 > 0) {
            curveYours = qsTr("Your best 5 minutes this period is %1 W").arg(round(f.w300))
            if (f.prior300 > 0) {
                var d = Math.round(100 * (f.w300 - f.prior300) / f.prior300)
                curveYours += d === 0 ? qsTr(", the same as the period before.") : (d > 0 ? qsTr(", %1% above the period before.").arg(d) : qsTr(", %1% under the period before.").arg(-d))
            } else
                curveYours += "."
        }
        e = make(qsTr("Power curve"),
                 qsTr("Your best power for every length of effort, from a 5 second sprint to an hour, next to the period before."),
                 curveYours,
                 qsTr("Where the curve rises tells you what your training is improving."),
                 qsTr("Hold and drag across the chart to read any length."),
                 ["bests", "records", "ftp"])
    } else if (id === "volume") {
        var volYours = first
        if (f.lastText) {
            volYours = qsTr("Last week: %1").arg(f.lastText)
            if (f.avgText)
                volYours += f.last > f.avg * 1.05 ? qsTr(", over your 4 week average of %1.").arg(f.avgText)
                          : (f.last < f.avg * 0.95 ? qsTr(", under your 4 week average of %1.").arg(f.avgText) : qsTr(", right on your 4 week average."))
            else
                volYours += "."
        }
        e = make(qsTr("Weekly volume"),
                 qsTr("How much you rode each week, with a line for your 4 week average."),
                 volYours,
                 qsTr("Steady volume builds fitness; sudden jumps are what wear you out."),
                 qsTr("Grow your weeks by no more than about a tenth at a time."),
                 ["usual", "fitness", "year"])
    } else if (id === "year") {
        e = make(qsTr("Your year in one picture"),
                 qsTr("Your riding time in each of the last 12 months, with your biggest month lit up."),
                 f.bestMonth ? qsTr("%1 was your biggest month, with %2. %3 across the year.").arg(f.bestMonth).arg(hm(f.bestSeconds)).arg(hm(f.totalSeconds)) : first,
                 qsTr("The seasons show here: the months you build, and the months life gets in the way."),
                 f.bestMonth ? qsTr("Pick a month ahead to match %1, and plan your weeks for it.").arg(f.bestMonth)
                             : qsTr("Ride a little most weeks and the year fills in."),
                 ["volume", "consistency", "heatmap"])
    } else if (id === "consistency") {
        e = make(qsTr("Consistency"),
                 qsTr("Each square is a day of the last 52 weeks; filled squares are days you rode."),
                 f.activeWeeks > 0 ? qsTr("You rode in %1 of the last 52 weeks.").arg(round(f.activeWeeks)) : first,
                 qsTr("Showing up week after week matters more than any one big ride."),
                 qsTr("Even a 20 minute spin keeps a week alive."),
                 ["streak", "freezes", "heatmap"])
    } else if (id === "streak") {
        e = make(qsTr("Streak"),
                 qsTr("How many weeks in a row you have met your weekly goal."),
                 f.streak > 0 ? (f.streak === 1 ? qsTr("1 week at your goal so far.") : qsTr("%1 weeks in a row at your goal.").arg(round(f.streak)))
                                + (f.goalText ? " " + qsTr("Your goal: %1 a week.").arg(f.goalText) : "")
                              : qsTr("Meet your weekly goal this week and your streak starts."),
                 qsTr("A streak turns riding into a habit, and habits outlast motivation."),
                 qsTr("Set a goal you can meet even in a busy week."),
                 ["freezes", "consistency", "week"])
    } else if (id === "freezes") {
        e = make(qsTr("Freezes"),
                 qsTr("A freeze saves your streak in a week you miss your goal. You earn one for every 4 goal weeks and can keep 2."),
                 (f.freezes === 1 ? qsTr("You have 1 freeze saved.") : qsTr("You have %1 freezes saved.").arg(round(f.freezes)))
                 + (f.toNext > 0 ? " " + (f.toNext === 1 ? qsTr("1 more goal week earns the next.") : qsTr("%1 more goal weeks earn the next.").arg(round(f.toNext))) : ""),
                 qsTr("A missed week should not wipe out months of good work."),
                 qsTr("Going away? Mark the week as a rest week on Goals and keep your freezes."),
                 ["streak", "consistency"])
    } else if (id === "records") {
        e = make(qsTr("Records"),
                 qsTr("Your best ever at each length of effort, and your biggest rides and weeks, with how long each has stood."),
                 f.newest ? qsTr("Your newest record is your %1, set %2.").arg(f.newest).arg(f.when || qsTr("recently")) : first,
                 qsTr("Records mark progress you can feel, not just see in a chart."),
                 qsTr("Tap a record to see every time it was beaten."),
                 ["bests", "curve", "reach"])
    } else if (id === "compare") {
        e = make(qsTr("Compare periods"),
                 qsTr("This week, month or year side by side with the one before."),
                 f.nowText ? qsTr("%1 this %2, against %3 last %2.").arg(f.nowText).arg(f.span || qsTr("month")).arg(f.beforeText || "0 min") : first,
                 qsTr("Side by side, small changes in your routine become easy to see."),
                 qsTr("Compare months to see whether a new routine is paying off."),
                 ["volume", "year"])
    } else if (id === "rideusual") {
        var rideParts = []
        if (f.usualSeconds > 0)
            rideParts.push(f.seconds > f.usualSeconds * 1.1 ? qsTr("longer than usual") : (f.seconds < f.usualSeconds * 0.9 ? qsTr("shorter than usual") : qsTr("about your usual length")))
        if (f.usualPower > 0 && f.power > 0)
            rideParts.push(f.power > f.usualPower * 1.05 ? qsTr("with more power") : (f.power < f.usualPower * 0.95 ? qsTr("with less power") : qsTr("at your usual power")))
        if (f.usualHeart > 0 && f.heart > 0)
            rideParts.push(f.heart > f.usualHeart + 3 ? qsTr("with a higher heart rate") : (f.heart < f.usualHeart - 3 ? qsTr("with a lower heart rate") : qsTr("with your usual heart rate")))
        var joined = rideParts.length > 1 ? rideParts.slice(0, rideParts.length - 1).join(", ") + " " + qsTr("and") + " " + rideParts[rideParts.length - 1]
                                          : rideParts.join("")
        var rideYours = rideParts.length > 0 ? qsTr("This ride was %1.").arg(joined) : qsTr("No rides in the 30 days before this one to compare with.")
        e = make(qsTr("This ride vs your usual"),
                 qsTr("This ride next to the average of your rides in the 30 days before it. The line on each bar is your usual."),
                 rideYours,
                 qsTr("Next to your own rides, what was different about today stands out."),
                 qsTr("More power at a lower heart rate than usual is a sign your fitness is growing."),
                 ["avgpower", "avghr", "ef"])
    } else if (id === "ridechart") {
        e = make(qsTr("Power across the ride"),
                 qsTr("Your power second by second, colored by zone, with your heart rate as a thin line over it. The shaded band is your best stretch."),
                 f.bestLabel && f.bestWatts > 0 ? qsTr("Your best %1 was %2 W.").arg(f.bestLabel).arg(round(f.bestWatts)) : qsTr("The shape of the ride: steady, surging, or fading at the end."),
                 qsTr("The shape shows how you paced it, which matters as much as the average."),
                 qsTr("Hold and drag to read any moment. Pinch to zoom; double tap to see the whole ride."),
                 ["zones", "np", "avghr"])
    } else if (id === "record") {
        e = make(qsTr("A new record"),
                 qsTr("Your best power ever for this length of effort."),
                 f.watts > 0 ? qsTr("%1 W for %2, up from %3 W.").arg(round(f.watts)).arg(f.effort || "").arg(round(f.previous)) : first,
                 qsTr("A record is proof that the work is working."),
                 qsTr("Records come on fresh legs: an easy day or two before helps the next one."),
                 ["records", "curve", "bests"])
    } else if (id === "effort") {
        e = make(qsTr("Best in 90 days"),
                 qsTr("The most power you held for this length in the last 90 days."),
                 f.watts > 0 ? qsTr("%1 W for %2, up from %3 W.").arg(round(f.watts)).arg(f.effort || "").arg(round(f.previous)) : first,
                 qsTr("Beating your recent self is the clearest sign of form."),
                 qsTr("Repeat this effort in a few weeks and see if it grows."),
                 ["ridecurve", "records", "curve"])
    } else if (id === "time") {
        e = make(qsTr("Ride time"),
                 qsTr("How long you rode, from start to finish."),
                 f.seconds > 0 ? qsTr("%1 on the bike.").arg(hm(f.seconds)) : first,
                 qsTr("Time in the saddle is the base everything else is built on."),
                 qsTr("One longer ride a week builds endurance faster than anything."),
                 ["work", "tss"])
    } else if (id === "work") {
        e = make(qsTr("Work (kJ)"),
                 qsTr("The energy you put into the pedals, in kilojoules. It is close to the food calories the ride burned."),
                 f.kj > 0 ? qsTr("%1 kJ%2: about %3 calories of food.").arg(Format.big(f.kj)).arg(f.estimated ? " " + qsTr("(estimated)") : "").arg(Format.big(f.kj)) : first,
                 qsTr("Work counts both how hard and how long, so it is fair to any kind of ride."),
                 qsTr("On rides over 90 minutes, eat as you go to keep the work coming."),
                 ["time", "avgpower", "tss"])
    } else if (id === "distance") {
        e = make(qsTr("Distance"),
                 qsTr("How far you would have gone on a road at the speed of the bike."),
                 f.distanceText ? qsTr("%1 on this ride.").arg(f.distanceText) : first,
                 qsTr("Distance makes rides easy to picture and to add up over a year."),
                 qsTr("Start a journey on Goals and ride your kilometers across a real map."),
                 ["speed", "journey"])
    } else if (id === "avgpower") {
        e = make(qsTr("Average power"),
                 qsTr("Your power in watts averaged over the whole ride, coasting included."),
                 f.power > 0 ? qsTr("%1 W on average%2.").arg(round(f.power)).arg(f.estimated ? " " + qsTr("(estimated)") : "") : first,
                 qsTr("Watts measure your effort directly, whatever the wind or the hill."),
                 qsTr("Compare it with rides of the same length to see your progress."),
                 ["np", "ftp", "zones"])
    } else if (id === "np") {
        var npYours = first
        if (f.np > 0) {
            var vi = f.power > 0 ? f.np / f.power : 1
            npYours = qsTr("%1 W against an average of %2 W: %3.").arg(round(f.np)).arg(round(f.power))
                .arg(vi < 1.05 ? qsTr("a steady, even ride") : (vi < 1.15 ? qsTr("some surges") : qsTr("plenty of surges and recoveries")))
        }
        e = make(qsTr("Normalized power (NP)"),
                 qsTr("What the ride felt like to your body: surges count for more than steady riding."),
                 npYours,
                 qsTr("Two rides with the same average can feel very different; this number tells them apart."),
                 qsTr("For endurance, keep it close to your average power by riding smoothly."),
                 ["avgpower", "if", "tss"])
    } else if (id === "if") {
        e = make(qsTr("Intensity factor (IF)"),
                 qsTr("How hard the ride was against your FTP. 1.00 means right at your threshold."),
                 f.value > 0 ? qsTr("%1: %2.").arg(Number(f.value).toFixed(2)).arg(intensityWords(f.value)) : first,
                 qsTr("It makes rides of different lengths easy to compare by how hard they were."),
                 qsTr("Easy rides under 0.75, hard sessions from 0.85 up: keep them apart."),
                 ["ftp", "np", "tss"])
    } else if (id === "avghr") {
        e = make(qsTr("Average heart rate"),
                 qsTr("How hard your heart worked, in beats a minute. It drifts up with heat, tiredness and coffee."),
                 f.heart > 0 ? qsTr("%1 bpm on average.").arg(round(f.heart)) + (f.usualHeart > 0 ? " " + qsTr("Your usual is %1 bpm.").arg(round(f.usualHeart)) : "") : first,
                 qsTr("The same power at a lower heart rate means you are getting fitter."),
                 qsTr("Ride steady rides at a heart rate you could still talk at."),
                 ["ef", "decoupling", "rideusual"])
    } else if (id === "cadence") {
        var cad = f.cadence || 0
        e = make(qsTr("Cadence"),
                 qsTr("How fast you pedal, in turns of the cranks a minute (rpm)."),
                 cad > 0 ? qsTr("%1 rpm on average: %2.").arg(round(cad)).arg(cad < 75 ? qsTr("on the slow side, pushing big gears")
                                                                            : (cad > 98 ? qsTr("quick and spinny") : qsTr("in the usual 80 to 95 range"))) : first,
                 qsTr("A smooth, steady cadence spares your legs for the end of the ride."),
                 qsTr("Try a few minutes at 100 rpm in an easy gear to make pedaling smoother."),
                 ["avgpower", "speed"])
    } else if (id === "speed") {
        e = make(qsTr("Speed"),
                 qsTr("How fast you would be going on a flat road. Indoors it comes from your power or the bike."),
                 f.distanceText ? qsTr("%1 ridden on this ride.").arg(f.distanceText) : first,
                 qsTr("Speed is easy to picture, but power says more about the effort."),
                 qsTr("Compare power, not speed, between different bikes."),
                 ["distance", "avgpower"])
    } else if (id === "level") {
        e = make(qsTr("Level"),
                 qsTr("The resistance level of the bike over the ride."),
                 qsTr("Higher levels push back harder: each step makes the same cadence take more power."),
                 qsTr("It shows how a workout or you changed the resistance along the way."),
                 qsTr("For a steady ride, pick one level and let cadence set the power."),
                 ["cadence", "avgpower"])
    } else if (id === "zones") {
        e = make(qsTr("Time in zones"),
                 qsTr("How long you spent in each of seven power zones, from Recovery to Sprint, cut from your FTP."),
                 f.topZone ? qsTr("Most of this ride was %1, %2% of the time.").arg(f.topZone).arg(round(f.topShare)) : qsTr("The color of each day and each part of a ride is its zone."),
                 qsTr("Each zone trains something different: easy zones build the engine, hard ones raise the ceiling."),
                 qsTr("Keep easy rides in the first two zones, even when you feel good."),
                 ["ftp", "mix", "if"])
    } else if (id === "ridecurve") {
        e = make(qsTr("Power curve of the ride"),
                 qsTr("This ride's best power at every length, next to your best of the 90 days before it."),
                 f.effort && f.watts > 0 ? qsTr("For %1 you held %2 W, against a 90 day best of %3 W.").arg(f.effort).arg(round(f.watts)).arg(round(f.prior))
                                         : qsTr("Where this ride's line touches the 90 day line, you matched your recent best."),
                 qsTr("It shows which kind of effort this ride trained: short punches or long steady power."),
                 qsTr("A ride that stays well under the line is a training day, not a test, and that is fine."),
                 ["curve", "records", "effort"])
    } else if (id === "changes") {
        e = make(qsTr("What changed"),
                 qsTr("This ride against the most similar ride you did before: about the same length and effort."),
                 f.count > 0 ? (f.count === 1 ? qsTr("One thing stood out against your similar ride.") : qsTr("%1 things stood out against your similar ride.").arg(f.count))
                             : qsTr("When you repeat a kind of ride, the differences show here."),
                 qsTr("Repeating a ride is the best test of progress: only you changed."),
                 qsTr("Ride the same workout once a month and watch this list."),
                 ["rideusual", "ef"])
    } else if (id === "decoupling") {
        var dec = f.value || 0
        e = make(qsTr("Decoupling"),
                 qsTr("How much your heart rate drifted up against your power from the first half of the ride to the second."),
                 has(f.value) ? (dec < 5 ? qsTr("%1%: under 5%, your aerobic engine held up well.").arg(dec.toFixed(1))
                                         : (dec < 10 ? qsTr("%1%: some drift. Longer steady rides will bring it down.").arg(dec.toFixed(1))
                                                     : qsTr("%1%: a big drift, from heat, tiredness or a ride longer than you are used to.").arg(dec.toFixed(1)))) : first,
                 qsTr("Little drift on long rides is the clearest sign of endurance."),
                 qsTr("Ride an hour steady at endurance pace and watch this number fall over the weeks."),
                 ["ef", "avghr"])
    } else if (id === "ef") {
        e = make(qsTr("Efficiency factor"),
                 qsTr("Normalized power divided by average heart rate: how many watts each heartbeat buys."),
                 has(f.value) ? qsTr("%1 on this ride. Compare it with similar rides: higher means fitter.").arg(Number(f.value).toFixed(2)) : first,
                 qsTr("When the same heart rate buys more watts, your aerobic fitness has grown."),
                 qsTr("Compare steady rides of the same length a month apart."),
                 ["decoupling", "avghr", "np"])
    } else if (id === "workblocks") {
        e = make(qsTr("Laps and work blocks"),
                 qsTr("Your laps as blocks: the hard efforts stand out from the easy parts between them."),
                 f.count > 0 ? (f.work ? qsTr("%1 work blocks in this ride.").arg(f.count) : qsTr("%1 laps in this ride.").arg(f.count)) : first,
                 qsTr("Even blocks mean even pacing; a fading last block means the first ones were too hard."),
                 qsTr("Tap a block to zoom the chart to it."),
                 ["ridechart", "zones"])
    } else if (id === "challenge") {
        e = make(qsTr("Monthly challenge"),
                 qsTr("A target for the month made from your own recent months, plus a tenth."),
                 f.targetText ? qsTr("%1 of %2 so far, %3.").arg(f.doneText || "0 min").arg(f.targetText).arg(f.daysLeftText || "")
                               + (f.paceText ? " " + f.paceText : "") : first,
                 qsTr("A target made from your own riding is hard enough to matter and close enough to reach."),
                 qsTr("Spread it out: a little each week beats a rush at the end."),
                 ["streak", "volume"])
    } else if (id === "journey") {
        e = make(qsTr("Journey"),
                 qsTr("Your kilometers laid along a real route, from the day you start it."),
                 f.name ? qsTr("%1: %2% of the way.").arg(f.name).arg(round(f.percent)) : qsTr("Pick a route and every ride moves you along it."),
                 qsTr("A far-off place makes ordinary rides add up to something you can picture."),
                 qsTr("Pick a route that takes a few months: long enough to matter."),
                 ["lifetime", "ladders"])
    } else if (id === "badges") {
        e = make(qsTr("Badges"),
                 qsTr("Marks for the things worth celebrating: records, streaks, journeys and challenges."),
                 f.total > 0 ? qsTr("%1 of %2 earned so far.").arg(round(f.earned)).arg(round(f.total)) : first,
                 qsTr("They remember the moments a chart forgets."),
                 qsTr("Tap a badge to see how it is earned and how close you are."),
                 ["records", "streak", "challenge"])
    } else if (id === "ladders") {
        e = make(qsTr("Ladders"),
                 qsTr("Lifetime totals of distance and work, with every rung on the way up."),
                 f.distanceText ? qsTr("%1 ridden so far. %2").arg(f.distanceText).arg(f.nextText || "") : first,
                 qsTr("Long-term totals reward every ride, even the short ones."),
                 qsTr("Check how far the next rung is and plan a long ride to cross it."),
                 ["lifetime", "journey"])
    } else if (id === "recap") {
        e = make(qsTr("Your week in review"),
                 qsTr("Last week as a short story: time, rides, your biggest ride, records and your goal."),
                 f.rides > 0 ? (f.rides === 1 ? qsTr("Last week: 1 ride, %1.").arg(hm(f.seconds)) : qsTr("Last week: %1 rides, %2.").arg(f.rides).arg(hm(f.seconds)))
                             : qsTr("Last week was a quiet one. This week is a fresh start."),
                 qsTr("A look back each Monday helps you plan the week ahead."),
                 qsTr("Open it every Monday and set one small aim for the week."),
                 ["streak", "usual"])
    }
    if (e === null)
        e = make(qsTr("About this"), qsTr("A picture of your riding."), first, qsTr("Your own numbers say more than any average."),
                 qsTr("Ride, then come back and see what changed."), [])
    e.id = id
    return e
}

// the title of an entry, for the related links
function titleOf(id) {
    return entry(id, {}).title
}
