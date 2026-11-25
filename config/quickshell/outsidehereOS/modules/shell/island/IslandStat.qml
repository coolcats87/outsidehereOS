import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * A resource platter (Apple widget style): small caps label with a tinted glyph, a big
 * rounded percentage, a thin capsule meter and a detail line. The meter goes from the
 * system blue to orange to red as the value climbs.
 */
Rectangle {
    id: root
    property string icon: "memory"
    property string label: ""
    property real value: 0 // 0..1, or < 0 for "n/a"
    property string valueText: value < 0 ? "—" : `${Math.round(value * 100)}%`
    property string detail: ""
    readonly property color accent: value > 0.85 ? Glass.red
        : value > 0.6 ? Glass.orange : Glass.accent

    radius: 18
    color: Glass.platter
    implicitHeight: col.implicitHeight + 22
    implicitWidth: 120

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: 12
        }
        spacing: 4

        RowLayout {
            spacing: 5
            GlassIcon {
                text: root.icon
                iconSize: 14
                color: root.accent
                Behavior on color { ColorAnimation { duration: Glass.duration.normal } }
            }
            GlassText {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                color: Glass.secondaryLabel
                font.pixelSize: Glass.size.caption
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.4
            }
        }
        GlassText {
            text: root.valueText
            numeric: true
            font.family: Glass.fontRounded
            font.pixelSize: Glass.size.title2
            font.weight: Font.DemiBold
        }
        Rectangle { // meter
            Layout.fillWidth: true
            implicitHeight: 5
            radius: 2.5
            color: Glass.track
            Rectangle {
                height: parent.height
                radius: 2.5
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
                visible: root.value >= 0
                color: root.accent
                Behavior on width { SpringAnimation { spring: Glass.spring.snappySpring; damping: 0.6; epsilon: 0.25 } }
                Behavior on color { ColorAnimation { duration: Glass.duration.normal } }
            }
        }
        GlassText {
            Layout.fillWidth: true
            visible: root.detail.length > 0
            text: root.detail
            elide: Text.ElideRight
            color: Glass.tertiaryLabel
            font.pixelSize: Glass.size.caption
        }
    }
}
