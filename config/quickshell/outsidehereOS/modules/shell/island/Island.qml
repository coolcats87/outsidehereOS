pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Dynamic-island style top bar (replaces modules/shell/bar/Bar.qml in IllogicalImpulseFamily.qml).
 *
 * Collapsed: a pill with the existing workspaces, a tiny equalizer while media plays, and the time.
 * Hover: the pill morphs into a rounded box with everything the bar used to show, plus synced
 * lyrics (LRCLIB) and notifications. The corner button pops quick settings out beside itself.
 * Autohide: the pill slides away when idle; the top screen edge (or holding Super) brings it back.
 */
Scope {
    id: island

    // ── Visibility mode (cycled with Super+Alt+J, saved across restarts) ──
    //   "hidden":  tucked away; the top screen edge (or holding Super) brings it back
    //   "dodge":   stays out while the workspace is empty, hides as soon as a window is open on it
    //   "visible": always shown, drawn over windows (reserves no space)
    readonly property var modes: ["hidden", "dodge", "visible"]
    readonly property var modeLabels: ({ "hidden": "Auto-hide", "dodge": "Dodge windows", "visible": "Always visible" })
    readonly property var modeIcons: ({ "hidden": "visibility_off", "dodge": "select_window", "visible": "visibility" })
    property string mode: "hidden"
    readonly property bool autoHide: island.mode !== "visible"
    function setMode(m) {
        if (!island.modes.includes(m)) return;
        island.mode = m;
        modeFile.setText(m);
        island.toast(island.modeIcons[m], island.modeLabels[m]);
    }
    function cycleMode() { island.setMode(island.modes[(island.modes.indexOf(island.mode) + 1) % island.modes.length]); }

    // ── Notification style (cycled with Super+Alt+N, saved across restarts) ──
    //   "banner": the island grows into the full notification
    //   "ticker": the island stays a pill; icon + "App · title — body" scrolls through it
    readonly property var notifStyles: ["banner", "ticker"]
    readonly property var notifStyleLabels: ({ "banner": "Full notifications", "ticker": "Ticker notifications" })
    readonly property var notifStyleIcons: ({ "banner": "notifications", "ticker": "text_rotation_none" })
    property string notifStyle: "banner"
    function setNotifStyle(st) {
        if (!island.notifStyles.includes(st)) return;
        island.notifStyle = st;
        notifStyleFile.setText(st);
        island.toast(island.notifStyleIcons[st], island.notifStyleLabels[st]);
    }
    function cycleNotifStyle() { island.setNotifStyle(island.notifStyles[(island.notifStyles.indexOf(island.notifStyle) + 1) % island.notifStyles.length]); }
    FileView {
        id: notifStyleFile
        path: `${Directories.state}/user/island-notif-style`
        printErrors: false
        onLoaded: {
            const st = notifStyleFile.text().trim();
            if (island.notifStyles.includes(st)) island.notifStyle = st;
        }
    }
    FileView {
        id: modeFile
        path: `${Directories.state}/user/island-mode`
        printErrors: false // doesn't exist until the mode is first changed
        onLoaded: {
            const m = modeFile.text().trim();
            if (island.modes.includes(m)) island.mode = m;
        }
    }

    // A short message in the pill (e.g. the new mode), like iOS's silent-switch island
    property string toastIcon: ""
    property string toastText: ""
    property int toastSerial: 0
    function toast(icon, text) { island.toastIcon = icon; island.toastText = text; island.toastSerial++; }
    // ── Levels: volume / brightness / night-light changes show up IN the island (replaces end4's
    // OSD window): the pill stretches into a slim slider on the focused screen, like iOS.
    property string levelKind: "volume" // "volume" | "brightness" | "gamma"
    property int levelSerial: 0
    signal levelHide()
    function showLevel(kind) { island.levelKind = kind; island.levelSerial++; }
    readonly property var levelMonitor: Brightness.getMonitorForScreen(Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null)
    readonly property bool levelMuted: Audio.sink?.audio.muted ?? false
    readonly property real levelVolume: Audio.sink?.audio.volume ?? 0
    readonly property real levelFrom: island.levelKind === "gamma" ? Hyprsunset.gammaLowerLimit / 100 : 0
    readonly property real levelValue: island.levelKind === "volume" ? (island.levelMuted ? 0 : island.levelVolume)
        : island.levelKind === "brightness" ? (island.levelMonitor?.brightness ?? 0.5)
        : Hyprsunset.gamma / 100
    readonly property real levelPosition: Math.max(0, Math.min(1, (island.levelValue - island.levelFrom) / (1 - island.levelFrom)))
    readonly property string levelIcon: {
        if (island.levelKind === "volume") {
            if (island.levelMuted || island.levelVolume <= 0.001) return "volume_off";
            return island.levelVolume < 0.34 ? "volume_mute" : island.levelVolume < 0.67 ? "volume_down" : "volume_up";
        }
        if (island.levelKind === "brightness") return Hyprsunset.temperatureActive ? "routine" : "light_mode";
        return "wb_twilight";
    }
    readonly property string levelText: island.levelKind === "volume" && island.levelMuted ? Translation.tr("Muted")
        : `${Math.round((island.levelKind === "volume" ? island.levelVolume : island.levelValue) * 100)}%`
    function setLevel(pos) { // pos: 0..1 along the bar
        const v = island.levelFrom + Math.max(0, Math.min(1, pos)) * (1 - island.levelFrom);
        if (island.levelKind === "volume") {
            if (!Audio.sink?.audio) return;
            Audio.sink.audio.muted = false;
            Audio.sink.audio.volume = v;
        } else if (island.levelKind === "brightness") {
            island.levelMonitor?.setBrightness(v);
        } else {
            Hyprsunset.setGamma(Math.round(v * 100));
        }
    }
    Connections {
        target: Brightness
        function onBrightnessChanged() { island.showLevel("brightness"); }
    }
    Connections {
        target: Hyprsunset
        function onGammaChangeAttempt() { island.showLevel("gamma"); }
    }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() { if (Audio.ready) island.showLevel("volume"); }
        function onMutedChanged() { if (Audio.ready) island.showLevel("volume"); }
    }
    Connections { // volume protection refused a jump: say why
        target: Audio
        function onSinkProtectionTriggered(reason) { island.levelHide(); island.toast("warning", reason); }
    }
    // end4's OSD hooks, so existing keybinds/scripts keep working
    IpcHandler {
        target: "osdVolume"
        function trigger(): void { island.showLevel("volume"); }
        function hide(): void { island.levelHide(); }
        function toggle(): void { island.showLevel("volume"); }
    }
    GlobalShortcut {
        name: "osdVolumeTrigger"
        description: "Shows the volume level in the island"
        onPressed: island.showLevel("volume")
    }
    GlobalShortcut {
        name: "osdVolumeHide"
        description: "Hides the level in the island"
        onPressed: island.levelHide()
    }

    // Test hooks driven by the "island" IPC target below
    property var batteryPreview: null
    signal ipcReveal()
    signal ipcExpand(bool expand)
    signal ipcQuickSettings(bool open)
    signal ipcTool(string id)

    // ── Notifications: the island turns into the newest popup (end4's popup windows are gone) ──
    // Notifications.popupList holds what is still "popping up"; the service's per-notification
    // timer drops it from the list. The island pauses that timer while hovered.
    readonly property var popups: Notifications.popupList
    readonly property var liveNotif: popups.length > 0 ? popups[popups.length - 1] : null
    // Don't let an app keep it up longer than the configured timeout (config: notifications.timeout)
    onLiveNotifChanged: {
        const t = island.liveNotif?.timer;
        const cap = Config.options.notifications.timeout ?? 5000;
        if (t && t.interval > cap) { t.interval = cap; t.restart(); }
    }

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        LazyLoader {
            id: loader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData

            component: PanelWindow {
                id: win
                screen: loader.modelData

                // ── Geometry ──
                readonly property real topGap: 6
                readonly property real pillHeight: 34
                readonly property real pillPadding: 14
                readonly property real expandedWidth: Math.min(win.screen.width - 32, 860)
                readonly property real expandedPadding: 18
                readonly property real expandedRadius: 38 // inner cards use Glass.concentric(expandedRadius, expandedPadding)
                readonly property real expandedHeight: Math.min(expandedContent.implicitHeight + expandedPadding * 2, win.screen.height * 0.75)
                readonly property real notifWidth: Math.min(win.screen.width - 32, 460)
                readonly property real notifPadding: 16
                readonly property real notifHeight: banner.implicitHeight + notifPadding * 2
                readonly property real edgeRevealHeight: Math.max(1, Config.options.bar.autoHide.hoverRegionWidth ?? 2)

                // ── State ──
                property bool expanded: false
                property bool qsOpen: false
                // Showing a notification: only while the island isn't opened up
                readonly property bool notifShowing: island.liveNotif !== null && !win.expanded
                // Opening the island shows the notification in the list: retire the popup(s)
                onExpandedChanged: if (expanded && island.popups.length > 0) Notifications.timeoutAll()

                // "dodge" mode: is this monitor's current workspace empty?
                readonly property var monitorData: HyprlandData.monitors.find(m => m.name === win.screen?.name)
                readonly property var activeWs: HyprlandData.workspaces.find(w => w.id === win.monitorData?.activeWorkspace?.id)
                readonly property bool workspaceEmpty: (win.activeWs?.windows ?? 0) === 0
                readonly property bool dodgeShow: island.mode === "dodge" && win.workspaceEmpty

                // Toast (mode changes): shown in the pill for a moment
                property bool toastActive: false
                Timer {
                    id: toastTimer
                    interval: 1700
                    onTriggered: { win.toastActive = false; if (win.idle) hideTimer.restart(); }
                }
                Connections {
                    target: island
                    function onToastSerialChanged() { win.toastActive = true; toastTimer.restart(); win.reveal(); }
                }

                // Level (volume/brightness) slider: on the focused screen only, over notifications and toasts
                property bool levelActive: false
                readonly property bool levelShowing: win.levelActive && !win.expanded
                Timer {
                    id: levelTimer
                    interval: Config.options.osd.timeout ?? 1500
                    onTriggered: {
                        if (boxHover.hovered || levelMouse.pressed) { levelTimer.restart(); return; } // reading or dragging it
                        win.levelActive = false;
                        if (win.hovered) expandTimer.restart(); // still on it: open as a normal hover would
                        else if (win.idle) hideTimer.restart();
                    }
                }
                Connections {
                    target: island
                    function onLevelSerialChanged() {
                        if (win.screen?.name !== Hyprland.focusedMonitor?.name) return;
                        win.levelActive = true;
                        levelTimer.restart();
                        win.reveal();
                    }
                    function onLevelHide() { levelTimer.stop(); win.levelActive = false; if (win.idle) hideTimer.restart(); }
                }

                readonly property bool tickerShowing: win.notifShowing && !win.levelShowing && island.notifStyle === "ticker"
                readonly property bool bannerShowing: win.notifShowing && !win.levelShowing && island.notifStyle === "banner"
                // Click on the notification (banner or ticker): its default action, else open the island
                function activateNotif() {
                    const n = island.liveNotif;
                    if (!n) return;
                    if ((n.actions ?? []).some(a => a.identifier === "default")) {
                        Notifications.attemptInvokeAction(n.notificationId, "default");
                    } else {
                        Notifications.timeoutNotification(n.notificationId);
                        win.revealed = true;
                        win.expanded = true;
                    }
                }
                readonly property bool hovered: boxHover.hovered || qsHover.hovered || bridgeHover.hovered || toolsHover.hovered || toolsBridgeHover.hovered

                // ── Autohide ──
                property bool revealed: !island.autoHide
                property bool superShow: false
                // Out of the way while a capture tool runs, whatever the mode
                property bool capturing: false
                Timer {
                    id: captureTimer
                    interval: 1500 // the tool has taken its shot (or frozen the screen) by then
                    onTriggered: win.capturing = false
                }
                readonly property bool shown: !win.capturing && (!island.autoHide || win.revealed || win.expanded || win.notifShowing || win.dodgeShow || win.toastActive || win.levelActive)
                // Idle = nothing is holding the island open
                readonly property bool idle: !win.hovered && !edgeHover.hovered && !win.expanded && !win.qsOpen && !win.superShow && !win.notifShowing && !win.toastActive && !win.levelActive
                function reveal() {
                    win.revealed = true;
                    if (win.idle) hideTimer.restart();
                }
                onIdleChanged: idle ? hideTimer.restart() : hideTimer.stop()
                Timer {
                    id: hideTimer
                    interval: 250
                    onTriggered: if (island.autoHide && win.idle) win.checkCursor("hide")
                }
                Timer { // same delay the old bar used for Super-to-show
                    id: superTimer
                    interval: Config.options.bar.autoHide.showWhenPressingSuper.delay ?? 140
                    onTriggered: { win.superShow = true; win.reveal(); }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!Config.options.bar.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) superTimer.restart();
                        else { superTimer.stop(); win.superShow = false; }
                    }
                }
                Connections {
                    target: island
                    function onIpcReveal() { win.reveal(); }
                    function onIpcExpand(expand) {
                        if (expand) { win.revealed = true; win.expanded = true; }
                        else { win.qsOpen = false; win.expanded = false; }
                    }
                    function onIpcTool(id) { win.runTool(id); }
                    function onIpcQuickSettings(open) {
                        if (open) { win.revealed = true; win.expanded = true; }
                        win.qsOpen = open;
                    }
                }

                // Hovering a notification opens the island like hovering the pill does
                // (the notification is then in the list, and its popup is retired: onExpandedChanged)
                onHoveredChanged: {
                    if (hovered) {
                        collapseTimer.stop();
                        leavePoll.stop();
                        if (!expanded) expandTimer.restart();
                    } else {
                        expandTimer.stop();
                        // Hyprland can report a pointer "leave" right after the island grows even though
                        // the cursor never moved. Confirm with the real cursor position before collapsing.
                        if (win.expanded) win.checkCursor("collapse");
                        else collapseTimer.restart();
                    }
                }
                // Qt's hover state goes stale when the island moves/grows under a still pointer, so the
                // expand and collapse decisions are confirmed against Hyprland's actual cursor position.
                function checkCursor(mode) {
                    cursorProc.mode = mode;
                    if (!cursorProc.running) cursorProc.running = true;
                }
                function insideIsland(px, py) {
                    const inRect = (it) => it.visible !== false && px >= it.x && px <= it.x + it.width && py >= it.y && py <= it.y + it.height;
                    return inRect(box) || (qsBox.visible && inRect(qsBox)) || (qsBridge.width > 0 && inRect(qsBridge))
                        || (toolsBox.visible && inRect(toolsBox)) || (toolsBridge.width > 0 && inRect(toolsBridge));
                }
                Process {
                    id: cursorProc
                    property string mode: "collapse"
                    command: ["hyprctl", "cursorpos", "-j"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let p = null;
                            try { p = JSON.parse(text); } catch (e) { p = null; }
                            const inside = p !== null && win.insideIsland(p.x - win.screen.x, p.y - win.screen.y);
                            if (cursorProc.mode === "hide") {
                                if (!island.autoHide || !win.idle) return;
                                // pointer still parked on the top edge or on the pill (stale hover): keep it, re-check
                                const onEdge = p !== null && (p.y - win.screen.y) <= win.edgeRevealHeight
                                    && (p.x - win.screen.x) >= 0 && (p.x - win.screen.x) <= win.width;
                                if (inside || onEdge) hideTimer.restart();
                                else win.revealed = false;
                                return;
                            }
                            if (cursorProc.mode === "expand") {
                                if (inside && !win.expanded) win.expanded = true; // otherwise: stale hover, stay a pill
                                return;
                            }
                            if (!win.expanded) return;
                            if (inside) leavePoll.restart();   // still on it (stale "leave"): look again shortly
                            else collapseTimer.restart();      // really left: close in ~180ms
                        }
                    }
                }
                Timer {
                    id: leavePoll
                    interval: 120
                    onTriggered: if (win.expanded) win.checkCursor("collapse")
                }
                Timer { // a short dwell so sweeping the mouse past the top edge doesn't pop it open
                    id: expandTimer
                    interval: 110
                    onTriggered: {
                        if (!win.hovered) return;
                        if (win.levelShowing) return; // the slider is up: hovering keeps it (to drag), doesn't open the island
                        // While the pill is still sliding in from the top edge it passes under the cursor;
                        // only expand once it has settled and the pointer is genuinely on it.
                        if (Math.abs(box.y - win.topGap) > 0.5) { expandTimer.restart(); return; }
                        win.checkCursor("expand"); // confirm with the real pointer position
                    }
                }
                // ── Tool dock actions: fold the island away first so it isn't captured ──
                property string pendingTool: ""
                function runTool(id) {
                    if (id === "keys") { Keystrokes.toggle(); return; }
                    if (id === "record" && toolsContent.recording) { // stop right away
                        Quickshell.execDetached(["bash", `${Quickshell.shellDir}/scripts/videos/record.sh`]);
                        return;
                    }
                    win.pendingTool = id;
                    win.capturing = true;
                    win.qsOpen = false;
                    win.expanded = false;
                    if (island.autoHide) win.revealed = false;
                    toolTimer.restart();
                }
                Timer {
                    id: toolTimer
                    interval: 420 // collapse + slide-out finished
                    onTriggered: {
                        const ipc = (t, f) => Quickshell.execDetached(["qs", "-c", "outsidehereOS", "ipc", "call", t, f]);
                        const mon = win.screen.name;
                        switch (win.pendingTool) {
                        case "snip": ipc("region", "screenshot"); break;
                        case "ocr": ipc("region", "ocr"); break;
                        case "lens": ipc("region", "search"); break;
                        case "record": ipc("region", "record"); break;
                        case "clipboard": ipc("search", "clipboardToggle"); break;
                        case "recordFull":
                            Quickshell.execDetached(["bash", `${Quickshell.shellDir}/scripts/videos/record.sh`, "--fullscreen", "--sound"]);
                            break;
                        case "picker": Quickshell.execDetached(["hyprpicker", "-a"]); break;
                        case "shot":
                            Quickshell.execDetached(["bash", "-c",
                                'd="$(xdg-user-dir PICTURES)/Screenshots"; mkdir -p "$d"; f="$d/Screenshot_$(date +%Y-%m-%d_%H.%M.%S).png"; '
                                + 'grim -o "$1" "$f" && wl-copy < "$f" && notify-send -a Screenshot -i "$f" "Screenshot saved" "$f"',
                                "_", mon]);
                            break;
                        }
                        win.pendingTool = "";
                        captureTimer.restart();
                    }
                }
                Timer {
                    id: collapseTimer
                    interval: 180
                    onTriggered: {
                        if (qsPanel.wantsKeyboard) return; // typing a Wi-Fi password: stay
                        win.qsOpen = false;
                        win.expanded = false;
                        // fold away together with the collapse instead of lingering as a pill
                        if (island.autoHide && !edgeHover.hovered && !win.superShow) win.revealed = false;
                    }
                }

                // ── Window ──
                WlrLayershell.namespace: "quickshell:island"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: (win.qsOpen && qsPanel.wantsKeyboard) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: 0 // every mode draws over windows; none reserves space
                color: "transparent"
                anchors {
                    top: true
                    left: true
                    right: true
                }
                // Tall enough for the opened island + quick settings; only the shapes take input
                implicitHeight: win.screen.height
                mask: Region {
                    item: box
                    regions: [
                        Region { item: qsMaskItem },
                        Region { item: edgeStrip },
                        Region { item: qsBridge },
                        Region { item: toolsMaskItem },
                        Region { item: toolsBridge }
                    ]
                }
                Item { // top-edge reveal strip: the only input area while the pill is hidden
                    id: edgeStrip
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: island.autoHide ? win.edgeRevealHeight : 0
                    HoverHandler {
                        id: edgeHover
                        onHoveredChanged: if (hovered) win.reveal()
                    }
                }
                Item { // invisible hover bridge over the gap, so moving to quick settings doesn't collapse the island
                    id: qsBridge
                    readonly property bool on: qsBox.visible
                    x: !on ? 0 : qsBox.side === "right" ? box.x + box.width : qsBox.side === "left" ? qsBox.x + qsBox.width : qsBox.x
                    y: !on ? 0 : qsBox.side === "below" ? box.y + box.height : qsBox.y
                    width: !on ? 0 : qsBox.side === "right" ? Math.max(0, qsBox.x - (box.x + box.width))
                        : qsBox.side === "left" ? Math.max(0, box.x - (qsBox.x + qsBox.width)) : qsBox.width
                    height: !on ? 0 : qsBox.side === "below" ? Math.max(0, qsBox.y - (box.y + box.height)) : Math.min(box.height, qsBox.height)
                    HoverHandler { id: bridgeHover }
                }
                Item { // input area of quick settings; zero-sized while closed so it never eats clicks
                    id: qsMaskItem
                    x: qsBox.x
                    y: qsBox.y
                    width: qsBox.visible ? qsBox.width : 0
                    height: qsBox.visible ? qsBox.height : 0
                }

                Component.onCompleted: GlobalFocusGrab.addPersistent(win)
                Component.onDestruction: GlobalFocusGrab.removePersistent(win)

                // ── The island itself: a Liquid Glass pane (shadow drawn by GlassSurface) ──
                GlassSurface {
                    id: box
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Slides fully above the screen edge (incl. shadow) while hidden
                    y: win.shown ? win.topGap : -(height + 48)
                    Behavior on y {
                        NumberAnimation {
                            duration: win.shown ? 460 : 240
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: win.shown ? Glass.curve.bouncy : Glass.curve.exit
                        }
                    }
                    readonly property bool toasting: win.toastActive && !win.expanded && !win.notifShowing && !win.levelShowing
                    width: win.expanded ? win.expandedWidth
                        : win.levelShowing ? Math.min(win.screen.width - 32, 320)
                        : win.tickerShowing ? tickerRow.implicitWidth + win.pillPadding * 2 + 4
                        : win.notifShowing ? win.notifWidth
                        : box.toasting ? toastRow.implicitWidth + win.pillPadding * 2 + 8
                        : collapsedRow.implicitWidth + win.pillPadding * 2
                    height: win.expanded ? win.expandedHeight : win.bannerShowing ? win.notifHeight : win.pillHeight
                    radius: win.expanded ? win.expandedRadius : win.bannerShowing ? 30 : win.pillHeight / 2
                    // Liquid Glass over Hyprland's blur (layer rule in hypr/custom/rules.lua)
                    tint: (win.expanded || win.bannerShowing) ? Glass.regular : Glass.clear
                    shadowBlur: win.expanded ? 36 : win.notifShowing ? 28 : 18
                    shadowOffsetY: win.expanded ? 12 : win.notifShowing ? 9 : 4
                    clipContent: true

                    // The morph: a spring, like the real Dynamic Island. Interruptible: hovering
                    // in and out mid-way retargets it without a jump.
                    Behavior on width {
                        SpringAnimation { spring: Glass.spring.morphSpring; damping: Glass.spring.morphDamping; epsilon: 0.25 }
                    }
                    Behavior on height {
                        SpringAnimation { spring: Glass.spring.morphSpring; damping: Glass.spring.morphDamping + 0.06; epsilon: 0.25 }
                    }
                    Behavior on radius {
                        SpringAnimation { spring: Glass.spring.morphSpring; damping: 0.6; epsilon: 0.1 }
                    }

                    HoverHandler {
                        id: boxHover
                    }
                    // (scrolling to switch workspaces is handled by the workspace chips, in both states)

                    // Collapsed content
                    Row {
                        id: collapsedRow
                        anchors.centerIn: parent
                        spacing: 12
                        opacity: (win.expanded || win.notifShowing || box.toasting || win.levelShowing) ? 0 : 1
                        scale: (win.expanded || win.notifShowing || box.toasting || win.levelShowing) ? 0.8 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: (win.expanded || win.notifShowing || box.toasting || win.levelShowing) ? 120 : 260; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        Rectangle { // recording indicator
                            anchors.verticalCenter: parent.verticalCenter
                            visible: toolsContent.recording
                            width: 8; height: 8; radius: 4
                            color: Glass.red
                            SequentialAnimation on opacity {
                                running: toolsContent.recording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                        IslandBattery {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Battery.available || island.batteryPreview !== null
                            preview: island.batteryPreview
                        }
                        IslandWorkspaces {
                            anchors.verticalCenter: parent.verticalCenter
                            screen: win.screen
                        }
                        Item { // media hint, only while playing
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property bool show: MprisController.isPlaying
                            width: show ? eq.width : 0
                            height: eq.height
                            visible: width > 0.5
                            clip: true
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            IslandEqualizer {
                                id: eq
                                playing: MprisController.isPlaying
                            }
                        }
                        GlassText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: DateTime.time
                            numeric: true
                            font.pixelSize: Glass.size.callout
                            font.weight: Font.DemiBold
                        }
                    }

                    Row { // ticker notification: icon + one scrolling line, inside the pill
                        id: tickerRow
                        readonly property var n: banner.shownNotif
                        readonly property real maxTextWidth: 380
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: win.tickerShowing ? 1 : 0
                        scale: win.tickerShowing ? 1 : 0.8
                        visible: opacity > 0
                        Behavior on opacity {
                            SequentialAnimation {
                                PauseAnimation { duration: win.tickerShowing ? 100 : 0 }
                                NumberAnimation { duration: win.tickerShowing ? 220 : 100; easing.type: Easing.OutCubic }
                            }
                        }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        IslandNotifIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            notif: tickerRow.n
                            size: 20
                        }
                        Item {
                            id: tickerClip
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(tickerText.implicitWidth, tickerRow.maxTextWidth)
                            height: tickerText.implicitHeight
                            clip: true
                            readonly property real overflow: Math.max(0, tickerText.implicitWidth - width)
                            GlassText {
                                id: tickerText
                                readonly property string app: (tickerRow.n?.appName ?? "") || Translation.tr("Notification")
                                readonly property string body: (tickerRow.n?.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
                                textFormat: Text.StyledText
                                text: `<b>${StringUtils.escapeHtml(tickerText.app)}</b> · ${StringUtils.escapeHtml(tickerRow.n?.summary ?? "")}`
                                    + (tickerText.body.length > 0 ? ` <font color="${Glass.secondaryLabel}">— ${StringUtils.escapeHtml(tickerText.body)}</font>` : "")
                                font.pixelSize: Glass.size.callout
                                onTextChanged: { x = 0; if (marquee.running) marquee.restart(); }
                                // Ticker tape: pause, scroll to the end, pause, jump back, repeat
                                SequentialAnimation on x {
                                    id: marquee
                                    running: win.tickerShowing && tickerClip.overflow > 0
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: 900 }
                                    NumberAnimation { to: -tickerClip.overflow; duration: tickerClip.overflow * 22; easing.type: Easing.InOutSine }
                                    PauseAnimation { duration: 900 }
                                    PropertyAction { value: 0 }
                                }
                            }
                        }
                    }
                    MouseArea { // click the ticker: same as clicking the banner
                        anchors.fill: parent
                        enabled: win.tickerShowing
                        visible: enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.activateNotif()
                    }

                    Item { // level content: icon, a slim draggable bar, the value
                        id: levelRow
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        opacity: win.levelShowing ? 1 : 0
                        scale: win.levelShowing ? 1 : 0.85
                        visible: opacity > 0
                        Behavior on opacity {
                            SequentialAnimation {
                                PauseAnimation { duration: win.levelShowing ? 80 : 0 }
                                NumberAnimation { duration: win.levelShowing ? 200 : 100; easing.type: Easing.OutCubic }
                            }
                        }
                        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                        GlassIcon {
                            id: levelIcon
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: island.levelIcon
                            iconSize: 18
                            color: island.levelKind === "volume" && island.levelMuted ? Glass.secondaryLabel : Glass.label
                        }
                        GlassText {
                            id: levelValueText
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 44
                            horizontalAlignment: Text.AlignRight
                            text: island.levelText
                            numeric: true
                            font.pixelSize: Glass.size.footnote
                            font.weight: Font.DemiBold
                            color: Glass.secondaryLabel
                        }
                        Item {
                            id: levelBar
                            anchors { left: levelIcon.right; right: levelValueText.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                            height: 22
                            readonly property bool active: levelMouse.containsMouse || levelMouse.pressed
                            property real shown: island.levelPosition
                            Behavior on shown { enabled: !levelMouse.pressed; SpringAnimation { spring: Glass.spring.snappySpring; damping: 0.6; epsilon: 0.001 } }
                            Rectangle {
                                id: levelTrack
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                height: levelBar.active ? 10 : 6
                                radius: height / 2
                                color: Glass.track
                                Behavior on height { NumberAnimation { duration: Glass.duration.fast; easing.type: Easing.OutCubic } }
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: Math.max(parent.height, parent.width * levelBar.shown)
                                    visible: levelBar.shown > 0.001
                                    radius: height / 2
                                    color: Glass.label
                                }
                            }
                            MouseArea {
                                id: levelMouse
                                anchors.fill: parent
                                anchors.topMargin: -6
                                anchors.bottomMargin: -6
                                hoverEnabled: true
                                enabled: win.levelShowing
                                cursorShape: Qt.PointingHandCursor
                                function setFrom(x) { levelBar.shown = Math.max(0, Math.min(1, x / width)); island.setLevel(levelBar.shown); }
                                onPressed: mouse => setFrom(mouse.x)
                                onPositionChanged: mouse => { if (pressed) setFrom(mouse.x); }
                                onWheel: wheel => island.setLevel(island.levelPosition + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                            }
                        }
                    }

                    Row { // toast content (mode changes)
                        id: toastRow
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: box.toasting ? 1 : 0
                        scale: box.toasting ? 1 : 0.8
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: box.toasting ? 220 : 120; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        GlassIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: island.toastIcon
                            iconSize: 17
                        }
                        GlassText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: island.toastText
                            font.pixelSize: Glass.size.callout
                            font.weight: Font.DemiBold
                        }
                    }

                    // Expanded content: laid out at full size, revealed as the box grows
                    StyledFlickable {
                        id: expandedFlick
                        x: win.expandedPadding
                        y: win.expandedPadding
                        width: win.expandedWidth - win.expandedPadding * 2
                        height: win.expandedHeight - win.expandedPadding * 2
                        contentHeight: expandedContent.implicitHeight
                        interactive: contentHeight > height
                        clip: true
                        opacity: win.expanded ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            SequentialAnimation {
                                PauseAnimation { duration: win.expanded ? 110 : 0 }
                                NumberAnimation { duration: win.expanded ? 260 : 110; easing.type: Easing.OutCubic }
                            }
                        }

                        IslandExpanded {
                            id: expandedContent
                            width: expandedFlick.width
                            scale: win.expanded ? 1 : 0.96
                            transformOrigin: Item.Top
                            Behavior on scale { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.smooth } }
                            screen: win.screen
                            shown: win.expanded
                            qsOpen: win.qsOpen
                            onToggleQuickSettings: win.qsOpen = !win.qsOpen
                        }
                    }
                }

                // ── Notification banner (inside the island; positioned over the box) ──
                IslandBanner {
                    id: banner
                    x: box.x + win.notifPadding
                    y: box.y + win.notifPadding
                    width: win.notifWidth - win.notifPadding * 2
                    // keeps the last notification while the island shrinks back, so it doesn't blank mid-morph
                    property var shownNotif: null
                    Connections {
                        target: island
                        function onLiveNotifChanged() { if (island.liveNotif) banner.shownNotif = island.liveNotif; }
                    }
                    Component.onCompleted: if (island.liveNotif) banner.shownNotif = island.liveNotif
                    notif: shownNotif
                    moreCount: Math.max(0, island.popups.length - 1)
                    opacity: win.bannerShowing ? 1 : 0
                    scale: win.bannerShowing ? 1 : 0.9
                    visible: opacity > 0.01
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: win.bannerShowing ? 120 : 0 }
                            NumberAnimation { duration: win.bannerShowing ? 240 : 100; easing.type: Easing.OutCubic }
                        }
                    }
                    Behavior on scale { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }
                    onActivated: win.activateNotif()
                }

                // ── Keystroke dropdown ──
                IslandKeys {
                    active: !launcher.windowVisible   // while the launcher is up, its own copy shows under the search bar
                    readonly property bool pillVisible: win.shown && box.y > -box.height / 2
                    attachedToEdge: !pillVisible
                    topY: pillVisible ? box.y + box.height + 8 : 0
                    Behavior on topY { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }

                // ── Tool dock: floats on the island's left, as tall as the expanded island ──
                Item { // input area; zero-sized while hidden
                    id: toolsMaskItem
                    x: toolsBox.x
                    y: toolsBox.y
                    width: toolsBox.visible ? toolsBox.width : 0
                    height: toolsBox.visible ? toolsBox.height : 0
                }
                Item { // hover bridge over the gap between dock and island
                    id: toolsBridge
                    readonly property bool on: toolsBox.visible
                    x: toolsBox.x + toolsBox.width
                    y: box.y
                    width: on ? toolsBox.gap : 0
                    height: on ? toolsBox.height : 0
                    HoverHandler { id: toolsBridgeHover }
                }
                GlassSurface {
                    id: toolsBox
                    readonly property bool open: win.expanded && win.shown
                    readonly property real gap: 10
                    // target geometry of the expanded island, so it doesn't chase the morph
                    readonly property real islandLeft: (win.width - win.expandedWidth) / 2
                    property real slide: open ? 0 : 24
                    x: islandLeft - gap - width + slide
                    y: box.y
                    width: 64
                    height: win.expandedHeight
                    radius: 32
                    tint: Glass.regular
                    opacity: open ? 1 : 0
                    visible: opacity > 0.01
                    transform: Scale {
                        origin.x: toolsBox.width
                        origin.y: 0
                        yScale: toolsBox.open ? 1 : 0.55
                        Behavior on yScale {
                            NumberAnimation {
                                duration: toolsBox.open ? 520 : 240
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: toolsBox.open ? Glass.curve.bouncy : Glass.curve.exit
                            }
                        }
                    }
                    Behavior on slide {
                        NumberAnimation {
                            duration: toolsBox.open ? 480 : 240
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: toolsBox.open ? Glass.curve.bouncy : Glass.curve.exit
                        }
                    }
                    Behavior on opacity { NumberAnimation { duration: toolsBox.open ? 220 : 180 } }

                    HoverHandler {
                        id: toolsHover
                        enabled: toolsBox.visible
                    }
                    MouseArea { // keep clicks/scrolls from falling through
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => wheel.accepted = true
                    }
                    IslandTools {
                        id: toolsContent
                        anchors.fill: parent
                        shown: toolsBox.open
                        onRun: id => win.runTool(id)
                    }
                }

                // ── Quick settings: grows out of its trigger button, beside the island ──
                // Button rect in window coordinates; re-evaluated as the box moves/morphs
                readonly property rect qsButtonRect: {
                    box.x; box.y; box.width; box.height; expandedFlick.contentY; // dependencies
                    const b = expandedContent.qsButton;
                    if (!b) return Qt.rect(box.x + box.width, box.y, 0, 0);
                    const p = b.mapToItem(win.contentItem, 0, 0);
                    return Qt.rect(p.x, p.y, b.width, b.height);
                }
                GlassSurface {
                    id: qsBox
                    readonly property bool open: win.qsOpen && win.expanded
                    readonly property real gap: 10
                    // Beside the expanded island, never over it: right side if it fits, else left, else below.
                    // (Computed from the island's *target* width so it doesn't chase the morph animation.)
                    readonly property real islandLeft: (win.width - win.expandedWidth) / 2
                    readonly property real islandRight: islandLeft + win.expandedWidth
                    readonly property string side: (islandRight + gap + width + gap <= win.width) ? "right"
                        : (islandLeft - toolsBox.width - gap * 2 - width - gap >= 0) ? "left" : "below"
                    x: side === "right" ? islandRight + gap
                        : side === "left" ? islandLeft - toolsBox.width - gap * 2 - width
                        : Math.max(gap, Math.min(win.width - width - gap, islandRight - width))
                    y: side === "below" ? Math.min(win.height - height - gap, box.y + box.height + gap)
                        : Math.max(gap, Math.min(win.height - height - gap, box.y))
                    width: qsPanel.implicitWidth
                    height: qsPanel.implicitHeight
                    radius: 34
                    tint: Glass.regular
                    clipContent: true
                    // Scale out of the button's centre (expressed in this panel's coordinates)
                    property real scaleAmount: open ? 1 : 0.6
                    transform: Scale {
                        origin.x: win.qsButtonRect.x + win.qsButtonRect.width / 2 - qsBox.x
                        origin.y: win.qsButtonRect.y + win.qsButtonRect.height / 2 - qsBox.y
                        xScale: qsBox.scaleAmount
                        yScale: qsBox.scaleAmount
                    }
                    opacity: open ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on scaleAmount {
                        NumberAnimation {
                            duration: qsBox.open ? 460 : 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: qsBox.open ? Glass.curve.bouncy : Glass.curve.exit
                        }
                    }
                    Behavior on opacity { NumberAnimation { duration: qsBox.open ? 180 : 200 } }
                    // No animation of its own: its height is the content's, which already animates
                    // (an extra animation here made the panel trail behind the content)

                    HoverHandler {
                        id: qsHover
                        enabled: qsBox.visible
                    }
                    MouseArea { // it floats over the panel: keep clicks/scrolls from falling through
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => wheel.accepted = true
                    }

                    IslandQuickSettings {
                        id: qsPanel
                        anchors.fill: parent
                        screen: win.screen
                        shown: qsBox.open
                    }
                }
            }
        }
    }

    // Super-tap launcher (apps / math / >kitty command / ?google)
    IslandLauncher { id: launcher }

    // qs -c outsidehereOS ipc call island <fn> — for keybinds and for testing states without the mouse
    IpcHandler {
        target: "island"
        function reveal(): void { island.ipcReveal(); }
        function expand(): void { island.ipcExpand(true); }
        function collapse(): void { island.ipcExpand(false); }
        function openQuickSettings(): void { island.ipcQuickSettings(true); }
        function closeQuickSettings(): void { island.ipcQuickSettings(false); }
        function previewBattery(percent: int, charging: bool): void { island.batteryPreview = { percent: percent, charging: charging }; }
        function clearBatteryPreview(): void { island.batteryPreview = null; }
        function toggleKeystrokes(): void { Keystrokes.toggle(); }
        function tool(id: string): void { island.ipcTool(id); }
        function cycleMode(): void { island.cycleMode(); }
        function setMode(mode: string): void { island.setMode(mode); }
        function getMode(): string { return island.mode; }
        function cycleNotifStyle(): void { island.cycleNotifStyle(); }
        function setNotifStyle(style: string): void { island.setNotifStyle(style); }
        function getNotifStyle(): string { return island.notifStyle; }
    }

    // Same IPC/shortcuts as the old bar, so existing keybinds keep working
    IpcHandler {
        target: "bar"
        function toggle(): void { GlobalStates.barOpen = !GlobalStates.barOpen; }
        function close(): void { GlobalStates.barOpen = false; }
        function open(): void { GlobalStates.barOpen = true; }
    }
    GlobalShortcut {
        name: "islandNotifStyleCycle"
        description: "Island: cycle full / ticker notifications"
        onPressed: island.cycleNotifStyle()
    }
    GlobalShortcut {
        name: "islandModeCycle"
        description: "Island: cycle auto-hide / dodge windows / always visible"
        onPressed: island.cycleMode()
    }
    GlobalShortcut {
        name: "islandKeystrokesToggle"
        description: "Island: show/hide the keystroke dropdown"
        onPressed: Keystrokes.toggle()
    }
    GlobalShortcut {
        name: "barToggle"
        description: "Toggles bar on press"
        onPressed: GlobalStates.barOpen = !GlobalStates.barOpen
    }
    GlobalShortcut {
        name: "barOpen"
        description: "Opens bar on press"
        onPressed: GlobalStates.barOpen = true
    }
    GlobalShortcut {
        name: "barClose"
        description: "Closes bar on press"
        onPressed: GlobalStates.barOpen = false
    }
}
