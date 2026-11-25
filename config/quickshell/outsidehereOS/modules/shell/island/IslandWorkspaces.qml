pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Only the workspaces that exist (are occupied or focused) on this monitor.
 * Collapsed: small dots, the active one stretched into a pill. Expanded: numbered chips.
 */
Row {
    id: root
    required property var screen
    property bool big: false
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
    readonly property string monitorName: root.screen?.name ?? ""
    readonly property var monitorData: HyprlandData.monitors.find(m => m.name === root.monitorName)
    readonly property int activeId: root.monitorData?.activeWorkspace?.id ?? root.monitor?.activeWorkspace?.id ?? -1
    // hyprctl-backed (HyprlandData): Quickshell's own Hyprland.workspaces stays empty on this setup
    readonly property var workspaces: {
        const list = HyprlandData.workspaces
            .filter(w => w.id > 0 && w.monitor === root.monitorName)
            .map(w => ({ id: w.id }));
        if (root.activeId > 0 && !list.some(w => w.id === root.activeId))
            list.push({ id: root.activeId });
        return list.sort((a, b) => a.id - b.id);
    }

    readonly property real dotSize: big ? 26 : 8
    spacing: big ? 6 : 5

    Repeater {
        model: ScriptModel {
            values: root.workspaces
            objectProp: "id"
        }
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool active: modelData.id === root.activeId
            anchors.verticalCenter: parent?.verticalCenter
            implicitHeight: root.dotSize
            implicitWidth: active ? root.dotSize * (root.big ? 1.7 : 2.6) : root.dotSize
            radius: height / 2
            // Page-indicator style: the active one a bright capsule, the rest dim
            color: root.big
                ? (active ? Glass.label : chipMouse.containsMouse ? Glass.fillPressed : Glass.fill)
                : (active ? Glass.label : chipMouse.containsMouse ? Glass.secondaryLabel : Glass.tertiaryLabel)

            Behavior on implicitWidth {
                SpringAnimation { spring: Glass.spring.snappySpring; damping: Glass.spring.snappyDamping; epsilon: 0.25 }
            }
            Behavior on color {
                ColorAnimation { duration: Glass.duration.fast }
            }

            GlassText {
                anchors.centerIn: parent
                visible: root.big
                text: chip.modelData.id
                numeric: true
                font.pixelSize: Glass.size.footnote
                font.weight: Font.DemiBold
                color: chip.active ? (Glass.dark ? "#000000" : "#FFFFFF") : Glass.label
            }

            MouseArea {
                id: chipMouse
                anchors.fill: parent
                anchors.margins: root.big ? 0 : -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace = ${chip.modelData.id}})`)
                onWheel: wheel => Hyprland.dispatch(`hl.dsp.focus({workspace = "${wheel.angleDelta.y < 0 ? "r+1" : "r-1"}"})`)
            }
        }
    }
}
