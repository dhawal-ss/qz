import QtQuick 2.15
import QtQml 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtCharts 2.15
import Qt.labs.calendar 1.0
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.0 as Dialogs

Page {
    id: workoutHistoryPage



    Settings {
        id: settings
        property bool miles_unit: false
    }

    // Signal for chart preview
    signal fitfile_preview_clicked(var url)

    // a pending offer to recover the workouts of a previous install is made here
    Component.onCompleted: {
        rootItem.historyPageOpened()
        // the training load follows the date: the page may open on another day than the last load
        if (workoutModel)
            workoutModel.refreshTrainingLoad()
    }

    // Helper function to wrap text with emoji font only on Android. Android shows an emoji
    // only with the downloaded font, so until it is there the emoji is left out
    function wrapEmoji(emoji) {
        if (Qt.platform.os !== "android")
            return emoji;
        if (!fontManager || fontManager.emojiFontFamily === "Arial")
            return "";
        // A trailing space stays out of the emoji font: its space is a wide one
        var space = "";
        if (emoji.slice(-1) === " ") {
            space = " ";
            emoji = emoji.slice(0, -1);
        }
        return '<font face="' + fontManager.emojiFontFamily + '">' + emoji + '</font>' + space;
    }

    // Fitness & Form card: the status id (metric::trainingStatus) as words and as a colour
    function trainingStatusText(status) {
        switch (status) {
        case "fading": return qsTr("Well rested – fitness is starting to fade")
        case "fresh": return qsTr("Fresh – ready for a hard ride")
        case "balanced": return qsTr("Balanced – ride as planned")
        case "building": return qsTr("Building fitness – good training load")
        case "tired": return qsTr("Tired – keep the next ride easy")
        case "learning": return qsTr("Learning your form – day %1 of 42").arg(workoutModel.trainingLoad.historyDays)
        case "break": return qsTr("Welcome back – start with an easy ride")
        }
        return ""
    }
    function trainingStatusDetail(status) {
        switch (status) {
        case "tired": return qsTr("An easy ride still counts for your streak.")
        case "learning": return qsTr("Keep riding, or import older rides with the Import button, to fill in the picture.")
        case "break": return qsTr("%1 days since your last ride").arg(workoutModel.trainingLoad.daysSinceLastRide)
        }
        return ""
    }
    function trainingStatusColor(status) {
        switch (status) {
        case "fading": return "#8D6E00"
        case "fresh": return "#1565C0"
        case "building": return "#2E7D32"
        case "tired": return "#C62828"
        }
        return "#616161"
    }
    // a sign on positive numbers, and a real minus sign
    function signedNumber(n) {
        return n > 0 ? "+" + n : (n < 0 ? "\u2212" + (-n) : "0")
    }
    function spokenNumber(n) {
        return n > 0 ? qsTr("plus %1").arg(n) : (n < 0 ? qsTr("minus %1").arg(-n) : "0")
    }
    function fitnessTrendText(change) {
        if (change > 0)
            return qsTr("+%1 this week").arg(change)
        if (change < 0)
            return qsTr("\u2212%1 this week").arg(-change)
        return qsTr("Steady this week")
    }

    // Sport type to ShapeIcon name, drawn instead of the emoji on Android
    function getSportIconName(sport) {
        switch(parseInt(sport)) {
            case 1:  // FIT_SPORT_RUNNING
                return "directions_run";
            case 11: // FIT_SPORT_WALKING
                return "directions_walk";
            case 2:  // FIT_SPORT_CYCLING
                return "pedal_bike";
            case 15: // FIT_SPORT_ROWING
                return "rowing";
            default:
                return "fitness_center";
        }
    }

    // Sport type to icon mapping (using FIT_SPORT values)
    function getSportIcon(sport) {
        switch(parseInt(sport)) {
            case 1:  // FIT_SPORT_RUNNING
            case 11: // FIT_SPORT_WALKING
                return "🏃"; // Running/Walking
            case 2:  // FIT_SPORT_CYCLING
                return "🚴"; // Cycling
            case 4:  // FIT_SPORT_FITNESS_EQUIPMENT (Elliptical)
                return "⭕"; // Elliptical
            case 15: // FIT_SPORT_ROWING
                return "🚣"; // Rowing
            case 84: // FIT_SPORT_JUMPROPE
                return "🪢"; // Jump Rope
            default: 
                return "💪"; // Generic workout
        }
    }

    function hasAnyUploadServiceConfigured(workoutId) {
        return (rootItem &&
                (rootItem.isStravaLoggedIn() ||
                 rootItem.isGarminUploadConfigured() ||
                 rootItem.isIntervalsICUUploadConfigured())) ||
               (Qt.platform.os === "ios" &&
                workoutModel &&
                workoutModel.canWriteAppleHealth(workoutId))
    }

    function openUploadMenu(delegateItem, workoutId, workoutTitle) {
        if (!workoutModel || !hasAnyUploadServiceConfigured(workoutId)) {
            return
        }

        var details = workoutModel.getWorkoutDetails(workoutId)
        if (!details.filePath || details.filePath === "") {
            return
        }

        uploadMenu.workoutId = workoutId
        uploadMenu.workoutTitle = workoutTitle
        uploadMenu.filePath = details.filePath

        var popupPoint = delegateItem.mapToItem(workoutHistoryPage, delegateItem.width / 2, delegateItem.height / 2)
        uploadMenu.x = Math.max(8, popupPoint.x - 40)
        uploadMenu.y = Math.max(8, popupPoint.y - 20)
        uploadMenu.open()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: 60
            // a bigger text: the title and the filter line keep inside the header (the layout reads
            // the height only once, a preferred height it follows)
            Layout.preferredHeight: window.textScale !== 1 ? Math.max(60, headerTitle.height + 12) : -1
            color: "#f5f5f5"

            // Calendar Icon Button - positioned absolutely on the left
            Button {
                id: calendarButton
                Accessible.name: qsTr("Filter by date")
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: window.contentSideMargin
                width: 48
                height: 48
                
                background: Rectangle {
                    radius: 8
                    color: calendarButton.pressed ? "#e0e0e0" : "#f0f0f0"
                    border.color: "#d0d0d0"
                    border.width: 1
                }
                
                contentItem: Item {
                    Text {
                        anchors.fill: parent
                        visible: Qt.platform.os !== "android"
                        text: "📅"
                        font.pixelSize: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Android shows an emoji only with a downloaded font, so the icon is drawn
                    ShapeIcon {
                        anchors.centerIn: parent
                        visible: Qt.platform.os === "android"
                        name: "calendar_month"
                        size: 26
                        color: "#444444"
                    }
                }
                
                onClicked: {
                    calendarPopup.open()
                }
            }

            // Clear Filter Button - right of the calendar; before the title and the import button, as a screen reader goes through the header in this order
            Button {
                id: clearFilterButton
                Accessible.name: qsTr("Clear Filter")
                // next to the calendar that set the filter; small, so the title keeps its room
                anchors.left: calendarButton.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                width: 32
                height: 32
                visible: workoutModel && workoutModel.isDateFiltered

                background: Rectangle {
                    radius: 16
                    color: clearFilterButton.pressed ? "#ff6666" : "#ff8888"
                    border.color: "#ff4444"
                    border.width: 1
                }

                contentItem: Text {
                    text: "×"
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    workoutModel.clearDateFilter()
                }
            }

            // Title with filter status - between the buttons, shrinking on narrow screens
            Column {
                id: headerTitle
                anchors.left: clearFilterButton.visible ? clearFilterButton.right : calendarButton.right
                anchors.right: importButton.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Workout History")
                    font.pixelSize: window.fontPx(24)
                    font.bold: true
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 14
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: workoutModel && workoutModel.isDateFiltered ?
                          qsTr("Filtered: %1").arg(workoutModel.filteredDate.toLocaleDateString()) : ""
                    font.pixelSize: window.fontPx(12)
                    color: "#666666"
                    elide: Text.ElideRight
                    visible: workoutModel && workoutModel.isDateFiltered
                }
            }

            // Import Button - on the right: a single .fit file, or every workout of the QZ folder
            Button {
                id: importButton
                Accessible.name: qsTr("Import workouts")
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: window.contentSideMargin
                width: 48
                height: 48

                background: Rectangle {
                    radius: 8
                    color: importButton.pressed ? "#e0e0e0" : "#f0f0f0"
                    border.color: "#d0d0d0"
                    border.width: 1
                }

                contentItem: Item {
                    Text {
                        anchors.fill: parent
                        visible: Qt.platform.os !== "android"
                        text: "📥"
                        font.pixelSize: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Android shows an emoji only with a downloaded font, so the icon is drawn
                    ShapeIcon {
                        anchors.centerIn: parent
                        visible: Qt.platform.os === "android"
                        name: "download"
                        size: 26
                        color: "#444444"
                    }
                }

                onClicked: importMenu.popup(importButton, 0, importButton.height)
            }
        }

        // Loading indicator
        BusyIndicator {
            id: loadingIndicator
            Layout.alignment: Qt.AlignHCenter
            visible: (workoutModel ? (workoutModel.isLoading || workoutModel.isDatabaseProcessing) : false) ||
                     (rootItem && rootItem.fitImportRunning)
            running: visible
        }

        // Workout import message: copying the picked files can take a while
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: window.contentSideMargin
            Layout.rightMargin: window.contentSideMargin
            visible: rootItem ? rootItem.fitImportRunning : false
            text: qsTr("Importing workouts...")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#666666"
            font.pixelSize: window.fontPx(16)
        }

        // Database processing message
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: window.contentSideMargin
            Layout.rightMargin: window.contentSideMargin
            visible: workoutModel ? workoutModel.isDatabaseProcessing : false
            text: qsTr("Processing workout files...\nThis may take a few moments on first startup.")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#666666"
            font.pixelSize: window.fontPx(16)
        }

        // Workout List
        ListView {
            id: workoutListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.bottomMargin: streakBanner.visible ? streakBanner.height + 10 : 10
            model: workoutModel
            spacing: 8
            clip: true
            
            onContentYChanged: {
                // Hide banner when scrolling down, show when at top. With a header the list starts at
                // originY, below 0
                streakBanner.visible = contentY - originY <= 20
            }

            // Fitness & Form: how ready the rider is, from the training load of the bike rides. It
            // scrolls away with the list; hidden while a day is picked in the calendar
            header: Item {
                id: trainingLoadHeader
                readonly property var load: workoutModel ? workoutModel.trainingLoad : ({})
                readonly property bool shown: !!workoutModel && !workoutModel.isDateFiltered &&
                                              (load.available === true || load.updating === true)
                readonly property bool updating: load.updating === true
                readonly property bool wide: width >= 600
                width: workoutListView.width
                height: shown ? trainingLoadCard.height + 8 : 0
                visible: shown
                // A taller header is laid out upwards from the first workout and the view keeps its
                // place, which left the card above the top (after a date filter is cleared, or when
                // the fill ends): keep the view at the beginning when it was there
                property real lastHeight: 0
                onHeightChanged: {
                    if (!workoutListView.moving && workoutListView.contentY <= -lastHeight + 1)
                        workoutListView.contentY = workoutListView.originY
                    lastHeight = height
                }

                Rectangle {
                    id: trainingLoadCard
                    y: 8
                    x: window.contentSideMargin
                    width: parent.width - 2 * window.contentSideMargin
                    height: trainingLoadColumn.height + 24
                    radius: 10
                    color: "white"
                    border.color: "#e0e0e0"

                    // one sentence for a screen reader, and a double tap opens the explanation
                    Accessible.role: Accessible.Button
                    Accessible.name: trainingLoadHeader.updating
                                     ? qsTr("Fitness and form: working out your fitness from your past rides")
                                     : qsTr("Fitness and form: %1. Fitness %2, fatigue %3, form %4.")
                                           .arg(trainingStatusText(trainingLoadHeader.load.status))
                                           .arg(trainingLoadHeader.load.fitness)
                                           .arg(trainingLoadHeader.load.fatigue)
                                           .arg(spokenNumber(trainingLoadHeader.load.form))
                    Accessible.onPressAction: trainingLoadPopup.open()

                    MouseArea {
                        anchors.fill: parent
                        onClicked: trainingLoadPopup.open()
                    }

                    // positioners with set widths, not layouts: the card height read from a layout loops
                    // on the wrapped texts while the list lays the header out
                    Column {
                        id: trainingLoadColumn
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 8

                        Item {
                            width: parent.width
                            height: Math.max(trainingLoadOverline.height, trainingLoadHelpBadge.height)
                            Text {
                                id: trainingLoadOverline
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - trainingLoadHelpBadge.width - 8
                                text: qsTr("FITNESS & FORM")
                                elide: Text.ElideRight
                                font.pixelSize: window.fontPx(12)
                                font.bold: true
                                font.letterSpacing: 1
                                color: "#666666"
                                Accessible.ignored: true
                            }
                            Rectangle {
                                id: trainingLoadHelpBadge
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: window.fontPx(22)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: "#bdbdbd"
                                Accessible.ignored: true
                                Text {
                                    anchors.centerIn: parent
                                    text: "?"
                                    font.pixelSize: window.fontPx(13)
                                    font.bold: true
                                    color: "#666666"
                                    Accessible.ignored: true
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            visible: trainingLoadHeader.updating
                            text: qsTr("Working out your fitness from your past rides…")
                            wrapMode: Text.WordWrap
                            font.pixelSize: window.fontPx(15)
                            color: "#333333"
                            Accessible.ignored: true
                        }

                        Grid {
                            id: trainingLoadGrid
                            visible: !trainingLoadHeader.updating && trainingLoadHeader.load.available === true
                            columns: trainingLoadHeader.wide ? 2 : 1
                            columnSpacing: 16
                            rowSpacing: 8
                            // half the card each when wide
                            readonly property real cellWidth: trainingLoadHeader.wide ? (trainingLoadColumn.width - columnSpacing) / 2
                                                                                      : trainingLoadColumn.width

                            Column {
                                width: trainingLoadGrid.cellWidth
                                spacing: 8

                                Row {
                                    width: parent.width
                                    spacing: 8
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        y: (trainingLoadStatusText.font.pixelSize * 1.35 - height) / 2
                                        color: trainingStatusColor(trainingLoadHeader.load.status)
                                        Accessible.ignored: true
                                    }
                                    Text {
                                        id: trainingLoadStatusText
                                        width: parent.width - 18
                                        text: trainingStatusText(trainingLoadHeader.load.status)
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: window.fontPx(15)
                                        font.bold: true
                                        color: "#212121"
                                        Accessible.ignored: true
                                    }
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: trainingStatusDetail(trainingLoadHeader.load.status)
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: window.fontPx(12)
                                    color: "#666666"
                                    Accessible.ignored: true
                                }

                                Row {
                                    width: parent.width
                                    Repeater {
                                        model: [
                                            { label: qsTr("Fitness"), value: "" + trainingLoadHeader.load.fitness, swatch: "#1565C0" },
                                            { label: qsTr("Fatigue"), value: "" + trainingLoadHeader.load.fatigue, swatch: "#AD1457" },
                                            { label: qsTr("Form"), value: signedNumber(trainingLoadHeader.load.form), swatch: "" }
                                        ]
                                        Column {
                                            id: trainingLoadNumber
                                            width: trainingLoadGrid.cellWidth / 3
                                            spacing: 2
                                            Text {
                                                width: parent.width
                                                text: modelData.value
                                                elide: Text.ElideRight
                                                font.pixelSize: window.fontPx(28)
                                                font.bold: true
                                                color: "#212121"
                                                Accessible.ignored: true
                                            }
                                            Row {
                                                width: parent.width
                                                spacing: 6
                                                Rectangle {
                                                    visible: modelData.swatch !== ""
                                                    width: 12
                                                    height: 3
                                                    y: (trainingLoadNumberLabel.font.pixelSize * 1.35 - height) / 2
                                                    color: modelData.swatch === "" ? "transparent" : modelData.swatch
                                                    Accessible.ignored: true
                                                }
                                                Text {
                                                    id: trainingLoadNumberLabel
                                                    width: trainingLoadNumber.width - (modelData.swatch !== "" ? 18 : 0) - 4
                                                    text: modelData.label
                                                    wrapMode: Text.WordWrap
                                                    font.pixelSize: window.fontPx(12)
                                                    color: "#666666"
                                                    Accessible.ignored: true
                                                }
                                            }
                                        }
                                    }
                                }
                                Text {
                                    width: parent.width
                                    visible: trainingLoadHeader.load.status !== "learning"
                                    text: fitnessTrendText(trainingLoadHeader.load.fitnessChange)
                                    font.pixelSize: window.fontPx(12)
                                    color: "#666666"
                                    Accessible.ignored: true
                                }
                            }

                            Column {
                                width: trainingLoadGrid.cellWidth
                                spacing: 2

                                // Fitness (with a light fill) and Fatigue over the last 6 weeks
                                Item {
                                    id: trainingLoadChartBox
                                    width: parent.width
                                    height: trainingLoadHeader.wide ? 96 : 56
                                    Accessible.ignored: true

                                    // drawn at the pixel density of the screen and scaled down, as ShapeIcon does
                                    Canvas {
                                        id: trainingLoadChart
                                        width: trainingLoadChartBox.width * Screen.devicePixelRatio
                                        height: trainingLoadChartBox.height * Screen.devicePixelRatio
                                        scale: 1 / Screen.devicePixelRatio
                                        transformOrigin: Item.TopLeft
                                        Accessible.ignored: true
                                        readonly property var fitnessSeries: trainingLoadHeader.load.fitnessSeries || []
                                        readonly property var fatigueSeries: trainingLoadHeader.load.fatigueSeries || []
                                        onFitnessSeriesChanged: requestPaint()
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            var ratio = Screen.devicePixelRatio
                                            ctx.scale(ratio, ratio)
                                            var w = trainingLoadChartBox.width
                                            var h = trainingLoadChartBox.height - 6
                                            var n = fitnessSeries.length
                                            if (n < 2 || w <= 0)
                                                return
                                            var top = 10
                                            for (var i = 0; i < n; i++)
                                                top = Math.max(top, fitnessSeries[i], fatigueSeries[i])
                                            top *= 1.15
                                            var xAt = function(i) { return 4 + (w - 8) * i / (n - 1) }
                                            var yAt = function(v) { return 3 + h - h * v / top }

                                            ctx.strokeStyle = "#e0e0e0"
                                            ctx.lineWidth = 1
                                            ctx.beginPath()
                                            ctx.moveTo(0, yAt(0) + 0.5)
                                            ctx.lineTo(w, yAt(0) + 0.5)
                                            ctx.stroke()

                                            ctx.beginPath()
                                            ctx.moveTo(xAt(0), yAt(0))
                                            for (i = 0; i < n; i++)
                                                ctx.lineTo(xAt(i), yAt(fitnessSeries[i]))
                                            ctx.lineTo(xAt(n - 1), yAt(0))
                                            ctx.closePath()
                                            ctx.fillStyle = Qt.rgba(0x15 / 255, 0x65 / 255, 0xC0 / 255, 0.12)
                                            ctx.fill()

                                            var line = function(series, color) {
                                                ctx.strokeStyle = color
                                                ctx.lineWidth = 2
                                                ctx.beginPath()
                                                for (var k = 0; k < n; k++) {
                                                    if (k === 0)
                                                        ctx.moveTo(xAt(k), yAt(series[k]))
                                                    else
                                                        ctx.lineTo(xAt(k), yAt(series[k]))
                                                }
                                                ctx.stroke()
                                                ctx.fillStyle = color
                                                ctx.beginPath()
                                                ctx.arc(xAt(n - 1), yAt(series[n - 1]), 4, 0, 2 * Math.PI)
                                                ctx.fill()
                                            }
                                            line(fatigueSeries, "#AD1457")
                                            line(fitnessSeries, "#1565C0")
                                        }
                                    }
                                }
                                Item {
                                    width: parent.width
                                    height: trainingLoadWeeksAgo.height
                                    Text {
                                        id: trainingLoadWeeksAgo
                                        anchors.left: parent.left
                                        text: qsTr("6 weeks ago")
                                        font.pixelSize: window.fontPx(11)
                                        color: "#9e9e9e"
                                        Accessible.ignored: true
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: qsTr("Today")
                                        font.pixelSize: window.fontPx(11)
                                        color: "#9e9e9e"
                                        Accessible.ignored: true
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            visible: !trainingLoadHeader.updating && trainingLoadHeader.load.available === true
                            text: qsTr("FTP %1 W").arg(trainingLoadHeader.load.ftp) +
                                  (trainingLoadHeader.load.counted < trainingLoadHeader.load.total
                                   ? " · " + qsTr("%1 of %2 workouts in the last 6 weeks counted")
                                                 .arg(trainingLoadHeader.load.counted).arg(trainingLoadHeader.load.total)
                                   : "")
                            wrapMode: Text.WordWrap
                            font.pixelSize: window.fontPx(11)
                            color: "#9e9e9e"
                            Accessible.ignored: true
                        }
                    }
                }
            }

            delegate: SwipeDelegate {
                id: swipeDelegate
                // The row is a list item for Qt 5, which has no press action for a screen reader: with
                // the handler a double tap opens the workout
                Accessible.onPressAction: swipeDelegate.clicked()
                // The row has no text of its own: without a name a screen reader stops on the texts
                // inside it, which cannot be pressed, and the workout cannot be opened
                Accessible.name: title + ", " + date + ", " + duration
                width: parent.width
                // a bigger text: the card grows with its lines (margins 8 + 12 on each side)
                height: window.textScale !== 1 ? Math.max(135, workoutInfo.implicitHeight + 40) : 135

                Component.onCompleted: {
                    console.log("Delegate data:", JSON.stringify({
                        sport: sport,
                        title: title,
                        date: date,
                        duration: duration,
                        distance: distance,
                        calories: calories,
                        id: id
                    }))
                }

                swipe.right: Rectangle {
                    width: parent.width
                    height: parent.height
                    color: "#FF4444"
                    clip: true

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 20
                        spacing: 4

                        ShapeIcon {
                            visible: Qt.platform.os === "android"
                            name: "delete"
                            size: 18
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Qt.platform.os === "android" ? qsTr("Delete") : "🗑️ " + qsTr("Delete")
                            color: "white"
                            font.pixelSize: window.fontPx(16)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                swipe.onCompleted: {
                    // Show confirmation dialog
                    confirmDialog.workoutId = model.id
                    confirmDialog.workoutTitle = model.title
                    confirmDialog.open()
                }

                // Card-like container
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.leftMargin: window.contentSideMargin
                    anchors.rightMargin: window.contentSideMargin
                    radius: 10
                    color: "white"
                    border.color: "#e0e0e0"

                    // Workout Type Tag - positioned absolutely in top-right
                    WorkoutTypeTag {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        workoutSource: workoutModel ? workoutModel.getWorkoutSource(model.id) : "QZ"
                    }

                    // Action buttons - positioned absolutely in bottom-right
                    Row {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        spacing: 8
                        
                        // Peloton URL button
                        Button {
                            Accessible.name: qsTr("Open on Peloton")
                            width: 40
                            height: 45
                            visible: workoutModel && workoutModel.getWorkoutSource(model.id) === "PELOTON" && 
                                    workoutModel.getPelotonUrl(model.id) !== ""
                            
                            background: Rectangle {
                                color: parent.pressed ? "#ff8855" : "#ff6b35"
                                radius: 6
                                border.color: "#cc5529"
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Text {
                                    visible: Qt.platform.os !== "android"
                                    text: "🌐"
                                    font.pixelSize: 16
                                    color: "white"
                                    anchors.centerIn: parent
                                }

                                ShapeIcon {
                                    visible: Qt.platform.os === "android"
                                    name: "language"
                                    size: 20
                                    color: "white"
                                    anchors.centerIn: parent
                                }
                            }
                            
                            onClicked: {
                                workoutModel.openPelotonUrl(model.id)
                            }
                        }
                        
                        // Training Program button
                        Button {
                            Accessible.name: qsTr("Load training program")
                            width: 40
                            height: 45
                            visible: workoutModel && workoutModel.hasTrainingProgram(model.id)
                            
                            background: Rectangle {
                                color: parent.pressed ? "#1976d2" : "#2196f3"
                                radius: 6
                                border.color: "#1565c0"
                                border.width: 1
                            }
                            
                            contentItem: Item {
                                Text {
                                    visible: Qt.platform.os !== "android"
                                    text: "📋"
                                    font.pixelSize: 16
                                    color: "white"
                                    anchors.centerIn: parent
                                }

                                ShapeIcon {
                                    visible: Qt.platform.os === "android"
                                    name: "list_alt"
                                    size: 20
                                    color: "white"
                                    anchors.centerIn: parent
                                }
                            }
                            
                            onClicked: {
                                var success = workoutModel.loadTrainingProgram(model.id)
                                if (success) {
                                    trainingProgramDialog.title = qsTr("Success")
                                    trainingProgramDialog.message = qsTr("Training program loaded successfully!")
                                    trainingProgramDialog.isSuccess = true
                                } else {
                                    trainingProgramDialog.title = qsTr("Error")
                                    trainingProgramDialog.message = qsTr("Failed to load training program. Please check if the file exists.")
                                    trainingProgramDialog.isSuccess = false
                                }
                                trainingProgramDialog.open()
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 16

                        // Sport icon
                        Column {
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                visible: Qt.platform.os !== "android"
                                text: getSportIcon(sport)
                                font.pixelSize: 32
                            }

                            // Android shows an emoji only with a downloaded font, so the icon is drawn
                            ShapeIcon {
                                visible: Qt.platform.os === "android"
                                name: getSportIconName(sport)
                                size: 32
                                color: "#444444"
                            }
                        }

                        // Workout info
                        ColumnLayout {
                            id: workoutInfo
                            Layout.fillWidth: true
                            spacing: 4

                            // Title row (without tag) with auto-scrolling
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.rightMargin: window.fontPx(80) // Reserve space for tag
                                Layout.preferredHeight: window.textScale !== 1 ? Math.max(24, titleText.implicitHeight) : 24
                                clip: true
                                color: "transparent"
                                
                                Text {
                                    id: titleText
                                    text: title
                                    font.bold: true
                                    font.pixelSize: window.fontPx(18)
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    // Auto-scroll animation for long titles.
                                    // The row width settles only after the layout runs (the first
                                    // delegate passes through narrower widths), and an animation started
                                    // on one of them kept running: decide after the layout, again on every
                                    // width change, and put the title back when it stops mid-scroll.
                                    readonly property bool overflows: parent.width > 0 && contentWidth > parent.width
                                    function updateScroll() {
                                        if (overflows) {
                                            titleScroll.restart()
                                        } else {
                                            titleScroll.stop()
                                            x = 0
                                        }
                                    }
                                    onOverflowsChanged: Qt.callLater(updateScroll)
                                    onContentWidthChanged: if (overflows) Qt.callLater(updateScroll)
                                    Connections {
                                        target: titleText.parent
                                        function onWidthChanged() { if (titleText.overflows) Qt.callLater(titleText.updateScroll) }
                                    }

                                    SequentialAnimation {
                                        id: titleScroll
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            target: titleText
                                            property: "x"
                                            from: 0
                                            to: -(titleText.contentWidth - titleText.parent.width + 20)
                                            duration: Math.max(3000, titleText.contentWidth * 30)
                                        }
                                        PauseAnimation { duration: 1500 }
                                        NumberAnimation {
                                            target: titleText
                                            property: "x"
                                            from: -(titleText.contentWidth - titleText.parent.width + 20)
                                            to: 0
                                            duration: Math.max(3000, titleText.contentWidth * 30)
                                        }
                                        PauseAnimation { duration: 2000 }
                                    }
                                }
                            }

                            Text {
                                // a plain Text does not inherit the window font: the text size while it is not 100 %
                                Binding on font.pixelSize { when: window.scaledFontPx > 0; value: window.plainFontPx; restoreMode: Binding.RestoreBindingOrValue }
                                text: date
                                color: "#666666"
                            }

                            // Stats row; with a bigger text one under the other, clear of the action
                            // buttons in the bottom-right corner
                            GridLayout {
                                columns: window.textScale > 1 ? 1 : 2
                                columnSpacing: 16
                                rowSpacing: 4

                                Text {
                                    Binding on font.pixelSize { when: window.scaledFontPx > 0; value: window.plainFontPx; restoreMode: Binding.RestoreBindingOrValue }
                                    text: wrapEmoji("⏱ ") + duration
                                    textFormat: Qt.platform.os === "android" ? Text.RichText : Text.PlainText
                                }

                                Text {
                                    Binding on font.pixelSize { when: window.scaledFontPx > 0; value: window.plainFontPx; restoreMode: Binding.RestoreBindingOrValue }
                                    text: {
                                        var useMiles = settings && settings.miles_unit
                                        var displayDistance = useMiles ? (distance / 1.60934) : distance
                                        return wrapEmoji("📏 ") + displayDistance.toFixed(2) + " " + (useMiles ? qsTr("mi") : qsTr("km"))
                                    }
                                    textFormat: Qt.platform.os === "android" ? Text.RichText : Text.PlainText
                                }
                            }

                            RowLayout {
                                spacing: 16

                                Text {
                                    Binding on font.pixelSize { when: window.scaledFontPx > 0; value: window.plainFontPx; restoreMode: Binding.RestoreBindingOrValue }
                                    text: Qt.platform.os === "android" ? 
                                          wrapEmoji("🔥 ") + Math.round(calories) + " " + qsTr("kcal") :
                                          "🔥 " + Math.round(calories) + " " + qsTr("kcal")
                                    textFormat: Qt.platform.os === "android" ? Text.RichText : Text.PlainText
                                }
                            }
                        }
                        
                    }
                }

                onClicked: {
                    console.log("Workout clicked, ID:", model.id)
                    
                    // Get workout details from the model
                    var details = workoutModel.getWorkoutDetails(model.id)
                    console.log("Workout details:", JSON.stringify(details))

                    // Emit signal with file URL for chart preview - same pattern as profiles.qml
                    console.log("Emitting fitfile_preview_clicked with path:", details.filePath)
                    // Convert to URL like profiles.qml does with FolderListModel
                    var fileUrl = "file://" + details.filePath
                    console.log("Converted to URL:", fileUrl)
                    workoutHistoryPage.fitfile_preview_clicked(fileUrl)

                    // Push the ChartJsTest view
                    stackView.push("PreviewChart.qml")
                }

                onPressAndHold: {
                    workoutHistoryPage.openUploadMenu(swipeDelegate, model.id, model.title)
                }
            }
        }
    }

    Menu {
        // A MenuItem has no press action for a screen reader in Qt 5 (its role is reset to
        // MenuItem): it is read, but a double tap does nothing without the handler
        // The name is set as well: the one Qt takes from the text was empty for TalkBack on a phone
        id: importMenu
        // Modal, as the calendar: otherwise a screen reader touching an item got the workout
        // row under the menu; no dim, so it looks as before
        modal: true
        dim: false

        MenuItem {
            Accessible.onPressAction: triggered()
            Accessible.name: text
            text: qsTr("Import FIT File...")
            onTriggered: {
                if (Qt.platform.os === "android") {
                    rootItem.openAndroidDocumentPicker("fit")
                } else {
                    fitFileDialogLoader.active = true
                }
            }
        }

        MenuItem {
            Accessible.onPressAction: triggered()
            Accessible.name: text
            // after a reinstall the workouts of the previous install stay in this folder,
            // but Android hides them from the app until the folder is picked once
            text: qsTr("Import from QZ Folder...")
            onTriggered: rootItem.importFitFolder()
        }
    }

    Loader {
        id: fitFileDialogLoader
        active: false
        sourceComponent: Component {
            Dialogs.FileDialog {
                title: qsTr("Please choose a file")
                folder: shortcuts.home
                nameFilters: [qsTr("FIT files (*.fit *.FIT)"), qsTr("All files (*)")]
                visible: true
                onAccepted: {
                    rootItem.importFitFile(fileUrl)
                    fitFileDialogLoader.active = false
                }
                onRejected: fitFileDialogLoader.active = false
            }
        }
    }

    Menu {
        // A MenuItem has no press action for a screen reader in Qt 5 (its role is reset to
        // MenuItem): it is read, but a double tap does nothing without the handler
        // The name is set as well: the one Qt takes from the text was empty for TalkBack on a phone
        id: uploadMenu
        // Modal, as the calendar: otherwise a screen reader touching an item got the workout
        // row under the menu; no dim, so it looks as before
        modal: true
        dim: false

        property int workoutId: -1
        property string workoutTitle: ""
        property string filePath: ""

        title: workoutTitle

        MenuItem {
            Accessible.onPressAction: triggered()
            Accessible.name: text
            text: qsTr("Upload to Strava")
            visible: rootItem && rootItem.isStravaLoggedIn()
            onTriggered: rootItem.uploadHistoricalWorkoutToStrava(uploadMenu.filePath)
        }

        MenuItem {
            Accessible.onPressAction: triggered()
            Accessible.name: text
            text: qsTr("Upload to Garmin")
            visible: rootItem && rootItem.isGarminUploadConfigured()
            onTriggered: rootItem.uploadHistoricalWorkoutToGarmin(uploadMenu.filePath)
        }

        MenuItem {
            Accessible.onPressAction: triggered()
            Accessible.name: text
            text: qsTr("Upload to Intervals.icu")
            visible: rootItem && rootItem.isIntervalsICUUploadConfigured()
            onTriggered: rootItem.uploadHistoricalWorkoutToIntervalsICU(uploadMenu.filePath)
        }

        MenuItem {
            Accessible.onPressAction: triggered()
            Accessible.name: text
            text: qsTr("Upload to Apple Health")
            visible: Qt.platform.os === "ios" &&
                     workoutModel &&
                     workoutModel.canWriteAppleHealth(uploadMenu.workoutId)
            onTriggered: workoutModel.uploadWorkoutToAppleHealth(uploadMenu.workoutId)
        }
    }

    // Confirmation Dialog
    Dialog {
        id: confirmDialog

        property int workoutId
        property string workoutTitle

        title: qsTr("Delete Workout")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        // a bigger text: the dialog keeps inside the screen and the question wraps
        width: window.textScale !== 1 ? Math.min(implicitWidth, parent.width - 32) : implicitWidth

        Text {
            Binding on font.pixelSize { when: window.scaledFontPx > 0; value: window.plainFontPx; restoreMode: Binding.RestoreBindingOrValue }
            width: window.textScale !== 1 ? confirmDialog.availableWidth : implicitWidth
            wrapMode: window.labelWrap
            text: qsTr("Are you sure you want to delete '%1'?").arg(confirmDialog.workoutTitle)
        }

        onAccepted: {
            workoutModel.deleteWorkout(confirmDialog.workoutId)
            swipeDelegate.swipe.close()
        }
        onRejected: {
            swipeDelegate.swipe.close()
        }
    }

    // Training Program Loading Dialog
    Dialog {
        id: trainingProgramDialog
        // a white popup in the app's dark Material theme: its buttons were white on white
        Material.theme: Material.Light

        property string message: ""
        property bool isSuccess: true

        modal: true
        standardButtons: Dialog.Ok

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        background: Rectangle {
            color: "white"
            radius: 8
            border.color: trainingProgramDialog.isSuccess ? "#4caf50" : "#f44336"
            border.width: 2
        }

        header: Rectangle {
            height: 50
            color: trainingProgramDialog.isSuccess ? "#4caf50" : "#f44336"
            radius: 8

            Text {
                anchors.centerIn: parent
                text: trainingProgramDialog.title
                color: "white"
                font.pixelSize: window.fontPx(18)
                font.bold: true
            }
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                Layout.margins: 20
                Layout.preferredWidth: 300
                Layout.preferredHeight: window.textScale !== 1 ? Math.max(120, implicitHeight) : 120
                text: Qt.platform.os === "android" ? 
                      wrapEmoji("🔥 ") +
                      wrapEmoji(trainingProgramDialog.isSuccess ? '✅ ' : '❌ ') +
                      trainingProgramDialog.message :
                      "🔥 " + (trainingProgramDialog.isSuccess ? '✅ ' : '❌ ') + trainingProgramDialog.message
                textFormat: Qt.platform.os === "android" ? Text.RichText : Text.PlainText
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: window.fontPx(14)
            }
        }
    }

    // Streak Banner at the bottom
    Rectangle {
        id: streakBanner
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: window.textScale !== 1 ? Math.max(80, streakColumn.implicitHeight + 16) : 80
        visible: workoutModel
        
        Behavior on visible {
            NumberAnimation {
                properties: "opacity"
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
        
        // Special pulsing effect for major milestones
        SequentialAnimation on opacity {
            running: workoutModel && workoutModel.currentStreak >= 30
            loops: Animation.Infinite
            NumberAnimation { from: 0.9; to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.9; duration: 1500; easing.type: Easing.InOutSine }
        }
        
        gradient: Gradient {
            GradientStop { 
                position: 0.0; 
                color: workoutModel && (workoutModel.currentStreak >= 365) ? "#FFD700" : 
                       workoutModel && (workoutModel.currentStreak >= 180) ? "#9932CC" : 
                       workoutModel && (workoutModel.currentStreak >= 90) ? "#FF1493" : 
                       workoutModel && (workoutModel.currentStreak >= 30) ? "#FF4500" : 
                       workoutModel && (workoutModel.currentStreak >= 7) ? "#FF6347" : "#FF6B35"
            }
            GradientStop { 
                position: 1.0; 
                color: workoutModel && (workoutModel.currentStreak >= 365) ? "#FFA500" : 
                       workoutModel && (workoutModel.currentStreak >= 180) ? "#8A2BE2" : 
                       workoutModel && (workoutModel.currentStreak >= 90) ? "#DC143C" : 
                       workoutModel && (workoutModel.currentStreak >= 30) ? "#FF6B35" : 
                       workoutModel && (workoutModel.currentStreak >= 7) ? "#FF4500" : "#F7931E"
            }
        }
        
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#40FFFFFF" }
                GradientStop { position: 1.0; color: "#00FFFFFF" }
            }
        }
        
        ColumnLayout {
            id: streakColumn
            anchors.centerIn: parent
            spacing: 4

            // Current streak with count
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 15

                // Fire emoji with animation
                Text {
                    text: Qt.platform.os === "android" ? (
                          workoutModel && workoutModel.currentStreak >= 365 ? wrapEmoji("👑🔥") :
                          workoutModel && workoutModel.currentStreak >= 180 ? wrapEmoji("🎖️🔥") :
                          workoutModel && workoutModel.currentStreak >= 90 ? wrapEmoji("🦁🔥") :
                          workoutModel && workoutModel.currentStreak >= 30 ? wrapEmoji("🎊🔥") :
                          workoutModel && workoutModel.currentStreak >= 7 ? wrapEmoji("🏆🔥") : wrapEmoji("🔥")
                          ) : (
                          workoutModel && workoutModel.currentStreak >= 365 ? "👑🔥" :
                          workoutModel && workoutModel.currentStreak >= 180 ? "🎖️🔥" :
                          workoutModel && workoutModel.currentStreak >= 90 ? "🦁🔥" :
                          workoutModel && workoutModel.currentStreak >= 30 ? "🎊🔥" :
                          workoutModel && workoutModel.currentStreak >= 7 ? "🏆🔥" : "🔥"
                          )
                    textFormat: Qt.platform.os === "android" ? Text.RichText : Text.PlainText
                    font.pixelSize: workoutModel && workoutModel.currentStreak >= 7 ? 28 : 24

                    SequentialAnimation on scale {
                        running: workoutModel && workoutModel.currentStreak > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 1.0;
                            to: workoutModel && workoutModel.currentStreak >= 7 ? 1.4 : 1.2;
                            duration: workoutModel && workoutModel.currentStreak >= 365 ? 600 : 800;
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: workoutModel && workoutModel.currentStreak >= 7 ? 1.4 : 1.2;
                            to: 1.0;
                            duration: workoutModel && workoutModel.currentStreak >= 7 ? 600 : 800;
                            easing.type: Easing.InOutSine
                        }
                    }

                    // Special sparkle effect for year achievement
                    SequentialAnimation on rotation {
                        running: workoutModel && workoutModel.currentStreak >= 7
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: 360; duration: 3000; easing.type: Easing.Linear }
                    }
                }

                // Current streak count
                Text {
                    text: workoutModel ? (workoutModel.currentStreak !== 1 ? qsTr("%1 days streak") : qsTr("%1 day streak")).arg(workoutModel.currentStreak) : ""
                    font.pixelSize: window.fontPx(18)
                    font.bold: true
                    color: "white"
                    visible: workoutModel
                }

                // Another fire emoji
                Text {
                    text: Qt.platform.os === "android" ? (
                          workoutModel && workoutModel.currentStreak >= 365 ? wrapEmoji("🔥👑") :
                          workoutModel && workoutModel.currentStreak >= 180 ? wrapEmoji("🔥🎖️") :
                          workoutModel && workoutModel.currentStreak >= 90 ? wrapEmoji("🔥🦁") :
                          workoutModel && workoutModel.currentStreak >= 30 ? wrapEmoji("🔥🎊") :
                          workoutModel && workoutModel.currentStreak >= 7 ? wrapEmoji("🔥🏆") : wrapEmoji("🔥")
                          ) : (
                          workoutModel && workoutModel.currentStreak >= 365 ? "🔥👑" :
                          workoutModel && workoutModel.currentStreak >= 180 ? "🔥🎖️" :
                          workoutModel && workoutModel.currentStreak >= 90 ? "🔥🦁" :
                          workoutModel && workoutModel.currentStreak >= 30 ? "🔥🎊" :
                          workoutModel && workoutModel.currentStreak >= 7 ? "🔥🏆" : "🔥"
                          )
                    textFormat: Qt.platform.os === "android" ? Text.RichText : Text.PlainText
                    font.pixelSize: workoutModel && workoutModel.currentStreak >= 365 ? 28 : 24

                    SequentialAnimation on scale {
                        running: workoutModel && workoutModel.currentStreak > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 1.0;
                            to: workoutModel && workoutModel.currentStreak >= 7 ? 1.4 : 1.2;
                            duration: workoutModel && workoutModel.currentStreak >= 7 ? 700 : 1000;
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: workoutModel && workoutModel.currentStreak >= 7 ? 1.4 : 1.2;
                            to: 1.0;
                            duration: workoutModel && workoutModel.currentStreak >= 7 ? 700 : 1000;
                            easing.type: Easing.InOutSine
                        }
                    }

                    // Counter-rotation for variety
                    SequentialAnimation on rotation {
                        running: workoutModel && workoutModel.currentStreak >= 7
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: -360; duration: 3500; easing.type: Easing.Linear }
                    }
                }
            }
            
            // Motivational message
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: workoutModel ? workoutModel.streakMessage : ""
                font.pixelSize: window.fontPx(14)
                font.italic: true
                color: "white"
                visible: workoutModel && workoutModel.streakMessage !== ""
                opacity: 0.9
            }
            
            // Best streak (smaller text)
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: workoutModel ? (workoutModel.longestStreak !== 1 ? qsTr("Personal best: %1 days") : qsTr("Personal best: %1 day")).arg(workoutModel.longestStreak) : ""
                font.pixelSize: window.fontPx(12)
                color: "white"
                visible: workoutModel && workoutModel.longestStreak > workoutModel.currentStreak && workoutModel.longestStreak > 0
                opacity: 0.7
            }
        }
        
        // Subtle shadow effect at the top
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#40000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }
    }

    // What Fitness, Fatigue and Form mean, with this rider's Form zones
    Popup {
        id: trainingLoadPopup
        // a white popup in the app's dark Material theme: its buttons were white on white
        Material.theme: Material.Light
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(parent.width - 32, 440)
        // fitted to the text, and scrolled when the screen is shorter
        height: Math.min(parent.height - 32, trainingLoadPopupColumn.height + topPadding + bottomPadding)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        readonly property var load: workoutModel ? workoutModel.trainingLoad : ({})
        readonly property var limits: load.zoneLimits || [0, 0, 0, 0]
        readonly property bool ready: load.available === true && load.updating !== true

        background: Rectangle {
            color: "white"
            radius: 12
            border.color: "#d0d0d0"
            border.width: 1
        }

        Flickable {
            id: trainingLoadPopupFlickable
            anchors.fill: parent
            contentWidth: width
            contentHeight: trainingLoadPopupColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // positioners, not layouts: a layout's height read in a binding loops on the wrapped texts
            Column {
                id: trainingLoadPopupColumn
                width: trainingLoadPopupFlickable.width
                spacing: 10

                Text {
                    width: parent.width
                    text: qsTr("Fitness & Form")
                    font.pixelSize: window.fontPx(18)
                    font.bold: true
                    color: "#212121"
                }
                Repeater {
                    model: [
                        { title: qsTr("Fitness"), body: qsTr("Your training over the last 6 weeks. It grows slowly when you ride often and drops slowly when you stop.") },
                        { title: qsTr("Fatigue"), body: qsTr("Your training over the last 7 days. Hard rides raise it fast; rest days bring it down fast.") },
                        { title: qsTr("Form"), body: qsTr("Fitness minus fatigue. Below zero you are tired from recent training – that is how you get fitter. Above zero you are rested and ready to go hard.") }
                    ]
                    Text {
                        width: trainingLoadPopupColumn.width
                        text: "<b>" + modelData.title + "</b> – " + modelData.body
                        textFormat: Text.StyledText
                        wrapMode: Text.WordWrap
                        font.pixelSize: window.fontPx(14)
                        color: "#333333"
                    }
                }
                // the zones need the numbers: hidden while they are worked out
                Text {
                    width: parent.width
                    visible: trainingLoadPopup.ready
                    text: qsTr("Form zones for your fitness")
                    font.pixelSize: window.fontPx(14)
                    font.bold: true
                    color: "#212121"
                }
                Repeater {
                    // the limits are whole numbers: a zone runs from its lower limit to the next one
                    model: [
                        { status: "fading", range: qsTr("above %1").arg(signedNumber(trainingLoadPopup.limits[0])) },
                        { status: "fresh", range: qsTr("%1 to %2").arg(signedNumber(trainingLoadPopup.limits[1] + 1)).arg(signedNumber(trainingLoadPopup.limits[0])) },
                        { status: "balanced", range: qsTr("%1 to %2").arg(signedNumber(trainingLoadPopup.limits[2])).arg(signedNumber(trainingLoadPopup.limits[1])) },
                        { status: "building", range: qsTr("%1 to %2").arg(signedNumber(trainingLoadPopup.limits[3])).arg(signedNumber(trainingLoadPopup.limits[2] - 1)) },
                        { status: "tired", range: qsTr("below %1").arg(signedNumber(trainingLoadPopup.limits[3])) }
                    ]
                    Row {
                        width: trainingLoadPopupColumn.width
                        spacing: 8
                        visible: trainingLoadPopup.ready
                        readonly property bool current: trainingLoadPopup.load.status === modelData.status
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            y: (zoneText.font.pixelSize * 1.3 - height) / 2
                            color: trainingStatusColor(modelData.status)
                            Accessible.ignored: true
                        }
                        Text {
                            id: zoneText
                            width: parent.width - 18
                            text: trainingStatusText(modelData.status) + " (" + modelData.range + ")" +
                                  (parent.current ? " " + qsTr("(now)") : "")
                            wrapMode: Text.WordWrap
                            font.pixelSize: window.fontPx(13)
                            font.bold: parent.current
                            color: "#333333"
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: qsTr("Each bike ride with power gets a training stress score (TSS): one hour all-out at your FTP scores 100. QZ uses the FTP you had on the day of the ride. Your FTP now: %1 W (Settings › General Options › FTP value). Tip: 95% of your best 20-minute power is a good FTP estimate. Runs, rows and rides without power are not counted yet.").arg(trainingLoadPopup.load.ftp)
                    wrapMode: Text.WordWrap
                    font.pixelSize: window.fontPx(12)
                    color: "#666666"
                }
                Button {
                    x: parent.width - width
                    text: qsTr("Close")
                    onClicked: trainingLoadPopup.close()
                }
            }
        }
    }

    // Calendar Popup
    Popup {
        id: calendarPopup
        // a white popup in the app's dark Material theme: its buttons were white on white
        Material.theme: Material.Light
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(parent.width * 0.9, 400)
        height: Math.min(parent.height * 0.8, 500)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        onOpened: {
            // Refresh workout dates when calendar opens
            if (workoutModel) {
                calendar.workoutDates = workoutModel.getWorkoutDates()
                console.log("Calendar opened, refreshed workout dates:", JSON.stringify(calendar.workoutDates))
            }
        }

        background: Rectangle {
            color: "white"
            radius: 12
            border.color: "#d0d0d0"
            border.width: 1
            
            // Shadow effect
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.leftMargin: 2
                radius: parent.radius
                color: "#40000000"
                z: -1
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Calendar Header
            RowLayout {
                Layout.fillWidth: true
                
                Button {
                    text: "<"
                    Accessible.name: qsTr("Previous month")
                    onClicked: calendar.selectedDate = new Date(calendar.selectedDate.getFullYear(), calendar.selectedDate.getMonth() - 1, 1)
                }
                
                Text {
                    Layout.fillWidth: true
                    text: calendar.selectedDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    font.pixelSize: window.fontPx(18)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Button {
                    text: ">"
                    Accessible.name: qsTr("Next month")
                    onClicked: calendar.selectedDate = new Date(calendar.selectedDate.getFullYear(), calendar.selectedDate.getMonth() + 1, 1)
                }
            }

            // Calendar Grid
            GridLayout {
                id: calendar
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                
                property date selectedDate: new Date()
                property var workoutDates: workoutModel ? workoutModel.getWorkoutDates() : []
                
                // Debug: print workout dates when they change
                onWorkoutDatesChanged: {
                    console.log("Calendar workout dates updated:", JSON.stringify(workoutDates))
                }
                
                // Day headers
                Repeater {
                    model: [qsTr("Sun"), qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr("Fri"), qsTr("Sat")]
                    Text {
                        Binding on font.pixelSize { when: window.scaledFontPx > 0; value: window.plainFontPx; restoreMode: Binding.RestoreBindingOrValue }
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        text: modelData
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: "#666666"
                    }
                }
                
                // Calendar days
                Repeater {
                    model: getCalendarDays()
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 40
                        
                        property date dayDate: modelData.date
                        property bool isCurrentMonth: modelData.currentMonth
                        property bool hasWorkout: modelData.hasWorkout
                        property bool isToday: dayDate.toDateString() === new Date().toDateString()

                        // A day is a rectangle with a MouseArea: a screen reader sees it only as a button
                        // with a name and a press action; days of the other months do nothing on a tap
                        Accessible.role: Accessible.Button
                        Accessible.name: dayDate.toLocaleDateString(Qt.locale(), Locale.LongFormat) + (hasWorkout ? ", " + qsTr("has a workout") : "")
                        Accessible.ignored: !isCurrentMonth
                        Accessible.onPressAction: selectDay()

                        function selectDay() {
                            if (isCurrentMonth) {
                                var year = dayDate.getFullYear();
                                var month = dayDate.getMonth() + 1; // i mesi JS sono 0-indicizzati
                                var day = dayDate.getDate();
                                var dateString = year + "-" + (month < 10 ? '0' + month : month) + "-" + (day < 10 ? '0' + day : day);

                                workoutModel.setDateFilter(dateString);
                                calendarPopup.close();
                            }
                        }

                        color: {
                            if (mouseArea.pressed) return "#e3f2fd"
                            if (isToday) return "#bbdefb"
                            if (!isCurrentMonth) return "#f5f5f5"
                            return "white"
                        }
                        
                        border.color: isToday ? "#2196f3" : "#e0e0e0"
                        border.width: isToday ? 2 : 1
                        radius: 4
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dayDate.getDate()
                                color: isCurrentMonth ? "black" : "#cccccc"
                                font.pixelSize: window.fontPx(14)
                            }
                            
                            // Workout indicator dot
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: "#ff6b35"
                                visible: hasWorkout
                                border.width: 1
                                border.color: "#cc5529"
                                
                                // Debug: log when a dot should be visible
                                Component.onCompleted: {
                                    if (hasWorkout) {
                                        console.log("Workout dot visible for date:", dayDate.toDateString())
                                    }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            
                            onClicked: parent.selectDay()
                        }
                    }
                }
            }
            
            // Close button
            Button {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Close")
                onClicked: calendarPopup.close()
            }
        }
    }

    // JavaScript functions for calendar
    function getCalendarDays() {
        var days = []
        var firstDay = new Date(calendar.selectedDate.getFullYear(), calendar.selectedDate.getMonth(), 1)
        var lastDay = new Date(calendar.selectedDate.getFullYear(), calendar.selectedDate.getMonth() + 1, 0)
        var startDate = new Date(firstDay)
        startDate.setDate(startDate.getDate() - firstDay.getDay()) // Go back to start of week
        
        var workoutDates = calendar.workoutDates || []
        console.log("getCalendarDays: workoutDates received:", JSON.stringify(workoutDates))
        
        // workoutDates is now a QStringList (array of strings in format "yyyy-MM-dd")
        var workoutDateStrings = workoutDates || []
        console.log("Final workout date strings:", JSON.stringify(workoutDateStrings))
        
        for (var i = 0; i < 42; i++) { // 6 rows x 7 days
            var currentDate = new Date(startDate)
            currentDate.setDate(startDate.getDate() + i)
            
            // Costruisci la stringa YYYY-MM-DD dai componenti della data locale per evitare problemi di fuso orario
            var year = currentDate.getFullYear();
            var month = currentDate.getMonth() + 1; // i mesi JS sono 0-indicizzati
            var day = currentDate.getDate();
            var localDateString = year + "-" + (month < 10 ? '0' + month : month) + "-" + (day < 10 ? '0' + day : day);

            var hasWorkout = workoutDateStrings.indexOf(localDateString) !== -1;
            if (hasWorkout) {
                // Questo console.log ora utilizza la stringa della data locale corretta per la corrispondenza
                console.log("Found workout match for:", localDateString);
            }
            
            var isCurrentMonth = currentDate.getMonth() === calendar.selectedDate.getMonth()
            
            days.push({
                date: currentDate,
                currentMonth: isCurrentMonth,
                hasWorkout: hasWorkout
            })
        }
        
        console.log("getCalendarDays: returning", days.length, "days")
        return days
    }
}
