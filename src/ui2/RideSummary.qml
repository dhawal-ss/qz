import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "sig"
import "moments"
import "Format.js" as Format
import "Metrics.js" as Metrics
import "moments/Moments.js" as Moments
import "goals/Streak.js" as Streak

// After the ride, in the Signature language. The biggest moments come full screen first: a new
// power record blooms (PrMoment) and settles into the badge of the summary, and a ride that
// closes the weekly goal shows the week closed with its rings (WeekClosed). Then the summary:
// the biggest moment as a coach would say it with its number, the other moments as quiet rows,
// and the numbers of the ride on hairlines. Share opens the ride fingerprint.
// The summary shows right away; the power records follow once the library has read the saved
// ride, a moment later. The same item serves every ride, so a new `ride` starts it over.
// A ride saved soon after the one before joins it in the library (ui2/mergeGapMinutes): it keeps
// the id of the ride before and starts with it, so the saved ride is found by its end
// (Moments.match), and once it shows it was merged the moments are worked out again without the
// part from before (Moments.earlierPart): the same ride goes on, the count of rides does not grow.
Item {
    id: summary

    // a copy of the ride source, taken when the ride finished (main2 copyRide: endedAt is when it
    // was paused for a ride ended while paused, else 0)
    property var ride: ({})
    property bool demo: false
    property var library: null
    property var core: null
    // the app can hand a saved picture to Android's share sheet (see shareImage)
    property bool canShare: false

    signal done()
    signal openRide(int id)
    // Plan next week on Week closed: the goals
    signal planWeek()
    // Share on the share view: the picture is saved at path, ready to hand to the share sheet
    signal shareImage(string path)
    // the summary rises in: when it opens and when a full-screen moment settles
    signal entered()

    // the moments, biggest first: the first is the hero, the others are rows
    property var moments: []
    readonly property var hero: moments.length > 0 ? moments[0] : ({})
    property real finishedAt: 0
    // when the ride ended: its last second is in the saved file then
    property real endedAt: 0
    // the newest ride of the library when the summary opened, { id, end }, until this ride is found
    property int knownId: 0
    property var known: null
    // the moments know this ride joined the ride before it
    property bool continuedShown: false
    // this ride's own numbers, for Moments.earlierPart()
    function session() {
        return { elapsed: ride.elapsed || 0, kj: ride.kilojoules || 0, tss: ride.tss || 0,
                 km: ride.miles ? (ride.distance || 0) / 0.621371 : (ride.distance || 0) }
    }

    // what Moments.detect() needs: the rides before this one, from the library ride that holds it
    // when it is there (saved), else from everything the library has
    function inputFor(saved) {
        var goal = goalInput()
        var own = session()
        var input = {
            elapsed: own.elapsed, kj: own.kj, tss: own.tss, km: own.km, miles: ride.miles === true,
            start: endedAt - own.elapsed * 1000, goalKind: goal.kind, goalValue: goal.value, restWeeks: goal.rest,
            previousStart: 0, longestBefore: 0, continued: null
        }
        if (saved !== null) {
            input.start = saved.start
            input.continued = Moments.earlierPart(saved, own)
        }
        var bound = saved !== null ? saved.start : 0
        input.before = library.totals(0, bound)
        input.days = library.days(0, bound)
        var earlier = library.rides(0, 1000)
        for (var i = 0; i < earlier.length; i++) {
            if (saved !== null && earlier[i].start >= saved.start)
                continue
            if (input.previousStart === 0)
                input.previousStart = earlier[i].start
            input.longestBefore = Math.max(input.longestBefore, earlier[i].duration)
        }
        return input
    }

    // the ride in the library once it is read, its power line, and whether its records are in
    property int savedId: 0
    property var spark: []
    property bool recordsAdded: false
    property bool sharing: false
    property string savedImage: ""
    property bool saveFailed: false
    // the fingerprint of the share card: [{ watts, zone }] and the minutes a bar stands for
    property var bars: []
    property int minutesPerBar: 1
    property string rideName: ""

    // the full-screen moments: "record" and "week", one after the other
    property var overlayQueue: []
    property string overlay: ""
    property bool overlaysReady: false
    property var overlaysSeen: ({})
    property var recordMoment: null
    property var goalMoment: null

    readonly property bool awaitingImport: !demo && library !== null && finishedAt > 0 && (savedId === 0 || !recordsAdded)

    // a phone on its side gets the hero on the left; a tablet gets two centered columns
    readonly property bool split: width > height && height < 500
    readonly property bool wide: split || (width >= 840 && height >= 600)
    readonly property real margin: width < 400 ? 16 : 24
    readonly property real frameWidth: Math.min(width - margin * 2, wide ? 1040 : 560)
    readonly property real frameX: (width - frameWidth) / 2
    readonly property real leftWidth: wide ? Math.round(frameWidth * 0.44) : frameWidth
    readonly property real paneX: wide ? frameX + leftWidth + 32 : frameX
    readonly property real paneWidth: wide ? frameWidth - leftWidth - 32 : frameWidth
    readonly property int barHeight: 92

    readonly property bool estimated: ride.powerEstimated === true
    // training load needs the rider's own FTP (Theme.ftpSet): without it, it is left out
    readonly property var rows: [
        [qsTr("Ride time"), Metrics.clock(ride.elapsed || 0), "", false],
        [qsTr("Average power"), Metrics.whole(ride.avgPower), "W", estimated],
        [qsTr("Normalized power"), Metrics.whole(ride.normalizedPower), "W", estimated],
        Theme.ftpSet ? [qsTr("Training load"), Metrics.whole(ride.tss), "TSS", estimated] : null,
        [qsTr("Work"), Metrics.whole(ride.kilojoules), "kJ", estimated],
        [qsTr("Calories"), Metrics.whole(ride.calories), "kcal", estimated],
        [qsTr("Distance"), ride.distance !== undefined ? ride.distance.toFixed(1) : "0", ride.miles ? "mi" : "km", false]
    ].filter(function (r) { return r !== null })
    readonly property var keyItems: rows.map(function (r) { return { value: r[1], unit: r[2], label: r[0], estimated: r[3] } })

    // read with value(): a property here would keep the goal of when the app started
    Settings {
        id: goalSettings
        category: "ui2"
    }

    onRideChanged: begin()
    // the share view opened before the ride was saved: its minutes are there now
    onSavedIdChanged: if (sharing && savedId > 0) fingerprint()

    // the weekly goal as Goals stores it, and the rest weeks with a pause in them
    function goalInput() {
        var kind = String(goalSettings.value("goalKind", "minutes"))
        if (Streak.kinds.indexOf(kind) < 0)
            kind = "minutes"
        var value = Number(goalSettings.value(Streak.settingKeys[kind], Streak.defaults[kind])) || Streak.defaults[kind]
        var rest = Streak.parseList(String(goalSettings.value("restWeeks", "[]")))
        var pause = Streak.parsePause(String(goalSettings.value("goalsPause", "")))
        if (pause !== null)
            rest = Streak.withPause(rest, {}, pause, Date.now()).rest
        return { kind: kind, value: value, rest: rest }
    }

    // a new ride: the moments known now, from the summary and the rides before it
    function begin() {
        if (ride.elapsed === undefined)
            return
        finishedAt = Date.now()
        endedAt = ride.endedAt > 0 ? ride.endedAt : finishedAt
        savedId = 0
        known = null
        continuedShown = false
        spark = []
        recordsAdded = false
        sharing = false
        savedImage = ""
        saveFailed = false
        bars = []
        rideName = ""
        overlayQueue = []
        overlay = ""
        overlaysReady = false
        overlaysSeen = {}
        recordMoment = null
        goalMoment = null
        cards.clear()
        page.contentY = 0
        heroPane.contentY = 0
        if (demo || library === null) {
            var single = demo ? Moments.demo(ride.elapsed) : [Moments.fallback(0, ride.elapsed)]
            if (!demo)
                single[0].title = qsTr("Ride saved")
            show(single, true)
            entered()
            return
        }
        // the library may have read the ride already: then everything before it is what came before
        var newest = library.rides(0, 3)
        knownId = newest.length > 0 ? newest[0].id : 0
        var saved = Moments.match(newest, endedAt, ride.elapsed, null)
        known = saved === null && newest.length > 0 ? { id: newest[0].id, end: newest[0].end || 0 } : null
        var input = inputFor(saved)
        continuedShown = input.continued !== null
        show(Moments.detect(input), true)
        entered()
        // the records may still come: the full-screen moments wait a moment for them
        overlayWait.restart()
        if (saved !== null)
            takeSaved(saved)
    }

    // the ride is in the library: it can be opened, and its records join the moments once
    function takeSaved(saved) {
        savedId = saved.id
        known = null
        spark = saved.spark || []
        rideName = Format.title(saved)
        // it joined the ride before it: the moments again, without the part from before
        if (!continuedShown && Moments.earlierPart(saved, session()) !== null) {
            continuedShown = true
            // a Week closed worked out before is dropped unless it is showing: show() queues it
            // again when the week is still closed with the part from before counted once
            if (overlay !== "week") {
                goalMoment = null
                overlayQueue = overlayQueue.filter(function (k) { return k !== "week" })
                var seen = {}
                for (var k in overlaysSeen)
                    if (k !== "week")
                        seen[k] = overlaysSeen[k]
                overlaysSeen = seen
            }
            show(Moments.detect(inputFor(saved)), false)
        }
        // a rescan reads the ride in before it marks the records: until they are there, keep listening
        var records = saved.records || []
        if (recordsAdded || records.length === 0)
            return
        recordsAdded = true
        var best = library.ride(saved.id).best || []
        // records race rides with the same kind of watts (estimated or measured) as this one
        var extra = Moments.recordMoments(records, best, library.powerCurve(0, saved.start, saved.powerEstimated === true ? 1 : 0))
        if (extra.length > 0)
            show(Moments.merge(moments, extra), false)
        startOverlays()
    }

    // The hero blooms when it changes; the rows keep their place and new ones slide in. The
    // moments that come full screen join the queue.
    function show(list, fresh) {
        var bloom = fresh || moments.length === 0 || list[0].key !== moments[0].key
        moments = list
        var rest = list.slice(1)
        var keep = {}
        for (var i = 0; i < rest.length; i++)
            keep[rest[i].key] = true
        for (var j = cards.count - 1; j >= 0; j--)
            if (!keep[cards.get(j).key])
                cards.remove(j)
        var arrived = 0
        for (var k = 0; k < rest.length; k++) {
            var at = -1
            for (var n = 0; n < cards.count; n++)
                if (cards.get(n).key === rest[k].key)
                    at = n
            if (at === k)
                continue
            if (at >= 0) {
                cards.move(at, k, 1)
                continue
            }
            var card = rest[k]
            cards.insert(k, { key: card.key, kind: card.kind, title: card.title, detail: card.detail,
                              value: card.value, unit: card.unit, tone: card.tone,
                              delay: (fresh ? 420 : 200) + arrived * 90 })
            arrived++
        }
        for (var m = 0; m < list.length; m++) {
            if (list[m].kind === "record" && recordMoment === null && !demo) {
                recordMoment = list[m]
                queueOverlay("record")
            }
            if (list[m].week !== undefined && goalMoment === null && !demo) {
                goalMoment = list[m]
                queueOverlay("week")
            }
        }
        if (bloom)
            heroItem.bloom()
    }

    function queueOverlay(kind) {
        if (overlaysSeen[kind])
            return
        var seen = overlaysSeen
        seen[kind] = true
        overlaysSeen = seen
        var queue = overlayQueue.slice()
        // a record comes before the week
        if (kind === "record")
            queue.unshift(kind)
        else
            queue.push(kind)
        overlayQueue = queue
        if (overlay === "" && overlaysReady)
            nextOverlay()
    }

    function startOverlays() {
        overlayWait.stop()
        overlaysReady = true
        if (overlay === "")
            nextOverlay()
    }

    // the next full-screen moment, or back to the summary, which rises in again
    function nextOverlay() {
        var was = overlay
        if (overlayQueue.length === 0) {
            overlay = ""
            if (was === "record")
                heroItem.rise()
            if (was !== "")
                entered()
            return
        }
        var queue = overlayQueue.slice()
        overlay = queue.shift()
        overlayQueue = queue
    }

    // where the badge of the hero is, for the record's shape to land in
    function badgeSpot() {
        page.contentY = 0
        heroPane.contentY = 0
        var b = heroItem.badge
        var p = b.mapToItem(summary, b.width / 2, b.height / 2)
        return { x: p.x, y: p.y, size: b.width }
    }

    // one bar per minute of the saved ride, at most 120 (longer rides get a bar per few minutes)
    function fingerprint() {
        var minutes = Math.max(1, Math.round((ride.elapsed || 0) / 60))
        var count = Math.min(120, minutes)
        minutesPerBar = Math.max(1, Math.round(minutes / count))
        var power = []
        var ftp = 0
        if (savedId > 0 && library !== null) {
            var detail = library.ride(savedId)
            ftp = Number(detail.ftp) || 0
            var samples = library.samples(savedId, count)
            power = Moments.buckets(samples.power || [], count)
        }
        if (power.length < 2)
            power = spark
        bars = power.map(function (w) { return { watts: w, zone: ftp > 0 ? Theme.powerZone(w, ftp) : 0 } })
    }

    function openShare() {
        fingerprint()
        savedImage = ""
        saveFailed = false
        sharing = true
    }

    function imagePath() {
        var folder = core !== null ? core.getWritableAppDir() : ""
        return folder + "bikemodo-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png"
    }

    function saveImage() {
        shareLoader.item.card.save(imagePath(), function (ok, where) {
            summary.savedImage = ok ? where : ""
            summary.saveFailed = !ok
        })
    }

    function shareNow() {
        shareLoader.item.card.save(imagePath(), function (ok, where) {
            summary.saveFailed = !ok
            if (ok)
                summary.shareImage(where)
        })
    }

    Timer {
        id: overlayWait
        interval: 1500
        onTriggered: summary.startOverlays()
    }

    Connections {
        target: summary.library
        enabled: summary.awaitingImport
        ignoreUnknownSignals: true
        function onChanged() {
            var newest = summary.library.rides(0, 3)
            var saved = Moments.match(newest, summary.endedAt, summary.ride.elapsed, summary.known)
            if (saved !== null)
                summary.takeSaved(saved)
        }
    }

    ListModel { id: cards }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // the glow of the moment, behind its badge
    Item {
        anchors.fill: parent
        opacity: summary.overlay === "" ? 1 : 0
        HeroGlow {
            readonly property point center: {
                var moved = page.contentY + heroPane.contentY + heroItem.y + heroItem.width + heroItem.badge.x + heroItem.badge.width + summary.width + summary.height + (summary.overlay === "" ? 1 : 0)
                return heroItem.badge.mapToItem(summary, heroItem.badge.width / 2, heroItem.badge.height / 2)
            }
            width: 420
            height: 420
            x: center.x - width / 2
            y: center.y - height / 2
            tint: heroItem.tint
            low: 0.22
            high: 0.34
        }
    }

    // the hero: in the left pane when wide, else at the top of the page
    Flickable {
        id: heroPane
        x: summary.frameX
        width: summary.leftWidth
        height: summary.height
        visible: summary.wide
        contentHeight: Math.max(height, heroItem.height + 48)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    }

    MomentHero {
        id: heroItem
        objectName: "summaryHero"
        parent: summary.wide ? heroPane.contentItem : heroSlot
        width: summary.wide ? summary.leftWidth : summary.paneWidth
        y: summary.wide ? Math.max(24, (heroPane.height - height) / 2) : 0
        moment: summary.hero
        compact: summary.height < 500
        large: summary.width >= 840 && summary.height >= 600
        estimated: summary.estimated
        status: summary.demo ? qsTr("Demo ride, not saved")
                             : (summary.continuedShown ? qsTr("Saved, joined to the ride before") : qsTr("Ride saved"))
        showShare: !summary.demo && summary.library !== null
        badgeHidden: summary.recordMoment !== null && summary.hero === summary.recordMoment
                     && (summary.overlay === "record" || summary.overlayQueue.indexOf("record") >= 0)
        onShare: summary.openShare()
    }

    Flickable {
        id: page
        objectName: "summaryFlick"
        x: summary.paneX
        width: summary.paneWidth
        height: summary.height - summary.barHeight
        contentHeight: column.height + 48
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            width: parent.width
            y: 24

            Item {
                id: heroSlot
                width: parent.width
                height: heroItem.height
                visible: !summary.wide
            }

            Item { width: 1; height: summary.wide ? 0 : 34; visible: cards.count > 0 }
            Rise {
                cue: summary
                order: 2
                width: parent.width
                visible: cards.count > 0
                CapLabel {
                    text: qsTr("More from this ride")
                }
            }
            Repeater {
                model: cards
                MomentCard {
                    width: column.width
                    title: model.title
                    detail: model.detail
                    value: model.value
                    unit: model.unit
                    tone: model.tone
                    delay: model.delay
                    arrive: true
                }
            }

            Item { width: 1; height: 34 }
            Rise {
                cue: summary
                order: 3
                width: parent.width
                Column {
                    width: parent.width
                    spacing: 4
                    CapLabel {
                        text: qsTr("This ride")
                    }
                    KeyNumbers {
                        width: parent.width
                        columns: width >= 640 ? 4 : 2
                        items: summary.keyItems
                        valueSize: 26
                    }
                }
            }
        }
    }

    // the page fades out above the buttons
    Rectangle {
        x: summary.paneX
        y: summary.height - summary.barHeight - height
        width: summary.paneWidth
        height: 24
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0) }
            GradientStop { position: 1; color: Theme.bg }
        }
    }

    // the way out, always in reach
    Rectangle {
        x: summary.paneX
        y: summary.height - summary.barHeight
        width: summary.paneWidth
        height: summary.barHeight
        color: Theme.bg

        Row {
            y: 8
            width: parent.width
            spacing: 10

            PulseButton {
                id: seeRide
                visible: !summary.demo && summary.library !== null
                width: (parent.width - 10) * 0.42
                height: 64
                fill: pressed ? Theme.chip : Theme.pressed
                pressedRadius: 20
                enabled: summary.savedId > 0
                Accessible.name: enabled ? qsTr("See the ride") : qsTr("Saving the ride")
                onClicked: summary.openRide(summary.savedId)
                contentItem: Text {
                    text: seeRide.enabled ? qsTr("See the ride") : qsTr("Saving")
                    color: seeRide.enabled ? Theme.text : Theme.text3
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(16)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            PulseButton {
                width: seeRide.visible ? parent.width - seeRide.width - 10 : parent.width
                height: 64
                fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                pressedRadius: 20
                Accessible.name: qsTr("Done")
                onClicked: summary.done()
                contentItem: Text {
                    text: qsTr("Done")
                    color: Theme.accentInk
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(18)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // a new record, full screen, settling into the badge
    Loader {
        id: prLoader
        anchors.fill: parent
        active: summary.overlay === "record" && summary.recordMoment !== null
        sourceComponent: PrMoment {
            objectName: "prMoment"
            moment: summary.recordMoment
            estimated: summary.estimated
            status: qsTr("Ride saved")
            badgeAt: summary.badgeSpot
            onFinished: summary.nextOverlay()
            Component.onCompleted: play()
        }
    }

    // the weekly goal closed by this ride, full screen
    Loader {
        id: weekLoader
        anchors.fill: parent
        active: summary.overlay === "week" && summary.goalMoment !== null
        sourceComponent: WeekClosed {
            objectName: "weekClosed"
            week: summary.goalMoment.week
            miles: summary.ride.miles === true
            onClose: summary.nextOverlay()
            onPlan: {
                summary.planWeek()
                summary.nextOverlay()
            }
            Component.onCompleted: show()
        }
    }

    // the share view: the ride fingerprint as it will be saved
    Loader {
        id: shareLoader
        anchors.fill: parent
        active: summary.sharing
        sourceComponent: ShareSheet {
            ride: summary.ride
            moment: summary.hero
            spark: summary.spark
            bars: summary.bars
            minutesPerBar: summary.minutesPerBar
            name: summary.rideName !== "" ? summary.rideName : Format.title({ title: "", start: summary.finishedAt - (summary.ride.elapsed || 0) * 1000 })
            when: summary.finishedAt
            canShare: summary.canShare
            savedImage: summary.savedImage
            failed: summary.saveFailed
            onClose: summary.sharing = false
            onSave: summary.saveImage()
            onShare: summary.shareNow()
        }
    }
}
