import QtQuick 2.15
import Qt.labs.settings 1.0
import "."
import "progress"
import "progress/Progress.js" as Progress

// Trends and records as cards the rider can hide and reorder (Customize): the power curve,
// fitness and form, this period against the last, every record, and the volume per week, month
// or year. One column on phones, two on wider windows, the cards taking turns left and right.
Item {
    id: progressPage
    objectName: "progressScreen"

    property var library: null
    property bool miles: false
    property bool showYou: true
    property string initial: "B"

    signal openYou()
    signal openRide(int id)

    readonly property var cardIds: ["curve", "fitness", "compare", "records", "volume"]
    readonly property var cardTitles: ({
        curve: qsTr("Power curve"),
        fitness: qsTr("Fitness and form"),
        compare: qsTr("Compare periods"),
        records: qsTr("Records"),
        volume: qsTr("Volume")
    })
    property var cards: Progress.cardList("", cardIds)
    property string detailLevel: "simple"
    property real weight: 0          // kg, 0 when the rider has not set it
    property bool customizing: false

    readonly property bool hasRides: library !== null && library.rideCount > 0
    readonly property var shownIds: {
        var out = []
        for (var i = 0; i < cards.length; i++)
            if (cards[i].shown)
                out.push(cards[i].id)
        return out
    }

    // You changes these through its own Settings objects, and Qt.labs.settings does not tell the
    // others: read them again each time the screen shows
    function readSettings() {
        detailLevel = String(uiStore.value("detailLevel", "simple"))
        weight = Number(qzStore.value("weight", 0)) || 0
        // a new list rebuilds every card, so only when it changed
        var saved = Progress.cardList(String(uiStore.value("progressCards", "")), cardIds)
        if (Progress.cardJson(saved) !== Progress.cardJson(cards))
            cards = saved
    }

    function saveCards(list) {
        cards = list
        uiStore.setValue("progressCards", Progress.cardJson(list))
    }

    function moveCard(from, to) {
        if (to < 0 || to >= cards.length)
            return
        var list = cards.slice()
        var moved = list.splice(from, 1)[0]
        list.splice(to, 0, moved)
        saveCards(list)
    }

    function showCard(cardId, shown) {
        var list = []
        for (var i = 0; i < cards.length; i++)
            list.push({ id: cards[i].id, shown: cards[i].id === cardId ? shown : cards[i].shown })
        saveCards(list)
    }

    // the shown cards of one column
    function columnIds(column, columns) {
        var out = []
        for (var i = 0; i < shownIds.length; i++)
            if (i % columns === column)
                out.push(shownIds[i])
        return out
    }

    function componentFor(cardId) {
        if (cardId === "curve")
            return curveCard
        if (cardId === "fitness")
            return fitnessCard
        if (cardId === "compare")
            return compareCard
        if (cardId === "records")
            return recordsCard
        return volumeCard
    }

    function openCustomize() {
        customizing = true
    }

    // Android back closes the sheet first
    function goBack() {
        if (customizing) {
            customizing = false
            return true
        }
        return false
    }

    onVisibleChanged: if (visible) readSettings()
    Component.onCompleted: readSettings()

    Settings {
        id: uiStore
        category: "ui2"
    }
    Settings {
        id: qzStore
    }

    Component {
        id: curveCard
        PowerCurve {
            library: progressPage.library
            weight: progressPage.weight
            onOpenRide: progressPage.openRide(id)
        }
    }
    Component {
        id: fitnessCard
        FitnessChart {
            library: progressPage.library
            pro: progressPage.detailLevel === "pro"
        }
    }
    Component {
        id: compareCard
        PeriodCompare {
            library: progressPage.library
            miles: progressPage.miles
        }
    }
    Component {
        id: recordsCard
        RecordsBoard {
            library: progressPage.library
            miles: progressPage.miles
            weight: progressPage.weight
            onOpenRide: progressPage.openRide(id)
        }
    }
    Component {
        id: volumeCard
        VolumeCard {
            library: progressPage.library
            miles: progressPage.miles
        }
    }

    Flickable {
        id: flick
        objectName: "progressFlick"
        anchors.fill: parent
        contentHeight: content.height + 32
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            readonly property real margin: Theme.margin(progressPage.width)
            readonly property bool twoColumns: progressPage.width >= 680
            readonly property int columns: twoColumns ? 2 : 1
            readonly property real columnWidth: twoColumns ? (width - 16) / 2 : width
            x: margin
            width: Math.min(progressPage.width - margin * 2, 1120)
            spacing: 16

            Item {
                width: parent.width
                height: header.height
                PageHeader {
                    id: header
                    width: parent.width
                    title: qsTr("Progress")
                    showYou: progressPage.showYou
                    initial: progressPage.initial
                    onOpenYou: progressPage.openYou()
                }
                PulseButton {
                    id: customizeButton
                    visible: progressPage.hasRides
                    x: parent.width - width - (progressPage.showYou ? 56 : 0)
                    y: 10
                    width: customizeText.implicitWidth + 32
                    height: 48
                    topInset: 4
                    bottomInset: 4
                    radius: 20
                    fill: pressed ? Theme.pressed : Theme.chip
                    Accessible.name: qsTr("Customize the Progress cards")
                    onClicked: progressPage.openCustomize()
                    contentItem: Text {
                        id: customizeText
                        text: qsTr("Customize")
                        color: Theme.accent
                        font.family: Theme.bodySemibold
                        font.pixelSize: Theme.labelSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                width: parent.width
                visible: !progressPage.hasRides
                text: qsTr("Your records and trends start with your first ride.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                visible: progressPage.hasRides && progressPage.shownIds.length === 0
                text: qsTr("Every card is hidden. Customize brings them back.")
                color: Theme.text2
                font.family: Theme.bodyMedium
                font.pixelSize: Theme.bodySize
                wrapMode: Text.WordWrap
            }

            Row {
                visible: progressPage.hasRides
                spacing: 16
                Repeater {
                    model: content.columns
                    Column {
                        id: cardColumn
                        readonly property int column: index
                        width: content.columnWidth
                        spacing: 16
                        Repeater {
                            model: progressPage.columnIds(cardColumn.column, content.columns)
                            Loader {
                                id: cardLoader
                                width: cardColumn.width
                                sourceComponent: progressPage.componentFor(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    CustomizeSheet {
        anchors.fill: parent
        open: progressPage.customizing
        cards: progressPage.cards
        titles: progressPage.cardTitles
        onMoveCard: progressPage.moveCard(from, to)
        onShowCard: progressPage.showCard(id, shown)
        onClose: progressPage.customizing = false
    }
}
