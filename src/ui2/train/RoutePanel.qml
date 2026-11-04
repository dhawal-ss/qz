import QtQuick 2.15
import ".."
import "../Format.js" as Format
import "Route.js" as Route

// The route under way, on the ride screen: the elevation profile with where the rider is, the
// distance done and to go, the gradient now, the next climb, and what this gradient takes at the
// speed now (watts, and on an Echelon the level). Bikemodo never sets the resistance.
Rectangle {
    id: panel

    property var route: null
    property real km: 0
    property real speed: 0           // km/h now
    property real weight: 75
    property bool miles: false
    property int level: 0
    property int levelTarget: -1
    property string ghostText: ""

    readonly property real total: route ? Route.total(route) : 0
    readonly property var pos: route ? Route.at(route, km) : null
    readonly property var climb: route ? Route.nextClimb(route, km) : null
    readonly property int need: pos && !pos.done ? Route.watts(pos.grade, Math.max(speed, 12), weight) : 0

    implicitHeight: content.height + 28
    radius: 22
    color: Theme.control
    Accessible.role: Accessible.StaticText
    Accessible.name: route ? route.name + ", " + distanceLine.text + ", " + gradeLine.text : ""

    onKmChanged: profile.requestPaint()
    onRouteChanged: profile.requestPaint()

    Column {
        id: content
        x: 16
        y: 14
        width: panel.width - 32
        spacing: 8

        Item {
            width: parent.width
            height: distanceLine.height
            Text {
                id: nameLine
                width: parent.width - distanceLine.width - 12
                anchors.verticalCenter: parent.verticalCenter
                text: panel.route ? panel.route.name : ""
                color: Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(15)
                elide: Text.ElideRight
            }
            Text {
                id: distanceLine
                anchors.right: parent.right
                text: Format.distance(Math.min(panel.km, panel.total), panel.miles) + " / " + Format.distance(panel.total, panel.miles)
                color: Theme.text
                font.family: Theme.display
                font.pixelSize: Theme.fs(20)
            }
        }

        // the profile, with where the rider is
        Canvas {
            id: profile
            width: parent.width
            height: 56
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                if (!panel.route || panel.route.points.length < 2)
                    return
                var p = panel.route.points
                var lo = p[0][1], hi = p[0][1]
                for (var i = 1; i < p.length; i++) {
                    lo = Math.min(lo, p[i][1])
                    hi = Math.max(hi, p[i][1])
                }
                var range = Math.max(30, hi - lo)
                var w = width, h = height
                function x(km) { return km / panel.total * w }
                function y(e) { return h - 4 - (e - lo) / range * (h - 8) }
                ctx.beginPath()
                ctx.moveTo(0, h)
                for (var k = 0; k < p.length; k++)
                    ctx.lineTo(x(p[k][0]), y(p[k][1]))
                ctx.lineTo(w, h)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(Theme.text3.r, Theme.text3.g, Theme.text3.b, 0.35)
                ctx.fill()
                // the part ridden
                var done = Math.min(panel.km, panel.total)
                ctx.save()
                ctx.beginPath()
                ctx.rect(0, 0, x(done), h)
                ctx.clip()
                ctx.beginPath()
                ctx.moveTo(0, h)
                for (var m = 0; m < p.length; m++)
                    ctx.lineTo(x(p[m][0]), y(p[m][1]))
                ctx.lineTo(w, h)
                ctx.closePath()
                ctx.fillStyle = Theme.accent
                ctx.fill()
                ctx.restore()
                // now
                ctx.fillStyle = Theme.text
                ctx.fillRect(x(done) - 1.5, 0, 3, h)
            }
        }

        Item {
            width: parent.width
            height: Math.max(gradeLine.height, adviceLine.height)
            Text {
                id: gradeLine
                width: parent.width * 0.5
                text: !panel.pos ? "" : panel.pos.done ? qsTr("Route done") : qsTr("%1% now").arg(panel.pos.grade.toFixed(1))
                color: panel.pos && panel.pos.grade >= 3 ? Theme.zoneColors[4] : Theme.text
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(17)
            }
            Text {
                id: adviceLine
                anchors.right: parent.right
                width: parent.width * 0.5 - 8
                horizontalAlignment: Text.AlignRight
                text: !panel.pos || panel.pos.done ? ""
                      : panel.levelTarget > 0 && panel.level > 0
                        ? (panel.levelTarget > panel.level ? qsTr("Level %1, turn up %2").arg(panel.levelTarget).arg(panel.levelTarget - panel.level)
                           : panel.levelTarget < panel.level ? qsTr("Level %1, ease off %2").arg(panel.levelTarget).arg(panel.level - panel.levelTarget)
                           : qsTr("Level %1, hold it").arg(panel.levelTarget))
                        : qsTr("About %1 W to hold your speed").arg(panel.need)
                color: Theme.text2
                font.family: Theme.bodySemibold
                font.pixelSize: Theme.fs(14)
                wrapMode: Text.WordWrap
            }
        }

        Text {
            width: parent.width
            text: panel.climb ? qsTr("Climb in %1: %2% for %3").arg(Format.distance(panel.climb.inKm, panel.miles))
                                .arg(panel.climb.grade.toFixed(1)).arg(Format.distance(panel.climb.lengthKm, panel.miles))
                              : qsTr("No more climbs")
            color: Theme.text3
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(13)
            elide: Text.ElideRight
        }

        Text {
            visible: panel.ghostText !== ""
            width: parent.width
            text: panel.ghostText
            color: Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(13)
        }
    }
}
