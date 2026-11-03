import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Streak.js" as Streak

// "What feels doable each week?": the weekly goal as rides or minutes (a rider who counts work or
// distance keeps that choice too), four sizes to pick from, the ring of the week as it would
// look, how freezes work, and Set my goal. Nothing is stored until Set my goal.
HabitPage {
    id: setup

    property string kind: "rides"        // the goal as stored, to start from
    property real goal: 3
    property var week: null              // this week, from Streak.perWeek()
    property bool miles: false

    signal chosen(string goalKind, real goalValue)

    property string pickedKind: "rides"
    property real pickedValue: 3

    readonly property var kindOptions: {
        var list = [["rides", qsTr("Rides")], ["minutes", qsTr("Minutes")]]
        if (kind === "kj")
            list.push(["kj", qsTr("Work")])
        if (kind === "km")
            list.push(["km", qsTr("Distance")])
        return list
    }
    readonly property var sizes: {
        if (pickedKind === "rides")
            return [2, 3, 4, 5]
        if (pickedKind === "kj")
            return [500, 1000, 1500, 2000]
        if (pickedKind === "km")
            return miles ? [15, 30, 50, 75] : [25, 50, 75, 100]
        return [60, 90, 120, 180]
    }
    // the picked size as shown (miles for a rider who sees miles)
    readonly property real shownValue: pickedKind === "km" && miles ? Math.round(pickedValue / 1.609344) : Math.round(pickedValue)
    readonly property string unitWords: {
        if (pickedKind === "rides")
            return Math.round(pickedValue) === 1 ? qsTr("ride a week") : qsTr("rides a week")
        if (pickedKind === "kj")
            return qsTr("kJ a week")
        if (pickedKind === "km")
            return miles ? qsTr("miles a week") : qsTr("km a week")
        return qsTr("minutes a week")
    }

    primaryText: qsTr("Set my goal")
    glowY: 330
    glowSize: 260
    onPrimary: setup.chosen(pickedKind, pickedValue)
    onOpenChanged: if (open) start()

    // from the stored goal; a size not on the list snaps to the nearest one
    function start() {
        pickedKind = kindOptions.map(function (o) { return o[0] }).indexOf(kind) >= 0 ? kind : "rides"
        pickValue(pickedKind === kind ? goal : (pickedKind === "rides" ? 3 : 120))
    }

    function pickKind(k) {
        if (k === pickedKind)
            return
        pickedKind = k
        pickValue(k === kind ? goal : (k === "rides" ? 3 : (k === "minutes" ? 120 : sizes[1])))
    }

    function pickValue(v) {
        var list = sizes
        var shown = pickedKind === "km" && miles ? v / 1.609344 : v
        var best = list[0]
        for (var i = 1; i < list.length; i++)
            if (Math.abs(list[i] - shown) < Math.abs(best - shown))
                best = list[i]
        pickedValue = pickedKind === "km" && miles ? best * 1.609344 : best
    }

    Item { width: 1; height: 20 }
    Rise {
        cue: setup
        order: 0
        width: parent.width
        Text {
            width: parent.width
            text: qsTr("What feels doable each week?")
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: setup.width < 400 ? 28 : 30
            font.letterSpacing: -0.6
            lineHeightMode: Text.FixedHeight
            lineHeight: Math.round(font.pixelSize * 1.08)
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
    }

    Item { width: 1; height: 20 }
    Rise {
        cue: setup
        order: 1
        width: parent.width
        Column {
            width: parent.width
            spacing: 14

            // what the goal counts: a pill holding the choices, the picked one lit with a check
            Rectangle {
                width: kindRow.width + 8
                height: 44
                radius: 22
                color: Theme.control
                Row {
                    id: kindRow
                    x: 4
                    y: 4
                    spacing: 2
                    Repeater {
                        model: setup.kindOptions
                        PulseButton {
                            id: kindButton
                            readonly property bool current: modelData[0] === setup.pickedKind
                            width: kindLabel.implicitWidth + (current ? 46 : 32)
                            height: 36
                            fill: current ? Theme.accent : (pressed ? Theme.pressed : "transparent")
                            pressedScale: 0.96
                            Accessible.name: modelData[1] + (current ? ", " + qsTr("selected") : "")
                            onClicked: setup.pickKind(modelData[0])
                            Behavior on width {
                                enabled: !Theme.reduceMotion
                                Spring { token: "fast" }
                            }
                            contentItem: Item {
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    GoalGlyph {
                                        visible: kindButton.current
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 16
                                        weight: 2.4
                                        name: "check"
                                        color: Theme.accentInk
                                    }
                                    Text {
                                        id: kindLabel
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData[1]
                                        color: kindButton.current ? Theme.accentInk : Theme.text2
                                        font.family: Theme.bodySemibold
                                        font.pixelSize: 14
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // the four sizes: a connected group, the picked one fully round
            Row {
                width: parent.width
                spacing: 4
                Repeater {
                    model: setup.sizes
                    PulseButton {
                        id: sizeButton
                        readonly property bool current: Math.round(modelData) === Math.round(setup.shownValue)
                        readonly property real outer: height / 2
                        width: (parent.width - 12) / 4
                        height: 76
                        pressedScale: 0.96
                        Accessible.name: qsTr("%1 %2").arg(modelData).arg(setup.unitWords) + (current ? ", " + qsTr("selected") : "")
                        onClicked: setup.pickValue(setup.pickedKind === "km" && setup.miles ? modelData * 1.609344 : modelData)
                        background: Item {
                            Rectangle {
                                id: leftHalf
                                width: parent.width / 2 + radius
                                height: parent.height
                                radius: sizeButton.current || index === 0 ? sizeButton.outer : 12
                                color: sizeButton.current ? Theme.accent : (sizeButton.pressed ? Theme.pressed : Theme.control)
                                Behavior on radius {
                                    enabled: !Theme.reduceMotion
                                    Spring { token: "fast" }
                                }
                                Behavior on color {
                                    enabled: !Theme.reduceMotion
                                    ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                                }
                            }
                            Rectangle {
                                x: parent.width / 2 - radius
                                width: parent.width / 2 + radius
                                height: parent.height
                                radius: sizeButton.current || index === 3 ? sizeButton.outer : 12
                                color: leftHalf.color
                                Behavior on radius {
                                    enabled: !Theme.reduceMotion
                                    Spring { token: "fast" }
                                }
                            }
                            Rectangle {
                                visible: sizeButton.visualFocus
                                anchors.fill: parent
                                radius: sizeButton.outer
                                color: "transparent"
                                border.width: 3
                                border.color: Theme.accent
                            }
                        }
                        contentItem: Item {
                            Numeral {
                                anchors.centerIn: parent
                                text: Format.big(modelData)
                                color: sizeButton.current ? Theme.accentInk : Theme.text
                                font.family: sizeButton.current ? Theme.heroFamily(6) : Theme.display
                                font.pixelSize: Math.min(34, Math.floor(sizeButton.width * 1.05 / Math.max(2, text.length)))
                            }
                        }
                    }
                }
            }
        }
    }

    Item { width: 1; height: 24 }
    Rise {
        cue: setup
        order: 2
        width: parent.width
        Item {
            width: parent.width
            height: ring.height
            GoalRing {
                id: ring
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(176, Math.max(132, setup.height * 0.19))
                height: width
                segments: setup.pickedKind === "rides" ? Math.round(setup.pickedValue) : 0
                done: setup.pickedKind === "rides" ? Math.min(Math.round(setup.pickedValue), Streak.measure(setup.week, "rides"))
                                                   : Streak.measure(setup.week, setup.pickedKind) / Math.max(1, setup.pickedValue)
                value: String(setup.shownValue)
                word: setup.unitWords
            }
        }
    }

    Item { width: 1; height: 22 }
    Rise {
        cue: setup
        order: 3
        width: parent.width
        Column {
            width: parent.width
            spacing: 16
            // the one raised surface: how freezes keep a streak alive
            Rectangle {
                width: parent.width
                height: freezeWords.height + 36
                radius: 28
                color: Theme.card
                border.width: 1
                border.color: Theme.raisedBorder
                Rectangle {
                    x: 20
                    y: 18
                    width: 44
                    height: 44
                    radius: 22
                    color: Theme.pressed
                    GoalGlyph { anchors.centerIn: parent; size: 22; weight: 1.8; name: "freeze"; color: Theme.accent }
                }
                Column {
                    id: freezeWords
                    x: 80
                    y: 18
                    width: parent.width - x - 20
                    spacing: 6
                    Text {
                        text: qsTr("Freezes")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 17
                    }
                    Text {
                        width: parent.width
                        text: qsTr("Earn a freeze every %1 goal weeks. Hold up to %2. Missed weeks use them automatically.")
                              .arg(Streak.freezeEvery).arg(Streak.freezeMax)
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 14
                        lineHeight: 1.1
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Text {
                x: 4
                width: parent.width - 8
                text: qsTr("You can change this any time. Smaller goals stick better.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 14
                lineHeight: 1.1
                wrapMode: Text.WordWrap
            }
        }
    }
}
