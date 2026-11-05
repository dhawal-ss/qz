import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"

// Share ride: the card as it will be saved, Share (when the app can hand a picture to Android),
// Save, and Post to Strava, shown but not there yet. On a phone on its side the card is on the
// left and the buttons on the right. On Android the picture goes into the phone's Photos
// (Pictures/Bikemodo, bikemodoBridge.saveToPhotos), once for each card: Share hands that picture
// to Android's share sheet. Elsewhere it is saved as a file in folder.
Item {
    id: sheet

    property var ride: ({})
    property var moment: ({})
    property var spark: []
    property var bars: []
    property int minutesPerBar: 1
    property string name: ""
    property real when: Date.now()
    // the lit lines of the card, Share.achievements()
    property var achievements: []
    // where the picture is written first (rootItem.getWritableAppDir())
    property string folder: ""
    // the phone's Photos can take the picture, and so the share sheet can too
    readonly property bool photos: typeof bikemodoBridge !== "undefined" && bikemodoBridge !== null && bikemodoBridge.canSaveToPhotos()
    readonly property bool canShare: photos
    // where the card was saved: its file, or its content:// address in Photos
    property string savedImage: ""
    property string savedUri: ""
    property bool failed: false
    property alias card: card

    signal close()

    // a card that changes (its minutes read from the saved ride) is saved again
    onBarsChanged: forget()
    onAchievementsChanged: forget()
    function forget() {
        savedImage = ""
        savedUri = ""
        failed = false
    }

    // the card saved once, then(uri) after: uri is "" off Android or when it failed
    function store(then) {
        if (savedUri !== "") {
            then(savedUri)
            return
        }
        var name = "bikemodo-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png"
        card.save(folder + name, function (ok, where) {
            if (!ok) {
                sheet.failed = true
                then("")
                return
            }
            if (!sheet.photos) {
                sheet.failed = false
                sheet.savedImage = where
                then("")
                return
            }
            var uri = bikemodoBridge.saveToPhotos(where, name)
            sheet.failed = uri === ""
            sheet.savedUri = uri
            sheet.savedImage = uri
            then(uri)
        })
    }

    function save() {
        store(function () {})
    }

    function share() {
        store(function (uri) {
            if (uri !== "")
                sheet.failed = !bikemodoBridge.sharePicture(uri, qsTr("Share ride"))
        })
    }

    readonly property bool sideways: width > height
    readonly property real controlsHeight: (canShare ? 64 + 10 : 0) + 52 + 44 + statusText.height + 12
    readonly property real fit: sideways ? Math.min((width * 0.56 - 48) / 1080, (height - 100) / 1350)
                                         : Math.min((width - 48) / 1080, (height - 82 - 22 - controlsHeight - 16) / 1350)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Share ride")

    Component.onCompleted: card.grow()

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }
    // keeps taps from reaching the summary under it
    MouseArea { anchors.fill: parent }

    Item {
        id: topLine
        x: 24
        y: 16
        width: sheet.width - 48
        height: 44
        PulseButton {
            x: -2
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            topInset: 2
            bottomInset: 2
            leftInset: 2
            rightInset: 2
            fill: pressed ? Theme.pressed : Theme.control
            Accessible.name: qsTr("Close")
            onClicked: sheet.close()
            contentItem: Item {
                Icon { anchors.centerIn: parent; name: "close"; size: 18; weight: 1.8; color: Theme.text }
            }
        }
        Text {
            anchors.centerIn: parent
            text: qsTr("Share ride")
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(17)
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
    }

    Rise {
        id: preview
        x: sheet.sideways ? 24 : (sheet.width - width) / 2
        // between the top line and the buttons
        y: sheet.sideways ? Math.max(topLine.y + topLine.height + 8, (sheet.height - height) / 2)
                          : Math.max(topLine.y + topLine.height + 22, (topLine.y + topLine.height + controls.y - height) / 2)
        width: 1080 * sheet.fit
        height: 1350 * sheet.fit
        order: 1
        Item {
            width: 1080
            height: 1350
            scale: sheet.fit
            transformOrigin: Item.TopLeft
            ShareCard {
                id: card
                ride: sheet.ride
                moment: sheet.moment
                spark: sheet.spark
                bars: sheet.bars
                minutesPerBar: sheet.minutesPerBar
                name: sheet.name
                when: sheet.when
                achievements: sheet.achievements
            }
        }
    }

    Column {
        id: controls
        x: sheet.sideways ? preview.x + preview.width + 24 : 24
        width: sheet.sideways ? sheet.width - x - 24 : sheet.width - 48
        y: sheet.sideways ? Math.max(topLine.y + topLine.height + 8, (sheet.height - height) / 2) : sheet.height - 44 - height
        spacing: 10

        Text {
            id: statusText
            width: parent.width
            visible: text !== ""
            text: sheet.failed ? qsTr("The image could not be saved.")
                  : (sheet.savedUri !== "" ? qsTr("Saved to Photos, in Pictures/Bikemodo")
                     : (sheet.savedImage !== "" ? qsTr("Saved to %1").arg(sheet.savedImage) : ""))
            color: sheet.failed ? Theme.danger : Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(13)
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        // Share leads when the app can share; else Save does
        PulseButton {
            id: leadButton
            width: parent.width
            height: 64
            pressedRadius: 20
            fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
            Accessible.name: sheet.canShare ? qsTr("Share") : qsTr("Save image")
            onClicked: sheet.canShare ? sheet.share() : sheet.save()
            contentItem: Item {
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Shape {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: Theme.accentInk
                            strokeWidth: 1.8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            scale: Qt.size(20 / 24, 20 / 24)
                            PathSvg { path: sheet.canShare ? "M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6" : "M12 3v12M7 10l5 5 5-5M5 21h14" }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sheet.canShare ? qsTr("Share") : qsTr("Save image")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(18)
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10
            PulseButton {
                id: saveButton
                visible: sheet.canShare
                width: (parent.width - 10) / 2.4
                height: 52
                radius: 18
                pressedRadius: 12
                fill: pressed ? Theme.chip : Theme.pressed
                Accessible.name: qsTr("Save image")
                onClicked: sheet.save()
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Shape {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            layer.enabled: true
                            layer.samples: 4
                            ShapePath {
                                strokeColor: Theme.text
                                strokeWidth: 1.8
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                scale: Qt.size(0.75, 0.75)
                                PathSvg { path: "M12 3v12M7 10l5 5 5-5M5 21h14" }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Save")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(15)
                        }
                    }
                }
            }
            // Strava posting needs its API; until then it shows, quietly, as not there yet
            PulseButton {
                width: saveButton.visible ? parent.width - saveButton.width - 10 : parent.width
                height: 52
                radius: 18
                enabled: false
                opacity: 0.45
                fill: Theme.pressed
                Accessible.name: qsTr("Post to Strava, not available yet")
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Shape {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            layer.enabled: true
                            layer.samples: 4
                            ShapePath {
                                strokeColor: Theme.text
                                strokeWidth: 1.8
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                scale: Qt.size(0.75, 0.75)
                                PathSvg { path: "M5 19l7-14 7 14M9 13h6" }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Post to Strava")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(15)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Soon")
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(12)
                        }
                    }
                }
            }
        }
    }
}
