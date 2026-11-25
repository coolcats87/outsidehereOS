import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Widgets

/**
 * A notification's icon, iOS style (rounded square): its image, else the app icon, else a
 * glyph guessed from the summary. Images of notifications restored after a shell restart
 * point at dead handles, so a failed image falls back too.
 */
ClippingRectangle {
    id: root
    property var notif: null
    property real size: 34
    readonly property bool imageOk: notifImage.status === Image.Ready
    readonly property bool hasAppIcon: (root.notif?.appIcon ?? "") !== ""

    implicitWidth: root.size
    implicitHeight: root.size
    radius: Math.round(root.size * 0.26)
    color: root.imageOk || root.hasAppIcon ? "transparent" : Glass.fillStrong

    Image {
        id: notifImage
        anchors.fill: parent
        visible: root.imageOk
        source: root.notif?.image ?? ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
    }
    IconImage {
        anchors.fill: parent
        visible: !root.imageOk && root.hasAppIcon
        source: visible ? Quickshell.iconPath(root.notif.appIcon, "image-missing") : ""
        asynchronous: true
    }
    GlassIcon {
        anchors.centerIn: parent
        visible: !root.imageOk && !root.hasAppIcon
        text: NotificationUtils.findSuitableMaterialSymbol(root.notif?.summary ?? "")
        iconSize: root.size * 0.55
    }
}
