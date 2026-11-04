import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../sig"
import "../Format.js" as Format
import "Journeys.js" as Journeys

// A journey: the distance ridden since it started, laid along a real route drawn as a line with
// its towns (no map, nothing from the network). Without a journey, or while changing it, the card
// lists them to pick from; a finished one is a badge and the card offers the next.
// A quiet section: a cap label, the route on the page, the journeys to pick as hairline rows.
Column {
    id: journeyCard

    property string journeyId: ""
    property real ridden: 0          // km since the journey started
    property var finished: []        // [{id, date}]
    property bool miles: false

    signal startJourney(string id)

    property bool choosing: false

    readonly property var journey: Journeys.byId(journeyId)
    readonly property var trip: journey ? Journeys.progress(journey, ridden) : null
    readonly property color tint: Theme.accent
    readonly property bool picking: !journey || choosing

    spacing: 12

    function km(v) {
        return miles ? Format.big(v * 0.621371) + " mi" : Format.big(v) + " km"
    }

    // the distance, and where it runs when the name does not say
    function rowDetail(j) {
        var length = km(Journeys.total(j))
        if (j.ring)
            return qsTr("About %1, round the equator from %2").arg(length).arg(Journeys.from(j))
        if (j.name.indexOf(Journeys.from(j)) >= 0)
            return qsTr("About %1").arg(length)
        return qsTr("About %1, %2 to %3").arg(length).arg(Journeys.from(j)).arg(Journeys.to(j))
    }

    function placeName(i) {
        return journey ? journey.points[i][0] : ""
    }

    Item {
        width: parent.width
        height: 24
        CapLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Journey")
        }
    }

    // ---- picking a journey
    Text {
        visible: journeyCard.picking
        width: parent.width
        text: journeyCard.journey ? qsTr("Pick a new journey. It starts from here.")
                                  : qsTr("Ride a real route, one ride at a time. Your distance from today on carries you along it.")
        color: Theme.text
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.bodySize
        wrapMode: Text.WordWrap
    }
    Column {
        visible: journeyCard.picking
        width: parent.width
        spacing: 0
        Repeater {
            model: Journeys.journeys
            PulseButton {
                id: pickRow
                readonly property bool riddenBefore: Journeys.isDone(journeyCard.finished, modelData.id)
                x: -12
                width: parent.width + 24
                height: Math.max(64, pickTexts.implicitHeight + 24)
                radius: 18
                pressedScale: 0.985
                fill: pressed ? Theme.pressed : "transparent"
                Accessible.name: qsTr("Start %1, about %2").arg(modelData.name).arg(journeyCard.km(Journeys.total(modelData)))
                                 + (riddenBefore ? qsTr(", ridden before") : "")
                onClicked: {
                    journeyCard.choosing = false
                    journeyCard.startJourney(modelData.id)
                }
                contentItem: Item {
                    Rectangle {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.zoneColors[modelData.tone - 1]
                    }
                    Column {
                        id: pickTexts
                        x: 36
                        width: parent.width - x - 44
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: Theme.bodySize
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            width: parent.width
                            text: journeyCard.rowDetail(modelData) + (pickRow.riddenBefore ? qsTr(". Ridden before") : "")
                            color: Theme.text3
                            font.family: Theme.bodyMedium
                            font.pixelSize: Theme.tertiarySize
                            wrapMode: Text.WordWrap
                        }
                    }
                    GoalGlyph {
                        visible: pickRow.riddenBefore
                        anchors.right: parent.right
                        anchors.rightMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        name: "check"
                        color: Theme.accent
                    }
                    Icon {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "forward"
                        size: 20
                        color: Theme.text3
                    }
                }
                Hairline {
                    x: 12
                    width: parent.width - 24
                    anchors.bottom: parent.bottom
                    visible: index < Journeys.journeys.length - 1
                }
            }
        }
    }

    // ---- on the way
    Text {
        visible: !journeyCard.picking
        width: parent.width
        text: journeyCard.journey ? journeyCard.journey.name : ""
        color: Theme.text
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.fs(21)
        font.letterSpacing: -0.2
        wrapMode: Text.WordWrap
    }

    Item {
        id: routeMap
        visible: !journeyCard.picking
        width: parent.width
        height: journeyCard.journey && journeyCard.journey.ring ? Math.min(220, width) : 210
        readonly property var points: journeyCard.journey ? Journeys.route(journeyCard.journey, width, height, 18) : []
        readonly property var riddenPoints: journeyCard.trip ? Journeys.ridden(points, journeyCard.trip.km) : []
        readonly property var here: Journeys.position(points, journeyCard.trip ? journeyCard.trip.km : 0)
        Accessible.role: Accessible.Graphic
        Accessible.name: journeyCard.journey && journeyCard.trip
                         ? qsTr("Route of %1, %2% ridden").arg(journeyCard.journey.name).arg(journeyCard.trip.percent) : ""

        function qtPoints(list) {
            return list.map(function (p) { return Qt.point(p.x, p.y) })
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeColor: Theme.dashed
                strokeWidth: 6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: routeMap.qtPoints(routeMap.points) }
            }
            ShapePath {
                strokeColor: journeyCard.tint
                strokeWidth: 6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: routeMap.qtPoints(routeMap.riddenPoints) }
            }
        }

        // the towns
        Repeater {
            model: journeyCard.journey ? journeyCard.journey.points : []
            Rectangle {
                readonly property var spot: Journeys.position(routeMap.points, modelData[1])
                readonly property bool behind: journeyCard.trip !== null && journeyCard.trip.km >= modelData[1]
                x: spot.x - width / 2
                y: spot.y - height / 2
                width: 10
                height: 10
                radius: 5
                color: behind ? journeyCard.tint : Theme.bg
                border.width: 2
                border.color: behind ? Theme.bg : Theme.dashed
            }
        }

        // where the rider is
        Rectangle {
            x: routeMap.here.x - width / 2
            y: routeMap.here.y - height / 2
            width: 20
            height: 20
            radius: 10
            color: Theme.text
            border.width: 4
            border.color: journeyCard.tint
        }

        // start and finish names, kept inside the box
        Repeater {
            model: journeyCard.journey && !journeyCard.journey.ring ? [0, journeyCard.journey.points.length - 1] : []
            Text {
                readonly property var spot: routeMap.points[modelData] || { x: 0, y: 0 }
                // beside the town, on the side with more room
                readonly property bool leftSide: spot.x > routeMap.width / 2
                x: Math.max(0, Math.min(routeMap.width - width, leftSide ? spot.x - width - 12 : spot.x + 12))
                y: Math.max(0, Math.min(routeMap.height - height, spot.y - height / 2))
                text: journeyCard.placeName(modelData)
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.fs(11)
            }
        }

        // the world gets its share in the middle of the ring
        Column {
            visible: journeyCard.journey !== null && journeyCard.journey.ring === true
            anchors.centerIn: parent
            spacing: 4
            Numeral {
                anchors.horizontalCenter: parent.horizontalCenter
                text: journeyCard.trip ? journeyCard.trip.percent + "%" : ""
                color: Theme.text
                font.pixelSize: 40
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("of the equator")
                color: Theme.text3
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.tertiarySize
            }
        }
    }

    Row {
        visible: !journeyCard.picking && journeyCard.journey !== null && !journeyCard.journey.ring
        spacing: 12
        Numeral {
            text: journeyCard.trip ? String(journeyCard.trip.percent) : ""
            color: Theme.text
            font.pixelSize: 40
        }
        Text {
            anchors.bottom: parent.bottom
            text: "%"
            Accessible.ignored: true
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.bodySize
        }
    }

    Text {
        visible: !journeyCard.picking
        width: parent.width
        text: {
            var s = journeyCard.trip
            if (!s)
                return ""
            if (s.done)
                return qsTr("You rode all the way to %1. The badge is yours.").arg(journeyCard.placeName(journeyCard.journey.points.length - 1))
            if (s.passed > 0)
                return qsTr("You passed %1").arg(journeyCard.placeName(s.passed))
            return qsTr("On your way from %1").arg(journeyCard.placeName(0))
        }
        color: Theme.text
        font.family: Theme.bodySemibold
        font.pixelSize: Theme.bodySize
        wrapMode: Text.WordWrap
    }
    Text {
        visible: !journeyCard.picking
        width: parent.width
        text: {
            var s = journeyCard.trip
            if (!s)
                return ""
            if (s.done)
                return qsTr("%1 ridden. Where next?").arg(journeyCard.km(s.km))
            return qsTr("Next: %1, %2 to go. %3 of %4 ridden.").arg(journeyCard.placeName(s.next)).arg(journeyCard.km(s.toNext))
                .arg(journeyCard.km(s.km)).arg(journeyCard.km(Journeys.total(journeyCard.journey)))
        }
        color: Theme.text2
        font.family: Theme.bodyMedium
        font.pixelSize: Theme.labelSize
        wrapMode: Text.WordWrap
    }

    PulseButton {
        visible: journeyCard.journey !== null
        id: changeButton
        readonly property bool finishedNow: journeyCard.trip !== null && journeyCard.trip.done
        x: finishedNow && !journeyCard.choosing ? 0 : -12
        width: changeLabel.implicitWidth + (finishedNow && !journeyCard.choosing ? 40 : 24)
        height: finishedNow && !journeyCard.choosing ? 48 : 44
        fill: finishedNow && !journeyCard.choosing ? Theme.accent : (pressed ? Theme.pressed : "transparent")
        Accessible.name: changeLabel.text
        onClicked: journeyCard.choosing = !journeyCard.choosing
        contentItem: Text {
            id: changeLabel
            text: journeyCard.choosing ? (changeButton.finishedNow ? qsTr("Not now") : qsTr("Keep riding %1").arg(journeyCard.journey ? journeyCard.journey.name : ""))
                  : (changeButton.finishedNow ? qsTr("Pick the next journey") : qsTr("Change journey"))
            color: changeButton.finishedNow && !journeyCard.choosing ? Theme.accentInk : Theme.accent
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(14)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
