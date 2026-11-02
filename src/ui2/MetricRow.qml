import QtQuick 2.15
import "."
import "Metrics.js" as Metrics

// One row of the ride screen: a metric as a number, a trend line or a bar.
PulseButton {
    id: row

    property var source
    property string metric: "power"
    property string kind: "number"
    property color tint: Theme.accent
    property bool selected: false
    property bool lastRow: false

    readonly property bool empty: metric === "empty"
    readonly property var info: empty ? Metrics.info("", source) : Metrics.info(metric, source)

    implicitHeight: 74
    radius: 16
    pressedRadius: 16
    pressedScale: 0.98
    fill: selected ? Qt.rgba(201 / 255, 184 / 255, 1, 0.08) : "transparent"
    Accessible.name: empty ? qsTr("Add a metric here") : qsTr("Change %1").arg(info.label) + ", " + info.value + " " + info.unit

    FontMetrics {
        id: labelMetrics
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.labelSize
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.hairline
        visible: !row.lastRow && !row.selected
    }

    // empty space
    Rectangle {
        visible: row.empty
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 50
        radius: 16
        color: "transparent"
        border.width: 1.5
        border.color: Theme.dashed
        Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: "+"
                color: Theme.accent
                font.family: Theme.bodySemibold
                font.pixelSize: 20
                anchors.verticalCenter: parent.verticalCenter
                Accessible.ignored: true
            }
            Text {
                text: qsTr("Add metric")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // label and its quiet tag
    Column {
        visible: !row.empty
        anchors { left: parent.left; leftMargin: row.selected ? 12 : 0 }
        // label baseline on the value baseline, except next to a trend line
        y: row.kind === "trend" ? (row.height - height) / 2 : value.y + big.height - labelMetrics.ascent
        spacing: 2
        Row {
            spacing: 6
            Text {
                text: row.info.label
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
            }
            Text {
                visible: row.kind !== "trend" && text !== ""
                text: row.info.tag
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }
        Text {
            visible: row.kind === "trend" && text !== ""
            text: row.info.tag
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
        }
    }

    // the value
    Row {
        id: value
        visible: !row.empty
        anchors { right: parent.right; rightMargin: row.selected ? 12 : 0 }
        y: row.kind === "bar" ? 16 : (row.height - big.height) / 2
        spacing: 5
        Numeral {
            id: big
            text: row.info.value
            color: Theme.text
            font.pixelSize: row.kind === "number" ? 36 : 30
            font.letterSpacing: -1
        }
        Text {
            visible: row.kind !== "trend" && text !== ""
            text: row.info.unit
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
            anchors.baseline: big.baseline
        }
    }

    Sparkline {
        visible: row.kind === "trend" && !row.empty
        width: 96
        height: 30
        anchors { right: value.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
        color: row.tint
        values: row.source && row.info.trail !== "" ? row.source[row.info.trail] : []
    }

    Rectangle {
        visible: row.kind === "bar" && !row.empty
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 14 }
        anchors.leftMargin: row.selected ? 12 : 0
        anchors.rightMargin: row.selected ? 12 : 0
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.08)
        Rectangle {
            height: parent.height
            radius: 2
            color: row.tint
            width: parent.width * Math.max(0, Math.min(1, row.info.frac || 0))
            Behavior on width {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
            }
        }
    }
}
