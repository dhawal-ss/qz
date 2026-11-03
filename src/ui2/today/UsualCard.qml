import QtQuick 2.15
import ".."
import "../sig"
import "../learn"
import "Patterns.js" as Patterns

// This week against your usual week by the same day (Patterns.usual): a coach line and a bar
// each for time, rides and training load, with a line where the usual is. The whole section is
// the button to its Learn sheet. For a rider with no rides yet a sample in graphite.
LearnTap {
    id: usualCard

    property var usual: Patterns.usualSample()
    property bool sample: false
    property color tint: Theme.accent

    function grow() {
        compare.grow()
    }

    name: sample ? qsTr("This week vs your usual, a sample of what shows after your first ride")
                 : qsTr("This week vs your usual. %1 %2").arg(Patterns.usualWords(usual)).arg(compare.Accessible.name)

    Column {
        width: parent.width
        spacing: 12
        VisualHead {
            width: parent.width
            title: qsTr("This week vs your usual")
            sample: usualCard.sample
        }
        Text {
            width: parent.width
            text: Patterns.usualWords(usualCard.usual)
            color: usualCard.sample ? Theme.text2 : Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: 17
            wrapMode: Text.WordWrap
        }
        CompareBars {
            id: compare
            width: parent.width
            rows: Patterns.usualRows(usualCard.usual)
            tint: usualCard.tint
            sample: usualCard.sample
            Accessible.ignored: true
        }
    }
}
