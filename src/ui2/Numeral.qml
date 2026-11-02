import QtQuick 2.15
import "."

// A number whose box is exactly as tall as its digits, so big numerals sit on a grid instead of
// floating in the line height of the font. The baseline is the bottom of the box.
Item {
    id: numeral

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias label: label

    implicitWidth: label.implicitWidth
    implicitHeight: Math.ceil(metrics.capHeight)
    baselineOffset: implicitHeight

    TextMetrics {
        id: metrics
        font: label.font
        text: "0123456789"
        readonly property real capHeight: -tightBoundingRect.y
    }
    FontMetrics {
        id: fontMetrics
        font: label.font
    }

    Text {
        id: label
        y: numeral.implicitHeight - fontMetrics.ascent
        font.family: Theme.display
    }
}
