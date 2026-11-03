import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "Progress.js" as Progress

// The history of one record as steps: flat while it stood, up each time it was beaten, from the
// first time it was set to today.
Item {
    id: chart

    property var steps: []            // [{start, value, text}] in time order, each one higher

    readonly property real first: steps.length > 0 ? steps[0].start : 0
    readonly property real span: Math.max(86400000, Date.now() - first)
    readonly property real lo: steps.length > 0 ? steps[0].value * 0.92 : 0
    readonly property real hi: steps.length > 0 ? steps[steps.length - 1].value * 1.02 : 1

    Accessible.role: Accessible.Graphic
    Accessible.name: steps.length > 1
                     ? qsTr("Record history: from %1 on %2 to %3 on %4").arg(steps[0].text).arg(Progress.shortDate(steps[0].start))
                       .arg(steps[steps.length - 1].text).arg(Progress.shortDate(steps[steps.length - 1].start))
                     : qsTr("Record history: set once")

    function xOf(ms) {
        return (ms - first) / span * plot.width
    }

    function yOf(v) {
        return plot.height * (1 - (v - lo) / Math.max(1e-6, hi - lo))
    }

    readonly property var line: {
        var out = []
        if (steps.length === 0 || plot.width < 2)
            return out
        out.push(Qt.point(0, yOf(steps[0].value)))
        for (var i = 1; i < steps.length; i++) {
            var x = xOf(steps[i].start)
            out.push(Qt.point(x, yOf(steps[i - 1].value)))
            out.push(Qt.point(x, yOf(steps[i].value)))
        }
        out.push(Qt.point(plot.width, yOf(steps[steps.length - 1].value)))
        return out
    }

    Item {
        id: plot
        x: 4
        y: 18
        width: parent.width - 8
        height: parent.height - 18 - 20

        Rectangle {
            width: parent.width
            height: 1
            y: parent.height
            color: Theme.hairline
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 2
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                PathPolyline { path: chart.line }
            }
        }

        Repeater {
            model: chart.steps.length
            Rectangle {
                id: stepDot
                x: chart.xOf(chart.steps[index].start) - width / 2
                y: chart.yOf(chart.steps[index].value) - height / 2
                width: index === chart.steps.length - 1 ? 10 : 7
                height: width
                radius: width / 2
                color: index === chart.steps.length - 1 ? Theme.accent : Theme.text2
                border.width: 2
                border.color: Theme.bg
            }
        }
    }

    // the record now, above its end
    Text {
        anchors.right: parent.right
        y: 0
        text: chart.steps.length > 0 ? chart.steps[chart.steps.length - 1].text : ""
        color: Theme.text
        font.family: Theme.bodySemibold
        font.pixelSize: 11
    }

    Text {
        x: 0
        anchors.bottom: parent.bottom
        text: chart.steps.length > 0 ? Progress.shortDate(chart.first) : ""
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 11
    }
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: qsTr("Today")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 11
    }
}
