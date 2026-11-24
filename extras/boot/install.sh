#!/usr/bin/env bash
# Glass boot: Plymouth theme + drop SDDM for tty1 autologin into Hyprland (lock screen asks for the password).
# Run:  sudo bash ~/.local/share/glass-boot/install.sh      Undo: sudo bash ~/.local/share/glass-boot/restore.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-outsidehere}"
BK="$SRC/backup"
mkdir -p "$BK"

echo "==> Backing up current config to $BK"
cp -a /etc/plymouth/plymouthd.conf "$BK/" 2>/dev/null || true
cp -a /etc/systemd/system/getty@tty1.service.d "$BK/" 2>/dev/null || true
cp -a /etc/sddm.conf /etc/sddm.conf.d "$BK/" 2>/dev/null || true

echo "==> Installing the Plymouth theme"
install -d /usr/share/plymouth/themes/glass
install -m644 "$SRC"/plymouth/glass/* /usr/share/plymouth/themes/glass/
cat > /etc/plymouth/plymouthd.conf <<CONF
[Daemon]
Theme=glass
ShowDelay=0
DeviceTimeout=8
CONF

echo "==> tty1 autologin for $USER_NAME"
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER_NAME --noclear %I \$TERM
CONF

echo "==> Disabling and removing SDDM"
systemctl disable sddm.service || true
rm -f /etc/systemd/system/display-manager.service
if pacman -Rns --noconfirm sddm; then
    echo "    sddm removed"
else
    echo "    sddm is needed by another package: left installed but disabled"
fi
systemctl daemon-reload

echo "==> Rebuilding the initramfs (dracut)"
dracut-rebuild

echo
echo "Done. Reboot to see it. If anything goes wrong at boot: Ctrl+Alt+F2, log in, then"
echo "  sudo bash $SRC/restore.sh"
