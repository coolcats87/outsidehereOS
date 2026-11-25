# outsidehereOS

A Beautiful Custom Hyprland Shell based loosely out of end4 and follows the apple design language (for the most part).

The shell is a [Quickshell](https://quickshell.org) config built around a dynamic island. It started as a fork of [end4's illogical-impulse](https://github.com/end-4/dots-hyprland); the end4 panels are gone. Licensed GPL-3.0, like end4.

- [What you get](#what-you-get)
- [Install](#install)
- [Shortcuts](#shortcuts)
- [Make it yours](#make-it-yours)
- [Directory tree](#directory-tree)
- [For developers](#for-developers)
- [Uninstall](#uninstall)

---

## What you get

| | |
|---|---|
| **Dynamic island** | Workspaces, clock, battery, now playing (with lyrics), notifications as a banner or a scrolling ticker, quick settings. Volume and brightness changes morph the island into a slider instead of a pop-up. |
| **Spotlight** | Tap **Super**. Apps, math (`2^10`, `5 usd to eur`), `>command` runs in a terminal, `?words` searches the web. **Super+V** is clipboard history and **Super+.** is emoji search. |
| **Lock screen** | Blurred wallpaper, big glass clock, now playing, iPhone-style stacked notifications. |
| **Glass everywhere** | Power menu, password (polkit) prompts, screenshot/region selector, Super+G overlay (volume mixer, CPU/RAM, recorder, notes), wallpaper picker, rounded screen corners. |
| **Wallpapers** | Ctrl+Super+T picks one. App colours follow the wallpaper (matugen). Video wallpapers work too. |
| **Silent boot** *(optional)* | Boot splash → straight into Hyprland → the lock screen asks for your password. No login screen and no text, at boot or shutdown. |

## Install

You need **Arch Linux** or an Arch-based distro (EndeavourOS, CachyOS, Garuda…) and an internet connection.

```bash
git clone https://github.com/coolcats87/outsidehereOS ~/.rices/outsidehereOS
cd ~/.rices/outsidehereOS
./install.sh
```

That's it. The installer explains each step, asks before anything big and is safe to run again. Run it as your normal user; it asks for your password when it needs `sudo`.

**What `install.sh` does:**

1. **Installs the packages** in [`packages.txt`](packages.txt), from the Arch repos and the AUR. If you have no AUR helper, it installs `yay` first. Packages you already have are skipped.
2. **Backs up your current configs** (`~/.config/hypr`, `fuzzel`, `matugen`, …) to `~/.local/share/outsidehereOS/backups/<date>/`.
3. **Links the configs** from this folder into `~/.config`. Because they're links, a `git pull` here updates your desktop.
4. **Creates your machine settings** in `~/.rices/local/hypr/` (monitors, keyboard layout, touchpad). They're yours, and updates never touch them.
5. **Sets up the rest:**
   - a default wallpaper in `~/Pictures/Wallpapers`;
   - the dark GTK theme, the Inter font and the Bibata cursor;
   - Python for the screenshot tool;
   - the services the shell uses (Bluetooth, ydotool).
6. **Asks** two questions, both defaulting to no:
   - Add you to the `input` group? Only the keystroke overlay needs it.
   - Set up the silent boot?

Then log out and choose **Hyprland** on your login screen (or reboot, if you picked the silent boot).

**Options:**

| Command | What it does |
|---|---|
| `./install.sh -y` | No questions; use the defaults |
| `./install.sh --boot` | Also set up the silent boot |
| `./install.sh --skip-packages` | Only link the configs |
| `./install.sh --help` | Show all options |

**Update:** `cd ~/.rices/outsidehereOS && git pull`, then press **Ctrl+Super+R** to restart the shell. Run `./install.sh` again if `packages.txt` changed.

**Silent boot later, or undo it:** run `sudo bash extras/boot/setup.sh` to set it up and `sudo bash extras/boot/restore.sh` to undo it. If anything goes wrong at boot, press **Ctrl+Alt+F2**, log in and run the restore script.

## Shortcuts

Press **Super+/** for the full, searchable list. The main ones:

| Keys | Action | | Keys | Action |
|---|---|---|---|---|
| **Super** (tap) | Spotlight | | **Super+Enter** | Terminal |
| **Super+V** | Clipboard history | | **Super+E** | Files |
| **Super+.** | Emoji | | **Super+W** | Browser |
| **Super+Q** | Close window | | **Super+L** | Lock |
| **Super+1…9** | Go to workspace | | **Super+Alt+1…9** | Send window there |
| **Super+Shift+S** | Screenshot a region | | **Print** | Screenshot everything |
| **Super+Shift+X** | Copy text from the screen (OCR) | | **Super+Shift+C** | Pick a colour |
| **Super+Shift+R** | Record a region | | **Super+G** | Overlay (mixer, stats, notes) |
| **Ctrl+Super+T** | Wallpapers | | **Ctrl+Super+Shift+D** | Light / dark |
| **Super+Alt+J** | Cycle island style | | **Super+Alt+N** | Notifications: banner ↔ ticker |
| **Ctrl+Alt+Delete** | Power menu | | **Ctrl+Super+R** | Restart the shell |

## Make it yours

Everything is plain text. Edit a file, save it, and Hyprland reloads by itself. For shell (QML) changes, press **Ctrl+Super+R**.

| I want to… | Edit |
|---|---|
| Set up my monitors | `~/.rices/local/hypr/monitors.lua` (run `hyprctl monitors all` to see their names) |
| Change keyboard layout / touchpad | `~/.rices/local/hypr/input.lua` |
| Start an app at login | `~/.rices/local/hypr/execs.lua`, or `config/hypr/custom/execs.lua` |
| Add or change shortcuts | `config/hypr/custom/keybinds.lua` (defaults: `config/hypr/hyprland/keybinds.lua`) |
| Use a different terminal / browser / file manager | `config/hypr/custom/variables.lua` |
| Change gaps, borders, blur, animations | `config/hypr/custom/general.lua` |
| Add window rules | `config/hypr/custom/rules.lua` |
| Change shell settings (search engine, island, 12/24h…) | `config/outsidehereOS/config.json` |
| Change glass colours, blur, radii, fonts | `config/quickshell/outsidehereOS/modules/common/Glass.qml` |
| Add wallpapers | Drop them in `~/Pictures/Wallpapers` |
| Install more packages with the rice | Add a line to `packages.txt` |

Files in `config/hypr/custom/` load **after** the defaults in `config/hypr/hyprland/`, so put your changes in `custom` and leave the defaults alone.

## Directory tree

```
outsidehereOS/
├── install.sh                  Installer (see above). Safe to re-run.
├── uninstall.sh                Removes the links, puts your old configs back.
├── packages.txt                Every package the rice needs, one per line, with comments.
├── manifest                    The same links, for the `riceswitch` tool (optional).
├── wallpapers/                 Default wallpapers, copied to ~/Pictures/Wallpapers.
│
├── config/                     Everything linked into ~/.config
│   ├── hypr/                   → ~/.config/hypr            HYPRLAND
│   │   ├── hyprland.lua        Entry point: loads the folders below, in order.
│   │   ├── hyprland/           Defaults. Read them; override in custom/.
│   │   │   ├── env.lua             Environment variables (toolkits, cursor, venv path).
│   │   │   ├── execs.lua           Started at login: the shell, idle daemon, clipboard, chime.
│   │   │   ├── general.lua         Gaps, borders, decoration, animations, layouts.
│   │   │   ├── rules.lua           Window and layer rules (floating dialogs, blur…).
│   │   │   ├── keybinds.lua        All default shortcuts.
│   │   │   ├── variables.lua       Default apps (terminal, browser…) and `qsConfig`.
│   │   │   ├── colors.lua          Border colours. Generated by matugen from the wallpaper.
│   │   │   ├── liquidglass.lua     Optional hyprglass plugin; does nothing if it isn't installed.
│   │   │   ├── lib/                Small Lua helpers used by the files above.
│   │   │   ├── services/           Creates custom/ files on first run.
│   │   │   ├── shellOverrides/     Written by the shell's settings. Don't edit by hand.
│   │   │   └── scripts/            Helpers for shortcuts (emoji fallback, Google Lens, AI…).
│   │   ├── custom/             YOUR changes. Same file names; loaded after the defaults.
│   │   │   └── scripts/            __restore_video_wallpaper.sh (written by the wallpaper script).
│   │   ├── hypridle.conf       Lock after 5 min, screen off after 10, sleep after 15.
│   │   ├── hyprlock.conf       Fallback lock screen, used only if the shell isn't running.
│   │   ├── hyprlock/           Its colours (generated by matugen).
│   │   └── scripts/            Audio visualiser restart helper.
│   │
│   ├── quickshell/outsidehereOS/   → ~/.config/quickshell/outsidehereOS     THE SHELL
│   │   ├── shell.qml           Entry point: lists every part of the shell that gets loaded.
│   │   ├── GlobalStates.qml    Small shared state (e.g. is Super being held).
│   │   ├── modules/
│   │   │   ├── shell/          The visible pieces, one folder each:
│   │   │   │   ├── island/         Dynamic island: Island.qml is the bar itself; Island*.qml
│   │   │   │   │                   are its parts (Launcher = Spotlight, Cheatsheet, Power,
│   │   │   │   │                   Notifications, NowPlaying, QuickSettings, Keys, Lyrics…).
│   │   │   │   ├── lock/           Lock screen (GlassLockSurface.qml is what you see).
│   │   │   │   ├── overlay/        Super+G overlay and its widgets (mixer, resources, notes,
│   │   │   │   │                   recorder, crosshair, floating image, FPS limiter).
│   │   │   │   ├── polkit/         Password prompt for admin actions.
│   │   │   │   ├── regionSelector/ Screenshot / OCR / recording region picker.
│   │   │   │   ├── screenCorners/  Rounded screen corners.
│   │   │   │   ├── wallpaper/      Draws the wallpaper.
│   │   │   │   └── wallpaperPicker/ Ctrl+Super+T grid.
│   │   │   └── common/         Shared building blocks:
│   │   │       ├── Glass.qml       Design tokens: colours, blur, radii, fonts, animation curves.
│   │   │       ├── Config.qml      Reads/writes ~/.config/outsidehereOS/config.json (all options).
│   │   │       ├── Appearance.qml  Older colour/font tokens some widgets still use.
│   │   │       ├── Directories.qml Paths the shell uses.
│   │   │       ├── Persistent.qml  State kept between restarts.
│   │   │       ├── Icons.qml, Images.qml   Icon/image lookups.
│   │   │       ├── widgets/        Reusable widgets. Glass*.qml are the Liquid Glass ones
│   │   │       │                   (GlassSurface, GlassButton, GlassSlider, GlassText…).
│   │   │       ├── shaders/        Glass and liquid-glass GPU shaders (.frag source + compiled .qsb).
│   │   │       ├── functions/      Helpers: fuzzy search, strings, colours, files, power actions.
│   │   │       ├── panels/lock/    Password checking (PAM) for the lock screen.
│   │   │       └── utils/          Screenshot helpers.
│   │   ├── services/           Background logic, no UI: Audio, Battery, Brightness, Network,
│   │   │                       BluetoothStatus, Notifications, MprisController (media),
│   │   │                       Cliphist (clipboard), Emojis, AppSearch, Lyrics, Keystrokes…
│   │   ├── scripts/            Shell scripts the services call:
│   │   │   ├── wallpaper/set-wallpaper.sh   Sets the wallpaper + recolours apps.
│   │   │   ├── session/quiet-power.sh       Shut down / restart without text on screen.
│   │   │   ├── videos/record.sh             Screen recording.
│   │   │   ├── images/                      Finds images on screen for the region selector.
│   │   │   ├── keys/                        Keystroke overlay + shortcut list reader.
│   │   │   ├── keyring/, lyrics/, cava/     Keyring, lyrics download, visualiser config.
│   │   ├── assets/             Icons, emoji list, startup sound.
│   │   └── translations/       UI text (English).
│   │
│   ├── outsidehereOS/          → ~/.config/outsidehereOS    config.json: the shell's settings.
│   ├── matugen/                → ~/.config/matugen          Templates that turn the wallpaper
│   │                                                        into colours for Hyprland, GTK, fuzzel.
│   ├── fuzzel/                 → ~/.config/fuzzel           Fallback launcher (shell not running).
│   └── wlogout/                → ~/.config/wlogout          Fallback power menu.
│
├── extras/
│   ├── boot/
│   │   ├── setup.sh            Silent boot (sudo). Works with systemd-boot or GRUB,
│   │   │                       dracut or mkinitcpio, any display manager.
│   │   ├── restore.sh          Undo it.
│   │   └── backup/             Your original boot files (made by setup.sh, not in git).
│   ├── autostart/              Starts Hyprland when tty1 logs in (fish / bash / zsh).
│   └── local-template/hypr/    Starting point for ~/.rices/local/hypr (machine settings).
│
└── state/                      Not in git: runtime data (Python venv, todo list, colours).
```

## For developers

**How it fits together.** `shell.qml` loads each module in `modules/shell/`. Modules get their data from singletons in `services/`, style themselves with `modules/common/Glass.qml` and are built from the `Glass*` widgets. Hyprland triggers the shell through global shortcuts (`hl.dsp.global("quickshell:<name>")`, matched by `GlobalShortcut { name: "<name>" }` in QML) or through IPC.

**Run, restart, debug:**
```bash
qs -c outsidehereOS                        # run it in a terminal to see errors live
qs kill -c outsidehereOS; qs -c outsidehereOS   # restart (or Ctrl+Super+R)
qs log -c outsidehereOS                    # log of the running instance
qs -c outsidehereOS ipc show               # every IPC target and function
```

**IPC.** Everything can be driven from a terminal or a keybind, which is handy for testing:
```bash
qs -c outsidehereOS ipc call islandLauncher toggle      # also: clipboard, emoji, query "text"
qs -c outsidehereOS ipc call island cycleNotifStyle
qs -c outsidehereOS ipc call wallpaperPicker random
qs -c outsidehereOS ipc call appearance toggleDark
```
Targets: `appearance`, `audio`, `brightness`, `cheatsheet`, `island`, `islandLauncher`, `lock`, `lockPreview`, `mpris`, `overlay`, `polkit`, `region`, `session`, `wallpaperPicker`.

**Adding a module:**
1. Create `modules/shell/myThing/MyThing.qml`, with a `Scope` holding a `PanelWindow`.
2. Style it with `Glass.*` tokens and `GlassSurface`.
3. Add `import qs.modules.shell.myThing` and `Panel { component: MyThing {} }` to `shell.qml`.
4. If it should blur what's behind it, name its layer `quickshell:island<Something>`. A Hyprland layer rule in `config/hypr/custom/rules.lua` already blurs those.

**Settings.** Options live in `modules/common/Config.qml` as typed properties, saved to `~/.config/outsidehereOS/config.json`. Read them with `Config.options.<section>.<key>`.

**Commits.** Generated files change whenever you set a wallpaper: `config/hypr/hyprland/colors.lua`, `config/hypr/hyprlock/colors.conf`, `config/fuzzel/fuzzel_theme.ini`, and the wallpaper path in `config.json`. Leave them out of commits unless you mean to change the defaults.

## Uninstall

```bash
cd ~/.rices/outsidehereOS
sudo bash extras/boot/restore.sh   # only if you set up the silent boot
./uninstall.sh
```
This removes the links and puts your old configs back. Packages, wallpapers and `~/.rices/local` stay.

## Credits

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse): the original shell this grew out of.
- [Quickshell](https://quickshell.org) and [Hyprland](https://hyprland.org).
- Design inspired by Apple's Liquid Glass. outsidehereOS isn't affiliated with Apple, and none of Apple's assets are used.
