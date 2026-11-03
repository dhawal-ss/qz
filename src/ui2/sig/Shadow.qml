import QtQuick 2.15
import ".."

// A soft shadow under a floating surface, from a few faint rounded layers that grow wider and
// fainter (about a 12 px offset with a 32 px blur, as on the boards). Put it under the surface,
// the same size: Shadow { anchors.fill: surface; radius: surface.radius }
Item {
    id: shadow

    property real radius: 32
    property real offset: 10
    property real strength: 0.5

    Accessible.ignored: true

    Repeater {
        model: [{ grow: 2, alpha: 0.30 }, { grow: 6, alpha: 0.16 }, { grow: 11, alpha: 0.09 }, { grow: 18, alpha: 0.05 }]
        Rectangle {
            x: -modelData.grow
            y: shadow.offset * (0.4 + modelData.grow / 30) - modelData.grow
            width: shadow.width + modelData.grow * 2
            height: shadow.height + modelData.grow * 2
            radius: shadow.radius + modelData.grow
            color: Qt.rgba(0, 0, 0, modelData.alpha * shadow.strength * 2)
        }
    }
}
