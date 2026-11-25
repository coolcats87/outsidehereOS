#!/usr/bin/env bash
# outsidehereOS installer — Arch Linux and Arch-based distros (EndeavourOS, CachyOS, ...).
#
#   git clone https://github.com/coolcats87/outsidehereOS ~/.rices/outsidehereOS
#   cd ~/.rices/outsidehereOS && ./install.sh
#
# Options:
#   -y, --yes          don't ask; use the defaults (silent boot is NOT set up unless --boot)
#   --boot             also set up the silent boot (autologin, no login screen)
#   --no-boot          skip the silent-boot question
#   --skip-packages    don't install packages (only link configs)
#   -h, --help         show this help
#
# Safe to run again: it skips what's already done. Undo with ./uninstall.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.local/share/outsidehereOS/backups/$STAMP"
VENV="$HOME/.local/state/quickshell/.venv"
PICS="$(xdg-user-dir PICTURES 2>/dev/null || true)"
[[ -n $PICS && $PICS != "$HOME" ]] || PICS="$HOME/Pictures"
WALLS="$PICS/Wallpapers"

YES=0; BOOT=ask; PACKAGES=1
for a in "$@"; do
    case "$a" in
        -y|--yes) YES=1 ;;
        --boot) BOOT=yes ;;
        --no-boot) BOOT=no ;;
        --skip-packages) PACKAGES=0 ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $a (try --help)"; exit 1 ;;
    esac
done

# ── Output helpers ───────────────────────────────────────────────────────────
bold=$'\033[1m'; dim=$'\033[2m'; blue=$'\033[1;34m'; green=$'\033[1;32m'; yellow=$'\033[1;33m'; red=$'\033[1;31m'; off=$'\033[0m'
step() { printf '\n%s==>%s %s%s%s\n' "$blue" "$off" "$bold" "$*" "$off"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$green" "$off" "$*"; }
warn() { printf '    %s!%s %s\n' "$yellow" "$off" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$red" "$*" "$off" >&2; exit 1; }
ask()  { # ask "question" default(y|n) → 0 for yes
    local q="$1" def="$2" hint reply
    [[ $def == y ]] && hint="[Y/n]" || hint="[y/N]"
    if (( YES )); then [[ $def == y ]]; return; fi
    read -rp "    $q $hint " reply || true
    reply="${reply:-$def}"
    [[ ${reply,,} == y* ]]
}
trap 'die "Something failed on line $LINENO. Fix the error above and run ./install.sh again (it skips what is already done)."' ERR

# ── 0. Checks ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] || die "Run this as your normal user, not with sudo. It asks for your password when it needs it."
command -v pacman >/dev/null || die "outsidehereOS needs an Arch-based distro (pacman not found)."

cat <<EOF

  ${bold}outsidehereOS${off} — Hyprland with an Apple Liquid Glass look

  This will:
    1. install the packages in packages.txt (Arch repos + AUR)
    2. back up your current configs to ${dim}${BACKUP/#$HOME/\~}${off}
    3. link the outsidehereOS configs into ~/.config
    4. set up the wallpaper, fonts, theme and the screenshot tool
    5. optionally set up a silent boot straight into the lock screen

EOF
ask "Continue?" y || { echo "    Nothing changed."; exit 0; }

# ── 1. Packages ──────────────────────────────────────────────────────────────
if (( PACKAGES )); then
    step "Packages"
    sudo -v || die "sudo is needed to install packages."
    mapfile -t wanted < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$REPO/packages.txt")
    # pacman -T prints the ones not installed (or not provided by something installed)
    mapfile -t missing < <(pacman -T "${wanted[@]}" || true)
    if (( ${#missing[@]} == 0 )); then
        ok "All ${#wanted[@]} packages are already installed"
    else
        repo=(); aur=()
        sudo pacman -Sy >/dev/null
        for p in "${missing[@]}"; do
            if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
        done
        if (( ${#repo[@]} )); then
            info "From the Arch repos: ${repo[*]}"
            sudo pacman -S --needed --noconfirm "${repo[@]}"
        fi
        if (( ${#aur[@]} )); then
            info "From the AUR: ${aur[*]}"
            helper=""
            for h in paru yay; do command -v $h >/dev/null && { helper=$h; break; }; done
            if [[ -z $helper ]]; then
                info "No AUR helper found: installing yay"
                sudo pacman -S --needed --noconfirm base-devel git
                tmp="$(mktemp -d)"
                git clone -q https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
                (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
                rm -rf "$tmp"
                helper=yay
            fi
            $helper -S --needed --noconfirm "${aur[@]}"
        fi
        ok "Packages installed"
    fi
fi

# ── 2 + 3. Configs ───────────────────────────────────────────────────────────
step "Configs"
# repo path → where it is linked
LINKS=(
    "config/hypr:$HOME/.config/hypr"
    "config/quickshell/outsidehereOS:$HOME/.config/quickshell/outsidehereOS"
    "config/outsidehereOS:$HOME/.config/outsidehereOS"
    "config/matugen:$HOME/.config/matugen"
    "config/fuzzel:$HOME/.config/fuzzel"
    "config/wlogout:$HOME/.config/wlogout"
)
for pair in "${LINKS[@]}"; do
    src="$REPO/${pair%%:*}"; dst="${pair#*:}"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        ok "${dst/#$HOME/\~} (already linked)"; continue
    fi
    if [[ -e $dst || -L $dst ]]; then
        mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")"
        mv "$dst" "$BACKUP/${dst#$HOME/}"
        info "backed up ${dst/#$HOME/\~}"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    ok "${dst/#$HOME/\~} → ${src/#$HOME/\~}"
done
mkdir -p "$HOME/.local/state/quickshell/user/generated"

# Machine-specific settings (monitors, keyboard, touchpad): a copy you edit, never overwritten
if [[ -f $HOME/.rices/local/hypr/local.lua ]]; then
    ok "Machine settings: ~/.rices/local/hypr (kept as is)"
else
    mkdir -p "$HOME/.rices/local"
    cp -r "$REPO/extras/local-template/hypr" "$HOME/.rices/local/hypr"
    ok "Machine settings: ~/.rices/local/hypr (edit monitors.lua / input.lua there)"
fi

# ── 4. Extras ────────────────────────────────────────────────────────────────
step "Wallpaper, theme and tools"

mkdir -p "$WALLS"
for w in "$REPO"/wallpapers/*; do [[ -e "$WALLS/$(basename "$w")" ]] || cp "$w" "$WALLS/"; done
ok "Wallpapers in ${WALLS/#$HOME/\~} (add your own there; Ctrl+Super+T picks one)"
current="$(jq -r '.background.wallpaperPath // ""' "$REPO/config/outsidehereOS/config.json" 2>/dev/null || true)"
if [[ ! -f $current ]]; then
    bash "$REPO/config/quickshell/outsidehereOS/scripts/wallpaper/set-wallpaper.sh" "$WALLS/outsidehereOS-aurora.jpg" || warn "Couldn't set the wallpaper (set one later with Ctrl+Super+T)"
    ok "Wallpaper set to outsidehereOS-aurora"
fi

if [[ -x $VENV/bin/python ]] && "$VENV/bin/python" -c 'import cv2, numpy' 2>/dev/null; then
    ok "Screenshot region detection (already set up)"
else
    info "Setting up screenshot region detection (Python: numpy, opencv)…"
    if python3 -m venv "$VENV" && "$VENV/bin/pip" install -q --disable-pip-version-check numpy opencv-python-headless; then
        ok "Screenshot region detection"
    else
        warn "Couldn't set it up; screenshots still work, just without detecting images on screen"
    fi
fi

if id -nG "$USER" | grep -qw input; then
    ok "Keystroke overlay (you're in the input group)"
else
    info "The keystroke overlay (shows the keys you press, for demos) needs your user in the"
    info "'input' group. That also lets any program you run read keyboard input."
    if ask "Add $USER to the input group?" n; then
        sudo usermod -aG input "$USER" && ok "Added to the input group (applies after you log in again)"
    else
        info "Skipped: everything else works without it"
    fi
fi

if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Inter 11' 2>/dev/null || true
    ok "Dark GTK theme, Inter font, Bibata cursor"
fi
fc-cache -f >/dev/null 2>&1 || true

if systemctl --user cat ydotool.service >/dev/null 2>&1; then
    systemctl --user enable --now ydotool.service >/dev/null 2>&1 && ok "ydotool (pastes clipboard entries for you)" || true
fi
if systemctl cat bluetooth.service >/dev/null 2>&1 && ! systemctl -q is-enabled bluetooth.service; then
    sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 && ok "Bluetooth service enabled" || true
fi

# ── 5. Silent boot (optional) ────────────────────────────────────────────────
if [[ $BOOT == ask ]]; then
    step "Silent boot (optional)"
    info "Boot splash → straight into Hyprland → the lock screen asks for your password."
    info "No login screen and no text. Your display manager (SDDM, GDM…) is disabled, not removed."
    info "Undo any time with: sudo bash extras/boot/restore.sh"
    ask "Set it up?" n && BOOT=yes || BOOT=no
fi
if [[ $BOOT == yes ]]; then
    sudo bash "$REPO/extras/boot/setup.sh"
    # Start Hyprland when tty1 logs in, for the user's login shell
    case "$(basename "${SHELL:-bash}")" in
        fish)
            mkdir -p "$HOME/.config/fish/conf.d"
            ln -sfn "$REPO/extras/autostart/hyprland-autostart.fish" "$HOME/.config/fish/conf.d/zz-hyprland-autostart.fish"
            ok "fish starts Hyprland on tty1" ;;
        zsh|bash)
            [[ $(basename "$SHELL") == zsh ]] && profile="$HOME/.zprofile" || profile="$HOME/.bash_profile"
            line="[ -f \"$REPO/extras/autostart/hyprland-autostart.sh\" ] && . \"$REPO/extras/autostart/hyprland-autostart.sh\" # outsidehereOS"
            grep -qF "# outsidehereOS" "$profile" 2>/dev/null || echo "$line" >> "$profile"
            ok "${profile/#$HOME/\~} starts Hyprland on tty1" ;;
        *) warn "Unknown shell $SHELL: add extras/autostart/hyprland-autostart.sh to its login profile yourself" ;;
    esac
fi

# ── Done ─────────────────────────────────────────────────────────────────────
step "Done"
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload >/dev/null 2>&1 || true
    qs kill -c outsidehereOS >/dev/null 2>&1 || true
    sleep 2
    setsid -f qs -c outsidehereOS >/dev/null 2>&1 || true
    ok "Reloaded Hyprland and started the shell"
    info "Log out and back in once so every setting applies."
elif [[ $BOOT == yes ]]; then
    info "Reboot to start outsidehereOS."
else
    info "Log out, pick ${bold}Hyprland${off} on your login screen, and log in."
fi
[[ -d $BACKUP ]] && info "Your old configs are in ${BACKUP/#$HOME/\~}"
cat <<EOF

    ${bold}First shortcuts${off}
      Super            Spotlight (apps, math, >command, ?web search)
      Super+Enter      terminal          Super+Q  close window
      Super+V          clipboard         Super+.  emoji
      Ctrl+Super+T     wallpapers        Super+L  lock
      Super+/          all shortcuts

EOF
