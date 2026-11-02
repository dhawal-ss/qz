import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15
import Qt.labs.settings 1.0
import "."

// The root of the Pulse interface, used instead of main.qml when pulse_ui_enabled is on.
// homeform connects to the signals of this window and of the object named "home" by name,
// so both declare the same signals as main.qml and Home.qml, with the same types.
ApplicationWindow {
    id: window
    objectName: "stack"
    visible: true
    width: 915
    height: 412
    title: "qDomyos-Zwift"
    color: Theme.bg

    signal gpx_open_clicked(url name)
    signal gpxpreview_open_clicked(url name)
    signal profile_open_clicked(url name)
    signal trainprogram_open_clicked(url name)
    signal fitfile_preview_clicked(url name)
    signal trainprogram_open_other_folder(url name)
    signal gpx_open_other_folder(url name)
    signal trainprogram_preview(url name)
    signal trainprogram_zwo_loaded(string s)
    signal trainprogram_autostart_requested()
    signal fitfile_preview(string s)
    signal gpx_save_clicked()
    signal fit_save_clicked()
    signal refresh_bluetooth_devices_clicked()
    signal strava_connect_clicked()
    signal peloton_connect_clicked()
    signal intervalsicu_connect_clicked()
    signal intervalsicu_download_todays_workout_clicked()
    signal loadSettings(url name)
    signal saveSettings(url name)
    signal deleteSettings(url name)
    signal restoreSettings()
    signal saveProfile(string profilename)
    signal restart()
    signal volumeUp()
    signal volumeDown()
    signal keyMediaPrevious()
    signal keyMediaNext()
    signal floatingOpen()
    signal openFloatingWindowBrowser()
    signal strava_upload_file_prepare()

    // rootItem and rideMetrics are set by homeform after this file loads
    property var core: null
    property var metricsObject: null

    // start, ride, demo or summary
    property string mode: "start"
    property var finishedRide: ({})
    property bool finishedDemo: false

    Timer {
        interval: 200
        repeat: true
        running: window.core === null || window.metricsObject === null
        triggeredOnStart: true
        onTriggered: {
            if (typeof rootItem !== "undefined")
                window.core = rootItem
            if (typeof rideMetrics !== "undefined")
                window.metricsObject = rideMetrics
        }
    }

    Settings {
        id: interfaceSetting
        property bool pulse_ui_enabled: true
    }

    // homeform drives this player when a workout comes with a video
    MediaPlayer {
        objectName: "videoplaybackhalf"
        autoPlay: false
    }

    LiveSource {
        id: live
        metrics: window.metricsObject
        core: window.core
        home: home
        onConnectedChanged: if (connected && window.mode === "start") window.mode = "ride"
    }

    RideSim {
        id: demoRide
        running: false
    }

    function copyRide(source) {
        return {
            elapsed: source.elapsed, avgPower: source.avgPower, normalizedPower: source.normalizedPower,
            tss: source.tss, kilojoules: source.kilojoules, calories: source.calories,
            distance: source.distance, miles: source.miles, powerEstimated: source.powerEstimated
        }
    }

    function openDemo() {
        demoRide.restart()
        mode = "demo"
    }

    function finishRide() {
        finishedDemo = mode === "demo"
        if (finishedDemo) {
            finishedRide = copyRide(demoRide)
            demoRide.running = false
            mode = "summary"
            return
        }
        finishedRide = copyRide(live)
        home.stop_clicked()
        // with the effort question on, the ride is saved only by finalizeFitSave
        if (core !== null && core.rpeFeelPopupEnabled())
            core.finalizeFitSave(-1, -1)
        if (core !== null)
            core.save_screenshot()
        mode = "summary"
    }

    // the web page, a keyboard or a template can ask for a start or a stop
    Timer {
        interval: 200
        repeat: true
        running: window.core !== null
        onTriggered: {
            // homeform has started the ride already, show it
            if (window.core.startRequested) {
                window.core.startRequested = false
                window.core.stopRequested = false
                if (window.mode !== "demo")
                    window.mode = "ride"
            }
            if (window.core.stopRequested) {
                window.core.stopRequested = false
                if (window.mode === "ride")
                    window.finishRide()
                else
                    home.stop_clicked()
            }
        }
    }

    Item {
        id: home
        objectName: "home"
        anchors.fill: parent

        signal start_clicked()
        signal stop_clicked()
        signal lap_clicked()
        signal peloton_start_workout()
        signal peloton_abort_workout()
        signal plus_clicked(string name)
        signal minus_clicked(string name)
        signal largeButton_clicked(string name)

        property string searchStatus: ""

        Timer {
            interval: 1000
            repeat: true
            running: window.core !== null && window.mode === "start"
            triggeredOnStart: true
            onTriggered: home.searchStatus = window.core.bluetoothSearchStatus()
        }

        StartScreen {
            anchors.fill: parent
            visible: window.mode === "start"
            connected: live.connected
            deviceName: live.deviceName
            searchStatus: home.searchStatus
            rideInProgress: live.elapsed > 0 && !live.stopped
            onOpenRide: window.mode = "ride"
            onOpenDemo: window.openDemo()
            onSearchAgain: if (window.core !== null) window.core.bluetoothSearchNow()
            onUseClassic: {
                interfaceSetting.pulse_ui_enabled = false
                // written now: restart() quits right away
                interfaceSetting.sync()
                window.restart()
            }
        }

        Loader {
            anchors.fill: parent
            active: window.mode === "ride" || window.mode === "demo"
            sourceComponent: RideScreen {
                source: window.mode === "demo" ? demoRide : live
                onFinishRequested: window.finishRide()
            }
        }

        RideSummary {
            anchors.fill: parent
            visible: window.mode === "summary"
            ride: window.finishedRide
            demo: window.finishedDemo
            onDone: window.mode = "start"
        }
    }
}
