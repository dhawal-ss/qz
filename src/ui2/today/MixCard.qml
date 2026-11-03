import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../learn"
import "../Format.js" as Format
import "Patterns.js" as Patterns

// The effort mix of the last 30 days (Patterns.mix): a ring of easy, moderate and hard riding
// time with the biggest share in the middle, and the three beside it. The ring sweeps in when it
// shows. The whole section is the button to its Learn sheet; a sample in graphite for a rider
// with no rides yet.
LearnTap {
    id: mixCard

    property var mix: Patterns.mixSample()
    property bool sample: false
    // 0 to 1: how far the ring has swept round
    property real sweep: 1

    readonly property var parts: [
        { name: qsTr("Easy"), seconds: mix.easy, color: sample ? Qt.rgba(1, 1, 1, 0.34) : Theme.zoneColors[1] },
        { name: qsTr("Moderate"), seconds: mix.moderate, color: sample ? Qt.rgba(1, 1, 1, 0.2) : Theme.zoneColors[2] },
        { name: qsTr("Hard"), seconds: mix.hard, color: sample ? Qt.rgba(1, 1, 1, 0.12) : Theme.zoneColors[4] }
    ]
    readonly property real total: Math.max(1, mix.easy + mix.moderate + mix.hard)
    readonly property int lead: {
        var best = 0
        for (var i = 1; i < 3; i++)
            if (parts[i].seconds > parts[best].seconds)
                best = i
        return best
    }

    function share(i) {
        return Math.round(100 * parts[i].seconds / total)
    }

    function play() {
        if (Theme.reduceMotion) {
            sweepIn.stop()
            sweep = 1
            return
        }
        sweepIn.restart()
    }

    onMixChanged: play()
    name: sample ? qsTr("Effort mix, a sample of what shows after your first ride")
                 : qsTr("Effort mix of the last 30 days: easy %1 percent, moderate %2 percent, hard %3 percent").arg(share(0)).arg(share(1)).arg(share(2))

    SequentialAnimation {
        id: sweepIn
        PropertyAction { target: mixCard; property: "sweep"; value: 0 }
        PauseAnimation { duration: 120 }
        NumberAnimation {
            target: mixCard
            property: "sweep"
            to: 1
            duration: 900
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.effectsCurve
        }
    }

    Column {
        width: parent.width
        spacing: 12
        VisualHead {
            width: parent.width
            title: qsTr("Effort mix, 30 days")
            sample: mixCard.sample
        }
        Text {
            width: parent.width
            text: Patterns.mixWords(mixCard.mix)
            color: mixCard.sample ? Theme.text2 : Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: 17
            wrapMode: Text.WordWrap
        }
        Item {
            width: parent.width
            height: ring.height
            Accessible.ignored: true

            Item {
                id: ring
                width: 124
                height: 124
                readonly property real thickness: 14
                readonly property real r: (width - thickness) / 2

                Shape {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.06)
                        strokeWidth: ring.thickness
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: ring.width / 2
                            centerY: ring.height / 2
                            radiusX: ring.r
                            radiusY: ring.r
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                }
                // a part each: it starts where the one before ended, a small gap between them
                Repeater {
                    model: 3
                    Shape {
                        id: arc
                        readonly property real before: {
                            var sum = 0
                            for (var i = 0; i < index; i++)
                                sum += mixCard.parts[i].seconds
                            return sum / mixCard.total
                        }
                        readonly property real part: mixCard.parts[index].seconds / mixCard.total
                        visible: part > 0.005
                        anchors.fill: parent
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: mixCard.parts[index].color
                            strokeWidth: ring.thickness
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap
                            PathAngleArc {
                                centerX: ring.width / 2
                                centerY: ring.height / 2
                                radiusX: ring.r
                                radiusY: ring.r
                                startAngle: -90 + 360 * arc.before * mixCard.sweep + 1.5
                                sweepAngle: Math.max(0.1, 360 * arc.part * mixCard.sweep - 3)
                            }
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Numeral {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: mixCard.share(mixCard.lead) + "%"
                        color: mixCard.sample ? Theme.text2 : Theme.text
                        font.pixelSize: 28
                        font.letterSpacing: -0.6
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: mixCard.parts[mixCard.lead].name.toLowerCase()
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 12
                    }
                }
            }

            // the three parts
            Column {
                x: ring.width + 24
                width: parent.width - x
                anchors.verticalCenter: ring.verticalCenter
                Repeater {
                    model: 3
                    Item {
                        width: parent.width
                        height: 40
                        Rectangle {
                            y: 15
                            width: 10
                            height: 10
                            radius: 5
                            color: mixCard.parts[index].color
                        }
                        Text {
                            x: 20
                            y: 4
                            text: mixCard.parts[index].name
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: 14
                        }
                        Text {
                            x: 20
                            y: 22
                            width: parent.width - 20 - shareText.width - 8
                            text: Format.hours(mixCard.parts[index].seconds)
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            id: shareText
                            anchors.right: parent.right
                            y: 8
                            text: mixCard.share(index) + "%"
                            color: mixCard.sample ? Theme.text3 : Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: 17
                        }
                        Hairline {
                            visible: index < 2
                            anchors.bottom: parent.bottom
                            width: parent.width
                        }
                    }
                }
            }
        }
    }
}
