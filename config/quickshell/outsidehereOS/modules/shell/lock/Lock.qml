pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.panels.lock
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

LockScreen {
    id: root

    // Monitor name -> workspace id to restore on unlock (set when locking)
    property var savedWorkspaces: ({})

    Timer {
        id: restoreTimer
        interval: 150
        repeat: false
        onTriggered: {
            var batch = ""
            for (var j = 0; j < Quickshell.screens.length; ++j) {
                var monName = Quickshell.screens[j].name
                var wsId = root.savedWorkspaces[monName]
                if (wsId !== undefined) {
                    batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${monName}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${wsId}})';`
                }
            }
            if (batch.length > 0) {
                Quickshell.execDetached(["bash", "-c", batch])
            }
        }
    }

    lockSurface: GlassLockSurface {
        context: root.context
    }

    // Dry run of the lock screen in a normal overlay window (no session lock):
    //   qs -c outsidehereOS ipc call lockPreview toggle
    // It has its own LockContext, so the right password just closes it and the
    // power buttons never act. Esc (with an empty field) closes it too.
    property bool previewOpen: false
    signal previewExpand(string app) // test hook: fan out a notification stack in the preview
    LockContext {
        id: previewContext
        onUnlocked: targetAction => { previewContext.reset(); root.previewOpen = false; }
    }
    Loader {
        active: root.previewOpen
        sourceComponent: PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:lockPreview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors { top: true; left: true; right: true; bottom: true }
            GlassLockSurface {
                id: previewSurface
                anchors.fill: parent
                context: previewContext
                preview: true
                onPreviewClose: { previewContext.reset(); root.previewOpen = false; }
                Connections { target: root; function onPreviewExpand(app) { previewSurface.debugExpand(app); } }
            }
        }
    }
    IpcHandler {
        target: "lockPreview"
        function toggle(): void { root.previewOpen = !root.previewOpen; }
        function open(): void { root.previewOpen = true; }
        function close(): void { root.previewOpen = false; }
        function expand(app: string): void { root.previewExpand(app); }
    }

    // Single batch for lock and unlock so we don't race multiple hyprctl calls
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                // Lock: save workspace per monitor and move all to temp workspace in one batch
                var next = {}
                var batch = "keyword animation workspaces,1,7,menu_decel,slidevert; "
                for (var i = 0; i < Quickshell.screens.length; ++i) {
                    var mon = Quickshell.screens[i].name
                    var mData = HyprlandData.monitors.find(m => m.name === mon)
                    if (mData?.activeWorkspace == undefined) {
                        return;
                    }
                    var ws = (mData?.activeWorkspace?.id ?? 1)
                    next[mon] = ws
                    batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${mon}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${2147483647 - ws}})';`
                }
                root.savedWorkspaces = next
                Quickshell.execDetached(["bash", "-c", batch])
            } else {
                restoreTimer.start()
            }
        }
    }

    // Push everything down (visual only; workspace switch is in Connections above)
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            required property ShellScreen modelData
            property bool shouldPush: GlobalStates.screenLocked
            property string targetMonitorName: modelData.name
            property int verticalMovementDistance: modelData.height
            property int horizontalSqueeze: modelData.width * 0.2
        }
    }
}
