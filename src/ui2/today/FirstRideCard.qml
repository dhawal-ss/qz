import QtQuick 2.15
import ".."
import "../sig"

// Before the first ride: what Today fills in once there are rides, as quiet rows. While QZ's
// older rides are read in, how far that got.
Column {
    id: firstCard

    property bool busy: false
    property int indexed: 0
    property int toIndex: 0

    spacing: 4

    CapLabel {
        text: firstCard.busy ? qsTr("Reading your ride history") : qsTr("What fills in here")
    }
    Text {
        visible: firstCard.busy
        width: firstCard.width
        topPadding: 8
        bottomPadding: 8
        text: qsTr("%1 of %2 rides read. They show up here as they come in.").arg(firstCard.indexed).arg(firstCard.toIndex)
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: [
            { tone: 3, title: qsTr("Your form, every morning"), detail: qsTr("How ready your legs are, from the load of every ride.") },
            { tone: 1, title: qsTr("Your week"), detail: qsTr("Each day in the color of its effort, against a goal you pick.") },
            { tone: 5, title: qsTr("Your records"), detail: qsTr("Best power from 5 seconds to an hour, and when one is in reach.") }
        ]
        Item {
            width: firstCard.width
            height: Math.max(64, firstTexts.implicitHeight + 24)
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.title + ". " + modelData.detail
            Rectangle {
                width: 10
                height: 10
                radius: 5
                y: 20
                color: Theme.zoneColors[modelData.tone - 1]
            }
            Column {
                id: firstTexts
                x: 24
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    width: parent.width
                    text: modelData.title
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: modelData.detail
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            Hairline {
                visible: index < 2
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }
    }
}
