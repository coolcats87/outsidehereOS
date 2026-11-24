pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live keystrokes for the island's key overlay (scripts/keys/keystroke-reader.py reads /dev/input).
 * Only the latest stroke is kept, in memory; nothing is logged. The reader is not running while
 * the screen is locked or when disabled (IPC: `qs -c outsidehereOS ipc call island toggleKeystrokes`).
 */
Singleton {
    id: root

    property bool enabled: true
    property bool suppressed: false          // e.g. while the launcher is open (you can see what you type)
    readonly property bool active: enabled && !GlobalStates.screenLocked

    // Latest stroke: list of { label, isSuper } — one entry, or several for "A + B" combos
    property var keys: []
    property int strokeId: 0                 // bumps on every key press (restarts the hide timer)
    signal stroke()

    property var held: []                    // currently held key names, in press order

    // Shared dropdown visibility (the island and the launcher each draw a copy, only one at a time)
    property bool showing: false
    property int holdMs: 280                 // how long a stroke stays up after the last key press
    Timer {
        id: holdTimer
        interval: root.holdMs
        onTriggered: root.showing = false
    }

    readonly property var modifierOrder: ["KEY_LEFTMETA", "KEY_RIGHTMETA", "KEY_LEFTCTRL", "KEY_RIGHTCTRL",
        "KEY_LEFTALT", "KEY_RIGHTALT", "KEY_LEFTSHIFT", "KEY_RIGHTSHIFT"]
    readonly property var labels: ({
        "KEY_LEFTCTRL": "Ctrl", "KEY_RIGHTCTRL": "Ctrl", "KEY_LEFTSHIFT": "Shift", "KEY_RIGHTSHIFT": "Shift",
        "KEY_LEFTALT": "Alt", "KEY_RIGHTALT": "AltGr", "KEY_ENTER": "Enter", "KEY_KPENTER": "Enter",
        "KEY_SPACE": "Space", "KEY_BACKSPACE": "⌫", "KEY_TAB": "Tab", "KEY_ESC": "Esc", "KEY_DELETE": "Del",
        "KEY_UP": "↑", "KEY_DOWN": "↓", "KEY_LEFT": "←", "KEY_RIGHT": "→", "KEY_CAPSLOCK": "Caps",
        "KEY_PAGEUP": "PgUp", "KEY_PAGEDOWN": "PgDn", "KEY_HOME": "Home", "KEY_END": "End",
        "KEY_INSERT": "Ins", "KEY_SYSRQ": "PrtSc", "KEY_MINUS": "-", "KEY_EQUAL": "=",
        "KEY_LEFTBRACE": "[", "KEY_RIGHTBRACE": "]", "KEY_SEMICOLON": ";", "KEY_APOSTROPHE": "'",
        "KEY_GRAVE": "`", "KEY_BACKSLASH": "\\", "KEY_COMMA": ",", "KEY_DOT": ".", "KEY_SLASH": "/",
        "KEY_VOLUMEUP": "Vol +", "KEY_VOLUMEDOWN": "Vol −", "KEY_MUTE": "Mute",
        "KEY_BRIGHTNESSUP": "Bright +", "KEY_BRIGHTNESSDOWN": "Bright −",
        "KEY_PLAYPAUSE": "⏯", "KEY_NEXTSONG": "⏭", "KEY_PREVIOUSSONG": "⏮", "KEY_COMPOSE": "Menu"
    })

    function isSuper(name) { return name === "KEY_LEFTMETA" || name === "KEY_RIGHTMETA"; }
    function label(name) {
        if (root.labels[name] !== undefined) return root.labels[name];
        let s = name.replace(/^KEY_/, "");
        if (s.startsWith("KP")) s = s.slice(2);            // keypad: KP7 → 7
        if (s.length <= 3) return s.toUpperCase();        // A, 7, F12
        return s.charAt(0) + s.slice(1).toLowerCase();    // PAUSE → Pause
    }
    // Modifiers first (Super, Ctrl, Alt, Shift), then other keys in the order pressed
    function sorted(names) {
        const rank = n => { const i = root.modifierOrder.indexOf(n); return i < 0 ? 100 : i; };
        return names.map((n, i) => ({ n, i })).sort((a, b) => (rank(a.n) - rank(b.n)) || (a.i - b.i)).map(x => x.n);
    }

    function onDown(name) {
        if (!root.held.includes(name)) root.held = [...root.held, name];
        root.keys = root.sorted(root.held).map(n => ({ label: root.isSuper(n) ? "" : root.label(n), isSuper: root.isSuper(n) }));
        root.strokeId++;
        root.stroke();
        if (!root.suppressed) {
            root.showing = true;
            holdTimer.restart();
        }
    }
    function onUp(name) {
        root.held = root.held.filter(n => n !== name);
    }

    function toggle() { root.enabled = !root.enabled; }

    Process {
        id: reader
        running: root.active
        command: ["python3", "-I", `${Directories.scriptPath}/keys/keystroke-reader.py`.replace(/^file:\/\//, "")]
        onRunningChanged: if (!running) root.held = []
        stdout: SplitParser {
            onRead: line => {
                const sp = line.indexOf(" ");
                if (sp < 0) return;
                const kind = line.slice(0, sp), name = line.slice(sp + 1).trim();
                if (kind === "D") root.onDown(name);
                else if (kind === "U") root.onUp(name);
            }
        }
    }
}
