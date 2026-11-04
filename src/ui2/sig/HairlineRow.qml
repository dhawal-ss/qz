import QtQuick 2.15
import ".."

// One row of a quiet section: what it is on the left (and a line under it), the number on the
// right with its unit, a quiet "est." when the number is estimated, and a change under it.
// A hairline under the row unless it is the last. With `interactive` the row is a button that
// softens a little while pressed.
PulseButton {
    id: row

    property string label: ""
    property string sub: ""
    property string value: ""
    property string unit: ""
    property string delta: ""
    property color deltaColor: Theme.zoneColors[2]
    property color valueColor: Theme.text
    property bool estimated: false
    property bool interactive: false
    property bool line: true
    property int valueSize: 26

    implicitHeight: Math.max(56, Math.max(texts.implicitHeight, numbers.implicitHeight) + 24)
    fill: interactive && pressed ? Theme.pressed : "transparent"
    radius: 16
    pressedScale: interactive ? 0.985 : 1
    enabled: interactive
    focusPolicy: interactive ? Qt.StrongFocus : Qt.NoFocus
    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: {
        var parts = [label]
        if (value !== "")
            parts.push(value + (unit !== "" ? " " + unit : "") + (estimated ? " " + qsTr("estimated") : ""))
        if (sub !== "")
            parts.push(sub)
        if (delta !== "")
            parts.push(delta)
        return parts.join(", ")
    }

    contentItem: Item {
        Column {
            id: texts
            width: parent.width - numbers.width - 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: row.label
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(15)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: row.sub
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                lineHeight: 1.15
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
        Column {
            id: numbers
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Row {
                anchors.right: parent.right
                spacing: 4
                Numeral {
                    id: big
                    text: row.value
                    color: row.valueColor
                    font.pixelSize: row.valueSize
                }
                Text {
                    visible: row.unit !== ""
                    anchors.baseline: big.baseline
                    text: row.unit
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(13)
                }
                Text {
                    visible: row.estimated
                    anchors.baseline: big.baseline
                    text: qsTr("est.")
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(12)
                }
            }
            Text {
                anchors.right: parent.right
                visible: text !== ""
                text: row.delta
                color: row.deltaColor
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(12)
            }
        }
    }

    Hairline {
        visible: row.line
        anchors.bottom: parent.bottom
        width: parent.width
    }
}
