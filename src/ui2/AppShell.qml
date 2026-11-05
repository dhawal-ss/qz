import QtQuick 2.15
import "."
import "sig"
import "goals"

// The app around the ride: Today, Rides, Progress and You, with Ride always one tap away, every
// one of them named (sig/FloatingNav): on compact windows (phones held upright) a bar across the
// bottom with Today, Rides, Ride in the middle, Progress and You; on wider windows a rail down the
// left with Ride on top. A tab switch fades through: the open page fades out quickly, then the
// new one fades in as it grows from 96%. The pages stay alive. The goals are one shared model
// (goals/GoalsModel.qml): the week lives on Today, the rest of the goals on Progress.
// The shell keeps clear of the system bars and the camera cutout with the insets it is given.
// Whenever a sheet or a full page covers the open tab (each page says so with `covering`), or the
// keyboard is up, the bottom bar steps aside: it slides down, and comes back after.
Item {
    id: shell

    property var library: null      // rideLibrary from C++, null in previews
    property var core: null         // rootItem
    property var metrics: null      // rideMetrics
    property bool connected: false
    property string deviceName: ""
    property string searchStatus: ""
    property bool miles: false
    property string nickname: ""
    property string tab: "today"
    // a live ride paused and left for the app: Today shows a banner, the Ride button a dot
    property bool ridePaused: false
    property real pausedAt: 0

    property int insetTop: 0
    property int insetBottom: 0
    property int insetLeft: 0
    property int insetRight: 0

    signal rideRequested()
    signal workoutRequested(var plan)
    signal workoutFileRequested()
    signal intervalsRequested()
    signal routeRequested(var route)
    signal routeFileRequested()
    // End on the paused ride banner of Today
    signal endRideRequested()
    signal demoRequested()
    signal searchAgain()
    signal restartRequested()
    signal stravaConnect()
    signal pelotonConnect()
    signal intervalsConnect()
    signal refreshDevices()
    // miles or kilometers picked in You; the shell already shows it, main2 may store it too
    signal unitsPicked(bool miles)

    readonly property bool rail: width >= 600
    // the room the rail takes on the left, right of the left inset
    readonly property int railWidth: nav.railWidth
    // what a page that scrolls under the bottom bar keeps free at its end, over the bottom inset:
    // the bar and a little room, so the last thing on a page is never under it
    readonly property int navClearance: rail ? 16 : nav.barHeight + 16
    readonly property string initial: nickname !== "" ? nickname.charAt(0).toUpperCase() : "B"

    // a sheet or a full page over the open tab. Pages say so with `covering`; Today and Progress
    // also count while they customize, or while a page of the goals is open over them, Rides
    // while a ride fills a phone screen. A page that lacks a property simply does not cover.
    function covers(page) {
        return page !== null && page !== undefined && (page.covering === true || page.customizing === true)
    }
    readonly property bool covering: {
        if (shownTab === "today")
            return covers(todayScreen)
        if (shownTab === "rides")
            return covers(rides) || (!rail && rides.detailOpen === true)
        if (shownTab === "progress")
            return covers(progressScreen)
        if (shownTab === "you")
            return covers(youLoader.item)
        return false
    }

    // Ride goes in the middle of them (sig/FloatingNav)
    readonly property var destinations: [
        { name: "today", label: qsTr("Today"), icon: "today" },
        { name: "rides", label: qsTr("Rides"), icon: "rides" },
        { name: "progress", label: qsTr("Progress"), icon: "progress" },
        { name: "you", label: qsTr("You"), icon: "you" }
    ]

    // the goals, shared by Today and Progress
    GoalsModel {
        id: goalsModel
        library: shell.library
        miles: shell.miles
    }

    // the fade through between tabs: the page on screen, the page fading out, and how far each is
    property string shownTab: ""
    property string leavingTab: ""
    property real leaveFade: 1
    property real enterFade: 1

    // Only the page on screen follows a window change (a rotation) at once; each hidden page keeps
    // its layout and catches up after, one at a time once the window has settled, or when it is
    // opened. Laying out all five pages at once kept the first frame after a turn from coming.
    property size todaySize: Qt.size(0, 0)
    property size ridesSize: Qt.size(0, 0)
    property size progressSize: Qt.size(0, 0)
    property size youSize: Qt.size(0, 0)
    readonly property var pageNames: ["today", "rides", "progress", "you"]

    function sizeOf(name) {
        return name === "today" ? todaySize : name === "rides" ? ridesSize : name === "progress" ? progressSize : youSize
    }
    function syncPage(name) {
        var now = Qt.size(pages.width, pages.height)
        var old = sizeOf(name)
        if (old.width === now.width && old.height === now.height)
            return false
        setSizeOf(name, now)
        return true
    }
    // behind a ride or the start screen no page is on screen: all of them catch up after
    // (a ride's live numbers never wait for them)
    onVisibleChanged: {
        if (!visible) {
            catchUp.stop()
            return
        }
        syncPage(shownTab !== "" ? shownTab : tab)
        catchUp.interval = 700
        catchUp.restart()
    }
    function pagesResized() {
        if (!visible)
            return
        catchUp.interval = 700
        catchUp.restart()
        syncPage(shownTab !== "" ? shownTab : tab)
        if (leavingTab !== "")
            syncPage(leavingTab)
    }
    // the hidden pages, one per tick once a rotation has settled
    Timer {
        id: catchUp
        interval: 700
        repeat: true
        onTriggered: {
            interval = 150
            for (var i = 0; i < shell.pageNames.length; i++) {
                if (shell.syncPage(shell.pageNames[i]))
                    return
            }
            interval = 700
            stop()
        }
    }

    function setSizeOf(name, size) {
        if (name === "today") todaySize = size
        else if (name === "rides") ridesSize = size
        else if (name === "progress") progressSize = size
        else youSize = size
    }

    onTabChanged: {
        syncPage(tab)
        if (tab === shownTab)
            return
        if (Theme.reduceMotion) {
            fadeThrough.stop()
            leavingTab = ""
            shownTab = tab
            leaveFade = 1
            enterFade = 1
            return
        }
        // a switch while a page is still fading in: that page leaves from where it got to
        var from = fadeThrough.running ? (leavingTab !== "" ? 0 : enterFade) : 1
        leavingTab = from > 0 ? shownTab : ""
        leaveFade = from
        shownTab = tab
        enterFade = 0
        fadeThrough.restart()
    }

    SequentialAnimation {
        id: fadeThrough
        NumberAnimation {
            target: shell
            property: "leaveFade"
            to: 0
            duration: 90
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.effectsCurve
        }
        PropertyAction { target: shell; property: "leavingTab"; value: "" }
        NumberAnimation {
            target: shell
            property: "enterFade"
            to: 1
            duration: 210
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.effectsCurve
        }
    }

    function pageShown(name) {
        return name === shownTab || name === leavingTab
    }
    function pageOpacity(name) {
        if (name === leavingTab)
            return leaveFade
        return name === shownTab ? enterFade : 0
    }
    function pageScale(name) {
        return name === shownTab ? 0.96 + 0.04 * enterFade : 1
    }

    // what a sheet or full page keeps free at its end: only the bottom inset, as the floating nav
    // steps aside while it is open. A page that declares `sheetClearance` gets it bound.
    readonly property real sheetClearance: insetBottom
    function bindSheetClearance(page) {
        if (page !== null && page !== undefined && page.sheetClearance !== undefined)
            page.sheetClearance = Qt.binding(function () { return shell.sheetClearance })
    }

    Component.onCompleted: {
        for (var p = 0; p < pageNames.length; p++)
            syncPage(pageNames[p])
        shownTab = tab
        var list = [todayScreen, rides, progressScreen]
        for (var i = 0; i < list.length; i++)
            bindSheetClearance(list[i])
    }

    function openRide(id) {
        tab = "rides"
        rides.open(id)
    }

    // the goal setup, over Today
    function openGoalSetup() {
        tab = "today"
        goalsModel.setupOpen = true
    }

    // the bike chip of Today: You, at bike setup
    function openBike() {
        tab = "you"
        if (youLoader.item)
            youLoader.item.open("bike")
    }

    // Android back: step back inside the section, then to Today, then let the app close

    function goBack() {
        if (tab === "rides" && rides.goBack())
            return true
        if (tab === "progress" && progressScreen.goBack())
            return true
        if (tab === "today" && todayScreen.goBack())
            return true
        if (tab === "you" && youLoader.item && youLoader.item.goBack())
            return true
        if (tab !== "today") {
            tab = "today"
            return true
        }
        return false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // The pages, under the status bar and beside the rail. Each keeps navClearance free at its
    // end, so it scrolls behind the bottom bar but its last line ends above it.
    Item {
        id: pages
        x: shell.rail ? shell.insetLeft + shell.railWidth : shell.insetLeft
        y: shell.insetTop
        width: shell.width - x - shell.insetRight
        height: shell.height - y
        readonly property bool fading: fadeThrough.running
        onWidthChanged: shell.pagesResized()
        onHeightChanged: shell.pagesResized()

        TodayScreen {
            id: todayScreen
            core: shell.core
            width: shell.todaySize.width
            height: shell.todaySize.height
            visible: shell.pageShown("today")
            opacity: shell.pageOpacity("today")
            scale: shell.pageScale("today")
            enabled: shell.shownTab === "today"
            layer.enabled: pages.fading && visible
            bottomClearance: shell.navClearance + shell.insetBottom
            library: shell.library
            connected: shell.connected
            deviceName: shell.deviceName
            searchStatus: shell.searchStatus
            miles: shell.miles
            nickname: shell.nickname
            showYou: false
            initial: shell.initial
            ridePaused: shell.ridePaused
            pausedAt: shell.pausedAt
            onRideRequested: shell.rideRequested()
            onWorkoutRequested: shell.workoutRequested(plan)
            onEndRideRequested: shell.endRideRequested()
            onDemoRequested: shell.demoRequested()
            onSearchAgain: shell.searchAgain()
            onOpenYou: shell.tab = "you"
            onOpenBike: shell.openBike()
            onOpenRide: shell.openRide(id)
            onOpenTab: shell.tab = name
            goals: goalsModel
        }
        RidesScreen {
            id: rides
            width: shell.ridesSize.width
            height: shell.ridesSize.height
            bottomClearance: shell.navClearance + shell.insetBottom
            core: shell.core
            visible: shell.pageShown("rides")
            opacity: shell.pageOpacity("rides")
            scale: shell.pageScale("rides")
            enabled: shell.shownTab === "rides"
            layer.enabled: pages.fading && visible
            library: shell.library
            miles: shell.miles
            showYou: false
            initial: shell.initial
            onOpenYou: shell.tab = "you"
        }
        ProgressScreen {
            id: progressScreen
            width: shell.progressSize.width
            height: shell.progressSize.height
            bottomClearance: shell.navClearance + shell.insetBottom
            visible: shell.pageShown("progress")
            opacity: shell.pageOpacity("progress")
            scale: shell.pageScale("progress")
            enabled: shell.shownTab === "progress"
            layer.enabled: pages.fading && visible
            library: shell.library
            miles: shell.miles
            showYou: false
            initial: shell.initial
            onOpenYou: shell.tab = "you"
            onOpenRide: shell.openRide(id)
            goals: goalsModel
            onWorkoutRequested: shell.workoutRequested(workout)
            onWorkoutFileRequested: shell.workoutFileRequested()
            onIntervalsRequested: shell.intervalsRequested()
            onRouteRequested: shell.routeRequested(route)
            onRouteFileRequested: shell.routeFileRequested()
        }
        Loader {
            id: youLoader
            width: shell.youSize.width
            height: shell.youSize.height
            visible: shell.pageShown("you")
            opacity: shell.pageOpacity("you")
            scale: shell.pageScale("you")
            enabled: shell.shownTab === "you"
            layer.enabled: pages.fading && visible
            active: shell.tab === "you" || status === Loader.Ready
            source: "you/YouScreen.qml"
            onLoaded: {
                item.core = Qt.binding(function () { return shell.core })
                item.metrics = Qt.binding(function () { return shell.metrics })
                item.bottomClearance = Qt.binding(function () { return shell.navClearance + shell.insetBottom })
                shell.bindSheetClearance(item)
            }
        }
        Connections {
            target: youLoader.item
            ignoreUnknownSignals: true
            function onRestartRequested() { shell.restartRequested() }
            function onStravaConnect() { shell.stravaConnect() }
            function onPelotonConnect() { shell.pelotonConnect() }
            function onIntervalsConnect() { shell.intervalsConnect() }
            function onRefreshDevicesRequested() { shell.refreshDevices() }
            function onMilesPicked(miles) {
                // every page reads shell.miles; main2's own Settings would not see the change
                shell.miles = miles
                shell.unitsPicked(miles)
            }
        }
    }

    // the navigation: a bar across the bottom, or a rail down the left, edge to edge
    FloatingNav {
        id: nav
        objectName: "floatingNav"
        vertical: shell.rail
        tab: shell.tab
        destinations: shell.destinations
        ridePaused: shell.ridePaused
        insetBottom: shell.insetBottom
        insetLeft: shell.insetLeft
        insetTop: shell.insetTop
        available: shell.rail ? shell.height : shell.width - shell.insetLeft - shell.insetRight
        x: 0
        y: shell.rail ? 0 : shell.height - height
        width: shell.rail ? implicitWidth : shell.width
        height: implicitHeight
        // the bar never covers what the rider needs: a sheet or a full page over the tab (the ride
        // analysis on a phone, Edit sections, the goal setup...) or the keyboard moves it aside.
        // The rail sits beside the pages, so it stays.
        readonly property bool stepAside: !shell.rail && (shell.covering || Qt.inputMethod.visible)
        // how far it slides off the bottom edge
        property real away: stepAside ? 1 : 0
        opacity: 1 - away
        visible: opacity > 0
        enabled: !stepAside
        transform: Translate {
            y: nav.vertical ? 0 : nav.away * nav.height
        }
        Behavior on away { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.effectsTime + 50; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve } }
        onPicked: shell.tab = name
        onRideRequested: shell.rideRequested()
    }
}
