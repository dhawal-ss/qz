import QtQuick 2.15
import ".."
import "../Format.js" as Format
import "Challenge.js" as Challenge

// The monthly challenge (rules in Challenge.js): a target made from the rider's own months, how
// far this month is, and the pace. Short of the pace it says what a week needs, never "behind".
Card {
    id: challengeCard

    property var history: []         // Challenge.history()
    property real nowMs: Date.now()

    readonly property var month: history.length > 0 ? history[history.length - 1] : { key: Challenge.monthKey(nowMs), target: Challenge.starter, minutes: 0, met: false }
    readonly property var pace: Challenge.pace(month.minutes, month.target, nowMs)
    readonly property int metCount: Challenge.metMonths(history).length
    readonly property color tint: month.met ? Theme.zoneColors[2] : Theme.accent

    // 23 h, 4 h 30 min, 40 min
    function hoursText(minutes) {
        var m = Math.round(minutes)
        if (m >= 60 && m % 60 === 0)
            return (m / 60) + " h"
        return Format.hours(m * 60)
    }

    Item {
        width: parent.width
        height: 24
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Monthly challenge")
            color: Theme.text2
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.labelSize
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: challengeCard.metCount > 0
            text: challengeCard.metCount === 1 ? qsTr("1 met so far") : qsTr("%1 met so far").arg(challengeCard.metCount)
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
        }
    }

    Text {
        width: parent.width
        text: qsTr("Ride %1 in %2").arg(challengeCard.hoursText(challengeCard.month.target)).arg(Format.monthNames[new Date(challengeCard.nowMs).getMonth()])
        color: Theme.text
        font.family: Theme.display
        font.pixelSize: 24
        wrapMode: Text.WordWrap
    }

    Text {
        width: parent.width
        text: challengeCard.history.length <= 1 ? qsTr("A first target to get going. From next month it grows out of your own rides.")
                                                : qsTr("Your recent months plus 10%, made for you.")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.tertiarySize
        wrapMode: Text.WordWrap
    }

    Item {
        width: parent.width
        height: 16
        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("%1 of %2 this month").arg(challengeCard.hoursText(challengeCard.month.minutes)).arg(challengeCard.hoursText(challengeCard.month.target))
        Rectangle {
            y: 2
            width: parent.width
            height: 12
            radius: 6
            color: Theme.chip
            Rectangle {
                width: Math.max(12, parent.width * Math.min(1, challengeCard.month.minutes / Math.max(1, challengeCard.month.target)))
                height: parent.height
                radius: 6
                color: challengeCard.tint
                Behavior on width {
                    enabled: !Theme.reduceMotion
                    NumberAnimation { duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                }
            }
        }
        // where the pace is today
        Rectangle {
            visible: !challengeCard.month.met
            x: Math.min(parent.width - width, parent.width * challengeCard.pace.expected / Math.max(1, challengeCard.month.target))
            width: 3
            height: 16
            radius: 1.5
            color: Theme.text2
        }
    }

    Text {
        width: parent.width
        text: qsTr("%1 of %2").arg(challengeCard.hoursText(challengeCard.month.minutes)).arg(challengeCard.hoursText(challengeCard.month.target))
              + "  ·  " + (challengeCard.pace.daysLeft === 1 ? qsTr("1 day left") : qsTr("%1 days left").arg(challengeCard.pace.daysLeft))
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.labelSize
        wrapMode: Text.WordWrap
    }

    Row {
        width: parent.width
        spacing: 8
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            radius: 5
            color: challengeCard.month.met || challengeCard.pace.onTrack ? Theme.zoneColors[2] : Theme.accent
        }
        Text {
            width: parent.width - 18
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (challengeCard.month.met)
                    return qsTr("Challenge complete. Everything from here is extra.")
                if (challengeCard.pace.onTrack)
                    return qsTr("On track")
                return qsTr("About %1 a week gets you there").arg(challengeCard.hoursText(challengeCard.pace.perWeek))
            }
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.bodySize
            wrapMode: Text.WordWrap
        }
    }
}
