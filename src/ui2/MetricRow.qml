import QtQuick 2.15
import "."
import "sig"
import "Metrics.js" as Metrics

// One row of the ride screen: a metric as a number, a trend line or a bar.
// Picked for a swap, the row lifts (default spatial spring) and wears the accent outline; a new
// metric rolls in: the old value moves up and out of the row as the new one rolls in from below
// (fast spatial spring) while the label crosses over.
PulseButton {
    id: row

    property var source
    property string metric: "power"
    property string kind: "number"
    property color tint: Theme.accent
    property bool selected: false
    property bool lastRow: false
    // off while the screen is still loading its saved layout, so nothing rolls on open
    property bool animate: true

    readonly property bool empty: metric === "empty"
    readonly property var info: empty ? Metrics.info("", source) : Metrics.info(metric, source)

    // the metric showing before a swap, to roll it out
    property string shownMetric: ""
    property string ghostValue: ""
    property string ghostUnit: ""
    property string ghostLabel: ""

    // the lift of a picked row
    property real lift: selected ? 1.03 : 1
    Behavior on lift {
        enabled: !Theme.reduceMotion
        Spring { token: "default"; epsilon: 0.002 }
    }
    transform: Scale {
        origin.x: row.width / 2
        origin.y: row.height / 2
        xScale: row.lift
        yScale: row.lift
    }

    implicitHeight: 74
    radius: 16
    pressedRadius: 16
    pressedScale: 0.98
    fill: selected ? Qt.rgba(42 / 255, 36 / 255, 64 / 255, 1) : "transparent"
    Accessible.name: empty ? qsTr("Add a metric here") : qsTr("Change %1").arg(info.label) + ", " + info.value + " " + info.unit

    Component.onCompleted: shownMetric = metric
    onMetricChanged: {
        if (animate && shownMetric !== "" && shownMetric !== metric && !Theme.reduceMotion) {
            var before = shownMetric === "empty" ? null : Metrics.info(shownMetric, source)
            ghostLabel = before ? before.label : ""
            ghostValue = before ? before.value : ""
            ghostUnit = before && kind !== "trend" ? before.unit : ""
            rollAnimation.restart()
        }
        shownMetric = metric
    }

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

    // the accent outline of a picked row
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: row.selected ? 1 : 0
        Behavior on opacity {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        }
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
                font.pixelSize: Theme.fs(20)
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

    // label and its quiet tag, and the label of the metric before, crossing over
    Text {
        id: ghostLabelText
        x: labelColumn.x
        y: labelColumn.y
        opacity: 0
        text: row.ghostLabel
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.labelSize
    }
    Column {
        id: labelColumn
        visible: !row.empty
        anchors { left: parent.left; leftMargin: row.selected ? 12 : 0 }
        // label baseline on the value baseline, except next to a trend line
        y: row.kind === "trend" ? (row.height - height) / 2 : valueBox.y + big.height - labelMetrics.ascent
        spacing: 2
        Row {
            spacing: 6
            Text {
                text: row.info.label
                color: row.selected ? Theme.text : Theme.text2
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

    // the value, in a window the old and new values roll through
    Item {
        id: valueBox
        anchors { right: parent.right; rightMargin: row.selected ? 12 : 0 }
        y: row.kind === "bar" ? 16 : (row.height - big.height) / 2
        width: Math.max(value.width, ghostRow.opacity > 0 ? ghostRow.width : 0)
        // room under the baseline for the descenders of the unit
        height: big.height + 8
        clip: true

        Row {
            id: ghostRow
            anchors.right: parent.right
            spacing: 5
            opacity: 0
            transform: Translate { id: ghostShift }
            Numeral {
                id: ghostBig
                text: row.ghostValue
                color: Theme.text
                font.pixelSize: big.font.pixelSize
                font.letterSpacing: -1
            }
            Text {
                visible: text !== ""
                text: row.ghostUnit
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
                anchors.baseline: ghostBig.baseline
            }
        }
        Row {
            id: value
            visible: !row.empty
            anchors.right: parent.right
            spacing: 5
            transform: Translate { id: valueShift }
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
    }

    Sparkline {
        visible: row.kind === "trend" && !row.empty
        width: 96
        height: 30
        anchors { right: valueBox.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
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

    // the roll: the value moves a full row height, the labels cross over on the effects curve
    ParallelAnimation {
        id: rollAnimation
        NumberAnimation { target: ghostShift; property: "y"; from: 0; to: -valueBox.height; duration: Theme.fastSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.fastSpatialCurve }
        NumberAnimation { target: ghostRow; property: "opacity"; from: 1; to: 0; duration: Theme.fastSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        NumberAnimation { target: valueShift; property: "y"; from: valueBox.height; to: 0; duration: Theme.fastSpatialTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.fastSpatialCurve }
        NumberAnimation { target: value; property: "opacity"; from: 0; to: 1; duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        NumberAnimation { target: ghostLabelText; property: "opacity"; from: 1; to: 0; duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        NumberAnimation { target: labelColumn; property: "opacity"; from: 0; to: 1; duration: Theme.effectsTime * 2; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
    }
}
