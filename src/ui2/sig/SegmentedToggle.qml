import QtQuick 2.15
import ".."

// A connected button group (Simple / Pro, the periods): the picked segment goes fully round in
// the tint, the others stay soft squares with round outer ends. Picking springs the corners.
Item {
    id: segmentGroup

    property var options: []         // labels
    property int currentIndex: 0
    property color tint: Theme.accent
    property color ink: Theme.accentInk
    property string name: ""         // what the group picks, for the screen reader

    signal picked(int index)

    implicitHeight: 44
    implicitWidth: options.length * 88

    Row {
        anchors.fill: parent
        spacing: 3
        Repeater {
            model: segmentGroup.options
            PulseButton {
                id: segment
                readonly property bool current: index === segmentGroup.currentIndex
                readonly property real outer: height / 2
                width: (segmentGroup.width - 3 * (segmentGroup.options.length - 1)) / Math.max(1, segmentGroup.options.length)
                height: segmentGroup.height
                pressedScale: 0.97
                Accessible.name: (segmentGroup.name !== "" ? segmentGroup.name + ", " : "") + modelData
                                 + (current ? ", " + qsTr("selected") : "")
                onClicked: {
                    segmentGroup.currentIndex = index
                    segmentGroup.picked(index)
                }
                // two halves, so each outer end stays round while the inner corners square up
                background: Item {
                    Rectangle {
                        id: leftHalf
                        width: parent.width / 2 + radius
                        height: parent.height
                        radius: segment.current || index === 0 ? segment.outer : 10
                        color: segment.current ? segmentGroup.tint : (segment.pressed ? Theme.chip : Theme.pressed)
                        Behavior on radius {
                            enabled: !Theme.reduceMotion
                            Spring { token: "fast" }
                        }
                        Behavior on color {
                            enabled: !Theme.reduceMotion
                            ColorAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                        }
                    }
                    Rectangle {
                        x: parent.width / 2 - radius
                        width: parent.width / 2 + radius
                        height: parent.height
                        radius: segment.current || index === segmentGroup.options.length - 1 ? segment.outer : 10
                        color: leftHalf.color
                        Behavior on radius {
                            enabled: !Theme.reduceMotion
                            Spring { token: "fast" }
                        }
                    }
                    Rectangle {
                        visible: segment.visualFocus
                        anchors.fill: parent
                        radius: segment.outer
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.accent
                    }
                }
                contentItem: Text {
                    text: modelData
                    color: segment.current ? segmentGroup.ink : Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
