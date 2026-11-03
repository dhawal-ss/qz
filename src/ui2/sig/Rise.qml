import QtQuick 2.15
import ".."

// The entrance of a page, one block at a time: what is inside rises 10 px and fades in on the
// spring curve, 80 ms after the block before it (order 0, 1, 2...). It plays when it is made and
// again each time `cue` emits entered(), e.g. a page that tells when it shows:
//   Rise { cue: myPage; order: 2; width: parent.width; MyBlock { width: parent.width } }
// The block takes the height of what is inside it; a block of height 0 is skipped by a Column.
Item {
    id: rise

    default property alias content: holder.data
    property var cue: null
    property int order: 0
    // 0 to 1 (and a little over, the curve overshoots)
    property real progress: 1

    implicitHeight: holder.childrenRect.height
    implicitWidth: holder.childrenRect.width

    function play() {
        if (Theme.reduceMotion) {
            riseAnimation.stop()
            progress = 1
            return
        }
        riseAnimation.restart()
    }

    Item {
        id: holder
        width: rise.width
        height: rise.height
        opacity: Math.max(0, Math.min(1, rise.progress))
        y: (1 - rise.progress) * Theme.riseDistance
    }

    SequentialAnimation {
        id: riseAnimation
        PropertyAction { target: rise; property: "progress"; value: 0 }
        PauseAnimation { duration: Math.max(0, rise.order) * Theme.riseStagger }
        NumberAnimation {
            target: rise
            property: "progress"
            to: 1
            duration: Theme.riseTime
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.defaultSpatialCurve
        }
    }

    Component.onCompleted: play()
    Connections {
        target: rise.cue
        ignoreUnknownSignals: true
        function onEntered() { rise.play() }
    }
}
