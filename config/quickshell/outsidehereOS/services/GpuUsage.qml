pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * NVIDIA dGPU usage via nvidia-smi, polled only while something watches it
 * (the expanded dynamic island). If the dGPU is runtime-suspended it is left asleep
 * and reported as "off", so opening the island never wakes it up.
 */
Singleton {
    id: root

    property int watchers: 0
    property bool available: true
    property bool asleep: false
    property real usage: 0          // 0..1
    property int temperature: 0     // °C
    property real memoryUsed: 0     // MiB
    property real memoryTotal: 1    // MiB

    Timer {
        running: root.watchers > 0 && root.available
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pollProc.running) pollProc.running = true
    }

    Process {
        id: pollProc
        command: ["bash", "-c", `
            command -v nvidia-smi >/dev/null || { echo none; exit; }
            for d in /sys/bus/pci/drivers/nvidia/0000:*; do
                [ "$(cat "$d/power/runtime_status" 2>/dev/null)" = suspended ] && { echo asleep; exit; }
            done
            nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits | head -1
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t === "none") { root.available = false; return; }
                if (t === "asleep") { root.asleep = true; root.usage = 0; return; }
                const v = t.split(",").map(s => parseFloat(s.trim()));
                if (v.length < 4 || v.some(isNaN)) return;
                root.asleep = false;
                root.usage = v[0] / 100;
                root.temperature = v[1];
                root.memoryUsed = v[2];
                root.memoryTotal = Math.max(1, v[3]);
            }
        }
    }
}
