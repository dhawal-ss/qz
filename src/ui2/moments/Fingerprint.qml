import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."

// The ride fingerprint of the share card: one bar per minute round a ring, clockwise from the top,
// each as long as the power of its minute and in the color of its zone; the words in the middle.
// It grows in once (scale 0.6 and a turn to its place, on the spring curve).
Item {
    id: fprint

    // [{ watts, zone }] in ride order; zone 0 takes the tint
    property var bars: []
    property color tint: Theme.accent
    property string centerValue: ""
    property string centerWord: ""
    property real grown: 1

    // on the board's 300 box: the ring at 50, bars up to 88 long, 5 wide
    readonly property real unit: width / 300
    readonly property real inner: 50 * unit
    readonly property real peak: {
        var top = 1
        for (var i = 0; i < bars.length; i++)
            top = Math.max(top, bars[i].watts || 0)
        return top
    }
    readonly property real barWidth: Math.max(1.5, Math.min(5 * unit, 0.62 * 2 * Math.PI * inner / Math.max(1, bars.length)))

    implicitWidth: 300
    implicitHeight: 300

    function grow() {
        if (Theme.reduceMotion) {
            grown = 1
            return
        }
        growAnimation.restart()
    }

    NumberAnimation {
        id: growAnimation
        target: fprint
        property: "grown"
        from: 0
        to: 1
        duration: 1200
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.springCurve
    }

    // the bars of one zone (1 to 7, 0 for no zone) as pairs of points
    function lines(zone) {
        var out = []
        var n = bars.length
        var c = width / 2
        for (var i = 0; i < n; i++) {
            if ((bars[i].zone || 0) !== zone)
                continue
            var share = Math.max(0, Math.min(1, (bars[i].watts || 0) / peak))
            var length = (12 + 76 * share * share) * unit
            var a = (-90 + (i + 0.5) * 360 / n) * Math.PI / 180
            out.push([Qt.point(c + Math.cos(a) * inner, c + Math.sin(a) * inner),
                      Qt.point(c + Math.cos(a) * (inner + length), c + Math.sin(a) * (inner + length))])
        }
        return out
    }

    Item {
        anchors.fill: parent
        opacity: Math.min(1, fprint.grown * 1.6)
        scale: 0.6 + 0.4 * fprint.grown
        rotation: -30 * (1 - fprint.grown)
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeColor: fprint.tint
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(0) }
            }
            ShapePath {
                strokeColor: Theme.zoneColors[0]
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(1) }
            }
            ShapePath {
                strokeColor: Theme.zoneColors[1]
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(2) }
            }
            ShapePath {
                strokeColor: Theme.zoneColors[2]
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(3) }
            }
            ShapePath {
                strokeColor: Theme.zoneColors[3]
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(4) }
            }
            ShapePath {
                strokeColor: Theme.zoneColors[4]
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(5) }
            }
            ShapePath {
                strokeColor: Theme.zoneColors[5]
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(6) }
            }
            ShapePath {
                strokeColor: Theme.zoneColors[6]
                strokeWidth: fprint.barWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathMultiline { paths: fprint.lines(7) }
            }
        }
    }

    // the quiet ring and the words in the middle
    Rectangle {
        anchors.centerIn: parent
        width: 76 * fprint.unit
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, fprint.unit)
        border.color: Theme.hairline
    }
    Column {
        anchors.centerIn: parent
        spacing: 3 * fprint.unit
        Numeral {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fprint.centerValue
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: Math.round(30 * fprint.unit * Math.min(1, 3 / Math.max(1, text.length)))
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fprint.centerWord
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Math.max(10, Math.round(12 * fprint.unit))
        }
    }
}
