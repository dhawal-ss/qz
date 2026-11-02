import QtQuick 2.15
import "."
import "Metrics.js" as Metrics

// After the ride: what it was, in a few honest numbers.
Item {
    id: summary

    // a copy of the ride source, taken when the ride finished
    property var ride: ({})
    property bool demo: false

    signal done()

    readonly property bool estimated: ride.powerEstimated === true
    readonly property var rows: [
        [qsTr("Average power"), Metrics.whole(ride.avgPower), "W", estimated],
        [qsTr("Normalized power"), Metrics.whole(ride.normalizedPower), "W", estimated],
        [qsTr("Training load"), Metrics.whole(ride.tss), "TSS", estimated],
        [qsTr("Work"), Metrics.whole(ride.kilojoules), "kJ", estimated],
        [qsTr("Calories"), Metrics.whole(ride.calories), "kcal", estimated],
        [qsTr("Distance"), ride.distance !== undefined ? ride.distance.toFixed(1) : "0", ride.miles ? "mi" : "km", false]
    ]

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Glow {
        x: column.x - 160
        y: -160
        width: 560
        height: 560
        tint: Theme.accent
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + 64
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: Math.min(520, summary.width - 48)
            x: (summary.width - width) / 2
            y: 40
            spacing: 18

            Text {
                text: summary.demo ? qsTr("Demo ride, not saved") : qsTr("Ride saved")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 14
            }

            Numeral {
                text: Metrics.clock(summary.ride.elapsed || 0)
                color: Theme.text
                font.family: Theme.celebrate
                font.pixelSize: 88
                font.letterSpacing: -2
            }

            Item { width: 1; height: 6 }

            Column {
                width: parent.width
                Repeater {
                    model: summary.rows
                    Item {
                        width: column.width
                        height: 58
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
                                font.pixelSize: 28
                            }
                            Text {
                                text: modelData[2]
                                color: Theme.text3
                                font.family: Theme.bodyMedium
                                font.pixelSize: Theme.tertiarySize
                                anchors.baseline: value.baseline
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 6 }

            PulseButton {
                width: parent.width
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
}
