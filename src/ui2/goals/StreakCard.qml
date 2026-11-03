import QtQuick 2.15
import ".."
import "../progress"
import "../Format.js" as Format
import "Streak.js" as Streak

// The weekly goal and the streak of weeks that met it (rules in Streak.js): this week against
// the goal, the streak with its freezes, the last 12 weeks as dots, and behind two buttons the
// goal itself and the weeks marked rest, sick or injured.
Card {
    id: streakCard

    property string kind: "minutes"
    property real goal: 120
    property bool miles: false
    property var result: null        // Streak.run()
    property var reasonsMap: ({})    // week key -> rest, sick or injured
    property real nowMs: Date.now()

    signal setKind(string kind)
    signal setGoal(real value)
    signal markWeek(int key, string reason)

    property bool editing: false
    property bool resting: false

    readonly property var current: result && result.current ? result.current : { key: 0, value: 0, status: "current" }
    readonly property real value: current.value
    readonly property bool weekMet: current.status === "met"
    readonly property int streak: result ? result.streak : 0
    readonly property int freezes: result ? result.freezes : 0
    readonly property var dots: result ? Streak.lastWeeks(result.timeline, 12, nowMs) : []
    readonly property int lastWeekKey: Streak.dayKey(Streak.addWeeks(nowMs, -1))

    // a value in the unit of the goal, as words
    function amount(v) {
        if (kind === "kj")
            return Format.big(v) + " kJ"
        if (kind === "km")
            return Format.distance(v, miles)
        if (kind === "rides")
            return Math.round(v) === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(Math.round(v))
        return Math.round(v) + " min"
    }

    function bigValue() {
        if (kind === "kj")
            return Format.big(value)
        if (kind === "km") {
            var v = value * (miles ? 0.621371 : 1)
            return v >= 100 ? String(Math.round(v)) : v.toFixed(1)
        }
        return String(Math.round(value))
    }

    // 2 Nov
    function shortDate(ms) {
        var d = new Date(ms)
        return d.getDate() + " " + Format.monthShort[d.getMonth()]
    }

    function choiceLabel(v) {
        if (kind === "minutes")
            return v < 60 ? v + " min" : (v / 60) + " h"
        return String(v)
    }

    readonly property var kindOptions: [["minutes", qsTr("Time")], ["kj", qsTr("Work")], ["km", qsTr("Distance")], ["rides", qsTr("Rides")]]
    readonly property var valueOptions: {
        var list = kind === "km" && miles ? Streak.mileChoices : Streak.choices[kind]
        return list.map(function (v) { return [String(v), choiceLabel(v)] })
    }
    readonly property string currentChoice: {
        if (kind === "km" && miles)
            return String(Math.round(goal / 1.609344))
        return String(Math.round(goal))
    }
    readonly property string unitWords: kind === "kj" ? qsTr("kJ a week") : (kind === "km" ? (miles ? qsTr("miles a week") : qsTr("km a week"))
                                       : (kind === "rides" ? qsTr("rides a week") : qsTr("hours a week")))

    function weekWords(status) {
        if (status === "met")
            return qsTr("met")
        if (status === "frozen")
            return qsTr("saved by a freeze")
        if (status === "rest")
            return qsTr("rest")
        if (status === "missed")
            return qsTr("missed")
        if (status === "current")
            return qsTr("in progress")
        return ""
    }

    // the dots for the screen reader, as counts
    readonly property string dotsSummary: {
        var counts = { met: 0, frozen: 0, rest: 0, missed: 0 }
        for (var i = 0; i < dots.length; i++)
            if (counts[dots[i].status] !== undefined)
                counts[dots[i].status]++
        return qsTr("Last 12 weeks: %1 met, %2 saved by a freeze, %3 rest, %4 missed. This week %5.")
            .arg(counts.met).arg(counts.frozen).arg(counts.rest).arg(counts.missed).arg(weekWords(current.status))
    }

    Item {
        width: parent.width
        height: 24
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Weekly goal")
            color: Theme.text2
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.labelSize
        }
        // the banked freezes
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: streakCard.freezes > 0
            Accessible.role: Accessible.StaticText
            Accessible.name: streakCard.freezes === 1 ? qsTr("1 freeze banked") : qsTr("%1 freezes banked").arg(streakCard.freezes)
            Repeater {
                model: streakCard.freezes
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Qt.rgba(138 / 255, 180 / 255, 1, 0.18)
                    GoalGlyph { anchors.centerIn: parent; name: "freeze"; size: 16; weight: 2; color: Theme.zoneColors[0] }
                }
            }
        }
    }

    Row {
        spacing: 12
        Numeral {
            text: streakCard.bigValue()
            color: Theme.text
            font.pixelSize: 48
        }
        Text {
            anchors.bottom: parent.bottom
            text: qsTr("of %1 this week").arg(streakCard.amount(streakCard.goal))
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
        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("This week, %1 of %2").arg(streakCard.amount(streakCard.value)).arg(streakCard.amount(streakCard.goal))
        Rectangle {
            width: Math.max(12, parent.width * Math.min(1, streakCard.goal > 0 ? streakCard.value / streakCard.goal : 0))
            height: parent.height
            radius: 6
            color: streakCard.weekMet ? Theme.zoneColors[2] : Theme.accent
            Behavior on width {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
            }
        }
    }

    Row {
        width: parent.width
        spacing: 8
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "flame"
            size: 20
            color: streakCard.streak > 0 ? Theme.zoneColors[4] : Theme.text3
        }
        Text {
            width: parent.width - 28
            anchors.verticalCenter: parent.verticalCenter
            text: streakCard.streak === 0 ? qsTr("Meet the goal this week to start a streak")
                  : (streakCard.streak === 1 ? qsTr("1 week streak") : qsTr("%1 week streak").arg(streakCard.streak))
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.bodySize
            wrapMode: Text.WordWrap
        }
    }

    Text {
        width: parent.width
        visible: text !== ""
        text: {
            if (!streakCard.result)
                return ""
            if (streakCard.result.welcomeBack)
                return qsTr("Welcome back. One goal week starts a new streak, and this week is open.")
            var best = streakCard.result.best > streakCard.streak ? qsTr("Best %1 weeks. ").arg(streakCard.result.best) : ""
            if (streakCard.freezes >= Streak.freezeMax)
                return best + qsTr("2 freezes banked: a missed week uses one, so the streak lives on.")
            if (streakCard.streak === 0 && streakCard.freezes === 0)
                return best + qsTr("Every 4 goal weeks earn a freeze that saves a missed week.")
            var next = streakCard.result.toNextFreeze
            return best + (next === 1 ? qsTr("Next freeze after 1 more goal week.") : qsTr("Next freeze after %1 more goal weeks.").arg(next))
        }
        color: streakCard.result && streakCard.result.welcomeBack ? Theme.accent : Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.labelSize
        wrapMode: Text.WordWrap
    }

    // the last 12 weeks
    Item {
        id: dotRow
        width: parent.width
        height: dotSize + 22
        readonly property real dotSize: Math.min(22, Math.floor((width - 11 * 6) / 12))
        readonly property real gap: (width - 12 * dotSize) / 11
        Accessible.role: Accessible.Graphic
        Accessible.name: streakCard.dotsSummary

        Repeater {
            model: streakCard.dots
            Item {
                id: dotCell
                readonly property string status: modelData.status
                x: index * (dotRow.dotSize + dotRow.gap)
                width: dotRow.dotSize
                height: dotRow.dotSize
                Rectangle {
                    anchors.centerIn: parent
                    width: dotCell.status === "none" ? 6 : parent.width
                    height: width
                    radius: width / 2
                    color: dotCell.status === "met" ? Theme.zoneColors[2]
                           : (dotCell.status === "frozen" ? Theme.zoneColors[0]
                              : (dotCell.status === "rest" || dotCell.status === "none" ? Theme.chip : "transparent"))
                    border.width: dotCell.status === "missed" || dotCell.status === "current" ? 2 : 0
                    border.color: dotCell.status === "current" ? Theme.accent : Theme.dashed
                }
                // the week in progress fills from the middle
                Rectangle {
                    visible: dotCell.status === "current"
                    anchors.centerIn: parent
                    width: Math.max(0, (parent.width - 8) * Math.min(1, streakCard.goal > 0 ? streakCard.value / streakCard.goal : 0))
                    height: width
                    radius: width / 2
                    color: Theme.accent
                }
                GoalGlyph {
                    visible: dotCell.status === "frozen" || dotCell.status === "rest"
                    anchors.centerIn: parent
                    size: Math.round(parent.width * 0.62)
                    weight: 2.4
                    name: dotCell.status === "frozen" ? "freeze" : "moon"
                    color: dotCell.status === "frozen" ? Theme.bg : Theme.text2
                }
            }
        }
        Text {
            y: dotRow.dotSize + 6
            text: qsTr("12 weeks ago")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 11
        }
        Text {
            anchors.right: parent.right
            y: dotRow.dotSize + 6
            text: qsTr("This week")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 11
        }
    }

    Row {
        spacing: 8
        Repeater {
            model: [[qsTr("Change goal"), "edit"], [qsTr("Rest week"), "rest"]]
            PulseButton {
                id: toggleButton
                readonly property bool lit: modelData[1] === "edit" ? streakCard.editing : streakCard.resting
                width: toggleLabel.implicitWidth + 32
                height: 48
                topInset: 4
                bottomInset: 4
                radius: 20
                fill: lit ? Theme.accent : (pressed ? Theme.pressed : Theme.chip)
                Accessible.name: modelData[0]
                Accessible.checkable: true
                Accessible.checked: lit
                onClicked: {
                    if (modelData[1] === "edit")
                        streakCard.editing = !streakCard.editing
                    else
                        streakCard.resting = !streakCard.resting
                }
                contentItem: Text {
                    id: toggleLabel
                    text: modelData[0]
                    color: toggleButton.lit ? Theme.accentInk : Theme.accent
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.labelSize
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // the goal: what it counts and how much
    Column {
        visible: streakCard.editing
        width: parent.width
        spacing: 4
        Text {
            text: qsTr("Count")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
        }
        Chips {
            width: parent.width
            options: streakCard.kindOptions
            current: streakCard.kind
            what: qsTr("Goal counts")
            onPicked: streakCard.setKind(key)
        }
        Text {
            text: qsTr("Goal, %1").arg(streakCard.unitWords)
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
        }
        Chips {
            width: parent.width
            options: streakCard.valueOptions
            current: streakCard.currentChoice
            what: qsTr("Goal, %1").arg(streakCard.unitWords)
            onPicked: {
                var v = Number(key)
                streakCard.setGoal(streakCard.kind === "km" && streakCard.miles ? v * 1.609344 : v)
            }
        }
    }

    // rest, sick or injured: this week and the one before
    Column {
        visible: streakCard.resting
        width: parent.width
        spacing: 4
        Text {
            width: parent.width
            text: qsTr("A rest, sick or injured week pauses the streak. It does not end it and uses no freeze.")
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
            wrapMode: Text.WordWrap
        }
        Repeater {
            model: [[streakCard.current.key, qsTr("This week")], [streakCard.lastWeekKey, qsTr("Last week")]]
            Column {
                id: restRow
                readonly property int weekKey: modelData[0]
                width: parent.width
                spacing: 0
                Text {
                    topPadding: 8
                    text: qsTr("%1, from Monday %2").arg(modelData[1]).arg(streakCard.shortDate(Streak.keyDay(restRow.weekKey)))
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.tertiarySize
                }
                Chips {
                    width: parent.width
                    options: [["", qsTr("Counts")], ["rest", qsTr("Rest")], ["sick", qsTr("Sick")], ["injured", qsTr("Injured")]]
                    current: streakCard.reasonsMap[String(restRow.weekKey)] || ""
                    what: modelData[1]
                    onPicked: streakCard.markWeek(restRow.weekKey, key)
                }
            }
        }
    }
}
