pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Wallpaper picker, Liquid Glass (Ctrl+Super+T). A glass sheet with a grid of the wallpapers in
 * ~/Pictures/Wallpapers (newest first): type to filter, arrows to move, Enter or click to set,
 * Esc or a click outside to close. Ctrl+Super+Alt+T sets a random one without opening it.
 * Setting runs scripts/wallpaper/set-wallpaper.sh.
 */
Scope {
    id: root
    property bool open: false
    property bool windowVisible: false
    readonly property string folder: `${Quickshell.env("HOME")}/Pictures/Wallpapers`
    readonly property string current: Config.options.background.wallpaperPath
    readonly property string setScript: `${Quickshell.shellDir}/scripts/wallpaper/set-wallpaper.sh`

    function show() { hideTimer.stop(); root.windowVisible = true; root.open = true; }
    function close() { root.open = false; hideTimer.restart(); }
    function toggle() { root.open ? root.close() : root.show(); }
    function apply(path) { if (path) Quickshell.execDetached([root.setScript, path]); }
    function random() {
        if (files.count === 0) return;
        let i = Math.floor(Math.random() * files.count);
        if (files.count > 1 && files.get(i, "filePath") === root.current) i = (i + 1) % files.count;
        root.apply(files.get(i, "filePath"));
    }
    Timer {
        id: hideTimer
        interval: 240
        onTriggered: if (!root.open) root.windowVisible = false
    }

    FolderListModel {
        id: files
        folder: `file://${root.folder}`
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif", "*.bmp", "*.jxl", "*.gif"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Time
    }

    PanelWindow {
        id: win
        visible: root.windowVisible
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:islandWallpaper" // island.* blur rule
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; left: true; right: true; bottom: true }

        // Search-filtered list of paths (the model itself stays unfiltered)
        property string query: ""
        readonly property var shownPaths: {
            files.count; // dependency
            const q = win.query.trim().toLowerCase().split(/\s+/).filter(w => w.length > 0);
            const out = [];
            for (let i = 0; i < files.count; i++) {
                const p = files.get(i, "filePath");
                const name = files.get(i, "fileName").toLowerCase();
                if (q.every(w => name.includes(w))) out.push(p);
            }
            return out;
        }

        Rectangle {
            anchors.fill: parent
            color: Glass.scrim
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        GlassSurface {
            id: sheet
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.open ? 28 : -40
            width: Math.min(1240, win.width - 64)
            height: Math.min(620, win.height * 0.62)
            radius: 34
            tint: Glass.thick
            clipContent: true
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: root.open ? Glass.duration.slow : 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? Glass.curve.bouncy : Glass.curve.exit } }

            MouseArea { anchors.fill: parent } // clicks inside don't close it

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        spacing: 0
                        GlassText {
                            text: Translation.tr("Wallpaper")
                            font.pixelSize: Glass.size.title2
                            font.weight: Font.Bold
                        }
                        GlassText {
                            text: `${root.folder.replace(Quickshell.env("HOME"), "~")} · ${files.count}`
                            font.pixelSize: Glass.size.footnote
                            color: Glass.secondaryLabel
                        }
                    }
                    Item { Layout.fillWidth: true }
                    GlassButton {
                        implicitHeight: 34
                        padding: 14
                        icon: "shuffle"
                        text: Translation.tr("Shuffle")
                        textSize: Glass.size.footnote
                        onClicked: root.random()
                    }
                    GlassButton {
                        implicitHeight: 34
                        padding: 14
                        icon: "folder_open"
                        text: Translation.tr("Open Folder")
                        textSize: Glass.size.footnote
                        onClicked: { Qt.openUrlExternally(`file://${root.folder}`); root.close(); }
                    }
                    GlassTextField {
                        id: search
                        implicitWidth: 240
                        implicitHeight: 34
                        radius: 17
                        placeholderText: Translation.tr("Search")
                        onTextChanged: { win.query = text; grid.currentIndex = 0; }
                        input.Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) { if (search.text.length > 0) search.text = ""; else root.close(); }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.apply(win.shownPaths[grid.currentIndex]); }
                            else if (event.key === Qt.Key_Right) grid.moveCurrentIndexRight();
                            else if (event.key === Qt.Key_Left) grid.moveCurrentIndexLeft();
                            else if (event.key === Qt.Key_Down) grid.moveCurrentIndexDown();
                            else if (event.key === Qt.Key_Up) grid.moveCurrentIndexUp();
                            else return;
                            event.accepted = true;
                        }
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: win.shownPaths
                    readonly property int columns: Math.max(2, Math.round(width / 280))
                    cellWidth: width / columns
                    cellHeight: cellWidth * 0.62 + 30
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: false
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: tile
                        required property string modelData
                        required property int index
                        readonly property bool isCurrent: tile.modelData === root.current
                        readonly property bool focused: grid.currentIndex === tile.index
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle { // selection ring (keyboard focus or the wallpaper in use)
                            anchors.fill: thumb
                            anchors.margins: -4
                            radius: thumb.radius + 4
                            color: "transparent"
                            border.width: 3
                            border.color: tile.isCurrent ? Glass.accent : Glass.label
                            opacity: tile.isCurrent ? 1 : tile.focused ? 0.55 : 0
                            Behavior on opacity { NumberAnimation { duration: Glass.duration.fast } }
                        }
                        ClippingRectangle {
                            id: thumb
                            x: 8
                            y: 8
                            width: tile.width - 16
                            height: tile.width * 0.62 - 16
                            radius: 16
                            color: Glass.fill
                            scale: mouse.pressed ? 0.97 : mouse.containsMouse ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: Glass.duration.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }
                            Image {
                                anchors.fill: parent
                                source: `file://${tile.modelData}`
                                sourceSize: Qt.size(420, 260)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                            Rectangle { // ✓ on the one in use
                                visible: tile.isCurrent
                                anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                                width: 24; height: 24; radius: 12
                                color: Glass.accent
                                GlassIcon { anchors.centerIn: parent; text: "check"; iconSize: 16; color: "white" }
                            }
                        }
                        GlassText {
                            anchors { left: thumb.left; right: thumb.right; top: thumb.bottom; topMargin: 6 }
                            text: tile.modelData.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ")
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Glass.size.caption
                            color: tile.isCurrent ? Glass.label : Glass.secondaryLabel
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: thumb
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: grid.currentIndex = tile.index
                            onClicked: root.apply(tile.modelData)
                        }
                    }
                }
            }

            GlassText {
                anchors.centerIn: parent
                visible: win.shownPaths.length === 0
                text: files.count === 0 ? Translation.tr("No images in %1").arg(root.folder.replace(Quickshell.env("HOME"), "~"))
                    : Translation.tr("No wallpapers match “%1”").arg(win.query)
                font.pixelSize: Glass.size.body
                color: Glass.secondaryLabel
            }
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (!root.open) return;
                search.text = "";
                search.focusInput();
                const i = win.shownPaths.indexOf(root.current);
                grid.currentIndex = Math.max(0, i);
                grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
            }
        }
    }

    // Same hooks as end4's selector, so Ctrl+Super+T / Ctrl+Super+Alt+T keep working
    GlobalShortcut { name: "wallpaperSelectorToggle"; description: "Wallpaper picker"; onPressed: root.toggle() }
    GlobalShortcut { name: "wallpaperSelectorRandom"; description: "Random wallpaper"; onPressed: root.random() }
    IpcHandler {
        target: "wallpaperPicker"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.close(); }
        function random(): void { root.random(); }
        function set(path: string): void { root.apply(path); }
    }
}
