import QtQuick 2.15
import ".."
import "../Format.js" as Format

// One month as a calendar, its weeks from the first day the rider picked (Monday, or Sunday:
// Theme.weekStart): ride days are tinted, carry a dot and their minutes and
// open with a tap. Previous and next step through the months, never past the current one.
// Days are worked out at noon: the JavaScript engine of Qt 5 can read local midnight of a DST
// change as 23:00 of the day before, noon is never on the wrong day.
Item {
    id: month

    property var library: null
    // a time in the shown month, by default noon of its first day
    property real monthMs: {
        var d = new Date()
        return new Date(d.getFullYear(), d.getMonth(), 1, 12).getTime()
    }

    signal dayClicked(real dayMs)

    // day of the month -> the day of library.days()
    property var dayMap: ({})
    property int monthRides: 0
    property real monthSeconds: 0
    property int todayKey: keyOf(new Date())

    readonly property var first: {
        var d = new Date(monthMs)
        return new Date(d.getFullYear(), d.getMonth(), 1, 12)
    }
    readonly property int lead: (first.getDay() - Theme.weekStart + 7) % 7
    readonly property int length: new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
    readonly property int rows: Math.ceil((lead + length) / 7)
    readonly property bool atCurrent: Format.monthKey(monthMs) >= Format.monthKey(Date.now())
    readonly property real cellWidth: width / 7

    implicitHeight: content.height

    function keyOf(date) {
        return date.getFullYear() * 10000 + date.getMonth() * 100 + date.getDate()
    }

    function refresh() {
        todayKey = keyOf(new Date())
        var map = {}
        var rides = 0
        var seconds = 0
        if (library) {
            var start = new Date(monthMs)
            // from an hour before midnight of the 1st to after the last day: days() is per day anyway
            var from = new Date(start.getFullYear(), start.getMonth(), 1, 12).getTime() - 13 * 3600000
            var to = new Date(start.getFullYear(), start.getMonth() + 1, 1, 12).getTime() - 11 * 3600000
            var list = library.days(from, to)
            for (var i = 0; i < list.length; i++) {
                var day = new Date(list[i].day + 12 * 3600000)
                if (day.getMonth() !== start.getMonth())
                    continue
                map[day.getDate()] = list[i]
                rides += list[i].rides
                seconds += list[i].seconds
            }
        }
        dayMap = map
        monthRides = rides
        monthSeconds = seconds
    }

    function step(by) {
        var start = new Date(monthMs)
        monthMs = new Date(start.getFullYear(), start.getMonth() + by, 1, 12).getTime()
    }

    onMonthMsChanged: refresh()
    onLibraryChanged: refresh()
    Component.onCompleted: refresh()
    Connections {
        target: month.library
        ignoreUnknownSignals: true
        function onChanged() { month.refresh() }
    }

    Column {
        id: content
        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: 48
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 104
                spacing: 2
                Text {
                    width: parent.width
                    text: Format.monthNames[month.first.getMonth()] + " " + month.first.getFullYear()
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 16
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: month.monthRides === 0 ? qsTr("No rides")
                          : (month.monthRides === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(month.monthRides))
                            + ", " + Format.hours(month.monthSeconds)
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.tertiarySize
                    elide: Text.ElideRight
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                PulseButton {
                    width: 48
                    height: 48
                    fill: Theme.control
                    Accessible.name: qsTr("Previous month")
                    onClicked: month.step(-1)
                    contentItem: Item {
                        Icon { anchors.centerIn: parent; name: "back"; size: 20; color: Theme.text }
                    }
                }
                PulseButton {
                    width: 48
                    height: 48
                    enabled: !month.atCurrent
                    opacity: enabled ? 1 : 0.35
                    fill: Theme.control
                    Accessible.name: qsTr("Next month")
                    onClicked: month.step(1)
                    contentItem: Item {
                        Icon { anchors.centerIn: parent; name: "forward"; size: 20; color: Theme.text }
                    }
                }
            }
        }

        Row {
            width: parent.width
            Repeater {
                model: Format.weekLetters(Theme.weekStart)
                Text {
                    width: month.cellWidth
                    text: modelData
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    Accessible.ignored: true
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7
            Repeater {
                model: month.rows * 7
                Item {
                    id: slot
                    readonly property int date: index - month.lead + 1
                    readonly property bool inMonth: date >= 1 && date <= month.length
                    readonly property var entry: inMonth ? month.dayMap[date] : undefined
                    readonly property bool rode: entry !== undefined && entry.rides > 0
                    readonly property var day: new Date(month.first.getFullYear(), month.first.getMonth(), date, 12)
                    readonly property int key: month.keyOf(day)
                    width: month.cellWidth
                    height: 52

                    PulseButton {
                        id: dayButton
                        visible: slot.inMonth
                        anchors.fill: parent
                        topInset: 2
                        bottomInset: 2
                        leftInset: 2
                        rightInset: 2
                        enabled: slot.rode
                        radius: 14
                        fill: slot.rode ? Theme.accentWash(dayButton.pressed ? 0.24 : 0.12) : "transparent"
                        Accessible.name: slot.rode
                                         ? Format.day(slot.day.getTime()) + ", " + (slot.entry.rides === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(slot.entry.rides))
                                           + ", " + Format.hours(slot.entry.seconds)
                                         : Format.day(slot.day.getTime()) + ", " + qsTr("no ride")
                        onClicked: month.dayClicked(slot.entry.day)
                        contentItem: Item {
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                visible: slot.key === month.todayKey
                                radius: 14
                                color: "transparent"
                                border.width: 1.5
                                border.color: Theme.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: slot.rode ? 6 : (parent.height - height) / 2
                                text: slot.date
                                color: slot.rode ? Theme.text : (slot.key > month.todayKey ? Theme.dashed : Theme.text3)
                                font.family: slot.rode ? Theme.bodySemibold : Theme.bodyMedium
                                font.pixelSize: 14
                            }
                            Rectangle {
                                x: parent.width - 11
                                y: 7
                                width: 5
                                height: 5
                                radius: 2.5
                                visible: slot.rode
                                color: Theme.accent
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                visible: slot.rode
                                text: slot.rode ? Math.round(slot.entry.seconds / 60) + (month.cellWidth >= 64 ? " min" : "'") : ""
                                color: Theme.accent
                                font.family: Theme.bodyMedium
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }
}
