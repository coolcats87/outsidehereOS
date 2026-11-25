pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shell.overlay

/**
 * Volume mixer (Super+G), Liquid Glass: Output / Input segments, the device's volume with
 * mute, each app's volume, and the device list (tap to switch, ✓ = current).
 */
StyledOverlayWidget {
    id: root
    minimumWidth: 300
    minimumHeight: 380

    readonly property bool isSink: (Persistent.states.overlay.volumeMixer.tabIndex ?? 0) === 0
    readonly property var device: root.isSink ? Audio.sink : Audio.source
    readonly property var apps: root.isSink ? Audio.outputAppNodes : Audio.inputAppNodes
    readonly property var devices: root.isSink ? Audio.outputDevices : Audio.inputDevices

    PwObjectTracker { objects: [...root.apps, ...root.devices, root.device].filter(o => o) }

    contentItem: OverlayBackground {
        radius: root.contentRadius
        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 12

            GlassSegmented {
                Layout.fillWidth: true
                model: [{ icon: "volume_up", label: Translation.tr("Output") }, { icon: "mic", label: Translation.tr("Input") }]
                currentIndex: Persistent.states.overlay.volumeMixer.tabIndex ?? 0
                onSelected: index => Persistent.states.overlay.volumeMixer.tabIndex = index
            }

            // The device's own level
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                GlassSlider {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    icon: root.isSink ? ((root.device?.audio.muted ?? false) ? "volume_off" : "volume_up") : ((root.device?.audio.muted ?? false) ? "mic_off" : "mic")
                    value: (root.device?.audio.muted ?? false) ? 0 : (root.device?.audio.volume ?? 0)
                    onMoved: if (root.device?.audio) { root.device.audio.muted = false; root.device.audio.volume = value; }
                }
                GlassButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    icon: root.isSink ? "volume_off" : "mic_off"
                    iconSize: 16
                    toggled: root.device?.audio.muted ?? false
                    danger: true
                    onClicked: if (root.device?.audio) root.device.audio.muted = !root.device.audio.muted
                }
            }

            StyledFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: lists.implicitHeight
                clip: true

                ColumnLayout {
                    id: lists
                    width: parent.width
                    spacing: 8

                    SectionLabel { text: Translation.tr("Apps") }
                    GlassText {
                        Layout.fillWidth: true
                        visible: root.apps.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 6
                        bottomPadding: 6
                        text: root.isSink ? Translation.tr("No apps are playing sound") : Translation.tr("No apps are using the microphone")
                        font.pixelSize: Glass.size.footnote
                        color: Glass.tertiaryLabel
                    }
                    Repeater {
                        model: root.apps
                        delegate: RowLayout {
                            id: app
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 10
                            IconImage {
                                implicitSize: 26
                                source: Quickshell.iconPath(AppSearch.guessIcon(app.modelData.properties["application.icon-name"] ?? Audio.appNodeDisplayName(app.modelData)), "audio-x-generic")
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                GlassText {
                                    Layout.fillWidth: true
                                    text: Audio.appNodeDisplayName(app.modelData)
                                    elide: Text.ElideRight
                                    font.pixelSize: Glass.size.footnote
                                    font.weight: Font.Medium
                                }
                                GlassSlider {
                                    Layout.fillWidth: true
                                    implicitHeight: 22
                                    value: app.modelData.audio?.volume ?? 0
                                    onMoved: if (app.modelData.audio) app.modelData.audio.volume = value
                                }
                            }
                        }
                    }

                    SectionLabel { text: root.isSink ? Translation.tr("Output Device") : Translation.tr("Input Device"); Layout.topMargin: 6 }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: devCol.implicitHeight + 8
                        radius: 14
                        color: Glass.fill
                        ColumnLayout {
                            id: devCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4 }
                            spacing: 0
                            Repeater {
                                model: root.devices
                                delegate: Item {
                                    id: dev
                                    required property var modelData
                                    required property int index
                                    readonly property bool current: dev.modelData.id === root.device?.id
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    Rectangle {
                                        visible: dev.index > 0
                                        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12 }
                                        height: 1
                                        color: Glass.separator
                                    }
                                    Rectangle {
                                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                        radius: 10
                                        color: devMouse.containsMouse ? Glass.fillHover : "transparent"
                                    }
                                    GlassText {
                                        anchors { left: parent.left; right: check.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 8 }
                                        text: Audio.friendlyDeviceName(dev.modelData)
                                        elide: Text.ElideRight
                                        font.pixelSize: Glass.size.footnote
                                        font.weight: dev.current ? Font.DemiBold : Font.Normal
                                    }
                                    GlassIcon {
                                        id: check
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                                        text: "check"
                                        iconSize: 16
                                        color: Glass.accent
                                        visible: dev.current
                                    }
                                    MouseArea {
                                        id: devMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.isSink ? Audio.setDefaultSink(dev.modelData) : Audio.setDefaultSource(dev.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component SectionLabel: GlassText {
        Layout.leftMargin: 4
        font.pixelSize: Glass.size.caption
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.4
        color: Glass.secondaryLabel
    }
}
