import QtQuick 2.15
import ".."
import "../sig"
import "../learn"
import "../Format.js" as Format
import "Streak.js" as Streak

// This week, on Today: the one home of the week against the weekly goal. The ring of the week,
// what is left to close it, the streak as one plain sentence, the freezes, each day of the week,
// and one way to change it all: Edit goal (the goal setup, which also has Take a break). While
// the goals are paused, I'm back comes first. The rules are in Streak.js; goals is the shared
// GoalsModel. A tap on the ring or the streak opens its Learn sheet (learn("streak")).
Rectangle {
    id: home

    property var goals: null         // goals/GoalsModel.qml
    property var days: []            // Coach.weekDays()
    property bool miles: false

    signal learn(string id)
    signal editGoal()
    signal resume()

    readonly property string kind: goals ? goals.goalKind : "minutes"
    readonly property real goal: goals ? goals.goalValue : 120
    readonly property var result: goals ? goals.streakResult : null
    readonly property var current: result && result.current ? result.current : { key: 0, value: 0, status: "current" }
    readonly property real value: current.value
    readonly property bool weekMet: current.status === "met"
    readonly property bool paused: goals ? goals.paused : false
    readonly property int pauseUntil: goals && goals.pause ? (Number(goals.pause.until) || 0) : 0
    readonly property int streak: result ? result.streak : 0
    readonly property int freezes: result ? result.freezes : 0
    readonly property real share: goal > 0 ? Math.min(1, value / goal) : 0

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

    // the week, as the first line
    readonly property string weekLine: {
        if (paused)
            return qsTr("Paused. This week can't be missed.")
        if (weekMet)
            return qsTr("Week closed. Everything from here is extra.")
        var left = Math.max(0, goal - value)
        if (kind === "rides") {
            var n = Math.max(1, Math.ceil(left - 1e-9))
            return n === 1 ? qsTr("1 more ride closes the week.") : qsTr("%1 more rides close the week.").arg(n)
        }
        return qsTr("%1 more closes the week.").arg(amount(kind === "minutes" ? Math.ceil(left) : left))
    }
    // the streak, as one sentence
    readonly property string streakLine: {
        if (paused)
            return pauseUntil > 0 ? qsTr("Your streak waits until around %1.").arg(Streak.weekWords(pauseUntil))
                                  : qsTr("Your streak waits while you're away.")
        if (weekMet)
            return streak > 1 ? qsTr("%1 weeks in a row.").arg(streak) : qsTr("Your streak starts with this week.")
        if (streak > 0)
            return streak === 1 ? qsTr("1 week in a row. Close this one for 2.")
                                : qsTr("%1 weeks in a row. Close this one for %2.").arg(streak).arg(streak + 1)
        if (result && result.welcomeBack)
            return qsTr("Welcome back. One goal week starts a streak.")
        return qsTr("Close it to start a streak.")
    }
    readonly property string freezesLine: {
        if (!result)
            return ""
        if (freezes > 0)
            return freezes === 1 ? qsTr("1 freeze saved for a missed week") : qsTr("%1 freezes saved for missed weeks").arg(freezes)
        var next = result.toNextFreeze
        return next === 1 ? qsTr("A freeze after 1 more goal week") : qsTr("A freeze after %1 more goal weeks").arg(next)
    }

    implicitHeight: body.height + 40
    radius: Theme.heroRadius
    color: Theme.card
    border.width: 1
    border.color: Theme.raisedBorder

    Column {
        id: body
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        Item {
            width: parent.width
            height: weekCap.height
            CapLabel {
                id: weekCap
                text: qsTr("This week")
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: weekCap.verticalCenter
                width: Math.min(implicitWidth, parent.width - weekCap.width - 12)
                text: qsTr("Goal %1").arg(home.amount(home.goal))
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                elide: Text.ElideRight
            }
        }

        // the ring and the streak are the button to the streak's Learn sheet
        LearnTap {
            width: parent.width
            name: home.weekLine + " " + home.streakLine
            onClicked: home.learn("streak")
            Item {
                width: parent.width
                height: Math.max(ring.height, side.height)
                GoalRing {
                    id: ring
                    width: 96
                    height: 96
                    segments: home.kind === "rides" ? Math.max(1, Math.round(home.goal)) : 0
                    done: home.kind === "rides" ? home.value : home.share
                    value: home.bigValue(home.value)
                    word: home.unitWord
                    numberSize: 28
                    thickness: 9
                }
                Column {
                    id: side
                    x: ring.width + 18
                    width: parent.width - x
                    anchors.verticalCenter: ring.verticalCenter
                    spacing: 6
                    Text {
                        width: parent.width
                        text: home.weekLine
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(16)
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 21
                        wrapMode: Text.WordWrap
                        Accessible.ignored: true
                    }
                    Text {
                        width: parent.width
                        text: home.streakLine
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.fs(14)
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 19
                        wrapMode: Text.WordWrap
                        Accessible.ignored: true
                    }
                }
            }
        }

        WeekPulses {
            width: parent.width
            days: home.days
            Accessible.ignored: true
        }

        // the freezes are the button to their Learn sheet
        LearnTap {
            objectName: "freezesTap"
            width: parent.width
            name: freezesText.text
            onClicked: home.learn("freezes")
            Row {
                width: parent.width
                spacing: 8
                GoalGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    weight: 1.8
                    name: "freeze"
                    color: home.freezes > 0 ? Theme.accent : Theme.text3
                }
                Text {
                    id: freezesText
                    width: parent.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: home.freezesLine
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(13)
                    wrapMode: Text.WordWrap
                    Accessible.ignored: true
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: home.paused ? [[qsTr("I'm back"), "resume"], [qsTr("Edit goal"), "goal"]] : [[qsTr("Edit goal"), "goal"]]
                PulseButton {
                    id: actionButton
                    width: actionText.implicitWidth + 40
                    height: 48
                    pressedRadius: 16
                    fill: pressed ? Theme.chip : Theme.pressed
                    Accessible.name: modelData[1] === "resume" ? qsTr("I'm back, resume goals") : qsTr("Edit your weekly goal")
                    onClicked: {
                        if (modelData[1] === "goal")
                            home.editGoal()
                        else
                            home.resume()
                    }
                    contentItem: Text {
                        id: actionText
                        text: modelData[0]
                        color: Theme.text
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
