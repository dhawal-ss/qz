import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "Share.js" as Share

// The picture of a ride to share, the "ride fingerprint" of the Moments board: the mark and the
// name, one bar per minute round a ring in the colors of the zones, the ride's name and day, what
// the ride achieved (a new best, the weekly goal) as lit lines, and its numbers in two rows on a
// hairline. It is laid out at 1080 x 1350 (a 4:5 post), shown scaled down and saved full size.
// The end of a ride and a ride in Rides both share this card (moments/Share.js).
Rectangle {
    id: share

    property var ride: ({})
    property var moment: ({})
    property var spark: []
    property real when: Date.now()
    // the fingerprint: [{ watts, zone }], one per bar, and the minutes a bar stands for
    property var bars: []
    property int minutesPerBar: 1
    property string name: ""
    // the lit lines, Share.achievements(): [{ text, tone }], at most two
    property var achievements: []

    readonly property int tone: moment.tone || 1
    readonly property color tint: Theme.zoneColors[tone - 1]
    // the bars, or the power line of the ride when there are no minutes yet
    readonly property var shownBars: {
        if (bars.length > 0)
            return bars
        return spark.map(function (w) { return { watts: w, zone: 0 } })
    }
    readonly property real k: 1080 / 364
    readonly property var numbers: Share.numbers(ride, Theme.ftpSet)

    width: 1080
    height: 1350
    color: Theme.bg
    clip: true
    Accessible.ignored: true

    // saves the card as a PNG at full size; done(ok, path) when written
    function save(path, done) {
        share.grabToImage(function (result) {
            done(result.saveToFile(path), path)
        }, Qt.size(1080, 1350))
    }

    function grow() {
        fingerprint.grow()
    }

    // the card itself, the board's 364 x 500 raised surface drawn at 1080 wide
    Rectangle {
        anchors.fill: parent
        radius: 32 * share.k
        color: Theme.surface
        border.width: 3
        border.color: Theme.overlay(0.06)
        clip: true

        Glow {
            x: 52 * share.k - 60
            y: 40 * share.k - 120
            width: 260 * share.k
            height: width
            tint: share.tint
            breathing: false
            opacity: 0.3
        }
    }

    // the mark and the name, and what the picture is
    Row {
        x: 24 * share.k
        y: 22 * share.k
        spacing: 7 * share.k
        Pulse {
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * share.k * 108 / 85
            height: width
            zone: share.tone
            color: share.tint
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Bikemodo"
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Math.round(13 * share.k)
        }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 24 * share.k
        y: 22 * share.k + 4
        text: share.minutesPerBar > 1 ? qsTr("Ride fingerprint, a bar per %1 min").arg(share.minutesPerBar) : qsTr("Ride fingerprint")
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: Math.round(12.5 * share.k)
    }

    Fingerprint {
        id: fingerprint
        // as big as the space between the top line and the name allows
        readonly property real roomTop: 40 * share.k
        readonly property real room: titleBlock.y - 8 * share.k - roomTop
        x: (share.width - width) / 2
        y: roomTop + (room - height) / 2
        width: Math.min(720, room)
        height: width
        bars: share.shownBars
        tint: share.tint
        centerValue: String(Math.max(1, Math.round((share.ride.elapsed || 0) / 60)))
        centerWord: qsTr("minutes")
    }

    // the name and the day
    Column {
        id: titleBlock
        x: 24 * share.k
        y: (share.achievements.length > 0 ? achievementsColumn.y - 12 * share.k : numbersBlock.y - 16 * share.k) - height
        width: share.width - 48 * share.k
        spacing: 4 * share.k
        Text {
            width: parent.width
            text: share.name
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Math.round(21 * share.k)
            font.letterSpacing: -0.6
            elide: Text.ElideRight
        }
        Text {
            text: new Date(share.when).toLocaleDateString(Qt.locale(), "dddd d MMMM")
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Math.round(12.5 * share.k)
        }
    }

    // what the ride achieved, each line lit in the color of its moment
    Column {
        id: achievementsColumn
        x: 24 * share.k
        y: numbersBlock.y - 14 * share.k - height
        spacing: 5 * share.k
        Repeater {
            model: share.achievements
            Rectangle {
                readonly property color lit: Theme.zoneColors[Math.max(1, Math.min(7, modelData.tone)) - 1]
                width: achievementRow.width + 20 * share.k
                height: 26 * share.k
                radius: height / 2
                color: Qt.rgba(lit.r, lit.g, lit.b, 0.14)
                Row {
                    id: achievementRow
                    x: 9 * share.k
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * share.k
                    Pulse {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11 * share.k
                        height: width
                        zone: Math.max(1, Math.min(7, modelData.tone))
                        color: parent.parent.lit
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Math.round(12.5 * share.k)
                    }
                }
            }
        }
    }

    // the numbers on a hairline, two rows of three
    Item {
        id: numbersBlock
        x: 24 * share.k
        width: share.width - 48 * share.k
        y: share.height - 22 * share.k - height
        height: 12 * share.k + numbersGrid.height
        Rectangle {
            width: parent.width
            height: 3
            color: Theme.hairline
        }
        Grid {
            id: numbersGrid
            y: 12 * share.k
            width: parent.width
            columns: 3
            columnSpacing: 12 * share.k
            rowSpacing: 10 * share.k
            Repeater {
                model: share.numbers
                Column {
                    width: (numbersGrid.width - 24 * share.k) / 3
                    spacing: 3 * share.k
                    Text {
                        text: modelData.label
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Math.round(12 * share.k)
                    }
                    Row {
                        spacing: 10
                        Numeral {
                            id: keyValue
                            text: modelData.value
                            color: Theme.text
                            font.pixelSize: Math.round(22 * share.k)
                        }
                        Text {
                            visible: modelData.unit !== ""
                            anchors.baseline: keyValue.baseline
                            text: modelData.unit
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Math.round(12 * share.k)
                        }
                        Text {
                            visible: modelData.est
                            anchors.baseline: keyValue.baseline
                            text: qsTr("est.")
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Math.round(11 * share.k)
                        }
                    }
                }
            }
        }
    }
}
