import QtQuick 2.15
import ".."

// Connections: the services rides go to, connected or not.
YouPage {
    id: page

    title: qsTr("Connections")
    lead: qsTr("Connecting opens the sign-in page of the service. Bikemodo keeps the sign-in on this device.")

    // the service whose Disconnect was tapped once, it asks again before it signs out
    property string confirming: ""

    readonly property var services: [
        { id: "strava", name: "Strava", detail: qsTr("Rides are uploaded when they end."), loggedIn: "isStravaLoggedIn", logout: "strava_logout" },
        { id: "intervals", name: "intervals.icu", detail: qsTr("Rides are uploaded when they end."), loggedIn: "isIntervalsICULoggedIn", logout: "intervalsicu_logout" },
        { id: "peloton", name: "Peloton", detail: qsTr("Follow Peloton classes with your bike."), loggedIn: "isPelotonLoggedIn", logout: "peloton_logout" }
    ]

    function connect(id) {
        if (id === "strava")
            you.stravaConnect()
        else if (id === "intervals")
            you.intervalsConnect()
        else
            you.pelotonConnect()
    }

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: page.confirming = ""
    }

    Repeater {
        model: page.services
        delegate: Item {
            readonly property bool linked: you.ask(modelData.loggedIn, false)
            width: parent.width
            height: Math.max(76, serviceText.implicitHeight + 28)

            Column {
                id: serviceText
                x: 12
                width: serviceButton.x - x - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    width: parent.width
                    text: modelData.name
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.bodySize + 1
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: linked ? qsTr("Connected") : qsTr("Not connected")
                    color: linked ? Theme.zoneColors[1] : Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.labelSize
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: modelData.detail
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.labelSize
                    wrapMode: Text.WordWrap
                }
            }

            YouButton {
                id: serviceButton
                x: parent.width - width - 12
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(168, parent.width * 0.42)
                primary: !linked
                danger: linked && page.confirming === modelData.id
                text: !linked ? qsTr("Connect")
                      : (page.confirming === modelData.id ? qsTr("Sure? Disconnect") : qsTr("Disconnect"))
                Accessible.name: text + " " + modelData.name
                onClicked: {
                    if (!linked) {
                        page.connect(modelData.id)
                    } else if (page.confirming !== modelData.id) {
                        page.confirming = modelData.id
                        confirmTimer.restart()
                    } else {
                        page.confirming = ""
                        if (you.core !== null)
                            you.core[modelData.logout]()
                    }
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
                height: 1
                color: Theme.hairline
            }
        }
    }

    // Garmin signs in with an email and a password, which Bikemodo does not ask for yet
    Item {
        id: garminRow
        readonly property bool garmin: you.ask("isGarminUploadConfigured", false)
        width: parent.width
        height: Math.max(76, garminText.implicitHeight + 28)

        Column {
            id: garminText
            x: 12
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: qsTr("Garmin Connect")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.bodySize + 1
            }
            Text {
                width: parent.width
                text: garminRow.garmin ? qsTr("Connected, rides are uploaded") : qsTr("Not set up")
                color: garminRow.garmin ? Theme.zoneColors[1] : Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: !garminRow.garmin
                text: qsTr("Garmin needs your Garmin email and password. Bikemodo cannot set that up yet.")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
            height: 1
            color: Theme.hairline
        }
    }

    // QZ asks for Health Connect access when the app starts and adds every saved ride once it is
    // allowed (CustomQtActivity, homeform::fit_save_clicked): this says so
    Item {
        visible: Qt.platform.os === "android"
        width: parent.width
        height: visible ? Math.max(76, healthText.implicitHeight + 28) : 0

        Column {
            id: healthText
            x: 12
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: qsTr("Health Connect")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.bodySize + 1
            }
            Text {
                width: parent.width
                text: qsTr("Every ride you save is added to Health Connect once you allow it. Bikemodo asks when it first starts. Change or remove access any time in the Health Connect app.")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
        }
    }

    // QZ's virtual bike (virtual_device_enabled): the bike shows up again as a Bluetooth bike for
    // Zwift, MyWhoosh and other apps, on this phone or a tablet nearby. Read when QZ starts.
    YouText {
        kind: "heading"
        text: qsTr("Other apps")
    }
    YouSwitch {
        readonly property bool running: you.ask("virtualBikeRunning", false)
        readonly property bool inUse: you.ask("virtualBikeInUse", false)
        title: qsTr("Share the bike with other apps")
        detail: !you.qz.virtual_device_enabled ? qsTr("Off. Other apps cannot see the bike through Bikemodo.")
                : inUse ? qsTr("An app is connected now and gets your watts, cadence and heart rate.")
                : running ? qsTr("On. In Zwift or another app, pick the Bluetooth bike called QZ.")
                : qsTr("On. It shows up once your bike is connected.")
        isOn: you.qz.virtual_device_enabled
        hairline: false
        onSwitched: {
            you.qz.virtual_device_enabled = value
            you.qz.setValue("virtual_device_enabled", value)
            you.needRestart()
        }
    }
}
