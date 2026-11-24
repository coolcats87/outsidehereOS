pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Island power splash: a full-screen frosted overlay with four big squircles.
 * Reboot · Sleep · Shut down · Task manager (Mission Center).
 * Replaces end4's SessionScreen in IllogicalImpulseFamily.qml and keeps its hooks:
 * GlobalStates.sessionOpen, the "session" IPC target and the sessionToggle/Open/Close
 * shortcuts, so Ctrl+Alt+Del (hypr keybinds.lua) opens this.
 * Keys: ←/→ (or Tab) to move, Enter/Space to pick, 1–4 to pick directly, Esc / click outside to close.
 */
Scope {
    id: root
    property bool windowVisible: false
    readonly property bool open: GlobalStates.sessionOpen

    onOpenChanged: {
        if (open) { hideTimer.stop(); root.windowVisible = true; }
        else hideTimer.restart();
    }
    Timer { // let the fade-out finish before unmapping
        id: hideTimer
        interval: 220
        onTriggered: if (!root.open) root.windowVisible = false
    }
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() { if (GlobalStates.screenLocked) GlobalStates.sessionOpen = false; }
    }

    function close() { GlobalStates.sessionOpen = false; }
    function run(action) {
        root.close();
        switch (action) {
        case "reboot": Session.reboot(); break;
        case "sleep": Session.suspend(); break;
        case "shutdown": Session.poweroff(); break;
        case "taskmanager": Quickshell.execDetached(["missioncenter"]); break;
        }
    }

    readonly property var options: [
        { action: "reboot", icon: "restart_alt", label: Translation.tr("Reboot") },
        { action: "sleep", icon: "bedtime", label: Translation.tr("Sleep") },
        { action: "shutdown", icon: "power_settings_new", label: Translation.tr("Shut down") },
        { action: "taskmanager", icon: "monitoring", label: Translation.tr("Task manager") }
    ]

    PanelWindow {
        id: win
        visible: root.windowVisible
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:islandPower"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"

        property int current: 0

        Rectangle { // frosted dim (the layer rule blurs what's behind it)
            id: scrim
            anchors.fill: parent
            color: Glass.scrim
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.open ? 200 : 180; easing.type: Easing.OutCubic } }
        }

        MouseArea { // click outside closes
            anchors.fill: parent
            onClicked: root.close()
        }

        Item {
            id: content
            anchors.fill: parent
            focus: true
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.open ? 220 : 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.open ? 320 : 180; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? Glass.curve.bouncy : Glass.curve.exit } }

            Keys.onPressed: event => {
                const n = root.options.length;
                if (event.key === Qt.Key_Escape) root.close();
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_L) win.current = (win.current + 1) % n;
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_H) win.current = (win.current + n - 1) % n;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.run(root.options[win.current].action);
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) root.run(root.options[event.key - Qt.Key_1].action);
                else return;
                event.accepted = true;
            }

            Column {
                anchors.centerIn: parent
                spacing: 34

                GlassText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: DateTime.time
                    numeric: true
                    font.family: Glass.fontRounded
                    font.pixelSize: 88
                    font.weight: Font.Bold
                }

                Row {
                    id: tiles
                    readonly property real tile: Math.max(120, Math.min(210, (win.width - 64 - 3 * spacing) / 4))
                    spacing: 28

                    Repeater {
                        model: root.options
                        delegate: Item {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool selected: win.current === index
                            readonly property bool danger: modelData.action === "shutdown"
                            width: tiles.tile
                            height: tiles.tile + 40

                            GlassSurface { // glass squircle; the selected one fills with the accent (red for shut down)
                                id: sq
                                width: tiles.tile
                                height: tiles.tile
                                radius: width * 0.3
                                scale: area.pressed ? 0.92 : tile.selected ? 1.06 : 1
                                tint: tile.selected ? (tile.danger ? Glass.red : Glass.accent) : Glass.clear
                                glow: tile.selected ? 0.16 : Glass.glow
                                shadowBlur: 34
                                shadowOffsetY: 10
                                Behavior on scale { SpringAnimation { spring: Glass.spring.snappySpring; damping: Glass.spring.snappyDamping; epsilon: 0.002 } }
                                Behavior on tint { ColorAnimation { duration: Glass.duration.fast } }

                                GlassIcon {
                                    anchors.centerIn: parent
                                    text: tile.modelData.icon
                                    iconSize: tiles.tile * 0.34
                                    color: tile.selected ? Glass.accentLabel : Glass.label
                                }

                                MouseArea {
                                    id: area
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.current = tile.index
                                    onClicked: root.run(tile.modelData.action)
                                }
                            }

                            GlassText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                text: tile.modelData.label
                                font.pixelSize: Glass.size.headline
                                font.weight: tile.selected ? Font.DemiBold : Font.Medium
                                color: tile.selected ? Glass.label : Glass.secondaryLabel
                            }
                        }
                    }
                }

                GlassText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Translation.tr("←/→ to choose · Enter to confirm · Esc to cancel")
                    font.pixelSize: Glass.size.subheadline
                    color: Glass.tertiaryLabel
                }
            }
        }

        Connections {
            target: root
            function onOpenChanged() { if (root.open) { win.current = 3; // default to Task manager so a stray Enter never reboots
                content.forceActiveFocus(); } }
        }
    }

    IpcHandler {
        target: "session"
        function toggle(): void { GlobalStates.sessionOpen = !GlobalStates.sessionOpen; }
        function close(): void { GlobalStates.sessionOpen = false; }
        function open(): void { GlobalStates.sessionOpen = true; }
    }
    GlobalShortcut {
        name: "sessionToggle"
        description: "Toggles the power splash on press"
        onPressed: GlobalStates.sessionOpen = !GlobalStates.sessionOpen
    }
    GlobalShortcut {
        name: "sessionOpen"
        description: "Opens the power splash on press"
        onPressed: GlobalStates.sessionOpen = true
    }
    GlobalShortcut {
        name: "sessionClose"
        description: "Closes the power splash on press"
        onPressed: GlobalStates.sessionOpen = false
    }
}
