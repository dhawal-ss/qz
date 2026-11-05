import QtQuick 2.15
import Qt.labs.settings 1.0
import ".."
import "../learn/Learn.js" as Learn
import "../progress/Progress.js" as Progress
import "Streak.js" as Streak
import "Journeys.js" as Journeys
import "Badges.js" as Badges
import "Challenge.js" as Challenge
import "../Format.js" as Format
import "../train/Plans.js" as Plans
import "../train/Levels.js" as Levels

// The goals of the rider, made once in the shell and shared: Today shows the week and the streak
// (the week's home, goals/WeekHome.qml) with the goal setup, Taking a break and Welcome back over
// it; Progress shows training, the week in review, the monthly challenge, the journey, badges and
// the ladders. The rules are in Streak.js and the other goals/*.js files.
// The week is cheap to work out and is read again each time Today shows (refreshWeek); the rest
// (badges need every record's history) only when Progress shows and the rides changed (refreshAll).
// Everything stored is in the ui2 settings: goalKind, weeklyGoalMinutes (also read by the ride
// summary), weeklyGoalKj, weeklyGoalKm, weeklyGoalRides, restWeeks, restReasons, goalsPause,
// welcomeSeen, goalSetupOffered, journeyId, journeyStartKm, journeyStartMs, journeysDone,
// trainingPlan and workoutLog (written by the ride screen).
Item {
    id: goals

    property var library: null
    property bool miles: false

    // what is stored, read again each time a page shows
    property string goalKind: "minutes"
    property real goalValue: 120
    property bool goalChosen: true
    property var restWeeks: []
    property var restReasons: ({})
    property var pause: null
    property string journeyId: ""
    property real journeyStartKm: 0
    property real journeyStartMs: 0
    property var journeysDone: []
    // the training plan under way (train/Plans.js, null for none), where it stands, and the levels
    property var trainingPlan: null
    property var planState: null
    property var levels: ({})

    // worked out from the library: the week
    property real nowMs: Date.now()
    property var streakResult: null
    property var thisWeek: null
    property var lastWeek: ({ rides: 0, seconds: 0 })
    // Welcome back is due: the last week a freeze or a break covered, and this week not ridden yet
    property string welcomeCovered: ""
    // and the rest, for Progress
    property var lifetime: ({})
    property var ridesAsc: []
    property var histories: ({})
    property var challengeHistory: []
    property var badges: []
    property real journeyRidden: 0
    // the rides changed since refreshAll()
    property bool stale: true

    // what is open on top: on Today the goal setup, the break and Welcome back; on Progress a
    // badge and the week in review
    property bool setupOpen: false
    property bool pauseOpen: false
    property bool welcomeOpen: false
    property bool recapOpen: false
    property string badgeId: ""
    property var openedBadge: null   // kept while the sheet slides away
    // the setup is offered once a session to a rider without a goal
    property bool setupOffered: false

    readonly property bool hasRides: library !== null && library.rideCount > 0
    readonly property bool paused: Streak.pausedNow(pause, nowMs)
    readonly property bool weekPageOpen: setupOpen || pauseOpen || welcomeOpen
    // the Learn entries of the goals, on the page that shows each
    readonly property var weekLearnIds: ["streak", "freezes"]
    readonly property var sectionLearnIds: ["challenge", "journey", "badges", "ladders", "recap", "lifetime"]

    Settings {
        id: uiStore
        category: "ui2"
    }

    function goalWords(kind, value) {
        if (kind === "kj")
            return Format.big(value) + " kJ"
        if (kind === "km")
            return Format.distance(value, miles)
        if (kind === "rides")
            return Math.round(value) === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(Math.round(value))
        return Math.round(value) + " min"
    }

    // Qt.labs.settings does not tell one Settings object what another wrote: read again
    function readSettings() {
        var stored = String(uiStore.value("goalKind", ""))
        goalChosen = stored !== "" || String(uiStore.value("weeklyGoalMinutes", "")) !== ""
        var kind = stored
        if (Streak.kinds.indexOf(kind) < 0)
            kind = "minutes"
        goalKind = kind
        goalValue = Number(uiStore.value(Streak.settingKeys[kind], Streak.defaults[kind])) || Streak.defaults[kind]
        restWeeks = Streak.parseList(String(uiStore.value("restWeeks", "[]")))
        restReasons = Streak.parseMap(String(uiStore.value("restReasons", "{}")))
        pause = Streak.parsePause(String(uiStore.value("goalsPause", "")))
        journeyId = String(uiStore.value("journeyId", ""))
        journeyStartKm = Number(uiStore.value("journeyStartKm", 0)) || 0
        journeyStartMs = Number(uiStore.value("journeyStartMs", 0)) || 0
        journeysDone = Streak.parseList(String(uiStore.value("journeysDone", "[]")))
        trainingPlan = Plans.parse(String(uiStore.value("trainingPlan", "")))
        levels = Levels.levels(Levels.parse(String(uiStore.value("workoutLog", "[]"))), Date.now())
    }

    // A pause marks its weeks as rest weeks in the stored list, so the ride summary sees them
    // too; an open pause adds each new week as it comes. A pause whose week of return has come
    // is over.
    function syncPause() {
        if (pause === null)
            return
        var marked = Streak.withPause(restWeeks, restReasons, pause, nowMs)
        if (JSON.stringify(marked.rest) !== JSON.stringify(restWeeks)) {
            restWeeks = marked.rest
            restReasons = marked.reasons
            uiStore.setValue("restWeeks", JSON.stringify(marked.rest))
            uiStore.setValue("restReasons", JSON.stringify(marked.reasons))
        }
        if (!Streak.pausedNow(pause, nowMs)) {
            pause = null
            uiStore.setValue("goalsPause", "")
        }
    }

    // the week against the goal, the streak and its freezes, and whether Welcome back is due
    function refreshWeek() {
        nowMs = Date.now()
        syncPause()
        var days = library ? library.days(0, 0) : []
        var weeks = Streak.perWeek(days)
        streakResult = Streak.run(weeks, { kind: goalKind, goal: goalValue, rest: restWeeks, now: nowMs })
        thisWeek = weeks[Streak.weekKey(nowMs)] || null
        var week = weeks[Streak.weekKey(Streak.addWeeks(nowMs, -1))]
        lastWeek = week ? { rides: week.rides, seconds: week.seconds } : { rides: 0, seconds: 0 }

        // Welcome back: a streak alive, last week covered, nothing ridden yet this week
        var line = streakResult.timeline
        var last = line.length > 1 ? line[line.length - 2] : null
        var covered = last !== null && (last.status === "frozen" || last.status === "rest") ? last.status : ""
        welcomeCovered = !paused && streakResult.streak > 0 && covered !== "" && streakResult.current !== null
                         && streakResult.current.value === 0 ? covered : ""
        return days
    }

    // the week, then what the Progress sections show
    function refreshAll() {
        var days = refreshWeek()
        stale = false
        lifetime = library ? library.totals(0, 0) : ({})
        ridesAsc = library ? library.rides(0, library.rideCount).slice().reverse() : []
        var found = {}
        if (library) {
            var curve = library.powerCurve(0, 0)
            for (var i = 0; i < curve.length; i++)
                found[curve[i].seconds] = library.recordHistory(curve[i].seconds)
        }
        histories = found
        planState = trainingPlan ? Plans.now(trainingPlan, library ? library.rides(0, 60) : [], nowMs, levels) : null
        challengeHistory = Challenge.history(days, nowMs)

        // the journey, and its badge the first time it is done
        var journey = Journeys.byId(journeyId)
        journeyRidden = journey ? Math.max(0, (lifetime.distance || 0) - journeyStartKm) : 0
        if (journey && journeyRidden >= Journeys.total(journey)) {
            var recorded = false
            for (var d = 0; d < journeysDone.length; d++)
                if (journeysDone[d].id === journeyId && Number(journeysDone[d].date) >= journeyStartMs)
                    recorded = true
            if (!recorded) {
                var on = Journeys.finishedOn(ridesAsc, journeyStartMs, Journeys.total(journey)) || nowMs
                var done = journeysDone.slice()
                done.push({ id: journeyId, date: on })
                journeysDone = done
                uiStore.setValue("journeysDone", JSON.stringify(done))
            }
        }
        var percent = journey ? Journeys.progress(journey, journeyRidden).percent : 0
        badges = Badges.evaluate({ rides: ridesAsc, recordCounts: Badges.recordCounts(histories), streak: streakResult,
                                   journeysDone: journeysDone, journeyId: journeyId, journeyPercent: percent,
                                   challenges: challengeHistory, now: nowMs, miles: miles })
    }

    // after a change the rider made: what is shown on either page is right again
    function reload() {
        readSettings()
        if (stale)
            refreshWeek()
        else
            refreshAll()
    }

    // what opens over Today as it shows: the goal setup first, else Welcome back once a week
    function offer() {
        if (weekPageOpen)
            return
        // offered once, ever (ui2/goalSetupOffered): Edit goal opens it again any time
        if (!goalChosen && !setupOffered && String(uiStore.value("goalSetupOffered", "")) !== "true") {
            setupOffered = true
            uiStore.setValue("goalSetupOffered", "true")
            setupOpen = true
            return
        }
        if (welcomeCovered !== "" && streakResult && streakResult.current
                && String(uiStore.value("welcomeSeen", "")) !== String(streakResult.current.key)) {
            uiStore.setValue("welcomeSeen", String(streakResult.current.key))
            welcomeOpen = true
        }
    }

    function startPlan(id, weeks) {
        uiStore.setValue("trainingPlan", JSON.stringify({ id: id, startMs: Date.now(), weeks: weeks }))
        reload()
    }

    function endPlan() {
        uiStore.setValue("trainingPlan", "")
        reload()
    }

    // the goal from the setup: what it counts and how much, at once
    function chooseGoal(kind, value) {
        uiStore.setValue("goalKind", kind)
        uiStore.setValue(Streak.settingKeys[kind], value)
        setupOpen = false
        reload()
    }

    // Taking a break: from this week, until the week of return (a week key) or open
    function pauseGoals(reason, until) {
        var started = { from: Streak.weekKey(Date.now()), until: until > 0 ? until : 0, reason: reason }
        uiStore.setValue("goalsPause", JSON.stringify(started))
        pauseOpen = false
        reload()
    }

    // back early: the weeks marked ahead are free again
    function resumeGoals() {
        if (pause !== null) {
            var freed = Streak.endPause(restWeeks, restReasons, pause, Date.now())
            uiStore.setValue("restWeeks", JSON.stringify(freed.rest))
            uiStore.setValue("restReasons", JSON.stringify(freed.reasons))
        }
        uiStore.setValue("goalsPause", "")
        reload()
    }

    // starts a journey from the distance ridden so far
    function startJourney(id) {
        uiStore.setValue("journeyId", id)
        uiStore.setValue("journeyStartKm", lifetime.distance || 0)
        uiStore.setValue("journeyStartMs", Date.now())
        reload()
    }

    // what the Learn sheet of an entry says about this rider
    function factsFor(id) {
        // the ride count from the library: Today reads the week only, without the lifetime
        var f = { rides: library ? library.rideCount : 0 }
        if (id === "streak" && streakResult) {
            f.streak = streakResult.streak
            f.goalText = goalWords(goalKind, goalValue)
        }
        if (id === "freezes" && streakResult) {
            f.freezes = streakResult.freezes || 0
            f.toNext = streakResult.toNextFreeze || 0
        }
        if (id === "challenge" && challengeHistory.length > 0) {
            var month = challengeHistory[challengeHistory.length - 1]
            var pace = Challenge.pace(month.minutes, month.target, nowMs)
            var hoursText = function (minutes) {
                var m = Math.round(minutes)
                return m >= 60 && m % 60 === 0 ? (m / 60) + " h" : Format.hours(m * 60)
            }
            f.targetText = hoursText(month.target)
            f.doneText = hoursText(month.minutes)
            f.daysLeftText = month.met ? qsTr("done for the month") : (pace.daysLeft === 1 ? qsTr("1 day left") : qsTr("%1 days left").arg(pace.daysLeft))
            f.paceText = month.met ? qsTr("Everything from here is extra.")
                         : (pace.onTrack ? qsTr("You are on track.") : qsTr("About %1 a week gets you there.").arg(hoursText(pace.perWeek)))
        }
        if (id === "journey") {
            var journey = Journeys.byId(journeyId)
            if (journey) {
                f.name = journey.name
                f.percent = Journeys.progress(journey, journeyRidden).percent
            }
        }
        if (id === "badges") {
            f.earned = Badges.earned(badges).length
            f.total = badges.length
        }
        if (id === "ladders" && (lifetime.distance || 0) > 0)
            f.distanceText = Format.distance(lifetime.distance, miles)
        if (id === "lifetime")
            f.seconds = lifetime.seconds || 0
        if (id === "recap") {
            f.rides = lastWeek.rides
            f.seconds = lastWeek.seconds
        }
        return f
    }

    function learnEntry(id) {
        return Learn.entry(id, factsFor(id))
    }

    function openBadge(id) {
        openedBadge = Badges.byId(badges, id)
        badgeId = id
    }

    // Android back closes what the goals have open on top, Today's first
    function goBackWeek() {
        if (welcomeOpen) {
            welcomeOpen = false
            return true
        }
        if (pauseOpen) {
            pauseOpen = false
            return true
        }
        if (setupOpen) {
            setupOpen = false
            return true
        }
        return false
    }
    function goBackSections() {
        if (badgeId !== "") {
            badgeId = ""
            return true
        }
        if (recapOpen) {
            recapOpen = false
            return true
        }
        return false
    }

    onLibraryChanged: { readSettings(); refreshWeek(); stale = true }
    Component.onCompleted: { readSettings(); refreshWeek() }

    // the library tells about every ride it reads in: one refresh for a burst of them
    Timer {
        id: refreshLater
        interval: 300
        onTriggered: { goals.refreshWeek(); goals.stale = true }
    }
    Connections {
        target: goals.library
        ignoreUnknownSignals: true
        function onChanged() { refreshLater.restart() }
    }
}
