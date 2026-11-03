import QtQuick 2.15
import ".."

// The row above a stack of charts. With the crosshair shown it reads every metric at that
// moment; without it, it says which part of the ride the charts show, with a way back to all
// of it. It keeps one height, so the page does not jump while scrubbing.
Item {
    id: readout

    property ChartView view: null
    property var samples: ({})
    property bool miles: false
    property bool heart: true
    property bool cadence: true
    property bool speed: false
    property bool level: false

    // three values a row on a phone, all six in one row on a wider window
    readonly property int columns: width < 480 ? 3 : 6
    implicitHeight: columns === 3 ? 88 : 48

    readonly property bool scrubbing: view !== null && view.cursor >= 0

    // the sample closest to the crosshair
    readonly property int at: {
        var s = samples.seconds || []
        if (!scrubbing || s.length === 0)
            return -1
        var t = view.cursor * view.duration
        var a = 0
        var b = s.length
        while (a < b) {
            var m = Math.floor((a + b) / 2)
            if (s[m] < t)
                a = m + 1
            else
                b = m
        }
        var i = Math.min(s.length - 1, a)
        if (i > 0 && t - s[i - 1] < s[i] - t)
            i--
        return i
    }

    function sampleAt(key) {
        var list = samples[key] || []
        return at >= 0 && at < list.length ? list[at] : 0
    }

    readonly property var cells: {
        if (at < 0)
            return []
        var list = [[view.clock(view.cursor * view.duration), qsTr("Time")],
                    [Math.round(sampleAt("power")) + " W", qsTr("Power")]]
        if (heart)
            list.push([sampleAt("heart") > 0 ? Math.round(sampleAt("heart")) + " bpm" : "-", qsTr("Heart rate")])
        if (cadence)
            list.push([Math.round(sampleAt("cadence")) + " rpm", qsTr("Cadence")])
        if (level)
            list.push([String(Math.round(sampleAt("level"))), qsTr("Level")])
        if (speed)
            list.push([(sampleAt("speed") * (miles ? 0.621371 : 1)).toFixed(1) + (miles ? " mph" : " km/h"), qsTr("Speed")])
        return list
    }

    // values at the crosshair
    Grid {
        id: values
        visible: readout.scrubbing
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        columns: readout.columns
        rowSpacing: 8
        Repeater {
            // a count, so moving the crosshair updates the texts instead of rebuilding them
            model: readout.cells.length
            Column {
                id: cell
                width: values.width / readout.columns
                spacing: 2
                Text {
                    width: cell.width - 4
                    text: (readout.cells[index] || ["", ""])[0]
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 18
                    elide: Text.ElideRight
                }
                Text {
                    width: cell.width - 4
                    text: (readout.cells[index] || ["", ""])[1]
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }

    // which part of the ride is shown
    Column {
        visible: !readout.scrubbing
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (resetButton.visible ? resetButton.width + 12 : 0)
        spacing: 2
        Text {
            width: parent.width
            text: readout.view && readout.view.zoomed
                  ? qsTr("%1 to %2").arg(readout.view.clock(Math.max(0, readout.view.viewStart) * readout.view.duration))
                                    .arg(readout.view.clock(Math.min(1, readout.view.viewEnd) * readout.view.duration))
                  : qsTr("Whole ride")
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.bodySize
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: readout.view && readout.view.zoomed
                  ? qsTr("Drag to move along the ride")
                  : qsTr("Drag across a chart to read it, pinch to zoom in")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.tertiarySize
            elide: Text.ElideRight
        }
    }

    PulseButton {
        id: resetButton
        visible: !readout.scrubbing && readout.view !== null && readout.view.zoomed
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: resetText.implicitWidth + 32
        height: 40
        fill: pressed ? Theme.pressed : Theme.chip
        Accessible.name: qsTr("Reset zoom")
        onClicked: readout.view.reset()
        contentItem: Text {
            id: resetText
            text: qsTr("Reset")
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.labelSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
