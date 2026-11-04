import QtQuick 2.15
import QtQuick.Controls 2.15
import ".."

// A typed setting: name and detail on the left, the box on the right with its unit.
// A valid value is kept when typing pauses, on Enter or when the box loses focus;
// an invalid one goes back to the saved value.
Item {
    id: field

    property string title: ""
    property string detail: ""
    property string unit: ""
    // the saved value, as text
    property string value: ""
    // "text", "int" or "number"
    property string kind: "int"
    property real minimum: 0
    property real maximum: 1000
    property bool hairline: true

    signal committed(string text)

    readonly property bool valid: check(input.text)
    // a half typed number is not an error until typing pauses
    property bool showInvalid: false

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(68, texts.implicitHeight + 24)

    function cleaned(text) {
        // a comma is the decimal mark in many languages
        return text.trim().split(",").join(".")
    }

    function check(text) {
        if (kind === "text")
            return true
        var t = cleaned(text)
        if (t === "")
            return false
        var n = Number(t)
        if (isNaN(n) || n < minimum || n > maximum)
            return false
        return kind !== "int" || Math.round(n) === n
    }

    function commit() {
        var t = kind === "text" ? input.text.trim() : cleaned(input.text)
        if (!check(input.text)) {
            if (!input.activeFocus) {
                input.text = value
                showInvalid = false
            }
            return
        }
        if (t !== value)
            committed(t)
    }

    onValueChanged: if (!input.activeFocus) input.text = value
    Component.onCompleted: input.text = value

    Column {
        id: texts
        x: 12
        width: Math.max(0, box.x - x - 16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Text {
            width: parent.width
            text: field.title
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.bodySize + 1
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: field.showInvalid ? qsTr("Between %1 and %2").arg(field.minimum).arg(field.maximum) : field.detail
            color: field.showInvalid ? Theme.danger : Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        id: box
        x: field.width - width - 12
        width: field.kind === "text" ? Math.min(240, Math.max(140, field.width * 0.45)) : 132
        height: 48
        radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.control
        border.width: input.activeFocus || field.showInvalid ? 2 : 1
        border.color: field.showInvalid ? Theme.danger : (input.activeFocus ? Theme.accent : Theme.hairline)

        TextField {
            id: input
            anchors { left: parent.left; right: unitLabel.left; top: parent.top; bottom: parent.bottom; leftMargin: 14; rightMargin: unitLabel.text !== "" ? 6 : 14 }
            padding: 0
            topPadding: 0
            bottomPadding: 0
            leftPadding: 0
            rightPadding: 0
            background: null
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: field.kind === "text" ? TextInput.AlignLeft : TextInput.AlignRight
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentInk
            selectByMouse: true
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(17)
            maximumLength: field.kind === "text" ? 40 : 7
            inputMethodHints: field.kind === "int" ? Qt.ImhDigitsOnly
                              : (field.kind === "number" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNoPredictiveText)
            Accessible.name: field.title + ": " + text + (field.unit !== "" ? " " + field.unit : "")
            onTextEdited: {
                field.showInvalid = false
                pause.restart()
            }
            onEditingFinished: {
                pause.stop()
                field.showInvalid = !field.valid
                field.commit()
            }
        }

        Text {
            id: unitLabel
            anchors { right: parent.right; rightMargin: text !== "" ? 14 : 0; verticalCenter: parent.verticalCenter }
            text: field.unit
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.labelSize
        }
    }

    Timer {
        id: pause
        interval: 900
        onTriggered: {
            field.showInvalid = !field.valid
            field.commit()
        }
    }

    Rectangle {
        visible: field.hairline
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
        height: 1
        color: Theme.hairline
    }
}
