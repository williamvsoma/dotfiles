#!/usr/bin/env bash
# Cycle tahoe-beach wallpapers based on time of day
set -euo pipefail

WALLPAPER_DIR="$HOME/.config/hypr/wallpapers/26-tahoe-beach"
WAYBAR_COLORS="$HOME/.local/state/waybar/tahoe-colors.css"
HYPRLOCK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock"
HYPRLOCK_WALLPAPER="$HYPRLOCK_DIR/wallpaper.png"
LOCK_ONLY=false

lock_cache_path() {
    local filename="${1##*/}"
    printf '%s/%s-lock.png' "$HYPRLOCK_DIR" "${filename%.*}"
}

prepare_lock_wallpaper() {
    local source="$1"
    local target="$2"
    local tmp="$target.tmp.png"

    if [ -s "$target" ] && [ "$target" -nt "$source" ]; then
        return 0
    fi

    command -v ffmpeg >/dev/null 2>&1 || return 1

    ffmpeg -y -hide_banner -loglevel error \
        -i "$source" \
        -vf "scale=3440:1440:force_original_aspect_ratio=increase:flags=lanczos,crop=3440:1440,gblur=sigma=34:steps=3,eq=contrast=0.92:brightness=-0.05:saturation=1.08,noise=alls=2:allf=u,format=rgb24" \
        -frames:v 1 -compression_level 5 "$tmp" &&
        mv "$tmp" "$target"
}

set_wallpaper() {
    local wallpaper="$1"
    local monitor failed=0
    local -a monitors=()

    systemctl --user start hyprpaper.service >/dev/null 2>&1 || true

    if command -v hyprctl >/dev/null 2>&1; then
        while IFS= read -r monitor; do
            monitors+=("$monitor")
        done < <(hyprctl monitors 2>/dev/null | awk '/^Monitor / { print $2 }')

        if [ "${#monitors[@]}" -eq 0 ]; then
            monitors=(HDMI-A-2)
        fi

        for monitor in "${monitors[@]}"; do
            hyprctl hyprpaper wallpaper "$monitor,$wallpaper" >/dev/null 2>&1 || failed=1
        done

        return "$failed"
    fi

    return 1
}

write_waybar_colors() {
    local fg="$1"
    local tmp="$WAYBAR_COLORS.tmp"

    mkdir -p "${WAYBAR_COLORS%/*}"
    {
        printf '@define-color fg %s;\n' "$fg"
        printf '@define-color fg_dim %s;\n' "$fg"
        printf '@define-color fg_soft %s;\n' "$fg"
    } >"$tmp"
    mv "$tmp" "$WAYBAR_COLORS"
}

if [ "${1:-}" = "--lock-only" ]; then
    LOCK_ONLY=true
fi

HOUR=$(date +%H)

if [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 8 ]; then
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Dawn.png"
    FG="#000000"
elif [ "$HOUR" -ge 8 ] && [ "$HOUR" -lt 18 ]; then
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Day.png"
    FG="#000000"
elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 21 ]; then
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Dusk.png"
    FG="#ffffff"
else
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Night.png"
    FG="#ffffff"
fi

mkdir -p "$HYPRLOCK_DIR"
LOCK_WALLPAPER_CACHE="$(lock_cache_path "$WALLPAPER")"

if [ "$LOCK_ONLY" = false ]; then
    prepare_lock_wallpaper "$WALLPAPER" "$LOCK_WALLPAPER_CACHE" || true
fi

if [ -s "$LOCK_WALLPAPER_CACHE" ]; then
    ln -sfn "$LOCK_WALLPAPER_CACHE" "$HYPRLOCK_WALLPAPER"
else
    ln -sfn "$WALLPAPER" "$HYPRLOCK_WALLPAPER"
fi

if [ "$LOCK_ONLY" = true ]; then
    exit 0
fi

set_wallpaper "$WALLPAPER" || true
write_waybar_colors "$FG"

if systemctl --user is-active --quiet waybar.service; then
    systemctl --user reload-or-restart waybar.service >/dev/null 2>&1 || true
fi
