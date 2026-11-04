import QtQuick 2.15
import ".."
import "../sig"
import "../you"
import "../goals"

// The first run: four short steps on the habit pages, each one skippable, nothing presented as a
// fact the rider did not give. 1 name and units, 2 the bike (main2 shows the StartScreen in setup
// mode for it), 3 FTP and age (left empty, Bikemodo keeps power zones neutral and the heart zones
// estimated), 4 the weekly goal (GoalSetup). main2 stores what comes out and keeps the step.
Item {
    id: setup

    // 0 welcome, 1 the bike (not drawn here), 2 power and heart, 3 the weekly goal
    property int step: 0
    property string nickname: ""
    property bool miles: false
    property int age: 35
    property real bottomClearance: 0

    signal nameChosen(string name)
    signal milesChosen(bool miles)
    signal ageChosen(int age)
    signal goalChosen(string goalKind, real goalValue)
    signal next()
    signal previous()
    signal skipAll()

    // what was typed on the power and heart page, stored on Next
    property string ftpText: Theme.ftpSet ? String(Math.round(Theme.ftp)) : ""
    property string ageText: age !== 35 ? String(age) : ""

    function finishBody() {
        var watts = Number(ftpText)
        if (ftpText !== "" && watts >= 50 && watts <= 999)
            Theme.setFtp(watts)
        var years = Number(ageText)
        if (ageText !== "" && years >= 10 && years <= 99)
            ageChosen(Math.round(years))
        next()
    }

    // a quiet Skip on the top line, right, over the habit page
    component SkipButton: PulseButton {
        property var page
        x: (page.width - page.measure) / 2 + page.measure - width + 2
        y: 14
        width: skipText.implicitWidth + 32
        height: 48
        fill: pressed ? Theme.pressed : "transparent"
        Accessible.name: skipText.text
        contentItem: Text {
            id: skipText
            text: qsTr("Skip")
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // 1 of 4: who rides and how distance reads
    HabitPage {
        id: welcome
        anchors.fill: parent
        open: setup.step === 0
        closeButton: true
        topLabel: qsTr("1 of 4")
        primaryText: qsTr("Next")
        bottomClearance: setup.bottomClearance
        glowY: 200
        onBack: setup.skipAll()
        onPrimary: setup.next()

        Item { width: 1; height: 20 }
        Rise {
            cue: welcome
            order: 0
            width: parent.width
            Column {
                width: parent.width
                spacing: 10
                Text {
                    width: parent.width
                    text: qsTr("Welcome to Bikemodo")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: setup.width < 400 ? 28 : 30
                    font.letterSpacing: -0.6
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Text {
                    width: parent.width
                    text: qsTr("Four quick steps, then your first ride. Skip any of them, everything can change later in You.")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 15
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.45)
                    wrapMode: Text.WordWrap
                }
            }
        }
        Item { width: 1; height: 16 }
        Rise {
            cue: welcome
            order: 1
            width: parent.width
            Column {
                width: parent.width
                YouField {
                    title: qsTr("Your name")
                    detail: qsTr("For the greeting on Today")
                    kind: "text"
                    value: setup.nickname
                    onCommitted: setup.nameChosen(text)
                }
                YouChoice {
                    title: qsTr("Distance and speed in")
                    options: [[false, qsTr("Kilometers")], [true, qsTr("Miles")]]
                    current: setup.miles
                    hairline: false
                    onPicked: setup.milesChosen(value)
                }
            }
        }
    }

    // 3 of 4: FTP and age, both optional
    HabitPage {
        id: body
        anchors.fill: parent
        open: setup.step === 2
        topLabel: qsTr("3 of 4")
        primaryText: qsTr("Next")
        bottomClearance: setup.bottomClearance
        glowY: 200
        onBack: setup.previous()
        onPrimary: setup.finishBody()

        Item { width: 1; height: 20 }
        Rise {
            cue: body
            order: 0
            width: parent.width
            Column {
                width: parent.width
                spacing: 10
                Text {
                    width: parent.width
                    text: qsTr("Your power and heart")
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: setup.width < 400 ? 28 : 30
                    font.letterSpacing: -0.6
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Text {
                    width: parent.width
                    text: qsTr("Both are optional. Leave a box empty if you are not sure.")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 15
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.45)
                    wrapMode: Text.WordWrap
                }
            }
        }
        Item { width: 1; height: 16 }
        Rise {
            cue: body
            order: 1
            width: parent.width
            Column {
                width: parent.width
                YouField {
                    title: qsTr("FTP")
                    detail: setup.ftpText !== "" ? qsTr("Your power zones start from it")
                                                 : qsTr("The power you could hold for about an hour. Not sure? After a few rides Bikemodo suggests one, until then power zones stay off.")
                    unit: "W"
                    kind: "int"
                    minimum: 50
                    maximum: 999
                    value: setup.ftpText
                    onCommitted: setup.ftpText = text
                }
                YouField {
                    title: qsTr("Age")
                    detail: setup.ageText !== "" ? qsTr("Heart zones from an estimated max of %1 bpm. Change it in You if you know yours.").arg(220 - Number(setup.ageText))
                                                 : qsTr("Gives an estimated max heart rate for heart zones.")
                    kind: "int"
                    minimum: 10
                    maximum: 99
                    hairline: false
                    value: setup.ageText
                    onCommitted: setup.ageText = text
                }
            }
        }
    }
    SkipButton {
        page: body
        visible: body.visible
        opacity: body.opacity
        onClicked: setup.next()
    }

    // 4 of 4: the weekly goal
    GoalSetup {
        id: goal
        anchors.fill: parent
        open: setup.step === 3
        topLabel: qsTr("4 of 4")
        bottomClearance: setup.bottomClearance
        miles: setup.miles
        onBack: setup.previous()
        onChosen: setup.goalChosen(goalKind, goalValue)
    }
    SkipButton {
        page: goal
        visible: goal.visible
        opacity: goal.opacity
        onClicked: setup.next()
    }
}
