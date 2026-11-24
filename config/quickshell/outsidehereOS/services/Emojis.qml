pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Emoji list for the Spotlight emoji mode. Data: assets/emoji.txt, one per line:
 * "<emoji> <name and keywords>". Loaded on first use.
 */
Singleton {
    id: root
    property var list: [] // [{ emoji, name, keywords }]
    property var prepared: []
    function load() { if (root.list.length === 0) file.reload(); }

    function query(search: string): var {
        const q = search.trim();
        if (q.length === 0) return root.list;
        return Fuzzy.go(q, root.prepared, { all: false, limit: 80, key: "text" }).map(r => r.obj.item);
    }

    FileView {
        id: file
        path: Qt.resolvedUrl("../assets/emoji.txt")
        blockLoading: false
        onLoaded: {
            const out = [];
            for (const line of file.text().split("\n")) {
                const t = line.trim();
                const sp = t.indexOf(" ");
                if (sp <= 0) continue;
                const emoji = t.slice(0, sp);
                const rest = t.slice(sp + 1);
                out.push({ emoji: emoji, name: rest, text: rest });
            }
            root.list = out;
            root.prepared = out.map(e => ({ text: Fuzzy.prepare(e.text), item: e }));
        }
    }
}
