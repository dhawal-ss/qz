import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "goals"
import "progress"
import "progress/Progress.js" as Progress
import "goals/Streak.js" as Streak
import "goals/Journeys.js" as Journeys
import "goals/Badges.js" as Badges
import "goals/Challenge.js" as Challenge
import "Format.js" as Format

// Goals: the weekly goal with a streak of weeks (freezes and rest weeks keep it alive), the week
// in review, a monthly challenge made from the rider's own months, a journey along a real route,
// badges and the lifetime ladders. The rider hides and orders the cards with Customize; one
// column on phones, two on wider windows, the cards taking turns left and right.
// Everything Goals stores is in the ui2 settings: goalKind, weeklyGoalMinutes (also read by the
// ride summary), weeklyGoalKj, weeklyGoalKm, weeklyGoalRides, restWeeks, restReasons, journeyId,
// journeyStartKm, journeyStartMs, journeysDone and goalsCards.
Item {
    id: goals
    objectName: "goalsScreen"

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"

    signal openYou()

    readonly property var cardIds: ["streak", "recap", "challenge", "journey", "badges", "ladders"]
    readonly property var cardTitles: ({
        streak: qsTr("Weekly goal and streak"),
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
    property var restWeeks: []
    property var restReasons: ({})
    property string journeyId: ""
    property real journeyStartKm: 0
    property real journeyStartMs: 0
    property var journeysDone: []

    // worked out from the library
    property real nowMs: Date.now()
    property var streakResult: null
    property var lifetime: ({})
    property var ridesAsc: []
    property var histories: ({})
    property var challengeHistory: []
    property var badges: []
    property real journeyRidden: 0
    property var lastWeek: ({ rides: 0, seconds: 0 })

    // what is open on top
    property bool customizing: false
    property bool recapOpen: false
    property string badgeId: ""
    property var openedBadge: null   // kept while the sheet slides away

    readonly property bool hasRides: library !== null && library.rideCount > 0
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
        var kind = String(uiStore.value("goalKind", "minutes"))
        if (Streak.kinds.indexOf(kind) < 0)
            kind = "minutes"
        goalKind = kind
        goalValue = Number(uiStore.value(Streak.settingKeys[kind], Streak.defaults[kind])) || Streak.defaults[kind]
        restWeeks = Streak.parseList(String(uiStore.value("restWeeks", "[]")))
        restReasons = Streak.parseMap(String(uiStore.value("restReasons", "{}")))
        journeyId = String(uiStore.value("journeyId", ""))
        journeyStartKm = Number(uiStore.value("journeyStartKm", 0)) || 0
        journeyStartMs = Number(uiStore.value("journeyStartMs", 0)) || 0
        journeysDone = Streak.parseList(String(uiStore.value("journeysDone", "[]")))
        // a new list rebuilds every card, so only when it changed
        var saved = Progress.cardList(String(uiStore.value("goalsCards", "")), cardIds)
        if (Progress.cardJson(saved) !== Progress.cardJson(cards))
            cards = saved
    }

    function refresh() {
        nowMs = Date.now()
        var days = library ? library.days(0, 0) : []
        var weeks = Streak.perWeek(days)
        streakResult = Streak.run(weeks, { kind: goalKind, goal: goalValue, rest: restWeeks, now: nowMs })
        lifetime = library ? library.totals(0, 0) : ({})
        ridesAsc = library ? library.rides(0, library.rideCount).slice().reverse() : []
        var found = {}
        if (library) {
            var curve = library.powerCurve(0, 0)
            for (var i = 0; i < curve.length; i++)
                found[curve[i].seconds] = library.recordHistory(curve[i].seconds)
        }
        histories = found
        challengeHistory = Challenge.history(days, nowMs)
        var week = weeks[Streak.dayKey(Streak.addWeeks(nowMs, -1))]
        lastWeek = week ? { rides: week.rides, seconds: week.seconds } : { rides: 0, seconds: 0 }

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
                                   challenges: challengeHistory, now: nowMs })
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

    // reason is rest, sick or injured; anything else clears the mark
    function markWeek(key, reason) {
        var marked = Streak.mark(restWeeks, restReasons, key, reason)
        uiStore.setValue("restWeeks", JSON.stringify(marked.rest))
        uiStore.setValue("restReasons", JSON.stringify(marked.reasons))
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

    // the shown cards of one column
    function columnIds(column, columns) {
        var out = []
        for (var i = 0; i < shownIds.length; i++)
            if (i % columns === column)
                out.push(shownIds[i])
        return out
    }

    function componentFor(cardId) {
        if (cardId === "streak")
            return streakComponent
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

    function openRecap() {
        recapOpen = true
    }

    function openBadge(id) {
        openedBadge = Badges.byId(badges, id)
        badgeId = id
    }

    // Android back closes what is on top first: a badge, the week in review, then Customize
    function goBack() {
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
    onVisibleChanged: if (visible) { readSettings(); refresh() }
    Component.onCompleted: { readSettings(); refresh() }
    Connections {
        target: goals.library
        ignoreUnknownSignals: true
        function onChanged() { goals.refresh() }
    }

    Component {
        id: streakComponent
        StreakCard {
            kind: goals.goalKind
            goal: goals.goalValue
            miles: goals.miles
            result: goals.streakResult
            reasonsMap: goals.restReasons
            nowMs: goals.nowMs
            onSetKind: goals.setKind(kind)
            onSetGoal: goals.setGoal(value)
            onMarkWeek: goals.markWeek(key, reason)
        }
    }
    Component {
        id: recapComponent
        Card {
            id: recapEntry
            Text {
                text: qsTr("Your week in review")
                color: Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.labelSize
            }
            Text {
                width: parent.width
                text: goals.lastWeek.rides === 0 ? qsTr("Last week was a quiet one")
                      : (goals.lastWeek.rides === 1 ? qsTr("1 ride, %1").arg(Format.hours(goals.lastWeek.seconds))
                                                   : qsTr("%1 rides, %2").arg(goals.lastWeek.rides).arg(Format.hours(goals.lastWeek.seconds)))
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: 24
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: qsTr("%1 to %2").arg(Format.day(Streak.addWeeks(goals.nowMs, -1)))
                      .arg(Format.day(Streak.addWeeks(goals.nowMs, 0) - 86400000))
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
                wrapMode: Text.WordWrap
            }
            PulseButton {
                width: weekLabel.implicitWidth + 40
                height: 48
                fill: pressed ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                Accessible.name: qsTr("See your week in review")
                onClicked: goals.openRecap()
                contentItem: Text {
                    id: weekLabel
                    text: qsTr("See your week")
                    color: Theme.accentInk
                    font.family: Theme.bodySemibold
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
    Component {
        id: challengeComponent
        ChallengeCard {
            history: goals.challengeHistory
            nowMs: goals.nowMs
        }
    }
    Component {
        id: journeyComponent
        JourneyCard {
            journeyId: goals.journeyId
            ridden: goals.journeyRidden
            finished: goals.journeysDone
            miles: goals.miles
            onStartJourney: goals.startJourney(id)
        }
    }
    Component {
        id: badgesComponent
        BadgeGrid {
            badges: goals.badges
            miles: goals.miles
            onOpenBadge: goals.openBadge(id)
        }
    }
    Component {
        id: laddersComponent
        LaddersCard {
            lifetime: goals.lifetime
            miles: goals.miles
        }
    }

    Flickable {
        id: flick
        objectName: "goalsFlick"
        anchors.fill: parent
        contentHeight: content.height + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            readonly property real margin: Theme.margin(goals.width)
            readonly property bool twoColumns: goals.width >= 680
            readonly property int columns: twoColumns ? 2 : 1
            readonly property real columnWidth: twoColumns ? (width - 16) / 2 : width
            x: margin
            width: Math.min(goals.width - margin * 2, 1120)
            spacing: 16

            Item {
                width: parent.width
                height: header.height
                PageHeader {
                    id: header
                    width: parent.width
                    title: qsTr("Goals")
                    showYou: goals.showYou
                    initial: goals.initial
                    onOpenYou: goals.openYou()
                }
                PulseButton {
                    x: parent.width - width - (goals.showYou ? 56 : 0)
                    y: 10
                    width: customizeText.implicitWidth + 32
                    height: 48
                    topInset: 4
                    bottomInset: 4
                    radius: 20
                    fill: pressed ? Theme.pressed : Theme.chip
                    Accessible.name: qsTr("Customize the Goals cards")
                    onClicked: goals.openCustomize()
                    contentItem: Text {
                        id: customizeText
                        text: qsTr("Customize")
                        color: Theme.accent
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                width: parent.width
                visible: goals.shownIds.length === 0
                text: qsTr("Every card is hidden. Customize brings them back.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                wrapMode: Text.WordWrap
            }

            Row {
                spacing: 16
                Repeater {
                    model: content.columns
                    Column {
                        id: goalsColumn
                        readonly property int column: index
                        width: content.columnWidth
                        spacing: 16
                        Repeater {
                            model: goals.columnIds(goalsColumn.column, content.columns)
                            Loader {
                                id: goalsCardLoader
                                width: goalsColumn.width
                                sourceComponent: goals.componentFor(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    CustomizeSheet {
        hint: qsTr("Pick the Goals cards and their order.")
        anchors.fill: parent
        open: goals.customizing
        cards: goals.cards
        titles: goals.cardTitles
        onMoveCard: goals.moveCard(from, to)
        onShowCard: goals.showCard(id, shown)
        onClose: goals.customizing = false
    }

    BadgeSheet {
        anchors.fill: parent
        open: goals.badgeId !== ""
        badge: goals.openedBadge
        miles: goals.miles
        onClose: goals.badgeId = ""
    }

    WeeklyRecap {
        anchors.fill: parent
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
}
