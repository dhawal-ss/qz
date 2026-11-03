import QtQuick 2.15
import ".."
import "../sig"

// What is new about the rider today, as quiet rows: what it is on the left, its number in the
// color of its zone on the right. The top three show, the rest behind More.
Column {
    id: insightsCard

    property var insights: []
    property bool expanded: false

    signal act(var action)

    readonly property int shownCount: expanded ? insights.length : Math.min(3, insights.length)

    spacing: 4

    CapLabel {
        text: qsTr("For you today")
    }
    Repeater {
        model: insightsCard.insights.slice(0, insightsCard.shownCount)
        HairlineRow {
            width: insightsCard.width
            interactive: true
            label: modelData.title || ""
            sub: modelData.detail || ""
            value: modelData.value || ""
            unit: modelData.unit || ""
            valueColor: Theme.zoneColors[Math.max(1, Math.min(7, modelData.tone || 1)) - 1]
            line: index < insightsCard.shownCount - 1 || insightsCard.insights.length > 3
            onClicked: insightsCard.act(modelData.action)
        }
    }
    PulseButton {
        visible: insightsCard.insights.length > 3
        height: 44
        width: moreLabel.implicitWidth + 24
        x: -12
        fill: pressed ? Theme.pressed : "transparent"
        Accessible.name: moreLabel.text
        onClicked: insightsCard.expanded = !insightsCard.expanded
        contentItem: Text {
            id: moreLabel
            text: insightsCard.expanded ? qsTr("Show less")
                  : (insightsCard.insights.length - 3 === 1 ? qsTr("1 more") : qsTr("%1 more").arg(insightsCard.insights.length - 3))
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
