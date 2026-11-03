import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "calendar"
import "today"
import "Format.js" as Format
import "progress/Progress.js" as Progress
import "goals/Streak.js" as Streak
import "today/Insights.js" as Insights
import "today/Coach.js" as Coach

// Home, in the Signature language: the date and You at the top, the rider's form as one number
// in the breathing Pulse (today/Coach.js says how it is worked out), what a coach would say about
// it, ONE raised card with the ride to do now, and then the week as Pulse shapes and quiet
// sections on hairlines that the rider can hide and reorder (Customize): insights, the latest
// ride, a record within reach, best power, this day last year, all the rides so far and the
// year. Everything rises in, one block after the other, each time the screen shows.
// On wide windows the hero and the card stay on the left and the rest goes to a right column.
Item {
    id: todayPage
    objectName: "todayScreen"

    property var library: null
    property bool connected: false
    property string deviceName: ""
    property string searchStatus: ""
    property bool miles: false
    property string nickname: ""
    property bool showYou: true
    property string initial: "B"
    // the end of the page the floating navigation covers: the content scrolls under it
    property real bottomClearance: 0

    signal rideRequested()
    signal demoRequested()
    signal searchAgain()
    signal openYou()
    signal openRide(int id)
    signal openTab(string name)
    // each time the screen shows: the blocks rise in again
    signal entered()

    readonly property var cardIds: ["week", "insights", "latest", "reach", "bests", "onthisday", "lifetime", "year"]
    readonly property var cardTitles: ({
        week: qsTr("This week"),
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
    property var shownIds: ["week", "first"]
    // Coach.readiness(), Coach.words(), Coach.suggest(), Coach.weekDays()
    property var ready: Coach.readiness([], 0, Date.now())
    property var coachWords: Coach.words(ready)
    property var suggestion: Coach.suggest(ready, null, "")
    property bool swapped: false
    property var weekDays: Coach.weekDays([], Date.now())

    readonly property var plan: swapped ? suggestion.other : suggestion.main
    readonly property bool formShown: ready.hasForm === true
    readonly property var heroWeek: Coach.weekHero(weekValue, goalValue, goalKind, miles)

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

    function componentFor(cardId) {
        if (cardId === "first")
            return firstComponent
        if (cardId === "week")
            return weekComponent
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

    // where an insight leads
    function act(action) {
        if (!action)
            return
        if (action.kind === "ride")
            rideRequested()
        else if (action.kind === "openRide")
            openRide(action.rideId)
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
    function readSettings() {
        var kind = String(uiStore.value("goalKind", "minutes"))
        goalKind = Streak.kinds.indexOf(kind) >= 0 ? kind : "minutes"
        goalValue = Number(uiStore.value(Streak.settingKeys[goalKind], Streak.defaults[goalKind])) || Streak.defaults[goalKind]
        restWeeks = Streak.parseList(String(uiStore.value("restWeeks", "[]")))
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
        return true
    }

    // Which sections show, from the setting and the data. A new list rebuilds every section, so
    // only when it changed.
    function layout() {
        var ids = []
        // the coach line already welcomes the rider back
        var told = ["welcome"]
        if (rideCount === 0) {
            ids = ["week", "first"]
        } else {
            for (var i = 0; i < cards.length; i++) {
                var cardId = cards[i].id
                if (!cards[i].shown || !hasContent(cardId))
                    continue
                ids.push(cardId)
                if (cardId === "reach")
                    told.push("reach")
                else if (cardId === "onthisday")
                    told.push("onThisDay")
                else if (cardId === "lifetime")
                    told.push("milestone")
                else if (cardId === "week" && found.goalStreak >= 2)
                    told.push("streak")
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
            coachWords = Coach.words(ready)
            suggestion = Coach.suggest(ready, null, "")
            weekDays = Coach.weekDays([], now)
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
        goalStreak = Streak.run(weeks, { kind: goalKind, goal: goalValue, rest: restWeeks, now: now }).streak
        found = Insights.build({
            rides: recent,
            days: allDays,
            curveAll: curve,
            curveRecent: library.powerCurve(now - Insights.sixWeeks, 0),
            curvePrior: library.powerCurve(now - 2 * Insights.sixWeeks, now - Insights.sixWeeks),
            latestBest: latest ? (library.ride(latest.id).best || []) : [],
            lifetime: lifetime,
            goalStreak: goalStreak,
            miles: miles
        }, now)
        ready = Coach.readiness(allDays, latest ? latest.start : 0, now)
        coachWords = Coach.words(ready)
        suggestion = Coach.suggest(ready, found.reach, found.reach ? Format.effort(found.reach.seconds) : "")
        weekDays = Coach.weekDays(recent, now)
        layout()
    }

    onLibraryChanged: refresh()
    onMilesChanged: refreshLater.restart()
    onVisibleChanged: {
        if (!visible)
            return
        readSettings()
        refresh()
        entered()
    }
    Component.onCompleted: {
        readSettings()
        refresh()
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

    Component {
        id: firstComponent
        FirstRideCard {
            busy: todayPage.library ? todayPage.library.busy : false
            indexed: todayPage.library ? todayPage.library.indexed : 0
            toIndex: todayPage.library ? todayPage.library.toIndex : 0
        }
    }
    Component {
        id: weekComponent
        WeekCard {
            days: todayPage.weekDays
            summary: Coach.goalText(todayPage.weekValue, todayPage.goalValue, todayPage.goalKind, todayPage.miles)
            met: todayPage.goalValue > 0 && todayPage.weekValue >= todayPage.goalValue - 1e-9
            onOpenGoals: todayPage.openTab("goals")
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
        }
    }
    Component {
        id: bestsComponent
        BestsCard {
            bests: todayPage.bests
            onOpenRide: todayPage.openRide(id)
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
            onOpenGoals: todayPage.openTab("goals")
        }
    }
    Component {
        id: yearComponent
        Column {
            spacing: 12
            CapLabel {
                text: qsTr("Your year")
            }
            CalendarHeatmap {
                width: parent.width
                library: todayPage.library
                onDayClicked: todayPage.openDay(dayMs)
            }
        }
    }

    // the glow of the hero, outside the Flickable so it reaches into the top of the screen; it
    // follows the hero as the page scrolls
    HeroGlow {
        // mapToItem tells no change: name what moves the hero, so the binding runs again
        readonly property point center: {
            var moved = flick.contentY + flick.contentX + content.x + content.width + lead.y + hero.x
            return hero.mapToItem(todayPage, hero.width / 2, hero.height / 2)
        }
        width: 480
        height: 480
        x: center.x - width / 2
        y: center.y - height / 2
        tint: hero.tint
        Accessible.ignored: true
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

            // the date, the bike once it is there, and You where the navigation has none
            Item {
                id: header
                y: 24
                width: content.leftWidth
                height: 44
                Text {
                    width: parent.width - (youButton.visible ? youButton.width + 8 : 0) - (bikeStatus.visible ? bikeStatus.width + 12 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                    color: Theme.text
                    font.family: Theme.bodyMedium
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Row {
                    id: bikeStatus
                    visible: todayPage.connected
                    anchors.right: youButton.visible ? youButton.left : parent.right
                    anchors.rightMargin: youButton.visible ? 10 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Accessible.role: Accessible.StaticText
                    Accessible.name: bikeName.text
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.zoneColors[1]
                    }
                    Text {
                        id: bikeName
                        width: Math.min(implicitWidth, 150)
                        text: todayPage.deviceName !== "" ? todayPage.deviceName : qsTr("Bike ready")
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                PulseButton {
                    id: youButton
                    visible: todayPage.showYou
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // 48 to touch, 44 to see
                    width: 48
                    height: 48
                    topInset: 2
                    bottomInset: 2
                    leftInset: 2
                    rightInset: 2
                    fill: pressed ? Theme.pressed : Theme.control
                    Accessible.name: qsTr("You, profile and settings")
                    onClicked: todayPage.openYou()
                    contentItem: Text {
                        text: todayPage.initial
                        color: Theme.accent
                        font.family: Theme.bodySemibold
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // the hero, the coach and the ride to do now
            Column {
                id: lead
                y: header.y + header.height + 8
                width: content.leftWidth

                Rise {
                    objectName: "heroRise"
                    cue: todayPage
                    order: 0
                    width: parent.width
                    Item {
                        width: parent.width
                        height: 136
                        PulseHero {
                            id: hero
                            objectName: "todayHero"
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 136
                            height: 136
                            glow: false
                            zone: 2
                            value: todayPage.formShown ? String(todayPage.ready.ready) : todayPage.heroWeek.value
                            word: todayPage.formShown ? todayPage.ready.word : todayPage.heroWeek.word
                            summary: todayPage.formShown ? qsTr("%1, ready %2 of 100").arg(todayPage.ready.word).arg(todayPage.ready.ready)
                                                         : qsTr("This week %1 %2").arg(todayPage.heroWeek.value).arg(todayPage.heroWeek.word)
                        }
                    }
                }
                Item { width: 1; height: 14 }
                Rise {
                    cue: todayPage
                    order: 1
                    width: parent.width
                    Column {
                        width: parent.width
                        spacing: 10
                        Text {
                            width: parent.width
                            text: todayPage.balanced(todayPage.coachWords.headline)
                            color: Theme.text
                            font.family: Theme.display
                            font.pixelSize: content.wide || todayPage.width >= 400 ? 30 : 28
                            font.letterSpacing: -0.6
                            lineHeightMode: Text.FixedHeight
                            lineHeight: Math.round(font.pixelSize * 1.08)
                            wrapMode: Text.WordWrap
                            Accessible.role: Accessible.Heading
                            Accessible.name: todayPage.coachWords.headline
                        }
                        Text {
                            width: parent.width
                            text: todayPage.coachWords.line
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 14
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 20
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                Item { width: 1; height: 14 }
                Rise {
                    cue: todayPage
                    order: 2
                    width: parent.width
                    SuggestionCard {
                        width: parent.width
                        plan: todayPage.plan
                        swapLabel: todayPage.swapped ? qsTr("Back to %1").arg(todayPage.suggestion.main.name) : todayPage.suggestion.otherLabel
                        firstRide: todayPage.rideCount === 0
                        onRideRequested: todayPage.rideRequested()
                        onSwap: todayPage.swapped = !todayPage.swapped
                        onDemoRequested: todayPage.demoRequested()
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
                            height: 44
                            fill: pressed ? Theme.pressed : "transparent"
                            Accessible.name: qsTr("Customize Today")
                            onClicked: todayPage.customizing = true
                            contentItem: Text {
                                id: customizeText
                                text: qsTr("Customize Today")
                                color: Theme.accent
                                font.family: Theme.bodySemibold
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        PulseButton {
                            visible: todayPage.rideCount > 0
                            width: demoText.implicitWidth + 24
                            height: 44
                            fill: pressed ? Theme.pressed : "transparent"
                            Accessible.name: qsTr("Try a demo ride, no bike needed")
                            onClicked: todayPage.demoRequested()
                            contentItem: Text {
                                id: demoText
                                text: qsTr("Try a demo ride")
                                color: Theme.text2
                                font.family: Theme.bodySemibold
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
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
