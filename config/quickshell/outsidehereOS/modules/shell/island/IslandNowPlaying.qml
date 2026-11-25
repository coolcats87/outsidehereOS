pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

/**
 * Now playing, Apple Music style: rounded cover, title/artist, transport buttons and a
 * thin scrubber that thickens under the pointer. Replaces end4's NowPlaying in the island.
 */
Item {
    id: root
    readonly property var player: MprisController.activePlayer
    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property real length: root.player?.length ?? 0
    readonly property real progress: root.length > 0 ? Math.min(1, (root.player?.position ?? 0) / root.length) : 0

    implicitHeight: col.implicitHeight

    Timer { // position is only reported on state changes: ask while playing
        running: root.playing && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Cover art: local files as they are; web ones through the cache end4's media controls use
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property bool artIsRemote: root.artUrl.startsWith("http")
    readonly property string artCachePath: `${Directories.coverArt}/${Qt.md5(root.artUrl)}`
    property bool artCached: false
    readonly property string artSource: !root.artIsRemote ? root.artUrl : root.artCached ? Qt.resolvedUrl(root.artCachePath) : ""
    onArtUrlChanged: {
        root.artCached = false;
        if (!root.artIsRemote) return;
        artDownloader.target = root.artUrl;
        artDownloader.path = root.artCachePath;
        artDownloader.running = true;
    }
    Component.onCompleted: root.artUrlChanged()
    Process {
        id: artDownloader
        property string target
        property string path
        command: ["bash", "-c", `mkdir -p "$(dirname "$2")"; [ -f "$2" ] || curl -4 -sSL "$1" -o "$2"`, "_", target, path]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && path === root.artCachePath) root.artCached = true;
        }
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ClippingRectangle { // cover
                implicitWidth: 58
                implicitHeight: 58
                radius: 12
                color: Glass.fill
                GlassIcon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "music_note"
                    iconSize: 26
                    color: Glass.secondaryLabel
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.artSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 116
                    sourceSize.height: 116
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Glass.duration.normal } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                GlassText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || Translation.tr("Nothing playing")
                    elide: Text.ElideRight
                    font.pixelSize: Glass.size.headline
                    font.weight: Font.DemiBold
                }
                GlassText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    font.pixelSize: Glass.size.subheadline
                    color: Glass.secondaryLabel
                }
            }

            Row {
                spacing: 2
                GlassButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 34; implicitHeight: 34
                    flat: true
                    icon: "fast_rewind"
                    iconSize: 22
                    enabled: MprisController.canGoPrevious
                    onClicked: MprisController.previous()
                }
                GlassButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 42; implicitHeight: 42
                    flat: true
                    icon: root.playing ? "pause" : "play_arrow"
                    iconSize: 30
                    onClicked: MprisController.togglePlaying()
                }
                GlassButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 34; implicitHeight: 34
                    flat: true
                    icon: "fast_forward"
                    iconSize: 22
                    enabled: MprisController.canGoNext
                    onClicked: MprisController.next()
                }
            }
        }

        RowLayout { // scrubber
            Layout.fillWidth: true
            visible: root.length > 0
            spacing: 10
            GlassText {
                text: StringUtils.friendlyTimeForSeconds(scrub.pressed ? scrub.dragPos * root.length : (root.player?.position ?? 0))
                numeric: true
                font.pixelSize: Glass.size.caption
                font.weight: Font.Medium
                color: Glass.tertiaryLabel
            }
            Item {
                id: scrubArea
                Layout.fillWidth: true
                implicitHeight: 14
                readonly property bool active: scrub.containsMouse || scrub.pressed
                Rectangle {
                    id: scrubTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: scrubArea.active ? 8 : 4
                    radius: height / 2
                    color: Glass.track
                    clip: true
                    Behavior on height { SpringAnimation { spring: Glass.spring.snappySpring; damping: 0.5; epsilon: 0.05 } }
                    Rectangle {
                        height: parent.height
                        width: parent.width * (scrub.pressed ? scrub.dragPos : root.progress)
                        radius: height / 2
                        color: scrubArea.active ? Glass.label : Glass.secondaryLabel
                        Behavior on color { ColorAnimation { duration: Glass.duration.fast } }
                    }
                }
                MouseArea {
                    id: scrub
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    property real dragPos: 0
                    onPressed: mouse => dragPos = Math.max(0, Math.min(1, mouse.x / width))
                    onPositionChanged: mouse => { if (pressed) dragPos = Math.max(0, Math.min(1, mouse.x / width)); }
                    onReleased: if (root.player?.canSeek) root.player.position = dragPos * root.length
                }
            }
            GlassText {
                text: "-" + StringUtils.friendlyTimeForSeconds(Math.max(0, root.length - (scrub.pressed ? scrub.dragPos * root.length : (root.player?.position ?? 0))))
                numeric: true
                font.pixelSize: Glass.size.caption
                font.weight: Font.Medium
                color: Glass.tertiaryLabel
            }
        }
    }
}
