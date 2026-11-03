import QtQuick 2.15
import ".."

// Units and display: kilometers or miles, kilograms or pounds, how much the screens show,
// and calmer motion.
YouPage {
    id: page

    title: qsTr("Units and display")

    readonly property var qz: you.qz
    readonly property var prefs: you.prefs

    YouChoice {
        title: qsTr("Distance and speed")
        options: [[false, qsTr("Kilometers")], [true, qsTr("Miles")]]
        current: page.qz.miles_unit
        onPicked: {
            page.qz.miles_unit = value
            page.qz.setValue("miles_unit", value)
        }
    }

    YouChoice {
        visible: page.qz.miles_unit
        title: qsTr("Weight")
        detail: qsTr("Pounds go with miles, unless you prefer kilograms.")
        options: [[false, qsTr("Pounds")], [true, qsTr("Kilograms")]]
        current: page.qz.weight_kg_unit
        onPicked: {
            page.qz.weight_kg_unit = value
            page.qz.setValue("weight_kg_unit", value)
        }
    }

    YouText {
        visible: !page.qz.miles_unit
        text: qsTr("Weight is in kilograms with kilometers.")
    }

    YouText {
        kind: "heading"
        text: qsTr("Display")
    }

    YouChoice {
        title: qsTr("Detail level")
        detail: page.prefs.detailLevel === "pro" ? qsTr("Pro shows every number and chart there is.")
                : qsTr("Simple shows the numbers most rides need.")
        options: [["simple", qsTr("Simple")], ["pro", qsTr("Pro")]]
        current: page.prefs.detailLevel
        onPicked: page.prefs.detailLevel = value
    }

    YouSwitch {
        title: qsTr("Reduce motion")
        detail: qsTr("No breathing glow, turning shapes or springy movement.")
        isOn: page.prefs.reduceMotion
        hairline: false
        onSwitched: {
            page.prefs.reduceMotion = value
            Theme.reduceMotion = value
        }
    }
}
