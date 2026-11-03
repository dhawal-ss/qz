import QtQuick 2.15
import ".."

// Units and display: the same rows as on the list of You (MakeItYours), for a page opened as
// open("units").
YouPage {
    id: page

    title: qsTr("Units and display")

    MakeItYours {
        you: page.you
    }
}
