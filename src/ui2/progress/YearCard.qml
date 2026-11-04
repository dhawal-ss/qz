import QtQuick 2.15
import ".."
import "../sig"
import "../learn"
import "../Format.js" as Format
import "Progress.js" as Progress

// Your year in one picture: riding time in each of the last 12 months as a bar, this month last,
// the biggest month lit in the accent with its hours over it, and a sentence that names it. The
// bars grow in when the section shows. The whole section is the button to its Learn sheet.
LearnTap {
    id: year
    objectName: "yearCard"

    property var library: null

    // [{ start, seconds, rides }] oldest first, this month last
    property var months: []
    // 0 to 1: how far the bars have grown
    property real grown: 1

    readonly property int best: {
        var pick = -1
        for (var i = 0; i < months.length; i++)
            if (months[i].seconds > 0 && (pick < 0 || months[i].seconds > months[pick].seconds))
                pick = i
        return pick
    }
    readonly property real total: {
        var sum = 0
        for (var i = 0; i < months.length; i++)
            sum += months[i].seconds
        return sum
    }
    readonly property real scaleMax: best >= 0 ? months[best].seconds * 1.08 : 1
    readonly property string bestName: best >= 0 ? Format.monthNames[new Date(months[best].start).getMonth()] : ""

    function refresh() {
        var t = new Date()
        var list = []
        for (var m = 11; m >= 0; m--)
            list.push({ start: new Date(t.getFullYear(), t.getMonth() - m, 1, 12).getTime(), seconds: 0, rides: 0 })
        if (library) {
            var days = library.days(new Date(t.getFullYear(), t.getMonth() - 11, 1).getTime(), 0)
            for (var d = 0; d < days.length; d++) {
                // days are local midnight: read them at noon, so a DST change never moves a day
                var day = Progress.noon(days[d].day + 12 * 3600000)
                var slot = (day.getFullYear() - t.getFullYear()) * 12 + day.getMonth() - t.getMonth() + 11
                if (slot < 0 || slot > 11)
                    continue
                list[slot].seconds += days[d].seconds
                list[slot].rides += days[d].rides
            }
        }
        months = list
    }

    function play() {
        if (Theme.reduceMotion) {
            growth.stop()
            grown = 1
            return
        }
        growth.restart()
    }

    // what the Learn sheet says about this year
    function learnFacts() {
        return { rides: total > 0 ? 1 : 0, bestMonth: bestName, bestSeconds: best >= 0 ? months[best].seconds : 0, totalSeconds: total }
    }

    name: best >= 0 ? qsTr("Your year in one picture: %1 was your biggest month, %2. %3 in 12 months")
                      .arg(bestName).arg(Format.hours(months[best].seconds)).arg(Format.hours(total))
                    : qsTr("Your year in one picture, no rides in the last 12 months")

    SequentialAnimation {
        id: growth
        PropertyAction { target: year; property: "grown"; value: 0 }
        PauseAnimation { duration: 120 }
        NumberAnimation {
            target: year
            property: "grown"
            to: 1
            duration: Theme.slowSpatialTime + 250
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.slowSpatialCurve
        }
    }

    Column {
        width: parent.width
        spacing: 12

        SectionHead {
            width: parent.width
            title: qsTr("Your year in one picture")
            note: qsTr("12 months")
        }
        Text {
            width: parent.width
            text: year.best >= 0 ? qsTr("%1 was your biggest month.").arg(year.bestName) : qsTr("Ride a little most weeks and the year fills in.")
            color: Theme.text
            font.family: Theme.bodySemibold
            font.pixelSize: Theme.fs(17)
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: year.best >= 0
            text: qsTr("%1 across the year, %2 in %3.").arg(Format.hours(year.total)).arg(year.best >= 0 ? Format.hours(year.months[year.best].seconds) : "").arg(year.bestName)
            color: Theme.text2
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.fs(13)
            wrapMode: Text.WordWrap
        }
        Item {
            width: parent.width
            height: 150
            Accessible.ignored: true
            Repeater {
                model: year.months
                Item {
                    id: monthColumn
                    readonly property bool lit: index === year.best
                    readonly property real plotTop: 22
                    readonly property real plotHeight: 100
                    x: index * parent.width / 12
                    width: parent.width / 12
                    height: parent.height
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(6, Math.min(26, parent.width * 0.62))
                        height: modelData.seconds > 0 ? Math.max(width / 2, monthColumn.plotHeight * modelData.seconds / year.scaleMax * year.grown) : 4
                        y: monthColumn.plotTop + monthColumn.plotHeight - height
                        radius: Math.min(7, width / 2)
                        color: monthColumn.lit ? Theme.accent : (modelData.seconds > 0 ? Qt.rgba(1, 1, 1, 0.16) : Theme.rest)
                    }
                    // the hours of the biggest month, over its bar
                    Text {
                        visible: monthColumn.lit
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: monthColumn.plotTop + monthColumn.plotHeight * (1 - modelData.seconds / year.scaleMax * year.grown) - height - 4
                        text: Math.round(modelData.seconds / 3600) + " h"
                        color: Theme.accent
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.fs(12)
                        opacity: Math.max(0, Math.min(1, year.grown))
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: monthColumn.plotTop + monthColumn.plotHeight + 9
                        text: Format.monthShort[new Date(modelData.start).getMonth()].charAt(0)
                        color: monthColumn.lit ? Theme.accent : (index === 11 ? Theme.text : Theme.text3)
                        font.family: monthColumn.lit || index === 11 ? Theme.bodySemibold : Theme.bodyMedium
                        font.pixelSize: Theme.fs(12)
                    }
                }
            }
        }
    }
}
