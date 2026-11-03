import QtQuick 2.15
import ".."
import "../sig"

// The one raised surface of Progress: what the period means, as a coach would say it, and what
// to do next (Hub.insight). The sentence fades over when the period changes.
Rectangle {
    id: insight
    objectName: "insightBlock"

    property string headline: ""
    property string line: ""
    property string label: qsTr("This period")

    implicitHeight: body.implicitHeight + 44
    radius: Theme.heroRadius
    color: Theme.card
    border.width: 1
    border.color: Theme.raisedBorder
    Accessible.role: Accessible.StaticText
    Accessible.name: headline + " " + line

    Column {
        id: body
        x: 22
        y: 22
        width: parent.width - 44
        spacing: 10

        Row {
            spacing: 8
            Pulse {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                zone: 2
                color: Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: insight.label
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: 13
            }
        }
        Text {
            id: headlineText
            width: parent.width
            text: insight.headline
            color: Theme.text
            font.family: Theme.display
            font.pixelSize: insight.width < 380 ? 21 : 23
            font.letterSpacing: -0.3
            lineHeightMode: Text.FixedHeight
            lineHeight: Math.round(font.pixelSize * 1.2)
            wrapMode: Text.WordWrap
            Behavior on text {
                enabled: !Theme.reduceMotion
                SequentialAnimation {
                    NumberAnimation { target: headlineText; property: "opacity"; to: 0; duration: 120 }
                    PropertyAction {}
                    NumberAnimation {
                        target: headlineText; property: "opacity"; to: 1
                        duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve
                    }
                }
            }
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: insight.line
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: 14
            lineHeightMode: Text.FixedHeight
            lineHeight: 20
            wrapMode: Text.WordWrap
        }
    }
}
