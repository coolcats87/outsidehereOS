pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * iOS segmented control: a capsule track with a sliding raised pill under the current item.
 * model: [{ icon, label }]
 */
Item {
    id: root
    property var model: []
    property int currentIndex: 0
    signal selected(int index)

    implicitHeight: 32
    implicitWidth: 240
    readonly property real segW: root.model.length > 0 ? (root.width - 4) / root.model.length : 0

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Glass.track
    }
    Rectangle { // the raised pill
        x: 2 + root.currentIndex * root.segW
        y: 2
        width: root.segW
        height: root.height - 4
        radius: height / 2
        color: Glass.platterHover
        border.width: 0.5
        border.color: Glass.separator
        Behavior on x { SpringAnimation { spring: Glass.spring.snappySpring; damping: Glass.spring.snappyDamping; epsilon: 0.25 } }
    }
    Row {
        x: 2
        y: 2
        Repeater {
            model: root.model
            delegate: Item {
                id: seg
                required property var modelData
                required property int index
                width: root.segW
                height: root.height - 4
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (seg.modelData.icon ?? "").length > 0
                        text: seg.modelData.icon ?? ""
                        iconSize: 16
                        fill: root.currentIndex === seg.index ? 1 : 0
                    }
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.modelData.label ?? ""
                        font.pixelSize: Glass.size.footnote
                        font.weight: root.currentIndex === seg.index ? Font.DemiBold : Font.Medium
                        color: root.currentIndex === seg.index ? Glass.label : Glass.secondaryLabel
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.currentIndex = seg.index; root.selected(seg.index); }
                }
            }
        }
    }
}
