import QtQuick 2.15
import ".."
import "../sig"
import "../learn"

// The first card of Today: ready to ride. Where the bike is and how the rider is (the form, as
// a word, a tap opens its Learn sheet), the one filled button of the screen, Start ride (a free
// ride, through the launcher that finds the bike when it is not there yet), and under it the idea
// for today as a smaller choice: its name and length, its shape in zone colors, what it holds and
// how hard it is in words, Start for it as a workout, and a swap for something else (before the
// first ride, a demo ride).
Rectangle {
    id: suggestion

    property var plan: null              // Coach.plan()
    // where a training plan is ("Week 3 of 8 · ride 2 of 3"), in place of "Idea for today"
    property string kicker: ""
    property string swapLabel: ""
    property bool firstRide: false
    // the training load of the idea, which needs the rider's own FTP (Theme.ftpSet)
    property bool showLoad: true
    // the effort score as a number too ("More detail" on Progress)
    property bool detailed: false
    // where the bike is, as a sentence, and whether it is there
    property string status: ""
    property bool bikeReady: false
    // the form as a word ("Fresh"), "" before there is one
    property string readiness: ""

    signal rideRequested()
    // Start on the idea: its steps on the ride screen (train/Workout.js)
    signal workoutRequested()
    signal swap()
    signal demoRequested()
    signal learnReadiness()

    // the effort of the idea in words, from its training load (TSS)
    function effortWords(tss) {
        if (tss < 30)
            return qsTr("Light effort")
        if (tss < 60)
            return qsTr("Moderate effort")
        if (tss < 90)
            return qsTr("Hard effort")
        return qsTr("Very hard effort")
    }

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

        Column {
            width: parent.width
            spacing: 6
            CapLabel {
                text: suggestion.bikeReady ? qsTr("Ready to ride") : qsTr("Ride")
            }
            Row {
                width: parent.width
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: suggestion.bikeReady ? Theme.zoneColors[1] : Theme.text3
                }
                Text {
                    width: parent.width - 16
                    text: suggestion.status
                    color: Theme.text
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(15)
                    wrapMode: Text.WordWrap
                }
            }
            // the form: a word, the button to its Learn sheet
            LearnTap {
                visible: suggestion.readiness !== ""
                x: -8
                width: Math.min(parent.width + 8, formText.implicitWidth + 16)
                height: visible ? 32 : 0
                name: formText.text
                onClicked: suggestion.learnReadiness()
                Text {
                    id: formText
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Your form today: %1").arg(suggestion.readiness)
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(14)
                }
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
            Accessible.name: qsTr("Start ride")
            onClicked: suggestion.rideRequested()
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
                        text: qsTr("Start ride")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(18)
                    }
                }
            }
        }

        // the idea for today, a smaller choice under Start ride
        Rectangle {
            width: parent.width
            height: 1
            visible: suggestion.plan !== null
            color: Theme.hairline
        }
        Column {
            visible: suggestion.plan !== null
            width: parent.width
            spacing: 10
            Item {
                width: parent.width
                height: ideaColumn.height
                Column {
                    id: ideaColumn
                    width: parent.width - ideaStart.width - 12
                    spacing: 4
                    CapLabel {
                        text: suggestion.kicker !== "" ? suggestion.kicker : (suggestion.firstRide ? qsTr("Or a first workout") : qsTr("Or try today's idea"))
                    }
                    Text {
                        id: planName
                        width: parent.width
                        text: suggestion.plan ? qsTr("%1 · %2 min").arg(suggestion.plan.name).arg(suggestion.plan.minutes) : ""
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(17)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        Accessible.role: Accessible.Heading
                        Accessible.name: suggestion.plan ? qsTr("Idea for today: %1, %2 minutes").arg(suggestion.plan.name).arg(suggestion.plan.minutes) : ""
                    }
                    Text {
                        width: parent.width
                        text: {
                            if (!suggestion.plan)
                                return ""
                            var words = suggestion.plan.detail
                            if (suggestion.showLoad)
                                words += " · " + suggestion.effortWords(suggestion.plan.tss)
                                         + (suggestion.detailed ? " " + qsTr("(effort score %1)").arg(suggestion.plan.tss) : "")
                            return words
                        }
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.fs(13)
                        wrapMode: Text.WordWrap
                    }
                }
                PulseButton {
                    id: ideaStart
                    anchors.right: parent.right
                    anchors.verticalCenter: ideaColumn.verticalCenter
                    width: ideaText.implicitWidth + 32
                    height: 48
                    pressedRadius: 16
                    fill: pressed ? Theme.chip : Theme.pressed
                    Accessible.name: suggestion.plan ? qsTr("Start the workout %1").arg(suggestion.plan.name) : ""
                    onClicked: suggestion.workoutRequested()
                    contentItem: Text {
                        id: ideaText
                        text: qsTr("Start")
                        color: Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(14)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            WorkoutShape {
                width: parent.width
                height: 40
                blocks: suggestion.plan ? suggestion.plan.blocks : []
                summary: suggestion.plan ? qsTr("Ride shape: %1").arg(suggestion.plan.detail) : ""
            }

            PulseButton {
                x: -12
                width: Math.min(parent.width + 12, swapText.implicitWidth + 24)
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
}
