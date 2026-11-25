-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()

    -- Bar, wallpaper
    hl.exec_cmd("$HOME/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
    hl.exec_cmd("qs -c $qsConfig")
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Core components (lock screen). Machine-specific services (keyring, easyeffects...): ~/.rices/local/hypr/execs.lua
    hl.exec_cmd("hypridle")
    -- Boot: let the splash go (no-op without Plymouth), then the startup chime
    hl.exec_cmd("sleep 0.5 && plymouth quit")
    hl.exec_cmd("sleep 0.8 && pw-play --volume 0.8 $HOME/.config/quickshell/$qsConfig/assets/sounds/startup.wav")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

    -- Audio
    -- Optional: audio-wave-visualizer, only if it is cloned to ~/audio-wave-visualizer
    hl.exec_cmd("[ -f $HOME/audio-wave-visualizer/hyprland/run.sh ] && bash $HOME/audio-wave-visualizer/hyprland/run.sh")
    hl.exec_cmd("[ -d $HOME/audio-wave-visualizer ] && sleep 3 && ~/.config/hypr/scripts/restart-audio-visualizer.sh")
    -- Clipboard: history
    --hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
