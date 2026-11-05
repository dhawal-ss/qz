import QtQuick 2.15
import QtQuick.Controls 2.15
import ".."

// Ride in the navigation: the round button in the accent (RideFab) with its name under it, like
// the destinations beside it. While a ride is paused and left it says Resume, and the button
// carries its dot. The whole slot is the button.
AbstractButton {
    id: slot

    property bool paused: false

    padding: 0
    focusPolicy: Qt.NoFocus
    Accessible.ignored: true
    background: Item {}

    contentItem: Item {
        // the name on the line of the destinations' names, the button over it
        RideFab {
            id: fab
            anchors.horizontalCenter: parent.horizontalCenter
            y: label.y - 3 - height
            size: 44
            paused: slot.paused
            onClicked: slot.clicked()
        }
        Text {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 10
            width: Math.min(implicitWidth, parent.width - 4)
            text: slot.paused ? qsTr("Resume") : qsTr("Ride")
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(12)
            Accessible.ignored: true
        }
    }
}
