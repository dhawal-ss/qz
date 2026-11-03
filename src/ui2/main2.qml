import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15
import Qt.labs.settings 1.0
import AndroidStatusBar 1.0
import "."
import "rides"

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
        // QZ starts recording as soon as the bike connects; Bikemodo waits for Start ride
        property bool pause_on_start: false
        // QZ saves the ride when the app closes only with this on
        property bool fit_file_saved_on_quit: false
    }

    // once, on the first start of Bikemodo: rides begin when the rider presses Start ride, so
    // the first ride does not include the time before it (the rider can still change it).
    // And once: a ride still open when the app closes is saved, not lost (the library keeps only
    // one ride when it is saved again later).
    Settings {
        id: firstRun
        category: "ui2"
        property bool pauseOnStartSet: false
        property bool saveOnQuitSet: false
    }
    Component.onCompleted: {
        if (!firstRun.pauseOnStartSet) {
            qzSettings.pause_on_start = true
            qzSettings.sync()
            firstRun.pauseOnStartSet = true
        }
        if (!firstRun.saveOnQuitSet) {
            qzSettings.fit_file_saved_on_quit = true
            qzSettings.sync()
            firstRun.saveOnQuitSet = true
        }
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

    // back to the app from a ride that is paused or has not started: it stays as it is, and the
    // Ride button comes back to it (a demo is left behind, the next one starts fresh)
    function leaveRide() {
        if (mode === "demo")
            demoRide.running = false
        mode = "home"
    }

    // a ride with time on it that has not ended: closing the app first asks to end and save it
    readonly property bool rideOpen: live.elapsed > 0 && !live.stopped
    property bool askingToClose: false

    // Android back: close the launcher or the summary, step back in the app, leave a ride only
    // while it is paused or not started (never a moving one), and on Today ask for a second
    // press within 2 s before closing, as QZ does; with a ride still open, ask about it instead
    onClosing: {
        if (Qt.platform.os !== "android")
            return
        if (askingToClose) {
            askingToClose = false
            close.accepted = false
        } else if (mode === "launcher" || mode === "summary") {
            mode = "home"
            close.accepted = false
        } else if (mode === "ride" || mode === "demo") {
            close.accepted = false
            var shown = mode === "demo" ? demoRide : live
            if (shown.paused || shown.stopped)
                leaveRide()
        } else if (shell.goBack()) {
            close.accepted = false
        } else if (rideOpen) {
            close.accepted = false
            askingToClose = true
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
    }

    // whether the last bike that connected measures its watts or works them out: You marks FTP as
    // estimated from it while no bike is there
    Settings {
        id: powerMemory
        category: "ui2"
        property bool lastPowerEstimated: false
        property bool unknownPowerAssigned: false
    }
    Connections {
        target: live
        function onConnectedChanged() {
            if (live.connected) {
                powerMemory.lastPowerEstimated = live.powerEstimated
                if (!powerMemory.unknownPowerAssigned)
                    assignPower.restart()
            }
        }
        function onPowerEstimatedChanged() { if (live.connected) powerMemory.lastPowerEstimated = live.powerEstimated }
    }
    // once: the rides read before the library kept their power source are taken as this bike's, so
    // they stay in its power curve and records. 10 s after it connects, when it has said how it
    // gets its watts.
    Timer {
        id: assignPower
        interval: 10000
        onTriggered: {
            if (!live.connected || window.libraryObject === null || powerMemory.unknownPowerAssigned)
                return
            window.libraryObject.assignUnknownPower(live.powerEstimated)
            powerMemory.unknownPowerAssigned = true
        }
    }
    // a new FTP: the training load, zones and form of every ride are worked out again with it
    Connections {
        target: Theme
        // after Theme.setFtp has saved it, so the library reads the new one
        function onFtpChanged() {
            Qt.callLater(function () {
                if (window.libraryObject !== null)
                    window.libraryObject.rebuild()
            })
        }
    }

    // power curves and records are this bike's kind: estimated watts with estimated ones only
    Binding {
        target: window.libraryObject
        when: window.libraryObject !== null
        property: "powerGroup"
        value: powerMemory.lastPowerEstimated ? 1 : 0
    }

    RideSim {
        id: demoRide
        running: false
        miles: qzSettings.miles_unit
    }

    // endedAt: when a ride ended while paused, the time it was paused (its file ends there; the
    // summary finds the saved ride by its end), else 0
    function copyRide(source) {
        return {
            elapsed: source.elapsed, avgPower: source.avgPower, normalizedPower: source.normalizedPower,
            tss: source.tss, kilojoules: source.kilojoules, calories: source.calories,
            distance: source.distance, miles: source.miles, powerEstimated: source.powerEstimated,
            endedAt: source.paused === true && source.pausedAt > 0 ? source.pausedAt : 0
        }
    }

    function openDemo() {
        demoRide.restart()
        // stopped, so the ride screen shows Start ride and its 3, 2, 1 countdown
        demoRide.stop()
        mode = "demo"
    }

    // End ride: the numbers are copied before the engine stops (a stopped ride reads as zeros),
    // and only a ride that is still going is ended, so a second End or a late stop request
    // cannot save it twice or show an empty summary
    function finishRide() {
        if (mode === "demo") {
            if (demoRide.stopped)
                return
            finishedDemo = true
            finishedRide = copyRide(demoRide)
            demoRide.end()
            mode = "summary"
            return
        }
        live.refresh()
        if (live.stopped)
            return
        finishedDemo = false
        finishedRide = copyRide(live)
        finishing = true
        live.end()
        finishing = false
        // with the effort question on, the ride is saved only by finalizeFitSave
        if (core !== null && core.rpeFeelPopupEnabled())
            core.finalizeFitSave(-1, -1)
        if (core !== null)
            core.save_screenshot()
        mode = "summary"
    }

    // the engine ended the ride by itself (a workout program at its end, the bike's own stop
    // button, the web page), on the ride screen or while the rider was elsewhere in the app: save it
    // and show its summary as End would, from rideMetrics, which still holds the totals (LiveSource
    // reads zeros once stopped). finishRide sets finishing while it ends one.
    property bool finishing: false
    Connections {
        target: live
        function onStoppedChanged() {
            if (!live.stopped || window.finishing || window.mode === "demo" || window.metricsObject === null
                    || window.metricsObject.elapsed <= 0)
                return
            window.finishedDemo = false
            window.finishedRide = window.copyRide(window.metricsObject)
            if (window.core !== null && window.core.rpeFeelPopupEnabled())
                window.core.finalizeFitSave(-1, -1)
            if (window.core !== null)
                window.core.save_screenshot()
            window.mode = "summary"
        }
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
            // a ride paused and left: Today and the Ride button offer to go back to it
            ridePaused: live.paused && !live.stopped && live.elapsed > 0 && window.mode === "home"
            pausedAt: live.pausedAt
            onRideRequested: window.requestRide()
            onEndRideRequested: window.finishRide()
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
                    onLeaveRequested: window.leaveRide()
                }
            }

            RideSummary {
                anchors.fill: parent
                visible: window.mode === "summary"
                ride: window.finishedRide
                demo: window.finishedDemo
                library: window.libraryObject
                core: window.core
                onDone: window.mode = "home"
                onOpenRide: {
                    window.mode = "home"
                    shell.openRide(id)
                }
                onPlanWeek: {
                    window.mode = "home"
                    shell.tab = "goals"
                    shell.openGoalSetup()
                }
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

    // Back on Today with a ride still open: end and save it, or keep it and stay
    JoinSheet {
        anchors.fill: parent
        open: window.askingToClose && window.rideOpen && window.mode === "home"
        bottomInset: insets.insetBottom
        title: qsTr("Your ride is still open")
        words: qsTr("End it to save it before you close Bikemodo. Cancel keeps it paused, ready to resume.")
        confirmText: qsTr("End and save")
        onConfirm: {
            window.askingToClose = false
            window.finishRide()
        }
        onClose: window.askingToClose = false
    }
}
