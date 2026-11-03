import QtQuick 2.15
import ".."

// Body and FTP: the numbers zones, calories and estimated power are worked out from.
YouPage {
    id: page

    title: qsTr("Body and FTP")
    lead: qsTr("Calories, zones and training load are worked out from these. They stay on this device.")

    readonly property var qz: you.qz
    readonly property int ageMax: Math.round(220 - qz.age)

    YouField {
        title: qsTr("Name")
        detail: qsTr("Shown on your profile")
        kind: "text"
        value: page.qz.user_nickname
        onCommitted: page.qz.user_nickname = text
    }

    YouField {
        title: qsTr("Weight")
        unit: you.lbs ? qsTr("lb") : qsTr("kg")
        kind: "number"
        minimum: you.lbs ? 44 : 20
        maximum: you.lbs ? 660 : 300
        // stored in kg, shown in pounds with miles unless kg is chosen
        value: you.lbs ? String(Math.round(page.qz.weight * 2.20462 * 10) / 10) : String(Math.round(page.qz.weight * 10) / 10)
        onCommitted: page.qz.weight = you.lbs ? Number(text) / 2.20462 : Number(text)
    }

    YouField {
        title: qsTr("Age")
        unit: qsTr("years")
        kind: "int"
        minimum: 5
        maximum: 110
        value: String(page.qz.age)
        onCommitted: page.qz.age = Number(text)
    }

    YouChoice {
        title: qsTr("Sex")
        detail: qsTr("Used for the calorie estimate")
        options: [["Male", qsTr("Male")], ["Female", qsTr("Female")]]
        current: page.qz.sex
        onPicked: page.qz.sex = value
    }

    YouText {
        kind: "heading"
        text: qsTr("Power")
    }

    YouField {
        title: qsTr("FTP")
        detail: qsTr("The power you could hold for about an hour. Your power zones start from it.")
        unit: qsTr("W")
        kind: "int"
        minimum: 30
        maximum: 2000
        value: String(Math.round(page.qz.ftp))
        hairline: false
        onCommitted: page.qz.ftp = Number(text)
    }

    YouText {
        kind: "heading"
        text: qsTr("Heart")
    }

    YouSwitch {
        title: qsTr("Set my max heart rate")
        detail: page.qz.heart_max_override_enable ? qsTr("Your heart zones use the number below.")
                : qsTr("Worked out from your age: %1 bpm").arg(page.ageMax)
        isOn: page.qz.heart_max_override_enable
        onSwitched: page.qz.heart_max_override_enable = value
    }

    YouField {
        visible: page.qz.heart_max_override_enable
        title: qsTr("Max heart rate")
        unit: qsTr("bpm")
        kind: "int"
        minimum: 100
        maximum: 240
        value: String(Math.round(page.qz.heart_max_override_value))
        onCommitted: page.qz.heart_max_override_value = Number(text)
    }

    YouField {
        title: qsTr("Resting heart rate")
        detail: qsTr("Measured lying still, best just after waking up")
        unit: qsTr("bpm")
        kind: "int"
        minimum: 25
        maximum: 120
        value: String(page.qz.heart_rate_resting)
        hairline: false
        onCommitted: page.qz.heart_rate_resting = Number(text)
    }
}
