import QtQuick 2.15
import ".."

// A pill that acts only when held: the fill grows across it while the finger stays down and
// the action happens when it is full, so a stray tap on a moving bike cannot end a ride.
// A short tap only asks for a hold (tapped); a screen reader, which cannot hold, asks for a
// confirm instead (confirmRequested).
Item {
    id: hold

    property string label: qsTr("End")
    property string holdingLabel: qsTr("Keep holding")
    property string spokenName: qsTr("End ride. Press and hold to end it.")
    property color fill: Theme.chip
    property color fillDone: Theme.text
    property color ink: Theme.text
    property int holdTime: 1200
    property int fontSize: 15
    property real radius: height / 2

    // 0 to 1 while held
    property real progress: 0
    readonly property bool holding: area.pressed

    signal held()
    signal tapped()
    signal confirmRequested()

    opacity: enabled ? 1 : 0.35
    Accessible.role: Accessible.Button
    Accessible.name: hold.spokenName
    Accessible.onPressAction: hold.confirmRequested()

    scale: area.pressed ? 0.97 : 1
    Behavior on scale {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
    }

    Rectangle {
        id: base
        anchors.fill: parent
        radius: area.pressed ? Math.min(hold.radius, 18) : hold.radius
        color: hold.fill
        Behavior on radius {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.fast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.springCurve }
        }

        // the hold fills the pill from its middle out: the same shape, growing to its edges
        Rectangle {
            anchors.fill: parent
            visible: hold.progress > 0
            radius: parent.radius
            scale: hold.progress
            color: Qt.rgba(hold.fillDone.r, hold.fillDone.g, hold.fillDone.b, 0.24)
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 16
        horizontalAlignment: Text.AlignHCenter
        text: hold.holding ? hold.holdingLabel : hold.label
        color: hold.ink
        font.family: Theme.bodySemibold
        font.pixelSize: hold.fontSize
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 10
        elide: Text.ElideRight
    }

    NumberAnimation {
        id: fillUp
        target: hold
        property: "progress"
        to: 1
        easing.type: Easing.Linear
        onFinished: {
            if (area.pressed && hold.progress >= 1) {
                hold.progress = 0
                area.done = true
                hold.held()
            }
        }
    }
    NumberAnimation {
        id: fillBack
        target: hold
        property: "progress"
        to: 0
        duration: Theme.reduceMotion ? 0 : 220
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.effectsCurve
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: hold.enabled
        // true once this press has ended the ride, so the release does nothing more
        property bool done: false
        onPressed: {
            done = false
            fillBack.stop()
            fillUp.duration = Math.max(1, hold.holdTime * (1 - hold.progress))
            fillUp.restart()
        }
        onReleased: {
            fillUp.stop()
            // let go before the pill was full: say how it works
            if (!done)
                hold.tapped()
            fillBack.restart()
        }
        onCanceled: {
            fillUp.stop()
            fillBack.restart()
        }
    }
}
