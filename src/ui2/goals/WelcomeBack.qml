import QtQuick 2.15
import ".."
import "../sig"
import "../today"
import "Streak.js" as Streak

// Welcome back, after a week a freeze covered or a break: the streak in the breathing Pulse with
// what kept it, the weeks that led here, an easy ride to come back with and the kind word.
HabitPage {
    id: welcome

    property int streak: 0
    property string covered: "frozen"    // what kept last week: frozen or rest
    property var weeks: []               // Streak.lastWeeks()
    property real nowMs: Date.now()

    signal rideRequested()

    // the easy return: warm up, a steady easy block, cool down
    readonly property var plan: ({ name: qsTr("Easy return, 15 min"), minutes: 15, tss: 11,
                                   blocks: [[3, 1], [9, 2], [3, 1]] })
    readonly property string sentence: covered === "frozen"
                                        ? (streak === 1 ? qsTr("Your 1 week streak is safe. A freeze covered last week.")
                                                        : qsTr("Your %1 week streak is safe. A freeze covered last week.").arg(streak))
                                        : (streak === 1 ? qsTr("Your 1 week streak waited while you were away.")
                                                        : qsTr("Your %1 week streak waited while you were away.").arg(streak))

    closeButton: true
    topLabel: new Date(nowMs).toLocaleDateString(Qt.locale(), "dddd, d MMMM")
    primaryText: qsTr("Not today")
    quietPrimary: true
    glowY: 200
    glowSize: 320

    Item { width: 1; height: 40 }
    Rise {
        cue: welcome
        order: 0
        width: parent.width
        Item {
            width: parent.width
            height: 156
            Item {
                id: badge
                anchors.horizontalCenter: parent.horizontalCenter
                width: 156
                height: 156
                PulseHero {
                    anchors.fill: parent
                    glow: false
                    zone: 2
                    value: String(welcome.streak)
                    word: welcome.streak === 1 ? qsTr("week") : qsTr("weeks")
                    summary: qsTr("%1 week streak").arg(welcome.streak)
                }
                // what kept the streak alive
                Rectangle {
                    x: parent.width - width + 2
                    y: parent.height - height - 6
                    width: 44
                    height: 44
                    radius: 22
                    color: Theme.floating
                    border.width: 3
                    border.color: Theme.bg
                    GoalGlyph {
                        anchors.centerIn: parent
                        size: 20
                        weight: 1.8
                        name: welcome.covered === "frozen" ? "freeze" : "moon"
                        color: Theme.accent
                    }
                }
            }
        }
    }

    Item { width: 1; height: 26 }
    Rise {
        cue: welcome
        order: 1
        width: parent.width
        Column {
            width: parent.width
            spacing: 14
            Text {
                width: parent.width
                text: qsTr("Welcome\nback.")
                color: Theme.text
                font.family: Theme.celebrate
                font.pixelSize: welcome.height < 700 ? 46 : 56
                font.letterSpacing: -1.2
                lineHeightMode: Text.FixedHeight
                lineHeight: Math.round(font.pixelSize * 0.98)
                horizontalAlignment: Text.AlignHCenter
                Accessible.role: Accessible.Heading
                Accessible.name: qsTr("Welcome back.")
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, 290)
                text: welcome.sentence
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(15)
                lineHeight: 1.1
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    Item { width: 1; height: 20 }
    Rise {
        cue: welcome
        order: 2
        width: parent.width
        Item {
            width: parent.width
            height: row.height
            WeekRow {
                id: row
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, welcome.weeks.length * 32 - 10)
                cell: 20
                weeks: welcome.weeks
                discs: true
                labels: false
                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("%1 goal weeks, then a week %2, and this week ahead").arg(welcome.streak)
                                 .arg(welcome.covered === "frozen" ? qsTr("covered by a freeze") : qsTr("of rest"))
            }
        }
    }

    Item { width: 1; height: 34 }
    Rise {
        cue: welcome
        order: 3
        width: parent.width
        // the one raised surface: the ride to come back with
        Rectangle {
            width: parent.width
            height: planColumn.height + 40
            radius: Theme.heroRadius
            color: Theme.card
            border.width: 1.5
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
            Column {
                id: planColumn
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 16
                Item {
                    width: parent.width
                    height: Math.max(planWords.height, startButton.height)
                    Column {
                        id: planWords
                        width: parent.width - startButton.width - 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        CapLabel { text: qsTr("Suggested") }
                        Text {
                            width: parent.width
                            text: welcome.plan.name
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.fs(21)
                            font.letterSpacing: -0.2
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            width: parent.width
                            text: qsTr("Endurance, TSS %1 <font color=\"%2\">est.</font>").arg(welcome.plan.tss).arg(Theme.text3)
                            textFormat: Text.StyledText
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.fs(13)
                            Accessible.name: qsTr("Endurance, training load %1, estimated").arg(welcome.plan.tss)
                        }
                    }
                    PulseButton {
                        id: startButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: startRow.implicitWidth + 36
                        height: 48
                        pressedRadius: 16
                        fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                        Accessible.name: qsTr("Start the easy return ride")
                        onClicked: welcome.rideRequested()
                        contentItem: Item {
                            Row {
                                id: startRow
                                anchors.centerIn: parent
                                spacing: 8
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "play"
                                    size: 16
                                    color: Theme.accentInk
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Start")
                                    color: Theme.accentInk
                                    font.family: Theme.bodySemibold
                                    font.pixelSize: Theme.fs(15)
                                }
                            }
                        }
                    }
                }
                WorkoutShape {
                    width: parent.width
                    height: 44
                    blocks: welcome.plan.blocks
                    summary: qsTr("Workout shape: gentle warm up, steady easy block, gentle cool down")
                }
            }
        }
    }

    Item { width: 1; height: 22 }
    Rise {
        cue: welcome
        order: 4
        width: parent.width
        Text {
            width: parent.width
            text: qsTr("Coming back matters more than any single hard ride.")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(14)
            lineHeight: 1.1
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
