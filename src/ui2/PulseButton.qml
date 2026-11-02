import QtQuick 2.15
import QtQuick.Controls 2.15
import "."

// A plain pressable surface. Its shape softens while pressed, like the M3 Expressive buttons.
AbstractButton {
    id: control

    property color fill: "transparent"
    property real radius: height / 2
    property real pressedRadius: radius
    property real pressedScale: 0.97

    Accessible.role: Accessible.Button
    Accessible.onPressAction: control.clicked()
    focusPolicy: Qt.StrongFocus
    padding: 0
    scale: pressed ? pressedScale : 1

    Behavior on scale {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
    }

    background: Rectangle {
        color: control.fill
        radius: control.pressed ? control.pressedRadius : control.radius
        border.width: control.visualFocus ? 3 : 0
        border.color: Theme.accent
        Behavior on radius {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
        }
        Behavior on color {
            enabled: !Theme.reduceMotion
            ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        }
    }
}
