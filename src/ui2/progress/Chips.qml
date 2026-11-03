import QtQuick 2.15
import ".."

// A row of choice chips: the picked one is filled with the accent. The chips share the width of
// the row evenly, each 36 high and touching 48, close together like a connected button group;
// a label too long for its share makes the row wrap instead. An optional word before the chips says what they choose.
Flow {
    id: chips

    property var options: []     // [[key, label], ...]
    property string current: ""
    property string what: ""     // what the chips choose, for the screen reader: "Period"
    property string lead: ""     // a word shown before the chips

    signal picked(string key)

    readonly property real share: (width - (leadItem.visible ? leadItem.width + spacing : 0) - spacing * Math.max(0, options.length - 1))
                                  / Math.max(1, options.length)

    spacing: 4

    Item {
        id: leadItem
        visible: chips.lead !== ""
        width: leadText.implicitWidth + 4
        height: 48
        Text {
            id: leadText
            anchors.verticalCenter: parent.verticalCenter
            text: chips.lead
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
        }
    }

    Repeater {
        model: chips.options
        PulseButton {
            id: chip
            readonly property bool chosen: chips.current === modelData[0]
            width: Math.max(chipLabel.implicitWidth + 12, Math.floor(chips.share))
            height: 48
            topInset: 6
            bottomInset: 6
            radius: 18
            fill: chosen ? Theme.accent : (pressed ? Theme.pressed : Theme.chip)
            Accessible.name: chips.what !== "" ? qsTr("%1: %2").arg(chips.what).arg(modelData[1]) : modelData[1]
            Accessible.checkable: true
            Accessible.checked: chosen
            onClicked: chips.picked(modelData[0])
            contentItem: Text {
                id: chipLabel
                text: modelData[1]
                color: chip.chosen ? Theme.accentInk : Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: chips.share < 80 ? 12 : 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
