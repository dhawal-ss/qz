import QtQuick 2.12
import QtQuick.Controls 2.5

// A button of the ride bar and of the connection card: 48 px tall, a pill, sized to its label
// (no "PAU..." truncation), mixed case, no shadow
Button {
    id: control
    property color fillColor: window.theme.surfaceRaised
    property color labelColor: window.theme.textPrimary
    property real minimumWidth: 0

    height: 48
    topInset: 0
    bottomInset: 0
    leftPadding: 20
    rightPadding: 20
    font.pixelSize: window.fontPx(16)
    font.capitalization: Font.MixedCase
    font.bold: true

    contentItem: Label {
        text: control.text
        font: control.font
        color: control.labelColor
        opacity: control.enabled ? 1 : 0.4
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        implicitWidth: control.minimumWidth
        implicitHeight: 48
        radius: 24
        // pressed: lighter, or the pressed surface for a flat (transparent) button
        color: !control.down ? control.fillColor
                             : control.fillColor.a === 0 ? window.theme.surfacePressed : Qt.lighter(control.fillColor, 1.3)
        opacity: control.enabled ? 1 : 0.5
    }

    // VoiceOver/TalkBack: the screen-reader name and description are set by each use
    Accessible.role: Accessible.Button
    Accessible.focusable: true
}
