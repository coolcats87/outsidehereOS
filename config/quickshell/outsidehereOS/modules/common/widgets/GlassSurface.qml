import qs.modules.common
import QtQuick

/**
 * A Liquid Glass pane (Apple look). Put content inside it like a Rectangle.
 * The blur of what is behind comes from Hyprland (blur layer rule on the window's
 * namespace); this draws the tint, the lit rim, the bevel glow, the sheen and the
 * shadow in one shader pass (../shaders/glasssurface.frag), so it is cheap to
 * resize every frame while the island morphs.
 */
Item {
    id: root

    property real radius: Glass.radiusLarge
    property color tint: Glass.regular
    property color outline: Glass.outline
    property real rimWidth: 1.2
    property real rimStrength: Glass.rimStrength
    property real rimBase: Glass.rimBase
    property real glow: Glass.glow
    property real bezel: Math.min(10, root.radius * 0.4)
    property real sheen: Glass.sheen
    property real lightAngle: Glass.lightAngle
    property bool shadow: false // off by default: the glass floats without a drop shadow
    property color shadowColor: Glass.shadow
    property real shadowBlur: 28
    property real shadowOffsetY: 8
    // Clip the content to the pane's box (not its rounded corners: keep content padded)
    property bool clipContent: false

    default property alias content: contentItem.data
    readonly property alias contentItem: contentItem

    ShaderEffect {
        id: fx
        readonly property real pad: root.shadow ? Math.ceil(root.shadowBlur + Math.abs(root.shadowOffsetY)) : 1
        x: -pad
        y: -pad
        width: root.width + pad * 2
        height: root.height + pad * 2
        visible: root.width > 0.5 && root.height > 0.5

        property vector2d itemSize: Qt.vector2d(width, height)
        property real radius: root.radius
        property color tint: root.tint
        property color outline: root.outline
        property real rimWidth: root.rimWidth
        property real rimStrength: root.rimStrength
        property real rimBase: root.rimBase
        property real glow: root.glow
        property real bezel: root.bezel
        property real sheen: root.sheen
        property real lightAngle: root.lightAngle
        property color shadowColor: root.shadow ? root.shadowColor : "transparent"
        property real shadowBlur: root.shadowBlur
        property real shadowOffsetY: root.shadowOffsetY

        fragmentShader: Qt.resolvedUrl("../shaders/glasssurface.frag.qsb")
    }

    Item {
        id: contentItem
        anchors.fill: parent
        clip: root.clipContent
    }
}
