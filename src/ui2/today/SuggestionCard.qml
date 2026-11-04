import QtQuick 2.15
import ".."
import "../sig"

// The one raised surface of Today: the ride to do now. Its name and length, its shape in zone
// colors, what it holds, the big Start ride pill and a swap for something easier (or, before the
// first ride, a demo ride). The suggestion is a guide: Start ride opens a free ride, through the
// launcher that finds the bike when it is not there yet.
Rectangle {
    id: suggestion

    property var plan: null              // Coach.plan()
    // where a training plan is ("Week 3 of 8 · ride 2 of 3"), in place of "Idea for today"
    property string kicker: ""
    property string swapLabel: ""
    property bool firstRide: false
    // the training load of the idea, which needs the rider's own FTP (Theme.ftpSet)
    property bool showLoad: true

    signal rideRequested()
    // Start: the idea as a workout, its steps on the ride screen (train/Workout.js)
    signal workoutRequested()
    signal swap()
    signal demoRequested()

    implicitHeight: body.implicitHeight + 40
    radius: Theme.heroRadius
    color: Theme.card
    border.width: 1
    border.color: Theme.raisedBorder

    Column {
        id: body
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 14

        Item {
            width: parent.width
            height: titleColumn.height
            Column {
                id: titleColumn
                width: parent.width - length.width - 12
                spacing: 6
                CapLabel {
                    text: suggestion.kicker !== "" ? suggestion.kicker : (suggestion.firstRide ? qsTr("Your first ride") : qsTr("Idea for today"))
                }
                Text {
                    id: planName
                    width: parent.width
                    text: suggestion.plan ? suggestion.plan.name : ""
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(21)
                    font.letterSpacing: -0.2
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    Accessible.role: Accessible.Heading
                    Accessible.name: qsTr("Idea for today: %1, %2 minutes").arg(text).arg(suggestion.plan ? suggestion.plan.minutes : 0)
                }
            }
            Text {
                id: length
                anchors.right: parent.right
                // on the baseline of the first line of the name
                y: planName.y + planName.baselineOffset - baselineOffset
                text: suggestion.plan ? qsTr("%1 min").arg(suggestion.plan.minutes) : ""
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                Accessible.ignored: true
            }
        }

        WorkoutShape {
            width: parent.width
            height: 54
            blocks: suggestion.plan ? suggestion.plan.blocks : []
            summary: suggestion.plan ? qsTr("Ride shape: %1").arg(suggestion.plan.detail) : ""
        }

        Row {
            width: parent.width
            spacing: 18
            Text {
                text: suggestion.plan ? suggestion.plan.detail : ""
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                width: Math.min(implicitWidth, parent.width - load.width - 18)
                elide: Text.ElideRight
            }
            Text {
                id: load
                visible: suggestion.showLoad
                text: suggestion.plan ? qsTr("TSS %1 <font color=\"%2\">est.</font>").arg(suggestion.plan.tss).arg(Theme.text3) : ""
                textFormat: Text.StyledText
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(13)
                Accessible.name: suggestion.plan ? qsTr("Training load %1, estimated").arg(suggestion.plan.tss) : ""
            }
        }

        PulseButton {
            id: startButton
            objectName: "startRide"
            width: parent.width
            height: 64
            fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
            pressedRadius: 20
            pressedScale: 0.97
            Accessible.name: suggestion.plan ? qsTr("Start the workout %1").arg(suggestion.plan.name) : qsTr("Start ride")
            onClicked: suggestion.plan ? suggestion.workoutRequested() : suggestion.rideRequested()
            contentItem: Item {
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "play"
                        size: 20
                        color: Theme.accentInk
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: suggestion.plan ? qsTr("Start workout") : qsTr("Start ride")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(18)
                    }
                }
            }
        }

        PulseButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, swapText.implicitWidth + 32)
            height: 48
            // 40 to see, 48 to touch
            topInset: 4
            bottomInset: 4
            fill: pressed ? Theme.pressed : "transparent"
            Accessible.name: swapText.text
            onClicked: suggestion.firstRide ? suggestion.demoRequested() : suggestion.swap()
            contentItem: Text {
                id: swapText
                text: suggestion.firstRide ? qsTr("Try a demo ride, no bike needed") : suggestion.swapLabel
                color: Theme.accent
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(14)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
