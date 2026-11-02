import QtQuick 2.15
import QtQuick.Shapes 1.15
import "."

// The last minutes of one metric as a thin line.
Item {
    id: spark

    property var values: []
    property color color: Theme.accent

    Accessible.ignored: true

    function points() {
        var list = []
        var n = values.length
        if (n < 2)
            return list
        var lo = values[0]
        var hi = values[0]
        for (var i = 1; i < n; i++) {
            lo = Math.min(lo, values[i])
            hi = Math.max(hi, values[i])
        }
        var span = Math.max(1, hi - lo)
        for (var j = 0; j < n; j++)
            list.push(Qt.point(j * width / (n - 1), 2 + (height - 4) * (1 - (values[j] - lo) / span)))
        return list
    }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            strokeColor: spark.color
            strokeWidth: 2.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: spark.points() }
        }
    }
}
