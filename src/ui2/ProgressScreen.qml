import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "progress"
import "progress/Progress.js" as Progress
import "progress/Fitness.js" as Fitness
import "progress/Hub.js" as Hub
import "goals/Streak.js" as Streak

// The Progress hub in the Signature language: the period (4 weeks, 3 months, 1 year) and the
// detail level (Simple, Pro) at the top, then quiet sections on hairlines the rider can hide and
// reorder (Customize): what the period means as a coach would say it (the one raised surface),
// fitness, fatigue and form over their bands, the estimated FTP as steps, the power curve against
// the period before, the weekly volume with its 4 week average, a year of consistency, every
// record and this week, month or year against the last. One column on phones, two from 720 wide,
// each section going to the shorter column. A new period draws the charts in again and rolls
// the numbers; everything rises in each time the screen shows.
Item {
    id: progressPage
    objectName: "progressScreen"

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"
    // the end of the page the floating navigation covers: the content scrolls under it
    property real bottomClearance: 0

    signal openYou()
    signal openRide(int id)
    // each time the screen shows: the sections rise in again
    signal entered()
    // the library changed: every section reads it again
    signal reload()
    // the period changed: the sections that follow it read it again
    signal periodReload()
    // the charts draw in again
    signal replay()

    readonly property var cardIds: ["insight", "fitness", "ftp", "curve", "volume", "consistency", "records", "compare"]
    readonly property var cardTitles: ({
        insight: qsTr("This period"),
        fitness: qsTr("Fitness and form"),
        ftp: qsTr("FTP"),
        curve: qsTr("Power curve"),
        volume: qsTr("Weekly volume"),
        consistency: qsTr("Consistency"),
        records: qsTr("Records"),
        compare: qsTr("Compare periods")
    })
    property var cards: Progress.cardList("", cardIds)
    property string detailLevel: "simple"
    property string period: "3m"
    property real weight: 0          // kg, 0 when the rider has not set it
    property real ftpSetting: 0
    property bool customizing: false
    // the weekly goal as set on Goals, rules in goals/Streak.js
    property string goalKind: "minutes"
    property real goalValue: 120
    property var restWeeks: []
    property var streakResult: ({ streak: 0, freezes: 0, toNextFreeze: 0 })
    // Fitness.series() from half a year before the year shown, so the year starts warmed up
    property var series: []

    readonly property bool pro: detailLevel === "pro"
    readonly property bool hasRides: library !== null && library.rideCount > 0
    readonly property var shownIds: {
        var out = []
        for (var i = 0; i < cards.length; i++)
            if (cards[i].shown)
                out.push(cards[i].id)
        return out
    }
    readonly property var insightWords: {
        var n = series.length
        if (n === 0)
            return Hub.insight(period, Date.now(), 0, 0, "start")
        var last = series[n - 1]
        var first = series[Math.max(0, n - Hub.days(period))]
        return Hub.insight(period, first.day, first.ctl, last.ctl, Fitness.formLabel(last.ctl, last.tsb))
    }

    // You, Goals and Customize change these through their own Settings objects, and
    // Qt.labs.settings does not tell the others: read them again each time the screen shows
    function readSettings() {
        detailLevel = String(uiStore.value("detailLevel", "simple"))
        var p = Hub.period(String(uiStore.value("progressPeriod", "3m")))
        if (p !== period) {
            period = p
            periodReload()
        }
        weight = Number(qzStore.value("weight", 0)) || 0
        ftpSetting = Number(qzStore.value("ftp", 0)) || 0
        var kind = String(uiStore.value("goalKind", "minutes"))
        goalKind = Streak.kinds.indexOf(kind) >= 0 ? kind : "minutes"
        goalValue = Number(uiStore.value(Streak.settingKeys[goalKind], Streak.defaults[goalKind])) || Streak.defaults[goalKind]
        restWeeks = Streak.parseList(String(uiStore.value("restWeeks", "[]")))
        // a new list rebuilds every section, so only when it changed
        var saved = Progress.cardList(String(uiStore.value("progressCards", "")), cardIds)
        if (Progress.cardJson(saved) !== Progress.cardJson(cards))
            cards = saved
    }

    // fitness and the streak: cheap, worked out each time the screen shows
    function refresh() {
        if (!library) {
            series = []
            streakResult = { streak: 0, freezes: 0, toNextFreeze: 0 }
            return
        }
        var now = Date.now()
        var first = Progress.noon(now)
        first.setDate(first.getDate() - 365 - 182)
        series = Fitness.series(library.days(first.getTime() - 13 * 3600000, 0), first.getTime(), now)
        var weeks = Streak.perWeek(library.days(0, 0))
        streakResult = Streak.run(weeks, { kind: goalKind, goal: goalValue, rest: restWeeks, now: now })
    }

    function setPeriod(p) {
        if (p === period)
            return
        period = p
        uiStore.setValue("progressPeriod", p)
        periodReload()
        replay()
    }

    function setPro(on) {
        detailLevel = on ? "pro" : "simple"
        uiStore.setValue("detailLevel", detailLevel)
    }

    function saveCards(list) {
        cards = list
        uiStore.setValue("progressCards", Progress.cardJson(list))
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

    // about how tall each section is, to send each one to the shorter column; fixed, so Simple
    // and Pro never move a section (a new column list would make every section again)
    function weightOf(cardId) {
        var w = { insight: 1.4, fitness: 4, ftp: 2, curve: 3.4, volume: 2.8, consistency: 2.6,
                  records: 8, compare: 4 }
        return w[cardId] || 3
    }

    // the shown sections of one column
    function columnIds(column, columns) {
        if (columns < 2)
            return column === 0 ? shownIds : []
        var heights = [0, 0]
        var out = []
        for (var i = 0; i < shownIds.length; i++) {
            var side = heights[1] < heights[0] ? 1 : 0
            heights[side] += weightOf(shownIds[i])
            if (side === column)
                out.push(shownIds[i])
        }
        return out
    }

    function componentFor(cardId) {
        if (cardId === "insight")
            return insightSection
        if (cardId === "fitness")
            return fitnessSection
        if (cardId === "ftp")
            return ftpSection
        if (cardId === "curve")
            return curveSection
        if (cardId === "volume")
            return volumeSection
        if (cardId === "consistency")
            return consistencySection
        if (cardId === "records")
            return recordsSection
        return compareSection
    }

    function openCustomize() {
        customizing = true
    }

    // Android back closes the sheet first
    function goBack() {
        if (customizing) {
            customizing = false
            return true
        }
        return false
    }

    onLibraryChanged: {
        refresh()
        reload()
    }
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
        onTriggered: {
            progressPage.refresh()
            progressPage.reload()
        }
    }
    Connections {
        target: progressPage.library
        ignoreUnknownSignals: true
        function onChanged() { refreshLater.restart() }
    }

    Settings {
        id: uiStore
        category: "ui2"
    }
    Settings {
        id: qzStore
    }

    Component {
        id: insightSection
        InsightBlock {
            headline: progressPage.insightWords.headline
            line: progressPage.insightWords.line
        }
    }
    Component {
        id: fitnessSection
        FitnessChart {
            id: fitnessChart
            all: progressPage.series
            range: Hub.days(progressPage.period)
            pro: progressPage.pro
            Connections {
                target: progressPage
                function onReplay() { fitnessChart.play() }
                function onEntered() { fitnessChart.play() }
            }
        }
    }
    Component {
        id: ftpSection
        FtpTrend {
            id: ftpTrend
            library: progressPage.library
            period: progressPage.period
            pro: progressPage.pro
            setting: progressPage.ftpSetting
            Component.onCompleted: refresh()
            Connections {
                target: progressPage
                function onReload() { ftpTrend.refresh() }
                function onPeriodReload() { ftpTrend.refresh() }
                function onReplay() { ftpTrend.play() }
                function onEntered() { ftpTrend.play() }
            }
        }
    }
    Component {
        id: curveSection
        PowerCurve {
            id: powerCurve
            library: progressPage.library
            weight: progressPage.weight
            period: progressPage.period
            pro: progressPage.pro
            onOpenRide: progressPage.openRide(id)
            Component.onCompleted: refresh()
            Connections {
                target: progressPage
                function onReload() { powerCurve.refresh() }
                function onPeriodReload() { powerCurve.refresh() }
                function onReplay() { powerCurve.play() }
                function onEntered() { powerCurve.play() }
            }
        }
    }
    Component {
        id: volumeSection
        VolumeCard {
            id: volumeCard
            library: progressPage.library
            miles: progressPage.miles
            period: progressPage.period
            pro: progressPage.pro
            Component.onCompleted: refresh()
            Connections {
                target: progressPage
                function onReload() { volumeCard.refresh() }
                function onPeriodReload() { volumeCard.refresh() }
                function onReplay() { volumeCard.play() }
                function onEntered() { volumeCard.play() }
            }
        }
    }
    Component {
        id: consistencySection
        ConsistencyCard {
            id: consistencyCard
            library: progressPage.library
            streak: progressPage.streakResult.streak
            freezes: progressPage.streakResult.freezes
            toNextFreeze: progressPage.streakResult.toNextFreeze
            Component.onCompleted: refresh()
            Connections {
                target: progressPage
                function onReload() { consistencyCard.refresh() }
                function onReplay() { consistencyCard.play() }
                function onEntered() { consistencyCard.play() }
            }
        }
    }
    Component {
        id: recordsSection
        RecordsBoard {
            id: recordsBoard
            library: progressPage.library
            miles: progressPage.miles
            weight: progressPage.weight
            pro: progressPage.pro
            onOpenRide: progressPage.openRide(id)
            Component.onCompleted: refresh()
            Connections {
                target: progressPage
                function onReload() { recordsBoard.refresh() }
            }
        }
    }
    Component {
        id: compareSection
        PeriodCompare {
            id: periodCompare
            library: progressPage.library
            miles: progressPage.miles
            pro: progressPage.pro
            Component.onCompleted: refresh()
            Connections {
                target: progressPage
                function onReload() { periodCompare.refresh() }
            }
        }
    }

    // the period and the detail level, as wide as the Loader holding them
    Component {
        id: toggles
        Row {
            id: toggleRow
            // short words when "3 months" would not fit its segment
            readonly property bool narrow: width < 348
            spacing: width < 400 ? 8 : 12
            SegmentedToggle {
                width: toggleRow.width - detailToggle.width - toggleRow.spacing
                height: 44
                name: qsTr("Period")
                options: toggleRow.narrow ? [qsTr("4 wk"), qsTr("3 mo"), qsTr("1 yr")] : [qsTr("4 weeks"), qsTr("3 months"), qsTr("1 year")]
                currentIndex: Hub.periods.indexOf(progressPage.period)
                // a tap sets currentIndex itself: bind it again, so a period read from the
                // settings still shows
                onPicked: {
                    progressPage.setPeriod(Hub.periods[index])
                    currentIndex = Qt.binding(function () { return Hub.periods.indexOf(progressPage.period) })
                }
            }
            SegmentedToggle {
                id: detailToggle
                width: toggleRow.width < 400 ? 124 : 144
                height: 44
                name: qsTr("Detail")
                options: [qsTr("Simple"), qsTr("Pro")]
                currentIndex: progressPage.pro ? 1 : 0
                onPicked: {
                    progressPage.setPro(index === 1)
                    currentIndex = Qt.binding(function () { return progressPage.pro ? 1 : 0 })
                }
            }
        }
    }

    Flickable {
        id: flick
        objectName: "progressFlick"
        anchors.fill: parent
        contentHeight: page.height + progressPage.bottomClearance + 24
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: page
            readonly property real margin: progressPage.width < 400 ? 16 : 24
            readonly property bool wide: progressPage.width >= 720
            readonly property int columns: wide ? 2 : 1
            readonly property real gutter: 40
            readonly property real columnWidth: wide ? (width - gutter) / 2 : width
            // the toggles sit on the title line when there is room
            readonly property bool togglesInHeader: width >= 760
            x: Math.max(margin, (progressPage.width - width) / 2)
            // one column keeps to a phone's measure, centered on a wider window
            width: Math.min(progressPage.width - margin * 2, wide ? 1120 : 560)
            spacing: 0

            Rise {
                cue: progressPage
                order: 0
                width: parent.width
                Item {
                    width: parent.width
                    height: header.height
                    PageHeader {
                        id: header
                        width: parent.width
                        title: qsTr("Progress")
                        showYou: progressPage.showYou
                        initial: progressPage.initial
                        onOpenYou: progressPage.openYou()
                    }
                    // the toggles on the title line when there is room
                    Loader {
                        active: page.togglesInHeader && progressPage.hasRides
                        x: (progressPage.hasRides ? customizeButton.x : parent.width) - width - 16
                        y: 24
                        width: 300 + 12 + 144
                        height: 44
                        sourceComponent: toggles
                    }
                    PulseButton {
                        id: customizeButton
                        visible: progressPage.hasRides
                        x: parent.width - width - (progressPage.showYou ? 56 : 0)
                        // on the line of the title and the You button
                        y: 22
                        width: customizeText.implicitWidth + 32
                        height: 48
                        topInset: 4
                        bottomInset: 4
                        radius: 20
                        fill: pressed ? Theme.pressed : Theme.chip
                        Accessible.name: qsTr("Customize the Progress sections")
                        onClicked: progressPage.openCustomize()
                        contentItem: Text {
                            id: customizeText
                            text: qsTr("Customize")
                            color: Theme.accent
                            font.family: Theme.bodySemibold
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Rise {
                cue: progressPage
                order: 1
                width: parent.width
                Item {
                    width: parent.width
                    height: page.togglesInHeader || !progressPage.hasRides ? 12 : 44 + 30
                    Loader {
                        active: !page.togglesInHeader && progressPage.hasRides
                        width: parent.width
                        height: 44
                        sourceComponent: toggles
                    }
                }
            }

            Text {
                width: parent.width
                visible: !progressPage.hasRides
                topPadding: 8
                text: qsTr("Your records and trends start with your first ride.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 15
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                visible: progressPage.hasRides && progressPage.shownIds.length === 0
                text: qsTr("Every section is hidden. Customize brings them back.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 15
                wrapMode: Text.WordWrap
            }

            Row {
                visible: progressPage.hasRides
                spacing: page.gutter
                Repeater {
                    model: page.columns
                    Column {
                        id: sectionColumn
                        readonly property int column: index
                        width: page.columnWidth
                        spacing: 40
                        Repeater {
                            model: progressPage.columnIds(sectionColumn.column, page.columns)
                            Rise {
                                id: sectionRise
                                cue: progressPage
                                order: Math.min(7, 2 + index * page.columns + sectionColumn.column)
                                width: sectionColumn.width
                                Loader {
                                    width: parent.width
                                    sourceComponent: progressPage.componentFor(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    CustomizeSheet {
        anchors.fill: parent
        open: progressPage.customizing
        hint: qsTr("Pick the Progress sections and their order.")
        cards: progressPage.cards
        titles: progressPage.cardTitles
        onMoveCard: progressPage.moveCard(from, to)
        onShowCard: progressPage.showCard(id, shown)
        onClose: progressPage.customizing = false
    }
}
