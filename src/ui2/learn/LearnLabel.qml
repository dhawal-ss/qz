import QtQuick 2.15
import ".."
import "../sig"

// The cap label of a section as a button to its Learn sheet, for a section whose body taps do
// something else (the days of a calendar, the badges, the rides of the records). It looks like
// the cap label and softens while pressed.
PulseButton {
    id: learnLabel

    property string caption: ""

    implicitWidth: capText.implicitWidth + 20
    implicitHeight: 32
    fill: pressed ? Theme.pressed : "transparent"
    radius: 12
    pressedScale: 0.97
    Accessible.name: qsTr("%1, tap to learn more").arg(caption)

    contentItem: Item {
        CapLabel {
            id: capText
            x: 8
            width: Math.min(implicitWidth, learnLabel.width - 16)
            anchors.verticalCenter: parent.verticalCenter
            text: learnLabel.caption
            Accessible.ignored: true
        }
    }
}
