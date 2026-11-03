import QtQuick 2.15
import ".."

// Heart rate: where it comes from, a belt or watch, or the bike's own grips.
YouPage {
    id: page

    title: qsTr("Heart rate")

    readonly property var qz: you.qz
    readonly property string chosen: qz.heart_rate_belt_name
    // the chosen belt stays in the list even when the last search did not see it
    readonly property var names: {
        var list = you.devices.slice()
        var bike = you.deviceName
        if (bike !== "" && list.indexOf(bike) >= 0)
            list.splice(list.indexOf(bike), 1)
        if (chosen !== "Disabled" && list.indexOf(chosen) < 0)
            list.unshift(chosen)
        return list
    }

    function choose(name) {
        if (name === chosen)
            return
        qz.heart_rate_belt_name = name
        qz.setValue("heart_rate_belt_name", name)
        // a belt connects right away, going back to none is read at the next start
        if (name === "Disabled")
            you.needRestart()
        else if (you.core !== null)
            you.core.reconnectHeartRateBelt(name)
    }

    Item {
        width: parent.width
        height: nowCard.height + 8

        Rectangle {
            id: nowCard
            x: 12
            width: parent.width - 24
            height: Math.max(88, nowColumn.height + 36)
            radius: 28
            color: Theme.card

            Rectangle {
                id: heartBadge
                x: 20
                width: 48
                height: 48
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.chip
                YouIcon {
                    anchors.centerIn: parent
                    name: "heart"
                    size: 24
                    weight: 2.4
                    color: Theme.zoneColors[5]
                }
            }
            Column {
                id: nowColumn
                x: heartBadge.x + heartBadge.width + 16
                width: parent.width - x - 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: you.heartRate > 0 ? qsTr("%1 bpm").arg(Math.round(you.heartRate)) : qsTr("No heart rate yet")
                    color: Theme.text
                    font.family: you.heartRate > 0 ? Theme.display : Theme.bodySemibold
                    font.pixelSize: you.heartRate > 0 ? 28 : Theme.titleSize
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: page.chosen === "Disabled" ? qsTr("From the bike, when it has grips or a belt of its own")
                          : qsTr("From %1").arg(page.chosen)
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.labelSize
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Heart rate source")
    }

    YouRow {
        title: qsTr("None, use the bike")
        trailing: "check"
        selected: page.chosen === "Disabled"
        onClicked: page.choose("Disabled")
    }

    Repeater {
        model: page.names
        delegate: YouRow {
            title: modelData
            trailing: "check"
            selected: page.chosen === modelData
            hairline: index < page.names.length - 1
            onClicked: page.choose(modelData)
        }
    }

    YouText {
        visible: page.names.length === 0
        text: qsTr("No belts or watches seen yet. Put the belt on, or start a workout on the watch, then look again.")
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
        text: qsTr("Fitbit and some other watches show up here only after you switch on heart rate sharing on the watch, sometimes called broadcast.")
    }

    YouSwitch {
        title: qsTr("Ignore the bike's heart rate")
        detail: qsTr("Use only the belt or watch, even when the bike sends a heart rate of its own.")
        isOn: page.qz.heart_ignore_builtin
        hairline: false
        onSwitched: page.qz.heart_ignore_builtin = value
    }
}
