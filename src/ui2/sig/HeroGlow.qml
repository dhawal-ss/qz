import QtQuick 2.15
import ".."

// The soft glow of a hero in its tint, breathing once every 4 s between two strengths, as the
// boards draw it (a blurred disc at about a quarter strength). Put it behind the hero, and
// outside any clipping Flickable when it should reach into the top of the screen.
Glow {
    id: heroGlow

    property real low: 0.36
    property real high: 0.52
    // how many breaths each time it shows, 0 for as long as it shows
    property int breaths: 0

    breathing: false
    opacity: low

    SequentialAnimation on opacity {
        running: !Theme.reduceMotion && heroGlow.visible
        loops: heroGlow.breaths > 0 ? heroGlow.breaths : Animation.Infinite
        NumberAnimation { from: heroGlow.low; to: heroGlow.high; duration: heroGlow.beat / 2; easing.type: Easing.InOutSine }
        NumberAnimation { from: heroGlow.high; to: heroGlow.low; duration: heroGlow.beat / 2; easing.type: Easing.InOutSine }
    }
}
