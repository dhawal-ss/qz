import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Controls.Material 2.12
import QtGraphicalEffects 1.12
import QtQuick.Window 2.12
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import QtMultimedia 5.15

HomeForm {
    objectName: "home"
    // The dashboard colours (ThemeTokens.qml); a colour of the rider's own stays
    readonly property color pageColor: window.theme.pick(settings.theme_background_color, "#303030", window.theme.bg)
    readonly property color tileColor: window.theme.pick(settings.theme_tile_background_color, "#303030", window.theme.surface)
    // the glow only for a shadow colour of the rider's own: the stock purple was louder than the data
    readonly property bool legacyShadow: settings.theme_tile_shadow_enabled &&
                                         String(settings.theme_tile_shadow_color).toLowerCase() !== "#9c27b0"
    background: Rectangle {
        anchors.fill: parent
        width: parent.fill
        height: parent.fill
        color: pageColor

        // VoiceOver accessibility - ignore decorative background
        Accessible.role: Accessible.Pane
        Accessible.ignored: true
    }
    signal start_clicked;
    signal stop_clicked;
    signal lap_clicked;
    signal peloton_start_workout;
    signal peloton_abort_workout;
    signal plus_clicked(string name)
    signal minus_clicked(string name)
    signal largeButton_clicked(string name)

    Settings {
        id: settings
        Component.onCompleted: window.retakeSettingsSnapshot(settings)
        property real ui_zoom: 100.0
        property bool theme_tile_icon_enabled: false
        property string theme_tile_background_color: "#303030"
        property string theme_background_color: "#303030"
        property bool theme_tile_shadow_enabled: true
        property string theme_tile_shadow_color: "#9C27B0"
        property int theme_tile_secondline_textsize: 12
        property bool skipLocationServicesDialog: false
        property bool trainprogram_sound_on_segment: false
    }

    // The settings page writes through its own Settings copy, and a copy reads the stored values
    // only when it is created, so the tile size and the tile colors waited for a restart (#466).
    // The settings page sends each new value here (settings.qml), and it is set in both copies.
    // Assigning one key makes Qt.labs.settings write the whole copy back, so every key of these
    // copies that the settings page can change is sent, and none of them is left stale.
    Connections {
        target: window
        function onTileSettingChanged(key, value) {
            if (settings[key] !== undefined && settings[key] !== value) {
                // skipLocationServicesDialog is written back too. homeform.cpp resets it when the
                // GPS is on (Android), after this copy has read it: apply the same rule here
                if (Qt.platform.os === "android" && typeof rootItem !== "undefined" && rootItem.locationServices())
                    settings.skipLocationServicesDialog = false
                settings[key] = value
            }
            if (homeFormSettings[key] !== undefined && homeFormSettings[key] !== value)
                homeFormSettings[key] = value
        }
    }

    SoundEffect {
        id: trainingProgramSegmentSound
        source: "qrc:/sounds/training-program-segment.wav"
        volume: 0.9
    }

    Connections {
        target: rootItem
        onTrainingProgramIntervalSoundRequested: trainingProgramSegmentSound.play()
    }

    MessageDialog {
        id: messagePelotonAskStart
        text: qsTr("Peloton Workout in progress")
        informativeText: qsTr("Do you want to follow the resistance? ") + rootItem.pelotonProvider
        buttons: (MessageDialog.Yes | MessageDialog.No)
        onYesClicked: {rootItem.pelotonAskStart = false; peloton_start_workout();}
        onNoClicked: {rootItem.pelotonAskStart = false; peloton_abort_workout();}
        visible: rootItem.pelotonAskStart
    }

    MessageDialog {
        id: stopConfirmationDialog
        text: qsTr("Stop Workout")
        informativeText: qsTr("Do you really want to stop the current workout?")
        buttons: (MessageDialog.Yes | MessageDialog.No)
        onYesClicked: {
            close();
            inner_stop();
        }
        onNoClicked: close()
    }

    // Optional post-workout popup (settings.rpe_feel_popup_enabled) asking for perceived exertion
    // and how the user felt. Saving the FIT file (rootItem.finalizeFitSave) is suspended until this
    // popup is answered, so the values can be embedded in the FIT file before it's written/uploaded.
    Popup {
        id: rpeFeelPopup
        parent: Overlay.overlay

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        // with a bigger text: as wide as the screen allows, as tall as the content (Skip/Save fell out)
        width: window.textScale !== 1 ? Math.min(420, parent.width - 32) : 420
        height: window.textScale !== 1
            ? Math.min(parent.height - 40, Math.max(340, rpeColumn.implicitHeight + 32 + topPadding + bottomPadding))
            : 340
        modal: true
        focus: true
        palette.text: "white"
        closePolicy: Popup.NoAutoClose

        property int selectedRpe: 5
        property int selectedFeel: 50
        readonly property var rpeLabels: [
            qsTr("Rest"), qsTr("Very Light"), qsTr("Light"), qsTr("Moderate"),
            qsTr("Somewhat Hard"), qsTr("Hard"), qsTr("Harder"), qsTr("Very Hard"),
            qsTr("Very Very Hard"), qsTr("Extremely Hard"), qsTr("Maximum Effort")
        ]

        Column {
            id: rpeColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Label {
                text: qsTr("How was this workout?")
                font.bold: true
                font.pixelSize: window.fontPx(18)
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Label {
                text: qsTr("Perceived Exertion (RPE): ") + rpeFeelPopup.selectedRpe + " - " + rpeFeelPopup.rpeLabels[rpeFeelPopup.selectedRpe]
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Slider {
                id: rpeSlider
                width: parent.width
                from: 0
                to: 10
                stepSize: 1
                value: rpeFeelPopup.selectedRpe
                onValueChanged: rpeFeelPopup.selectedRpe = value
            }

            Label {
                text: qsTr("How did you feel?")
                width: parent.width
                wrapMode: Text.WordWrap
            }

            UiComboBox {
                id: feelCombo
                width: parent.width
                model: [qsTr("Very Bad"), qsTr("Bad"), qsTr("OK"), qsTr("Good"), qsTr("Very Good")]
                currentIndex: 2
                onCurrentIndexChanged: rpeFeelPopup.selectedFeel = currentIndex * 25
            }

            Row {
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter

                Button {
                    text: qsTr("Skip")
                    onClicked: {
                        rpeFeelPopup.close();
                        rootItem.finalizeFitSave(-1, -1);
                        finish_stop();
                    }
                }

                Button {
                    text: qsTr("Save")
                    highlighted: true
                    onClicked: {
                        rpeFeelPopup.close();
                        rootItem.finalizeFitSave(rpeFeelPopup.selectedRpe, rpeFeelPopup.selectedFeel);
                        finish_stop();
                    }
                }
            }
        }
    }

    Timer {
        id: searchStatusTimer
        // Always running: rootItem.device blinks while no device is connected (it drives the icon),
        // and bluetoothSearchStatus() is empty once a device is connected
        interval: 1000; repeat: true; triggeredOnStart: true; running: true
        onTriggered: searchStatus = rootItem.bluetoothSearchStatus()
    }

    Timer {
        id: checkStartStopFromWeb
        interval: 200; running: true; repeat: true
        onTriggered: {if(rootItem.stopRequested) {rootItem.stopRequested = false; inner_stop(); }}
    }

    property bool locationServiceRequsted: false
    // Bluetooth and Location as Android reports them now, not only at app start: switched on from
    // the quick settings, the questions about them go away.
    // Home.qml is created before homeform sets rootItem: until then assume "on", so the question
    // doesn't flash at start; setting rootItem re-evaluates the binding with the real value
    property bool locationServicesOn: typeof rootItem === "undefined" || rootItem.locationServices()
    // "No" answered: not asked again until the next start
    property bool locationServicesDeclined: false

    Timer {
        interval: 2000; repeat: true
        // only while a question about them is open: devices without GPS never report Location on
        running: !locationServicesOn && (locationServicesDialog.visible || locationServiceRequsted)
        onTriggered: locationServicesOn = rootItem.refreshLocationServices()
    }

    MessageDialog {
        id: locationServicesDialog
        text: qsTr("Permissions Required")
        informativeText: qsTr("QZ needs Bluetooth enabled to discover fitness equipment. On Android 11 and earlier, Android also requires Location permission and Location Services for Bluetooth discovery. QZ does not use your location data. On Android 12 and later, Nearby devices permission allows Bluetooth discovery without Location.\n\nWould you like to enable the required services?")
        buttons: (MessageDialog.Yes | MessageDialog.No)
        onYesClicked: {
            locationServiceRequsted = true
            rootItem.enableLocationServices()
        }
        onNoClicked: {
            locationServicesDeclined = true
            remindLocationServicesDialog.visible = true
        }
        visible: !locationServicesOn && !locationServiceRequsted && !locationServicesDeclined && !settings.skipLocationServicesDialog
    }

    MessageDialog {
        id: remindLocationServicesDialog
        text: qsTr("Reminder Preference")
        informativeText: qsTr("Would you like to be reminded about enabling Bluetooth or Location Services next time?")
        buttons: (MessageDialog.Yes | MessageDialog.No)
        onYesClicked: settings.skipLocationServicesDialog = false
        onNoClicked: settings.skipLocationServicesDialog = true
        visible: false
    }

    MessageDialog {
        text: qsTr("Restart the app")
        informativeText: qsTr("To apply the changes, you need to restart the app.\nWould you like to do that now?")
        buttons: (MessageDialog.Yes | MessageDialog.No)
        onYesClicked: Qt.callLater(Qt.quit)
        onNoClicked: this.visible = false;
        visible: locationServiceRequsted && !locationServicesOn
    }

    Timer {
        interval: 200; running: true; repeat: false
        onTriggered: {
            if(rootItem.firstRun()) {
                stackView.push("Wizard.qml")
            }
        }
    }

    function inner_stop() {
        stop_clicked();
        if (rootItem.rpeFeelPopupEnabled()) {
            rpeFeelPopup.selectedRpe = 5;
            rpeFeelPopup.selectedFeel = 50;
            // A change of language rebuilds the list and moves it to the first item
            feelCombo.currentIndex = 2;
            rpeFeelPopup.open();
        } else {
            finish_stop();
        }
    }

    function finish_stop() {
        rootItem.save_screenshot();
        if(CHARTJS)
            stackView.push("ChartJsTest.qml")
        else
            stackView.push("ChartsEndWorkout.qml")
    }

    start.onClicked: { start_clicked(); }
    stop.onClicked: {
        if (rootItem.confirmStopEnabled()) {
            stopConfirmationDialog.open();
        } else {
            inner_stop();
        }
    }
    lap.onClicked: { lap_clicked(); toast.show(qsTr("New lap started!"), 1500); }
    searchNow.onClicked: { rootItem.bluetoothSearchNow(); rootItem.reconnectHeartRateBelt(); }
    moreHelp.onClicked: moreHelpPopup.open()

    // After a ride whose best 20 minutes beats the FTP (homeform::Stop): offered when the rider is back
    // on this page from the chart page, so the mail of the ride keeps the FTP of the ride and a web
    // view (the chart page on phones) cannot cover the question
    StackView.onActivated: {
        // the first activation comes before homeform sets rootItem
        if (typeof rootItem === "undefined")
            return
        // a new power record of the ride (the chart page is a web view on phones, above any toast)
        rootItem.showPendingRecordToast()
        // the FTP is read again: the rider may have changed it since the ride
        if (!ftpSuggestionPopup.opened && rootItem.refreshFtpSuggestion())
            ftpSuggestionPopup.open()
    }

    Popup {
        id: ftpSuggestionPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 32)
        padding: 24
        // the numbers are kept when it opens: the answer clears rootItem.ftpSuggestion before it closes
        property int watts: 0
        property int current: 0
        onAboutToShow: { watts = rootItem.ftpSuggestion; current = rootItem.ftpSuggestionCurrent }
        // Back or a tap outside is "Not now"
        onClosed: rootItem.dismissFtpSuggestion()
        background: Rectangle { radius: window.theme.cardRadius; color: window.theme.surface; border.color: window.theme.stroke }

        contentItem: Column {
            spacing: 12

            Label {
                width: parent.width
                text: qsTr("New FTP: %1 W").arg(ftpSuggestionPopup.watts)
                wrapMode: Text.WordWrap
                font.pixelSize: window.fontPx(22)
                font.bold: true
                color: window.theme.go
            }
            Label {
                width: parent.width
                // a no-break space keeps "229 W" on one line
                text: qsTr("Your best 20 minutes in this ride says your FTP is %1. It is %2 now. Your power zones, workout targets and training load follow your FTP.")
                      .arg(ftpSuggestionPopup.watts + "\u00a0W").arg(ftpSuggestionPopup.current + "\u00a0W")
                wrapMode: Text.WordWrap
                color: window.theme.textOnTint
            }
            RideButton {
                width: parent.width
                text: qsTr("Update FTP")
                fillColor: window.theme.go
                labelColor: "#000000"
                onClicked: { rootItem.acceptFtpSuggestion(); ftpSuggestionPopup.close() }
                Accessible.name: text
                Accessible.description: qsTr("Set your FTP to %1 W").arg(ftpSuggestionPopup.watts)
            }
            RideButton {
                width: parent.width
                text: qsTr("Not now")
                fillColor: "transparent"
                labelColor: window.theme.textPrimary
                onClicked: ftpSuggestionPopup.close()
                Accessible.name: text
                Accessible.description: qsTr("Keep your FTP")
            }
        }
    }

    // A ride QZ did not save at the last run (closed or crashed before Stop): offered at launch. Not now
    // keeps it for the next launch
    Connections {
        target: typeof rootItem !== "undefined" ? rootItem : null
        function onRecoverableRideChanged() {
            if (rootItem.recoverableRide !== "" && !recoverRidePopup.opened)
                recoverRidePopup.open()
        }
    }

    Popup {
        id: recoverRidePopup
        parent: Overlay.overlay
        modal: true
        focus: true
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 32)
        padding: 24
        property string ride: ""
        onAboutToShow: ride = rootItem.recoverableRide
        background: Rectangle { radius: window.theme.cardRadius; color: window.theme.surface; border.color: window.theme.stroke }

        contentItem: Column {
            spacing: 12

            Label {
                width: parent.width
                text: qsTr("Recover your last ride?")
                wrapMode: Text.WordWrap
                font.pixelSize: window.fontPx(22)
                font.bold: true
                color: window.theme.textPrimary
            }
            Label {
                width: parent.width
                text: qsTr("QZ closed before this ride was saved: %1. Recover it to keep it in your workout history.").arg(recoverRidePopup.ride)
                wrapMode: Text.WordWrap
                color: window.theme.textOnTint
            }
            RideButton {
                width: parent.width
                text: qsTr("Recover")
                fillColor: window.theme.go
                labelColor: "#000000"
                onClicked: { recoverRidePopup.close(); rootItem.recoverRide() }
                Accessible.name: text
                Accessible.description: qsTr("Save the ride in your workout history")
            }
            RideButton {
                width: parent.width
                text: qsTr("Not now")
                fillColor: "transparent"
                labelColor: window.theme.textPrimary
                onClicked: recoverRidePopup.close()
                Accessible.name: text
                Accessible.description: qsTr("Ask again at the next launch")
            }
            RideButton {
                width: parent.width
                text: qsTr("Discard")
                fillColor: "transparent"
                labelColor: window.theme.danger
                onClicked: { recoverRidePopup.close(); rootItem.discardRecoverableRide() }
                Accessible.name: text
                Accessible.description: qsTr("Delete the backup of this ride")
            }
        }
    }

    // The checklist of the connection card's More help
    Popup {
        id: moreHelpPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 32)
        height: Math.min(helpColumn.height + topPadding + bottomPadding, parent.height - 32)
        padding: 24
        background: Rectangle { radius: window.theme.cardRadius; color: window.theme.surface; border.color: window.theme.stroke }

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: helpColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: helpColumn
                width: parent.width
                spacing: 12

                Label {
                    width: parent.width
                    text: qsTr("If your equipment does not connect")
                    wrapMode: Text.WordWrap
                    font.pixelSize: window.fontPx(20)
                    font.bold: true
                    color: window.theme.textPrimary
                }
                Repeater {
                    model: [qsTr("QZ connects to your bike, treadmill or rower by itself. If it does not:"),
                            qsTr("1. Close the maker's app (Echelon, Domyos...) and any other app that connects to it."),
                            qsTr("2. Turn Bluetooth on and allow QZ to use it."),
                            qsTr("3. Turn the equipment on before you open QZ."),
                            qsTr("4. Restart your phone or tablet."),
                            qsTr("If it disconnects every 30 seconds, turn off the virtual device in the settings.")]
                    Label {
                        width: helpColumn.width
                        text: modelData
                        wrapMode: Text.WordWrap
                        color: window.theme.textOnTint
                    }
                }
                RideButton {
                    width: parent.width
                    text: qsTr("Close")
                    onClicked: moreHelpPopup.close()
                    Accessible.name: text
                    Accessible.description: qsTr("Close the help")
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("home.qml completed");
    }

    GridView {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // The tiles stretch to fill the row: the space left over by a whole number of columns
        // is shared between the columns, up to a quarter of the tile width, and what remains
        // centres the grid. Measured on the page, so the Android insets are excluded.
        // The grid is exactly as wide as its columns and centred by the anchor above, not
        // by leftMargin: Qt 5.15 does not recount the columns when leftMargin changes, so
        // after a resize a row could come out one column short
        // Size classes: bigger tiles on bigger screens, so a tablet or a TV does not show many
        // columns of phone-sized numbers
        readonly property int sizeClass: parent.width < 600 ? 0 : (parent.width < 1024 ? 1 : (parent.width < 1600 ? 2 : 3))
        readonly property real tileBaseWidth: [175, 190, 220, 260][sizeClass] * settings.ui_zoom / 100
        readonly property int tileColumns: Math.max(1, Math.floor(parent.width / tileBaseWidth))
        cellWidth: Math.floor(Math.min(parent.width / tileColumns, tileBaseWidth * 1.25))
        width: tileColumns * cellWidth
        // Every tile is narrower than its cell by tileGap and sits at the cell's left edge, so the
        // last column ends with the gap: the grid is shifted by half the gap, so the outer margins
        // are equal
        readonly property real tileGap: (parent.width >= 600 ? 12 : 8) * settings.ui_zoom / 100
        anchors.horizontalCenterOffset: tileGap / 2
        cellHeight: [130, 140, 156, 180][sizeClass] * settings.ui_zoom / 100
        focus: true
        model: appModel
        anchors.topMargin: (!window.lockTiles ? topChromeHeight + 8 : 0)
        // Bikes: Watts, Heart, Cadence and Elapsed large above the tiles; it scrolls with them, so a
        // phone in landscape still reaches the grid
        header: HeroStrip {
            width: gridView.width - gridView.tileGap
            tiles: typeof rootItem !== "undefined" ? rootItem.heroTiles : []
            theme: window.theme
            zoom: settings.ui_zoom / 100
            availableHeight: gridView.height
            visible: !window.lockTiles && tiles.length > 0
            height: visible ? implicitHeight : 0
            // A taller header is laid out upwards and the view keeps its place: the strip arrives after
            // the first layout and was left above the top. Keep the view at the beginning when it was there
            property real lastHeight: 0
            onHeightChanged: {
                if (!gridView.moving && gridView.contentY <= -lastHeight + 1)
                    gridView.contentY = gridView.originY
                lastHeight = height
            }
        }
        // paused: the tiles step back, the bar shows End and Resume; searching: the connection card
        // is in front
        opacity: rootItem.labelHelp ? 0.3 : (rootItem.rideState === 2 ? 0.5 : 1)
        Behavior on opacity { NumberAnimation { duration: 200 } }
        interactive: !window.lockTiles
        id: gridView
        objectName: "gridview"
        // the tiles scroll under the ride bar, not over it
        clip: true
        Screen.orientationUpdateMask:  Qt.LandscapeOrientation | Qt.PortraitOrientation | Qt.InvertedLandscapeOrientation | Qt.InvertedPortraitOrientation
        Screen.onPrimaryOrientationChanged:{
            // Nothing to recompute: cellWidth and the grid width follow the page width
        }

        Accessible.ignored: true

        delegate: Item {
            id: id1
            width: gridView.cellWidth - gridView.tileGap
            height: gridView.cellHeight - gridView.tileGap

            visible: visibleItem

            // Tile anatomy: a small caption on top, the value large and left-aligned with its
            // unit after it, one secondary line. The name "Speed (km/h)" gives the caption
            // "Speed" and the unit "km/h" (no new strings)
            readonly property real s: settings.ui_zoom / 100
            readonly property int unitStart: name.indexOf("(")
            readonly property int unitEnd: name.lastIndexOf(")")
            readonly property string caption: unitStart > 0 ? name.substring(0, unitStart).trim() : name
            readonly property string unit: unitStart > 0 && unitEnd > unitStart ? name.substring(unitStart + 1, unitEnd) : ""
            readonly property real pad: 12 * s
            // +/- at least 44 px (a sweaty finger), in a column on the right, side by side when the
            // tile is too short for two
            readonly property real stepper: Math.max(44, 44 * s)
            readonly property bool steppersSideBySide: height < 2 * stepper + 24
            readonly property bool hasSteppers: writable && !largeButton
            readonly property real contentWidth: width - 2 * pad - (hasSteppers ? (steppersSideBySide ? 2 * stepper + 12 * s : stepper + 8 * s) : 0)
            // one value size per tile height, so "99" and "100" W look the same
            readonly property real valueSize: Math.round(height * 0.44)
            property bool autoIncl: false
            // the zone of the value (homeform DataObject.zone): a band on top, a Z pill and the value colour
            readonly property color zc: zone > 0 ? window.theme.zoneColor(zone, zoneCount) : "transparent"
            // the FTP Zone tile already reads "Z4.2": no second Z
            readonly property bool showZonePill: zone > 0 && !largeButton && String(value).indexOf("Z") !== 0

            // VoiceOver accessibility support
            Accessible.role: largeButton ? Accessible.Button : (writable ? Accessible.Pane : Accessible.StaticText)
            Accessible.name: name + (largeButton ? "" : (": " + value)) + (zone > 0 && !largeButton ? ", " + qsTr("zone %1").arg(zone) : "")
            Accessible.description: largeButton ? largeButtonLabel : (secondLine !== "" ? secondLine : (writable ? qsTr("Adjustable. Current value: ") + value : qsTr("Current value: ") + value))
            Accessible.focusable: true


            SequentialAnimation on rotation {
                NumberAnimation { to:  2; duration: 60 }
                NumberAnimation { to: -2; duration: 120 }
                NumberAnimation { to:  0; duration: 60 }
                running: loc.currentId !== -1 && id1.state !== "active" && window.lockTiles
                loops: Animation.Infinite; alwaysRunToEnd: true
            }

            states: State {
                name: "active"; when: loc.currentId === gridId && window.lockTiles
                PropertyChanges { target: id1; opacity: 0.3 }
            }

            transitions: Transition { NumberAnimation { property: "opacity"; duration: 200} }

            // a flat surface, a shade lighter than the page, with a hairline edge
            Rectangle {
                anchors.fill: parent
                radius: window.theme.tileRadius * id1.s
                border.width: 1
                border.color: legacyShadow ? settings.theme_tile_shadow_color : window.theme.stroke
                color: tileColor
                id: rect

                // Ignore for VoiceOver - decorative background only
                Accessible.ignored: true
            }
            // the zone band along the top edge, inside the rounded corners
            Rectangle {
                visible: zone > 0 && !largeButton
                x: rect.radius
                y: 0
                width: parent.width - 2 * rect.radius
                height: 4 * id1.s
                radius: height / 2
                color: id1.zc
                Accessible.ignored: true
            }

            DropShadow {
                visible: legacyShadow
                anchors.fill: rect
                cached: true
                horizontalOffset: 3
                verticalOffset: 3
                radius: 8.0
                samples: 16
                color: settings.theme_tile_shadow_color
                source: rect
            }

            // the inclination tile follows the app (auto inclination): a static AUTO chip instead of a
            // blinking icon
            Timer {
                id: toggleIconTimer
                interval: 1000; repeat: true
                running: identificator === "inclination"
                onTriggered: id1.autoIncl = rootItem.autoInclinationEnabled()
            }

            Image {
                id: myIcon
                x: id1.pad
                y: 10 * id1.s
                width: 20 * id1.s
                height: 20 * id1.s
                sourceSize.width: 40
                sourceSize.height: 40
                source: icon
                visible: settings.theme_tile_icon_enabled && !largeButton

                // Ignore for VoiceOver - decorative only
                Accessible.ignored: true
            }
            Text {
                id: myText
                x: id1.pad + (myIcon.visible ? myIcon.width + 6 * id1.s : 0)
                y: 10 * id1.s
                height: Math.max(myIcon.height, implicitHeight)
                width: id1.contentWidth - (myIcon.visible ? myIcon.width + 6 * id1.s : 0) - (autoChip.visible ? autoChip.width + 6 * id1.s : 0)
                       - (zonePill.visible ? zonePill.width + 6 * id1.s : 0)
                verticalAlignment: Text.AlignVCenter
                text: id1.caption
                font.pixelSize: Math.round(14 * id1.s)
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.4
                elide: Text.ElideRight
                color: window.theme.textSecondary
                visible: !largeButton

                // Ignore for VoiceOver - parent Item handles accessibility
                Accessible.ignored: true
            }
            Rectangle {
                id: zonePill
                visible: id1.showZonePill
                x: myText.x + myText.width + 6 * id1.s
                y: myText.y + (myText.height - height) / 2
                height: 18 * id1.s
                width: zonePillText.implicitWidth + 12 * id1.s
                radius: height / 2
                color: id1.zc
                Accessible.ignored: true
                Text {
                    id: zonePillText
                    anchors.centerIn: parent
                    text: "Z" + zone
                    font.pixelSize: Math.round(11 * id1.s)
                    font.bold: true
                    color: "#000000"
                    Accessible.ignored: true
                }
            }
            Rectangle {
                id: autoChip
                visible: id1.autoIncl && !largeButton
                x: myText.x + myText.width + 6 * id1.s
                y: myText.y + (myText.height - height) / 2
                height: 18 * id1.s
                width: autoChipText.implicitWidth + 12 * id1.s
                radius: height / 2
                color: window.theme.infoTonal
                Accessible.ignored: true
                Text {
                    id: autoChipText
                    anchors.centerIn: parent
                    text: qsTr("Auto")
                    font.capitalization: Font.AllUppercase
                    font.pixelSize: Math.round(11 * id1.s)
                    font.bold: true
                    color: window.theme.info
                    Accessible.ignored: true
                }
            }
            Text {
                objectName: "value"
                id: myValue
                // zone 1 (recovery) stays white: its grey would read as disabled
                color: zone > 1 ? id1.zc : (zone === 1 ? window.theme.textPrimary : window.theme.valueColor(valueFontColor))
                x: id1.pad
                anchors.bottom: secondLineText.top
                anchors.bottomMargin: 2 * id1.s
                text: value
                horizontalAlignment: Text.AlignLeft
                // room for the unit after it; a long value (a time) shrinks to fit
                width: Math.max(20, id1.contentWidth - (unitText.text !== "" ? unitText.implicitWidth + unitText.gap : 0))
                height: id1.valueSize * 1.15
                verticalAlignment: Text.AlignBottom
                font.pixelSize: id1.valueSize
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Math.round(id1.valueSize / 2)
                font.bold: true
                visible: !largeButton

                // Ignore for VoiceOver - parent Item handles accessibility
                Accessible.ignored: true
            }
            Text {
                id: unitText
                readonly property real gap: id1.unit === "%" ? 0 : 4 * id1.s
                x: myValue.x + myValue.contentWidth + gap
                anchors.baseline: myValue.baseline
                text: id1.unit
                font.pixelSize: Math.round(0.36 * id1.valueSize)
                font.weight: Font.Medium
                color: window.theme.textSecondary
                visible: !largeButton && text !== ""
                Accessible.ignored: true
            }
            Text {
                objectName: "secondLine"
                id: secondLineText
                color: window.theme.textSecondary
                x: id1.pad
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10 * id1.s
                text: secondLine
                horizontalAlignment: Text.AlignLeft
                width: id1.contentWidth
                font.pixelSize: Math.max(11, Math.round(settings.theme_tile_secondline_textsize * 1.25 * id1.s))
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 11
                elide: Text.ElideRight
                font.bold: false
                visible: !largeButton

                // Ignore for VoiceOver - parent Item handles accessibility
                Accessible.ignored: true
            }
            RoundButton {
                id: plusButton
                autoRepeat: true
                objectName: plusName
                text: "+"
                font.pixelSize: Math.round(0.5 * width)
                onClicked: plus_clicked(objectName)
                visible: id1.hasSteppers
                width: id1.stepper
                height: id1.stepper
                x: id1.width - 8 * id1.s - width
                y: id1.steppersSideBySide ? myValue.y + (myValue.height - height) / 2 : 8 * id1.s
                // a raised disc: Material.background does not colour a RoundButton in Qt 5.15
                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? window.theme.surfacePressed : window.theme.surfaceRaised
                }

                // VoiceOver accessibility
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Increase ") + name
                Accessible.description: qsTr("Increase the value of ") + name
                Accessible.focusable: true
                Accessible.onPressAction: { plus_clicked(objectName) }
            }
            RoundButton {
                objectName: minusName
                autoRepeat: true
                // the minus sign, not a hyphen: as wide as the "+" and on the same line
                text: "−"
                font.pixelSize: Math.round(0.5 * width)
                onClicked: minus_clicked(objectName)
                visible: id1.hasSteppers
                width: id1.stepper
                height: id1.stepper
                x: id1.steppersSideBySide ? plusButton.x - width - 4 * id1.s : plusButton.x
                y: id1.steppersSideBySide ? plusButton.y : id1.height - 8 * id1.s - height
                // a raised disc: Material.background does not colour a RoundButton in Qt 5.15
                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? window.theme.surfacePressed : window.theme.surfaceRaised
                }

                // VoiceOver accessibility
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Decrease ") + name
                Accessible.description: qsTr("Decrease the value of ") + name
                Accessible.focusable: true
                Accessible.onPressAction: { minus_clicked(objectName) }
            }
            RoundButton {
                autoRepeat: true
                objectName: identificator
                text: largeButtonLabel
                onClicked: largeButton_clicked(objectName)
                visible: largeButton
                anchors.fill: rect
                      background: Rectangle {
                          color: largeButtonColor
                            radius: window.theme.tileRadius * id1.s
                            }
                font.pixelSize: Math.round(18 * id1.s)
                font.bold: true

                // VoiceOver accessibility
                Accessible.role: Accessible.Button
                Accessible.name: largeButtonLabel
                Accessible.description: name + ": " + largeButtonLabel
                Accessible.focusable: true
                Accessible.onPressAction: { largeButton_clicked(objectName) }
            }
        }
    }

    footer: Item {
        id: footerItem
        width: parent.width
        height: footerHeight
        property real footerHeight: (rootItem.chartFooterVisible ? parent.height / 4 : parent.height / 2)
        property real minHeight: parent.height / 4
        property real maxHeight: parent.height * 3 / 4
        anchors.bottom: parent.bottom
        clip: true
        visible: rootItem.chartFooterVisible || rootItem.videoVisible

        // the handle that resizes the chart or video: a small pill, the touch area stays as wide
        Rectangle {
            id: dragHandle
            width: parent.width / 5
            height: 24
            color: "transparent"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: rootItem.chartFooterVisible || rootItem.videoVisible

            Rectangle {
                width: 36
                height: 4
                radius: 2
                anchors.centerIn: parent
                color: window.theme.textSecondary
                Accessible.ignored: true
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor

                property real startY: 0
                property real startHeight: 0

                onPressed: {
                    startY = mouseY
                    startHeight = footerItem.height
                }

                onMouseYChanged: {
                    if (pressed) {
                        var newHeight = Math.max(footerItem.minHeight, Math.min(footerItem.maxHeight, startHeight + startY - mouseY))
                        footerItem.footerHeight = newHeight
                    }
                }
            }
        }

        Rectangle {
            id: chartFooterRectangle
            visible: rootItem.chartFooterVisible
            anchors.top: dragHandle.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            ChartFooter {
                anchors.fill: parent
                visible: rootItem.chartFooterVisible
            }
        }

        Rectangle {
            objectName: "footerrectangle"
            visible: rootItem.videoVisible
            anchors.top: dragHandle.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            onVisibleChanged: {
                if(visible === true) {
                    console.log("mediaPlayer onCompleted: " + rootItem.videoPath)
                    console.log("videoRate: " + rootItem.videoRate)
                    videoPlaybackHalf.source = rootItem.videoPath
                    videoPlaybackHalf.seek(rootItem.videoPosition)
                    videoPlaybackHalf.play()
                    videoPlaybackHalf.muted = rootItem.currentCoordinateValid
                } else {
                    videoPlaybackHalf.stop()
                }
            }

            MediaPlayer {
                id: videoPlaybackHalf
                objectName: "videoplaybackhalf"
                autoPlay: false
                playbackRate: rootItem.videoRate

                onError: {
                    if (videoPlaybackHalf.NoError !== error) {
                        console.log("[qmlvideo] VideoItem.onError error " + error + " errorString " + errorString)
                    }
                }
            }

            VideoOutput {
                id: videoPlayer
                anchors.fill: parent
                source: videoPlaybackHalf
            }
        }
    }

    Item {
        id: ghostTile
        visible: loc.currentId !== -1 && window.lockTiles
        x: loc.mouseX - width / 2
        y: loc.mouseY - height / 2
        width: 85 * settings.ui_zoom / 100
        height: 63 * settings.ui_zoom / 100
        z: 200

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: settings.theme_tile_background_color
            opacity: 0.9
            border.width: 2
            border.color: settings.theme_tile_shadow_color

            Text {
                anchors.centerIn: parent
                color: "white"
                text: loc.tileName
                font.pointSize: 10 * settings.ui_zoom / 100
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - 8
                wrapMode: Text.WordWrap
            }
        }
    }

    Timer {
        id: autoScrollTimer
        interval: 50
        repeat: true
        running: false
        property real scrollSpeed: 15
        onTriggered: {
            if (loc.currentId === -1) { running = false; return; }
            var edgeZone = 80
            if (loc.mouseY > gridView.height - edgeZone) {
                var factor = (loc.mouseY - (gridView.height - edgeZone)) / edgeZone
                gridView.contentY = Math.min(
                    gridView.contentHeight - gridView.height,
                    gridView.contentY + scrollSpeed * (1 + factor * 2)
                )
            } else if (loc.mouseY < edgeZone) {
                var factor2 = (edgeZone - loc.mouseY) / edgeZone
                gridView.contentY = Math.max(0, gridView.contentY - scrollSpeed * (1 + factor2 * 2))
            } else {
                running = false
            }
        }
    }

    MouseArea {
        property int currentId: -1
        property int newIndex
        property int startIndex: -1
        property string tileName: ""
        property real lastScrollY: 0
        property bool isSwiping: false

        function indexAtMouse(mx, my) {
            var cols = gridView.tileColumns
            var adjustedY = my + gridView.contentY
            var col = Math.floor((mx - gridView.x) / gridView.cellWidth)
            if (col < 0 || col >= cols) return -1
            var row = Math.floor(adjustedY / gridView.cellHeight)
            var idx = row * cols + col
            if (idx < 0 || idx >= appModel.count) return -1
            return idx
        }

        id: loc
        enabled: window.lockTiles
        anchors.fill: parent

        onPressed: {
            lastScrollY = mouseY
            isSwiping = false
        }

        onPressAndHold: {
            if (isSwiping) return
            var idx = indexAtMouse(mouseX, mouseY)
            if (idx !== -1) {
                startIndex = idx
                newIndex = idx
                currentId = appModel[idx].gridId
                tileName = appModel[idx].name
            } else {
                currentId = -1
                tileName = ""
            }
        }

        onReleased: {
            autoScrollTimer.running = false
            if (currentId !== -1) {
                var idx = indexAtMouse(mouseX, mouseY)
                if (idx !== -1 && idx !== startIndex)
                    rootItem.moveTile(tileName, idx, startIndex)
            }
            currentId = -1
            startIndex = -1
            tileName = ""
            isSwiping = false
        }

        onPositionChanged: {
            if (currentId === -1) {
                // No drag in progress: scroll the grid like a normal flick
                var dy = mouseY - lastScrollY
                if (Math.abs(dy) > 5) isSwiping = true
                gridView.contentY = Math.max(0,
                    Math.min(gridView.contentHeight - gridView.height,
                             gridView.contentY - dy))
                lastScrollY = mouseY
                return
            }
            var edgeZone = 80
            if (mouseY > gridView.height - edgeZone || mouseY < edgeZone)
                autoScrollTimer.running = true
            else
                autoScrollTimer.running = false

            var idx = indexAtMouse(mouseX, mouseY)
            if (idx !== -1 && idx !== newIndex) newIndex = idx
        }
    }
}
