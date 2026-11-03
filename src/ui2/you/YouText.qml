import QtQuick 2.15
import ".."

// The two kinds of text between rows: a cap label over a group (small, uppercase, tracked, in
// the third text color, as every section of the Signature language), or a quiet note.
Text {
    // "heading" or "note"
    property string kind: "note"

    width: parent ? parent.width : implicitWidth
    topPadding: kind === "heading" ? 30 : 8
    bottomPadding: kind === "heading" ? 10 : 8
    color: kind === "heading" ? Theme.text3 : Theme.text2
    font.family: kind === "heading" ? Theme.bodySemibold : Theme.bodyMedium
    font.pixelSize: kind === "heading" ? Theme.capSize : Theme.labelSize
    font.letterSpacing: kind === "heading" ? Theme.capSpacing : 0
    font.capitalization: kind === "heading" ? Font.AllUppercase : Font.MixedCase
    lineHeightMode: Text.FixedHeight
    lineHeight: Math.round(font.pixelSize * 1.45)
    leftPadding: 12
    rightPadding: 12
    wrapMode: Text.WordWrap
    Accessible.role: kind === "heading" ? Accessible.Heading : Accessible.StaticText
    Accessible.name: text
}
