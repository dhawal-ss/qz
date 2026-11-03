import QtQuick 2.15
import ".."
import "../sig"

// A new power record, full screen (the PR moment of the Moments and Motion boards): the Pulse
// blooms in the record's color (scale 0.3 to 1 and a turn, on the spring curve) with small shapes
// orbiting it and the glow beating behind, the heavy numeral inside, "New 5 minute best" and the
// gain under it. After a hold, or a tap, the shape settles into the badge in the corner of the
// finish screen on the default spatial spring while the rest fades away; then finished().
// badgeAt() gives where the badge is: { x, y, size }, its center in this item.
Item {
    id: pr

    property var moment: ({})
    property bool estimated: false
    property string status: ""
    property var badgeAt: null
    property int hold: 2800

    signal finished()

    readonly property int tone: moment.tone || 5
    readonly property color tint: Theme.zoneColors[tone - 1]
    readonly property bool sideways: width > height
    // the shape: as big as the board's 300 on a phone, from the height on a phone on its side
    readonly property real shapeSize: sideways ? Math.min(300, height * 0.62) : Math.min(300, width - 112, height * 0.36)
    readonly property real homeX: sideways ? width * 0.3 : width / 2
    readonly property real homeY: sideways ? height / 2 : Math.max(shapeSize / 2 + 90, height * 0.41)
    property string phase: "bloom"       // bloom, settle, done

    // where the shape is: its center and its scale, springing once it settles
    property real cx: homeX
    property real cy: homeY
    property real s: 1
    Behavior on cx { enabled: pr.phase === "settle" && !Theme.reduceMotion; Spring { token: "default" } }
    Behavior on cy { enabled: pr.phase === "settle" && !Theme.reduceMotion; Spring { token: "default" } }
    Behavior on s { enabled: pr.phase === "settle" && !Theme.reduceMotion; Spring { token: "default"; epsilon: 0.002 } }
    // the backdrop, the glow, the orbit and the words, faded out as the shape settles
    property real stage: 1
    Behavior on stage {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
    }

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("%1, %2 watts. %3").arg(moment.title || "").arg(moment.value || "").arg(moment.detail || "")

    function play() {
        phase = "bloom"
        cx = homeX
        cy = homeY
        s = 1
        stage = 1
        holdTimer.interval = hold
        if (Theme.reduceMotion) {
            shapeBox.scale = 1
            shapeBox.rotation = 0
            shapeBox.opacity = 1
            orbit.opacity = 1
            words.opacity = 1
            words.shift = 0
        } else {
            bloomAnimation.restart()
        }
        holdTimer.restart()
    }

    // the shape flies to the badge, the rest fades
    function settle() {
        if (phase !== "bloom")
            return
        holdTimer.stop()
        bloomAnimation.complete()
        phase = "settle"
        var at = badgeAt ? badgeAt() : null
        stage = 0
        if (at) {
            cx = at.x
            cy = at.y
            s = at.size / shapeSize
        } else {
            s = 0.3
        }
        doneTimer.interval = Theme.reduceMotion ? 0 : 650
        doneTimer.restart()
    }

    onWidthChanged: if (phase === "bloom") { cx = homeX; cy = homeY }
    onHeightChanged: if (phase === "bloom") { cx = homeX; cy = homeY }

    Timer {
        id: holdTimer
        onTriggered: pr.settle()
    }
    Timer {
        id: doneTimer
        onTriggered: {
            pr.phase = "done"
            pr.finished()
        }
    }

    ParallelAnimation {
        id: bloomAnimation
        NumberAnimation {
            target: shapeBox; property: "scale"; from: 0.3; to: 1; duration: 1300
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
        }
        NumberAnimation {
            target: shapeBox; property: "rotation"; from: -70; to: 0; duration: 1300
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
        }
        NumberAnimation {
            target: shapeBox; property: "opacity"; from: 0; to: 1; duration: 400
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve
        }
        SequentialAnimation {
            PropertyAction { target: orbit; property: "opacity"; value: 0 }
            PauseAnimation { duration: 250 }
            NumberAnimation {
                target: orbit; property: "opacity"; to: 1; duration: 700
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve
            }
        }
        SequentialAnimation {
            PropertyAction { target: words; property: "opacity"; value: 0 }
            PropertyAction { target: words; property: "shift"; value: Theme.riseDistance }
            PauseAnimation { duration: 160 + Theme.riseStagger }
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
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: pr.stage
    }

    // a tap anywhere settles it early
    MouseArea {
        anchors.fill: parent
        enabled: pr.phase === "bloom"
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Continue to the ride summary")
        Accessible.onPressAction: pr.settle()
        onClicked: pr.settle()
    }

    // the glow beats behind the shape, faster than the 4 s of a hero: a record is a moment
    Item {
        anchors.fill: parent
        opacity: pr.stage
        HeroGlow {
            width: pr.shapeSize * 1.5
            height: width
            x: pr.homeX - width / 2
            y: pr.homeY - height / 2
            tint: pr.tint
            beat: 1300
            low: 0.5
            high: 0.8
        }
    }

    // the small shapes orbiting, once a 36 s turn
    Item {
        id: orbit
        x: pr.homeX
        y: pr.homeY
        opacity: 1
        visible: pr.stage > 0.01
        Accessible.ignored: true
        readonly property real reach: pr.shapeSize * 0.55
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 36000
            loops: Animation.Infinite
            running: !Theme.reduceMotion && pr.visible && pr.phase === "bloom"
        }
        Repeater {
            // angle, size of the 412 board, strength
            model: [[-20, 21, 0.9], [135, 14, 0.5], [230, 17, 0.7], [310, 12, 0.4]]
            Pulse {
                readonly property real angle: modelData[0] * Math.PI / 180
                width: modelData[1] * 108 / 85 * pr.shapeSize / 300
                height: width
                x: Math.cos(angle) * orbit.reach * 1.1 - width / 2
                y: Math.sin(angle) * orbit.reach * 1.1 - height / 2
                zone: pr.tone
                color: pr.tint
                opacity: modelData[2] * pr.stage
            }
        }
    }

    // the shape and the numeral inside it
    Item {
        id: shapeBox
        width: pr.shapeSize
        height: pr.shapeSize
        x: pr.cx - width / 2
        y: pr.cy - height / 2
        transform: Scale { origin.x: pr.shapeSize / 2; origin.y: pr.shapeSize / 2; xScale: pr.s; yScale: pr.s }
        Pulse {
            anchors.centerIn: parent
            width: parent.width * 108 / 85
            height: width
            zone: pr.tone
            color: pr.tint
            turning: true
        }
        Column {
            anchors.centerIn: parent
            spacing: Math.round(pr.shapeSize * 0.02)
            opacity: pr.stage
            Accessible.ignored: true
            Numeral {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pr.moment.value || ""
                color: Theme.bg
                font.family: Theme.celebrate
                font.pixelSize: Math.round(pr.shapeSize * 0.233 * Math.min(1, 3 / Math.max(1, text.length)))
                font.letterSpacing: -1.5
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (pr.moment.unit || "") + (pr.estimated ? " " + qsTr("est.") : "")
                color: Theme.bg
                font.family: Theme.bodySemibold
                font.pixelSize: Math.max(12, Math.round(pr.shapeSize * 0.043))
            }
        }
    }

    // the status line on top
    Row {
        x: 24
        y: 16
        height: 44
        spacing: 8
        opacity: pr.stage
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: pr.tint
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pr.status
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: 14
        }
    }

    // what it is and what it beat
    Column {
        id: words
        property real shift: 0
        x: pr.sideways ? pr.width * 0.58 : 24
        y: pr.sideways ? (pr.height - height) / 2 : pr.homeY + pr.shapeSize / 2 + 52
        width: pr.sideways ? pr.width * 0.38 : pr.width - 48
        spacing: 10
        opacity: 1
        transform: Translate { y: words.shift }
        Item {
            width: parent.width
            height: wordsInner.height
            opacity: pr.stage
            Column {
                id: wordsInner
                width: parent.width
                spacing: 10
                Text {
                    width: parent.width
                    text: pr.moment.title || ""
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 26
                    font.letterSpacing: -0.4
                    horizontalAlignment: pr.sideways ? Text.AlignLeft : Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Text {
                    width: parent.width
                    text: pr.moment.detail || ""
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 14
                    horizontalAlignment: pr.sideways ? Text.AlignLeft : Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Item { width: 1; height: pr.sideways ? 14 : 0 }
                PulseButton {
                    visible: pr.sideways
                    width: continueText.implicitWidth + 48
                    height: 52
                    fill: pressed ? Theme.chip : Theme.floating
                    pressedRadius: 18
                    Accessible.name: qsTr("Continue")
                    onClicked: pr.settle()
                    contentItem: Text {
                        id: continueText
                        text: qsTr("Continue")
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

    // the way on, at the bottom of a phone
    Column {
        visible: !pr.sideways
        anchors.horizontalCenter: parent.horizontalCenter
        y: pr.height - 44 - height
        spacing: 14
        opacity: pr.stage * words.opacity
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 36
            height: 4
            radius: 2
            color: Theme.dashed
        }
        PulseButton {
            width: continueRow.implicitWidth + 48
            height: 52
            fill: pressed ? Theme.chip : Theme.floating
            pressedRadius: 18
            Accessible.name: qsTr("Continue to the ride summary")
            onClicked: pr.settle()
            contentItem: Item {
                Row {
                    id: continueRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron"
                        size: 18
                        weight: 1.8
                        color: Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Continue")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                    }
                }
            }
        }
    }
}
