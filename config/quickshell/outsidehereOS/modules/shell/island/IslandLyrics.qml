pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

/**
 * Time-synced lyrics (LRCLIB) for the playing track: the current line centered and bright,
 * neighbours dimmed, scrolling smoothly as the song moves on.
 */
Item {
    id: root
    property bool active: true // only poll the player position while shown
    property int visibleLines: 3
    readonly property real lineHeight: 28
    implicitHeight: lineHeight * visibleLines + 4

    // Register with the service only while active (idempotent: safe against initial binding flips)
    property bool counted: false
    function syncWatch() {
        if (root.active === root.counted) return;
        Lyrics.watchers += root.active ? 1 : -1;
        root.counted = root.active;
    }
    onActiveChanged: syncWatch()
    Component.onCompleted: syncWatch()
    Component.onDestruction: if (counted) Lyrics.watchers--

    readonly property string statusText: Lyrics.loading ? Translation.tr("Looking for lyrics…")
        : Lyrics.instrumental ? Translation.tr("♪ Instrumental ♪")
        : (!Lyrics.synced && Lyrics.plainLines.length > 0) ? Translation.tr("Only unsynced lyrics on LRCLIB")
        : !Lyrics.synced ? Translation.tr("No lyrics found")
        : ""

    GlassText {
        anchors.centerIn: parent
        visible: root.statusText.length > 0
        text: root.statusText
        color: Glass.tertiaryLabel
        font.pixelSize: Glass.size.subheadline
        font.weight: Font.Medium
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: Lyrics.synced && !Lyrics.loading
        clip: true
        interactive: false
        model: Lyrics.lines
        currentIndex: Math.max(0, Lyrics.currentIndex)
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (height - root.lineHeight) / 2
        preferredHighlightEnd: (height + root.lineHeight) / 2
        highlightMoveDuration: 450
        highlightMoveVelocity: -1

        delegate: Item {
            id: line
            required property int index
            required property var modelData
            readonly property bool current: index === Lyrics.currentIndex
            readonly property int distance: Math.abs(index - Lyrics.currentIndex)
            width: ListView.view.width
            height: root.lineHeight

            // Apple Music style: bold, the current line bright, the rest faded
            GlassText {
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: line.modelData.text.length > 0 ? line.modelData.text : "♪"
                font.pixelSize: line.current ? Glass.size.title3 : Glass.size.body
                font.weight: Font.Bold
                color: line.current ? Glass.label : Glass.tertiaryLabel
                opacity: line.current ? 1 : Math.max(0.25, 0.75 - line.distance * 0.25)
                scale: line.current ? 1 : 0.96

                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on font.pixelSize { NumberAnimation { duration: 200 } }
            }
        }
    }
}
