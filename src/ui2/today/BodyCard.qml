import QtQuick 2.15
import ".."
import "../sig"

// Your body today, on Today: from Health Connect, last night's HRV, resting heart rate and sleep
// against your own usual (today/Body.js), as a plain line and the inputs themselves. Before the
// rider has said yes, one quiet offer to use them; nothing is read until then.
Rectangle {
    id: bodyCard

    property var body: null          // Body.today(), null while nothing has been read
    property bool asked: false       // the rider said yes (ui2/healthRead)

    signal connect()
    signal dismiss()

    readonly property color tone: !body ? Theme.text : body.state === "good" ? Theme.zoneColors[1]
                                  : body.state === "easy" ? Theme.zoneColors[4] : Theme.text

    width: parent ? parent.width : 0
    implicitHeight: content.height + 32
    radius: 24
    color: Theme.control

    Column {
        id: content
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 10

        CapLabel {
            text: bodyCard.asked ? qsTr("Your body today") : qsTr("Readiness from your body")
        }

        // the offer
        Text {
            visible: !bodyCard.asked
            width: parent.width
            text: qsTr("Use heart rate variability, resting heart rate and sleep from Health Connect, against what is usual for you. Read on this phone only, never sent anywhere.")
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 13
            lineHeightMode: Text.FixedHeight
            lineHeight: 18
            wrapMode: Text.WordWrap
        }
        Row {
            visible: !bodyCard.asked
            spacing: 8
            PulseButton {
                width: connectText.implicitWidth + 32
                height: 48
                pressedRadius: 14
                fill: pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                Accessible.name: qsTr("Use Health Connect for readiness")
                onClicked: bodyCard.connect()
                contentItem: Text {
                    id: connectText
                    text: qsTr("Use Health Connect")
                    color: Theme.accentInk
                    font.family: Theme.bodySemibold
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            PulseButton {
                width: laterText.implicitWidth + 32
                height: 48
                pressedRadius: 14
                fill: pressed ? Theme.pressed : "transparent"
                Accessible.name: laterText.text
                onClicked: bodyCard.dismiss()
                contentItem: Text {
                    id: laterText
                    text: qsTr("Not now")
                    color: Theme.text
                    font.family: Theme.bodySemibold
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // the answer
        Text {
            visible: bodyCard.asked
            width: parent.width
            text: !bodyCard.body ? qsTr("Reading Health Connect...")
                  : bodyCard.body.state === "none" ? qsTr("Nothing from last night yet. A watch or ring that writes to Health Connect brings it.")
                  : bodyCard.body.words
            color: bodyCard.tone
            font.family: Theme.bodySemibold
            font.pixelSize: 17
            wrapMode: Text.WordWrap
        }
        Flow {
            visible: bodyCard.asked && bodyCard.body !== null && bodyCard.body.inputs.length > 0
            width: parent.width
            spacing: 8
            Repeater {
                model: bodyCard.body ? bodyCard.body.inputs : []
                Rectangle {
                    width: inputColumn.implicitWidth + 24
                    height: inputColumn.implicitHeight + 16
                    radius: 14
                    color: Theme.bg
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.name + ", " + modelData.value + (modelData.usual !== "" ? ", " + modelData.usual : "")
                    Column {
                        id: inputColumn
                        x: 12
                        y: 8
                        spacing: 1
                        Text {
                            text: modelData.name
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData.value
                            color: modelData.tone > 0 ? Theme.zoneColors[1] : (modelData.tone < 0 ? Theme.zoneColors[4] : Theme.text)
                            font.family: Theme.bodySemibold
                            font.pixelSize: 15
                        }
                        Text {
                            visible: text !== ""
                            text: modelData.usual
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
