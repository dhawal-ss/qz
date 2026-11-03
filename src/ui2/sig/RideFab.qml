import QtQuick 2.15
import QtQuick.Controls 2.15
import ".."

// The Ride button beside the navigation: a round button in the accent with the Bikemodo mark.
// Pressed, its corners pull in towards a rounded square and it dips a little, on the fast spring.
// While a ride is paused and left (paused), a small dot on its edge breathes: the button resumes it.
AbstractButton {
    id: fab

    property int size: 64
    property bool paused: false

    implicitWidth: size
    implicitHeight: size
    padding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: paused ? qsTr("Resume your paused ride") : qsTr("Ride")
    Accessible.description: paused ? qsTr("Go back to the ride you paused") : qsTr("Start a ride")
    Accessible.onPressAction: fab.clicked()

    scale: pressed ? 0.94 : 1
    Behavior on scale {
        enabled: !Theme.reduceMotion
        Spring { token: "fast"; epsilon: 0.002 }
    }

    Shadow {
        z: -2
        anchors.fill: parent
        radius: face.radius
    }

    background: Rectangle {
        id: face
        radius: fab.pressed ? Math.round(fab.height * 0.3) : fab.height / 2
        color: fab.pressed ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
        border.width: fab.visualFocus ? 3 : 0
        border.color: Theme.text
        Behavior on radius {
            enabled: !Theme.reduceMotion
            Spring { token: "fast" }
        }
    }

    contentItem: Item {
        BrandMark {
            anchors.centerIn: parent
            width: Math.round(fab.size * 0.6)
            height: width
            color: Theme.accentInk
        }
    }

    // the paused ride: a dot in the recording color on the top right edge, ringed in the
    // background so it reads on the accent; it breathes once every 2 s, and stays still with reduce motion
    Rectangle {
        id: pausedDot
        readonly property real at: fab.width / 2 + fab.width / 2 * 0.7071
        visible: fab.paused
        width: Math.round(fab.size * 0.28)
        height: width
        radius: width / 2
        x: at - width / 2
        y: fab.height - at - height / 2
        color: Theme.recording
        border.width: 3
        border.color: Theme.bg
        Accessible.ignored: true
        property real breath: 1
        opacity: Theme.reduceMotion ? 1 : breath
        SequentialAnimation on breath {
            running: fab.paused && !Theme.reduceMotion
            loops: Animation.Infinite
            NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 1000; easing.type: Easing.InOutSine }
        }
    }
}
