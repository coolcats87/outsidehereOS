import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Tooltip in the Apple look: a small glass capsule that fades and scales in.
 * Shows while its parent reports `hovered` (GlassButton does).
 */
ToolTip {
    id: root
    property bool extraVisibleCondition: true
    readonly property bool shown: root.extraVisibleCondition && (parent?.hovered ?? false)

    delay: 350
    visible: shown
    padding: 0
    background: null
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Glass.duration.fast }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Glass.duration.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Glass.duration.fast }
    }

    contentItem: GlassSurface {
        implicitWidth: label.implicitWidth + 20
        implicitHeight: label.implicitHeight + 10
        radius: height / 2
        tint: Glass.thick
        shadowBlur: 12
        shadowOffsetY: 3
        GlassText {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.pixelSize: Glass.size.footnote
            font.weight: Font.Medium
        }
    }
}
