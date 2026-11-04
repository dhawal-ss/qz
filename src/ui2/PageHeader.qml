import QtQuick 2.15
import "."

// The top of a section in the Signature language: the title big in the display face on the
// line of Today's date, a quiet line under it, a back arrow when there is somewhere to go back
// to, and the round You button where the navigation has no You (phones; tablets have it in
// the rail).
Item {
    id: header

    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    property bool showYou: false
    property string initial: "B"

    signal back()
    signal openYou()

    implicitHeight: column.y + column.height + 16

    PulseButton {
        id: backButton
        visible: header.showBack
        x: -10
        y: 22
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
        y: 24
        width: parent.width - x - (header.showYou ? 56 : 0)
        spacing: 6
        Text {
            width: parent.width
            // on the 44 high line of the You button, as Today's date
            height: Math.max(44, implicitHeight)
            verticalAlignment: Text.AlignVCenter
            text: header.title
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: header.showBack ? 26 : 34
            font.letterSpacing: header.showBack ? -0.4 : -0.8
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
            font.pixelSize: Theme.fs(13)
            wrapMode: Text.WordWrap
        }
    }

    PulseButton {
        visible: header.showYou
        anchors.right: parent.right
        y: 22
        // 48 to touch, 44 to see
        width: 48
        height: 48
        topInset: 2
        bottomInset: 2
        leftInset: 2
        rightInset: 2
        fill: pressed ? Theme.pressed : Theme.control
        Accessible.name: qsTr("You, profile and settings")
        onClicked: header.openYou()
        contentItem: Text {
            text: header.initial
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(17)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
