import QtQuick 2.15
import "."
import "charts"
import "laps"
import "Format.js" as Format

// One ride in depth: the numbers, power, heart rate, cadence, level and speed on one timeline
// that zooms and reads out under the finger, time in zones, best efforts and laps.
Item {
    id: detail

    property var library: null
    property int rideId: -1
    property bool miles: false
    property bool showBack: true
    property var ride: ({})
    property var samples: ({})
    // which metrics have data, worked out once per ride
    property var has: ({})
    property int loadedId: -1
    readonly property alias chartView: chartView

    signal back()

    // every 1 Hz sample of the ride, read once when the ride changes
    function load() {
        if (!library || rideId < 0) {
            ride = {}
            samples = {}
            has = {}
            loadedId = -1
            return
        }
        if (rideId === loadedId)
            return
        loadedId = rideId
        ride = library.ride(rideId)
        var all = library.samples(rideId, 0)
        var seconds = all.seconds || []
        has = { power: hasValues(all.power), heart: hasValues(all.heart), cadence: hasValues(all.cadence),
                speed: hasValues(all.speed), level: hasValues(all.level) }
        chartView.duration = seconds.length > 0 ? Math.max(1, seconds[seconds.length - 1]) : Math.max(1, ride.duration || 1)
        chartView.reset(true)
        samples = all
        flick.contentY = 0
    }

    readonly property var lapStarts: {
        var out = []
        var list = ride.laps || []
        for (var i = 0; i < list.length; i++)
            out.push(list[i].start)
        return out
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
    onLibraryChanged: {
        loadedId = -1
        load()
    }
    Component.onCompleted: load()

    ChartView { id: chartView }

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

            // power, heart rate, cadence, level and speed on one timeline
            Card {
                id: chartsCard
                readonly property real chartHeight: column.width < 520 ? 110 : 150
                width: column.width
                visible: detail.has.power === true || detail.has.heart === true || detail.has.cadence === true
                spacing: 14
                CursorReadout {
                    width: parent.width
                    view: chartView
                    samples: detail.samples
                    miles: detail.miles
                    heart: detail.has.heart === true
                    cadence: detail.has.cadence === true
                    speed: detail.has.speed === true
                    level: detail.has.level === true
                }
                TimeChart {
                    width: parent.width
                    height: chartsCard.chartHeight
                    visible: detail.has.power === true
                    view: chartView
                    seconds: detail.samples.seconds || []
                    values: detail.samples.power || []
                    name: qsTr("Power")
                    unit: "W"
                    color: Theme.accent
                    average: detail.ride.avgPower || 0
                    zoneColored: true
                    ftp: detail.ride.ftp || 0
                    laps: detail.lapStarts
                }
                TimeChart {
                    width: parent.width
                    height: chartsCard.chartHeight
                    visible: detail.has.heart === true
                    view: chartView
                    seconds: detail.samples.seconds || []
                    values: detail.samples.heart || []
                    name: qsTr("Heart rate")
                    unit: "bpm"
                    color: Theme.zoneColors[5]
                    average: detail.ride.avgHr || 0
                    fromLowest: true
                    laps: detail.lapStarts
                }
                TimeChart {
                    width: parent.width
                    height: chartsCard.chartHeight
                    visible: detail.has.cadence === true
                    view: chartView
                    seconds: detail.samples.seconds || []
                    values: detail.samples.cadence || []
                    name: qsTr("Cadence")
                    unit: "rpm"
                    color: Theme.zoneColors[1]
                    average: detail.ride.avgCadence || 0
                    laps: detail.lapStarts
                }
                TimeChart {
                    width: parent.width
                    height: chartsCard.chartHeight
                    visible: detail.has.level === true
                    view: chartView
                    seconds: detail.samples.seconds || []
                    values: detail.samples.level || []
                    name: qsTr("Level")
                    color: Theme.zoneColors[3]
                    laps: detail.lapStarts
                }
                TimeChart {
                    width: parent.width
                    height: chartsCard.chartHeight
                    visible: detail.has.speed === true
                    view: chartView
                    seconds: detail.samples.seconds || []
                    values: detail.samples.speed || []
                    name: qsTr("Speed")
                    unit: detail.miles ? "mph" : "km/h"
                    factor: detail.miles ? 0.621371 : 1
                    decimals: 1
                    color: Theme.zoneColors[0]
                    laps: detail.lapStarts
                }
                TimeAxis {
                    width: parent.width
                    view: chartView
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

            // laps: ribbon, bars, table and pacing; picking a lap zooms the charts to it
            LapsSection {
                width: column.width
                ride: detail.ride
                samples: detail.samples
                miles: detail.miles
                onLapSelected: {
                    if (index < 0) {
                        chartView.reset(false)
                        return
                    }
                    var lap = detail.ride.laps[index]
                    var s = detail.samples.seconds || []
                    var a = s[lap.start] || lap.start
                    var b = s[lap.start + lap.duration - 1] || (lap.start + lap.duration)
                    chartView.place(a / chartView.duration, Math.max(chartView.minSpan, (b - a) / chartView.duration))
                    flick.contentY = 0
                }
            }
        }
    }
}
