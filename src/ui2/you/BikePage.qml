import QtQuick 2.15
import ".."
import "../sig"

// The bike, as the first run board draws it: the Pulse looking nearby (it breathes while it
// searches and turns the Endurance color with a check once the bike is there), which bike to
// connect to as pick rows, the tips that help, and the Echelon firmware note with its one raised
// card: keep auto-update off. How watts are worked out lives on Power.
YouPage {
    id: page

    title: you.connected ? qsTr("Your bike") : qsTr("Find your bike")

    readonly property var qz: you.qz
    readonly property string chosen: qz.filter_device
    // the chosen bike stays in the list even when the last search did not see it
    readonly property var names: {
        var list = you.devices.slice()
        if (chosen !== "Disabled" && list.indexOf(chosen) < 0)
            list.unshift(chosen)
        return list
    }
    readonly property string searchStatus: you.connected ? "" : you.ask("bluetoothSearchStatus", "")
    // Bluetooth off, Nearby devices not allowed or Location off: the button fixes it first
    readonly property string problem: you.connected ? "" : you.ask("connectionProblem", "")
    readonly property color tint: you.connected ? Theme.zoneColors[1] : Theme.accent

    // a ride with time on it keeps its bike: the samples of another one would land in it
    readonly property bool rideOpen: {
        var fresh = you.tick
        return you.metrics !== null && you.metrics.elapsed > 0 && you.core !== null && !you.core.rideStopped()
    }
    property bool triedDuringRide: false

    function choose(name) {
        if (name === chosen)
            return
        if (rideOpen) {
            triedDuringRide = true
            return
        }
        qz.filter_device = name
        // switchBike() drops the bike and looks for the new one, no restart; QZ set to quit on a lost
        // connection takes one (then written at once, the restart may come right away)
        if (you.core !== null && you.core.switchBike(name))
            return
        qz.setValue("filter_device", name)
        you.needRestart()
    }

    // the Pulse: looking, or found
    Item {
        width: parent.width
        height: 196
        Accessible.role: Accessible.StaticText
        Accessible.name: lookingLabel.text + (statusLabel.text !== "" ? ", " + statusLabel.text : "")

        Item {
            id: look
            width: 104
            height: 104
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            HeroGlow {
                width: 300
                height: 300
                anchors.centerIn: parent
                tint: page.tint
                low: 0.14
                high: 0.24
            }
            Item {
                anchors.fill: parent
                SequentialAnimation on scale {
                    running: !Theme.reduceMotion && page.visible && !you.connected
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 1.04; duration: 2000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.04; to: 1; duration: 2000; easing.type: Easing.InOutSine }
                }
                Pulse {
                    anchors.fill: parent
                    zone: you.connected ? 2 : 1
                    color: page.tint
                    turning: true
                    turnTime: 30000
                    Behavior on color {
                        enabled: !Theme.reduceMotion
                        ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                    }
                }
                YouIcon {
                    visible: you.connected
                    anchors.centerIn: parent
                    name: "check"
                    size: 34
                    weight: 3.4
                    color: Theme.light ? Theme.zoneInk : "#0d2420"
                }
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: look.y + look.height + 18
            width: parent.width - 24
            spacing: 4
            Text {
                id: lookingLabel
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: you.connected ? (you.deviceName !== "" ? you.deviceName : qsTr("Connected")) : qsTr("Looking nearby")
                color: you.connected ? page.tint : Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(15)
                elide: Text.ElideRight
            }
            Text {
                id: statusLabel
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: you.connected ? qsTr("Connected")
                    : page.problem === "bluetooth" ? qsTr("Bluetooth is off")
                    : page.problem === "permission" ? qsTr("Bikemodo needs Nearby devices to look for the bike")
                    : page.problem === "location" ? qsTr("This version of Android needs Location on to find the bike")
                    : page.searchStatus
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                wrapMode: Text.WordWrap
            }
        }
    }

    Item {
        visible: !you.connected
        width: parent.width
        height: searchButton.height + 8
        YouButton {
            id: searchButton
            x: 12
            width: parent.width - 24
            primary: true
            text: page.problem === "bluetooth" ? qsTr("Turn on Bluetooth")
                : page.problem === "permission" ? qsTr("Allow Nearby devices")
                : page.problem === "location" ? qsTr("Turn on Location")
                : qsTr("Search again")
            onClicked: {
                if (you.core === null)
                    return
                if (page.problem !== "")
                    you.core.fixConnectionProblem()
                else
                    you.core.bluetoothSearchNow()
            }
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Which bike to connect")
    }
    YouText {
        topPadding: 0
        text: qsTr("Bikemodo connects to the first bike it recognizes. Pick yours to connect to that one only, useful with other bikes or sensors nearby.")
    }

    YouText {
        visible: page.triedDuringRide && page.rideOpen
        topPadding: 0
        color: Theme.accent
        text: qsTr("End the ride first. The bike changes once it is saved.")
    }

    YouRow {
        title: qsTr("Any bike Bikemodo recognizes")
        trailing: "check"
        selected: page.chosen === "Disabled"
        onClicked: page.choose("Disabled")
    }

    Repeater {
        model: page.names
        delegate: YouRow {
            title: modelData
            detail: modelData === you.deviceName && you.connected ? qsTr("Connected now") : ""
            trailing: "check"
            selected: page.chosen === modelData
            hairline: index < page.names.length - 1
            onClicked: page.choose(modelData)
        }
    }

    YouText {
        visible: page.names.length === 0
        text: qsTr("No other devices seen yet. Look for nearby devices, with the bike awake.")
    }

    Item {
        width: parent.width
        height: lookButton.height + 20
        YouButton {
            id: lookButton
            x: 12
            y: 12
            text: qsTr("Look for nearby devices")
            onClicked: you.refreshDevicesRequested()
        }
    }

    YouText {
        visible: page.chosen !== "Disabled"
        text: qsTr("Bikemodo waits for %1 and ignores other bikes. Pick \"Any bike\" to go back.").arg(page.chosen)
    }

    YouText {
        kind: "heading"
        text: qsTr("If it does not connect")
    }

    Repeater {
        model: [
            { glyph: "info", line: qsTr("Close the Echelon app first. It can hold on to the bike.") },
            { glyph: "bike", line: qsTr("Pedal a few turns to wake the bike, then search again.") }
        ]
        delegate: Item {
            width: parent.width
            height: Math.max(60, tipText.implicitHeight + 26)
            Rectangle {
                id: tipBadge
                x: 12
                width: 40
                height: 40
                radius: 20
                color: Theme.control
                anchors.verticalCenter: parent.verticalCenter
                YouIcon {
                    anchors.centerIn: parent
                    name: modelData.glyph
                    size: 20
                    weight: 1.8
                    color: Theme.text2
                }
            }
            Text {
                id: tipText
                x: tipBadge.x + tipBadge.width + 14
                width: parent.width - x - 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.line
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(15)
                lineHeightMode: Text.FixedHeight
                lineHeight: Math.round(font.pixelSize * 1.45)
                wrapMode: Text.WordWrap
            }
            Rectangle {
                visible: index === 0
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
                height: 1
                color: Theme.hairline
            }
        }
    }

    // the firmware note: Bikemodo cannot tell which firmware a bike runs, so it is a condition
    YouText {
        kind: "heading"
        text: qsTr("Echelon firmware")
    }

    Item {
        width: parent.width
        height: firmware.height + 8
        Column {
            id: firmware
            x: 12
            width: parent.width - 24
            spacing: 12
            Rectangle {
                width: 48
                height: 48
                radius: 24
                color: Theme.control
                YouIcon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: 22
                    weight: 1.8
                    color: Theme.accent
                }
            }
            Text {
                width: parent.width
                text: qsTr("Some Echelon firmware blocks other apps.")
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: Theme.fs(24)
                lineHeightMode: Text.FixedHeight
                lineHeight: 27
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }
            Text {
                width: parent.width
                text: qsTr("An Echelon update from July 2025 makes the bike check with Echelon's servers before it talks to any other app. If your bike stopped connecting after an update, that is likely why. It isn't something you did.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(14)
                lineHeightMode: Text.FixedHeight
                lineHeight: Math.round(font.pixelSize * 1.45)
                wrapMode: Text.WordWrap
            }
        }
    }

    Item {
        width: 1
        height: 8
    }

    // the one raised card of the page
    Item {
        width: parent.width
        height: advice.height + 8
        Rectangle {
            id: advice
            x: 12
            width: parent.width - 24
            height: Math.max(84, adviceText.implicitHeight + 36)
            radius: 28
            color: Theme.card
            border.width: 1
            border.color: Theme.raisedBorder
            YouIcon {
                id: adviceIcon
                x: 18
                y: 18
                name: "shield"
                size: 22
                weight: 1.8
                color: Theme.accent
            }
            Column {
                id: adviceText
                x: adviceIcon.x + adviceIcon.width + 14
                y: 18
                width: parent.width - x - 18
                spacing: 4
                Text {
                    width: parent.width
                    text: qsTr("Keep auto-update off")
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(15)
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: qsTr("If your Echelon still connects, turn off automatic firmware updates in the Echelon app to keep it open to Bikemodo.")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(13)
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.45)
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
