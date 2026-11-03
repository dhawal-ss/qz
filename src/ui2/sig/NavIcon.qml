import QtQuick 2.15
import QtQuick.Shapes 1.15
import QtQuick.Window 2.15
import ".."

// The icons of the floating navigation, drawn as on the Today board on a 24 x 24 grid with
// 1.8 wide round lines: Today is a small sun, Progress a rising line. Each has a line part and
// an optional filled part.
Item {
    id: navIcon

    property string name: "today"
    property color color: Theme.text2
    property real size: 22

    width: size
    height: size
    Accessible.ignored: true

    readonly property var lines: ({
        today: "M12 1.5L12 4.5M12 19.5L12 22.5M1.5 12L4.5 12M19.5 12L22.5 12",
        rides: "M5 7L19 7M5 12L19 12M5 17L13 17",
        progress: "M3 17L8 12L12 15L20 7M15 7L20 7L20 12",
        goals: "M8 4L16 4L16 9A4 4 0 0 1 8 9ZM8 6L5 6Q5 10 8 10M16 6L19 6Q19 10 16 10M12 13L12 17M8 20L16 20M10 17L14 17",
        you: "M12 12A4 4 0 1 0 12 4A4 4 0 1 0 12 12ZM4 21C5.5 17 8.5 15 12 15C15.5 15 18.5 17 20 21"
    })
    readonly property var fills: ({
        today: "M7 12A5 5 0 1 0 17 12A5 5 0 1 0 7 12Z"
    })

    Shape {
        width: 24
        height: 24
        scale: navIcon.size / 24
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.ceil(navIcon.size * Math.max(1, Screen.devicePixelRatio)),
                                   Math.ceil(navIcon.size * Math.max(1, Screen.devicePixelRatio)))

        ShapePath {
            strokeColor: navIcon.color
            strokeWidth: 1.8 * 24 / navIcon.size
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: navIcon.lines[navIcon.name] || "" }
        }
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: navIcon.fills[navIcon.name] ? navIcon.color : "transparent"
            PathSvg { path: navIcon.fills[navIcon.name] || "M0 0Z" }
        }
    }
}
