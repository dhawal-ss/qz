import QtQuick 2.15

// The ride as the engine sees it: the numbers of rideMetrics (src/ridemetrics.h) and the
// controls of the home object. Same properties as RideSim.
//
// The ride lifecycle of homeform: Start() pauses a running ride, resumes a paused one and, on a
// stopped engine, clears the session and begins a new ride. Stop() ends the ride and saves it.
// So pause and resume below only ever call Start() on an engine that is not stopped, and only
// begin() may call it on a stopped one.
QtObject {
    id: live

    // rideMetrics, rootItem and the object named "home" of main2.qml
    property var metrics: null
    property var core: null
    property var home: null

    readonly property bool ready: metrics !== null

    // homeform keeps these as plain fields, read them with every update and after every command
    property bool paused: false
    property bool stopped: false
    readonly property bool running: !stopped

    // the device keeps the totals of a finished ride until the next one begins (homeform Start
    // clears them), and rideMetrics keeps its NP and TSS a second longer: a ride that has not
    // begun shows zeros instead
    readonly property bool fresh: !ready || stopped || metrics.elapsed <= 0

    readonly property real power: ready ? metrics.power : 0
    readonly property real heartRate: ready ? metrics.heartRate : 0
    readonly property real cadence: ready ? metrics.cadence : 0
    readonly property int level: ready ? metrics.level : 0
    readonly property int levelMax: ready ? metrics.levelMax : 32
    readonly property int elapsed: fresh ? 0 : metrics.elapsed
    readonly property real calories: fresh ? 0 : metrics.calories
    readonly property real distance: fresh ? 0 : metrics.distance
    readonly property real speed: ready ? metrics.speed : 0
    readonly property real normalizedPower: fresh ? 0 : metrics.normalizedPower
    readonly property real avgPower: fresh ? 0 : metrics.avgPower
    readonly property real kilojoules: fresh ? 0 : metrics.kilojoules
    readonly property real tss: fresh ? 0 : metrics.tss
    readonly property real ftp: ready ? metrics.ftp : 200
    readonly property real maxHeartRate: ready ? metrics.maxHeartRate : 190
    readonly property int plannedSeconds: 0
    readonly property bool miles: ready ? metrics.miles : false
    readonly property bool powerEstimated: ready ? metrics.powerEstimated : false
    readonly property string heartSource: ""
    readonly property bool connected: ready ? metrics.connected : false
    readonly property string deviceName: ready ? metrics.deviceName : ""
    readonly property var powerTrail: fresh ? [] : metrics.powerTrail
    readonly property var heartTrail: fresh ? [] : metrics.heartTrail
    readonly property var cadenceTrail: fresh ? [] : metrics.cadenceTrail
    readonly property var zoneHistory: fresh ? [] : metrics.zoneHistory

    // whether the app can set the level of this bike (homeform.canChangeResistance)
    property bool canChangeResistance: true
    // laps pressed in this ride
    property int laps: 0
    // when the ride was paused (ms since the epoch), 0 while it is not
    property double pausedAt: 0
    onPausedChanged: pausedAt = paused ? Date.now() : 0

    function refresh() {
        if (core === null)
            return
        paused = core.ridePaused()
        stopped = core.rideStopped()
        // asked only while the bike is there, so a dropped connection does not swap the dock
        if (connected && typeof core.canChangeResistance === "function")
            canChangeResistance = core.canChangeResistance()
    }

    property Connections watcher: Connections {
        target: live.metrics
        ignoreUnknownSignals: true
        function onUpdated() {
            live.refresh()
        }
    }

    function levelUp() {
        if (home)
            home.plus_clicked("resistance_plus")
    }
    function levelDown() {
        if (home)
            home.minus_clicked("resistance_minus")
    }

    // a new ride, only from a stopped engine
    function begin() {
        refresh()
        if (home && stopped) {
            laps = 0
            home.start_clicked()
        }
        refresh()
    }
    // the same ride, held
    function pause() {
        refresh()
        if (home && !paused && !stopped)
            home.start_clicked()
        refresh()
    }
    // the same ride, going again; never a new one
    function resume() {
        refresh()
        if (home && paused && !stopped)
            home.start_clicked()
        refresh()
    }
    function togglePause() {
        refresh()
        if (stopped)
            begin()
        else if (paused)
            resume()
        else
            pause()
    }
    // ends and saves the ride; true when there was one to end
    function end() {
        refresh()
        if (!home || stopped)
            return false
        home.stop_clicked()
        refresh()
        return true
    }
    function stop() {
        end()
    }
    function lap() {
        if (stopped)
            return
        laps++
        if (home)
            home.lap_clicked()
    }
}
