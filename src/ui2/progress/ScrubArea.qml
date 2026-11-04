import QtQuick 2.15
import ".."

// The touch of a chart on a scrolling page, as in charts/TimeChart.qml: a sideways drag, or press
// and hold then drag, moves the crosshair; a tap is the chart's to use (hide the crosshair, or
// open the Learn sheet). Vertical drags are left to the page, so it still scrolls over the chart.
// With `learnable` the chart shows it is a button while a finger rests on it without scrubbing.
MouseArea {
    id: touch

    signal scrub(real at)
    signal tap(real at)

    property bool scrubbing: false
    property real pressX: 0
    property real pressY: 0
    property bool learnable: false

    Accessible.ignored: true
    pressAndHoldInterval: 350

    // the page keeps the touch until it is clearly sideways or held
    function take() {
        scrubbing = true
        preventStealing = true
    }

    onPressed: {
        scrubbing = false
        pressX = mouse.x
        pressY = mouse.y
    }
    onPressAndHold: {
        // a slow scroll is not a hold
        if (Math.abs(mouse.y - pressY) > 10)
            return
        take()
        touch.scrub(mouse.x)
    }
    onPositionChanged: {
        if (!scrubbing) {
            var dx = Math.abs(mouse.x - pressX)
            var dy = Math.abs(mouse.y - pressY)
            if (dx > 6 && dx > 2 * dy)
                take()
        }
        if (scrubbing)
            touch.scrub(mouse.x)
    }
    onReleased: preventStealing = false
    onCanceled: {
        preventStealing = false
        scrubbing = false
    }
    onClicked: {
        if (!scrubbing)
            touch.tap(mouse.x)
    }

    // the pressed state of a chart that is a button: gone as soon as the touch scrubs
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 18
        color: Theme.overlay(0.05)
        opacity: touch.learnable && touch.pressed && !touch.scrubbing ? 1 : 0
        Behavior on opacity {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        }
    }
}
