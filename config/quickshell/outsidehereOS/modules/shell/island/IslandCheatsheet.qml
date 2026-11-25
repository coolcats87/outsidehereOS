pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Keyboard shortcuts (Super+/), Liquid Glass. Replaces end4's cheatsheet in the ii family.
 * Every time it opens it asks Hyprland what is bound right now (scripts/keys/list-binds.py:
 * `hyprctl binds` + labels from the config for binds without a description), so it never
 * goes stale. Type to filter; Esc or a click outside closes.
 */
Scope {
    id: root
    property bool open: false
    property bool windowVisible: false
    property var binds: []
    property bool loading: false
    property string error: ""

    function show() {
        hideTimer.stop();
        root.windowVisible = true;
        root.open = true;
        root.loading = true;
        loader.running = false;
        loader.running = true;
    }
    function close() { if (root.open) root.rememberWorkspace(); root.open = false; hideTimer.restart(); }
    // Closing an overlay that held the keyboard makes Hyprland refocus the last focused
    // window, even on another workspace. If you switched workspaces while it was open,
    // that yanked you back: stay on the workspace you're on when it closes.
    property int keepWorkspace: 0
    function rememberWorkspace() {
        root.keepWorkspace = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 0;
        keepWorkspaceTimer.restart();
    }
    Timer {
        id: keepWorkspaceTimer
        interval: 60
        onTriggered: {
            const now = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 0;
            if (root.keepWorkspace > 0 && now !== root.keepWorkspace)
                Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({workspace=${root.keepWorkspace}})`]);
        }
    }

    function toggle() { root.open ? root.close() : root.show(); }
    Timer {
        id: hideTimer
        interval: 220
        onTriggered: if (!root.open) root.windowVisible = false
    }

    Process {
        id: loader
        command: ["python3", "-I", `${Quickshell.shellDir}/scripts/keys/list-binds.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(text);
                    if (Array.isArray(data)) { root.binds = data; root.error = ""; }
                    else root.error = data.error ?? Translation.tr("Couldn't read the keybinds");
                } catch (e) {
                    root.error = Translation.tr("Couldn't read the keybinds");
                }
            }
        }
    }

    // ── Display names ──
    function keyName(k) {
        const map = {
            "SUPER": "", "Return": "Return", "Slash": "/", "Backslash": "\\", "Period": ".", "Comma": ",",
            "Semicolon": ";", "Apostrophe": "'", "Minus": "−", "Equal": "=", "Escape": "Esc", "Delete": "Del",
            "Page_Up": "PgUp", "Page_Down": "PgDn", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
            "Space": "Space", "Tab": "Tab", "Print": "PrtSc", "BackSpace": "⌫",
            "XF86MonBrightnessUp": "Brightness +", "XF86MonBrightnessDown": "Brightness −",
            "XF86AudioRaiseVolume": "Volume +", "XF86AudioLowerVolume": "Volume −", "XF86AudioMute": "Mute",
            "XF86AudioMicMute": "Mic Mute", "XF86AudioPlay": "Play", "XF86AudioPause": "Pause",
            "XF86AudioNext": "Next", "XF86AudioPrev": "Previous"
        };
        if (map[k] !== undefined) return map[k];
        return k.length === 1 ? k.toUpperCase() : k;
    }
    function modName(m) {
        return ({ "SUPER": "", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift" })[m] ?? m;
    }
    function comboText(c) { return [...c.mods.map(root.modName), root.keyName(c.key)].join(" "); }

    // ── Filtered + grouped ──
    property string query: ""
    readonly property var groups: {
        const q = root.query.trim().toLowerCase();
        const byCat = {};
        const order = [];
        for (const b of root.binds) {
            if (q.length > 0) {
                const hay = `${b.cat} ${b.label} ${b.combos.map(c => [...c.mods, c.key].join(" ")).join(" ")}`.toLowerCase();
                if (!q.split(/\s+/).every(w => hay.includes(w))) continue;
            }
            if (!byCat[b.cat]) { byCat[b.cat] = []; order.push(b.cat); }
            byCat[b.cat].push(b);
        }
        return order.map(c => ({ cat: c, rows: byCat[c] }));
    }
    // Spread categories over the columns so they end at about the same height
    readonly property int columnCount: 3
    readonly property var columns: {
        const cols = [];
        const heights = [];
        for (let i = 0; i < root.columnCount; i++) { cols.push([]); heights.push(0); }
        for (const g of root.groups) {
            let best = 0;
            for (let i = 1; i < root.columnCount; i++) if (heights[i] < heights[best]) best = i;
            cols[best].push(g);
            heights[best] += g.rows.length + 2;
        }
        return cols;
    }

    component Keycap: Rectangle {
        id: cap
        property string text
        readonly property bool isSuper: cap.text === ""
        implicitHeight: 22
        implicitWidth: Math.max(22, capLabel.implicitWidth + 12)
        radius: 6
        color: Glass.fill
        border.width: 1
        border.color: Glass.separator
        Text {
            id: capLabel
            anchors.centerIn: parent
            text: cap.text
            renderType: Text.NativeRendering
            font.family: cap.isSuper ? "JetBrainsMono Nerd Font" : Glass.fontFamily
            font.pixelSize: cap.isSuper ? 13 : Glass.size.caption
            font.weight: Font.DemiBold
            color: Glass.label
        }
    }

    PanelWindow {
        id: win
        visible: root.windowVisible
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:islandCheatsheet"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; left: true; right: true; bottom: true }

        Rectangle { // dim + blur behind (layer rule quickshell:island.*)
            anchors.fill: parent
            color: Glass.scrim
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        GlassSurface {
            id: panel
            anchors.centerIn: parent
            width: Math.min(1180, win.width - 80)
            height: Math.min(800, win.height - 100)
            radius: 34
            tint: Glass.thick
            shadow: false
            clipContent: true
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: root.open ? 160 : 160 } }
            Behavior on scale { NumberAnimation { duration: root.open ? Glass.duration.slow : 180; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? Glass.curve.bouncy : Glass.curve.exit } }

            MouseArea { anchors.fill: parent } // clicks inside don't close it

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    GlassText {
                        Layout.fillWidth: true
                        text: Translation.tr("Keyboard Shortcuts")
                        font.pixelSize: Glass.size.title1
                        font.weight: Font.Bold
                    }
                    GlassTextField {
                        id: search
                        implicitWidth: 300
                        implicitHeight: 36
                        radius: 18
                        placeholderText: Translation.tr("Search shortcuts")
                        onTextChanged: root.query = text
                        input.Keys.onEscapePressed: {
                            if (search.text.length > 0) search.text = "";
                            else root.close();
                        }
                    }
                }

                StyledFlickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: cols.implicitHeight
                    clip: true

                    RowLayout {
                        id: cols
                        width: flick.width
                        spacing: 18

                        Repeater {
                            model: root.columns
                            delegate: ColumnLayout {
                                id: column
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop
                                spacing: 16

                                Repeater {
                                    model: column.modelData
                                    delegate: ColumnLayout {
                                        id: group
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 6

                                        GlassText {
                                            Layout.leftMargin: 6
                                            text: group.modelData.cat
                                            font.pixelSize: Glass.size.footnote
                                            font.weight: Font.DemiBold
                                            font.capitalization: Font.AllUppercase
                                            font.letterSpacing: 0.5
                                            color: Glass.secondaryLabel
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: rowsCol.implicitHeight + 8
                                            radius: 16
                                            color: Glass.platter
                                            ColumnLayout {
                                                id: rowsCol
                                                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4 }
                                                spacing: 0
                                                Repeater {
                                                    model: group.modelData.rows
                                                    delegate: Item {
                                                        id: bindRow
                                                        required property var modelData
                                                        required property int index
                                                        Layout.fillWidth: true
                                                        implicitHeight: Math.max(34, rowLayout.implicitHeight + 10)
                                                        Rectangle { // separator, inset like iOS lists
                                                            visible: bindRow.index > 0
                                                            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12 }
                                                            height: 1
                                                            color: Glass.separator
                                                        }
                                                        RowLayout {
                                                            id: rowLayout
                                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 10 }
                                                            spacing: 10
                                                            GlassText {
                                                                Layout.fillWidth: true
                                                                text: bindRow.modelData.label
                                                                elide: Text.ElideRight
                                                                font.pixelSize: Glass.size.callout
                                                            }
                                                            ColumnLayout { // one line per shortcut ("or")
                                                                spacing: 4
                                                                Repeater {
                                                                    model: bindRow.modelData.combos
                                                                    delegate: Row {
                                                                        id: combo
                                                                        required property var modelData
                                                                        Layout.alignment: Qt.AlignRight
                                                                        spacing: 3
                                                                        Repeater {
                                                                            model: [...combo.modelData.mods.map(root.modName), root.keyName(combo.modelData.key)]
                                                                            delegate: Keycap {
                                                                                required property var modelData
                                                                                text: modelData
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GlassText { // loading / empty / error states
                anchors.centerIn: parent
                visible: root.loading || root.error.length > 0 || root.groups.length === 0
                text: root.loading ? Translation.tr("Reading keybinds…")
                    : root.error.length > 0 ? root.error
                    : Translation.tr("No shortcuts match “%1”").arg(root.query)
                font.pixelSize: Glass.size.body
                color: Glass.secondaryLabel
            }
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) { search.text = ""; search.focusInput(); flick.contentY = 0; }
            }
        }
    }

    // Same hooks as end4's cheatsheet, so Super+/ (quickshell:cheatsheetToggle) opens this one
    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggles the keyboard shortcuts sheet"
        onPressed: root.toggle()
    }
    GlobalShortcut {
        name: "cheatsheetOpen"
        description: "Opens the keyboard shortcuts sheet"
        onPressed: root.show()
    }
    GlobalShortcut {
        name: "cheatsheetClose"
        description: "Closes the keyboard shortcuts sheet"
        onPressed: root.close()
    }
    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.close(); }
    }
}
