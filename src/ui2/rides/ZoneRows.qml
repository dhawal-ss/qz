import QtQuick 2.15
import ".."

// Time in power zones: one bar of the whole ride split by zone, then a row per zone with its
// name, its watt range, its minutes and a short bar. The zone ridden most is set in its color,
// an empty zone stays quiet. The bars grow in from the left when the rows rise in.
Item {
    id: zones

    property var seconds: []          // 7 zones
    property real ftp: 0
    property real grow: 1             // 0 to 1, the bars

    readonly property real total: {
        var sum = 0
        for (var i = 0; i < seconds.length; i++)
            sum += seconds[i]
        return Math.max(1, sum)
    }
    readonly property int topZone: {
        var best = 0
        for (var i = 1; i < seconds.length; i++)
            if (seconds[i] > seconds[best])
                best = i
        return best
    }
    readonly property int used: {
        var n = 0
        for (var i = 0; i < seconds.length; i++)
            if (seconds[i] > 0)
                n++
        return Math.max(1, n)
    }
    readonly property int rowHeight: 30

    implicitHeight: 12 + 16 + 7 * rowHeight
    Accessible.role: Accessible.Graphic
    Accessible.name: {
        var parts = []
        for (var i = 0; i < seconds.length; i++)
            parts.push(qsTr("%1 %2 min").arg(Theme.powerZoneNames[i]).arg(Math.round(seconds[i] / 60)))
        return qsTr("Minutes by power zone: %1").arg(parts.join(", "))
    }

    function range(zone) {
        var text = Theme.powerZoneRange(zone, ftp)
        return text.charAt(0).toUpperCase() + text.substring(1)
    }

    // the whole ride, split by zone
    Row {
        id: split
        width: parent.width * zones.grow
        height: 12
        spacing: 3
        clip: true
        Repeater {
            model: zones.seconds
            Rectangle {
                visible: modelData > 0
                width: Math.max(4, (zones.width - 3 * (zones.used - 1)) * modelData / zones.total)
                height: 12
                radius: 4
                color: Theme.zoneColors[index]
            }
        }
    }

    Column {
        y: 12 + 16
        width: parent.width
        Repeater {
            model: zones.seconds.length
            Item {
                id: zoneRow
                readonly property real secs: zones.seconds[index] || 0
                readonly property bool lead: index === zones.topZone && secs > 0
                readonly property bool none: Math.round(secs / 60) === 0
                width: zones.width
                height: zones.rowHeight
                Accessible.ignored: true

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 4
                    color: zoneRow.none ? Theme.rest : Theme.zoneColors[index]
                }
                Text {
                    x: 24
                    width: Math.min(96, zones.width * 0.28)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.powerZoneNames[index]
                    color: zoneRow.lead ? Theme.zoneColors[index] : (zoneRow.none ? Theme.text3 : Theme.text)
                    font.family: Theme.bodySemibold
                    font.pixelSize: Theme.fs(14)
                    elide: Text.ElideRight
                }
                Text {
                    x: 24 + Math.min(96, zones.width * 0.28) + 10
                    width: zoneBar.x - x - 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: zones.ftp > 0
                    text: zones.range(index + 1)
                    color: Theme.text2
                    font.family: Theme.bodyMedium
                    font.pixelSize: Theme.fs(13)
                    elide: Text.ElideRight
                }
                // a short bar of its share, before the minutes
                Rectangle {
                    id: zoneBar
                    readonly property real room: Math.min(64, zones.width * 0.16)
                    x: minutes.x - 12 - room
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(zoneRow.none ? 0 : 3, room * zoneRow.secs / zones.total * zones.grow / Math.max(0.01, zones.seconds[zones.topZone] / zones.total))
                    height: 4
                    radius: 2
                    color: zoneRow.lead ? Theme.zoneColors[index] : Theme.overlay(0.16)
                }
                Text {
                    id: minutes
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 56
                    horizontalAlignment: Text.AlignRight
                    // seconds under a minute, so a short ride does not read 0 min in every zone
                    text: zoneRow.secs > 0 && zoneRow.secs < 60 ? qsTr("%1 s").arg(Math.round(zoneRow.secs))
                                                                 : qsTr("%1 min").arg(Math.round(zoneRow.secs / 60))
                    color: zoneRow.lead ? Theme.zoneColors[index] : (zoneRow.none ? Theme.text3 : Theme.text)
                    font.family: Theme.display
                    font.pixelSize: Theme.fs(15)
                }
            }
        }
    }
}
