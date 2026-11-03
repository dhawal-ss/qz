import QtQuick 2.15
import ".."

// One hairline row: an optional icon, a title with a detail line under it, and on the right
// a value and a chevron, a check mark or an "opens elsewhere" arrow.
PulseButton {
    id: row

    property string title: ""
    property string detail: ""
    property string value: ""
    property string glyph: ""
    property color iconColor: Theme.accent
    // "next", "check", "open" or "" for nothing
    property string trailing: "next"
    property bool selected: false
    property bool highlighted: false
    property bool hairline: true

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(glyph !== "" ? 68 : 56, texts.implicitHeight + 24)
    radius: 16
    pressedScale: 0.98
    fill: highlighted ? Theme.pressed : (pressed ? Theme.control : Qt.rgba(0, 0, 0, 0))
    Accessible.name: title + (value !== "" ? ", " + value : "") + (detail !== "" ? ", " + detail : "")
    Accessible.checkable: trailing === "check"
    Accessible.checked: selected

    contentItem: Item {
        Rectangle {
            id: badge
            visible: row.glyph !== ""
            x: 12
            width: visible ? 40 : 0
            height: 40
            radius: 14
            anchors.verticalCenter: parent.verticalCenter
            color: row.highlighted ? Theme.accentInk : Theme.chip
            YouIcon {
                anchors.centerIn: parent
                name: row.glyph
                size: 20
                color: row.iconColor
            }
        }

        Column {
            id: texts
            x: badge.visible ? badge.x + badge.width + 14 : 12
            width: Math.max(0, end.x - x - 12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: row.title
                color: Theme.text
                font.family: row.highlighted ? Theme.bodySemibold : Theme.bodyMedium
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
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        Row {
            id: end
            x: parent.width - width - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text {
                visible: text !== ""
                width: Math.min(implicitWidth, row.width * 0.4)
                anchors.verticalCenter: parent.verticalCenter
                text: row.value
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize + 1
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
            YouIcon {
                visible: row.trailing !== "" && (row.trailing !== "check" || row.selected)
                anchors.verticalCenter: parent.verticalCenter
                name: row.trailing === "" ? "next" : row.trailing
                size: 20
                weight: row.trailing === "check" ? 2.6 : 2.0
                color: row.trailing === "check" ? Theme.accent : Theme.text3
            }
            // keeps the titles of a check list aligned when the mark is hidden
            Item {
                visible: row.trailing === "check" && !row.selected
                width: 20
                height: 20
            }
        }
    }

    Rectangle {
        visible: row.hairline && !row.highlighted
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: texts.x; rightMargin: 12 }
        height: 1
        color: Theme.hairline
    }
}
