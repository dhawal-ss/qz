import QtQuick 2.15
import "."
import "sig"
import "calendar"
import "rides"
import "Format.js" as Format
import "rides/Analysis.js" as Analysis

// Every ride as a journal: the year as a grid of days at the top, then the months, newest first,
// each under its name in display type with what it added up to, and each ride a row on a
// hairline with its own small Pulse in the zone it counts in, its day, a tiny power line and a
// mark for every record. On phones a tapped row grows into the ride (the row is the container
// the ride opens from) and going back slides the ride away as a predictive back does; on wide
// windows the ride sits beside the list and changes with a fade through.
Item {
    id: rides
    objectName: "ridesScreen"

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"
    property int selectedId: -1
    // the power of the rides is estimated (a bike without a power meter)
    property bool powerEstimated: false
    // rootItem, for the folder a shared picture is saved in
    property var core: null
    // the end of the page the floating navigation covers: the list and the ride scroll under it
    property real bottomClearance: 0

    signal openYou()

    readonly property bool twoPane: width >= 760
    // a ride covers the list (phones): the shell can hide its navigation
    readonly property bool detailOpen: !twoPane && shownId >= 0

    // the ride the detail shows: it stays while the detail slides away
    property int shownId: -1
    // phones: how far the ride has grown out of its row (0 to 1), and how far it has gone back
    property real openness: 0
    property real leave: 0
    // where the ride grows from: the row, or a row-sized strip in the middle
    property rect origin: Qt.rect(0, 0, 0, 0)
    // wide windows: the fade through between two rides
    property real paneFade: 1
    property var allRides: []
    property var monthTotals: ({})

    function open(id) {
        if (id === selectedId)
            return
        origin = rowRect(id)
        selectedId = id
    }

    // a row was tapped: the ride grows out of it
    function openFrom(id, item) {
        if (item) {
            var p = item.mapToItem(rides, 0, 0)
            origin = Qt.rect(p.x, p.y, item.width, item.height)
        }
        selectedId = id
    }

    function goBack() {
        if (!twoPane && selectedId >= 0) {
            selectedId = -1
            return true
        }
        return false
    }

    // the rect of the row of a ride on screen, else a row-sized strip in the middle
    function rowRect(id) {
        var kids = list.contentItem.children
        for (var i = 0; i < kids.length; i++) {
            var k = kids[i]
            if (k.rideId === id && k.visible) {
                var p = k.mapToItem(rides, 0, 0)
                if (p.y + k.height > 0 && p.y < rides.height)
                    return Qt.rect(p.x, p.y, k.width, k.height)
            }
        }
        var m = Theme.margin(width)
        return Qt.rect(m, height * 0.4, width - m * 2, 76)
    }

    onSelectedIdChanged: {
        if (twoPane) {
            backAnimation.stop()
            openAnimation.stop()
            openness = 1
            leave = 0
            if (selectedId < 0 || shownId < 0 || Theme.reduceMotion) {
                paneSwap.stop()
                shownId = selectedId
                paneFade = 1
                return
            }
            paneSwap.restart()
            return
        }
        if (selectedId >= 0) {
            backAnimation.stop()
            shownId = selectedId
            leave = 0
            if (Theme.reduceMotion) {
                openness = 1
                return
            }
            openness = 0
            openAnimation.restart()
            return
        }
        if (shownId < 0)
            return
        openAnimation.stop()
        if (Theme.reduceMotion) {
            shownId = -1
            openness = 0
            return
        }
        backAnimation.restart()
    }

    // the first ride of a tapped day
    function openDay(dayMs) {
        var day = Format.startOfDay(dayMs)
        for (var i = rideModel.count - 1; i >= 0; i--)
            if (Format.startOfDay(rideModel.get(i).start) === day) {
                open(rideModel.get(i).rideId)
                return
            }
    }

    function refresh() {
        rideModel.clear()
        if (!library) {
            allRides = []
            monthTotals = {}
            return
        }
        var list = library.rides(0, 5000)
        allRides = list
        monthTotals = Analysis.monthTotals(list)
        for (var i = 0; i < list.length; i++) {
            var r = list[i]
            rideModel.append({
                rideId: r.id, start: r.start, month: Format.month(r.start), title: Format.title(r),
                day: Format.day(r.start) + ", " + Format.time(r.start), length: Analysis.shortDuration(r.duration),
                zone: Analysis.rideZone(r.intensity), spark: JSON.stringify(r.spark || []),
                records: (r.records || []).length
            })
        }
        if (twoPane && selectedId < 0 && list.length > 0)
            selectedId = list[0].id
    }

    function monthLine(name) {
        var t = monthTotals[name]
        if (!t)
            return ""
        var parts = [t.rides === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(t.rides), Format.hours(t.seconds)]
        if (t.kj > 0)
            parts.push(qsTr("%1 kJ").arg(Format.big(t.kj)))
        return parts.join(", ")
    }

    onLibraryChanged: refresh()
    Component.onCompleted: refresh()
    onTwoPaneChanged: {
        if (twoPane && selectedId < 0 && rideModel.count > 0)
            selectedId = rideModel.get(0).rideId
        else if (twoPane) {
            openness = 1
            leave = 0
            shownId = selectedId
        }
    }
    Connections {
        target: rides.library
        ignoreUnknownSignals: true
        function onChanged() { rides.refresh() }
    }

    ListModel { id: rideModel }

    // phones: the ride grows out of its row on the emphasized curve, which does not overshoot
    // (an overshoot would push the edges off the screen)
    NumberAnimation {
        id: openAnimation
        target: rides
        property: "openness"
        to: 1
        duration: 480
        easing.type: Easing.Bezier
        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
    }
    // phones, going back: the ride shrinks a little and slides off to the side as it fades
    SequentialAnimation {
        id: backAnimation
        NumberAnimation {
            target: rides
            property: "leave"
            from: 0
            to: 1
            duration: 340
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
        }
        PropertyAction { target: rides; property: "shownId"; value: -1 }
        PropertyAction { target: rides; property: "openness"; value: 0 }
        PropertyAction { target: rides; property: "leave"; value: 0 }
    }
    // wide windows: the ride beside the list fades out, changes, and fades in
    SequentialAnimation {
        id: paneSwap
        NumberAnimation {
            target: rides
            property: "paneFade"
            to: 0
            duration: 90
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.effectsCurve
        }
        ScriptAction { script: rides.shownId = rides.selectedId }
        NumberAnimation {
            target: rides
            property: "paneFade"
            to: 1
            duration: 210
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.effectsCurve
        }
    }

    ListView {
        id: list
        readonly property real margin: Theme.margin(rides.width)
        readonly property real cover: rides.twoPane ? 0 : Math.min(1, rides.openness) * (1 - 0.6 * rides.leave)
        visible: rides.twoPane || rides.shownId < 0 || cover < 1
        x: 0
        width: rides.twoPane ? Math.min(420, rides.width * 0.42) : rides.width
        height: rides.height
        // behind a ride growing out of it, the list sinks back a little and dims
        scale: 1 - 0.04 * cover
        opacity: 1 - 0.75 * cover
        clip: true
        model: rideModel
        boundsBehavior: Flickable.StopAtBounds
        bottomMargin: 24 + rides.bottomClearance

        // the header grows once the calendar knows its size: stay at the top until the rider scrolls
        property bool scrolled: false
        onMovementStarted: scrolled = true
        Connections {
            target: list.headerItem
            function onHeightChanged() {
                if (!list.scrolled)
                    list.positionViewAtBeginning()
            }
        }

        header: Column {
            x: list.margin
            width: list.width - list.margin * 2
            spacing: 4
            PageHeader {
                width: parent.width
                title: qsTr("Rides")
                subtitle: rideModel.count === 0 ? ""
                          : (rideModel.count === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(rideModel.count))
                showYou: rides.showYou && !rides.twoPane
                initial: rides.initial
                onOpenYou: rides.openYou()
            }
            CalendarHeatmap {
                width: parent.width
                visible: rideModel.count > 0
                library: rides.library
                onDayClicked: rides.openDay(dayMs)
            }
            Text {
                width: parent.width
                visible: rideModel.count === 0
                topPadding: 24
                text: rides.library && rides.library.busy
                      ? qsTr("Reading your ride history, %1 of %2").arg(rides.library.indexed).arg(rides.library.toIndex)
                      : qsTr("No rides yet. Finish a ride and it shows up here, with every chart.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                wrapMode: Text.WordWrap
            }
        }

        // a month: its name in display type and what it added up to
        section.property: "month"
        section.delegate: Item {
            width: list.width
            height: 104
            Accessible.role: Accessible.Heading
            Accessible.name: section + ", " + rides.monthLine(section)
            Text {
                id: monthName
                x: list.margin
                y: 36
                width: parent.width - list.margin * 2
                text: section
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: 30
                font.letterSpacing: -0.6
                elide: Text.ElideRight
                Accessible.ignored: true
            }
            Text {
                x: list.margin
                anchors.top: monthName.bottom
                anchors.topMargin: 4
                width: parent.width - list.margin * 2
                text: rides.monthLine(section)
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
                elide: Text.ElideRight
                Accessible.ignored: true
            }
        }

        delegate: RideRow {
            id: row
            readonly property int rideId: model.rideId
            objectName: "rideRow" + index
            x: list.margin - 10
            width: list.width - list.margin * 2 + 20
            height: 76
            title: model.title
            day: model.day
            length: model.length
            zone: model.zone
            spark: JSON.parse(model.spark)
            records: model.records
            picked: rides.twoPane && rides.selectedId === model.rideId
            line: ListView.nextSection === ListView.section
            onClicked: rides.openFrom(model.rideId, row)
        }
    }

    Rectangle {
        visible: rides.twoPane
        x: list.width
        width: 1
        height: parent.height
        color: Theme.hairline
    }

    // the ride: on phones a container that grows out of the row, beside the list on wide windows
    Item {
        id: sheet
        readonly property real p: rides.twoPane ? 1 : rides.openness
        readonly property real fullX: rides.twoPane ? list.width + 1 : 0
        visible: rides.shownId >= 0
        x: rides.origin.x + (fullX - rides.origin.x) * p
        y: rides.origin.y * (1 - p)
        width: rides.origin.width + (rides.width - fullX - rides.origin.width) * p
        height: rides.origin.height + (rides.height - rides.origin.height) * p
        clip: !rides.twoPane && p < 1
        // going back: a little smaller, to the side, fading
        transform: [
            Scale {
                origin.x: sheet.width / 2
                origin.y: sheet.height / 2
                xScale: 1 - 0.1 * rides.leave
                yScale: 1 - 0.1 * rides.leave
            },
            Translate { x: rides.width * 0.16 * rides.leave }
        ]
        // it stays solid while it shrinks and moves, and fades only at the end
        opacity: Math.min(1, (1 - rides.leave) / 0.4) * (rides.twoPane ? rides.paneFade : 1)
        layer.enabled: rides.leave > 0

        // the row's surface becoming the page
        Rectangle {
            anchors.fill: parent
            radius: rides.twoPane ? 0 : Math.max(20 * (1 - sheet.p), 28 * rides.leave)
            color: Qt.rgba(Theme.control.r + (Theme.bg.r - Theme.control.r) * sheet.p,
                           Theme.control.g + (Theme.bg.g - Theme.control.g) * sheet.p,
                           Theme.control.b + (Theme.bg.b - Theme.control.b) * sheet.p, 1)
        }

        RideDetail {
            id: rideDetail
            x: -sheet.x + sheet.fullX
            y: -sheet.y
            width: rides.width - sheet.fullX
            height: rides.height
            // the content shows once the container has grown a good part of the way
            opacity: rides.twoPane ? 1 : Math.max(0, Math.min(1, (sheet.p - 0.3) / 0.5))
            library: rides.library
            rideId: rides.shownId
            miles: rides.miles
            showBack: !rides.twoPane
            powerEstimated: rides.powerEstimated
            core: rides.core
            rideList: rides.allRides
            bottomClearance: rides.bottomClearance
            onBack: rides.goBack()
        }
    }
}
