import QtQuick 2.15
import ".."
import "../sig"
import "../settings"

// Units and the choices that make Bikemodo the rider's own, as hairline rows under two cap
// labels: metric or imperial (and pounds or kilograms with imperial), the layout a ride opens
// with, Simple or Pro, the accent, the first day of the week, who sets the resistance, merging
// rides split by a short pause, and calmer motion. On the list of You, and on the Units page.
// Every value is written at once (QZ's keys through YouScreen.setMiles / setWeightKg, Bikemodo's
// own ui2 keys through YouScreen.setLook), so the other screens read the new value next time.
Column {
    id: prefs

    // the YouScreen
    property var you: null

    readonly property var qz: you.qz
    readonly property var look: you.look

    width: parent ? parent.width : implicitWidth

    YouText {
        kind: "heading"
        text: qsTr("Units")
    }

    YouChoice {
        title: qsTr("Measurements")
        detail: prefs.qz.miles_unit ? (prefs.qz.weight_kg_unit ? qsTr("Miles and mph, weight in kilograms.") : qsTr("Miles, mph and pounds."))
                                    : qsTr("Kilometers, km/h and kilograms.")
        options: [[false, qsTr("Metric")], [true, qsTr("Imperial")]]
        current: prefs.qz.miles_unit
        hairline: prefs.qz.miles_unit
        onPicked: prefs.you.setMiles(value)
    }

    // QZ keeps kilograms with kilometers; with miles the rider may keep kilograms
    YouChoice {
        visible: prefs.qz.miles_unit
        title: qsTr("Weight")
        options: [[false, qsTr("Pounds")], [true, qsTr("Kilograms")]]
        current: prefs.qz.weight_kg_unit
        hairline: false
        onPicked: prefs.you.setWeightKg(value)
    }

    YouText {
        kind: "heading"
        text: qsTr("Make it yours")
    }

    YouChoice {
        title: qsTr("Ride screen")
        detail: prefs.look.ridePreset === "custom" ? qsTr("Now your own layout. Picking one here replaces it.")
                : qsTr("The numbers a ride opens with. Tap any number during a ride to change it.")
        options: [["power", qsTr("Power")], ["simple", qsTr("Simple")], ["heart", qsTr("Heart")], ["focus", qsTr("Focus")]]
        current: prefs.look.ridePreset
        onPicked: prefs.you.setLook("ridePreset", value)
    }

    YouChoice {
        title: qsTr("Detail level")
        detail: prefs.look.detailLevel === "pro" ? qsTr("Pro shows every number and chart there is.")
                : qsTr("Simple shows the numbers most rides need.")
        options: [["simple", qsTr("Simple")], ["pro", qsTr("Pro")]]
        current: prefs.look.detailLevel
        onPicked: prefs.you.setLook("detailLevel", value)
    }

    YouChoice {
        title: qsTr("Look")
        detail: prefs.look.appearance === "light" ? qsTr("Light, for bright rooms. Changes after a ride, never during one.")
                : prefs.look.appearance === "dark" ? qsTr("Dark, whatever the phone uses.")
                : qsTr("Follows the phone's dark theme. Changes after a ride, never during one.")
        options: [["system", qsTr("Phone")], ["dark", qsTr("Dark")], ["light", qsTr("Light")]]
        current: prefs.look.appearance
        onPicked: prefs.you.setLook("appearance", value)
    }

    // the accent: a row of swatches, the picked one ringed with a check
    Column {
        width: parent.width
        topPadding: 14
        spacing: 12
        Column {
            x: 12
            width: parent.width - 24
            spacing: 3
            Text {
                width: parent.width
                text: qsTr("Accent")
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize + 1
            }
            Text {
                width: parent.width
                text: qsTr("%1. The color of buttons, rings and the Ride button.").arg(Theme.accentEntry.name)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
        }
        Row {
            id: swatches
            x: 12
            readonly property real cell: Math.min(48, (prefs.width - 24 - 5 * 6) / 6)
            spacing: Math.max(6, Math.min(14, (prefs.width - 24 - 6 * cell) / 5))
            Repeater {
                model: Theme.accents
                PulseButton {
                    id: swatch
                    readonly property bool on: Theme.accentChoice === modelData.id
                    width: swatches.cell
                    height: swatches.cell
                    pressedScale: 0.9
                    fill: "transparent"
                    Accessible.name: qsTr("Accent %1").arg(modelData.name) + (on ? ", " + qsTr("selected") : "")
                    Accessible.checkable: true
                    Accessible.checked: on
                    onClicked: prefs.you.setLook("accentChoice", modelData.id)
                    contentItem: Item {
                        // the ring of the picked one
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.light ? modelData.lightColor : modelData.color
                            opacity: swatch.on ? 1 : 0
                            Behavior on opacity {
                                enabled: !Theme.reduceMotion
                                NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: swatch.on ? parent.width - 10 : parent.width - 4
                            height: width
                            radius: width / 2
                            color: Theme.light ? modelData.lightColor : modelData.color
                            Behavior on width {
                                enabled: Theme.layoutMotion
                                Spring { token: "fast" }
                            }
                            YouIcon {
                                anchors.centerIn: parent
                                visible: swatch.on
                                name: "check"
                                size: 16
                                weight: 2.6
                                color: Theme.light ? "#ffffff" : modelData.ink
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            x: 12
            width: parent.width - 24
            height: 1
            color: Theme.hairline
        }
    }

    // every week calculation follows it (Theme.weekStart, Format.firstDay, goals/Streak.js)
    YouChoice {
        title: qsTr("Week starts on")
        detail: qsTr("For the week on Today, your calendar and weekly totals.")
        options: [[1, qsTr("Monday")], [0, qsTr("Sunday")]]
        current: prefs.look.weekStart
        onPicked: prefs.you.setLook("weekStart", value)
    }

    YouChoice {
        title: qsTr("Resistance control")
        detail: (prefs.look.resistanceControl === "on" ? qsTr("The level buttons always show while you ride.")
                 : prefs.look.resistanceControl === "off" ? qsTr("No level buttons, you turn the knob.")
                 : qsTr("The level buttons show when the bike lets Bikemodo set the level."))
                + " " + qsTr("Some bikes only allow manual resistance.")
        options: [["auto", qsTr("Auto")], ["on", qsTr("Always on")], ["off", qsTr("Off")]]
        current: prefs.look.resistanceControl
        onPicked: prefs.you.setLook("resistanceControl", value)
    }

    YouSwitch {
        title: qsTr("Pause when you stop")
        detail: qsTr("After 5 seconds without pedaling, or when the bike drops out. Pedal again and the ride goes on.")
        isOn: prefs.look.autoPause !== false
        onSwitched: prefs.you.setLook("autoPause", value)
    }

    YouSwitch {
        title: qsTr("Beeps and buzz")
        detail: qsTr("3, 2, 1 before each step of a workout, and a tick at a new zone. Quiet when the phone is on silent.")
        isOn: prefs.look.cueSound !== false
        onSwitched: prefs.you.setLook("cueSound", value)
    }

    YouSwitch {
        title: qsTr("Spoken cues")
        detail: qsTr("Each step of a workout and each lap, said out loud.")
        isOn: prefs.look.cueVoice === true
        onSwitched: prefs.you.setLook("cueVoice", value)
    }

    // the gap under which two rides become one, 0 for never; on a narrow column the stepper goes
    // under the words
    Item {
        id: mergeRow
        readonly property bool stacked: width < 400
        width: parent.width
        height: stacked ? mergeTexts.implicitHeight + mergeStepper.height + 40
                        : Math.max(76, mergeTexts.implicitHeight + 28)
        Column {
            id: mergeTexts
            x: 12
            y: mergeRow.stacked ? 14 : (mergeRow.height - height) / 2
            width: mergeRow.stacked ? mergeRow.width - 24 : Math.max(0, mergeStepper.x - x - 12)
            spacing: 3
            Text {
                width: parent.width
                text: qsTr("Merge rides after a short pause")
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize + 1
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: prefs.look.mergeGapMinutes > 0
                      ? qsTr("Rides less than %1 min apart count as one.").arg(prefs.look.mergeGapMinutes)
                      : qsTr("Every ride stays on its own.")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
                wrapMode: Text.WordWrap
            }
        }
        NumberStepper {
            id: mergeStepper
            x: mergeRow.stacked ? 6 : parent.width - width - 12
            y: mergeRow.stacked ? mergeTexts.y + mergeTexts.height + 12 : (mergeRow.height - height) / 2
            width: 156
            height: 48
            buttonSize: 44
            numberSize: 22
            value: prefs.look.mergeGapMinutes
            from: 0
            to: 60
            step: 5
            unit: qsTr("min")
            zeroText: qsTr("Off")
            name: qsTr("Merge rides, minutes apart")
            onEdited: prefs.you.setLook("mergeGapMinutes", value)
        }
        Rectangle {
            x: 12
            y: parent.height - 1
            width: parent.width - 24
            height: 1
            color: Theme.hairline
        }
    }

    YouSwitch {
        title: qsTr("Reduce motion")
        detail: qsTr("No breathing glow, turning shapes or springy movement.")
        isOn: prefs.look.reduceMotion === true
        hairline: false
        onSwitched: prefs.you.setLook("reduceMotion", value)
    }
}
