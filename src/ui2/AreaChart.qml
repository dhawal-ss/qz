import QtQuick 2.15
import QtQuick.Shapes 1.15
import "."

// One metric over a ride: a line with a soft fill under it, the average as a faint line and
// the top of the scale written on the right. Values are spread evenly over the width.
Item {
    id: chart

    property var values: []
    property color color: Theme.accent
    property string unit: ""
    property real floor: 0          // bottom of the scale; heart rate starts near its lowest value
    property bool fromLowest: false
    property real average: -1       // drawn when 0 or more

    Accessible.ignored: true

    readonly property real scaleTop: {
        var hi = 1
        for (var i = 0; i < values.length; i++)
            hi = Math.max(hi, values[i])
        return niceTop(hi)
    }
    readonly property real scaleBottom: {
        if (!fromLowest)
            return floor
        var lo = scaleTop
        for (var i = 0; i < values.length; i++)
            if (values[i] > 0)
                lo = Math.min(lo, values[i])
        return Math.max(0, Math.floor((lo - 5) / 10) * 10)
    }

    // round the top of the scale up to a value that reads well
    function niceTop(v) {
        var steps = [10, 20, 25, 50, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 1500, 2000]
        for (var i = 0; i < steps.length; i++)
            if (v <= steps[i])
                return steps[i]
        return Math.ceil(v / 500) * 500
    }

    function yOf(v) {
        var span = Math.max(1, scaleTop - scaleBottom)
        return plot.height * (1 - (Math.max(scaleBottom, v) - scaleBottom) / span)
    }

    function line() {
        var list = []
        var n = values.length
        if (n < 2)
            return list
        for (var i = 0; i < n; i++)
            list.push(Qt.point(i * plot.width / (n - 1), yOf(values[i])))
        return list
    }

    function area() {
        var list = line()
        if (list.length < 2)
            return list
        list.push(Qt.point(plot.width, plot.height))
        list.push(Qt.point(0, plot.height))
        return list
    }

    Item {
        id: plot
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 18 }

        // faint grid at the top, middle and bottom of the scale
        Repeater {
            model: 3
            Rectangle {
                width: plot.width
                height: 1
                y: Math.round(index * plot.height / 2)
                color: Theme.hairline
            }
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: plot.height
                    GradientStop { position: 0; color: Qt.rgba(chart.color.r, chart.color.g, chart.color.b, 0.32) }
                    GradientStop { position: 1; color: Qt.rgba(chart.color.r, chart.color.g, chart.color.b, 0.02) }
                }
                PathPolyline { path: chart.area() }
            }
            ShapePath {
                strokeColor: chart.color
                strokeWidth: 2
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathPolyline { path: chart.line() }
            }
        }

        Rectangle {
            visible: chart.average >= 0 && chart.values.length > 1
            width: plot.width
            height: 1
            y: Math.round(chart.yOf(chart.average))
            color: Qt.rgba(1, 1, 1, 0.35)
        }

        Text {
            anchors.right: parent.right
            y: -17
            text: chart.scaleTop + (chart.unit !== "" ? " " + chart.unit : "")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(11)
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            visible: chart.scaleBottom > 0
            text: chart.scaleBottom
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(11)
        }
    }
}
