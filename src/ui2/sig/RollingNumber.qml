import QtQuick 2.15
import ".."

// A number whose digits roll to the new value when it changes, each digit on its own wheel, on
// the fast spatial spring. Other signs (a point, a minus, a space) stay put. The box is as tall
// as the digits plus a little room for the roll, so big numbers sit on a grid.
Item {
    id: roller

    property string value: ""
    property color color: Theme.text
    property alias font: metrics.font
    property string token: "fast"

    readonly property real capHeight: -metrics.tightBoundingRect.y
    readonly property real cellHeight: Math.ceil(capHeight * 1.3)
    readonly property real digitWidth: metrics.advanceWidth

    implicitWidth: row.width
    implicitHeight: cellHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: value

    TextMetrics {
        id: metrics
        font.family: Theme.display
        font.pixelSize: 40
        text: "0"
    }
    FontMetrics {
        id: fontMetrics
        font: metrics.font
    }

    Row {
        id: row
        Repeater {
            model: roller.value.length
            Item {
                id: cell
                readonly property string sign: roller.value.charAt(index)
                readonly property int digit: "0123456789".indexOf(sign)
                width: digit >= 0 ? roller.digitWidth : otherMetrics.advanceWidth
                height: roller.cellHeight
                clip: true
                Accessible.ignored: true

                TextMetrics {
                    id: otherMetrics
                    font: metrics.font
                    text: cell.sign
                }
                // the wheel of a digit: 0 to 9 one under the other, turned to the digit
                Column {
                    visible: cell.digit >= 0
                    y: -Math.max(0, cell.digit) * roller.cellHeight
                    Behavior on y {
                        enabled: Theme.layoutMotion
                        Spring { token: roller.token }
                    }
                    Repeater {
                        model: 10
                        Item {
                            width: roller.digitWidth
                            height: roller.cellHeight
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                y: (roller.cellHeight - roller.capHeight) / 2 + roller.capHeight - fontMetrics.ascent
                                text: index
                                color: roller.color
                                font: metrics.font
                            }
                        }
                    }
                }
                Text {
                    visible: cell.digit < 0
                    y: (roller.cellHeight - roller.capHeight) / 2 + roller.capHeight - fontMetrics.ascent
                    text: cell.sign
                    color: roller.color
                    font: metrics.font
                }
            }
        }
    }
}
