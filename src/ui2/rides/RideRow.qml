import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"

// One ride in the journal of rides: its own small Pulse in the zone it counts in, the title with
// a mark for each record it set, the day, a tiny line of its power and how long it was. A
// hairline under it. Picked (on a tablet, the ride beside the list) it lifts onto a soft surface.
PulseButton {
    id: rideRow

    property string title: ""
    property string day: ""
    property string length: ""
    property int zone: 2
    property var spark: []
    property int records: 0
    property bool picked: false
    property bool line: true

    readonly property color tint: Theme.zoneColors[Math.max(1, Math.min(7, zone)) - 1]

    implicitHeight: 76
    radius: 20
    pressedScale: 0.985
    fill: picked ? Theme.control : (pressed ? Theme.pressed : "transparent")
    Accessible.name: title + ", " + day + ", " + length
                     + (records > 0 ? ", " + (records === 1 ? qsTr("1 record") : qsTr("%1 records").arg(records)) : "")

    contentItem: Item {
        Pulse {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            zone: rideRow.zone
            color: rideRow.tint
        }
        Column {
            x: 54
            anchors.verticalCenter: parent.verticalCenter
            width: miniLine.x - x - 12
            spacing: 5
            Row {
                width: parent.width
                spacing: 7
                Text {
                    id: rowTitle
                    width: Math.min(implicitWidth, parent.width - (marks.visible ? marks.width + 7 : 0))
                    text: rideRow.title
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 16
                    elide: Text.ElideRight
                }
                // a record: the Pulse at its spikiest, as the badge a record settles into
                Row {
                    id: marks
                    visible: rideRow.records > 0
                    anchors.verticalCenter: rowTitle.verticalCenter
                    spacing: 3
                    Pulse {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        height: 13
                        zone: 7
                        color: rideRow.tint
                    }
                    Text {
                        visible: rideRow.records > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: rideRow.records
                        color: rideRow.tint
                        font.family: Theme.bodySemibold
                        font.pixelSize: 12
                    }
                }
            }
            Text {
                width: parent.width
                text: rideRow.day
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        // the power of the ride, tiny, in its tint
        Shape {
            id: miniLine
            x: lengthText.x - 14 - width
            anchors.verticalCenter: parent.verticalCenter
            width: rideRow.width < 380 ? 40 : 56
            height: 22
            visible: rideRow.spark.length > 1
            layer.enabled: true
            layer.samples: 4

            function points() {
                var list = []
                var values = rideRow.spark
                var n = values.length
                if (n < 2)
                    return list
                var lo = values[0]
                var hi = values[0]
                for (var i = 1; i < n; i++) {
                    lo = Math.min(lo, values[i])
                    hi = Math.max(hi, values[i])
                }
                var span = Math.max(1, hi - lo)
                for (var j = 0; j < n; j++)
                    list.push(Qt.point(j * width / (n - 1), 2 + (height - 4) * (1 - (values[j] - lo) / span)))
                return list
            }

            ShapePath {
                strokeColor: Qt.rgba(rideRow.tint.r, rideRow.tint.g, rideRow.tint.b, 0.85)
                strokeWidth: 1.6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: miniLine.points() }
            }
        }

        Text {
            id: lengthText
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 62
            horizontalAlignment: Text.AlignRight
            text: rideRow.length
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: 17
        }
    }

    Hairline {
        visible: rideRow.line && !rideRow.picked
        x: 54
        anchors.bottom: parent.bottom
        width: parent.width - 54 - 10
    }
}
