import QtQuick 2.15
import ".."

// A text button: filled with the accent for the main action, quiet for the others.
PulseButton {
    id: button

    property bool primary: false
    property bool danger: false

    implicitWidth: Math.max(48, label.implicitWidth + 40)
    implicitHeight: Math.max(48, label.implicitHeight + 24)
    fill: primary ? Theme.accent : Theme.chip
    pressedRadius: Math.min(height / 2, 16)
    opacity: enabled ? 1 : 0.4
    Accessible.name: text

    contentItem: Text {
        id: label
        text: button.text
        color: button.primary ? Theme.accentInk : (button.danger ? Theme.danger : Theme.text)
        font.family: Theme.bodySemibold
        font.pixelSize: 15
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        leftPadding: 20
        rightPadding: 20
    }
}
