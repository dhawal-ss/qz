import QtQuick 2.15
import "."

// Rounded bars for totals per day or week, the newest one in the accent, its label under it.
Item {
    id: bars

    property var values: []
    property var labels: []
    property color color: Theme.accent
    property int highlight: values.length - 1

    Accessible.ignored: true

    readonly property real scaleTop: {
        var hi = 0
        for (var i = 0; i < values.length; i++)
            hi = Math.max(hi, values[i])
        return Math.max(hi, 1)
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.bottomMargin: 20
        spacing: bars.values.length > 14 ? 3 : 6
        Repeater {
            model: bars.values.length
            Item {
                width: (row.width - row.spacing * (bars.values.length - 1)) / Math.max(1, bars.values.length)
                height: row.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(4, parent.height * bars.values[index] / bars.scaleTop)
                    radius: Math.min(width / 2, 6)
                    color: index === bars.highlight ? bars.color
                           : (bars.values[index] > 0 ? Qt.rgba(bars.color.r, bars.color.g, bars.color.b, 0.38) : Theme.chip)
                    Behavior on height {
                        enabled: !Theme.reduceMotion
                        NumberAnimation { duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    text: bars.labels[index] || ""
                    color: index === bars.highlight ? Theme.text : Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(11)
                }
            }
        }
    }
}
