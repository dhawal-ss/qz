import QtQuick 2.15
import ".."

// The frame of every page of You: a back button on a phone, the title, and the rows in a
// column that stays readable on a tablet.
Item {
    id: page

    // the YouScreen
    property var you: null
    property string title: ""
    property string lead: ""
    default property alias content: body.data

    readonly property real margin: width < 600 ? 16 : 24
    readonly property bool showBack: you !== null && !you.wide

    // the page comes in from the side, with a little overshoot
    property real shift: 0
    Component.onCompleted: if (!Theme.reduceMotion) enter.start()
    ParallelAnimation {
        id: enter
        NumberAnimation { target: page; property: "shift"; from: 36; to: 0; duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
        NumberAnimation { target: flick; property: "opacity"; from: 0; to: 1; duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.y + column.height + 32 + (page.you !== null && page.you.restartNeeded ? 140 : 0)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            width: Math.min(720, page.width - 2 * (page.margin - 12))
            x: (page.width - width) / 2 + page.shift
            y: page.showBack ? 8 : 28

            PulseButton {
                visible: page.showBack
                x: 0
                width: 48
                height: 48
                fill: pressed ? Theme.control : Qt.rgba(0, 0, 0, 0)
                Accessible.name: qsTr("Back")
                onClicked: page.you.goBack()
                contentItem: Item {
                    YouIcon {
                        anchors.centerIn: parent
                        name: "back"
                        size: 24
                        weight: 2.4
                        color: Theme.text
                    }
                }
            }

            Text {
                width: parent.width
                leftPadding: 12
                rightPadding: 12
                topPadding: page.showBack ? 4 : 0
                text: page.title
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: 30
                wrapMode: Text.WordWrap
            }

            Text {
                visible: page.lead !== ""
                width: parent.width
                leftPadding: 12
                rightPadding: 12
                topPadding: 8
                text: page.lead
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                lineHeight: 1.15
                wrapMode: Text.WordWrap
            }

            Item {
                width: 1
                height: 12
            }

            Column {
                id: body
                width: parent.width
            }
        }
    }
}
