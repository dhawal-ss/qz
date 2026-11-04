import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."

// One metric over the window of the ride a ChartView shows: a line with a soft fill, the
// average as a faint line, lap starts as faint verticals and the shared crosshair with its value.
// A long ride is cut into one bucket per pixel and each bucket draws its lowest and highest
// sample, so peaks survive and the line stays light. Power can color the line by zone.
//
// Touch: a sideways drag scrubs the crosshair (pans when zoomed in), press and hold then drag
// always scrubs, a pinch zooms, a tap shows or hides the crosshair, a double tap shows the
// whole ride. Vertical drags are left to the page, so it still scrolls over the charts.
// With `learnable` a tap opens the chart's Learn sheet instead (learn(), after the time of a
// double tap, so a double tap still shows the whole ride); a tap while the crosshair shows still
// hides it, and a held or sideways touch still scrubs.
//
// For the hero chart of a ride: `filled` paints the power as soft areas in their zone colors,
// `overlay` lays a second metric (heart rate) over it as a thin line on its own scale, and a
// band (bandStart to bandEnd, ride seconds) marks the best stretch with its label at the top
// right; the band pans and zooms with the rest. `reveal` (0 to 1) wipes the ink in.
Item {
    id: chart

    property ChartView view: null
    property var seconds: []
    property var values: []
    property string name: ""
    property string unit: ""
    property color color: Theme.accent
    property real factor: 1             // multiplies every value: 0.621371 for speed in miles
    property int decimals: 0
    property real average: -1           // the ride's average; below 0 it is worked out here
    property bool fromLowest: false     // heart rate: the scale starts near the lowest value and 0 is a dropout
    property bool zoneColored: false
    property real ftp: 0
    property var laps: []               // start of each lap, in seconds
    property var parts: []              // where each part of a merged ride starts (after the first), in seconds
    property bool showAverage: true
    property bool filled: false
    property var overlay: []            // a second metric on the same seconds, e.g. heart rate
    property string overlayName: ""
    property string overlayShort: ""    // its name in the bubble: "HR"
    property real bandStart: -1
    property real bandEnd: -1
    property color bandColor: Theme.accent
    property string bandLabel: ""
    property string bandValue: ""
    property real reveal: 1

    property int topStrip: 22
    property bool learnable: false

    signal learn()

    Accessible.role: learnable ? Accessible.Button : Accessible.Graphic
    Accessible.name: qsTr("%1 chart, average %2, highest %3").arg(name).arg(valueText(shownAverage)).arg(valueText(stats.hi))
                     + (learnable ? ". " + qsTr("Tap to learn more") : "")
    Accessible.onPressAction: if (learnable) chart.learn()

    // a single tap waits out a double tap before it opens the Learn sheet
    Timer {
        id: learnLater
        interval: 260
        onTriggered: chart.learn()
    }

    // the whole ride once: highest, lowest reading and average, before the factor
    readonly property var stats: {
        var n = Math.min(seconds.length, values.length)
        var hi = 0
        var lo = -1
        var sum = 0
        for (var i = 0; i < n; i++) {
            var v = values[i]
            hi = Math.max(hi, v)
            sum += v
            if (v > 0 && (lo < 0 || v < lo))
                lo = v
        }
        return { hi: hi, lo: Math.max(0, lo), mean: n > 0 ? sum / n : 0 }
    }
    // lowest, highest, sum and count of every 16 samples, so a long window is drawn from
    // a sixteenth of the samples
    readonly property int blockSize: 16
    readonly property var blocks: {
        var n = Math.min(seconds.length, values.length)
        var out = { lo: [], hi: [], sum: [], used: [] }
        for (var start = 0; start < n; start += blockSize) {
            var lo = -1
            var hi = -1
            var sum = 0
            var used = 0
            for (var i = start; i < Math.min(n, start + blockSize); i++) {
                var v = values[i]
                if (fromLowest && v <= 0)
                    continue
                if (lo < 0 || v < values[lo])
                    lo = i
                if (hi < 0 || v > values[hi])
                    hi = i
                sum += v
                used++
            }
            out.lo.push(lo)
            out.hi.push(hi)
            out.sum.push(sum)
            out.used.push(used)
        }
        return out
    }
    // the overlay keeps to the upper part of the plot, over the power
    readonly property var overlayStats: {
        var hi = 0
        var lo = -1
        for (var i = 0; i < overlay.length; i++) {
            var v = overlay[i]
            if (!(v > 0))
                continue
            hi = Math.max(hi, v)
            if (lo < 0 || v < lo)
                lo = v
        }
        var span = Math.max(10, hi - Math.max(0, lo))
        return { hi: hi + span * 0.15, lo: Math.max(0, lo) - span * 0.55 }
    }
    readonly property real shownAverage: average >= 0 ? average : stats.mean
    readonly property real scaleTop: niceTop(Math.max(1, stats.hi * factor))
    readonly property real scaleBottom: fromLowest ? Math.max(0, Math.floor((stats.lo * factor - 5) / 10) * 10) : 0

    // the line, its fill and the zone pieces for the current window; rebuilt with the window
    property var drawn: ({ line: [], area: [], zones: [[], [], [], [], [], [], []], areas: ["", "", "", "", "", "", ""], over: [] })

    // round the top of the scale up to a value that reads well
    function niceTop(v) {
        var steps = [5, 10, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 1500, 2000]
        for (var i = 0; i < steps.length; i++)
            if (v <= steps[i])
                return steps[i]
        return Math.ceil(v / 500) * 500
    }

    function valueText(v) {
        return (v * factor).toFixed(decimals) + (unit !== "" ? " " + unit : "")
    }

    function yOfOverlay(v) {
        var span = Math.max(1, overlayStats.hi - overlayStats.lo)
        return plot.height * (1 - (v - overlayStats.lo) / span)
    }

    function yOf(v) {
        var span = Math.max(1, scaleTop - scaleBottom)
        return plot.height * (1 - (Math.max(scaleBottom, v * factor) - scaleBottom) / span)
    }

    // first sample at or after a ride time
    function firstFrom(t) {
        var a = 0
        var b = Math.min(seconds.length, values.length)
        while (a < b) {
            var m = Math.floor((a + b) / 2)
            if (seconds[m] < t)
                a = m + 1
            else
                b = m
        }
        return a
    }

    // the sample closest to a ride time
    function indexAt(t) {
        var n = Math.min(seconds.length, values.length)
        if (n === 0)
            return -1
        var i = Math.min(n - 1, firstFrom(t))
        if (i > 0 && t - seconds[i - 1] < seconds[i] - t)
            i--
        return i
    }

    function fractionAt(x) {
        if (!view)
            return 0
        return Math.max(0, Math.min(1, view.viewStart + x / Math.max(1, plot.width) * view.span))
    }

    function xOfFraction(f) {
        return (f - view.viewStart) / view.span * plot.width
    }

    function scrub(x) {
        if (view)
            view.cursor = fractionAt(x)
    }

    function schedule() {
        Qt.callLater(chart.rebuild)
    }

    function rebuild() {
        var w = plot.width
        var h = plot.height
        var n = Math.min(seconds.length, values.length)
        var zones = [[], [], [], [], [], [], []]
        if (!view || w < 2 || h < 2 || n < 2) {
            drawn = { line: [], area: [], zones: zones, areas: ["", "", "", "", "", "", ""], over: [] }
            return
        }
        var total = Math.max(1, view.duration)
        var vs = view.viewStart
        var span = view.span
        // one sample past each edge, so the line reaches the sides
        var i0 = Math.max(0, firstFrom(Math.max(0, vs) * total) - 1)
        var i1 = Math.min(n - 1, firstFrom(Math.min(1, view.viewEnd) * total))
        var count = i1 - i0 + 1
        var buckets = Math.max(1, Math.floor(w))
        var per = count / buckets
        var zoned = zoneColored && ftp > 0
        var line = []
        var over = []
        var hasOverlay = overlay.length >= n
        var run = null
        var runZone = -1

        // the overlay averaged over the same samples as a bucket of the line
        function overlayPoint(from, to) {
            var sum = 0
            var used = 0
            for (var k = from; k < to; k++) {
                if (overlay[k] > 0) {
                    sum += overlay[k]
                    used++
                }
            }
            if (used > 0)
                over.push(Qt.point(((seconds[from] + seconds[to - 1]) / 2 / total - vs) / span * w, yOfOverlay(sum / used)))
        }

        function emit(points, value) {
            for (var p = 0; p < points.length; p++)
                line.push(points[p])
            if (!zoned)
                return
            var zone = Theme.powerZone(value, ftp)
            if (zone !== runZone) {
                // a new piece starts where the last one ended, so the line has no gaps
                run = run && run.length > 0 ? [run[run.length - 1]] : []
                zones[zone - 1].push(run)
                runZone = zone
            }
            for (var q = 0; q < points.length; q++)
                run.push(points[q])
        }

        function point(i) {
            return Qt.point((seconds[i] / total - vs) / span * w, yOf(values[i]))
        }

        if (per <= 2) {
            for (var i = i0; i <= i1; i++) {
                if (hasOverlay)
                    overlayPoint(i, i + 1)
                if (fromLowest && values[i] <= 0)
                    continue
                emit([point(i)], values[i])
            }
        } else {
            // a long window reads the blocks, a short one the samples
            var coarse = per >= blockSize
            for (var b = 0; b < buckets; b++) {
                var from = i0 + Math.floor(b * per)
                var to = Math.min(i1 + 1, i0 + Math.floor((b + 1) * per))
                var lo = -1
                var hi = -1
                var sum = 0
                var used = 0
                if (coarse) {
                    for (var c = Math.floor(from / blockSize); c < Math.floor(to / blockSize); c++) {
                        if (blocks.used[c] === 0)
                            continue
                        if (lo < 0 || values[blocks.lo[c]] < values[lo])
                            lo = blocks.lo[c]
                        if (hi < 0 || values[blocks.hi[c]] > values[hi])
                            hi = blocks.hi[c]
                        sum += blocks.sum[c]
                        used += blocks.used[c]
                    }
                } else {
                    for (var k = from; k < to; k++) {
                        var v = values[k]
                        if (fromLowest && v <= 0)
                            continue
                        if (lo < 0 || v < values[lo])
                            lo = k
                        if (hi < 0 || v > values[hi])
                            hi = k
                        sum += v
                        used++
                    }
                }
                if (hasOverlay && to > from)
                    overlayPoint(from, to)
                if (used === 0)
                    continue
                // lowest and highest in the order they happened; the filled look takes the
                // average, so the areas read smooth
                var pts = lo === hi ? [point(lo)] : (lo < hi ? [point(lo), point(hi)] : [point(hi), point(lo)])
                var zoneValue = sum / used
                if (filled) {
                    pts = [Qt.point(((seconds[from] + seconds[to - 1]) / 2 / total - vs) / span * w, yOf(sum / used))]
                    // the zone of the half minute around the bucket, so short wobbles across a
                    // zone line do not cut the area into slivers
                    var aroundFrom = Math.max(0, from - 15)
                    var aroundTo = Math.min(n, to + 15)
                    var around = 0
                    for (var c2 = aroundFrom; c2 < aroundTo; c2++)
                        around += values[c2]
                    zoneValue = around / Math.max(1, aroundTo - aroundFrom)
                }
                emit(pts, zoneValue)
            }
        }

        var area = line.slice()
        if (line.length > 1) {
            area.push(Qt.point(line[line.length - 1].x, h))
            area.push(Qt.point(line[0].x, h))
        }
        // each zone piece closed down to the bottom, for the filled look: one SVG path per zone
        // (a ShapePath fills every closed piece of it)
        var areas = ["", "", "", "", "", "", ""]
        if (zoned && filled) {
            for (var zi = 0; zi < 7; zi++) {
                var svg = ""
                for (var r = 0; r < zones[zi].length; r++) {
                    var piece = zones[zi][r]
                    if (piece.length < 2)
                        continue
                    svg += "M" + piece[0].x.toFixed(1) + " " + h.toFixed(1)
                    for (var q = 0; q < piece.length; q++)
                        svg += "L" + piece[q].x.toFixed(1) + " " + piece[q].y.toFixed(1)
                    svg += "L" + piece[piece.length - 1].x.toFixed(1) + " " + h.toFixed(1) + "Z"
                }
                areas[zi] = svg
            }
        }
        drawn = { line: line, area: area, zones: zones, areas: areas, over: over }
    }

    onSecondsChanged: schedule()
    onValuesChanged: schedule()
    onZoneColoredChanged: schedule()
    onFtpChanged: schedule()
    onFactorChanged: schedule()
    onOverlayChanged: schedule()
    onFilledChanged: schedule()
    onViewChanged: schedule()
    Connections {
        target: chart.view
        function onViewStartChanged() { chart.schedule() }
        function onViewEndChanged() { chart.schedule() }
        function onDurationChanged() { chart.schedule() }
    }

    // the name on the left and the top of the scale on the right, above the line
    Text {
        y: 2
        visible: chart.overlayName === ""
        width: parent.width - topLabel.implicitWidth - 12
        text: chart.name
        color: Theme.text2
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.fs(11)
        elide: Text.ElideRight
    }
    // the overlay's legend in place of the name
    Row {
        visible: chart.overlayName !== ""
        y: 2
        spacing: 6
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 1.4
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.7)
        }
        Text {
            text: chart.overlayName
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(12)
        }
    }
    // the band's label at the top right: what it is, then its value in its color
    Column {
        visible: chart.bandLabel !== ""
        anchors.right: parent.right
        y: 0
        spacing: 2
        Text {
            anchors.right: parent.right
            text: chart.bandLabel
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(12)
        }
        Text {
            anchors.right: parent.right
            text: chart.bandValue
            color: chart.bandColor
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(14)
        }
    }
    Text {
        id: topLabel
        visible: chart.bandLabel === ""
        anchors.right: parent.right
        y: 2
        text: chart.scaleTop + (chart.unit !== "" ? " " + chart.unit : "")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.fs(11)
    }

    Item {
        id: plot
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: chart.topStrip }

        onWidthChanged: chart.schedule()
        onHeightChanged: chart.schedule()

        // faint grid at the top, middle and bottom of the scale
        Repeater {
            model: 3
            Rectangle {
                width: plot.width
                height: 1
                y: Math.min(plot.height - 1, Math.round(index * plot.height / 2))
                color: Theme.hairline
            }
        }

        // the band of the best stretch, under the ink, with a line in its color above it
        Item {
            id: band
            readonly property bool shown: chart.view !== null && chart.bandStart >= 0 && chart.bandEnd > chart.bandStart
            readonly property real x0: shown ? chart.xOfFraction(chart.bandStart / Math.max(1, chart.view.duration)) : 0
            readonly property real x1: shown ? chart.xOfFraction(chart.bandEnd / Math.max(1, chart.view.duration)) : 0
            visible: shown && x1 > 0 && x0 < plot.width
            x: Math.max(0, x0)
            width: Math.max(1, Math.min(plot.width, x1) - x)
            height: plot.height
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.045)
            }
            Rectangle {
                y: -5
                width: parent.width
                height: 2
                radius: 1
                color: chart.bandColor
            }
        }

        // the top of the scale on its grid line, when the band label has the top right
        Text {
            visible: chart.bandLabel !== ""
            z: 2
            x: 0
            y: 3
            text: chart.scaleTop + (chart.unit !== "" ? " " + chart.unit : "")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(11)
        }

        // lap starts
        Repeater {
            model: chart.view ? chart.laps : []
            Rectangle {
                id: lapLine
                readonly property real lapX: chart.xOfFraction(modelData / Math.max(1, chart.view.duration))
                visible: modelData > 0 && lapX > 0 && lapX < plot.width
                x: Math.round(lapX)
                width: 1
                height: plot.height
                color: Qt.rgba(1, 1, 1, 0.13)
            }
        }

        // where the parts of a merged ride join: faint dashed lines, apart from the solid laps
        Repeater {
            model: chart.view ? chart.parts : []
            Shape {
                readonly property real partX: chart.xOfFraction(modelData / Math.max(1, chart.view.duration))
                visible: modelData > 0 && partX > 0 && partX < plot.width
                x: Math.round(partX)
                width: 1
                height: plot.height
                ShapePath {
                    strokeColor: Theme.text3
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: "transparent"
                    startX: 0.5
                    startY: 0
                    PathLine { x: 0.5; y: plot.height }
                }
            }
        }

        Item {
            id: ink
            width: parent.width * Math.max(0, Math.min(1, chart.reveal))
            height: parent.height
            clip: true
            layer.enabled: true
            layer.samples: 4

            Shape {
                width: plot.width
                height: plot.height
                visible: !chart.filled
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: plot.height
                        GradientStop { position: 0; color: Qt.rgba(chart.color.r, chart.color.g, chart.color.b, 0.28) }
                        GradientStop { position: 1; color: Qt.rgba(chart.color.r, chart.color.g, chart.color.b, 0.02) }
                    }
                    PathPolyline { path: chart.drawn.area }
                }
            }
            Shape {
                width: plot.width
                height: plot.height
                visible: !(chart.zoneColored && chart.ftp > 0)
                ShapePath {
                    strokeColor: chart.color
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: chart.drawn.line }
                }
            }
            // one piece per power zone
            Repeater {
                model: chart.zoneColored && chart.ftp > 0 ? 7 : 0
                Shape {
                    id: zoneShape
                    width: plot.width
                    height: plot.height
                    ShapePath {
                        strokeWidth: -1
                        // the zone color at about 42%, as #aarrggbb
                        fillColor: chart.filled ? "#6b" + String(Theme.zoneColors[index]).substring(1) : "transparent"
                        PathSvg { path: chart.filled && chart.drawn.areas[index] !== "" ? chart.drawn.areas[index] : "M0 0Z" }
                    }
                    ShapePath {
                        strokeColor: Theme.zoneColors[index]
                        strokeWidth: chart.filled ? 1.2 : 1.6
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        capStyle: ShapePath.RoundCap
                        PathMultiline { paths: chart.drawn.zones[index] }
                    }
                }
            }
            // the overlay, a thin light line
            Shape {
                width: plot.width
                height: plot.height
                visible: chart.drawn.over.length > 1
                ShapePath {
                    strokeColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.7)
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: chart.drawn.over }
                }
            }
        }

        Rectangle {
            visible: chart.showAverage && chart.shownAverage > 0 && chart.drawn.line.length > 1
            width: plot.width
            height: 1
            y: Math.round(chart.yOf(chart.shownAverage))
            color: Qt.rgba(1, 1, 1, 0.3)
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

        // the crosshair
        Item {
            id: crosshair
            readonly property real cx: chart.view && chart.view.cursor >= 0 ? chart.xOfFraction(chart.view.cursor) : -1
            readonly property int at: chart.view && chart.view.cursor >= 0 ? chart.indexAt(chart.view.cursor * chart.view.duration) : -1
            readonly property real value: at >= 0 ? chart.values[at] : 0
            readonly property bool gap: chart.fromLowest && value <= 0
            visible: at >= 0 && cx >= 0 && cx <= plot.width
            anchors.fill: parent

            Rectangle {
                x: Math.round(crosshair.cx)
                width: 1
                height: plot.height
                color: Qt.rgba(1, 1, 1, 0.6)
            }
            Rectangle {
                visible: !crosshair.gap
                x: crosshair.cx - width / 2
                y: chart.yOf(crosshair.value) - height / 2
                width: 9
                height: 9
                radius: 4.5
                color: chart.zoneColored && chart.ftp > 0 ? Theme.zoneColors[Theme.powerZone(crosshair.value, chart.ftp) - 1] : chart.color
                border.width: 2
                border.color: Theme.card
            }
        }
    }

    // the value at the crosshair, in the strip above the line and always inside the chart
    Rectangle {
        visible: crosshair.visible
        x: Math.max(0, Math.min(chart.width - width, crosshair.cx - width / 2))
        y: 0
        width: bubbleText.implicitWidth + 14
        height: 20
        radius: 10
        color: Theme.chip
        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: {
                var main = crosshair.gap ? "-" : chart.valueText(crosshair.value)
                if (chart.overlay.length === 0 || crosshair.at < 0)
                    return main
                var o = chart.overlay[crosshair.at] || 0
                return chart.view.clock(chart.seconds[crosshair.at] || 0) + "   " + main
                       + (o > 0 ? "   " + chart.overlayShort + " " + Math.round(o) : "")
            }
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(11)
        }
    }

    PinchArea {
        id: pinchArea
        anchors.fill: parent
        Accessible.ignored: true

        onPinchUpdated: {
            if (!chart.view)
                return
            chart.view.pan(-(pinch.center.x - pinch.previousCenter.x) / Math.max(1, plot.width) * chart.view.span)
            chart.view.zoomAt(chart.fractionAt(pinch.center.x), pinch.scale / Math.max(0.01, pinch.previousScale))
        }

        MouseArea {
            id: touch
            anchors.fill: parent
            pressAndHoldInterval: 350

            property string mode: ""    // "scrub" or "pan" once this touch is the chart's
            property real pressX: 0
            property real pressY: 0
            property real lastX: 0

            // the page keeps the touch until it is clearly sideways or held
            function take(next) {
                mode = next
                preventStealing = true
            }

            onPressed: {
                mode = ""
                pressX = mouse.x
                pressY = mouse.y
                lastX = mouse.x
            }
            onPressAndHold: {
                // a slow scroll is not a hold
                if (Math.abs(mouse.y - pressY) > 10)
                    return
                take("scrub")
                chart.scrub(mouse.x)
            }
            onPositionChanged: {
                if (!chart.view)
                    return
                if (mode === "") {
                    var dx = Math.abs(mouse.x - pressX)
                    var dy = Math.abs(mouse.y - pressY)
                    if (dx > 6 && dx > 2 * dy)
                        take(chart.view.zoomed ? "pan" : "scrub")
                }
                if (mode === "scrub")
                    chart.scrub(mouse.x)
                else if (mode === "pan")
                    chart.view.pan(-(mouse.x - lastX) / Math.max(1, plot.width) * chart.view.span)
                lastX = mouse.x
            }
            onReleased: preventStealing = false
            onCanceled: {
                preventStealing = false
                mode = ""
            }
            onClicked: {
                if (mode !== "" || !chart.view)
                    return
                if (chart.view.cursor >= 0)
                    chart.view.cursor = -1
                else if (chart.learnable)
                    learnLater.restart()
                else
                    chart.view.cursor = chart.fractionAt(mouse.x)
            }
            onDoubleClicked: {
                learnLater.stop()
                if (chart.view)
                    chart.view.reset()
            }

            // the pressed state of a chart that is a button: gone as soon as the touch scrubs
            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.05)
                opacity: chart.learnable && touch.pressed && touch.mode === "" ? 1 : 0
                Behavior on opacity {
                    enabled: !Theme.reduceMotion
                    NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                }
            }
            // ctrl and the wheel zoom on a desktop; the plain wheel still scrolls the page
            onWheel: {
                if (chart.view && (wheel.modifiers & Qt.ControlModifier)) {
                    chart.view.zoomAt(chart.fractionAt(wheel.x), Math.pow(1.002, wheel.angleDelta.y))
                    return
                }
                wheel.accepted = false
            }
        }
    }
}
