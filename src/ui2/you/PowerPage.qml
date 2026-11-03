import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"

// Power, honestly: how far to trust the watts. Three steps of confidence, each drawn as the Pulse
// (a dashed outline for an estimate, half filled when checked, filled with a check when
// calibrated), the FTP the zones start from on the one raised card, how an Echelon turns level
// and cadence into watts, and calibration with a power meter, which is not built yet and says so.
YouPage {
    id: page

    title: qsTr("Your power, honestly")
    lead: you.powerEstimated ? qsTr("Your bike has no power meter, so Bikemodo works out the watts from level and cadence. Here is how far to trust them.")
                             : qsTr("Your bike measures watts itself, so the numbers come straight from it.")

    readonly property var qz: you.qz

    // shape: "dashed", "half" or "full"; state: "now", "coming" or ""
    readonly property var tiers: [
        you.powerEstimated
            ? { name: qsTr("Estimated"), detail: qsTr("From level and cadence. Usually within 10 to 20 percent."), shape: "dashed", state: "now" }
            : { name: qsTr("Measured"), detail: qsTr("From the power meter in your bike."), shape: "full", state: "now" },
        { name: qsTr("Checked"), detail: qsTr("Your heart rate agrees with the watts."), shape: "half", state: "coming" },
        { name: qsTr("Calibrated"), detail: qsTr("Matched to a power meter, level by level. Within about 3 percent."), shape: "full", state: "coming" }
    ]

    YouText {
        kind: "heading"
        topPadding: 8
        text: qsTr("How sure the watts are")
    }

    Repeater {
        model: page.tiers
        delegate: Item {
            width: parent.width
            height: Math.max(88, tierText.implicitHeight + 32)
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.name + ", " + modelData.detail
                             + (modelData.state === "now" ? ", " + qsTr("now") : (modelData.state === "coming" ? ", " + qsTr("coming later") : ""))

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: modelData.state === "now" ? Qt.rgba(201 / 255, 184 / 255, 1, 0.08) : "transparent"
            }
            // the line between two steps
            Rectangle {
                visible: index < page.tiers.length - 1
                x: confidence.x + confidence.width / 2 - 1
                y: confidence.y + confidence.height + 8
                width: 2
                height: parent.height - confidence.height - 16 + 16
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // the confidence, as the Pulse
            Item {
                id: confidence
                x: 16
                y: 18
                width: 48
                height: 48
                readonly property color ink: modelData.state === "now" ? Theme.accent : Theme.text3
                Shape {
                    width: 108
                    height: 108
                    scale: confidence.width / 108
                    transformOrigin: Item.TopLeft
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeColor: modelData.shape === "dashed" ? confidence.ink : (modelData.shape === "half" ? Theme.text3 : "transparent")
                        strokeWidth: modelData.shape === "dashed" ? 7 : 6
                        strokeStyle: modelData.shape === "dashed" ? ShapePath.DashLine : ShapePath.SolidLine
                        dashPattern: [1.3, 1.6]
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        fillColor: modelData.shape === "full" ? confidence.ink : "transparent"
                        PathSvg { path: Theme.pulsePath(2) }
                    }
                }
                // half filled: the lower half of the shape
                Item {
                    visible: modelData.shape === "half"
                    y: confidence.height / 2
                    width: confidence.width
                    height: confidence.height / 2
                    clip: true
                    Shape {
                        y: -confidence.height / 2
                        width: 108
                        height: 108
                        scale: confidence.width / 108
                        transformOrigin: Item.TopLeft
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeWidth: -1
                            fillColor: Theme.dashed
                            PathSvg { path: Theme.pulsePath(2) }
                        }
                    }
                }
                YouIcon {
                    visible: modelData.shape === "full"
                    anchors.centerIn: parent
                    name: "check"
                    size: 22
                    weight: 3
                    color: Theme.bg
                }
            }

            Column {
                id: tierText
                x: confidence.x + confidence.width + 16
                y: 18
                width: parent.width - x - 16
                spacing: 6
                Row {
                    spacing: 8
                    Text {
                        id: tierName
                        text: modelData.name
                        color: modelData.state === "coming" ? Theme.text2 : Theme.text
                        font.family: Theme.bodySemibold
                        font.pixelSize: 17
                    }
                    Rectangle {
                        visible: modelData.state !== ""
                        anchors.verticalCenter: tierName.verticalCenter
                        width: chipText.implicitWidth + 18
                        height: 22
                        radius: 11
                        color: modelData.state === "now" ? Theme.accent : Theme.pressed
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.state === "now" ? qsTr("Now") : qsTr("Coming")
                            color: modelData.state === "now" ? Theme.accentInk : Theme.text2
                            font.family: Theme.bodySemibold
                            font.pixelSize: 12
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: modelData.detail
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 14
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.45)
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Item {
        width: 1
        height: 20
    }

    // the one raised surface: the FTP the zones start from
    Item {
        width: parent.width
        height: ftpCard.height
        Rectangle {
            id: ftpCard
            x: 12
            width: parent.width - 24
            height: ftpColumn.height + 40
            radius: Theme.heroRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.raisedBorder

            Column {
                id: ftpColumn
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 12
                CapLabel {
                    text: qsTr("Your FTP")
                }
                Item {
                    width: parent.width
                    height: Math.max(ftpRow.height, change.height)
                    Row {
                        id: ftpRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Numeral {
                            id: ftpNumber
                            text: String(Math.round(page.qz.ftp))
                            color: Theme.text
                            font.family: Theme.heroFamily(4)
                            font.pixelSize: 44
                        }
                        Text {
                            anchors.baseline: ftpNumber.baseline
                            text: qsTr("W")
                            color: Theme.text2
                            font.family: Theme.bodyMedium
                            font.pixelSize: 15
                        }
                        Text {
                            visible: you.powerEstimated
                            anchors.baseline: ftpNumber.baseline
                            text: qsTr("est.")
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: 12
                        }
                    }
                    YouButton {
                        id: change
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Change")
                        onClicked: you.open("body")
                    }
                }
                Text {
                    width: parent.width
                    text: you.powerEstimated ? qsTr("Your zones start from it. Set from estimated watts, it is an estimate too.")
                                             : qsTr("Your zones start from it.")
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: 13
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.45)
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Echelon watts")
    }

    YouChoice {
        title: qsTr("Watt table")
        detail: qsTr("How Bikemodo turns level and cadence into watts on an Echelon without a power meter. Try the other one if your watts look off.")
        options: [["Echelon", qsTr("Echelon")], ["mgarcea", qsTr("mgarcea")]]
        current: page.qz.echelon_watttable
        hairline: false
        onPicked: page.qz.echelon_watttable = value
    }

    YouText {
        kind: "heading"
        text: qsTr("Calibration")
    }

    // not built yet: shown so the rider knows it is coming, and plainly marked so
    Item {
        width: parent.width
        height: calibrateButton.height + 8
        YouButton {
            id: calibrateButton
            x: 12
            width: parent.width - 24
            height: 56
            enabled: false
            text: qsTr("Calibrate with a power meter")
            Accessible.name: qsTr("Calibrate with a power meter, coming in a later version")
        }
        Rectangle {
            anchors.right: calibrateButton.right
            anchors.rightMargin: 14
            anchors.verticalCenter: calibrateButton.verticalCenter
            width: comingText.implicitWidth + 18
            height: 24
            radius: 12
            color: Theme.accentInk
            Text {
                id: comingText
                anchors.centerIn: parent
                text: qsTr("Coming")
                color: Theme.accent
                font.family: Theme.bodySemibold
                font.pixelSize: 12
            }
        }
    }

    YouText {
        text: qsTr("Coming in a later version: ride a few minutes at each level with a power meter on the bike, and Bikemodo corrects the watts level by level. Until then, watts on this bike stay estimates.")
    }
}
