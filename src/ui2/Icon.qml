import QtQuick 2.15
import QtQuick.Shapes 1.15

// Stroke icons drawn on a 24 x 24 grid, 1.8 to 2.6 wide with round caps.
Item {
    id: icon

    property string name: "plus"
    property color color: "white"
    property real size: 24
    property real weight: size >= 24 ? 2.6 : 2.0

    width: size
    height: size
    Accessible.ignored: true

    readonly property var paths: ({
        plus: "M12 5L12 19M5 12L19 12",
        minus: "M5 12L19 12",
        chevron: "M7 10L12 15L17 10",
        lock: "M8 11L8 7A4 4 0 0 1 16 7L16 11M7 11L17 11Q19 11 19 13L19 19Q19 21 17 21L7 21Q5 21 5 19L5 13Q5 11 7 11Z",
        unlock: "M8 11L8 7A4 4 0 0 1 15.5 5M7 11L17 11Q19 11 19 13L19 19Q19 21 17 21L7 21Q5 21 5 19L5 13Q5 11 7 11Z",
        close: "M6 6L18 18M18 6L6 18",
        back: "M15 5L8 12L15 19",
        heart: "M12 20C5 15 3 12 3 8.5A4.5 4.5 0 0 1 12 6A4.5 4.5 0 0 1 21 8.5C21 12 19 15 12 20Z",
        bolt: "M13 3L5 14L12 14L11 21L19 10L12 10Z"
    })
    readonly property bool solid: name === "play" || name === "pause"

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: icon.solid ? "transparent" : icon.color
            strokeWidth: icon.solid ? -1 : icon.weight * 24 / icon.size
            fillColor: icon.solid ? icon.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: icon.name === "pause" ? "M6 5L10 5L10 19L6 19ZM14 5L18 5L18 19L14 19Z"
                      : (icon.name === "play" ? "M7 4L20 12L7 20Z" : (icon.paths[icon.name] || ""))
            }
        }
    }
}
