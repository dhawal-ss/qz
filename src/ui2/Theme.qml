pragma Singleton
import QtQuick 2.15

// Colors, type, zones and motion of the Pulse interface (ui2).
QtObject {
    id: theme

    // surfaces
    readonly property color bg: "#09090b"
    readonly property color surface: "#111114"
    readonly property color card: "#121215"
    readonly property color control: "#141417"
    readonly property color floating: "#18181c"
    readonly property color pressed: "#1d1c22"
    readonly property color chip: "#222228"
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.07)
    readonly property color dashed: "#3a3842"

    // text
    readonly property color text: "#f5f3f8"
    readonly property color text2: "#a7a3b0"
    readonly property color text3: "#8a8694"
    readonly property color danger: "#ffb3a8"
    readonly property color recording: "#ff5e5e"

    // brand accent, used when no zone tints the screen
    readonly property color accent: "#c9b8ff"
    readonly property color accentInk: "#1e1240"

    // zones: fill color and the lighter color of the hero numeral
    readonly property var zoneColors: ["#8ab4ff", "#5fd8c6", "#b9e66e", "#ffcb52", "#ff8f52", "#ff5e7e", "#c487ff"]
    readonly property var zoneLight: ["#dde8ff", "#d2f6f0", "#e9f7d2", "#fff1cc", "#ffdfcc", "#ffd3dc", "#eedcff"]
    readonly property var powerZoneNames: [qsTr("Recovery"), qsTr("Endurance"), qsTr("Tempo"), qsTr("Threshold"), qsTr("VO2 max"), qsTr("Anaerobic"), qsTr("Sprint")]
    readonly property var heartZoneNames: [qsTr("Easy"), qsTr("Endurance"), qsTr("Tempo"), qsTr("Threshold"), qsTr("Max")]
    // where each zone starts, as a share of FTP (power) or of max heart rate
    readonly property var powerZoneStarts: [0.555, 0.755, 0.905, 1.055, 1.205, 1.505]
    readonly property var heartZoneStarts: [0.6, 0.7, 0.8, 0.9]

    // type: each role is its own static cut of Google Sans Flex (see tools/build_ui2_fonts.py)
    readonly property FontLoader displayFont: FontLoader { source: "fonts/PulseDisplay.ttf" }
    readonly property FontLoader celebrateFont: FontLoader { source: "fonts/PulseCelebrate.ttf" }
    readonly property FontLoader tallFont: FontLoader { source: "fonts/PulseTall.ttf" }
    readonly property FontLoader textFont: FontLoader { source: "fonts/PulseText.ttf" }
    readonly property FontLoader textMediumFont: FontLoader { source: "fonts/PulseTextMedium.ttf" }
    readonly property FontLoader textSemiboldFont: FontLoader { source: "fonts/PulseTextSemibold.ttf" }
    readonly property list<FontLoader> heroFonts: [
        FontLoader { source: "fonts/PulseHero1.ttf" },
        FontLoader { source: "fonts/PulseHero2.ttf" },
        FontLoader { source: "fonts/PulseHero3.ttf" },
        FontLoader { source: "fonts/PulseHero4.ttf" },
        FontLoader { source: "fonts/PulseHero5.ttf" },
        FontLoader { source: "fonts/PulseHero6.ttf" },
        FontLoader { source: "fonts/PulseHero7.ttf" }
    ]

    readonly property string display: displayFont.name
    readonly property string celebrate: celebrateFont.name
    readonly property string tall: tallFont.name
    readonly property string body: textFont.name
    readonly property string bodyMedium: textMediumFont.name
    readonly property string bodySemibold: textSemiboldFont.name

    // the ride hero numeral gets heavier in every zone
    function heroFamily(zone) {
        var i = Math.max(1, Math.min(7, zone)) - 1
        return heroFonts[i].name
    }

    // sizes
    readonly property int labelSize: 13
    readonly property int tertiarySize: 12
    readonly property int bodySize: 15
    readonly property int titleSize: 19

    // motion: the expressive curve overshoots a little, the effects curve does not
    readonly property var springCurve: [0.3, 1.35, 0.5, 1, 1, 1]
    readonly property var effectsCurve: [0.2, 0, 0, 1, 1, 1]
    readonly property int fast: 350
    readonly property int medium: 500
    readonly property int slow: 700
    readonly property int colorTime: 600
    property bool reduceMotion: false

    function powerZone(watts, ftp) {
        var zone = 1
        for (var i = 0; i < powerZoneStarts.length; i++) {
            if (watts >= Math.round(ftp * powerZoneStarts[i]))
                zone = i + 2
        }
        return zone
    }

    function heartZone(bpm, maxHr) {
        var zone = 1
        for (var i = 0; i < heartZoneStarts.length; i++) {
            if (bpm >= Math.round(maxHr * heartZoneStarts[i]))
                zone = i + 2
        }
        return zone
    }

    function powerZoneRange(zone, ftp) {
        var starts = powerZoneStarts.map(function (p) { return Math.round(ftp * p) })
        if (zone <= 1)
            return qsTr("under %1 W").arg(starts[0])
        if (zone >= 7)
            return qsTr("%1 W and up").arg(starts[5])
        return qsTr("%1 to %2 W").arg(starts[zone - 2]).arg(starts[zone - 1] - 1)
    }

    function heartZoneRange(zone, maxHr) {
        var starts = heartZoneStarts.map(function (p) { return Math.round(maxHr * p) })
        if (zone <= 1)
            return qsTr("under %1 bpm").arg(starts[0])
        if (zone >= 5)
            return qsTr("%1 bpm and up").arg(starts[3])
        return qsTr("%1 to %2 bpm").arg(starts[zone - 2]).arg(starts[zone - 1] - 1)
    }

    // The Pulse: a 12-lobe shape that grows spikier with every zone. Every zone has the same
    // 24 quadratic segments, so a fractional zone draws the shape between two zones.
    // The shape is centered on (54, 54) of a 108 x 108 box.
    function pulsePath(zone) {
        var level = Math.max(0, Math.min(6, zone - 1))
        var outer = 40.5 + 2.083 * level
        var inner = 39.5 - 2.0 * level
        var anchor = 39.6
        var path = ""
        for (var k = 0; k < 24; k++) {
            var a0 = (-7.5 + 15 * k) * Math.PI / 180
            var c = (15 * k) * Math.PI / 180
            var a1 = (7.5 + 15 * k) * Math.PI / 180
            var r = (k % 2 === 0) ? outer : inner
            if (k === 0)
                path += "M" + (54 + anchor * Math.sin(a0)).toFixed(2) + " " + (54 - anchor * Math.cos(a0)).toFixed(2)
            path += "Q" + (54 + r * Math.sin(c)).toFixed(2) + " " + (54 - r * Math.cos(c)).toFixed(2)
                    + " " + (54 + anchor * Math.sin(a1)).toFixed(2) + " " + (54 - anchor * Math.cos(a1)).toFixed(2)
        }
        return path + "Z"
    }
}
