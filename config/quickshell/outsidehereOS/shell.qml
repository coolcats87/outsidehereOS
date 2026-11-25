//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Glass shell: a Liquid Glass desktop built around a dynamic island.
// outsidehereOS. (Started life as a fork of end4's illogical-impulse; the end4 panels are gone.)

import "modules/common"
import "services"

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.shell.wallpaper
import qs.modules.shell.wallpaperPicker
import qs.modules.shell.island
import qs.modules.shell.lock
import qs.modules.shell.overlay
import qs.modules.shell.polkit
import qs.modules.shell.regionSelector
import qs.modules.shell.screenCorners

ShellRoot {
    id: root

    Component.onCompleted: {
        Hyprsunset.load()
        Cliphist.refresh()
        BluetoothStatus.load()
    }

    component Panel: LazyLoader {
        active: Config.ready
    }

    Panel { component: Wallpaper {} }
    Panel { component: Island {} }
    Panel { component: IslandCheatsheet {} }
    Panel { component: IslandPower {} }
    Panel { component: Lock {} }
    Panel { component: Overlay {} }
    Panel { component: Polkit {} }
    Panel { component: RegionSelector {} }
    Panel { component: ScreenCorners {} }
    Panel { component: WallpaperPicker {} }

    // Light / dark (Ctrl+Super+Shift+D)
    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles light/dark mode"
        onPressed: Glass.toggleDark()
    }
    IpcHandler {
        target: "appearance"
        function toggleDark(): void { Glass.toggleDark(); }
        function setDark(dark: bool): void { Glass.setDark(dark); }
    }
}
