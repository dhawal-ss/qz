import QtQuick 2.15
import QtQuick.Shapes 1.15
import Qt.labs.settings 1.0
import ".."
import "../sig"

// Heart rate, as the heart wizard board draws it, in three steps: what you wear (tiles), how to
// start sharing from it with the device to pick once it shows up (the one raised card waits for
// it), and a live check with the beating heart and the number. The source is QZ's
// heart_rate_belt_name, written and connected at once as before; what you wear is remembered by
// Bikemodo only (ui2 settings).
YouPage {
    id: page

    readonly property var qz: you.qz
    readonly property string chosen: qz.heart_rate_belt_name
    // the chosen belt stays in the list even when the last search did not see it
    readonly property var names: {
        var list = you.devices.slice()
        var bike = you.deviceName
        if (bike !== "" && list.indexOf(bike) >= 0)
            list.splice(list.indexOf(bike), 1)
        if (chosen !== "Disabled" && list.indexOf(chosen) < 0)
            list.unshift(chosen)
        return list
    }

    // what you wear, and the guide to start sharing from it
    readonly property var wearables: [
        { id: "fitbit", name: qsTr("Fitbit Air or Charge 6"), glyph: "band", chip: qsTr("Wrist, a few seconds behind"), note: "",
          title: qsTr("Start sharing from Google Health"), lead: qsTr("Your Fitbit sends heart rate to Bikemodo once sharing is on."),
          steps: [qsTr("Open Google Health"), qsTr("Connections, then your Fitbit"), qsTr("Tap Share heart rate")] },
        { id: "pixel", name: qsTr("Pixel Watch"), glyph: "watch", chip: qsTr("Wrist, a few seconds behind"), note: "",
          title: qsTr("Start sharing from Google Health"), lead: qsTr("Your Pixel Watch sends heart rate to Bikemodo once sharing is on."),
          steps: [qsTr("Open Google Health"), qsTr("Connections, then your Pixel Watch"), qsTr("Tap Share heart rate")] },
        { id: "garmin", name: qsTr("Garmin watch"), glyph: "watch", chip: qsTr("Wrist, a few seconds behind"), note: "",
          title: qsTr("Broadcast from your Garmin"), lead: qsTr("Garmin watches send heart rate to any app while they broadcast."),
          steps: [qsTr("Open the controls menu on the watch"), qsTr("Tap Broadcast heart rate"), qsTr("Leave it on while you ride")] },
        { id: "galaxy", name: qsTr("Galaxy Watch"), glyph: "watch", chip: qsTr("Wrist, a few seconds behind"), note: qsTr("Needs the QZ watch app"),
          title: qsTr("Add the QZ watch app"), lead: qsTr("A Galaxy Watch sends heart rate through the QZ app on the watch."),
          steps: [qsTr("Install QZ on the watch"), qsTr("Open it before you ride"), qsTr("Keep it open while you ride")] },
        { id: "strap", name: qsTr("Chest strap"), glyph: "strap", chip: qsTr("Best for intervals"), note: "",
          title: qsTr("Wake your strap"), lead: qsTr("A chest strap follows your heart without delay."),
          steps: [qsTr("Wet the pads and put it on"), qsTr("It wakes when it feels your heart"), qsTr("Pick it below when it shows up")] },
        { id: "none", name: qsTr("Nothing for now"), glyph: "none", chip: "", note: qsTr("Ride by power and feel"),
          title: "", lead: "", steps: [] }
    ]

    // Bikemodo's own memory of what you wear
    Settings {
        id: heartPrefs
        category: "ui2"
        property string heartWearable: ""
    }

    property string wearable: heartPrefs.heartWearable
    readonly property var worn: {
        for (var i = 0; i < wearables.length; i++) {
            if (wearables[i].id === wearable)
                return wearables[i]
        }
        return wearables[4]
    }
    readonly property bool wrist: worn.id !== "strap"

    // 0 what you wear, 1 start sharing, 2 the live check
    property int step: chosen !== "Disabled" ? 2 : 0

    stepCount: 3
    stepIndex: step
    canStepBack: step > 0
    onStepBack: step = step - 1

    title: step === 0 ? qsTr("What do you wear?")
           : (step === 1 ? worn.title : (you.heartRate > 0 ? qsTr("That's your heart.") : qsTr("Listening for your heart")))
    lead: step === 0 ? qsTr("Pick what you ride with most. You can change it any time.")
          : (step === 1 ? worn.lead : "")

    function choose(name) {
        if (name === chosen)
            return
        qz.heart_rate_belt_name = name
        qz.setValue("heart_rate_belt_name", name)
        // a belt connects right away, going back to none is read at the next start
        if (name === "Disabled")
            you.needRestart()
        else if (you.core !== null)
            you.core.reconnectHeartRateBelt(name)
    }

    function pickWearable(id) {
        wearable = id
        heartPrefs.heartWearable = id
    }

    // step 1: what do you wear
    Item {
        visible: page.step === 0
        width: parent.width
        height: visible ? tiles.height + 8 : 0
        Grid {
            id: tiles
            x: 12
            width: parent.width - 24
            columns: width >= 560 ? 3 : 2
            spacing: 12
            Repeater {
                model: page.wearables
                delegate: PulseButton {
                    id: tile
                    readonly property bool on: page.wearable === modelData.id
                    width: (tiles.width - (tiles.columns - 1) * 12) / tiles.columns
                    // tall enough for a long name over the chip on a narrow phone
                    height: Math.max(168, tileName.y + tileName.implicitHeight + 12 + tileFoot.implicitHeight + 14)
                    radius: 24
                    pressedRadius: 28
                    pressedScale: 0.97
                    fill: on ? Qt.rgba(201 / 255, 184 / 255, 1, 0.09) : Theme.card
                    Accessible.name: modelData.name + (modelData.chip !== "" ? ", " + modelData.chip : "") + (modelData.note !== "" ? ", " + modelData.note : "")
                    Accessible.checkable: true
                    Accessible.checked: on
                    onClicked: page.pickWearable(modelData.id)

                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        color: "transparent"
                        border.width: tile.on ? 2 : 1
                        border.color: tile.on ? Theme.accent : Theme.raisedBorder
                    }
                    Rectangle {
                        visible: tile.on
                        x: parent.width - width - 12
                        y: 12
                        width: 24
                        height: 24
                        radius: 12
                        color: Theme.accent
                        YouIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 14
                            weight: 3
                            color: Theme.accentInk
                        }
                    }
                    YouIcon {
                        x: 14
                        y: 14
                        name: modelData.glyph
                        size: 26
                        weight: 1.8
                        color: tile.on ? Theme.accent : (modelData.id === "none" ? Theme.text2 : Theme.text)
                    }
                    Text {
                        id: tileName
                        x: 14
                        y: 52
                        width: parent.width - 28 - (tile.on ? 18 : 0)
                        text: modelData.name
                        color: modelData.id === "none" ? Theme.text2 : Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                        lineHeight: 1.05
                        wrapMode: Text.WordWrap
                    }
                    Column {
                        id: tileFoot
                        x: 14
                        width: parent.width - 28
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        spacing: 6
                        Rectangle {
                            visible: modelData.chip !== ""
                            width: Math.min(parent.width, chipLabel.implicitWidth + 18)
                            height: chipLabel.implicitHeight + 10
                            radius: 10
                            color: tile.on ? Qt.rgba(201 / 255, 184 / 255, 1, 0.14) : Theme.pressed
                            Text {
                                id: chipLabel
                                x: 9
                                y: 5
                                width: parent.width - 18
                                text: modelData.chip
                                color: modelData.id === "strap" ? Theme.accent : (tile.on ? Theme.text : Theme.text2)
                                font.family: Theme.bodySemibold
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                        Text {
                            visible: modelData.note !== ""
                            width: parent.width
                            text: modelData.note
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Item {
        visible: page.step === 0
        width: parent.width
        height: visible ? continueButton.height + 28 : 0
        YouButton {
            id: continueButton
            x: 12
            y: 16
            width: parent.width - 24
            height: 60
            primary: true
            enabled: page.wearable !== ""
            text: page.wearable === "none" ? qsTr("Use the bike's own heart rate") : qsTr("Continue")
            onClicked: {
                if (page.wearable === "none") {
                    page.choose("Disabled")
                    page.step = 2
                } else {
                    page.step = 1
                }
            }
        }
    }

    // step 2: start sharing, then pick it when it shows up
    Repeater {
        model: page.step === 1 ? page.worn.steps : []
        delegate: Item {
            width: parent.width
            height: 60
            Rectangle {
                id: stepNumber
                x: 12
                width: 32
                height: 32
                radius: 16
                color: Theme.pressed
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: index + 1
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 15
                }
            }
            Text {
                x: stepNumber.x + stepNumber.width + 14
                width: parent.width - x - 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }
            Rectangle {
                visible: index < 2
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
                height: 1
                color: Theme.hairline
            }
        }
    }

    Item {
        visible: page.step === 1
        width: 1
        height: visible ? 16 : 0
    }

    // the one raised card: waiting for the band, the ring turning while it looks
    Item {
        visible: page.step === 1
        width: parent.width
        height: visible ? waiting.height + 8 : 0
        Rectangle {
            id: waiting
            x: 12
            width: parent.width - 24
            height: waitingColumn.height + 48
            radius: Theme.heroRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.raisedBorder
            Column {
                id: waitingColumn
                y: 24
                width: parent.width
                spacing: 6
                Item {
                    width: 116
                    height: 116
                    anchors.horizontalCenter: parent.horizontalCenter
                    Accessible.role: Accessible.Graphic
                    Accessible.name: qsTr("Looking for your heart rate")
                    Rectangle {
                        id: halo
                        anchors.centerIn: parent
                        width: 104
                        height: 104
                        radius: 52
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(201 / 255, 184 / 255, 1, 0.18)
                        SequentialAnimation on scale {
                            running: !Theme.reduceMotion && page.visible && page.step === 1
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.92; to: 1; duration: 2000; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.92; duration: 2000; easing.type: Easing.InOutSine }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 82
                        height: 82
                        radius: 41
                        color: "transparent"
                        border.width: 6
                        border.color: Theme.hairline
                    }
                    Shape {
                        anchors.centerIn: parent
                        width: 82
                        height: 82
                        layer.enabled: true
                        layer.samples: 4
                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 2800
                            loops: Animation.Infinite
                            running: !Theme.reduceMotion && page.visible && page.step === 1
                        }
                        ShapePath {
                            strokeColor: Theme.accent
                            strokeWidth: 6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 41
                                centerY: 41
                                radiusX: 38
                                radiusY: 38
                                startAngle: -90
                                sweepAngle: 80
                            }
                        }
                    }
                    YouIcon {
                        anchors.centerIn: parent
                        name: page.worn.glyph
                        size: 26
                        weight: 1.8
                        color: Theme.text
                    }
                }
                Item {
                    width: 1
                    height: 10
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: page.wrist ? qsTr("Waiting for your band") : qsTr("Waiting for your strap")
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 18
                }
                Text {
                    width: parent.width
                    leftPadding: 20
                    rightPadding: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Pick it below as soon as it shows up.")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    YouText {
        visible: page.step === 1
        kind: "heading"
        text: qsTr("Seen nearby")
    }

    Repeater {
        model: page.step === 1 ? page.names : []
        delegate: YouRow {
            title: modelData
            trailing: "check"
            selected: page.chosen === modelData
            hairline: index < page.names.length - 1
            onClicked: {
                page.choose(modelData)
                page.step = 2
            }
        }
    }

    YouText {
        visible: page.step === 1 && page.names.length === 0
        text: qsTr("Nothing seen yet. Start sharing, then look again.")
    }

    Item {
        visible: page.step === 1
        width: parent.width
        height: visible ? lookButton.height + 20 : 0
        YouButton {
            id: lookButton
            x: 12
            y: 12
            text: qsTr("Look for nearby devices")
            onClicked: you.refreshDevicesRequested()
        }
    }

    YouRow {
        visible: page.step === 1 && page.wrist
        glyph: "info"
        iconColor: Theme.text2
        title: qsTr("Connected but no numbers?")
        detail: qsTr("Sharing turns itself off after a while. Start it again.")
        trailing: ""
        hairline: false
        enabled: false
    }

    // step 3: the live check
    Item {
        visible: page.step === 2
        width: parent.width
        height: visible ? check.height + 12 : 0
        Accessible.role: Accessible.StaticText
        Accessible.name: you.heartRate > 0 ? qsTr("%1 beats per minute").arg(Math.round(you.heartRate)) : qsTr("No heart rate yet")

        Column {
            id: check
            width: parent.width
            spacing: 0
            Item {
                width: parent.width
                height: 128
                Shape {
                    id: beat
                    width: 24
                    height: 24
                    anchors.centerIn: parent
                    scale: 4.4
                    layer.enabled: true
                    layer.samples: 4
                    layer.textureSize: Qt.size(112, 112)
                    opacity: you.heartRate > 0 ? 1 : 0.4
                    ShapePath {
                        strokeWidth: -1
                        fillColor: Theme.zoneColors[5]
                        PathSvg { path: "M12 20C5 15 3 12 3 8.5A4.5 4.5 0 0 1 12 6A4.5 4.5 0 0 1 21 8.5C21 12 19 15 12 20Z" }
                    }
                    // a heartbeat, at the rate of the heart
                    SequentialAnimation on scale {
                        running: !Theme.reduceMotion && page.visible && page.step === 2 && you.heartRate > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 4.8; duration: page.beatTime * 0.14; easing.type: Easing.OutQuad }
                        NumberAnimation { to: 4.4; duration: page.beatTime * 0.14; easing.type: Easing.InQuad }
                        NumberAnimation { to: 4.6; duration: page.beatTime * 0.14; easing.type: Easing.OutQuad }
                        NumberAnimation { to: 4.4; duration: page.beatTime * 0.14; easing.type: Easing.InQuad }
                        PauseAnimation { duration: page.beatTime * 0.44 }
                    }
                }
            }
            Item {
                width: 1
                height: 8
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Numeral {
                    id: bpm
                    text: you.heartRate > 0 ? String(Math.round(you.heartRate)) : "--"
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 112
                }
                Text {
                    anchors.baseline: bpm.baseline
                    text: qsTr("bpm")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 20
                }
            }
            Item {
                width: 1
                height: 20
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                YouIcon {
                    visible: page.chosen !== "Disabled"
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    size: 18
                    weight: 2.4
                    color: Theme.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.chosen === "Disabled" ? qsTr("From the bike") : qsTr("%1 picked").arg(page.chosen)
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 17
                }
                Text {
                    visible: page.chosen !== "Disabled" && page.wearable !== "" && page.wearable !== "none"
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.wrist ? qsTr("wrist") : qsTr("chest")
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 12
                }
            }
            Text {
                width: parent.width
                topPadding: 10
                leftPadding: 24
                rightPadding: 24
                horizontalAlignment: Text.AlignHCenter
                text: page.chosen === "Disabled" ? qsTr("Bikes with grips or a belt of their own send it.")
                      : (page.wrist ? qsTr("Move your arm. If the number changes, it's you.") : qsTr("Breathe in deep. If the number moves, it's you."))
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 14
                lineHeightMode: Text.FixedHeight
                lineHeight: Math.round(font.pixelSize * 1.45)
                wrapMode: Text.WordWrap
            }
        }
    }

    YouText {
        visible: page.step === 2
        kind: "heading"
        text: qsTr("Heart rate source")
    }

    YouSwitch {
        visible: page.step === 2
        title: qsTr("Ignore the bike's heart rate")
        detail: qsTr("Use only the belt or watch, even when the bike sends a heart rate of its own.")
        isOn: page.qz.heart_ignore_builtin
        onSwitched: page.qz.heart_ignore_builtin = value
    }

    YouRow {
        visible: page.step === 2
        title: qsTr("Pick another source")
        detail: qsTr("A different watch, band or strap")
        trailing: "next"
        hairline: false
        onClicked: page.step = 0
    }

    // how long one beat lasts, for the heart
    readonly property int beatTime: Math.round(60000 / Math.max(40, Math.min(200, you.heartRate > 0 ? you.heartRate : 60)))
}
