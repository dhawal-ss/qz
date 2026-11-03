import QtQuick 2.15
import ".."

// The window of the ride that a stack of charts shows, and the crosshair they share. Every
// position is a fraction of the ride: 0 is the start, 1 the end. Pinching and panning move the
// window directly, under the finger; a reset springs back to the whole ride.
QtObject {
    id: view

    property real duration: 1       // ride seconds, for the shortest window
    property real viewStart: 0
    property real viewEnd: 1
    property real cursor: -1        // the crosshair, -1 when hidden

    // about a minute of the ride is the closest the charts zoom in
    readonly property real minSpan: Math.min(1, 60 / Math.max(1, duration))
    readonly property real span: Math.max(0.0001, viewEnd - viewStart)
    readonly property bool zoomed: viewStart > 0.0005 || viewEnd < 0.9995

    // zoom in (factor above 1) or out around a fraction of the ride, keeping it under the finger
    function zoomAt(fraction, factor) {
        springBack.stop()
        var start = Math.max(0, viewStart)
        var width = Math.min(1, viewEnd) - start
        var next = Math.max(minSpan, Math.min(1, width / Math.max(0.01, factor)))
        var at = (fraction - start) / Math.max(0.0001, width)
        place(fraction - at * next, next)
    }

    function pan(deltaFraction) {
        springBack.stop()
        var start = Math.max(0, viewStart)
        place(start + deltaFraction, Math.min(1, viewEnd) - start)
    }

    // the whole ride again, with the crosshair hidden; instant when asked or with reduced motion
    function reset(instant) {
        cursor = -1
        springBack.stop()
        if (instant || Theme.reduceMotion) {
            viewStart = 0
            viewEnd = 1
            return
        }
        springBack.start()
    }

    // a window of this width starting here, kept inside the ride
    function place(start, width) {
        var s = Math.max(0, Math.min(1 - width, start))
        viewStart = s
        viewEnd = s + width
    }

    // a ride time on the clock: 4:05 under an hour, 1:04:05 above
    function clock(seconds) {
        var s = Math.max(0, Math.round(seconds))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var r = s % 60
        var tail = (r < 10 ? ":0" : ":") + r
        if (h > 0)
            return h + (m < 10 ? ":0" : ":") + m + tail
        return m + tail
    }

    property ParallelAnimation springBack: ParallelAnimation {
        NumberAnimation {
            target: view
            property: "viewStart"
            to: 0
            duration: Theme.medium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.springCurve
        }
        NumberAnimation {
            target: view
            property: "viewEnd"
            to: 1
            duration: Theme.medium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.springCurve
        }
    }
}
