import QtQuick 2.15
import ".."
import "../sig"
import "../you"
import "../train/Plans.js" as Plans
import "../train/Levels.js" as Levels
import "../train/Ftp.js" as Ftp

// Training, on Goals: a plan (train/Plans.js) to start, or the one under way with this week's
// three rides, the next weeks to come and End plan; the training levels the coach picks workouts
// from (train/Levels.js); and the FTP tests (train/Ftp.js). Starting a ride or a test goes to the
// ride screen through workoutRequested.
Column {
    id: card

    property var plan: null          // Plans.parse(), null for none
    property var planState: null     // Plans.now()
    property var levels: ({})

    signal startPlan(string id, int weeks)
    signal endPlan()
    signal workoutRequested(var workout)

    property int eventWeeks: 8

    spacing: 4

    CapLabel {
        text: qsTr("Training")
    }

    // ---- no plan: the three to pick from
    Repeater {
        model: card.plan === null ? Plans.list() : []
        Item {
            width: card.width
            height: planRow.height + 20
            Column {
                id: planRow
                y: 10
                width: parent.width - startButton.width - 12
                spacing: 3
                Text {
                    width: parent.width
                    text: modelData.id === "event" ? qsTr("Event in %1 weeks").arg(card.eventWeeks) : modelData.name
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: modelData.detail
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
                // the weeks to the event
                Row {
                    visible: modelData.id === "event"
                    spacing: 6
                    topPadding: 4
                    Repeater {
                        model: [4, 6, 8, 12, 16]
                        PulseButton {
                            width: 48
                            height: 40
                            pressedRadius: 12
                            fill: card.eventWeeks === modelData ? Theme.accent : Theme.control
                            Accessible.name: qsTr("%1 weeks").arg(modelData)
                            onClicked: card.eventWeeks = modelData
                            contentItem: Text {
                                text: modelData
                                color: card.eventWeeks === modelData ? Theme.accentInk : Theme.text
                                font.family: Theme.bodySemibold
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
            PulseButton {
                id: startButton
                anchors.right: parent.right
                y: 10
                width: startText.implicitWidth + 28
                height: 44
                pressedRadius: 14
                fill: pressed ? Theme.chip : Theme.control
                Accessible.name: qsTr("Start the plan %1").arg(modelData.name)
                onClicked: card.startPlan(modelData.id, modelData.id === "event" ? card.eventWeeks : modelData.weeks)
                contentItem: Text {
                    id: startText
                    text: qsTr("Start")
                    color: Theme.accent
                    font.family: Theme.bodySemibold
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Hairline {
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }
    }

    // ---- a plan under way
    Column {
        visible: card.plan !== null && card.planState !== null
        width: card.width
        spacing: 10
        topPadding: 8

        Text {
            width: parent.width
            text: card.plan ? (card.plan.id === "event" ? qsTr("Event in %1 weeks").arg(card.plan.weeks) : Plans.info(card.plan.id).name) : ""
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: 24
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: !card.planState ? "" : card.planState.over ? qsTr("Done. Every week of it is behind you.")
                  : qsTr("Week %1 of %2, %3 of %4 rides this week").arg(card.planState.week + 1).arg(card.planState.weeks)
                    .arg(card.planState.done).arg(card.planState.rides.length)
                    + (card.planState.easy ? ". " + qsTr("An easier week, to let the work sink in.") : "")
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }

        // this week's rides, the ridden ones checked; a missed one simply goes with the week
        Repeater {
            model: card.planState && !card.planState.over ? card.planState.rides : []
            Item {
                width: card.width
                height: 52
                readonly property bool ridden: index < card.planState.done
                readonly property bool nextOne: index === card.planState.done
                Rectangle {
                    id: mark
                    width: 28
                    height: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.ridden ? Theme.accent : "transparent"
                    border.width: parent.ridden ? 0 : 2
                    border.color: parent.nextOne ? Theme.accent : Theme.hairline
                    YouIcon {
                        anchors.centerIn: parent
                        visible: parent.parent.ridden
                        name: "check"
                        size: 16
                        weight: 2.6
                        color: Theme.accentInk
                    }
                }
                Column {
                    x: mark.width + 12
                    width: parent.width - x - rideButton.width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: modelData.name
                        color: parent.parent.ridden ? Theme.text3 : Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 15
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: qsTr("%1 min").arg(modelData.minutes) + " · " + modelData.detail
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                PulseButton {
                    id: rideButton
                    visible: parent.nextOne
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? rideText.implicitWidth + 28 : 0
                    height: 40
                    pressedRadius: 12
                    fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                    Accessible.name: qsTr("Ride %1 now").arg(modelData.name)
                    onClicked: card.workoutRequested(modelData)
                    contentItem: Text {
                        id: rideText
                        text: qsTr("Ride")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // the next weeks, a line each
        Repeater {
            model: {
                if (!card.planState || card.planState.over || !card.plan)
                    return []
                var out = []
                for (var w = card.planState.week + 1; w < Math.min(card.plan.weeks, card.planState.week + 4); w++)
                    out.push({ week: w, rides: Plans.week(card.plan, w, card.levels), easy: Plans.easierWeek(card.plan, w) })
                return out
            }
            Text {
                width: card.width
                text: qsTr("Week %1").arg(modelData.week + 1) + (modelData.easy ? " · " + qsTr("easier") : "") + ": "
                      + modelData.rides.map(function (r) { return r.name }).join(", ")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }

        PulseButton {
            x: -12
            width: endText.implicitWidth + 24
            height: 44
            fill: pressed ? Theme.pressed : "transparent"
            Accessible.name: card.planState && card.planState.over ? qsTr("Close the plan") : qsTr("End the plan")
            onClicked: card.endPlan()
            contentItem: Text {
                id: endText
                text: card.planState && card.planState.over ? qsTr("Close the plan") : qsTr("End the plan")
                color: Theme.accent
                font.family: Theme.bodySemibold
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ---- the training levels
    Item { width: 1; height: 14 }
    Text {
        width: card.width
        text: qsTr("Your levels")
        color: Theme.text
        font.family: Theme.bodySemibold
        font.pixelSize: 15
    }
    Text {
        width: card.width
        text: qsTr("A finished workout raises its level, one left early lowers it. Workouts grow with them.")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        bottomPadding: 6
    }
    Repeater {
        model: Levels.kinds
        Item {
            width: card.width
            height: 30
            readonly property real value: card.levels[modelData] || 1
            Text {
                id: levelName
                width: 96
                anchors.verticalCenter: parent.verticalCenter
                text: Levels.names()[modelData]
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
            }
            Rectangle {
                x: levelName.width + 8
                width: parent.width - x - 44
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.control
                Rectangle {
                    width: parent.width * parent.parent.value / 10
                    height: parent.height
                    radius: 4
                    color: Theme.zoneColors[index + 1]
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: (Math.round(parent.value * 10) / 10).toFixed(1)
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: 13
            }
        }
    }

    // ---- the FTP tests
    Item { width: 1; height: 14 }
    Text {
        width: card.width
        text: qsTr("Test your FTP")
        color: Theme.text
        font.family: Theme.bodySemibold
        font.pixelSize: 15
    }
    Text {
        width: card.width
        text: qsTr("The ramp is about 20 minutes and ends when you cannot hold a step. The 20 minute test hurts longer and needs pacing. You choose whether to use the result.")
        color: Theme.text3
        font.family: Theme.bodyMedium
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        bottomPadding: 6
    }
    Row {
        spacing: 8
        PulseButton {
            width: rampText.implicitWidth + 32
            height: 48
            pressedRadius: 14
            fill: pressed ? Theme.chip : Theme.control
            Accessible.name: qsTr("Start a ramp test")
            onClicked: card.workoutRequested(Ftp.rampPlan(Theme.ftp))
            contentItem: Text {
                id: rampText
                text: qsTr("Ramp test")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        PulseButton {
            width: twentyText.implicitWidth + 32
            height: 48
            pressedRadius: 14
            fill: pressed ? Theme.chip : Theme.control
            Accessible.name: qsTr("Start a 20 minute FTP test")
            onClicked: card.workoutRequested(Ftp.twentyPlan())
            contentItem: Text {
                id: twentyText
                text: qsTr("20 minute test")
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
