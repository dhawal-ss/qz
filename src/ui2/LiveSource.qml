import QtQuick 2.15

// The ride as the engine sees it: the numbers of rideMetrics (src/ridemetrics.h) and the
// controls of the home object. Same properties as RideSim.
QtObject {
    id: live

    // rideMetrics, rootItem and the object named "home" of main2.qml
    property var metrics: null
    property var core: null
    property var home: null

    readonly property bool ready: metrics !== null
    readonly property real power: ready ? metrics.power : 0
    readonly property real heartRate: ready ? metrics.heartRate : 0
    readonly property real cadence: ready ? metrics.cadence : 0
    readonly property int level: ready ? metrics.level : 0
    readonly property int levelMax: ready ? metrics.levelMax : 32
    readonly property int elapsed: ready ? metrics.elapsed : 0
    readonly property real calories: ready ? metrics.calories : 0
    readonly property real distance: ready ? metrics.distance : 0
    readonly property real speed: ready ? metrics.speed : 0
    readonly property real normalizedPower: ready ? metrics.normalizedPower : 0
    readonly property real avgPower: ready ? metrics.avgPower : 0
    readonly property real kilojoules: ready ? metrics.kilojoules : 0
    readonly property real tss: ready ? metrics.tss : 0
    readonly property real ftp: ready ? metrics.ftp : 200
    readonly property real maxHeartRate: ready ? metrics.maxHeartRate : 190
    readonly property int plannedSeconds: 0
    readonly property bool miles: ready ? metrics.miles : false
    readonly property bool powerEstimated: ready ? metrics.powerEstimated : false
    readonly property string heartSource: ""
    readonly property bool connected: ready ? metrics.connected : false
    readonly property string deviceName: ready ? metrics.deviceName : ""
    readonly property var powerTrail: ready ? metrics.powerTrail : []
    readonly property var heartTrail: ready ? metrics.heartTrail : []
    readonly property var cadenceTrail: ready ? metrics.cadenceTrail : []
    readonly property var zoneHistory: ready ? metrics.zoneHistory : []

    // homeform keeps these as plain fields, read them with every update
    property bool paused: false
    property bool stopped: false
    readonly property bool running: !stopped

    property Connections watcher: Connections {
        target: live.metrics
        ignoreUnknownSignals: true
        function onUpdated() {
            if (live.core !== null) {
                live.paused = live.core.ridePaused()
                live.stopped = live.core.rideStopped()
            }
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
    // Start pauses a running ride and resumes a paused one
    function togglePause() {
        if (home)
            home.start_clicked()
        if (core) {
            paused = core.ridePaused()
            stopped = core.rideStopped()
        }
    }
    function stop() {
        if (home)
            home.stop_clicked()
    }
    function lap() {
        if (home)
            home.lap_clicked()
    }
}
