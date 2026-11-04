import QtQuick 2.15
import QtQuick.Shapes 1.15

// The stroke glyphs of Goals, on the 24 x 24 grid of Icon: badge marks, the freeze and the rest week.
Item {
    id: glyph

    property string name: "spark"
    property color color: Theme.light ? Theme.text : "white"
    property real size: 24
    property real weight: 2.2

    width: size
    height: size
    Accessible.ignored: true
    // drawn at its own size, so a big glyph stays sharp
    layer.enabled: true
    layer.samples: 4

    readonly property var paths: ({
        spark: "M12 3Q13 11 21 12Q13 13 12 21Q11 13 3 12Q11 11 12 3Z",
        wheel: "M12 21A9 9 0 1 0 12 3A9 9 0 1 0 12 21ZM12 14A2 2 0 1 0 12 10A2 2 0 1 0 12 14ZM12 3L12 10M12 14L12 21M3 12L10 12M14 12L21 12",
        sun: "M3 18L21 18M7.5 18A4.5 4.5 0 0 1 16.5 18M12 5L12 9M5.6 9.6L7.6 11.6M18.4 9.6L16.4 11.6",
        moon: "M20 14.5A8 8 0 1 1 9.5 4A6.5 6.5 0 0 0 20 14.5Z",
        road: "M8 3L5 21M16 3L19 21M12 4L12 7M12 10.5L12 13.5M12 17L12 20",
        bolt: "M13 3L5 14L12 14L11 21L19 10L12 10Z",
        clock: "M12 21A9 9 0 1 0 12 3A9 9 0 1 0 12 21ZM12 7L12 12L15.5 14",
        week: "M4 6L20 6L20 19L4 19ZM4 10L20 10M8 3L8 7M16 3L16 7M8 14L8 15M12 14L12 15M16 14L16 15",
        flame: "M12 3C13 7 17 8.5 17 13.5A5 5 0 0 1 7 13.5C7 11 8.5 9.5 9.5 8.5C9.5 10.5 10.5 11.5 11.5 11.5C11.5 8 10.5 5.5 12 3Z",
        trophy: "M8 4L16 4L16 9A4 4 0 0 1 8 9ZM8 6L5 6Q5 10 8 10M16 6L19 6Q19 10 16 10M12 13L12 17M8 20L16 20M10 17L14 17",
        route: "M4 20L9 13L13 16L20 5M20 5L20 10M20 5L15 5",
        globe: "M12 21A9 9 0 1 0 12 3A9 9 0 1 0 12 21ZM3 12L21 12M12 3Q6.5 12 12 21M12 3Q17.5 12 12 21",
        target: "M12 21A9 9 0 1 0 12 3A9 9 0 1 0 12 21ZM12 16A4 4 0 1 0 12 8A4 4 0 1 0 12 16ZM12 12L12 12.1",
        freeze: "M12 3L12 21M4.2 7.5L19.8 16.5M4.2 16.5L19.8 7.5M9.5 4.5L12 7L14.5 4.5M9.5 19.5L12 17L14.5 19.5",
        lock: "M8 11L8 7A4 4 0 0 1 16 7L16 11M7 11L17 11Q19 11 19 13L19 19Q19 21 17 21L7 21Q5 21 5 19L5 13Q5 11 7 11Z",
        check: "M5 12.5L10 17.5L19 7",
        // the Pause goals sheet and the habit screens, from the Habits board
        thermometer: "M10 13.5V5a2 2 0 0 1 4 0v8.5a4 4 0 1 1-4 0zM12 9.5v6",
        bandage: "M10.94 18.72L18.72 10.94A4 4 0 0 0 13.06 5.28L5.28 13.06A4 4 0 0 0 10.94 18.72ZM12 8.46L15.54 12L12 15.54L8.46 12Z",
        suitcase: "M6.5 7L17.5 7Q20.5 7 20.5 10L20.5 17Q20.5 20 17.5 20L6.5 20Q3.5 20 3.5 17L3.5 10Q3.5 7 6.5 7ZM9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M8 7v13M16 7v13",
        more: "M12 21A9 9 0 1 0 12 3A9 9 0 1 0 12 21ZM8 12h.01M12 12h.01M16 12h.01",
        pause: "M9 6v12M15 6v12",
        calendar: "M8 4.5L16 4.5Q20.5 4.5 20.5 9L20.5 16Q20.5 20.5 16 20.5L8 20.5Q3.5 20.5 3.5 16L3.5 9Q3.5 4.5 8 4.5ZM3.5 9.5h17M8.5 2.5v4M15.5 2.5v4",
        chevron: "M9 6l6 6-6 6",
        back: "M15 6l-6 6 6 6",
        close: "M6 6l12 12M18 6L6 18",
        share: "M12 15V3M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6",
        download: "M12 3v12M7 10l5 5 5-5M5 21h14",
        strava: "M5 19l7-14 7 14M9 13h6",
        down: "M6 9l6 6 6-6"
    })

    Shape {
        width: 24
        height: 24
        scale: glyph.size / 24
        transformOrigin: Item.TopLeft
        ShapePath {
            strokeColor: glyph.color
            strokeWidth: glyph.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: glyph.paths[glyph.name] || "" }
        }
    }
}
