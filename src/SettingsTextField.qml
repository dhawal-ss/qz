import QtQuick 2.14
import QtQuick.Controls 2.15

// Text field of a free-text setting (a name, an e-mail, a password, a colour, a serial port).
// `savedText`: the row binds the saved setting here instead of `text`; the field shows it and
// shows it again whenever the setting changes (after OK too). `dirty` - the text is not the
// saved one, the OK button of the row is enabled by it: a grey OK means there is nothing to
// save. A field without `savedText` is never dirty. A word still being typed on a predictive
// keyboard (Android) is in preeditText, not yet in text: it counts as a change, or the OK stayed
// grey and could not take the tap that commits the word
TextField {
    id: field

    property var savedText: undefined
    readonly property bool dirty: savedText !== undefined
                                  && (text !== String(savedText) || preeditText !== "")

    onSavedTextChanged: if (savedText !== undefined) text = savedText
    Component.onCompleted: if (savedText !== undefined) text = savedText

    // Leaving the field saves an edited text, as OK does (see SettingsNumberField)
    // Return/Enter emits editingFinished before accepted (Qt 5.15): the row's Enter handler saves
    // that value, without a toast as before, so the handler below leaves it alone
    property bool returnPressed: false
    Keys.onPressed: if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) returnPressed = true
    onEditingFinished: {
        if (returnPressed) {
            returnPressed = false
            return
        }
        if (!dirty)
            return
        field.accepted()
        if (!dirty)
            toast.show(qsTranslate("settings", "Setting saved!"))
    }
}
