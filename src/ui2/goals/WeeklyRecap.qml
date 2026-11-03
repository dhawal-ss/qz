import QtQuick 2.15
import ".."
import "../Format.js" as Format
import "Streak.js" as Streak

// The week in review: a short story of last week (from the first day of the week the rider
// picked, Streak.js), one page at a time. Time and
// rides, the biggest ride, records, the zones, the streak and goal, and a kind word to close.
// Swipe or use the buttons; on a tablet it is a card in the middle with a size it never grows past.
Item {
    id: recap

    property bool open: false
    property var library: null
    property bool miles: false
    property real monday: 0          // noon of a day of the week (its first day)
    property var rides: []           // every ride, oldest first
    property var histories: ({})     // recordHistory() per duration
    property var streakResult: null  // Streak.run()
    property string goalWords: ""    // "120 min"
    property string nextGoalWords: ""

    signal close()

    property var pages: []

    visible: open || card.opacity > 0
    Accessible.ignored: !open

    onOpenChanged: {
        if (open) {
            build()
            list.positionViewAtIndex(0, ListView.Beginning)
            list.currentIndex = 0
        }
    }

    function range() {
        var from = Streak.weekStartOf(monday)
        var start = new Date(from)
        start.setHours(0, 0, 0, 0)
        var end = new Date(Streak.addWeeks(from, 1))
        end.setHours(0, 0, 0, 0)
        return { from: start.getTime(), to: end.getTime() }
    }

    function build() {
        var r = range()
        var weekRides = rides.filter(function (x) { return x.start >= r.from && x.start < r.to })
        var lastDay = new Date(r.to - 12 * 3600000)
        var overline = qsTr("Your week, %1 to %2").arg(Format.day(r.from)).arg(Format.day(lastDay.getTime()))
        var out = []
        var seconds = 0, km = 0, kj = 0
        var longest = null
        for (var i = 0; i < weekRides.length; i++) {
            seconds += weekRides[i].duration
            km += weekRides[i].distance
            kj += weekRides[i].kj
            if (!longest || weekRides[i].duration > longest.duration)
                longest = weekRides[i]
        }

        if (weekRides.length === 0) {
            out.push({ overline: overline, big: "", unit: "", tone: 2,
                       title: qsTr("A quiet week"),
                       detail: qsTr("Rest is part of training too. The bike will be here when you are ready.") })
        } else {
            out.push({ overline: overline, big: String(weekRides.length), unit: weekRides.length === 1 ? qsTr("ride") : qsTr("rides"), tone: 7,
                       title: qsTr("%1 on the bike").arg(Format.hours(seconds)),
                       detail: qsTr("%1 and %2 kJ of work.").arg(Format.distance(km, miles)).arg(Format.big(kj)) })
            out.push({ overline: qsTr("Best moment"), big: String(Math.round(longest.duration / 60)), unit: qsTr("min"), tone: 3,
                       title: qsTr("Your longest ride, %1").arg(Format.day(longest.start)),
                       detail: qsTr("%1 at %2 W on average.").arg(Format.distance(longest.distance, miles)).arg(Math.round(longest.avgPower || 0)) })

            // new records of 5 s or more that beat an earlier best
            var found = []
            for (var s in histories) {
                var h = histories[s] || []
                if (Number(s) < 5)
                    continue
                for (var j = 1; j < h.length; j++)
                    if (h[j].start >= r.from && h[j].start < r.to && found.indexOf(Number(s)) < 0)
                        found.push(Number(s))
            }
            found.sort(function (a, b) { return a - b })
            if (found.length > 0) {
                var names = found.slice(0, 4).map(function (x) { return Format.effort(x) })
                out.push({ overline: qsTr("Records"), big: String(found.length), unit: found.length === 1 ? qsTr("new record") : qsTr("new records"), tone: 7,
                           title: found.length > 4 ? qsTr("New bests at %1 and more").arg(names.join(", ")) : qsTr("New bests at %1").arg(names.join(", ")),
                           detail: qsTr("Stronger than ever before, over these durations.") })
            } else {
                out.push({ overline: qsTr("Records"), big: "", unit: "", tone: 2,
                           title: qsTr("No new records this week"),
                           detail: qsTr("Steady weeks are what records grow from.") })
            }

            // time in zones over the week's rides
            var power = [0, 0, 0, 0, 0, 0, 0]
            var heart = [0, 0, 0, 0, 0]
            var powerSum = 0, heartSum = 0
            if (library) {
                for (var k = 0; k < weekRides.length; k++) {
                    var full = library.ride(weekRides[k].id)
                    var pz = full.powerZones || []
                    var hz = full.hrZones || []
                    for (var p = 0; p < pz.length && p < 7; p++) { power[p] += Number(pz[p]) || 0; powerSum += Number(pz[p]) || 0 }
                    for (var q = 0; q < hz.length && q < 5; q++) { heart[q] += Number(hz[q]) || 0; heartSum += Number(hz[q]) || 0 }
                }
            }
            var usePower = powerSum > 0
            var zones = usePower ? power : heart
            var total = usePower ? powerSum : heartSum
            if (total > 0) {
                var top = 0
                for (var z = 1; z < zones.length; z++)
                    if (zones[z] > zones[top])
                        top = z
                var zoneNames = usePower ? Theme.powerZoneNames : Theme.heartZoneNames
                out.push({ overline: usePower ? qsTr("Where you rode, by power") : qsTr("Where you rode, by heart rate"),
                           big: String(Math.round(100 * zones[top] / total)), unit: "%", tone: top + 1,
                           title: qsTr("Mostly %1").arg(zoneNames[top]),
                           detail: qsTr("%1 of the week in zone %2.").arg(Format.hours(zones[top])).arg(top + 1),
                           zones: zones.map(function (v) { return v / total }), heart: !usePower })
            }
        }

        // the streak and goal of that week
        var entry = null
        var key = Streak.weekKey(monday)
        var timeline = streakResult ? streakResult.timeline : []
        for (var t = 0; t < timeline.length; t++)
            if (timeline[t].key === key)
                entry = timeline[t]
        var status = entry ? entry.status : "none"
        var run = entry ? entry.streak : 0
        var titles = {
            met: qsTr("Goal met: %1").arg(goalWords),
            frozen: qsTr("A freeze kept your streak going"),
            rest: qsTr("A rest week, the streak waited for you"),
            missed: qsTr("Goal of %1, not this time").arg(goalWords),
            none: qsTr("Your streak starts with a goal week")
        }
        var details = {
            met: run > 1 ? qsTr("%1 weeks in a row now.").arg(run) : qsTr("A streak starts here."),
            frozen: qsTr("You earned it with 4 goal weeks. That is what it is for."),
            rest: qsTr("Rest, sick or injured weeks pause the streak and cost nothing."),
            missed: qsTr("This week is a fresh start."),
            none: qsTr("Meet your weekly goal to start one.")
        }
        out.push({ overline: qsTr("Streak and goal"), big: run > 0 ? String(run) : "", unit: qsTr("week streak"),
                   tone: status === "met" ? 3 : (status === "frozen" ? 1 : 5), title: titles[status] || titles.none, detail: details[status] || details.none })

        var closing = [qsTr("See you on the bike."), qsTr("Every ride adds up."), qsTr("Consistency builds fitness."), qsTr("Showing up is the hard part.")]
        out.push({ overline: qsTr("This week"), big: "", unit: "", tone: 2,
                   title: closing[Streak.weekKey(monday) % closing.length],
                   detail: qsTr("This week's goal: %1. One ride at a time.").arg(nextGoalWords) })
        pages = out
    }

    // dims the page behind, a tap there closes it
    PulseButton {
        anchors.fill: parent
        radius: 0
        pressedScale: 1
        fill: Qt.rgba(5 / 255, 5 / 255, 6 / 255, recap.open ? 0.75 : 0)
        Accessible.name: qsTr("Close the week in review")
        onClicked: recap.close()
    }

    Rectangle {
        id: card
        width: Math.min(recap.width - 32, 460)
        height: Math.min(recap.height - 32, 780)
        anchors.centerIn: parent
        radius: 28
        color: Theme.surface
        // a phone on its side: less room above and below the page
        readonly property bool tight: height < 480
        clip: true
        opacity: recap.open ? 1 : 0
        scale: recap.open ? 1 : 0.94
        Behavior on opacity {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
        }
        Behavior on scale {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.medium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
        }

        MouseArea { anchors.fill: parent }

        // the page tint glows from the top
        Rectangle {
            id: glow
            width: parent.width
            height: parent.height * 0.6
            readonly property var page: recap.pages[list.currentIndex] || { tone: 1 }
            property color tint: Theme.zoneColors[(page.tone || 1) - 1]
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.22) }
                GradientStop { position: 1; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0) }
            }
            Behavior on tint {
                enabled: !Theme.reduceMotion
                ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
        }

        // story segments, one per page
        Row {
            id: segments
            x: 20
            y: 16
            width: card.width - 40
            spacing: 4
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("Page %1 of %2").arg(list.currentIndex + 1).arg(recap.pages.length)
            Repeater {
                model: recap.pages.length
                Rectangle {
                    width: (segments.width - segments.spacing * (recap.pages.length - 1)) / Math.max(1, recap.pages.length)
                    height: 4
                    radius: 2
                    color: index <= list.currentIndex ? Theme.text : Qt.rgba(1, 1, 1, 0.18)
                }
            }
        }

        PulseButton {
            x: card.width - width - 8
            y: 28
            width: 48
            height: 48
            fill: pressed ? Theme.pressed : "transparent"
            Accessible.name: qsTr("Close the week in review")
            onClicked: recap.close()
            contentItem: Item {
                Icon { anchors.centerIn: parent; name: "close"; size: 20; color: Theme.text }
            }
        }

        ListView {
            id: list
            y: card.tight ? 60 : 80
            width: card.width
            height: card.height - y - (card.tight ? 68 : 80)
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: Theme.reduceMotion ? 0 : Theme.medium
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: recap.pages
            delegate: Item {
                id: recapPage
                width: list.width
                height: list.height
                readonly property color tint: Theme.zoneColors[(modelData.tone || 1) - 1]
                readonly property bool roomy: height > 360
                readonly property int titleSize: roomy ? 30 : 22

                Column {
                    x: 28
                    width: parent.width - 56
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: recapPage.roomy ? 16 : 8
                    Text {
                        width: parent.width
                        text: modelData.overline
                        color: Theme.text3
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                        wrapMode: Text.WordWrap
                    }
                    Item {
                        visible: modelData.big !== ""
                        width: parent.width
                        height: bigNumber.height
                        Row {
                            spacing: 10
                            Numeral {
                                id: bigNumber
                                text: modelData.big
                                color: recapPage.tint
                                font.family: Theme.celebrate
                                font.pixelSize: recapPage.roomy ? 96 : 48
                            }
                            Text {
                                anchors.bottom: parent.bottom
                                text: modelData.unit
                                color: Theme.text2
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.titleSize
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        text: modelData.title
                        color: Theme.text
                        font.family: Theme.display
                        font.pixelSize: recapPage.titleSize
                        lineHeightMode: Text.FixedHeight
                        lineHeight: Math.round(recapPage.titleSize * 1.2)
                        wrapMode: Text.WordWrap
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    // the zones as one bar
                    Row {
                        visible: modelData.zones !== undefined
                        width: parent.width
                        height: 20
                        spacing: 2
                        Accessible.role: Accessible.Graphic
                        Accessible.name: modelData.detail
                        Repeater {
                            model: modelData.zones || []
                            Rectangle {
                                visible: modelData > 0.005
                                width: Math.max(2, (recapPage.width - 56 - 2 * 6) * modelData)
                                height: 20
                                radius: 4
                                color: Theme.zoneColors[index]
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        text: modelData.detail
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.bodySize
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // back and next
        Item {
            x: 16
            y: card.height - (card.tight ? 60 : 68)
            width: card.width - 32
            height: 52
            PulseButton {
                id: backButton
                visible: list.currentIndex > 0
                width: backLabel.implicitWidth + 40
                height: 52
                fill: pressed ? Theme.pressed : Theme.chip
                Accessible.name: qsTr("Previous page")
                onClicked: list.decrementCurrentIndex()
                contentItem: Text {
                    id: backLabel
                    text: qsTr("Back")
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            PulseButton {
                id: nextButton
                anchors.right: parent.right
                width: nextLabel.implicitWidth + 48
                height: 52
                fill: pressed ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                readonly property bool last: list.currentIndex >= recap.pages.length - 1
                Accessible.name: last ? qsTr("Done, close the week in review") : qsTr("Next page")
                onClicked: {
                    if (last)
                        recap.close()
                    else
                        list.incrementCurrentIndex()
                }
                contentItem: Text {
                    id: nextLabel
                    text: nextButton.last ? qsTr("Done") : qsTr("Next")
                    color: Theme.accentInk
                    font.family: Theme.bodySemibold
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
