import QtQuick 2.15
import ".."

// The hero of a screen: the Pulse in one tint, breathing once every 4 s and turning slowly, with
// one number and one word inside it, and a soft glow of the same tint breathing behind it.
// The number rolls when it changes; the shape morphs when the zone changes.
Item {
    id: hero

    property string value: ""
    property string word: ""
    property int zone: 2
    property color tint: Theme.accent
    property color ink: Theme.accentInk
    property string summary: ""        // for the screen reader: "Ready 82, a good day"
    property bool glow: true
    property real glowSize: width * 3.2
    // the glow breathes between these
    property real glowLow: 0.3
    property real glowHigh: 0.46
    property int beat: 4000
    // how many breaths (and turns of the Pulse) each time it shows, 0 for as long as it shows
    property int breaths: 0

    implicitWidth: 136
    implicitHeight: 136
    Accessible.role: Accessible.Graphic
    Accessible.name: summary !== "" ? summary : (word + " " + value)

    // behind everything, wider than the hero: it may reach out of the item
    HeroGlow {
        visible: hero.glow
        width: hero.glowSize
        height: hero.glowSize
        anchors.centerIn: parent
        tint: hero.tint
        beat: hero.beat
        low: hero.glowLow
        high: hero.glowHigh
        breaths: hero.breaths
    }

    Item {
        id: breather
        anchors.fill: parent
        SequentialAnimation on scale {
            id: breath
            running: !Theme.reduceMotion && hero.visible
            loops: hero.breaths > 0 ? hero.breaths : Animation.Infinite
            NumberAnimation { from: 1; to: 1.035; duration: hero.beat / 2; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.035; to: 1; duration: hero.beat / 2; easing.type: Easing.InOutSine }
        }
        // the shape fills the hero: the Pulse reaches about 42.5 of its 108 box
        Pulse {
            width: hero.width * 108 / 85
            height: width
            anchors.centerIn: parent
            zone: hero.zone
            color: hero.tint
            turning: hero.breaths > 0 ? breath.running : true
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4
        RollingNumber {
            anchors.horizontalCenter: parent.horizontalCenter
            value: hero.value
            color: hero.ink
            font.family: Theme.celebrate
            // three digits fit the shape; a longer value gets smaller
            font.pixelSize: Math.round(hero.width * 0.36 * Math.min(1, 3 / Math.max(1, hero.value.length)))
            Accessible.ignored: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: hero.word
            color: hero.ink
            font.family: Theme.bodySemibold
            font.pixelSize: Math.max(11, Math.round(hero.width * 0.09))
            Accessible.ignored: true
        }
    }
}
