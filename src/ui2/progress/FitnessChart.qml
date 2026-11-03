import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Fitness.js" as Fitness
import "Progress.js" as Progress

// Fitness, fatigue and form (see Fitness.js) over the period: today's three numbers in plain
// words on a hairline, fitness as a filled line with fatigue beside it, and form as a bar a day
// over its bands (Fresh, Productive, Overreaching). Drag across to read any day; the numbers
// roll to it. Pro adds the scale and the fatigue line. A tap on the chart or on one of the three
// numbers opens its Learn sheet (learn()); a tap while the crosshair shows hides it.
Column {
    id: fitness
    objectName: "fitnessChart"

    property var all: []             // Fitness.series() of the page, warm-up days included
    property int range: 91           // days shown
    property bool pro: false
    property int cursor: -1          // index in shownDays, -1 when the crosshair is hidden

    readonly property var shownDays: all.slice(Math.max(0, all.length - range))
    readonly property bool hasRides: {
        for (var i = 0; i < shownDays.length; i++)
            if (shownDays[i].ctl > 0.5)
                return true
        return false
    }
    readonly property var today: all.length > 0 ? all[all.length - 1] : ({ ctl: 0, atl: 0, tsb: 0, day: Date.now() })
    readonly property var shownDay: cursor >= 0 && cursor < shownDays.length ? shownDays[cursor] : today
    readonly property string formState: Fitness.formLabel(shownDay.ctl, shownDay.tsb)
    readonly property real scaleTop: {
        var hi = 0
        for (var i = 0; i < shownDays.length; i++)
            hi = Math.max(hi, shownDays[i].ctl, pro ? shownDays[i].atl : 0)
        return Progress.niceTop(Math.max(20, hi * 1.08))
    }
    // the form strip runs from +25 to -45: every band shows even for a calm rider
    readonly property real formUpper: 25
    readonly property real formLower: -45

    property var drawn: ({ ctl: [], area: [], atl: [] })

    // a tap asks for the Learn sheet of "fitness", "fatigue" or "form", with the rider's numbers
    signal learn(string key, var facts)

    // today and four weeks before: what the Learn sheets say about yours
    function learnFacts() {
        var n = all.length
        var before = n > 28 ? all[n - 29] : (n > 0 ? all[0] : today)
        return { ctl: today.ctl, atl: today.atl, tsb: today.tsb, state: Fitness.formLabel(today.ctl, today.tsb),
                 change: today.ctl - before.ctl, days: Math.min(28, Math.max(1, n - 1)), rides: hasRides ? 1 : 0 }
    }

    function play() {
        cursor = -1
        Qt.callLater(fitness.rebuild)
        drawIn.play()
    }

    function stateName(key) {
        if (key === "veryFresh")
            return qsTr("very fresh")
        if (key === "fresh")
            return qsTr("fresh")
        if (key === "steady")
            return qsTr("steady")
        if (key === "building")
            return qsTr("productive")
        if (key === "overreaching")
            return qsTr("overreaching")
        return qsTr("getting started")
    }

    function signed(v) {
        var r = Math.round(v)
        return r > 0 ? "+" + r : (r < 0 ? "\u2212" + (-r) : "0")
    }

    function xOf(i) {
        return shownDays.length > 1 ? i / (shownDays.length - 1) * plot.width : 0
    }

    function yOf(v) {
        return plot.height * (1 - Math.max(0, v) / scaleTop)
    }

    function formY(tsb) {
        var t = Math.max(formLower, Math.min(formUpper, tsb))
        return (formUpper - t) / (formUpper - formLower) * strip.height
    }

    function rebuild() {
        var c = []
        var a = []
        if (plot.width > 1)
            for (var i = 0; i < shownDays.length; i++) {
                c.push(Qt.point(xOf(i), yOf(shownDays[i].ctl)))
                a.push(Qt.point(xOf(i), yOf(shownDays[i].atl)))
            }
        var area = c.slice()
        if (c.length > 1) {
            area.push(Qt.point(c[c.length - 1].x, plot.height))
            area.push(Qt.point(0, plot.height))
        }
        drawn = { ctl: c, area: area, atl: a }
    }

    function dayAt(x) {
        if (shownDays.length < 2)
            return -1
        return Math.max(0, Math.min(shownDays.length - 1, Math.round(x / Math.max(1, plot.width) * (shownDays.length - 1))))
    }

    // dates under the chart: the first of each month (every other one on a year), or four dates
    // on four weeks
    function ticks() {
        var out = []
        var n = shownDays.length
        if (n < 2)
            return out
        if (range <= 31) {
            for (var q = 0; q < 4; q++) {
                var at = Math.round(q * (n - 1) / 3)
                out.push({ x: xOf(at), text: q === 3 ? qsTr("Today") : Progress.shortDate(shownDays[at].day) })
            }
            return out
        }
        var months = []
        for (var i = 1; i < n; i++)
            if (new Date(shownDays[i].day).getDate() === 1)
                months.push(i)
        var step = months.length > 7 ? 2 : 1
        for (var k = months.length - 1; k >= 0; k -= step)
            out.unshift({ x: xOf(months[k]), text: Format.monthShort[new Date(shownDays[months[k]].day).getMonth()] })
        return out
    }

    onAllChanged: Qt.callLater(fitness.rebuild)
    onRangeChanged: {
        cursor = -1
        Qt.callLater(fitness.rebuild)
    }
    onProChanged: Qt.callLater(fitness.rebuild)

    spacing: 14

    SectionHead {
        width: parent.width
        title: qsTr("Fitness, fatigue and form")
        note: fitness.cursor >= 0 ? Format.day(fitness.shownDay.day)
                                  : (fitness.range <= 31 ? qsTr("Last 4 weeks") : (fitness.range <= 91 ? qsTr("Last 90 days") : qsTr("Last year")))
    }

    Text {
        width: parent.width
        visible: !fitness.hasRides
        text: qsTr("Ride a few times a week and your fitness shows here.")
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }

    // the three numbers of today, or of the day under the finger
    Item {
        width: parent.width
        height: 80
        visible: fitness.hasRides
        Accessible.role: Accessible.StaticText
        Accessible.name: qsTr("Fitness %1, fatigue %2, form %3, %4").arg(Math.round(fitness.shownDay.ctl))
                         .arg(Math.round(fitness.shownDay.atl)).arg(fitness.signed(fitness.shownDay.tsb))
                         .arg(fitness.stateName(fitness.formState))
        Repeater {
            model: [[qsTr("Fitness"), String(Math.round(fitness.shownDay.ctl)), Theme.zoneColors[0]],
                    [qsTr("Fatigue"), String(Math.round(fitness.shownDay.atl)), Theme.text],
                    [fitness.formState === "start" ? qsTr("Form") : qsTr("Form, %1").arg(fitness.stateName(fitness.formState)),
                     fitness.signed(fitness.shownDay.tsb), Theme.text]]
            PulseButton {
                id: numberCell
                x: index * parent.width / 3
                width: parent.width / 3
                height: parent.height - 1
                radius: 16
                fill: pressed ? Theme.pressed : "transparent"
                pressedScale: 0.97
                leftInset: -8
                Accessible.name: qsTr("%1, %2, tap to learn more").arg(modelData[0]).arg(modelData[1])
                onClicked: fitness.learn(["fitness", "fatigue", "form"][index], fitness.learnFacts())
                RollingNumber {
                    id: cellNumber
                    y: 6
                    value: modelData[1]
                    color: modelData[2]
                    font.family: Theme.display
                    font.pixelSize: 30
                }
                Text {
                    y: cellNumber.y + cellNumber.height + 4
                    width: parent.width - 8
                    text: modelData[0]
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }
        Hairline {
            anchors.bottom: parent.bottom
            width: parent.width
        }
    }

    DrawIn {
        id: drawIn
        width: parent.width
        height: chartBox.height
        visible: fitness.hasRides

        Item {
            id: chartBox
            width: drawIn.width
            height: strip.y + strip.height + 4

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Fitness chart, last %1 days: fitness %2, fatigue %3, form %4, %5. Tap to learn more")
                             .arg(fitness.range).arg(Math.round(fitness.today.ctl)).arg(Math.round(fitness.today.atl))
                             .arg(fitness.signed(fitness.today.tsb)).arg(fitness.stateName(Fitness.formLabel(fitness.today.ctl, fitness.today.tsb)))
            Accessible.onPressAction: fitness.learn("fitness", fitness.learnFacts())

            Item {
                id: plot
                y: 8
                width: parent.width
                height: fitness.width < 480 ? 140 : 180

                onWidthChanged: Qt.callLater(fitness.rebuild)
                onHeightChanged: Qt.callLater(fitness.rebuild)

                // the top and the middle of the scale
                Repeater {
                    model: 2
                    Item {
                        id: gridLine
                        y: Math.round(index * plot.height / 2)
                        width: plot.width
                        Hairline {
                            width: parent.width
                            opacity: 0.6
                        }
                        Text {
                            visible: fitness.pro
                            x: 2
                            y: 3
                            style: Text.Outline
                            styleColor: Theme.bg
                            text: Math.round(fitness.scaleTop * (1 - index / 2))
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 11
                        }
                    }
                }
                Hairline {
                    y: plot.height
                    width: plot.width
                }

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            strokeWidth: -1
                            fillGradient: LinearGradient {
                                x1: 0; y1: 0; x2: 0; y2: plot.height
                                GradientStop { position: 0; color: Qt.rgba(0x8a / 255, 0xb4 / 255, 1, 0.34) }
                                GradientStop { position: 1; color: Qt.rgba(0x8a / 255, 0xb4 / 255, 1, 0.04) }
                            }
                            PathPolyline { path: fitness.drawn.area }
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        visible: fitness.pro
                        ShapePath {
                            strokeColor: Theme.text3
                            strokeWidth: 1.3
                            fillColor: "transparent"
                            joinStyle: ShapePath.RoundJoin
                            PathPolyline { path: fitness.drawn.atl }
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: Theme.zoneColors[0]
                            strokeWidth: 2.2
                            fillColor: "transparent"
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.RoundCap
                            PathPolyline { path: fitness.drawn.ctl }
                        }
                    }
                }

                // today at the end of each line
                Rectangle {
                    visible: fitness.pro && fitness.shownDays.length > 1
                    x: plot.width - width / 2
                    y: fitness.yOf(fitness.today.atl) - height / 2
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.text3
                    border.width: 2
                    border.color: Theme.bg
                }
                Rectangle {
                    visible: fitness.shownDays.length > 1
                    x: plot.width - width / 2
                    y: fitness.yOf(fitness.today.ctl) - height / 2
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.zoneColors[0]
                    border.width: 2
                    border.color: Theme.bg
                }
            }

            // the dates under the lines
            Repeater {
                model: fitness.ticks()
                Text {
                    id: tickText
                    y: plot.y + plot.height + 6
                    x: Math.max(0, Math.min(chartBox.width - implicitWidth, modelData.x - implicitWidth / 2))
                    text: modelData.text
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 11
                }
            }

            // form: its bands, then a bar a day above or below zero
            Item {
                id: strip
                y: plot.y + plot.height + 28
                width: parent.width
                height: 90

                Repeater {
                    // [from, to, color, name, name color]
                    model: [[25, 5, Theme.zoneColors[0], qsTr("Fresh")],
                            [-10, -30, Theme.zoneColors[2], qsTr("Productive")],
                            [-30, -45, Theme.zoneColors[5], qsTr("Overreaching")]]
                    Item {
                        id: band
                        y: fitness.formY(modelData[0])
                        width: strip.width
                        height: fitness.formY(modelData[1]) - y
                        Rectangle {
                            anchors.fill: parent
                            color: modelData[2]
                            opacity: index === 1 ? 0.16 : 0.1
                        }
                    }
                }
                Hairline {
                    y: Math.round(fitness.formY(0))
                    width: strip.width
                    color: Qt.rgba(1, 1, 1, 0.16)
                }
                Repeater {
                    model: fitness.shownDays.length
                    Rectangle {
                        id: formBar
                        readonly property real tsb: fitness.shownDays[index] ? fitness.shownDays[index].tsb : 0
                        readonly property real slot: strip.width / Math.max(1, fitness.shownDays.length)
                        readonly property real zero: fitness.formY(0)
                        readonly property bool last: index === fitness.shownDays.length - 1
                        x: index * slot + (slot > 3 ? 0.5 : 0)
                        width: Math.max(1, slot > 3 ? slot - 1 : slot)
                        height: Math.max(1, Math.abs(fitness.formY(tsb) - zero))
                        y: tsb >= 0 ? zero - height : zero
                        radius: width > 3 ? 1 : 0
                        color: last || fitness.cursor === index ? Theme.text : Qt.rgba(1, 1, 1, 0.26)
                    }
                }
            }

            // the names of the bands, over the bars
            Repeater {
                model: [[15, Theme.zoneColors[0], qsTr("Fresh")], [-20, Theme.zoneColors[2], qsTr("Productive")],
                        [-37.5, Theme.zoneColors[5], qsTr("Overreaching")]]
                Text {
                    id: bandName
                    x: 6
                    y: strip.y + fitness.formY(modelData[0]) - implicitHeight / 2
                    text: modelData[2]
                    color: modelData[1]
                    style: Text.Outline
                    styleColor: Theme.bg
                    font.family: index === 1 ? Theme.bodySemibold : Theme.bodyMedium
                    font.pixelSize: 11
                }
            }

            // the crosshair over both
            Item {
                anchors.fill: parent
                visible: fitness.cursor >= 0
                Rectangle {
                    x: Math.round(fitness.xOf(fitness.cursor))
                    y: plot.y
                    width: 1
                    height: strip.y + strip.height - plot.y
                    color: Qt.rgba(1, 1, 1, 0.5)
                }
                Rectangle {
                    x: fitness.xOf(fitness.cursor) - width / 2
                    y: plot.y + fitness.yOf(fitness.shownDay.ctl) - height / 2
                    width: 11
                    height: 11
                    radius: 5.5
                    color: Theme.zoneColors[0]
                    border.width: 2
                    border.color: Theme.bg
                }
            }

            ScrubArea {
                width: parent.width
                height: strip.y + strip.height
                onScrub: fitness.cursor = fitness.dayAt(at)
                learnable: true
                onTap: {
                    if (fitness.cursor >= 0)
                        fitness.cursor = -1
                    else
                        fitness.learn("fitness", fitness.learnFacts())
                }
            }
        }
    }
}
