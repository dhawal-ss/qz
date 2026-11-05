import QtQuick 2.15
import ".."
import "../Format.js" as Format
import "Badges.js" as Badges

// One badge, big: how it is earned, and the day it was or how close it is.
Item {
    id: sheet

    property bool open: false
    property var badge: null
    property bool miles: false

    signal close()

    readonly property var shown: badge || ({ name: "", how: "", tone: 1, tier: 1, glyph: "spark", earned: false, progress: 0 })
    readonly property color tint: Theme.zoneColors[Math.max(1, Math.min(7, shown.tone || 1)) - 1]

    visible: open || panel.y < height
    Accessible.ignored: !open

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
        height: Math.min(sheet.height - 16, body.height + 40)
        x: (sheet.width - width) / 2
        y: sheet.open ? sheet.height - height : sheet.height
        color: Theme.control
        radius: 28

        Behavior on y {
            enabled: Theme.layoutMotion
            NumberAnimation { duration: 450; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
        }

        // square the bottom corners, the sheet runs off the screen there
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 28
            color: Theme.control
        }

        MouseArea { anchors.fill: parent }

        Flickable {
            anchors.fill: parent
            contentHeight: body.height + 40
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: body
                x: 24
                y: 20
                width: panel.width - 48
                spacing: 12

                Item {
                    width: parent.width
                    height: 48
                    PulseButton {
                        anchors.right: parent.right
                        width: 48
                        height: 48
                        fill: pressed ? Theme.pressed : Theme.chip
                        Accessible.name: qsTr("Close the badge")
                        onClicked: sheet.close()
                        contentItem: Item {
                            Icon { anchors.centerIn: parent; name: "close"; size: 20; color: Theme.text }
                        }
                    }
                }

                BadgeEmblem {
                    anchors.horizontalCenter: parent.horizontalCenter
                    badge: sheet.shown
                    size: Math.min(128, Math.max(72, sheet.height * 0.18))
                    Accessible.role: Accessible.Graphic
                    Accessible.ignored: false
                    Accessible.name: sheet.shown.earned ? qsTr("%1 emblem").arg(sheet.shown.name) : qsTr("%1 emblem, locked").arg(sheet.shown.name)
                }

                Text {
                    width: parent.width
                    text: sheet.shown.name
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 28
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Text {
                    width: parent.width
                    text: sheet.shown.how
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Text {
                    visible: sheet.shown.earned
                    width: parent.width
                    text: qsTr("Earned %1").arg(sheet.shown.date ? Format.day(sheet.shown.date) : "")
                    color: sheet.tint
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                }
                Column {
                    visible: !sheet.shown.earned
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        width: parent.width
                        height: 10
                        radius: 5
                        color: Theme.chip
                        Accessible.role: Accessible.ProgressBar
                        Accessible.name: sheet.badge ? Badges.progressText(sheet.shown, sheet.miles) : ""
                        Rectangle {
                            width: Math.max(10, parent.width * (sheet.shown.progress || 0))
                            height: parent.height
                            radius: 5
                            color: sheet.tint
                        }
                    }
                    Text {
                        width: parent.width
                        text: sheet.badge ? Badges.progressText(sheet.shown, sheet.miles) : ""
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.labelSize
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
