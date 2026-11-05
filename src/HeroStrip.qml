import QtQuick 2.12

// The key numbers of a bike ride, large, above the tiles (dashboard spec, step 4): Watts, Heart,
// Cadence and Elapsed (homeform::heroTiles). Self-contained: no window, rootItem or settings, so the
// QML tests load it on their own.
Item {
    id: hero
    // the DataObjects to show, in order
    property var tiles: []
    // ThemeTokens
    property var theme
    property real zoom: 1
    // the height of the page area under the ride bar: the cells grow with it
    property real availableHeight: 600

    readonly property int count: tiles ? tiles.length : 0
    readonly property real gap: width >= 600 ? 12 : 8
    readonly property int columns: count <= 3 ? Math.max(count, 1) : (width >= 600 ? 4 : 2)
    readonly property int rows: count > 0 ? Math.ceil(count / columns) : 0
    readonly property real cellW: (width - (columns - 1) * gap) / columns
    readonly property real cellH: Math.round(Math.min(Math.max(availableHeight * 0.18, cellW * 0.5, 112 * zoom), 240 * zoom))
    // the cells, and the gap to the tiles under them
    implicitHeight: count > 0 ? rows * cellH + rows * gap : 0

    // The value as shown: no heart rate is "--", an elapsed time under an hour drops its "0:"
    function shownValue(tile) {
        if (!tile)
            return ""
        var v = String(tile.value)
        if (tile.identificator === "heart" && v === "0")
            return "--"
        if (tile.identificator === "elapsed" && v.indexOf("0:") === 0)
            return v.substring(2)
        return v
    }

    Grid {
        id: grid
        columns: hero.columns
        spacing: hero.gap

        Repeater {
            id: repeater
            model: hero.tiles

            Rectangle {
                id: cell
                objectName: "heroCell"
                width: hero.cellW
                height: hero.cellH
                radius: 16
                color: !hero.theme ? "#1C1D21" : zone > 0 ? Qt.tint(hero.theme.surface, Qt.rgba(zc.r, zc.g, zc.b, 0.20)) : hero.theme.surface
                border.color: hero.theme ? hero.theme.stroke : "#2E2F33"

                // "Heart (bpm)" gives the caption "Heart" and the unit "bpm", as on the tiles
                readonly property string tileName: modelData.name
                readonly property int unitStart: tileName.indexOf("(")
                readonly property int unitEnd: tileName.lastIndexOf(")")
                readonly property string caption: unitStart > 0 ? tileName.substring(0, unitStart).trim() : tileName
                readonly property string unit: unitStart > 0 && unitEnd > unitStart ? tileName.substring(unitStart + 1, unitEnd) : ""
                readonly property string shown: hero.shownValue(modelData)
                readonly property real pad: 14 * hero.zoom
                readonly property bool showSecondLine: hero.cellH >= 120 * hero.zoom && modelData.secondLine !== ""
                readonly property real valueSize: Math.round(height * (showSecondLine ? 0.46 : 0.54))
                // the zone of the value tints the cell (power 1-7, heart rate 1-5)
                readonly property int zone: modelData.zone !== undefined ? modelData.zone : 0
                readonly property color zc: zone > 0 && hero.theme ? hero.theme.zoneColor(zone, modelData.zoneCount) : "transparent"
                readonly property color onTint: hero.theme ? (zone > 0 ? hero.theme.textOnTint : hero.theme.textSecondary) : "#A1A1A8"

                Accessible.role: Accessible.StaticText
                Accessible.name: caption + ": " + shown + (zone > 0 ? ", " + qsTr("zone %1").arg(zone) : "")
                Accessible.description: modelData.secondLine
                Accessible.focusable: true

                Text {
                    x: cell.pad
                    y: 10 * hero.zoom
                    width: cell.width - 2 * cell.pad
                    text: cell.caption
                    font.pixelSize: Math.round(14 * hero.zoom)
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.4
                    elide: Text.ElideRight
                    color: cell.onTint
                    Accessible.ignored: true
                }
                Text {
                    id: valueText
                    objectName: "heroValue"
                    x: cell.pad
                    anchors.bottom: cell.showSecondLine ? secondLineText.top : parent.bottom
                    anchors.bottomMargin: cell.showSecondLine ? 2 * hero.zoom : 10 * hero.zoom
                    // room for the unit after it; a long value (a time) shrinks to fit
                    width: Math.max(20, cell.width - 2 * cell.pad - (unitText.visible ? unitText.implicitWidth + unitText.gap : 0))
                    height: cell.valueSize * 1.15
                    verticalAlignment: Text.AlignBottom
                    text: cell.shown
                    font.pixelSize: cell.valueSize
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Math.round(cell.valueSize / 2)
                    font.bold: true
                    color: !hero.theme ? "white" : cell.zone > 0 ? hero.theme.textPrimary : hero.theme.valueColor(modelData.valueFontColor)
                    Accessible.ignored: true
                }
                Text {
                    id: unitText
                    readonly property real gap: cell.unit === "%" ? 0 : 4 * hero.zoom
                    x: valueText.x + valueText.contentWidth + gap
                    anchors.baseline: valueText.baseline
                    visible: text !== ""
                    text: cell.unit
                    font.pixelSize: Math.round(0.34 * cell.valueSize)
                    font.weight: Font.Medium
                    color: cell.onTint
                    Accessible.ignored: true
                }
                Text {
                    id: secondLineText
                    x: cell.pad
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10 * hero.zoom
                    width: cell.width - 2 * cell.pad
                    visible: cell.showSecondLine
                    text: modelData.secondLine
                    font.pixelSize: Math.max(11, Math.round(14 * hero.zoom))
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 11
                    elide: Text.ElideRight
                    color: cell.onTint
                    Accessible.ignored: true
                }
            }
        }
    }
}
