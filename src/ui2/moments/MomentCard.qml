import QtQuick 2.15
import ".."

// One more moment of the ride under the hero: its Pulse, the number and what it means.
// A card that arrives slides in after `delay` ms, so late records land one by one.
Rectangle {
    id: card

    property string title: ""
    property string detail: ""
    property string value: ""
    property string unit: ""
    property int tone: 1
    property bool arrive: false
    property int delay: 0

    readonly property color tint: Theme.zoneColors[tone - 1]

    implicitHeight: Math.max(80, words.height + 36)
    radius: 24
    color: Theme.card
    border.width: 1
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.18)
    transform: Translate { id: slide }

    Component.onCompleted: {
        if (arrive && !Theme.reduceMotion) {
            opacity = 0
            enter.start()
        }
    }

    SequentialAnimation {
        id: enter
        PauseAnimation { duration: card.delay }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.medium }
            NumberAnimation {
                target: slide; property: "y"; from: 28; to: 0; duration: Theme.slow
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
            }
            NumberAnimation {
                target: card; property: "scale"; from: 0.94; to: 1; duration: Theme.slow
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve
            }
        }
    }

    PulseShape {
        id: mark
        x: 16
        y: 20
        width: 40
        height: 40
        zone: card.tone
        color: card.tint
    }

    // the number first, then what it means
    Column {
        id: words
        x: 72
        width: card.width - x - 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Row {
            spacing: 5
            Numeral {
                id: number
                text: card.value
                color: Theme.zoneLight[card.tone - 1]
                font.pixelSize: 28
            }
            Text {
                text: card.unit
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
                anchors.baseline: number.baseline
                visible: text !== ""
            }
        }
        Item { width: 1; height: 2 }
        Text {
            width: parent.width
            text: card.title
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.bodySize
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: card.detail
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
            wrapMode: Text.WordWrap
            visible: text !== ""
        }
    }
}
