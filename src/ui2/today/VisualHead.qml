import QtQuick 2.15
import ".."
import "../sig"

// The head of a Today visual: its cap label, and for a rider with no rides yet a quiet chip that
// says the picture is a sample of what comes after the first ride.
Item {
    id: head

    property string title: ""
    property bool sample: false

    implicitHeight: 24

    CapLabel {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, head.width - (chip.visible ? chip.width + 10 : 0))
        text: head.title
        Accessible.ignored: true
    }
    Rectangle {
        id: chip
        visible: head.sample
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: chipText.implicitWidth + 20
        height: 24
        radius: 12
        color: Theme.chip
        Text {
            id: chipText
            anchors.centerIn: parent
            text: qsTr("After your first ride")
            color: Theme.text2
            font.family: Theme.bodySemibold
            font.pixelSize: 11
        }
    }
}
