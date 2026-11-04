import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../Format.js" as Format

// The laps of a ride. A strip of the whole ride split into laps picks one out; under it the laps
// show as bars of their average power, as a table against the ride average, or as power lines
// laid over each other from their own start (pacing). Pacing needs the full 1 Hz samples.
// Quiet structure: no box, hairlines and a connected switch; `titled: false` leaves the title
// to the page.
Item {
    id: laps

    property var ride: ({})
    property var samples: ({})
    property bool miles: false
    // "bars", "table" or "pacing"
    property string view: "bars"
    property int selectedLap: -1
    property bool titled: true

    // a lap of the strip was tapped; -1 when the tap let it go again
    signal lapSelected(int index)

    readonly property var lapList: ride && ride.laps ? ride.laps : []
    readonly property bool hasLaps: lapList.length > 1
    readonly property real ftp: ride && ride.ftp > 0 ? ride.ftp : 200

    // the laps can leave out paused time, so widths go by the sum of the laps, not the ride
    readonly property real lapSeconds: {
        var sum = 0
        for (var i = 0; i < lapList.length; i++)
            sum += lapList[i].duration
        return sum
    }

    // the strongest lap of a minute or more; a short sprint lap only wins when all are short
    readonly property int bestLap: {
        var best = -1
        for (var pass = 0; pass < 2 && best < 0; pass++) {
            for (var i = 0; i < lapList.length; i++) {
                if (pass === 0 && lapList[i].duration < 60)
                    continue
                if (best < 0 || lapList[i].avgPower > lapList[best].avgPower)
                    best = i
            }
        }
        return best
    }

    readonly property real topLapPower: {
        var hi = 0
        for (var i = 0; i < lapList.length; i++)
            hi = Math.max(hi, lapList[i].avgPower)
        return hi
    }

    // pacing reads the laps out of the 1 Hz samples: lap start and duration count samples
    readonly property bool hasPacing: {
        if (lapList.length < 2 || !samples || !samples.power)
            return false
        var last = lapList[lapList.length - 1]
        return samples.power.length >= last.start + last.duration
    }

    readonly property string shownView: view === "pacing" && !hasPacing ? "bars" : view

    implicitHeight: hasLaps ? card.implicitHeight : 0
    visible: hasLaps

    onRideChanged: selectedLap = -1

    function zoneOf(lap) {
        return Theme.powerZone(lap.avgPower, ftp)
    }

    // the zone of a lap comes from FTP: the accent for every lap until it is set (Theme.ftpSet)
    function zoneColor(lap) {
        return Theme.ftpSet ? Theme.zoneColors[zoneOf(lap) - 1] : Theme.accent
    }

    // x and width of every lap in a row of the given width: each lap gets a minimum, the rest is
    // shared by duration, so the row always fills the width exactly
    function spans(width, minWanted, gap) {
        var n = lapList.length
        var out = []
        if (n === 0 || width <= 0)
            return out
        gap = Math.min(gap, width / n / 3)
        var room = width - gap * (n - 1)
        var least = Math.min(minWanted, room / n)
        var rest = room - least * n
        var x = 0
        for (var i = 0; i < n; i++) {
            var w = least + (lapSeconds > 0 ? rest * lapList[i].duration / lapSeconds : rest / n)
            out.push({ x: x, w: w })
            x += w + gap
        }
        return out
    }

    function signed(v) {
        var r = Math.round(v)
        return r > 0 ? "+" + r : String(r)
    }

    // warm when the lap was harder than the reference, cool when easier
    function deltaColor(v) {
        var r = Math.round(v)
        return r > 0 ? Theme.zoneColors[4] : (r < 0 ? Theme.zoneColors[0] : Theme.text3)
    }

    function lapName(i) {
        return qsTr("Lap %1").arg(i + 1)
    }

    function lapLine(i) {
        var lap = lapList[i]
        var line = lapName(i) + "  ·  " + Format.duration(lap.duration) + "  ·  " + Math.round(lap.avgPower) + " W"
        // the zone needs the rider's own FTP (Theme.ftpSet)
        if (Theme.ftpSet)
            line += "  ·  Z" + zoneOf(lap) + " " + Theme.powerZoneNames[zoneOf(lap) - 1]
        return line
    }

    // round the top of the scale up to a value that reads well, as AreaChart does
    function niceTop(v) {
        var steps = [100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 1500, 2000]
        for (var i = 0; i < steps.length; i++)
            if (v <= steps[i])
                return steps[i]
        return Math.ceil(v / 500) * 500
    }

    // every lap's power from its own start, averaged into about 120 points: [{t, w}, ...];
    // a lap under 30 s (a sprint) stays out, it would only be a blip on the time axis
    readonly property var pacingLines: {
        var out = []
        if (!hasPacing)
            return out
        var power = samples.power
        for (var i = 0; i < lapList.length; i++) {
            var lap = lapList[i]
            var size = Math.max(1, Math.ceil(lap.duration / 120))
            var line = []
            if (lap.duration < 30) {
                out.push(line)
                continue
            }
            for (var from = 0; from < lap.duration; from += size) {
                var to = Math.min(lap.duration, from + size)
                var sum = 0
                for (var k = from; k < to; k++)
                    sum += power[lap.start + k] || 0
                line.push({ t: (from + to) / 2, w: sum / (to - from) })
            }
            out.push(line)
        }
        return out
    }

    readonly property real pacingSeconds: {
        var hi = 1
        for (var i = 0; i < pacingLines.length; i++)
            if (pacingLines[i].length > 0)
                hi = Math.max(hi, lapList[i].duration)
        return hi
    }

    readonly property real pacingTop: {
        var hi = 1
        for (var i = 0; i < pacingLines.length; i++)
            for (var k = 0; k < pacingLines[i].length; k++)
                hi = Math.max(hi, pacingLines[i][k].w)
        return niceTop(hi)
    }

    // best lap in the accent, the picked lap in its zone, the latest strong, the first faint
    function lineColor(i) {
        var n = lapList.length
        if (i === bestLap)
            return Theme.accent
        if (i === selectedLap)
            return zoneColor(lapList[i])
        var a = i === n - 1 ? 0.92 : 0.22 + 0.3 * i / Math.max(1, n - 1)
        if (selectedLap >= 0 && i !== n - 1)
            a = a * 0.6
        return Qt.rgba(1, 1, 1, a)
    }

    function lineWidth(i) {
        return i === bestLap || i === selectedLap || i === lapList.length - 1 ? 2.25 : 1.5
    }

    function lineDepth(i) {
        if (i === selectedLap)
            return 4
        if (i === bestLap)
            return 3
        return i === lapList.length - 1 ? 2 : 1
    }

    readonly property var pacingLegend: {
        var n = lapList.length
        var out = [{ color: lineColor(0), label: lapName(0) + (bestLap === 0 ? ", " + qsTr("best") : "") }]
        var last = lapName(n - 1) + ", " + qsTr("latest") + (bestLap === n - 1 ? ", " + qsTr("best") : "")
        out.push({ color: lineColor(n - 1), label: last })
        if (bestLap > 0 && bestLap < n - 1)
            out.push({ color: lineColor(bestLap), label: lapName(bestLap) + ", " + qsTr("best") })
        if (selectedLap > 0 && selectedLap < n - 1 && selectedLap !== bestLap)
            out.push({ color: lineColor(selectedLap), label: lapName(selectedLap) })
        return out
    }

    readonly property string barsSummary: {
        var parts = []
        for (var i = 0; i < lapList.length; i++)
            parts.push(lapName(i) + " " + Math.round(lapList[i].avgPower) + " W")
        return qsTr("Average power of each lap: %1").arg(parts.join(", "))
    }

    Column {
        id: card
        width: parent.width
        spacing: 14

        Item {
            visible: laps.titled
            width: parent.width
            height: 20
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Laps")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.titleSize
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("%1 laps").arg(laps.lapList.length)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }

        // the whole ride as one strip, a tap picks a lap out in every view
        Item {
            id: ribbon
            width: parent.width
            height: 48
            readonly property var parts: laps.spans(width, 14, 3)

            Repeater {
                model: laps.lapList.length
                PulseButton {
                    id: segment
                    readonly property var lap: laps.lapList[index]
                    readonly property bool picked: laps.selectedLap === index
                    x: ribbon.parts[index] ? ribbon.parts[index].x : 0
                    width: ribbon.parts[index] ? ribbon.parts[index].w : 0
                    height: ribbon.height
                    radius: 8
                    pressedScale: 1
                    Accessible.name: qsTr("Lap %1, %2, %3 watts").arg(index + 1).arg(Format.duration(segment.lap.duration))
                                     .arg(Math.round(segment.lap.avgPower))
                    Accessible.checkable: true
                    Accessible.checked: segment.picked
                    onClicked: {
                        laps.selectedLap = segment.picked ? -1 : index
                        laps.lapSelected(laps.selectedLap)
                    }
                    contentItem: Item {
                        Rectangle {
                            id: strip
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: segment.picked ? 36 : 26
                            radius: 7
                            color: laps.zoneColor(segment.lap)
                            opacity: laps.selectedLap < 0 || segment.picked ? 1 : 0.32
                            Behavior on height {
                                enabled: !Theme.reduceMotion
                                NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                            }
                            Behavior on opacity {
                                enabled: !Theme.reduceMotion
                                NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: implicitWidth + 6 <= strip.width
                                text: index + 1
                                color: Theme.bg
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(12)
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 16
            Text {
                width: parent.width - total.implicitWidth - 12
                anchors.verticalCenter: parent.verticalCenter
                text: laps.selectedLap >= 0 && laps.selectedLap < laps.lapList.length
                      ? laps.lapLine(laps.selectedLap) : qsTr("Tap a lap to pick it out")
                color: laps.selectedLap >= 0 ? Theme.text : Theme.text3
                font.family: laps.selectedLap >= 0 ? Theme.bodySemibold : Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
                elide: Text.ElideRight
            }
            Text {
                id: total
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Format.duration(laps.lapSeconds)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(11)
            }
        }

        // which view: a connected switch
        SegmentedToggle {
            id: switcher
            readonly property var keys: laps.hasPacing ? ["bars", "table", "pacing"] : ["bars", "table"]
            width: Math.min(parent.width, keys.length * 96)
            height: 40
            options: laps.hasPacing ? [qsTr("Bars"), qsTr("Table"), qsTr("Pacing")] : [qsTr("Bars"), qsTr("Table")]
            currentIndex: Math.max(0, keys.indexOf(laps.shownView))
            name: qsTr("Show laps as")
            onPicked: laps.view = keys[index]
        }

        // bars: height by average power, width by duration, tinted by zone
        Item {
            id: barsView
            visible: laps.shownView === "bars"
            width: parent.width
            height: width < 520 ? 196 : 232
            Accessible.role: Accessible.Graphic
            Accessible.name: laps.barsSummary

            readonly property var parts: laps.spans(width, 16, 4)
            readonly property real scaleTop: Math.max(laps.topLapPower, laps.ftp) * 1.08

            Item {
                id: barPlot
                y: 26
                width: parent.width
                height: parent.height - 26 - 40

                // FTP as a faint reference line over the bars
                Rectangle {
                    z: 2
                    width: barPlot.width
                    height: 1
                    y: Math.round(barPlot.height * (1 - laps.ftp / barsView.scaleTop))
                    color: Qt.rgba(1, 1, 1, 0.28)
                }

                Repeater {
                    model: laps.lapList.length
                    Item {
                        id: barSlot
                        readonly property var lap: laps.lapList[index]
                        x: barsView.parts[index] ? barsView.parts[index].x : 0
                        width: barsView.parts[index] ? barsView.parts[index].w : 0
                        height: barPlot.height

                        Rectangle {
                            id: bar
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(4, barPlot.height * barSlot.lap.avgPower / barsView.scaleTop)
                            radius: Math.min(width / 2, 8)
                            color: laps.zoneColor(barSlot.lap)
                            opacity: laps.selectedLap < 0 || laps.selectedLap === index ? 1 : 0.32
                            Behavior on height {
                                enabled: !Theme.reduceMotion
                                NumberAnimation { duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
                            }
                            Behavior on opacity {
                                enabled: !Theme.reduceMotion
                                NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 6
                                visible: implicitWidth + 6 <= bar.width && bar.height >= implicitHeight + 10
                                text: Math.round(barSlot.lap.avgPower)
                                color: Theme.bg
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.fs(12)
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 5
                            visible: implicitWidth <= barSlot.width + 4
                            text: index + 1
                            color: index === laps.selectedLap ? Theme.text : Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(11)
                        }
                    }
                }

                // the best lap, marked over its bar (declared after the bars, so drawn over them)
                Rectangle {
                    id: bestMark
                    z: 3
                    visible: laps.bestLap >= 0 && barsView.parts.length > laps.bestLap
                    readonly property var part: barsView.parts[laps.bestLap] || { x: 0, w: 0 }
                    readonly property real barTop: barPlot.height
                                                   - Math.max(4, barPlot.height * (laps.lapList[laps.bestLap] ? laps.lapList[laps.bestLap].avgPower : 0) / barsView.scaleTop)
                    width: bestText.implicitWidth + 14
                    height: 20
                    radius: 10
                    x: Math.max(0, Math.min(barPlot.width - width, part.x + part.w / 2 - width / 2))
                    y: barTop - height - 4
                    color: Theme.accentWash(0.16)
                    Text {
                        id: bestText
                        anchors.centerIn: parent
                        text: qsTr("Best")
                        color: Theme.accent
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(11)
                    }
                }
            }

            // what the line is
            Row {
                anchors.bottom: parent.bottom
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.5)
                }
                Text {
                    text: qsTr("FTP %1 W").arg(Math.round(laps.ftp))
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(11)
                }
            }
        }

        // table: every lap against the ride average, and the lap before on wide screens
        Column {
            id: table
            visible: laps.shownView === "table"
            width: parent.width
            spacing: 2

            readonly property bool wide: width >= 560
            readonly property real numberWidth: 34
            readonly property real wantWidth: wide ? 104 : 62
            readonly property bool anyHr: {
                for (var i = 0; i < laps.lapList.length; i++)
                    if (laps.lapList[i].avgHr > 0)
                        return true
                return false
            }
            readonly property bool anyCadence: {
                for (var i = 0; i < laps.lapList.length; i++)
                    if (laps.lapList[i].avgCadence > 0)
                        return true
                return false
            }
            // most wanted first; columns that do not fit are left out, from the end
            readonly property var columns: {
                var wanted = ["time", "power"]
                if (anyHr)
                    wanted.push("hr")
                if (anyCadence)
                    wanted.push("cadence")
                wanted.push("distance")
                var fit = Math.max(2, Math.floor((width - numberWidth) / wantWidth))
                return wanted.slice(0, fit)
            }
            readonly property real cellWidth: (width - numberWidth) / Math.max(1, columns.length)

            function heading(key) {
                if (key === "time")
                    return qsTr("Time")
                if (key === "power")
                    return qsTr("Power")
                if (key === "hr")
                    return wide ? qsTr("Heart rate") : qsTr("HR")
                if (key === "cadence")
                    return qsTr("Cadence")
                return qsTr("Distance")
            }

            // [number, unit]: the unit is set smaller, so four columns fit a 360 wide phone
            function value(key, lap) {
                if (key === "time")
                    return [Format.duration(lap.duration), ""]
                if (key === "power")
                    return [String(Math.round(lap.avgPower)), "W"]
                if (key === "hr")
                    return lap.avgHr > 0 ? [String(Math.round(lap.avgHr)), "bpm"] : ["-", ""]
                if (key === "cadence")
                    return lap.avgCadence > 0 ? [String(Math.round(lap.avgCadence)), "rpm"] : ["-", ""]
                return Format.distance(lap.distance, laps.miles).split(" ")
            }

            // the metric of a lap and of the ride, for the deltas; time and distance have none
            function metric(key, item) {
                if (!item)
                    return 0
                if (key === "power")
                    return item.avgPower || 0
                if (key === "hr")
                    return item.avgHr || 0
                if (key === "cadence")
                    return item.avgCadence || 0
                return 0
            }

            // the small line under a value: start and speed where a delta means nothing
            function note(key, i) {
                var lap = laps.lapList[i]
                // lap start counts samples; the clock of that sample also counts paused time
                if (key === "time") {
                    var clock = laps.samples && laps.samples.seconds && laps.samples.seconds.length > lap.start
                                ? laps.samples.seconds[lap.start] : lap.start
                    return qsTr("at %1").arg(Format.duration(clock))
                }
                if (key === "distance") {
                    var kmh = lap.duration > 0 ? lap.distance * 3600 / lap.duration : 0
                    return laps.miles ? (kmh * 0.621371).toFixed(1) + " mph" : kmh.toFixed(1) + " km/h"
                }
                return ""
            }

            Row {
                width: parent.width
                height: 26
                Text {
                    width: table.numberWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "#"
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.tertiarySize
                    Accessible.ignored: true
                }
                Repeater {
                    model: table.columns
                    Text {
                        width: table.cellWidth
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 6
                        text: table.heading(modelData)
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }
            }

            Repeater {
                model: laps.lapList.length
                Rectangle {
                    id: lapRow
                    readonly property var lap: laps.lapList[index]
                    readonly property int lapIndex: index
                    width: table.width
                    height: 48
                    radius: 12
                    color: laps.selectedLap === index ? Theme.chip : "transparent"

                    Row {
                        anchors.fill: parent
                        Item {
                            width: table.numberWidth
                            height: parent.height
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 4
                                width: 3
                                height: 22
                                radius: 1.5
                                color: laps.zoneColor(lapRow.lap)
                            }
                            Text {
                                x: 13
                                anchors.verticalCenter: parent.verticalCenter
                                text: lapRow.lapIndex + 1
                                color: lapRow.lapIndex === laps.bestLap ? Theme.accent : Theme.text2
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.labelSize
                            }
                        }
                        Repeater {
                            model: table.columns
                            Column {
                                id: tableCell
                                readonly property string key: modelData
                                readonly property real mine: table.metric(key, lapRow.lap)
                                readonly property real average: table.metric(key, laps.ride)
                                readonly property real before: lapRow.lapIndex > 0 ? table.metric(key, laps.lapList[lapRow.lapIndex - 1]) : 0
                                width: table.cellWidth
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Row {
                                    readonly property var parts: table.value(tableCell.key, lapRow.lap)
                                    anchors.right: parent.right
                                    spacing: 3
                                    Text {
                                        text: parent.parts[0]
                                        color: Theme.text
                                        font.family: Theme.bodySemibold
                                        font.pixelSize: Theme.fs(14)
                                    }
                                    Text {
                                        anchors.baseline: parent.children[0].baseline
                                        visible: text !== ""
                                        text: parent.parts[1] || ""
                                        color: Theme.text3
                                        font.family: Theme.bodyMedium
                                        font.pixelSize: Theme.fs(11)
                                    }
                                }
                                Row {
                                    anchors.right: parent.right
                                    spacing: 6
                                    Text {
                                        visible: text !== ""
                                        text: tableCell.mine > 0 && tableCell.average > 0 ? laps.signed(tableCell.mine - tableCell.average)
                                                                                          : table.note(tableCell.key, lapRow.lapIndex)
                                        color: tableCell.mine > 0 && tableCell.average > 0 ? laps.deltaColor(tableCell.mine - tableCell.average)
                                                                                           : Theme.text3
                                        font.family: Theme.bodyMedium
                                        font.pixelSize: Theme.fs(11)
                                    }
                                    Text {
                                        visible: table.wide && tableCell.mine > 0 && tableCell.before > 0
                                        text: laps.signed(tableCell.mine - tableCell.before)
                                        color: Theme.text3
                                        font.family: Theme.bodyMedium
                                        font.pixelSize: Theme.fs(11)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                topPadding: 6
                text: table.wide ? qsTr("Small figures: the change from the ride average, then from the lap before")
                                 : qsTr("Small figures: the change from the ride average")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(11)
                wrapMode: Text.WordWrap
            }
        }

        // pacing: every lap's power from its own start on one time axis
        Column {
            id: pacingView
            visible: laps.shownView === "pacing"
            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: width < 520 ? 176 : 216
                Accessible.role: Accessible.Graphic
                Accessible.name: laps.hasPacing
                                 ? qsTr("Power of every lap from its own start. First lap %1 W, latest lap %2 W, best lap %3 at %4 W")
                                   .arg(Math.round(laps.lapList[0].avgPower))
                                   .arg(Math.round(laps.lapList[laps.lapList.length - 1].avgPower))
                                   .arg(laps.bestLap + 1)
                                   .arg(Math.round(laps.lapList[Math.max(0, laps.bestLap)].avgPower))
                                 : ""

                Item {
                    id: pacePlot
                    y: 18
                    width: parent.width
                    height: parent.height - 18

                    Repeater {
                        model: 3
                        Rectangle {
                            width: pacePlot.width
                            height: 1
                            y: Math.round(index * (pacePlot.height - 1) / 2)
                            color: Theme.hairline
                        }
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.samples: 4
                        Repeater {
                            model: laps.pacingLines.length
                            Shape {
                                id: paceShape
                                readonly property var line: laps.pacingLines[index] || []
                                anchors.fill: parent
                                z: laps.lineDepth(index)
                                ShapePath {
                                    strokeColor: laps.lineColor(index)
                                    strokeWidth: laps.lineWidth(index)
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.RoundJoin
                                    capStyle: ShapePath.RoundCap
                                    PathPolyline {
                                        path: {
                                            var list = []
                                            var src = paceShape.line
                                            for (var k = 0; k < src.length; k++)
                                                list.push(Qt.point(pacePlot.width * src[k].t / laps.pacingSeconds,
                                                                   pacePlot.height * (1 - Math.min(src[k].w, laps.pacingTop) / laps.pacingTop)))
                                            return list
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        y: -17
                        text: laps.pacingTop + " W"
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.fs(11)
                    }
                }
            }

            Item {
                width: parent.width
                height: 14
                Text {
                    text: "0:00"
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(11)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Format.duration(laps.pacingSeconds / 2)
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(11)
                }
                Text {
                    anchors.right: parent.right
                    text: Format.duration(laps.pacingSeconds)
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(11)
                }
            }

            Flow {
                width: parent.width
                spacing: 16
                Repeater {
                    model: laps.pacingLegend
                    Row {
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 3
                            radius: 1.5
                            color: modelData.color
                        }
                        Text {
                            text: modelData.label
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.tertiarySize
                        }
                    }
                }
            }
        }
    }
}
