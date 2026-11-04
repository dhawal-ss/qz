import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Hub.js" as Hub

// The last 52 weeks as a strip of days, a column a week from its first day (Monday, or Sunday:
// Format.firstDay) to its last, each day stronger
// the harder it was (Hub.level), today outlined. Over it the weekly goal streak and the active
// weeks, under it the streak freezes saved (goals/Streak.js, as on Goals). Narrow screens fold
// the year into two half years, one over the other.
Column {
    id: consistency
    objectName: "consistencyCard"

    property var library: null
    property int streak: 0           // goal weeks in a row, Streak.run().streak
    property int freezes: 0          // Streak.run().freezes
    property int toNextFreeze: 0     // Streak.run().toNextFreeze

    property var levels: []          // 364 days, oldest first: 0 to 4
    property int activeWeeks: 0
    property real firstMonday: 0     // noon of the first day of the first column
    property int todayIndex: 0

    readonly property int weekCount: 52
    readonly property int blockWeeks: Math.floor((width + 3) / weekCount) >= 8 ? weekCount : weekCount / 2
    readonly property int blocks: weekCount / blockWeeks
    readonly property real pitch: (width + gapSize) / blockWeeks
    readonly property int gapSize: blockWeeks === weekCount ? 2 : 3
    readonly property real cellSize: Math.min(16, pitch - gapSize)
    readonly property var shades: [Theme.overlay(0.06), Theme.accentWash(0.28), Theme.accentWash(0.52),
                                   Theme.accentWash(0.78), Theme.accent]

    function refresh() {
        var t = new Date()
        var back = Format.weekday(t.getTime())
        var first = new Date(t.getFullYear(), t.getMonth(), t.getDate() - back - (weekCount - 1) * 7, 12)
        firstMonday = first.getTime()
        todayIndex = (weekCount - 1) * 7 + back
        var out = []
        for (var i = 0; i < weekCount * 7; i++)
            out.push(0)
        var active = {}
        if (library) {
            var days = library.days(first.getTime() - 13 * 3600000, 0)
            for (var d = 0; d < days.length; d++) {
                var noon = new Date(days[d].day + 12 * 3600000)
                noon = new Date(noon.getFullYear(), noon.getMonth(), noon.getDate(), 12)
                var index = Math.round((noon.getTime() - first.getTime()) / Hub.dayMs)
                if (index < 0 || index >= out.length)
                    continue
                out[index] = Math.max(out[index], Hub.level(days[d].tss, days[d].seconds))
                if (days[d].rides > 0)
                    active[Math.floor(index / 7)] = true
            }
        }
        var count = 0
        for (var k in active)
            count++
        activeWeeks = count
        levels = out
    }

    function play() {
        drawIn.play()
    }

    // the months under a block: [{column, text}] where a month starts in the first week
    function months(block) {
        var out = []
        var last = -1
        for (var c = 0; c < blockWeeks; c++) {
            var w = block * blockWeeks + c
            var monday = new Date(firstMonday + w * 7 * Hub.dayMs)
            monday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate(), 12)
            var m = monday.getMonth()
            if (monday.getDate() <= 7 && m !== last && c > 0) {
                last = m
                if (blockWeeks === weekCount && m % 2 === 1)
                    continue
                out.push({ column: c, text: Format.monthShort[m] })
            }
        }
        return out
    }

    spacing: 14

    SectionHead {
        width: parent.width
        title: qsTr("Consistency")
        note: qsTr("52 weeks")
    }

    Flow {
        width: parent.width
        spacing: 22
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("%1 goal weeks in a row, %2 active weeks of the last 52").arg(consistency.streak).arg(consistency.activeWeeks)
        Row {
            spacing: 6
            RollingNumber {
                id: streakNumber
                value: String(consistency.streak)
                font.family: Theme.display
                font.pixelSize: 30
            }
            Text {
                anchors.bottom: streakNumber.bottom
                anchors.bottomMargin: 6
                text: consistency.streak === 1 ? qsTr("week in a row") : qsTr("weeks in a row")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
            }
        }
        Row {
            spacing: 6
            RollingNumber {
                id: activeNumber
                value: String(consistency.activeWeeks)
                font.family: Theme.display
                font.pixelSize: 30
            }
            Text {
                anchors.bottom: activeNumber.bottom
                anchors.bottomMargin: 6
                text: qsTr("active weeks of 52")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
            }
        }
    }

    DrawIn {
        id: drawIn
        width: parent.width
        height: grid.height

        Column {
            id: grid
            width: drawIn.width
            spacing: 10
            Accessible.role: Accessible.Graphic
            Accessible.name: qsTr("Riding days over the past 52 weeks, %1 weeks with a ride").arg(consistency.activeWeeks)

            Repeater {
                model: consistency.blocks
                Item {
                    id: block
                    readonly property int blockIndex: index
                    width: grid.width
                    height: 7 * consistency.pitch - consistency.gapSize + 20

                    Repeater {
                        model: consistency.blockWeeks * 7
                        Rectangle {
                            id: dayCell
                            readonly property int day: block.blockIndex * consistency.blockWeeks * 7 + index
                            readonly property bool future: day > consistency.todayIndex
                            x: Math.floor(index / 7) * consistency.pitch
                            y: (index % 7) * consistency.pitch
                            width: consistency.cellSize
                            height: consistency.cellSize
                            radius: Math.max(1.5, width * 0.3)
                            visible: !future
                            color: consistency.shades[consistency.levels[day] || 0]
                        }
                    }
                    // today
                    Rectangle {
                        readonly property int local: consistency.todayIndex - block.blockIndex * consistency.blockWeeks * 7
                        visible: local >= 0 && local < consistency.blockWeeks * 7
                        x: Math.floor(local / 7) * consistency.pitch - 1.5
                        y: (local % 7) * consistency.pitch - 1.5
                        width: consistency.cellSize + 3
                        height: width
                        radius: Math.max(2, width * 0.3)
                        color: "transparent"
                        border.width: 1.5
                        border.color: Theme.text
                    }
                    Repeater {
                        model: consistency.months(block.blockIndex)
                        Text {
                            id: monthLabel
                            x: modelData.column * consistency.pitch
                            y: 7 * consistency.pitch - consistency.gapSize + 5
                            text: modelData.text
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(11)
                        }
                    }
                }
            }
        }
    }

    Flow {
        width: parent.width
        spacing: 16
        Text {
            height: 16
            verticalAlignment: Text.AlignVCenter
            visible: text !== ""
            text: consistency.freezes === 1 ? qsTr("1 streak freeze saved")
                  : (consistency.freezes > 1 ? qsTr("%1 streak freezes saved").arg(consistency.freezes)
                  : (consistency.toNextFreeze > 0 ? qsTr("A streak freeze in %1 more goal weeks").arg(consistency.toNextFreeze) : ""))
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(13)
        }
        Row {
            height: 16
            spacing: 4
            Accessible.ignored: true
            Text {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 4
                text: qsTr("Easy")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(12)
            }
            Repeater {
                model: consistency.shades
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
                leftPadding: 4
                text: qsTr("Hard")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(12)
            }
        }
    }
}
