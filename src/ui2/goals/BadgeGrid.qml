import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Badges.js" as Badges

// Badges: the earned ones newest first, then the few closest to being earned, and every other
// one behind See all. A tap opens the badge. A quiet section: a cap label, no box.
Column {
    id: badgeCard

    property var badges: []          // Badges.evaluate()
    property bool miles: false

    signal openBadge(string id)

    property bool showAll: false

    readonly property var earnedList: Badges.earned(badges)
    readonly property var lockedList: Badges.next(badges, showAll ? badges.length : 3)
    readonly property int columns: Math.max(3, Math.floor((width + 8) / 100))
    readonly property real cellWidth: (width - 8 * (columns - 1)) / columns

    spacing: 12

    function subtitle(b) {
        if (b.earned)
            return Format.day(b.date)
        return Badges.progressText(b, miles)
    }

    Item {
        width: parent.width
        height: 24
        CapLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Badges")
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("%1 of %2 earned").arg(badgeCard.earnedList.length).arg(badgeCard.badges.length)
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
        }
    }

    Text {
        visible: badgeCard.earnedList.length === 0
        width: parent.width
        text: qsTr("Your first badge is one ride away.")
        color: Theme.text
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.bodySize
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: [{ title: "", list: badgeCard.earnedList }, { title: badgeCard.showAll ? qsTr("Still to earn") : qsTr("Next up"), list: badgeCard.lockedList }]
        Column {
            id: section
            readonly property var sectionList: modelData.list
            visible: sectionList.length > 0
            width: parent.width
            spacing: 8
            CapLabel {
                visible: modelData.title !== ""
                topPadding: 8
                text: modelData.title
            }
            Grid {
                columns: badgeCard.columns
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: section.sectionList
                    PulseButton {
                        id: badgeCell
                        width: badgeCard.cellWidth
                        height: cellColumn.implicitHeight + 16
                        radius: 18
                        pressedScale: 0.96
                        fill: pressed ? Theme.pressed : "transparent"
                        Accessible.name: modelData.earned
                                         ? qsTr("%1 badge, earned %2").arg(modelData.name).arg(Format.day(modelData.date))
                                         : qsTr("%1 badge, locked, %2").arg(modelData.name).arg(Badges.progressText(modelData, badgeCard.miles))
                        onClicked: badgeCard.openBadge(modelData.id)
                        contentItem: Item {
                            Column {
                                id: cellColumn
                                y: 8
                                width: parent.width
                                spacing: 6
                                BadgeEmblem {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    badge: modelData
                                    size: Math.min(60, badgeCell.width - 16)
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: modelData.earned ? Theme.text : Theme.text2
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.tertiarySize
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: badgeCard.subtitle(modelData)
                                    color: Theme.text3
                                    font.family: Theme.bodyMedium
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PulseButton {
        visible: badgeCard.badges.length > badgeCard.earnedList.length + 3
        x: -12
        width: allLabel.implicitWidth + 24
        height: 44
        fill: pressed ? Theme.pressed : "transparent"
        Accessible.name: allLabel.text
        onClicked: badgeCard.showAll = !badgeCard.showAll
        contentItem: Text {
            id: allLabel
            text: badgeCard.showAll ? qsTr("Show fewer") : qsTr("See all %1 badges").arg(badgeCard.badges.length)
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
