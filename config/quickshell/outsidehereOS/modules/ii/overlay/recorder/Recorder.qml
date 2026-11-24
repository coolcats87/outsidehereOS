pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 310
    minimumHeight: 130

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8
        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 10

            Row {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 10

                BigRecorderButton {
                    materialSymbol: "screenshot_region"
                    name: "Screenshot region"
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                    }
                }

                BigRecorderButton {
                    materialSymbol: "photo_camera"
                    name: "Screenshot"
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["bash", "-c", "grim - | wl-copy"]);
                    }
                }

                BigRecorderButton {
                    materialSymbol: "screen_record"
                    name: "Record region"
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "recordWithSound"]);
                    }
                }
                
                BigRecorderButton {
                    materialSymbol: "capture"
                    name: "Record screen"
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]);
                    }
                }
            }

            RippleButton {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.fillWidth: false
                buttonRadius: height / 2
                colBackground: Glass.fill
                colBackgroundHover: Glass.fillHover
                colRipple: Glass.fillPressed
                onClicked: {
                    GlobalStates.overlayOpen = false;
                    Qt.openUrlExternally(`file://${Config.options.screenRecord.savePath}`);
                }
                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 6
                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "folder_open"
                        iconSize: 18
                    }
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Open Recordings Folder")
                        font.pixelSize: Glass.size.footnote
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    component BigRecorderButton: RippleButton {
        id: bigButton
        required property string materialSymbol
        required property string name
        implicitHeight: 66
        implicitWidth: 66
        buttonRadius: height / 2

        colBackground: Glass.fill
        colBackgroundHover: Glass.fillHover
        colRipple: Glass.fillPressed

        contentItem: GlassIcon {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: bigButton.materialSymbol
            iconSize: 26
        }

        StyledToolTip {
            text: bigButton.name
        }
    }
}
