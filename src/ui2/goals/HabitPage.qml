import QtQuick 2.15
import ".."
import "../sig"

// A full page over Goals for the habit screens (goal setup, taking a break, welcome back): a
// round back or close button on the top line, the content in a column that scrolls when the
// window is short, and the one big pill at the bottom, clear of the floating navigation.
// It rises in on the default spring and fades on the effects curve.
Item {
    id: page

    property bool open: false
    property bool closeButton: false     // a close cross on the right instead of a back arrow
    property string topLabel: ""         // words on the top line, left
    property string primaryText: ""
    property bool primaryEnabled: true
    property bool quietPrimary: false    // a text button instead of the pill
    property real bottomClearance: 0
    property color glowTint: Theme.accent
    property real glowY: 260
    property real glowSize: 300
    property bool glow: true
    default property alias content: body.data
    readonly property real measure: Math.min(page.width - 2 * margin, 560)
    readonly property real margin: page.width < 400 ? 16 : 24
    property alias flick: flick

    signal back()
    signal primary()
    // each time the page opens: what is inside rises in again
    signal entered()

    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    enabled: open
    Accessible.ignored: !open
    transform: Translate { y: page.open ? 0 : 24; Behavior on y { enabled: !Theme.reduceMotion; Spring { token: "default" } } }
    Behavior on opacity {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
    }
    onOpenChanged: {
        if (open) {
            flick.contentY = 0
            entered()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }
    // keeps taps from reaching the page under it
    MouseArea { anchors.fill: parent }

    HeroGlow {
        visible: page.glow
        width: page.glowSize
        height: page.glowSize
        x: (page.width - width) / 2
        y: page.glowY - flick.contentY - height / 2
        tint: page.glowTint
        low: 0.22
        high: 0.34
    }

    Flickable {
        id: flick
        // 12 wider on each side, so a picked row can reach past the margin
        x: (page.width - page.measure) / 2 - 12
        width: page.measure + 24
        height: page.height - bottomBar.height - page.bottomClearance
        contentHeight: topLine.height + body.height + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: topLine
            x: 12
            y: 16
            width: parent.width - 24
            height: 44
            Text {
                visible: page.topLabel !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 60
                text: page.topLabel
                color: Theme.text
                font.family: Theme.bodyMedium
                font.pixelSize: 14
                elide: Text.ElideRight
            }
            PulseButton {
                x: page.closeButton ? parent.width - width + 2 : -2
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                topInset: 2
                bottomInset: 2
                leftInset: 2
                rightInset: 2
                fill: pressed ? Theme.pressed : Theme.control
                Accessible.name: page.closeButton ? qsTr("Close") : qsTr("Back")
                onClicked: page.back()
                contentItem: Item {
                    GoalGlyph {
                        anchors.centerIn: parent
                        size: page.closeButton ? 18 : 20
                        weight: 1.8
                        name: page.closeButton ? "close" : "back"
                        color: Theme.text
                    }
                }
            }
        }

        Column {
            id: body
            x: 12
            y: topLine.y + topLine.height
            width: parent.width - 24
        }
    }

    // the one big button, or a quiet text button
    Item {
        id: bottomBar
        x: (page.width - page.measure) / 2
        y: page.height - page.bottomClearance - height
        width: page.measure
        height: page.primaryText !== "" ? (page.quietPrimary ? 64 : 92) : 16

        // the page fades out above the button
        Rectangle {
            visible: page.primaryText !== ""
            y: -24
            width: parent.width
            height: 24
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0) }
                GradientStop { position: 1; color: Theme.bg }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
        }

        PulseButton {
            id: primaryButton
            visible: page.primaryText !== ""
            width: page.quietPrimary ? quietText.implicitWidth + 48 : parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            y: page.quietPrimary ? 8 : 8
            height: page.quietPrimary ? 48 : 64
            enabled: page.primaryEnabled
            opacity: enabled ? 1 : 0.4
            pressedRadius: page.quietPrimary ? 16 : 20
            fill: page.quietPrimary ? (pressed ? Theme.pressed : "transparent")
                                    : (pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
            Accessible.name: page.primaryText
            onClicked: page.primary()
            contentItem: Text {
                id: quietText
                text: page.primaryText
                color: page.quietPrimary ? Theme.accent : Theme.accentInk
                font.family: Theme.bodySemibold
                font.pixelSize: page.quietPrimary ? 15 : 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
