pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Time-synced lyrics for the active MPRIS track, from LRCLIB (https://lrclib.net).
 * Used by the dynamic island (modules/ii/island). Results are cached in ~/.cache/quickshell/lyrics.
 */
Singleton {
    id: root

    readonly property var player: MprisController.activePlayer
    property string trackKey: ""
    property bool loading: fetchProc.running
    property bool instrumental: false
    property bool synced: lines.length > 0
    property list<var> lines: []        // [{ time: seconds, text: string }]
    property list<string> plainLines: []
    property real position: 0           // seconds, refreshed by `tick()`
    property real offset: 0.25          // show a line slightly early, feels more in sync
    readonly property int currentIndex: {
        if (!synced) return -1;
        const p = position + offset;
        let lo = 0, hi = lines.length - 1, ans = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].time <= p) { ans = mid; lo = mid + 1; } else hi = mid - 1;
        }
        return ans;
    }
    readonly property string currentLine: currentIndex >= 0 ? lines[currentIndex].text : ""

    // Consumers set this while lyrics are on screen so we only poll then
    property int watchers: 0
    function tick() {
        if (!root.player) return;
        root.player.positionChanged();
        root.position = root.player.position;
    }
    Timer {
        running: root.watchers > 0 && (root.player?.isPlaying ?? false)
        interval: 200
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    function clean(s) {
        return (s ?? "")
            .replace(/\.(mp3|flac|m4a|aac|ogg|opus|wav|webm|mp4|mkv)$/i, "")
            .replace(/\s*[\(\[][^\)\]]*(official|video|audio|lyric|visuali[sz]er|mv|hd|4k|remaster)[^\)\]]*[\)\]]/ig, "")
            .replace(/\s*-\s*topic$/i, "")
            .trim();
    }

    function parseLrc(text) {
        const out = [];
        for (const raw of (text ?? "").split("\n")) {
            const re = /\[(\d+):(\d+(?:[.:]\d+)?)\]/g; // (no String.matchAll in Qt's JS engine)
            const tags = [];
            let m;
            while ((m = re.exec(raw)) !== null) tags.push(m);
            if (tags.length === 0) continue;
            const content = raw.replace(/\[[^\]]*\]/g, "").trim();
            for (const t of tags) {
                const secs = parseInt(t[1]) * 60 + parseFloat(t[2].replace(":", "."));
                out.push({ time: secs, text: content });
            }
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    function refetch() {
        const p = root.player;
        let title = clean(p?.trackTitle);
        let artist = clean(p?.trackArtist);
        const album = p?.trackAlbum ?? "";
        if (!title) { root.reset(""); return; }
        // Browser players often put "Artist - Title" in the title
        if ((!artist || artist.length === 0) && title.includes(" - ")) {
            const parts = title.split(" - ");
            artist = parts[0].trim();
            title = parts.slice(1).join(" - ").trim();
        }
        const key = `${artist}\n${title}`;
        if (key === root.trackKey) return;
        root.reset(key);
        const dur = Math.round(p?.length ?? 0);
        fetchProc.running = false;
        fetchProc.command = ["bash", `${Directories.scriptPath}/lyrics/lrclib-fetch.sh`.replace(/^file:\/\//, ""), artist, title, album, `${dur > 0 ? dur : ""}`];
        fetchProc.running = true;
    }

    function reset(key) {
        root.trackKey = key;
        root.lines = [];
        root.plainLines = [];
        root.instrumental = false;
    }

    Timer { // Debounce: players emit title/artist/length one after another
        id: refetchTimer
        interval: 400
        onTriggered: root.refetch()
    }
    Connections {
        target: root.player
        function onTrackTitleChanged() { refetchTimer.restart(); }
        function onTrackArtistChanged() { refetchTimer.restart(); }
        function onLengthChanged() { if (!root.synced) refetchTimer.restart(); }
    }
    onPlayerChanged: refetchTimer.restart()
    Component.onCompleted: refetchTimer.restart() // a track may already be playing at startup

    Process {
        id: fetchProc
        property string forKey: ""
        onStarted: forKey = root.trackKey
        stdout: StdioCollector {
            onStreamFinished: {
                if (fetchProc.forKey !== root.trackKey) return;
                if (!text || text.trim().length === 0) return;
                try {
                    const data = JSON.parse(text);
                    root.instrumental = data.instrumental ?? false;
                    root.lines = root.parseLrc(data.syncedLyrics);
                    root.plainLines = (data.plainLyrics ?? "").split("\n").filter(l => l.trim().length > 0);
                } catch (e) {
                    console.warn("[Lyrics] Could not parse LRCLIB response:", e);
                }
            }
        }
    }
}
