#!/bin/bash
# Refresh the lock-screen wallpaper target before starting Hyprlock.

bash "$HOME/.config/hypr/wallpaper-cycle.sh" --lock-only
pidof hyprlock >/dev/null || exec hyprlock --immediate-render --no-fade-in
