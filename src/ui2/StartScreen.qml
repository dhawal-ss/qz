import QtQuick 2.15
import "."
import "sig"
import "you"

// Before the ride: is the bike there, and a way into the ride or a demo. Opened by the Ride
// button when the bike is not connected yet.
// While it searches, a calm Pulse in the accent breathes and turns slowly; when the bike is
// found it blooms (a springy swell) into the Endurance zone color, zoneColors[1], and the
// Start ride pill takes over. On a landscape phone the Pulse sits left of the words.
Item {
    id: start

    property bool connected: false
    property string deviceName: ""
    property string searchStatus: ""
    property bool rideInProgress: false

    signal openRide()
    signal openDemo()
    signal searchAgain()
    signal closeRequested()

    readonly property color found: Theme.zoneColors[1]
    readonly property color tint: connected ? found : Theme.accent
    readonly property bool sideBySide: width > height && height < 600
    readonly property real margin: Theme.margin(width)

    // the found moment: the Pulse swells past its size and settles
    onConnectedChanged: if (connected && !Theme.reduceMotion) bloom.restart()

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // the stage of the Pulse: the top of the screen on a phone, the left half in landscape
    Item {
        id: stageArea
        x: 0
        y: start.sideBySide ? 0 : 76
        width: start.sideBySide ? start.width * 0.42 : start.width
        height: start.sideBySide ? start.height : Math.min(260, start.height * 0.3)

        HeroGlow {
            width: Math.min(420, stageArea.width * 1.1)
            height: width
            anchors.centerIn: pulseHolder
            tint: start.tint
            low: 0.2
            high: start.connected ? 0.42 : 0.3
            Behavior on tint {
                enabled: !Theme.reduceMotion
                ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
        }

        Item {
            id: pulseHolder
            readonly property real size: Math.min(168, stageArea.width * 0.42, stageArea.height * 0.62)
            width: size
            height: size
            anchors.centerIn: parent
            Accessible.role: Accessible.Graphic
            Accessible.name: start.connected ? qsTr("Bike found") : qsTr("Looking for your bike")

            // the bloom, then the breath inside it
            Item {
                id: bloomer
                anchors.fill: parent
                SequentialAnimation {
                    id: bloom
                    NumberAnimation { target: bloomer; property: "scale"; from: 0.86; to: 1.16; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                    NumberAnimation { target: bloomer; property: "scale"; to: 1; duration: Theme.slowSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.fastSpatialCurve }
                }

                Item {
                    id: breather
                    anchors.fill: parent
                    SequentialAnimation on scale {
                        running: !Theme.reduceMotion && start.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 1.035; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.035; to: 1; duration: 2000; easing.type: Easing.InOutSine }
                    }
                    Pulse {
                        anchors.fill: parent
                        zone: start.connected ? 2 : 1
                        color: start.tint
                        turning: true
                        turnTime: start.connected ? 60000 : 30000
                        Behavior on color {
                            enabled: !Theme.reduceMotion
                            ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                        }
                    }
                    YouIcon {
                        anchors.centerIn: parent
                        name: "check"
                        size: Math.round(pulseHolder.size * 0.34)
                        weight: 3.6
                        color: "#0d2420"
                        opacity: start.connected ? 1 : 0
                        scale: start.connected ? 1 : 0.6
                        Behavior on opacity {
                            enabled: !Theme.reduceMotion
                            NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                        }
                        Behavior on scale {
                            enabled: !Theme.reduceMotion
                            Spring { token: "fast"; epsilon: 0.002 }
                        }
                    }
                }
            }
        }
    }

    // the close button, top left
    PulseButton {
        x: start.margin + 8
        y: 16
        width: 44
        height: 44
        fill: Theme.control
        Accessible.name: qsTr("Close")
        onClicked: start.closeRequested()
        contentItem: Item {
            Icon { anchors.centerIn: parent; name: "close"; size: 20; color: Theme.text }
        }
    }

    Flickable {
        id: flick
        x: start.sideBySide ? stageArea.width : 0
        y: start.sideBySide ? 0 : stageArea.y + stageArea.height
        width: start.width - x
        height: start.height - y
        contentHeight: Math.max(height, words.y + words.height + actions.height + 56)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: words
            // on a phone the column runs along the left margin, on a wide window it centers
            width: Math.min(460, flick.width - (start.sideBySide ? 8 : start.margin + 8) - start.margin - 8)
            x: start.sideBySide ? 8 : Math.max(start.margin + 8, (flick.width - width) / 2)
            y: start.sideBySide ? 64 : 8
            spacing: 0

            Rise {
                order: 0
                width: parent.width
                Text {
                    width: parent.width
                    text: start.connected ? (start.rideInProgress ? qsTr("Your ride is waiting") : qsTr("Ready to ride"))
                                          : qsTr("Find your bike")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: start.sideBySide ? 28 : 30
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.1)
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
            }

            Item { width: 1; height: 12 }

            Rise {
                order: 1
                width: parent.width
                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        width: parent.width
                        text: start.connected ? (start.deviceName !== "" ? start.deviceName : qsTr("Your bike"))
                                              : qsTr("Looking nearby")
                        color: start.connected ? start.found : Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 17
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: start.connected ? qsTr("Found and connected")
                                              : start.searchStatus
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { width: 1; height: 18 }

            // what helps while it looks, on hairlines
            Rise {
                order: 2
                width: parent.width
                visible: !start.connected
                Column {
                    width: parent.width
                    Hairline { width: parent.width }
                    Repeater {
                        model: [
                            { glyph: "bike", line: qsTr("Wake the bike by pedaling a few turns.") },
                            { glyph: "info", line: qsTr("Close the Echelon app first. It can hold on to the bike.") }
                        ]
                        Item {
                            width: parent.width
                            height: Math.max(56, tipText.implicitHeight + 24)
                            Rectangle {
                                id: tipBadge
                                width: 36
                                height: 36
                                radius: 18
                                color: Theme.control
                                anchors.verticalCenter: parent.verticalCenter
                                YouIcon {
                                    anchors.centerIn: parent
                                    name: modelData.glyph
                                    size: 18
                                    weight: 1.8
                                    color: Theme.text2
                                }
                            }
                            Text {
                                id: tipText
                                x: tipBadge.width + 14
                                width: parent.width - x
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.line
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: 14
                                lineHeightMode: Text.FixedHeight
                                lineHeight: Math.round(font.pixelSize * 1.45)
                                wrapMode: Text.WordWrap
                            }
                            Hairline {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                visible: index === 0
                            }
                        }
                    }
                }
            }
        }

        // the way in: Start ride when the bike is there, else search again; a demo either way
        Rise {
            id: actions
            order: 3
            x: words.x
            width: words.width
            y: Math.max(words.y + words.height + 20, flick.height - height - 24)

            // side by side in landscape, the demo under the pill on a phone
            Grid {
                width: parent.width
                columns: start.sideBySide ? 2 : 1
                columnSpacing: 8
                rowSpacing: 6
                verticalItemAlignment: Grid.AlignVCenter
                horizontalItemAlignment: Grid.AlignHCenter
                PulseButton {
                    width: start.sideBySide ? parent.width - demoButton.width - 8 : parent.width
                    height: start.sideBySide ? 56 : 64
                    fill: start.connected ? Theme.accent : Theme.chip
                    pressedRadius: 22
                    Accessible.name: primaryLabel.text
                    onClicked: start.connected ? start.openRide() : start.searchAgain()
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Icon {
                                visible: start.connected
                                anchors.verticalCenter: parent.verticalCenter
                                name: "play"
                                size: 18
                                color: Theme.accentInk
                            }
                            Text {
                                id: primaryLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: start.connected ? (start.rideInProgress ? qsTr("Back to the ride") : qsTr("Start ride")) : qsTr("Search again")
                                color: start.connected ? Theme.accentInk : Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: 18
                            }
                        }
                    }
                }
                PulseButton {
                    id: demoButton
                    width: demoRow.implicitWidth + 32
                    height: 48
                    fill: pressed ? Theme.pressed : "transparent"
                    Accessible.name: qsTr("Try a demo ride, no bike needed")
                    onClicked: start.openDemo()
                    contentItem: Item {
                        Row {
                            id: demoRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: qsTr("Try a demo ride")
                                color: Theme.accent
                                font.family: Theme.bodySemibold
                                font.pixelSize: 14
                            }
                            Text {
                                text: qsTr("no bike needed")
                                color: Theme.text3
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.tertiarySize
                            }
                        }
                    }
                }
            }
        }
    }
}
