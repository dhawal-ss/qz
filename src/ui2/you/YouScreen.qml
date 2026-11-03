import QtQuick 2.15
import Qt.labs.settings 1.0
import ".."

// You: the profile and the settings Bikemodo needs, the bike, heart rate, body, zones, units,
// connections, the rides on disk and the credits. The list of sections and the open page side
// by side on wide windows, one after the other on phones.
// The values are QZ's own settings (the same keys as settings.qml), read and written here.
Item {
    id: screen

    // rootItem and rideMetrics, null in previews
    property var core: null
    property var metrics: null

    signal restartRequested()
    signal stravaConnect()
    signal pelotonConnect()
    signal intervalsConnect()
    // the shell forwards it to refresh_bluetooth_devices_clicked() of the window
    signal refreshDevicesRequested()

    // the open page, "" for the list on a phone
    property string section: ""
    property bool restartNeeded: false
    // ticks while You is shown, so the answers of rootItem's functions stay fresh
    property int tick: 0

    readonly property bool wide: Theme.expanded(width)
    readonly property real margin: Theme.margin(width)
    readonly property string shown: section !== "" ? section : (wide ? "bike" : "")
    readonly property alias qz: qzStore
    readonly property alias prefs: prefStore

    readonly property bool connected: metrics !== null && metrics.connected === true
    readonly property string deviceName: metrics !== null && metrics.deviceName ? metrics.deviceName : ""
    readonly property real heartRate: metrics !== null && metrics.heartRate ? metrics.heartRate : 0
    readonly property bool lbs: qzStore.miles_unit && !qzStore.weight_kg_unit
    readonly property int maxHeartRate: Math.round(qzStore.heart_max_override_enable ? qzStore.heart_max_override_value : 220 - qzStore.age)
    readonly property string nickname: qzStore.user_nickname.trim()
    readonly property string initial: nickname !== "" ? nickname.charAt(0).toUpperCase() : "B"
    readonly property string version: Qt.application.version

    // the Bluetooth devices QZ has seen, by name, without "Disabled", "Wifi" and the signal strength
    readonly property var devices: {
        var list = core !== null && core.bluetoothDevices ? core.bluetoothDevices : []
        var names = []
        for (var i = 0; i < list.length; i++) {
            var name = deviceLabel(list[i])
            if (name !== "Disabled" && name !== "Wifi" && names.indexOf(name) < 0)
                names.push(name)
        }
        return names
    }

    readonly property var sections: [
        { id: "bike", title: qsTr("Bike and sensors"), icon: "bike" },
        { id: "heart", title: qsTr("Heart rate"), icon: "heart" },
        { id: "body", title: qsTr("Body and FTP"), icon: "body" },
        { id: "zones", title: qsTr("Zones"), icon: "zones" },
        { id: "units", title: qsTr("Units and display"), icon: "units" },
        { id: "connections", title: qsTr("Connections"), icon: "link" },
        { id: "data", title: qsTr("Your data"), icon: "data" },
        { id: "about", title: qsTr("About"), icon: "info" }
    ]

    // the settings of QZ, same names, types and defaults as in settings.qml
    Settings {
        id: qzStore
        property int age: 35
        property real weight: 75.0
        property real ftp: 200.0
        property string user_nickname: ""
        property bool miles_unit: false
        property bool weight_kg_unit: false
        property string sex: "Male"
        property string heart_rate_belt_name: "Disabled"
        property bool heart_ignore_builtin: false
        property real heart_rate_zone1: 70.0
        property real heart_rate_zone2: 80.0
        property real heart_rate_zone3: 90.0
        property real heart_rate_zone4: 100.0
        property bool heart_max_override_enable: false
        property real heart_max_override_value: 195.0
        property int heart_rate_resting: 60
        property string filter_device: "Disabled"
        property string echelon_watttable: "Echelon"
    }

    // what only Bikemodo uses
    Settings {
        id: prefStore
        category: "ui2"
        property string detailLevel: "simple"
        property bool reduceMotion: false
    }

    Component.onCompleted: Theme.reduceMotion = prefStore.reduceMotion

    Timer {
        interval: 1000
        repeat: true
        running: screen.visible
        onTriggered: screen.tick++
    }

    function open(id) {
        // a box being typed in keeps its value when its page goes away
        screen.forceActiveFocus()
        section = id
    }

    // Android back: from a page to the list on a phone; true when it went back
    function goBack() {
        if (!wide && section !== "") {
            screen.forceActiveFocus()
            section = ""
            return true
        }
        return false
    }

    function needRestart() {
        restartNeeded = true
    }

    // a function of rootItem, or the fallback in a preview
    function ask(name, fallback) {
        var t = tick
        if (core !== null && typeof core[name] === "function")
            return core[name]()
        return fallback
    }

    // "Name (85%)" of rootItem.bluetoothDevices to "Name"
    function deviceLabel(entry) {
        var cut = entry.lastIndexOf(" (")
        var tail = entry.length >= 2 ? entry.substring(entry.length - 2) : ""
        return cut > 0 && tail === "%)" ? entry.substring(0, cut) : entry
    }

    function weightText(kg) {
        if (lbs)
            return qsTr("%1 lb").arg(Math.round(kg * 2.20462))
        return qsTr("%1 kg").arg(Math.round(kg * 10) / 10)
    }

    function summary(id) {
        var t = tick
        if (id === "bike") {
            if (connected)
                return deviceName !== "" ? deviceName : qsTr("Connected")
            return qzStore.filter_device !== "Disabled" ? qsTr("Waiting for %1").arg(qzStore.filter_device) : qsTr("Not connected")
        }
        if (id === "heart")
            return qzStore.heart_rate_belt_name === "Disabled" ? qsTr("From the bike") : qzStore.heart_rate_belt_name
        if (id === "body")
            return qsTr("FTP %1 W, %2").arg(Math.round(qzStore.ftp)).arg(weightText(qzStore.weight))
        if (id === "zones")
            return qsTr("7 power zones, 5 heart zones")
        if (id === "units")
            return (qzStore.miles_unit ? qsTr("Miles") : qsTr("Kilometers")) + ", "
                    + (prefStore.detailLevel === "pro" ? qsTr("Pro detail") : qsTr("Simple detail"))
        if (id === "connections") {
            var names = []
            if (ask("isStravaLoggedIn", false))
                names.push("Strava")
            if (ask("isIntervalsICULoggedIn", false))
                names.push("intervals.icu")
            if (ask("isGarminUploadConfigured", false))
                names.push("Garmin")
            if (ask("isPelotonLoggedIn", false))
                names.push("Peloton")
            return names.length === 0 ? qsTr("Nothing connected yet") : qsTr("%1 connected").arg(names.join(", "))
        }
        if (id === "data")
            return qsTr("Where rides are saved, import")
        return version !== "" ? qsTr("Bikemodo %1").arg(version) : qsTr("Bikemodo")
    }

    Keys.onBackPressed: event.accepted = goBack()
    Keys.onEscapePressed: event.accepted = goBack()

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // the list of sections, under the profile
    Item {
        id: listPane
        width: screen.wide ? 340 : screen.width
        height: screen.height
        visible: screen.wide || screen.section === ""
        clip: true

        onVisibleChanged: if (visible && !screen.wide && !Theme.reduceMotion) listEnter.start()
        NumberAnimation {
            id: listEnter
            target: listFlick
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.fast
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.effectsCurve
        }

        Glow {
            x: -180
            y: -220
            width: 520
            height: 520
            tint: Theme.accent
            opacity: 0.16
        }

        Flickable {
            id: listFlick
            anchors.fill: parent
            contentHeight: listColumn.y + listColumn.height + 32 + (screen.restartNeeded ? 140 : 0)
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: listColumn
                x: (listPane.width - width) / 2
                y: 28
                width: Math.min(720, listPane.width - 2 * (screen.margin - 12))

                Text {
                    width: parent.width
                    leftPadding: 12
                    rightPadding: 12
                    text: qsTr("You")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 34
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }

                Item {
                    width: 1
                    height: 16
                }

                // the profile: a tap opens Body and FTP
                PulseButton {
                    x: 12
                    width: parent.width - 24
                    height: Math.max(96, profileText.implicitHeight + 40)
                    radius: 28
                    pressedRadius: 20
                    fill: Theme.card
                    Accessible.name: (screen.nickname !== "" ? screen.nickname : qsTr("Add your name")) + ", " + qsTr("edit your profile")
                    onClicked: screen.open("body")

                    contentItem: Item {
                        PulseShape {
                            id: avatar
                            x: 18
                            width: 60
                            height: 60
                            anchors.verticalCenter: parent.verticalCenter
                            zone: 2
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: screen.initial
                                color: Theme.accentInk
                                font.family: Theme.display
                                font.pixelSize: 26
                            }
                        }
                        Column {
                            id: profileText
                            x: avatar.x + avatar.width + 16
                            width: parent.width - x - 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                width: parent.width
                                text: screen.nickname !== "" ? screen.nickname : qsTr("Add your name")
                                color: screen.nickname !== "" ? Theme.text : Theme.text2
                                font.family: Theme.display
                                font.pixelSize: 24
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: qsTr("FTP %1 W, max heart rate %2 bpm").arg(Math.round(qzStore.ftp)).arg(screen.maxHeartRate)
                                color: Theme.text3
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.labelSize
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 12
                }

                Repeater {
                    model: screen.sections
                    delegate: YouRow {
                        title: modelData.title
                        detail: screen.summary(modelData.id)
                        glyph: modelData.icon
                        iconColor: modelData.id === "heart" ? Theme.zoneColors[5] : Theme.accent
                        highlighted: screen.wide && screen.shown === modelData.id
                        trailing: screen.wide ? "" : "next"
                        hairline: index < screen.sections.length - 1
                        onClicked: screen.open(modelData.id)
                    }
                }
            }
        }
    }

    Rectangle {
        visible: screen.wide
        x: listPane.width
        width: 1
        height: screen.height
        color: Theme.hairline
    }

    Loader {
        id: pageLoader
        x: screen.wide ? listPane.width + 1 : 0
        width: screen.width - x
        height: screen.height
        visible: screen.shown !== ""
        sourceComponent: screen.shown === "bike" ? bikePage
                         : screen.shown === "heart" ? heartPage
                         : screen.shown === "body" ? bodyPage
                         : screen.shown === "zones" ? zonesPage
                         : screen.shown === "units" ? unitsPage
                         : screen.shown === "connections" ? connectionsPage
                         : screen.shown === "data" ? dataPage
                         : screen.shown === "about" ? aboutPage : null
    }

    Component { id: bikePage; BikePage { you: screen } }
    Component { id: heartPage; HeartPage { you: screen } }
    Component { id: bodyPage; BodyPage { you: screen } }
    Component { id: zonesPage; ZonesPage { you: screen } }
    Component { id: unitsPage; UnitsPage { you: screen } }
    Component { id: connectionsPage; ConnectionsPage { you: screen } }
    Component { id: dataPage; DataPage { you: screen } }
    Component { id: aboutPage; AboutPage { you: screen } }

    // some choices are read by QZ only when it starts
    Rectangle {
        width: Math.min(600, pageLoader.width - 2 * screen.margin)
        height: restartRow.height + 24
        // under the page, the list stays clear on a wide window
        x: pageLoader.x + (pageLoader.width - width) / 2
        y: screen.restartNeeded ? screen.height - height - 16 : screen.height + 8
        visible: screen.restartNeeded
        radius: 28
        color: Theme.floating
        border.width: 1
        border.color: Theme.hairline

        Behavior on y {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
        }

        Item {
            id: restartRow
            // on a narrow phone the button goes under the text
            readonly property bool stacked: width < restartButton.implicitWidth + 150
            x: 16
            y: 12
            width: parent.width - 32
            height: stacked ? restartText.implicitHeight + 10 + restartButton.height
                            : Math.max(restartButton.height, restartText.implicitHeight)
            Text {
                id: restartText
                y: restartRow.stacked ? 4 : (restartRow.height - height) / 2
                width: restartRow.stacked ? parent.width : parent.width - restartButton.width - 12
                leftPadding: 6
                text: qsTr("Some changes apply after a restart. If Bikemodo just closes, open it again.")
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize + 1
                wrapMode: Text.WordWrap
            }
            YouButton {
                id: restartButton
                x: restartRow.stacked ? 0 : parent.width - width
                y: restartRow.stacked ? parent.height - height : (restartRow.height - height) / 2
                width: restartRow.stacked ? parent.width : implicitWidth
                text: qsTr("Restart to apply")
                primary: true
                onClicked: screen.restartRequested()
            }
        }
    }
}
