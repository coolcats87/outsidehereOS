pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.panels.lock
import qs.modules.ii.island

/**
 * Lock screen, Apple Liquid Glass style (replaces LockSurface.qml in Lock.qml).
 *
 *   top:     date + a big glass clock; now playing and unseen notifications on glass below
 *   top-right: keyboard layout, network, battery
 *   bottom:  avatar, name, password capsule, then Sleep / Restart / Shut Down
 *
 * Logic is end4's (LockContext: PAM, fingerprint, password-guarded power actions,
 * Ctrl+Enter unlocks and keeps the screen awake). `preview: true` is a dry run in a normal
 * window (Lock.qml's lockPreview IPC): Esc closes it and power/sleep do nothing.
 */
MouseArea {
    id: root
    required property LockContext context
    property bool preview: false
    signal previewClose()
    signal debugExpand(string app)

    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower
    readonly property real s: Math.max(0.6, height / 1080) // scale for big type

    function forceFieldFocus() { field.forceActiveFocus(); }
    Connections {
        target: root.context
        function onShouldReFocus() { root.forceFieldFocus(); }
    }
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: root.forceFieldFocus()
    onPositionChanged: root.forceFieldFocus()

    property bool ctrlHeld: false
    Keys.onPressed: event => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control) root.ctrlHeld = true;
        if (event.key === Qt.Key_Escape) {
            if (root.preview && root.context.currentText.length === 0) root.previewClose();
            root.context.currentText = "";
        }
        root.forceFieldFocus();
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) root.ctrlHeld = false;
        root.forceFieldFocus();
    }

    // Entrance: things settle into place
    property real enter: 0
    Component.onCompleted: { root.forceFieldFocus(); root.enter = 1; }
    Behavior on enter { NumberAnimation { duration: 650; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.smooth } }

    // ───────────── Wallpaper (sharp, and a blurred copy the glass shows through) ─────────────
    readonly property string wallpaperPath: {
        const path = Config.options.background.wallpaperPath;
        const isVideo = [".mp4", ".webm", ".mkv", ".avi", ".mov"].some(ext => path.endsWith(ext));
        return isVideo ? Config.options.background.thumbnailPath : path;
    }
    Rectangle { anchors.fill: parent; color: "black" }
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        cache: false
        visible: false // drawn through `backdrop` and `blurred`
    }
    MultiEffect { // the frosted copy: glass panes sample their piece of this
        id: blurred
        anchors.fill: parent
        source: wall
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        blurMultiplier: 1.6
        saturation: 0.25
        brightness: Glass.dark ? -0.06 : 0.04
    }
    Item { // the sharp wallpaper, over the blurred one
        id: backdrop
        anchors.fill: parent
        MultiEffect {
            anchors.fill: parent
            source: wall
            autoPaddingEnabled: false
            // a whisper of blur and dim, like a screen at rest
            blurEnabled: true
            blur: 0.18
            blurMax: 24
            brightness: -0.08
        }
        Rectangle { // legibility: darker towards the top (clock) and bottom (login)
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.32) }
                GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 0.62; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.42) }
            }
        }
    }

    // ───────────── Top right: status ─────────────
    GlassLockPane {
        id: status
        blurSource: blurred
        anchors { top: parent.top; right: parent.right; topMargin: 14; rightMargin: 16 }
        width: statusRow.implicitWidth + 24
        height: 32
        opacity: root.enter
        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 12
            GlassText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text.length > 0
                text: HyprlandXkb.currentLayoutCode.toUpperCase()
                font.pixelSize: Glass.size.footnote
                font.weight: Font.DemiBold
                color: "white"
            }
            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Network.materialSymbol
                iconSize: 17
                color: "white"
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Battery.available
                spacing: 6
                GlassText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round(Battery.percentage * 100)}%`
                    numeric: true
                    font.pixelSize: Glass.size.footnote
                    font.weight: Font.DemiBold
                    color: "white"
                }
                IslandBattery { anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ───────────── Clock ─────────────
    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.07 - (1 - root.enter) * 30
        opacity: root.enter
        spacing: -8 * root.s

        GlassText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale().toString(DateTime.clock.date, "dddd, d MMMM")
            font.pixelSize: Math.round(24 * root.s)
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.92)
        }
        Item { // The time, in glass (refracts the wallpaper), like iOS 26 / Tahoe
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockText.implicitWidth
            height: clockText.implicitHeight
            LiquidGlassEffect {
                anchors.fill: parent
                backdrop: backdrop
                bezel: 12 * root.s
                refraction: 18 * root.s
                bodyLens: 0
                frost: 1.0
                rim: 1.1
                brightness: 1.15
                adaptiveDim: 0.1
                tint: Qt.rgba(1, 1, 1, 0.22)
                dispersion: 0.25
                shadow: 0.25
                mapTick: root.enter + clock.y

                Text {
                    id: clockText
                    text: DateTime.time
                    color: "white"
                    font.family: Glass.fontRounded
                    font.pixelSize: Math.round(176 * root.s)
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    font.letterSpacing: -3 * root.s
                }
            }
        }
    }

    // ───────────── Now playing + unseen notifications ─────────────
    ColumnLayout {
        id: widgets
        anchors.horizontalCenter: parent.horizontalCenter
        y: clock.y + clock.height + 26 * root.s
        width: Math.min(440, root.width - 40)
        spacing: 10
        opacity: root.enter
        readonly property real room: login.y - 30 - y

        GlassLockPane {
            id: media
            Layout.fillWidth: true
            blurSource: blurred
            visible: Config.options.lock.showMedia && (MprisController.activePlayer?.trackTitle?.length ?? 0) > 0
            implicitHeight: nowPlaying.implicitHeight + 28
            radius: 24
            tint: Glass.regular
            mapTick: root.enter + widgets.y
            IslandNowPlaying {
                id: nowPlaying
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            }
        }

        // Notifications that arrived since you last looked, stacked per app like iOS:
        // the newest card in front, up to two peeking out under it. Tap a stack to
        // fan it out; "Show less" folds it back. Acting on them waits for the unlock.
        readonly property bool showContent: Config.options.lock.notifications.showContent
        readonly property var unseen: Config.options.lock.notifications.enable
            ? Notifications.list.filter(n => n.time > Notifications.readUntil).slice().reverse() : []
        readonly property var groups: {
            const byApp = {}, order = [];
            for (const n of widgets.unseen) {
                const app = n.appName || Translation.tr("Notification");
                if (!byApp[app]) { byApp[app] = []; order.push(app); }
                byApp[app].push(n);
            }
            return order.map(app => ({ app: app, notifs: byApp[app] }));
        }
        property string expandedApp: ""
        onGroupsChanged: if (widgets.expandedApp !== "" && !widgets.groups.some(g => g.app === widgets.expandedApp)) widgets.expandedApp = ""
        // Rough heights, to decide how many stacks fit above the password field
        readonly property real cardEstimate: 92
        readonly property real notifRoom: widgets.room - (media.visible ? media.height + widgets.spacing : 0)
        readonly property int expandedFit: Math.max(1, Math.floor((widgets.notifRoom - 40) / (widgets.cardEstimate + 8)))
        readonly property var shownGroups: {
            let used = 0;
            const out = [];
            const groups = widgets.expandedApp !== "" ? widgets.groups.filter(g => g.app === widgets.expandedApp) : widgets.groups;
            for (const g of groups) {
                const h = widgets.expandedApp !== "" ? 0 : widgets.cardEstimate + Math.min(2, g.notifs.length - 1) * 9 + widgets.spacing;
                if (used + h > widgets.notifRoom - 30) break;
                used += h;
                out.push(g);
            }
            return out;
        }
        readonly property int hiddenCount: widgets.groups.filter(g => !widgets.shownGroups.includes(g))
            .reduce((sum, g) => sum + (widgets.expandedApp !== "" ? 0 : g.notifs.length), 0)

        Repeater {
            model: widgets.shownGroups
            delegate: ColumnLayout {
                id: group
                required property var modelData
                readonly property var notifs: group.modelData.notifs.slice(0, group.expanded ? widgets.expandedFit : 3)
                readonly property bool expanded: widgets.expandedApp === group.modelData.app
                Layout.fillWidth: true
                spacing: 0

                // Fanned-out header: app name, Show less, clear
                Item {
                    Layout.fillWidth: true
                    implicitHeight: group.expanded ? 38 : 0
                    clip: true
                    Behavior on implicitHeight { NumberAnimation { duration: Glass.duration.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.smooth } }
                    RowLayout {
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 6 }
                        height: 30
                        opacity: group.expanded ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Glass.duration.fast } }
                        GlassText {
                            Layout.fillWidth: true
                            text: group.modelData.app
                            elide: Text.ElideRight
                            font.pixelSize: Glass.size.title3
                            font.weight: Font.Bold
                            color: "white"
                        }
                        PillButton { label: Translation.tr("Show less"); icon: "keyboard_arrow_up"; onClicked: widgets.expandedApp = "" }
                        PillButton {
                            icon: "close"
                            onClicked: {
                                group.modelData.notifs.forEach(n => Notifications.discardNotification(n.notificationId));
                                widgets.expandedApp = "";
                            }
                        }
                    }
                }

                Item { // the stack itself; cards move between stacked and fanned-out positions
                    id: stack
                    Layout.fillWidth: true
                    property int heightsTick: 0
                    function cardH(i) { stack.heightsTick; const it = cards.itemAt(i); return it ? it.implicitHeight : widgets.cardEstimate; }
                    // test hook: fan out a stack without clicking
                    Connections { target: root; function onDebugExpand(app) { widgets.expandedApp = app; } }
                    function cardY(i) {
                        if (group.expanded) { let y = 0; for (let j = 0; j < i; j++) y += stack.cardH(j) + 8; return y; }
                        if (i === 0) return 0;
                        return stack.cardH(0) - stack.cardH(i) + Math.min(i, 2) * 9;
                    }
                    implicitHeight: {
                        stack.heightsTick;
                        const n = cards.count;
                        if (n === 0) return 0;
                        return group.expanded ? stack.cardY(n - 1) + stack.cardH(n - 1) : stack.cardH(0) + Math.min(n - 1, 2) * 9;
                    }
                    Behavior on implicitHeight { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }

                    Repeater {
                        id: cards
                        model: group.notifs
                        // Each card sits in a clip "slot": a card behind the front one only
                        // draws the part peeking out below it (the front glass is see-through)
                        delegate: Item {
                            id: slot
                            required property var modelData
                            required property int index
                            readonly property int depth: group.expanded ? 0 : slot.index
                            readonly property bool peeking: !group.expanded && slot.index > 0
                            implicitHeight: card.implicitHeight
                            onImplicitHeightChanged: stack.heightsTick++
                            property real py: stack.cardY(slot.index)
                            Behavior on py { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }
                            z: -slot.index
                            clip: slot.peeking
                            width: stack.width
                            y: slot.peeking ? Math.min(stack.cardH(0), slot.py + card.height) : slot.py
                            height: slot.peeking ? Math.max(0, slot.py + card.height - slot.y) : card.height
                            opacity: slot.depth === 0 ? 1 : slot.depth === 1 ? 0.8 : slot.depth === 2 ? 0.6 : 0
                            Behavior on opacity { NumberAnimation { duration: Glass.duration.normal } }

                            NotifCard {
                                id: card
                                notif: slot.modelData
                                x: slot.depth * 12
                                y: slot.py - slot.y
                                width: stack.width - slot.depth * 24
                                height: implicitHeight
                                contentOpacity: slot.depth === 0 ? 1 : 0
                                mapTick: root.enter + widgets.y + group.y + stack.y + slot.y + card.y + card.x
                                Behavior on x { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }
                                Behavior on width { NumberAnimation { duration: Glass.duration.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }
                            }
                        }
                    }
                    MouseArea { // tap a stack to fan it out
                        anchors.fill: parent
                        enabled: !group.expanded && group.modelData.notifs.length > 1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: widgets.expandedApp = group.modelData.app
                    }
                }
            }
        }
        GlassText {
            Layout.alignment: Qt.AlignHCenter
            visible: widgets.hiddenCount > 0
            text: widgets.hiddenCount === 1 ? Translation.tr("1 more notification") : Translation.tr("%1 more notifications").arg(widgets.hiddenCount)
            font.pixelSize: Glass.size.footnote
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.75)
        }
    }

    component PillButton: GlassLockPane {
        id: pill
        property string label: ""
        property string icon: ""
        signal clicked()
        blurSource: blurred
        implicitWidth: pillRow.implicitWidth + (pill.label.length > 0 ? 22 : 12)
        implicitHeight: 28
        tint: pillMouse.containsMouse ? Glass.regular : Glass.clear
        scale: pillMouse.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: Glass.duration.fast } }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 3
            GlassIcon { anchors.verticalCenter: parent.verticalCenter; visible: pill.icon.length > 0; text: pill.icon; iconSize: 16; color: "white" }
            GlassText { anchors.verticalCenter: parent.verticalCenter; visible: pill.label.length > 0; text: pill.label; font.pixelSize: Glass.size.footnote; font.weight: Font.DemiBold; color: "white" }
        }
        MouseArea { id: pillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }

    component NotifCard: GlassLockPane {
        id: card
        property var notif
        property real contentOpacity: 1
        blurSource: blurred
        implicitHeight: cardRow.implicitHeight + 24
        radius: 22
        tint: Glass.regular
        RowLayout {
            id: cardRow
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10
            opacity: card.contentOpacity
            Behavior on opacity { NumberAnimation { duration: Glass.duration.normal } }
            IslandNotifIcon {
                Layout.alignment: Qt.AlignTop
                notif: card.notif
                size: 34
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    GlassText {
                        Layout.fillWidth: true
                        text: (card.notif?.appName ?? "") || Translation.tr("Notification")
                        elide: Text.ElideRight
                        font.pixelSize: Glass.size.footnote
                        font.weight: Font.DemiBold
                        color: Glass.secondaryLabel
                    }
                    GlassText {
                        text: { DateTime.time; return NotificationUtils.getFriendlyNotifTimeString(card.notif?.time ?? Date.now()); }
                        font.pixelSize: Glass.size.footnote
                        color: Glass.tertiaryLabel
                    }
                }
                GlassText {
                    Layout.fillWidth: true
                    text: widgets.showContent ? (card.notif?.summary ?? "") : Translation.tr("Notification")
                    elide: Text.ElideRight
                    font.pixelSize: Glass.size.subheadline
                    font.weight: Font.DemiBold
                }
                GlassText {
                    Layout.fillWidth: true
                    visible: widgets.showContent && text.length > 0
                    text: NotificationUtils.processNotificationBody(card.notif?.body ?? "", (card.notif?.appName ?? "") || (card.notif?.summary ?? "")).replace(/<[^>]*>/g, "").replace(/\n/g, " ")
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.pixelSize: Glass.size.subheadline
                    color: Glass.secondaryLabel
                }
            }
        }
    }

    // ───────────── Login: avatar, name, password, power ─────────────
    ColumnLayout {
        id: login
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.06 - (1 - root.enter) * 30
        spacing: 0
        opacity: root.enter

        // Avatar: only if there's a picture at ~/.face (no placeholder)
        Item {
            Layout.alignment: Qt.AlignHCenter
            visible: avatar.status === Image.Ready
            implicitWidth: 76
            implicitHeight: 76
            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                visible: avatar.status === Image.Ready
                Image {
                    id: avatar
                    anchors.fill: parent
                    source: `file://${Quickshell.env("HOME")}/.face`
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(152, 152)
                    asynchronous: true
                }
            }
        }
        GlassText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: avatar.status === Image.Ready ? 10 : 0
            text: root.fullName || SystemInfo.username
            font.pixelSize: Glass.size.headline + 2
            font.weight: Font.DemiBold
            color: "white"
        }

        // Password capsule
        GlassLockPane {
            id: passwordPane
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            implicitWidth: 268
            implicitHeight: 40
            blurSource: blurred
            tint: Glass.clear
            mapTick: root.enter + shake.x
            transform: Translate { id: shake; x: 0 }

            TextInput {
                id: field
                anchors { left: parent.left; right: goButton.left; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 6 }
                clip: true
                color: "white"
                font.family: Glass.fontFamily
                font.pixelSize: Glass.size.body
                font.letterSpacing: echoMode === TextInput.Password ? 2 : 0
                echoMode: TextInput.Password
                passwordCharacter: "●"
                inputMethodHints: Qt.ImhSensitiveData
                selectionColor: Glass.accent
                enabled: !root.context.unlockInProgress
                verticalAlignment: TextInput.AlignVCenter
                onTextChanged: root.context.currentText = text
                onAccepted: root.context.tryUnlock(root.ctrlHeld)
                Keys.onPressed: event => root.context.resetClearTimer()
                Connections {
                    target: root.context
                    function onCurrentTextChanged() { field.text = root.context.currentText; }
                }
                GlassText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: GlobalStates.screenUnlockFailed ? Translation.tr("Incorrect Password")
                        : root.context.targetAction === LockContext.ActionEnum.Poweroff ? Translation.tr("Password to Shut Down")
                        : root.context.targetAction === LockContext.ActionEnum.Reboot ? Translation.tr("Password to Restart")
                        : Translation.tr("Enter Password")
                    font.pixelSize: Glass.size.body
                    color: GlobalStates.screenUnlockFailed ? Qt.rgba(1, 0.75, 0.75, 0.9) : Qt.rgba(1, 1, 1, 0.55)
                }
            }
            Rectangle { // → button: appears once you type
                id: goButton
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 5 }
                readonly property bool show: field.text.length > 0 || root.context.unlockInProgress
                width: 30
                height: 30
                radius: 15
                color: root.context.targetAction === LockContext.ActionEnum.Unlock ? Qt.rgba(1, 1, 1, 0.9) : Glass.red
                opacity: show ? 1 : 0
                scale: show ? (goMouse.pressed ? 0.88 : 1) : 0.6
                Behavior on opacity { NumberAnimation { duration: Glass.duration.fast } }
                Behavior on scale { NumberAnimation { duration: Glass.duration.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Glass.curve.bouncy } }
                GlassIcon {
                    anchors.centerIn: parent
                    text: root.context.unlockInProgress ? "progress_activity"
                        : root.context.targetAction === LockContext.ActionEnum.Poweroff ? "power_settings_new"
                        : root.context.targetAction === LockContext.ActionEnum.Reboot ? "restart_alt"
                        : root.ctrlHeld ? "coffee" : "arrow_forward"
                    iconSize: 18
                    color: root.context.targetAction === LockContext.ActionEnum.Unlock ? "#1C1C1E" : "white"
                    RotationAnimation on rotation {
                        running: root.context.unlockInProgress
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                    }
                }
                MouseArea {
                    id: goMouse
                    anchors.fill: parent
                    enabled: goButton.show && !root.context.unlockInProgress
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.context.tryUnlock(root.ctrlHeld)
                }
            }

            SequentialAnimation { // wrong password: the capsule shakes its head
                id: shakeAnim
                NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
                NumberAnimation { target: shake; property: "x"; to: 14; duration: 60 }
                NumberAnimation { target: shake; property: "x"; to: -9; duration: 55 }
                NumberAnimation { target: shake; property: "x"; to: 9; duration: 55 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
            }
            Connections {
                target: GlobalStates
                function onScreenUnlockFailedChanged() { if (GlobalStates.screenUnlockFailed) shakeAnim.restart(); }
            }
        }

        GlassText { // hint line
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            text: root.context.fingerprintsConfigured ? Translation.tr("Touch the sensor or enter your password")
                : root.ctrlHeld ? Translation.tr("Unlock and keep awake")
                : root.preview ? Translation.tr("Preview · Esc to close")
                : ""
            visible: text.length > 0
            font.pixelSize: Glass.size.footnote
            color: Qt.rgba(1, 1, 1, 0.7)
        }

        // Sleep / Restart / Shut Down
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 26
            spacing: 34
            Repeater {
                model: [
                    { id: "sleep", icon: "bedtime", label: Translation.tr("Sleep") },
                    { id: "reboot", icon: "restart_alt", label: Translation.tr("Restart"), action: LockContext.ActionEnum.Reboot },
                    { id: "poweroff", icon: "power_settings_new", label: Translation.tr("Shut Down"), action: LockContext.ActionEnum.Poweroff }
                ]
                delegate: Column {
                    id: pbtn
                    required property var modelData
                    readonly property bool armed: pbtn.modelData.action !== undefined && root.context.targetAction === pbtn.modelData.action
                    spacing: 6
                    GlassLockPane {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 44
                        blurSource: blurred
                        tint: pbtn.armed ? Glass.red : Glass.clear
                        mapTick: root.enter
                        scale: pMouse.pressed ? 0.9 : pMouse.containsMouse ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Glass.duration.fast; easing.type: Easing.OutCubic } }
                        GlassIcon {
                            anchors.centerIn: parent
                            text: pbtn.modelData.icon
                            iconSize: 20
                            color: "white"
                        }
                        MouseArea {
                            id: pMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerAction(pbtn.modelData)
                        }
                    }
                    GlassText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pbtn.modelData.label
                        font.pixelSize: Glass.size.caption
                        font.weight: Font.Medium
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }
                }
            }
        }
    }

    function powerAction(m) {
        if (m.id === "sleep") {
            if (!root.preview) Session.suspend();
            return;
        }
        if (!root.requirePasswordToPower) { // straight away, like end4 (never in the preview)
            if (!root.preview) root.context.unlocked(m.action);
            return;
        }
        // Arm it: the password field now asks for the password to do this; tap again to disarm
        if (root.context.targetAction === m.action) root.context.resetTargetAction();
        else { root.context.targetAction = m.action; root.context.shouldReFocus(); }
    }

    // Full name from the passwd entry (GECOS), for the name under the avatar
    property string fullName: ""
    Process {
        running: true
        command: ["bash", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: root.fullName = text.trim() }
    }
}
