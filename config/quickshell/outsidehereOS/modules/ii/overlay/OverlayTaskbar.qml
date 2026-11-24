pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.island

GlassSurface {
    id: root

    property real padding: 7

    opacity: GlobalStates.overlayOpen ? 1 : 0
    scale: GlobalStates.overlayOpen ? 1 : 0.94
    implicitWidth: contentRow.implicitWidth + (padding * 2)
    implicitHeight: contentRow.implicitHeight + (padding * 2)
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    tint: Glass.regular

    Behavior on opacity { NumberAnimation { duration: Glass.duration.fast } }
    Behavior on scale { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Row {
            spacing: 4
            Repeater {
                model: ScriptModel {
                    values: OverlayContext.availableWidgets
                }
                delegate: WidgetButton {
                    required property var modelData
                    identifier: modelData.identifier
                    materialSymbol: modelData.materialSymbol
                }
            }
        }

        Separator {}
        GlassText {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 6
            Layout.rightMargin: 4
            text: DateTime.time
            numeric: true
            font.pixelSize: Glass.size.title3
            font.weight: Font.DemiBold
        }
        Separator { visible: Battery.available }
        Row {
            visible: Battery.available
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
            Layout.rightMargin: 10
            spacing: 6
            GlassText {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Battery.percentage * 100) + "%"
                numeric: true
                font.pixelSize: Glass.size.subheadline
                font.weight: Font.DemiBold
                color: Battery.isLowAndNotCharging ? Glass.red : Glass.label
            }
            IslandBattery { anchors.verticalCenter: parent.verticalCenter }
        }
    }

    component Separator: Rectangle {
        implicitWidth: 1
        implicitHeight: 22
        color: Glass.separator
        Layout.alignment: Qt.AlignVCenter
    }

    component WidgetButton: GlassButton {
        id: widgetButton
        required property string identifier
        required property string materialSymbol

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 40
        implicitHeight: 40
        icon: widgetButton.materialSymbol
        iconSize: 20
        iconFill: widgetButton.toggled ? 1 : 0
        flat: !widgetButton.toggled
        toggled: Persistent.states.overlay.open.includes(identifier)
        onClicked: {
            if (widgetButton.toggled) {
                Persistent.states.overlay.open = Persistent.states.overlay.open.filter(type => type !== identifier);
            } else {
                Persistent.states.overlay.open.push(identifier);
            }
        }
        // Right-click: bring it to the centre (end4's altAction)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: OverlayContext.requestCenter(widgetButton.identifier)
        }
    }
}
