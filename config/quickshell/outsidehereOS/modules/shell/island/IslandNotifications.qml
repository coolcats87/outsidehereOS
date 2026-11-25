pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

/**
 * Notification Center, Apple style: a header, then one glass platter per notification
 * (newest first) with the app icon, app name, relative time, summary, body and action
 * capsules. Hover shows the dismiss button; clicking runs the default action.
 * Replaces end4's NotificationListView in the island.
 */
ColumnLayout {
    id: root
    property real platterRadius: 18
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 4
        GlassText {
            Layout.fillWidth: true
            text: Translation.tr("Notifications")
            font.pixelSize: Glass.size.title3
            font.weight: Font.Bold
        }
        GlassButton {
            implicitWidth: 30; implicitHeight: 30
            icon: Notifications.silent ? "do_not_disturb_on" : "do_not_disturb_off"
            iconSize: 17
            toggled: Notifications.silent
            accent: Glass.indigo // Focus mode colour
            onClicked: Notifications.silent = !Notifications.silent
            GlassToolTip { text: Notifications.silent ? Translation.tr("Do Not Disturb is on") : Translation.tr("Do Not Disturb") }
        }
        GlassButton {
            visible: Notifications.list.length > 0
            implicitHeight: 30
            padding: 12
            text: Translation.tr("Clear")
            textSize: Glass.size.footnote
            onClicked: Notifications.discardAllNotifications()
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list
            anchors.fill: parent
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: [...Notifications.list].reverse()
                objectProp: "notificationId"
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Glass.duration.normal }
                    NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: Glass.duration.fast }
                    NumberAnimation { property: "x"; to: list.width * 0.4; duration: Glass.duration.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.exit }
                }
            }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.smooth }
            }

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var notif: modelData
                readonly property var actions: (notif?.actions ?? []).filter(a => a.identifier !== "default")
                readonly property bool hasDefault: (notif?.actions ?? []).some(a => a.identifier === "default")
                readonly property bool urgent: (notif?.urgency ?? "") === "critical"
                readonly property bool hovered: cardMouse.containsMouse || closeBtn.hovered

                width: ListView.view.width
                implicitHeight: content.implicitHeight + 24
                radius: root.platterRadius
                color: card.hovered ? Glass.platterHover : Glass.platter
                border.width: card.urgent ? 1.5 : 0
                border.color: Glass.red
                Behavior on color { ColorAnimation { duration: Glass.duration.fast } }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: card.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (card.hasDefault) Notifications.attemptInvokeAction(card.notif.notificationId, "default")
                }

                RowLayout {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 10

                    IslandNotifIcon {
                        Layout.alignment: Qt.AlignTop
                        notif: card.notif
                        size: 34
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            GlassText {
                                Layout.fillWidth: true
                                text: (card.notif?.appName ?? "") || Translation.tr("Notification")
                                elide: Text.ElideRight
                                font.pixelSize: Glass.size.caption
                                font.weight: Font.DemiBold
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.4
                                color: Glass.secondaryLabel
                            }
                            GlassText {
                                // DateTime.time ticks every minute, which refreshes "5m ago"
                                text: { DateTime.time; return NotificationUtils.getFriendlyNotifTimeString(card.notif?.time ?? Date.now()); }
                                font.pixelSize: Glass.size.caption
                                color: Glass.tertiaryLabel
                                opacity: card.hovered ? 0 : 1 // the dismiss button takes its place
                                Behavior on opacity { NumberAnimation { duration: Glass.duration.fast } }
                            }
                        }
                        GlassText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: card.notif?.summary ?? ""
                            elide: Text.ElideRight
                            font.pixelSize: Glass.size.subheadline
                            font.weight: Font.DemiBold
                        }
                        GlassText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: NotificationUtils.processNotificationBody(card.notif?.body ?? "", (card.notif?.appName ?? "") || (card.notif?.summary ?? "")).replace(/\n/g, "<br/>")
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            font.pixelSize: Glass.size.subheadline
                            color: Glass.secondaryLabel
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                        Flow {
                            id: actionsRow
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            visible: card.actions.length > 0
                            spacing: 6
                            Repeater {
                                model: card.actions
                                delegate: GlassButton {
                                    required property var modelData
                                    implicitHeight: 28
                                    padding: 12
                                    text: modelData.text
                                    textSize: Glass.size.footnote
                                    colBackground: Glass.fillStrong
                                    onClicked: Notifications.attemptInvokeAction(card.notif.notificationId, modelData.identifier)
                                }
                            }
                        }
                    }
                }

                GlassButton { // dismiss, where the time is, on hover
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    implicitWidth: 22
                    implicitHeight: 22
                    icon: "close"
                    iconSize: 13
                    colBackground: Glass.thick
                    colBackgroundHover: Glass.fillPressed
                    opacity: card.hovered ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Glass.duration.fast } }
                    onClicked: Notifications.discardNotification(card.notif.notificationId)
                }
            }
        }

        ColumnLayout { // Empty state
            anchors.centerIn: parent
            visible: Notifications.list.length === 0
            spacing: 6
            GlassIcon {
                Layout.alignment: Qt.AlignHCenter
                text: Notifications.silent ? "do_not_disturb_on" : "notifications"
                iconSize: 34
                color: Glass.tertiaryLabel
            }
            GlassText {
                Layout.alignment: Qt.AlignHCenter
                text: Notifications.silent ? Translation.tr("Do Not Disturb") : Translation.tr("No Notifications")
                font.pixelSize: Glass.size.callout
                font.weight: Font.Medium
                color: Glass.secondaryLabel
            }
        }
    }
}
