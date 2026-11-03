import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../Metrics.js" as Metrics

// The picture of a ride to share, the "ride fingerprint" of the Moments board: the mark and the
// name, one bar per minute round a ring in the colors of the zones, the ride's name and day, and
// three key numbers on a hairline. It is laid out at 1080 x 1350 (a 4:5 post), shown scaled down
// and saved full size.
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

    readonly property int tone: moment.tone || 1
    readonly property color tint: Theme.zoneColors[tone - 1]
    readonly property bool estimated: ride.powerEstimated === true
    readonly property bool record: moment.kind === "record"
    // the bars, or the power line of the ride when there are no minutes yet
    readonly property var shownBars: {
        if (bars.length > 0)
            return bars
        return spark.map(function (w) { return { watts: w, zone: 0 } })
    }
    readonly property real k: 1080 / 364
    readonly property var numbers: [
        { label: qsTr("Time"), value: Metrics.clock(ride.elapsed || 0), unit: "", est: false, lit: false },
        record ? { label: qsTr("%1 best").arg(effortShort(moment.seconds || 0)), value: moment.value || "", unit: "W", est: estimated, lit: true }
               : { label: qsTr("Avg power"), value: Metrics.whole(ride.avgPower), unit: "W", est: estimated, lit: false },
        // training load is always worked out, so always estimated
        { label: qsTr("Load"), value: Metrics.whole(ride.tss), unit: "", est: true, lit: false }
    ]

    function effortShort(seconds) {
        if (seconds < 60)
            return qsTr("%1 s").arg(seconds)
        if (seconds < 3600)
            return qsTr("%1 min").arg(Math.round(seconds / 60))
        return qsTr("%1 h").arg(seconds / 3600)
    }

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
        border.color: Qt.rgba(1, 1, 1, 0.06)
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
        x: (share.width - width) / 2
        y: 128
        width: 720
        height: 720
        bars: share.shownBars
        tint: share.tint
        centerValue: String(Math.max(1, Math.round((share.ride.elapsed || 0) / 60)))
        centerWord: qsTr("minutes")
    }

    Column {
        x: 24 * share.k
        y: 872
        width: share.width - 48 * share.k
        spacing: 5 * share.k
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

    // the key numbers on a hairline
    Item {
        x: 24 * share.k
        width: share.width - 48 * share.k
        y: share.height - 24 * share.k - height
        height: 14 * share.k + numbersRow.height
        Rectangle {
            width: parent.width
            height: 3
            color: Theme.hairline
        }
        Row {
            id: numbersRow
            y: 14 * share.k
            width: parent.width
            spacing: 12 * share.k
            Repeater {
                model: share.numbers
                Column {
                    width: (numbersRow.width - 24 * share.k) * [1, 1.2, 1][index] / 3.2
                    spacing: 6 * share.k
                    Text {
                        text: modelData.label
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Math.round(12.5 * share.k)
                    }
                    Row {
                        spacing: 10
                        Numeral {
                            id: keyValue
                            text: modelData.value
                            color: modelData.lit ? share.tint : Theme.text
                            font.pixelSize: Math.round(24 * share.k)
                        }
                        Text {
                            visible: modelData.unit !== ""
                            anchors.baseline: keyValue.baseline
                            text: modelData.unit
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Math.round(12.5 * share.k)
                        }
                        Text {
                            visible: modelData.est
                            anchors.baseline: keyValue.baseline
                            text: qsTr("est.")
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Math.round(12 * share.k)
                        }
                    }
                }
            }
        }
    }
}
