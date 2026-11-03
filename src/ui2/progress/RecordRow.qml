import QtQuick 2.15
import ".."
import "Progress.js" as Progress

// One record of the board: what it is, its value, the day it was set (a tap opens that ride) and
// how long it has stood. A tap on the row opens the history of the record under it.
Item {
    id: row

    property string label: ""
    property string valueText: ""
    property string dateText: ""
    property real start: 0
    property int rideId: 0
    property bool open: false
    property var steps: []           // the history, for StepChart, when open
    property string note: ""         // under the history: how often it was beaten

    signal toggle()
    signal openRide(int id)

    readonly property int days: Progress.daysBetween(start, Date.now())
    readonly property string stoodText: days <= 0 ? qsTr("Set today") : qsTr("Stood %1").arg(Progress.stood(start, Date.now()))

    width: parent ? parent.width : 0
    height: 68 + (open ? detail.height : 0)
    clip: true

    Behavior on height {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
    }

    PulseButton {
        id: head
        width: parent.width
        height: 68
        radius: 16
        pressedScale: 0.99
        fill: pressed ? Theme.pressed : "transparent"
        Accessible.name: qsTr("%1 record, %2, %3. %4").arg(row.label).arg(row.valueText).arg(row.stoodText)
                         .arg(row.open ? qsTr("Hide its history") : qsTr("Show its history"))
        onClicked: row.toggle()
        contentItem: Item {
            Row {
                y: 10
                spacing: 8
                Text {
                    width: Math.min(implicitWidth, head.width - valueLabel.implicitWidth - 16 - (newPill.visible ? newPill.width + 8 : 0))
                    elide: Text.ElideRight
                    text: row.label
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.bodySize
                }
                // a record from the last two weeks
                Rectangle {
                    id: newPill
                    visible: row.days < 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: newText.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Theme.accent
                    Text {
                        id: newText
                        anchors.centerIn: parent
                        text: qsTr("New")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: 11
                    }
                }
            }
            Text {
                id: valueLabel
                anchors.right: parent.right
                anchors.rightMargin: 4
                y: 6
                text: row.valueText
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: 22
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                y: 40
                text: row.stoodText
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }
    }

    // the day it was set: opens that ride
    PulseButton {
        id: dateButton
        y: 20
        width: Math.max(48, dateLabel.implicitWidth + 16)
        radius: 12
        height: 48
        enabled: row.rideId > 0
        fill: pressed ? Theme.chip : "transparent"
        Accessible.name: qsTr("Open the ride of %1").arg(row.dateText)
        onClicked: row.openRide(row.rideId)
        contentItem: Text {
            id: dateLabel
            text: row.dateText
            color: row.rideId > 0 ? Theme.accent : Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
    }

    Column {
        id: detail
        y: 68
        width: parent.width
        spacing: 6
        StepChart {
            width: parent.width
            height: 120
            steps: row.open ? row.steps : []
        }
        Text {
            width: parent.width
            text: row.note
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
            wrapMode: Text.WordWrap
        }
        Item {
            width: 1
            height: 8
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.hairline
    }
}
