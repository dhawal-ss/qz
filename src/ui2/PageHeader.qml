import QtQuick 2.15
import "."

// The top of a section: a back arrow when there is somewhere to go back to, the title, a line
// under it, and on phones the round You button (tablets reach You from the rail).
Item {
    id: header

    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    property bool showYou: false
    property string initial: "B"

    signal back()
    signal openYou()

    implicitHeight: column.height + 20

    PulseButton {
        id: backButton
        visible: header.showBack
        x: -8
        y: 10
        width: 48
        height: 48
        fill: pressed ? Theme.pressed : "transparent"
        Accessible.name: qsTr("Back")
        onClicked: header.back()
        contentItem: Item {
            Icon { anchors.centerIn: parent; name: "back"; size: 22; color: Theme.text }
        }
    }

    Column {
        id: column
        x: header.showBack ? 44 : 0
        y: 14
        width: parent.width - x - (header.showYou ? 56 : 0)
        spacing: 2
        Text {
            width: parent.width
            text: header.title
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: header.showBack ? 24 : 32
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Text {
            width: parent.width
            visible: header.subtitle !== ""
            text: header.subtitle
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
            wrapMode: Text.WordWrap
        }
    }

    PulseButton {
        visible: header.showYou
        anchors.right: parent.right
        y: 12
        width: 44
        height: 44
        fill: Theme.chip
        Accessible.name: qsTr("You, profile and settings")
        onClicked: header.openYou()
        contentItem: Text {
            text: header.initial
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: 17
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
