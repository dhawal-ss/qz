import QtQuick 2.15
import QtQuick.Controls 2.15
import "."
import "sig"
import "Metrics.js" as Metrics

// The side sheet that swaps, restyles or removes one metric while the ride keeps recording.
// It slides in on the default spatial spring; a picked metric lights up for a moment before the
// sheet slides away and the metric rolls into its row.
Item {
    id: sheet

    property var source
    property var slots: []
    property int slot: -1
    readonly property bool open: slot >= 0
    // the slot the sheet shows: it keeps the last one while sliding away
    property int shownSlot: -1
    onSlotChanged: if (slot >= 0) shownSlot = slot
    readonly property var current: shownSlot >= 0 && shownSlot < slots.length ? slots[shownSlot] : null
    readonly property bool currentEmpty: current !== null && current.m === "empty"

    signal pickStyle(string style)
    signal pickMetric(string metricId)
    signal removeSlot()
    signal close()

    // the metric just picked, lit while the sheet hands it over
    property string picking: ""
    onOpenChanged: picking = ""

    function pick(id) {
        if (!open || picking !== "")
            return
        if (Theme.reduceMotion) {
            pickMetric(id)
            return
        }
        picking = id
        pickTimer.restart()
    }

    Timer {
        id: pickTimer
        interval: 160
        onTriggered: {
            var id = sheet.picking
            sheet.picking = ""
            if (id !== "")
                sheet.pickMetric(id)
        }
    }

    visible: open || panel.x < width
    Accessible.ignored: !open

    function slotOf(id) {
        for (var k = 0; k < slots.length; k++) {
            if (k !== shownSlot && slots[k].m === id)
                return k
        }
        return -1
    }

    // dims the ride behind the sheet, a tap there closes it
    PulseButton {
        anchors.fill: parent
        radius: 0
        pressedScale: 1
        fill: Qt.rgba(5 / 255, 5 / 255, 6 / 255, sheet.open ? 0.55 : 0)
        Accessible.name: qsTr("Close")
        onClicked: sheet.close()
    }

    // the sheet floats over the ride
    Shadow {
        x: panel.x
        width: panel.width
        height: panel.height
        radius: 32
        offset: 0
        visible: panel.x < sheet.width
    }

    Rectangle {
        id: panel
        width: Math.min(384, sheet.width)
        height: parent.height
        x: sheet.open ? sheet.width - width : sheet.width
        color: Theme.control
        radius: 32

        Behavior on x {
            enabled: !Theme.reduceMotion
            Spring { token: "default" }
        }

        // square the right edge, the sheet runs off the screen there
        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 32
            color: Theme.control
        }

        // swallow taps on the panel itself
        MouseArea { anchors.fill: parent }

        Column {
            id: head
            x: 20
            y: 20
            width: panel.width - 40
            spacing: 14

            Item {
                width: parent.width
                height: Math.max(titleBlock.height, done.height)
                Column {
                    id: titleBlock
                    width: parent.width - done.width - 12
                    spacing: 6
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: sheet.current === null ? "" : (sheet.shownSlot === 0 ? qsTr("Main number")
                              : (sheet.currentEmpty ? qsTr("Add a metric") : Metrics.info(sheet.current.m, sheet.source).label))
                        color: Theme.text
                        font.family: Theme.display
                        font.pixelSize: 24
                    }
                    Text {
                        text: qsTr("The ride keeps recording.")
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                    }
                }
                PulseButton {
                    id: done
                    anchors.right: parent.right
                    width: doneLabel.implicitWidth + 32
                    height: 40
                    fill: Theme.accent
                    Accessible.name: qsTr("Done")
                    onClicked: sheet.close()
                    contentItem: Text {
                        id: doneLabel
                        text: qsTr("Done")
                        color: Theme.accentInk
                        font.family: Theme.bodySemibold
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // connected button group: number, trend, bar
            Row {
                visible: sheet.current !== null && sheet.shownSlot > 0 && !sheet.currentEmpty
                width: parent.width
                spacing: 3
                Repeater {
                    model: [["number", qsTr("Number")], ["trend", qsTr("Trend")], ["bar", qsTr("Bar")]]
                    delegate: PulseButton {
                        readonly property bool on: sheet.current !== null && sheet.current.st === modelData[0]
                        width: (parent.width - 6) / 3
                        height: 46
                        radius: on ? 23 : 10
                        fill: on ? Theme.accent : Theme.pressed
                        Accessible.name: qsTr("Show as %1").arg(modelData[1])
                        Accessible.checked: on
                        onClicked: if (sheet.open) sheet.pickStyle(modelData[0])
                        contentItem: Text {
                            text: modelData[1]
                            color: parent.on ? Theme.accentInk : Theme.text
                            font.family: Theme.bodySemibold
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Text {
                text: sheet.shownSlot === 0 ? qsTr("Show instead") : (sheet.currentEmpty ? qsTr("Choose a metric") : qsTr("Swap for"))
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.labelSize
            }
        }

        ListView {
            id: options
            x: 14
            width: panel.width - 28
            anchors { top: head.bottom; topMargin: 4; bottom: removeButton.visible ? removeButton.top : parent.bottom; bottomMargin: 12 }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: sheet.current !== null ? Metrics.order.filter(function (id) { return id !== sheet.current.m }) : []
            Accessible.name: qsTr("Metrics")
            delegate: PulseButton {
                readonly property var info: Metrics.info(modelData, sheet.source)
                readonly property int where: sheet.slotOf(modelData)
                width: options.width
                height: 54
                radius: 18
                pressedScale: 0.98
                fill: sheet.picking === modelData ? Qt.rgba(42 / 255, 36 / 255, 64 / 255, 1) : (pressed ? Theme.pressed : "transparent")
                Accessible.name: (sheet.currentEmpty ? qsTr("Add %1") : qsTr("Show %1")).arg(info.label)
                onClicked: sheet.pick(modelData)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 6; rightMargin: 6 }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
                Column {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: info.label
                        color: Theme.text
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.bodySize
                    }
                    Text {
                        text: where >= 0 ? qsTr("On screen, they swap places") : (info.unit + (info.tag !== "" ? " " + info.tag : ""))
                        color: Theme.text3
                        font.family: Theme.bodyMedium
                        font.pixelSize: Theme.tertiarySize
                    }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: info.value
                    color: Theme.text
                    font.family: Theme.display
                    font.pixelSize: 24
                }
            }
        }

        PulseButton {
            id: removeButton
            visible: sheet.current !== null && sheet.shownSlot > 0 && !sheet.currentEmpty
            x: 20
            width: panel.width - 40
            height: 46
            anchors { bottom: parent.bottom; bottomMargin: 16 }
            fill: Theme.pressed
            Accessible.name: qsTr("Remove, keep the space")
            onClicked: if (sheet.open) sheet.removeSlot()
            contentItem: Text {
                text: qsTr("Remove, keep the space")
                color: Theme.danger
                font.family: Theme.bodySemibold
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
