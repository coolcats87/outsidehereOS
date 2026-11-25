pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

/**
 * The wallpaper, nothing else (no desktop clock or widgets). One background layer per screen,
 * cover-scaled, cross-fading with a slight settle when it changes. A video wallpaper is played
 * by mpvpaper (scripts/wallpaper/set-wallpaper.sh), so this layer stays out of its way.
 */
Scope {
    id: root
    readonly property string path: Config.options.background.wallpaperPath
    readonly property bool isVideo: /\.(mp4|webm|mkv|avi|mov)$/i.test(root.path)

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: !root.isVideo
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:wallpaper"
            anchors { top: true; bottom: true; left: true; right: true }

            // Two images: the new one fades in over the old, then they swap roles
            property bool useA: true
            property string shown: ""
            function show(p) {
                if (p === win.shown) return;
                win.shown = p;
                const next = win.useA ? imgB : imgA;
                next.source = p ? `file://${p}` : "";
            }
            Component.onCompleted: win.show(root.path)
            Connections {
                target: root
                function onPathChanged() { if (!root.isVideo) win.show(root.path); }
            }

            component Layer: Image {
                id: img
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(win.width, win.height)
                asynchronous: true
                cache: false
                smooth: true
                opacity: 0
                scale: 1.04
                property bool front: false
                z: front ? 1 : 0
                states: State {
                    when: img.front
                    PropertyChanges { img.opacity: 1; img.scale: 1 }
                }
                transitions: Transition {
                    to: "*"
                    NumberAnimation { properties: "opacity"; duration: 600; easing.type: Easing.OutCubic }
                    NumberAnimation { properties: "scale"; duration: 900; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.smooth }
                }
                onStatusChanged: {
                    if (status !== Image.Ready || img.front) return;
                    // this one finished loading: bring it to the front, retire the other
                    img.front = true;
                    const other = img === imgA ? imgB : imgA;
                    other.front = false;
                    win.useA = img === imgA;
                }
            }
            Layer { id: imgA }
            Layer { id: imgB }
        }
    }
}
