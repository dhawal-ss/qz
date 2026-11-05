pragma Singleton
import QtQuick 2.15
import Qt.labs.settings 1.0
import "Format.js" as Format

// Colors, type, zones and motion of the Pulse interface (ui2).
QtObject {
    id: theme

    // light: the light palette, for bright rooms (main2.qml sets it from ui2/appearance and the
    // phone's dark theme). Every color below has a dark and a light value; the light ones are
    // chosen by contrast (text 4.5:1 or more on bg and cards, accents and zones 3:1 or more).
    property bool light: false

    // surfaces
    readonly property color bg: light ? "#f6f5f8" : "#09090b"
    readonly property color surface: light ? "#ffffff" : "#111114"
    readonly property color card: light ? "#ffffff" : "#121215"
    readonly property color control: light ? "#efedf2" : "#141417"
    readonly property color floating: light ? "#ffffff" : "#18181c"
    readonly property color pressed: light ? "#e7e5ec" : "#1d1c22"
    readonly property color chip: light ? "#e4e2ea" : "#222228"
    readonly property color hairline: overlay(light ? 0.09 : 0.07)
    readonly property color dashed: light ? "#c4c1cc" : "#3a3842"
    // a wash over a surface: white on the dark palette, black on the light one (lines, tracks,
    // empty bars). Not for a mark on a zone or accent fill, which keeps its own color.
    function overlay(alpha) {
        return light ? Qt.rgba(0, 0, 0, alpha) : Qt.rgba(1, 1, 1, alpha)
    }

    // text
    readonly property color text: light ? "#16151a" : "#f5f3f8"
    readonly property color text2: light ? "#55525e" : "#a7a3b0"
    readonly property color text3: light ? "#6b6875" : "#8a8694"
    readonly property color danger: light ? "#b3261e" : "#ffb3a8"
    readonly property color recording: light ? "#c62828" : "#ff5e5e"

    // brand accent, used when no zone tints the screen. The rider picks it in You (Make it yours);
    // each one is a light tone that reads on bg and cards, with its own dark ink for text on it,
    // and a deeper tone with white ink for the light palette.
    readonly property var accents: [
        { id: "lavender", name: qsTr("Lavender"), color: "#c9b8ff", ink: "#1e1240", lightColor: "#6a4fd1" },
        { id: "sky", name: qsTr("Sky"), color: "#a9c7ff", ink: "#0b1d3d", lightColor: "#2f63c4" },
        { id: "mint", name: qsTr("Mint"), color: "#8fe3cc", ink: "#062a20", lightColor: "#0d7a63" },
        { id: "peach", name: qsTr("Peach"), color: "#ffc29e", ink: "#3d1a06", lightColor: "#ad4f14" },
        { id: "rose", name: qsTr("Rose"), color: "#ffb0c8", ink: "#3e0f22", lightColor: "#b02f64" },
        { id: "silver", name: qsTr("Silver"), color: "#d8d5de", ink: "#1c1b21", lightColor: "#5d5a66" }
    ]
    // the saved choice (ui2/accentChoice), read once at start; You sets accentChoice when it changes
    readonly property Settings savedLook: Settings {
        category: "ui2"
        property string accentChoice: "lavender"
        property string appearance: "system"
        property int weekStart: 1
        property bool heartZonesSet: false
        property bool ftpConfirmed: false
    }
    // QZ's FTP. Its default, 200 W, is not the rider's own until they set or confirm it (ui2/
    // ftpConfirmed): until then training load, form and power zones say "set your FTP" instead
    // of numbers worked out from a guess. Body and FTP and Today set it here with setFtp().
    readonly property Settings savedFtp: Settings {
        property real ftp: 200.0
    }
    readonly property real ftp: savedFtp.ftp > 0 ? savedFtp.ftp : 200
    readonly property bool ftpSet: Math.round(savedFtp.ftp) !== 200 || savedLook.ftpConfirmed
    function setFtp(watts) {
        savedFtp.ftp = watts
        savedLook.ftpConfirmed = true
        savedFtp.sync()
        savedLook.sync()
    }
    // QZ's four heart zone steps (heart_rate_zone1..4): the share of max heart rate, in percent,
    // where zones 2 to 5 start. Saved rides are worked out from the same keys (ridestats.cpp), and
    // the Zones page writes here as well as to its own copy when the rider changes them.
    readonly property Settings savedZones: Settings {
        property real heart_rate_zone1: 70.0
        property real heart_rate_zone2: 80.0
        property real heart_rate_zone3: 90.0
        property real heart_rate_zone4: 100.0
    }
    property string accentChoice: savedLook.accentChoice
    // ui2/appearance: "system" follows the phone's dark theme, "dark" or "light" keep one; main2
    // turns it into light. You sets appearance when it changes.
    property string appearance: savedLook.appearance === "dark" || savedLook.appearance === "light" ? savedLook.appearance : "system"
    readonly property var accentEntry: {
        for (var i = 0; i < accents.length; i++)
            if (accents[i].id === accentChoice)
                return accents[i]
        return accents[0]
    }
    readonly property color accent: light ? accentEntry.lightColor : accentEntry.color
    readonly property color accentInk: light ? "#ffffff" : accentEntry.ink
    // the accent as a faint wash, e.g. accentWash(0.08) behind a picked row
    function accentWash(alpha) {
        return Qt.rgba(accent.r, accent.g, accent.b, alpha)
    }

    // the first day of the week (ui2/weekStart): 1 Monday, 0 Sunday. Read once at start; You sets
    // weekStart when it changes. Bindings that lay out a week read it here, so they update; the
    // JavaScript files get it through Format.firstDay, which this keeps in step.
    property int weekStart: Number(savedLook.weekStart) === 0 ? 0 : 1
    onWeekStartChanged: Format.setFirstDay(weekStart)
    Component.onCompleted: {
        Format.setFirstDay(weekStart)
        // once: QZ's untouched steps (70/80/90/100) put zone 5 at max heart rate and above, so
        // Bikemodo starts zones 2 to 5 at 60, 70, 80 and 90 percent. Steps the rider set are kept.
        if (!savedLook.heartZonesSet) {
            if (Math.round(savedZones.heart_rate_zone1) === 70 && Math.round(savedZones.heart_rate_zone2) === 80
                    && Math.round(savedZones.heart_rate_zone3) === 90 && Math.round(savedZones.heart_rate_zone4) === 100) {
                savedZones.heart_rate_zone1 = 60
                savedZones.heart_rate_zone2 = 70
                savedZones.heart_rate_zone3 = 80
                savedZones.heart_rate_zone4 = 90
                savedZones.sync()
            }
            savedLook.heartZonesSet = true
        }
    }

    // zones: fill color and the lighter color of the hero numeral (on the light palette deeper
    // tones, for both: the numeral sits on a light page), and the ink of text on a zone fill
    readonly property var zoneColors: light ? ["#2f6fdf", "#0b8576", "#57850f", "#9a6c00", "#bf5316", "#cc2649", "#8547d1"]
                                            : ["#8ab4ff", "#5fd8c6", "#b9e66e", "#ffcb52", "#ff8f52", "#ff5e7e", "#c487ff"]
    readonly property var zoneLight: light ? zoneColors
                                           : ["#dde8ff", "#d2f6f0", "#e9f7d2", "#fff1cc", "#ffdfcc", "#ffd3dc", "#eedcff"]
    readonly property color zoneInk: light ? "#ffffff" : "#141011"
    // text on a pill of Theme.text (the undo toast of the ride screen)
    readonly property color inverseText: light ? "#f5f3f8" : "#141318"
    readonly property var powerZoneNames: [qsTr("Recovery"), qsTr("Endurance"), qsTr("Tempo"), qsTr("Threshold"), qsTr("VO2 max"), qsTr("Anaerobic"), qsTr("Sprint")]
    readonly property var heartZoneNames: [qsTr("Easy"), qsTr("Endurance"), qsTr("Tempo"), qsTr("Threshold"), qsTr("Max")]
    // where each zone starts, as a share of FTP (power) or of max heart rate
    readonly property var powerZoneStarts: [0.555, 0.755, 0.905, 1.055, 1.205, 1.505]
    readonly property var heartZoneStarts: [savedZones.heart_rate_zone1 / 100, savedZones.heart_rate_zone2 / 100,
                                            savedZones.heart_rate_zone3 / 100, savedZones.heart_rate_zone4 / 100]

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

    // window size classes, as in Material 3: compact phones, medium (landscape phones, foldables,
    // small tablets), expanded (tablets). The shell switches navigation and panes on these.
    function compact(width) { return width < 600 }
    function expanded(width) { return width >= 840 }
    // side margin of the content: 16 on compact windows, 24 above
    function margin(width) { return width < 600 ? 16 : 24 }

    // sizes. Text follows the phone's font size (Android's font scale, set by main2.qml), up to
    // 1.25 times so the layouts still hold; numerals of 28 px and more keep their size, they are
    // already big and drawn to fit their room.
    property real textScale: 1
    function fs(px) {
        return px >= 28 ? px : Math.round(px * textScale)
    }
    readonly property int labelSize: fs(13)
    readonly property int tertiarySize: fs(12)
    readonly property int bodySize: fs(15)
    readonly property int titleSize: fs(19)

    // motion: the expressive curve overshoots a little, the effects curve does not
    readonly property var springCurve: [0.3, 1.35, 0.5, 1, 1, 1]
    readonly property var effectsCurve: [0.2, 0, 0, 1, 1, 1]
    readonly property int fast: 350
    readonly property int medium: 500
    readonly property int slow: 700
    readonly property int colorTime: 600
    property bool reduceMotion: false
    // true for a moment while the window changes shape (the phone turned, main2.qml): the layout
    // snaps to the new shape instead of springing there, and nothing slides through the screen
    property bool resizing: false
    // what a moving size or place animates with: off with reduce motion and while resizing
    readonly property bool layoutMotion: !reduceMotion && !resizing

    // Motion of the Signature pass: the M3 Expressive springs, as damping ratio / stiffness
    // (mass 1): fast spatial 0.6 / 800 (presses, toggles, small moves), default spatial 0.8 / 380
    // (rows, sheets, cards entering), slow spatial 0.8 / 200 (hero, zone crossings, page moves).
    // Effects (color, opacity) never bounce: the effects curve above, effectsTime long.
    //
    // As a SpringAnimation (or Behavior { SpringAnimation {...} }, which keeps the velocity when
    // the target changes mid-way): Qt 5.15 steps the spring in 16 ms ticks, about
    //   velocity += spring * distance - damping * velocity;  value += velocity * 0.016
    // so spring = 0.016 * stiffness and damping is about 0.016 * 2 * ratio * sqrt(stiffness),
    // trimmed by sampling a 0 to 100 move in qmlscene against the M3 step response:
    //   fast     spring 12.8 damping 0.48: overshoot 9.0% (M3 9.5%), half way 52 ms (52), settled 180 ms (208)
    //   default  spring 6.08 damping 0.45: overshoot 1.0% (1.5%), half way 76 ms (80), settled 176 ms (192)
    //   slow     spring 3.2  damping 0.33: overshoot 1.5% (1.5%), half way 104 ms (108), settled 244 ms (264)
    // epsilon is in the unit of the property: about 0.25 for pixels, 0.002 for scale and opacity.
    // The effects spring (1.0 / 1600) needs a damping over 1, which SpringAnimation clamps, so
    // effects use a NumberAnimation.
    //
    // As a NumberAnimation (easing.type: Easing.Bezier): the curves of the motion board, each with
    // the duration that reaches half way when the spring does:
    //   fast [0.34, 1.56, 0.64, 1] 400 ms, default [0.3, 1.35, 0.5, 1] 600 ms,
    //   slow [0.32, 1.18, 0.5, 1] 650 ms, effects [0.2, 0, 0, 1] 250 ms.
    readonly property real fastSpatialSpring: 12.8
    readonly property real fastSpatialDamping: 0.48
    readonly property real defaultSpatialSpring: 6.08
    readonly property real defaultSpatialDamping: 0.45
    readonly property real slowSpatialSpring: 3.2
    readonly property real slowSpatialDamping: 0.33
    readonly property var fastSpatialCurve: [0.34, 1.56, 0.64, 1, 1, 1]
    readonly property var defaultSpatialCurve: [0.3, 1.35, 0.5, 1, 1, 1]
    readonly property var slowSpatialCurve: [0.32, 1.18, 0.5, 1, 1, 1]
    readonly property int fastSpatialTime: 400
    readonly property int defaultSpatialTime: 600
    readonly property int slowSpatialTime: 650
    readonly property int effectsTime: 250
    // the entrance of a page: each item rises 10 and fades in, 80 ms after the one before
    readonly property int riseTime: 700
    readonly property int riseStagger: 80
    readonly property int riseDistance: 10

    // Signature type and shapes
    readonly property int capSize: fs(11)
    readonly property real capSpacing: 1.5
    readonly property int heroRadius: 32
    readonly property color raisedBorder: overlay(light ? 0.08 : 0.05)
    readonly property color rest: light ? "#dcd9e2" : "#2a2a30"

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
