import QtQuick 2.15
import ".."
import "../Format.js" as Format
import "Progress.js" as Progress

// How much was ridden: time, distance, work or rides per week, month or year, the current one in
// the accent, with the total of the span and the current one over the bars.
Card {
    id: card

    property var library: null
    property bool miles: false

    property string span: "weeks"    // "weeks" (12), "months" (12) or "years" (5)
    property string metric: "seconds"
    property var buckets: []

    function refresh() {
        if (!library) {
            buckets = []
            return
        }
        var t = new Date()
        var count = span === "years" ? 5 : 12
        var list = []
        var from
        for (var b = 0; b < count; b++) {
            var start
            if (span === "weeks")
                start = new Date(t.getFullYear(), t.getMonth(), t.getDate() - (t.getDay() + 6) % 7 - (count - 1 - b) * 7, 12)
            else if (span === "months")
                start = new Date(t.getFullYear(), t.getMonth() - (count - 1 - b), 1, 12)
            else
                start = new Date(t.getFullYear() - (count - 1 - b), 0, 1, 12)
            list.push({ start: start.getTime(), seconds: 0, distance: 0, kj: 0, rides: 0 })
        }
        var days = library.days(list[0].start - 13 * 3600000, 0)
        var first = new Date(list[0].start)
        for (var d = 0; d < days.length; d++) {
            // days are local midnight: read them at noon, so a DST change never moves a day
            var day = Progress.noon(days[d].day + 12 * 3600000)
            var slot
            if (span === "weeks")
                slot = Math.floor(Math.round((day.getTime() - list[0].start) / 86400000) / 7)
            else if (span === "months")
                slot = (day.getFullYear() * 12 + day.getMonth()) - (first.getFullYear() * 12 + first.getMonth())
            else
                slot = day.getFullYear() - first.getFullYear()
            if (slot < 0 || slot >= count)
                continue
            list[slot].seconds += days[d].seconds
            list[slot].distance += days[d].distance
            list[slot].kj += days[d].kj
            list[slot].rides += days[d].rides
        }
        buckets = list
    }

    function value(bucket) {
        var v = bucket[metric]
        if (metric === "seconds")
            return v / 3600
        if (metric === "distance" && miles)
            return v * 0.621371
        return v
    }

    function valueText(v) {
        // whole hours from 10 h up, so a long total fits half the card
        if (metric === "seconds")
            return v >= 36000 ? Math.round(v / 3600) + " h" : Format.hours(v)
        if (metric === "distance")
            return Format.distance(v, miles)
        if (metric === "kj")
            return Format.big(v) + " kJ"
        return v === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(Format.big(v))
    }

    function values() {
        var out = []
        for (var i = 0; i < buckets.length; i++)
            out.push(value(buckets[i]))
        return out
    }

    function labels() {
        var out = []
        for (var i = 0; i < buckets.length; i++) {
            var d = new Date(buckets[i].start)
            var last = i === buckets.length - 1
            if (span === "weeks")
                out.push(i % 3 === 2 || last ? d.getDate() + "/" + (d.getMonth() + 1) : "")
            else if (span === "months")
                out.push(i % 2 === 1 || last ? Format.monthShort[d.getMonth()] : "")
            else
                out.push(String(d.getFullYear()))
        }
        return out
    }

    readonly property real total: {
        var sum = 0
        for (var i = 0; i < buckets.length; i++)
            sum += buckets[i][metric]
        return sum
    }
    readonly property real current: buckets.length > 0 ? buckets[buckets.length - 1][metric] : 0
    readonly property string currentName: span === "weeks" ? qsTr("This week") : (span === "months" ? qsTr("This month") : qsTr("This year"))
    readonly property string spanName: span === "weeks" ? qsTr("last 12 weeks") : (span === "months" ? qsTr("last 12 months") : qsTr("last 5 years"))

    onLibraryChanged: refresh()
    onSpanChanged: refresh()
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: card.library
        ignoreUnknownSignals: true
        function onChanged() { card.refresh() }
    }

    Text {
        text: qsTr("Volume")
        color: Theme.text2
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.labelSize
    }

    Chips {
        width: parent.width
        what: qsTr("Span")
        current: card.span
        options: [["weeks", qsTr("12 weeks")], ["months", qsTr("12 months")], ["years", qsTr("5 years")]]
        onPicked: card.span = key
    }

    Row {
        width: parent.width
        spacing: 16
        Column {
            width: (parent.width - 16) / 2
            spacing: 0
            Text {
                width: parent.width
                text: card.valueText(card.current)
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: 24
                elide: Text.ElideRight
            }
            Text {
                text: card.currentName
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }
        Column {
            width: (parent.width - 16) / 2
            spacing: 0
            Text {
                width: parent.width
                text: card.valueText(card.total)
                color: Theme.text2
                font.family: Theme.display
                font.pixelSize: 24
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: qsTr("In the %1").arg(card.spanName)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
                elide: Text.ElideRight
            }
        }
    }

    BarChart {
        width: parent.width
        height: 150
        values: card.values()
        labels: card.labels()
        Accessible.ignored: false
        Accessible.role: Accessible.Graphic
        Accessible.name: qsTr("%1 per %2, %3: %4").arg(card.metric === "seconds" ? qsTr("Time") : (card.metric === "distance" ? qsTr("Distance") : (card.metric === "kj" ? qsTr("Work") : qsTr("Rides"))))
                         .arg(card.span === "weeks" ? qsTr("week") : (card.span === "months" ? qsTr("month") : qsTr("year")))
                         .arg(card.spanName).arg(card.valueText(card.total))
    }

    Chips {
        width: parent.width
        what: qsTr("Show")
        current: card.metric
        options: [["seconds", qsTr("Time")], ["distance", qsTr("Distance")], ["kj", qsTr("Work")], ["rides", qsTr("Rides")]]
        onPicked: card.metric = key
    }
}
