import QtQuick 2.15
import "."
import "sig"

// The app around the ride: Today, Rides, Progress, Goals and You, with Ride always one tap away.
// The navigation floats over the content (sig/FloatingNav): on compact windows (phones held
// upright) a pill at the bottom with Today, Rides, Progress and Goals and the round Ride button
// beside it, You behind the round button in each header; on wider windows a floating rail on the
// left with Ride on top and You in it. A tab switch fades through: the open page fades out
// quickly, then the new one fades in as it grows from 96%. The pages stay alive.
// The shell keeps clear of the system bars and the camera cutout with the insets it is given.
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

    property int insetTop: 0
    property int insetBottom: 0
    property int insetLeft: 0
    property int insetRight: 0

    signal rideRequested()
    signal demoRequested()
    signal searchAgain()
    signal restartRequested()
    signal stravaConnect()
    signal pelotonConnect()
    signal intervalsConnect()
    signal refreshDevices()

    readonly property bool rail: width >= 600
    // the room the floating rail takes on the left: its margin, its width and a gap
    readonly property int railWidth: 12 + 72 + 12
    // how high the bottom pill floats over the bottom inset
    readonly property int navLift: insetBottom > 0 ? 10 : 20
    // what a page that scrolls under the bottom pill keeps free at its end, over the bottom inset
    readonly property int navClearance: rail ? 16 : 64 + navLift + 16
    readonly property string initial: nickname !== "" ? nickname.charAt(0).toUpperCase() : "B"

    readonly property var destinations: {
        var list = [
            { name: "today", label: qsTr("Today"), icon: "today" },
            { name: "rides", label: qsTr("Rides"), icon: "rides" },
            { name: "progress", label: qsTr("Progress"), icon: "progress" },
            { name: "goals", label: qsTr("Goals"), icon: "goals" }
        ]
        if (rail)
            list.push({ name: "you", label: qsTr("You"), icon: "you" })
        return list
    }

    // the fade through between tabs: the page on screen, the page fading out, and how far each is
    property string shownTab: ""
    property string leavingTab: ""
    property real leaveFade: 1
    property real enterFade: 1

    onTabChanged: {
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

    Component.onCompleted: shownTab = tab

    function openRide(id) {
        tab = "rides"
        rides.open(id)
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
        if (tab === "goals" && goalsScreen.goBack())
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

    // The pages, under the status bar and beside the rail. Today scrolls under the floating pill
    // (it keeps navClearance free at its end); the other pages end above it.
    Item {
        id: pages
        x: shell.rail ? shell.insetLeft + shell.railWidth : shell.insetLeft
        y: shell.insetTop
        width: shell.width - x - shell.insetRight
        height: shell.height - y
        readonly property real shortHeight: height - shell.insetBottom - (shell.rail ? 0 : shell.navClearance - 8)
        readonly property bool fading: fadeThrough.running

        TodayScreen {
            id: todayScreen
            width: parent.width
            height: parent.height
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
            showYou: !shell.rail
            initial: shell.initial
            onRideRequested: shell.rideRequested()
            onDemoRequested: shell.demoRequested()
            onSearchAgain: shell.searchAgain()
            onOpenYou: shell.tab = "you"
            onOpenRide: shell.openRide(id)
            onOpenTab: shell.tab = name
        }
        RidesScreen {
            id: rides
            width: parent.width
            height: pages.shortHeight
            visible: shell.pageShown("rides")
            opacity: shell.pageOpacity("rides")
            scale: shell.pageScale("rides")
            enabled: shell.shownTab === "rides"
            layer.enabled: pages.fading && visible
            library: shell.library
            miles: shell.miles
            showYou: !shell.rail
            initial: shell.initial
            onOpenYou: shell.tab = "you"
        }
        ProgressScreen {
            id: progressScreen
            width: parent.width
            height: pages.shortHeight
            visible: shell.pageShown("progress")
            opacity: shell.pageOpacity("progress")
            scale: shell.pageScale("progress")
            enabled: shell.shownTab === "progress"
            layer.enabled: pages.fading && visible
            library: shell.library
            miles: shell.miles
            showYou: !shell.rail
            initial: shell.initial
            onOpenYou: shell.tab = "you"
            onOpenRide: shell.openRide(id)
        }
        GoalsScreen {
            id: goalsScreen
            width: parent.width
            height: pages.shortHeight
            visible: shell.pageShown("goals")
            opacity: shell.pageOpacity("goals")
            scale: shell.pageScale("goals")
            enabled: shell.shownTab === "goals"
            layer.enabled: pages.fading && visible
            library: shell.library
            miles: shell.miles
            showYou: !shell.rail
            initial: shell.initial
            onOpenYou: shell.tab = "you"
        }
        Loader {
            id: youLoader
            width: parent.width
            height: pages.shortHeight
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
        }
    }

    // the floating navigation: a pill at the bottom, or a rail on the left
    FloatingNav {
        id: nav
        objectName: "floatingNav"
        vertical: shell.rail
        tab: shell.tab
        destinations: shell.destinations
        available: shell.rail ? shell.height - shell.insetTop - shell.insetBottom - 24
                              : shell.width - shell.insetLeft - shell.insetRight - 32
        x: shell.rail ? shell.insetLeft + 12
                      : shell.insetLeft + Math.round((shell.width - shell.insetLeft - shell.insetRight - width) / 2)
        y: shell.rail ? shell.insetTop + Math.max(12, Math.round((shell.height - shell.insetTop - shell.insetBottom - height) / 2))
                      : shell.height - shell.insetBottom - shell.navLift - height
        width: implicitWidth
        height: implicitHeight
        onPicked: shell.tab = name
        onRideRequested: shell.rideRequested()
    }
}
