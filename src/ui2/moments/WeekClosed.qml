import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../Format.js" as Format
import "../goals/Streak.js" as Streak

// Week closed, full screen (the Moments board): three rings draw closed one after the other, the
// outer one the weekly goal and the two inside it the rider's usual week of the other measures
// (the average of the last 4 weeks ridden), the streak in the middle, "Week closed. Six in a
// row.", a row per ring, the freezes, and Plan next week.
Item {
    id: weekPage

    property var week: null          // the week of the goal moment (Moments.detect)
    property bool miles: false

    signal close()
    signal plan()

    readonly property var numberWords: [qsTr("No"), qsTr("One"), qsTr("Two"), qsTr("Three"), qsTr("Four"), qsTr("Five"),
                                        qsTr("Six"), qsTr("Seven"), qsTr("Eight"), qsTr("Nine"), qsTr("Ten"),
                                        qsTr("Eleven"), qsTr("Twelve")]
    readonly property int streak: week ? week.streak : 0
    readonly property bool sideways: width > height
    readonly property real ringBox: Math.max(120, sideways ? Math.min(268, height - 100, width * 0.36) : Math.min(268, width - 144, height * 0.3))
    readonly property var rings: build()
    property real drawn: 1

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Week closed. %1 weeks in a row.").arg(streak)

    function words(n) {
        return n < numberWords.length ? numberWords[n] : String(n)
    }

    function amount(measure, v) {
        if (measure === "rides")
            return String(Math.round(v))
        if (measure === "minutes") {
            var m = Math.round(v)
            return m >= 60 && m % 60 === 0 ? qsTr("%1 h").arg(m / 60) : Format.hours(m * 60)
        }
        if (measure === "kj")
            return Format.big(v)
        if (measure === "km")
            return Format.distance(v, miles)
        return String(Math.round(v))
    }

    // [{ name, value, target, goal, estimated }]: the goal first, then the usual week of two others
    function build() {
        if (!week)
            return []
        var names = { rides: qsTr("Rides"), minutes: qsTr("Time"), kj: qsTr("Work"), km: qsTr("Distance"), tss: qsTr("Load") }
        var values = { rides: week.rides, minutes: week.minutes, kj: week.kj, km: week.km, tss: week.tss }
        var usual = { rides: Math.round(week.usualRides), minutes: Math.round(week.usualMinutes / 5) * 5,
                      tss: Math.round(week.usualTss / 10) * 10 }
        var out = [{ name: names[week.kind], measure: week.kind, value: values[week.kind], target: week.goal, goal: true, estimated: false }]
        var others = ["rides", "minutes", "tss"]
        for (var i = 0; i < others.length && out.length < 3; i++) {
            var m = others[i]
            if (m === week.kind || !(usual[m] > 0))
                continue
            out.push({ name: names[m], measure: m, value: values[m], target: usual[m], goal: false, estimated: m === "tss" })
        }
        return out
    }

    function show() {
        if (Theme.reduceMotion) {
            drawn = 1
            return
        }
        drawAnimation.restart()
        flick.contentY = 0
        entered()
    }
    signal entered()

    NumberAnimation {
        id: drawAnimation
        target: weekPage
        property: "drawn"
        from: 0
        to: 1
        duration: 1900
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }
    MouseArea { anchors.fill: parent }

    HeroGlow {
        width: weekPage.ringBox * 1.6
        height: width
        x: ringItem.x + flick.x + (ringItem.width - width) / 2
        y: ringItem.y + flick.y - flick.contentY + (ringItem.height - height) / 2
        tint: Theme.accent
        low: 0.28
        high: 0.42
    }

    // the top line: the week and close
    Item {
        id: topLine
        x: 24
        y: 16
        width: weekPage.width - 48
        height: 44
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60
            text: weekPage.week ? qsTr("Week of %1").arg(new Date(weekPage.week.monday).toLocaleDateString(Qt.locale(), "d MMMM")) : ""
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        PulseButton {
            anchors.right: parent.right
            anchors.rightMargin: -2
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            topInset: 2
            bottomInset: 2
            leftInset: 2
            rightInset: 2
            fill: pressed ? Theme.pressed : Theme.control
            Accessible.name: qsTr("Close")
            onClicked: weekPage.close()
            contentItem: Item {
                Icon { anchors.centerIn: parent; name: "close"; size: 18; weight: 1.8; color: Theme.text }
            }
        }
    }

    Flickable {
        id: flick
        x: 24
        y: topLine.y + topLine.height
        width: weekPage.width - 48
        // on its side the button sits under the words on the right and the words scroll above it
        height: weekPage.sideways ? weekPage.height - y - 8 : weekPage.height - y - planButton.height - 44 - 16
        contentHeight: weekPage.sideways ? Math.max(ringItem.height, side.height + planButton.height + 28) + 8 : side.y + side.height + 24
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // the rings and the streak in the middle
        Item {
            id: ringItem
            x: weekPage.sideways ? 0 : (flick.width - width) / 2
            y: weekPage.sideways ? Math.max(0, (flick.height - height) / 2) : 18
            width: weekPage.ringBox
            height: weekPage.ringBox
            Accessible.role: Accessible.Graphic
            Accessible.name: qsTr("Weekly rings: %1").arg(weekPage.rings.map(function (r) {
                return r.name + " " + Math.round(Math.min(1, r.value / Math.max(1e-9, r.target)) * 100) + "%"
            }).join(", "))

            Repeater {
                model: weekPage.rings
                Shape {
                    id: ringShape
                    // the board's rings: 120, 96 and 72 of a 268 box, 14 wide
                    readonly property real ringRadius: weekPage.ringBox * (120 - index * 24) / 268
                    readonly property real share: Math.min(1, modelData.value / Math.max(1e-9, modelData.target))
                    // each ring starts 0.2 s after the one outside it and draws for 1.5 s
                    readonly property real local: Math.max(0, Math.min(1, (weekPage.drawn * 1900 - 200 - index * 200) / 1500))
                    readonly property real eased: local >= 1 ? 1 : 1 - Math.pow(1 - local, 3) * (1 - 0.35 * Math.sin(local * Math.PI))
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeColor: Theme.pressed
                        strokeWidth: weekPage.ringBox * 14 / 268
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: weekPage.ringBox / 2
                            centerY: weekPage.ringBox / 2
                            radiusX: ringShape.ringRadius
                            radiusY: ringShape.ringRadius
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                    ShapePath {
                        strokeColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, [1, 0.75, 0.5][index])
                        strokeWidth: weekPage.ringBox * 14 / 268
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: weekPage.ringBox / 2
                            centerY: weekPage.ringBox / 2
                            radiusX: ringShape.ringRadius
                            radiusY: ringShape.ringRadius
                            startAngle: -90
                            sweepAngle: Math.max(0.01, 360 * ringShape.share * ringShape.eased)
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                Accessible.ignored: true
                Numeral {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(weekPage.streak)
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: Math.round(weekPage.ringBox * 52 / 268)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: weekPage.streak === 1 ? qsTr("week") : qsTr("weeks")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                }
            }
        }

        Column {
            id: side
            x: weekPage.sideways ? ringItem.width + 40 : 0
            y: weekPage.sideways ? 8 : ringItem.y + ringItem.height + 28
            width: flick.width - x
            spacing: 0

            Rise {
                cue: weekPage
                order: 2
                width: parent.width
                Text {
                    width: parent.width
                    text: weekPage.streak > 1 ? qsTr("Week closed.\n%1 in a row.").arg(weekPage.words(weekPage.streak))
                                            : qsTr("Week closed.\nA streak starts here.")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: weekPage.width < 400 ? 30 : 34
                    font.letterSpacing: -0.7
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.08)
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text.split("\n").join(" ")
                }
            }
            Item { width: 1; height: 16 }
            Rise {
                cue: weekPage
                order: 3
                width: parent.width
                Column {
                    width: parent.width
                    Repeater {
                        model: weekPage.rings
                        Item {
                            width: parent.width
                            height: 50
                            Accessible.role: Accessible.StaticText
                            Accessible.name: qsTr("%1, %2 %3 %4").arg(modelData.name).arg(weekPage.amount(modelData.measure, modelData.value))
                                             .arg(modelData.goal ? qsTr("of") : qsTr("usual")).arg(weekPage.amount(modelData.measure, modelData.target))
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, [1, 0.75, 0.5][index])
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: Theme.text
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: 15
                                }
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                Numeral {
                                    id: rowValue
                                    text: weekPage.amount(modelData.measure, modelData.value)
                                    color: Theme.text
                                    font.pixelSize: 22
                                }
                                Text {
                                    anchors.baseline: rowValue.baseline
                                    text: (modelData.goal ? qsTr("of %1") : qsTr("usual %1")).arg(weekPage.amount(modelData.measure, modelData.target))
                                    color: Theme.text2
                                    font.family: Theme.bodyMedium
                                    font.pixelSize: 13
                                }
                                Text {
                                    visible: modelData.estimated
                                    anchors.baseline: rowValue.baseline
                                    text: qsTr("est.")
                                    color: Theme.text3
                                    font.family: Theme.bodyMedium
                                    font.pixelSize: 12
                                }
                            }
                            Hairline {
                                anchors.bottom: parent.bottom
                                width: parent.width
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: 22 }
            Rise {
                cue: weekPage
                order: 4
                width: parent.width
                Row {
                    width: parent.width
                    spacing: 14
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.control
                        anchors.verticalCenter: parent.verticalCenter
                        Shape {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            layer.enabled: true
                            layer.samples: 4
                            ShapePath {
                                strokeColor: Theme.accent
                                strokeWidth: 1.8
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                scale: Qt.size(0.75, 0.75)
                                PathSvg { path: "M12 2v20M4 6.5l16 11M20 6.5l-16 11M9.5 3.5L12 6l2.5-2.5M9.5 20.5L12 18l2.5 2.5" }
                            }
                        }
                    }
                    Column {
                        width: parent.width - 54
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            width: parent.width
                            text: !weekPage.week ? "" : (weekPage.week.freezes > 0
                                  ? (weekPage.week.freezes === 1 ? qsTr("1 streak freeze saved") : qsTr("%1 streak freezes saved").arg(weekPage.week.freezes))
                                  : qsTr("Freezes come with goal weeks"))
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            width: parent.width
                            text: !weekPage.week ? "" : (weekPage.week.freezes > 0 ? qsTr("A missed week will not break your run.")
                                  : (weekPage.week.toNextFreeze === 1 ? qsTr("One more goal week earns one.")
                                     : qsTr("%1 more goal weeks earn one.").arg(weekPage.week.toNextFreeze)))
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    PulseButton {
        id: planButton
        x: weekPage.sideways ? flick.x + side.x : 24
        width: weekPage.sideways ? side.width : weekPage.width - 48
        y: weekPage.height - (weekPage.sideways ? 20 : 44) - height
        height: 64
        pressedRadius: 20
        fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
        Accessible.name: qsTr("Plan next week")
        onClicked: weekPage.plan()
        contentItem: Text {
            text: qsTr("Plan next week")
            color: Theme.accentInk
            font.family: Theme.bodySemibold
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
