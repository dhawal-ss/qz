import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../Format.js" as Format

// The best effort of a ride at every length against the best of the 90 days before it: the
// 90-day best as a quiet line, this ride in its tint, both dashed under 15 s (short peaks are
// mostly noise). Every length this ride beat is marked; the biggest (or the one the headline
// is about) gets a ring and its watts. Lengths run on a log scale from 1 s to 1 h (2 h for a
// longer ride). `reveal` wipes the lines in.
Item {
    id: curve

    property var ride: []        // [{ seconds, watts }] of this ride
    property var prior: []       // [{ seconds, watts }] of the 90 days before it
    property color tint: Theme.accent
    property real rideSeconds: 3600
    property int heroSeconds: 0
    property real reveal: 1

    readonly property int plotTop: 30
    readonly property int plotBottom: height - 34
    readonly property real maxSeconds: rideSeconds > 3700 ? 7200 : 3600
    readonly property real scaleTop: {
        var hi = 1
        for (var i = 0; i < ride.length; i++)
            if (ride[i].seconds >= 5)
                hi = Math.max(hi, ride[i].watts)
        for (var k = 0; k < prior.length; k++)
            if (prior[k].seconds >= 5)
                hi = Math.max(hi, prior[k].watts)
        var steps = [150, 300, 450, 600, 900, 1200, 1500, 1800, 2400, 3000]
        for (var s = 0; s < steps.length; s++)
            if (hi <= steps[s])
                return steps[s]
        return Math.ceil(hi / 600) * 600
    }

    function priorAt(seconds) {
        for (var i = 0; i < prior.length; i++)
            if (prior[i].seconds === seconds)
                return prior[i].watts
        return 0
    }

    // the lengths this ride beat, 5 s and longer: [{ seconds, watts, previous }]
    readonly property var beaten: {
        var out = []
        for (var i = 0; i < ride.length; i++) {
            var p = priorAt(ride[i].seconds)
            if (ride[i].seconds >= 5 && ride[i].seconds <= maxSeconds && p > 0 && ride[i].watts > p)
                out.push({ seconds: ride[i].seconds, watts: ride[i].watts, previous: p })
        }
        return out
    }
    readonly property int marked: {
        var pick = -1
        for (var i = 0; i < beaten.length; i++) {
            if (beaten[i].seconds === heroSeconds)
                return i
            if (pick < 0 || beaten[i].watts / beaten[i].previous > beaten[pick].watts / beaten[pick].previous)
                pick = i
        }
        return pick
    }

    implicitHeight: 210
    Accessible.role: Accessible.Graphic
    Accessible.name: {
        if (ride.length === 0)
            return ""
        if (beaten.length === 0)
            return qsTr("Power curve. This ride against your 90-day best. It did not beat it at any length.")
        var b = beaten[Math.max(0, marked)]
        return qsTr("Power curve. This ride against your 90-day best. It beats it at %1 lengths, %2 at %3 watts against %4.")
               .arg(beaten.length).arg(Format.effort(b.seconds)).arg(Math.round(b.watts)).arg(Math.round(b.previous))
    }

    function xOf(seconds) {
        var f = Math.log(Math.max(1, seconds)) / Math.log(maxSeconds)
        return 8 + f * (width - 16)
    }
    function yOf(watts) {
        return plotBottom - (plotBottom - plotTop) * Math.min(1, watts / scaleTop)
    }
    // the points of a curve, early (under 15 s) or the rest
    function points(list, early) {
        var out = []
        for (var i = 0; i < list.length; i++) {
            var s = list[i].seconds
            if (s > maxSeconds)
                break
            if ((early && s <= 15) || (!early && s >= 15))
                out.push(Qt.point(xOf(s), yOf(list[i].watts)))
        }
        return out
    }
    function last(list) {
        var at = null
        for (var i = 0; i < list.length; i++)
            if (list[i].seconds <= maxSeconds)
                at = list[i]
        return at
    }

    // the legend
    Row {
        spacing: 16
        Row {
            spacing: 6
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 14; height: 1.5; color: Theme.text3 }
            Text { text: qsTr("90-day best"); color: Theme.text2; font.family: Theme.bodyMedium; font.pixelSize: 12 }
        }
        Row {
            spacing: 6
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 14; height: 2.2; radius: 1; color: curve.tint }
            Text { text: qsTr("This ride"); color: curve.tint; font.family: Theme.bodySemibold; font.pixelSize: 12 }
        }
    }

    // the grid: three watt levels and the round lengths
    Repeater {
        model: 3
        Rectangle {
            x: 8
            y: Math.round(curve.yOf(curve.scaleTop * (3 - index) / 3))
            width: curve.width - 16
            height: 1
            color: Theme.overlay(0.06)
        }
    }
    Repeater {
        model: 3
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            y: curve.yOf(curve.scaleTop * (3 - index) / 3) - height - 2
            text: Math.round(curve.scaleTop * (3 - index) / 3) + (index === 0 ? " W" : "")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(12)
        }
    }
    Repeater {
        model: curve.maxSeconds > 3600 ? [5, 60, 300, 1200, 3600, 7200] : [5, 60, 300, 1200, 3600]
        Item {
            Rectangle {
                x: Math.round(curve.xOf(modelData))
                y: curve.plotTop - 8
                width: 1
                height: curve.plotBottom - curve.plotTop + 8
                color: Theme.overlay(0.06)
                visible: modelData !== curve.maxSeconds
            }
            Text {
                readonly property real at: curve.xOf(modelData)
                x: Math.max(0, Math.min(curve.width - width, at - width / 2))
                y: curve.plotBottom + 12
                text: Format.effort(modelData)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(12)
            }
        }
    }
    Text {
        x: 12
        y: curve.plotBottom - height - 4
        visible: curve.ride.length > 0
        text: qsTr("Under 15 s, low confidence")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.fs(11)
    }

    Item {
        id: lines
        width: curve.width * Math.max(0, Math.min(1, curve.reveal))
        height: curve.height
        clip: true

        Shape {
            width: curve.width
            height: curve.height
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeColor: Qt.rgba(Theme.text3.r, Theme.text3.g, Theme.text3.b, 0.4)
                strokeWidth: 1.5
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 2]
                PathPolyline { path: curve.points(curve.prior, true) }
            }
            ShapePath {
                strokeColor: Theme.text3
                strokeWidth: 1.5
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: curve.points(curve.prior, false) }
            }
            ShapePath {
                strokeColor: Qt.rgba(curve.tint.r, curve.tint.g, curve.tint.b, 0.35)
                strokeWidth: 2.2
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [1.4, 1.4]
                capStyle: ShapePath.RoundCap
                PathPolyline { path: curve.points(curve.ride, true) }
            }
            ShapePath {
                strokeColor: curve.tint
                strokeWidth: 2.2
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathPolyline { path: curve.points(curve.ride, false) }
            }
        }

        // the ends of the two lines
        Rectangle {
            readonly property var at: curve.last(curve.prior)
            visible: at !== null
            x: at ? curve.xOf(at.seconds) - 3 : 0
            y: at ? curve.yOf(at.watts) - 3 : 0
            width: 6
            height: 6
            radius: 3
            color: Theme.text3
        }
        Rectangle {
            readonly property var at: curve.last(curve.ride)
            visible: at !== null
            x: at ? curve.xOf(at.seconds) - 3 : 0
            y: at ? curve.yOf(at.watts) - 3 : 0
            width: 6
            height: 6
            radius: 3
            color: curve.tint
        }

        // every length beaten
        Repeater {
            model: curve.beaten
            Rectangle {
                visible: index !== curve.marked
                x: curve.xOf(modelData.seconds) - 3.5
                y: curve.yOf(modelData.watts) - 3.5
                width: 7
                height: 7
                radius: 3.5
                color: curve.tint
                border.width: 2
                border.color: Theme.bg
            }
        }
    }

    // the one the ride is about: a ring and its watts
    Item {
        id: mark
        readonly property var entry: curve.marked >= 0 ? curve.beaten[curve.marked] : null
        visible: entry !== null && curve.reveal >= 0.98
        x: entry ? curve.xOf(entry.seconds) : 0
        y: entry ? curve.yOf(entry.watts) : 0
        Rectangle {
            x: -9
            y: -9
            width: 18
            height: 18
            radius: 9
            color: Qt.rgba(curve.tint.r, curve.tint.g, curve.tint.b, 0.2)
        }
        Rectangle {
            x: -5.5
            y: -5.5
            width: 11
            height: 11
            radius: 5.5
            color: curve.tint
            border.width: 2
            border.color: Theme.bg
        }
        Text {
            x: Math.max(-mark.x, Math.min(curve.width - mark.x - width, -width / 2))
            y: -height - 10
            text: mark.entry ? qsTr("%1, new best").arg(Math.round(mark.entry.watts)) : ""
            color: curve.tint
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(12)
        }
    }
}
