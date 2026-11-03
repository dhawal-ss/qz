import QtQuick 2.15
import ".."

// A chart that draws in from the left: what is inside is wiped in on the slow spatial curve each
// time play() is called (the period changed, the page showed). Instant with Theme.reduceMotion.
// The children take the full width; only the visible part grows.
Item {
    id: drawIn

    default property alias content: inner.data
    // 0 to 1, a little over while the curve overshoots
    property real reveal: 1

    function play() {
        if (Theme.reduceMotion) {
            wipe.stop()
            reveal = 1
            return
        }
        wipe.restart()
    }

    Item {
        id: window
        width: Math.max(0, Math.min(1, drawIn.reveal)) * drawIn.width
        height: drawIn.height
        clip: drawIn.reveal < 1
        Item {
            id: inner
            width: drawIn.width
            height: drawIn.height
        }
    }

    SequentialAnimation {
        id: wipe
        PropertyAction { target: drawIn; property: "reveal"; value: 0 }
        NumberAnimation {
            target: drawIn
            property: "reveal"
            to: 1
            duration: Theme.slowSpatialTime
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.slowSpatialCurve
        }
    }
}
