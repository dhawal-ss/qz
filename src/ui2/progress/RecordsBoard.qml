import QtQuick 2.15
import ".."
import "../Format.js" as Format
import "Progress.js" as Progress

// Every record: the best watts for ten durations and the biggest ride and week. Each row says
// when it was set and how long it has stood, opens that ride from its date, and opens the
// history of the record (every time it was beaten) with a tap.
Card {
    id: card
    objectName: "recordsBoard"

    property var library: null
    property bool miles: false
    property real weight: 0          // kg, 0 when the rider has not set it

    signal openRide(int id)

    readonly property var powerDurations: [5, 15, 30, 60, 120, 300, 600, 1200, 1800, 3600]
    readonly property var totalKeys: ["longest", "kj", "week", "distance"]
    property var powerRows: []
    property var totalRows: []
    property string expanded: ""     // key of the row whose history is open
    property var history: []

    function totalLabel(key) {
        if (key === "longest")
            return qsTr("Longest ride")
        if (key === "kj")
            return qsTr("Most work")
        if (key === "week")
            return qsTr("Biggest week")
        return qsTr("Farthest ride")
    }

    function valueText(key, v) {
        if (key.charAt(0) === "p")
            return Math.round(v) + " W"
        if (key === "longest" || key === "week")
            return Format.hours(v)
        if (key === "kj")
            return Format.big(v) + " kJ"
        return Format.distance(v, miles)
    }

    function dateText(key, start) {
        return key === "week" ? qsTr("Week of %1").arg(Progress.shortDate(start)) : Format.day(start)
    }

    function refresh() {
        expanded = ""
        history = []
        if (!library) {
            powerRows = []
            totalRows = []
            return
        }
        var curve = library.powerCurve(0, 0)
        var rows = []
        for (var i = 0; i < curve.length; i++)
            if (powerDurations.indexOf(curve[i].seconds) >= 0)
                rows.push({ key: "p" + curve[i].seconds, seconds: curve[i].seconds, value: curve[i].watts,
                            start: curve[i].start, rideId: curve[i].rideId })
        powerRows = rows
        var records = library.rideRecords()
        var totals = []
        for (var k = 0; k < totalKeys.length; k++)
            for (var j = 0; j < records.length; j++)
                if (records[j].key === totalKeys[k])
                    totals.push(records[j])
        totalRows = totals
    }

    // open or close the history of a row; power histories are read only when opened
    function toggle(row) {
        if (expanded === row.key) {
            expanded = ""
            return
        }
        var steps = []
        var raw = row.key.charAt(0) === "p" ? library.recordHistory(row.seconds) : (row.history || [])
        for (var i = 0; i < raw.length; i++) {
            var v = raw[i].watts !== undefined ? raw[i].watts : raw[i].value
            steps.push({ start: raw[i].start, value: v, text: valueText(row.key, v) })
        }
        history = steps
        expanded = row.key
    }

    function note(row) {
        var n = history.length
        if (n === 0 || expanded !== row.key)
            return ""
        var since = Progress.shortDate(history[0].start)
        var text = qsTr("Set on %1 and not beaten since.").arg(since)
        if (n === 2)
            text = qsTr("Beaten once since %1, up from %2.").arg(since).arg(history[0].text)
        else if (n > 2)
            text = qsTr("Beaten %1 times since %2, up from %3.").arg(n - 1).arg(since).arg(history[0].text)
        if (row.key.charAt(0) === "p" && weight > 0)
            text += " " + qsTr("%1 W/kg at your weight.").arg((row.value / weight).toFixed(1))
        return text
    }

    onLibraryChanged: refresh()
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: card.library
        ignoreUnknownSignals: true
        function onChanged() { card.refresh() }
    }

    Text {
        text: qsTr("Records")
        color: Theme.text2
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.labelSize
    }

    Text {
        width: parent.width
        visible: card.powerRows.length === 0 && card.totalRows.length === 0
        text: qsTr("Your records start with your first ride.")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.bodySize
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: 0
        visible: card.powerRows.length > 0
        Text {
            text: qsTr("Power")
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: Theme.titleSize
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Repeater {
            model: card.powerRows
            RecordRow {
                id: powerRow
                label: Progress.effort(modelData.seconds)
                valueText: card.valueText(modelData.key, modelData.value)
                dateText: card.dateText(modelData.key, modelData.start)
                start: modelData.start
                rideId: modelData.rideId
                open: card.expanded === modelData.key
                steps: open ? card.history : []
                note: card.note(modelData)
                onToggle: card.toggle(modelData)
                onOpenRide: card.openRide(id)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 0
        visible: card.totalRows.length > 0
        Item {
            width: 1
            height: 4
        }
        Text {
            text: qsTr("Rides and weeks")
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: Theme.titleSize
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Repeater {
            model: card.totalRows
            RecordRow {
                id: totalRow
                label: card.totalLabel(modelData.key)
                valueText: card.valueText(modelData.key, modelData.value)
                dateText: card.dateText(modelData.key, modelData.start)
                start: modelData.start
                rideId: modelData.rideId
                open: card.expanded === modelData.key
                steps: open ? card.history : []
                note: card.note(modelData)
                onToggle: card.toggle(modelData)
                onOpenRide: card.openRide(id)
            }
        }
    }
}
