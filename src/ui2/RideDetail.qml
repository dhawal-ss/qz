import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "charts"
import "laps"
import "rides"
import "learn"
import "Format.js" as Format
import "rides/Analysis.js" as Analysis
import "learn/Learn.js" as Learn

// One ride in depth, in the Signature language: the ride's name and day, what a coach would
// say about it (the record it set, else the most notable thing) with that one number big in its
// zone, the power with heart rate over it and the best stretch marked, the key numbers on
// hairlines, time in zones, the power curve against the 90 days before, what changed against
// a similar ride, aerobic durability, the laps as work blocks, and sharing. Simple shows what
// most rides need; Pro adds every chart (linked: they zoom and read out together), the power
// curve, durability and the lap views. The screen wears one tint: the zone of its hero number,
// else the zone the ride counts in. Everything is worked out once when the ride changes.
// Under the chart, this ride against the usual of the 30 days before it (rides/RideUsual.qml).
// Tap to learn: the hero number, the charts, every key number and every section opens a Learn
// sheet (learn/LearnSheet.qml) on what it is and what this ride's number says; holding or
// dragging a chart still reads it out, a double tap still shows the whole ride.
Item {
    id: detail
    objectName: "rideDetail"

    property var library: null
    property int rideId: -1
    property bool miles: false
    property bool showBack: true
    // the power of the rides is estimated (a bike without a power meter): numbers from it say "est."
    property bool powerEstimated: false
    // rootItem, for the folder a shared picture is saved in
    property var core: null
    // the rides of the library, newest first, when the caller has them (else read here)
    property var rideList: []
    // the end of the page the floating navigation covers
    property real bottomClearance: 0
    // what a sheet keeps free at its end: the bottom inset
    property real sheetClearance: 0
    property var ride: ({})
    property var samples: ({})
    // which metrics have data, worked out once per ride
    property var has: ({})
    property int loadedId: -1
    readonly property alias chartView: chartView

    // Analysis.headline(), the best stretch, the 90 days before, durability, the sentences, the laps
    property var story: ({ sentence: "", value: "", unit: "", label: "", sub: "", zone: 0, seconds: 0, power: false })
    property var segment: null
    property var curve90: []
    // the best of every ride before this one
    property var curveBefore: []
    // the rides of the library, newest first, as load() read them
    property var history: []
    // the Learn sheet
    property bool learnOpen: false
    property var learnEntry: null
    readonly property var learnIds: ["ridechart", "rideusual", "record", "effort", "time", "work", "distance", "avgpower", "np", "if",
                                     "tss", "avghr", "cadence", "speed", "level", "zones", "ridecurve", "changes", "decoupling",
                                     "ef", "workblocks"]
    // a sheet covers the ride
    readonly property bool covering: learnOpen
    property var durable: null
    property var changes: []
    property var blocks: ({ blocks: [], work: false })
    property int pickedLap: -1
    property bool pro: false
    property bool sharing: false
    // the share card: one bar per minute (or few minutes) of power, and where it was saved
    property var shareBars: []
    property int shareMinutes: 1
    property string savedImage: ""
    property bool saveFailed: false
    // the charts and bars wipe in, 0 to 1
    property real reveal: 1

    readonly property int rideZone: Analysis.rideZone(ride.intensity)
    readonly property int tintZone: story.zone > 0 ? story.zone : rideZone
    readonly property color tint: Theme.zoneColors[Math.max(1, Math.min(7, tintZone)) - 1]
    readonly property bool estimated: powerEstimated || ride.powerEstimated === true

    signal back()
    // each time a ride shows: the blocks rise in
    signal entered()

    // every 1 Hz sample of the ride, read once when the ride changes, and all that follows from it
    function load() {
        if (!library || rideId < 0) {
            ride = {}
            samples = {}
            has = {}
            loadedId = -1
            return
        }
        if (rideId === loadedId)
            return
        loadedId = rideId
        readLevel()
        sharing = false
        pickedLap = -1
        var r = library.ride(rideId)
        var all = library.samples(rideId, 0)
        var seconds = all.seconds || []
        has = { power: hasValues(all.power), heart: hasValues(all.heart), cadence: hasValues(all.cadence),
                speed: hasValues(all.speed), level: hasValues(all.level) }
        chartView.duration = seconds.length > 0 ? Math.max(1, seconds[seconds.length - 1]) : Math.max(1, r.duration || 1)
        chartView.reset(true)

        var day = 86400000
        var list = rideList.length > 0 ? rideList : library.rides(0, 2000)
        var similar = Analysis.similarRide(r, list)
        var spread = Analysis.cadenceSpread(all)
        var similarSpread = similar ? Analysis.cadenceSpread(library.samples(similar.id, 0)) : 0
        curve90 = r.start ? library.powerCurve(r.start - 90 * day, r.start) : []
        curveBefore = r.start ? library.powerCurve(0, r.start) : []
        history = list
        learnOpen = false
        story = Analysis.headline({
            ride: r, before: curveBefore, prior90: curve90,
            month: Analysis.sameMonth(list, r), spread: spread, similarSpread: similarSpread, ftp: r.ftp || 0, now: Date.now()
        })
        var length = story.seconds > 0 ? story.seconds : ((r.duration || 0) >= 1200 ? 300 : 60)
        var stretch = has.power ? Analysis.bestWindow(all, length) : null
        if (stretch !== null)
            stretch.seconds = length
        segment = stretch
        durable = has.power && has.heart ? Analysis.durability(all) : null
        changes = Analysis.changes(r, similar, spread, similarSpread, Date.now())
        blocks = Analysis.workBlocks(r.laps || [], r.avgPower || 0, r.ftp || 0)
        ride = r
        samples = all
        flick.contentY = 0
        wipeIn.restart()
        entered()
        proCue.entered()
    }

    readonly property var lapStarts: {
        var out = []
        var list = ride.laps || []
        for (var i = 0; i < list.length; i++)
            out.push(list[i].start)
        return out
    }

    // the Learn entry of the hero number, by what the number is
    function heroLearnId() {
        if (story.record)
            return "record"
        if (story.seconds > 0)
            return "effort"
        if (story.unit === "kJ")
            return "work"
        if (story.unit === "rpm")
            return "cadence"
        if (story.unit === "W")
            return ride.np > 0 ? "np" : "avgpower"
        return "time"
    }

    // what the Learn sheet of an entry says about this ride
    function factsFor(id) {
        var r = ride
        var f = { rides: 1, estimated: estimated, seconds: r.duration || 0, kj: r.kj || 0, power: r.avgPower || 0, np: r.np || 0,
                  value: r.intensity || 0, tss: r.tss || 0, heart: r.avgHr || 0, cadence: r.avgCadence || 0,
                  distanceText: r.distance > 0 ? Format.distance(r.distance, miles) : "" }
        if (id === "record" || id === "effort") {
            f.effort = Analysis.effortWords(story.seconds)
            f.watts = Number(story.value) || 0
            f.previous = Analysis.wattsAt(id === "record" ? curveBefore : curve90, story.seconds)
        }
        if (id === "if")
            f.value = r.intensity || 0
        if (id === "decoupling" || id === "ef")
            f.value = durable ? (id === "ef" ? durable.ef : durable.decoupling) : undefined
        if (id === "zones") {
            var z = r.powerZones || []
            var best = -1
            for (var i = 0; i < z.length; i++)
                if (best < 0 || z[i] > z[best])
                    best = i
            if (best >= 0 && zoneTotal > 1) {
                f.topZone = Theme.powerZoneNames[best]
                f.topShare = 100 * z[best] / zoneTotal
            }
        }
        if (id === "ridecurve") {
            var s = story.seconds > 0 ? story.seconds : 300
            var w = Analysis.wattsAt(r.best || [], s)
            if (w > 0) {
                f.effort = Analysis.effortWords(s)
                f.watts = w
                f.prior = Analysis.wattsAt(curve90, s)
            }
        }
        if (id === "ridechart" && segment) {
            f.bestLabel = Format.effort(segment.seconds)
            f.bestWatts = segment.watts
        }
        if (id === "changes")
            f.count = changes.length
        if (id === "workblocks") {
            f.count = blocks.blocks.length
            f.work = blocks.work
        }
        if (id === "rideusual" || id === "avghr") {
            var u = usualSection.learnFacts()
            for (var k in u)
                f[k] = u[k]
        }
        return f
    }

    function openLearn(id) {
        learnEntry = Learn.entry(id, factsFor(id))
        learnOpen = true
    }

    // Android back closes the Learn sheet first
    function goBack() {
        if (learnOpen) {
            learnOpen = false
            return true
        }
        return false
    }

    function hasValues(list) {
        if (!list)
            return false
        for (var i = 0; i < list.length; i++)
            if (list[i] > 0)
                return true
        return false
    }

    // Simple or Pro, shared with Progress and You; Qt.labs.settings does not tell the others,
    // so it is read each time a ride shows
    function readLevel() {
        pro = String(uiStore.value("detailLevel", "simple")) === "pro"
    }
    function setPro(on) {
        if (on === pro)
            return
        pro = on
        uiStore.setValue("detailLevel", on ? "pro" : "simple")
        if (on)
            proCue.entered()
    }
    onProChanged: levelToggle.currentIndex = pro ? 1 : 0

    // a lap picked in the blocks or the lap views zooms the charts to it; -1 shows the whole ride
    function pickLap(index) {
        pickedLap = index
        lapsSection.selectedLap = index
        if (index < 0 || !ride.laps || index >= ride.laps.length) {
            chartView.reset(false)
            return
        }
        var lap = ride.laps[index]
        var s = samples.seconds || []
        var a = s[lap.start] || lap.start
        var b = s[lap.start + lap.duration - 1] || (lap.start + lap.duration)
        chartView.place(a / chartView.duration, Math.max(chartView.minSpan, (b - a) / chartView.duration))
        var target = Math.max(0, chartBlock.y - 16)
        if (Theme.reduceMotion) {
            flick.contentY = target
            return
        }
        scrollTo.to = target
        scrollTo.restart()
    }

    // the ride as the share card draws it: one bar per minute of power, 120 at most
    function openShare() {
        var minutes = Math.max(1, Math.round((ride.duration || 0) / 60))
        var count = Math.min(120, minutes)
        shareMinutes = Math.max(1, Math.round(minutes / count))
        var power = Analysis.buckets(samples.power || [], count)
        if (power.length < 2)
            power = ride.spark || []
        var ftp = ride.ftp || 0
        shareBars = power.map(function (w) { return { watts: w, zone: ftp > 0 ? Theme.powerZone(w, ftp) : 0 } })
        savedImage = ""
        saveFailed = false
        sharing = true
    }

    function saveImage() {
        if (!shareLoader.item)
            return
        var folder = core !== null && core !== undefined ? core.getWritableAppDir() : ""
        var path = folder + "bikemodo-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png"
        shareLoader.item.card.save(path, function (ok, where) {
            detail.savedImage = ok ? where : ""
            detail.saveFailed = !ok
        })
    }

    // A headline on two lines that read well: after a full stop when there is one in the middle,
    // else at the space nearest the middle. Plain string work, no patterns.
    function balanced(sentence) {
        var words = sentence.split(" ")
        if (words.length < 4)
            return sentence
        var stop = sentence.indexOf(". ")
        if (stop > 0 && stop < sentence.length - 3)
            return sentence.substring(0, stop + 1) + "\n" + sentence.substring(stop + 2)
        var middle = sentence.length / 2
        var best = -1
        for (var i = 0; i < sentence.length; i++)
            if (sentence.charAt(i) === " " && (best < 0 || Math.abs(i - middle) < Math.abs(best - middle)))
                best = i
        return best < 0 ? sentence : sentence.substring(0, best) + "\n" + sentence.substring(best + 1)
    }

    function dayLine() {
        if (!ride.start)
            return ""
        var d = new Date(ride.start)
        var format = d.getFullYear() === new Date().getFullYear() ? "dddd d MMMM" : "dddd d MMMM yyyy"
        return Qt.formatDate(d, format) + ", " + Analysis.shortDuration(ride.duration || 0)
    }

    readonly property var keyItems: {
        var out = []
        var r = ride
        if (!r.start)
            return out
        var power = r.avgPower > 0
        out.push({ label: qsTr("Time"), value: Analysis.shortDuration(r.duration || 0), unit: "", learn: "time" })
        if (power)
            out.push({ label: qsTr("Work"), value: Format.big(r.kj || 0), unit: "kJ", estimated: estimated, learn: "work" })
        if (!pro)
            out.push({ label: qsTr("Distance"), value: Format.distance(r.distance || 0, miles).split(" ")[0], unit: miles ? "mi" : "km", learn: "distance" })
        if (power)
            out.push({ label: qsTr("Avg power"), value: Format.whole(r.avgPower), unit: "W", estimated: estimated, learn: "avgpower" })
        if (pro && r.np > 0) {
            out.push({ label: qsTr("Normalized power"), value: Format.whole(r.np), unit: "W", estimated: estimated, learn: "np" })
            out.push({ label: qsTr("Intensity factor"), value: (r.intensity || 0).toFixed(2), unit: "", estimated: estimated, learn: "if" })
            out.push({ label: qsTr("Training load"), value: Format.whole(r.tss), unit: "TSS", estimated: estimated, learn: "tss" })
        }
        if (r.avgHr > 0)
            out.push({ label: qsTr("Avg heart rate"), value: Format.whole(r.avgHr), unit: "bpm", learn: "avghr" })
        if (r.avgCadence > 0)
            out.push({ label: qsTr("Avg cadence"), value: Format.whole(r.avgCadence), unit: "rpm", learn: "cadence" })
        return out
    }

    readonly property real zoneTotal: {
        var sum = 0
        var z = ride.powerZones || []
        for (var i = 0; i < z.length; i++)
            sum += z[i]
        return sum
    }

    onRideIdChanged: load()
    // You may have changed the level while the ride stayed open (tablets)
    onVisibleChanged: {
        if (visible)
            readLevel()
        else
            learnOpen = false
    }
    onLibraryChanged: {
        loadedId = -1
        load()
    }
    Component.onCompleted: {
        readLevel()
        levelToggle.currentIndex = pro ? 1 : 0
        load()
    }

    ChartView { id: chartView }

    // the Pro sections rise in when they appear
    QtObject {
        id: proCue
        signal entered()
    }

    Settings {
        id: uiStore
        category: "ui2"
    }

    NumberAnimation {
        id: wipeIn
        target: detail
        property: "reveal"
        from: Theme.reduceMotion ? 1 : 0
        to: 1
        duration: Theme.reduceMotion ? 0 : 1400
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.effectsCurve
    }
    NumberAnimation {
        id: scrollTo
        target: flick
        property: "contentY"
        duration: Theme.slowSpatialTime
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.effectsCurve
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // the glow of the hero in the tint, outside the Flickable so it reaches the top of the
    // screen; it follows the hero as the page scrolls
    HeroGlow {
        readonly property point center: {
            var moved = flick.contentY + column.x + heroRow.y + heroBlock.y
            return heroRow.mapToItem(detail, heroRow.width * 0.3, heroRow.height / 2)
        }
        visible: detail.ride.start !== undefined
        width: Math.min(520, detail.width * 1.1)
        height: width
        x: center.x - width / 2
        y: center.y - height / 2
        tint: detail.tint
        low: 0.22
        high: 0.34
        Behavior on tint {
            enabled: !Theme.reduceMotion
            ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        }
    }

    Flickable {
        id: flick
        objectName: "rideDetailFlick"
        anchors.fill: parent
        contentHeight: column.y + column.height + 24 + detail.bottomClearance
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            readonly property real margin: detail.width < 400 ? 16 : 24
            readonly property bool wide: width >= 560
            x: Math.max(margin, (detail.width - width) / 2)
            y: 24
            width: Math.min(detail.width - margin * 2, 760)
            spacing: 26

            // back, Simple or Pro, the ride and its day, the headline and the hero number
            Rise {
                id: heroBlock
                cue: detail
                order: 0
                width: parent.width
                Column {
                    width: parent.width
                    spacing: 0
                    Item {
                        width: parent.width
                        height: 44
                        PulseButton {
                            id: backButton
                            visible: detail.showBack
                            x: -2
                            y: -2
                            width: 48
                            height: 48
                            topInset: 2
                            bottomInset: 2
                            leftInset: 2
                            rightInset: 2
                            fill: pressed ? Theme.pressed : Theme.control
                            Accessible.name: qsTr("Back")
                            onClicked: detail.back()
                            contentItem: Item {
                                LineIcon { anchors.centerIn: parent; name: "back"; size: 20 }
                            }
                        }
                        SegmentedToggle {
                            id: levelToggle
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 171
                            height: 40
                            options: [qsTr("Simple"), qsTr("Pro")]
                            name: qsTr("Detail level")
                            onPicked: detail.setPro(index === 1)
                        }
                    }
                    Item { width: 1; height: 12 }
                    Text {
                        width: parent.width
                        text: detail.ride.start ? Format.title(detail.ride) : ""
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 21
                        font.letterSpacing: -0.2
                        elide: Text.ElideRight
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    Item { width: 1; height: 6 }
                    Text {
                        width: parent.width
                        text: detail.dayLine()
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                    Item { width: 1; height: 18 }
                    Text {
                        width: parent.width
                        text: detail.balanced(detail.story.sentence)
                        color: Theme.text
                        font.family: Theme.display
                        font.pixelSize: detail.width < 400 ? 32 : 36
                        font.letterSpacing: -0.7
                        lineHeightMode: Text.FixedHeight
                        lineHeight: Math.round(font.pixelSize * 1.06)
                        wrapMode: Text.WordWrap
                        Accessible.role: Accessible.Heading
                        Accessible.name: detail.story.sentence
                    }
                    Item { width: 1; height: 14 }
                    // the hero: the number of the headline, heavier the harder it was
                    // the hero number is the button to its Learn sheet
                    LearnTap {
                        id: heroRow
                        width: parent.width
                        height: Math.max(heroNumber.height, heroLabels.height + Math.round(heroNumber.height * 0.12))
                        name: detail.story.label + ", " + detail.story.value + " " + detail.story.unit
                              + (detail.story.power && detail.estimated ? " " + qsTr("estimated") : "")
                              + (detail.story.sub !== "" ? ", " + detail.story.sub : "")
                        onClicked: detail.openLearn(detail.heroLearnId())
                        RollingNumber {
                            id: heroNumber
                            anchors.bottom: parent.bottom
                            value: detail.story.value
                            color: detail.tint
                            font.family: Theme.heroFamily(detail.tintZone)
                            font.pixelSize: Math.round(Math.min(100, Math.max(64, (heroRow.width - 190) / Math.max(2.4, detail.story.value.length * 0.62))))
                            token: "slow"
                            Accessible.ignored: true
                        }
                        Text {
                            id: heroUnit
                            x: heroNumber.width + 6
                            anchors.bottom: heroNumber.bottom
                            anchors.bottomMargin: Math.round(heroNumber.height * 0.12)
                            text: detail.story.unit
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 18
                            Accessible.ignored: true
                        }
                        Column {
                            id: heroLabels
                            x: heroUnit.x + heroUnit.width + 16
                            width: heroRow.width - x
                            anchors.bottom: heroUnit.bottom
                            spacing: 5
                            // the label wraps when it is long ("Normalized power"), with "est." after it
                            Text {
                                width: parent.width
                                text: detail.story.label + (detail.story.power && detail.estimated
                                                            ? "<font color=\"" + Theme.text3 + "\" size=\"2\"> " + qsTr("est.") + "</font>" : "")
                                textFormat: Text.StyledText
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: 15
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Accessible.ignored: true
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: detail.story.sub
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                Accessible.ignored: true
                            }
                        }
                    }
                }
            }

            // power with heart rate over it and the best stretch; in Pro the readout and every
            // other metric on the same timeline
            Rise {
                id: chartBlock
                cue: detail
                order: 1
                width: parent.width
                visible: detail.has.power === true || detail.has.heart === true
                Column {
                    width: parent.width
                    spacing: 12
                    CursorReadout {
                        visible: detail.pro
                        width: parent.width
                        view: chartView
                        samples: detail.samples
                        miles: detail.miles
                        heart: detail.has.heart === true
                        cadence: detail.has.cadence === true
                        speed: detail.has.speed === true
                        level: detail.has.level === true
                    }
                    TimeChart {
                        id: heroChart
                        readonly property bool power: detail.has.power === true
                        width: parent.width
                        height: column.wide ? 280 : 226
                        topStrip: 48
                        view: chartView
                        seconds: detail.samples.seconds || []
                        values: power ? (detail.samples.power || []) : (detail.samples.heart || [])
                        name: power ? qsTr("Power") : qsTr("Heart rate")
                        unit: power ? "W" : "bpm"
                        color: power ? detail.tint : Theme.zoneColors[5]
                        fromLowest: !power
                        zoneColored: power
                        filled: power
                        showAverage: false
                        ftp: detail.ride.ftp || 0
                        laps: detail.lapStarts
                        overlay: power && detail.has.heart === true ? (detail.samples.heart || []) : []
                        overlayName: power && detail.has.heart === true ? qsTr("Heart rate") : ""
                        overlayShort: qsTr("HR")
                        bandStart: detail.segment ? detail.segment.start : -1
                        bandEnd: detail.segment ? detail.segment.end : -1
                        bandColor: detail.tint
                        bandLabel: detail.segment ? qsTr("Best %1").arg(Format.effort(detail.segment.seconds)) : ""
                        // the same number as the hero when the hero is this stretch
                        bandValue: detail.segment ? Math.round(detail.story.seconds > 0 && Analysis.wattsAt(detail.ride.best, detail.story.seconds) > 0
                                                               ? Analysis.wattsAt(detail.ride.best, detail.story.seconds)
                                                               : detail.segment.watts) + " W" : ""
                        reveal: detail.reveal
                        learnable: true
                        onLearn: detail.openLearn(power ? "ridechart" : "avghr")
                        Accessible.name: power
                                         ? qsTr("Power across the ride%1. Best %2, %3 watts.")
                                           .arg(detail.has.heart === true ? qsTr(" with heart rate") : "")
                                           .arg(detail.segment ? Format.effort(detail.segment.seconds) : "")
                                           .arg(detail.segment ? Math.round(detail.segment.watts) : 0)
                                         : qsTr("Heart rate across the ride")
                    }
                    TimeChart {
                        visible: detail.pro && detail.has.cadence === true
                        width: parent.width
                        height: column.wide ? 140 : 110
                        view: chartView
                        seconds: detail.samples.seconds || []
                        values: detail.samples.cadence || []
                        name: qsTr("Cadence")
                        unit: "rpm"
                        color: Theme.text2
                        average: detail.ride.avgCadence || 0
                        laps: detail.lapStarts
                        reveal: detail.reveal
                        learnable: true
                        onLearn: detail.openLearn("cadence")
                    }
                    TimeChart {
                        visible: detail.pro && detail.has.level === true
                        width: parent.width
                        height: column.wide ? 140 : 110
                        view: chartView
                        seconds: detail.samples.seconds || []
                        values: detail.samples.level || []
                        name: qsTr("Level")
                        color: Theme.text2
                        laps: detail.lapStarts
                        reveal: detail.reveal
                        learnable: true
                        onLearn: detail.openLearn("level")
                    }
                    TimeChart {
                        visible: detail.pro && detail.has.speed === true
                        width: parent.width
                        height: column.wide ? 140 : 110
                        view: chartView
                        seconds: detail.samples.seconds || []
                        values: detail.samples.speed || []
                        name: qsTr("Speed")
                        unit: detail.miles ? "mph" : "km/h"
                        factor: detail.miles ? 0.621371 : 1
                        decimals: 1
                        color: Theme.text2
                        laps: detail.lapStarts
                        reveal: detail.reveal
                        learnable: true
                        onLearn: detail.openLearn("speed")
                    }
                    TimeAxis {
                        width: parent.width
                        view: chartView
                    }
                }
            }

            // this ride against the rides of the 30 days before it
            Rise {
                cue: detail
                order: 2
                width: parent.width
                visible: usualSection.rows.length > 0
                RideUsual {
                    id: usualSection
                    width: parent.width
                    ride: detail.ride
                    rides: detail.history
                    tint: detail.tint
                    estimated: detail.estimated
                    onClicked: detail.openLearn("rideusual")
                    Connections {
                        target: detail
                        function onEntered() { usualSection.grow() }
                    }
                }
            }

            // the key numbers on hairlines
            Rise {
                cue: detail
                order: 2
                width: parent.width
                visible: detail.keyItems.length > 0
                Column {
                    width: parent.width
                    spacing: 12
                    Text {
                        text: qsTr("Key numbers")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.titleSize
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    KeyGrid {
                        width: parent.width
                        items: detail.keyItems
                        onPicked: detail.openLearn(detail.keyItems[index].learn)
                    }
                }
            }

            // time in power zones
            Rise {
                cue: detail
                order: 3
                width: parent.width
                visible: (detail.ride.powerZones || []).length === 7 && detail.zoneTotal > 1
                LearnTap {
                  width: parent.width
                  name: qsTr("Time in zones")
                  onClicked: detail.openLearn("zones")
                  Column {
                    width: parent.width
                    spacing: 14
                    Item {
                        width: parent.width
                        height: zonesTitle.height
                        Text {
                            id: zonesTitle
                            text: qsTr("Time in zones")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.titleSize
                            Accessible.role: Accessible.Heading
                            Accessible.name: text
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.baseline: zonesTitle.baseline
                            text: detail.estimated ? qsTr("Power, est.") : qsTr("Power")
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 13
                        }
                    }
                    ZoneRows {
                        width: parent.width
                        seconds: detail.ride.powerZones || []
                        ftp: detail.ride.ftp || 0
                        grow: Math.min(1, detail.reveal * 1.4)
                    }
                  }
                }
            }

            // the power curve against the 90 days before
            Rise {
                cue: proCue
                order: 4
                width: parent.width
                visible: detail.pro && (detail.ride.best || []).length > 0 && detail.curve90.length > 0
                LearnTap {
                  width: parent.width
                  name: qsTr("Power curve of the ride")
                  onClicked: detail.openLearn("ridecurve")
                  Column {
                    width: parent.width
                    spacing: 10
                    Item {
                        width: parent.width
                        height: curveTitle.height
                        Text {
                            id: curveTitle
                            text: qsTr("Power curve")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.titleSize
                            Accessible.role: Accessible.Heading
                            Accessible.name: text
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.baseline: curveTitle.baseline
                            width: Math.min(implicitWidth, parent.width - curveTitle.width - 12)
                            text: detail.estimated ? qsTr("Best at each length, est.") : qsTr("Best at each length")
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                    PowerCurve {
                        width: parent.width
                        height: column.wide ? 240 : 210
                        ride: detail.ride.best || []
                        prior: detail.curve90
                        tint: detail.tint
                        rideSeconds: detail.ride.duration || 0
                        heroSeconds: detail.story.seconds || 0
                        reveal: detail.reveal
                    }
                  }
                }
            }

            // what changed against a similar ride before
            Rise {
                cue: detail
                order: 4
                width: parent.width
                visible: detail.changes.length > 0
                LearnTap {
                  width: parent.width
                  name: qsTr("What changed")
                  onClicked: detail.openLearn("changes")
                  Column {
                    width: parent.width
                    Text {
                        bottomPadding: 6
                        text: qsTr("What changed")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.titleSize
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    Repeater {
                        model: detail.changes
                        Item {
                            width: parent.width
                            height: Math.max(56, sentence.implicitHeight + 20)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 36
                                radius: 18
                                color: Theme.control
                                LineIcon {
                                    anchors.centerIn: parent
                                    name: modelData.icon
                                    size: 18
                                }
                            }
                            Text {
                                id: sentence
                                x: 50
                                width: parent.width - 50
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text
                                color: Theme.text
                                font.family: Theme.bodyMedium
                                font.pixelSize: 15
                                lineHeight: 1.2
                                wrapMode: Text.WordWrap
                            }
                            Hairline {
                                visible: index < detail.changes.length - 1
                                anchors.bottom: parent.bottom
                                width: parent.width
                            }
                        }
                    }
                  }
                }
            }

            // aerobic durability
            Rise {
                cue: proCue
                order: 5
                width: parent.width
                visible: detail.pro && detail.durable !== null
                Column {
                    width: parent.width
                    spacing: 12
                    Text {
                        text: qsTr("Aerobic durability")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.titleSize
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    Row {
                        width: parent.width
                        spacing: 24
                        Repeater {
                            model: detail.durable ? [
                                [qsTr("Decoupling"), detail.durable.decoupling.toFixed(1), "%", "decoupling"],
                                [qsTr("Efficiency factor"), detail.durable.ef.toFixed(2), "", "ef"]
                            ] : []
                            LearnTap {
                                width: (parent.width - 24) / 2
                                name: modelData[0] + ", " + modelData[1] + modelData[2]
                                onClicked: detail.openLearn(modelData[3])
                              Column {
                                width: parent.width
                                spacing: 10
                                Text {
                                    text: modelData[0]
                                    color: Theme.text2
                                    font.family: Theme.bodyMedium
                                    font.pixelSize: 13
                                    Accessible.ignored: true
                                }
                                Row {
                                    spacing: 2
                                    Numeral {
                                        id: durableValue
                                        text: modelData[1]
                                        color: Theme.text
                                        font.pixelSize: 34
                                        font.letterSpacing: -0.9
                                        Accessible.ignored: true
                                    }
                                    Text {
                                        anchors.baseline: durableValue.baseline
                                        text: modelData[2]
                                        color: Theme.text2
                                        font.family: Theme.bodyMedium
                                        font.pixelSize: 18
                                        Accessible.ignored: true
                                    }
                                }
                              }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        text: detail.durable ? Analysis.durabilityWords(detail.durable.decoupling) : ""
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 14
                        lineHeight: 1.2
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // the laps as work blocks; the lap views in Pro
            Rise {
                cue: detail
                order: 5
                width: parent.width
                visible: detail.blocks.blocks.length >= 2
                Column {
                    width: parent.width
                    spacing: 8
                    LearnTap {
                        width: parent.width
                        height: lapsTitle.height
                        name: qsTr("Laps")
                        onClicked: detail.openLearn("workblocks")
                        Text {
                            id: lapsTitle
                            text: qsTr("Laps")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.titleSize
                            Accessible.role: Accessible.Heading
                            Accessible.name: text
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.baseline: lapsTitle.baseline
                            text: detail.blocks.work ? qsTr("Work blocks") : qsTr("%1 laps").arg(detail.blocks.blocks.length)
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 13
                        }
                    }
                    WorkBlocks {
                        width: parent.width
                        list: detail.blocks.blocks
                        tint: detail.tint
                        estimated: detail.estimated
                        picked: detail.pickedLap
                        onLapPicked: detail.pickLap(lapIndex)
                    }
                }
            }
            Rise {
                cue: proCue
                order: 6
                width: parent.width
                visible: detail.pro && lapsSection.hasLaps
                LapsSection {
                    id: lapsSection
                    width: parent.width
                    titled: false
                    ride: detail.ride
                    samples: detail.samples
                    miles: detail.miles
                    onLapSelected: detail.pickLap(index)
                }
            }

            // share, and where the ride is kept
            Rise {
                cue: detail
                order: 6
                width: parent.width
                visible: detail.ride.start !== undefined
                Column {
                    width: parent.width
                    spacing: 14
                    PulseButton {
                        width: Math.min(parent.width, 420)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 56
                        fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                        pressedRadius: 18
                        Accessible.name: qsTr("Share")
                        Accessible.description: qsTr("Make a picture of this ride to share")
                        onClicked: detail.openShare()
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                LineIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "share"
                                    color: Theme.accentInk
                                    size: 18
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Share")
                                    color: Theme.accentInk
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: 16
                                }
                            }
                        }
                    }
                    Row {
                        visible: (detail.ride.filePath || "") !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        LineIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            color: Theme.text3
                            size: 14
                        }
                        Text {
                            text: qsTr("Saved on this phone as a FIT file")
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    LearnSheet {
        anchors.fill: parent
        open: detail.learnOpen
        entry: detail.learnEntry
        known: detail.learnIds
        tint: detail.tint
        bottomInset: detail.sheetClearance
        onClose: detail.learnOpen = false
        onRelated: detail.openLearn(id)
    }

    // the share sheet of the moments (moments/ShareSheet.qml), the ride as a fingerprint card;
    // loaded by its path so this page never waits on it
    Loader {
        id: shareLoader
        anchors.fill: parent
        active: detail.sharing
        source: "moments/ShareSheet.qml"
        onLoaded: {
            var sheet = item
            sheet.ride = Qt.binding(function () {
                return { elapsed: detail.ride.duration || 0, avgPower: detail.ride.avgPower || 0,
                         distance: (detail.ride.distance || 0) * (detail.miles ? 0.621371 : 1), miles: detail.miles,
                         kilojoules: detail.ride.kj || 0, tss: detail.ride.tss || 0, powerEstimated: detail.estimated }
            })
            sheet.moment = Qt.binding(function () {
                return { tone: detail.tintZone, title: detail.story.sentence, value: detail.story.value, unit: detail.story.unit,
                         detail: detail.story.label + (detail.story.sub !== "" ? ", " + detail.story.sub : ""),
                         kind: detail.story.record ? "record" : "", seconds: detail.story.seconds }
            })
            sheet.spark = Qt.binding(function () { return detail.ride.spark || [] })
            sheet.bars = Qt.binding(function () { return detail.shareBars })
            sheet.minutesPerBar = Qt.binding(function () { return detail.shareMinutes })
            sheet.name = Qt.binding(function () { return detail.ride.start ? Format.title(detail.ride) : "" })
            sheet.when = Qt.binding(function () { return detail.ride.start || Date.now() })
            sheet.savedImage = Qt.binding(function () { return detail.savedImage })
            sheet.failed = Qt.binding(function () { return detail.saveFailed })
        }
    }
    Connections {
        target: shareLoader.item
        ignoreUnknownSignals: true
        function onClose() { detail.sharing = false }
        function onSave() { detail.saveImage() }
    }
}
