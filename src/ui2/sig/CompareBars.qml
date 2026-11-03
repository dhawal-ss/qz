import QtQuick 2.15
import ".."

// A few numbers against the rider's usual, one row each: the name and the number on a line, a
// bar filled to the number in the tint, and a short upright line where the usual is, named
// under it ("usual 3 h 10 min"). Past the line is more than usual. The bars grow in on the
// default spatial spring each time grow() is called and when the numbers change; instant with
// Theme.reduceMotion. `sample` draws them in graphite, for a picture of what is to come.
//   rows: [{ label, value, usual, valueText, usualText }]
Column {
    id: bars

    property var rows: []
    property color tint: Theme.accent
    property bool sample: false
    // 0 to 1: how far the bars have grown
    property real grown: 1

    function grow() {
        if (Theme.reduceMotion) {
            growth.stop()
            grown = 1
            return
        }
        growth.restart()
    }

    onRowsChanged: grow()
    spacing: 16
    Accessible.role: Accessible.Graphic
    Accessible.name: {
        var parts = []
        for (var i = 0; i < rows.length; i++)
            parts.push(qsTr("%1 %2, usual %3").arg(rows[i].label).arg(rows[i].valueText).arg(rows[i].usualText))
        return parts.join(". ")
    }

    SequentialAnimation {
        id: growth
        PropertyAction { target: bars; property: "grown"; value: 0 }
        PauseAnimation { duration: 120 }
        NumberAnimation {
            target: bars
            property: "grown"
            to: 1
            duration: Theme.defaultSpatialTime + 200
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.defaultSpatialCurve
        }
    }

    Repeater {
        model: bars.rows
        Item {
            id: barRow
            readonly property real scaleMax: Math.max(1e-9, Math.max(modelData.value || 0, modelData.usual || 0) * 1.12)
            readonly property real share: Math.max(0, (modelData.value || 0) / scaleMax)
            readonly property real usualShare: Math.max(0, (modelData.usual || 0) / scaleMax)
            readonly property bool over: (modelData.value || 0) >= (modelData.usual || 0)
            width: bars.width
            height: 22 + 8 + 12 + 6 + 14
            Accessible.ignored: true

            Text {
                id: rowLabel
                width: parent.width - rowValue.width - 12
                text: modelData.label
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
                elide: Text.ElideRight
                anchors.baseline: rowValue.baseline
            }
            Numeral {
                id: rowValue
                anchors.right: parent.right
                text: modelData.valueText
                color: bars.sample ? Theme.text3 : Theme.text
                font.pixelSize: 20
                font.letterSpacing: -0.3
            }
            // the track, the bar and the usual
            Item {
                id: track
                y: 30
                width: parent.width
                height: 12
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
                Rectangle {
                    width: Math.max(height, track.width * barRow.share * Math.max(0, bars.grown))
                    height: parent.height
                    radius: height / 2
                    color: bars.sample ? Qt.rgba(1, 1, 1, 0.16) : (barRow.over ? bars.tint : Qt.darker(bars.tint, 1.5))
                    Behavior on color {
                        enabled: !Theme.reduceMotion
                        ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                    }
                }
                Rectangle {
                    visible: (modelData.usual || 0) > 0
                    x: Math.round(track.width * barRow.usualShare) - 1
                    y: -4
                    width: 2
                    height: parent.height + 8
                    radius: 1
                    color: bars.sample ? Theme.text3 : Theme.text
                }
            }
            Text {
                visible: (modelData.usual || 0) > 0
                y: track.y + track.height + 6
                x: Math.max(0, Math.min(parent.width - width, track.width * barRow.usualShare - width / 2))
                text: qsTr("usual %1").arg(modelData.usualText)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 12
            }
        }
    }
}
