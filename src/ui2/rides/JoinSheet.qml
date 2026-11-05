import QtQuick 2.15
import ".."
import "../sig"

// The question before rides are merged or split, as a small sheet over the ride: what will
// happen in a coach-like headline and one line, then Cancel and the change itself. It slides up
// on the default spatial spring; a tap on the dimmed page or Cancel closes it.
//   JoinSheet { anchors.fill: parent; open: page.asking !== ""; title: ...; words: ...
//               confirmText: qsTr("Merge"); onConfirm: page.merge(); onClose: page.asking = "" }
Item {
    id: sheet
    objectName: "joinSheet"

    property bool open: false
    property string title: ""
    property string words: ""
    property string confirmText: ""
    // the other button, and what a tap on the dimmed page does too (close)
    property string cancelText: qsTr("Cancel")
    // the system bar under the sheet: the buttons stay clear of it
    property real bottomInset: 0

    signal confirm()
    signal close()
    // the blocks rise in each time it opens
    signal entered()

    visible: open || panel.y < height - 0.5
    Accessible.ignored: !open
    onOpenChanged: if (open) entered()

    // dims the page behind the sheet, a tap there closes it
    PulseButton {
        anchors.fill: parent
        radius: 0
        pressedScale: 1
        fill: Qt.rgba(5 / 255, 5 / 255, 6 / 255, sheet.open ? 0.62 : 0)
        Accessible.name: qsTr("Close")
        onClicked: sheet.close()
        Behavior on fill {
            enabled: !Theme.reduceMotion
            ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        }
    }

    Rectangle {
        id: panel
        objectName: "joinPanel"
        width: Math.min(560, sheet.width)
        height: body.height + 40 + sheet.bottomInset
        x: (sheet.width - width) / 2
        y: sheet.open ? sheet.height - height : sheet.height + 8
        color: Theme.control
        radius: 28

        Behavior on y {
            enabled: Theme.layoutMotion
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

        Column {
            id: body
            x: 24
            y: 30
            width: panel.width - 48
            spacing: 0

            Rise {
                cue: sheet
                order: 0
                width: parent.width
                Text {
                    width: parent.width
                    text: sheet.title
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: sheet.width < 400 ? 26 : 28
                    font.letterSpacing: -0.5
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.08)
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
            }
            Item { width: 1; height: 12 }
            Rise {
                cue: sheet
                order: 1
                width: parent.width
                Text {
                    width: parent.width
                    text: sheet.words
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(15)
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 21
                    wrapMode: Text.WordWrap
                }
            }
            Item { width: 1; height: 24 }
            Rise {
                cue: sheet
                order: 2
                width: parent.width
                Row {
                    width: parent.width
                    spacing: 10
                    PulseButton {
                        id: cancelButton
                        width: (parent.width - 10) * 0.42
                        height: 56
                        pressedRadius: 18
                        fill: pressed ? Theme.chip : Theme.pressed
                        Accessible.name: sheet.cancelText
                        onClicked: sheet.close()
                        contentItem: Text {
                            text: sheet.cancelText
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(16)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    PulseButton {
                        width: parent.width - cancelButton.width - 10
                        height: 56
                        pressedRadius: 18
                        fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                        Accessible.name: sheet.confirmText
                        onClicked: sheet.confirm()
                        contentItem: Text {
                            text: sheet.confirmText
                            color: Theme.accentInk
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(16)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
