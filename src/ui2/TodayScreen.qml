import QtQuick 2.15
import "."
import "Format.js" as Format

// Home: something new about you first, the ride one tap away. Cards flow in one column on
// phones and two on wide windows.
Item {
    id: today

    property var library: null
    property bool connected: false
    property string deviceName: ""
    property string searchStatus: ""
    property bool miles: false
    property string nickname: ""
    property bool showYou: true
    property string initial: "B"

    signal rideRequested()
    signal demoRequested()
    signal searchAgain()
    signal openYou()
    signal openRide(int id)
    signal openTab(string name)

    property var week: ({})
    property var weekBars: [0, 0, 0, 0, 0, 0, 0]
    property var latest: null
    property var bests: []
    property var lifetime: ({})
    property int rideCount: 0

    readonly property string greeting: {
        var hour = new Date().getHours()
        var who = nickname !== "" ? ", " + nickname : ""
        if (hour < 5 || hour >= 18)
            return qsTr("Good evening") + who
        if (hour < 12)
            return qsTr("Good morning") + who
        return qsTr("Good afternoon") + who
    }

    function refresh() {
        if (!library) {
            rideCount = 0
            return
        }
        rideCount = library.rideCount
        var monday = Format.weekStart(Date.now())
        week = library.totals(monday, 0)
        var bars = [0, 0, 0, 0, 0, 0, 0]
        var days = library.days(monday, 0)
        for (var i = 0; i < days.length; i++) {
            var slot = Math.round((Format.startOfDay(days[i].day) - monday) / 86400000)
            if (slot >= 0 && slot < 7)
                bars[slot] += days[i].seconds / 60
        }
        weekBars = bars
        var last = library.rides(0, 1)
        latest = last.length > 0 ? last[0] : null
        var curve = library.powerCurve(0, 0)
        var want = [5, 60, 300, 1200]
        var picked = []
        for (var j = 0; j < want.length; j++)
            for (var k = 0; k < curve.length; k++)
                if (curve[k].seconds === want[j])
                    picked.push(curve[k])
        bests = picked
        lifetime = library.totals(0, 0)
    }

    onLibraryChanged: refresh()
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections {
        target: today.library
        ignoreUnknownSignals: true
        function onChanged() { today.refresh() }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            readonly property real margin: Theme.margin(today.width)
            readonly property bool twoColumns: today.width >= 680
            readonly property real columnWidth: twoColumns ? (width - 16) / 2 : width
            x: margin
            width: Math.min(today.width - margin * 2, 1120)
            spacing: 16

            PageHeader {
                width: parent.width
                title: today.greeting
                subtitle: new Date().toLocaleDateString(Qt.locale(), "dddd d MMMM")
                showYou: today.showYou
                initial: today.initial
                onOpenYou: today.openYou()
            }

            Flow {
                width: parent.width
                spacing: 16

                // the bike and the way into the ride
                Card {
                    width: content.columnWidth
                    Row {
                        spacing: 14
                        width: parent.width
                        PulseShape {
                            width: 44
                            height: 44
                            zone: today.connected ? 2 : 1
                            color: today.connected ? Theme.zoneColors[1] : Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            spacing: 3
                            width: parent.width - 58
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                text: today.connected ? qsTr("Bike connected") : qsTr("Looking for your bike")
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.titleSize
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                width: parent.width
                                text: today.connected ? today.deviceName
                                      : (today.searchStatus !== "" ? today.searchStatus : qsTr("Wake the bike by pedaling a few turns."))
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.labelSize
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    PulseButton {
                        width: parent.width
                        height: 56
                        fill: Theme.accent
                        pressedRadius: 18
                        Accessible.name: primary.text
                        onClicked: today.connected ? today.rideRequested() : today.searchAgain()
                        contentItem: Text {
                            id: primary
                            text: today.connected ? qsTr("Ride") : qsTr("Search again")
                            color: Theme.accentInk
                            font.family: Theme.bodySemibold
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    PulseButton {
                        width: parent.width
                        height: 48
                        fill: Theme.control
                        pressedRadius: 18
                        Accessible.name: qsTr("Try a demo ride")
                        onClicked: today.demoRequested()
                        contentItem: Item {
                            Text {
                                x: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Try a demo ride")
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: 14
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                                text: qsTr("no bike needed")
                                color: Theme.text3
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.tertiarySize
                            }
                        }
                    }
                }

                // this week
                Card {
                    width: content.columnWidth
                    Text {
                        text: qsTr("This week")
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                    }
                    Row {
                        spacing: 28
                        Column {
                            Numeral {
                                text: Format.hours(today.week.seconds || 0)
                                color: Theme.text
                                font.pixelSize: 40
                            }
                            Item { width: 1; height: 8 }
                            Text {
                                text: (today.week.rides || 0) === 1 ? qsTr("1 ride") : qsTr("%1 rides").arg(today.week.rides || 0)
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.labelSize
                            }
                        }
                        Column {
                            anchors.bottom: parent.bottom
                            spacing: 4
                            Text {
                                text: Format.distance(today.week.distance || 0, today.miles)
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: 15
                            }
                            Text {
                                text: Format.big(today.week.kj || 0) + " kJ"
                                color: Theme.text2
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.labelSize
                            }
                        }
                    }
                    BarChart {
                        width: parent.width
                        height: 96
                        values: today.weekBars
                        labels: ["M", "T", "W", "T", "F", "S", "S"]
                        highlight: (new Date().getDay() + 6) % 7
                    }
                }

                // the latest ride
                Card {
                    width: content.columnWidth
                    visible: today.latest !== null
                    PulseButton {
                        width: parent.width
                        height: latestColumn.implicitHeight
                        fill: "transparent"
                        pressedScale: 0.98
                        Accessible.name: today.latest ? qsTr("Open %1").arg(Format.title(today.latest)) : ""
                        onClicked: if (today.latest) today.openRide(today.latest.id)
                        contentItem: Column {
                            id: latestColumn
                            spacing: 10
                            Text {
                                text: qsTr("Latest ride")
                                color: Theme.text2
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.labelSize
                            }
                            Text {
                                width: parent.width
                                text: today.latest ? Format.title(today.latest) + "  ·  " + Format.day(today.latest.start) : ""
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.titleSize
                                elide: Text.ElideRight
                            }
                            Row {
                                spacing: 24
                                Repeater {
                                    model: today.latest ? [
                                        [Format.duration(today.latest.duration), qsTr("time")],
                                        [Format.whole(today.latest.avgPower) + " W", qsTr("average")],
                                        [Format.big(today.latest.kj) + " kJ", qsTr("work")]
                                    ] : []
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: modelData[0]
                                            color: Theme.text
                                            font.family: Theme.display
                                            font.pixelSize: 22
                                        }
                                        Text {
                                            text: modelData[1]
                                            color: Theme.text3
                                            font.family: Theme.bodyMedium
                                            font.pixelSize: Theme.tertiarySize
                                        }
                                    }
                                }
                            }
                            Sparkline {
                                width: parent.width
                                height: 40
                                values: today.latest ? today.latest.spark : []
                            }
                        }
                    }
                }

                // bests, all time
                Card {
                    width: content.columnWidth
                    visible: today.bests.length > 0
                    Text {
                        text: qsTr("Your best power")
                        color: Theme.text2
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                    }
                    Grid {
                        width: parent.width
                        columns: 4
                        columnSpacing: 8
                        Repeater {
                            model: today.bests
                            PulseButton {
                                width: (parent.width - 24) / 4
                                height: 72
                                fill: Theme.control
                                radius: 18
                                Accessible.name: qsTr("%1 best, %2 watts").arg(Format.effort(modelData.seconds)).arg(Math.round(modelData.watts))
                                onClicked: today.openRide(modelData.rideId)
                                contentItem: Column {
                                    topPadding: 12
                                    spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(modelData.watts)
                                        color: Theme.zoneColors[6 - index]
                                        font.family: Theme.display
                                        font.pixelSize: 24
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Format.effort(modelData.seconds)
                                        color: Theme.text3
                                        font.family: Theme.bodyMedium
                                        font.pixelSize: Theme.tertiarySize
                                    }
                                }
                            }
                        }
                    }
                }

                // everything so far
                Card {
                    width: content.columnWidth
                    visible: today.rideCount > 0
                    PulseButton {
                        width: parent.width
                        height: lifeRow.implicitHeight
                        fill: "transparent"
                        pressedScale: 0.98
                        Accessible.name: qsTr("Open your goals")
                        onClicked: today.openTab("goals")
                        contentItem: Column {
                            id: lifeRow
                            spacing: 10
                            Text {
                                text: qsTr("All your rides")
                                color: Theme.text2
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.labelSize
                            }
                            Row {
                                spacing: 28
                                Repeater {
                                    model: [
                                        [Format.distance(today.lifetime.distance || 0, today.miles), qsTr("ridden")],
                                        [Format.hours(today.lifetime.seconds || 0), qsTr("in the saddle")],
                                        [Format.big(today.lifetime.rides || 0), qsTr("rides")]
                                    ]
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: modelData[0]
                                            color: Theme.text
                                            font.family: Theme.display
                                            font.pixelSize: 20
                                        }
                                        Text {
                                            text: modelData[1]
                                            color: Theme.text3
                                            font.family: Theme.bodyMedium
                                            font.pixelSize: Theme.tertiarySize
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // before the first ride
                Card {
                    width: content.columnWidth
                    visible: today.rideCount === 0
                    Text {
                        width: parent.width
                        text: today.library && today.library.busy
                              ? qsTr("Reading your ride history, %1 of %2").arg(today.library.indexed).arg(today.library.toIndex)
                              : qsTr("Your rides will show up here")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.titleSize
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: qsTr("Every ride you finish adds to your week, your records and your goals. Rides QZ saved before are read in automatically.")
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.labelSize
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
