import QtQuick 2.15
import ".."
import "../sig"

// The frame of every page of You, in the Signature language: a round back button on a phone
// (and step dots for a page in steps), a short headline, a quiet lead, then the rows on
// hairlines in a column that stays readable on a tablet. The headline and the rows rise in,
// again each time the page moves to another step.
Item {
    id: page

    // the YouScreen
    property var you: null
    property string title: ""
    property string lead: ""
    default property alias content: body.data

    // a page in steps: the dots in the top bar; with canStepBack, Back goes to stepBack()
    property int stepCount: 0
    property int stepIndex: 0
    property bool canStepBack: false

    signal stepBack()
    // the blocks rise in again
    signal entered()

    readonly property real margin: width < 600 ? 16 : 24
    readonly property bool showBack: (you !== null && !you.wide) || canStepBack
    readonly property real bottomClearance: you !== null && you.bottomClearance !== undefined ? you.bottomClearance : 0
    readonly property alias flickable: flick

    // Android back on a page in steps goes one step back; true when it did
    function goBack() {
        if (!canStepBack)
            return false
        stepBack()
        return true
    }

    onStepIndexChanged: {
        flick.contentY = 0
        entered()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.y + column.height + 32 + page.bottomClearance
                       + (page.you !== null && page.you.restartNeeded ? 140 : 0)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            width: Math.min(720, page.width - 2 * (page.margin - 12))
            x: (page.width - width) / 2
            y: 16

            // back and the steps
            Item {
                visible: page.showBack || page.stepCount > 0
                x: 12
                width: parent.width - 24
                height: 44

                PulseButton {
                    visible: page.showBack
                    width: 44
                    height: 44
                    fill: Theme.control
                    Accessible.name: qsTr("Back")
                    onClicked: page.canStepBack ? page.stepBack() : page.you.goBack()
                    contentItem: Item {
                        YouIcon {
                            anchors.centerIn: parent
                            name: "back"
                            size: 20
                            weight: 1.8
                            color: Theme.text
                        }
                    }
                }

                Row {
                    visible: page.stepCount > 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Accessible.role: Accessible.StaticText
                    Accessible.name: qsTr("Step %1 of %2").arg(page.stepIndex + 1).arg(page.stepCount)
                    Repeater {
                        model: page.stepCount
                        Rectangle {
                            width: 22
                            height: 5
                            radius: 2.5
                            color: index <= page.stepIndex ? Theme.accent : Theme.rest
                            Behavior on color {
                                enabled: !Theme.reduceMotion
                                ColorAnimation { duration: Theme.colorTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                            }
                        }
                    }
                }
            }

            Item {
                width: 1
                height: page.showBack || page.stepCount > 0 ? 18 : 12
            }

            Rise {
                cue: page
                order: 0
                width: parent.width
                Column {
                    width: parent.width
                    spacing: 10
                    Text {
                        width: parent.width
                        leftPadding: 12
                        rightPadding: 12
                        text: page.title
                        color: Theme.text
                        font.family: Theme.display
                        font.pixelSize: 30
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 33
                        wrapMode: Text.WordWrap
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    Text {
                        visible: page.lead !== ""
                        width: parent.width
                        leftPadding: 12
                        rightPadding: 12
                        text: page.lead
                        color: Theme.text2
                        font.family: Theme.bodyMedium
                        font.pixelSize: 14
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 20
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item {
                width: 1
                height: 14
            }

            Rise {
                cue: page
                order: 1
                width: parent.width
                Column {
                    id: body
                    width: parent.width
                }
            }
        }
    }
}
