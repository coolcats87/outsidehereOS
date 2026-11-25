pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

/**
 * Control Center (macOS style) that pops out of the island's corner button:
 * Wi-Fi / Bluetooth / Caffeine / Do Not Disturb modules, Display and Sound sliders,
 * output device picker, Wi-Fi network list (with password entry), Bluetooth devices.
 */
Item {
    id: root
    required property var screen
    property bool shown: false
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool wantsKeyboard: Network.friendlyWifiNetworks.some(n => n.askingPassword)

    property bool deviceListOpen: false
    property bool wifiListOpen: false
    property bool btListOpen: false
    onShownChanged: if (!shown) { deviceListOpen = false; wifiListOpen = false; btListOpen = false; }

    // Concentric with the panel (Island.qml qsBox radius 34, padding 16)
    readonly property real moduleRadius: 18

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 32

    component SectionLabel: GlassText {
        Layout.leftMargin: 4
        font.pixelSize: Glass.size.footnote
        font.weight: Font.DemiBold
        color: Glass.secondaryLabel
    }

    // A list row inside a platter: icon, title/subtitle, trailing glyph; accent check when selected
    component ListRow: Rectangle {
        id: lr
        property string iconName
        property string title
        property string subtitle: ""
        property bool selected: false
        property string trailingIcon: ""
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 12
        color: lrMouse.pressed ? Glass.fillPressed : lrMouse.containsMouse ? Glass.fill : "transparent"
        Behavior on color { ColorAnimation { duration: Glass.duration.fast } }
        MouseArea {
            id: lrMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lr.clicked()
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 10
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: lr.selected ? Glass.accent : Glass.fill
                GlassIcon {
                    anchors.centerIn: parent
                    text: lr.iconName
                    iconSize: 15
                    color: lr.selected ? Glass.accentLabel : Glass.label
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                GlassText {
                    Layout.fillWidth: true
                    text: lr.title
                    elide: Text.ElideRight
                    font.pixelSize: Glass.size.callout
                    font.weight: lr.selected ? Font.DemiBold : Font.Normal
                }
                GlassText {
                    Layout.fillWidth: true
                    visible: lr.subtitle.length > 0
                    text: lr.subtitle
                    elide: Text.ElideRight
                    font.pixelSize: Glass.size.caption
                    color: Glass.secondaryLabel
                }
            }
            GlassIcon {
                visible: lr.trailingIcon.length > 0
                text: lr.trailingIcon
                iconSize: 16
                fill: 0
                color: lr.trailingIcon === "check" ? Glass.accent : Glass.tertiaryLabel
            }
        }
    }

    // A Control Center module: round toggle (accent when on), title/subtitle, optional chevron
    component Module: Rectangle {
        id: mod
        property string icon
        property string title
        property string subtitle
        property bool on: false
        property color onColor: Glass.accent
        property bool hasList: false
        property bool listOpen: false
        signal toggled()
        signal listToggled()
        Layout.fillWidth: true
        implicitHeight: 60
        radius: root.moduleRadius
        color: modMouse.containsMouse ? Glass.platterHover : Glass.platter
        Behavior on color { ColorAnimation { duration: Glass.duration.fast } }

        MouseArea {
            id: modMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mod.toggled()
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 10
            Rectangle { // the round toggle
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                color: mod.on ? mod.onColor : Glass.fillStrong
                scale: modMouse.pressed ? 0.9 : 1
                Behavior on color { ColorAnimation { duration: Glass.duration.normal } }
                Behavior on scale { SpringAnimation { spring: Glass.spring.snappySpring; damping: Glass.spring.snappyDamping; epsilon: 0.002 } }
                GlassIcon {
                    anchors.centerIn: parent
                    text: mod.icon
                    iconSize: 19
                    color: mod.on ? Glass.accentLabel : Glass.label
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                GlassText {
                    Layout.fillWidth: true
                    text: mod.title
                    elide: Text.ElideRight
                    font.pixelSize: Glass.size.callout
                    font.weight: Font.DemiBold
                }
                GlassText {
                    Layout.fillWidth: true
                    text: mod.subtitle
                    elide: Text.ElideRight
                    font.pixelSize: Glass.size.caption
                    color: Glass.secondaryLabel
                }
            }
            GlassButton {
                visible: mod.hasList
                implicitWidth: 28
                implicitHeight: 28
                flat: true
                icon: "chevron_right"
                iconSize: 18
                rotation: mod.listOpen ? 90 : 0
                Behavior on rotation { SpringAnimation { spring: Glass.spring.snappySpring; damping: 0.5; epsilon: 0.1 } }
                onClicked: mod.listToggled()
            }
        }
    }

    // A rounded, height-animated platter for the dropdown lists
    component ListPlatter: Rectangle {
        Layout.fillWidth: true
        visible: implicitHeight > 0.5
        clip: true
        radius: 14
        color: Glass.platter
        // Smooth, no overshoot: the panel around it follows this height frame by frame
        Behavior on implicitHeight { NumberAnimation { duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.smooth } }
    }

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 16
        }
        spacing: 10

        // ── Connectivity: Wi-Fi, Bluetooth ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Module {
                icon: Network.ethernet ? "lan" : Network.wifiEnabled ? "wifi" : "wifi_off"
                title: Network.ethernet ? Translation.tr("Ethernet") : Translation.tr("Wi-Fi")
                subtitle: Network.ethernet ? Translation.tr("Connected")
                    : !Network.wifiEnabled ? Translation.tr("Off")
                    : Network.networkName.length > 0 ? Network.networkName : Translation.tr("Not Connected")
                on: Network.wifiEnabled || Network.ethernet
                hasList: Network.wifiEnabled
                listOpen: root.wifiListOpen
                onToggled: Network.toggleWifi()
                onListToggled: {
                    root.wifiListOpen = !root.wifiListOpen;
                    root.btListOpen = false;
                    if (root.wifiListOpen) Network.rescanWifi();
                }
            }
            Module {
                icon: !BluetoothStatus.enabled ? "bluetooth_disabled" : BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
                title: Translation.tr("Bluetooth")
                subtitle: !BluetoothStatus.available ? Translation.tr("Unavailable")
                    : !BluetoothStatus.enabled ? Translation.tr("Off")
                    : BluetoothStatus.activeDeviceCount === 1 ? (BluetoothStatus.firstActiveDevice?.name ?? "")
                    : BluetoothStatus.activeDeviceCount > 1 ? Translation.tr("%1 Devices").arg(BluetoothStatus.activeDeviceCount)
                    : Translation.tr("On")
                on: BluetoothStatus.enabled
                hasList: BluetoothStatus.enabled
                listOpen: root.btListOpen
                onToggled: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                onListToggled: {
                    root.btListOpen = !root.btListOpen;
                    root.wifiListOpen = false;
                }
            }
        }

        // ── Wi-Fi networks: opens right under the Wi-Fi / Bluetooth row ──
        ListPlatter {
            implicitHeight: root.wifiListOpen ? Math.min(wifiCol.implicitHeight + 12, 260) : 0
            StyledFlickable {
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: wifiCol.implicitHeight
                clip: true
                ColumnLayout {
                    id: wifiCol
                    width: parent.width
                    spacing: 2
                    GlassText {
                        visible: Network.wifiScanning && Network.friendlyWifiNetworks.length === 0
                        Layout.margins: 8
                        text: Translation.tr("Searching…")
                        color: Glass.secondaryLabel
                        font.pixelSize: Glass.size.callout
                    }
                    Repeater {
                        model: Network.friendlyWifiNetworks.slice(0, 10)
                        delegate: ColumnLayout {
                            id: net
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4
                            ListRow {
                                iconName: net.modelData.strength > 80 ? "signal_wifi_4_bar" : net.modelData.strength > 55 ? "network_wifi_3_bar"
                                    : net.modelData.strength > 30 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                                title: net.modelData.ssid
                                subtitle: net.modelData.active ? Translation.tr("Connected")
                                    : (Network.wifiConnecting && Network.wifiConnectTarget === net.modelData) ? Translation.tr("Connecting…") : ""
                                selected: net.modelData.active
                                trailingIcon: net.modelData.isSecure ? "lock" : ""
                                onClicked: net.modelData.active ? Network.disconnectWifiNetwork() : Network.connectToWifiNetwork(net.modelData)
                            }
                            RowLayout { // password prompt
                                Layout.fillWidth: true
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                Layout.bottomMargin: 4
                                visible: net.modelData.askingPassword
                                spacing: 6
                                GlassTextField {
                                    id: pw
                                    Layout.fillWidth: true
                                    placeholderText: Translation.tr("Password")
                                    echoMode: TextInput.Password
                                    inputMethodHints: Qt.ImhSensitiveData
                                    onVisibleChanged: if (visible) focusInput()
                                    onAccepted: Network.changePassword(net.modelData, pw.text)
                                }
                                GlassButton {
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    icon: "arrow_upward"
                                    highlighted: pw.text.length > 0
                                    onClicked: Network.changePassword(net.modelData, pw.text)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Bluetooth devices: opens right under the Wi-Fi / Bluetooth row ──
        ListPlatter {
            id: btPlatter
            // The list stays populated; only the height opens and closes (so content doesn't vanish first)
            readonly property var devices: !BluetoothStatus.enabled ? []
                : [...BluetoothStatus.connectedDevices, ...BluetoothStatus.pairedButNotConnectedDevices]
            readonly property bool showEmpty: BluetoothStatus.enabled && devices.length === 0
            implicitHeight: root.btListOpen ? btCol.implicitHeight + 12 : 0
            ColumnLayout {
                id: btCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                spacing: 2
                Repeater {
                    model: btPlatter.devices
                    delegate: ListRow {
                        required property var modelData
                        readonly property var dev: modelData
                        iconName: (dev.icon ?? "").includes("headset") || (dev.icon ?? "").includes("headphone") ? "headphones"
                            : (dev.icon ?? "").includes("mouse") ? "mouse"
                            : (dev.icon ?? "").includes("keyboard") ? "keyboard"
                            : (dev.icon ?? "").includes("phone") ? "smartphone"
                            : (dev.icon ?? "").includes("audio") ? "speaker" : "bluetooth"
                        title: dev.name
                        subtitle: dev.connected
                            ? (dev.batteryAvailable ? Translation.tr("Connected · %1%").arg(Math.round(dev.battery * 100)) : Translation.tr("Connected"))
                            : dev.state === BluetoothDeviceState.Connecting ? Translation.tr("Connecting…") : Translation.tr("Not Connected")
                        selected: dev.connected
                        onClicked: dev.connected ? dev.disconnect() : dev.connect()
                    }
                }
                GlassText {
                    visible: btPlatter.showEmpty
                    Layout.margins: 8
                    text: Translation.tr("No Paired Devices")
                    color: Glass.secondaryLabel
                    font.pixelSize: Glass.size.callout
                }
            }
        }

        // ── Caffeine, Focus ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Module {
                icon: "coffee"
                title: Translation.tr("Caffeine")
                subtitle: Idle.inhibit ? Translation.tr("Staying Awake") : Translation.tr("Off")
                on: Idle.inhibit
                onColor: Glass.orange
                onToggled: Idle.toggleInhibit()
            }
            Module {
                icon: "do_not_disturb_on"
                title: Translation.tr("Focus")
                subtitle: Notifications.silent ? Translation.tr("Do Not Disturb") : Translation.tr("Off")
                on: Notifications.silent
                onColor: Glass.indigo
                onToggled: Notifications.silent = !Notifications.silent
            }
        }

        // ── Display ──
        Rectangle {
            Layout.fillWidth: true
            visible: root.brightnessMonitor !== undefined && root.brightnessMonitor !== null
            implicitHeight: dispCol.implicitHeight + 24
            radius: root.moduleRadius
            color: Glass.platter
            ColumnLayout {
                id: dispCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 8
                GlassText {
                    text: Translation.tr("Display")
                    font.pixelSize: Glass.size.callout
                    font.weight: Font.DemiBold
                }
                GlassSlider {
                    Layout.fillWidth: true
                    icon: "light_mode"
                    value: root.brightnessMonitor?.brightness ?? 0
                    onMoved: root.brightnessMonitor?.setBrightness(value)
                }
            }
        }

        // ── Sound ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: soundCol.implicitHeight + 24
            radius: root.moduleRadius
            color: Glass.platter
            ColumnLayout {
                id: soundCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    GlassText {
                        Layout.fillWidth: true
                        text: Translation.tr("Sound")
                        font.pixelSize: Glass.size.callout
                        font.weight: Font.DemiBold
                    }
                    GlassText {
                        Layout.maximumWidth: 200
                        text: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Translation.tr("No Output")
                        elide: Text.ElideRight
                        font.pixelSize: Glass.size.caption
                        color: Glass.secondaryLabel
                    }
                    GlassButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        flat: true
                        icon: "chevron_right"
                        iconSize: 17
                        rotation: root.deviceListOpen ? 90 : 0
                        Behavior on rotation { SpringAnimation { spring: Glass.spring.snappySpring; damping: 0.5; epsilon: 0.1 } }
                        onClicked: root.deviceListOpen = !root.deviceListOpen
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    GlassSlider {
                        Layout.fillWidth: true
                        icon: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : Audio.value < 0.34 ? "volume_mute" : Audio.value < 0.67 ? "volume_down" : "volume_up"
                        value: Math.min(1, Audio.sink?.audio?.volume ?? 0)
                        onMoved: if (Audio.sink?.audio) Audio.sink.audio.volume = value
                        opacity: (Audio.sink?.audio?.muted ?? false) ? 0.5 : 1
                    }
                    GlassButton {
                        implicitWidth: 30
                        implicitHeight: 30
                        icon: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
                        iconSize: 16
                        toggled: Audio.sink?.audio?.muted ?? false
                        danger: true
                        onClicked: Audio.toggleMute()
                    }
                }
                // Output devices (inline, so hovering it keeps the island open)
                Item {
                    Layout.fillWidth: true
                    implicitHeight: root.deviceListOpen ? devCol.implicitHeight : 0
                    visible: implicitHeight > 0.5
                    clip: true
                    Behavior on implicitHeight { NumberAnimation { duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.smooth } }
                    ColumnLayout {
                        id: devCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: 2
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Glass.separator; Layout.bottomMargin: 4 }
                        Repeater {
                            model: Audio.outputDevices
                            delegate: ListRow {
                                required property var modelData
                                iconName: (modelData.properties?.["device.api"] === "bluez5" || (modelData.name ?? "").includes("bluez")) ? "headphones"
                                    : (modelData.name ?? "").includes("hdmi") ? "tv" : "speaker"
                                title: Audio.friendlyDeviceName(modelData)
                                selected: Audio.sink === modelData
                                trailingIcon: selected ? "check" : ""
                                onClicked: Audio.setDefaultSink(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
