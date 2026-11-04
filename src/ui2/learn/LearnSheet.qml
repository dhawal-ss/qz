import QtQuick 2.15
import ".."
import "../sig"
import "Learn.js" as Learn

// Tap to learn: the sheet that slides up over a screen when a chart or a big number is tapped.
// What yours says leads in display type, then what it is, why it matters and one thing to try
// on hairlines, an optional action ("See your goals") and links to related entries. It slides
// up on the default spatial spring and its blocks rise in, again when a related entry is picked.
//   LearnSheet { anchors.fill: parent; open: page.learnOpen; entry: page.learnEntry
//                onClose: page.learnOpen = false; onRelated: page.openLearn(id, {}) }
Item {
    id: sheet
    objectName: "learnSheet"

    property bool open: false
    property var entry: null         // Learn.entry()
    property color tint: Theme.accent
    // the system bar under the sheet: the end of the content stays clear of it
    property real bottomInset: 0
    // an optional button under Try this: its words, and act() when it is pressed
    property string actionLabel: ""
    // the entries this screen can fill with the rider's numbers: the related links keep to these
    property var known: []

    signal close()
    signal related(string id)
    signal act()
    // the blocks rise in: when the sheet opens and when the entry changes
    signal entered()

    readonly property var shown: entry || Learn.entry("", {})
    readonly property var links: shown.related.filter(function (id) { return known.length === 0 || known.indexOf(id) >= 0 })

    visible: open || panel.y < height - 0.5
    Accessible.ignored: !open

    onOpenChanged: {
        if (open) {
            scroller.contentY = 0
            entered()
        }
    }
    onEntryChanged: {
        if (open) {
            scroller.contentY = 0
            entered()
        }
    }

    // dims the page behind the sheet, a tap there closes it
    PulseButton {
        anchors.fill: parent
        radius: 0
        pressedScale: 1
        fill: Qt.rgba(5 / 255, 5 / 255, 6 / 255, sheet.open ? 0.62 : 0)
        Accessible.name: qsTr("Close")
        onClicked: sheet.close()
    }

    Rectangle {
        id: panel
        objectName: "learnPanel"
        width: Math.min(560, sheet.width)
        height: Math.min(sheet.height - 16, body.height + 44 + sheet.bottomInset)
        x: (sheet.width - width) / 2
        y: sheet.open ? sheet.height - height : sheet.height + 8
        color: Theme.control
        radius: 28

        Behavior on y {
            enabled: !Theme.reduceMotion
            Spring { token: "default" }
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

        // the handle
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: 36
            height: 4
            radius: 2
            color: Theme.rest
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            contentHeight: body.height + 44 + sheet.bottomInset
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: body
                x: 24
                y: 22
                width: panel.width - 48
                spacing: 0

                // the name, and the way out
                Rise {
                    cue: sheet
                    order: 0
                    width: parent.width
                    Item {
                        width: parent.width
                        height: Math.max(48, titleText.implicitHeight)
                        Row {
                            id: titleRow
                            width: parent.width - closeButton.width - 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Pulse {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                zone: 2
                                color: sheet.tint
                            }
                            Text {
                                id: titleText
                                width: titleRow.width - 32
                                anchors.verticalCenter: parent.verticalCenter
                                text: sheet.shown.title
                                color: Theme.text
                                font.family: Theme.display
                                font.pixelSize: sheet.width < 400 ? 24 : 26
                                font.letterSpacing: -0.4
                                lineHeight: 0.92
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Accessible.role: Accessible.Heading
                                Accessible.name: text
                            }
                        }
                        PulseButton {
                            id: closeButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 48
                            height: 48
                            topInset: 2
                            bottomInset: 2
                            leftInset: 2
                            rightInset: 2
                            fill: pressed ? Theme.pressed : Theme.chip
                            Accessible.name: qsTr("Close")
                            onClicked: sheet.close()
                            contentItem: Item {
                                Icon { anchors.centerIn: parent; name: "close"; size: 20; color: Theme.text }
                            }
                        }
                    }
                }

                // what it is, in one line
                Rise {
                    cue: sheet
                    order: 0
                    width: parent.width
                    Text {
                        width: parent.width
                        topPadding: 8
                        bottomPadding: 18
                        text: sheet.shown.what
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.fs(15)
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 21
                        wrapMode: Text.WordWrap
                    }
                }

                // what yours says: the lead
                Rise {
                    cue: sheet
                    order: 1
                    width: parent.width
                    Column {
                        width: parent.width
                        spacing: 10
                        Hairline { width: parent.width }
                        Item { width: 1; height: 6 }
                        CapLabel {
                            text: qsTr("What yours says")
                            color: sheet.tint
                        }
                        Text {
                            objectName: "learnYours"
                            width: parent.width
                            bottomPadding: 18
                            text: sheet.shown.yours
                            color: Theme.text
                            font.family: Theme.display
                            font.pixelSize: sheet.width < 400 ? 20 : 22
                            font.letterSpacing: -0.3
                            lineHeightMode: Text.FixedHeight
                            lineHeight: Math.round(font.pixelSize * 1.22)
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // why it matters, and one thing to try
                Repeater {
                    model: [[qsTr("Why it matters"), sheet.shown.why], [qsTr("Try this"), sheet.shown.tryThis]]
                    Rise {
                        cue: sheet
                        order: 2 + index
                        width: body.width
                        Column {
                            width: parent.width
                            spacing: 8
                            Hairline { width: parent.width }
                            Item { width: 1; height: 6 }
                            CapLabel {
                                text: modelData[0]
                            }
                            Text {
                                width: parent.width
                                bottomPadding: 16
                                text: modelData[1]
                                color: Theme.text
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.fs(15)
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 21
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                // where it leads, and what to read next
                Rise {
                    cue: sheet
                    order: 4
                    width: parent.width
                    Column {
                        width: parent.width
                        spacing: 14
                        PulseButton {
                            visible: sheet.actionLabel !== ""
                            width: Math.min(parent.width, actionText.implicitWidth + 48)
                            height: 52
                            fill: pressed ? Qt.lighter(sheet.tint, 1.08) : sheet.tint
                            pressedRadius: 16
                            Accessible.name: sheet.actionLabel
                            onClicked: sheet.act()
                            contentItem: Text {
                                id: actionText
                                text: sheet.actionLabel
                                color: Theme.accentInk
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(15)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Column {
                            visible: sheet.links.length > 0
                            width: parent.width
                            spacing: 10
                            Hairline { width: parent.width }
                            CapLabel {
                                text: qsTr("Related")
                            }
                            Flow {
                                width: parent.width
                                spacing: 8
                                Repeater {
                                    model: sheet.links
                                    PulseButton {
                                        width: chipText.implicitWidth + 32
                                        height: 44
                                        topInset: 4
                                        bottomInset: 4
                                        radius: 18
                                        pressedRadius: 12
                                        fill: pressed ? Theme.pressed : Theme.chip
                                        Accessible.name: qsTr("Learn about %1").arg(chipText.text)
                                        onClicked: sheet.related(modelData)
                                        contentItem: Text {
                                            id: chipText
                                            text: Learn.titleOf(modelData)
                                            color: Theme.text
                                            font.family: Theme.bodySemibold
                                            font.pixelSize: Theme.fs(13)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
