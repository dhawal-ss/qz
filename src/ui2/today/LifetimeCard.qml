import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format
import "../moments/Moments.js" as Moments

// Everything so far, and the next rung of the distance ladder, as a quiet section. A tap opens
// its Learn sheet (learn()), which leads on to Goals.
Column {
    id: lifetimeCard

    property var lifetime: ({})      // library.totals(0, 0)
    property var milestone: null     // Insights.nextRung() of the distance ladder, in km
    property bool miles: false

    signal openGoals()
    signal learn()

    readonly property real share: milestone ? Math.max(0, Math.min(1, ((lifetime.distance || 0) - milestone.from)
                                                                        / Math.max(1, milestone.rung - milestone.from))) : 1
    readonly property real toUnit: miles ? 0.621371 : 1

    // a rung in the rider's unit, a round number (Moments.distanceLadder)
    function rungName(km) {
        return Moments.isWorldRung(km) ? qsTr("around the world") : Format.big(Moments.rungShown(km, miles)) + (miles ? " mi" : " km")
    }

    spacing: 4

    CapLabel {
        text: qsTr("All your rides")
    }
    PulseButton {
        width: lifetimeCard.width
        height: lifeColumn.implicitHeight + 12
        fill: pressed ? Theme.pressed : "transparent"
        radius: 18
        pressedScale: 0.985
        Accessible.name: lifetimeCard.milestone
                         ? qsTr("All your rides, %1. Next milestone %2. Tap to learn more").arg(Format.distance(lifetimeCard.lifetime.distance || 0, lifetimeCard.miles)).arg(lifetimeCard.rungName(lifetimeCard.milestone.rung))
                         : qsTr("All your rides, %1. Tap to learn more").arg(Format.distance(lifetimeCard.lifetime.distance || 0, lifetimeCard.miles))
        onClicked: lifetimeCard.learn()
        contentItem: Column {
            id: lifeColumn
            spacing: 14
            KeyNumbers {
                width: parent.width
                valueSize: 24
                items: [
                    { value: Format.big((lifetimeCard.lifetime.distance || 0) * lifetimeCard.toUnit), unit: lifetimeCard.miles ? "mi" : "km", label: qsTr("Ridden") },
                    { value: Format.big((lifetimeCard.lifetime.seconds || 0) / 3600), unit: "h", label: qsTr("In the saddle") },
                    { value: Format.big(lifetimeCard.lifetime.rides || 0), label: qsTr("Rides") }
                ]
            }
            Rectangle {
                visible: lifetimeCard.milestone !== null
                width: parent.width
                height: 4
                radius: 2
                color: Theme.chip
                Rectangle {
                    width: Math.max(4, parent.width * lifetimeCard.share)
                    height: parent.height
                    radius: 2
                    color: Theme.zoneColors[1]
                }
            }
            Text {
                width: parent.width
                text: lifetimeCard.milestone
                      ? qsTr("Next milestone: %1, %2 to go").arg(lifetimeCard.rungName(lifetimeCard.milestone.rung))
                          .arg(Format.distance(lifetimeCard.milestone.remaining, lifetimeCard.miles))
                      : qsTr("Every rung of the distance ladder done.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                wrapMode: Text.WordWrap
            }
        }
    }
}
