import QtQuick 2.15
import "."

// A rounded group on the page. Children stack in a column inside the padding.
Rectangle {
    id: card

    default property alias cardItems: column.data
    property real padding: 20
    property alias spacing: column.spacing

    implicitHeight: column.height + padding * 2
    radius: 24
    color: Theme.card

    Column {
        id: column
        x: card.padding
        y: card.padding
        width: card.width - card.padding * 2
        spacing: 12
    }
}
