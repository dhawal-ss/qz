import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../Format.js" as Format
import "Progress.js" as Progress

// The best watts for every duration, from 1 s to the longest effort of the period, on a
// logarithmic time axis, with a fainter curve of an earlier period to compare with.
// The library keeps the best of each ride for the durations of RideStatsCalc::curveDurations()
// only, so the line between those points is a monotone curve through them, and the crosshair
// snaps to the measured points: only they have a ride and a date.
Card {
    id: card
    objectName: "powerCurve"

    property var library: null
    property real weight: 0          // kg, 0 when the rider has not set it

    signal openRide(int id)

    // "30", "90", "year" or "all"; the comparison: "previous", "all" or "none"
    property string period: "90"
    property string compare: "previous"
    property var points: []
    property var comparePoints: []
    property int cursor: -1          // index in points, -1 when the crosshair is hidden

    readonly property bool comparing: period !== "all" && compare !== "none" && comparePoints.length > 1
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
    // the point the readout shows without the crosshair: 20 min, or the longest one under it
    readonly property int headline: {
        var pick = -1
        for (var i = 0; i < points.length; i++)
            if (points[i].seconds <= 1200)
                pick = i
        return pick
    }
    readonly property int shown: cursor >= 0 && cursor < points.length ? cursor : headline
    readonly property var shownPoint: shown >= 0 ? points[shown] : null

    // the lines of both curves for the current size; rebuilt with the data
    property var drawn: ({ line: [], area: [], before: [] })

    function periodLabel(key) {
        if (key === "30")
            return qsTr("Last 30 days")
        if (key === "90")
            return qsTr("Last 90 days")
        if (key === "year")
            return qsTr("This year")
        return qsTr("All time")
    }

    function compareLabel() {
        if (compare === "all")
            return qsTr("All time")
        if (period === "30")
            return qsTr("Previous 30 days")
        if (period === "90")
            return qsTr("Previous 90 days")
        return qsTr("Last year so far")
    }

    // the current period and the one to compare with, as [from, to] in ms (0 = no bound)
    function ranges() {
        var now = Date.now()
        var day = 86400000
        if (period === "30")
            return [[now - 30 * day, 0], [now - 60 * day, now - 30 * day]]
        if (period === "90")
            return [[now - 90 * day, 0], [now - 180 * day, now - 90 * day]]
        // this year so far against last year up to the same date and time (29 Feb becomes 28)
        if (period === "year") {
            var t = new Date()
            var lastDay = new Date(t.getFullYear() - 1, t.getMonth() + 1, 0, 12).getDate()
            var same = new Date(t.getFullYear() - 1, t.getMonth(), Math.min(t.getDate(), lastDay), t.getHours(), t.getMinutes())
            return [[new Date(t.getFullYear(), 0, 1).getTime(), 0], [new Date(t.getFullYear() - 1, 0, 1).getTime(), same.getTime()]]
        }
        return [[0, 0], [0, 0]]
    }

    function refresh() {
        cursor = -1
        if (!library) {
            points = []
            comparePoints = []
            return
        }
        var r = ranges()
        points = library.powerCurve(r[0][0], r[0][1])
        if (period === "all" || compare === "none")
            comparePoints = []
        else if (compare === "all")
            comparePoints = library.powerCurve(0, 0)
        else
            comparePoints = library.powerCurve(r[1][0], r[1][1])
        rebuild()
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
        var line = curveLine(points)
        var area = line.slice()
        if (line.length > 1) {
            area.push(Qt.point(line[line.length - 1].x, plot.height))
            area.push(Qt.point(line[0].x, plot.height))
        }
        drawn = { line: line, area: area, before: comparing ? curveLine(comparePoints) : [] }
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

    function wattsText(watts) {
        return Math.round(watts) + " W"
    }

    function perKg(watts) {
        return weight > 0 ? (watts / weight).toFixed(1) + " W/kg" : ""
    }

    onLibraryChanged: refresh()
    onPeriodChanged: refresh()
    onCompareChanged: refresh()
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: card.library
        ignoreUnknownSignals: true
        function onChanged() { card.refresh() }
    }

    Text {
        text: qsTr("Power curve")
        color: Theme.text2
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.labelSize
    }

    Chips {
        width: parent.width
        what: qsTr("Period")
        current: card.period
        options: [["30", qsTr("30 days")], ["90", qsTr("90 days")], ["year", qsTr("Year")], ["all", qsTr("All")]]
        onPicked: card.period = key
    }

    // the best of a duration: the one under the crosshair, or 20 min
    Item {
        width: parent.width
        height: 78
        visible: card.points.length > 0

        // the first two lines keep clear of the button, the last one runs under it
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 2
            Text {
                width: parent.width - (openButton.visible ? openButton.width + 12 : 0)
                text: card.shownPoint ? qsTr("Best %1").arg(Progress.effort(card.shownPoint.seconds)) : ""
                color: Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.labelSize
                elide: Text.ElideRight
            }
            Row {
                spacing: 8
                Text {
                    id: bigWatts
                    text: card.shownPoint ? card.wattsText(card.shownPoint.watts) : ""
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 28
                }
                Text {
                    anchors.baseline: bigWatts.baseline
                    visible: text !== ""
                    text: card.shownPoint ? card.perKg(card.shownPoint.watts) : ""
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.bodySize
                }
            }
            Text {
                width: parent.width
                text: {
                    if (!card.shownPoint)
                        return ""
                    if (card.cursor < 0)
                        return qsTr("Drag across the curve to read it")
                    var line = Format.day(card.shownPoint.start)
                    var before = card.comparing ? card.wattsAt(card.comparePoints, card.shownPoint.seconds) : -1
                    if (before > 0)
                        line += ", " + qsTr("%1: %2").arg(card.compareLabel().toLowerCase()).arg(card.wattsText(before))
                    return line
                }
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
                elide: Text.ElideRight
            }
        }

        PulseButton {
            id: openButton
            visible: card.cursor >= 0 && card.shownPoint !== null && card.shownPoint.rideId > 0
            anchors.right: parent.right
            y: 4
            width: openText.implicitWidth + 32
            height: 48
            fill: pressed ? Theme.pressed : Theme.chip
            Accessible.name: qsTr("Open the ride of this record")
            onClicked: card.openRide(card.shownPoint.rideId)
            contentItem: Text {
                id: openText
                text: qsTr("Open ride")
                color: Theme.accent
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.labelSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Item {
        id: chartBox
        width: parent.width
        height: (card.width < 480 ? 190 : 230) + 22

        Accessible.role: Accessible.Graphic
        Accessible.name: {
            var parts = []
            var want = [5, 60, 300, 1200, 3600]
            for (var i = 0; i < card.points.length; i++)
                if (want.indexOf(card.points[i].seconds) >= 0)
                    parts.push(Progress.effort(card.points[i].seconds) + " " + card.wattsText(card.points[i].watts))
            return parts.length > 0 ? qsTr("Power curve, %1: %2").arg(card.periodLabel(card.period).toLowerCase()).arg(parts.join(", "))
                                    : qsTr("Power curve, no rides in this period")
        }

        Item {
            id: plot
            width: parent.width
            height: parent.height - 22

            onWidthChanged: Qt.callLater(card.rebuild)
            onHeightChanged: Qt.callLater(card.rebuild)

            // faint grid at 0, half and the top of the scale, with its watts
            Repeater {
                model: 3
                Item {
                    id: gridLine
                    y: Math.round(index * (plot.height - 1) / 2)
                    width: plot.width
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.hairline
                    }
                    Text {
                        visible: index < 2
                        y: 3
                        text: Math.round(card.scaleTop * (1 - index / 2)) + " W"
                        color: Theme.text3
                        style: Text.Outline
                        styleColor: Theme.card
                        font.family: Theme.bodyMedium
                        font.pixelSize: 11
                    }
                }
            }

            // the ticks of the time axis
            Repeater {
                model: [5, 60, 300, 1200, 3600]
                Rectangle {
                    id: tick
                    visible: modelData < card.longest * 1.001
                    x: Math.round(card.xOf(modelData))
                    width: 1
                    height: plot.height
                    color: Qt.rgba(1, 1, 1, 0.05)
                }
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 0; y2: plot.height
                            GradientStop { position: 0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30) }
                            GradientStop { position: 1; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.02) }
                        }
                        PathPolyline { path: card.drawn.area }
                    }
                }
                Shape {
                    anchors.fill: parent
                    visible: card.comparing
                    ShapePath {
                        strokeColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                        strokeWidth: 1.6
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 3]
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: card.drawn.before }
                    }
                }
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 2.2
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        capStyle: ShapePath.RoundCap
                        PathPolyline { path: card.drawn.line }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: card.points.length === 0
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("No rides in this period yet.")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
            }

            // the crosshair on a measured point
            Item {
                id: crosshair
                anchors.fill: parent
                visible: card.cursor >= 0 && card.shownPoint !== null
                readonly property real cx: card.shownPoint ? card.xOf(card.shownPoint.seconds) : 0
                readonly property real before: card.shownPoint && card.comparing ? card.wattsAt(card.comparePoints, card.shownPoint.seconds) : -1

                Rectangle {
                    x: Math.round(crosshair.cx)
                    width: 1
                    height: plot.height
                    color: Qt.rgba(1, 1, 1, 0.6)
                }
                Rectangle {
                    visible: crosshair.before > 0
                    x: crosshair.cx - width / 2
                    y: card.yOf(crosshair.before) - height / 2
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.text2
                    border.width: 2
                    border.color: Theme.card
                }
                Rectangle {
                    x: crosshair.cx - width / 2
                    y: card.shownPoint ? card.yOf(card.shownPoint.watts) - height / 2 : 0
                    width: 11
                    height: 11
                    radius: 5.5
                    color: Theme.accent
                    border.width: 2
                    border.color: Theme.card
                }
            }

            ScrubArea {
                anchors.fill: parent
                enabled: card.points.length > 0
                onScrub: card.cursor = card.nearest(at)
                onTap: card.cursor = card.cursor >= 0 ? -1 : card.nearest(at)
            }
        }

        // durations under the ticks; the outer ones stay inside the chart
        Repeater {
            model: [5, 60, 300, 1200, 3600]
            Text {
                id: tickLabel
                visible: modelData < card.longest * 1.001
                y: plot.height + 5
                x: Math.max(0, Math.min(chartBox.width - implicitWidth, card.xOf(modelData) - implicitWidth / 2))
                text: Progress.effort(modelData)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 11
            }
        }
    }

    // which line is which
    Flow {
        width: parent.width
        spacing: 16
        visible: card.points.length > 0
        Row {
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 3
                radius: 1.5
                color: Theme.accent
            }
            Text {
                text: card.periodLabel(card.period)
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }
        Row {
            spacing: 8
            visible: card.comparing
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 3
                    Rectangle {
                        width: 4
                        height: 2
                        color: Theme.text2
                    }
                }
            }
            Text {
                text: card.compareLabel()
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }
    }

    Chips {
        width: parent.width
        visible: card.period !== "all"
        what: qsTr("Compare with")
        lead: width > 400 ? qsTr("Compare with") : ""
        current: card.compare
        options: [["previous", card.period === "year" ? qsTr("Last year") : qsTr("Previous")],
                  ["all", qsTr("All time")], ["none", qsTr("None")]]
        onPicked: card.compare = key
    }
}
