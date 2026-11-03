import QtQuick 2.15
import QtQuick.Shapes 1.15
import QtQuick.Window 2.15
import ".."

// The Pulse drawn sharp at any size: the 12-lobe shape of Theme.pulsePath, rendered into a
// multisampled layer as big as it shows (PulseShape draws it at 108 and scales the picture).
// It morphs between zones on the slow spatial curve, and turns once a minute only when asked.
Item {
    id: pulse

    property real zone: 1
    property color color: Theme.zoneColors[0]
    property bool turning: false
    property int turnTime: 60000
    property real shownZone: zone

    implicitWidth: 28
    implicitHeight: 28
    Accessible.ignored: true

    Behavior on shownZone {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.slowSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.slowSpatialCurve }
    }

    Shape {
        id: shape
        width: 108
        height: 108
        anchors.centerIn: parent
        scale: Math.min(pulse.width, pulse.height) / 108
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true
        // the picture as big as it shows on the screen, so it stays sharp
        readonly property int pixels: Math.ceil(108 * scale * Math.max(1, Screen.devicePixelRatio))
        layer.textureSize: Qt.size(pixels, pixels)

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: pulse.turnTime
            loops: Animation.Infinite
            running: pulse.turning && !Theme.reduceMotion && pulse.visible
        }

        ShapePath {
            strokeWidth: -1
            fillColor: pulse.color
            PathSvg { path: Theme.pulsePath(pulse.shownZone) }
        }
    }
}
