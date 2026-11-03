import QtQuick 2.15
import ".."
import "../sig"

// One more moment of the ride under the hero, as a quiet row on a hairline: its small Pulse, what
// it is and what it means on the left, the number on the right. A row that arrives rises in
// after `delay` ms on the default spring, so late records land one by one.
Item {
    id: card

    property string title: ""
    property string detail: ""
    property string value: ""
    property string unit: ""
    property int tone: 1
    property bool arrive: false
    property int delay: 0
    property bool line: true

    readonly property color tint: Theme.zoneColors[tone - 1]

    implicitHeight: Math.max(64, Math.max(words.height, number.height) + 28)
    Accessible.role: Accessible.StaticText
    Accessible.name: title + ", " + value + (unit !== "" ? " " + unit : "") + (detail !== "" ? ". " + detail : "")

    property real progress: 1
    opacity: Math.max(0, Math.min(1, progress))
    transform: Translate { y: (1 - card.progress) * Theme.riseDistance * 2 }

    Component.onCompleted: {
        if (arrive && !Theme.reduceMotion)
            enter.start()
    }

    SequentialAnimation {
        id: enter
        PropertyAction { target: card; property: "progress"; value: 0 }
        PauseAnimation { duration: card.delay }
        NumberAnimation {
            target: card; property: "progress"; to: 1; duration: Theme.riseTime
            easing.type: Easing.Bezier; easing.bezierCurve: Theme.defaultSpatialCurve
        }
    }

    Pulse {
        id: mark
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        zone: card.tone
        color: card.tint
    }

    Column {
        id: words
        x: 44
        width: card.width - x - number.width - 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Accessible.ignored: true
        Text {
            width: parent.width
            text: card.title
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: 15
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: card.detail
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 13
            lineHeightMode: Text.FixedHeight
            lineHeight: 18
            wrapMode: Text.WordWrap
            visible: text !== ""
        }
    }

    Row {
        id: number
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Accessible.ignored: true
        Numeral {
            id: big
            text: card.value
            color: Theme.text
            font.pixelSize: 24
        }
        Text {
            text: card.unit
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 13
            anchors.baseline: big.baseline
            visible: text !== ""
        }
    }

    Hairline {
        visible: card.line
        anchors.bottom: parent.bottom
        width: parent.width
    }
}
