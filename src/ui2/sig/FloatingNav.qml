import QtQuick 2.15
import ".."

// The navigation of the app, every destination named. On phones held upright a bar across the
// bottom, edge to edge, with five slots of the same width: Today, Rides, Ride in the middle (the
// round button in the accent), Progress and You. Upright on wider windows (a phone on its side,
// a tablet) a rail down the left edge: Ride on top, then the four destinations, each name under
// its icon. The open destination has its icon in a filled pill. The bar keeps clear of the
// bottom inset and the rail of the left one (the camera cutout); both paint under them.
// `available` is the room across (bar) or upright (rail); a short rail packs tighter.
Item {
    id: floatingNav

    property string tab: "today"
    // [{ name, label, icon }]: four, Ride goes in the middle of them
    property var destinations: []
    property bool vertical: false
    property real available: 1000
    property int insetBottom: 0
    property int insetLeft: 0
    property int insetTop: 0
    // a ride is paused and waits: the Ride button carries a dot and says Resume
    property bool ridePaused: false

    signal picked(string name)
    signal rideRequested()

    // the bar: 76 high over the bottom inset; the rail: 80 wide right of the left inset
    readonly property int barHeight: 76
    readonly property int railWidth: 80
    readonly property bool dense: vertical && available < 380
    readonly property int railSlot: dense ? 56 : 64
    readonly property real slotWidth: (available) / Math.max(1, destinations.length + 1)
    readonly property var slots: {
        var out = []
        var half = Math.ceil(destinations.length / 2)
        for (var i = 0; i < destinations.length; i++) {
            if (i === half)
                out.push({ name: "ride" })
            out.push(destinations[i])
        }
        if (destinations.length < 2)
            out.push({ name: "ride" })
        return out
    }

    implicitWidth: vertical ? insetLeft + railWidth : available
    implicitHeight: vertical ? available : barHeight + insetBottom

    // the surface, under the insets too
    Rectangle {
        anchors.fill: parent
        color: Theme.floating
    }
    Rectangle {
        visible: !floatingNav.vertical
        width: parent.width
        height: 1
        color: Theme.hairline
    }
    Rectangle {
        visible: floatingNav.vertical
        x: parent.width - 1
        width: 1
        height: parent.height
        color: Theme.hairline
    }

    // across: five slots of the same width
    Row {
        id: across
        visible: !floatingNav.vertical
        x: floatingNav.insetLeft
        y: 0
        Repeater {
            model: floatingNav.vertical ? [] : floatingNav.slots
            Item {
                width: floatingNav.slotWidth
                height: floatingNav.barHeight
                NavButton {
                    visible: modelData.name !== "ride"
                    anchors.fill: parent
                    text: modelData.label || ""
                    iconName: modelData.icon || "today"
                    current: floatingNav.tab === modelData.name
                    onClicked: floatingNav.picked(modelData.name)
                }
                RideSlot {
                    visible: modelData.name === "ride"
                    anchors.fill: parent
                    paused: floatingNav.ridePaused
                    onClicked: floatingNav.rideRequested()
                }
            }
        }
    }

    // upright: Ride on top, the destinations under it, the group in the middle of the height
    Column {
        id: upright
        visible: floatingNav.vertical
        x: floatingNav.insetLeft
        y: floatingNav.insetTop + Math.max(8, Math.round((floatingNav.height - floatingNav.insetTop - height) / 2))
        spacing: floatingNav.dense ? 0 : 4
        RideSlot {
            width: floatingNav.railWidth
            height: floatingNav.dense ? 72 : 80
            paused: floatingNav.ridePaused
            onClicked: floatingNav.rideRequested()
        }
        Item { width: 1; height: floatingNav.dense ? 4 : 12 }
        Repeater {
            model: floatingNav.vertical ? floatingNav.destinations : []
            NavButton {
                width: floatingNav.railWidth
                height: floatingNav.railSlot
                text: modelData.label
                iconName: modelData.icon
                current: floatingNav.tab === modelData.name
                onClicked: floatingNav.picked(modelData.name)
            }
        }
    }
}
