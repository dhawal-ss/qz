import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "ride"
import "Metrics.js" as Metrics
import "train"
import "train/Workout.js" as Workout
import "train/Ftp.js" as Ftp
import "train/Route.js" as Route
import "Format.js" as Format

// The live ride. One big number, four quiet rows, the level dock and the ride ribbon.
// The screen takes one color, from the current zone. Every number can be swapped, restyled
// or removed mid-ride from a side sheet, with undo.
// Motion marks change (the motion board): a ride that has not started shows a Start ride pill
// that presses, morphs into a round pause button and counts 3, 2, 1 before the ride starts; at a
// zone crossing the hero numeral, the tint and the Pulse cross to the next zone; a swapped metric
// rolls into its row.
// The lifecycle: Pause and Resume always keep the same ride; only a held End (or End confirmed,
// for a screen reader) finishes and saves it. A paused or not yet started ride can be left with
// the back button: the ride stays paused and the Ride button comes back to it.
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

    // rootItem, for the cues and the level coach (null in previews)
    property var core: null
    // the workout under way (today/Coach.js plan(), null for a free ride) and the ride seconds it
    // started at. Its steps take the ride's own FTP: the rider's on a live ride, the demo's in a demo
    // (a demo has no "not set").
    property var workoutPlan: null
    readonly property var workoutSteps: workoutPlan ? Workout.steps(workoutPlan, source.ftp,
                                                                    typeof source.ftpSet === "boolean" ? source.ftpSet : true,
                                                                    Theme.powerZoneStarts) : []
    // a route instead (train/Route.js, null for none) and the km it started at; the ride is named
    // after the workout or the route
    property var route: null
    property real routeStartKm: 0
    readonly property bool inRoute: route !== null && !inWorkout
    readonly property real kmNow: source.miles === true ? source.distance / 0.621371 : source.distance
    readonly property real routeKm: Math.max(0, kmNow - routeStartKm)
    readonly property string workoutName: workoutPlan ? workoutPlan.name : (route ? route.name : "")
    // the rider's weight (kg), for what a climb takes
    property real weight: 75
    // Ghost: the last ride of the same workout or route ({ values, unit: "kj" or "km", day }, null for
    // none), where the rider is against it now; only from the start of a ride
    property var ghost: null
    property string ghostText: ""
    property int workoutStart: 0
    readonly property bool inWorkout: workoutSteps.length > 0
    readonly property int workoutT: Math.max(0, source.elapsed - workoutStart)
    readonly property var workoutPos: Workout.at(workoutSteps, workoutT)

    signal finishRequested()
    // back to the app, the ride stays as it is (paused, or not started)
    signal leaveRequested()

    // stopped: the ride was finished and the next tap on Start begins a new one
    readonly property bool stopped: source.stopped === true
    readonly property bool idle: source.paused || stopped

    // the level buttons, or Pause, Lap and End in their place for a bike whose level is set by
    // hand. "resistanceControl" (You): "auto" follows the bike, "on" and "off" force it
    property string resistanceMode: "auto"
    // names of the bikes that ignored a level press from the app, learned in "auto"
    property var manualBikes: []
    readonly property bool learnedManual: manualBikes.indexOf(source.deviceName) >= 0
    readonly property bool levelControls: resistanceMode === "on"
                                          || (resistanceMode === "auto" && source.canChangeResistance !== false && !learnedManual)
    // End asked for a confirm (a screen reader cannot hold)
    property bool confirmingEnd: false
    property double lastToggle: 0

    readonly property bool heartDriven: preset === "heart" && source.heartRate > 0
    readonly property int rawZone: heartDriven ? Theme.heartZone(source.heartRate, source.maxHeartRate)
                                               : Theme.powerZone(source.power, source.ftp)
    // the zone the screen shows follows the number once it has stayed in a new zone for 2 s, so
    // watts on a zone boundary do not flicker the colors
    property int zone: rawZone
    onRawZoneChanged: {
        if (rawZone === zone)
            zoneHold.stop()
        else if (!zoneHold.running)
            zoneHold.start()
    }
    onHeartDrivenChanged: { zoneHold.stop(); zone = rawZone }
    Timer {
        id: zoneHold
        interval: 2000
        onTriggered: screen.zone = screen.rawZone
    }
    // Focus: the layout of one big number, the clock and the controls
    readonly property bool focusMode: preset === "focus"
    // power zones need the rider's own FTP: until it is set (Theme.ftpSet) the screen keeps the
    // accent and one numeral cut whatever the watts, and the zone line says so. shownZone is the
    // zone the colors, the numeral and the Pulse follow.
    readonly property bool zonesNeutral: !heartDriven && !Theme.ftpSet
    readonly property int shownZone: zonesNeutral ? 1 : zone
    readonly property color tint: zonesNeutral ? Theme.accent : Theme.zoneColors[zone - 1]
    readonly property int pulseZone: heartDriven ? Math.min(7, Math.round(1 + (zone - 1) * 1.5)) : shownZone
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
        var name = heartDriven ? qsTr("Heart %1").arg(Theme.heartZoneNames[Math.max(1, Math.min(5, z)) - 1])
                               : Theme.powerZoneNames[Math.max(1, Math.min(7, z)) - 1]
        // the zone follows the watts (or the heart rate) of this second: under another big number,
        // such as Live NP, it says so
        return slots[0].m === (heartDriven ? "heart" : "power") ? name : qsTr("Now: %1").arg(name)
    }

    // the hero numeral moves up and fades out, the next one rises in (slow spatial spring)
    function cross(previousZone, value, unit) {
        if (Theme.reduceMotion)
            return
        fromZone = Math.max(1, Math.min(7, previousZone))
        fromValue = value
        fromUnit = unit
        fromName = zonesNeutral ? qsTr("Set your FTP for power zones") : zoneName(previousZone)
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
            if (screen.source.stopped) {
                screen.source.begin()
                // the saved ride is named after the workout (QZ clears the name when a ride starts)
                if ((screen.inWorkout || screen.inRoute) && typeof screen.source.core !== "undefined" && screen.source.core !== null)
                    screen.source.core.setWorkoutName(screen.workoutName)
            }
            screen.cue(2, screen.inWorkout ? qsTr("%1. Go").arg(screen.workoutName) : "")
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
        resistanceMode = String(saved.value("resistanceControl", "auto"))
        autoPauseOn = String(saved.value("autoPause", "true")) !== "false"
        cueSound = String(saved.value("cueSound", "true")) !== "false"
        cueVoice = String(saved.value("cueVoice", "false")) === "true"
        try {
            var known = JSON.parse(String(saved.value("manualLevelBikes", "[]")))
            manualBikes = Array.isArray(known) ? known : []
        } catch (e) {
            manualBikes = []
        }
        preset = saved.ridePreset
        slots = Metrics.parseLayout(saved.rideLayout, preset === "custom" ? "power" : preset)
        lastZone = shownZone
        Qt.callLater(function () { screen.settled = true })
    }

    // true once the saved layout is in: changes after that are the rider's, and they move
    property bool settled: false

    // while the screen is locked every control but the lock only says so
    function lockedOut() {
        if (!locked)
            return false
        touched = true
        toast(qsTr("Locked. Tap the lock to use the controls."))
        return true
    }

    // Pause or Resume, never a new ride; a second tap within half a second is ignored so a
    // bump on the handlebar cannot pause and resume at once
    function pauseResume() {
        if (lockedOut() || bounced())
            return
        toggleRide()
    }

    // true for a second press within half a second of the last one, which is then ignored
    function bounced() {
        touched = true
        var now = Date.now()
        if (now - lastToggle < 500)
            return true
        lastToggle = now
        return false
    }

    function toggleRide() {
        if (source.stopped)
            return
        autoPaused = false
        pedaled = false
        stillFor = 0
        if (source.paused)
            source.resume()
        else
            source.pause()
    }

    // the big button of the ride controls, the pause button of the level dock and the Start ride
    // pill: start (3, 2, 1), cancel the count, pause or resume; a bump right after is ignored
    function mainControl() {
        if (lockedOut() || bounced())
            return
        if (startPhase === "count")
            cancelCountdown()
        else if (stopped)
            startCountdown()
        else
            toggleRide()
    }

    // how long the ride has been paused, in seconds
    property int pausedFor: 0
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: screen.source.paused === true && !screen.stopped && screen.source.pausedAt > 0
        onTriggered: screen.pausedFor = Math.max(0, Math.round((Date.now() - screen.source.pausedAt) / 1000))
    }

    // Auto-pause (You, on unless switched off): 5 s at 0 rpm after pedaling, or the bike lost for
    // 3 s, pauses the ride; pedaling again with the bike there resumes it. Only a pause the screen
    // made by itself ends by itself, a pause the rider pressed waits for Resume.
    property bool autoPauseOn: true
    property bool autoPaused: false
    property bool pedaled: false
    property int stillFor: 0
    property int lostFor: 0
    property int movingFor: 0
    readonly property bool bikeLost: source.connected === false && !stopped
    Timer {
        interval: 1000
        repeat: true
        running: !screen.stopped && screen.startPhase === ""
        onTriggered: screen.autoPauseTick()
    }
    function autoPauseTick() {
        lostFor = source.connected === false ? lostFor + 1 : 0
        if (!autoPauseOn)
            return
        if (!source.paused) {
            if (lostFor >= 3) {
                autoPause()
                return
            }
            if (source.cadence > 0) {
                pedaled = true
                stillFor = 0
                return
            }
            if (!pedaled)
                return
            stillFor++
            if (stillFor >= 5)
                autoPause()
        } else if (autoPaused) {
            movingFor = source.connected !== false && source.cadence > 0 ? movingFor + 1 : 0
            if (movingFor >= 2) {
                source.resume()
                autoPaused = false
                stillFor = 0
                movingFor = 0
                toast(qsTr("Riding again"))
            }
        }
    }
    function autoPause() {
        source.pause()
        autoPaused = true
        stillFor = 0
        movingFor = 0
    }

    // the lap that ends: its number, time and average power, from the ride's totals at its start
    property int lapStartElapsed: 0
    property real lapStartKj: 0
    // a second Lap within a second is a double tap, not a lap of one second
    property real lastLap: 0
    function lapRide() {
        if (lockedOut())
            return
        touched = true
        if (stopped || Date.now() - lastLap < 1000)
            return
        lastLap = Date.now()
        var seconds = source.elapsed - lapStartElapsed
        var watts = seconds > 0 ? Math.round((source.kilojoules - lapStartKj) * 1000 / seconds) : 0
        lapStartElapsed = source.elapsed
        lapStartKj = source.kilojoules
        source.lap()
        var parts = [qsTr("Lap %1").arg(source.laps), Metrics.clock(Math.max(0, seconds))]
        if (watts > 0)
            parts.push(qsTr("%1 W avg").arg(watts))
        toast(parts.join("  ·  "), 5000)
        cue(1, parts.join(", "))
    }
    onStoppedChanged: {
        lapStartElapsed = 0
        lapStartKj = 0
        autoPaused = false
        pedaled = false
    }

    // Cues (You): a beep and a buzz (on unless switched off), and spoken words (off unless switched
    // on). kind 0 a tick (a new zone), 1 the count before a change, 2 a change or the start
    property bool cueSound: true
    property bool cueVoice: false
    function cue(kind, words) {
        if (core === null)
            return
        if (cueSound)
            bikemodoBridge.cue(kind)
        if (cueVoice && words)
            core.say(words)
    }

    // the workout: 3, 2, 1 before each new step, then the step said; the end said once
    property int cuedIndex: -1
    property int cuedSecond: -1
    onWorkoutTChanged: {
        // a test that is over has no more steps to count down
        if (!inWorkout || stopped || source.paused || testOver)
            return
        var p = workoutPos
        if (p.index !== cuedIndex) {
            var first = cuedIndex < 0
            cuedIndex = p.index
            if (p.done) {
                cue(2, qsTr("Workout done"))
                toast(qsTr("Workout done. Keep riding, or hold End to finish."), 5000)
            } else if (!first) {
                var s = workoutSteps[p.index]
                cue(2, qsTr("%1 minutes, %2").arg(Math.round(s.seconds / 60)).arg(Workout.target(s)))
            }
            return
        }
        if (!p.done && p.left <= 3 && p.left >= 1 && p.index + 1 < workoutSteps.length && cuedSecond !== workoutT) {
            cuedSecond = workoutT
            cue(1, "")
        }
    }
    onWorkoutStepsChanged: { cuedIndex = -1; cuedSecond = -1 }

    // An FTP test (train/Ftp.js) measures while its test steps run: every second of the ramp for the
    // best minute, the 20 minutes for their average. A ramp is over once the last 20 s are well
    // under the step (after its first 2 minutes). The result waits on Today (ui2/ftpTestResult) for
    // the rider to use it or not; a demo only says it.
    readonly property bool testing: Ftp.isTest(workoutPlan)
    property var testSeconds: []
    property real testBest: 0
    property real testSum: 0
    property int testCount: 0
    property bool testOver: false
    property bool testSaved: false
    property int testWatts: 0
    onWorkoutPlanChanged: {
        testSeconds = []
        testBest = 0
        testSum = 0
        testCount = 0
        testOver = false
        testSaved = false
        testWatts = 0
    }
    function measureTest() {
        if (!testing || testOver || source.paused || stopped)
            return
        var p = workoutPos
        if (p.index < workoutPlan.testFrom)
            return
        if (p.index > workoutPlan.testTo) {
            endTest()
            return
        }
        var w = source.power
        var list = testSeconds.slice()
        list.push(w)
        if (list.length > 60)
            list.shift()
        testSeconds = list
        testSum += w
        testCount++
        if (list.length >= 60) {
            var sum = 0
            for (var i = 0; i < list.length; i++)
                sum += list[i]
            testBest = Math.max(testBest, sum / list.length)
        }
        if (workoutPlan.kind === "ramp" && p.index >= workoutPlan.testFrom + 2 && list.length >= 20) {
            var recent = 0
            for (var j = list.length - 20; j < list.length; j++)
                recent += list[j]
            var s = workoutSteps[p.index]
            if (recent / 20 < (s.low + 5) * 0.85)
                endTest()
        }
    }
    // the test is over: its FTP, said, and kept for Today unless it is a demo
    function endTest() {
        if (testOver)
            return
        testOver = true
        var average = testCount > 0 ? testSum / testCount : 0
        // a 20 minute test cut short says nothing
        if (workoutPlan.kind === "twenty" && testCount < 18 * 60)
            average = 0
        testWatts = Ftp.result(workoutPlan.kind, testBest, average)
        if (testWatts <= 0) {
            toast(qsTr("Too short for an FTP. Spin easy, then hold End."), 5000)
            return
        }
        cue(2, qsTr("Test over. FTP %1 watts").arg(testWatts))
        toast(qsTr("Test over: FTP %1 W. Spin easy, then hold End.").arg(testWatts), 6000)
        if (testSaved || typeof source.core === "undefined" || source.core === null)
            return
        testSaved = true
        saved.setValue("ftpTestResult", JSON.stringify({ watts: testWatts, kind: workoutPlan.kind,
                                                         measured: Math.round(workoutPlan.kind === "ramp" ? testBest : average),
                                                         estimated: source.powerEstimated === true, ms: Date.now() }))
    }

    // watts over the last seconds and the level for the middle of the band (an Echelon's own table),
    // for what the workout panel says to do
    property real wattsHeld: 0
    property int levelTarget: -1
    property bool routeDoneSaid: false
    onRouteChanged: routeDoneSaid = false
    Timer {
        interval: 1000
        repeat: true
        running: (screen.inWorkout || screen.inRoute) && !screen.stopped
        onTriggered: {
            screen.ghostText = screen.ghostLine()
            if (screen.inRoute) {
                var at = Route.at(screen.route, screen.routeKm)
                if (at.done && !screen.routeDoneSaid) {
                    screen.routeDoneSaid = true
                    screen.cue(2, qsTr("Route done"))
                    screen.toast(qsTr("Route done. Keep riding, or hold End to finish."), 5000)
                }
                var need = at.done ? 0 : Route.watts(at.grade, Math.max(screen.source.speed * (screen.source.miles === true ? 1.609344 : 1), 12), screen.weight)
                screen.levelTarget = need > 0 && screen.core !== null && screen.source.cadence > 0 ? screen.core.levelForWatts(need) : -1
                return
            }
            screen.measureTest()
            screen.wattsHeld = screen.wattsHeld * 0.6 + screen.source.power * 0.4
            var p = screen.workoutPos
            var s = p.index >= 0 && p.index < screen.workoutSteps.length ? screen.workoutSteps[p.index] : null
            screen.levelTarget = s && s.high > 0 && screen.core !== null && screen.source.cadence > 0
                    ? screen.core.levelForWatts(Math.round((s.low + s.high) / 2)) : -1
        }
    }
    // "3.2 kJ ahead of your ride on 12 Oct"
    function ghostLine() {
        if (ghost === null || stopped || ghost.values.length === 0)
            return ""
        var t = Math.min(ghost.values.length - 1, source.elapsed)
        if (ghost.unit === "kj") {
            if (workoutStart > 0)
                return ""
            var dk = source.kilojoules - ghost.values[t]
            return Math.abs(dk) < 0.5 ? qsTr("Level with your ride of %1").arg(ghost.day)
                 : (dk > 0 ? qsTr("%1 kJ ahead of your ride of %2") : qsTr("%1 kJ behind your ride of %2")).arg(Math.abs(dk).toFixed(1)).arg(ghost.day)
        }
        if (routeStartKm > 0)
            return ""
        var dd = routeKm - ghost.values[t]
        return Math.abs(dd) < 0.02 ? qsTr("Level with your ride of %1").arg(ghost.day)
             : (dd > 0 ? qsTr("%1 ahead of your ride of %2") : qsTr("%1 behind your ride of %2")).arg(Format.distance(Math.abs(dd), source.miles === true)).arg(ghost.day)
    }

    // Android back while the ride moves: it stays, and the screen says how to leave
    function backPressed() {
        toast(qsTr("Pause the ride to leave it."))
    }

    // Pause or Lap from the notification: on purpose, so the lock does not stop them
    function notificationAction(action) {
        if (action === 1 && !stopped && startPhase === "") {
            toggleRide()
        } else if (action === 2 && !stopped) {
            var wasLocked = locked
            locked = false
            lapRide()
            locked = wasLocked
        }
    }

    function askEnd() {
        if (lockedOut() || stopped)
            return
        editing = -1
        confirmingEnd = true
        confirmTimer.restart()
    }

    function endRide() {
        confirmingEnd = false
        if (lockedOut() || stopped)
            return
        // a test ended by the rider: what it measured counts
        if (testing && !testOver && workoutPos.index >= workoutPlan.testFrom)
            endTest()
        finishRequested()
    }

    // Harder or easier. In "auto" a press that leaves the level where it was for 5 s means the
    // bike has a hand knob: the dock turns into the ride controls, for this bike from now on.
    property int levelBefore: 0
    function pressLevel(up) {
        if (lockedOut())
            return
        touched = true
        if (up)
            source.levelUp()
        else
            source.levelDown()
        var atEdge = up ? source.level >= source.levelMax : source.level <= 1
        if (resistanceMode === "auto" && source.connected && source.level > 0 && !atEdge && !levelWatch.running) {
            levelBefore = source.level
            levelWatch.restart()
        }
    }

    function learnManual() {
        if (source.deviceName === "" || learnedManual)
            return
        var next = manualBikes.slice()
        next.push(source.deviceName)
        manualBikes = next
        saved.setValue("manualLevelBikes", JSON.stringify(next))
        toast(qsTr("This bike sets its level by hand, so the dock now holds Pause, Lap and End."), 6000)
    }

    Timer {
        id: levelWatch
        interval: 5000
        onTriggered: {
            if (screen.source.level === screen.levelBefore)
                screen.learnManual()
        }
    }
    Connections {
        target: screen.source
        ignoreUnknownSignals: true
        // rideMetrics renews every number each second, so this also comes with no change
        function onLevelChanged() {
            if (screen.source.level !== screen.levelBefore)
                levelWatch.stop()
        }
    }
    Timer { id: confirmTimer; interval: 8000; onTriggered: screen.confirmingEnd = false }

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

    function toast(text, ms) {
        toastText = text
        toastTimer.interval = ms ? ms : 2600
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
            cross(shownZone, hero.value, hero.unit)
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
            y: 10
            width: stage.width - x - (screen.portrait ? 24 : 24)
            height: 48

            // back to the app while the ride is paused or has not started; it stays as it is
            PulseButton {
                id: leaveButton
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                visible: screen.idle && screen.startPhase === "" && screen.editing < 0
                fill: Theme.control
                Accessible.name: screen.stopped ? qsTr("Back") : qsTr("Back, the ride stays paused")
                onClicked: {
                    if (screen.stopped || !screen.lockedOut())
                        screen.leaveRequested()
                }
                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        name: "back"
                        color: Theme.text2
                        size: 18
                    }
                }
            }

            Rectangle {
                id: recDot
                x: leaveButton.visible ? leaveButton.width + 14 : 0
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
                      : (screen.stopped ? qsTr("Ready")
                         : (screen.source.paused ? (screen.pausedFor >= 5 ? qsTr("Paused for %1").arg(Metrics.clock(screen.pausedFor)) : qsTr("Paused"))
                            : Metrics.clock(screen.source.elapsed)))
                color: Theme.text
                font.family: screen.idle ? Theme.bodySemibold : Theme.display
                font.pixelSize: screen.idle ? 17 : 32
            }

            PulseButton {
                id: lockButton
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 48
                height: 48
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
                        size: 18
                    }
                }
            }
            PulseButton {
                id: presetPill
                anchors { right: lockButton.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: presetLabel.implicitWidth + 44
                height: 48
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
                        font.pixelSize: Theme.fs(13)
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

        // the bike dropped out: said at the top until it is back (the ride pauses by itself)
        Rectangle {
            visible: screen.bikeLost && screen.lostFor >= 2
            anchors.horizontalCenter: topBar.horizontalCenter
            y: topBar.y + topBar.height + 6
            width: lostRow.implicitWidth + 32
            height: 40
            radius: 20
            color: Theme.recording
            z: 2
            Accessible.role: Accessible.AlertMessage
            Accessible.name: lostText.text
            Row {
                id: lostRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    id: lostText
                    text: qsTr("Bike lost. Looking for it")
                    color: "#ffffff"
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(15)
                }
            }
        }

        // the hero: one big number in the zone color
        PulseButton {
            id: heroButton
            x: screen.portrait ? 24 : 32
            y: screen.portrait ? 74 : 66
            width: screen.portrait ? stage.width - 48 : (screen.focusMode && !screen.inWorkout && !screen.inRoute ? dock.x - 32 - 36 : rows.x - 32 - 36)
            height: screen.portrait ? (screen.focusMode ? Math.max(270, ribbon.y - 40 - y - (screen.inWorkout ? workoutPanel.height + 16 : (screen.inRoute ? routePanel.height + 16 : 0))) : 270) : 300
            radius: 28
            pressedScale: 0.985
            fill: screen.editing === 0 ? Theme.accentWash(0.06) : "transparent"
            Accessible.name: qsTr("Change the main number, now %1").arg(screen.hero.label) + ", " + screen.hero.value + " " + screen.hero.unit
            onClicked: screen.edit(0)

            Column {
                id: heroContent
                spacing: 10
                // in Focus the number sits in the middle of its room
                y: screen.focusMode && screen.portrait ? Math.max(0, (heroButton.height - height) / 2 - 20) : 0
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
                        font.pixelSize: Theme.fs(14)
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
                            color: screen.zonesNeutral ? Theme.text : Theme.zoneLight[screen.fromZone - 1]
                            font.family: Theme.heroFamily(screen.fromZone)
                            font.pixelSize: heroNumber.font.pixelSize
                            font.letterSpacing: -4
                        }
                        Text {
                            text: screen.fromUnit
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(20)
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
                            color: screen.zonesNeutral ? Theme.text : Theme.zoneLight[screen.zone - 1]
                            font.family: Theme.heroFamily(screen.shownZone)
                            font.pixelSize: (screen.hero.value.length > 4 ? (screen.portrait ? 104 : 118) : (screen.portrait ? 140 : 156))
                                            * (screen.focusMode ? 1.2 : 1)
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
                            font.pixelSize: Theme.fs(20)
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
                                font.pixelSize: Theme.fs(15)
                            }
                            Text {
                                id: zoneLabel
                                text: screen.zonesNeutral ? qsTr("Set your FTP for power zones") : screen.zoneName(screen.zone)
                                color: screen.shownTint
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(15)
                            }
                        }
                        Text {
                            visible: !screen.zonesNeutral
                            text: screen.heartDriven ? Theme.heartZoneRange(screen.zone, screen.source.maxHeartRate) : Theme.powerZoneRange(screen.zone, screen.source.ftp)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.tertiarySize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Item {
                        id: zoneLine
                        visible: !screen.zonesNeutral
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
                                    color: index + 1 === screen.zone ? screen.shownTint : (index + 1 < screen.zone ? Theme.overlay(0.18) : Theme.overlay(0.07))
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
            visible: !screen.focusMode
            x: screen.portrait ? 24 : dock.x - 35 - width
            y: screen.portrait ? heroButton.y + heroButton.height + 6 : 62
            width: screen.portrait ? stage.width - 48 : 290
            Repeater {
                // a workout or a route takes the room of the last two
                model: screen.inWorkout || screen.inRoute ? 2 : 4
                MetricRow {
                    width: rows.width
                    source: screen.source
                    metric: screen.slots[index + 1].m
                    kind: screen.slots[index + 1].st
                    tint: screen.shownTint
                    selected: screen.editing === index + 1
                    lastRow: index === (screen.inWorkout || screen.inRoute ? 1 : 3)
                    animate: screen.settled
                    onClicked: screen.edit(index + 1)
                }
            }
        }

        // the workout under way: under the rows, or under the number in Focus on a phone
        WorkoutPanel {
            id: workoutPanel
            visible: screen.inWorkout
            x: rows.x
            width: rows.width
            y: screen.focusMode ? (screen.portrait ? heroButton.y + heroButton.height + 6 : 62) : rows.y + rows.height + 10
            height: implicitHeight
            steps: screen.workoutSteps
            t: screen.workoutT
            watts: screen.wattsHeld
            level: screen.source.level
            levelTarget: screen.levelTarget
            estimated: screen.source.powerEstimated === true
            ghostText: screen.ghostText
            overText: screen.testOver ? (screen.testWatts > 0 ? qsTr("Test over: FTP %1 W. Spin easy, then hold End.").arg(screen.testWatts)
                                                              : qsTr("Too short for an FTP. Spin easy, then hold End.")) : ""
        }

        // the route under way, where the workout would be
        RoutePanel {
            id: routePanel
            visible: screen.inRoute
            x: rows.x
            width: rows.width
            y: screen.focusMode ? (screen.portrait ? heroButton.y + heroButton.height + 6 : 62) : rows.y + rows.height + 10
            height: implicitHeight
            route: screen.route
            km: screen.routeKm
            speed: screen.source.speed * (screen.source.miles === true ? 1.609344 : 1)
            weight: screen.weight
            miles: screen.source.miles === true
            level: screen.source.level
            levelTarget: screen.levelTarget
            ghostText: screen.ghostText
        }

        // the dock: harder, the level, easier and pause for a bike the app can set; the ride
        // controls (Pause, Lap, held End and the level to read) for one whose level is set by hand
        Rectangle {
            id: dock
            x: screen.portrait ? 20 : stage.width - 20 - width
            y: screen.portrait ? stage.height - 20 - height : 62
            width: screen.portrait ? stage.width - 40 : (screen.levelControls ? 92 : 124)
            height: screen.portrait ? (screen.levelControls ? 92 : 116) : Math.max(306, stage.height - 106)
            radius: screen.levelControls ? 46 : 40
            color: Theme.control

            Grid {
                visible: screen.levelControls
                anchors.fill: parent
                anchors.margins: screen.portrait ? 10 : 0
                anchors.topMargin: 10
                anchors.bottomMargin: screen.portrait ? 10 : 14
                flow: screen.portrait ? Grid.LeftToRight : Grid.TopToBottom
                columns: screen.portrait ? 4 : 1
                rows: screen.portrait ? 1 : 4
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                columnSpacing: screen.portrait ? (width - 72 - 72 - 64 - 56) / 3 : 0
                rowSpacing: screen.portrait ? 0 : (height - 72 - 72 - 64 - 56) / 3
                layoutDirection: Qt.LeftToRight

                PulseButton {
                    id: plus
                    width: 72
                    height: 72
                    radius: 26
                    pressedRadius: 36
                    fill: screen.shownTint
                    Accessible.name: qsTr("Harder, level up")
                    onClicked: screen.pressLevel(true)
                    contentItem: Item { Icon { anchors.centerIn: parent; name: "plus"; color: Theme.zoneInk; size: 28 } }
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
                    onClicked: screen.pressLevel(false)
                    contentItem: Item { Icon { anchors.centerIn: parent; name: "minus"; color: Theme.text; size: 28 } }
                }
                PulseButton {
                    width: 56
                    height: 56
                    pressedRadius: 18
                    fill: screen.idle && screen.startPhase === "" ? Theme.accent : Theme.pressed
                    Accessible.name: screen.startPhase === "count" ? qsTr("Cancel the start")
                                     : (screen.stopped ? qsTr("Start ride") : (screen.source.paused ? qsTr("Resume ride") : qsTr("Pause ride")))
                    onClicked: screen.mainControl()
                    contentItem: Item {
                        Icon {
                            anchors.centerIn: parent
                            name: screen.idle && screen.startPhase === "" ? "play" : "pause"
                            color: screen.idle && screen.startPhase === "" ? Theme.accentInk : Theme.text
                            size: 20
                        }
                    }
                }
            }

            RideControls {
                visible: !screen.levelControls
                anchors.fill: parent
                vertical: !screen.portrait
                source: screen.source
                tint: screen.shownTint
                phase: screen.startPhase
                onMainPressed: screen.mainControl()
                onLapPressed: screen.lapRide()
                onEndHeld: screen.endRide()
                onEndTapped: screen.toast(qsTr("Hold End to finish the ride."))
                onEndConfirm: screen.askEnd()
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
                    // one accent wash for every ridden half minute while power zones need an FTP
                    color: index < ribbon.history.length ? (screen.zonesNeutral ? Theme.accentWash(0.45) : Theme.zoneColors[ribbon.history[index] - 1])
                           : (index === ribbon.history.length ? (screen.zonesNeutral ? Theme.accent : Theme.zoneColors[Theme.powerZone(screen.source.power, screen.source.ftp) - 1]) : Theme.floating)
                }
            }
            Accessible.ignored: true
        }

        // hint, undo and toast share one place above the ribbon
        Text {
            x: ribbon.x
            y: ribbon.y - 20 - height
            width: Math.min(400, stage.leftRoom)
            visible: !screen.touched && screen.editing < 0 && !screen.idle
            text: screen.levelControls ? qsTr("Tap any number to change it. Level buttons push you through the zones.")
                                       : qsTr("Tap any number to change it. Hold End when the ride is done.")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(12)
            wrapMode: Text.WordWrap
        }

        // paused, with the ride controls in the dock: say what the two ways on are
        Text {
            x: ribbon.x
            y: ribbon.y - 20 - height
            width: Math.min(420, ribbon.width)
            visible: !screen.levelControls && screen.source.paused && !screen.stopped && screen.editing < 0
                     && screen.toastText === "" && screen.undoState === null && !screen.confirmingEnd
            text: screen.bikeLost ? qsTr("Bike lost. The ride is paused while Bikemodo finds it again.")
                  : screen.autoPaused ? qsTr("Paused while you stopped. Pedal to go on, or hold End to finish.")
                  : qsTr("Paused. Resume and this stays one ride, or hold End to finish it.")
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(14)
            wrapMode: Text.WordWrap
        }

        // the room at the left above the ribbon, next to Lap and End in portrait
        readonly property real leftRoom: screen.portrait ? ribbon.width - (lapEnd.visible ? lapEnd.width + 16 : 0)
                                                         : heroButton.width
        // the top of the bars above the ribbon: a toast or the undo sits above them
        readonly property real barsTop: Math.min(ribbon.y - 6, pausedBar.visible ? pausedBar.y : ribbon.y,
                                                 confirmBar.visible ? confirmBar.y : ribbon.y)

        Rectangle {
            id: snack
            x: ribbon.x
            y: stage.barsTop - 10 - height
            width: Math.min(340, stage.leftRoom)
            height: 48
            radius: 18
            color: Theme.text
            visible: screen.undoState !== null && screen.editing < 0 && screen.toastText === ""
            Text {
                x: 16
                width: parent.width - undoButton.width - 30
                anchors.verticalCenter: parent.verticalCenter
                text: screen.undoState ? screen.undoState.message : ""
                color: Theme.inverseText
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(13)
                elide: Text.ElideRight
            }
            PulseButton {
                id: undoButton
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: 72
                height: 48
                // 36 to see, 48 to touch
                topInset: 6
                bottomInset: 6
                fill: Theme.accentInk
                Accessible.name: qsTr("Undo")
                onClicked: screen.undo()
                contentItem: Text {
                    text: qsTr("Undo")
                    color: Theme.accent
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(13)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            x: ribbon.x
            y: stage.barsTop - 12 - height
            readonly property real room: stage.leftRoom
            width: Math.min(toastLabel.implicitWidth, room - 32) + 32
            height: Math.max(40, toastLabel.height + 22)
            radius: 18
            color: Theme.pressed
            visible: screen.toastText !== "" && screen.editing < 0
            Text {
                id: toastLabel
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.room - 32)
                text: screen.toastText
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(13)
                wrapMode: Text.WordWrap
            }
        }

        // Lap and a held End, for the layout with the level dock (the ride controls have their own):
        // in the top bar in landscape, above the ribbon at the right in portrait. The paused bar
        // takes over while paused.
        Row {
            id: lapEnd
            x: screen.portrait ? ribbon.x + ribbon.width - width : topBar.x + presetPill.x - 10 - width
            y: screen.portrait ? ribbon.y - 16 - height : topBar.y + (topBar.height - height) / 2
            spacing: 8
            visible: screen.levelControls && !screen.stopped && !pausedBar.visible && !screen.confirmingEnd
                     && screen.editing < 0
            PulseButton {
                width: 64
                height: 48
                // 40 to see, 48 to touch
                topInset: 4
                bottomInset: 4
                fill: Theme.control
                Accessible.name: qsTr("Lap")
                onClicked: screen.lapRide()
                contentItem: Text {
                    text: qsTr("Lap")
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(13)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            HoldButton {
                width: 72
                height: 40
                fill: Theme.control
                fontSize: 13
                label: qsTr("End")
                holdingLabel: qsTr("Hold")
                onHeld: screen.endRide()
                onTapped: screen.toast(qsTr("Hold End to finish the ride."))
                onConfirmRequested: screen.askEnd()
            }
        }

        // paused, with the level dock: resume, or hold to end
        Rectangle {
            id: pausedBar
            visible: screen.levelControls && screen.source.paused && !screen.stopped && screen.editing < 0
                     && !screen.confirmingEnd
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
                    height: 48
                    // 46 to see, 48 to touch
                    topInset: 1
                    bottomInset: 1
                    fill: Theme.accent
                    pressedRadius: 16
                    Accessible.name: qsTr("Resume ride")
                    onClicked: screen.pauseResume()
                    contentItem: Text {
                        text: qsTr("Resume")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(15)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                HoldButton {
                    width: 140
                    height: 46
                    label: qsTr("Hold to end")
                    onHeld: screen.endRide()
                    onTapped: screen.toast(qsTr("Hold to end the ride."))
                    onConfirmRequested: screen.askEnd()
                }
            }
        }

        // End without a hold (a screen reader): one more step before the ride is saved
        Rectangle {
            id: confirmBar
            x: ribbon.x
            y: ribbon.y - 12 - height
            width: Math.min(ribbon.width, confirmRow.implicitWidth + 32)
            height: 56
            radius: 28
            color: Theme.floating
            visible: screen.confirmingEnd && !screen.stopped && screen.editing < 0
            Row {
                id: confirmRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("End this ride?")
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(15)
                    rightPadding: 6
                }
                PulseButton {
                    width: 110
                    height: 48
                    // 44 to see, 48 to touch
                    topInset: 2
                    bottomInset: 2
                    fill: Theme.accent
                    pressedRadius: 16
                    Accessible.name: qsTr("End ride")
                    onClicked: screen.endRide()
                    contentItem: Text {
                        text: qsTr("End ride")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(14)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                PulseButton {
                    width: 110
                    height: 48
                    // 44 to see, 48 to touch
                    topInset: 2
                    bottomInset: 2
                    fill: Theme.chip
                    pressedRadius: 16
                    Accessible.name: qsTr("Keep riding")
                    onClicked: screen.confirmingEnd = false
                    contentItem: Text {
                        text: qsTr("Keep riding")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(14)
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
            onClicked: screen.mainControl()
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
                        font.pixelSize: Theme.fs(17)
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

    // only a zone the screen shows crosses: none while power zones need an FTP
    onShownZoneChanged: {
        if (lastZone > 0 && lastZone !== shownZone && !inWorkout && !idle && startPhase === "")
            cue(0, "")
        if (lastZone > 0 && lastZone !== shownZone)
            cross(lastZone, hero.value, hero.unit)
        lastZone = shownZone
    }
}
