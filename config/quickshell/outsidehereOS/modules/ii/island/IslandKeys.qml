pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

/**
 * Keystroke dropdown. Unfolds from `topY` (the screen's top edge when the pill is hidden, or just
 * below the pill) showing the latest stroke: one key, or "A + B" for keys held together, with the
 * Arch logo for Super. Folds back up after a short pause. Display only: never takes input.
 */
Item {
    id: root
    property real topY: 0
    property bool attachedToEdge: true   // hanging from the screen edge: square top, rounded bottom
    property bool active: true           // false = another copy is showing the stroke (e.g. in the launcher)
    readonly property bool open: root.active && Keystrokes.showing

    readonly property real padV: 7
    readonly property real padH: 10
    readonly property real contentH: keysRow.implicitHeight + padV * 2
    x: (parent.width - width) / 2
    y: root.topY
    width: keysRow.implicitWidth + padH * 2
    height: root.open ? contentH : 0
    clip: true
    visible: height > 0.5
    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on height {
        NumberAnimation {
            duration: root.open ? 160 : 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Glass.curve.smooth : Glass.curve.exit
        }
    }

    GlassSurface { // background; content is pinned to its bottom so it slides down as it unfolds
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // When hanging from the edge, push the top corners above the screen so only the bottom ones show
        height: root.contentH + (root.attachedToEdge ? radius : 0)
        radius: 16
        tint: Glass.regular
        shadow: false // the dropdown clips to its own box, a shadow would be cut off

        Row {
            id: keysRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.padV
            spacing: 6

            Repeater {
                model: Keystrokes.keys
                delegate: Row {
                    id: entry
                    required property var modelData
                    required property int index
                    spacing: 6
                    GlassText { // "+" between keys
                        visible: entry.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+"
                        color: Glass.tertiaryLabel
                        font.pixelSize: Glass.size.subheadline
                    }
                    Rectangle { // keycap
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: Math.max(28, capText.implicitWidth + 16)
                        radius: 8
                        color: Glass.fill
                        border.width: 1
                        border.color: Glass.separator
                        Text {
                            id: capText
                            anchors.centerIn: parent
                            // U+F303: Arch Linux logo (Nerd Font)
                            text: entry.modelData.isSuper ? "" : entry.modelData.label
                            font.family: entry.modelData.isSuper ? "JetBrainsMono Nerd Font" : Glass.fontFamily
                            font.pixelSize: entry.modelData.isSuper ? 17 : Glass.size.subheadline
                            font.weight: Font.DemiBold
                            color: entry.modelData.isSuper ? "#1793D1" : Glass.label // Arch blue
                        }
                    }
                }
            }
        }
    }
}
