import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"

// The biggest moment of a ride at the top of the finish screen, in the Signature language: the
// moment as a coach would say it, its number set heavier the harder the moment, what it means,
// and in the corner its badge, the Pulse in the moment's color. A record blooms full screen first
// (PrMoment) and its shape settles into this badge; any other moment blooms the badge here.
// With reduce motion everything is simply there.
Item {
    id: hero

    property var moment: ({})
    property string status: ""
    // short windows (a phone on its side) get a smaller numeral
    property bool compact: false
    // tablets get a bigger one
    property bool large: false
    property bool showShare: false
    property bool estimated: false
    // the badge waits for a record's shape to land in it
    property bool badgeHidden: false
    property alias badge: badgeBox

    signal share()

    readonly property int tone: moment.tone || 1
    readonly property color tint: Theme.zoneColors[tone - 1]
    readonly property int numeralBase: compact ? 72 : (large ? 128 : 104)
    readonly property string valueText: moment.value || ""
    readonly property bool watts: (moment.unit || "") === "W"
    // the record and the work moments are about effort: the heavier the zone, the heavier the face
    readonly property string numeralFamily: valueText.length > 0 && isDigits(valueText) ? Theme.heroFamily(tone) : Theme.display

    implicitHeight: column.height

    function isDigits(text) {
        var allowed = "0123456789:., -+%"
        for (var i = 0; i < text.length; i++)
            if (allowed.indexOf(text.charAt(i)) < 0)
                return false
        return true
    }

    // the numeral shrinks until value and unit fit the width, measured at 100 px
    function numeralSize() {
        var room = hero.width - unitRow.implicitWidth - 12
        return Math.max(40, Math.min(numeralBase, Math.floor(100 * room / Math.max(1, probe.advanceWidth))))
    }

    TextMetrics {
        id: probe
        font.family: hero.numeralFamily
        font.pixelSize: 100
        text: hero.valueText
    }

    // the badge blooms (scale and turn, on the spring curve) and the words rise after it
    function bloom() {
        bloomAnimation.stop()
        if (Theme.reduceMotion) {
            badgeBox.scale = 1
            badgeBox.rotation = 0
            words.opacity = 1
            words.shift = 0
            return
        }
        bloomAnimation.start()
    }

    // the words only: the badge is already in place (a record's shape landed in it)
    function rise() {
        bloomAnimation.stop()
        badgeBox.scale = 1
        badgeBox.rotation = 0
        if (Theme.reduceMotion) {
            words.opacity = 1
            words.shift = 0
            return
        }
        wordsAnimation.restart()
    }

    ParallelAnimation {
        id: bloomAnimation
        NumberAnimation {
            target: badgeBox; property: "scale"; from: 0.3; to: 1; duration: 1300
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
        }
        NumberAnimation {
            target: badgeBox; property: "rotation"; from: -70; to: 0; duration: 1300
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
        }
        ScriptAction { script: wordsAnimation.restart() }
    }
    SequentialAnimation {
        id: wordsAnimation
        PropertyAction { target: words; property: "opacity"; value: 0 }
        PropertyAction { target: words; property: "shift"; value: Theme.riseDistance * 2 }
        PauseAnimation { duration: 120 }
        ParallelAnimation {
            NumberAnimation {
                target: words; property: "opacity"; to: 1; duration: Theme.riseTime
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve
            }
            NumberAnimation {
                target: words; property: "shift"; to: 0; duration: Theme.riseTime
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.defaultSpatialCurve
            }
        }
    }

    // only for its paths
    Icon {
        id: glyphs
        visible: false
    }

    Column {
        id: column
        width: hero.width
        spacing: 0

        // the status line, and the badge on the right
        Item {
            width: parent.width
            height: badgeBox.height + (hero.compact ? 4 : 10)
            Row {
                anchors.verticalCenter: badgeBox.verticalCenter
                width: parent.width - badgeBox.width - 12
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: hero.tint
                }
                Text {
                    width: parent.width - 16
                    text: hero.status
                    color: Theme.text
                    font.family: Theme.bodyMedium
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }

            Item {
                id: badgeBox
                objectName: "momentBadge"
                anchors.right: parent.right
                width: hero.compact ? 48 : 64
                height: width
                opacity: hero.badgeHidden ? 0 : 1
                Accessible.ignored: true
                Pulse {
                    anchors.centerIn: parent
                    width: parent.width * 108 / 85
                    height: width
                    zone: hero.tone
                    color: hero.tint
                    turning: true
                }
                // what the moment is about
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
                Item {
                    readonly property real side: Math.round(badgeBox.width * 0.4)
                    anchors.centerIn: parent
                    width: side
                    height: side
                    visible: badgeBox.glyph !== ""
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
                            PathSvg { path: glyphs.paths[badgeBox.glyph] || "" }
                        }
                    }
                }
                BrandMark {
                    anchors.centerIn: parent
                    visible: badgeBox.glyph === ""
                    width: Math.round(badgeBox.width * 0.5)
                    height: width
                    color: Theme.accentInk
                }
            }
        }

        Column {
            id: words
            property real shift: 0
            width: parent.width
            spacing: hero.compact ? 10 : 16
            transform: Translate { y: words.shift }

            Text {
                width: parent.width
                text: hero.moment.title || ""
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: hero.compact ? 26 : (hero.large ? 34 : 30)
                font.letterSpacing: -0.6
                lineHeightMode: Text.FixedHeight
                lineHeight: Math.round(font.pixelSize * 1.08)
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }

            Row {
                spacing: 8
                Accessible.role: Accessible.StaticText
                Accessible.name: hero.valueText + " " + (hero.moment.unit || "") + (hero.estimated && hero.watts ? " " + qsTr("estimated") : "")
                Numeral {
                    id: numeral
                    text: hero.valueText
                    color: Theme.zoneLight[hero.tone - 1]
                    font.family: hero.numeralFamily
                    font.pixelSize: hero.numeralSize()
                    font.letterSpacing: -2
                    Accessible.ignored: true
                }
                Row {
                    id: unitRow
                    anchors.baseline: numeral.baseline
                    baselineOffset: unitText.baselineOffset
                    spacing: 5
                    Accessible.ignored: true
                    Text {
                        id: unitText
                        text: hero.moment.unit || ""
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: hero.compact ? 16 : 18
                        visible: text !== ""
                    }
                    Text {
                        visible: hero.estimated && hero.watts
                        anchors.baseline: unitText.baseline
                        text: qsTr("est.")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: 12
                    }
                }
            }

            Text {
                width: parent.width
                text: hero.moment.detail || ""
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 15
                lineHeightMode: Text.FixedHeight
                lineHeight: 21
                wrapMode: Text.WordWrap
            }

            PulseButton {
                visible: hero.showShare
                x: -2
                width: shareRow.implicitWidth + 40
                height: 48
                pressedRadius: 16
                fill: pressed ? Theme.chip : Theme.pressed
                Accessible.name: qsTr("Share the ride")
                onClicked: hero.share()
                contentItem: Item {
                    Row {
                        id: shareRow
                        anchors.centerIn: parent
                        spacing: 8
                        Shape {
                            width: 18
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            layer.enabled: true
                            layer.samples: 4
                            ShapePath {
                                strokeColor: Theme.text
                                strokeWidth: 1.8
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                scale: Qt.size(0.75, 0.75)
                                PathSvg { path: "M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6" }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Share")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: 15
                        }
                    }
                }
            }
        }
    }
}
