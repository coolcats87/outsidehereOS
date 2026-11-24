import qs.modules.common
import QtQuick

/**
 * Tiny bouncing bars: the "something is playing" hint in the collapsed pill.
 */
Row {
    id: root
    property bool playing: true
    property color color: Glass.label
    property real barHeight: 12
    spacing: 2
    height: barHeight

    Repeater {
        model: 4
        delegate: Rectangle {
            id: bar
            required property int index
            anchors.bottom: parent.bottom
            width: 2.5
            radius: 1.25
            color: root.color
            height: root.barHeight * 0.3
            SequentialAnimation on height {
                running: root.playing && root.visible
                loops: Animation.Infinite
                NumberAnimation {
                    to: root.barHeight * [0.9, 0.55, 1.0, 0.7][bar.index]
                    duration: [380, 300, 440, 340][bar.index]
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.barHeight * [0.3, 0.2, 0.4, 0.25][bar.index]
                    duration: [340, 420, 300, 380][bar.index]
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
