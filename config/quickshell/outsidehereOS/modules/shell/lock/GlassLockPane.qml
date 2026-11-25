import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Widgets

/**
 * Liquid Glass pane for the lock screen. Hyprland's blur can't reach a session-lock
 * surface, so the lock draws its own wallpaper and a blurred copy of it (`blurSource`);
 * this pane shows the piece of that blurred copy that sits right behind it, clipped to
 * its rounded shape, with the usual glass tint/rim/gloss (GlassSurface) on top.
 */
Item {
    id: root
    required property Item blurSource   // full-size blurred wallpaper, in the lock surface's coordinates
    property real radius: height / 2
    property color tint: Glass.clear
    property real mapTick: 0             // bump while an ancestor moves/scales so the blur follows
    default property alias content: holder.data

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: root.blurSource
            live: true
            sourceRect: {
                root.mapTick; root.x; root.y; root.width; root.height; // dependencies
                const p = root.mapToItem(root.blurSource, 0, 0);
                return Qt.rect(p.x, p.y, root.width, root.height);
            }
        }
    }
    GlassSurface {
        anchors.fill: parent
        radius: root.radius
        tint: root.tint
    }
    Item {
        id: holder
        anchors.fill: parent
    }
}
