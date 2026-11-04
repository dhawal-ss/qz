import QtQuick 2.15
import ".."
import "../sig"
import "../learn"
import "../Format.js" as Format
import "../moments/Moments.js" as Moments

// A record the latest ride came close to, and the effort that would take it, as a quiet
// section. A tap on the words opens the ride that came close; Ride starts one.
Column {
    id: reachCard

    property var reach: null         // Insights.reach()

    signal rideRequested()
    signal openRide(int id)
    signal learn()

    readonly property color tint: reach ? Theme.zoneColors[Moments.recordTone(reach.seconds) - 1] : Theme.accent
    readonly property string effortName: reach ? Format.effort(reach.seconds) : ""

    spacing: 4

    LearnLabel {
        x: -8
        caption: qsTr("Record within reach")
        onClicked: reachCard.learn()
    }
    PulseButton {
        width: reachCard.width
        height: reachColumn.implicitHeight + 16
        fill: pressed ? Theme.pressed : "transparent"
        radius: 18
        pressedScale: 0.985
        Accessible.name: reachCard.reach ? qsTr("A new %1 record is %2 watts away. Open the ride that came close")
                                           .arg(reachCard.effortName).arg(reachCard.reach.gap) : ""
        onClicked: if (reachCard.reach) reachCard.openRide(reachCard.reach.rideId)
        contentItem: Column {
            id: reachColumn
            topPadding: 8
            spacing: 6
            Text {
                width: parent.width
                text: reachCard.reach ? qsTr("A new %1 record is %2 W away").arg(reachCard.effortName).arg(reachCard.reach.gap) : ""
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(17)
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: reachCard.reach ? qsTr("Your last ride held %1 W for %2. Your best is %3 W.")
                                          .arg(reachCard.reach.watts).arg(reachCard.effortName).arg(reachCard.reach.best) : ""
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                wrapMode: Text.WordWrap
            }
        }
    }
    // the effort to try, and the way into a ride
    Item {
        width: reachCard.width
        height: 64
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            CapLabel {
                text: qsTr("Try %1 at").arg(reachCard.effortName)
                Accessible.ignored: true
            }
            Row {
                spacing: 4
                Numeral {
                    id: targetNumber
                    text: reachCard.reach ? String(reachCard.reach.target) : ""
                    color: reachCard.tint
                    font.pixelSize: 30
                }
                Text {
                    anchors.baseline: targetNumber.baseline
                    text: "W"
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(14)
                }
            }
        }
        PulseButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: rideText.implicitWidth + 40
            height: 48
            fill: pressed ? Theme.pressed : Theme.chip
            pressedRadius: 16
            Accessible.name: qsTr("Ride, try %1 at %2 watts").arg(reachCard.effortName).arg(reachCard.reach ? reachCard.reach.target : 0)
            onClicked: reachCard.rideRequested()
            contentItem: Text {
                id: rideText
                text: qsTr("Try it")
                color: Theme.accent
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(15)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
