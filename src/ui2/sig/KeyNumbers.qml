import QtQuick 2.15
import ".."

// A few key numbers side by side, 2 to 4 to a row, each over its cap label, rows on hairlines.
// items: [{ value, unit, label, color, estimated, action }]; a number with an action (any
// value) is a button and emits picked(index).
Item {
    id: keys

    property var items: []
    property int columns: Math.min(4, Math.max(1, items.length))
    property int valueSize: 28

    signal picked(int index)

    readonly property int rows: Math.ceil(items.length / Math.max(1, columns))
    readonly property real cellHeight: valueSize + 46

    implicitHeight: rows * cellHeight

    Repeater {
        model: keys.rows
        Hairline {
            y: (index + 1) * keys.cellHeight - 1
            width: keys.width
        }
    }

    Repeater {
        model: keys.items
        PulseButton {
            id: keyCell
            readonly property var entry: modelData
            readonly property bool acts: entry.action !== undefined && entry.action !== null
            x: (index % keys.columns) * keys.width / keys.columns
            y: Math.floor(index / keys.columns) * keys.cellHeight
            width: keys.width / keys.columns
            height: keys.cellHeight - 1
            radius: 14
            fill: pressed && acts ? Theme.pressed : "transparent"
            pressedScale: acts ? 0.97 : 1
            enabled: acts
            focusPolicy: acts ? Qt.StrongFocus : Qt.NoFocus
            Accessible.role: acts ? Accessible.Button : Accessible.StaticText
            Accessible.name: qsTr("%1, %2").arg(entry.label || "").arg((entry.value || "") + (entry.unit ? " " + entry.unit : "")
                                                                       + (entry.estimated ? " " + qsTr("estimated") : ""))
            onClicked: keys.picked(index)
            contentItem: Item {
                Row {
                    id: numberRow
                    y: 14
                    spacing: 4
                    Numeral {
                        id: keyValue
                        text: keyCell.entry.value || ""
                        color: keyCell.entry.color || Theme.text
                        font.pixelSize: keys.valueSize
                    }
                    Text {
                        visible: text !== ""
                        anchors.baseline: keyValue.baseline
                        text: keyCell.entry.unit || ""
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 13
                    }
                    Text {
                        visible: keyCell.entry.estimated === true
                        anchors.baseline: keyValue.baseline
                        text: qsTr("est.")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: 12
                    }
                }
                CapLabel {
                    y: numberRow.y + numberRow.height + 10
                    width: parent.width - 8
                    text: keyCell.entry.label || ""
                    Accessible.ignored: true
                }
            }
        }
    }
}
