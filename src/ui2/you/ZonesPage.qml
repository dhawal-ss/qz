import QtQuick 2.15
import ".."

// Zones: power zones from FTP, heart zones from max heart rate and QZ's four zone steps.
YouPage {
    id: page

    title: qsTr("Zones")

    readonly property var qz: you.qz
    readonly property int ftp: Math.round(qz.ftp)
    // QZ's steps: the share of max heart rate where zones 2 to 5 start
    readonly property var steps: [qz.heart_rate_zone1, qz.heart_rate_zone2, qz.heart_rate_zone3, qz.heart_rate_zone4]

    function heartRange(zone) {
        var max = you.maxHeartRate
        var starts = steps.map(function (p) { return Math.round(max * p / 100) })
        if (zone <= 1)
            return qsTr("under %1 bpm").arg(starts[0])
        if (zone >= 5)
            return qsTr("%1 bpm and up").arg(starts[3])
        return qsTr("%1 to %2 bpm").arg(starts[zone - 2]).arg(starts[zone - 1] - 1)
    }

    // What the heart zones start from (ui2/heartZoneBasis): the share of max heart rate as QZ keeps
    // them, heart rate reserve (Karvonen: 60, 70, 80 and 90% of the way from resting to max), or the
    // threshold heart rate (lactate threshold, the zones Joe Friel gives: 81, 90, 94 and 100% of it).
    // The last two are written as QZ's four steps, so the ride screen, saved rides and QZ agree.
    property string basis: String(you.prefs.value("heartZoneBasis", "max"))
    property int lthr: Number(you.prefs.value("lthr", 0)) || 0

    function applyBasis(b) {
        basis = b
        you.prefs.setValue("heartZoneBasis", b)
        var max = you.maxHeartRate
        var rest = qz.heart_rate_resting
        var out
        if (b === "reserve" && max > rest && rest > 0)
            out = [0.6, 0.7, 0.8, 0.9].map(function (f) { return (rest + f * (max - rest)) / max * 100 })
        else if (b === "threshold" && lthr > 0 && max > 0)
            out = [0.81, 0.90, 0.94, 1.0].map(function (f) { return f * lthr / max * 100 })
        else if (b === "max")
            out = [60, 70, 80, 90]
        if (!out)
            return
        for (var i = 0; i < 4; i++)
            setStep(i, Math.round(out[i] * 10) / 10)
    }

    // also in Theme, so the ride screen uses the new steps at once
    function setStep(i, percent) {
        if (i === 0) {
            qz.heart_rate_zone1 = percent
            Theme.savedZones.heart_rate_zone1 = percent
        } else if (i === 1) {
            qz.heart_rate_zone2 = percent
            Theme.savedZones.heart_rate_zone2 = percent
        } else if (i === 2) {
            qz.heart_rate_zone3 = percent
            Theme.savedZones.heart_rate_zone3 = percent
        } else {
            qz.heart_rate_zone4 = percent
            Theme.savedZones.heart_rate_zone4 = percent
        }
    }

    YouText {
        kind: "heading"
        topPadding: 8
        text: qsTr("Power zones")
    }
    YouText {
        text: qsTr("From your FTP of %1 W. Change it in Body and FTP.").arg(page.ftp)
    }

    Repeater {
        model: 7
        delegate: Item {
            width: parent.width
            height: Math.max(52, powerName.implicitHeight + 20)
            Accessible.role: Accessible.StaticText
            Accessible.name: powerName.text + ", " + powerRange.text

            Rectangle {
                id: powerSwatch
                x: 12
                width: 8
                height: 28
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.zoneColors[index]
            }
            Text {
                id: powerName
                x: powerSwatch.x + powerSwatch.width + 14
                width: powerRange.x - x - 12
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Zone %1, %2").arg(index + 1).arg(Theme.powerZoneNames[index])
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                wrapMode: Text.WordWrap
            }
            Text {
                id: powerRange
                x: parent.width - width - 12
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.powerZoneRange(index + 1, page.ftp)
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize + 1
            }
            Rectangle {
                visible: index < 6
                anchors { left: powerName.left; right: parent.right; bottom: parent.bottom; rightMargin: 12 }
                height: 1
                color: Theme.hairline
            }
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Heart zones")
    }
    YouText {
        text: you.qz.heart_max_override_enable ? qsTr("From your max heart rate of %1 bpm.").arg(you.maxHeartRate)
              : qsTr("From your max heart rate of %1 bpm, worked out from your age. Set your own in Body and FTP.").arg(you.maxHeartRate)
    }

    YouChoice {
        title: qsTr("Heart zones from")
        detail: page.basis === "reserve" ? qsTr("Your heart rate reserve, between resting (%1 bpm) and max.").arg(page.qz.heart_rate_resting)
                : page.basis === "threshold" ? (page.lthr > 0 ? qsTr("Your threshold heart rate of %1 bpm.").arg(page.lthr)
                                                              : qsTr("Type your threshold heart rate below: the average of the last 20 minutes of a 30 minute all-out ride."))
                : qsTr("A share of your max heart rate, as set below.")
        options: [["max", qsTr("Max")], ["reserve", qsTr("Reserve")], ["threshold", qsTr("Threshold")]]
        current: page.basis
        onPicked: page.applyBasis(value)
    }
    YouField {
        visible: page.basis === "threshold"
        title: qsTr("Threshold heart rate")
        unit: "bpm"
        kind: "int"
        minimum: 100
        maximum: 220
        value: page.lthr > 0 ? String(page.lthr) : ""
        onCommitted: {
            page.lthr = Number(text)
            you.prefs.setValue("lthr", page.lthr)
            page.applyBasis("threshold")
        }
    }

    Repeater {
        model: 5
        delegate: Item {
            width: parent.width
            height: Math.max(52, heartName.implicitHeight + 20)
            Accessible.role: Accessible.StaticText
            Accessible.name: heartName.text + ", " + heartRange.text

            Rectangle {
                id: heartSwatch
                x: 12
                width: 8
                height: 28
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                // the same colors as the ride screen in a heart zone
                color: Theme.zoneColors[index]
            }
            Text {
                id: heartName
                x: heartSwatch.x + heartSwatch.width + 14
                width: heartRange.x - x - 12
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Zone %1, %2").arg(index + 1).arg(Theme.heartZoneNames[index])
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                wrapMode: Text.WordWrap
            }
            Text {
                id: heartRange
                x: parent.width - width - 12
                anchors.verticalCenter: parent.verticalCenter
                text: page.heartRange(index + 1)
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize + 1
            }
            Rectangle {
                visible: index < 4
                anchors { left: heartName.left; right: parent.right; bottom: parent.bottom; rightMargin: 12 }
                height: 1
                color: Theme.hairline
            }
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Where each heart zone starts")
    }
    YouText {
        text: qsTr("As a share of your max heart rate. Each step has to be above the one before.")
    }

    Repeater {
        model: 4
        delegate: YouField {
            title: qsTr("Zone %1 starts at").arg(index + 2)
            unit: qsTr("%")
            kind: "int"
            minimum: index === 0 ? 30 : Math.round(page.steps[index - 1]) + 1
            maximum: index === 3 ? 120 : Math.round(page.steps[index + 1]) - 1
            value: String(Math.round(page.steps[index]))
            hairline: index < 3
            onCommitted: page.setStep(index, Number(text))
        }
    }
}
