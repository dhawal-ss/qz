import QtQuick 2.15
import ".."
import "../Format.js" as Format

// A year of riding as a grid of days: a column per week from its first day (Monday, or Sunday
// when weeks start on Sunday: Theme.weekStart) to its last, the newest week
// on the right, each day lighter the more was ridden. Narrow screens show the most recent weeks
// that fit. The grid is one button: a tap picks the day under the finger.
// Days are worked out at noon: the JavaScript engine of Qt 5 can read local midnight of a DST
// change as 23:00 of the day before, noon is never on the wrong day.
Item {
    id: heat

    property var library: null
    // "seconds", "kj" or "tss"
    property string metric: "seconds"
    property int weeks: 53

    // local midnight of a ride day; noon for a day without a ride (see the note on noon above)
    signal dayClicked(real dayMs)

    // y * 10000 + month * 100 + day -> the day of library.days()
    property var dayMap: ({})
    property int yearRides: 0
    property int longestStreak: 0
    property var today: noon(new Date())
    // noon of the day tapped last, -1 for none
    property real pickedMs: -1

    readonly property int gap: 3
    readonly property int labelWidth: 18
    readonly property int monthHeight: 18
    readonly property real gridRoom: Math.max(0, width - labelWidth)
    // square cells of 10 to 18 px; when every week does not fit, the most recent ones that do
    readonly property int shownWeeks: {
        var wanted = Math.max(1, weeks)
        if (Math.floor((gridRoom - gap * (wanted - 1)) / wanted) >= 10)
            return wanted
        return Math.max(1, Math.min(wanted, Math.floor((gridRoom + gap) / (10 + gap))))
    }
    readonly property int cell: Math.max(4, Math.min(18, Math.floor((gridRoom - gap * (shownWeeks - 1)) / shownWeeks)))
    readonly property int pitch: cell + gap

    readonly property int todayKey: keyOf(today)
    readonly property int todayRow: (today.getDay() - Theme.weekStart + 7) % 7
    // noon of the first day of the first column (a Monday, or a Sunday)
    readonly property var firstMonday: new Date(today.getFullYear(), today.getMonth(),
                                                today.getDate() - todayRow - (shownWeeks - 1) * 7, 12)

    // shades from no ride to the accent
    readonly property var shades: {
        var a = Theme.chip
        var b = Theme.accent
        var out = []
        var steps = [0, 0.3, 0.52, 0.76, 1]
        for (var i = 0; i < steps.length; i++) {
            var t = steps[i]
            out.push(Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1))
        }
        return out
    }

    readonly property string summary: {
        var rides = yearRides === 0 ? qsTr("No rides in the last 12 months yet")
                  : (yearRides === 1 ? qsTr("1 ride in the last 12 months") : qsTr("%1 rides in the last 12 months").arg(yearRides))
        if (yearRides === 0)
            return rides
        return rides + ", " + (longestStreak === 1 ? qsTr("longest streak 1 day") : qsTr("longest streak %1 days").arg(longestStreak))
    }

    implicitHeight: monthHeight + 7 * pitch - gap + 14 + footer.height

    function noon(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12)
    }

    function keyOf(date) {
        return date.getFullYear() * 10000 + date.getMonth() * 100 + date.getDate()
    }

    // the key of a day of library.days(), which is local midnight
    function keyOfDay(ms) {
        return keyOf(new Date(ms + 12 * 3600000))
    }

    function dateAt(column, row) {
        return new Date(firstMonday.getFullYear(), firstMonday.getMonth(), firstMonday.getDate() + column * 7 + row, 12)
    }

    // 0 for no ride, then 1 to 4 by minutes, kJ or training load
    function level(entry) {
        if (!entry || !(entry.rides > 0))
            return 0
        var v = metric === "kj" ? entry.kj : (metric === "tss" ? entry.tss : entry.seconds / 60)
        var steps = metric === "kj" ? [300, 600, 900] : [30, 60, 90]
        var out = 1
        for (var i = 0; i < steps.length; i++)
            if (v >= steps[i])
                out++
        return out
    }

    function refresh() {
        today = noon(new Date())
        if (!library) {
            dayMap = {}
            yearRides = 0
            longestStreak = 0
            return
        }
        var first = new Date(today.getFullYear(), today.getMonth(), today.getDate() - todayRow - (Math.max(weeks, 53) - 1) * 7, 12)
        // the last 12 months: 365 days up to today
        var yearStart = keyOf(new Date(today.getFullYear(), today.getMonth(), today.getDate() - 364, 12))
        var list = library.days(first.getTime() - 13 * 3600000, 0)
        var map = {}
        var rides = 0
        var streak = 0
        var run = 0
        var previous = -1
        for (var i = 0; i < list.length; i++) {
            var key = keyOfDay(list[i].day)
            var day = list[i].day
            map[key] = list[i]
            if (key < yearStart || !(list[i].rides > 0))
                continue
            rides += list[i].rides
            // days, not 24 h: a day next to a DST change is 23 or 25 hours long
            run = previous >= 0 && Math.round((day - previous) / 86400000) === 1 ? run + 1 : 1
            streak = Math.max(streak, run)
            previous = day
        }
        dayMap = map
        yearRides = rides
        longestStreak = streak
    }

    function dayText(ms) {
        var entry = dayMap[keyOf(new Date(ms))]
        if (!entry || !(entry.rides > 0))
            return Format.day(ms) + ": " + qsTr("no ride")
        var rides = entry.rides === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(entry.rides)
        return Format.day(ms) + ": " + rides + ", " + Format.hours(entry.seconds) + ", " + Format.big(entry.kj) + " kJ"
    }

    onLibraryChanged: refresh()
    onWeeksChanged: refresh()
    Component.onCompleted: refresh()
    Connections {
        target: heat.library
        ignoreUnknownSignals: true
        function onChanged() { heat.refresh() }
    }

    // month names over the week where a month begins
    Item {
        x: heat.labelWidth
        width: heat.width - heat.labelWidth
        height: heat.monthHeight
        Accessible.ignored: true
        readonly property var marks: {
            var out = []
            for (var c = 1; c < heat.shownWeeks; c++) {
                var m = heat.dateAt(c, 0).getMonth()
                if (m !== heat.dateAt(c - 1, 0).getMonth())
                    out.push({ column: c, text: Format.monthShort[m] })
            }
            // the first column gets the name of its month only when the next name is far enough
            if (out.length === 0 || out[0].column * heat.pitch >= 34)
                out.unshift({ column: 0, text: Format.monthShort[heat.dateAt(0, 6).getMonth()] })
            return out
        }
        Repeater {
            model: parent.marks
            Text {
                x: Math.min(modelData.column * heat.pitch, heat.width - heat.labelWidth - implicitWidth)
                text: modelData.text
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 11
            }
        }
    }

    // weekday initials, every other one when the rows are tight
    Repeater {
        model: Format.weekLetters(Theme.weekStart)
        Text {
            y: heat.monthHeight + index * heat.pitch + (heat.cell - height) / 2
            width: heat.labelWidth - 4
            visible: heat.pitch >= 15 || index % 2 === 0
            text: modelData
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 10
            Accessible.ignored: true
        }
    }

    PulseButton {
        id: grid
        x: heat.labelWidth
        y: heat.monthHeight
        width: heat.shownWeeks * heat.pitch - heat.gap
        height: 7 * heat.pitch - heat.gap
        radius: 4
        pressedScale: 1
        // a screen reader clicks without a press: then the day is today
        property bool touched: false
        Accessible.name: heat.summary + ". " + qsTr("Tap a day to open it")
        onPressed: touched = true
        onCanceled: touched = false
        onClicked: {
            var date = heat.today
            if (touched) {
                var column = Math.max(0, Math.min(heat.shownWeeks - 1, Math.floor((grid.pressX + heat.gap / 2) / heat.pitch)))
                var row = Math.max(0, Math.min(6, Math.floor((grid.pressY + heat.gap / 2) / heat.pitch)))
                date = heat.dateAt(column, row)
            }
            touched = false
            if (heat.keyOf(date) > heat.todayKey)
                return
            heat.pickedMs = date.getTime()
            var entry = heat.dayMap[heat.keyOf(date)]
            heat.dayClicked(entry ? entry.day : date.getTime())
        }

        contentItem: Item {
            Accessible.ignored: true
            Repeater {
                model: heat.shownWeeks * 7
                Rectangle {
                    id: dayCell
                    readonly property int column: Math.floor(index / 7)
                    readonly property int row: index % 7
                    readonly property var day: heat.dateAt(column, row)
                    x: column * heat.pitch
                    y: row * heat.pitch
                    width: heat.cell
                    height: heat.cell
                    radius: heat.cell >= 14 ? 4 : 3
                    visible: heat.keyOf(dayCell.day) <= heat.todayKey
                    color: heat.shades[heat.level(heat.dayMap[heat.keyOf(dayCell.day)])]
                }
            }

            // today, and the day picked last, as rings around their cells
            Rectangle {
                x: (heat.shownWeeks - 1) * heat.pitch - 2
                y: heat.todayRow * heat.pitch - 2
                width: heat.cell + 4
                height: heat.cell + 4
                radius: heat.cell >= 14 ? 6 : 5
                color: "transparent"
                border.width: 1.5
                border.color: Theme.text
            }
            Rectangle {
                // days from the first day of the grid; rounded, as a day next to a DST change is not 24 h
                readonly property int offset: Math.round((heat.pickedMs - heat.firstMonday.getTime()) / 86400000)
                visible: heat.pickedMs >= 0 && heat.keyOf(new Date(heat.pickedMs)) !== heat.todayKey
                         && offset >= 0 && offset < heat.shownWeeks * 7
                x: Math.floor(offset / 7) * heat.pitch - 2
                y: (offset % 7) * heat.pitch - 2
                width: heat.cell + 4
                height: heat.cell + 4
                radius: heat.cell >= 14 ? 6 : 5
                color: "transparent"
                border.width: 1.5
                border.color: Theme.accent
            }
        }
    }

    Column {
        id: footer
        y: grid.y + grid.height + 14
        width: heat.width
        spacing: 8

        Text {
            width: parent.width
            visible: heat.pickedMs >= 0
            text: heat.pickedMs >= 0 ? heat.dayText(heat.pickedMs) : ""
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.labelSize
            elide: Text.ElideRight
        }

        Flow {
            width: parent.width
            spacing: 12
            Text {
                width: Math.min(implicitWidth, parent.width)
                text: heat.summary
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
            Row {
                spacing: 4
                Accessible.ignored: true
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 2
                    text: qsTr("Less")
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                }
                Repeater {
                    model: heat.shades
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 3
                        color: modelData
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 2
                    text: qsTr("More")
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                }
            }
        }
    }
}
