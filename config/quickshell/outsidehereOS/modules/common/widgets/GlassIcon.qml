import qs.modules.common
import QtQuick

/**
 * Icon glyph for the Apple look. SF Symbols isn't available on Linux, so this uses
 * Material Symbols Rounded tuned to sit closer to it: medium weight, filled by default
 * (Control Center style), no grade. Takes Material Symbols names.
 */
Text {
    id: root
    property real iconSize: 18
    property real fill: 1
    property int weight: 500

    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: Glass.label
    font {
        family: Glass.iconFamily
        pixelSize: root.iconSize
        hintingPreference: Font.PreferNoHinting
        variableAxes: ({
            "FILL": root.fill >= 0.5 ? 1 : 0,
            "wght": root.weight,
            "GRAD": 0,
            "opsz": Math.max(20, Math.min(48, root.iconSize))
        })
    }
}
