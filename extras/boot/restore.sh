#!/usr/bin/env bash
# Undo extras/boot/setup.sh: normal login screen and boot messages again.
#   sudo bash extras/boot/restore.sh
# Uses the copies setup.sh saved in extras/boot/backup/. Plymouth itself stays installed.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"; BK="$SRC/backup"
[[ -d "$BK" ]] || { echo "No backup in $BK: nothing to restore."; exit 1; }
say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

say "Normal tty1 login"
rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
[[ -d "$BK/getty@tty1.service.d" ]] && cp -a "$BK/getty@tty1.service.d/." /etc/systemd/system/getty@tty1.service.d/
rm -f /etc/systemd/system/plymouth-quit.service.d/retain.conf

say "Kernel command line"
[[ -f "$BK/cmdline" ]] && cp -a "$BK/cmdline" /etc/kernel/cmdline
[[ -f "$BK/kernel-cmdline.bak" ]] && cp -a "$BK/kernel-cmdline.bak" /etc/kernel/cmdline   # older backups
[[ -f "$BK/grub" ]] && cp -a "$BK/grub" /etc/default/grub
[[ -f "$BK/mkinitcpio.conf" ]] && cp -a "$BK/mkinitcpio.conf" /etc/mkinitcpio.conf
if [[ -d "$BK/loader-entries" ]]; then
    for e in "$BK"/loader-entries/*.conf; do
        for dir in /boot/loader/entries /efi/loader/entries /boot/efi/loader/entries; do
            [[ -f "$dir/$(basename "$e")" ]] && cp -a "$e" "$dir/"
        done
    done
fi
[[ -f "$BK/plymouthd.conf" ]] && cp -a "$BK/plymouthd.conf" /etc/plymouth/plymouthd.conf

say "Display manager back on"
if [[ -f "$BK/display-manager.txt" ]]; then
    systemctl enable "$(cat "$BK/display-manager.txt")"
elif [[ -d "$BK/sddm.conf.d" || -f "$BK/sddm.conf" ]]; then   # older backups: SDDM was uninstalled
    pacman -Q sddm >/dev/null 2>&1 || pacman -S --noconfirm sddm
    [[ -d "$BK/sddm.conf.d" ]] && cp -a "$BK/sddm.conf.d" /etc/
    [[ -f "$BK/sddm.conf" ]] && cp -a "$BK/sddm.conf" /etc/
    systemctl enable sddm.service
fi
systemctl daemon-reload

say "Rebuilding the initramfs and boot entries"
if command -v reinstall-kernels >/dev/null; then reinstall-kernels
elif command -v dracut-rebuild >/dev/null; then dracut-rebuild
elif command -v mkinitcpio >/dev/null; then mkinitcpio -P
fi
[[ -f "$BK/grub" ]] && grub-mkconfig -o /boot/grub/grub.cfg
echo "Restored. Reboot."
