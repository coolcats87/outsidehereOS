# Boot straight into Hyprland without a display manager (fish).
# extras/boot/setup.sh makes tty1 log in automatically; this then starts Hyprland, and the
# outsidehereOS lock screen asks for your password. Other ttys (Ctrl+Alt+F2...) still give a
# normal login prompt, for recovery. Installed to ~/.config/fish/conf.d/zz-hyprland-autostart.fish
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test (tty) = /dev/tty1
    and not systemctl -q is-active display-manager.service
    exec start-hyprland >$HOME/.cache/hyprland-tty.log 2>&1 # silent: nothing printed on the console
end
