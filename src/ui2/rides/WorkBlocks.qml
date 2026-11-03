import QtQuick 2.15
import ".."
import "../sig"
import "../Format.js" as Format

// The laps of a ride as rows on hairlines: the name with its time and heart rate, the average
// watts, and the change from the block before. The strongest block is set in the tint. A tap on
// a row zooms the charts to that lap; a second tap lets it go.
Item {
    id: blocks

    // Analysis.workBlocks(): [{ index, name, duration, hr, watts, delta, first, best }]
    property var list: []
    property color tint: Theme.accent
    property bool estimated: false
    property int picked: -1          // the lap index picked, -1 for none

    signal lapPicked(int lapIndex)

    readonly property int rowHeight: 50
    implicitHeight: list.length * rowHeight

    Repeater {
        model: blocks.list
        PulseButton {
            id: blockRow
            readonly property var entry: modelData
            readonly property bool on: blocks.picked === entry.index
            y: index * blocks.rowHeight
            x: -8
            width: blocks.width + 16
            height: blocks.rowHeight
            radius: 16
            pressedScale: 0.985
            fill: on ? Theme.control : (pressed ? Theme.pressed : "transparent")
            Accessible.name: qsTr("%1, %2, %3 watts%4%5").arg(entry.name).arg(Format.duration(entry.duration))
                             .arg(Math.round(entry.watts))
                             .arg(entry.hr > 0 ? ", " + qsTr("%1 bpm").arg(Math.round(entry.hr)) : "")
                             .arg(entry.first ? "" : ", " + qsTr("%1 watts from the one before").arg(entry.delta > 0 ? "+" + entry.delta : entry.delta))
            Accessible.description: qsTr("Zooms the chart to this lap")
            onClicked: blocks.lapPicked(blockRow.on ? -1 : entry.index)

            contentItem: Item {
                Row {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 16 - numbers.width - deltaText.width - 24
                    spacing: 8
                    Text {
                        id: blockName
                        text: blockRow.entry.name
                        color: blockRow.entry.best ? blocks.tint : Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                    }
                    Text {
                        anchors.baseline: blockName.baseline
                        width: Math.max(0, parent.width - blockName.width - 8)
                        text: Format.duration(blockRow.entry.duration)
                              + (blockRow.entry.hr > 0 ? ", " + qsTr("%1 bpm").arg(Math.round(blockRow.entry.hr)) : "")
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: numbers
                    x: deltaText.x - 12 - width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Numeral {
                        id: blockWatts
                        text: Math.round(blockRow.entry.watts)
                        color: blockRow.entry.best ? blocks.tint : Theme.text
                        font.pixelSize: 24
                        font.letterSpacing: -0.6
                    }
                    Text {
                        anchors.baseline: blockWatts.baseline
                        text: "W"
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 13
                    }
                    Text {
                        visible: blocks.estimated
                        anchors.baseline: blockWatts.baseline
                        text: qsTr("est.")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: 12
                    }
                }
                Text {
                    id: deltaText
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    horizontalAlignment: Text.AlignRight
                    text: blockRow.entry.first ? qsTr("First") : ((blockRow.entry.delta > 0 ? "+" : "") + blockRow.entry.delta + " W")
                    color: blockRow.entry.first ? Theme.text2 : (blockRow.entry.best ? blocks.tint : Theme.text)
                    font.family: blockRow.entry.first ? Theme.bodyMedium : Theme.bodySemibold
                    font.pixelSize: 14
                }
            }

            Hairline {
                visible: index < blocks.list.length - 1
                x: 8
                anchors.bottom: parent.bottom
                width: parent.width - 16
            }
        }
    }
}
