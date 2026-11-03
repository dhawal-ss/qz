import QtQuick 2.15
import ".."
import "../sig"

// The head of a Progress section: the cap label on the left and a quiet note on the right
// ("Last 90 days", "vs last period").
Item {
    id: head

    property string title: ""
    property string note: ""

    implicitHeight: 24

    CapLabel {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, head.width - noteText.implicitWidth - 12)
        text: head.title
    }
    Text {
        id: noteText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: head.note
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 13
    }
}
