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
        bolt: "M13 3L5 14L12 14L11 21L19 10L12 10Z",
        today: "M4 11L12 4L20 11M6 9.5L6 19Q6 20 7 20L17 20Q18 20 18 19L18 9.5",
        rides: "M5 7L19 7M5 12L19 12M5 17L13 17",
        progress: "M4 5L4 19L20 19M8 15L12 10L15 13L20 7",
        goals: "M8 4L16 4L16 9A4 4 0 0 1 8 9ZM8 6L5 6Q5 10 8 10M16 6L19 6Q19 10 16 10M12 13L12 17M8 20L16 20M10 17L14 17",
        you: "M12 12A4 4 0 1 0 12 4A4 4 0 1 0 12 12ZM4.5 20C5.5 16.5 8.5 14.5 12 14.5C15.5 14.5 18.5 16.5 19.5 20",
        forward: "M9 5L16 12L9 19",
        calendar: "M5 6L19 6L19 20L5 20ZM5 10L19 10M9 3L9 7M15 3L15 7",
        flame: "M12 3C13 7 17 8.5 17 13.5A5 5 0 0 1 7 13.5C7 11 8.5 9.5 9.5 8.5C9.5 10.5 10.5 11.5 11.5 11.5C11.5 8 10.5 5.5 12 3Z"
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
