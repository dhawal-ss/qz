import QtQuick 2.15
import QtQuick.Shapes 1.15

// Stroke icons of the You section, drawn on a 24 x 24 grid like ../Icon.qml.
Item {
    id: icon

    property string name: "info"
    property color color: Theme.light ? Theme.text : "white"
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
        search: "M4 11A7 7 0 1 0 18 11A7 7 0 1 0 4 11ZM16 16L20.5 20.5",
        bolt: "M13 3L5 14L12 14L11 21L19 10L12 10Z",
        lock: "M8 11L8 7.5A4 4 0 0 1 16 7.5L16 11M8 11L16 11Q19 11 19 14L19 18Q19 21 16 21L8 21Q5 21 5 18L5 14Q5 11 8 11Z",
        shield: "M12 3L19.5 6L19.5 11.5C19.5 16 16.4 19.7 12 21C7.6 19.7 4.5 16 4.5 11.5L4.5 6ZM9 12L11.2 14.2L15.5 10",
        band: "M12 5A4 4 0 0 1 16 9L16 15A4 4 0 0 1 8 15L8 9A4 4 0 0 1 12 5ZM10 5.5L10 2.5M14 5.5L14 2.5M10 18.5L10 21.5M14 18.5L14 21.5",
        watch: "M6 12A6 6 0 1 0 18 12A6 6 0 1 0 6 12ZM9 6.8L10 2.5L14 2.5L15 6.8M9 17.2L10 21.5L14 21.5L15 17.2",
        strap: "M2 9.5Q12 16.5 22 9.5M8.5 8.5L15.5 8.5Q17 8.5 17 10L17 13.5Q17 15 15.5 15L8.5 15Q7 15 7 13.5L7 10Q7 8.5 8.5 8.5Z",
        none: "M4 12A8 8 0 1 0 20 12A8 8 0 1 0 4 12ZM6.5 17.5L17.5 6.5",
        signal: "M3 12L7 12L9.5 6L13.5 18L16 12L21 12"
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
