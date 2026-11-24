import qs.modules.common
import QtQuick

/**
 * Control Center slider: a thick capsule whose bright fill grows with the value, with the
 * icon sitting inside it. Drag or click anywhere; scroll to nudge.
 * `moved()` fires only for user changes (like Slider.moved).
 */
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    property string icon: ""
    property real stepSize: 0.05
    readonly property bool pressed: drag.pressed
    readonly property real position: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    signal moved()

    implicitHeight: 30
    implicitWidth: 200

    // While dragging, the fill follows the pointer exactly; otherwise it eases to the value
    property real shownPosition: root.position
    Behavior on shownPosition {
        enabled: !root.pressed
        SpringAnimation { spring: Glass.spring.snappySpring; damping: 0.6; epsilon: 0.001 }
    }

    function setFromX(x) {
        const pos = Math.max(0, Math.min(1, x / root.width));
        root.value = root.from + pos * (root.to - root.from);
        root.moved();
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Glass.track
        // grows a touch while held, like iOS
        scale: root.pressed ? 1.02 : 1
        Behavior on scale { SpringAnimation { spring: Glass.spring.snappySpring; damping: Glass.spring.snappyDamping; epsilon: 0.002 } }

        Item {
            anchors.fill: parent
            clip: true
            Rectangle { // the fill, as a capsule clipped to the track
                height: parent.height
                // never narrower than a circle, so the left end stays round at 0
                width: Math.max(track.height, track.width * root.shownPosition)
                radius: height / 2
                color: Glass.sliderFill
            }
        }

        GlassIcon {
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            x: (track.height - width) / 2
            text: root.icon
            iconSize: 16
            color: Glass.sliderGlyph
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.setFromX(mouse.x); }
        onWheel: wheel => {
            const dir = (wheel.angleDelta.y || -wheel.angleDelta.x) > 0 ? 1 : -1;
            root.value = Math.max(root.from, Math.min(root.to, root.value + dir * root.stepSize * (root.to - root.from)));
            root.moved();
        }
    }
}
