import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../Format.js" as Format
import "Fitness.js" as Fitness
import "Progress.js" as Progress

// Fitness, fatigue and form (see Fitness.js) over the last weeks: two lines above, form as bars
// around zero below, today's three numbers on top with what they mean. On the Simple detail
// level the card says in one sentence where fitness is going, and the chart is one tap away.
Card {
    id: card
    objectName: "fitnessChart"

    property var library: null
    property bool pro: false

    property int range: 91           // days shown: 42, 91 or 182
    property bool revealed: false    // the chart, asked for on the Simple level
    property var all: []             // a year of days, see Fitness.series()
    property int cursor: -1          // index in shownDays, -1 when the crosshair is hidden

    readonly property bool full: pro || revealed
    readonly property var shownDays: all.slice(Math.max(0, all.length - range))
    readonly property bool hasRides: {
        for (var i = 0; i < all.length; i++)
            if (all[i].tss > 0)
                return true
        return false
    }
    readonly property var today: all.length > 0 ? all[all.length - 1] : ({ ctl: 0, atl: 0, tsb: 0, day: Date.now() })
    readonly property var shownDay: cursor >= 0 && cursor < shownDays.length ? shownDays[cursor] : today
    readonly property string formState: Fitness.formLabel(shownDay.ctl, shownDay.tsb)
    readonly property real scaleTop: {
        var hi = 0
        for (var i = 0; i < shownDays.length; i++)
            hi = Math.max(hi, shownDays[i].ctl, shownDays[i].atl)
        return Progress.niceTop(Math.max(20, hi * 1.08))
    }
    readonly property real formTop: {
        var hi = 0
        for (var i = 0; i < shownDays.length; i++)
            hi = Math.max(hi, Math.abs(shownDays[i].tsb))
        return Progress.niceTop(Math.max(10, hi))
    }

    property var drawn: ({ ctl: [], atl: [] })

    function stateName(key) {
        if (key === "veryFresh")
            return qsTr("Very fresh")
        if (key === "fresh")
            return qsTr("Fresh")
        if (key === "steady")
            return qsTr("Steady")
        if (key === "building")
            return qsTr("Building")
        if (key === "overreaching")
            return qsTr("Overreaching")
        return qsTr("Getting started")
    }

    function stateText(key) {
        if (key === "veryFresh")
            return qsTr("Well rested. A long break starts to cost fitness.")
        if (key === "fresh")
            return qsTr("Rested and ready for a hard ride or an event.")
        if (key === "steady")
            return qsTr("Training and recovery are in balance.")
        if (key === "building")
            return qsTr("Training is raising your fitness.")
        if (key === "overreaching")
            return qsTr("More load than you can absorb for long. Plan easy days.")
        return qsTr("Ride a few times a week and your fitness shows here.")
    }

    function formColor(tsb) {
        if (tsb >= 0.5)
            return Theme.zoneColors[2]
        if (tsb < -30)
            return Theme.zoneColors[3]
        return Theme.text2
    }

    function signed(v) {
        var r = Math.round(v)
        return r > 0 ? "+" + r : String(r)
    }

    function refresh() {
        cursor = -1
        if (!library) {
            all = []
            return
        }
        // a year of history: fitness forgets old rides within months, so the shown weeks are right
        var now = Date.now()
        var first = Progress.noon(now)
        first.setDate(first.getDate() - 364)
        all = Fitness.series(library.days(first.getTime() - 13 * 3600000, 0), first.getTime(), now)
        rebuild()
    }

    function xOf(i) {
        return shownDays.length > 1 ? i / (shownDays.length - 1) * plot.width : 0
    }

    function yOf(v) {
        return plot.height * (1 - Math.max(0, v) / scaleTop)
    }

    function rebuild() {
        var c = []
        var a = []
        if (plot.width > 1)
            for (var i = 0; i < shownDays.length; i++) {
                c.push(Qt.point(xOf(i), yOf(shownDays[i].ctl)))
                a.push(Qt.point(xOf(i), yOf(shownDays[i].atl)))
            }
        drawn = { ctl: c, atl: a }
    }

    function dayAt(x) {
        if (shownDays.length < 2)
            return -1
        return Math.max(0, Math.min(shownDays.length - 1, Math.round(x / Math.max(1, plot.width) * (shownDays.length - 1))))
    }

    onLibraryChanged: refresh()
    onRangeChanged: {
        cursor = -1
        Qt.callLater(card.rebuild)
    }
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: card.library
        ignoreUnknownSignals: true
        function onChanged() { card.refresh() }
    }

    Text {
        text: qsTr("Fitness and form")
        color: Theme.text2
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.labelSize
    }

    // Simple: one sentence, and the chart on request
    Column {
        width: parent.width
        visible: !card.full
        spacing: 8
        Text {
            width: parent.width
            text: {
                if (!card.hasRides)
                    return qsTr("Ride to start building fitness")
                var trend = Fitness.trend(card.all)
                if (trend === "rising")
                    return qsTr("Your fitness is rising")
                if (trend === "falling")
                    return qsTr("Your fitness is easing off")
                return qsTr("Your fitness is holding steady")
            }
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: 24
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: card.hasRides
            text: qsTr("Form today: %1. %2").arg(card.stateName(card.formState)).arg(card.stateText(card.formState))
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.bodySize
            wrapMode: Text.WordWrap
        }
    }

    Chips {
        width: parent.width
        visible: card.full && card.hasRides
        what: qsTr("Range")
        current: String(card.range)
        options: [["42", qsTr("6 weeks")], ["91", qsTr("3 months")], ["182", qsTr("6 months")]]
        onPicked: card.range = Number(key)
    }

    // the three numbers of today, or of the day under the crosshair
    Column {
        width: parent.width
        visible: card.full && card.hasRides
        spacing: 6
        Text {
            text: card.cursor >= 0 ? Format.day(card.shownDay.day) : qsTr("Today")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
        }
        Row {
            width: parent.width
            Repeater {
                model: [[qsTr("Fitness"), Math.round(card.shownDay.ctl), Theme.accent],
                        [qsTr("Fatigue"), Math.round(card.shownDay.atl), Theme.zoneColors[5]],
                        [qsTr("Form"), card.signed(card.shownDay.tsb), card.formColor(card.shownDay.tsb)]]
                Column {
                    id: number
                    width: parent.width / 3
                    spacing: 0
                    Text {
                        text: modelData[1]
                        color: modelData[2]
                        font.family: Theme.display
                        font.pixelSize: 28
                    }
                    Text {
                        text: modelData[0]
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.labelSize
                    }
                }
            }
        }
        Text {
            width: parent.width
            text: card.stateName(card.formState) + ". " + card.stateText(card.formState)
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: chartBox
        width: parent.width
        visible: card.full && card.hasRides
        height: plot.height + 8 + band.height + 22

        Accessible.role: Accessible.Graphic
        Accessible.name: qsTr("Fitness chart, last %1 days: fitness %2, fatigue %3, form %4, %5")
                         .arg(card.range).arg(Math.round(card.today.ctl)).arg(Math.round(card.today.atl))
                         .arg(card.signed(card.today.tsb)).arg(card.stateName(Fitness.formLabel(card.today.ctl, card.today.tsb)))

        Item {
            id: plot
            width: parent.width
            height: card.width < 480 ? 150 : 180

            onWidthChanged: Qt.callLater(card.rebuild)
            onHeightChanged: Qt.callLater(card.rebuild)

            Repeater {
                model: 3
                Item {
                    id: gridLine
                    y: Math.round(index * (plot.height - 1) / 2)
                    width: plot.width
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.hairline
                    }
                    Text {
                        visible: index < 2
                        y: 3
                        text: Math.round(card.scaleTop * (1 - index / 2))
                        color: Theme.text3
                        style: Text.Outline
                        styleColor: Theme.card
                        font.family: Theme.bodyMedium
                        font.pixelSize: 11
                    }
                }
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: Theme.zoneColors[5]
                        strokeWidth: 1.8
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: card.drawn.atl }
                    }
                }
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 2.4
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: card.drawn.ctl }
                    }
                }
            }
        }

        // form: one bar a day above or below zero
        Item {
            id: band
            y: plot.height + 8
            width: parent.width
            height: 56
            Rectangle {
                y: Math.round(band.height / 2)
                width: band.width
                height: 1
                color: Theme.hairline
            }
            Repeater {
                model: card.shownDays.length
                Rectangle {
                    id: formBar
                    readonly property real tsb: card.shownDays[index] ? card.shownDays[index].tsb : 0
                    readonly property real slot: band.width / Math.max(1, card.shownDays.length)
                    x: index * slot + (slot > 3 ? 0.5 : 0)
                    width: Math.max(1, slot > 3 ? slot - 1 : slot)
                    height: Math.max(1, Math.abs(tsb) / card.formTop * (band.height / 2 - 2))
                    y: tsb >= 0 ? band.height / 2 - height : band.height / 2
                    color: card.formColor(tsb)
                    opacity: card.cursor < 0 || card.cursor === index ? 0.85 : 0.45
                }
            }
            Text {
                y: 0
                anchors.right: parent.right
                text: qsTr("Form")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 11
            }
        }

        // the crosshair over both
        Item {
            anchors.fill: parent
            visible: card.cursor >= 0
            Rectangle {
                x: Math.round(card.xOf(card.cursor))
                width: 1
                height: band.y + band.height
                color: Qt.rgba(1, 1, 1, 0.6)
            }
            Rectangle {
                x: card.xOf(card.cursor) - width / 2
                y: card.yOf(card.shownDay.atl) - height / 2
                width: 9
                height: 9
                radius: 4.5
                color: Theme.zoneColors[5]
                border.width: 2
                border.color: Theme.card
            }
            Rectangle {
                x: card.xOf(card.cursor) - width / 2
                y: card.yOf(card.shownDay.ctl) - height / 2
                width: 11
                height: 11
                radius: 5.5
                color: Theme.accent
                border.width: 2
                border.color: Theme.card
            }
        }

        // four dates under the chart, the last one today
        Repeater {
            model: 4
            Text {
                id: dateLabel
                readonly property int at: Math.round(index * (card.shownDays.length - 1) / 3)
                y: band.y + band.height + 5
                x: index === 0 ? 0 : (index === 3 ? chartBox.width - implicitWidth : card.xOf(at) - implicitWidth / 2)
                text: card.shownDays.length === 0 ? "" : (index === 3 ? qsTr("Today") : Progress.shortDate(card.shownDays[at].day))
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 11
            }
        }

        ScrubArea {
            width: parent.width
            height: band.y + band.height
            onScrub: card.cursor = card.dayAt(at)
            onTap: card.cursor = card.cursor >= 0 ? -1 : card.dayAt(at)
        }
    }

    PulseButton {
        visible: !card.pro && card.hasRides
        width: revealText.implicitWidth + 32
        height: 48
        fill: pressed ? Theme.pressed : Theme.chip
        Accessible.name: card.revealed ? qsTr("Hide the fitness chart") : qsTr("Show the fitness chart")
        onClicked: card.revealed = !card.revealed
        contentItem: Text {
            id: revealText
            text: card.revealed ? qsTr("Hide the chart") : qsTr("Show the chart")
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.labelSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
