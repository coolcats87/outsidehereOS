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
import Quickshell.Widgets
import Quickshell.Hyprland

/**
 * Island-style launcher (Super). Drops from the top centre of the focused screen.
 *   text      → apps (end4's fuzzy AppSearch), a math answer when it looks like math (qalc),
 *               "run in kitty" and "search Google" rows
 *   >command  → run the command in kitty (window stays open)
 *   ?query    → Google only
 *   =expr     → math only
 * Modes (own shortcuts, Backspace on an empty field goes back to search):
 *   clipboard (Super+V) → cliphist history, Enter copies, Shift+Del deletes
 *   emoji     (Super+.) → emoji search, Enter copies
 * ↑/↓ (or Tab) to move, Enter to run, Esc / click outside to close. Math results copy to clipboard.
 */
Scope {
    id: root
    property bool open: false
    property bool windowVisible: false
    property string mode: "search" // "search" | "clipboard" | "emoji"
    function toggle() { root.open ? root.close() : root.show(); }
    function show() { root.showMode("search"); }
    function showMode(m) {
        root.mode = m;
        if (m === "clipboard") Cliphist.refresh();
        if (m === "emoji") Emojis.load();
        if (root.open) { field.text = ""; root.rebuild(); field.forceActiveFocus(); return; }
        root.windowVisible = true; root.open = true;
    }
    function toggleMode(m) { (root.open && root.mode === m) ? root.close() : root.showMode(m); }
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

    Timer { // let the fold-away animation finish before unmapping
        id: hideTimer
        interval: 220
        onTriggered: if (!root.open) root.windowVisible = false
    }

    readonly property string shell: Quickshell.env("SHELL") || "bash"
    readonly property string home: Quickshell.env("HOME") || "/"
    readonly property string googleBase: Config.options.search.engineBaseUrl ?? "https://www.google.com/search?q="

    PanelWindow {
        id: win
        visible: root.windowVisible
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:islandLauncher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea { // click outside closes
            anchors.fill: parent
            onClicked: root.close()
        }

        GlassSurface { // Spotlight-style glass panel
            id: panel
            readonly property real fullHeight: col.implicitHeight + 24
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(680, win.width - 32)
            // Where macOS puts Spotlight: centred, about a quarter of the way down
            y: Math.round(win.height * 0.24)
            height: fullHeight
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: root.open ? Glass.duration.slow : 160; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? Glass.curve.bouncy : Glass.curve.exit } }
            // A capsule while it is just the search field; a rounded panel once results show
            radius: list.count > 0 ? 26 : height / 2
            tint: Glass.regular
            clipContent: true
            Behavior on height { SpringAnimation { spring: Glass.spring.morphSpring; damping: Glass.spring.morphDamping + 0.1; epsilon: 0.25 } }
            Behavior on radius { SpringAnimation { spring: Glass.spring.morphSpring; damping: 0.6; epsilon: 0.1 } }
            Behavior on opacity { NumberAnimation { duration: root.open ? 140 : 180 } }

            MouseArea { anchors.fill: parent } // swallow clicks so they don't close the launcher

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                RowLayout { // search field
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 10
                    GlassIcon {
                        text: root.mode === "clipboard" ? "content_paste" : root.mode === "emoji" ? "mood"
                            : field.text.startsWith(">") ? "terminal" : field.text.startsWith("?") ? "travel_explore"
                            : field.text.startsWith("=") ? "calculate" : "search"
                        iconSize: 24
                        fill: 0
                        color: Glass.secondaryLabel
                    }
                    TextInput {
                        id: field
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        color: Glass.label
                        selectionColor: Glass.accent
                        selectedTextColor: Glass.accentLabel
                        font.family: Glass.fontFamily
                        font.pixelSize: Glass.size.title2
                        clip: true
                        onTextChanged: { list.currentIndex = 0; mathTimer.restart(); root.rebuild(); }
                        GlassText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text.length === 0
                            text: root.mode === "clipboard" ? Translation.tr("Clipboard History")
                                : root.mode === "emoji" ? Translation.tr("Search Emoji") : Translation.tr("Spotlight Search")
                            color: Glass.tertiaryLabel
                            font.pixelSize: Glass.size.title2
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; }
                            else if (event.key === Qt.Key_Backspace && field.text.length === 0 && root.mode !== "search") {
                                root.showMode("search"); event.accepted = true;
                            } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier) && root.mode === "clipboard") {
                                const r = root.results[list.currentIndex];
                                if (r) Cliphist.deleteEntry(r.value);
                                event.accepted = true;
                            }
                            else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1); event.accepted = true;
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                list.currentIndex = Math.max(0, list.currentIndex - 1); event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.activate(list.currentIndex); event.accepted = true;
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: list.count > 0
                    implicitHeight: 1
                    color: Glass.separator
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight, 8 * 50)
                    visible: count > 0
                    clip: true
                    interactive: contentHeight > height
                    model: root.results
                    highlightMoveDuration: 120
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        // Spotlight: the selected row is filled with the accent colour, text turns white
                        readonly property bool current: ListView.isCurrentItem
                        readonly property color fg: current ? Glass.accentLabel : Glass.label
                        readonly property color fg2: current ? Qt.rgba(1, 1, 1, 0.78) : Glass.secondaryLabel
                        height: 50
                        radius: 14
                        color: current ? Glass.accent : rowMouse.containsMouse ? Glass.fill : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(row.index)
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 12
                            Item {
                                implicitWidth: 30
                                implicitHeight: 30
                                IconImage {
                                    anchors.fill: parent
                                    visible: row.modelData.appIcon !== undefined
                                    source: row.modelData.appIcon !== undefined ? Quickshell.iconPath(row.modelData.appIcon, "application-x-executable") : ""
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: row.modelData.glyph !== undefined
                                    text: row.modelData.glyph ?? ""
                                    font.pixelSize: 24
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: row.modelData.appIcon === undefined && row.modelData.glyph === undefined
                                    radius: 8
                                    color: row.current ? Qt.rgba(1, 1, 1, 0.22) : Glass.fillStrong
                                    GlassIcon {
                                        anchors.centerIn: parent
                                        text: row.modelData.icon ?? "apps"
                                        iconSize: 19
                                        color: row.fg
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                GlassText {
                                    Layout.fillWidth: true
                                    text: row.modelData.title
                                    elide: Text.ElideRight
                                    font.pixelSize: Glass.size.body
                                    font.weight: Font.Medium
                                    font.family: row.modelData.mono ? Glass.fontMono : Glass.fontFamily
                                    color: row.fg
                                }
                                GlassText {
                                    Layout.fillWidth: true
                                    visible: (row.modelData.subtitle ?? "").length > 0
                                    text: row.modelData.subtitle ?? ""
                                    elide: Text.ElideRight
                                    font.pixelSize: Glass.size.footnote
                                    color: row.fg2
                                }
                            }
                            GlassText {
                                visible: row.current
                                text: (row.modelData.verb ?? "") + "  ↩"
                                font.pixelSize: Glass.size.footnote
                                font.weight: Font.Medium
                                color: row.fg2
                            }
                        }
                    }
                }
            }
        }

        IslandKeys { // keystroke dropdown, under the search bar (this window is above the island)
            attachedToEdge: false
            topY: panel.y + panel.height + 8
        }
    }

    // ── Results ──
    property var results: []
    property string mathResult: ""
    property string mathFor: ""

    function looksLikeMath(q) {
        return /\d/.test(q) && /[-+*\/^%()!]|\b(sqrt|sin|cos|tan|log|ln|pi|to|in|mod)\b/i.test(q);
    }

    function rebuild() {
        const raw = field.text;
        const q = raw.trim();
        const out = [];
        if (root.mode === "clipboard") {
            for (const e of Cliphist.fuzzyQuery(q).slice(0, 60)) {
                const text = e.replace(/^\d+\t/, "");
                const img = Cliphist.entryIsImage(e);
                const dims = img ? (text.match(/(\d+x\d+)/)?.[1] ?? "") : "";
                out.push({ kind: "clip", icon: img ? "image" : "content_paste",
                    title: img ? Translation.tr("Image") : text.replace(/\s+/g, " ").trim(),
                    subtitle: img ? dims : "", verb: Translation.tr("Copy"), value: e });
            }
            root.results = out;
            return;
        }
        if (root.mode === "emoji") {
            for (const e of Emojis.query(q).slice(0, 80))
                out.push({ kind: "emoji", glyph: e.emoji, title: e.name, verb: Translation.tr("Copy"), value: e.emoji });
            root.results = out;
            return;
        }
        if (q.length === 0) { root.results = []; return; }

        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim();
            if (cmd.length > 0)
                out.push({ kind: "cmd", icon: "terminal", title: cmd, subtitle: Translation.tr("Run in kitty"), verb: Translation.tr("Run"), mono: true, value: cmd });
            root.results = out;
            return;
        }
        if (q.startsWith("?")) {
            const s = q.slice(1).trim();
            if (s.length > 0) out.push({ kind: "web", icon: "travel_explore", title: s, subtitle: Translation.tr("Search Google"), verb: Translation.tr("Search"), value: s });
            root.results = out;
            return;
        }
        const mathOnly = q.startsWith("=");
        const expr = mathOnly ? q.slice(1).trim() : q;
        if (root.mathResult.length > 0 && root.mathFor === expr && (mathOnly || root.looksLikeMath(expr)))
            out.push({ kind: "math", icon: "calculate", title: root.mathResult, subtitle: Translation.tr("%1 · Enter to copy").arg(expr), verb: Translation.tr("Copy"), mono: true, value: root.mathResult });
        if (mathOnly) { root.results = out; return; }

        for (const app of AppSearch.fuzzyQuery(q).slice(0, 6))
            out.push({ kind: "app", appIcon: AppSearch.guessIcon(app.icon || app.id || app.name), title: app.name, subtitle: app.comment || app.genericName || "", verb: Translation.tr("Launch"), entry: app });

        out.push({ kind: "cmd", icon: "terminal", title: q, subtitle: Translation.tr("Run in kitty"), verb: Translation.tr("Run"), mono: true, value: q });
        out.push({ kind: "web", icon: "travel_explore", title: q, subtitle: Translation.tr("Search Google"), verb: Translation.tr("Search"), value: q });
        root.results = out;
    }

    function activate(index) {
        const r = root.results[index];
        if (!r) return;
        if (r.kind === "app") {
            if (r.entry.runInTerminal)
                Quickshell.execDetached(["kitty", "--directory", root.home, "-e", ...r.entry.command]);
            else
                r.entry.execute();
        } else if (r.kind === "cmd") {
            Quickshell.execDetached(["kitty", "--directory", root.home, "--hold", root.shell, "-c", r.value]);
        } else if (r.kind === "web") {
            Qt.openUrlExternally(root.googleBase + encodeURIComponent(r.value));
        } else if (r.kind === "math" || r.kind === "emoji") {
            Quickshell.execDetached(["wl-copy", r.value]);
        } else if (r.kind === "clip") {
            Cliphist.copy(r.value);
        }
        root.close();
    }

    Timer {
        id: mathTimer
        interval: 90
        onTriggered: {
            const q = field.text.trim();
            const expr = q.startsWith("=") ? q.slice(1).trim() : q;
            if (root.mode !== "search" || expr.length === 0 || q.startsWith(">") || q.startsWith("?") || !(q.startsWith("=") || root.looksLikeMath(expr))) {
                root.mathResult = ""; root.mathFor = ""; root.rebuild(); return;
            }
            mathProc.forExpr = expr;
            mathProc.running = false;
            mathProc.command = ["qalc", "-t", expr];
            mathProc.running = true;
        }
    }
    Process {
        id: mathProc
        property string forExpr: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const res = text.trim().split("\n").pop() ?? "";
                const bad = res.length === 0 || /^(error|warning)/i.test(res) || res === mathProc.forExpr;
                root.mathResult = bad ? "" : res;
                root.mathFor = mathProc.forExpr;
                root.rebuild();
            }
        }
    }

    Connections { // data arrives async: refresh the list when it lands
        target: Cliphist
        function onEntriesChanged() { if (root.open && root.mode === "clipboard") root.rebuild(); }
    }
    Connections {
        target: Emojis
        function onListChanged() { if (root.open && root.mode === "emoji") root.rebuild(); }
    }

    onOpenChanged: {
        Keystrokes.suppressed = root.open;
        if (open) { field.text = ""; field.forceActiveFocus(); root.rebuild(); }
    }

    // Super tap (release without other keys) → toggle. Same interrupt logic as end4's search:
    // hypr/custom/keybinds.lua fires searchToggleReleaseInterrupt on any Super+key.
    GlobalShortcut {
        name: "islandLauncherToggleRelease"
        description: "Island launcher: toggle on Super release"
        onPressed: GlobalStates.superReleaseMightTrigger = true
        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            root.toggle();
        }
    }
    GlobalShortcut { // any Super+key combo: don't open the launcher when Super is released
        name: "searchToggleReleaseInterrupt"
        description: "Cancels the Super-tap launcher when Super is part of a combo"
        onPressed: GlobalStates.superReleaseMightTrigger = false
    }
    GlobalShortcut {
        name: "islandClipboard"
        description: "Spotlight: clipboard history"
        onPressed: root.toggleMode("clipboard")
    }
    GlobalShortcut {
        name: "islandEmoji"
        description: "Spotlight: emoji"
        onPressed: root.toggleMode("emoji")
    }
    GlobalShortcut {
        name: "islandLauncherToggle"
        description: "Island launcher: toggle"
        onPressed: root.toggle()
    }
    IpcHandler {
        target: "islandLauncher"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.close(); }
        function query(text: string): void { root.show(); field.text = text; }
        function clipboard(): void { root.toggleMode("clipboard"); }
        function emoji(): void { root.toggleMode("emoji"); }
    }
}
