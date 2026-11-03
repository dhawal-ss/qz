import QtQuick 2.15
import ".."

// About: what Bikemodo is built on, and whose work it is.
YouPage {
    id: page

    title: qsTr("About")

    Item {
        width: parent.width
        height: brandCard.height + 8

        Rectangle {
            id: brandCard
            x: 12
            width: parent.width - 24
            height: brandColumn.height + 44
            radius: Theme.heroRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.raisedBorder

            Column {
                id: brandColumn
                x: 22
                y: 22
                width: parent.width - 44
                spacing: 16

                Row {
                    spacing: 14
                    Rectangle {
                        width: 52
                        height: 52
                        radius: 16
                        color: Theme.accentInk
                        BrandMark {
                            anchors.fill: parent
                            anchors.margins: 5
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "Bikemodo"
                            color: Theme.text
                            font.family: Theme.display
                            font.pixelSize: 26
                        }
                        Text {
                            visible: you.version !== ""
                            text: qsTr("Version %1").arg(you.version)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.labelSize
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: qsTr("Built on QDomyos-Zwift by Roberto Viola, open source under GPL-3.0.")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.bodySize
                    lineHeight: 1.15
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Source code")
    }

    YouRow {
        title: qsTr("QDomyos-Zwift")
        detail: "github.com/cagnulein/qdomyos-zwift"
        trailing: "open"
        onClicked: Qt.openUrlExternally("https://github.com/cagnulein/qdomyos-zwift")
    }

    YouRow {
        title: qsTr("Bikemodo")
        detail: "github.com/dhawal-ss/qz"
        trailing: "open"
        hairline: false
        onClicked: Qt.openUrlExternally("https://github.com/dhawal-ss/qz")
    }

    YouText {
        kind: "heading"
        text: qsTr("Credits")
    }

    YouText {
        color: Theme.text2
        text: qsTr("Type is Google Sans Flex, under the SIL Open Font License 1.1.")
    }
    YouText {
        text: qsTr("QDomyos-Zwift is the work of Roberto Viola and its contributors. Bikemodo adds a new interface on top and keeps the GPL-3.0 license.")
    }
}
