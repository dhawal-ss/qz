import QtQuick 2.15
import ".."

// The bike: is it there, search again, and which bike QZ should connect to.
YouPage {
    id: page

    title: qsTr("Bike and sensors")

    readonly property var qz: you.qz
    readonly property string chosen: qz.filter_device
    // the chosen bike stays in the list even when the last search did not see it
    readonly property var names: {
        var list = you.devices.slice()
        if (chosen !== "Disabled" && list.indexOf(chosen) < 0)
            list.unshift(chosen)
        return list
    }
    readonly property string searchStatus: you.connected ? "" : you.ask("bluetoothSearchStatus", "")

    function choose(name) {
        if (name === chosen)
            return
        qz.filter_device = name
        // written at once, QZ reads it when it starts and the restart may come right away
        qz.setValue("filter_device", name)
        you.needRestart()
    }

    // the bike, the same card as the start screen
    Item {
        width: parent.width
        height: statusCard.height + 8

        Rectangle {
            id: statusCard
            x: 12
            width: parent.width - 24
            height: statusColumn.height + 40
            radius: 28
            color: Theme.card

            Column {
                id: statusColumn
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 16

                Row {
                    width: parent.width
                    spacing: 14
                    PulseShape {
                        width: 44
                        height: 44
                        zone: you.connected ? 2 : 1
                        color: you.connected ? Theme.zoneColors[1] : Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        width: parent.width - 58
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: you.connected ? qsTr("Bike connected") : qsTr("Looking for your bike")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.titleSize
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            width: parent.width
                            text: you.connected ? (you.deviceName !== "" ? you.deviceName : qsTr("Connected"))
                                  : (page.searchStatus !== "" ? page.searchStatus : qsTr("Wake the bike by pedaling a few turns."))
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.labelSize
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                YouButton {
                    visible: !you.connected
                    width: parent.width
                    primary: true
                    text: qsTr("Search again")
                    onClicked: if (you.core !== null) you.core.bluetoothSearchNow()
                }
            }
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Which bike to connect")
    }
    YouText {
        text: qsTr("Bikemodo connects to the first bike it recognizes. Pick yours to make it connect to that one only, useful when there are other bikes or sensors nearby.")
    }

    YouRow {
        title: qsTr("Any bike Bikemodo recognizes")
        trailing: "check"
        selected: page.chosen === "Disabled"
        onClicked: page.choose("Disabled")
    }

    Repeater {
        model: page.names
        delegate: YouRow {
            title: modelData
            detail: modelData === you.deviceName && you.connected ? qsTr("Connected now") : ""
            trailing: "check"
            selected: page.chosen === modelData
            hairline: index < page.names.length - 1
            onClicked: page.choose(modelData)
        }
    }

    YouText {
        visible: page.names.length === 0
        text: qsTr("No other devices seen yet. Look for nearby devices, with the bike awake.")
    }

    Item {
        width: parent.width
        height: lookButton.height + 20
        YouButton {
            id: lookButton
            x: 12
            y: 12
            text: qsTr("Look for nearby devices")
            onClicked: you.refreshDevicesRequested()
        }
    }

    YouText {
        visible: page.chosen !== "Disabled"
        text: qsTr("Bikemodo waits for %1 and ignores other bikes. Pick \"Any bike\" to go back.").arg(page.chosen)
    }

    YouText {
        kind: "heading"
        text: qsTr("Echelon bikes")
    }

    YouChoice {
        title: qsTr("Watt table")
        detail: qsTr("How Bikemodo turns level and cadence into watts on an Echelon without a power meter. Try the other one if your watts look off.")
        options: [["Echelon", qsTr("Echelon")], ["mgarcea", qsTr("mgarcea")]]
        current: page.qz.echelon_watttable
        hairline: false
        onPicked: page.qz.echelon_watttable = value
    }
}
