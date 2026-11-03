import QtQuick 2.15
import ".."
import "../sig"
import "../learn"
import "../Format.js" as Format
import "Analysis.js" as Analysis

// This ride against your usual: its time, average power and heart rate as bars, each with a line
// at the average of the rides of the 30 days before it. The whole section is the button to its
// Learn sheet. It hides when there is no ride before it to compare with.
LearnTap {
    id: usualRide
    objectName: "rideUsual"

    property var ride: ({})
    property var rides: []           // every ride, newest first
    property color tint: Theme.accent
    property bool estimated: false

    // the average of the rides of the 30 days before this one
    readonly property var usual: {
        var out = { count: 0, seconds: 0, power: 0, heart: 0 }
        if (!ride.start)
            return out
        var from = ride.start - 30 * 86400000
        var powerCount = 0
        var heartCount = 0
        for (var i = 0; i < rides.length; i++) {
            var r = rides[i]
            if (r.id === ride.id || r.start >= ride.start || r.start < from)
                continue
            out.count++
            out.seconds += r.duration || 0
            if (r.avgPower > 0) {
                out.power += r.avgPower
                powerCount++
            }
            if (r.avgHr > 0) {
                out.heart += r.avgHr
                heartCount++
            }
        }
        out.seconds = out.count > 0 ? out.seconds / out.count : 0
        out.power = powerCount > 0 ? out.power / powerCount : 0
        out.heart = heartCount > 0 ? out.heart / heartCount : 0
        return out
    }
    readonly property var rows: {
        var out = []
        if (usual.count === 0)
            return out
        out.push({ label: qsTr("Time"), value: ride.duration || 0, usual: usual.seconds,
                   valueText: Analysis.shortDuration(ride.duration || 0), usualText: Analysis.shortDuration(usual.seconds) })
        if (ride.avgPower > 0 && usual.power > 0)
            out.push({ label: estimated ? qsTr("Average power, est.") : qsTr("Average power"), value: ride.avgPower, usual: usual.power,
                       valueText: Math.round(ride.avgPower) + " W", usualText: Math.round(usual.power) + " W" })
        if (ride.avgHr > 0 && usual.heart > 0)
            out.push({ label: qsTr("Heart rate"), value: ride.avgHr, usual: usual.heart,
                       valueText: Math.round(ride.avgHr) + " bpm", usualText: Math.round(usual.heart) + " bpm" })
        return out
    }

    // what the Learn sheet says about this ride
    function learnFacts() {
        return { rides: 1, seconds: ride.duration || 0, usualSeconds: usual.seconds, power: ride.avgPower || 0, usualPower: usual.power,
                 heart: ride.avgHr || 0, usualHeart: usual.heart, usualCount: usual.count }
    }

    function grow() {
        compare.grow()
    }

    visible: rows.length > 0
    name: qsTr("This ride vs your usual. %1").arg(compare.Accessible.name)

    Column {
        width: parent.width
        spacing: 14
        Item {
            width: parent.width
            height: usualTitle.height
            Text {
                id: usualTitle
                text: qsTr("This ride vs your usual")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.titleSize
                Accessible.ignored: true
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: usualTitle.baseline
                width: Math.min(implicitWidth, parent.width - usualTitle.width - 12)
                // short when the title leaves little room
                text: usualRide.width < 380 ? qsTr("30 days")
                      : (usualRide.usual.count === 1 ? qsTr("1 ride in 30 days") : qsTr("%1 rides in 30 days").arg(usualRide.usual.count))
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
        CompareBars {
            id: compare
            width: parent.width
            rows: usualRide.rows
            tint: usualRide.tint
            Accessible.ignored: true
        }
    }
}
