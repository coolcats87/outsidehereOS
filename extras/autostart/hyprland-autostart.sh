# Boot straight into Hyprland without a display manager (bash / zsh).
# extras/boot/setup.sh makes tty1 log in automatically; this then starts Hyprland, and the
# outsidehereOS lock screen asks for your password. Other ttys (Ctrl+Alt+F2...) still give a
# normal login prompt, for recovery. install.sh sources this from ~/.bash_profile or ~/.zprofile.
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = /dev/tty1 ] && ! systemctl -q is-active display-manager.service; then
    exec start-hyprland >"$HOME/.cache/hyprland-tty.log" 2>&1 # silent: nothing printed on the console
fi
