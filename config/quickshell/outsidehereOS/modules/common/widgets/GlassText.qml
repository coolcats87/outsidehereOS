import qs.modules.common
import QtQuick

/**
 * Text in the Apple look: SF Pro / Inter, Apple's text-style sizes, label colours.
 * `numeric: true` switches to tabular figures (clocks, percentages) so digits don't jiggle.
 */
Text {
    id: root
    property bool numeric: false

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    color: Glass.label
    linkColor: Glass.accent
    font {
        family: Glass.fontFamily
        pixelSize: Glass.size.body
        hintingPreference: Font.PreferDefaultHinting
        features: root.numeric ? { "tnum": 1 } : {}
    }
}
