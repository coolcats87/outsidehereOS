pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * What the island turns into when a notification arrives (replaces end4's popups):
 * app icon, app name, "now", summary, two lines of body, action capsules.
 * Island.qml sizes the pill around this; hovering it opens the full island.
 */
Item {
    id: root
    property var notif: null
    property int moreCount: 0      // other notifications still waiting behind this one
    signal activated()             // banner clicked
    readonly property var actions: (root.notif?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool urgent: (root.notif?.urgency ?? "") === "critical"

    implicitHeight: row.implicitHeight

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 12

        IslandNotifIcon {
            Layout.alignment: Qt.AlignTop
            notif: root.notif
            size: 42
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                GlassText {
                    text: (root.notif?.appName ?? "") || Translation.tr("Notification")
                    elide: Text.ElideRight
                    Layout.maximumWidth: 220
                    font.pixelSize: Glass.size.footnote
                    font.weight: Font.DemiBold
                    color: root.urgent ? Glass.red : Glass.secondaryLabel
                }
                Rectangle { // "+2": more notifications queued behind this one
                    visible: root.moreCount > 0
                    implicitWidth: moreText.implicitWidth + 10
                    implicitHeight: 16
                    radius: 8
                    color: Glass.fillStrong
                    GlassText {
                        id: moreText
                        anchors.centerIn: parent
                        text: `+${root.moreCount}`
                        numeric: true
                        font.pixelSize: Glass.size.caption
                        font.weight: Font.DemiBold
                    }
                }
                Item { Layout.fillWidth: true }
                GlassText {
                    text: { DateTime.time; return NotificationUtils.getFriendlyNotifTimeString(root.notif?.time ?? Date.now()); }
                    font.pixelSize: Glass.size.footnote
                    color: Glass.tertiaryLabel
                }
            }
            GlassText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.notif?.summary ?? ""
                elide: Text.ElideRight
                font.pixelSize: Glass.size.headline
                font.weight: Font.DemiBold
            }
            GlassText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: NotificationUtils.processNotificationBody(root.notif?.body ?? "", (root.notif?.appName ?? "") || (root.notif?.summary ?? "")).replace(/\n/g, "<br/>")
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Glass.size.subheadline
                color: Glass.secondaryLabel
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 8
                visible: root.actions.length > 0
                spacing: 6
                Repeater {
                    model: root.actions
                    delegate: GlassButton {
                        required property var modelData
                        implicitHeight: 30
                        padding: 14
                        text: modelData.text
                        textSize: Glass.size.footnote
                        colBackground: Glass.fillStrong
                        onClicked: Notifications.attemptInvokeAction(root.notif.notificationId, modelData.identifier)
                    }
                }
            }
        }
    }
}
