import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Progress.js" as Progress
import "Hub.js" as Hub

// The best watts for every duration of the period, from 1 s to its longest effort, on a
// logarithmic time axis, against the same length of time just before it (dashed). The headline
// is the best 5 minutes. The library keeps the best of each ride for the durations of
// RideStatsCalc::curveDurations() only, so the line between those points is a monotone curve
// through them, and the crosshair snaps to the measured points: only they have a ride and a date.
Column {
    id: curve
    objectName: "powerCurve"

    property var library: null
    property real weight: 0          // kg, 0 when the rider has not set it
    property string period: "3m"
    property bool pro: false

    signal openRide(int id)
    // a tap on the chart asks for its Learn sheet, with the rider's best 5 minutes
    signal learn(string key, var facts)

    function learnFacts() {
        return { w300: wattsAt(points, 300), prior300: comparing ? wattsAt(comparePoints, 300) : 0 }
    }

    property var points: []
    property var comparePoints: []
    property int cursor: -1          // index in points, -1 when the crosshair is hidden

    readonly property bool comparing: points.length > 1 && comparePoints.length > 1
    readonly property real longest: {
        var hi = 60
        if (points.length > 0)
            hi = Math.max(hi, points[points.length - 1].seconds)
        if (comparing)
            hi = Math.max(hi, comparePoints[comparePoints.length - 1].seconds)
        return hi
    }
    readonly property real scaleTop: {
        var hi = 0
        for (var i = 0; i < points.length; i++)
            hi = Math.max(hi, points[i].watts)
        if (comparing)
            for (var j = 0; j < comparePoints.length; j++)
                hi = Math.max(hi, comparePoints[j].watts)
        return Progress.niceTop(Math.max(100, hi * 1.04))
    }
    // the point the headline shows without the crosshair: 5 min, or the longest one under it
    readonly property int headline: {
        var pick = -1
        for (var i = 0; i < points.length; i++)
            if (points[i].seconds <= 300)
                pick = i
        return pick
    }
    readonly property int shown: cursor >= 0 && cursor < points.length ? cursor : headline
    readonly property var shownPoint: shown >= 0 ? points[shown] : null
    readonly property real shownBefore: shownPoint && comparing ? wattsAt(comparePoints, shownPoint.seconds) : -1

    // the lines of both curves for the current size; rebuilt with the data
    property var drawn: ({ line: [], before: [] })

    function refresh() {
        cursor = -1
        if (!library) {
            points = []
            comparePoints = []
            return
        }
        var now = Date.now()
        var span = Hub.days(period) * Hub.dayMs
        points = library.powerCurve(now - span, 0)
        comparePoints = library.powerCurve(now - 2 * span, now - span)
        rebuild()
    }

    function play() {
        cursor = -1
        drawIn.play()
    }

    function xOf(seconds) {
        return Math.log(Math.max(1, seconds)) / Math.log(longest) * plot.width
    }

    function yOf(watts) {
        return plot.height * (1 - Math.max(0, watts) / scaleTop)
    }

    function wattsAt(list, seconds) {
        for (var i = 0; i < list.length; i++)
            if (list[i].seconds === seconds)
                return list[i].watts
        return -1
    }

    // a polyline every 2 px along the monotone curve through the points
    function curveLine(list) {
        if (list.length < 2 || plot.width < 2)
            return []
        var xs = []
        var ys = []
        for (var i = 0; i < list.length; i++) {
            xs.push(Math.log(Math.max(1, list[i].seconds)))
            ys.push(list[i].watts)
        }
        var slopes = Progress.monotoneSlopes(xs, ys)
        var x0 = xOf(list[0].seconds)
        var x1 = xOf(list[list.length - 1].seconds)
        var out = []
        var scale = Math.log(longest) / plot.width
        for (var x = x0; x < x1; x += 2)
            out.push(Qt.point(x, yOf(Progress.monotoneAt(xs, ys, slopes, x * scale))))
        out.push(Qt.point(x1, yOf(ys[ys.length - 1])))
        return out
    }

    function rebuild() {
        drawn = { line: curveLine(points), before: comparing ? curveLine(comparePoints) : [] }
    }

    // the measured point closest to x on the log axis
    function nearest(x) {
        var u = Math.max(0, x) / Math.max(1, plot.width) * Math.log(longest)
        var best = -1
        for (var i = 0; i < points.length; i++) {
            var gap = Math.abs(Math.log(Math.max(1, points[i].seconds)) - u)
            if (best < 0 || gap < Math.abs(Math.log(Math.max(1, points[best].seconds)) - u))
                best = i
        }
        return best
    }

    spacing: 12

    SectionHead {
        width: parent.width
        title: qsTr("Power curve")
        // worked out watts (library.powerGroup 1) are compared only with this kind of bike
        note: curve.comparing ? qsTr("vs last period")
                              : (curve.library !== null && curve.library.powerGroup === 1 ? qsTr("Est., this bike") : "")
    }

    // the best of a duration: the one under the crosshair, or 5 min
    Item {
        width: parent.width
        height: 58
        visible: curve.shownPoint !== null
        Accessible.role: Accessible.StaticText
        Accessible.name: curve.shownPoint ? qsTr("%1 watts at %2").arg(Math.round(curve.shownPoint.watts)).arg(Progress.effort(curve.shownPoint.seconds)) : ""

        Row {
            id: wattsRow
            spacing: 6
            RollingNumber {
                id: wattsNumber
                value: curve.shownPoint ? String(Math.round(curve.shownPoint.watts)) : ""
                font.family: Theme.display
                font.pixelSize: 30
            }
            Text {
                anchors.bottom: wattsNumber.bottom
                anchors.bottomMargin: 6
                text: curve.shownPoint ? qsTr("W at %1").arg(Progress.effort(curve.shownPoint.seconds)) : ""
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
            }
            Text {
                anchors.bottom: wattsNumber.bottom
                anchors.bottomMargin: 6
                visible: curve.pro && curve.weight > 0 && curve.shownPoint !== null
                text: curve.shownPoint && curve.weight > 0 ? (curve.shownPoint.watts / curve.weight).toFixed(1) + " W/kg" : ""
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 12
            }
        }
        Text {
            y: wattsRow.y + wattsRow.height + 4
            width: parent.width - (openButton.visible ? openButton.width + 8 : 0)
            text: {
                if (!curve.shownPoint)
                    return ""
                var parts = []
                if (curve.cursor >= 0)
                    parts.push(Format.day(curve.shownPoint.start))
                if (curve.shownBefore > 0)
                    parts.push(qsTr("previous %1 W").arg(Math.round(curve.shownBefore)))
                return parts.join(", ")
            }
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        PulseButton {
            id: openButton
            visible: curve.cursor >= 0 && curve.shownPoint !== null && curve.shownPoint.rideId > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: openText.implicitWidth + 28
            height: 44
            fill: pressed ? Theme.pressed : Theme.chip
            Accessible.name: qsTr("Open the ride of this best")
            onClicked: curve.openRide(curve.shownPoint.rideId)
            contentItem: Text {
                id: openText
                text: qsTr("Open ride")
                color: Theme.accent
                font.family: Theme.bodySemibold
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    DrawIn {
        id: drawIn
        width: parent.width
        height: chartBox.height

        Item {
            id: chartBox
            width: drawIn.width
            height: plot.height + 22

            Accessible.role: Accessible.Button
            Accessible.name: {
                var parts = []
                var want = [5, 60, 300, 1200, 3600]
                for (var i = 0; i < curve.points.length; i++)
                    if (want.indexOf(curve.points[i].seconds) >= 0)
                        parts.push(Progress.effort(curve.points[i].seconds) + " " + Math.round(curve.points[i].watts) + " W")
                return parts.length > 0 ? qsTr("Power curve of the period: %1. Tap to learn more").arg(parts.join(", "))
                                        : qsTr("Power curve, no rides in this period. Tap to learn more")
            }
            Accessible.onPressAction: curve.learn("curve", curve.learnFacts())

            Item {
                id: plot
                width: parent.width
                height: curve.width < 480 ? 170 : 210

                onWidthChanged: Qt.callLater(curve.rebuild)
                onHeightChanged: Qt.callLater(curve.rebuild)

                // the ticks of the time axis
                Repeater {
                    model: [5, 60, 300, 1200, 3600]
                    Rectangle {
                        id: tick
                        visible: modelData < curve.longest * 1.001
                        x: Math.round(curve.xOf(modelData))
                        width: 1
                        height: plot.height
                        color: Qt.rgba(1, 1, 1, 0.05)
                    }
                }
                Hairline {
                    y: plot.height
                    width: plot.width
                }
                Text {
                    visible: curve.pro && curve.points.length > 0
                    x: 2
                    y: 0
                    text: curve.scaleTop + " W"
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                }

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    Shape {
                        anchors.fill: parent
                        visible: curve.comparing
                        ShapePath {
                            strokeColor: Theme.text3
                            strokeWidth: 1.5
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [2, 2]
                            fillColor: "transparent"
                            joinStyle: ShapePath.RoundJoin
                            PathPolyline { path: curve.drawn.before }
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: Theme.text
                            strokeWidth: 2
                            fillColor: "transparent"
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.RoundCap
                            PathPolyline { path: curve.drawn.line }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: curve.points.length === 0
                    width: parent.width - 32
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("No rides in this period yet.")
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 14
                }

                // the shown point: 5 min, or the one under the crosshair
                Item {
                    id: marker
                    anchors.fill: parent
                    visible: curve.shownPoint !== null
                    readonly property real cx: curve.shownPoint ? curve.xOf(curve.shownPoint.seconds) : 0

                    Rectangle {
                        visible: curve.cursor >= 0
                        x: Math.round(marker.cx)
                        width: 1
                        height: plot.height
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }
                    Rectangle {
                        visible: curve.shownBefore > 0 && curve.cursor >= 0
                        x: marker.cx - width / 2
                        y: curve.yOf(curve.shownBefore) - height / 2
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.text3
                        border.width: 2
                        border.color: Theme.bg
                    }
                    Rectangle {
                        x: marker.cx - width / 2
                        y: curve.shownPoint ? curve.yOf(curve.shownPoint.watts) - height / 2 : 0
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.accent
                        border.width: 2
                        border.color: Theme.bg
                    }
                }

                ScrubArea {
                    anchors.fill: parent
                    enabled: curve.points.length > 0
                    onScrub: curve.cursor = curve.nearest(at)
                    learnable: true
                    onTap: {
                        if (curve.cursor >= 0)
                            curve.cursor = -1
                        else
                            curve.learn("curve", curve.learnFacts())
                    }
                }
            }

            // durations under the ticks; the outer ones stay inside the chart
            Repeater {
                model: [5, 60, 300, 1200, 3600]
                Text {
                    id: tickLabel
                    visible: modelData < curve.longest * 1.001
                    y: plot.height + 6
                    x: Math.max(0, Math.min(chartBox.width - implicitWidth, curve.xOf(modelData) - implicitWidth / 2))
                    text: Progress.effort(modelData)
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                }
            }
        }
    }

    // which line is which
    Row {
        spacing: 18
        visible: curve.points.length > 0 && curve.comparing
        Row {
            spacing: 7
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 2
                radius: 1
                color: Theme.text
            }
            Text {
                text: qsTr("This period")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: 12
            }
        }
        Row {
            spacing: 7
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        width: 2
                        height: 2
                        color: Theme.text3
                    }
                }
            }
            Text {
                text: qsTr("Previous")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 12
            }
        }
    }
}
