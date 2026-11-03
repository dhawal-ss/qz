import QtQuick 2.15
import "."
import "calendar"
import "Format.js" as Format

// Every ride, newest first, grouped by month. Tapping one opens its detail: over the list on
// phones, beside it on wide windows.
Item {
    id: rides

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"
    property int selectedId: -1

    signal openYou()

    readonly property bool twoPane: width >= 760

    function open(id) {
        selectedId = id
    }

    function goBack() {
        if (!twoPane && selectedId >= 0) {
            selectedId = -1
            return true
        }
        return false
    }

    // the first ride of a tapped day
    function openDay(dayMs) {
        var day = Format.startOfDay(dayMs)
        for (var i = rideModel.count - 1; i >= 0; i--)
            if (Format.startOfDay(rideModel.get(i).start) === day) {
                selectedId = rideModel.get(i).rideId
                return
            }
    }

    function refresh() {
        rideModel.clear()
        if (!library)
            return
        var list = library.rides(0, 5000)
        for (var i = 0; i < list.length; i++) {
            var r = list[i]
            rideModel.append({
                rideId: r.id, start: r.start, month: Format.month(r.start), title: Format.title(r),
                duration: r.duration, distance: r.distance, avgPower: r.avgPower, kj: r.kj,
                spark: JSON.stringify(r.spark || []), records: (r.records || []).length
            })
        }
        if (twoPane && selectedId < 0 && list.length > 0)
            selectedId = list[0].id
    }

    onLibraryChanged: refresh()
    Component.onCompleted: refresh()
    onTwoPaneChanged: if (twoPane && selectedId < 0 && rideModel.count > 0) selectedId = rideModel.get(0).rideId
    Connections {
        target: rides.library
        ignoreUnknownSignals: true
        function onChanged() { rides.refresh() }
    }

    ListModel { id: rideModel }

    ListView {
        id: list
        readonly property real margin: Theme.margin(rides.width)
        visible: rides.twoPane || rides.selectedId < 0
        x: 0
        width: rides.twoPane ? Math.min(420, rides.width * 0.42) : rides.width
        height: rides.height
        clip: true
        model: rideModel
        boundsBehavior: Flickable.StopAtBounds
        bottomMargin: 24

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
            Item { width: 1; height: rideModel.count > 0 ? 8 : 0 }
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

        section.property: "month"
        section.delegate: Item {
            width: list.width
            height: 44
            Text {
                x: list.margin
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                text: section
                color: Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.labelSize
            }
        }

        delegate: PulseButton {
            id: row
            x: list.margin - 8
            width: list.width - list.margin * 2 + 16
            height: 86
            radius: 20
            pressedScale: 0.98
            fill: rides.twoPane && rides.selectedId === model.rideId ? Theme.control : (pressed ? Theme.pressed : "transparent")
            Accessible.name: model.title + ", " + Format.day(model.start) + ", " + Format.duration(model.duration)
            onClicked: rides.selectedId = model.rideId

            contentItem: Item {
                Column {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 16 - spark.width - 12
                    spacing: 4
                    Row {
                        spacing: 8
                        width: parent.width
                        Text {
                            width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 8 : 0))
                            text: model.title
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            id: badge
                            visible: model.records > 0
                            width: badgeText.implicitWidth + 14
                            height: 20
                            radius: 10
                            color: Qt.rgba(1, 203 / 255, 82 / 255, 0.16)
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: qsTr("Record")
                                color: Theme.zoneColors[3]
                                font.family: Theme.bodySemibold
                                font.pixelSize: 11
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        text: Format.day(model.start) + "  ·  " + Format.time(model.start)
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Format.duration(model.duration) + "   " + Format.distance(model.distance, rides.miles)
                              + "   " + Format.whole(model.avgPower) + " W"
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.labelSize
                        elide: Text.ElideRight
                    }
                }
                Sparkline {
                    id: spark
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(96, row.width * 0.24)
                    height: 34
                    values: JSON.parse(model.spark)
                    color: Qt.rgba(201 / 255, 184 / 255, 1, 0.8)
                }
            }
        }
    }

    Rectangle {
        visible: rides.twoPane
        x: list.width
        width: 1
        height: parent.height
        color: Theme.hairline
    }

    RideDetail {
        visible: rides.selectedId >= 0
        x: rides.twoPane ? list.width + 1 : 0
        width: rides.width - x
        height: rides.height
        library: rides.library
        rideId: rides.selectedId
        miles: rides.miles
        showBack: !rides.twoPane
        onBack: rides.selectedId = -1
    }
}
