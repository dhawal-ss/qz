import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format

// One ride in short, as a quiet section: its name and day, time, power and distance on a
// hairline, and its power as a line. Today shows the latest ride and the ride of this day last
// year with it. A tap opens the ride.
Column {
    id: rideCard

    property string label: ""
    property var ride: null
    property bool miles: false
    property color lineColor: Theme.accent

    signal openRide(int id)

    // 1:05 (hours) from an hour on, 45 (minutes) under it
    function clock(seconds) {
        var m = Math.round((seconds || 0) / 60)
        if (m < 60)
            return String(m)
        var rest = m % 60
        return Math.floor(m / 60) + ":" + (rest < 10 ? "0" : "") + rest
    }

    spacing: 4

    CapLabel {
        text: rideCard.label
    }
    PulseButton {
        width: rideCard.width
        height: rideColumn.implicitHeight + 16
        fill: pressed ? Theme.pressed : "transparent"
        radius: 18
        pressedScale: 0.985
        Accessible.name: rideCard.ride ? qsTr("%1, open %2").arg(rideCard.label).arg(Format.title(rideCard.ride)) : ""
        onClicked: if (rideCard.ride) rideCard.openRide(rideCard.ride.id)
        contentItem: Column {
            id: rideColumn
            topPadding: 8
            spacing: 6
            Item {
                width: parent.width
                height: rideTitle.height
                Text {
                    id: rideTitle
                    width: parent.width - 28
                    text: rideCard.ride ? qsTr("%1, %2").arg(Format.title(rideCard.ride)).arg(Format.day(rideCard.ride.start)) : ""
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(17)
                    elide: Text.ElideRight
                }
                Icon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "forward"
                    size: 18
                    color: Theme.text3
                }
            }
            KeyNumbers {
                width: parent.width
                valueSize: 24
                items: rideCard.ride ? [
                    { value: rideCard.clock(rideCard.ride.duration), unit: rideCard.ride.duration >= 3600 ? "h" : "min", label: qsTr("Time") },
                    { value: Format.whole(rideCard.ride.avgPower), unit: "W", label: qsTr("Average") },
                    { value: Format.distance(rideCard.ride.distance, rideCard.miles).split(" ")[0],
                      unit: rideCard.miles ? "mi" : "km", label: qsTr("Distance") }
                ] : []
            }
            Sparkline {
                width: parent.width
                height: 36
                visible: rideCard.ride !== null && (rideCard.ride.spark || []).length > 1
                values: rideCard.ride ? (rideCard.ride.spark || []) : []
                color: rideCard.lineColor
            }
        }
    }
}
