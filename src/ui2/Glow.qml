import QtQuick 2.15
import QtQuick.Shapes 1.15
import "."

// One soft radial glow in a single color. It breathes once per beat.
Shape {
    id: glow

    property color tint: Theme.accent
    property int beat: 4000
    property bool breathing: true

    opacity: 0.25
    Accessible.ignored: true

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: glow.width / 2; centerY: glow.height / 2; centerRadius: glow.width / 2
            focalX: glow.width / 2; focalY: glow.height / 2
            GradientStop { position: 0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.9) }
            GradientStop { position: 0.45; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.35) }
            GradientStop { position: 1; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0) }
        }
        PathAngleArc {
            centerX: glow.width / 2; centerY: glow.height / 2
            radiusX: glow.width / 2; radiusY: glow.height / 2
            startAngle: 0; sweepAngle: 360
        }
    }

    SequentialAnimation on scale {
        running: !Theme.reduceMotion && glow.breathing
        loops: Animation.Infinite
        NumberAnimation { to: 1.06; duration: glow.beat / 2; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: glow.beat / 2; easing.type: Easing.InOutSine }
    }
}
