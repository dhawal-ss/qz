import QtQuick 2.12

// The colours of the dashboard (Dark). Every text colour is at least 4.5:1 on `surface`.
// A setting still at its old stock value takes the token (pick), so riders who chose their own
// colours keep them.
QtObject {
    readonly property color bg: "#111214"
    readonly property color chrome: "#111214"
    readonly property color surface: "#1C1D21"
    readonly property color surfaceRaised: "#26282D"
    readonly property color surfacePressed: "#303238"
    readonly property color stroke: "#2E2F33"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#A1A1A8"
    readonly property color textOnTint: "#C7C7CC"
    readonly property color go: "#30D158"
    readonly property color caution: "#FFD60A"
    readonly property color cautionTonal: "#3C3512"
    readonly property color danger: "#FF5A4F"
    readonly property color dangerTonal: "#412020"
    readonly property color info: "#409CFF"
    readonly property color infoTonal: "#192B3E"

    readonly property real tileRadius: 12
    readonly property real cardRadius: 16

    // Power zones 1-7 (Recovery ... Neuromuscular); heart rate zones 1-5 use 1, 2, 3, 5 and 6, so
    // red is the top zone on both scales
    readonly property var powerZones: ["#8E8E93", "#409CFF", "#30D158", "#FFD60A", "#FF9F0A", "#FF5A4F", "#C77DFF"]

    // The stored colour, or the token when it is still the old stock value (any letter case)
    function pick(stored, legacy, token) {
        if (stored === undefined || stored === null || String(stored).toLowerCase() === String(legacy).toLowerCase())
            return token
        return stored
    }

    // The colour C++ gives a tile value: "white" is the primary text, "green" (2.6:1 on the tiles)
    // the green of the palette; any other colour as it is
    function valueColor(name) {
        if (name === "white")
            return textPrimary
        if (name === "green")
            return go
        return name
    }

    function zoneColor(zone, count) {
        if (zone < 1)
            return "transparent"
        var index = count === 5 ? [0, 1, 2, 4, 5][Math.min(zone, 5) - 1] : Math.min(zone, 7) - 1
        return powerZones[index]
    }
}
