import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15
import Qt.labs.settings 1.0
import AndroidStatusBar 1.0
import "."

// The root of Bikemodo, loaded by main.cpp instead of QZ's main.qml.
// homeform connects to the signals of this window and of the object named "home" by name,
// so both declare the same signals as main.qml and Home.qml, with the same types.
ApplicationWindow {
    id: window
    objectName: "stack"
    visible: true
    width: 915
    height: 412
    title: "Bikemodo"
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

    // rootItem, rideMetrics and rideLibrary are set by homeform after this file loads
    property var core: null
    property var metricsObject: null
    property var libraryObject: null

    // home (the app), launcher (finding the bike before a ride), ride, demo or summary
    property string mode: "home"
    property var finishedRide: ({})
    property bool finishedDemo: false

    Timer {
        interval: 200
        repeat: true
        running: window.core === null || window.metricsObject === null || window.libraryObject === null
        triggeredOnStart: true
        onTriggered: {
            if (typeof rootItem !== "undefined")
                window.core = rootItem
            if (typeof rideMetrics !== "undefined")
                window.metricsObject = rideMetrics
            if (typeof rideLibrary !== "undefined")
                window.libraryObject = rideLibrary
        }
    }

    // QZ's own settings, read by the app around the ride
    Settings {
        id: qzSettings
        property bool miles_unit: false
        property string user_nickname: ""
        // Bikemodo has no embedded sign-in page: Strava and intervals.icu open in the browser
        property bool strava_auth_external_webbrowser: false
    }

    function connectInBrowser() {
        qzSettings.strava_auth_external_webbrowser = true
        // homeform reads it right away
        qzSettings.sync()
    }

    // Bikemodo's own preferences; reduce motion is set in You
    Settings {
        id: uiSettings
        category: "ui2"
        property bool reduceMotion: false
    }
    Binding {
        target: Theme
        property: "reduceMotion"
        value: uiSettings.reduceMotion
    }

    // system bars and the camera cutout in dp, from QZ's AndroidStatusBar (CustomQtActivity.java
    // sends them). Same rules as main.qml: Android 12 and later draw under the bars, and in
    // landscape the cutout counts too so content stays clear of the camera.
    QtObject {
        id: insets
        readonly property bool active: Qt.platform.os === "android" && AndroidStatusBar.apiLevel >= 31
        readonly property bool landscape: Screen.orientation === Qt.LandscapeOrientation
                                          || Screen.orientation === Qt.InvertedLandscapeOrientation
        readonly property int insetTop: active ? AndroidStatusBar.height : 0
        readonly property int insetBottom: active ? AndroidStatusBar.navigationBarHeight : 0
        readonly property int insetLeft: active && landscape ? AndroidStatusBar.leftInset : 0
        readonly property int insetRight: active && landscape ? AndroidStatusBar.rightInset : 0
    }

    // the Ride button: straight into the ride once the bike is there, else find it first
    function requestRide() {
        mode = live.connected ? "ride" : "launcher"
    }

    // Android back: close the launcher or the summary, step back in the app, never leave a ride,
    // and on Today ask for a second press within 2 s before closing, as QZ does
    onClosing: {
        if (Qt.platform.os !== "android")
            return
        if (mode === "launcher" || mode === "summary") {
            mode = "home"
            close.accepted = false
        } else if (mode === "ride" || mode === "demo") {
            close.accepted = false
        } else if (shell.goBack()) {
            close.accepted = false
        } else if (!backToExit.running) {
            close.accepted = false
            backToExit.start()
        }
    }

    Timer {
        id: backToExit
        interval: 2000
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
        onConnectedChanged: if (connected && window.mode === "launcher") window.mode = "ride"
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
            running: window.core !== null && (window.mode === "home" || window.mode === "launcher")
            triggeredOnStart: true
            onTriggered: home.searchStatus = window.core.bluetoothSearchStatus()
        }

        AppShell {
            id: shell
            anchors.fill: parent
            visible: window.mode === "home"
            library: window.libraryObject
            core: window.core
            metrics: window.metricsObject
            connected: live.connected
            deviceName: live.deviceName
            searchStatus: home.searchStatus
            miles: qzSettings.miles_unit
            nickname: qzSettings.user_nickname
            insetTop: insets.insetTop
            insetBottom: insets.insetBottom
            insetLeft: insets.insetLeft
            insetRight: insets.insetRight
            onRideRequested: window.requestRide()
            onDemoRequested: window.openDemo()
            onSearchAgain: if (window.core !== null) window.core.bluetoothSearchNow()
            onRestartRequested: window.restart()
            onStravaConnect: { window.connectInBrowser(); window.strava_connect_clicked() }
            onPelotonConnect: window.peloton_connect_clicked()
            onIntervalsConnect: { window.connectInBrowser(); window.intervalsicu_connect_clicked() }
            onRefreshDevices: window.refresh_bluetooth_devices_clicked()
        }

        // the ride and the screens around it keep clear of the system bars and the cutout
        Item {
            id: safe
            x: insets.insetLeft
            y: insets.insetTop
            width: parent.width - insets.insetLeft - insets.insetRight
            height: parent.height - insets.insetTop - insets.insetBottom

            StartScreen {
                anchors.fill: parent
                visible: window.mode === "launcher"
                connected: live.connected
                deviceName: live.deviceName
                searchStatus: home.searchStatus
                rideInProgress: live.elapsed > 0 && !live.stopped
                onOpenRide: window.mode = "ride"
                onOpenDemo: window.openDemo()
                onSearchAgain: if (window.core !== null) window.core.bluetoothSearchNow()
                onCloseRequested: window.mode = "home"
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
                onDone: window.mode = "home"
            }
        }
    }

    // "Press back again to exit"
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - insets.insetBottom - 110 - height
        width: exitText.implicitWidth + 36
        height: 44
        radius: 22
        color: Theme.floating
        opacity: backToExit.running ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        Text {
            id: exitText
            anchors.centerIn: parent
            text: qsTr("Press back again to exit")
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: 14
        }
    }
}
