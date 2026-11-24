import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    required property real regionX
    required property real regionY
    required property real regionWidth
    required property real regionHeight
    required property real mouseX
    required property real mouseY
    required property color color
    required property color overlayColor
    property bool showAimLines: Config.options.regionSelector.rect.showAimLines

    property bool breathingBorderOnly: false

    // Overlay to darken screen
    // Base dark overlay around region
    Rectangle {
        id: darkenOverlay
        z: 1
        visible: !root.breathingBorderOnly
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: root.regionX - darkenOverlay.border.width
            topMargin: root.regionY - darkenOverlay.border.width
        }
        width: root.regionWidth + darkenOverlay.border.width * 2
        height: root.regionHeight + darkenOverlay.border.width * 2
        color: "transparent"
        border.color: root.overlayColor
        border.width: Math.max(root.width, root.height)
    }

    Rectangle { // the selection: a crisp white hairline (breathes while recording)
        id: selectionBorder
        z: 9
        x: Math.round(root.regionX) - 1
        y: Math.round(root.regionY) - 1
        width: Math.round(root.regionWidth) + 2
        height: Math.round(root.regionHeight) + 2
        color: "transparent"
        border.width: 1.5
        border.color: root.color
        opacity: 0.95
        SequentialAnimation on opacity {
            running: root.breathingBorderOnly
            loops: Animation.Infinite
            NumberAnimation { from: 0.95; to: 0.3; duration: 1200; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.3; to: 0.95; duration: 1200; easing.type: Easing.InOutQuad }
        }
    }
    Repeater { // macOS-style handles at the corners and edge midpoints
        model: (root.breathingBorderOnly || root.regionWidth < 24 || root.regionHeight < 24) ? [] : [[0,0],[0.5,0],[1,0],[0,0.5],[1,0.5],[0,1],[0.5,1],[1,1]]
        delegate: Rectangle {
            required property var modelData
            z: 10
            width: 9
            height: 9
            radius: 4.5
            color: "white"
            border.width: 0.5
            border.color: Qt.rgba(0, 0, 0, 0.35)
            x: selectionBorder.x + selectionBorder.width * modelData[0] - width / 2
            y: selectionBorder.y + selectionBorder.height * modelData[1] - height / 2
        }
    }

    Rectangle { // size, in a small dark capsule under the selection
        z: 10
        visible: !root.breathingBorderOnly && root.regionWidth > 0
        anchors { top: selectionBorder.bottom; horizontalCenter: selectionBorder.horizontalCenter; topMargin: 10 }
        width: sizeText.implicitWidth + 18
        height: 24
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.62)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        GlassText {
            id: sizeText
            anchors.centerIn: parent
            text: `${Math.round(root.regionWidth)} × ${Math.round(root.regionHeight)}`
            numeric: true
            font.pixelSize: Glass.size.caption
            font.weight: Font.DemiBold
            color: "white"
        }
    }

    // Coord lines
    Rectangle { // Vertical
        visible: root.showAimLines && !root.breathingBorderOnly
        opacity: 0.2
        z: 2
        x: root.mouseX
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        width: 1
        color: root.color
    }
    Rectangle { // Horizontal
        visible: root.showAimLines && !root.breathingBorderOnly
        opacity: 0.2
        z: 2
        y: root.mouseY
        anchors {
            left: parent.left
            right: parent.right
        }
        height: 1
        color: root.color
    }
}
