import QtQuick 2.15
import ".."

// The ride clock under a stack of charts, for the window their ChartView shows. Ticks sit on
// round times (30 s, 5 min, 15 min...), so they slide along while the charts pan.
Item {
    id: axis

    property ChartView view: null

    implicitHeight: 16
    Accessible.ignored: true

    // 3 ticks on a phone, up to 5 on a wide window
    readonly property int wanted: width < 360 ? 3 : (width < 640 ? 4 : 5)

    readonly property var ticks: {
        if (!view || width <= 0)
            return []
        var total = Math.max(1, view.duration)
        var t0 = Math.max(0, view.viewStart) * total
        var t1 = Math.min(1, view.viewEnd) * total
        var steps = [10, 15, 20, 30, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600, 7200]
        var step = steps[steps.length - 1]
        for (var i = 0; i < steps.length; i++) {
            if ((t1 - t0) / steps[i] <= wanted) {
                step = steps[i]
                break
            }
        }
        var out = []
        for (var t = Math.ceil(t0 / step) * step; t <= t1; t += step)
            out.push(t)
        return out
    }

    Repeater {
        // a count, so panning moves the labels instead of rebuilding them
        model: axis.ticks.length
        Text {
            id: tick
            readonly property real seconds: axis.ticks[index] || 0
            readonly property real at: (seconds / Math.max(1, axis.view.duration) - axis.view.viewStart) / axis.view.span * axis.width
            x: Math.max(0, Math.min(axis.width - width, at - width / 2))
            text: axis.view.clock(seconds)
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: 11
        }
    }
}
