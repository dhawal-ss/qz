import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "Format.js" as Format

// Goals: a weekly goal with a streak that counts weeks, never days, and lifetime ladders for
// distance and work. Phase 4 adds freezes, journeys, badges and the weekly recap.
Item {
    id: goals

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"

    signal openYou()

    property real weekSeconds: 0
    property int streak: 0
    property var lifetime: ({})

    readonly property var goalChoices: [60, 90, 120, 150, 180, 240, 300]
    readonly property var distanceRungs: [100, 250, 500, 1000, 2500, 5000, 10000, 20000, 40075]
    readonly property var workRungs: [1000, 5000, 10000, 25000, 50000, 100000, 250000]

    Settings {
        id: goalSettings
        category: "ui2"
        property int weeklyGoalMinutes: 120
    }

    function refresh() {
        if (!library) {
            weekSeconds = 0
            streak = 0
            lifetime = {}
            return
        }
        var monday = Format.weekStart(Date.now())
        var from = monday - 52 * 7 * 86400000
        var perWeek = {}
        var days = library.days(from, 0)
        for (var i = 0; i < days.length; i++) {
            var w = Format.weekStart(days[i].day)
            perWeek[w] = (perWeek[w] || 0) + days[i].seconds
        }
        weekSeconds = perWeek[monday] || 0
        var goal = goalSettings.weeklyGoalMinutes * 60
        // this week counts once it is met; before that the streak is the weeks before it
        var count = weekSeconds >= goal ? 1 : 0
        for (var back = 1; back <= 52; back++) {
            var start = Format.weekStart(monday - back * 7 * 86400000 + 3600000)
            if ((perWeek[start] || 0) >= goal)
                count++
            else
                break
        }
        streak = count
        lifetime = library.totals(0, 0)
    }

    function nextRung(rungs, value) {
        for (var i = 0; i < rungs.length; i++)
            if (value < rungs[i])
                return rungs[i]
        return rungs[rungs.length - 1]
    }

    onLibraryChanged: refresh()
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: goals.library
        ignoreUnknownSignals: true
        function onChanged() { goals.refresh() }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.height + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            readonly property real margin: Theme.margin(goals.width)
            readonly property bool twoColumns: goals.width >= 680
            readonly property real columnWidth: twoColumns ? (width - 16) / 2 : width
            x: margin
            width: Math.min(goals.width - margin * 2, 1120)
            spacing: 16

            PageHeader {
                width: parent.width
                title: qsTr("Goals")
                showYou: goals.showYou
                initial: goals.initial
                onOpenYou: goals.openYou()
            }

            Flow {
                width: parent.width
                spacing: 16

                // the weekly goal and the streak of weeks that met it
                Card {
                    width: content.columnWidth
                    Text {
                        text: qsTr("Weekly goal")
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                    }
                    Row {
                        spacing: 16
                        Numeral {
                            text: Math.round(goals.weekSeconds / 60)
                            color: Theme.text
                            font.pixelSize: 48
                        }
                        Text {
                            anchors.bottom: parent.bottom
                            text: qsTr("of %1 min this week").arg(goalSettings.weeklyGoalMinutes)
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.bodySize
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 12
                        radius: 6
                        color: Theme.chip
                        Rectangle {
                            width: Math.max(12, parent.width * Math.min(1, goals.weekSeconds / (goalSettings.weeklyGoalMinutes * 60)))
                            height: parent.height
                            radius: 6
                            color: goals.weekSeconds >= goalSettings.weeklyGoalMinutes * 60 ? Theme.zoneColors[2] : Theme.accent
                        }
                    }
                    Row {
                        spacing: 8
                        Icon { name: "flame"; size: 20; color: goals.streak > 0 ? Theme.zoneColors[4] : Theme.text3; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: goals.streak === 0 ? qsTr("Meet the goal this week to start a streak")
                                  : (goals.streak === 1 ? qsTr("1 week streak") : qsTr("%1 week streak").arg(goals.streak))
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.bodySize
                        }
                    }
                    Text {
                        width: parent.width
                        text: qsTr("Change the goal")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: goals.goalChoices
                            PulseButton {
                                width: 64
                                height: 40
                                fill: goalSettings.weeklyGoalMinutes === modelData ? Theme.accent : Theme.chip
                                Accessible.name: qsTr("%1 minutes a week").arg(modelData)
                                onClicked: {
                                    goalSettings.weeklyGoalMinutes = modelData
                                    goals.refresh()
                                }
                                contentItem: Text {
                                    text: (modelData / 60) + " h"
                                    color: goalSettings.weeklyGoalMinutes === modelData ? Theme.accentInk : Theme.text2
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                // lifetime ladders
                Column {
                    width: content.columnWidth
                    spacing: 16
                    Repeater {
                        model: [
                            { name: qsTr("Distance ladder"), value: (goals.lifetime.distance || 0), rungs: goals.distanceRungs, kind: "km" },
                            { name: qsTr("Work ladder"), value: (goals.lifetime.kj || 0), rungs: goals.workRungs, kind: "kJ" }
                        ]
                        Card {
                            id: ladder
                            width: content.columnWidth
                            readonly property real value: modelData.value
                            readonly property var rungs: modelData.rungs
                            readonly property real next: goals.nextRung(rungs, value)
                            function label(v) {
                                if (modelData.kind === "km")
                                    return v === 40075 ? qsTr("Around the world") : Format.distance(v, goals.miles)
                                return Format.big(v) + " kJ"
                            }
                            Text {
                                text: modelData.name
                                color: Theme.text2
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.labelSize
                            }
                            Text {
                                width: parent.width
                                text: modelData.kind === "km" ? Format.distance(modelData.value, goals.miles) : Format.big(modelData.value) + " kJ"
                                color: Theme.text
                                font.family: Theme.display
                                font.pixelSize: 32
                            }
                            Text {
                                width: parent.width
                                text: modelData.value >= modelData.rungs[modelData.rungs.length - 1] ? qsTr("Every rung done.")
                                      : qsTr("Next: %1, %2 to go").arg(ladder.label(ladder.next))
                                        .arg(modelData.kind === "km" ? Format.distance(ladder.next - ladder.value, goals.miles) : Format.big(ladder.next - ladder.value) + " kJ")
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.labelSize
                                wrapMode: Text.WordWrap
                            }
                            Row {
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: modelData.rungs
                                    Rectangle {
                                        width: (ladder.width - ladder.padding * 2 - 4 * (ladder.rungs.length - 1)) / ladder.rungs.length
                                        height: 10
                                        radius: 5
                                        color: modelData <= ladder.value ? Theme.accent : Theme.chip
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
