import QtQuick 2.15
import ".."

// The M3 Expressive floating toolbar of the app: a pill floating over the content with the
// destinations in it, the open one expanded into a filled accent pill with its name, and the
// round Ride button beside it. Across on phones held upright, upright as a floating rail on
// wider windows. The shell places it clear of the system bars; `available` is the room it has
// (its width across, its height upright), and it packs tighter when the room is short.
Item {
    id: floatingNav

    property string tab: "today"
    // [{ name, label, icon }]
    property var destinations: []
    property bool vertical: false
    property real available: 1000
    // a ride is paused and waits: the Ride button carries a dot and resumes it
    property bool ridePaused: false

    signal picked(string name)
    signal rideRequested()

    // across: the widest name decides if the comfortable sizes fit
    readonly property real widestLabel: widest.advanceWidth
    readonly property real comfortableWidth: 16 + (destinations.length - 1) * (52 + 4) + (16 + 22 + 8 + widestLabel + 20) + 10 + 64
    readonly property bool dense: vertical ? available < 380 : comfortableWidth > available
    readonly property int slot: vertical ? (dense ? 44 : 48) : (dense ? 42 : 52)
    readonly property int fabSize: dense ? 56 : 64
    readonly property int padding: vertical ? 6 : (dense ? 4 : 8)
    readonly property int gap: dense ? 8 : 10
    // what is left for the name of the open destination, so the group never outgrows the room
    readonly property real labelRoom: available - padding * 2 - (destinations.length - 1) * (slot + (dense ? 2 : 4))
                                      - (dense ? 14 + 22 + 6 + 16 : 16 + 22 + 8 + 20) - gap - fabSize

    implicitWidth: vertical ? 72 : pill.width + gap + fabSize
    implicitHeight: vertical ? fabSize + gap + pill.height : 64

    TextMetrics {
        id: widest
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.fs(14)
        text: {
            var longest = ""
            for (var i = 0; i < floatingNav.destinations.length; i++)
                if (floatingNav.destinations[i].label.length > longest.length)
                    longest = floatingNav.destinations[i].label
            return longest
        }
    }

    Item {
        id: pill
        x: floatingNav.vertical ? 0 : 0
        y: floatingNav.vertical ? floatingNav.fabSize + floatingNav.gap : 0
        width: floatingNav.vertical ? 72 : across.implicitWidth + floatingNav.padding * 2
        height: floatingNav.vertical ? upright.implicitHeight + floatingNav.padding * 2 : 64

        Shadow {
            anchors.fill: parent
            radius: surface.radius
        }
        Rectangle {
            id: surface
            anchors.fill: parent
            radius: floatingNav.vertical ? 36 : 32
            color: Theme.floating
            border.width: 1
            border.color: Theme.raisedBorder
        }

        Row {
            id: across
            visible: !floatingNav.vertical
            x: floatingNav.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: floatingNav.dense ? 2 : 4
            Repeater {
                model: floatingNav.vertical ? [] : floatingNav.destinations
                NavButton {
                    text: modelData.label
                    iconName: modelData.icon
                    current: floatingNav.tab === modelData.name
                    slot: floatingNav.slot
                    labelSize: floatingNav.dense ? 13 : 14
                    dense: floatingNav.dense
                    maxLabelWidth: Math.max(24, floatingNav.labelRoom)
                    onClicked: floatingNav.picked(modelData.name)
                }
            }
        }

        Column {
            id: upright
            visible: floatingNav.vertical
            x: floatingNav.padding
            y: floatingNav.padding
            spacing: floatingNav.dense ? 2 : 4
            Repeater {
                model: floatingNav.vertical ? floatingNav.destinations : []
                NavButton {
                    vertical: true
                    text: modelData.label
                    iconName: modelData.icon
                    current: floatingNav.tab === modelData.name
                    slot: floatingNav.slot
                    onClicked: floatingNav.picked(modelData.name)
                }
            }
        }
    }

    RideFab {
        x: floatingNav.vertical ? (72 - width) / 2 : pill.width + floatingNav.gap
        y: floatingNav.vertical ? 0 : (64 - height) / 2
        size: floatingNav.fabSize
        paused: floatingNav.ridePaused
        onClicked: floatingNav.rideRequested()
    }
}
