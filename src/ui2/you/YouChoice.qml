import QtQuick 2.15
import ".."

// One setting with a few answers, as a connected button group under its name.
Column {
    id: choice

    property string title: ""
    property string detail: ""
    // [[value, label], ...]
    property var options: []
    property var current
    property bool hairline: true

    signal picked(var value)

    width: parent ? parent.width : implicitWidth
    topPadding: 14
    bottomPadding: choice.hairline ? 0 : 14
    spacing: 12

    Column {
        x: 12
        width: parent.width - 24
        spacing: 3
        Text {
            width: parent.width
            text: choice.title
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.bodySize + 1
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: choice.detail
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
            wrapMode: Text.WordWrap
        }
    }

    Row {
        x: 12
        width: parent.width - 24
        spacing: 3
        Repeater {
            model: choice.options
            delegate: PulseButton {
                readonly property bool on: choice.current === modelData[0]
                width: (parent.width - (choice.options.length - 1) * 3) / choice.options.length
                height: Math.max(48, optionLabel.implicitHeight + 16)
                radius: on ? height / 2 : 12
                fill: on ? Theme.accent : Theme.pressed
                Accessible.name: choice.title + ": " + modelData[1]
                Accessible.checkable: true
                Accessible.checked: on
                onClicked: if (!on) choice.picked(modelData[0])
                Behavior on radius {
                    enabled: !Theme.reduceMotion
                    NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                }
                contentItem: Text {
                    id: optionLabel
                    text: modelData[1]
                    color: parent.on ? Theme.accentInk : Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    leftPadding: 6
                    rightPadding: 6
                }
            }
        }
    }

    Rectangle {
        visible: choice.hairline
        x: 12
        width: parent.width - 24
        height: 1
        color: Theme.hairline
    }
}
