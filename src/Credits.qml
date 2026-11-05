import QtQuick 2.7
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.0

ScrollView {
    contentWidth: -1
    focus: true
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.fill: parent

    Label {
        id: lblHelp
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        anchors.top: row1.bottom
        anchors.topMargin: 30
        text: "<b>" + qsTr("Credits") + "</b><br><br>" + qsTr("A very big thanks to<br>all the developers<br>(alphabetical sorted):") + "<br><br>ben75020<br>d3m3vilurr<br>lifof<br>p3g4asus<br>Roberto Viola"
              + "<br><br><i>" + qsTr("QZ specifically disclaims liability for incidental or consequential damages and assumes no responsibility or liability for any loss or damage suffered by any person as a result of the use or misuse of the app.") + "</i>"
        wrapMode: Label.WordWrap
    }
}

