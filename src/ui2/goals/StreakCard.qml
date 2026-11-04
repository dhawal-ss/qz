import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Streak.js" as Streak
import "../settings"
import "../learn"
import "../settings/GoalLimits.js" as GoalLimits

// The hero of Goals: the streak in the breathing Pulse, what a coach would say about it, the
// last weeks as a row (a goal week is the Pulse, a freeze or a rest week its glyph, this week a
// ring that fills), and the one raised card: this week against the goal, the freezes, the goal
// itself as a number to step or type (goalPicked, a moment after the last change), and the ways
// to change the goal or take a break. The rules are in Streak.js.
// Tap to learn: the streak in the Pulse and the freezes line open their Learn sheets on the page
// (cue.openLearn: GoalsScreen), the goal stepper keeps its own taps.
Column {
    id: streakCard

    property string kind: "minutes"
    property real goal: 120
    property bool miles: false
    property var result: null        // Streak.run()
    property var reasonsMap: ({})    // week key -> reason
    property real nowMs: Date.now()
    property bool paused: false
    property int pauseUntil: 0       // week key of the week of return, 0 when open
    property var cue: null           // the page, for the entrance
    property int weekCount: 12

    signal changeGoal()
    signal takeBreak()
    signal resume()
    // a new goal of the same kind, in the stored unit (km for distance); GoalsScreen stores it
    signal goalPicked(real value)

    // the goal being stepped, shown at once and stored a moment after the last change; -1 when none
    property real draftGoal: -1
    readonly property real liveGoal: draftGoal >= 0 ? draftGoal : goal
    readonly property var limits: GoalLimits.range(kind, miles)
    onGoalChanged: if (!goalCommit.running) draftGoal = -1
    onKindChanged: draftGoal = -1

    Timer {
        id: goalCommit
        interval: 700
        onTriggered: {
            if (streakCard.draftGoal < 0)
                return
            var picked = streakCard.draftGoal
            streakCard.draftGoal = -1
            // GoalsScreen stores it and hands the new goal back at once
            streakCard.goalPicked(picked)
        }
    }

    readonly property var current: result && result.current ? result.current : { key: 0, value: 0, status: "current" }
    readonly property real value: current.value
    readonly property bool weekMet: current.status === "met"
    readonly property int streak: result ? result.streak : 0
    readonly property int freezes: result ? result.freezes : 0
    readonly property var weeks: result ? Streak.lastWeeks(result.timeline, weekCount, nowMs) : []
    readonly property real share: liveGoal > 0 ? Math.min(1, value / liveGoal) : 0
    readonly property var numberWords: [qsTr("No"), qsTr("One"), qsTr("Two"), qsTr("Three"), qsTr("Four"), qsTr("Five"),
                                        qsTr("Six"), qsTr("Seven"), qsTr("Eight"), qsTr("Nine"), qsTr("Ten"),
                                        qsTr("Eleven"), qsTr("Twelve")]

    // a Learn sheet on the page, when it has them
    function learn(id) {
        if (cue && typeof cue.openLearn === "function")
            cue.openLearn(id)
    }

    function countWord(n) {
        return n < numberWords.length ? numberWords[n] : String(n)
    }

    // a value in the unit of the goal, as words
    function amount(v) {
        if (kind === "kj")
            return Format.big(v) + " kJ"
        if (kind === "km")
            return Format.distance(v, miles)
        if (kind === "rides")
            return Math.round(v) === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(Math.round(v))
        return qsTr("%1 min").arg(Math.round(v))
    }

    function bigValue(v) {
        if (kind === "kj")
            return Format.big(v)
        if (kind === "km") {
            var d = v * (miles ? 0.621371 : 1)
            return d >= 100 ? String(Math.round(d)) : d.toFixed(1)
        }
        return String(Math.round(v))
    }

    readonly property string unitWord: kind === "kj" ? "kJ" : (kind === "km" ? (miles ? "mi" : "km")
                                       : (kind === "rides" ? (Math.round(value) === 1 ? qsTr("ride") : qsTr("rides")) : qsTr("min")))

    // the first day of the week of return, as words (weeks start on Monday or Sunday, Streak.js)
    function mondayWords(key) {
        return Streak.weekWords(key)
    }

    // what is left of the week, as words
    readonly property string toGo: {
        var left = Math.max(0, liveGoal - value)
        if (kind === "rides") {
            var n = Math.max(1, Math.ceil(left - 1e-9))
            return n === 1 ? qsTr("One more ride closes the week.") : qsTr("%1 more rides close the week.").arg(countWord(n))
        }
        return qsTr("%1 more closes the week.").arg(amount(kind === "minutes" ? Math.ceil(left) : left))
    }

    readonly property string headline: {
        if (paused)
            return qsTr("Goals paused.\nYour streak waits.")
        if (weekMet)
            return streak > 1 ? qsTr("Week closed.\n%1 in a row.").arg(countWord(streak)) : qsTr("Week closed.\nA streak starts here.")
        if (streak > 0)
            return streak === 1 ? qsTr("One week in a row.\nKeep it going.") : qsTr("%1 weeks in a row.\nKeep it going.").arg(countWord(streak))
        if (result && result.welcomeBack)
            return qsTr("Welcome back.\nOne week starts a streak.")
        return qsTr("Start a streak\nthis week.")
    }
    readonly property string line: {
        if (paused)
            return pauseUntil > 0 ? qsTr("Back around %1. Nothing is missed while you are away.").arg(mondayWords(pauseUntil))
                                  : qsTr("Take the time you need. Nothing is missed while you are away.")
        var best = result ? result.best : 0
        if (streak > 0 && streak >= best)
            return qsTr("Your longest run yet. Every goal week adds one.")
        if (streak > 0)
            return qsTr("Your best run is %1 weeks. Every goal week adds one.").arg(best)
        if (result && result.welcomeBack)
            return qsTr("Every goal week from here adds one.")
        return qsTr("Meet the weekly goal once and a streak begins.")
    }

    spacing: 0

    Rise {
        cue: streakCard.cue
        order: 0
        width: parent.width
        Item {
            width: parent.width
            height: 136
            // the streak is the button to its Learn sheet
            LearnTap {
                objectName: "streakHeroTap"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 136
                height: 136
                fill: "transparent"
                pressedScale: 0.96
                name: streakHero.summary
                onClicked: streakCard.learn("streak")
                PulseHero {
                    id: streakHero
                    width: 136
                    height: 136
                    glow: false
                    zone: streakCard.weekMet ? 3 : 2
                    value: String(streakCard.streak)
                    word: streakCard.streak === 1 ? qsTr("week") : qsTr("weeks")
                    summary: qsTr("Streak, %1 weeks").arg(streakCard.streak)
                    Accessible.ignored: true
                }
            }
        }
    }
    Item { width: 1; height: 14 }
    Rise {
        cue: streakCard.cue
        order: 1
        width: parent.width
        Column {
            width: parent.width
            spacing: 10
            Text {
                width: parent.width
                text: streakCard.headline
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: streakCard.width >= 400 ? 30 : 28
                font.letterSpacing: -0.6
                lineHeightMode: Text.FixedHeight
                lineHeight: Math.round(font.pixelSize * 1.08)
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.Heading
                Accessible.name: text.split("\n").join(" ")
            }
            Text {
                width: parent.width
                text: streakCard.line
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(14)
                lineHeightMode: Text.FixedHeight
                lineHeight: 20
                wrapMode: Text.WordWrap
            }
        }
    }
    Item { width: 1; height: 22 }
    Rise {
        cue: streakCard.cue
        order: 2
        width: parent.width
        WeekRow {
            width: parent.width
            weeks: streakCard.weeks
            progress: streakCard.share
            Accessible.role: Accessible.Graphic
            Accessible.name: {
                var counts = { met: 0, frozen: 0, rest: 0, missed: 0 }
                for (var i = 0; i < streakCard.weeks.length; i++)
                    if (counts[streakCard.weeks[i].status] !== undefined)
                        counts[streakCard.weeks[i].status]++
                return qsTr("Last %1 weeks: %2 met, %3 saved by a freeze, %4 rest, %5 missed.")
                    .arg(streakCard.weeks.length).arg(counts.met).arg(counts.frozen).arg(counts.rest).arg(counts.missed)
            }
        }
    }
    Item { width: 1; height: 20 }
    Rise {
        cue: streakCard.cue
        order: 3
        width: parent.width
        // the one raised surface of Goals: this week, the freezes and the ways to change them
        Rectangle {
            width: parent.width
            height: weekBody.height + 40
            radius: Theme.heroRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.raisedBorder

            Column {
                id: weekBody
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 16

                CapLabel {
                    id: weekCap
                    text: qsTr("This week")
                }

                Item {
                    width: parent.width
                    height: Math.max(ring.height, side.height)
                    GoalRing {
                        id: ring
                        width: 104
                        height: 104
                        segments: streakCard.kind === "rides" ? Math.max(1, Math.round(streakCard.liveGoal)) : 0
                        done: streakCard.kind === "rides" ? streakCard.value : streakCard.share
                        value: streakCard.bigValue(streakCard.value)
                        word: streakCard.unitWord
                        numberSize: 30
                        thickness: 10
                    }
                    Column {
                        id: side
                        x: ring.width + 20
                        width: parent.width - x
                        anchors.verticalCenter: ring.verticalCenter
                        spacing: 12
                        Text {
                            width: parent.width
                            text: streakCard.paused ? qsTr("Paused. This week cannot be missed.")
                                  : (streakCard.weekMet ? qsTr("Closed. Everything from here is extra.") : streakCard.toGo)
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(16)
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 21
                            wrapMode: Text.WordWrap
                        }
                        // the freezes are the button to their Learn sheet
                        LearnTap {
                          objectName: "freezesTap"
                          width: parent.width
                          name: freezesText.text
                          onClicked: streakCard.learn("freezes")
                          Row {
                            width: parent.width
                            spacing: 8
                            GoalGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 16
                                weight: 1.8
                                name: "freeze"
                                color: streakCard.freezes > 0 ? Theme.accent : Theme.text3
                            }
                            Text {
                                id: freezesText
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!streakCard.result)
                                        return ""
                                    if (streakCard.freezes > 0)
                                        return streakCard.freezes === 1 ? qsTr("1 streak freeze saved") : qsTr("%1 streak freezes saved").arg(streakCard.freezes)
                                    var next = streakCard.result.toNextFreeze
                                    return next === 1 ? qsTr("A freeze after 1 more goal week") : qsTr("A freeze after %1 more goal weeks").arg(next)
                                }
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.fs(13)
                                wrapMode: Text.WordWrap
                                Accessible.ignored: true
                            }
                          }
                        }
                    }
                }

                // the goal itself on a hairline: step it or type it
                Item {
                    width: parent.width
                    height: goalRow.height + 1
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.hairline
                    }
                    Item {
                        id: goalRow
                        y: 1
                        width: parent.width
                        height: Math.max(64, goalStepper.height + 16)
                        Column {
                            width: Math.max(0, goalStepper.x - 12)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text {
                                width: parent.width
                                text: qsTr("Weekly goal")
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(15)
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: streakCard.kind === "rides" ? (Math.round(streakCard.liveGoal) === 1 ? qsTr("ride a week") : qsTr("rides a week"))
                                      : streakCard.kind === "kj" ? qsTr("kJ a week")
                                      : streakCard.kind === "km" ? (streakCard.miles ? qsTr("miles a week") : qsTr("km a week"))
                                      : qsTr("minutes a week")
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.fs(13)
                                elide: Text.ElideRight
                            }
                        }
                        NumberStepper {
                            id: goalStepper
                            x: parent.width - width
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(196, parent.width * 0.58)
                            height: 48
                            buttonSize: 44
                            numberSize: 24
                            value: GoalLimits.toShown(streakCard.kind, streakCard.liveGoal, streakCard.miles)
                            from: streakCard.limits.from
                            to: streakCard.limits.to
                            step: streakCard.limits.step
                            name: qsTr("Weekly goal")
                            onEdited: {
                                streakCard.draftGoal = GoalLimits.toStored(streakCard.kind, value, streakCard.miles)
                                goalCommit.restart()
                            }
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: streakCard.paused ? [[qsTr("I'm back"), "resume"], [qsTr("Change goal"), "goal"]]
                                                 : [[qsTr("Change goal"), "goal"], [qsTr("Take a break"), "break"]]
                        PulseButton {
                            id: actionButton
                            readonly property bool lead: modelData[1] === "resume"
                            width: actionText.implicitWidth + 40
                            height: 48
                            pressedRadius: 16
                            fill: lead ? (pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent) : (pressed ? Theme.chip : Theme.pressed)
                            Accessible.name: modelData[1] === "resume" ? qsTr("I'm back, resume goals") : modelData[0]
                            onClicked: {
                                if (modelData[1] === "goal")
                                    streakCard.changeGoal()
                                else if (modelData[1] === "break")
                                    streakCard.takeBreak()
                                else
                                    streakCard.resume()
                            }
                            contentItem: Text {
                                id: actionText
                                text: modelData[0]
                                color: actionButton.lead ? Theme.accentInk : Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(14)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
