import QtQuick 2.15
import QtQuick.Shapes 1.15
import ".."
import "../Format.js" as Format

// The seven days of a week from its first day (Monday, or Sunday: Theme.weekStart): a day with
// riding is the Pulse of its main zone,
// a day without is a small dot, today without a ride yet is a dashed ring in the tint.
// The shapes stand still: only the hero turns.
Item {
    id: week

    // [{ zone: 0 for no ride, else 1 to 7, today: bool }], from the first day of the week
    property var days: []
    property var letters: Format.weekLetters(Theme.weekStart)
    property var dayNames: Format.weekDayNames(Theme.weekStart)
    property color tint: Theme.accent
    property real shapeSize: 28

    implicitHeight: shapeSize + 7 + 16
    Accessible.role: Accessible.Graphic
    Accessible.name: {
        var parts = []
        for (var i = 0; i < Math.min(7, days.length); i++) {
            var d = days[i]
            parts.push(d.zone > 0 ? qsTr("%1, %2").arg(dayNames[i]).arg(Theme.powerZoneNames[d.zone - 1])
                                  : qsTr("%1, no ride").arg(dayNames[i]))
        }
        return qsTr("This week: %1").arg(parts.join(", "))
    }

    Row {
        width: parent.width
        Repeater {
            model: 7
            Item {
                id: dayCell
                readonly property var info: index < week.days.length ? week.days[index] : ({ zone: 0, today: false })
                width: week.width / 7
                height: week.height
                Accessible.ignored: true

                Item {
                    width: week.shapeSize
                    height: week.shapeSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    // a day's zone comes from FTP (Coach.weekDays): one shape in the accent until it
                    // is set (Theme.ftpSet)
                    Pulse {
                        visible: dayCell.info.zone > 0
                        anchors.fill: parent
                        zone: Theme.ftpSet ? Math.max(1, dayCell.info.zone) : 1
                        color: Theme.ftpSet ? Theme.zoneColors[Math.max(1, dayCell.info.zone) - 1] : Theme.accent
                    }
                    // a day without a ride
                    Rectangle {
                        visible: dayCell.info.zone === 0 && !dayCell.info.today
                        width: Math.round(week.shapeSize * 0.22)
                        height: width
                        radius: width / 2
                        anchors.centerIn: parent
                        color: Theme.rest
                    }
                    // today, still to ride
                    Shape {
                        visible: dayCell.info.zone === 0 && dayCell.info.today
                        anchors.fill: parent
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: week.tint
                            strokeWidth: Math.max(1.6, week.shapeSize * 8 / 108)
                            fillColor: "transparent"
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [1.25, 1.1]
                            PathAngleArc {
                                centerX: week.shapeSize / 2
                                centerY: week.shapeSize / 2
                                radiusX: week.shapeSize * 34 / 108
                                radiusY: week.shapeSize * 34 / 108
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: week.shapeSize + 7
                    text: week.letters[index]
                    color: dayCell.info.today ? week.tint : Theme.text2
                    font.family: dayCell.info.today ? Theme.bodySemibold : Theme.bodyMedium
                    font.pixelSize: Theme.fs(13)
                }
            }
        }
    }
}
