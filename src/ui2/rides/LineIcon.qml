import QtQuick 2.15
import QtQuick.Shapes 1.15
import QtQuick.Window 2.15
import ".."

// The thin line icons of the ride analysis, on a 24 x 24 grid with 1.8 wide round lines, as the
// board draws them: heart, bolt, cadence (a clock face), clock, share, check, back.
Item {
    id: lineIcon

    property string name: "heart"
    property color color: Theme.text
    property real size: 18

    width: size
    height: size
    Accessible.ignored: true

    readonly property var paths: ({
        heart: "M12 20C12 20 5 15.6 5 10A4 4 0 0 1 12 7.4A4 4 0 0 1 19 10C19 15.6 12 20 12 20Z",
        bolt: "M13 3L5 14L12 14L11 21L19 10L12 10Z",
        cadence: "M12 4A8 8 0 1 0 12 20A8 8 0 1 0 12 4ZM12 8L12 12L15 14",
        clock: "M12 4A8 8 0 1 0 12 20A8 8 0 1 0 12 4ZM12 8L12 12L15 14",
        share: "M12 15L12 3M7 8L12 3L17 8M5 13L5 19A2 2 0 0 0 7 21L17 21A2 2 0 0 0 19 19L19 13",
        check: "M5 12L10 17L19 7",
        back: "M15 5L8 12L15 19"
    })

    Shape {
        width: 24
        height: 24
        scale: lineIcon.size / 24
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.ceil(lineIcon.size * Math.max(1, Screen.devicePixelRatio)),
                                   Math.ceil(lineIcon.size * Math.max(1, Screen.devicePixelRatio)))
        ShapePath {
            strokeColor: lineIcon.color
            strokeWidth: 1.8
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: lineIcon.paths[lineIcon.name] || "" }
        }
    }
}
