pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 300
    minimumHeight: 200
    property list<var> resources: [
        {
            "icon": "planner_review",
            "name": Translation.tr("CPU"),
            "history": ResourceUsage.cpuUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableCpuString
        },
        {
            "icon": "memory",
            "name": Translation.tr("RAM"),
            "history": ResourceUsage.memoryUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableMemoryString
        },
        {
            "icon": "swap_horiz",
            "name": Translation.tr("Swap"),
            "history": ResourceUsage.swapUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableSwapString
        },
    ]

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 4
        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: parent.padding
            }
            spacing: 8

            GlassSegmented {
                id: tabBar
                Layout.fillWidth: true
                Layout.margins: 4
                model: root.resources.map(r => ({ icon: r.icon, label: r.name }))
                currentIndex: Persistent.states.overlay.resources.tabIndex
                onSelected: index => Persistent.states.overlay.resources.tabIndex = index
            }

            ResourceSummary {
                Layout.margins: 8
                history: root.resources[tabBar.currentIndex]?.history ?? []
                maxAvailableString: root.resources[tabBar.currentIndex]?.maxAvailableString ?? "--"
            }
        }
    }

    component ResourceSummary: RowLayout {
        id: resourceSummary
        required property list<real> history
        required property string maxAvailableString
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        ColumnLayout {
            spacing: 2
            GlassText {
                text: (resourceSummary.history[resourceSummary.history.length - 1] * 100).toFixed(1) + "%"
                numeric: true
                font.family: Glass.fontRounded
                font.pixelSize: Glass.size.title2
                font.weight: Font.Bold
            }
            GlassText {
                text: Translation.tr("of %1").arg(resourceSummary.maxAvailableString)
                font.pixelSize: Glass.size.caption
                color: Glass.secondaryLabel
            }
            Item {
                Layout.fillHeight: true
            }
        }
        Rectangle {
            id: graphBg
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: Glass.fill
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: graphBg.width
                    height: graphBg.height
                    radius: graphBg.radius
                }
            }
            Graph {
                anchors.fill: parent
                values: root.resources[tabBar.currentIndex]?.history ?? []
                points: ResourceUsage.historyLength
                alignment: Graph.Alignment.Right
                color: Glass.accent
                fillOpacity: 0.35
            }
        }
    }
}
