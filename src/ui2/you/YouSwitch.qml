import QtQuick 2.15
import ".."

// A row that turns one thing on or off. The whole row is the switch.
PulseButton {
    id: row

    property string title: ""
    property string detail: ""
    property bool isOn: false
    property bool hairline: true

    signal switched(bool value)

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(56, texts.implicitHeight + 24)
    radius: 16
    pressedScale: 0.98
    fill: pressed ? Theme.control : Qt.rgba(0, 0, 0, 0)
    Accessible.name: title + (detail !== "" ? ", " + detail : "")
    Accessible.checkable: true
    Accessible.checked: isOn
    onClicked: switched(!isOn)

    contentItem: Item {
        Column {
            id: texts
            x: 12
            width: Math.max(0, track.x - x - 16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: row.title
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize + 1
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: row.detail
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
        }

        // the M3 switch: the thumb grows when it is on
        Rectangle {
            id: track
            x: parent.width - width - 12
            width: 52
            height: 32
            radius: 16
            anchors.verticalCenter: parent.verticalCenter
            color: row.isOn ? Theme.accent : Theme.chip
            border.width: row.isOn ? 0 : 2
            border.color: Theme.text3
            Behavior on color {
                enabled: !Theme.reduceMotion
                ColorAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
            Rectangle {
                width: row.isOn ? 24 : 16
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: row.isOn ? parent.width - width - 4 : 8
                color: row.isOn ? Theme.accentInk : Theme.text3
                Behavior on x {
                    enabled: Theme.layoutMotion
                    NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                }
                Behavior on width {
                    enabled: Theme.layoutMotion
                    NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                }
            }
        }
    }

    Rectangle {
        visible: row.hairline
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
        height: 1
        color: Theme.hairline
    }
}
