import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "goals"
import "progress"
import "learn"
import "learn/Learn.js" as Learn
import "progress/Progress.js" as Progress
import "goals/Streak.js" as Streak
import "goals/Journeys.js" as Journeys
import "goals/Badges.js" as Badges
import "goals/Challenge.js" as Challenge
import "Format.js" as Format
import "train/Plans.js" as Plans
import "train/Levels.js" as Levels

// Goals, in the Signature language: the streak is the hero (the breathing Pulse, what a coach
// would say, the last weeks as a row, and the one raised card with this week against the goal),
// then quiet sections on the page the rider hides and orders with Customize: the week in review,
// a monthly challenge made from the rider's own months, a journey along a real route, badges and
// the lifetime ladders. On wide windows the hero stays on the left and the sections go right.
// Over the page: the goal setup (offered to a rider without a goal), Taking a break (pauses the
// goals, the weeks of the break become rest weeks) and Welcome back after a week a freeze or a
// break covered.
// Everything Goals stores is in the ui2 settings: goalKind, weeklyGoalMinutes (also read by the
// ride summary), weeklyGoalKj, weeklyGoalKm, weeklyGoalRides, restWeeks, restReasons, goalsPause,
// welcomeSeen, journeyId, journeyStartKm, journeyStartMs, journeysDone and goalsCards.
// Tap to learn: each section opens a Learn sheet (learn/LearnSheet.qml) on what it is and what the
// rider's own numbers say; openLearn("streak") and openLearn("freezes") are there for the hero.
Item {
    id: goals
    objectName: "goalsScreen"

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"
    // the end of the page the floating navigation covers: the content scrolls under it
    property real bottomClearance: 0
    // what a sheet keeps free at its end (the bottom inset; the shell binds it, the floating
    // navigation steps aside while a sheet covers the page)
    property real sheetClearance: 0

    signal openYou()
    // Start on Welcome back: an easy ride
    signal rideRequested()
    // a ride of the training plan or an FTP test (Coach.plan, train/Ftp.js): to the ride screen
    signal workoutRequested(var workout)
    signal workoutFileRequested()
    signal intervalsRequested()
    signal routeRequested(var route)
    signal routeFileRequested()
    // each time the screen shows: the blocks rise in again
    signal entered()

    readonly property var cardIds: ["training", "recap", "challenge", "journey", "badges", "ladders"]
    readonly property var cardTitles: ({
        training: qsTr("Training"),
        recap: qsTr("Your week in review"),
        challenge: qsTr("Monthly challenge"),
        journey: qsTr("Journey"),
        badges: qsTr("Badges"),
        ladders: qsTr("Ladders")
    })
    property var cards: Progress.cardList("", cardIds)

    // what is stored, read again each time the screen shows
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

    // worked out from the library
    property real nowMs: Date.now()
    property var streakResult: null
    property var thisWeek: null
    property var lifetime: ({})
    property var ridesAsc: []
    property var histories: ({})
    property var challengeHistory: []
    property var badges: []
    property real journeyRidden: 0
    property var lastWeek: ({ rides: 0, seconds: 0 })
    // Welcome back is due: the last week a freeze or a break covered, and this week not ridden yet
    property string welcomeCovered: ""

    // what is open on top
    property bool customizing: false
    property bool recapOpen: false
    property string badgeId: ""
    property var openedBadge: null   // kept while the sheet slides away
    property bool setupOpen: false
    property bool pauseOpen: false
    property bool welcomeOpen: false
    // the setup is offered once a session to a rider without a goal
    property bool setupOffered: false
    // the Learn sheet
    property bool learnOpen: false
    property var learnEntry: null
    readonly property var learnIds: ["streak", "freezes", "challenge", "journey", "badges", "ladders", "recap", "lifetime"]

    readonly property bool hasRides: library !== null && library.rideCount > 0
    readonly property bool paused: Streak.pausedNow(pause, nowMs)
    // a full page covers Goals: the shell may hide the floating navigation
    readonly property bool covering: setupOpen || pauseOpen || welcomeOpen || learnOpen || badgeId !== "" || recapOpen
    readonly property var shownIds: {
        var out = []
        for (var i = 0; i < cards.length; i++)
            if (cards[i].shown && (cards[i].id !== "recap" || hasRides))
                out.push(cards[i].id)
        return out
    }

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
        // a new list rebuilds every section, so only when it changed; Training comes first, also
        // in an order saved before it was there
        var savedText = String(uiStore.value("goalsCards", ""))
        var saved = Progress.cardList(savedText, cardIds)
        if (savedText.indexOf("training") < 0) {
            for (var t = 0; t < saved.length; t++)
                if (saved[t].id === "training")
                    saved.unshift(saved.splice(t, 1)[0])
        }
        if (Progress.cardJson(saved) !== Progress.cardJson(cards))
            cards = saved
    }

    // A pause marks its weeks as rest weeks in the stored list, so Today and the ride summary see
    // them too; an open pause adds each new week as it comes. A pause whose week of return has
    // come is over.
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

    function refresh() {
        nowMs = Date.now()
        syncPause()
        var days = library ? library.days(0, 0) : []
        var weeks = Streak.perWeek(days)
        streakResult = Streak.run(weeks, { kind: goalKind, goal: goalValue, rest: restWeeks, now: nowMs })
        thisWeek = weeks[Streak.weekKey(nowMs)] || null
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
        var week = weeks[Streak.weekKey(Streak.addWeeks(nowMs, -1))]
        lastWeek = week ? { rides: week.rides, seconds: week.seconds } : { rides: 0, seconds: 0 }

        // Welcome back: a streak alive, last week covered, nothing ridden yet this week
        var line = streakResult.timeline
        var last = line.length > 1 ? line[line.length - 2] : null
        var covered = last !== null && (last.status === "frozen" || last.status === "rest") ? last.status : ""
        welcomeCovered = !paused && streakResult.streak > 0 && covered !== "" && streakResult.current !== null
                         && streakResult.current.value === 0 ? covered : ""

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

    // what opens over the page as it shows: the goal setup first, else Welcome back once a week
    function offer() {
        if (covering)
            return
        if (!goalChosen && !setupOffered) {
            setupOffered = true
            setupOpen = true
            return
        }
        if (welcomeCovered !== "" && streakResult && streakResult.current
                && String(uiStore.value("welcomeSeen", "")) !== String(streakResult.current.key)) {
            uiStore.setValue("welcomeSeen", String(streakResult.current.key))
            welcomeOpen = true
        }
    }

    function setKind(kind) {
        uiStore.setValue("goalKind", kind)
        readSettings()
        refresh()
    }

    function setGoal(value) {
        uiStore.setValue(Streak.settingKeys[goalKind], value)
        readSettings()
        refresh()
    }

    // the goal from the setup: what it counts and how much, at once
    function startPlan(id, weeks) {
        uiStore.setValue("trainingPlan", JSON.stringify({ id: id, startMs: Date.now(), weeks: weeks }))
        readSettings()
        refresh()
    }

    function endPlan() {
        uiStore.setValue("trainingPlan", "")
        readSettings()
        refresh()
    }

    function chooseGoal(kind, value) {
        uiStore.setValue("goalKind", kind)
        uiStore.setValue(Streak.settingKeys[kind], value)
        setupOpen = false
        readSettings()
        refresh()
    }

    // reason is one of Streak.reasons; anything else clears the mark
    function markWeek(key, reason) {
        var marked = Streak.mark(restWeeks, restReasons, key, reason)
        uiStore.setValue("restWeeks", JSON.stringify(marked.rest))
        uiStore.setValue("restReasons", JSON.stringify(marked.reasons))
        readSettings()
        refresh()
    }

    // Taking a break: from this week, until the week of return (a week key) or open
    function pauseGoals(reason, until) {
        var started = { from: Streak.weekKey(Date.now()), until: until > 0 ? until : 0, reason: reason }
        uiStore.setValue("goalsPause", JSON.stringify(started))
        pauseOpen = false
        readSettings()
        refresh()
    }

    // back early: the weeks marked ahead are free again
    function resumeGoals() {
        if (pause !== null) {
            var freed = Streak.endPause(restWeeks, restReasons, pause, Date.now())
            uiStore.setValue("restWeeks", JSON.stringify(freed.rest))
            uiStore.setValue("restReasons", JSON.stringify(freed.reasons))
        }
        uiStore.setValue("goalsPause", "")
        readSettings()
        refresh()
    }

    // starts a journey from the distance ridden so far
    function startJourney(id) {
        uiStore.setValue("journeyId", id)
        uiStore.setValue("journeyStartKm", lifetime.distance || 0)
        uiStore.setValue("journeyStartMs", Date.now())
        readSettings()
        refresh()
    }

    function saveCards(list) {
        cards = list
        uiStore.setValue("goalsCards", Progress.cardJson(list))
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

    // the shown sections of one column
    function columnIds(column, columns) {
        var out = []
        for (var i = 0; i < shownIds.length; i++)
            if (i % columns === column)
                out.push(shownIds[i])
        return out
    }

    function componentFor(cardId) {
        if (cardId === "training")
            return trainingComponent
        if (cardId === "recap")
            return recapComponent
        if (cardId === "challenge")
            return challengeComponent
        if (cardId === "journey")
            return journeyComponent
        if (cardId === "badges")
            return badgesComponent
        return laddersComponent
    }

    function openCustomize() {
        customizing = true
    }

    // what the Learn sheet of an entry says about this rider
    function factsFor(id) {
        var f = { rides: lifetime.rides || 0 }
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

    function openLearn(id) {
        learnEntry = Learn.entry(id, factsFor(id))
        learnOpen = true
    }

    function openRecap() {
        recapOpen = true
    }

    function openBadge(id) {
        openedBadge = Badges.byId(badges, id)
        badgeId = id
    }

    function openSetup() {
        setupOpen = true
    }

    function openPause() {
        pauseOpen = true
    }

    // Android back closes what is on top first: a full page, a badge, the week in review, then
    // Customize
    function goBack() {
        if (learnOpen) {
            learnOpen = false
            return true
        }
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
        if (badgeId !== "") {
            badgeId = ""
            return true
        }
        if (recapOpen) {
            recapOpen = false
            return true
        }
        if (customizing) {
            customizing = false
            return true
        }
        return false
    }

    onLibraryChanged: refresh()
    onVisibleChanged: {
        if (!visible) {
            learnOpen = false
            return
        }
        readSettings()
        refresh()
        entered()
        offer()
    }
    Component.onCompleted: { readSettings(); refresh() }

    // the library tells about every ride it reads in: one refresh for a burst of them
    Timer {
        id: refreshLater
        interval: 300
        onTriggered: goals.refresh()
    }
    Connections {
        target: goals.library
        ignoreUnknownSignals: true
        function onChanged() { refreshLater.restart() }
    }

    Component {
        id: recapComponent
        LearnTap {
          name: qsTr("Your week in review")
          onClicked: goals.openLearn("recap")
          Column {
            width: parent.width
            spacing: 8
            CapLabel {
                text: qsTr("Your week in review")
            }
            Text {
                width: parent.width
                topPadding: 4
                text: goals.lastWeek.rides === 0 ? qsTr("Last week was a quiet one.")
                      : (goals.lastWeek.rides === 1 ? qsTr("1 ride, %1").arg(Format.hours(goals.lastWeek.seconds))
                                                   : qsTr("%1 rides, %2").arg(goals.lastWeek.rides).arg(Format.hours(goals.lastWeek.seconds)))
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(21)
                font.letterSpacing: -0.2
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: qsTr("%1 to %2").arg(Format.day(Streak.addWeeks(goals.nowMs, -1)))
                      .arg(Format.day(Streak.addWeeks(goals.nowMs, 0) - 86400000))
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(12)
                wrapMode: Text.WordWrap
            }
            PulseButton {
                x: -12
                width: weekLabel.implicitWidth + 24
                height: 48
                // 44 to see, 48 to touch
                topInset: 2
                bottomInset: 2
                fill: pressed ? Theme.pressed : "transparent"
                Accessible.name: qsTr("See your week in review")
                onClicked: goals.openRecap()
                contentItem: Text {
                    id: weekLabel
                    text: qsTr("See your week")
                    color: Theme.accent
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(14)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
          }
        }
    }
    Component {
        id: challengeComponent
        LearnTap {
            name: qsTr("Monthly challenge")
            onClicked: goals.openLearn("challenge")
            ChallengeCard {
                width: parent.width
                history: goals.challengeHistory
                nowMs: goals.nowMs
            }
        }
    }
    Component {
        id: journeyComponent
        LearnTap {
            name: qsTr("Journey")
            onClicked: goals.openLearn("journey")
            JourneyCard {
                width: parent.width
                journeyId: goals.journeyId
                ridden: goals.journeyRidden
                finished: goals.journeysDone
                miles: goals.miles
                onStartJourney: goals.startJourney(id)
            }
        }
    }
    Component {
        id: trainingComponent
        TrainingCard {
            plan: goals.trainingPlan
            planState: goals.planState
            levels: goals.levels
            onStartPlan: goals.startPlan(id, weeks)
            onEndPlan: goals.endPlan()
            onWorkoutRequested: goals.workoutRequested(workout)
            onWorkoutFileRequested: goals.workoutFileRequested()
            onIntervalsRequested: goals.intervalsRequested()
            onRouteRequested: goals.routeRequested(route)
            onRouteFileRequested: goals.routeFileRequested()
        }
    }
    Component {
        id: badgesComponent
        BadgeGrid {
            badges: goals.badges
            miles: goals.miles
            onOpenBadge: goals.openBadge(id)
            onLearn: goals.openLearn("badges")
        }
    }
    Component {
        id: laddersComponent
        LearnTap {
            name: qsTr("Ladders")
            onClicked: goals.openLearn("ladders")
            LaddersCard {
                width: parent.width
                lifetime: goals.lifetime
                miles: goals.miles
            }
        }
    }

    // the glow of the hero, outside the Flickable so it reaches into the top of the screen
    HeroGlow {
        readonly property point center: {
            var moved = flick.contentY + flick.contentX + content.x + content.width + lead.y + lead.x
            return lead.mapToItem(goals, lead.width / 2, 68)
        }
        width: 480
        height: 480
        x: center.x - width / 2
        y: center.y - height / 2
        tint: Theme.accent
        Accessible.ignored: true
    }

    Flickable {
        id: flick
        objectName: "goalsFlick"
        anchors.fill: parent
        contentHeight: content.height + goals.bottomClearance + 24
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: content
            readonly property real margin: goals.width < 400 ? 16 : 24
            readonly property bool wide: goals.width >= 720
            readonly property real leftWidth: wide ? Math.min(460, (width - 48) * 0.48) : width
            x: Math.max(margin, (goals.width - width) / 2)
            // one column keeps to a phone's measure, centered on a wider window
            width: Math.min(goals.width - margin * 2, wide ? 1120 : 560)
            height: Math.max(lead.y + lead.height, feedColumn.y + feedColumn.height)

            Item {
                id: headerBox
                width: content.leftWidth
                height: header.height
                PageHeader {
                    id: header
                    width: parent.width
                    title: qsTr("Goals")
                    showYou: goals.showYou
                    initial: goals.initial
                    onOpenYou: goals.openYou()
                }
                // on the line of the title and the You button
                PulseButton {
                    x: parent.width - width - (goals.showYou ? 56 : 0)
                    y: 22
                    width: customizeText.implicitWidth + 32
                    height: 48
                    topInset: 2
                    bottomInset: 2
                    fill: pressed ? Theme.pressed : Theme.control
                    Accessible.name: qsTr("Customize the Goals sections")
                    onClicked: goals.openCustomize()
                    contentItem: Text {
                        id: customizeText
                        text: qsTr("Customize")
                        color: Theme.accent
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(14)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            StreakCard {
                id: lead
                objectName: "goalsHero"
                onGoalPicked: goals.setGoal(value)
                y: headerBox.height
                width: content.leftWidth
                cue: goals
                weekCount: content.wide ? 12 : (goals.width < 400 ? 10 : 12)
                kind: goals.goalKind
                goal: goals.goalValue
                miles: goals.miles
                result: goals.streakResult
                reasonsMap: goals.restReasons
                nowMs: goals.nowMs
                paused: goals.paused
                pauseUntil: goals.pause ? (Number(goals.pause.until) || 0) : 0
                onChangeGoal: goals.openSetup()
                onTakeBreak: goals.openPause()
                onResume: goals.resumeGoals()
            }

            // the quiet sections: under the hero, or in the right column
            Column {
                id: feedColumn
                x: content.wide ? content.leftWidth + 48 : 0
                y: content.wide ? headerBox.height + 8 : lead.y + lead.height + 34
                width: content.wide ? content.width - x : content.width
                spacing: 34

                Text {
                    width: parent.width
                    visible: goals.shownIds.length === 0
                    text: qsTr("Every section is hidden. Customize brings them back.")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(14)
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: goals.shownIds
                    Rise {
                        cue: goals
                        order: Math.min(7, 4 + index)
                        width: feedColumn.width
                        Loader {
                            id: goalsCardLoader
                            width: parent.width
                            sourceComponent: goals.componentFor(modelData)
                        }
                    }
                }
            }
        }
    }

    // the sheets end above the floating navigation
    CustomizeSheet {
        hint: qsTr("Pick the Goals sections and their order. The streak stays on top.")
        anchors.fill: parent
        anchors.bottomMargin: goals.bottomClearance
        open: goals.customizing
        cards: goals.cards
        titles: goals.cardTitles
        onMoveCard: goals.moveCard(from, to)
        onShowCard: goals.showCard(id, shown)
        onClose: goals.customizing = false
    }

    BadgeSheet {
        anchors.fill: parent
        anchors.bottomMargin: goals.sheetClearance
        open: goals.badgeId !== ""
        badge: goals.openedBadge
        miles: goals.miles
        onClose: goals.badgeId = ""
    }

    WeeklyRecap {
        anchors.fill: parent
        anchors.bottomMargin: goals.sheetClearance
        open: goals.recapOpen
        library: goals.library
        miles: goals.miles
        monday: Streak.addWeeks(goals.nowMs, -1)
        rides: goals.ridesAsc
        histories: goals.histories
        streakResult: goals.streakResult
        goalWords: goals.goalWords(goals.goalKind, goals.goalValue)
        nextGoalWords: goals.goalWords(goals.goalKind, goals.goalValue)
        onClose: goals.recapOpen = false
    }

    LearnSheet {
        anchors.fill: parent
        open: goals.learnOpen
        entry: goals.learnEntry
        known: goals.learnIds
        bottomInset: goals.sheetClearance
        onClose: goals.learnOpen = false
        onRelated: goals.openLearn(id)
    }

    GoalSetup {
        objectName: "goalSetup"
        anchors.fill: parent
        bottomClearance: goals.bottomClearance
        open: goals.setupOpen
        kind: goals.goalChosen ? goals.goalKind : "rides"
        goal: goals.goalChosen ? goals.goalValue : 3
        week: goals.thisWeek
        miles: goals.miles
        onBack: goals.setupOpen = false
        onChosen: goals.chooseGoal(goalKind, goalValue)
    }

    PauseSheet {
        objectName: "pauseSheet"
        anchors.fill: parent
        bottomClearance: goals.bottomClearance
        open: goals.pauseOpen
        nowMs: goals.nowMs
        onBack: goals.pauseOpen = false
        onPauseGoals: goals.pauseGoals(reason, until)
    }

    WelcomeBack {
        objectName: "welcomeBack"
        anchors.fill: parent
        bottomClearance: goals.bottomClearance
        open: goals.welcomeOpen
        streak: goals.streakResult ? goals.streakResult.streak : 0
        covered: goals.welcomeCovered !== "" ? goals.welcomeCovered : "frozen"
        weeks: goals.streakResult ? Streak.lastWeeks(goals.streakResult.timeline, 8, goals.nowMs) : []
        nowMs: goals.nowMs
        onBack: goals.welcomeOpen = false
        onPrimary: goals.welcomeOpen = false
        onRideRequested: {
            goals.welcomeOpen = false
            goals.rideRequested()
        }
    }
}
