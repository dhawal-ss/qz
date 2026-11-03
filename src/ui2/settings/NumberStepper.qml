import QtQuick 2.15
import QtQuick.Controls 2.15
import ".."
import "../sig"
import "../Format.js" as Format

// A number the rider sets: a round minus on the left, a round plus on the right (hold either to
// keep stepping), and the number between them, which opens a numeric field when tapped so any
// value in the range can be typed. The steps land on the step grid (45 goes up to 50); a typed
// value is kept as typed, inside the range. With showValue false the middle only takes the tap
// and the field, for a number drawn by something else under it (the ring of the goal setup).
Item {
    id: stepper

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string unit: ""         // the words under the number
    property string zeroText: ""     // shown instead of 0, e.g. "Off"
    property string name: ""         // what the number is, for the screen reader
    property bool showValue: true
    property int numberSize: 34
    property int buttonSize: 52
    property color tint: Theme.accent
    readonly property bool editing: field.visible

    signal edited(real value)

    implicitWidth: 240
    implicitHeight: Math.max(buttonSize, face.implicitHeight)

    function clamp(v) {
        return Math.max(from, Math.min(to, v))
    }
    function stepBy(direction) {
        var grid = direction > 0 ? Math.floor(value / step + 1e-9) * step + step
                                 : Math.ceil(value / step - 1e-9) * step - step
        var next = clamp(Math.round(grid * 100) / 100)
        if (next !== value)
            edited(next)
    }
    function startTyping() {
        field.text = String(Math.round(value))
        field.visible = true
        field.forceActiveFocus()
        field.selectAll()
        Qt.inputMethod.show()
    }
    function finishTyping() {
        if (!field.visible)
            return
        var t = field.text.trim().split(",").join(".")
        field.visible = false
        Qt.inputMethod.hide()
        var n = Number(t)
        if (t === "" || isNaN(n))
            return
        var next = clamp(Math.round(n))
        if (next !== value)
            edited(next)
    }
    readonly property string valueText: value === 0 && zeroText !== "" ? zeroText : Format.big(value)

    // the two round buttons
    Repeater {
        model: [-1, 1]
        PulseButton {
            id: stepButton
            readonly property bool more: modelData > 0
            readonly property bool atEnd: more ? stepper.value >= stepper.to : stepper.value <= stepper.from
            x: more ? stepper.width - width : 0
            y: (stepper.height - height) / 2
            width: stepper.buttonSize
            height: stepper.buttonSize
            pressedRadius: stepper.buttonSize * 0.3
            pressedScale: 0.92
            autoRepeat: true
            autoRepeatDelay: 420
            autoRepeatInterval: 90
            enabled: !atEnd
            opacity: atEnd ? 0.35 : 1
            fill: pressed ? Theme.chip : Theme.pressed
            Accessible.name: (more ? qsTr("More") : qsTr("Less")) + (stepper.name !== "" ? ", " + stepper.name : "")
            onClicked: {
                stepper.finishTyping()
                stepper.stepBy(modelData)
            }
            Behavior on opacity {
                enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.effectsTime; easing.type: Easing.Bezier; easing.bezierCurve: Theme.effectsCurve }
            }
            contentItem: Item {
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(stepper.buttonSize * 0.36)
                    height: 2.4
                    radius: 1.2
                    color: Theme.text
                }
                Rectangle {
                    visible: stepButton.more
                    anchors.centerIn: parent
                    width: 2.4
                    height: Math.round(stepper.buttonSize * 0.36)
                    radius: 1.2
                    color: Theme.text
                }
            }
        }
    }

    // the number, a tap opens the field
    PulseButton {
        id: face
        x: stepper.buttonSize + 4
        width: stepper.width - 2 * (stepper.buttonSize + 4)
        height: stepper.height
        implicitHeight: faceColumn.implicitHeight + 8
        pressedScale: 0.97
        fill: "transparent"
        Accessible.name: (stepper.name !== "" ? stepper.name + ", " : "") + stepper.valueText
                         + (stepper.unit !== "" ? " " + stepper.unit : "") + ", " + qsTr("tap to type a number")
        onClicked: stepper.startTyping()
        contentItem: Item {
            Column {
                id: faceColumn
                anchors.centerIn: parent
                spacing: 4
                visible: stepper.showValue && !stepper.editing
                RollingNumber {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !(stepper.value === 0 && stepper.zeroText !== "")
                    value: Format.big(stepper.value)
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: stepper.numberSize
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: stepper.value === 0 && stepper.zeroText !== ""
                    text: stepper.zeroText
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: Math.round(stepper.numberSize * 0.8)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                    text: stepper.value === 0 && stepper.zeroText !== "" ? "" : stepper.unit
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Math.max(11, Math.round(stepper.numberSize * 0.36))
                }
            }
        }
    }

    // the field, over the number while typing
    TextField {
        id: field
        visible: false
        anchors.centerIn: face
        width: Math.min(face.width, Math.max(96, stepper.numberSize * 3.2))
        height: Math.max(44, stepper.numberSize + 16)
        padding: 0
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: stepper.tint
        selectedTextColor: Theme.accentInk
        selectByMouse: true
        font.family: Theme.display
        font.pixelSize: stepper.numberSize
        maximumLength: 6
        inputMethodHints: Qt.ImhDigitsOnly
        Accessible.name: (stepper.name !== "" ? stepper.name : qsTr("Number")) + (stepper.unit !== "" ? ", " + stepper.unit : "")
        background: Rectangle {
            radius: height / 2
            color: Theme.control
            border.width: 2
            border.color: stepper.tint
        }
        onAccepted: stepper.finishTyping()
        onEditingFinished: stepper.finishTyping()
        onActiveFocusChanged: if (!activeFocus) stepper.finishTyping()
        Keys.onEscapePressed: {
            field.text = ""
            stepper.finishTyping()
        }
    }
}
