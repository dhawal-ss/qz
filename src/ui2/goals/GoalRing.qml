import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"

// The weekly goal as a ring. A goal of rides is one arc per ride, the rides done so far lit; any
// other goal is one ring that fills as the week does. The number and its words sit inside.
// A change of goal or of the week draws the lit part again on the default spring.
Item {
    id: ring

    property int segments: 0         // rides in the goal, 0 for a continuous ring
    property real done: 0            // rides done, or 0 to 1 of the goal
    property string value: ""
    property string word: ""
    property color tint: Theme.accent
    property real thickness: Math.max(8, Math.round(width * 16 / 188))
    property int numberSize: Math.round(width * 56 / 188)

    // the lit share drawn so far, springs to the target
    property real drawn: target
    readonly property real target: segments > 0 ? Math.min(segments, done) / segments : Math.max(0, Math.min(1, done))
    Behavior on drawn {
        enabled: !Theme.reduceMotion
        Spring { token: "default"; epsilon: 0.002 }
    }

    readonly property real radius: (Math.min(width, height) - thickness) / 2
    readonly property real gapDegrees: segments > 1 ? 21.5 * 3 / segments : 0
    readonly property int parts: Math.max(1, segments)

    implicitWidth: 188
    implicitHeight: 188
    Accessible.role: Accessible.Graphic
    Accessible.name: segments > 0 ? qsTr("%1 of %2 rides done this week").arg(Math.round(done)).arg(segments)
                                  : qsTr("%1 percent of the weekly goal").arg(Math.round(target * 100))

    // each arc, and the lit part of it over it
    Repeater {
        model: ring.parts
        Shape {
            id: arcShape
            readonly property real span: 360 / ring.parts - ring.gapDegrees
            readonly property real start: -90 + ring.gapDegrees / 2 + index * 360 / ring.parts
            // how much of this arc is lit: 0 to 1
            readonly property real lit: Math.max(0, Math.min(1, ring.drawn * ring.parts - index))
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeColor: Theme.chip
                strokeWidth: ring.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: arcShape.start
                    sweepAngle: arcShape.span
                }
            }
            ShapePath {
                strokeColor: arcShape.lit > 0.001 ? ring.tint : "transparent"
                strokeWidth: ring.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: arcShape.start
                    sweepAngle: Math.max(0.01, arcShape.span * arcShape.lit)
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(ring.width * 8 / 188)
        Accessible.ignored: true
        RollingNumber {
            anchors.horizontalCenter: parent.horizontalCenter
            value: ring.value
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: ring.numberSize
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: ring.word
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Math.max(11, Math.round(ring.width * 13.5 / 188))
        }
    }
}
