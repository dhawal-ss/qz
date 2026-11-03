import QtQuick 2.15
import QtQuick.Controls 2.15
import "."
import "sig"

// One destination of the floating navigation. The open destination expands into a filled pill
// in the accent with its icon and name; the others are an icon only. Across (the bottom bar) the
// pill grows wider, upright (the side rail) it grows taller with the name under the icon. The
// size springs on the fast spatial spring, the fill and the name fade on the effects curve.
AbstractButton {
    id: nav

    property string iconName: "today"
    property bool current: false
    property bool vertical: false
    // the size of an icon-only destination: its width across, its height upright
    property int slot: 52
    property int labelSize: 14
    // a long name (a translation) is cut short with an ellipsis past this
    property real maxLabelWidth: 1000
    readonly property int iconSize: 22
    readonly property real labelWidth: Math.min(Math.ceil(labelMetrics.advanceWidth), maxLabelWidth)
    // the room around the icon and the name of the open destination; tighter on a narrow phone
    property bool dense: false
    readonly property int startPad: dense ? 14 : 16
    readonly property int iconGap: dense ? 6 : 8
    readonly property int endPad: dense ? 16 : 20
    readonly property real expandedWidth: Math.ceil(startPad + iconSize + iconGap + labelWidth + endPad)

    implicitWidth: vertical ? 60 : (current ? expandedWidth : slot)
    implicitHeight: vertical ? (current ? 64 : slot) : 48
    padding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selectable: true
    Accessible.selected: current
    Accessible.onPressAction: nav.clicked()

    Behavior on implicitWidth {
        enabled: !Theme.reduceMotion
        Spring { token: "fast" }
    }
    Behavior on implicitHeight {
        enabled: !Theme.reduceMotion
        Spring { token: "fast" }
    }

    TextMetrics {
        id: labelMetrics
        font.family: Theme.bodySemibold
        font.pixelSize: nav.labelSize
        text: nav.text
    }

    background: Rectangle {
        radius: nav.vertical ? 24 : height / 2
        color: nav.current ? Theme.accent : (nav.pressed ? Theme.pressed : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0))
        border.width: nav.visualFocus ? 3 : 0
        border.color: nav.current ? Theme.text : Theme.accent
        Behavior on color {
            enabled: !Theme.reduceMotion
            ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        }
    }

    contentItem: Item {
        clip: true
        NavIcon {
            id: navIcon
            x: nav.vertical ? (parent.width - width) / 2 : Math.min(nav.startPad, (parent.width - width) / 2)
            y: nav.vertical ? Math.min(10, (parent.height - height) / 2) : (parent.height - height) / 2
            name: nav.iconName
            size: nav.iconSize
            color: nav.current ? Theme.accentInk : Theme.text2
        }
        Text {
            x: nav.vertical ? (parent.width - width) / 2 : navIcon.x + navIcon.width + nav.iconGap
            y: nav.vertical ? navIcon.y + navIcon.height + 3 : (parent.height - height) / 2
            width: nav.vertical ? Math.min(implicitWidth, nav.width - 4) : nav.labelWidth
            text: nav.text
            elide: Text.ElideRight
            color: Theme.accentInk
            font.family: Theme.bodySemibold
            font.pixelSize: nav.vertical ? 11 : nav.labelSize
            opacity: nav.current ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
        }
    }
}
