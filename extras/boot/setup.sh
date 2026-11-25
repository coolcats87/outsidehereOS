#!/usr/bin/env bash
# outsidehereOS silent boot: Plymouth splash → autologin → Hyprland → lock screen, with no text on screen.
#
#   sudo bash extras/boot/setup.sh      (install.sh offers to run this for you)
#   sudo bash extras/boot/restore.sh    (undo)
#
# What it changes (originals are saved in extras/boot/backup/ first):
#   1. Plymouth: installed if missing; keeps your current theme. Its last frame stays on screen.
#   2. tty1 logs you in automatically, silently. Your password is asked on the lock screen instead.
#   3. Your display manager (SDDM, GDM, ...) is disabled, not uninstalled.
#   4. Kernel command line gets "quiet splash" plus options that hide boot messages.
#   5. The initramfs and boot entries are rebuilt.
# Works with systemd-boot (/etc/kernel/cmdline or loader entries) or GRUB, and dracut or mkinitcpio.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0"; exit 1; }
USER_NAME="${SUDO_USER:-}"
[[ -n "$USER_NAME" && "$USER_NAME" != root ]] || { echo "Run it with sudo from your own account, not as root."; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"
BK="$SRC/backup"
mkdir -p "$BK"
say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
backup() { for f in "$@"; do [[ -e "$f" && ! -e "$BK/$(basename "$f")" ]] && cp -a "$f" "$BK/" || true; done; }

# ── 1. Plymouth ──────────────────────────────────────────────────────────────
if ! command -v plymouth >/dev/null; then
    say "Installing Plymouth"
    pacman -S --needed --noconfirm plymouth
fi
if [[ -f /etc/mkinitcpio.conf ]] && ! command -v dracut >/dev/null; then
    if ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
        say "Adding the plymouth hook to mkinitcpio"
        backup /etc/mkinitcpio.conf
        # right after udev or systemd, whichever the HOOKS line uses
        sed -i -E '/^HOOKS=/ s/\b(systemd|udev)\b/\1 plymouth/' /etc/mkinitcpio.conf
    fi
fi
say "Splash keeps its last frame until Hyprland is up"
install -d /etc/systemd/system/plymouth-quit.service.d
cat > /etc/systemd/system/plymouth-quit.service.d/retain.conf <<CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/plymouth quit --retain-splash
CONF

# ── 2. Silent autologin on tty1 ──────────────────────────────────────────────
say "Silent autologin on tty1 for $USER_NAME"
backup /etc/systemd/system/getty@tty1.service.d
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER_NAME --skip-login --noissue --nohints --nohostname --nonewline --noclear %I \$TERM
TTYVTDisallocate=no
CONF

# ── 3. Display manager off ───────────────────────────────────────────────────
dm_link=/etc/systemd/system/display-manager.service
if [[ -L $dm_link ]]; then
    dm="$(basename "$(readlink -f "$dm_link")")"
    say "Disabling the display manager ($dm)"
    echo "$dm" > "$BK/display-manager.txt"
    systemctl disable "$dm" || true
    rm -f "$dm_link"
fi

# ── 4. Quiet kernel command line ─────────────────────────────────────────────
OPTS="quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false rd.systemd.show_status=false vt.global_cursor_default=0"
add_opts() { # existing cmdline → cmdline with OPTS added (no duplicates)
    local line="$1" opt
    for opt in $OPTS; do grep -qw -- "${opt%%=*}" <<<"$line" || line="$line $opt"; done
    echo "$line" | sed 's/^ *//'
}
rebuild=""
if [[ -f /etc/kernel/cmdline ]]; then                       # systemd-boot + kernel-install
    say "Kernel command line: /etc/kernel/cmdline"
    backup /etc/kernel/cmdline
    add_opts "$(cat /etc/kernel/cmdline)" > /etc/kernel/cmdline.new && mv /etc/kernel/cmdline.new /etc/kernel/cmdline
    rebuild=kernel-install
elif [[ -f /etc/default/grub ]]; then                       # GRUB
    say "Kernel command line: /etc/default/grub"
    backup /etc/default/grub
    cur="$(sed -n -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' /etc/default/grub)"
    new="$(add_opts "$cur")"
    sed -i -E "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new\"|" /etc/default/grub
    rebuild=grub
else                                                         # systemd-boot, hand-written entries
    shopt -s nullglob
    entries=(/boot/loader/entries/*.conf /efi/loader/entries/*.conf /boot/efi/loader/entries/*.conf)
    if (( ${#entries[@]} )); then
        say "Kernel command line: ${#entries[@]} systemd-boot entries"
        mkdir -p "$BK/loader-entries"
        for e in "${entries[@]}"; do
            [[ -e "$BK/loader-entries/$(basename "$e")" ]] || cp -a "$e" "$BK/loader-entries/"
            cur="$(sed -n -E 's/^options[[:space:]]+//p' "$e")"
            new="$(add_opts "$cur")"
            sed -i -E "s|^options[[:space:]].*|options $new|" "$e"
        done
    else
        echo "    Couldn't find your bootloader config. Add these to your kernel command line yourself:"
        echo "    $OPTS"
    fi
fi

systemctl daemon-reload

# ── 5. Rebuild ───────────────────────────────────────────────────────────────
say "Rebuilding the initramfs and boot entries (this can take a minute)"
if command -v reinstall-kernels >/dev/null; then reinstall-kernels       # EndeavourOS
elif command -v dracut-rebuild >/dev/null; then dracut-rebuild
elif command -v mkinitcpio >/dev/null; then mkinitcpio -P
fi
[[ $rebuild == grub ]] && grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "Done. Reboot to see it."
echo "If something goes wrong at boot: press Ctrl+Alt+F2, log in, then run"
echo "  sudo bash $SRC/restore.sh"
