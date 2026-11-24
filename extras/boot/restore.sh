#!/usr/bin/env bash
# Undo install.sh: back to SDDM + the previous Plymouth theme.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"; BK="$SRC/backup"
[[ -f "$BK/plymouthd.conf" ]] && cp -a "$BK/plymouthd.conf" /etc/plymouth/plymouthd.conf
[[ -d "$BK/getty@tty1.service.d" ]] && cp -a "$BK/getty@tty1.service.d/." /etc/systemd/system/getty@tty1.service.d/
pacman -Q sddm >/dev/null 2>&1 || pacman -S --noconfirm sddm
[[ -d "$BK/sddm.conf.d" ]] && cp -a "$BK/sddm.conf.d" /etc/
[[ -f "$BK/sddm.conf" ]] && cp -a "$BK/sddm.conf" /etc/
systemctl enable sddm.service
dracut-rebuild
echo "Restored. Reboot."
