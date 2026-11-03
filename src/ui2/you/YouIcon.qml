import QtQuick 2.15
import QtQuick.Shapes 1.15

// Stroke icons of the You section, drawn on a 24 x 24 grid like ../Icon.qml.
Item {
    id: icon

    property string name: "info"
    property color color: "white"
    property real size: 24
    property real weight: 2.0

    width: size
    height: size
    Accessible.ignored: true

    readonly property var paths: ({
        bike: "M2 17A3.5 3.5 0 1 0 9 17A3.5 3.5 0 1 0 2 17ZM15 17A3.5 3.5 0 1 0 22 17A3.5 3.5 0 1 0 15 17ZM5.5 17L9 9L15.5 9L18.5 17M9 9L12 17L15.5 9M7.5 6L10.5 6M15.5 9L14.5 6L17 6",
        heart: "M12 20C5 15 3 12 3 8.5A4.5 4.5 0 0 1 12 6A4.5 4.5 0 0 1 21 8.5C21 12 19 15 12 20Z",
        body: "M8 7A4 4 0 1 0 16 7A4 4 0 1 0 8 7ZM4 21C4 16.5 7.5 14 12 14C16.5 14 20 16.5 20 21",
        zones: "M5 20L5 15M10 20L10 11M15 20L15 7.5M20 20L20 4",
        units: "M4 7L20 7M4 17L20 17M9 4L9 10M15 14L15 20",
        link: "M10 14L14 10M8.5 11.5L6.5 13.5A3.5 3.5 0 0 0 11.5 18.5L13.5 16.5M10.5 7.5L12.5 5.5A3.5 3.5 0 0 1 17.5 10.5L15.5 12.5",
        data: "M3 7Q3 5 5 5L9.5 5L11.5 7.5L19 7.5Q21 7.5 21 9.5L21 17Q21 19 19 19L5 19Q3 19 3 17Z",
        info: "M3 12A9 9 0 1 0 21 12A9 9 0 1 0 3 12ZM12 11L12 16.5M12 7.5L12 7.6",
        next: "M10 6L16 12L10 18",
        back: "M15 5L8 12L15 19",
        check: "M5 12.5L10 17.5L19 7",
        open: "M14 4L20 4L20 10M20 4L11 13M18 14L18 18Q18 20 16 20L6 20Q4 20 4 18L4 8Q4 6 6 6L10 6",
        search: "M4 11A7 7 0 1 0 18 11A7 7 0 1 0 4 11ZM16 16L20.5 20.5"
    })

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: icon.color
            strokeWidth: icon.weight * 24 / icon.size
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.paths[icon.name] || "" }
        }
    }
}
