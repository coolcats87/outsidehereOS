import qs.modules.common
import QtQuick

/**
 * Button in the Apple look: no ripple. A vibrant fill that brightens on hover, a springy
 * press-in, and the accent colour when toggled (Control Center style).
 *
 * Shows `icon` (Material Symbols name) and/or `text`. Children placed inside go on top,
 * for custom content.
 */
Item {
    id: root

    property string icon: ""
    property string text: ""
    property real iconSize: 18
    property int textSize: Glass.size.callout
    property bool toggled: false
    property bool flat: false           // no fill until hovered
    property bool danger: false         // red when toggled/highlighted
    property bool highlighted: false    // accent fill without being a toggle
    property color accent: root.danger ? Glass.red : Glass.accent
    property real radius: Math.min(width, height) / 2
    property real padding: 12
    property real iconFill: 1
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property bool on: root.toggled || root.highlighted

    property color colBackground: root.flat ? "transparent" : Glass.fill
    property color colBackgroundHover: Glass.fillHover
    property color colForeground: root.on ? Glass.accentLabel : Glass.label

    signal clicked()
    signal pressAndHold()

    implicitHeight: 36
    implicitWidth: root.text.length > 0 ? row.implicitWidth + root.padding * 2 : implicitHeight
    opacity: root.enabled ? 1 : 0.4

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: root.on ? root.accent
            : root.pressed ? Glass.fillPressed
            : root.hovered ? root.colBackgroundHover
            : root.colBackground
        Behavior on color { ColorAnimation { duration: Glass.duration.fast } }
        scale: root.pressed ? 0.92 : 1
        Behavior on scale { SpringAnimation { spring: Glass.spring.snappySpring; damping: Glass.spring.snappyDamping; epsilon: 0.002 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.icon.length > 0
                text: root.icon
                iconSize: root.iconSize
                fill: root.iconFill
                color: root.colForeground
                Behavior on color { ColorAnimation { duration: Glass.duration.fast } }
            }
            GlassText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.text.length > 0
                text: root.text
                font.pixelSize: root.textSize
                font.weight: Font.Medium
                color: root.colForeground
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
    }
}
