import qs.modules.common
import QtQuick

/**
 * Text field in the Apple look: a rounded vibrant fill, an accent ring while focused.
 */
Rectangle {
    id: root
    property alias text: input.text
    property alias echoMode: input.echoMode
    property alias inputMethodHints: input.inputMethodHints
    property alias placeholderText: placeholder.text
    property alias input: input
    property int textSize: Glass.size.callout
    signal accepted()

    function focusInput() { input.forceActiveFocus(); }

    implicitHeight: 34
    implicitWidth: 200
    radius: 10
    color: Glass.fill
    border.width: input.activeFocus ? 2 : 0
    border.color: Glass.accent

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Glass.label
        selectionColor: Glass.accent
        selectedTextColor: Glass.accentLabel
        font.family: Glass.fontFamily
        font.pixelSize: root.textSize
        onAccepted: root.accepted()

        GlassText {
            id: placeholder
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            color: Glass.tertiaryLabel
            font.pixelSize: root.textSize
        }
    }
}
