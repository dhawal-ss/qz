import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "Progress.js" as Progress

// One record of the board on a hairline: what it is and the day it was set (a tap there opens
// that ride), a sparkline of every time it was beaten, its value and how long it has stood.
// A tap on the row opens the full history under it.
Item {
    id: row

    property string label: ""
    property string valueText: ""
    property string dateText: ""
    property real start: 0
    property int rideId: 0
    property bool open: false
    property var history: []         // [{start, value, text}] every time it was beaten, for the sparkline
    property var steps: []           // the history, for StepChart, when open
    property string note: ""         // under the history: how often it was beaten

    signal toggle()
    signal openRide(int id)

    readonly property int days: Progress.daysBetween(start, Date.now())
    readonly property string stoodText: days <= 0 ? qsTr("Set today") : qsTr("Stood %1").arg(Progress.stood(start, Date.now()))
    readonly property bool sparkShown: history.length > 1 && width >= 350

    width: parent ? parent.width : 0
    height: 72 + (open ? detail.height : 0)
    clip: true

    Behavior on height {
        enabled: Theme.layoutMotion
        Spring { token: "default" }
    }

    // the sparkline: the record as steps from the first time it was set to today
    readonly property var sparkLine: {
        var out = []
        var n = history.length
        if (n < 2)
            return out
        var first = history[0].start
        var span = Math.max(86400000, Date.now() - first)
        var lo = history[0].value
        var hi = history[n - 1].value
        var w = spark.width
        var h = spark.height
        function yOf(v) { return h - 2 - (v - lo) / Math.max(1e-6, hi - lo) * (h - 4) }
        out.push(Qt.point(0, yOf(history[0].value)))
        for (var i = 1; i < n; i++) {
            var x = (history[i].start - first) / span * w
            out.push(Qt.point(x, yOf(history[i - 1].value)))
            out.push(Qt.point(x, yOf(history[i].value)))
        }
        out.push(Qt.point(w, yOf(history[n - 1].value)))
        return out
    }

    PulseButton {
        id: head
        width: parent.width
        height: 72
        radius: 16
        pressedScale: 0.99
        fill: pressed ? Theme.pressed : "transparent"
        Accessible.name: qsTr("%1 record, %2, %3. %4").arg(row.label).arg(row.valueText).arg(row.stoodText)
                         .arg(row.open ? qsTr("Hide its history") : qsTr("Show its history"))
        onClicked: row.toggle()
        contentItem: Item {
            Row {
                y: 14
                spacing: 8
                Text {
                    width: Math.min(implicitWidth, (row.sparkShown ? spark.x - 12 : head.width - numbers.width - 24) - (newPill.visible ? newPill.width + 8 : 0))
                    elide: Text.ElideRight
                    text: row.label
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(15)
                }
                // a record from the last two weeks
                Rectangle {
                    id: newPill
                    visible: row.days < 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: newText.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Theme.accent
                    Text {
                        id: newText
                        anchors.centerIn: parent
                        text: qsTr("New")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(11)
                    }
                }
            }

            Shape {
                id: spark
                visible: row.sparkShown
                // a fixed column, so the sparklines line up down the board
                x: head.width - Math.max(numbers.width, 128) - width - 20
                y: 22
                width: Math.min(72, head.width * 0.18)
                height: 24
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: Theme.text3
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    joinStyle: ShapePath.MiterJoin
                    PathPolyline { path: row.sparkLine }
                }
            }
            Rectangle {
                visible: row.sparkShown
                x: spark.x + spark.width - width / 2
                y: spark.y + 2 - height / 2
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
            }

            Column {
                id: numbers
                anchors.right: parent.right
                anchors.rightMargin: 4
                y: 13
                spacing: 7
                Numeral {
                    anchors.right: parent.right
                    text: row.valueText
                    color: Theme.text
                    font.pixelSize: Theme.fs(22)
                }
                Text {
                    anchors.right: parent.right
                    text: row.stoodText
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(12)
                }
            }
        }
    }

    // the day it was set: opens that ride
    PulseButton {
        id: dateButton
        x: -6
        y: 30
        width: Math.max(48, dateLabel.implicitWidth + 12)
        radius: 12
        height: 48
        // 40 to see, 48 to touch
        topInset: 4
        bottomInset: 4
        enabled: row.rideId > 0
        fill: pressed ? Theme.chip : "transparent"
        Accessible.name: qsTr("Open the ride of %1").arg(row.dateText)
        onClicked: row.openRide(row.rideId)
        contentItem: Text {
            id: dateLabel
            leftPadding: 6
            text: row.dateText
            color: row.rideId > 0 ? Theme.accent : Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(13)
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
    }

    Column {
        id: detail
        y: 72
        width: parent.width
        spacing: 6
        StepChart {
            width: parent.width
            height: 120
            steps: row.open ? row.steps : []
        }
        Text {
            width: parent.width
            text: row.note
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(12)
            wrapMode: Text.WordWrap
        }
        Item {
            width: 1
            height: 10
        }
    }

    Hairline {
        anchors.bottom: parent.bottom
        width: parent.width
    }
}
