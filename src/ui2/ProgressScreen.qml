import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "progress"
import "learn"
import "Format.js" as Format
import "learn/Learn.js" as Learn
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
// the numbers; everything rises in each time the screen shows. "Your year in one picture" shows
// the hours of each of the last 12 months with the biggest one lit.
// Tap to learn: every chart, big number and section label opens a Learn sheet
// (learn/LearnSheet.qml) with what it is, what the rider's own numbers say, why it matters and
// one thing to try; holding or dragging a chart still reads it out.
Item {
    id: progressPage
    objectName: "progressScreen"

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
    signal openRide(int id)
    // each time the screen shows: the sections rise in again
    signal entered()
    // the library changed: every section reads it again
    signal reload()
    // the period changed: the sections that follow it read it again
    signal periodReload()
    // the charts draw in again
    signal replay()

    readonly property var cardIds: ["insight", "fitness", "ftp", "curve", "volume", "year", "consistency", "records", "compare"]
    readonly property var cardTitles: ({
        year: qsTr("Your year in one picture"),
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

    // the Learn sheet: open, what it shows, and the facts each section last gave, so a related
    // link back to a section still has the rider's numbers
    property bool learnOpen: false
    property var learnEntry: null
    property var learnStore: ({})
    // the entries the page fills itself, and those of the sections that are shown
    readonly property var learnIds: ["period", "fitness", "fatigue", "form", "tss", "zones", "if", "bests", "streak", "freezes"]
                                    .concat(Object.keys(learnStore))
    // a sheet covers the page: the shell can move the floating navigation aside
    readonly property bool covering: customizing || learnOpen

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

    // what the Learn sheet of an entry says about this rider: what a section gave, else what the
    // page knows itself
    function factsFor(id) {
        var f = learnStore[id] ? JSON.parse(JSON.stringify(learnStore[id])) : {}
        f.rides = library ? library.rideCount : 0
        if ((id === "fitness" || id === "fatigue" || id === "form") && series.length > 0 && f.ctl === undefined) {
            var n = series.length
            var last = series[n - 1]
            var before = series[Math.max(0, n - 29)]
            f.ctl = last.ctl
            f.atl = last.atl
            f.tsb = last.tsb
            f.state = Fitness.formLabel(last.ctl, last.tsb)
            f.change = last.ctl - before.ctl
            f.days = 28
        }
        if (id === "period") {
            f.headline = insightWords.headline
            f.line = insightWords.line
        }
        if (id === "streak") {
            f.streak = streakResult.streak
            f.goalText = goalKind === "rides" ? qsTr("%1 rides").arg(Math.round(goalValue))
                         : (goalKind === "kj" ? Format.big(goalValue) + " kJ"
                         : (goalKind === "km" ? Format.distance(goalValue, miles) : Math.round(goalValue) + " min"))
        }
        if (id === "freezes") {
            f.freezes = streakResult.freezes || 0
            f.toNext = streakResult.toNextFreeze || 0
        }
        if (id === "bests" && library) {
            var curve = library.powerCurve(0, 0)
            for (var i = 0; i < curve.length; i++)
                f["b" + curve[i].seconds] = curve[i].watts
        }
        return f
    }

    // a section tells what its Learn sheet would say, each time its data changes
    function remember(id, facts) {
        var store = {}
        for (var key in learnStore)
            store[key] = learnStore[key]
        store[id] = facts
        learnStore = store
    }

    // opens the Learn sheet of an entry; facts are what the section knows (kept for later)
    function openLearn(id, facts) {
        if (facts)
            remember(id, facts)
        learnEntry = Learn.entry(id, factsFor(id))
        learnOpen = true
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
        var w = { insight: 1.4, fitness: 4, ftp: 2, curve: 3.4, volume: 2.8, year: 2.6, consistency: 2.6,
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
        // fitness, fatigue and form are worked out from FTP: a note in their place until it is set
        if (cardId === "fitness")
            return Theme.ftpSet ? fitnessSection : fitnessNeedsFtp
        if (cardId === "ftp")
            return ftpSection
        if (cardId === "curve")
            return curveSection
        if (cardId === "volume")
            return volumeSection
        if (cardId === "year")
            return yearSection
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

    onLibraryChanged: {
        refresh()
        reload()
    }
    onVisibleChanged: {
        if (!visible) {
            learnOpen = false
            return
        }
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
        LearnTap {
            name: progressPage.insightWords.headline + " " + progressPage.insightWords.line
            pressedScale: 0.98
            fill: "transparent"
            onClicked: progressPage.openLearn("period", null)
            InsightBlock {
                width: parent.width
                headline: progressPage.insightWords.headline
                line: progressPage.insightWords.line
                Accessible.ignored: true
            }
        }
    }
    Component {
        id: fitnessNeedsFtp
        Column {
            spacing: 8
            SectionHead {
                width: parent.width
                title: qsTr("Fitness and form")
            }
            Text {
                width: parent.width
                text: qsTr("Your fitness, fatigue and form are worked out from your FTP. Set it in You, Body and FTP, or take the one Today offers from your rides.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 14
                lineHeightMode: Text.FixedHeight
                lineHeight: 20
                wrapMode: Text.WordWrap
            }
        }
    }
    Component {
        id: fitnessSection
        FitnessChart {
            id: fitnessChart
            all: progressPage.series
            range: Hub.days(progressPage.period)
            pro: progressPage.pro
            onLearn: progressPage.openLearn(key, facts)
            Connections {
                target: progressPage
                function onReplay() { fitnessChart.play() }
                function onEntered() { fitnessChart.play() }
            }
        }
    }
    Component {
        id: ftpSection
        LearnTap {
            id: ftpTap
            name: qsTr("FTP, %1 watts estimated").arg(Math.round(ftpTrend.current))
            onClicked: progressPage.openLearn("ftp", ftpFacts())
            function ftpFacts() {
                return { current: ftpTrend.current, firstValue: ftpTrend.firstStep ? ftpTrend.firstStep.value : 0,
                         sinceText: ftpTrend.firstStep ? Format.monthNames[new Date(ftpTrend.firstStep.start).getMonth()] : "",
                         setting: progressPage.ftpSetting }
            }
            FtpTrend {
                id: ftpTrend
                width: parent.width
                onStepsChanged: progressPage.remember("ftp", ftpTap.ftpFacts())
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
            onLearn: progressPage.openLearn(key, facts)
            onPointsChanged: progressPage.remember("curve", powerCurve.learnFacts())
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
        LearnTap {
            id: volumeTap
            name: qsTr("Weekly volume")
            onClicked: progressPage.openLearn("volume", volumeFacts())
            // last week against the 4 week average, in words
            function volumeFacts() {
                var v = volumeCard
                if (!v.lastWeek)
                    return {}
                var last = v.value(v.lastWeek)
                var avg = v.averages.length > 0 ? v.averages[v.averages.length - 1] : 0
                function words(x) {
                    return v.shownMetric === "seconds" ? Format.hours(x * 3600) : v.bigText(x) + " " + v.unitText()
                }
                return { last: last, avg: avg, lastText: words(last), avgText: avg > 0 ? words(avg) : "" }
            }
            VolumeCard {
                id: volumeCard
                width: parent.width
                onWeeksChanged: progressPage.remember("volume", volumeTap.volumeFacts())
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
    }
    Component {
        id: yearSection
        YearCard {
            id: yearCard
            library: progressPage.library
            onClicked: progressPage.openLearn("year", yearCard.learnFacts())
            onMonthsChanged: progressPage.remember("year", yearCard.learnFacts())
            Component.onCompleted: {
                refresh()
                play()
            }
            Connections {
                target: progressPage
                function onReload() { yearCard.refresh() }
                function onReplay() { yearCard.play() }
                function onEntered() { yearCard.play() }
            }
        }
    }
    Component {
        id: consistencySection
        LearnTap {
            name: qsTr("Consistency, %1 active weeks of 52").arg(consistencyCard.activeWeeks)
            onClicked: progressPage.openLearn("consistency", { activeWeeks: consistencyCard.activeWeeks })
            ConsistencyCard {
                id: consistencyCard
                width: parent.width
                onActiveWeeksChanged: progressPage.remember("consistency", { activeWeeks: consistencyCard.activeWeeks })
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
            onLearn: progressPage.openLearn(key, facts)
            onAllPowerRowsChanged: progressPage.remember("records", recordsBoard.learnFacts())
            Component.onCompleted: refresh()
            Connections {
                target: progressPage
                function onReload() { recordsBoard.refresh() }
            }
        }
    }
    Component {
        id: compareSection
        LearnTap {
            id: compareTap
            name: qsTr("Compare periods")
            function compareFacts() {
                return { span: periodCompare.span === "week" ? qsTr("week") : (periodCompare.span === "month" ? qsTr("month") : qsTr("year")),
                         nowText: Format.hours(periodCompare.now.seconds || 0), beforeText: Format.hours(periodCompare.before.seconds || 0) }
            }
            onClicked: progressPage.openLearn("compare", compareFacts())
            PeriodCompare {
                id: periodCompare
                width: parent.width
                onBeforeChanged: progressPage.remember("compare", compareTap.compareFacts())
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

    LearnSheet {
        anchors.fill: parent
        z: 2
        open: progressPage.learnOpen
        entry: progressPage.learnEntry
        known: progressPage.learnIds
        bottomInset: progressPage.sheetClearance
        onClose: progressPage.learnOpen = false
        onRelated: progressPage.openLearn(id, null)
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
