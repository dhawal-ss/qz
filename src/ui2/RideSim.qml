import QtQuick 2.15

// A demo ride: the same properties as LiveSource, made up from the level the rider picks.
// Used by "Try the ride screen" before a bike is paired, and to check the screens without one.
QtObject {
    id: sim

    // the ride source interface
    property real power: 0
    property real heartRate: 0
    property real cadence: 92
    property int level: 16
    property int levelMax: 32
    property int elapsed: 0
    property real calories: 0
    property real distance: 0
    property real speed: 0
    property real normalizedPower: 0
    property real avgPower: 0
    property real kilojoules: 0
    property real tss: 0
    property real ftp: 207
    property real maxHeartRate: 190
    property int plannedSeconds: 2700
    property bool miles: false
    property bool powerEstimated: true
    property string heartSource: ""
    property bool running: true
    property bool paused: false
    property bool stopped: false
    property bool connected: true
    property string deviceName: "ECH-SPORT demo"
    property var powerTrail: []
    property var heartTrail: []
    property var cadenceTrail: []
    // power zone of every 30 s of the ride
    property var zoneHistory: []

    // demo settings
    property int startAt: 0
    property bool frozen: false

    property var _rolling: []
    property real _fourthSum: 0
    property int _fourthCount: 0
    property real _powerSum: 0

    // a fresh demo ride from zero
    function restart() {
        elapsed = 0
        calories = 0
        distance = 0
        normalizedPower = 0
        avgPower = 0
        kilojoules = 0
        tss = 0
        heartRate = 0
        powerTrail = []
        heartTrail = []
        cadenceTrail = []
        zoneHistory = []
        _rolling = []
        _fourthSum = 0
        _fourthCount = 0
        _powerSum = 0
        paused = false
        stopped = false
        running = true
        step(0, false)
    }

    function levelUp() {
        if (level < levelMax)
            level++
    }
    function levelDown() {
        if (level > 1)
            level--
    }
    function togglePause() {
        if (stopped) {
            restart()
            return
        }
        paused = !paused
    }
    function stop() {
        running = false
        stopped = true
    }
    function lap() {
    }

    function targetPower() {
        return 54 + 9 * level
    }

    function zoneOf(watts) {
        var starts = [0.555, 0.755, 0.905, 1.055, 1.205, 1.505]
        var zone = 1
        for (var i = 0; i < starts.length; i++) {
            if (watts >= Math.round(ftp * starts[i]))
                zone = i + 2
        }
        return zone
    }

    function push(list, value, keep) {
        var copy = list.slice(Math.max(0, list.length - keep + 1))
        copy.push(value)
        return copy
    }

    function step(seconds, wobble) {
        var target = targetPower()
        power = Math.max(0, target + (wobble ? Math.round(Math.sin(elapsed / 7) * 4) : 0))
        cadence = 92 + (wobble ? Math.round(Math.sin(elapsed / 11) * 2) : 0)
        var hrTarget = 95 + 3.5 * level
        heartRate = heartRate <= 0 ? hrTarget : heartRate + (hrTarget - heartRate) * 0.08
        if (seconds <= 0)
            return
        elapsed += seconds

        _powerSum += power * seconds
        avgPower = _powerSum / Math.max(1, elapsed)
        kilojoules = _powerSum / 1000
        calories = kilojoules * 0.95
        speed = 3.6 * Math.pow(power / 0.3, 1 / 3)
        distance += speed * seconds / 3600

        _rolling = push(_rolling, power, 30)
        var mean = 0
        for (var i = 0; i < _rolling.length; i++)
            mean += _rolling[i]
        mean /= _rolling.length
        _fourthSum += Math.pow(mean, 4) * seconds
        _fourthCount += seconds
        normalizedPower = Math.pow(_fourthSum / _fourthCount, 0.25)
        var intensity = normalizedPower / ftp
        tss = elapsed * normalizedPower * intensity / (ftp * 3600) * 100

        powerTrail = push(powerTrail, power, 60)
        heartTrail = push(heartTrail, heartRate, 60)
        cadenceTrail = push(cadenceTrail, cadence, 60)
        if (elapsed % 30 === 0)
            zoneHistory = push(zoneHistory, zoneOf(power), 400)
    }

    // fast forward a believable ride up to startAt: warm up, three blocks and the current level
    function warmUp() {
        var plan = [10, 10, 10, 10, 10, 10, 13, 13, 13, 13, 16, 16, 16, 16, 13, 13, 10, 10, 13, 13,
                    16, 16, 16, 16, 16, 16, 19, 19, 16, 16, 13, 13, 10, 10, 13, 13, 16, 16, 16, 16]
        var keep = level
        for (var t = 0; t < startAt; t++) {
            var block = Math.floor(t / 30)
            level = block < plan.length ? plan[block] : keep
            step(1, true)
        }
        level = keep
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: sim.running && !sim.paused && !sim.frozen
        onTriggered: sim.step(1, true)
    }

    Component.onCompleted: {
        warmUp()
        step(0, false)
    }
}
