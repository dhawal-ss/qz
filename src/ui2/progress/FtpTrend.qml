import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "Hub.js" as Hub

// FTP as steps over the months: the rider's FTP setting is not kept over time, so each month gets
// an estimate, 95% of the best 20 minutes of the 90 days up to its end (Hub.ftpSteps), marked
// "est.". A step up shows each month the estimate rose; the latest is the big number.
Column {
    id: ftp
    objectName: "ftpTrend"

    property var library: null
    property string period: "3m"
    property bool pro: false
    property real setting: 0         // the FTP setting, 0 when unknown

    property var steps: []           // [{start, value}] one a month, Hub.ftpSteps()
    readonly property var changes: Hub.ftpChanges(steps)
    readonly property real current: changes.length > 0 ? changes[changes.length - 1].value : 0
    readonly property var firstStep: changes.length > 0 ? changes[0] : null
    readonly property real from: steps.length > 0 ? steps[0].start : Date.now()
    readonly property real span: Math.max(Hub.dayMs, Date.now() - from)
    readonly property real lo: {
        var v = current
        for (var i = 0; i < changes.length; i++)
            v = Math.min(v, changes[i].value)
        return v * 0.96
    }
    readonly property real hi: {
        var v = current
        for (var i = 0; i < changes.length; i++)
            v = Math.max(v, changes[i].value)
        return Math.max(v * 1.02, lo + 10)
    }

    function refresh() {
        if (!library) {
            steps = []
            return
        }
        var starts = Hub.monthStarts(Date.now(), Hub.ftpMonths(period))
        var best = []
        for (var i = 0; i < starts.length; i++) {
            var s = new Date(starts[i])
            var end = i === starts.length - 1 ? 0 : new Date(s.getFullYear(), s.getMonth() + 1, 1).getTime()
            var endMs = end > 0 ? end : Date.now()
            var curve = library.powerCurve(endMs - 90 * Hub.dayMs, end)
            var w = 0
            for (var k = 0; k < curve.length; k++)
                if (curve[k].seconds === 1200)
                    w = curve[k].watts
            best.push(w)
        }
        steps = Hub.ftpSteps(starts, best)
    }

    function play() {
        drawIn.play()
    }

    function xOf(ms) {
        return Math.max(0, Math.min(1, (ms - from) / span)) * plot.width
    }

    function yOf(v) {
        return plot.height - 6 - (v - lo) / Math.max(1, hi - lo) * (plot.height - 14)
    }

    readonly property var line: {
        var out = []
        if (changes.length === 0 || plot.width < 2)
            return out
        out.push(Qt.point(xOf(changes[0].start), yOf(changes[0].value)))
        for (var i = 1; i < changes.length; i++) {
            var x = xOf(changes[i].start)
            out.push(Qt.point(x, yOf(changes[i - 1].value)))
            out.push(Qt.point(x, yOf(changes[i].value)))
        }
        out.push(Qt.point(plot.width, yOf(changes[changes.length - 1].value)))
        return out
    }

    readonly property string changeText: {
        if (!firstStep || changes.length < 2)
            return firstStep ? qsTr("Holding since %1").arg(Hub.monthLong[new Date(firstStep.start).getMonth()]) : ""
        var d = Math.round(current - firstStep.value)
        var month = Hub.monthLong[new Date(firstStep.start).getMonth()]
        if (d === 0)
            return qsTr("Holding since %1").arg(month)
        return (d > 0 ? "+" + d : "\u2212" + (-d)) + " " + qsTr("since %1").arg(month)
    }

    spacing: 12

    SectionHead {
        width: parent.width
        title: qsTr("FTP")
        note: qsTr("From your best 20 min")
    }

    Text {
        width: parent.width
        visible: ftp.current <= 0
        text: qsTr("Ride 20 minutes or more and your FTP estimate shows here.")
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }

    Item {
        width: parent.width
        height: ftpNumber.height
        visible: ftp.current > 0
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("Estimated FTP %1 watts, %2").arg(Math.round(ftp.current)).arg(ftp.changeText)
        Row {
            spacing: 5
            RollingNumber {
                id: ftpNumber
                value: String(Math.round(ftp.current))
                font.family: Theme.display
                font.pixelSize: 34
            }
            Text {
                anchors.bottom: ftpNumber.bottom
                anchors.bottomMargin: 6
                text: "W"
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
            }
            Text {
                anchors.bottom: ftpNumber.bottom
                anchors.bottomMargin: 6
                text: qsTr("est.")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 12
            }
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: ftp.changeText
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: 13
        }
    }

    DrawIn {
        id: drawIn
        width: parent.width
        height: 96
        visible: ftp.current > 0

        Item {
            width: drawIn.width
            height: drawIn.height
            Accessible.role: Accessible.Graphic
            Accessible.name: {
                var parts = []
                for (var i = 0; i < ftp.changes.length; i++)
                    parts.push(Hub.monthShort[new Date(ftp.changes[i].start).getMonth()] + " " + ftp.changes[i].value)
                return qsTr("Estimated FTP by month: %1 watts").arg(parts.join(", "))
            }

            Item {
                id: plot
                width: parent.width
                height: 74

                Hairline {
                    y: plot.height
                    width: plot.width
                }
                Shape {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeColor: Theme.text
                        strokeWidth: 2
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        capStyle: ShapePath.RoundCap
                        PathPolyline { path: ftp.line }
                    }
                }
                Repeater {
                    model: ftp.changes
                    Rectangle {
                        id: stepDot
                        readonly property bool last: index === ftp.changes.length - 1
                        x: ftp.xOf(modelData.start) - width / 2
                        y: ftp.yOf(modelData.value) - height / 2
                        width: last ? 12 : 6
                        height: width
                        radius: width / 2
                        color: last ? Theme.accent : Theme.text
                        border.width: last ? 2 : 0
                        border.color: Theme.bg
                    }
                }
                // the first and the latest value beside their steps
                Text {
                    visible: ftp.changes.length > 1
                    x: ftp.changes.length > 1 ? Math.min(plot.width - implicitWidth, ftp.xOf(ftp.changes[0].start) + 8) : 0
                    y: ftp.changes.length > 1 ? ftp.yOf(ftp.changes[0].value) - implicitHeight - 2 : 0
                    text: ftp.changes.length > 1 ? ftp.changes[0].value : ""
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                }
                Text {
                    visible: ftp.changes.length > 1
                    x: ftp.changes.length > 1 ? Math.max(0, ftp.xOf(ftp.changes[ftp.changes.length - 1].start) - implicitWidth - 10) : 0
                    y: ftp.changes.length > 1 ? Math.max(0, ftp.yOf(ftp.current) - implicitHeight - 2) : 0
                    text: Math.round(ftp.current)
                    color: Theme.text2
                    font.family: Theme.bodySemibold
                    font.pixelSize: 11
                }
            }

            // the months under the steps, every other one on a year
            Repeater {
                model: ftp.steps
                Text {
                    id: monthText
                    visible: ftp.steps.length < 8 || (ftp.steps.length - 1 - index) % 2 === 0
                    y: plot.height + 6
                    x: Math.max(0, Math.min(plot.width - implicitWidth, ftp.xOf(modelData.start) - (index === 0 ? 0 : implicitWidth / 2)))
                    text: Hub.monthShort[new Date(modelData.start).getMonth()]
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: ftp.pro && ftp.setting > 0 && ftp.current > 0
        text: qsTr("Your FTP setting is %1 W.").arg(Math.round(ftp.setting))
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
}
