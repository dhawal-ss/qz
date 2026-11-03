import QtQuick 2.15
import QtQuick.Window 2.15
import AndroidStatusBar 1.0

// System bar and display cutout insets in dp, from QZ's AndroidStatusBar (CustomQtActivity.java
// sends them). The shell loads this file through a Loader, so a preview without the C++ type
// falls back to no insets. Same rules as main.qml: Android 12 and later draw under the bars.
Item {
    readonly property bool active: Qt.platform.os === "android" && AndroidStatusBar.apiLevel >= 31
    readonly property bool landscape: Screen.orientation === Qt.LandscapeOrientation
                                      || Screen.orientation === Qt.InvertedLandscapeOrientation
    readonly property int insetTop: active ? AndroidStatusBar.height : 0
    readonly property int insetBottom: active ? AndroidStatusBar.navigationBarHeight : 0
    // the cutout counts too: content stays clear of the camera on the side in landscape
    readonly property int insetLeft: active && landscape ? AndroidStatusBar.leftInset : 0
    readonly property int insetRight: active && landscape ? AndroidStatusBar.rightInset : 0
}
