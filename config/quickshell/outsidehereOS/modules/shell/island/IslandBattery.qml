import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import "islandBattery.js" as BatteryLogic

/**
 * Compact battery for the collapsed pill. Reads the existing Battery (UPower) service, no polling.
 * charging → green + bolt; <30% yellow; <20% red; <10% red + yellow hazard; otherwise white.
 * `preview` ({ percent, charging }) overrides the real values for testing (island IPC).
 */
Item {
    id: root
    property var preview: null
    readonly property real percent: root.preview ? root.preview.percent : Math.round(Battery.percentage * 100)
    readonly property bool charging: root.preview ? root.preview.charging : Battery.isCharging
    readonly property string state_: BatteryLogic.batteryState(root.percent, root.charging)

    readonly property color colGreen: Glass.green
    readonly property color colYellow: Glass.yellow
    readonly property color colRed: Glass.red
    readonly property color colNormal: Glass.label
    readonly property color mainColor: state_ === "charging" ? colGreen
        : state_ === "warning" ? colYellow
        : (state_ === "low" || state_ === "critical") ? colRed
        : colNormal

    implicitWidth: body.width + nub.width + (hazard.visible ? hazard.width - 2 : 0)
    implicitHeight: 14

    Rectangle { // outline
        id: body
        anchors.verticalCenter: parent.verticalCenter
        width: 23
        height: 12
        radius: 3.5
        color: "transparent"
        border.width: 1.4
        border.color: ColorUtils.applyAlpha(root.mainColor, 0.55)
        Behavior on border.color { ColorAnimation { duration: 250 } }

        Rectangle { // fill level
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                margins: 2.2
            }
            width: Math.max(2, (parent.width - 4.4) * Math.max(0, Math.min(100, root.percent)) / 100)
            radius: 1.6
            color: root.mainColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 250 } }
        }

        GlassIcon { // bolt while charging
            anchors.centerIn: parent
            visible: root.state_ === "charging"
            text: "bolt"
            iconSize: 13
            color: "#FFFFFF"
            style: Text.Outline
            styleColor: Qt.darker(root.colGreen, 1.6)
        }
    }
    Rectangle { // terminal nub
        id: nub
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 5
        radius: 1
        color: ColorUtils.applyAlpha(root.mainColor, 0.55)
    }
    GlassIcon { // hazard below 10%
        id: hazard
        anchors.left: nub.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        visible: root.state_ === "critical"
        text: "warning"
        iconSize: 14
        color: root.colYellow
    }
}
