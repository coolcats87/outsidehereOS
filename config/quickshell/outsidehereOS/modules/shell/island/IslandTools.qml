pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Vertical tool dock that floats beside the expanded island (left side, see Island.qml).
 * Capture tools + a few utilities; the buttons are spread evenly over the dock's full height.
 * Island.qml does the actual work in runTool(id) so it can fold the island away first
 * (otherwise it would end up in the screenshot / recording).
 */
Item {
    id: root
    property bool shown: false
    signal run(string id)

    // ── Recording state (wf-recorder, used by both end4's region recorder and record.sh) ──
    property bool recording: false
    Timer {
        interval: root.shown ? 1000 : 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!recProc.running) recProc.running = true
    }
    Process {
        id: recProc
        command: ["pidof", "wf-recorder"]
        onExited: (code, status) => root.recording = (code === 0)
    }

    readonly property var tools: [
        { id: "snip",       icon: "screenshot_region",  label: "Screenshot area" },
        { id: "shot",       icon: "screenshot_monitor", label: "Screenshot screen (file + clipboard)" },
        { id: "record",     icon: root.recording ? "stop_circle" : "videocam", label: root.recording ? "Stop recording" : "Record area",
          danger: root.recording },
        { id: "recordFull", icon: "screen_record",      label: "Record screen with sound" },
        { id: "ocr",        icon: "document_scanner",   label: "Copy text from area (OCR)" },
        { id: "lens",       icon: "image_search",       label: "Search area (Google Lens)" },
        { id: "picker",     icon: "colorize",           label: "Pick a colour" },
        { id: "clipboard",  icon: "content_paste",      label: "Clipboard history" },
        { id: "keys",       icon: "keyboard",           label: Keystrokes.enabled ? "Hide keystroke overlay" : "Show keystroke overlay",
          toggled: Keystrokes.enabled },
    ]

    readonly property real buttonSize: 40
    readonly property real pad: 14

    Repeater {
        model: root.tools.length
        delegate: GlassButton {
            id: btn
            required property int index
            readonly property var tool: root.tools[index]
            readonly property real step: root.tools.length > 1 ? (root.height - root.pad * 2 - root.buttonSize) / (root.tools.length - 1) : 0
            x: (root.width - width) / 2
            y: root.pad + index * Math.max(0, step)
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            icon: tool.icon
            iconSize: 19
            toggled: tool.toggled === true
            highlighted: tool.danger === true
            danger: tool.danger === true
            flat: true
            onClicked: root.run(tool.id)

            // staggered pop-in as the dock opens
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.6
            Behavior on opacity { SequentialAnimation {
                PauseAnimation { duration: root.shown ? 60 + btn.index * 24 : 0 }
                NumberAnimation { duration: root.shown ? 200 : 100; easing.type: Easing.OutCubic }
            } }
            Behavior on scale { SequentialAnimation {
                PauseAnimation { duration: root.shown ? 60 + btn.index * 24 : 0 }
                NumberAnimation { duration: root.shown ? Glass.duration.slow : 100; easing.type: Easing.BezierSpline; easing.bezierCurve: root.shown ? Glass.curve.bouncy : Glass.curve.exit }
            } }

            GlassToolTip {
                text: btn.tool.label
                // pop out to the left of the dock instead of covering the next button
                x: -implicitWidth - (root.width - btn.width) / 2 - 8
                y: (btn.height - implicitHeight) / 2
            }
        }
    }
}
