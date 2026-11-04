import QtQuick 2.15
import ".."
import "../sig"
import "../learn"
import "Patterns.js" as Patterns
import "../Format.js" as Format

// When you ride best (Patterns.whenBest): a column a weekday of every ride of the last half year,
// its brighter part the strongest third of them, the best day lit in the tint; under it the four
// parts of the day, the best one lit. The whole section is the button to its Learn sheet.
LearnTap {
    id: whenCard

    property var when: Patterns.whenSample()
    property bool sample: false
    property color tint: Theme.accent
    // 0 to 1: how far the columns have grown
    property real grown: 1

    // from the first day of the week, as Patterns.whenBest() counts them
    readonly property var letters: Format.weekLetters(Theme.weekStart)
    readonly property var slotLabels: [qsTr("Morning"), qsTr("Midday"), qsTr("Afternoon"), qsTr("Evening")]
    readonly property real columnTop: {
        var hi = 1
        for (var i = 0; i < when.days.length; i++)
            hi = Math.max(hi, when.days[i].all)
        return hi
    }
    readonly property real slotTop: {
        var hi = 1
        for (var i = 0; i < when.slots.length; i++)
            hi = Math.max(hi, when.slots[i].strong)
        return hi
    }

    function grow() {
        if (Theme.reduceMotion) {
            growth.stop()
            grown = 1
            return
        }
        growth.restart()
    }

    onWhenChanged: grow()
    name: sample ? qsTr("When you ride best, a sample of what shows after your first ride")
                 : qsTr("When you ride best: %1").arg(Patterns.whenWords(when))

    SequentialAnimation {
        id: growth
        PropertyAction { target: whenCard; property: "grown"; value: 0 }
        PauseAnimation { duration: 120 }
        NumberAnimation {
            target: whenCard
            property: "grown"
            to: 1
            duration: Theme.defaultSpatialTime + 200
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.defaultSpatialCurve
        }
    }

    Column {
        width: parent.width
        spacing: 12
        VisualHead {
            width: parent.width
            title: qsTr("When you ride best")
            sample: whenCard.sample
        }
        Text {
            width: parent.width
            text: Patterns.whenWords(whenCard.when)
            color: whenCard.sample ? Theme.text2 : Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(17)
            wrapMode: Text.WordWrap
        }
        // the weekdays
        Item {
            width: parent.width
            height: 96
            Accessible.ignored: true
            Repeater {
                model: 7
                Item {
                    id: dayColumn
                    readonly property var info: whenCard.when.days[index] || ({ all: 0, strong: 0 })
                    readonly property bool best: index === whenCard.when.bestDay
                    readonly property real plotHeight: 70
                    readonly property real barWidth: Math.min(28, width * 0.56)
                    x: index * parent.width / 7
                    width: parent.width / 7
                    height: parent.height
                    // every ride of the weekday
                    Rectangle {
                        visible: dayColumn.info.all > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dayColumn.barWidth
                        height: Math.max(width / 2, dayColumn.plotHeight * dayColumn.info.all / whenCard.columnTop * whenCard.grown)
                        y: dayColumn.plotHeight - height
                        radius: Math.min(8, width / 2)
                        color: Theme.overlay(0.07)
                    }
                    // the strongest of them
                    Rectangle {
                        visible: dayColumn.info.strong > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dayColumn.barWidth
                        height: Math.max(width / 2, dayColumn.plotHeight * dayColumn.info.strong / whenCard.columnTop * whenCard.grown)
                        y: dayColumn.plotHeight - height
                        radius: Math.min(8, width / 2)
                        color: whenCard.sample ? (dayColumn.best ? Theme.overlay(0.3) : Theme.overlay(0.16))
                                               : (dayColumn.best ? whenCard.tint : Theme.overlay(0.28))
                    }
                    // no ride on this weekday
                    Rectangle {
                        visible: dayColumn.info.all === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: dayColumn.plotHeight - height
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.rest
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: dayColumn.plotHeight + 9
                        text: whenCard.letters[index]
                        color: dayColumn.best && !whenCard.sample ? whenCard.tint : Theme.text2
                        font.family: dayColumn.best ? Theme.bodySemibold : Theme.bodyMedium
                        font.pixelSize: Theme.fs(13)
                    }
                }
            }
        }
        // the parts of the day
        Row {
            width: parent.width
            spacing: 8
            Accessible.ignored: true
            Repeater {
                model: 4
                Column {
                    id: slotCell
                    readonly property var info: whenCard.when.slots[index] || ({ all: 0, strong: 0 })
                    readonly property bool best: index === whenCard.when.bestSlot
                    width: (parent.width - 24) / 4
                    spacing: 6
                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 4
                        color: whenCard.sample ? (slotCell.best ? Theme.overlay(0.3) : Theme.overlay(0.1))
                               : (slotCell.best ? whenCard.tint : Theme.overlay(0.07 + 0.22 * slotCell.info.strong / whenCard.slotTop))
                    }
                    Text {
                        width: parent.width
                        text: whenCard.slotLabels[index]
                        color: slotCell.best && !whenCard.sample ? whenCard.tint : Theme.text3
                        font.family: slotCell.best ? Theme.bodySemibold : Theme.bodyMedium
                        font.pixelSize: Theme.fs(12)
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
