import QtQuick 2.15
import ".."
import "../sig"
import "../learn"

// The head of a Progress section: the cap label on the left and a quiet note on the right
// ("Last 90 days", "vs last period"). With `learnable` the label is the button to the Learn
// sheet of the section (learn()), for a section whose body taps do something else.
Item {
    id: head

    property string title: ""
    property string note: ""
    property bool learnable: false

    signal learn()

    implicitHeight: 24

    CapLabel {
        visible: !head.learnable
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, head.width - noteText.implicitWidth - 12)
        text: head.title
    }
    LearnLabel {
        visible: head.learnable
        x: -8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, head.width - noteText.implicitWidth - 4)
        caption: head.title
        onClicked: head.learn()
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
