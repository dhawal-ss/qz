import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Progress.js" as Progress
import "Hub.js" as Hub

// How much was ridden each week: 12 finished weeks (52 on a year), last week in the accent with
// its total as the headline, and the 4 week average as a line over the bars. Pro can show
// distance, work or rides instead of time.
Column {
    id: volume
    objectName: "volumeCard"

    property var library: null
    property bool miles: false
    property string period: "3m"
    property bool pro: false

    property string metric: "seconds"
    property var weeks: []           // [{start, seconds, distance, kj, rides}] oldest first, last week last

    readonly property string shownMetric: pro ? metric : "seconds"
    readonly property var values: {
        var out = []
        for (var i = 0; i < weeks.length; i++)
            out.push(value(weeks[i]))
        return out
    }
    // the average reaches back 3 weeks before the first bar
    readonly property int lead: 3
    readonly property var bars: values.slice(Math.min(values.length, lead))
    readonly property var averages: Hub.rolling(values, 4).slice(Math.min(values.length, lead))
    readonly property var lastWeek: weeks.length > 0 ? weeks[weeks.length - 1] : null
    readonly property real step: {
        var hi = 0
        for (var i = 0; i < bars.length; i++)
            hi = Math.max(hi, bars[i], averages[i])
        var steps = [0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]
        for (var k = 0; k < steps.length; k++)
            if (hi / steps[k] <= 4)
                return steps[k]
        return 10000
    }
    readonly property real scaleTop: {
        var hi = 0
        for (var i = 0; i < bars.length; i++)
            hi = Math.max(hi, bars[i], averages[i])
        return Math.max(step, Math.ceil(hi * 1.05 / step) * step)
    }

    function refresh() {
        if (!library) {
            weeks = []
            return
        }
        var t = new Date()
        var count = Hub.volumeWeeks(period) + lead
        var list = []
        for (var b = 0; b < count; b++) {
            // the first day of the week (Monday, or Sunday: Format.firstDay), the last one the week before this
            var start = new Date(t.getFullYear(), t.getMonth(), t.getDate() - Format.weekday(t.getTime()) - (count - b) * 7, 12)
            list.push({ start: start.getTime(), seconds: 0, distance: 0, kj: 0, rides: 0 })
        }
        var days = library.days(list[0].start - 13 * 3600000, 0)
        for (var d = 0; d < days.length; d++) {
            // days are local midnight: read them at noon, so a DST change never moves a day
            var day = Progress.noon(days[d].day + 12 * 3600000)
            var slot = Math.floor(Math.round((day.getTime() - list[0].start) / Hub.dayMs) / 7)
            if (slot < 0 || slot >= count)
                continue
            list[slot].seconds += days[d].seconds
            list[slot].distance += days[d].distance
            list[slot].kj += days[d].kj
            list[slot].rides += days[d].rides
        }
        weeks = list
    }

    function play() {
        drawIn.play()
    }

    function value(week) {
        var v = week[shownMetric]
        if (shownMetric === "seconds")
            return v / 3600
        if (shownMetric === "distance" && miles)
            return v * 0.621371
        return v
    }

    // the headline number and the words after it
    function bigText(v) {
        if (shownMetric === "seconds")
            return Hub.hm(v * 3600)
        if (shownMetric === "distance")
            return v >= 100 ? String(Math.round(v)) : v.toFixed(1)
        return Format.big(v)
    }

    function unitText() {
        if (shownMetric === "seconds")
            return qsTr("hours")
        if (shownMetric === "distance")
            return miles ? "mi" : "km"
        if (shownMetric === "kj")
            return "kJ"
        return qsTr("rides")
    }

    function axisText(v) {
        if (shownMetric === "seconds")
            return (v % 1 === 0 ? v : v.toFixed(1)) + " h"
        return Format.big(v)
    }

    function shortText(v) {
        if (shownMetric === "seconds")
            return v.toFixed(1) + " h"
        if (shownMetric === "distance")
            return Math.round(v) + (miles ? " mi" : " km")
        if (shownMetric === "kj")
            return Format.big(v) + " kJ"
        return v.toFixed(1)
    }

    function xOf(i) {
        return (i + 0.5) * plot.width / Math.max(1, bars.length)
    }

    function yOf(v) {
        return plot.height * (1 - Math.max(0, v) / scaleTop)
    }

    readonly property var avgLine: {
        var out = []
        if (plot.width < 2)
            return out
        for (var i = 0; i < averages.length; i++)
            out.push(Qt.point(xOf(i), yOf(averages[i])))
        return out
    }

    spacing: 12

    SectionHead {
        width: parent.width
        title: qsTr("Weekly volume")
        note: qsTr("%1 weeks").arg(volume.bars.length)
    }

    Item {
        width: parent.width
        height: volumeNumber.height
        visible: volume.lastWeek !== null
        Accessible.role: Accessible.StaticText
        Accessible.name: volume.lastWeek ? qsTr("Last week %1 %2, %3 rides").arg(volume.bigText(volume.value(volume.lastWeek)))
                                           .arg(volume.unitText()).arg(volume.lastWeek.rides) : ""
        Row {
            spacing: 8
            RollingNumber {
                id: volumeNumber
                value: volume.lastWeek ? volume.bigText(volume.value(volume.lastWeek)) : ""
                font.family: Theme.display
                font.pixelSize: 30
            }
            Text {
                anchors.bottom: volumeNumber.bottom
                anchors.bottomMargin: 6
                text: {
                    if (!volume.lastWeek)
                        return ""
                    var rides = volume.lastWeek.rides === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(volume.lastWeek.rides)
                    if (volume.shownMetric === "rides")
                        return qsTr("rides last week")
                    return qsTr("%1 last week, %2").arg(volume.unitText()).arg(rides)
                }
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
            }
        }
    }

    DrawIn {
        id: drawIn
        width: parent.width
        height: chartBox.height

        Item {
            id: chartBox
            width: drawIn.width
            height: plot.y + plot.height + 24
            Accessible.role: Accessible.Graphic
            Accessible.name: qsTr("Weekly %1 over %2 weeks, 4 week average %3")
                             .arg(volume.unitText()).arg(volume.bars.length)
                             .arg(volume.averages.length > 0 ? volume.shortText(volume.averages[volume.averages.length - 1]) : "0")

            Text {
                id: avgLabel
                anchors.right: plot.right
                text: volume.averages.length > 0 ? qsTr("4-week avg %1").arg(volume.shortText(volume.averages[volume.averages.length - 1])) : ""
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(12)
            }

            Item {
                id: plot
                y: avgLabel.height + 8
                width: parent.width - 34
                height: volume.width < 480 ? 120 : 140

                Repeater {
                    model: Math.round(volume.scaleTop / volume.step)
                    Item {
                        id: gridLine
                        readonly property real at: (index + 1) * volume.step
                        y: Math.round(volume.yOf(at))
                        width: plot.width
                        Hairline {
                            width: parent.width
                            opacity: 0.6
                        }
                        Text {
                            x: plot.width + 34 - implicitWidth
                            y: -implicitHeight / 2
                            text: volume.axisText(gridLine.at)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(11)
                        }
                    }
                }
                Hairline {
                    y: plot.height
                    width: plot.width
                }

                Repeater {
                    model: volume.bars.length
                    Rectangle {
                        id: weekBar
                        readonly property real slot: plot.width / Math.max(1, volume.bars.length)
                        readonly property bool last: index === volume.bars.length - 1
                        readonly property real v: volume.bars[index] || 0
                        width: Math.max(2, Math.min(14, slot * 0.64))
                        x: volume.xOf(index) - width / 2
                        height: Math.max(v > 0 ? 3 : 0, plot.height - volume.yOf(v))
                        y: plot.height - height
                        radius: Math.min(3.5, width / 2)
                        color: last ? Theme.accent : Qt.rgba(1, 1, 1, 0.2)
                    }
                }

                Shape {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeColor: Theme.text
                        strokeWidth: 1.6
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        capStyle: ShapePath.RoundCap
                        PathPolyline { path: volume.avgLine }
                    }
                }
                Rectangle {
                    visible: volume.averages.length > 0
                    x: volume.xOf(volume.averages.length - 1) - width / 2
                    y: volume.averages.length > 0 ? volume.yOf(volume.averages[volume.averages.length - 1]) - height / 2 : 0
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.text
                    border.width: 1.5
                    border.color: Theme.bg
                }
            }

            Text {
                y: plot.y + plot.height + 6
                text: volume.weeks.length > volume.lead ? Progress.shortDate(volume.weeks[volume.lead].start) : ""
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(11)
            }
            Text {
                y: plot.y + plot.height + 6
                anchors.right: plot.right
                text: qsTr("Last week")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(11)
            }
        }
    }

    SegmentedToggle {
        width: Math.min(parent.width, 360)
        height: 40
        visible: volume.pro
        name: qsTr("Show")
        options: [qsTr("Time"), qsTr("Distance"), qsTr("Work"), qsTr("Rides")]
        currentIndex: ["seconds", "distance", "kj", "rides"].indexOf(volume.metric)
        onPicked: volume.metric = ["seconds", "distance", "kj", "rides"][index]
    }
}
