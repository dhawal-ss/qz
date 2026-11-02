import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "Metrics.js" as Metrics

// The live ride. One big number, four quiet rows, the level dock and the ride ribbon.
// The screen takes one color, from the current zone. Every number can be swapped, restyled
// or removed mid-ride from a side sheet, with undo.
Item {
    id: screen

    // a LiveSource or a RideSim
    property var source

    property string preset: "power"
    property var slots: Metrics.presetSlots("power")
    property int editing: -1
    property bool locked: false
    property bool touched: false
    property var undoState: null
    property string toastText: ""

    signal finishRequested()

    // stopped: the ride was finished and the next tap on Start begins a new one
    readonly property bool stopped: source.stopped === true
    readonly property bool idle: source.paused || stopped

    readonly property bool heartDriven: preset === "heart" && source.heartRate > 0
    readonly property int zone: heartDriven ? Theme.heartZone(source.heartRate, source.maxHeartRate)
                                            : Theme.powerZone(source.power, source.ftp)
    readonly property color tint: Theme.zoneColors[zone - 1]
    readonly property int pulseZone: heartDriven ? Math.min(7, Math.round(1 + (zone - 1) * 1.5)) : zone
    readonly property var hero: Metrics.info(slots[0].m, source)

    // the layout survives restarts
    Settings {
        id: saved
        category: "ui2"
        property string rideLayout: ""
        property string ridePreset: "power"
    }

    Component.onCompleted: {
        preset = saved.ridePreset
        slots = Metrics.parseLayout(saved.rideLayout, preset === "custom" ? "power" : preset)
    }

    function presetSlotsFor(id) {
        return Metrics.presetSlots(id)
    }

    function store() {
        saved.ridePreset = preset
        saved.rideLayout = JSON.stringify(slots)
    }

    function remember(message) {
        undoState = { slots: Metrics.copySlots(slots), preset: preset, message: message }
        toastText = ""
        undoTimer.restart()
    }

    function edit(index) {
        touched = true
        if (locked) {
            toast(qsTr("Locked. Tap the lock to make changes."))
            return
        }
        toastText = ""
        editing = index
    }

    function toast(text) {
        toastText = text
        toastTimer.restart()
    }

    function labelOf(id) {
        return id === "empty" ? qsTr("Empty space") : Metrics.info(id, source).label
    }

    function setStyle(style) {
        var cur = slots[editing]
        if (cur.st === style)
            return
        remember(qsTr("%1 now shows as %2").arg(labelOf(cur.m)).arg(style === "number" ? qsTr("number") : (style === "trend" ? qsTr("trend") : qsTr("bar"))))
        var next = Metrics.copySlots(slots)
        next[editing].st = style
        slots = next
        preset = "custom"
        store()
    }

    function setMetric(id) {
        var cur = slots[editing]
        var before = labelOf(cur.m)
        var after = labelOf(id)
        var next = Metrics.copySlots(slots)
        var where = -1
        for (var k = 0; k < next.length; k++) {
            if (k !== editing && next[k].m === id)
                where = k
        }
        if (where >= 0) {
            remember(qsTr("%1 and %2 traded places").arg(before).arg(after))
            var held = next[where]
            next[where] = next[editing]
            next[editing] = held
        } else {
            remember(cur.m === "empty" ? qsTr("%1 added").arg(after) : qsTr("%1 swapped for %2").arg(before).arg(after))
            next[editing] = { m: id, st: cur.m === "empty" ? "number" : cur.st }
        }
        slots = next
        preset = "custom"
        editing = -1
        store()
    }

    function removeMetric() {
        remember(qsTr("%1 removed").arg(labelOf(slots[editing].m)))
        var next = Metrics.copySlots(slots)
        next[editing] = { m: "empty", st: "number" }
        slots = next
        preset = "custom"
        editing = -1
        store()
    }

    function cyclePreset() {
        touched = true
        if (locked) {
            toast(qsTr("Locked. Tap the lock to make changes."))
            return
        }
        var i = Metrics.presetOrder.indexOf(preset)
        var next = Metrics.presetOrder[(i + 1) % Metrics.presetOrder.length]
        remember(qsTr("Switched to the %1 layout").arg(Metrics.presetName(next)))
        preset = next
        slots = Metrics.presetSlots(next)
        editing = -1
        store()
    }

    function undo() {
        if (!undoState)
            return
        slots = undoState.slots
        preset = undoState.preset
        undoState = null
        store()
    }

    Timer { id: undoTimer; interval: 6000; onTriggered: screen.undoState = null }
    Timer { id: toastTimer; interval: 2600; onTriggered: screen.toastText = "" }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // Everything is drawn on a stage measured in the units of the design (a 915 x 412 phone in
    // landscape, 412 x 915 in portrait) and scaled to the screen. Extra room goes to the gaps.
    readonly property bool portrait: height > width
    readonly property real unit: portrait ? Math.min(width / 412, height / 915) : Math.min(width / 915, height / 412)

    Item {
        id: stage
        width: screen.width / screen.unit
        height: screen.height / screen.unit
        scale: screen.unit
        transformOrigin: Item.TopLeft

        // one soft glow in the zone color, breathing with the cadence
        Glow {
            x: screen.portrait ? stage.width / 2 - 230 : 0
            y: screen.portrait ? -30 : -20
            width: 460
            height: 460
            tint: screen.tint
            beat: 60000 / Math.max(40, screen.source.cadence)
            breathing: !screen.idle
        }

        // top bar: recording dot, ride clock, layout pill, lock
        Item {
            id: topBar
            x: screen.portrait ? 24 : 32
            y: 14
            width: stage.width - x - (screen.portrait ? 24 : 24)
            height: 40

            Rectangle {
                id: recDot
                width: 9
                height: 9
                radius: 4.5
                color: screen.idle ? Theme.text3 : Theme.recording
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: !Theme.reduceMotion && !screen.idle
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors { left: recDot.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: screen.stopped ? qsTr("Ready") : (screen.source.paused ? qsTr("Paused") : Metrics.clock(screen.source.elapsed))
                color: Theme.text
                font.family: screen.idle ? Theme.bodySemibold : Theme.display
                font.pixelSize: screen.idle ? 16 : 20
            }

            PulseButton {
                id: lockButton
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 36
                height: 36
                fill: screen.locked ? Theme.accent : Theme.control
                Accessible.name: screen.locked ? qsTr("Unlock the screen") : qsTr("Lock the screen")
                onClicked: {
                    screen.touched = true
                    screen.editing = -1
                    screen.toast(screen.locked ? qsTr("Unlocked.") : qsTr("Locked. Stray taps are ignored."))
                    screen.locked = !screen.locked
                }
                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        name: screen.locked ? "lock" : "unlock"
                        color: screen.locked ? Theme.accentInk : Theme.text2
                        size: 16
                    }
                }
            }
            PulseButton {
                id: presetPill
                anchors { right: lockButton.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                width: presetLabel.implicitWidth + 44
                height: 36
                fill: Theme.control
                Accessible.name: qsTr("Layout %1. Switch layout").arg(Metrics.presetName(screen.preset))
                onClicked: screen.cyclePreset()
                contentItem: Item {
                    Text {
                        id: presetLabel
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: Metrics.presetName(screen.preset)
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 13
                    }
                    Icon {
                        anchors { left: presetLabel.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        name: "chevron"
                        color: Theme.text2
                        size: 16
                    }
                }
            }
        }

        // the hero: one big number in the zone color
        PulseButton {
            id: heroButton
            x: screen.portrait ? 24 : 32
            y: screen.portrait ? 74 : 66
            width: screen.portrait ? stage.width - 48 : rows.x - 32 - 36
            height: screen.portrait ? 270 : 300
            radius: 28
            pressedScale: 0.985
            fill: screen.editing === 0 ? Qt.rgba(201 / 255, 184 / 255, 1, 0.06) : "transparent"
            Accessible.name: qsTr("Change the main number, now %1").arg(screen.hero.label) + ", " + screen.hero.value + " " + screen.hero.unit
            onClicked: screen.edit(0)

            Column {
                spacing: 10
                Row {
                    spacing: 8
                    Text {
                        text: screen.hero.label
                        color: Theme.text
                        font.family: Theme.bodyMedium
                        font.pixelSize: 14
                    }
                    Text {
                        visible: text !== ""
                        text: screen.hero.tag
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                        anchors.baseline: parent.children[0].baseline
                    }
                }
                Item { width: 1; height: 14 }
                Row {
                    spacing: 10
                    Numeral {
                        id: heroNumber
                        text: screen.hero.value
                        color: Theme.zoneLight[screen.zone - 1]
                        font.family: Theme.heroFamily(screen.zone)
                        font.pixelSize: screen.hero.value.length > 4 ? (screen.portrait ? 104 : 118) : (screen.portrait ? 140 : 156)
                        font.letterSpacing: -4
                        transformOrigin: Item.BottomLeft
                        Behavior on color {
                            enabled: !Theme.reduceMotion
                            ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                        }
                        SequentialAnimation {
                            id: bump
                            NumberAnimation { target: heroNumber; property: "scale"; to: 1.04; duration: 140; easing.type: Easing.OutQuad }
                            NumberAnimation { target: heroNumber; property: "scale"; to: 1; duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                        }
                    }
                    Text {
                        text: screen.hero.unit
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 20
                        anchors.baseline: heroNumber.baseline
                    }
                }
                Item { width: 1; height: 10 }
                Row {
                    spacing: 10
                    PulseShape {
                        width: 26
                        height: 26
                        zone: screen.pulseZone
                        color: screen.tint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: screen.heartDriven ? qsTr("Heart %1").arg(Theme.heartZoneNames[screen.zone - 1]) : Theme.powerZoneNames[screen.zone - 1]
                        color: screen.tint
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: screen.heartDriven ? Theme.heartZoneRange(screen.zone, screen.source.maxHeartRate) : Theme.powerZoneRange(screen.zone, screen.source.ftp)
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: screen.heartDriven ? 5 : 7
                        Rectangle {
                            width: (300 - 4 * ((screen.heartDriven ? 5 : 7) - 1)) / (screen.heartDriven ? 5 : 7)
                            height: 5
                            radius: 2.5
                            color: index + 1 === screen.zone ? screen.tint : (index + 1 < screen.zone ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.07))
                            Behavior on color {
                                enabled: !Theme.reduceMotion
                                ColorAnimation { duration: Theme.colorTime }
                            }
                        }
                    }
                }
            }
        }

        // the four rows
        Column {
            id: rows
            x: screen.portrait ? 24 : dock.x - 35 - width
            y: screen.portrait ? heroButton.y + heroButton.height + 6 : 62
            width: screen.portrait ? stage.width - 48 : 290
            Repeater {
                model: 4
                MetricRow {
                    width: rows.width
                    source: screen.source
                    metric: screen.slots[index + 1].m
                    kind: screen.slots[index + 1].st
                    tint: screen.tint
                    selected: screen.editing === index + 1
                    lastRow: index === 3
                    onClicked: screen.edit(index + 1)
                }
            }
        }

        // the level dock: harder, the level, easier, pause
        Rectangle {
            id: dock
            x: screen.portrait ? 20 : stage.width - 20 - width
            y: screen.portrait ? stage.height - 20 - height : 62
            width: screen.portrait ? stage.width - 40 : 92
            height: screen.portrait ? 92 : Math.max(306, stage.height - 106)
            radius: 46
            color: Theme.control

            Grid {
                anchors.fill: parent
                anchors.margins: screen.portrait ? 10 : 0
                anchors.topMargin: 10
                anchors.bottomMargin: screen.portrait ? 10 : 14
                flow: screen.portrait ? Grid.LeftToRight : Grid.TopToBottom
                columns: screen.portrait ? 4 : 1
                rows: screen.portrait ? 1 : 4
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                columnSpacing: screen.portrait ? (width - 72 - 72 - 64 - 44) / 3 : 0
                rowSpacing: screen.portrait ? 0 : (height - 72 - 72 - 64 - 44) / 3
                layoutDirection: Qt.LeftToRight

                PulseButton {
                    id: plus
                    width: 72
                    height: 72
                    radius: 26
                    pressedRadius: 36
                    fill: screen.tint
                    Accessible.name: qsTr("Harder, level up")
                    onClicked: { screen.touched = true; screen.source.levelUp() }
                    contentItem: Item { Icon { anchors.centerIn: parent; name: "plus"; color: "#141011"; size: 28 } }
                }
                Column {
                    width: 64
                    spacing: 8
                    Numeral {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screen.source.level
                        color: Theme.text
                        font.pixelSize: 40
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("level")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                    }
                }
                PulseButton {
                    width: 72
                    height: 72
                    pressedRadius: 20
                    fill: Theme.chip
                    Accessible.name: qsTr("Easier, level down")
                    onClicked: { screen.touched = true; screen.source.levelDown() }
                    contentItem: Item { Icon { anchors.centerIn: parent; name: "minus"; color: Theme.text; size: 28 } }
                }
                PulseButton {
                    width: 44
                    height: 44
                    fill: screen.idle ? Theme.accent : Theme.pressed
                    Accessible.name: screen.stopped ? qsTr("Start ride") : (screen.source.paused ? qsTr("Resume ride") : qsTr("Pause ride"))
                    onClicked: screen.source.togglePause()
                    contentItem: Item {
                        Icon {
                            anchors.centerIn: parent
                            name: screen.idle ? "play" : "pause"
                            color: screen.idle ? Theme.accentInk : Theme.text
                            size: 16
                        }
                    }
                }
            }
        }

        // the ride ribbon: one bar for every 30 s, in the zone of that half minute
        Row {
            id: ribbon
            x: screen.portrait ? 24 : 32
            width: screen.portrait ? stage.width - 48 : rows.x + rows.width - 32
            height: 8
            y: screen.portrait ? dock.y - 22 - height : stage.height - 22 - height
            spacing: 2
            readonly property int bars: 90
            readonly property var history: {
                var h = screen.source.zoneHistory
                return h.length > bars - 1 ? h.slice(h.length - bars + 1) : h
            }
            Repeater {
                model: ribbon.bars
                Rectangle {
                    width: (ribbon.width - (ribbon.bars - 1) * ribbon.spacing) / ribbon.bars
                    height: ribbon.height
                    radius: 2
                    color: index < ribbon.history.length ? Theme.zoneColors[ribbon.history[index] - 1]
                           : (index === ribbon.history.length ? Theme.zoneColors[Theme.powerZone(screen.source.power, screen.source.ftp) - 1] : Theme.floating)
                }
            }
            Accessible.ignored: true
        }

        // hint, undo and toast share one place above the ribbon
        Text {
            x: ribbon.x
            y: ribbon.y - 20 - height
            width: Math.min(400, ribbon.width)
            visible: !screen.touched && screen.editing < 0 && !screen.idle
            text: qsTr("Tap any number to change it. Level buttons push you through the zones.")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: snack
            x: ribbon.x
            y: ribbon.y - 16 - height
            width: 340
            height: 48
            radius: 18
            color: Theme.text
            visible: screen.undoState !== null && screen.editing < 0 && screen.toastText === ""
            Text {
                x: 16
                width: parent.width - undoButton.width - 30
                anchors.verticalCenter: parent.verticalCenter
                text: screen.undoState ? screen.undoState.message : ""
                color: "#141318"
                font.family: Theme.bodySemibold
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            PulseButton {
                id: undoButton
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: 72
                height: 36
                fill: Theme.accentInk
                Accessible.name: qsTr("Undo")
                onClicked: screen.undo()
                contentItem: Text {
                    text: qsTr("Undo")
                    color: Theme.accent
                    font.family: Theme.bodySemibold
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            x: ribbon.x
            y: ribbon.y - 18 - height
            width: toastLabel.implicitWidth + 32
            height: 40
            radius: 18
            color: Theme.pressed
            visible: screen.toastText !== "" && screen.editing < 0
            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: screen.toastText
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: 13
            }
        }

        // paused: resume or finish; stopped: start a new ride
        Rectangle {
            visible: screen.idle && screen.editing < 0
            anchors.horizontalCenter: screen.portrait ? parent.horizontalCenter : undefined
            x: screen.portrait ? 0 : heroButton.x
            y: ribbon.y - 12 - height
            width: screen.stopped ? 152 : 288
            height: 52
            radius: 26
            color: Theme.floating
            Row {
                anchors.centerIn: parent
                spacing: 8
                PulseButton {
                    width: 136
                    height: 42
                    fill: Theme.accent
                    Accessible.name: screen.stopped ? qsTr("Start a new ride") : qsTr("Resume")
                    onClicked: screen.source.togglePause()
                    contentItem: Text {
                        text: screen.stopped ? qsTr("Start") : qsTr("Resume")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                PulseButton {
                    visible: !screen.stopped
                    width: 136
                    height: 42
                    fill: Theme.chip
                    Accessible.name: qsTr("Finish ride")
                    onClicked: screen.finishRequested()
                    contentItem: Text {
                        text: qsTr("Finish")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        EditSheet {
            anchors.fill: parent
            source: screen.source
            slots: screen.slots
            slot: screen.editing
            onPickStyle: screen.setStyle(style)
            onPickMetric: screen.setMetric(metricId)
            onRemoveSlot: screen.removeMetric()
            onClose: screen.editing = -1
        }
    }

    onZoneChanged: if (!Theme.reduceMotion) bump.restart()
}
