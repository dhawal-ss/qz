import QtQuick 2.15
import ".."
import "../sig"

// This week: each day as the Pulse of the zone it was ridden in, a dot for a day off and a dashed
// ring for today still to ride, with the week against the weekly goal on the right
// ("3 of 4 rides", as set on Goals). A tap opens Goals.
PulseButton {
    id: weekCard

    property var days: []            // Coach.weekDays()
    property string summary: ""      // Coach.goalText()
    property bool met: false

    signal openGoals()

    implicitHeight: weekColumn.implicitHeight + 8
    fill: pressed ? Theme.pressed : "transparent"
    radius: 20
    pressedScale: 0.985
    Accessible.name: qsTr("This week, %1. Open your goals").arg(summary)
    onClicked: weekCard.openGoals()

    contentItem: Column {
        id: weekColumn
        spacing: 12
        Item {
            width: parent.width
            height: weekTitle.height
            Text {
                id: weekTitle
                text: qsTr("This week")
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: 14
            }
            Text {
                anchors.right: parent.right
                text: weekCard.summary
                color: weekCard.met ? Theme.zoneColors[2] : Theme.text2
                font.family: weekCard.met ? Theme.bodySemibold : Theme.bodyMedium
                font.pixelSize: 13
            }
        }
        WeekPulses {
            width: parent.width
            days: weekCard.days
            Accessible.ignored: true
        }
    }
}
