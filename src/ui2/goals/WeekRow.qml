import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"

// The streak as a row of weeks, oldest first (Streak.lastWeeks): a goal week is the Pulse in the
// tint (or a full disc with `discs`), a week a freeze covered is a dark disc ringed in the tint
// with the freeze, a rest week a dark disc with the moon, a missed week or one before the first
// ride a small dot, and the week in progress a dashed ring that fills as the week does.
Item {
    id: weekRow

    property var weeks: []           // [{ status, value }]
    property real progress: 0        // the week in progress, 0 to 1
    property color tint: Theme.accent
    property bool discs: false
    property bool labels: true
    property real cell: Math.min(26, Math.floor((width - (weeks.length - 1) * 6) / Math.max(1, weeks.length)))

    readonly property real gap: weeks.length > 1 ? (width - weeks.length * cell) / (weeks.length - 1) : 0

    implicitHeight: cell + (labels ? 24 : 0)

    Repeater {
        model: weekRow.weeks
        Item {
            id: weekCell
            readonly property string status: modelData.status
            x: index * (weekRow.cell + weekRow.gap)
            width: weekRow.cell
            height: weekRow.cell

            Pulse {
                visible: weekCell.status === "met" && !weekRow.discs
                anchors.fill: parent
                zone: 2
                color: weekRow.tint
            }
            Rectangle {
                visible: weekCell.status === "met" && weekRow.discs
                anchors.fill: parent
                radius: width / 2
                color: weekRow.tint
            }
            // a freeze or a rest week
            Rectangle {
                visible: weekCell.status === "frozen" || weekCell.status === "rest"
                anchors.fill: parent
                anchors.margins: weekRow.discs ? 0 : 1
                radius: width / 2
                color: Theme.pressed
                border.width: weekCell.status === "frozen" ? 1.5 : 0
                border.color: weekRow.tint
                GoalGlyph {
                    anchors.centerIn: parent
                    size: Math.round(weekRow.cell * 0.6)
                    weight: 2.4
                    name: weekCell.status === "frozen" ? "freeze" : "moon"
                    color: weekCell.status === "frozen" ? weekRow.tint : Theme.text2
                }
            }
            // missed, or before the first ride
            Rectangle {
                visible: weekCell.status === "missed" || weekCell.status === "none"
                anchors.centerIn: parent
                width: Math.round(weekRow.cell * 0.26)
                height: width
                radius: width / 2
                color: weekCell.status === "missed" ? Theme.dashed : Theme.rest
            }
            // the week in progress
            Shape {
                visible: weekCell.status === "current"
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: weekRow.tint
                    strokeWidth: 2
                    fillColor: "transparent"
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [2, 1.75]
                    PathAngleArc {
                        centerX: weekRow.cell / 2
                        centerY: weekRow.cell / 2
                        radiusX: weekRow.cell / 2 - 1.5
                        radiusY: weekRow.cell / 2 - 1.5
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }
            Rectangle {
                visible: weekCell.status === "current" && weekRow.progress > 0
                anchors.centerIn: parent
                width: Math.max(4, (weekRow.cell - 9) * Math.min(1, weekRow.progress))
                height: width
                radius: width / 2
                color: weekRow.tint
                Behavior on width {
                    enabled: !Theme.reduceMotion
                    Spring { token: "default" }
                }
            }
        }
    }

    Text {
        visible: weekRow.labels
        y: weekRow.cell + 8
        text: weekRow.weeks.length === 1 ? qsTr("This week") : qsTr("%1 weeks ago").arg(weekRow.weeks.length - 1)
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 11
    }
    Text {
        visible: weekRow.labels && weekRow.weeks.length > 1
        anchors.right: parent.right
        y: weekRow.cell + 8
        text: qsTr("This week")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 11
    }
}
