import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Controls.Material 2.12
import Qt.labs.settings 1.0
import QtQml 2.15

Page {

    title: qsTr("QZ Fitness")
    id: page

    // VoiceOver accessibility - ignore Page itself, only children are accessible
    Accessible.ignored: true

    property alias start: start
    property alias stop: stop
    property alias lap: lap
    property alias row: row
    property alias searchNow: searchNowButton
    property alias moreHelp: moreHelpButton
    // The bar and the status line under it: the tiles start below
    readonly property int topChromeHeight: topBar.visible ? topBar.height + statusLine.height : 0
    // Search for the equipment ("Next search in 12 s"), set by Home.qml while no device is connected
    property string searchStatus: ""
    // Home.qml sets the new values from the settings page in it (the background color of the top bar)
    property alias homeFormSettings: settings

    Settings {
	     id: settings
	     Component.onCompleted: window.retakeSettingsSnapshot(settings)
		  property real ui_zoom: 100.0
		  property bool theme_tile_icon_enabled: false
		  property string theme_background_color: "#303030"
		}

    // The ride bar (dashboard spec, step 3): the status chip on the left, the ride controls on the
    // right, the primary one at the edge. Hidden in lock mode and with the top bar off
    Item {
        id: topBar
        width: parent.width
        height: rootItem.topBarHeight > 0 ? Math.max(64, window.fontPx(16) + 40) : 0
        visible: !window.lockTiles && rootItem.topBarHeight > 0

        Rectangle { anchors.fill: parent; color: window.theme.bg; Accessible.ignored: true }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: window.theme.stroke; Accessible.ignored: true }

        // The connection and the ride at a glance. A tap searches now when no device is connected, or
        // looks for the heart rate sensor again when one is (what the Bluetooth icon did)
        Rectangle {
            id: statusChip
            readonly property bool searching: rootItem.labelHelp
            // labelHelp first: rootItem.device blinks while no device exists
            readonly property bool linkDown: !searching && !rootItem.device
            readonly property bool pausedRide: !searching && !linkDown && rootItem.rideState === 2
            readonly property string label: searching ? (page.searchStatus !== "" ? page.searchStatus.split("\n")[0] : qsTr("Searching…"))
                                          : linkDown ? qsTr("Reconnecting…")
                                          : pausedRide ? qsTr("Paused") : qsTr("Connected")
            // the room left of the buttons: the chip gives up its label before a button label is cut
            readonly property real room: row.x - x - 12
            readonly property real fullWidth: chipLabel.x + chipLabel.implicitWidth + 14
            anchors.left: parent.left
            anchors.leftMargin: window.contentSideMargin
            anchors.verticalCenter: parent.verticalCenter
            height: 36
            radius: 18
            width: room >= chipLabel.x + 48 ? Math.min(fullWidth, room) : 32
            color: pausedRide ? window.theme.cautionTonal : window.theme.surfaceRaised

            Rectangle {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: statusChip.searching ? window.theme.caution : statusChip.linkDown ? window.theme.danger : window.theme.go
                Accessible.ignored: true
            }
            Label {
                id: chipLabel
                x: 28
                width: Math.max(0, parent.width - x - 14)
                visible: parent.width > 32
                anchors.verticalCenter: parent.verticalCenter
                text: statusChip.label
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: window.fontPx(14)
                color: statusChip.pausedRide ? window.theme.caution : window.theme.textPrimary
                Accessible.ignored: true
            }
            MouseArea {
                anchors.fill: parent
                // at least 44 px tall to touch
                anchors.topMargin: -4
                anchors.bottomMargin: -4
                onClicked: { rootItem.bluetoothSearchNow(); rootItem.reconnectHeartRateBelt(); }

                // VoiceOver/TalkBack: a button that searches. The state is in the name: TalkBack (Qt 5.15)
                // reads no description when the name is set
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Bluetooth connection") + ": " + statusChip.label
                Accessible.description: statusChip.label
                Accessible.focusable: true
                Accessible.onPressAction: { rootItem.bluetoothSearchNow(); rootItem.reconnectHeartRateBelt(); }
            }
        }

        // Lap, End/Stop, then the primary button. A bike ends from Pause (End and Resume), so a stray
        // tap cannot end a ride; a treadmill keeps Stop while running, its belt must stop in one tap
        Row {
            id: row
            anchors.right: parent.right
            anchors.rightMargin: window.contentSideMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: rootItem.rideState === 2 ? 16 : 8

            RideButton {
                id: lap
                text: qsTr("Lap")
                minimumWidth: 72
                visible: !rootItem.labelHelp && rootItem.rideState === 1
                enabled: rootItem.lap
                fillColor: window.theme.surfaceRaised
                labelColor: window.theme.textPrimary
                Accessible.name: qsTr("Lap")
                Accessible.description: qsTr("Record a new lap")
            }
            RideButton {
                id: stop
                text: rootItem.endNeedsPause ? qsTr("End") : rootItem.stopText
                minimumWidth: 96
                visible: !rootItem.labelHelp && (rootItem.rideState === 2 || (!rootItem.endNeedsPause && rootItem.rideState === 1))
                fillColor: window.theme.dangerTonal
                labelColor: window.theme.danger
                Accessible.name: text
                Accessible.description: qsTr("Stop workout")
            }
            RideButton {
                id: start
                text: rootItem.startText
                minimumWidth: rootItem.endNeedsPause || rootItem.rideState !== 1 ? 120 : 96
                // Pause while riding; Start and Resume are the go colour
                fillColor: rootItem.rideState === 1 ? window.theme.cautionTonal : window.theme.go
                labelColor: rootItem.rideState === 1 ? window.theme.caution : "#000000"
                Accessible.name: text
                Accessible.description: qsTr("Start workout")
            }
        }
    }

    // The workout or class name under the bar, once the equipment is connected
    Label {
        id: statusLine
        anchors.top: topBar.bottom
        width: parent.width
        visible: topBar.visible && !rootItem.labelHelp && rootItem.info !== ""
        height: visible ? implicitHeight : 0
        leftPadding: window.contentSideMargin
        rightPadding: window.contentSideMargin
        topPadding: 4
        bottomPadding: 4
        horizontalAlignment: Text.AlignHCenter
        text: rootItem.info
        elide: Text.ElideRight
        maximumLineCount: 1
        font.pixelSize: window.fontPx(13)
        color: window.theme.textSecondary
    }

    // While no equipment is connected: what QZ is doing and what the rider can do. Outside the bar, so
    // it shows with the top bar off too; above the tiles
    Rectangle {
        id: connectionCard
        z: 10
        visible: rootItem.labelHelp
        width: Math.min(420, page.width - 2 * window.contentSideMargin)
        height: cardColumn.height + 48
        anchors.horizontalCenter: parent.horizontalCenter
        y: page.topChromeHeight + 16
        radius: window.theme.cardRadius
        color: window.theme.surface
        border.color: window.theme.stroke

        Column {
            id: cardColumn
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 12

            Label {
                width: parent.width
                text: qsTr("Looking for your equipment")
                wrapMode: Text.WordWrap
                font.pixelSize: window.fontPx(20)
                font.bold: true
                color: window.theme.textPrimary
            }
            Label {
                width: parent.width
                visible: page.searchStatus !== ""
                text: page.searchStatus
                wrapMode: Text.WordWrap
                color: window.theme.textSecondary
            }
            // the tips only where they fit: a phone in landscape keeps the buttons on screen
            Repeater {
                model: page.height - page.topChromeHeight > 480 ? [qsTr("Turn your bike on and pedal to wake it up."),
                                                                  qsTr("Close other apps that connect to it, like the maker's app or Zwift Companion."),
                                                                  qsTr("Keep Bluetooth on and allowed for QZ.")] : []
                Label {
                    width: cardColumn.width
                    text: "\u2022  " + modelData
                    wrapMode: Text.WordWrap
                    color: window.theme.textOnTint
                }
            }
            RideButton {
                id: searchNowButton
                width: parent.width
                text: qsTr("Search now")
                fillColor: "#FFFFFF"
                labelColor: "#000000"
                Accessible.name: text
                Accessible.description: qsTr("Search for the equipment now")
            }
            RideButton {
                id: moreHelpButton
                width: parent.width
                text: qsTr("More help")
                fillColor: "transparent"
                labelColor: window.theme.textPrimary
                Accessible.name: text
                Accessible.description: qsTr("What to check when the equipment does not connect")
            }
        }
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorZoom:0.6600000262260437;height:480;width:640}
}
##^##*/

