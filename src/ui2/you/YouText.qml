import QtQuick 2.15
import ".."

// The two kinds of text between rows: a small heading over a group, or a quiet note.
Text {
    // "heading" or "note"
    property string kind: "note"

    width: parent ? parent.width : implicitWidth
    topPadding: kind === "heading" ? 28 : 8
    bottomPadding: kind === "heading" ? 6 : 8
    color: kind === "heading" ? Theme.text2 : Theme.text3
    font.family: Theme.bodyMedium
    font.pixelSize: kind === "heading" ? Theme.labelSize : Theme.tertiarySize + 1
    lineHeight: 1.15
    leftPadding: 12
    rightPadding: 12
    wrapMode: Text.WordWrap
}
