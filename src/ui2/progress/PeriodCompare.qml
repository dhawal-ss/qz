import QtQuick 2.15
import ".."
import "../Format.js" as Format

// This week, month or year so far against the same stretch of the one before: up to the same
// weekday, date and time. A rise is green, a fall stays quiet; nothing here is red.
Card {
    id: card

    property var library: null
    property bool miles: false

    property string span: "month"    // "week", "month" or "year"
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
            var back = (t.getDay() + 6) % 7
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
        width: parent.width
        text: card.span === "week" ? qsTr("This week so far, against the same days of last week")
              : (card.span === "month" ? qsTr("This month so far, against the same days of last month")
                                       : qsTr("This year so far, against the same days of last year"))
        color: Theme.text2
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.labelSize
        wrapMode: Text.WordWrap
    }

    Chips {
        width: parent.width
        what: qsTr("Compare")
        current: card.span
        options: [["week", qsTr("This week")], ["month", qsTr("This month")], ["year", qsTr("This year")]]
        onPicked: card.span = key
    }

    Column {
        width: parent.width
        spacing: 0
        Repeater {
            model: card.rows
            Item {
                id: compareRow
                width: parent.width
                height: 54
                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("%1: %2, %3 %4, %5").arg(modelData[0]).arg(modelData[1]).arg(card.beforeName).arg(modelData[2]).arg(modelData[3])
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - values.width - 12
                    spacing: 2
                    Text {
                        width: parent.width
                        text: modelData[0]
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.bodySize
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: card.beforeName + " " + modelData[2]
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: values
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        color: Theme.text
                        font.family: Theme.display
                        font.pixelSize: 19
                    }
                    Text {
                        width: 48
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: modelData[3]
                        color: modelData[3].charAt(0) === "+" || modelData[3] === qsTr("new") ? Theme.zoneColors[2] : Theme.text3
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                    }
                }
            }
        }
    }
}
