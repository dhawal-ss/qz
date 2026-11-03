import QtQuick 2.15
import QtQuick.Controls 2.15
import "."

// One destination of the bottom bar or the side rail: an icon in a pill that fills when
// the destination is open, and its name under it.
AbstractButton {
    id: nav

    property string iconName: "today"
    property bool current: false

    implicitWidth: 72
    implicitHeight: 64
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.onPressAction: nav.clicked()

    contentItem: Item {
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            width: nav.current ? 60 : 36
            height: 32
            radius: 16
            color: nav.current ? Qt.rgba(201 / 255, 184 / 255, 1, 0.18) : (nav.pressed ? Theme.pressed : "transparent")
            Behavior on width {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
            }
            Icon {
                anchors.centerIn: parent
                name: nav.iconName
                size: 22
                color: nav.current ? Theme.accent : Theme.text2
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: pill.y + pill.height + 4
            text: nav.text
            color: nav.current ? Theme.text : Theme.text2
            font.family: nav.current ? Theme.bodySemibold : Theme.bodyMedium
            font.pixelSize: 12
        }
    }
}
