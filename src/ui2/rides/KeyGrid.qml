import QtQuick 2.15
import ".."
import "../sig"

// The key numbers of a ride as a grid of pairs on hairlines: the name over the number, with
// its unit and a quiet "est." when it comes from estimated power. Two to a row on a phone,
// four on a wide pane. items: [{ label, value, unit, estimated }]
Item {
    id: grid

    property var items: []
    property int columns: width >= 560 ? 4 : 2
    property int columnGap: 24

    readonly property real cellWidth: (width - columnGap * (columns - 1)) / Math.max(1, columns)
    readonly property int cellHeight: 64
    readonly property int rows: Math.ceil(items.length / Math.max(1, columns))

    implicitHeight: rows * cellHeight

    Repeater {
        model: grid.items
        Item {
            id: pair
            readonly property var entry: modelData
            x: (index % grid.columns) * (grid.cellWidth + grid.columnGap)
            y: Math.floor(index / grid.columns) * grid.cellHeight
            width: grid.cellWidth
            height: grid.cellHeight
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("%1, %2").arg(entry.label).arg(entry.value + (entry.unit ? " " + entry.unit : "")
                                                                  + (entry.estimated ? " " + qsTr("estimated") : ""))

            Hairline {
                width: parent.width
            }
            Text {
                id: pairLabel
                y: 9
                width: parent.width
                text: pair.entry.label
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
                elide: Text.ElideRight
                Accessible.ignored: true
            }
            Row {
                y: pairLabel.y + pairLabel.height + 9
                spacing: 5
                Numeral {
                    id: pairValue
                    text: pair.entry.value
                    color: Theme.text
                    font.pixelSize: 24
                    font.letterSpacing: -0.6
                    Accessible.ignored: true
                }
                Text {
                    visible: text !== ""
                    anchors.baseline: pairValue.baseline
                    text: pair.entry.unit || ""
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                    Accessible.ignored: true
                }
                Text {
                    visible: pair.entry.estimated === true
                    anchors.baseline: pairValue.baseline
                    text: qsTr("est.")
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 12
                    Accessible.ignored: true
                }
            }
        }
    }
}
