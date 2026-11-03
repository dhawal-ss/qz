import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "Metrics.js" as Metrics

// The live ride. One big number, four quiet rows, the level dock and the ride ribbon.
// The screen takes one color, from the current zone. Every number can be swapped, restyled
// or removed mid-ride from a side sheet, with undo.
// Motion marks change (the motion board): a ride that has not started shows a Start ride pill
// that presses, morphs into a round pause button and counts 3, 2, 1 before the ride starts; at a
// zone crossing the hero numeral, the tint and the Pulse cross to the next zone; a swapped metric
// rolls into its row.
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

    // the tint as it shows: it crosses to the color of a new zone on the effects curve
    property color shownTint: tint
    Behavior on shownTint {
        enabled: !Theme.reduceMotion
        ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
    }

    // the start of a ride: "" (nothing going on), "count" (3, 2, 1) or "go" (it just started)
    property string startPhase: ""
    property int count: 0
    // the Start ride pill shows: the ride has not started, or is just starting
    readonly property bool ready: stopped || startPhase !== ""
    // the zone line rests while there is no ride to show it for
    readonly property bool calm: idle || startPhase !== ""

    // the crossing to the next zone: what showed before, moving out while the new one comes in
    property int lastZone: 0
    property int fromZone: 1
    property string fromValue: ""
    property string fromUnit: ""
    property string fromName: ""

    // how far into its zone the number is, 0 to 1, for the marker on the zone line
    readonly property real zoneFraction: {
        var lo = 0
        var hi = 1
        var now = 0
        if (heartDriven) {
            var hs = Theme.heartZoneStarts.map(function (p) { return Math.round(source.maxHeartRate * p) })
            lo = zone <= 1 ? Math.round(source.maxHeartRate * 0.5) : hs[zone - 2]
            hi = zone >= 5 ? source.maxHeartRate : hs[zone - 1]
            now = source.heartRate
        } else {
            var ps = Theme.powerZoneStarts.map(function (p) { return Math.round(source.ftp * p) })
            lo = zone <= 1 ? 0 : ps[zone - 2]
            hi = zone >= 7 ? ps[5] * 1.25 : ps[zone - 1]
            now = source.power
        }
        return hi > lo ? Math.max(0, Math.min(1, (now - lo) / (hi - lo))) : 0
    }

    function zoneName(z) {
        if (heartDriven)
            return qsTr("Heart %1").arg(Theme.heartZoneNames[Math.max(1, Math.min(5, z)) - 1])
        return Theme.powerZoneNames[Math.max(1, Math.min(7, z)) - 1]
    }

    // the hero numeral moves up and fades out, the next one rises in (slow spatial spring)
    function cross(previousZone, value, unit) {
        if (Theme.reduceMotion)
            return
        fromZone = Math.max(1, Math.min(7, previousZone))
        fromValue = value
        fromUnit = unit
        fromName = zoneName(previousZone)
        crossAnimation.restart()
    }

    // Start ride: the pill morphs into a round pause button and counts down, then the ride starts.
    // Only a ride that has not started counts down; a tap during the count cancels it.
    function startCountdown() {
        if (!stopped || startPhase !== "")
            return
        touched = true
        editing = -1
        startPhase = "count"
        count = 3
        showCount()
        countTimer.restart()
    }

    function cancelCountdown() {
        if (startPhase !== "count")
            return
        countTimer.stop()
        countAnimation.stop()
        count = 0
        startPhase = ""
    }

    function showCount() {
        if (Theme.reduceMotion) {
            countNumber.scale = 1
            countNumber.opacity = 1
            return
        }
        countAnimation.restart()
    }

    Timer {
        id: countTimer
        interval: 1000
        repeat: true
        onTriggered: {
            screen.count--
            if (screen.count > 0) {
                screen.showCount()
                return
            }
            stop()
            countNumber.opacity = 0
            screen.startPhase = "go"
            // start once, and only a ride that is still waiting to start
            if (screen.source.stopped)
                screen.source.togglePause()
            goTimer.restart()
        }
    }
    Timer {
        id: goTimer
        interval: 900
        onTriggered: screen.startPhase = ""
    }

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
        lastZone = zone
        Qt.callLater(function () { screen.settled = true })
    }

    // true once the saved layout is in: changes after that are the rider's, and they move
    property bool settled: false

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
        // a new main number crosses in like a new zone
        if (editing === 0)
            cross(zone, hero.value, hero.unit)
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
            tint: screen.shownTint
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
                Behavior on color {
                    enabled: !Theme.reduceMotion
                    ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                }
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
                text: screen.startPhase === "count" ? qsTr("Get ready")
                      : (screen.stopped ? qsTr("Ready") : (screen.source.paused ? qsTr("Paused") : Metrics.clock(screen.source.elapsed)))
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
                id: heroContent
                spacing: 10
                // the count takes the place of the number while it runs
                opacity: screen.startPhase === "count" ? 0 : 1
                Behavior on opacity {
                    enabled: !Theme.reduceMotion
                    NumberAnimation { duration: Theme.colorTime / 2; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                }
                Row {
                    spacing: 8
                    Text {
                        id: heroLabel
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
                        anchors.baseline: heroLabel.baseline
                    }
                }
                Item { width: 1; height: 14 }
                // the number and its unit; at a crossing the one before moves up and out
                Item {
                    id: heroLine
                    width: Math.max(inLine.width, outLine.opacity > 0 ? outLine.width : 0)
                    height: heroNumber.height
                    Row {
                        id: outLine
                        spacing: 10
                        opacity: 0
                        transform: Translate { id: outShift }
                        Numeral {
                            id: heroOut
                            text: screen.fromValue
                            color: Theme.zoneLight[screen.fromZone - 1]
                            font.family: Theme.heroFamily(screen.fromZone)
                            font.pixelSize: heroNumber.font.pixelSize
                            font.letterSpacing: -4
                        }
                        Text {
                            text: screen.fromUnit
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 20
                            anchors.baseline: heroOut.baseline
                        }
                    }
                    Row {
                        id: inLine
                        spacing: 10
                        transform: Translate { id: inShift }
                        Numeral {
                            id: heroNumber
                            text: screen.hero.value
                            color: Theme.zoneLight[screen.zone - 1]
                            font.family: Theme.heroFamily(screen.zone)
                            font.pixelSize: screen.hero.value.length > 4 ? (screen.portrait ? 104 : 118) : (screen.portrait ? 140 : 156)
                            font.letterSpacing: -4
                            Behavior on color {
                                enabled: !Theme.reduceMotion
                                ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
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
                }
                Item { width: 1; height: 10 }
                // the zone: the Pulse, its name and range, and the zone line with a marker
                Column {
                    spacing: 10
                    opacity: screen.calm ? 0 : 1
                    Behavior on opacity {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                    }
                    Row {
                        spacing: 10
                        Pulse {
                            width: 26
                            height: 26
                            zone: screen.pulseZone
                            color: screen.shownTint
                            turning: true
                            turnTime: 30000
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            width: zoneLabel.implicitWidth
                            height: zoneLabel.implicitHeight
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on width {
                                enabled: !Theme.reduceMotion
                                Spring { token: "slow" }
                            }
                            Text {
                                id: zoneLabelOut
                                opacity: 0
                                text: screen.fromName
                                color: Theme.zoneColors[screen.fromZone - 1]
                                font.family: Theme.bodySemibold
                                font.pixelSize: 15
                            }
                            Text {
                                id: zoneLabel
                                text: screen.zoneName(screen.zone)
                                color: screen.shownTint
                                font.family: Theme.bodySemibold
                                font.pixelSize: 15
                            }
                        }
                        Text {
                            text: screen.heartDriven ? Theme.heartZoneRange(screen.zone, screen.source.maxHeartRate) : Theme.powerZoneRange(screen.zone, screen.source.ftp)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.tertiarySize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Item {
                        id: zoneLine
                        readonly property int segments: screen.heartDriven ? 5 : 7
                        readonly property real segmentWidth: (width - 4 * (segments - 1)) / segments
                        width: 300
                        height: 14
                        Row {
                            y: 4.5
                            spacing: 4
                            Repeater {
                                model: zoneLine.segments
                                Rectangle {
                                    width: zoneLine.segmentWidth
                                    height: 5
                                    radius: 2.5
                                    color: index + 1 === screen.zone ? screen.shownTint : (index + 1 < screen.zone ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.07))
                                    Behavior on color {
                                        enabled: !Theme.reduceMotion
                                        ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                                    }
                                }
                            }
                        }
                        // where the number is in its zone, sliding across zones on the slow spring
                        Rectangle {
                            x: (screen.zone - 1) * (zoneLine.segmentWidth + 4) + screen.zoneFraction * zoneLine.segmentWidth - width / 2
                            width: 3
                            height: 14
                            radius: 1.5
                            color: Theme.text
                            Behavior on x {
                                enabled: !Theme.reduceMotion
                                Spring { token: "slow" }
                            }
                        }
                    }
                }
            }
        }

        // the crossing to the next zone: slow spatial for the movement, effects for the fades
        ParallelAnimation {
            id: crossAnimation
            NumberAnimation { target: outShift; property: "y"; from: 0; to: -28; duration: Theme.slowSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.slowSpatialCurve }
            NumberAnimation { target: outLine; property: "opacity"; from: 1; to: 0; duration: 320; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            NumberAnimation { target: inShift; property: "y"; from: 28; to: 0; duration: Theme.slowSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.slowSpatialCurve }
            NumberAnimation { target: inLine; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            NumberAnimation { target: zoneLabelOut; property: "opacity"; from: 1; to: 0; duration: Theme.colorTime / 2; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            NumberAnimation { target: zoneLabel; property: "opacity"; from: 0; to: 1; duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
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
                    tint: screen.shownTint
                    selected: screen.editing === index + 1
                    lastRow: index === 3
                    animate: screen.settled
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
                    fill: screen.shownTint
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
                    fill: screen.idle && screen.startPhase === "" ? Theme.accent : Theme.pressed
                    Accessible.name: screen.startPhase === "count" ? qsTr("Cancel the start")
                                     : (screen.stopped ? qsTr("Start ride") : (screen.source.paused ? qsTr("Resume ride") : qsTr("Pause ride")))
                    onClicked: {
                        if (screen.startPhase === "count")
                            screen.cancelCountdown()
                        else if (screen.stopped)
                            screen.startCountdown()
                        else
                            screen.source.togglePause()
                    }
                    contentItem: Item {
                        Icon {
                            anchors.centerIn: parent
                            name: screen.idle && screen.startPhase === "" ? "play" : "pause"
                            color: screen.idle && screen.startPhase === "" ? Theme.accentInk : Theme.text
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

        // paused: resume or finish
        Rectangle {
            visible: screen.source.paused && !screen.stopped && screen.editing < 0
            anchors.horizontalCenter: screen.portrait ? parent.horizontalCenter : undefined
            x: screen.portrait ? 0 : heroButton.x
            y: ribbon.y - 12 - height
            width: 296
            height: 56
            radius: 28
            color: Theme.floating
            Row {
                anchors.centerIn: parent
                spacing: 8
                PulseButton {
                    width: 140
                    height: 46
                    fill: Theme.accent
                    pressedRadius: 16
                    Accessible.name: qsTr("Resume")
                    onClicked: screen.source.togglePause()
                    contentItem: Text {
                        text: qsTr("Resume")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                PulseButton {
                    width: 140
                    height: 46
                    fill: Theme.chip
                    pressedRadius: 16
                    Accessible.name: qsTr("Finish ride")
                    onClicked: screen.finishRequested()
                    contentItem: Text {
                        text: qsTr("Finish")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // 3, 2, 1 where the number will be: each count lands from big, holds, and shrinks away
        Numeral {
            id: countNumber
            visible: screen.startPhase === "count"
            x: heroButton.x + (heroButton.width - width) / 2
            y: heroButton.y + (heroButton.height - height) / 2
            text: screen.count > 0 ? String(screen.count) : ""
            color: Theme.text
            font.family: Theme.heroFamily(6)
            font.pixelSize: screen.portrait ? 150 : 170
            opacity: 0
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("Starting in %1").arg(screen.count)
        }
        SequentialAnimation {
            id: countAnimation
            ParallelAnimation {
                NumberAnimation { target: countNumber; property: "scale"; from: 1.5; to: 1; duration: Theme.fastSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.fastSpatialCurve }
                NumberAnimation { target: countNumber; property: "opacity"; from: 0; to: 1; duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
            NumberAnimation { target: countNumber; property: "scale"; to: 0.94; duration: 340; easing.type: Easing.InOutSine }
            ParallelAnimation {
                NumberAnimation { target: countNumber; property: "scale"; to: 0.8; duration: 200; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                NumberAnimation { target: countNumber; property: "opacity"; to: 0; duration: 200; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
        }

        // Start ride: a ride that has not started waits for this pill. Pressed, it morphs into a
        // round pause button (fast spatial spring) while the count runs; a tap then cancels.
        PulseButton {
            id: startPill
            readonly property bool morphed: screen.startPhase !== "" || !screen.stopped
            readonly property real centerX: screen.portrait ? stage.width / 2 : heroButton.x + heroButton.width / 2
            width: morphed ? 64 : 220
            height: 64
            x: centerX - width / 2
            y: ribbon.y - 18 - height
            opacity: screen.ready ? 1 : 0
            visible: opacity > 0.01 && screen.editing < 0
            pressedScale: 0.95
            fill: morphed ? Theme.chip : Theme.accent
            Accessible.name: screen.startPhase === "count" ? qsTr("Cancel the start")
                             : (screen.startPhase === "go" ? qsTr("Pause ride") : qsTr("Start ride"))
            onClicked: {
                if (screen.startPhase === "count")
                    screen.cancelCountdown()
                else if (screen.startPhase === "go")
                    screen.source.togglePause()
                else
                    screen.startCountdown()
            }
            Behavior on width {
                enabled: !Theme.reduceMotion
                Spring { token: "fast" }
            }
            Behavior on opacity {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
            contentItem: Item {
                // the label stays inside the pill while it narrows
                clip: true
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    opacity: startPill.morphed ? 0 : 1
                    Behavior on opacity {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "play"
                        size: 18
                        color: Theme.accentInk
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Start ride")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: 17
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    name: "pause"
                    size: 20
                    color: Theme.text
                    opacity: startPill.morphed ? 1 : 0
                    Behavior on opacity {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
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

    onZoneChanged: {
        if (lastZone > 0 && lastZone !== zone)
            cross(lastZone, hero.value, hero.unit)
        lastZone = zone
    }
}
