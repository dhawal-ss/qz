import QtQuick 2.15
import ".."

// A SpringAnimation with one of the M3 Expressive spatial springs of Theme: "fast", "default" or
// "slow". Use it in a Behavior, so a new target mid-way keeps the speed it has:
//   Behavior on width { enabled: !Theme.reduceMotion; Spring { token: "fast" } }
// epsilon is in the unit of the property: 0.25 suits pixels, 0.002 scale and opacity.
SpringAnimation {
    property string token: "default"

    spring: token === "fast" ? Theme.fastSpatialSpring : (token === "slow" ? Theme.slowSpatialSpring : Theme.defaultSpatialSpring)
    damping: token === "fast" ? Theme.fastSpatialDamping : (token === "slow" ? Theme.slowSpatialDamping : Theme.defaultSpatialDamping)
    epsilon: 0.25
}
