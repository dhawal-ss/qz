import QtQuick 2.15
import ".."
import "../sig"
import "Analytics.js" as Pro

// Physiology, on Progress: critical power and W′ fitted to the best 3 to 20 minutes of the last 90
// days, VO2 max from the best 5 minutes and the rider's weight (with how far off it can be), and
// how fast fitness rises (a warning above 8 a week). Each one says what it rests on, or what is
// missing for it.
Column {
    id: physio

    property var library: null
    property real weight: 0          // kg, 0 when not set
    property var series: []          // Fitness.series
    property bool pro: false

    property var model: null
    property var vo2: null
    readonly property var ramp: Pro.rampRate(series)
    readonly property bool estimated: library !== null && library.powerGroup === 1

    spacing: 14

    function refresh() {
        if (!library) {
            model = null
            vo2 = null
            return
        }
        var curve = library.powerCurve(Date.now() - 90 * 86400000, 0)
        model = Pro.criticalPower(curve)
        var best5 = 0
        for (var i = 0; i < curve.length; i++)
            if (curve[i].seconds === 300)
                best5 = curve[i].watts
        vo2 = Pro.vo2max(best5, weight, estimated)
    }
    onWeightChanged: refresh()

    SectionHead {
        width: parent.width
        title: qsTr("Physiology")
        note: physio.estimated ? qsTr("Est., from the watts of this bike") : qsTr("From your best efforts, 90 days")
    }

    // critical power and W′
    Row {
        width: parent.width
        spacing: 24
        Repeater {
            model: physio.model ? [[qsTr("Critical power"), String(physio.model.cp), "W"],
                                   [qsTr("W′"), (physio.model.wprime / 1000).toFixed(1), "kJ"]] : []
            Column {
                width: (physio.width - 24) / 2
                spacing: 6
                Accessible.role: Accessible.StaticText
                Accessible.name: modelData[0] + ", " + modelData[1] + " " + modelData[2]
                Text {
                    text: modelData[0]
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                }
                Row {
                    spacing: 3
                    Numeral {
                        id: modelValue
                        text: modelData[1]
                        color: Theme.text
                        font.pixelSize: 34
                        font.letterSpacing: -0.9
                    }
                    Text {
                        anchors.baseline: modelValue.baseline
                        text: modelData[2]
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 18
                    }
                }
            }
        }
    }
    Text {
        width: parent.width
        text: physio.model ? qsTr("Critical power is about what you can hold for 30 to 60 minutes; W′ is the reserve above it, for efforts and sprints.")
                           : qsTr("Critical power needs hard efforts of 3 to 20 minutes in the last 90 days. A ramp test or a few hard blocks bring it.")
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }

    Hairline { width: parent.width }

    // VO2 max
    Column {
        width: parent.width
        spacing: 6
        Text {
            text: qsTr("VO2 max")
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 13
        }
        Row {
            visible: physio.vo2 !== null
            spacing: 6
            Numeral {
                id: vo2Value
                text: physio.vo2 ? String(physio.vo2.value) : ""
                color: Theme.text
                font.pixelSize: 34
                font.letterSpacing: -0.9
            }
            Text {
                anchors.baseline: vo2Value.baseline
                text: physio.vo2 ? qsTr("ml/kg/min, likely %1 to %2").arg(physio.vo2.low).arg(physio.vo2.high) : ""
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 14
            }
        }
        Text {
            width: parent.width
            text: physio.vo2 ? qsTr("From your best 5 minutes and your weight. A lab test is the only exact one.")
                  : (physio.weight > 0 ? qsTr("Needs a hard 5 minutes in the last 90 days: an all-out effort, not an easy ride.") : qsTr("Needs your weight, set in You."))
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    Hairline { width: parent.width; visible: physio.ramp !== null && Theme.ftpSet }

    // how fast fitness rises
    Column {
        visible: physio.ramp !== null && Theme.ftpSet
        width: parent.width
        spacing: 6
        Text {
            text: qsTr("Fitness ramp")
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 13
        }
        Text {
            width: parent.width
            text: !physio.ramp ? ""
                  : physio.ramp.steep ? qsTr("Up %1 this week. More than 8 a week is hard to keep up: an easier week soon keeps it going.").arg(physio.ramp.perWeek)
                  : physio.ramp.perWeek > 0 ? qsTr("Up %1 this week, a pace you can keep.").arg(physio.ramp.perWeek)
                  : qsTr("Down %1 this week.").arg(Math.abs(physio.ramp.perWeek))
            color: physio.ramp && physio.ramp.steep ? Theme.zoneColors[5] : Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: 15
            wrapMode: Text.WordWrap
        }
    }
}
