import QtQuick 2.15
import ".."
import "../you"

// The sheet where the rider picks which Today cards show and in what order: a switch per card
// and buttons to move it up or down, so nothing needs a drag. A copy of the Progress sheet
// (progress/CustomizeSheet.qml) with its own words.
Item {
    id: sheet

    property bool open: false
    property var cards: []           // [{id, shown}] in order
    property var titles: ({})        // id -> title

    signal moveCard(int from, int to)
    signal showCard(string id, bool shown)
    signal close()

    visible: open || panel.y < height
    Accessible.ignored: !open

    // dims the page behind the sheet, a tap there closes it
    PulseButton {
        anchors.fill: parent
        radius: 0
        pressedScale: 1
        fill: Qt.rgba(5 / 255, 5 / 255, 6 / 255, sheet.open ? 0.6 : 0)
        Accessible.name: qsTr("Close")
        onClicked: sheet.close()
    }

    Rectangle {
        id: panel
        width: Math.min(520, sheet.width)
        height: Math.min(sheet.height - 16, head.y + head.height + 12 + sheet.cards.length * 60 + 24)
        x: (sheet.width - width) / 2
        y: sheet.open ? sheet.height - height : sheet.height
        color: Theme.control
        radius: 28

        Behavior on y {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: 450; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
        }

        // square the bottom corners, the sheet runs off the screen there
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 28
            color: Theme.control
        }

        // swallow taps on the panel itself
        MouseArea { anchors.fill: parent }

        Item {
            id: head
            x: 20
            y: 16
            width: panel.width - 40
            height: Math.max(titleBlock.height, done.height)
            Column {
                id: titleBlock
                width: parent.width - done.width - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    width: parent.width
                    text: qsTr("Customize")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 24
                    elide: Text.ElideRight
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Text {
                    width: parent.width
                    text: qsTr("Pick the Today cards and their order. The bike stays on top.")
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.tertiarySize
                    wrapMode: Text.WordWrap
                }
            }
            PulseButton {
                id: done
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: doneLabel.implicitWidth + 36
                height: 48
                fill: pressed ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                Accessible.name: qsTr("Done")
                onClicked: sheet.close()
                contentItem: Text {
                    id: doneLabel
                    text: qsTr("Done")
                    color: Theme.accentInk
                    font.family: Theme.bodySemibold
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        ListView {
            id: list
            x: 8
            y: head.y + head.height + 12
            width: panel.width - 16
            height: panel.height - y - 16
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: sheet.cards
            delegate: Item {
                id: cardRow
                width: list.width
                height: 60
                YouSwitch {
                    id: cardSwitch
                    width: parent.width - upButton.width - downButton.width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    title: sheet.titles[modelData.id] || modelData.id
                    isOn: modelData.shown
                    hairline: false
                    onSwitched: sheet.showCard(modelData.id, value)
                }
                PulseButton {
                    id: upButton
                    x: cardSwitch.width + 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    enabled: index > 0
                    opacity: enabled ? 1 : 0.3
                    fill: pressed ? Theme.pressed : "transparent"
                    Accessible.name: qsTr("Move %1 up").arg(cardSwitch.title)
                    onClicked: sheet.moveCard(index, index - 1)
                    contentItem: Item {
                        Icon {
                            anchors.centerIn: parent
                            name: "chevron"
                            size: 22
                            rotation: 180
                            color: Theme.text
                        }
                    }
                }
                PulseButton {
                    id: downButton
                    x: upButton.x + upButton.width
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    enabled: index < sheet.cards.length - 1
                    opacity: enabled ? 1 : 0.3
                    fill: pressed ? Theme.pressed : "transparent"
                    Accessible.name: qsTr("Move %1 down").arg(cardSwitch.title)
                    onClicked: sheet.moveCard(index, index + 1)
                    contentItem: Item {
                        Icon {
                            anchors.centerIn: parent
                            name: "chevron"
                            size: 22
                            color: Theme.text
                        }
                    }
                }
            }
        }
    }
}
