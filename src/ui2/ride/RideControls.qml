import QtQuick 2.15
import ".."

// The dock of a bike whose level is set by hand: the level as information, one big Pause or
// Resume, Lap and a held End. Big enough to hit on a handlebar mount. A rail in landscape, a row
// in portrait.
Item {
    id: controls

    // a LiveSource or a RideSim
    property var source
    property bool vertical: true
    property color tint: Theme.accent
    // the start of a ride on the ride screen: "", "count" or "go"
    property string phase: ""
    readonly property bool stopped: source.stopped === true
    readonly property bool paused: source.paused === true && !stopped
    readonly property bool showLevel: source.level > 0

    signal mainPressed()
    signal lapPressed()
    signal endHeld()
    signal endTapped()
    signal endConfirm()

    // what the big button does now
    readonly property string mainState: phase === "count" ? "cancel"
                                        : (stopped && phase === "" ? "start" : (paused ? "resume" : "pause"))

    // the big button takes the room a tall rail has to spare (a tablet), up to 200
    readonly property real mainWidth: vertical ? width - 20 : 112
    readonly property real mainHeight: vertical ? Math.max(96, Math.min(200, height - 20 - (showLevel ? levelInfo.height : 0) - 2 * smallHeight - 36))
                                                : height - 20
    readonly property real smallWidth: vertical ? width - 20 : 80
    readonly property real smallHeight: vertical ? (height > 400 ? 64 : 56) : 64

    // spread over the dock, up to 36 apart; a wide dock (a tablet in portrait) keeps the group
    // together in its middle
    Grid {
        id: grid
        anchors.centerIn: parent
        flow: controls.vertical ? Grid.TopToBottom : Grid.LeftToRight
        columns: controls.vertical ? 1 : 4
        rows: controls.vertical ? 4 : 1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        readonly property int count: controls.showLevel ? 4 : 3
        readonly property real used: controls.vertical
                                     ? (controls.showLevel ? levelInfo.height : 0) + controls.mainHeight + 2 * controls.smallHeight
                                     : (controls.showLevel ? levelInfo.width : 0) + controls.mainWidth + 2 * controls.smallWidth
        columnSpacing: controls.vertical ? 0 : Math.max(6, Math.min(36, (controls.width - 20 - used) / (count - 1)))
        rowSpacing: controls.vertical ? Math.max(6, Math.min(36, (controls.height - 20 - used) / (count - 1))) : 0

        // the level the bike reports, to read, not to press
        Column {
            id: levelInfo
            visible: controls.showLevel
            width: controls.vertical ? controls.mainWidth : 60
            spacing: 6
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("Level %1").arg(controls.source.level)
            Numeral {
                anchors.horizontalCenter: parent.horizontalCenter
                text: controls.source.level
                color: Theme.text
                font.pixelSize: 32
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("level")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }

        PulseButton {
            id: mainButton
            width: controls.mainWidth
            height: controls.mainHeight
            radius: 36
            pressedRadius: 24
            pressedScale: 0.95
            fill: controls.mainState === "pause" ? controls.tint
                  : (controls.mainState === "cancel" ? Theme.chip : Theme.accent)
            Accessible.name: controls.mainState === "cancel" ? qsTr("Cancel the start")
                             : (controls.mainState === "start" ? qsTr("Start ride")
                                : (controls.mainState === "resume" ? qsTr("Resume ride") : qsTr("Pause ride")))
            onClicked: controls.mainPressed()
            contentItem: Item {
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: controls.mainState === "pause" ? "pause" : (controls.mainState === "cancel" ? "close" : "play")
                        size: 30
                        color: controls.mainState === "pause" ? Theme.zoneInk
                               : (controls.mainState === "cancel" ? Theme.text : Theme.accentInk)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: controls.mainState === "cancel" ? qsTr("Cancel")
                              : (controls.mainState === "start" ? qsTr("Start")
                                 : (controls.mainState === "resume" ? qsTr("Resume") : qsTr("Pause")))
                        color: controls.mainState === "pause" ? Theme.zoneInk
                               : (controls.mainState === "cancel" ? Theme.text : Theme.accentInk)
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(15)
                    }
                }
            }
        }

        PulseButton {
            id: lapButton
            width: controls.smallWidth
            height: controls.smallHeight
            pressedRadius: 18
            fill: Theme.chip
            enabled: !controls.stopped
            opacity: enabled ? 1 : 0.35
            Accessible.name: qsTr("Lap")
            onClicked: controls.lapPressed()
            contentItem: Text {
                text: qsTr("Lap")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(15)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        HoldButton {
            width: controls.smallWidth
            height: controls.smallHeight
            enabled: !controls.stopped
            label: qsTr("End")
            holdingLabel: qsTr("Hold")
            onHeld: controls.endHeld()
            onTapped: controls.endTapped()
            onConfirmRequested: controls.endConfirm()
        }
    }
}
