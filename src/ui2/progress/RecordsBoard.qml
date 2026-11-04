import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Progress.js" as Progress

// Every record on hairlines: the best watts for five durations (ten on Pro) and the biggest ride
// and week. Each row says when it was set and how long it has stood, draws every time it was
// beaten as a sparkline, opens that ride from its date and the full history with a tap.
// The histories are read in refresh(), which the page calls when the library changes: each power
// history is a pass over every ride.
Column {
    id: board
    objectName: "recordsBoard"

    property var library: null
    property bool miles: false
    property real weight: 0          // kg, 0 when the rider has not set it
    property bool pro: false

    signal openRide(int id)
    // the label asks for the Learn sheet of records, with the newest one
    signal learn(string key, var facts)

    function learnFacts() {
        var newest = null
        for (var i = 0; i < allPowerRows.length; i++)
            if (newest === null || allPowerRows[i].start > newest.start)
                newest = allPowerRows[i]
        if (newest === null)
            return { rides: 0 }
        return { rides: 1, newest: qsTr("%1 power").arg(Progress.effort(newest.seconds)),
                 when: Progress.stood(newest.start, Date.now()) === "today" ? qsTr("today") : qsTr("%1 ago").arg(Progress.stood(newest.start, Date.now())) }
    }

    readonly property var allDurations: [5, 15, 30, 60, 120, 300, 600, 1200, 1800, 3600]
    readonly property var simpleDurations: [5, 60, 300, 1200, 3600]
    readonly property var totalKeys: ["longest", "kj", "week", "distance"]
    property var allPowerRows: []
    property var totalRows: []
    readonly property var powerRows: {
        if (pro)
            return allPowerRows
        var out = []
        for (var i = 0; i < allPowerRows.length; i++)
            if (simpleDurations.indexOf(allPowerRows[i].seconds) >= 0)
                out.push(allPowerRows[i])
        return out
    }
    property string expanded: ""     // key of the row whose history is open

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
        // the biggest week is a Monday to Sunday week of the library (ridelibrary.cpp), its start a
        // local midnight: read 6 h in, as Qt 5 can read a midnight of the other half of the DST
        // year as 23:00 of the day before
        return key === "week" ? qsTr("Week of %1").arg(Progress.shortDate(start + 6 * 3600000)) : Format.day(start)
    }

    function steps(key, raw) {
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var v = raw[i].watts !== undefined ? raw[i].watts : raw[i].value
            out.push({ start: raw[i].start, value: v, text: valueText(key, v) })
        }
        return out
    }

    function refresh() {
        expanded = ""
        if (!library) {
            allPowerRows = []
            totalRows = []
            return
        }
        var curve = library.powerCurve(0, 0)
        var rows = []
        for (var i = 0; i < curve.length; i++)
            if (allDurations.indexOf(curve[i].seconds) >= 0) {
                var key = "p" + curve[i].seconds
                rows.push({ key: key, seconds: curve[i].seconds, value: curve[i].watts, start: curve[i].start,
                            rideId: curve[i].rideId, history: steps(key, library.recordHistory(curve[i].seconds)) })
            }
        allPowerRows = rows
        var records = library.rideRecords()
        var totals = []
        for (var k = 0; k < totalKeys.length; k++)
            for (var j = 0; j < records.length; j++)
                if (records[j].key === totalKeys[k]) {
                    var r = records[j]
                    totals.push({ key: r.key, value: r.value, start: r.start, rideId: r.rideId,
                                  history: steps(r.key, r.history || []) })
                }
        totalRows = totals
    }

    function toggleRow(row) {
        expanded = expanded === row.key ? "" : row.key
    }

    function note(row) {
        var history = row.history
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

    spacing: 0

    SectionHead {
        width: parent.width
        title: qsTr("Records")
        // power records of worked out watts (library.powerGroup 1) are this kind of bike's only
        note: board.library !== null && board.library.powerGroup === 1 ? qsTr("Power est., this bike") : qsTr("All time")
        learnable: true
        onLearn: board.learn("records", board.learnFacts())
    }

    Text {
        width: parent.width
        topPadding: 12
        visible: board.allPowerRows.length === 0 && board.totalRows.length === 0
        text: qsTr("Your records start with your first ride.")
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.fs(14)
        wrapMode: Text.WordWrap
    }

    Item {
        width: 1
        height: 4
    }

    Repeater {
        model: board.powerRows
        RecordRow {
            id: powerRow
            label: qsTr("%1 power").arg(Progress.effort(modelData.seconds))
            valueText: board.valueText(modelData.key, modelData.value)
            dateText: board.dateText(modelData.key, modelData.start)
            start: modelData.start
            rideId: modelData.rideId
            history: modelData.history
            open: board.expanded === modelData.key
            steps: open ? modelData.history : []
            note: board.note(modelData)
            onToggle: board.toggleRow(modelData)
            onOpenRide: board.openRide(id)
        }
    }

    Repeater {
        model: board.totalRows
        RecordRow {
            id: totalRow
            label: board.totalLabel(modelData.key)
            valueText: board.valueText(modelData.key, modelData.value)
            dateText: board.dateText(modelData.key, modelData.start)
            start: modelData.start
            rideId: modelData.rideId
            history: modelData.history
            open: board.expanded === modelData.key
            steps: open ? modelData.history : []
            note: board.note(modelData)
            onToggle: board.toggleRow(modelData)
            onOpenRide: board.openRide(id)
        }
    }
}
