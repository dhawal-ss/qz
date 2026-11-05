import QtQuick 2.15
import QtQuick.Controls 2.15
import "."
import "sig"

// One destination of the navigation: its icon, and its name under it, always. The open
// destination has its icon in a filled pill in the accent that grows out from the icon on the fast
// spatial spring; the fill and the colors fade on the effects curve. The same in the bottom bar
// and in the rail: the button fills the slot it is given.
AbstractButton {
    id: nav

    property string iconName: "today"
    property bool current: false
    readonly property int iconSize: 22

    implicitWidth: 72
    implicitHeight: 64
    padding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selectable: true
    Accessible.selected: current
    Accessible.onPressAction: nav.clicked()

    background: Item {}

    contentItem: Item {
        // the name 10 from the bottom of the slot, as under Ride beside it, and the icon over it
        Rectangle {
            id: indicator
            anchors.horizontalCenter: parent.horizontalCenter
            y: label.y - 4 - height
            width: nav.current ? 56 : 32
            height: 32
            radius: 16
            color: nav.current ? Theme.accent : (nav.pressed ? Theme.pressed : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0))
            border.width: nav.visualFocus ? 3 : 0
            border.color: nav.current ? Theme.text : Theme.accent
            Behavior on width {
                enabled: Theme.layoutMotion
                Spring { token: "fast" }
            }
            Behavior on color {
                enabled: !Theme.reduceMotion
                ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
            NavIcon {
                anchors.centerIn: parent
                name: nav.iconName
                size: nav.iconSize
                color: nav.current ? Theme.accentInk : Theme.text2
            }
        }
        Text {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 10
            width: Math.min(implicitWidth, parent.width - 4)
            text: nav.text
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: nav.current ? Theme.text : Theme.text2
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(12)
            Accessible.ignored: true
        }
    }
}
