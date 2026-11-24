pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Polkit authentication, Liquid Glass (macOS-style sheet). Every screen dims (and blurs, via
 * the quickshell:island.* layer rule); the dialog sits on the focused one.
 * Same PolkitService flow as end4's. Esc / Cancel cancels, a wrong password shakes it.
 * `qs -c outsidehereOS ipc call polkit cancel` cancels from outside.
 */
Scope {
    id: root
    readonly property string focusedName: Hyprland.focusedMonitor?.name ?? ""
    property int failSerial: 0
    property string username: ""

    Connections {
        target: PolkitService.flow ?? null
        function onAuthenticationFailed() { root.failSerial++; }
    }
    Process {
        running: true
        command: ["whoami"]
        stdout: StdioCollector { onStreamFinished: root.username = text.trim() }
    }

    Loader {
        active: PolkitService.active
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: win
                required property var modelData
                readonly property bool hasDialog: win.modelData.name === root.focusedName
                    || (root.focusedName === "" && win.modelData === Quickshell.screens[0])
                screen: modelData
                anchors { top: true; left: true; right: true; bottom: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell:islandPolkit"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: win.hasDialog ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                property bool shown: false
                Component.onCompleted: win.shown = true

                Rectangle {
                    anchors.fill: parent
                    color: Glass.scrim
                    opacity: win.shown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent } // swallow clicks around the dialog

                Loader {
                    active: win.hasDialog
                    anchors.centerIn: parent
                    sourceComponent: GlassSurface {
                        id: dialog
                        width: 372
                        height: col.implicitHeight + 48
                        radius: 30
                        tint: Glass.thick
                        opacity: win.shown ? 1 : 0
                        scale: win.shown ? 1 : 0.92
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }
                        transform: Translate { id: shake }

                        function submit() {
                            if (!PolkitService.interactionAvailable) return;
                            PolkitService.submit(field.text);
                        }
                        Connections {
                            target: root
                            function onFailSerialChanged() { field.text = ""; shakeAnim.restart(); field.focusInput(); }
                        }
                        Connections {
                            target: PolkitService
                            function onInteractionAvailableChanged() { if (PolkitService.interactionAvailable) field.focusInput(); }
                        }
                        Component.onCompleted: field.focusInput()

                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
                            NumberAnimation { target: shake; property: "x"; to: 14; duration: 60 }
                            NumberAnimation { target: shake; property: "x"; to: -9; duration: 55 }
                            NumberAnimation { target: shake; property: "x"; to: 9; duration: 55 }
                            NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
                        }

                        ColumnLayout {
                            id: col
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                            spacing: 0

                            Rectangle { // lock badge
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 64
                                implicitHeight: 64
                                radius: 18
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.lighter(Glass.accent, 1.25) }
                                    GradientStop { position: 1; color: Glass.accent }
                                }
                                GlassIcon {
                                    anchors.centerIn: parent
                                    text: "lock"
                                    fill: 1
                                    iconSize: 34
                                    color: "white"
                                }
                            }
                            GlassText {
                                Layout.fillWidth: true
                                Layout.topMargin: 16
                                horizontalAlignment: Text.AlignHCenter
                                text: Translation.tr("Authentication Required")
                                font.pixelSize: Glass.size.headline
                                font.weight: Font.Bold
                            }
                            GlassText {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: 5
                                elide: Text.ElideRight
                                text: PolkitService.cleanMessage + "."
                                font.pixelSize: Glass.size.footnote
                                color: Glass.secondaryLabel
                            }
                            GlassText {
                                Layout.fillWidth: true
                                Layout.topMargin: 10
                                horizontalAlignment: Text.AlignHCenter
                                text: Translation.tr("Enter the password for “%1” to allow this.").arg(root.username)
                                visible: root.username.length > 0
                                wrapMode: Text.Wrap
                                font.pixelSize: Glass.size.footnote
                                color: Glass.secondaryLabel
                            }

                            GlassTextField {
                                id: field
                                Layout.fillWidth: true
                                Layout.topMargin: 18
                                implicitHeight: 36
                                radius: 12
                                enabled: PolkitService.interactionAvailable
                                echoMode: (PolkitService.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                                inputMethodHints: Qt.ImhSensitiveData
                                placeholderText: root.failSerial > 0 && field.text.length === 0 ? Translation.tr("Incorrect password, try again") : PolkitService.cleanPrompt
                                onAccepted: dialog.submit()
                                input.Keys.onEscapePressed: PolkitService.cancel()
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 18
                                spacing: 10
                                GlassButton {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    text: Translation.tr("Cancel")
                                    colBackground: Glass.fillStrong
                                    onClicked: PolkitService.cancel()
                                }
                                GlassButton {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    text: PolkitService.interactionAvailable ? Translation.tr("Authenticate") : Translation.tr("Checking…")
                                    highlighted: true
                                    enabled: PolkitService.interactionAvailable && field.text.length > 0
                                    opacity: enabled ? 1 : 0.55
                                    onClicked: dialog.submit()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "polkit"
        function cancel(): void { if (PolkitService.active) PolkitService.cancel(); }
    }
}
