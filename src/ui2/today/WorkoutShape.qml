import QtQuick 2.15
import ".."

// The shape of a ride as blocks on a line: each block as wide as its minutes and as tall as its
// zone, in the color of the zone. A new shape grows up from the line on the default spring.
Item {
    id: shape

    property var blocks: []          // [[minutes, zone]]
    property string summary: ""      // for the screen reader
    // the minutes ridden of a workout under way, marked on the shape; the blocks behind fade (-1: none)
    property real doneMinutes: -1
    readonly property var heights: [0.22, 0.33, 0.5, 0.7, 0.93, 1, 1]
    readonly property real gap: 4
    readonly property real total: {
        var sum = 0
        for (var i = 0; i < blocks.length; i++)
            sum += blocks[i][0]
        return Math.max(1, sum)
    }
    // the width left for the minutes once every block has its gap and the shortest their least
    readonly property real spread: Math.max(0, width - gap * Math.max(0, blocks.length - 1) - 6 * blocks.length)
    property real grown: 1

    implicitHeight: 54
    Accessible.role: Accessible.Graphic
    Accessible.name: summary

    onBlocksChanged: {
        if (Theme.reduceMotion)
            return
        growAnimation.restart()
    }
    NumberAnimation {
        id: growAnimation
        target: shape
        property: "grown"
        from: 0
        to: 1
        duration: Theme.defaultSpatialTime
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.defaultSpatialCurve
    }

    function widthOf(minutes) {
        return 6 + shape.spread * minutes / shape.total
    }
    function startOf(index) {
        var m = 0
        for (var i = 0; i < index; i++)
            m += blocks[i][0]
        return m
    }
    // where on the shape a number of minutes is
    function xAt(minutes) {
        var x = 0
        var left = minutes
        for (var i = 0; i < blocks.length; i++) {
            var w = widthOf(blocks[i][0])
            if (left <= blocks[i][0])
                return x + w * Math.max(0, left) / Math.max(0.001, blocks[i][0])
            x += w + gap
            left -= blocks[i][0]
        }
        return width
    }

    Row {
        spacing: shape.gap
        height: shape.height
        Repeater {
            model: shape.blocks
            Item {
                width: shape.widthOf(modelData[0])
                height: shape.height
                opacity: shape.doneMinutes >= 0 && shape.startOf(index) + modelData[0] <= shape.doneMinutes ? 0.35 : 1
                Rectangle {
                    readonly property real full: Math.max(8, shape.height * shape.heights[Math.max(1, modelData[1]) - 1])
                    width: parent.width
                    height: Math.max(4, full * shape.grown)
                    y: parent.height - height
                    radius: Math.min(6, width / 2, full / 3)
                    color: Theme.zoneColors[Math.max(1, modelData[1]) - 1]
                }
            }
        }
    }

    // now
    Rectangle {
        visible: shape.doneMinutes >= 0
        x: Math.min(shape.width - width, Math.max(0, shape.xAt(shape.doneMinutes) - 1))
        y: -4
        width: 3
        height: shape.height + 8
        radius: 1.5
        color: Theme.text
    }
}
