import QtQuick 2.15
import "."
import "Format.js" as Format

// One ride in depth: the numbers, power, heart rate and cadence over the ride, time in zones,
// best efforts and laps. Phase 2 adds zooming, linked charts and the lap visuals.
Item {
    id: detail

    property var library: null
    property int rideId: -1
    property bool miles: false
    property bool showBack: true
    property var ride: ({})
    property var samples: ({})

    signal back()

    function load() {
        if (!library || rideId < 0) {
            ride = {}
            samples = {}
            return
        }
        ride = library.ride(rideId)
        samples = library.samples(rideId, 360)
        flick.contentY = 0
    }

    function hasValues(list) {
        if (!list)
            return false
        for (var i = 0; i < list.length; i++)
            if (list[i] > 0)
                return true
        return false
    }

    function isRecord(seconds) {
        var list = ride.records || []
        for (var i = 0; i < list.length; i++)
            if (list[i] === seconds)
                return true
        return false
    }

    readonly property var zoneTotal: {
        var sum = 0
        var z = ride.powerZones || []
        for (var i = 0; i < z.length; i++)
            sum += z[i]
        return Math.max(1, sum)
    }

    readonly property var shownBests: {
        var want = [5, 15, 30, 60, 120, 300, 600, 1200, 1800, 3600]
        var out = []
        var list = ride.best || []
        for (var i = 0; i < list.length; i++)
            if (want.indexOf(list[i].seconds) >= 0)
                out.push(list[i])
        return out
    }

    onRideIdChanged: load()
    onLibraryChanged: load()
    Component.onCompleted: load()

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.height + 40
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            readonly property real margin: Theme.margin(detail.width)
            x: margin
            width: Math.min(detail.width - margin * 2, 920)
            spacing: 16

            PageHeader {
                width: parent.width
                title: detail.ride.start ? Format.title(detail.ride) : ""
                subtitle: detail.ride.start ? Format.day(detail.ride.start) + "  ·  " + Format.time(detail.ride.start) : ""
                showBack: detail.showBack
                onBack: detail.back()
            }

            // the numbers
            Grid {
                id: stats
                width: parent.width
                columns: width < 520 ? 2 : 4
                rowSpacing: 18
                columnSpacing: 12
                Repeater {
                    model: [
                        [Format.duration(detail.ride.duration || 0), qsTr("Time")],
                        [Format.distance(detail.ride.distance || 0, detail.miles), qsTr("Distance")],
                        [Format.whole(detail.ride.avgPower) + " W", qsTr("Average power")],
                        [Format.whole(detail.ride.np) + " W", qsTr("Normalized power")],
                        [Format.big(detail.ride.kj || 0) + " kJ", qsTr("Work")],
                        [Format.whole(detail.ride.tss), qsTr("Training load")],
                        [detail.ride.avgHr > 0 ? Format.whole(detail.ride.avgHr) + " bpm" : "-", qsTr("Average heart rate")],
                        [Format.whole(detail.ride.avgCadence) + " rpm", qsTr("Average cadence")]
                    ]
                    Column {
                        width: (stats.width - stats.columnSpacing * (stats.columns - 1)) / stats.columns
                        spacing: 4
                        Text {
                            width: parent.width
                            text: modelData[0]
                            color: Theme.text
                            font.family: Theme.display
                            font.pixelSize: 26
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: modelData[1]
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.tertiarySize
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // a metric over the ride, with the clock under it
            Repeater {
                model: [
                    { key: "power", name: qsTr("Power"), unit: "W", color: Theme.accent, avg: detail.ride.avgPower, lowest: false },
                    { key: "heart", name: qsTr("Heart rate"), unit: "bpm", color: Theme.zoneColors[5], avg: detail.ride.avgHr, lowest: true },
                    { key: "cadence", name: qsTr("Cadence"), unit: "rpm", color: Theme.zoneColors[1], avg: detail.ride.avgCadence, lowest: false }
                ]
                Card {
                    width: column.width
                    visible: detail.hasValues(detail.samples[modelData.key])
                    Row {
                        spacing: 10
                        Text {
                            text: modelData.name
                            color: Theme.text2
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.labelSize
                        }
                        Text {
                            text: qsTr("average %1 %2").arg(Format.whole(modelData.avg)).arg(modelData.unit)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.tertiarySize
                        }
                    }
                    AreaChart {
                        width: parent.width
                        height: column.width < 520 ? 120 : 160
                        values: detail.samples[modelData.key] || []
                        color: modelData.color
                        unit: modelData.unit
                        average: modelData.avg || 0
                        fromLowest: modelData.lowest
                    }
                    Item {
                        width: parent.width
                        height: 14
                        Text {
                            text: "0:00"
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 11
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Format.duration((detail.ride.duration || 0) / 2)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 11
                        }
                        Text {
                            anchors.right: parent.right
                            text: Format.duration(detail.ride.duration || 0)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // time in power zones
            Card {
                width: column.width
                visible: (detail.ride.powerZones || []).length === 7 && detail.zoneTotal > 1
                Text {
                    text: qsTr("Time in power zones")
                    color: Theme.text2
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.labelSize
                }
                Row {
                    width: parent.width
                    height: 14
                    spacing: 2
                    Repeater {
                        model: detail.ride.powerZones || []
                        Rectangle {
                            visible: modelData > 0
                            width: Math.max(0, (parent.width - 12) * modelData / detail.zoneTotal)
                            height: parent.height
                            radius: 4
                            color: Theme.zoneColors[index]
                        }
                    }
                }
                Repeater {
                    model: detail.ride.powerZones || []
                    Item {
                        width: parent.width
                        height: 30
                        visible: modelData > 0
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.zoneColors[index]
                        }
                        Text {
                            x: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Z" + (index + 1) + "  " + Theme.powerZoneNames[index]
                            color: Theme.text
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.bodySize
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Format.duration(modelData) + "   " + Math.round(100 * modelData / detail.zoneTotal) + "%"
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.labelSize
                        }
                    }
                }
            }

            // best efforts in this ride
            Card {
                width: column.width
                visible: detail.shownBests.length > 0
                Text {
                    text: qsTr("Best efforts")
                    color: Theme.text2
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.labelSize
                }
                Repeater {
                    model: detail.shownBests
                    Item {
                        width: parent.width
                        height: 34
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Format.effort(modelData.seconds)
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.bodySize
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Rectangle {
                                visible: detail.isRecord(modelData.seconds)
                                width: recordText.implicitWidth + 14
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(1, 203 / 255, 82 / 255, 0.16)
                                Text {
                                    id: recordText
                                    anchors.centerIn: parent
                                    text: qsTr("Record")
                                    color: Theme.zoneColors[3]
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                text: Math.round(modelData.watts) + " W"
                                color: Theme.text
                                font.family: Theme.display
                                font.pixelSize: 20
                            }
                        }
                    }
                }
            }

            // laps
            Card {
                width: column.width
                visible: (detail.ride.laps || []).length > 1
                Text {
                    text: qsTr("Laps")
                    color: Theme.text2
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.labelSize
                }
                Repeater {
                    model: [{ header: true }].concat(detail.ride.laps || [])
                    Row {
                        width: parent.width
                        height: 30
                        readonly property bool head: modelData.header === true
                        readonly property real cell: (width - 36) / 4
                        Text {
                            width: 36
                            text: parent.head ? "#" : modelData.index + 1
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.labelSize
                        }
                        Repeater {
                            model: parent.head ? [qsTr("Time"), qsTr("Power"), qsTr("Heart rate"), qsTr("Cadence")]
                                               : [Format.duration(modelData.duration), Format.whole(modelData.avgPower) + " W",
                                                  modelData.avgHr > 0 ? Format.whole(modelData.avgHr) : "-",
                                                  Format.whole(modelData.avgCadence)]
                            Text {
                                width: parent.cell
                                text: modelData
                                color: parent.head ? Theme.text3 : Theme.text
                                font.family: parent.head ? Theme.bodyMedium : Theme.bodySemibold
                                font.pixelSize: Theme.labelSize
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}
