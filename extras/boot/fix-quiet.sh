#!/usr/bin/env bash
# Back to the old boot splash (spinner) + no visible text between the splash and the lock screen.
# Run: sudo bash ~/.local/share/glass-boot/fix-quiet.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"; BK="$SRC/backup"; mkdir -p "$BK"
USER_NAME="${SUDO_USER:-outsidehere}"

echo "==> Boot splash back to spinner"
cp -a "$BK/plymouthd.conf" /etc/plymouth/plymouthd.conf 2>/dev/null || printf '[Daemon]\nTheme=spinner\n' > /etc/plymouth/plymouthd.conf
rm -rf /usr/share/plymouth/themes/glass

echo "==> Silent tty1 autologin (no issue, no prompt, no hostname, screen not cleared)"
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER_NAME --skip-login --noissue --nohints --nohostname --nonewline --noclear %I \$TERM
TTYVTDisallocate=no
CONF

echo "==> Splash leaves its last frame on screen (no text flash before Hyprland)"
install -d /etc/systemd/system/plymouth-quit.service.d
cat > /etc/systemd/system/plymouth-quit.service.d/retain.conf <<CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/plymouth quit --retain-splash
CONF

echo "==> Quieter kernel/systemd output"
cp -a /etc/kernel/cmdline "$BK/kernel-cmdline.bak"
line="$(cat /etc/kernel/cmdline)"
for opt in loglevel=3 rd.udev.log_level=3 systemd.show_status=false rd.systemd.show_status=false vt.global_cursor_default=0; do
    grep -qw -- "${opt%%=*}" <<<"$line" || line="$line $opt"
done
echo "$line" > /etc/kernel/cmdline
echo "    cmdline: $line"

systemctl daemon-reload
echo "==> Rebuilding initramfs + boot entries"
reinstall-kernels
echo "Done. Reboot."
