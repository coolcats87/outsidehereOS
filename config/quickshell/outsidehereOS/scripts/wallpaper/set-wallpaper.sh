#!/usr/bin/env bash
# Set the wallpaper (image or video). Replaces end4's switchwall.sh.
#   set-wallpaper.sh /path/to/file
# Image: the shell's Wallpaper layer shows it (config background.wallpaperPath).
# Video: mpvpaper plays it on every monitor; a first-frame thumbnail goes in background.thumbnailPath
#        (the lock screen and picker use that). Hyprland re-runs the restore script at login.
# App colours: if matugen is set up (~/.config/matugen), it re-themes apps (kitty, GTK...) from the image.
set -uo pipefail
path="${1:-}"
[[ -f "$path" ]] || { echo "usage: $0 <image-or-video>" >&2; exit 1; }
path="$(realpath "$path")"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/outsidehereOS/config.json"
RESTORE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/custom/scripts/__restore_video_wallpaper.sh"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/glass/wallpaper-thumbs"
MODE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/appearance-mode"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 load-scripts=no"
mkdir -p "$THUMBS" "$(dirname "$RESTORE")"

set_config() { # key value
    [[ -f "$CONFIG" ]] || return
    jq --arg v "$2" ".background.$1 = \$v" "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
}

pkill -f -9 mpvpaper 2>/dev/null || true
colour_source="$path"
case "${path,,}" in
    *.mp4|*.webm|*.mkv|*.avi|*.mov)
        thumb="$THUMBS/$(basename "${path%.*}").jpg"
        [[ -f "$thumb" ]] || ffmpeg -loglevel error -y -i "$path" -vframes 1 -q:v 3 "$thumb"
        set_config thumbnailPath "$thumb"
        cat > "$RESTORE" <<SCRIPT
#!/bin/bash
# Written by set-wallpaper.sh: plays the video wallpaper again at login.
pkill -f -9 mpvpaper
for monitor in \$(hyprctl monitors -j | jq -r '.[] | .name'); do
    mpvpaper -o "$VIDEO_OPTS" "\$monitor" "$path" &
    sleep 0.1
done
SCRIPT
        chmod +x "$RESTORE"
        setsid -f bash "$RESTORE" >/dev/null 2>&1
        colour_source="$thumb"
        ;;
    *)
        printf '#!/bin/bash\n# Written by set-wallpaper.sh: the wallpaper is an image, nothing to restore.\n' > "$RESTORE"
        chmod +x "$RESTORE"
        ;;
esac
set_config wallpaperPath "$path"

if command -v matugen >/dev/null && [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml" ]]; then
    mode=dark; [[ "$(cat "$MODE_FILE" 2>/dev/null)" == light ]] && mode=light
    matugen image "$colour_source" -m "$mode" >/dev/null 2>&1 &
fi
