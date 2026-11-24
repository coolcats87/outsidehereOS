#!/usr/bin/env bash
# Power off / reboot with nothing readable on screen between the desktop closing and the
# shutdown splash: blank tty1, hide its cursor and make its text black-on-black first.
# Usage: quiet-power.sh poweroff|reboot|firmware
tty=/dev/tty1
if [[ -w $tty ]]; then
    printf '\033[2J\033[H\033[?25l\033[30;40m' > "$tty" 2>/dev/null
    setterm --term linux --cursor off --foreground black --background black --clear all > "$tty" 2>/dev/null || true
fi
case "$1" in
    poweroff) systemctl poweroff || loginctl poweroff ;;
    reboot)   systemctl reboot || loginctl reboot ;;
    firmware) systemctl reboot --firmware-setup || loginctl reboot --firmware-setup ;;
    *) echo "usage: $0 poweroff|reboot|firmware" >&2; exit 2 ;;
esac
