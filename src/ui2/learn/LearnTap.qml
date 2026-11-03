import QtQuick 2.15
import ".."

// A chart, a ring or a big number that is its own button: a tap opens its Learn sheet. While
// pressed it softens and sinks a little, and a quiet surface shows under it. It takes the height
// of what is inside; the children take its width.
//   LearnTap { width: parent.width; name: qsTr("Effort mix"); onClicked: page.openLearn("mix", {})
//              MixRing { width: parent.width } }
// Buttons inside it keep their own taps.
PulseButton {
    id: tap

    default property alias content: holder.data
    // what the visual is, for the screen reader: "<name>, tap to learn more"
    property string name: ""

    implicitHeight: holder.childrenRect.height
    fill: pressed ? Theme.pressed : "transparent"
    radius: 22
    pressedRadius: 18
    pressedScale: 0.985
    topInset: -8
    bottomInset: -8
    leftInset: -10
    rightInset: -10
    Accessible.name: qsTr("%1, tap to learn more").arg(name)

    contentItem: Item {
        id: holder
    }
}
