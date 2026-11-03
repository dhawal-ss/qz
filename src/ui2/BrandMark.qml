import QtQuick 2.15
import QtQuick.Shapes 1.15
import "."

// The Bikemodo mark: a rider leaning low over a bike, on the 108 box of the app icon.
// Small sizes leave out the frame and use thicker lines, like the launcher icon.
Item {
    id: mark

    property color color: Theme.accent
    property bool detailed: Math.min(width, height) >= 96

    implicitWidth: 40
    implicitHeight: 40
    Accessible.ignored: true

    Shape {
        width: 108
        height: 108
        anchors.centerIn: parent
        scale: Math.min(mark.width, mark.height) / 108
        layer.enabled: true
        layer.samples: 4

        // the frame, only when there is room for it
        ShapePath {
            strokeColor: mark.detailed ? Qt.rgba(mark.color.r, mark.color.g, mark.color.b, 0.55) : "transparent"
            strokeWidth: 4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M28 78 L46 52 H70 L80 78 M46 52 L56 78 H28 M56 78 L70 52" }
        }
        // the wheels
        ShapePath {
            strokeColor: mark.color
            strokeWidth: mark.detailed ? 5.5 : 8
            fillColor: "transparent"
            PathSvg { path: "M13 78 A15 15 0 1 0 43 78 A15 15 0 1 0 13 78 M65 78 A15 15 0 1 0 95 78 A15 15 0 1 0 65 78" }
        }
        // the rider: back, arm to the bars, leg to the pedal
        ShapePath {
            strokeColor: mark.color
            strokeWidth: mark.detailed ? 6.5 : 9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M46 44 Q58 28 68 34 L74 52 M46 44 L64 60 L56 78" }
        }
        // the head
        ShapePath {
            strokeWidth: -1
            fillColor: mark.color
            PathSvg { path: mark.detailed ? "M68.5 26 A7.5 7.5 0 1 0 83.5 26 A7.5 7.5 0 1 0 68.5 26"
                                          : "M67 26 A9 9 0 1 0 85 26 A9 9 0 1 0 67 26" }
        }
    }
}
