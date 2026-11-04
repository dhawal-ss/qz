import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Streak.js" as Streak

// "Taking a break?": what is going on (resting, unwell, injured, traveling or something else),
// what a pause does, and when the rider expects to be back, which is optional. Pause goals marks
// the weeks of the break as rest weeks (Streak.js), so the streak waits and no freeze is spent.
HabitPage {
    id: pauseSheet

    property real nowMs: Date.now()

    // reason, and the week key of the week of return or 0 when not sure
    signal pauseGoals(string reason, int until)

    property string reason: ""
    property int until: 0
    property bool choosingDate: false

    readonly property var options: [["rest", qsTr("Resting"), "moon"], ["sick", qsTr("Unwell"), "thermometer"],
                                    ["injured", qsTr("Injured"), "bandage"], ["travel", qsTr("Traveling"), "suitcase"],
                                    ["other", qsTr("Something else"), "more"]]
    // the first days of the weeks to come back on (Monday, or Sunday when weeks start then):
    // next week to six weeks out
    readonly property var mondays: {
        var list = []
        for (var i = 1; i <= 6; i++)
            list.push(Streak.addWeeks(nowMs, i))
        return list
    }

    function mondayWords(key) {
        if (!(key > 0))
            return qsTr("Not sure yet")
        return Streak.weekWords(key)
    }

    primaryText: qsTr("Pause goals")
    primaryEnabled: reason !== ""
    glow: false
    onPrimary: pauseSheet.pauseGoals(reason, until)
    onOpenChanged: {
        if (open) {
            reason = ""
            until = Streak.weekKey(Streak.addWeeks(nowMs, 2))
            choosingDate = false
        }
    }

    Item { width: 1; height: 20 }
    Rise {
        cue: pauseSheet
        order: 0
        width: parent.width
        Text {
            width: parent.width
            text: qsTr("Taking a break?")
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: pauseSheet.width < 400 ? 28 : 30
            font.letterSpacing: -0.6
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
    }

    Item { width: 1; height: 22 }
    Rise {
        cue: pauseSheet
        order: 1
        width: parent.width
        Column {
            width: parent.width
            Repeater {
                model: pauseSheet.options
                PulseButton {
                    id: optionRow
                    readonly property bool current: pauseSheet.reason === modelData[0]
                    x: -12
                    width: parent.width + 24
                    height: 68
                    radius: 22
                    pressedScale: 0.985
                    fill: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : (pressed ? Theme.pressed : "transparent")
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData[1]
                    Accessible.checkable: true
                    Accessible.checked: current
                    onClicked: pauseSheet.reason = modelData[0]
                    contentItem: Item {
                        Rectangle {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 44
                            radius: 22
                            color: optionRow.current ? Theme.accent : Theme.control
                            Behavior on color {
                                enabled: !Theme.reduceMotion
                                ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                            }
                            GoalGlyph {
                                anchors.centerIn: parent
                                size: 22
                                weight: 1.8
                                name: modelData[2]
                                color: optionRow.current ? Theme.accentInk : Theme.text
                            }
                        }
                        Text {
                            x: 72
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 52
                            text: modelData[1]
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(17)
                            elide: Text.ElideRight
                        }
                        // the radio: a ring, filled with a check once picked
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 12
                            color: optionRow.current ? Theme.accent : "transparent"
                            border.width: optionRow.current ? 0 : 2
                            border.color: Theme.dashed
                            scale: optionRow.current ? 1 : 0.92
                            Behavior on scale {
                                enabled: !Theme.reduceMotion
                                Spring { token: "fast"; epsilon: 0.002 }
                            }
                            GoalGlyph {
                                visible: optionRow.current
                                anchors.centerIn: parent
                                size: 14
                                weight: 3
                                name: "check"
                                color: Theme.accentInk
                            }
                        }
                    }
                    Hairline {
                        x: 12
                        width: parent.width - 24
                        anchors.bottom: parent.bottom
                        visible: !optionRow.current && index < pauseSheet.options.length - 1
                                 && pauseSheet.options[index + 1][0] !== pauseSheet.reason
                    }
                }
            }
        }
    }

    Item { width: 1; height: 20 }
    Rise {
        cue: pauseSheet
        order: 2
        width: parent.width
        // the one raised surface: what a pause does
        Rectangle {
            width: parent.width
            height: Math.max(80, pauseWords.height + 36)
            radius: 28
            color: Theme.card
            border.width: 1
            border.color: Theme.raisedBorder
            Rectangle {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: Theme.pressed
                GoalGlyph { anchors.centerIn: parent; size: 20; weight: 1.8; name: "pause"; color: Theme.accent }
            }
            Text {
                id: pauseWords
                x: 80
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 20
                text: qsTr("Goals pause, your streak waits, reminders stop until you're back.")
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(15)
                lineHeight: 1.1
                wrapMode: Text.WordWrap
            }
        }
    }

    Item { width: 1; height: 8 }
    Rise {
        cue: pauseSheet
        order: 3
        width: parent.width
        Column {
            width: parent.width
            PulseButton {
                id: dateRow
                x: -12
                width: parent.width + 24
                height: 76
                radius: 22
                pressedScale: 0.985
                fill: pressed ? Theme.pressed : "transparent"
                Accessible.name: qsTr("Back around %1, optional. Change date").arg(pauseSheet.mondayWords(pauseSheet.until))
                onClicked: pauseSheet.choosingDate = !pauseSheet.choosingDate
                contentItem: Item {
                    Rectangle {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: Theme.control
                        GoalGlyph { anchors.centerIn: parent; size: 20; weight: 1.8; name: "calendar"; color: Theme.text }
                    }
                    Column {
                        x: 72
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - optional.width - 52
                        spacing: 4
                        Text {
                            text: qsTr("Back around")
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(13)
                        }
                        Text {
                            width: parent.width
                            text: pauseSheet.mondayWords(pauseSheet.until)
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(17)
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        id: optional
                        anchors.right: chevron.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Optional")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.fs(12)
                    }
                    GoalGlyph {
                        id: chevron
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        weight: 1.8
                        name: "chevron"
                        color: Theme.text3
                        rotation: pauseSheet.choosingDate ? 90 : 0
                        Behavior on rotation {
                            enabled: !Theme.reduceMotion
                            Spring { token: "fast" }
                        }
                    }
                }
            }
            Hairline { width: parent.width }

            // the weeks to pick from, and not sure
            Flow {
                visible: pauseSheet.choosingDate
                width: parent.width
                topPadding: 12
                spacing: 8
                Repeater {
                    model: pauseSheet.mondays.map(function (m) { return Streak.weekKey(m) }).concat([0])
                    PulseButton {
                        id: dateChip
                        readonly property bool current: pauseSheet.until === modelData
                        width: chipText.implicitWidth + 28
                        height: 48
                        // 40 to see, 48 to touch
                        topInset: 4
                        bottomInset: 4
                        radius: 18
                        pressedRadius: 12
                        fill: current ? Theme.accent : (pressed ? Theme.chip : Theme.control)
                        Accessible.name: pauseSheet.mondayWords(modelData) + (current ? ", " + qsTr("selected") : "")
                        onClicked: {
                            pauseSheet.until = modelData
                            pauseSheet.choosingDate = false
                        }
                        contentItem: Text {
                            id: chipText
                            text: modelData > 0 ? Format.day(Streak.weekStartOf(Streak.keyDay(modelData))) : qsTr("Not sure yet")
                            color: dateChip.current ? Theme.accentInk : Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(13)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
