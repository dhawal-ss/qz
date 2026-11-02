import QtQuick 2.15
import QtQuick.Shapes 1.15
import "."

// The Pulse: a slowly turning 12-lobe shape that grows spikier with every zone and morphs
// between zones.
Item {
    id: pulse

    property int zone: 1
    property color color: Theme.zoneColors[0]
    property real shownZone: zone

    implicitWidth: 26
    implicitHeight: 26
    Accessible.ignored: true

    Behavior on shownZone {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.slow; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
    }

    Shape {
        id: shape
        width: 108
        height: 108
        anchors.centerIn: parent
        scale: Math.min(pulse.width, pulse.height) / 108
        layer.enabled: true
        layer.samples: 4

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 30000
            loops: Animation.Infinite
            running: !Theme.reduceMotion && pulse.visible
        }

        ShapePath {
            strokeWidth: -1
            fillColor: pulse.color
            PathSvg { path: Theme.pulsePath(pulse.shownZone) }
        }
    }
}
