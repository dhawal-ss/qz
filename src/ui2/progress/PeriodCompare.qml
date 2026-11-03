import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format

// This week, month or year so far against the same stretch of the one before: up to the same
// weekday, date and time, as rows on hairlines. A rise is green, a fall stays quiet; nothing
// here is red. Simple shows time, distance and rides; Pro every row.
Column {
    id: card
    objectName: "periodCompare"

    property var library: null
    property bool miles: false

    property string span: "month"    // "week", "month" or "year"
    property bool pro: false
    property var now: ({})
    property var before: ({})

    function daysIn(year, month) {
        return new Date(year, month + 1, 0, 12).getDate()
    }

    function refresh() {
        if (!library) {
            now = {}
            before = {}
            return
        }
        var t = new Date()
        var start
        var prevStart
        var prevSame
        if (span === "week") {
            // from the first day of the week (Monday, or Sunday: Format.firstDay)
            var back = Format.weekday(t.getTime())
            start = new Date(t.getFullYear(), t.getMonth(), t.getDate() - back).getTime()
            prevStart = new Date(t.getFullYear(), t.getMonth(), t.getDate() - back - 7).getTime()
            prevSame = new Date(t.getFullYear(), t.getMonth(), t.getDate() - 7, t.getHours(), t.getMinutes()).getTime()
        } else if (span === "month") {
            // the 31st against a 30 day month is its last day, not the 1st after it
            start = new Date(t.getFullYear(), t.getMonth(), 1).getTime()
            prevStart = new Date(t.getFullYear(), t.getMonth() - 1, 1).getTime()
            var pm = new Date(prevStart)
            prevSame = new Date(pm.getFullYear(), pm.getMonth(), Math.min(t.getDate(), daysIn(pm.getFullYear(), pm.getMonth())),
                                t.getHours(), t.getMinutes()).getTime()
        } else {
            start = new Date(t.getFullYear(), 0, 1).getTime()
            prevStart = new Date(t.getFullYear() - 1, 0, 1).getTime()
            prevSame = new Date(t.getFullYear() - 1, t.getMonth(), Math.min(t.getDate(), daysIn(t.getFullYear() - 1, t.getMonth())),
                                t.getHours(), t.getMinutes()).getTime()
        }
        now = library.totals(start, 0)
        before = library.totals(prevStart, Math.min(prevSame, start))
    }

    function change(a, b) {
        if (!(b > 0))
            return a > 0 ? qsTr("new") : ""
        var pct = Math.round(100 * (a - b) / b)
        return (pct > 0 ? "+" : "") + pct + "%"
    }

    function avgPower(t) {
        return t.seconds > 0 ? t.kj * 1000 / t.seconds : 0
    }

    readonly property string beforeName: span === "week" ? qsTr("last week") : (span === "month" ? qsTr("last month") : qsTr("last year"))
    readonly property var rows: [
        [qsTr("Time"), Format.hours(now.seconds || 0), Format.hours(before.seconds || 0), change(now.seconds || 0, before.seconds || 0)],
        [qsTr("Distance"), Format.distance(now.distance || 0, miles), Format.distance(before.distance || 0, miles), change(now.distance || 0, before.distance || 0)],
        [qsTr("Work"), Format.big(now.kj || 0) + " kJ", Format.big(before.kj || 0) + " kJ", change(now.kj || 0, before.kj || 0)],
        [qsTr("Rides"), Format.big(now.rides || 0), Format.big(before.rides || 0), change(now.rides || 0, before.rides || 0)],
        [qsTr("Training load"), Format.big(now.tss || 0) + " TSS", Format.big(before.tss || 0) + " TSS", change(now.tss || 0, before.tss || 0)],
        [qsTr("Average power"), Math.round(avgPower(now)) + " W", Math.round(avgPower(before)) + " W", change(avgPower(now), avgPower(before))]
    ]

    // training load (rows[4]) needs the rider's own FTP (Theme.ftpSet)
    readonly property var shownRows: pro ? rows.filter(function (r, i) { return i !== 4 || Theme.ftpSet })
                                         : [rows[0], rows[1], rows[3]]

    onSpanChanged: refresh()

    spacing: 12

    SectionHead {
        width: parent.width
        title: qsTr("Compare")
        note: card.span === "week" ? qsTr("Same days last week")
              : (card.span === "month" ? qsTr("Same days last month") : qsTr("Same days last year"))
    }

    SegmentedToggle {
        width: Math.min(parent.width, 360)
        height: 40
        name: qsTr("Compare")
        options: [qsTr("This week"), qsTr("This month"), qsTr("This year")]
        currentIndex: ["week", "month", "year"].indexOf(card.span)
        onPicked: card.span = ["week", "month", "year"][index]
    }

    Column {
        width: parent.width
        spacing: 0
        Repeater {
            model: card.shownRows
            HairlineRow {
                id: compareRow
                width: parent.width
                label: modelData[0]
                sub: card.beforeName + " " + modelData[2]
                value: modelData[1]
                valueSize: 22
                delta: modelData[3]
                deltaColor: modelData[3].charAt(0) === "+" || modelData[3] === qsTr("new") ? Theme.zoneColors[2] : Theme.text3
                line: index < card.shownRows.length - 1
            }
        }
    }
}
