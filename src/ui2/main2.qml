import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15
import Qt.labs.settings 1.0
import AndroidStatusBar 1.0
import "."
import "rides"
import "onboarding"
import "goals/Streak.js" as Streak
import "Metrics.js" as Metrics

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

    // home (the app), setup (the first run), launcher (finding the bike before a ride), ride, demo or summary
    property string mode: "home"
    // the step of the first run: 0 name and units, 1 the bike, 2 power and heart, 3 the weekly goal
    property int setupStep: 0
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
        // the first run asks for it, for the estimated max heart rate
        property int age: 35
        // QZ keeps the screen on for as long as the app runs with this on; Bikemodo keeps it on
        // only on the ride screen (setKeepScreenOn), from the next start
        property bool android_wakelock: true
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
        // the first run setup: done (or skipped), and begun (it comes back if the app closed during it)
        property bool onboarded: false
        property bool onboardingStarted: false
        property bool wakeLockSet: false
    }

    // the first run of a new install shows the setup; an install that has been opened before
    // (app_opening counts the starts, main.cpp adds this one before the window loads) skips it
    function startSetupIfNew() {
        if (firstRun.onboarded)
            return
        var opens = Number(qzSettings.value("app_opening", 0)) || 0
        if (opens > 1 && !firstRun.onboardingStarted) {
            firstRun.onboarded = true
            return
        }
        firstRun.onboardingStarted = true
        setupStep = 0
        mode = "setup"
    }

    // the setup is over: to the bike and Start ride when it is there, else to Today
    function finishSetup() {
        firstRun.onboarded = true
        mode = live.connected ? "launcher" : "home"
    }

    function setupNext() {
        if (setupStep >= 3)
            finishSetup()
        else
            setupStep++
    }

    Component.onCompleted: {
        startSetupIfNew()
        if (!firstRun.wakeLockSet) {
            qzSettings.android_wakelock = false
            qzSettings.sync()
            firstRun.wakeLockSet = true
        }
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

    // the screen stays on while the ride screen shows, and may sleep everywhere else
    readonly property bool keepAwake: mode === "ride" || mode === "demo"
    onKeepAwakeChanged: if (core !== null) core.setKeepScreenOn(keepAwake)

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

    // After a reinstall the rides of the earlier install are still in the QZ folder, hidden from
    // this one (Android 14+): QZ notices it (a new history database) and offers once to copy them
    // in, with the folder picker. It waits for its workout page to be open; Bikemodo has none, so
    // it says so as soon as rootItem is there.
    property bool askingImport: false
    onCoreChanged: {
        if (core === null)
            return
        core.historyPageOpened()
        core.setKeepScreenOn(keepAwake)
    }
    Connections {
        target: window.core
        ignoreUnknownSignals: true
        function onHistoryRecoveryOfferRequested() { window.askingImport = true }
        // QZ's messages ("12 workouts imported", "No workout files found", ...)
        function onToastRequestedChanged(value) { if (value !== "") toastHost.show(value) }
        // imported rides have no power source: the next bike that connects gives them its own
        function onFitImportRunningChanged() {
            if (window.core.fitImportRunning)
                return
            powerMemory.unknownPowerAssigned = false
            if (live.connected)
                assignPower.restart()
        }
    }

    // Android back: close the launcher or the summary, step back in the app, leave a ride only
    // while it is paused or not started (never a moving one), and on Today ask for a second
    // press within 2 s before closing, as QZ does; with a ride still open, ask about it instead
    onClosing: {
        if (Qt.platform.os !== "android")
            return
        if (askingToClose || askingImport || askingDiscard) {
            askingToClose = false
            askingImport = false
            askingDiscard = false
            close.accepted = false
        } else if (mode === "setup") {
            if (setupStep > 0)
                setupStep--
            close.accepted = false
        } else if (mode === "launcher" || mode === "summary") {
            mode = "home"
            close.accepted = false
        } else if (mode === "ride" || mode === "demo") {
            close.accepted = false
            var shown = mode === "demo" ? demoRide : live
            if (shown.paused || shown.stopped)
                leaveRide()
            else if (rideLoader.item !== null)
                rideLoader.item.backPressed()
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
        // the FTP the library was last worked out with (rebuildLater)
        property real builtWithFtp: 0
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
        function onFtpChanged() { rebuildLater.restart() }
    }
    // Qt.labs.settings writes a changed value to QSettings only after its write delay (half a
    // second), and sync() does not hurry it: the library, which reads QSettings, waits for it
    Timer {
        id: rebuildLater
        interval: 1500
        onTriggered: {
            if (window.libraryObject === null)
                return
            window.libraryObject.rebuild()
            powerMemory.builtWithFtp = Theme.ftp
        }
    }
    // a rebuild cut short (the app closed) or read too early: the library is worked out again at
    // start when the FTP it was last worked out with is not the rider's
    onLibraryObjectChanged: {
        if (libraryObject !== null && Theme.ftpSet && Math.round(powerMemory.builtWithFtp) !== Math.round(Theme.ftp))
            rebuildLater.restart()
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
        // under a minute: save it, or let it go (askingDiscard)
        if (live.elapsed < 60 && !askingDiscard) {
            askingDiscard = true
            return
        }
        askingDiscard = false
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

    // End on a ride of less than a minute: Discard ends it without a file, Save it goes on as End
    property bool askingDiscard: false
    function discardRide() {
        askingDiscard = false
        live.refresh()
        if (live.stopped || core === null)
            return
        finishing = true
        core.discardRide()
        live.refresh()
        finishing = false
        mode = "home"
        toastHost.show(qsTr("Ride discarded"))
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
        // what keeps the search from working, the bike Bikemodo waits for and the last one connected,
        // read fresh: switchBike() and QZ write them in C++
        property string connectionProblem: ""
        property string chosenBike: "Disabled"
        property string lastBike: ""
        // the heart rate sensor chosen in You: not a bike, so not in the list of bikes
        property string heartBelt: ""
        // the devices the search has seen, by name, without "Disabled", "Wifi" and the signal strength
        readonly property var nearbyDevices: {
            var list = window.core !== null && window.core.bluetoothDevices ? window.core.bluetoothDevices : []
            var names = []
            for (var i = 0; i < list.length; i++) {
                var entry = list[i]
                var cut = entry.lastIndexOf(" (")
                var name = cut > 0 && entry.substring(entry.length - 2) === "%)" ? entry.substring(0, cut) : entry
                if (name !== "Disabled" && name !== "Wifi" && name !== home.heartBelt && names.indexOf(name) < 0)
                    names.push(name)
            }
            return names
        }

        Timer {
            interval: 1000
            repeat: true
            running: window.core !== null && (window.mode === "home" || window.mode === "launcher" || window.mode === "setup")
            triggeredOnStart: true
            onTriggered: {
                home.searchStatus = window.core.bluetoothSearchStatus()
                home.connectionProblem = live.connected ? "" : window.core.connectionProblem()
                home.chosenBike = String(qzSettings.value("filter_device", "Disabled"))
                home.lastBike = String(qzSettings.value("bluetooth_lastdevice_name", ""))
                home.heartBelt = String(qzSettings.value("heart_rate_belt_name", ""))
            }
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

            Onboarding {
                anchors.fill: parent
                visible: window.mode === "setup" && window.setupStep !== 1
                step: window.setupStep
                nickname: qzSettings.user_nickname
                miles: qzSettings.miles_unit
                age: qzSettings.age
                onNameChosen: qzSettings.user_nickname = name
                onMilesChosen: qzSettings.miles_unit = miles
                onAgeChosen: qzSettings.age = age
                onGoalChosen: {
                    firstRun.setValue("goalKind", goalKind)
                    firstRun.setValue(Streak.settingKeys[goalKind], goalValue)
                    window.finishSetup()
                }
                onNext: window.setupNext()
                onPrevious: if (window.setupStep > 0) window.setupStep--
                onSkipAll: window.finishSetup()
            }

            StartScreen {
                anchors.fill: parent
                visible: window.mode === "launcher" || (window.mode === "setup" && window.setupStep === 1)
                setup: window.mode === "setup"
                connected: live.connected
                deviceName: live.deviceName
                searchStatus: home.searchStatus
                rideInProgress: live.elapsed > 0 && !live.stopped
                problem: home.connectionProblem
                devices: home.nearbyDevices
                chosen: home.chosenBike
                lastDevice: home.lastBike
                onOpenRide: {
                    if (setup)
                        window.setupNext()
                    else
                        window.mode = "ride"
                }
                onOpenDemo: {
                    if (setup)
                        window.setupNext()
                    else
                        window.openDemo()
                }
                onSearchAgain: if (window.core !== null) window.core.bluetoothSearchNow()
                onFixProblem: if (window.core !== null) window.core.fixConnectionProblem()
                onChooseBike: {
                    if (window.core === null)
                        return
                    home.chosenBike = name
                    // QZ set to quit on a lost connection: the switch takes a restart
                    if (!window.core.switchBike(name))
                        window.restart()
                }
                onCloseRequested: {
                    if (setup)
                        window.setupStep = 0
                    else
                        window.mode = "home"
                }
            }

            Loader {
                id: rideLoader
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

    // a message from QZ, for a few seconds over the navigation
    Rectangle {
        id: toastHost
        function show(text) {
            toastText.text = text
            toastTimer.restart()
        }
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - insets.insetBottom - 110 - height
        width: Math.min(parent.width - 32, toastText.implicitWidth + 36)
        height: toastText.height + 24
        radius: 22
        color: Theme.floating
        opacity: toastTimer.running && !backToExit.running ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        Accessible.role: Accessible.AlertMessage
        Accessible.name: toastText.text
        Timer {
            id: toastTimer
            interval: 3500
        }
        Text {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.parent.width - 68)
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // the rides of an earlier install: copy them in through the folder picker, or not now
    JoinSheet {
        anchors.fill: parent
        open: window.askingImport && window.mode === "home"
        bottomInset: insets.insetBottom
        title: qsTr("Rides from before")
        words: qsTr("Rides of an earlier install may still be in the QZ folder, where this one cannot see them. In the next window, allow access to that folder and Bikemodo copies them in.")
        confirmText: qsTr("Find my rides")
        onConfirm: {
            window.askingImport = false
            if (window.core !== null)
                window.core.importFitFolder()
        }
        onClose: window.askingImport = false
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

    // End on a ride of less than a minute: let it go, or save it as any other (also a tap outside)
    JoinSheet {
        anchors.fill: parent
        open: window.askingDiscard
        bottomInset: insets.insetBottom
        title: qsTr("Save a ride this short?")
        words: qsTr("It is under a minute. Discard leaves no ride behind, Save it keeps it with the others.")
        confirmText: qsTr("Discard")
        cancelText: qsTr("Save it")
        onConfirm: window.discardRide()
        onClose: if (window.askingDiscard) window.finishRide()
    }
}
