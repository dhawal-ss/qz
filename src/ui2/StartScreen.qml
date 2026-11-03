import QtQuick 2.15
import "."

// Before the ride: is the bike there, and a way into the ride or a demo.
Item {
    id: start

    property bool connected: false
    property string deviceName: ""
    property string searchStatus: ""
    property bool rideInProgress: false

    signal openRide()
    signal openDemo()
    signal searchAgain()

    readonly property string greeting: {
        var hour = new Date().getHours()
        if (hour < 5 || hour >= 18)
            return qsTr("Good evening")
        if (hour < 12)
            return qsTr("Good morning")
        return qsTr("Good afternoon")
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // the same breathing glow as the ride, in the brand color
    Glow {
        x: column.x - 120
        y: -140
        width: 520
        height: 520
        tint: start.connected ? Theme.zoneColors[1] : Theme.accent
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.height + 64
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: Math.min(520, start.width - 48)
            x: (start.width - width) / 2
            y: 32
            spacing: 24

            Row {
                height: 40
                spacing: 12
                Rectangle {
                    width: 40
                    height: 40
                    radius: 12
                    color: Theme.accentInk
                    BrandMark {
                        anchors.fill: parent
                        anchors.margins: 4
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bikemodo"
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 22
                }
            }

            Text {
                width: parent.width
                text: start.greeting
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: 34
                wrapMode: Text.WordWrap
            }

            // the bike
            Rectangle {
                width: parent.width
                height: bikeColumn.height + 48
                radius: 28
                color: Theme.card

                Column {
                    id: bikeColumn
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 16

                    Row {
                        spacing: 14
                        PulseShape {
                            width: 44
                            height: 44
                            zone: start.connected ? 2 : 1
                            color: start.connected ? Theme.zoneColors[1] : Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: start.connected ? qsTr("Bike connected") : qsTr("Looking for your bike")
                                color: Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: Theme.titleSize
                            }
                            Text {
                                width: bikeColumn.width - 58
                                text: start.connected ? start.deviceName
                                      : (start.searchStatus !== "" ? start.searchStatus : qsTr("Wake the bike by pedaling a few turns."))
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
                        Accessible.name: primaryLabel.text
                        onClicked: start.connected ? start.openRide() : start.searchAgain()
                        contentItem: Text {
                            id: primaryLabel
                            text: start.connected ? (start.rideInProgress ? qsTr("Back to the ride") : qsTr("Ride")) : qsTr("Search again")
                            color: Theme.accentInk
                            font.family: Theme.bodySemibold
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            PulseButton {
                width: parent.width
                height: 56
                fill: Theme.control
                pressedRadius: 18
                Accessible.name: qsTr("Try a demo ride")
                onClicked: start.openDemo()
                contentItem: Item {
                    Text {
                        x: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Try a demo ride")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                        text: qsTr("no bike needed")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                    }
                }
            }
        }
    }
}
