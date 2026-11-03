import QtQuick 2.15
import ".."
import "../sig"
import "../learn"
import "../Format.js" as Format
import "../moments/Moments.js" as Moments

// The best power of all time at four lengths, each in the color of its effort and a button to
// the ride that set it. The label opens the Learn sheet of best power (learn()).
Column {
    id: bestsCard

    property var bests: []           // [{seconds, watts, rideId}] from library.powerCurve()

    signal openRide(int id)
    signal learn()

    spacing: 4

    LearnLabel {
        x: -8
        caption: qsTr("Best power")
        onClicked: bestsCard.learn()
    }
    KeyNumbers {
        width: bestsCard.width
        columns: 4
        valueSize: 26
        items: bestsCard.bests.map(function (b) {
            return { value: String(Math.round(b.watts)), unit: "W", label: Format.effort(b.seconds),
                     color: Theme.zoneColors[Moments.recordTone(b.seconds) - 1], action: b.rideId }
        })
        onPicked: bestsCard.openRide(bestsCard.bests[index].rideId)
    }
}
