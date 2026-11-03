import QtQuick 2.15
import "."

// The app around the ride: Today, Rides, Progress, Goals and You, with Ride always one tap away.
// Compact windows (phones held upright) get a bottom bar with Ride in the middle and You behind
// the round button in each header; wider windows get a side rail with Ride on top.
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
    readonly property int railWidth: 88
    readonly property int barHeight: 76
    readonly property string initial: nickname !== "" ? nickname.charAt(0).toUpperCase() : "B"

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

    // the pages, between the system bars and beside the rail
    Item {
        id: pages
        x: shell.rail ? shell.insetLeft + shell.railWidth : shell.insetLeft
        y: shell.insetTop
        width: shell.width - x - shell.insetRight
        height: shell.height - y - (shell.rail ? shell.insetBottom : shell.insetBottom + shell.barHeight)

        TodayScreen {
            anchors.fill: parent
            visible: shell.tab === "today"
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
            anchors.fill: parent
            visible: shell.tab === "rides"
            library: shell.library
            miles: shell.miles
            showYou: !shell.rail
            initial: shell.initial
            onOpenYou: shell.tab = "you"
        }
        ProgressScreen {
            id: progressScreen
            anchors.fill: parent
            visible: shell.tab === "progress"
            library: shell.library
            miles: shell.miles
            showYou: !shell.rail
            initial: shell.initial
            onOpenYou: shell.tab = "you"
            onOpenRide: shell.openRide(id)
        }
        GoalsScreen {
            anchors.fill: parent
            visible: shell.tab === "goals"
            library: shell.library
            miles: shell.miles
            showYou: !shell.rail
            initial: shell.initial
            onOpenYou: shell.tab = "you"
        }
        Loader {
            id: youLoader
            anchors.fill: parent
            visible: shell.tab === "you"
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

    // bottom bar on compact windows
    Rectangle {
        visible: !shell.rail
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: shell.barHeight + shell.insetBottom
        color: Theme.surface

        Rectangle { width: parent.width; height: 1; color: Theme.hairline }

        Row {
            id: barRow
            x: shell.insetLeft
            width: parent.width - shell.insetLeft - shell.insetRight
            height: shell.barHeight
            readonly property real slot: width / 5

            NavButton {
                width: barRow.slot; height: barRow.height
                text: qsTr("Today"); iconName: "today"
                current: shell.tab === "today"
                onClicked: shell.tab = "today"
            }
            NavButton {
                width: barRow.slot; height: barRow.height
                text: qsTr("Rides"); iconName: "rides"
                current: shell.tab === "rides"
                onClicked: shell.tab = "rides"
            }
            Item {
                width: barRow.slot; height: barRow.height
                PulseButton {
                    anchors.centerIn: parent
                    width: 64
                    height: 52
                    radius: 18
                    pressedRadius: 26
                    fill: Theme.accent
                    Accessible.name: qsTr("Ride")
                    onClicked: shell.rideRequested()
                    contentItem: Item {
                        BrandMark { anchors.centerIn: parent; width: 38; height: 38; color: Theme.accentInk }
                    }
                }
            }
            NavButton {
                width: barRow.slot; height: barRow.height
                text: qsTr("Progress"); iconName: "progress"
                current: shell.tab === "progress"
                onClicked: shell.tab = "progress"
            }
            NavButton {
                width: barRow.slot; height: barRow.height
                text: qsTr("Goals"); iconName: "goals"
                current: shell.tab === "goals"
                onClicked: shell.tab = "goals"
            }
        }
    }

    // side rail on medium and expanded windows
    Rectangle {
        visible: shell.rail
        x: 0
        width: shell.insetLeft + shell.railWidth
        height: parent.height
        color: Theme.surface

        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.hairline }

        Column {
            // a phone held sideways has about 390 of height: everything fits in one column
            readonly property bool tight: shell.height - shell.insetTop - shell.insetBottom < 520
            readonly property int itemHeight: tight ? 58 : 64
            x: shell.insetLeft + (shell.railWidth - 72) / 2
            y: shell.insetTop + (tight ? 10 : 16)
            spacing: tight ? 0 : 6

            PulseButton {
                width: 72
                height: parent.tight ? 54 : 64
                radius: 20
                pressedRadius: 28
                fill: Theme.accent
                Accessible.name: qsTr("Ride")
                onClicked: shell.rideRequested()
                contentItem: Item {
                    BrandMark { anchors.centerIn: parent; width: 42; height: 42; color: Theme.accentInk }
                }
            }
            Item { width: 1; height: parent.tight ? 8 : 14 }
            NavButton {
                height: parent.itemHeight
                text: qsTr("Today"); iconName: "today"
                current: shell.tab === "today"
                onClicked: shell.tab = "today"
            }
            NavButton {
                height: parent.itemHeight
                text: qsTr("Rides"); iconName: "rides"
                current: shell.tab === "rides"
                onClicked: shell.tab = "rides"
            }
            NavButton {
                height: parent.itemHeight
                text: qsTr("Progress"); iconName: "progress"
                current: shell.tab === "progress"
                onClicked: shell.tab = "progress"
            }
            NavButton {
                height: parent.itemHeight
                text: qsTr("Goals"); iconName: "goals"
                current: shell.tab === "goals"
                onClicked: shell.tab = "goals"
            }
            NavButton {
                height: parent.itemHeight
                text: qsTr("You"); iconName: "you"
                current: shell.tab === "you"
                onClicked: shell.tab = "you"
            }
        }
    }
}
