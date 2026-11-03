import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."

// The emblem of a badge: a Pulse in the badge's zone color, spikier for the bigger badges, with
// its glyph in the middle. A locked badge is a dark Pulse with a ring that fills as it gets close.
Item {
    id: emblem

    property var badge: ({})
    property real size: 64

    readonly property bool earned: badge.earned === true
    readonly property color tint: Theme.zoneColors[Math.max(1, Math.min(7, badge.tone || 1)) - 1]

    width: size
    height: size
    Accessible.ignored: true

    // a soft halo behind an earned badge
    Rectangle {
        visible: emblem.earned
        anchors.centerIn: parent
        width: emblem.size * 0.9
        height: width
        radius: width / 2
        color: Qt.rgba(emblem.tint.r, emblem.tint.g, emblem.tint.b, 0.16)
        scale: 1.12
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        Shape {
            width: 108
            height: 108
            scale: emblem.size / 108
            transformOrigin: Item.TopLeft
            ShapePath {
                strokeWidth: emblem.earned ? -1 : 3
                strokeColor: emblem.earned ? "transparent" : Theme.dashed
                fillColor: emblem.earned ? emblem.tint : Theme.chip
                PathSvg { path: Theme.pulsePath(emblem.badge.tier || 1) }
            }
            // how close a locked badge is, round the outside
            ShapePath {
                strokeWidth: emblem.earned || !(emblem.badge.progress > 0) ? 0 : 5
                strokeColor: emblem.earned || !(emblem.badge.progress > 0) ? "transparent" : emblem.tint
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 54
                    centerY: 54
                    radiusX: 51
                    radiusY: 51
                    startAngle: -90
                    sweepAngle: 360 * Math.min(1, emblem.badge.progress || 0)
                }
            }
        }
    }

    GoalGlyph {
        anchors.centerIn: parent
        size: Math.round(emblem.size * 0.38)
        weight: 2.4
        name: emblem.badge.glyph || "spark"
        color: emblem.earned ? Theme.bg : Theme.text3
    }
}
