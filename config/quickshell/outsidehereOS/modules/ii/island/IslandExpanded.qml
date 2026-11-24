pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

/**
 * What the island shows when it opens up (Liquid Glass look): clock & date, workspaces,
 * battery & power mode, now playing with synced lyrics, CPU/GPU/RAM/swap, and
 * Notification Center on the side.
 */
Item {
    id: root
    required property var screen
    property bool shown: false
    property bool qsOpen: false
    // Cards inside the island are concentric with it (Island.qml: expandedRadius - expandedPadding)
    property real cardRadius: 20
    signal toggleQuickSettings()

    implicitHeight: mainCol.implicitHeight

    // Poll the GPU only while visible
    property bool gpuCounted: false
    function syncGpuWatch() {
        if (root.shown === root.gpuCounted) return;
        GpuUsage.watchers += root.shown ? 1 : -1;
        root.gpuCounted = root.shown;
    }
    onShownChanged: syncGpuWatch()
    Component.onCompleted: syncGpuWatch()
    Component.onDestruction: if (gpuCounted) GpuUsage.watchers--

    readonly property bool hasPlayer: MprisController.activePlayer !== null
    // The quick settings panel anchors itself to this button (Island.qml)
    readonly property Item qsButton: qsBtn
    // Body height: whatever the left column needs, but at least a share of the screen, so the
    // lyrics pane has room. Both columns fill this height, so their bottoms always line up.
    readonly property real bodyTargetHeight: Math.round(Math.min(460, Math.max(280, (root.screen?.height ?? 1080) * 0.34)))

    ColumnLayout {
        id: mainCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: 16

        // ───────────── Header ─────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ColumnLayout { // Clock (lock-screen style: big, rounded, tabular)
                spacing: -4
                GlassText {
                    text: DateTime.time
                    numeric: true
                    font.family: Glass.fontRounded
                    font.pixelSize: 40
                    font.weight: Font.Bold
                }
                GlassText {
                    text: DateTime.longDate
                    font.pixelSize: Glass.size.subheadline
                    font.weight: Font.Medium
                    color: Glass.secondaryLabel
                }
            }

            Item { Layout.fillWidth: true }

            IslandWorkspaces {
                screen: root.screen
                big: true
            }

            Item { Layout.fillWidth: true }

            ColumnLayout { // Battery + power mode
                spacing: 8
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    visible: Battery.available
                    spacing: 6
                    GlassText {
                        readonly property real t: Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty
                        visible: t > 0 && Battery.energyRate > 0.01
                        text: `${Math.floor(t / 3600)}h ${Math.floor((t % 3600) / 60)}m${Battery.isCharging ? " " + Translation.tr("to full") : ""}`
                        numeric: true
                        font.pixelSize: Glass.size.footnote
                        color: Glass.secondaryLabel
                    }
                    GlassText {
                        text: `${Math.round(Battery.percentage * 100)}%`
                        numeric: true
                        font.pixelSize: Glass.size.callout
                        font.weight: Font.DemiBold
                    }
                    IslandBattery {}
                }

                // Power mode: an Apple segmented control (a thumb slides behind the selected segment)
                Rectangle {
                    id: seg
                    Layout.alignment: Qt.AlignRight
                    readonly property var modes: [
                        { profile: PowerProfile.PowerSaver, icon: "eco", label: Translation.tr("Saver") },
                        { profile: PowerProfile.Balanced, icon: "balance", label: Translation.tr("Balanced") },
                        { profile: PowerProfile.Performance, icon: "bolt", label: Translation.tr("Perf") }
                    ].filter(m => m.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                    readonly property int current: Math.max(0, seg.modes.findIndex(m => m.profile === PowerProfiles.profile))
                    readonly property real segWidth: 84
                    implicitWidth: segWidth * modes.length + 4
                    implicitHeight: 30
                    radius: height / 2
                    color: Glass.fill

                    Rectangle { // thumb
                        y: 2
                        x: 2 + seg.current * seg.segWidth
                        width: seg.segWidth
                        height: seg.height - 4
                        radius: height / 2
                        color: Glass.dark ? Qt.rgba(1, 1, 1, 0.24) : "#FFFFFF"
                        Behavior on x { SpringAnimation { spring: Glass.spring.snappySpring; damping: Glass.spring.snappyDamping; epsilon: 0.25 } }
                    }
                    Row {
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: seg.modes
                            delegate: Item {
                                id: segItem
                                required property var modelData
                                required property int index
                                readonly property bool selected: seg.current === index
                                width: seg.segWidth
                                height: seg.height - 4
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    GlassIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: segItem.modelData.icon
                                        iconSize: 14
                                        color: segItem.selected ? Glass.label : Glass.secondaryLabel
                                    }
                                    GlassText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: segItem.modelData.label
                                        font.pixelSize: Glass.size.footnote
                                        font.weight: segItem.selected ? Font.DemiBold : Font.Medium
                                        color: segItem.selected ? Glass.label : Glass.secondaryLabel
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PowerProfiles.profile = segItem.modelData.profile
                                }
                            }
                        }
                    }
                }
            }

            GlassButton { // Power splash (IslandPower.qml)
                id: powerBtn
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40
                icon: "power_settings_new"
                iconSize: 20
                onClicked: GlobalStates.sessionOpen = true
                GlassToolTip { text: Translation.tr("Power") }
            }

            GlassButton { // Quick settings toggle (corner)
                id: qsBtn
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40
                icon: "toggle_on"
                iconSize: 22
                toggled: root.qsOpen
                onClicked: root.toggleQuickSettings()
                GlassToolTip { text: Translation.tr("Control Center") }
            }
        }

        // ───────────── Body ─────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(leftCol.implicitHeight, root.bodyTargetHeight)
            spacing: 14

            ColumnLayout { // Left: media + lyrics, resources
                id: leftCol
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Rectangle { // Now playing platter: stretches so the stats row meets the notifications' bottom
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.cardRadius
                    color: Glass.platter
                    implicitHeight: mediaCol.implicitHeight + 28

                    ColumnLayout {
                        id: mediaCol
                        anchors {
                            fill: parent
                            margins: 14
                        }
                        spacing: 10

                        IslandNowPlaying {
                            Layout.fillWidth: true
                            visible: root.hasPlayer
                        }
                        IslandLyrics { // grows into all spare height (min. 3 lines)
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.hasPlayer
                            active: root.shown && root.hasPlayer
                        }
                        Item { // Nothing playing: fills the card, message centred
                            visible: !root.hasPlayer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            implicitHeight: idleCol.implicitHeight + 20
                            ColumnLayout {
                                id: idleCol
                                anchors.centerIn: parent
                                spacing: 6
                                GlassIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "music_note"
                                    iconSize: 34
                                    color: Glass.tertiaryLabel
                                }
                                GlassText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Translation.tr("Not Playing")
                                    font.pixelSize: Glass.size.callout
                                    font.weight: Font.Medium
                                    color: Glass.secondaryLabel
                                }
                            }
                        }
                    }
                }

                GridLayout { // Resources
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 10
                    rowSpacing: 10
                    IslandStat {
                        Layout.fillWidth: true
                        radius: Glass.concentric(root.cardRadius, 2)
                        icon: "memory_alt"
                        label: "CPU"
                        value: ResourceUsage.cpuUsage
                        detail: ResourceUsage.maxAvailableCpuString
                    }
                    IslandStat {
                        Layout.fillWidth: true
                        radius: Glass.concentric(root.cardRadius, 2)
                        icon: "developer_board"
                        label: "GPU"
                        value: !GpuUsage.available ? -1 : GpuUsage.usage
                        valueText: !GpuUsage.available ? "—" : GpuUsage.asleep ? Translation.tr("Off") : `${Math.round(GpuUsage.usage * 100)}%`
                        detail: !GpuUsage.available ? "" : GpuUsage.asleep ? Translation.tr("dGPU asleep")
                            : `${GpuUsage.temperature}°C · ${(GpuUsage.memoryUsed / 1024).toFixed(1)}/${(GpuUsage.memoryTotal / 1024).toFixed(0)} GB`
                    }
                    IslandStat {
                        Layout.fillWidth: true
                        radius: Glass.concentric(root.cardRadius, 2)
                        icon: "memory"
                        label: Translation.tr("Memory")
                        value: ResourceUsage.memoryUsedPercentage
                        detail: `${ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)} / ${ResourceUsage.maxAvailableMemoryString}`
                    }
                    IslandStat {
                        Layout.fillWidth: true
                        radius: Glass.concentric(root.cardRadius, 2)
                        icon: "swap_horiz"
                        label: Translation.tr("Swap")
                        value: ResourceUsage.swapUsedPercentage
                        detail: `${ResourceUsage.kbToGbString(ResourceUsage.swapUsed)} / ${ResourceUsage.maxAvailableSwapString}`
                    }
                }
            }

            IslandNotifications { // Right: Notification Center
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                Layout.minimumHeight: 200
                platterRadius: root.cardRadius
            }
        }
    }
}
