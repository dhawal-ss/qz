import QtQuick 2.15
import "."
import "sig"
import "you"

// Before the ride: is the bike there, and a way into the ride or a demo. Opened by the Ride
// button when the bike is not connected yet.
// While it searches, a calm Pulse in the accent breathes and turns slowly; when the bike is
// found it blooms (a springy swell) into the Endurance zone color, zoneColors[1], and the
// Start ride pill takes over. On a landscape phone the Pulse sits left of the words.
// There is always a next step: what keeps the search from working (Bluetooth off, Nearby devices
// not allowed, Location off) with the button that fixes it, tips for the bike, and after 40 s
// "Can't find it?" with the devices nearby to pick from (the switch needs no restart).
Item {
    id: start

    property bool connected: false
    property string deviceName: ""
    property string searchStatus: ""
    property bool rideInProgress: false
    // rootItem.connectionProblem(): "permission", "bluetooth", "location" or ""
    property string problem: ""
    // the devices the search has seen, by name, and the bike Bikemodo waits for ("Disabled" for any)
    property var devices: []
    property string chosen: "Disabled"
    // the bike of the last connection, for tips about its brand
    property string lastDevice: ""
    // step 2 of the first run: Next once the bike is there, Skip for now in place of the demo,
    // and the back arrow
    property bool setup: false

    signal openRide()
    signal openDemo()
    signal searchAgain()
    signal closeRequested()
    signal fixProblem()
    signal chooseBike(string name)

    readonly property bool blocked: problem !== "" && !connected
    // the bike the tips are about: the one Bikemodo waits for, else the last one
    readonly property string brandName: (chosen !== "Disabled" ? chosen : lastDevice).toLowerCase()
    readonly property bool echelon: brandName.indexOf("ech") === 0
    // 40 s of looking without a bike: "Can't find it?" and the devices nearby
    property bool slow: false
    // the devices in the order they were first seen, so a row never moves under the finger as
    // the search finds more (QZ sorts them by signal strength, which changes all the time)
    property var seenOrder: []
    onDevicesChanged: {
        var order = seenOrder.slice()
        for (var i = 0; i < devices.length; i++) {
            if (order.indexOf(devices[i]) < 0)
                order.push(devices[i])
        }
        if (order.length !== seenOrder.length)
            seenOrder = order
    }
    readonly property var nearby: {
        var list = []
        for (var i = 0; i < seenOrder.length && list.length < 6; i++) {
            if (seenOrder[i] !== chosen && devices.indexOf(seenOrder[i]) >= 0)
                list.push(seenOrder[i])
        }
        return list
    }
    readonly property var tips: {
        var t = [{ glyph: "bike", line: qsTr("Wake the bike by pedaling a few turns.") }]
        if (echelon)
            t.push({ glyph: "info", line: qsTr("Close the Echelon app first. It can hold on to the bike.") })
        else
            t.push({ glyph: "info", line: qsTr("Close other fitness apps. Most bikes talk to one app at a time.") })
        if (slow)
            t.push({ glyph: "info", line: echelon ? qsTr("Still nothing? Unplug the bike for 10 seconds, plug it back in, then pedal.")
                                                  : qsTr("Still nothing? Switch the bike off and on, then pedal.") })
        return t
    }

    Timer {
        interval: 40000
        running: start.visible && !start.connected && !start.blocked && !start.slow
        onTriggered: start.slow = true
    }
    onVisibleChanged: if (!visible) slow = false

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
            high: start.connected ? 0.42 : (start.blocked ? 0.16 : 0.3)
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
            Accessible.name: start.connected ? qsTr("Bike found") : (start.blocked ? titleText.text : qsTr("Looking for your bike"))

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
                        running: !Theme.reduceMotion && start.visible && !start.blocked
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 1.035; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.035; to: 1; duration: 2000; easing.type: Easing.InOutSine }
                    }
                    Pulse {
                        anchors.fill: parent
                        zone: start.connected ? 2 : 1
                        color: start.tint
                        turning: !start.blocked
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
        Accessible.name: start.setup ? qsTr("Back") : qsTr("Close")
        onClicked: start.closeRequested()
        contentItem: Item {
            Icon { anchors.centerIn: parent; name: start.setup ? "back" : "close"; size: 20; color: Theme.text }
        }
    }
    Text {
        visible: start.setup
        x: start.margin + 8 + 44 + 14
        y: 16 + (44 - height) / 2
        text: qsTr("2 of 4")
        color: Theme.text
        font.family: Theme.bodyMedium
        font.pixelSize: 14
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
                    id: titleText
                    width: parent.width
                    text: start.connected ? (start.setup ? qsTr("Found your bike") : start.rideInProgress ? qsTr("Your ride is waiting") : qsTr("Ready to ride"))
                        : start.problem === "bluetooth" ? qsTr("Bluetooth is off")
                        : start.problem === "permission" ? qsTr("Allow Bikemodo to find your bike")
                        : start.problem === "location" ? qsTr("Location is off")
                        : start.rideInProgress ? qsTr("Finding your bike again")
                        : start.slow ? qsTr("Can't find it?") : qsTr("Find your bike")
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
                        visible: !start.blocked
                        text: start.connected ? (start.deviceName !== "" ? start.deviceName : qsTr("Your bike"))
                                              : start.chosen !== "Disabled" ? qsTr("Looking for %1").arg(start.chosen)
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
                            : start.problem === "bluetooth" ? qsTr("Bikemodo talks to your bike over Bluetooth. Turn it on and the search starts by itself.")
                            : start.problem === "permission" ? qsTr("Android asks first: Bikemodo needs Nearby devices to look for the bike, and uses it for nothing else.")
                            : start.problem === "location" ? qsTr("This version of Android needs Location on to find Bluetooth devices. Bikemodo does not use where you are.")
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
                visible: !start.connected && !start.blocked
                Column {
                    width: parent.width
                    Hairline { width: parent.width }
                    Repeater {
                        model: start.tips
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
                                visible: index < start.tips.length - 1
                            }
                        }
                    }
                }
            }

            // Can't find it? The devices the search saw, to pick the bike from; the switch needs no restart
            Rise {
                order: 3
                width: parent.width
                visible: start.slow && !start.connected && !start.blocked && !start.rideInProgress
                         && (start.nearby.length > 0 || start.chosen !== "Disabled")
                Column {
                    width: parent.width
                    Item { width: 1; height: 18 }
                    Text {
                        width: parent.width
                        text: start.chosen !== "Disabled" ? qsTr("Bikemodo waits for %1 only. Is your bike one of these?").arg(start.chosen)
                                                          : qsTr("Is your bike one of these?")
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        bottomPadding: 6
                    }
                    // first, so it stays put while the devices below come and go
                    YouRow {
                        visible: start.chosen !== "Disabled"
                        title: qsTr("Any bike Bikemodo recognizes")
                        glyph: "bike"
                        iconColor: Theme.text2
                        hairline: start.nearby.length > 0
                        onClicked: start.chooseBike("Disabled")
                    }
                    Repeater {
                        model: start.nearby
                        YouRow {
                            title: modelData
                            glyph: "bike"
                            iconColor: Theme.text2
                            hairline: index < start.nearby.length - 1
                            Accessible.name: qsTr("Connect to %1").arg(modelData)
                            onClicked: start.chooseBike(modelData)
                        }
                    }
                }
            }
        }

        // the way in: Start ride when the bike is there, else search again; a demo either way
        Rise {
            id: actions
            order: 4
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
                    fill: start.connected || start.blocked ? Theme.accent : Theme.chip
                    pressedRadius: 22
                    Accessible.name: primaryLabel.text
                    onClicked: start.connected ? start.openRide() : start.blocked ? start.fixProblem() : start.searchAgain()
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Icon {
                                visible: start.connected && !start.setup
                                anchors.verticalCenter: parent.verticalCenter
                                name: "play"
                                size: 18
                                color: Theme.accentInk
                            }
                            Text {
                                id: primaryLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: start.connected ? (start.setup ? qsTr("Next") : start.rideInProgress ? qsTr("Back to the ride") : qsTr("Start ride"))
                                    : start.problem === "bluetooth" ? qsTr("Turn on Bluetooth")
                                    : start.problem === "permission" ? qsTr("Allow Nearby devices")
                                    : start.problem === "location" ? qsTr("Turn on Location")
                                    : qsTr("Search again")
                                color: start.connected || start.blocked ? Theme.accentInk : Theme.text
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
                    Accessible.name: start.setup ? qsTr("Skip for now") : qsTr("Try a demo ride, no bike needed")
                    onClicked: start.openDemo()
                    contentItem: Item {
                        Row {
                            id: demoRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: start.setup ? qsTr("Skip for now") : qsTr("Try a demo ride")
                                color: Theme.accent
                                font.family: Theme.bodySemibold
                                font.pixelSize: 14
                            }
                            Text {
                                visible: !start.setup
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
