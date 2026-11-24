# outsidehereOS

A Hyprland rice with an Apple Liquid Glass look. The shell is a Quickshell config built around a dynamic island. It started as a fork of end4's illogical-impulse; the end4 panels are gone.

## What's in it
- **Island** (`config/quickshell/outsidehereOS/modules/ii/island`): workspaces, clock, media, notifications (banner or ticker), volume/brightness levels and a keystroke overlay.
- **Spotlight** (Super): apps, math, `>` run in kitty, `?` web search. Super+V opens clipboard history and Super+. opens emoji search.
- **Lock screen** with iOS-style notification stacks, plus a power sheet, polkit sheet, region selector, Super+G overlay and a wallpaper picker (Ctrl+Super+T). All use the glass style.
- **Boot** (`extras/boot`): a silent Plymouth boot, tty1 autologin into Hyprland, then the lock screen. Shutdown is quiet too.

## Layout
| Path | Linked to |
|---|---|
| `config/hypr` | `~/.config/hypr` |
| `config/quickshell/outsidehereOS` | `~/.config/quickshell/outsidehereOS` (run with `qs -c outsidehereOS`) |
| `config/outsidehereOS` | `~/.config/outsidehereOS` (settings) |
| `config/{fuzzel,wlogout,matugen}` | `~/.config/…` |
| `extras/boot` | `~/.local/share/glass-boot` |
| `extras/fish/zz-hyprland-autostart.fish` | `~/.config/fish/conf.d/` |

`riceswitch use outsidehereOS` creates the links listed in `manifest`. `state/` is runtime data and is not tracked.

Machine-specific Hyprland settings (monitors, input, execs) live in `~/.rices/local`, outside this repo.
