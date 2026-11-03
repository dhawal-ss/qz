import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../Format.js" as Format
import "../Metrics.js" as Metrics

// The picture of a ride to share: the rider mark, the top moment, the key numbers and a small
// power line. It is laid out at 1080 x 1350 (a 4:5 post), shown scaled down and saved full size.
Rectangle {
    id: share

    property var ride: ({})
    property var moment: ({})
    property var spark: []
    property real when: Date.now()

    readonly property int tone: moment.tone || 1
    readonly property color tint: Theme.zoneColors[tone - 1]
    readonly property var numbers: [
        [qsTr("Time"), Metrics.clock(ride.elapsed || 0), ""],
        [qsTr("Avg power"), Metrics.whole(ride.avgPower), "W"],
        [qsTr("Distance"), (ride.distance || 0).toFixed(1), ride.miles ? "mi" : "km"],
        [qsTr("Work"), Metrics.whole(ride.kilojoules), "kJ"]
    ]

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

    Glow {
        x: 380
        y: -420
        width: 1200
        height: 1200
        tint: share.tint
        breathing: false
        opacity: 0.3
    }

    // the mark and the name
    Row {
        x: 80
        y: 80
        spacing: 24
        BrandMark {
            id: brand
            width: 112
            height: 112
            color: Theme.accent
        }
        Text {
            anchors.verticalCenter: brand.verticalCenter
            text: "Bikemodo"
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: 52
        }
    }
    Text {
        anchors { right: parent.right; rightMargin: 80 }
        y: 116
        text: Format.day(share.when) + ", " + Format.title({ title: "", start: share.when })
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: 36
    }

    // the top moment
    Column {
        x: 80
        y: 280
        width: share.width - 160
        spacing: 28

        PulseShape {
            width: 160
            height: 160
            zone: share.tone
            color: share.tint
        }
        Text {
            width: parent.width
            text: share.moment.title || ""
            color: Theme.zoneLight[share.tone - 1]
            font.family: Theme.bodySemibold
            font.pixelSize: 56
            elide: Text.ElideRight
        }
        Row {
            spacing: 20
            Numeral {
                id: hero
                text: share.moment.value || ""
                color: Theme.text
                font.family: Theme.celebrate
                font.pixelSize: Math.min(220, Math.floor(100 * (share.width - 180 - heroUnit.implicitWidth) / Math.max(1, probe.advanceWidth)))
                font.letterSpacing: -4
            }
            Text {
                id: heroUnit
                text: share.moment.unit || ""
                color: Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: 64
                anchors.baseline: hero.baseline
            }
        }
        Text {
            width: parent.width
            text: share.moment.detail || ""
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 38
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
    TextMetrics {
        id: probe
        font.family: Theme.celebrate
        font.pixelSize: 100
        text: share.moment.value || ""
    }

    // the key numbers, just above the power line
    Row {
        x: 80
        y: 1150 - 48 - height
        spacing: 44
        Repeater {
            model: share.numbers
            Column {
                spacing: 10
                Text {
                    text: modelData[0]
                    color: Theme.text3
                    font.family: Theme.bodyMedium
                    font.pixelSize: 30
                }
                Row {
                    spacing: 8
                    Numeral {
                        id: number
                        text: modelData[1]
                        color: Theme.text
                        font.pixelSize: 50
                    }
                    Text {
                        text: modelData[2]
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: 26
                        anchors.baseline: number.baseline
                        visible: text !== ""
                    }
                }
            }
        }
    }

    // the power of the ride as a filled line along the bottom
    Shape {
        id: line
        x: 80
        y: 1150
        width: share.width - 160
        height: 140
        visible: share.spark.length > 1
        layer.enabled: true
        layer.samples: 4

        function points(closed) {
            var list = []
            var values = share.spark
            var n = values.length
            if (n < 2)
                return list
            var lo = values[0]
            var hi = values[0]
            for (var i = 1; i < n; i++) {
                lo = Math.min(lo, values[i])
                hi = Math.max(hi, values[i])
            }
            var span = Math.max(1, hi - lo)
            for (var j = 0; j < n; j++)
                list.push(Qt.point(j * width / (n - 1), 6 + (height - 12) * (1 - (values[j] - lo) / span)))
            if (closed) {
                list.push(Qt.point(width, height))
                list.push(Qt.point(0, height))
            }
            return list
        }

        ShapePath {
            strokeWidth: -1
            fillColor: Qt.rgba(share.tint.r, share.tint.g, share.tint.b, 0.16)
            PathPolyline { path: line.points(true) }
        }
        ShapePath {
            strokeColor: share.tint
            strokeWidth: 7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: line.points(false) }
        }
    }
}
