import QtQuick 2.15
import QtQuick.Dialogs 1.3 as Dialogs
import ".."

// Your data: where the rides are on disk, and bringing in rides from elsewhere.
YouPage {
    id: page

    title: qsTr("Your data")
    lead: qsTr("Every ride is saved on this device as a FIT file, the format Strava, Garmin and most training apps read, in Documents/Bikemodo. Rides recorded with QZ, or left by an earlier install, come in with Bring in rides from a folder.")

    readonly property string folder: you.core !== null ? you.core.getWritableAppDir() + "fit/" : ""
    readonly property bool importing: you.core !== null && you.core.fitImportRunning === true
    // the ride library (homeform sets it on the root), for the export and the backup
    readonly property var library: typeof rideLibrary !== "undefined" ? rideLibrary : null
    // what the last export or backup said
    property string savedWords: ""

    function exportRides() {
        if (library === null || you.core === null)
            return
        var path = library.exportCsv(you.core.getWritableAppDir())
        savedWords = path !== "" ? qsTr("Saved as %1").arg(path) : qsTr("Could not write the file.")
    }

    function backUp() {
        if (library === null || you.core === null)
            return
        var path = library.backup(you.core.getWritableAppDir() + "backup")
        savedWords = path !== "" ? qsTr("Backed up in %1").arg(path) : qsTr("Could not write the backup.")
    }

    function importFile() {
        if (you.core === null)
            return
        if (Qt.platform.os === "android")
            you.core.openAndroidDocumentPicker("fit")
        else
            fileDialog.active = true
    }

    YouText {
        kind: "heading"
        text: qsTr("Where rides are saved")
    }

    // the folder, on a hairline
    Item {
        width: parent.width
        height: folderText.implicitHeight + 24
        Text {
            id: folderText
            x: 12
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            text: page.folder !== "" ? page.folder : qsTr("The fit folder")
            color: Theme.text
            font.family: Theme.bodyMedium
            font.pixelSize: Theme.bodySize
            wrapMode: Text.WrapAnywhere
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12 }
            height: 1
            color: Theme.hairline
        }
    }

    YouText {
        kind: "heading"
        text: qsTr("Bring in rides")
    }

    YouRow {
        title: qsTr("Import a FIT file")
        detail: qsTr("A ride from a bike computer, a watch or another app")
        trailing: "next"
        enabled: !page.importing
        onClicked: page.importFile()
    }

    YouRow {
        title: qsTr("Bring in rides from a folder")
        detail: qsTr("Pick Documents/QZ/fit for QZ's rides, or Documents/Bikemodo/fit after a reinstall: Bikemodo copies them in")
        trailing: "next"
        enabled: !page.importing
        hairline: false
        onClicked: if (you.core !== null) you.core.importFitFolder()
    }

    YouText {
        visible: page.importing
        color: Theme.accent
        text: qsTr("Importing rides...")
    }

    YouText {
        kind: "heading"
        text: qsTr("Take your rides with you")
    }

    YouRow {
        title: qsTr("Save every ride as a CSV file")
        detail: qsTr("One line a ride, for a spreadsheet: date, time, distance, power, heart rate, load")
        trailing: "next"
        onClicked: page.exportRides()
    }

    YouRow {
        title: qsTr("Back up the library")
        detail: qsTr("Your merges, splits and settings (never your sign-ins), in a dated folder next to the rides. The FIT files are the rides themselves.")
        trailing: "next"
        hairline: false
        onClicked: page.backUp()
    }

    YouText {
        visible: page.savedWords !== ""
        color: Theme.accent
        text: page.savedWords
    }

    Loader {
        id: fileDialog
        active: false
        sourceComponent: Component {
            Dialogs.FileDialog {
                title: qsTr("Choose a FIT file")
                folder: shortcuts.home
                nameFilters: [qsTr("FIT files (*.fit *.FIT)"), qsTr("All files (*)")]
                visible: true
                onAccepted: {
                    you.core.importFitFile(fileUrl)
                    fileDialog.active = false
                }
                onRejected: fileDialog.active = false
            }
        }
    }
}
