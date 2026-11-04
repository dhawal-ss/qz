import QtQuick 2.15
import ".."
import "../today"
import "../Metrics.js" as Metrics
import "Workout.js" as Workout

// The workout under way, on the ride screen: which step of how many and its zone, the time left
// in it, what to aim for (a watt band with the rider's own FTP, else how it should feel), what to
// do about it (on an Echelon the level to set, from the bike's own power table; on other bikes push
// or ease off), what comes next, and the shape of the whole workout with now marked on it.
// Bikemodo never sets the resistance: the rider does, from what this says.
Rectangle {
    id: panel

    property var steps: []
    // seconds into the workout
    property int t: 0
    // watts over the last few seconds, and the level now and the one that gives the middle of the band
    property real watts: 0
    property int level: 0
    property int levelTarget: -1
    // the watts are worked out from the level (est.)
    property bool estimated: false
    // said in place of the step once an FTP test is over ("" while it runs)
    property string overText: ""
    readonly property bool finished: pos.done || overText !== ""

    readonly property var pos: Workout.at(steps, t)
    readonly property var step: pos.index >= 0 && pos.index < steps.length ? steps[pos.index] : null
    readonly property var next: pos.index >= 0 && pos.index + 1 < steps.length ? steps[pos.index + 1] : null
    readonly property color tint: step ? Theme.zoneColors[step.zone - 1] : Theme.accent
    readonly property string advice: {
        if (!step)
            return ""
        if (levelTarget > 0 && level > 0 && step.high > 0) {
            var d = levelTarget - level
            if (d >= 1)
                return qsTr("Level %1, turn up %2").arg(levelTarget).arg(d)
            if (d <= -1)
                return qsTr("Level %1, ease off %2").arg(levelTarget).arg(-d)
            return qsTr("Level %1, hold it").arg(levelTarget)
        }
        var s = Workout.side(step, watts)
        if (step.high <= 0)
            return ""
        return s < 0 ? qsTr("Push a bit harder") : (s > 0 ? qsTr("Ease off a little") : qsTr("On target"))
    }

    implicitHeight: content.height + 28
    radius: 22
    color: Theme.control
    Accessible.role: Accessible.StaticText
    Accessible.name: finished ? doneText.text
                              : (stepLine.text + ", " + qsTr("%1 left").arg(clock.text) + ", " + targetText.text
                                 + (advice !== "" ? ", " + advice : ""))

    Column {
        id: content
        x: 16
        y: 14
        width: panel.width - 32
        spacing: 8

        // 2 of 7, Threshold, and the time left in the step
        Item {
            visible: !panel.finished
            width: parent.width
            height: clock.height
            Text {
                id: stepLine
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - clock.width - 12
                text: panel.step ? qsTr("%1 of %2 · %3").arg(panel.pos.index + 1).arg(panel.steps.length)
                                   .arg(Theme.powerZoneNames[panel.step.zone - 1]) : ""
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: 15
                elide: Text.ElideRight
            }
            Text {
                id: clock
                anchors.right: parent.right
                text: Metrics.clock(panel.pos.left)
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: 28
            }
        }

        // what to aim for, and what to do about it
        Item {
            visible: !panel.finished
            width: parent.width
            height: Math.max(targetText.height, adviceText.height)
            Text {
                id: targetText
                width: parent.width * 0.5
                text: Workout.target(panel.step) + (panel.estimated && panel.step && panel.step.high > 0 ? " " + qsTr("est.") : "")
                color: panel.tint
                font.family: Theme.bodySemibold
                font.pixelSize: 17
                wrapMode: Text.WordWrap
            }
            Text {
                id: adviceText
                anchors.right: parent.right
                width: parent.width * 0.5 - 8
                horizontalAlignment: Text.AlignRight
                text: panel.advice
                color: Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: 15
                wrapMode: Text.WordWrap
            }
        }

        Text {
            id: nextText
            visible: !panel.finished
            width: parent.width
            text: panel.next ? qsTr("Next: %1 · %2").arg(Metrics.clock(panel.next.seconds)).arg(Workout.target(panel.next))
                             : qsTr("Last block")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            id: doneText
            visible: panel.finished
            width: parent.width
            text: panel.overText !== "" ? panel.overText : qsTr("Workout done. Keep riding, or hold End to finish.")
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: 15
            wrapMode: Text.WordWrap
        }

        // no FTP of the rider's own: by feel, and where to get watt targets
        Text {
            visible: !panel.finished && panel.steps.length > 0 && panel.steps[0].high <= 0
            width: parent.width
            text: qsTr("Riding by feel. Set your FTP in You for watt targets.")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        WorkoutShape {
            width: parent.width
            height: 22
            blocks: Workout.blocks(panel.steps)
            doneMinutes: panel.t / 60
            Accessible.ignored: true
        }
    }
}
