import QtQuick 2.15
import QtQuick.Dialogs 1.3 as Dialogs
import ".."

// Your data: where the rides are on disk, and bringing in rides from elsewhere.
YouPage {
    id: page

    title: qsTr("Your data")
    lead: qsTr("Every ride is saved on this device as a FIT file, the format Strava, Garmin and most training apps read. After a reinstall, or for rides recorded with QZ, Look in the folder again brings them back.")

    readonly property string folder: you.core !== null ? you.core.getWritableAppDir() + "fit/" : ""
    readonly property bool importing: you.core !== null && you.core.fitImportRunning === true

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
        title: qsTr("Look in the folder again")
        detail: qsTr("After a reinstall, finds the rides that are still in the folder")
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
