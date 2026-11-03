import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "moments"
import "Metrics.js" as Metrics
import "moments/Moments.js" as Moments

// After the ride: the biggest moment of it up top, the other moments as cards, then the numbers.
// The summary shows right away; the power records follow once the library has read the saved
// ride, a moment later. The same item serves every ride, so a new `ride` starts it over.
Item {
    id: summary

    // a copy of the ride source, taken when the ride finished
    property var ride: ({})
    property bool demo: false
    property var library: null
    property var core: null

    signal done()
    signal openRide(int id)

    // the moments, biggest first: the first is the hero, the others are cards
    property var moments: []
    readonly property var hero: moments.length > 0 ? moments[0] : ({})
    property real finishedAt: 0
    // the newest ride of the library when the summary opened
    property int knownId: 0
    // the ride in the library once it is read, its power line, and whether its records are in
    property int savedId: 0
    property var spark: []
    property bool recordsAdded: false
    property bool sharing: false
    property string savedImage: ""

    readonly property bool awaitingImport: !demo && library !== null && finishedAt > 0 && (savedId === 0 || !recordsAdded)

    // a phone on its side gets the hero on the left; a tablet gets two centered columns
    readonly property bool split: width > height && height < 500
    readonly property bool wide: split || (width >= 840 && height >= 600)
    readonly property real margin: Theme.margin(width)
    readonly property real frameWidth: Math.min(width - margin * 2, wide ? 1040 : 560)
    readonly property real frameX: (width - frameWidth) / 2
    readonly property real leftWidth: wide ? Math.round(frameWidth * 0.44) : frameWidth
    readonly property real paneX: wide ? frameX + leftWidth + 24 : frameX
    readonly property real paneWidth: wide ? frameWidth - leftWidth - 24 : frameWidth
    readonly property int barHeight: 88

    readonly property bool estimated: ride.powerEstimated === true
    readonly property var rows: [
        [qsTr("Ride time"), Metrics.clock(ride.elapsed || 0), "", false],
        [qsTr("Average power"), Metrics.whole(ride.avgPower), "W", estimated],
        [qsTr("Normalized power"), Metrics.whole(ride.normalizedPower), "W", estimated],
        [qsTr("Training load"), Metrics.whole(ride.tss), "TSS", estimated],
        [qsTr("Work"), Metrics.whole(ride.kilojoules), "kJ", estimated],
        [qsTr("Calories"), Metrics.whole(ride.calories), "kcal", estimated],
        [qsTr("Distance"), ride.distance !== undefined ? ride.distance.toFixed(1) : "0", ride.miles ? "mi" : "km", false]
    ]

    // read with value(): a property here would keep the goal of when the app started
    Settings {
        id: goalSettings
        category: "ui2"
    }

    onRideChanged: begin()

    // a new ride: the moments known now, from the summary and the rides before it
    function begin() {
        if (ride.elapsed === undefined)
            return
        finishedAt = Date.now()
        savedId = 0
        spark = []
        recordsAdded = false
        sharing = false
        savedImage = ""
        cards.clear()
        if (demo || library === null) {
            var single = demo ? Moments.demo(ride.elapsed) : [Moments.fallback(0, ride.elapsed)]
            if (!demo)
                single[0].title = qsTr("Ride saved")
            show(single, true)
            return
        }
        var input = {
            elapsed: ride.elapsed, kj: ride.kilojoules || 0, miles: ride.miles === true,
            km: ride.miles ? (ride.distance || 0) / 0.621371 : (ride.distance || 0),
            start: finishedAt - ride.elapsed * 1000, goalMinutes: Number(goalSettings.value("weeklyGoalMinutes", 120)),
            previousStart: 0, longestBefore: 0
        }
        // the library may have read the ride already: then everything before it is what came before
        var newest = library.rides(0, 3)
        knownId = newest.length > 0 ? newest[0].id : 0
        var saved = Moments.match(newest, finishedAt, ride.elapsed)
        if (saved !== null)
            input.start = saved.start
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
        show(Moments.detect(input), true)
        if (saved !== null)
            takeSaved(saved)
    }

    // the ride is in the library: it can be opened, and its records join the moments once
    function takeSaved(saved) {
        savedId = saved.id
        spark = saved.spark || []
        var records = saved.records || []
        if (recordsAdded || records.length === 0)
            return
        recordsAdded = true
        var best = library.ride(saved.id).best || []
        var extra = Moments.recordMoments(records, best, library.powerCurve(0, saved.start))
        if (extra.length > 0)
            show(Moments.merge(moments, extra), false)
    }

    // The hero blooms when it changes; the cards keep their place and new ones slide in.
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
        if (bloom)
            heroItem.bloom()
    }

    function saveImage() {
        var folder = core !== null ? core.getWritableAppDir() : ""
        var path = folder + "bikemodo-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png"
        shareLoader.item.card.save(path, function (ok, where) {
            summary.savedImage = ok ? where : ""
            shareLoader.item.failed = !ok
        })
    }

    Connections {
        target: summary.library
        enabled: summary.awaitingImport
        ignoreUnknownSignals: true
        function onChanged() {
            var newest = summary.library.rides(0, 3)
            var saved = Moments.match(newest, summary.finishedAt, summary.ride.elapsed)
            if (saved === null)
                saved = Moments.arrived(newest, summary.knownId, summary.finishedAt, summary.ride.elapsed)
            if (saved !== null)
                summary.takeSaved(saved)
        }
    }

    ListModel { id: cards }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Glow {
        x: summary.wide ? summary.frameX + summary.leftWidth / 2 - 280 : summary.width / 2 - 280
        y: -200
        width: 560
        height: 560
        tint: Theme.zoneColors[(summary.hero.tone || 1) - 1]
        opacity: 0.18
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
        parent: summary.wide ? heroPane.contentItem : heroSlot
        width: summary.wide ? summary.leftWidth : summary.paneWidth
        y: summary.wide ? Math.max(24, (heroPane.height - height) / 2) : 0
        moment: summary.hero
        compact: summary.height < 500
        large: summary.width >= 840 && summary.height >= 600
        status: summary.demo ? qsTr("Demo ride, not saved") : qsTr("Ride saved")
        showShare: !summary.demo && summary.library !== null
        onShare: summary.sharing = true
    }

    Flickable {
        id: page
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
            spacing: 12

            Item {
                id: heroSlot
                width: parent.width
                height: heroItem.height + 12
                visible: !summary.wide
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

            Item { width: 1; height: 8 }

            Text {
                text: qsTr("This ride")
                color: Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.labelSize
            }

            Card {
                width: parent.width
                padding: 20
                spacing: 0
                Repeater {
                    model: summary.rows
                    Item {
                        width: column.width - 40
                        height: 54
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1
                            color: Theme.hairline
                            visible: index < summary.rows.length - 1
                        }
                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData[0]
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.labelSize
                            }
                            Text {
                                visible: modelData[3]
                                text: qsTr("est.")
                                color: Theme.text3
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.tertiarySize
                            }
                        }
                        Row {
                            spacing: 5
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            Numeral {
                                id: value
                                text: modelData[1]
                                color: Theme.text
                                font.pixelSize: 26
                            }
                            Text {
                                text: modelData[2]
                                color: Theme.text3
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.tertiarySize
                                anchors.baseline: value.baseline
                                visible: text !== ""
                            }
                        }
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
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 12

            PulseButton {
                id: seeRide
                visible: !summary.demo && summary.library !== null
                width: (parent.width - 12) / 2
                height: 56
                fill: Theme.chip
                pressedRadius: 18
                enabled: summary.savedId > 0
                Accessible.name: enabled ? qsTr("See the ride") : qsTr("Saving the ride")
                onClicked: summary.openRide(summary.savedId)
                contentItem: Text {
                    text: seeRide.enabled ? qsTr("See the ride") : qsTr("Saving")
                    color: seeRide.enabled ? Theme.text : Theme.text3
                    font.family: Theme.bodySemibold
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            PulseButton {
                width: seeRide.visible ? (parent.width - 12) / 2 : parent.width
                height: 56
                fill: Theme.accent
                pressedRadius: 18
                Accessible.name: qsTr("Done")
                onClicked: summary.done()
                contentItem: Text {
                    text: qsTr("Done")
                    color: Theme.accentInk
                    font.family: Theme.bodySemibold
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // the share view: the picture as it will be saved, and a button to save it
    Loader {
        id: shareLoader
        anchors.fill: parent
        active: summary.sharing
        sourceComponent: Rectangle {
            id: sheet
            property alias card: card
            property bool failed: false
            readonly property bool sideways: width > height
            readonly property real fit: sideways ? Math.min((width * 0.6 - 48) / 1080, (height - 48) / 1350)
                                                 : Math.min((width - 32) / 1080, (height - 220) / 1350)
            color: Theme.bg

            // keeps taps from reaching the summary under it
            MouseArea { anchors.fill: parent }

            Item {
                id: preview
                x: sheet.sideways ? 24 : (sheet.width - width) / 2
                y: sheet.sideways ? (sheet.height - height) / 2 : Math.max(24, (sheet.height - height - 16 - controls.height) / 2)
                width: 1080 * sheet.fit
                height: 1350 * sheet.fit
                Item {
                    width: 1080
                    height: 1350
                    scale: sheet.fit
                    transformOrigin: Item.TopLeft
                    ShareCard {
                        id: card
                        ride: summary.ride
                        moment: summary.hero
                        spark: summary.spark
                        when: summary.finishedAt
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: 4
                    border.width: 1
                    border.color: Theme.hairline
                }
            }

            Column {
                id: controls
                x: sheet.sideways ? preview.x + preview.width + 24 : 16
                width: sheet.sideways ? sheet.width - x - 24 : sheet.width - 32
                y: sheet.sideways ? (sheet.height - height) / 2 : preview.y + preview.height + 16
                spacing: 12

                Text {
                    width: parent.width
                    text: sheet.failed ? qsTr("The image could not be saved.")
                          : (summary.savedImage !== "" ? qsTr("Saved to %1").arg(summary.savedImage)
                                                       : qsTr("Save the picture of this ride to share it."))
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.labelSize
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 5
                }
                Row {
                    width: parent.width
                    spacing: 12
                    PulseButton {
                        width: (parent.width - 12) / 2
                        height: 56
                        fill: Theme.chip
                        pressedRadius: 18
                        Accessible.name: qsTr("Close")
                        onClicked: summary.sharing = false
                        contentItem: Text {
                            text: qsTr("Close")
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    PulseButton {
                        width: (parent.width - 12) / 2
                        height: 56
                        fill: Theme.accent
                        pressedRadius: 18
                        Accessible.name: qsTr("Save image")
                        onClicked: summary.saveImage()
                        contentItem: Text {
                            text: qsTr("Save image")
                            color: Theme.accentInk
                            font.family: Theme.bodySemibold
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
