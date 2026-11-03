import QtQuick 2.15
import ".."

// The small uppercase label over a section: 11 px, semibold, tracked, in the third text color.
Text {
    color: Theme.text3
    font.family: Theme.bodySemibold
    font.pixelSize: Theme.capSize
    font.letterSpacing: Theme.capSpacing
    font.capitalization: Font.AllUppercase
    elide: Text.ElideRight
    Accessible.role: Accessible.Heading
    Accessible.name: text
}
