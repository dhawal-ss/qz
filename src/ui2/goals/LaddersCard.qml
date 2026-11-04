import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "../moments/Moments.js" as Moments

// Lifetime ladders for distance and work: the total, the next rung and a bar of every rung.
// The rungs are the ones of Moments.js, so a rung crossed on a ride is a moment there: round
// numbers of the rider's unit (Moments.distanceLadder), compared in km.
// A quiet section: a cap label, then each ladder over a hairline.
Column {
    id: laddersCard

    property var lifetime: ({})      // library.totals(0, 0)
    property bool miles: false

    readonly property var distanceRungs: Moments.distanceLadder(miles)
    readonly property var workRungs: Moments.workRungs

    function nextRung(rungs, value) {
        for (var i = 0; i < rungs.length; i++)
            if (value < rungs[i])
                return rungs[i]
        return rungs[rungs.length - 1]
    }

    spacing: 20

    CapLabel {
        text: qsTr("Ladders")
    }

    Repeater {
        model: [
            { name: qsTr("Distance"), value: (laddersCard.lifetime.distance || 0), rungs: laddersCard.distanceRungs, kind: "km" },
            { name: qsTr("Work"), value: (laddersCard.lifetime.kj || 0), rungs: laddersCard.workRungs, kind: "kJ" }
        ]
        Column {
            id: ladder
            width: parent.width
            spacing: 8
            readonly property real value: modelData.value
            readonly property var rungs: modelData.rungs
            readonly property real next: laddersCard.nextRung(rungs, value)
            function label(v) {
                if (modelData.kind === "km")
                    return Moments.isWorldRung(v) ? qsTr("Around the world")
                                                  : Format.big(Moments.rungShown(v, laddersCard.miles)) + (laddersCard.miles ? " mi" : " km")
                return Format.big(v) + " kJ"
            }
            function amount(v) {
                return modelData.kind === "km" ? Format.distance(v, laddersCard.miles) : Format.big(v) + " kJ"
            }
            Item {
                width: parent.width
                height: ladderAmount.height
                Text {
                    anchors.baseline: ladderAmount.baseline
                    text: modelData.name
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(15)
                }
                Numeral {
                    id: ladderAmount
                    anchors.right: parent.right
                    text: ladder.amount(ladder.value)
                    color: Theme.text
                    font.pixelSize: Theme.fs(26)
                }
            }
            Text {
                width: parent.width
                text: ladder.value >= ladder.rungs[ladder.rungs.length - 1] ? qsTr("Every rung done.")
                      : qsTr("Next: %1, %2 to go").arg(ladder.label(ladder.next)).arg(ladder.amount(ladder.next - ladder.value))
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
            Row {
                width: parent.width
                spacing: 4
                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("%1 ladder, %2 of %3 rungs").arg(modelData.name).arg(ladder.rungs.filter(function (r) { return r <= ladder.value }).length).arg(ladder.rungs.length)
                Repeater {
                    model: ladder.rungs
                    Rectangle {
                        width: (ladder.width - 4 * (ladder.rungs.length - 1)) / ladder.rungs.length
                        height: 6
                        radius: 3
                        color: modelData <= ladder.value ? Theme.accent : Theme.chip
                    }
                }
            }
        }
    }
}
