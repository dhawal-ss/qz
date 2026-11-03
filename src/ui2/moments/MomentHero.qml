import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."

// The biggest moment of a ride: the Pulse blooms to the color of the moment with a short burst of
// dots, then the number lands under it. With reduce motion everything is simply there.
Item {
    id: hero

    property var moment: ({})
    property string status: ""
    // short windows (a phone on its side) get a smaller Pulse and numeral
    property bool compact: false
    // tablets get a bigger one
    property bool large: false
    property bool showShare: false

    signal share()

    readonly property int tone: moment.tone || 1
    readonly property color tint: Theme.zoneColors[tone - 1]
    readonly property int pulseSize: compact ? 88 : (large ? 168 : 128)
    readonly property int numeralBase: compact ? 72 : (large ? 136 : 104)
    readonly property string valueText: moment.value || ""

    implicitHeight: column.height

    // only for its paths
    Icon {
        id: glyphs
        visible: false
    }

    // the numeral shrinks until value and unit fit the width, measured at 100 px
    function numeralSize() {
        var room = hero.width - unit.implicitWidth - 16
        return Math.max(36, Math.min(numeralBase, Math.floor(100 * room / Math.max(1, probe.advanceWidth))))
    }

    TextMetrics {
        id: probe
        font.family: Theme.celebrate
        font.pixelSize: 100
        text: hero.valueText
    }

    function bloom() {
        bloomAnimation.stop()
        if (Theme.reduceMotion) {
            pulseBox.scale = 1
            pulse.shownZone = hero.tone
            pulse.color = hero.tint
            halo.opacity = 0.35
            burst.t = 1
            words.opacity = 1
            words.shift = 0
            return
        }
        words.opacity = 0
        bloomAnimation.start()
    }

    ParallelAnimation {
        id: bloomAnimation
        NumberAnimation {
            target: pulseBox; property: "scale"; from: 0.3; to: 1; duration: Theme.slow
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
        }
        NumberAnimation {
            target: pulse; property: "shownZone"; from: 1; to: hero.tone; duration: Theme.slow + 200
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
        }
        ColorAnimation {
            target: pulse; property: "color"; from: Theme.chip; to: hero.tint; duration: Theme.colorTime
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve
        }
        NumberAnimation {
            target: halo; property: "opacity"; from: 0; to: 0.35; duration: Theme.slow
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve
        }
        NumberAnimation { target: burst; property: "t"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 160 }
            ParallelAnimation {
                NumberAnimation { target: words; property: "opacity"; from: 0; to: 1; duration: Theme.medium }
                NumberAnimation {
                    target: words; property: "shift"; from: 22; to: 0; duration: Theme.slow
                    easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
                }
            }
        }
    }

    Column {
        id: column
        width: hero.width
        spacing: hero.compact ? 8 : 12

        Text {
            width: parent.width
            text: hero.status
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            id: stage
            width: parent.width
            height: hero.pulseSize + (hero.compact ? 8 : 24)

            Glow {
                id: halo
                width: hero.pulseSize * 2.6
                height: width
                anchors.centerIn: pulseBox
                tint: hero.tint
                opacity: 0.35
            }

            // the burst: dots thrown out of the Pulse once, fading as they go
            Item {
                id: burst
                property real t: 1
                anchors.centerIn: pulseBox
                visible: t < 1
                Accessible.ignored: true
                Repeater {
                    model: 16
                    Rectangle {
                        readonly property real angle: index * 2 * Math.PI / 16 + (index % 2) * 0.18
                        readonly property real reach: hero.pulseSize * (0.42 + (index % 3) * 0.22) * burst.t
                        readonly property real start: hero.pulseSize * 0.36
                        width: index % 3 === 0 ? 10 : 6
                        height: width
                        radius: width / 2
                        color: index % 2 === 0 ? hero.tint : Theme.zoneLight[hero.tone - 1]
                        x: Math.cos(angle) * (start + reach) - width / 2
                        y: Math.sin(angle) * (start + reach) - height / 2
                        opacity: 1 - burst.t
                    }
                }
            }

            Item {
                id: pulseBox
                width: hero.pulseSize
                height: hero.pulseSize
                anchors.centerIn: parent

                PulseShape {
                    id: pulse
                    anchors.fill: parent
                    zone: hero.tone
                    color: hero.tint
                }
                // the rider for the moments about riding itself, an icon for the others
                readonly property string glyph: {
                    switch (hero.moment.kind) {
                    case "record":
                    case "records": return "bolt"
                    case "streak": return "flame"
                    case "goal": return "goals"
                    case "distance":
                    case "work": return "progress"
                    case "back": return "heart"
                    case "week":
                    case "longest": return "calendar"
                    }
                    return ""
                }
                // drawn at its full size: Icon draws at 24 px and would blur when scaled up
                Item {
                    readonly property real side: Math.round(hero.pulseSize * 0.34)
                    anchors.centerIn: parent
                    width: side
                    height: side
                    visible: pulseBox.glyph !== ""
                    layer.enabled: true
                    layer.samples: 4
                    Shape {
                        width: 24
                        height: 24
                        scale: parent.side / 24
                        transformOrigin: Item.TopLeft
                        ShapePath {
                            strokeColor: Theme.accentInk
                            strokeWidth: 2.2
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: glyphs.paths[pulseBox.glyph] || "" }
                        }
                    }
                }
                BrandMark {
                    anchors.centerIn: parent
                    visible: pulseBox.glyph === ""
                    width: Math.round(hero.pulseSize * 0.5)
                    height: width
                    color: Theme.accentInk
                }
            }
        }

        Column {
            id: words
            property real shift: 0
            width: parent.width
            spacing: hero.compact ? 8 : 12
            transform: Translate { y: words.shift }

            Text {
                width: parent.width
                text: hero.moment.title || ""
                color: Theme.zoneLight[hero.tone - 1]
                font.family: Theme.bodySemibold
                font.pixelSize: hero.compact ? 16 : 18
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Numeral {
                    id: numeral
                    text: hero.valueText
                    color: Theme.text
                    font.family: Theme.celebrate
                    font.pixelSize: hero.numeralSize()
                    font.letterSpacing: -2
                }
                Text {
                    id: unit
                    text: hero.moment.unit || ""
                    color: Theme.text2
                    font.family: Theme.bodySemibold
                    font.pixelSize: hero.compact ? 18 : 22
                    anchors.baseline: numeral.baseline
                }
            }

            Text {
                width: parent.width
                text: hero.moment.detail || ""
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            PulseButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: hero.showShare
                width: 132
                height: 48
                fill: Theme.chip
                Accessible.name: qsTr("Share the ride")
                onClicked: hero.share()
                contentItem: Text {
                    text: qsTr("Share")
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
