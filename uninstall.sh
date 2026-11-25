#!/usr/bin/env bash
# Remove outsidehereOS's links from ~/.config and put back the configs install.sh backed up.
#   ./uninstall.sh
# Leaves installed packages, your wallpapers and ~/.rices/local alone.
# If you set up the silent boot, undo that first:  sudo bash extras/boot/restore.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
BACKUPS="$HOME/.local/share/outsidehereOS/backups"

read -rp "Remove outsidehereOS from ~/.config? [y/N] " r; [[ ${r,,} == y* ]] || exit 0
qs kill -c outsidehereOS >/dev/null 2>&1 || true

for dst in "$HOME/.config/hypr" "$HOME/.config/quickshell/outsidehereOS" "$HOME/.config/outsidehereOS" \
           "$HOME/.config/matugen" "$HOME/.config/fuzzel" "$HOME/.config/wlogout" \
           "$HOME/.config/fish/conf.d/zz-hyprland-autostart.fish"; do
    if [[ -L $dst && "$(readlink -f "$dst")" == "$REPO"/* ]]; then
        rm "$dst" && echo "  removed ${dst/#$HOME/\~}"
    fi
done
for profile in "$HOME/.bash_profile" "$HOME/.zprofile"; do
    [[ -f $profile ]] && sed -i '/# outsidehereOS$/d' "$profile"
done

# Put back the oldest backup: the configs you had before the first install
oldest="$(ls -1d "$BACKUPS"/*/ 2>/dev/null | head -1 || true)"
if [[ -n $oldest ]]; then
    cp -a "$oldest"/. "$HOME"/ && echo "  restored your old configs from ${oldest/#$HOME/\~}"
fi
echo "Done. Log out and back in (or reboot)."
