#!/usr/bin/env bash

APP="$HOME/audio-wave-visualizer"
CONFIG="$HOME/.config/audio-wave-visualizer/hyprland.json"

# Restart visualizer cleanly
pkill -f "$APP/hyprland/run.sh" 2>/dev/null
pkill -f "$APP/hyprland/../shell.qml" 2>/dev/null

sleep 1

# Force a fresh launch
bash "$APP/hyprland/run.sh" &
