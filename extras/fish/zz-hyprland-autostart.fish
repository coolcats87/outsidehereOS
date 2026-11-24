# Boot straight into Hyprland (SDDM is gone): tty1 autologs in (getty@tty1 override) and
# this starts the session; the quickshell lock screen then asks for the password.
# Other ttys (Ctrl+Alt+F2...) still give a normal login prompt for recovery.
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test (tty) = /dev/tty1
    and not systemctl -q is-active sddm.service
    exec start-hyprland >$HOME/.cache/hyprland-tty.log 2>&1 # silent: nothing printed on the console
end
