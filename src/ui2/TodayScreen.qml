import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "calendar"
import "today"
import "goals"
import "learn"
import "Format.js" as Format
import "progress/Progress.js" as Progress
import "goals/Streak.js" as Streak
import "today/Insights.js" as Insights
import "today/Coach.js" as Coach
import "train/Levels.js" as Levels
import "train/Plans.js" as Plans
import "train/Ftp.js" as Ftp
import "today/Body.js" as Body
import "today/Patterns.js" as Patterns
import "progress/Fitness.js" as Fitness
import "learn/Learn.js" as Learn

// Home, in the Signature language, with one job: the ride. The title with the date under it and
// the bike as a chip (a tap opens bike setup), then the card to ride now (today/SuggestionCard.qml:
// Start ride, the form as a word, the idea for today as a smaller choice), then the week's one
// home (goals/WeekHome.qml: the week against the goal, the streak, Edit goal), and then quiet
// sections on hairlines that the rider can hide and reorder (Edit sections): insights, the latest
// ride, a record within reach, best power, this day last year, all the rides so far and the
// year, and three pictures of the rider: this week against the usual week, the effort mix of
// 30 days and when the rider rides best (today/Patterns.js). Everything rises in, one block after
// the other, each time the screen shows. A rider with no rides yet sees those pictures as
// samples in graphite, labelled "After your first ride".
// The goal setup, Taking a break and Welcome back open over Today (the shared goals model).
// Tap to learn: the form, the week, every picture and every section label open a Learn sheet
// (learn/LearnSheet.qml) that says what it is, what the rider's own numbers say, why it matters
// and one thing to try.
// On wide windows the two cards stay on the left and the rest goes to a right column.
// A ride paused and left shows as a slim banner under the date: how long ago, Resume and End.
Item {
    id: todayPage
    objectName: "todayScreen"

    property var library: null
    // the shared goals (goals/GoalsModel.qml), null in previews
    property var goals: null
    // rootItem, for Health Connect (null in previews)
    property var core: null
    // readiness from the body (today/Body.js): the rider said yes (ui2/healthRead) or not now
    // (ui2/healthDismissed), and the answer of the last read
    property bool healthAsked: false
    property bool healthDismissed: false
    property var bodyNow: null
    readonly property bool healthOffered: core !== null && !healthAsked && !healthDismissed && bikemodoBridge.healthAvailable()
    property bool connected: false
    property string deviceName: ""
    property string searchStatus: ""
    property bool miles: false
    property string nickname: ""
    property bool showYou: true
    property string initial: "B"
    // the end of the page the floating navigation covers: the content scrolls under it
    property real bottomClearance: 0
    // what a sheet keeps free at its end (the bottom inset; the shell binds it, the floating
    // navigation steps aside while a sheet covers the page)
    property real sheetClearance: 0
    // a live ride paused and left for the app, and when it was paused (ms)
    property bool ridePaused: false
    property real pausedAt: 0
    // now, for "paused 12 min ago": ticks while the banner shows
    property real pauseClock: Date.now()
    // an update from Google Play (main2.qml): "", "available", "downloading" or "downloaded"; the
    // banner offers it, shows the download and restarts into it. "start", "later" or "restart":
    property string updateShown: ""
    property real updateProgress: 0
    signal updateAction(string what)

    signal rideRequested()
    // Start on the idea for today: the plan (today/Coach.js plan()) as a workout
    signal workoutRequested(var plan)
    // End on the paused ride banner
    signal endRideRequested()
    signal demoRequested()
    signal searchAgain()
    signal openYou()
    // the bike chip: You, at bike setup
    signal openBike()
    signal openRide(int id)
    signal openTab(string name)
    // each time the screen shows: the blocks rise in again
    signal entered()

    readonly property var cardIds: ["usual", "insights", "latest", "mix", "reach", "bests", "whenbest", "onthisday", "lifetime", "year"]
    readonly property var cardTitles: ({
        usual: qsTr("This week vs your usual"),
        mix: qsTr("Effort mix"),
        whenbest: qsTr("When you ride best"),
        insights: qsTr("For you today"),
        latest: qsTr("Latest ride"),
        reach: qsTr("Record within reach"),
        bests: qsTr("Best power"),
        onthisday: qsTr("On this day"),
        lifetime: qsTr("All your rides"),
        year: qsTr("Your year")
    })
    property var cards: Progress.cardList("", cardIds)
    property bool customizing: false
    // the weekly goal as set on Goals, rules in goals/Streak.js
    property string goalKind: "minutes"
    property real goalValue: 120
    property var restWeeks: []
    property real weekValue: 0
    property int goalStreak: 0

    property var latest: null
    property var bests: []
    property var lifetime: ({})
    property int rideCount: 0
    // Insights.build()
    property var found: Insights.build({}, Date.now())
    // the insights no shown section already tells
    property var feed: []
    // the sections under the card, in order
    property var shownIds: ["first"]
    // Coach.readiness(), Coach.suggest(), Coach.weekDays()
    property var ready: Coach.readiness([], 0, Date.now())
    property var suggestion: Coach.suggest(ready, null, "")
    property bool swapped: false
    // the training levels (train/Levels.js), the plan under way (train/Plans.js, null for none) and
    // where it stands, and an FTP test result waiting for the rider (null for none)
    property var levels: ({})
    property var trainingPlan: null
    property var planState: null
    property var ftpTest: null
    // above the idea: the week and ride of the plan, else nothing ("Idea for today")
    property string kicker: ""
    property var weekDays: Coach.weekDays([], Date.now())
    // Patterns.usual(), Patterns.whenBest(), Patterns.mix(); samples for a rider with no rides
    property var usual: Patterns.usualSample()
    property var whenData: Patterns.whenSample()
    property var mixData: Patterns.mixSample()
    // Streak.run() of the weekly goal: the streak and the freezes
    property var streakInfo: ({ streak: 0, freezes: 0, toNextFreeze: 0 })

    // the Learn sheet: open, what it shows, and where its button leads ("" for none)
    property bool learnOpen: false
    property var learnEntry: null
    property string learnTab: ""
    readonly property var learnIds: ["readiness", "fitness", "fatigue", "form", "week", "usual", "whenbest", "mix", "reach",
                                     "bests", "lifetime", "heatmap", "streak", "freezes", "zones", "tss", "if"]
    // a sheet covers the page: the shell can move the navigation aside; a full page of the goals
    // covers the rail too
    readonly property bool fullPage: goals !== null && goals.weekPageOpen
    readonly property bool covering: customizing || learnOpen || fullPage

    readonly property var plan: swapped ? suggestion.other : suggestion.main
    readonly property bool formShown: ready.hasForm === true
    // where the bike is, for the ride card
    readonly property string bikeWords: connected ? (deviceName !== "" ? qsTr("%1 is connected.").arg(deviceName) : qsTr("Your bike is connected."))
                                                  : qsTr("Start ride finds your bike.")

    // A headline on two lines that read well: after a full stop when there is one in the middle,
    // else at the space nearest the middle. Plain string work, no patterns.
    function balanced(sentence) {
        var words = sentence.split(" ")
        if (words.length < 4)
            return sentence
        var stop = sentence.indexOf(". ")
        if (stop > 0 && stop < sentence.length - 3)
            return sentence.substring(0, stop + 1) + "\n" + sentence.substring(stop + 2)
        var middle = sentence.length / 2
        var best = -1
        for (var i = 0; i < sentence.length; i++)
            if (sentence.charAt(i) === " " && (best < 0 || Math.abs(i - middle) < Math.abs(best - middle)))
                best = i
        return best < 0 ? sentence : sentence.substring(0, best) + "\n" + sentence.substring(best + 1)
    }

    // the cards under the week on Today, at most
    readonly property int maxCards: 3

    function componentFor(cardId) {
        if (cardId === "first")
            return firstComponent
        if (cardId === "unlock")
            return unlockComponent
        if (cardId === "usual")
            return usualComponent
        if (cardId === "mix")
            return mixComponent
        if (cardId === "whenbest")
            return whenComponent
        if (cardId === "insights")
            return insightsComponent
        if (cardId === "latest")
            return latestComponent
        if (cardId === "reach")
            return reachComponent
        if (cardId === "bests")
            return bestsComponent
        if (cardId === "onthisday")
            return onThisDayComponent
        if (cardId === "lifetime")
            return lifetimeComponent
        return yearComponent
    }

    function goalWords() {
        if (goalKind === "rides")
            return goalValue === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(Math.round(goalValue))
        if (goalKind === "kj")
            return Format.big(goalValue) + " kJ"
        if (goalKind === "km")
            return Format.distance(goalValue, miles)
        return Math.round(goalValue) + " min"
    }

    // fitness and fatigue of today and four weeks before, from every day ridden
    function fitnessFacts(f) {
        var days = library ? library.days(0, 0) : []
        if (days.length === 0)
            return f
        var first = days[0].day
        for (var i = 1; i < days.length; i++)
            first = Math.min(first, days[i].day)
        var line = Fitness.series(days, first, Date.now())
        var last = line[line.length - 1]
        var before = line[Math.max(0, line.length - 29)]
        f.ctl = last.ctl
        f.atl = last.atl
        f.tsb = last.tsb
        f.state = Fitness.formLabel(last.ctl, last.tsb)
        f.change = last.ctl - before.ctl
        f.days = Math.min(28, line.length - 1)
        return f
    }

    // what the Learn sheet of an entry says about this rider
    function factsFor(id) {
        var f = { rides: rideCount, estimated: false }
        if (id === "readiness")
            return { rides: rideCount, hasForm: formShown, ready: ready.ready, word: ready.word, tsb: ready.tsb, recent: ready.recent,
                     state: Fitness.formLabel(ready.ctl, ready.tsb), weekText: Coach.goalText(weekValue, goalValue, goalKind, miles) }
        if (id === "fitness" || id === "fatigue" || id === "form")
            return fitnessFacts(f)
        if (id === "week") {
            var rode = 0
            for (var i = 0; i < weekDays.length; i++)
                if (weekDays[i].zone > 0)
                    rode++
            return { rides: rideCount, rodeDays: rode, goalText: Coach.goalText(weekValue, goalValue, goalKind, miles),
                     met: goalValue > 0 && weekValue >= goalValue - 1e-9 }
        }
        if (id === "usual") {
            var u = JSON.parse(JSON.stringify(usual))
            u.rides = rideCount
            u.sample = rideCount === 0
            return u
        }
        if (id === "whenbest")
            return { rides: rideCount, sample: rideCount === 0 || !whenData.enough,
                     dayName: whenData.bestDay >= 0 ? Patterns.dayName(whenData.bestDay) : "",
                     slotName: whenData.bestSlot >= 0 ? Patterns.slotNames[whenData.bestSlot] : "" }
        if (id === "mix")
            return { rides: rideCount, sample: rideCount === 0, easy: mixData.easy, moderate: mixData.moderate, hard: mixData.hard }
        if (id === "reach" && found.reach)
            return { rides: rideCount, effort: Format.effort(found.reach.seconds), target: found.reach.target, current: found.reach.best }
        if (id === "bests") {
            for (var b = 0; b < bests.length; b++)
                f["b" + bests[b].seconds] = bests[b].watts
            return f
        }
        if (id === "lifetime")
            return { rides: lifetime.rides || 0, seconds: lifetime.seconds || 0,
                     nextText: found.milestone ? qsTr("%1 to go to the next milestone.").arg(Format.distance(found.milestone.remaining, miles)) : "" }
        if (id === "heatmap")
            return { rides: rideCount, rideDays: library ? library.days(Date.now() - 365 * 86400000, 0).length : 0 }
        if (id === "streak")
            return { rides: rideCount, streak: streakInfo.streak, goalText: goalWords() }
        if (id === "freezes")
            return { rides: rideCount, freezes: streakInfo.freezes || 0, toNext: streakInfo.toNextFreeze || 0 }
        return f
    }

    // opens the Learn sheet of an entry with the rider's own numbers
    function openLearn(id) {
        learnEntry = Learn.entry(id, factsFor(id))
        learnTab = id === "lifetime" ? "progress" : ""
        learnOpen = true
    }

    // where an insight leads
    function act(action) {
        if (!action)
            return
        if (action.kind === "ride")
            rideRequested()
        else if (action.kind === "openRide")
            openRide(action.rideId)
        else if (action.kind === "tab" && action.tab === "goals")
            openLearn("streak")
        else if (action.kind === "tab")
            openTab(action.tab)
    }

    // open the first ride of a day
    function openDay(dayMs) {
        if (!library)
            return
        var list = library.rides(0, 5000)
        var day = Format.startOfDay(dayMs)
        for (var i = list.length - 1; i >= 0; i--)
            if (Format.startOfDay(list[i].start) === day) {
                openRide(list[i].id)
                return
            }
    }

    // Goals and Customize write these through their own Settings objects, and Qt.labs.settings
    // does not tell the others: read them again each time the screen shows
    // a plan under way puts its next ride in place of the coach's idea, and says where it is
    function applyPlan(recent, now) {
        kicker = ""
        planState = trainingPlan ? Plans.now(trainingPlan, recent, now, levels) : null
        if (planState === null)
            return
        if (planState.over) {
            kicker = qsTr("Plan done. Start another on Goals")
            return
        }
        if (planState.workout === null) {
            kicker = qsTr("This week of the plan is done")
            return
        }
        kicker = qsTr("Week %1 of %2 · ride %3 of %4").arg(planState.week + 1).arg(planState.weeks)
                 .arg(planState.done + 1).arg(planState.rides.length) + (planState.easy ? " · " + qsTr("easier week") : "")
        suggestion = { main: planState.workout, other: Coach.easySpin(), otherLabel: qsTr("Swap for an easy spin") }
    }

    // Health Connect: ask, then read; the answer comes back on Android's time
    function connectHealth() {
        uiStore.setValue("healthRead", true)
        healthAsked = true
        if (core !== null)
            bikemodoBridge.healthRequestRead()
        // the dialog takes a while: read once it has had time, and again when Today shows
        healthAgain.restart()
    }
    function readBody() {
        if (core === null)
            return
        bikemodoBridge.healthRefresh()
        healthWait = 20
        healthPoll.start()
    }
    property int healthWait: 0
    Timer {
        id: healthPoll
        interval: 500
        repeat: true
        onTriggered: {
            var text = todayPage.core !== null ? bikemodoBridge.healthTake() : ""
            if (text !== "") {
                stop()
                var o = Body.parse(text)
                todayPage.bodyNow = o && o.granted ? Body.today(o.days || [], Date.now()) : (o ? { state: "none", words: "", inputs: [], need: 0 } : null)
                todayPage.pushBody()
                refreshLater.restart()
            } else if (--todayPage.healthWait <= 0) {
                stop()
            }
        }
    }
    Timer {
        id: healthAgain
        interval: 8000
        onTriggered: todayPage.readBody()
    }

    // the widget's short line about the body today, or none while there is nothing to say
    function pushBody() {
        if (core === null || bodyNow === null)
            return
        var words = bodyNow.state === "good" ? qsTr("Well recovered")
                  : bodyNow.state === "normal" ? qsTr("Body as usual")
                  : bodyNow.state === "easy" ? qsTr("Take it easy today") : ""
        bikemodoBridge.updateWidgetBody(words)
    }

    // the body says take it easy: a recovery spin in place of a harder idea (a plan keeps its ride)
    function applyBody() {
        if (bodyNow === null || bodyNow.state !== "easy" || (planState !== null && planState.workout !== null))
            return
        if (suggestion.main.zone <= 1)
            return
        suggestion = { main: Coach.plan("recovery", qsTr("Recovery spin"), qsTr("Easy pedaling, legs only"), [[5, 1], [15, 1], [5, 1]]),
                       other: suggestion.main, otherLabel: qsTr("Ride %1 anyway").arg(suggestion.main.name) }
        kicker = qsTr("Your body says take it easy")
    }

    // The home screen widget and Monday's recap (BikemodoWidget.java): this week against the goal and
    // the streak, as of now. week: Streak.perWeek() of this week, or null
    function pushWidget(week, now) {
        if (core === null)
            return
        var value = Coach.goalText(weekValue, goalValue, goalKind, miles)
        var rides = week ? week.rides : 0
        var detail = rides === 0 ? qsTr("No rides yet this week")
                   : (rides === 1 ? qsTr("1 ride, %1").arg(Format.hours(week.seconds)) : qsTr("%1 rides, %2").arg(rides).arg(Format.hours(week.seconds)))
        var streak = goalStreak >= 2 ? qsTr("%1 week streak").arg(goalStreak) : ""
        var key = String(Streak.weekKey(now))
        var monday = key.substr(0, 4) + "-" + key.substr(4, 2) + "-" + key.substr(6, 2)
        var title = rides === 0 ? "" : qsTr("Your week: %1").arg(detail)
        var text = weekValue >= goalValue ? qsTr("Goal reached: %1.").arg(value) : qsTr("%1 of your weekly goal.").arg(value)
        if (streak !== "")
            text += " " + streak + "."
        bikemodoBridge.updateWidget(value, detail, streak, monday, title, text)
    }

    // the FTP test result: used, or let go
    function settleFtpTest(use) {
        if (use && ftpTest !== null) {
            Theme.setFtp(ftpTest.watts)
            uiStore.setValue("ftpTestedMs", Date.now())
        }
        uiStore.setValue("ftpTestResult", "")
        ftpTest = null
    }

    function readGoal() {
        if (goals !== null) {
            goalKind = goals.goalKind
            goalValue = goals.goalValue
            restWeeks = goals.restWeeks
            return
        }
        var kind = String(uiStore.value("goalKind", "minutes"))
        goalKind = Streak.kinds.indexOf(kind) >= 0 ? kind : "minutes"
        goalValue = Number(uiStore.value(Streak.settingKeys[goalKind], Streak.defaults[goalKind])) || Streak.defaults[goalKind]
        restWeeks = Streak.parseList(String(uiStore.value("restWeeks", "[]")))
    }

    function readSettings() {
        if (goals !== null)
            goals.readSettings()
        readGoal()
        levels = Levels.levels(Levels.parse(String(uiStore.value("workoutLog", "[]"))), Date.now())
        trainingPlan = Plans.parse(String(uiStore.value("trainingPlan", "")))
        healthAsked = String(uiStore.value("healthRead", "false")) === "true"
        healthDismissed = String(uiStore.value("healthDismissed", "false")) === "true"
        if (healthAsked && core !== null)
            readBody()
        try {
            var test = JSON.parse(String(uiStore.value("ftpTestResult", "")) || "null")
            ftpTest = test && test.watts > 0 ? test : null
        } catch (e) {
            ftpTest = null
        }
        var saved = Progress.cardList(String(uiStore.value("todayCards", "")), cardIds)
        if (Progress.cardJson(saved) !== Progress.cardJson(cards))
            cards = saved
    }

    function saveCards(list) {
        cards = list
        uiStore.setValue("todayCards", Progress.cardJson(list))
        layout()
    }

    function moveCard(from, to) {
        if (to < 0 || to >= cards.length)
            return
        var list = cards.slice()
        var moved = list.splice(from, 1)[0]
        list.splice(to, 0, moved)
        saveCards(list)
    }

    function showCard(cardId, shown) {
        var list = []
        for (var i = 0; i < cards.length; i++)
            list.push({ id: cards[i].id, shown: cards[i].id === cardId ? shown : cards[i].shown })
        saveCards(list)
    }

    // Android back closes the sheet first
    function goBack() {
        if (goals !== null && goals.goBackWeek())
            return true
        if (learnOpen) {
            learnOpen = false
            return true
        }
        if (customizing) {
            customizing = false
            return true
        }
        return false
    }

    function hasContent(cardId) {
        if (cardId === "latest")
            return latest !== null
        if (cardId === "reach")
            return found.reach !== null
        if (cardId === "bests")
            return bests.length > 0
        if (cardId === "onthisday")
            return found.onThisDay !== null
        if (cardId === "usual")
            return usual.weeks > 0
        if (cardId === "whenbest")
            return whenData.enough
        // easy, moderate and hard come from FTP: no mix until it is the rider's own
        if (cardId === "mix")
            return Theme.ftpSet && mixData.total > 0
        return true
    }

    // Which sections show, from the setting and the data. A new list rebuilds every section, so
    // only when it changed.
    function layout() {
        var ids = []
        // the coach line already welcomes the rider back
        // and the week's card the streak
        var told = ["welcome"].concat(found.goalStreak >= 2 ? ["streak"] : [])
        if (rideCount === 0) {
            // what fills in as the rider rides, as chips; the history being read in first
            ids = library && library.busy ? ["first", "unlock"] : ["unlock"]
        } else {
            // a calm page: the week, then the first three cards of the rider's order that have
            // something to say (Customize picks them)
            var others = 0
            for (var i = 0; i < cards.length; i++) {
                var cardId = cards[i].id
                if (!cards[i].shown || !hasContent(cardId))
                    continue
                if (others >= maxCards)
                    continue
                others++
                ids.push(cardId)
                if (cardId === "reach")
                    told.push("reach")
                else if (cardId === "onthisday")
                    told.push("onThisDay")
                else if (cardId === "lifetime")
                    told.push("milestone")
            }
        }
        feed = Insights.without(found.list, told)
        if (feed.length === 0 && ids.indexOf("insights") >= 0)
            ids.splice(ids.indexOf("insights"), 1)
        if (JSON.stringify(ids) !== JSON.stringify(shownIds))
            shownIds = ids
    }

    function refresh() {
        var now = Date.now()
        rideCount = library ? library.rideCount : 0
        if (rideCount === 0) {
            latest = null
            bests = []
            lifetime = {}
            weekValue = 0
            goalStreak = 0
            found = Insights.build({}, now)
            ready = Coach.readiness([], 0, now)
            suggestion = Coach.suggest(ready, null, "", levels)
            applyPlan([], now)
            applyBody()
            weekDays = Coach.weekDays([], now)
            usual = Patterns.usualSample()
            whenData = Patterns.whenSample()
            mixData = Patterns.mixSample()
            streakInfo = { streak: 0, freezes: 0, toNextFreeze: 0 }
            layout()
            return
        }
        // the insights look back a year and a day at most: 1000 rides cover that for anyone
        var recent = library.rides(0, 1000)
        latest = recent.length > 0 ? recent[0] : null
        var curve = library.powerCurve(0, 0)
        var want = [5, 60, 300, 1200]
        var picked = []
        for (var j = 0; j < want.length; j++)
            for (var k = 0; k < curve.length; k++)
                if (curve[k].seconds === want[j])
                    picked.push(curve[k])
        bests = picked
        lifetime = library.totals(0, 0)
        var allDays = library.days(0, 0)
        var weeks = Streak.perWeek(allDays)
        weekValue = Streak.measure(weeks[Streak.weekKey(now)], goalKind)
        streakInfo = Streak.run(weeks, { kind: goalKind, goal: goalValue, rest: restWeeks, now: now })
        goalStreak = streakInfo.streak
        pushWidget(weeks[Streak.weekKey(now)] || null, now)
        found = Insights.build({
            rides: recent,
            days: allDays,
            curveAll: curve,
            curveRecent: library.powerCurve(now - Insights.sixWeeks, 0),
            curvePrior: library.powerCurve(now - 2 * Insights.sixWeeks, now - Insights.sixWeeks),
            latestBest: latest ? (library.ride(latest.id).best || []) : [],
            lifetime: lifetime,
            goalStreak: goalStreak,
            miles: miles,
            ftpSet: Theme.ftpSet
        }, now)
        ready = Coach.readiness(allDays, latest ? latest.start : 0, now, Theme.ftpSet)
        // an FTP to offer while it is still the guess: 95% of the best 20 min of the last 90 days
        var best20 = 0
        if (!Theme.ftpSet) {
            var lately = library.powerCurve(now - 90 * 86400000, 0)
            for (var b = 0; b < lately.length; b++)
                if (lately[b].seconds === 1200)
                    best20 = lately[b].watts
        }
        ftpOffer = best20 > 0 ? Math.round(best20 * 0.95) : 0
        suggestion = Coach.suggest(ready, found.reach, found.reach ? Format.effort(found.reach.seconds) : "", levels)
        applyPlan(recent, now)
        applyBody()
        weekDays = Coach.weekDays(recent, now)
        usual = Patterns.usual(recent, now)
        whenData = Patterns.whenBest(recent, now)
        mixData = Patterns.mix(recent, now)
        layout()
    }

    onLibraryChanged: refresh()
    onMilesChanged: refreshLater.restart()
    Connections {
        target: Theme
        function onFtpSetChanged() { refreshLater.restart() }
    }
    onVisibleChanged: {
        if (!visible) {
            learnOpen = false
            return
        }
        readSettings()
        if (goals !== null)
            goals.refreshWeek()
        refresh()
        entered()
        if (goals !== null)
            goals.offer()
    }
    // a goal changed from the week's card: the week, the insights and the widget follow
    Connections {
        target: todayPage.goals
        ignoreUnknownSignals: true
        function onGoalValueChanged() { todayPage.readGoal(); refreshLater.restart() }
        function onGoalKindChanged() { todayPage.readGoal(); refreshLater.restart() }
        function onRestWeeksChanged() { todayPage.readGoal(); refreshLater.restart() }
    }
    Component.onCompleted: {
        readSettings()
        refresh()
    }
    // Today is on screen at launch, before the app's core is there: read the body, and refresh
    // for the home screen widget, once it is
    onCoreChanged: {
        if (core === null)
            return
        if (healthAsked)
            readBody()
        refreshLater.restart()
    }

    // the library tells about every ride it reads in: one refresh for a burst of them
    Timer {
        id: refreshLater
        interval: 300
        onTriggered: todayPage.refresh()
    }
    Connections {
        target: todayPage.library
        ignoreUnknownSignals: true
        function onChanged() { refreshLater.restart() }
    }

    Settings {
        id: uiStore
        category: "ui2"
    }

    Timer {
        interval: 15000
        repeat: true
        running: todayPage.ridePaused && todayPage.visible
        triggeredOnStart: true
        onTriggered: todayPage.pauseClock = Date.now()
    }

    // how long ago the ride was paused, as words: "12 min ago"
    readonly property int pausedMinutes: pausedAt > 0 ? Math.max(0, Math.floor((pauseClock - pausedAt) / 60000)) : 0
    readonly property string pausedAgo: {
        if (pausedMinutes < 1)
            return qsTr("Just now")
        if (pausedMinutes < 60)
            return qsTr("%1 min ago").arg(pausedMinutes)
        return qsTr("%1 ago").arg(Format.hours(pausedMinutes * 60))
    }
    // FTP worked out from the rides while the rider has not set one (Theme.ftpSet), 0 for none
    property int ftpOffer: 0
    readonly property bool askFtp: !Theme.ftpSet && rideCount > 0

    // a ride the app was closed or killed during, from QZ's backups: the banner offers to keep it
    readonly property var unfinished: library && library.unfinished && library.unfinished.seconds > 0 ? library.unfinished : null
    readonly property bool showRecover: unfinished !== null && !ridePaused
    // what the banner under the header is about: a paused ride first, then an unfinished one, then
    // an update ("" for none)
    readonly property string bannerKind: ridePaused ? "paused" : showRecover ? "recover" : updateShown !== "" ? "update" : ""
    readonly property string bannerTitle: bannerKind === "paused" ? qsTr("Ride paused")
        : bannerKind === "recover" ? qsTr("Unfinished ride")
        : updateShown === "downloaded" ? qsTr("Update ready")
        : updateShown === "downloading" ? qsTr("Updating Bikemodo")
        : qsTr("A new Bikemodo")
    readonly property string bannerWords: bannerKind === "paused" ? pausedAgo
        : bannerKind === "recover" ? unfinishedWords
        : updateShown === "downloaded" ? qsTr("Restart to finish. It takes a few seconds.")
        : updateShown === "downloading" ? qsTr("Downloading, %1%").arg(Math.round(updateProgress * 100))
        : qsTr("It downloads while you carry on.")
    readonly property string unfinishedWords: unfinished === null ? ""
        : qsTr("%1, %2. The app closed before it was saved.").arg(Format.hours(unfinished.seconds))
                                                                   .arg(Format.day(unfinished.start) + " " + Format.time(unfinished.start))

    // past the gap after which a new ride would start (ui2/mergeGapMinutes, 0 never merges), Resume
    // still goes on with this one: the banner says so. Read with value(), You may have changed it.
    readonly property bool pastMergeGap: {
        var ticking = pauseClock
        var gap = Number(uiStore.value("mergeGapMinutes", 10))
        return ridePaused && pausedMinutes > (isNaN(gap) ? 10 : gap)
    }

    Component {
        id: firstComponent
        FirstRideCard {
            busy: todayPage.library ? todayPage.library.busy : false
            indexed: todayPage.library ? todayPage.library.indexed : 0
            toIndex: todayPage.library ? todayPage.library.toIndex : 0
        }
    }
    // before the first ride: what fills in, and what it takes (the same rules as the cards)
    Component {
        id: unlockComponent
        Column {
            spacing: 12
            CapLabel {
                text: qsTr("Fills in as you ride")
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [
                        { name: qsTr("Your usual week"), when: qsTr("after your first full week") },
                        { name: qsTr("Effort mix"), when: Theme.ftpSet ? qsTr("after your first ride") : qsTr("once your FTP is set") },
                        { name: qsTr("Best days and times"), when: qsTr("after 8 rides") },
                        { name: qsTr("Best power"), when: qsTr("after your first ride") }
                    ]
                    Rectangle {
                        width: chipColumn.implicitWidth + 28
                        height: chipColumn.implicitHeight + 20
                        radius: 16
                        color: Theme.control
                        Accessible.role: Accessible.StaticText
                        Accessible.name: modelData.name + ", " + modelData.when
                        Column {
                            id: chipColumn
                            x: 14
                            y: 10
                            spacing: 2
                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(14)
                            }
                            Text {
                                text: modelData.when
                                color: Theme.text3
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.fs(12)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: usualComponent
        UsualCard {
            id: usualCard
            usual: todayPage.usual
            sample: todayPage.rideCount === 0
            onClicked: todayPage.openLearn("usual")
            Connections {
                target: todayPage
                function onEntered() { usualCard.grow() }
            }
        }
    }
    Component {
        id: mixComponent
        MixCard {
            id: mixCard
            mix: todayPage.mixData
            sample: todayPage.rideCount === 0
            onClicked: todayPage.openLearn("mix")
            Connections {
                target: todayPage
                function onEntered() { mixCard.play() }
            }
        }
    }
    Component {
        id: whenComponent
        WhenCard {
            id: whenCard
            when: todayPage.whenData
            sample: todayPage.rideCount === 0
            onClicked: todayPage.openLearn("whenbest")
            Connections {
                target: todayPage
                function onEntered() { whenCard.grow() }
            }
        }
    }
    Component {
        id: insightsComponent
        InsightsCard {
            insights: todayPage.feed
            onAct: todayPage.act(action)
        }
    }
    Component {
        id: latestComponent
        RideCard {
            label: qsTr("Latest ride")
            ride: todayPage.latest
            miles: todayPage.miles
            onOpenRide: todayPage.openRide(id)
        }
    }
    Component {
        id: reachComponent
        ReachCard {
            reach: todayPage.found.reach
            onRideRequested: todayPage.rideRequested()
            onOpenRide: todayPage.openRide(id)
            onLearn: todayPage.openLearn("reach")
        }
    }
    Component {
        id: bestsComponent
        BestsCard {
            bests: todayPage.bests
            estimated: todayPage.library !== null && todayPage.library.powerGroup === 1
            onOpenRide: todayPage.openRide(id)
            onLearn: todayPage.openLearn("bests")
        }
    }
    Component {
        id: onThisDayComponent
        RideCard {
            label: todayPage.found.onThisDay && todayPage.found.onThisDay.offset !== 0 ? qsTr("This time last year") : qsTr("On this day last year")
            ride: todayPage.found.onThisDay ? todayPage.found.onThisDay.ride : null
            miles: todayPage.miles
            lineColor: Theme.zoneColors[1]
            onOpenRide: todayPage.openRide(id)
        }
    }
    Component {
        id: lifetimeComponent
        LifetimeCard {
            lifetime: todayPage.lifetime
            milestone: todayPage.found.milestone
            miles: todayPage.miles
            onLearn: todayPage.openLearn("lifetime")
        }
    }
    Component {
        id: yearComponent
        Column {
            spacing: 8
            LearnLabel {
                x: -8
                caption: qsTr("Your year")
                onClicked: todayPage.openLearn("heatmap")
            }
            CalendarHeatmap {
                width: parent.width
                library: todayPage.library
                onDayClicked: todayPage.openDay(dayMs)
            }
        }
    }

    Flickable {
        id: flick
        objectName: "todayFlick"
        anchors.fill: parent
        contentHeight: content.height + todayPage.bottomClearance + 24
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: content
            readonly property real margin: todayPage.width < 400 ? 16 : 24
            readonly property bool wide: todayPage.width >= 720
            readonly property real leftWidth: wide ? Math.min(460, (width - 48) * 0.48) : width
            x: Math.max(margin, (todayPage.width - width) / 2)
            // one column keeps to a phone's measure, centered on a wider window
            width: Math.min(todayPage.width - margin * 2, wide ? 1120 : 560)
            height: Math.max(lead.y + lead.height, feedColumn.y + feedColumn.height)

            // the title and the date, and the bike as a chip on the title line: a tap opens bike setup
            Item {
                id: header
                width: content.width
                height: pageHeader.height
                PageHeader {
                    id: pageHeader
                    width: parent.width - bikeChip.width - 12
                    title: qsTr("Today")
                    subtitle: new Date().toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                }
                PulseButton {
                    id: bikeChip
                    objectName: "bikeChip"
                    anchors.right: parent.right
                    y: 22
                    width: Math.min(chipRow.implicitWidth + 28, 190)
                    height: 48
                    topInset: 4
                    bottomInset: 4
                    radius: 20
                    fill: pressed ? Theme.pressed : Theme.chip
                    Accessible.name: todayPage.connected ? qsTr("%1, connected. Bike setup").arg(bikeName.text) : qsTr("No bike connected. Bike setup")
                    onClicked: todayPage.openBike()
                    contentItem: Item {
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 7
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: todayPage.connected ? Theme.zoneColors[1] : Theme.text3
                            }
                            Text {
                                id: bikeName
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 140)
                                text: todayPage.connected ? (todayPage.deviceName !== "" ? todayPage.deviceName : qsTr("Bike ready")) : qsTr("No bike")
                                color: Theme.text
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.fs(13)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // the ride paused and left: back to it, or end it. Or a ride the app never saved: keep it,
            // or let it go. Or a new version from Play: get it, then restart into it
            Item {
                id: pausedBanner
                objectName: "pausedBanner"
                y: header.y + header.height + 4
                width: content.leftWidth
                height: todayPage.bannerKind !== "" ? bannerBody.height : 0
                visible: todayPage.bannerKind !== ""
                Rectangle {
                    id: bannerBody
                    width: parent.width
                    height: bannerColumn.height + 24
                    radius: 24
                    color: Theme.accentWash(0.10)
                    Column {
                        id: bannerColumn
                        x: 16
                        y: 12
                        width: parent.width - 28
                        spacing: 4
                        Item {
                            width: parent.width
                            height: Math.max(48, bannerWords.height)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: todayPage.bannerKind === "paused" ? Theme.recording : Theme.accent
                            }
                            Column {
                                id: bannerWords
                                x: 20
                                width: Math.max(0, bannerButtons.x - x - 10)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Accessible.role: Accessible.StaticText
                                Accessible.name: todayPage.bannerKind === "paused" ? qsTr("Ride paused %1").arg(todayPage.pausedAgo.toLowerCase())
                                                                                   : todayPage.bannerTitle + ". " + todayPage.bannerWords
                                Text {
                                    width: parent.width
                                    text: todayPage.bannerTitle
                                    color: Theme.text
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.fs(15)
                                    elide: Text.ElideRight
                                    Accessible.ignored: true
                                }
                                Text {
                                    width: parent.width
                                    text: todayPage.bannerWords
                                    color: Theme.text2
                                    font.family: Theme.bodyMedium
                                    font.pixelSize: Theme.fs(13)
                                    // the paused line is short; the others say what happened
                                    elide: todayPage.bannerKind === "paused" ? Text.ElideRight : Text.ElideNone
                                    wrapMode: todayPage.bannerKind === "paused" ? Text.NoWrap : Text.WordWrap
                                    Accessible.ignored: true
                                }
                            }
                            Row {
                                id: bannerButtons
                                x: parent.width - width
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                PulseButton {
                                    id: resumeButton
                                    width: resumeText.implicitWidth + 32
                                    height: 48
                                    topInset: 2
                                    bottomInset: 2
                                    pressedRadius: 14
                                    fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                                    // the download runs by itself: nothing to press meanwhile
                                    visible: todayPage.updateShown !== "downloading" || todayPage.bannerKind !== "update"
                                    Accessible.name: todayPage.bannerKind === "paused" ? qsTr("Resume your paused ride")
                                        : todayPage.bannerKind === "recover" ? qsTr("Keep the unfinished ride with your rides")
                                        : todayPage.updateShown === "downloaded" ? qsTr("Restart Bikemodo into the new version")
                                        : qsTr("Download the new version of Bikemodo")
                                    onClicked: {
                                        if (todayPage.bannerKind === "paused")
                                            todayPage.rideRequested()
                                        else if (todayPage.bannerKind === "recover") {
                                            if (todayPage.library)
                                                todayPage.library.recoverUnfinished()
                                        } else if (todayPage.updateShown === "downloaded")
                                            todayPage.updateAction("restart")
                                        else
                                            todayPage.updateAction("start")
                                    }
                                    contentItem: Text {
                                        id: resumeText
                                        text: todayPage.bannerKind === "paused" ? qsTr("Resume")
                                            : todayPage.bannerKind === "recover" ? qsTr("Keep")
                                            : todayPage.updateShown === "downloaded" ? qsTr("Restart")
                                            : qsTr("Update")
                                        color: Theme.accentInk
                                        font.family: Theme.bodySemibold
                                        font.pixelSize: Theme.fs(14)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                PulseButton {
                                    id: endButton
                                    width: endText.implicitWidth + 32
                                    height: 48
                                    topInset: 2
                                    bottomInset: 2
                                    pressedRadius: 14
                                    fill: pressed ? Theme.chip : Theme.control
                                    visible: todayPage.updateShown !== "downloading" || todayPage.bannerKind !== "update"
                                    Accessible.name: todayPage.bannerKind === "paused" ? qsTr("End the paused ride and save it")
                                        : todayPage.bannerKind === "recover" ? qsTr("Let the unfinished ride go")
                                        : todayPage.updateShown === "downloaded" ? qsTr("Restart later")
                                        : qsTr("Not now, keep this version")
                                    onClicked: {
                                        if (todayPage.bannerKind === "paused")
                                            todayPage.endRideRequested()
                                        else if (todayPage.bannerKind === "recover") {
                                            if (todayPage.library)
                                                todayPage.library.dismissUnfinished()
                                        } else
                                            todayPage.updateAction("later")
                                    }
                                    contentItem: Text {
                                        id: endText
                                        text: todayPage.bannerKind === "paused" ? qsTr("End")
                                            : todayPage.bannerKind === "recover" ? qsTr("Dismiss")
                                            : todayPage.updateShown === "downloaded" ? qsTr("Later")
                                            : qsTr("Not now")
                                        color: Theme.text
                                        font.family: Theme.bodySemibold
                                        font.pixelSize: Theme.fs(14)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                        Text {
                            visible: todayPage.pastMergeGap
                            x: 20
                            width: parent.width - x
                            text: qsTr("A long pause, but Resume still carries on this same ride.")
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(13)
                            wrapMode: Text.WordWrap
                            bottomPadding: 6
                        }
                    }
                }
            }

            // the ride to do now and the week, then what needs an answer
            Column {
                id: lead
                y: pausedBanner.y + pausedBanner.height + (pausedBanner.height > 0 ? 14 : 4)
                width: content.leftWidth

                Rise {
                    cue: todayPage
                    order: 0
                    width: parent.width
                    SuggestionCard {
                        width: parent.width
                        plan: todayPage.plan
                        kicker: todayPage.kicker
                        showLoad: Theme.ftpSet
                        detailed: Theme.moreDetail
                        status: todayPage.bikeWords
                        bikeReady: todayPage.connected
                        readiness: todayPage.formShown ? todayPage.ready.word : ""
                        swapLabel: todayPage.swapped ? qsTr("Back to %1").arg(todayPage.suggestion.main.name) : todayPage.suggestion.otherLabel
                        firstRide: todayPage.rideCount === 0
                        onRideRequested: todayPage.rideRequested()
                        onWorkoutRequested: todayPage.workoutRequested(todayPage.plan)
                        onSwap: todayPage.swapped = !todayPage.swapped
                        onDemoRequested: todayPage.demoRequested()
                        onLearnReadiness: todayPage.openLearn("readiness")
                    }
                }
                Item { width: 1; height: 14 }
                Rise {
                    cue: todayPage
                    order: 1
                    width: parent.width
                    WeekHome {
                        objectName: "weekHome"
                        width: parent.width
                        goals: todayPage.goals
                        days: todayPage.weekDays
                        miles: todayPage.miles
                        onLearn: todayPage.openLearn(id)
                        onEditGoal: if (todayPage.goals !== null) todayPage.goals.setupOpen = true
                        onResume: if (todayPage.goals !== null) todayPage.goals.resumeGoals()
                    }
                }
                Item { width: 1; height: 14 }
                // FTP still QZ's guess: offer one from the rides, or the place to set it
                // readiness from the body: the offer, or last night against the usual
                BodyCard {
                    visible: todayPage.healthOffered || todayPage.healthAsked
                    height: visible ? implicitHeight : 0
                    body: todayPage.bodyNow
                    asked: todayPage.healthAsked
                    onConnect: todayPage.connectHealth()
                    onDismiss: {
                        uiStore.setValue("healthDismissed", true)
                        todayPage.healthDismissed = true
                    }
                }
                Item { width: 1; height: todayPage.healthOffered || todayPage.healthAsked ? 14 : 0 }
                // an FTP test result, waiting for the rider to use it or not
                Rectangle {
                    objectName: "ftpTestResult"
                    visible: todayPage.ftpTest !== null
                    width: parent.width
                    height: visible ? testColumn.height + 32 : 0
                    radius: 24
                    color: Theme.accentWash(0.10)
                    Column {
                        id: testColumn
                        x: 16
                        y: 16
                        width: parent.width - 32
                        spacing: 12
                        Column {
                            width: parent.width
                            spacing: 3
                            Accessible.role: Accessible.StaticText
                            Accessible.name: testTitle.text + ". " + testWords.text
                            Text {
                                id: testTitle
                                width: parent.width
                                text: todayPage.ftpTest ? (todayPage.ftpTest.kind === "ramp" ? qsTr("Ramp test: FTP %1 W") : qsTr("20 minute test: FTP %1 W"))
                                                          .arg(todayPage.ftpTest.watts) : ""
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(15)
                                Accessible.ignored: true
                            }
                            Text {
                                id: testWords
                                width: parent.width
                                text: !todayPage.ftpTest ? ""
                                      : (todayPage.ftpTest.kind === "ramp" ? qsTr("75% of your best minute, %1 W.") : qsTr("95% of your 20 minutes, %1 W."))
                                        .arg(todayPage.ftpTest.measured)
                                        + (todayPage.ftpTest.estimated ? " " + qsTr("Estimated by this bike, like its watts.") : "")
                                        + " " + qsTr("Your power zones, load and workouts start from FTP.")
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.fs(13)
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 18
                                wrapMode: Text.WordWrap
                                Accessible.ignored: true
                            }
                        }
                        Row {
                            spacing: 8
                            PulseButton {
                                width: useTestText.implicitWidth + 32
                                height: 48
                                pressedRadius: 14
                                fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                                Accessible.name: useTestText.text
                                onClicked: todayPage.settleFtpTest(true)
                                contentItem: Text {
                                    id: useTestText
                                    text: todayPage.ftpTest ? qsTr("Use %1 W").arg(todayPage.ftpTest.watts) : ""
                                    color: Theme.accentInk
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.fs(14)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            PulseButton {
                                width: keepText.implicitWidth + 32
                                height: 48
                                pressedRadius: 14
                                fill: pressed ? Theme.chip : Theme.control
                                Accessible.name: keepText.text
                                onClicked: todayPage.settleFtpTest(false)
                                contentItem: Text {
                                    id: keepText
                                    text: Theme.ftpSet ? qsTr("Keep %1 W").arg(Math.round(Theme.ftp)) : qsTr("Not now")
                                    color: Theme.text
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.fs(14)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
                Item { width: 1; height: todayPage.ftpTest !== null ? 14 : 0 }
                Rectangle {
                    objectName: "ftpAsk"
                    visible: todayPage.askFtp
                    width: parent.width
                    height: visible ? ftpColumn.height + 32 : 0
                    radius: 24
                    color: Theme.accentWash(0.10)
                    Column {
                        id: ftpColumn
                        x: 16
                        y: 16
                        width: parent.width - 32
                        spacing: 12
                        Column {
                            width: parent.width
                            spacing: 3
                            Accessible.role: Accessible.StaticText
                            Accessible.name: ftpTitle.text + ". " + ftpWords.text
                            Text {
                                id: ftpTitle
                                width: parent.width
                                text: qsTr("Set your FTP")
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(15)
                                Accessible.ignored: true
                            }
                            Text {
                                id: ftpWords
                                width: parent.width
                                text: todayPage.ftpOffer > 0
                                      ? qsTr("If your best 20 minutes of the last 90 days were ridden hard, it is near %1 W. Easy rides make it read low. Your load, form and power zones start from it.").arg(todayPage.ftpOffer)
                                      : qsTr("Your load, form and power zones start from it. Set it in You, or ride 20 minutes hard and Bikemodo offers one.")
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.fs(13)
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 18
                                wrapMode: Text.WordWrap
                                Accessible.ignored: true
                            }
                        }
                        Row {
                            spacing: 8
                            PulseButton {
                                visible: todayPage.ftpOffer > 0
                                width: useText.implicitWidth + 32
                                height: 48
                                pressedRadius: 14
                                fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                                Accessible.name: qsTr("Use %1 watts as your FTP").arg(todayPage.ftpOffer)
                                onClicked: Theme.setFtp(todayPage.ftpOffer)
                                contentItem: Text {
                                    id: useText
                                    text: qsTr("Use %1 W").arg(todayPage.ftpOffer)
                                    color: Theme.accentInk
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.fs(14)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            PulseButton {
                                width: rampText.implicitWidth + 32
                                height: 48
                                pressedRadius: 14
                                fill: pressed ? Theme.chip : Theme.control
                                Accessible.name: qsTr("Take a ramp test, about 20 minutes")
                                onClicked: todayPage.workoutRequested(Ftp.rampPlan(Theme.ftp))
                                contentItem: Text {
                                    id: rampText
                                    text: qsTr("Ramp test")
                                    color: Theme.text
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.fs(14)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            PulseButton {
                                width: ownText.implicitWidth + 32
                                height: 48
                                pressedRadius: 14
                                fill: pressed ? Theme.chip : Theme.control
                                Accessible.name: qsTr("Set your FTP in You")
                                onClicked: todayPage.openYou()
                                contentItem: Text {
                                    id: ownText
                                    text: qsTr("Set my own")
                                    color: Theme.text
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.fs(14)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }

            // the week and the quiet sections: under the card, or in the right column
            Column {
                id: feedColumn
                x: content.wide ? content.leftWidth + 48 : 0
                y: content.wide ? lead.y : lead.y + lead.height + 18
                width: content.wide ? content.width - x : content.width
                spacing: 34

                Repeater {
                    model: todayPage.shownIds
                    Rise {
                        cue: todayPage
                        order: Math.min(6, 3 + index)
                        width: feedColumn.width
                        Loader {
                            width: parent.width
                            sourceComponent: todayPage.componentFor(modelData)
                        }
                    }
                }

                // the quiet way into Customize and the demo ride
                Rise {
                    cue: todayPage
                    order: 6
                    width: feedColumn.width
                    Row {
                        x: -12
                        spacing: 4
                        PulseButton {
                            visible: todayPage.rideCount > 0
                            width: customizeText.implicitWidth + 24
                            height: 48
                            // 44 to see, 48 to touch
                            topInset: 2
                            bottomInset: 2
                            fill: pressed ? Theme.pressed : "transparent"
                            Accessible.name: qsTr("Edit the sections of Today")
                            onClicked: todayPage.customizing = true
                            contentItem: Text {
                                id: customizeText
                                text: qsTr("Edit sections")
                                color: Theme.accent
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(14)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        PulseButton {
                            visible: todayPage.rideCount > 0
                            width: demoText.implicitWidth + 24
                            height: 48
                            // 44 to see, 48 to touch
                            topInset: 2
                            bottomInset: 2
                            fill: pressed ? Theme.pressed : "transparent"
                            Accessible.name: qsTr("Try a demo ride, no bike needed")
                            onClicked: todayPage.demoRequested()
                            contentItem: Text {
                                id: demoText
                                text: qsTr("Try a demo ride")
                                color: Theme.text2
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(14)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    LearnSheet {
        anchors.fill: parent
        z: 2
        open: todayPage.learnOpen
        entry: todayPage.learnEntry
        known: todayPage.learnIds
        bottomInset: todayPage.sheetClearance
        actionLabel: todayPage.learnTab === "progress" ? qsTr("See Progress") : ""
        onClose: todayPage.learnOpen = false
        onRelated: todayPage.openLearn(id)
        onAct: {
            todayPage.learnOpen = false
            todayPage.openTab(todayPage.learnTab)
        }
    }

    GoalSetup {
        objectName: "goalSetup"
        anchors.fill: parent
        z: 3
        bottomClearance: todayPage.sheetClearance
        open: todayPage.goals !== null && todayPage.goals.setupOpen
        kind: todayPage.goals !== null && todayPage.goals.goalChosen ? todayPage.goals.goalKind : "rides"
        goal: todayPage.goals !== null && todayPage.goals.goalChosen ? todayPage.goals.goalValue : 3
        week: todayPage.goals !== null ? todayPage.goals.thisWeek : null
        miles: todayPage.miles
        offerBreak: todayPage.goals !== null && todayPage.goals.goalChosen && !todayPage.goals.paused
        onBack: todayPage.goals.setupOpen = false
        onChosen: todayPage.goals.chooseGoal(goalKind, goalValue)
        onTakeBreak: {
            todayPage.goals.setupOpen = false
            todayPage.goals.pauseOpen = true
        }
    }

    PauseSheet {
        objectName: "pauseSheet"
        anchors.fill: parent
        z: 3
        bottomClearance: todayPage.sheetClearance
        open: todayPage.goals !== null && todayPage.goals.pauseOpen
        nowMs: todayPage.goals !== null ? todayPage.goals.nowMs : Date.now()
        onBack: todayPage.goals.pauseOpen = false
        onPauseGoals: todayPage.goals.pauseGoals(reason, until)
    }

    WelcomeBack {
        objectName: "welcomeBack"
        anchors.fill: parent
        z: 3
        bottomClearance: todayPage.sheetClearance
        open: todayPage.goals !== null && todayPage.goals.welcomeOpen
        streak: todayPage.goals !== null && todayPage.goals.streakResult ? todayPage.goals.streakResult.streak : 0
        covered: todayPage.goals !== null && todayPage.goals.welcomeCovered !== "" ? todayPage.goals.welcomeCovered : "frozen"
        weeks: todayPage.goals !== null && todayPage.goals.streakResult ? Streak.lastWeeks(todayPage.goals.streakResult.timeline, 8, todayPage.goals.nowMs) : []
        nowMs: todayPage.goals !== null ? todayPage.goals.nowMs : Date.now()
        onBack: todayPage.goals.welcomeOpen = false
        onPrimary: todayPage.goals.welcomeOpen = false
        onRideRequested: {
            todayPage.goals.welcomeOpen = false
            todayPage.rideRequested()
        }
    }

    TodaySheet {
        anchors.fill: parent
        open: todayPage.customizing
        cards: todayPage.cards
        titles: todayPage.cardTitles
        onMoveCard: todayPage.moveCard(from, to)
        onShowCard: todayPage.showCard(id, shown)
        onClose: todayPage.customizing = false
    }
}
