import QtQuick 2.15
import "."
import "Format.js" as Format

// Trends and records: power records with the ride that set them, the last twelve weeks, and
// this month against the last. Phase 3 adds the power curve and fitness and fatigue.
Item {
    id: progress

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"

    signal openYou()
    signal openRide(int id)

    property var records: []
    property var weeks: []
    property string weekMetric: "seconds"
    property var thisMonth: ({})
    property var lastMonth: ({})

    function refresh() {
        if (!library) {
            records = []
            weeks = []
            return
        }
        var want = [5, 15, 30, 60, 120, 300, 600, 1200, 1800, 3600]
        var curve = library.powerCurve(0, 0)
        var picked = []
        for (var i = 0; i < curve.length; i++)
            if (want.indexOf(curve[i].seconds) >= 0)
                picked.push(curve[i])
        records = picked

        var monday = Format.weekStart(Date.now())
        var from = monday - 11 * 7 * 86400000
        var buckets = []
        for (var w = 0; w < 12; w++)
            buckets.push({ start: from + w * 7 * 86400000, seconds: 0, distance: 0, kj: 0, rides: 0 })
        var days = library.days(from, 0)
        for (var d = 0; d < days.length; d++) {
            var slot = Math.floor((Format.startOfDay(days[d].day) - from) / (7 * 86400000))
            if (slot < 0 || slot > 11)
                continue
            buckets[slot].seconds += days[d].seconds
            buckets[slot].distance += days[d].distance
            buckets[slot].kj += days[d].kj
            buckets[slot].rides += days[d].rides
        }
        weeks = buckets

        var now = new Date()
        var monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime()
        var prevStart = new Date(now.getFullYear(), now.getMonth() - 1, 1).getTime()
        var prevSameDay = new Date(now.getFullYear(), now.getMonth() - 1, now.getDate(), now.getHours(), now.getMinutes()).getTime()
        thisMonth = library.totals(monthStart, 0)
        lastMonth = library.totals(prevStart, Math.min(prevSameDay, monthStart))
    }

    function weekValues() {
        var out = []
        for (var i = 0; i < weeks.length; i++) {
            var v = weeks[i][weekMetric]
            out.push(weekMetric === "seconds" ? v / 3600 : (weekMetric === "distance" && miles ? v * 0.621371 : v))
        }
        return out
    }

    function weekLabels() {
        var out = []
        for (var i = 0; i < weeks.length; i++) {
            var d = new Date(weeks[i].start)
            out.push(i % 3 === 2 || i === weeks.length - 1 ? d.getDate() + "/" + (d.getMonth() + 1) : "")
        }
        return out
    }

    function change(now, before) {
        if (!before || before <= 0)
            return now > 0 ? qsTr("new") : ""
        var pct = Math.round(100 * (now - before) / before)
        return (pct >= 0 ? "+" : "") + pct + "%"
    }

    onLibraryChanged: refresh()
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: progress.library
        ignoreUnknownSignals: true
        function onChanged() { progress.refresh() }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.height + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            readonly property real margin: Theme.margin(progress.width)
            readonly property bool twoColumns: progress.width >= 680
            readonly property real columnWidth: twoColumns ? (width - 16) / 2 : width
            x: margin
            width: Math.min(progress.width - margin * 2, 1120)
            spacing: 16

            PageHeader {
                width: parent.width
                title: qsTr("Progress")
                showYou: progress.showYou
                initial: progress.initial
                onOpenYou: progress.openYou()
            }

            Text {
                width: parent.width
                visible: progress.records.length === 0
                text: qsTr("Your records and trends start with your first ride.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: 16
                visible: progress.records.length > 0

                Card {
                    width: content.columnWidth
                    Text {
                        text: qsTr("Last 12 weeks")
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                    }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [["seconds", qsTr("Time")], ["distance", qsTr("Distance")], ["kj", qsTr("Work")], ["rides", qsTr("Rides")]]
                            PulseButton {
                                width: chipText.implicitWidth + 28
                                height: 36
                                fill: progress.weekMetric === modelData[0] ? Theme.accent : Theme.chip
                                Accessible.name: qsTr("Show %1").arg(modelData[1])
                                onClicked: progress.weekMetric = modelData[0]
                                contentItem: Text {
                                    id: chipText
                                    text: modelData[1]
                                    color: progress.weekMetric === modelData[0] ? Theme.accentInk : Theme.text2
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                    BarChart {
                        width: parent.width
                        height: 150
                        values: progress.weekValues()
                        labels: progress.weekLabels()
                    }
                }

                Card {
                    width: content.columnWidth
                    Text {
                        text: qsTr("This month so far, against last month")
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                    }
                    Repeater {
                        model: [
                            [qsTr("Time"), Format.hours(progress.thisMonth.seconds || 0), progress.change(progress.thisMonth.seconds, progress.lastMonth.seconds)],
                            [qsTr("Distance"), Format.distance(progress.thisMonth.distance || 0, progress.miles), progress.change(progress.thisMonth.distance, progress.lastMonth.distance)],
                            [qsTr("Work"), Format.big(progress.thisMonth.kj || 0) + " kJ", progress.change(progress.thisMonth.kj, progress.lastMonth.kj)],
                            [qsTr("Rides"), Format.big(progress.thisMonth.rides || 0), progress.change(progress.thisMonth.rides, progress.lastMonth.rides)]
                        ]
                        Item {
                            width: parent.width
                            height: 36
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[0]
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.bodySize
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Text {
                                    text: modelData[1]
                                    color: Theme.text
                                    font.family: Theme.display
                                    font.pixelSize: 19
                                }
                                Text {
                                    width: 52
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData[2]
                                    color: modelData[2].charAt(0) === "+" || modelData[2] === qsTr("new") ? Theme.zoneColors[2] : Theme.text3
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.labelSize
                                }
                            }
                        }
                    }
                }

                Card {
                    width: content.columnWidth
                    Text {
                        text: qsTr("Power records")
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                    }
                    Repeater {
                        model: progress.records
                        PulseButton {
                            width: parent.width
                            height: 52
                            radius: 16
                            fill: pressed ? Theme.pressed : "transparent"
                            Accessible.name: qsTr("%1 record, %2 watts, %3").arg(Format.effort(modelData.seconds)).arg(Math.round(modelData.watts)).arg(Format.day(modelData.start))
                            onClicked: progress.openRide(modelData.rideId)
                            contentItem: Item {
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: Format.effort(modelData.seconds)
                                        color: Theme.text
                                        font.family: Theme.bodySemibold
                                        font.pixelSize: Theme.bodySize
                                    }
                                    Text {
                                        text: Format.day(modelData.start)
                                        color: Theme.text3
                                        font.family: Theme.bodyMedium
                                        font.pixelSize: Theme.tertiarySize
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Math.round(modelData.watts) + " W"
                                    color: Theme.text
                                    font.family: Theme.display
                                    font.pixelSize: 22
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
