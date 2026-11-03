import QtQuick 2.15
import ".."

// One hairline row: an optional icon in a round badge, a title with a detail line under it, and
// on the right a value and a chevron, an "opens elsewhere" arrow, or a pick mark: a ring that
// fills with the accent and a check when the row is the one picked (the picked row also takes
// a faint accent wash instead of its hairline).
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

    readonly property bool washed: trailing === "check" && selected

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(glyph !== "" ? 68 : 58, texts.implicitHeight + 26)
    radius: washed ? 24 : 16
    pressedScale: 0.98
    fill: washed ? Qt.rgba(201 / 255, 184 / 255, 1, 0.08)
                 : (highlighted ? Theme.pressed : (pressed ? Theme.control : Qt.rgba(0, 0, 0, 0)))
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
            radius: 20
            anchors.verticalCenter: parent.verticalCenter
            color: row.highlighted ? Theme.accentInk : Theme.control
            YouIcon {
                anchors.centerIn: parent
                name: row.glyph
                size: 20
                weight: 1.8
                color: row.iconColor
            }
        }

        Column {
            id: texts
            x: badge.visible ? badge.x + badge.width + 14 : 12
            width: Math.max(0, end.x - x - 12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                width: parent.width
                text: row.title
                color: Theme.text
                font.family: row.highlighted || row.washed ? Theme.bodySemibold : Theme.bodyMedium
                font.pixelSize: Theme.bodySize + 1
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: row.detail
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                lineHeightMode: Text.FixedHeight
                lineHeight: Math.round(font.pixelSize * 1.45)
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
                visible: row.trailing === "next" || row.trailing === "open"
                anchors.verticalCenter: parent.verticalCenter
                name: row.trailing === "open" ? "open" : "next"
                size: 20
                weight: 1.8
                color: Theme.text3
            }
            // the pick mark: an empty ring, or the accent with a check
            Rectangle {
                visible: row.trailing === "check"
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                color: row.selected ? Theme.accent : "transparent"
                border.width: row.selected ? 0 : 2
                border.color: Theme.dashed
                Behavior on color {
                    enabled: !Theme.reduceMotion
                    ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                }
                YouIcon {
                    anchors.centerIn: parent
                    visible: row.selected
                    name: "check"
                    size: 14
                    weight: 3
                    color: Theme.accentInk
                }
            }
        }
    }

    Rectangle {
        visible: row.hairline && !row.highlighted && !row.washed
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
        height: 1
        color: Theme.hairline
    }
}
