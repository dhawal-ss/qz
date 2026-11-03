import QtQuick 2.15
import Qt.labs.settings 1.0
import ".."
import "../sig"

// You: the profile and the settings Bikemodo needs, the bike, heart rate, power, body, zones,
// units, connections, the rides on disk and the credits. The profile leads as a hero (the initial
// in the Pulse, the name, FTP and max heart rate), the sections follow as hairline rows under cap
// labels, with Units and Make it yours (MakeItYours.qml) set right on the list. The list of
// sections and the open page side by side on wide windows, one after the other on phones.
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
    // miles or kilometers was picked: the shell passes it to the other screens at once
    signal milesPicked(bool miles)

    // a page over You with its own bottom actions: the shell moves the floating navigation aside
    readonly property bool covering: pageLoader.item !== null && pageLoader.item.covering === true

    // Bikemodo's own choices (ui2), read fresh each time You shows: other screens write some of
    // them (the ride screen its layout, Progress the detail level), and Settings objects do not
    // see each other's writes
    property var look: ({ detailLevel: "simple", reduceMotion: false, ridePreset: "power", accentChoice: "lavender",
                          weekStart: 1, resistanceControl: "auto", mergeGapMinutes: 10 })

    // the end of the page the floating navigation covers: the content scrolls under it
    property real bottomClearance: 0

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
    // watts are an estimate unless a connected bike says it measures them
    readonly property bool powerEstimated: !(connected && metrics.powerEstimated === false)
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

    readonly property var groups: [
        { id: "ride", title: qsTr("What you ride with") },
        { id: "you", title: qsTr("Your numbers") },
        { id: "app", title: qsTr("The app") }
    ]
    readonly property var sections: [
        { id: "bike", title: qsTr("Bike and sensors"), icon: "bike", group: "ride" },
        { id: "heart", title: qsTr("Heart rate"), icon: "heart", group: "ride" },
        { id: "power", title: qsTr("Power"), icon: "bolt", group: "ride" },
        { id: "body", title: qsTr("Body and FTP"), icon: "body", group: "you" },
        { id: "zones", title: qsTr("Zones"), icon: "zones", group: "you" },
        { id: "connections", title: qsTr("Connections"), icon: "link", group: "app" },
        { id: "data", title: qsTr("Your data"), icon: "data", group: "app" },
        { id: "about", title: qsTr("About"), icon: "info", group: "app" }
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

    // what only Bikemodo uses, read and written by key (readLook, setLook)
    Settings {
        id: prefStore
        category: "ui2"
    }

    Component.onCompleted: {
        readLook()
        Theme.reduceMotion = look.reduceMotion
    }
    onVisibleChanged: if (visible) readLook()

    function flag(v, fallback) {
        if (v === undefined || v === null || v === "")
            return fallback
        return v === true || v === "true"
    }

    function readLook() {
        var preset = String(prefStore.value("ridePreset", "power"))
        var gap = Number(prefStore.value("mergeGapMinutes", 10))
        var first = Number(prefStore.value("weekStart", 1))
        look = {
            detailLevel: String(prefStore.value("detailLevel", "simple")) === "pro" ? "pro" : "simple",
            reduceMotion: flag(prefStore.value("reduceMotion", false), false),
            ridePreset: ["power", "simple", "heart"].indexOf(preset) >= 0 ? preset : "custom",
            accentChoice: Theme.accentChoice,
            weekStart: first === 0 ? 0 : 1,
            resistanceControl: ["auto", "on", "off"].indexOf(String(prefStore.value("resistanceControl", "auto"))) >= 0
                               ? String(prefStore.value("resistanceControl", "auto")) : "auto",
            mergeGapMinutes: isNaN(gap) ? 10 : Math.max(0, Math.min(60, Math.round(gap)))
        }
    }

    // one Bikemodo choice: stored at once, applied where it shows right away
    function setLook(key, value) {
        prefStore.setValue(key, value)
        if (key === "ridePreset")
            prefStore.setValue("rideLayout", "")   // the ride screen opens the preset, not an old custom layout
        if (key === "reduceMotion")
            Theme.reduceMotion = value
        if (key === "accentChoice")
            Theme.accentChoice = value
        // every week of the app counts from it: Theme tells the bindings and the JavaScript files
        if (key === "weekStart")
            Theme.weekStart = Number(value) === 0 ? 0 : 1
        prefStore.sync()
        var next = {}
        for (var k in look)
            next[k] = look[k]
        next[key] = value
        look = next
    }

    // QZ's units, written as settings.qml does, and synced so the ride sees them at once
    function setMiles(value) {
        qzStore.miles_unit = value
        qzStore.setValue("miles_unit", value)
        qzStore.sync()
        milesPicked(value)
    }

    function setWeightKg(value) {
        qzStore.weight_kg_unit = value
        qzStore.setValue("weight_kg_unit", value)
        qzStore.sync()
    }

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

    // Android back: a page in steps goes a step back, else from a page to the list on a phone;
    // true when it went back
    function goBack() {
        if (pageLoader.item !== null && typeof pageLoader.item.goBack === "function" && pageLoader.item.goBack())
            return true
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
        if (id === "power")
            return powerEstimated ? qsTr("Estimated from level and cadence") : qsTr("Measured by the bike")
        if (id === "body")
            return qsTr("FTP %1 W, %2").arg(Math.round(qzStore.ftp)).arg(weightText(qzStore.weight))
        if (id === "zones")
            return qsTr("7 power zones, 5 heart zones")
        if (id === "units")
            return (qzStore.miles_unit ? qsTr("Miles") : qsTr("Kilometers")) + ", "
                    + (look.detailLevel === "pro" ? qsTr("Pro detail") : qsTr("Simple detail"))
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

    // the profile hero and the sections, grouped under cap labels on hairlines; nothing here is a
    // raised surface, so the open page beside it on a tablet may have its one
    Item {
        id: listPane
        width: screen.wide ? 340 : screen.width
        height: screen.height
        visible: screen.wide || screen.section === ""
        clip: true

        signal entered()
        onVisibleChanged: if (visible && !screen.wide) entered()

        Flickable {
            id: listFlick
            objectName: "youList"
            anchors.fill: parent
            contentHeight: listColumn.y + listColumn.height + 32 + screen.bottomClearance + (screen.restartNeeded ? 140 : 0)
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: listColumn
                x: (listPane.width - width) / 2
                y: 24
                width: Math.min(720, listPane.width - 2 * (screen.margin - 12))

                // the profile: the initial in the Pulse, the name, and the two numbers zones
                // come from; a tap opens Body and FTP
                Rise {
                    cue: listPane
                    order: 0
                    width: parent.width
                    PulseButton {
                        id: profile
                        width: parent.width
                        height: 112
                        radius: 28
                        pressedScale: 0.98
                        fill: pressed ? Theme.control : Qt.rgba(0, 0, 0, 0)
                        Accessible.name: (screen.nickname !== "" ? screen.nickname : qsTr("Add your name")) + ", " + qsTr("edit your profile")
                        onClicked: screen.open("body")

                        HeroGlow {
                            width: 300
                            height: 300
                            x: avatar.x + avatar.width / 2 - width / 2
                            y: avatar.y + avatar.height / 2 - height / 2
                            tint: Theme.accent
                            low: 0.16
                            high: 0.26
                        }
                        Item {
                            id: avatar
                            x: 12
                            width: 88
                            height: 88
                            anchors.verticalCenter: parent.verticalCenter
                            Pulse {
                                anchors.fill: parent
                                zone: 3
                                color: Theme.accent
                                turning: true
                            }
                            Text {
                                anchors.centerIn: parent
                                text: screen.initial
                                color: Theme.accentInk
                                font.family: Theme.display
                                font.pixelSize: 34
                            }
                        }
                        Column {
                            x: avatar.x + avatar.width + 18
                            width: parent.width - x - 40
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text {
                                width: parent.width
                                text: screen.nickname !== "" ? screen.nickname : qsTr("Add your name")
                                color: screen.nickname !== "" ? Theme.text : Theme.text2
                                font.family: Theme.display
                                font.pixelSize: 28
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: qsTr("Edit your profile")
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.labelSize
                                elide: Text.ElideRight
                            }
                        }
                        YouIcon {
                            x: parent.width - width - 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: "next"
                            size: 20
                            weight: 1.8
                            color: Theme.text3
                        }
                    }
                }

                Rise {
                    cue: listPane
                    order: 1
                    width: parent.width
                    KeyNumbers {
                        x: 12
                        width: parent.width - 24
                        columns: 2
                        valueSize: 30
                        items: [
                            { value: String(Math.round(screen.qz.ftp)), unit: qsTr("W"), label: qsTr("FTP"), estimated: screen.powerEstimated },
                            { value: String(screen.maxHeartRate), unit: qsTr("bpm"), label: qsTr("Max heart rate") }
                        ]
                    }
                }

                Repeater {
                    model: screen.groups
                    delegate: Rise {
                        id: group
                        readonly property string groupId: modelData.id
                        readonly property var members: screen.sections.filter(function (s) { return s.group === group.groupId })
                        cue: listPane
                        order: index + 2
                        width: listColumn.width
                        Column {
                            width: parent.width
                            // units and the rider's own choices, before the app's sections
                            Loader {
                                active: group.groupId === "app"
                                visible: active
                                width: parent.width
                                sourceComponent: MakeItYours { you: screen }
                            }
                            YouText {
                                kind: "heading"
                                text: modelData.title
                            }
                            Repeater {
                                model: group.members
                                delegate: YouRow {
                                    title: modelData.title
                                    detail: screen.summary(modelData.id)
                                    glyph: modelData.icon
                                    iconColor: modelData.id === "heart" ? Theme.zoneColors[5] : Theme.accent
                                    highlighted: screen.wide && screen.shown === modelData.id
                                    trailing: screen.wide ? "" : "next"
                                    hairline: index < group.members.length - 1
                                    onClicked: screen.open(modelData.id)
                                }
                            }
                        }
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
                         : screen.shown === "power" ? powerPage
                         : screen.shown === "body" ? bodyPage
                         : screen.shown === "zones" ? zonesPage
                         : screen.shown === "units" ? unitsPage
                         : screen.shown === "connections" ? connectionsPage
                         : screen.shown === "data" ? dataPage
                         : screen.shown === "about" ? aboutPage : null
    }

    Component { id: bikePage; BikePage { you: screen } }
    Component { id: heartPage; HeartPage { you: screen } }
    Component { id: powerPage; PowerPage { you: screen } }
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
        y: screen.restartNeeded ? screen.height - height - 16 - screen.bottomClearance : screen.height + 8
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
