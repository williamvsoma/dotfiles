#!/usr/bin/env bash
# Cycle tahoe-beach wallpapers based on time of day
set -euo pipefail

WALLPAPER_DIR="$HOME/.config/hypr/wallpapers/26-tahoe-beach"
WAYBAR_COLORS="$HOME/.local/state/waybar/tahoe-colors.css"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
HYPRLOCK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock"
HYPRLOCK_WALLPAPER="$HYPRLOCK_DIR/wallpaper.png"
FALLBACK_MONITOR="desc:HP Inc. HP P34hc G4 CNC049181P"
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
            monitors=("$FALLBACK_MONITOR")
        fi

        for monitor in "${monitors[@]}"; do
            hyprctl hyprpaper wallpaper "$monitor,$wallpaper" >/dev/null 2>&1 || failed=1
        done

        return "$failed"
    fi

    return 1
}

write_waybar_colors() {
    local theme="$1"
    local tmp="$WAYBAR_COLORS.tmp"

    mkdir -p "${WAYBAR_COLORS%/*}"

    if [ "$theme" = light ]; then
        {
            printf '@define-color fg #111114;\n'
            printf '@define-color fg_dim rgba(17, 17, 20, 0.64);\n'
            printf '@define-color fg_soft rgba(17, 17, 20, 0.38);\n'
            printf '@define-color notch_bg rgba(248, 248, 250, 0.76);\n'
            printf '@define-color notch_border rgba(255, 255, 255, 0.58);\n'
            printf '@define-color notch_shadow rgba(0, 0, 0, 0.16);\n'
            printf '@define-color notch_highlight rgba(255, 255, 255, 0.72);\n'
            printf '@define-color item_hover rgba(255, 255, 255, 0.58);\n'
            printf '@define-color active_bg #0a84ff;\n'
            printf '@define-color active_fg #ffffff;\n'
            printf '@define-color active_border rgba(255, 255, 255, 0.34);\n'
            printf '@define-color active_shadow rgba(10, 132, 255, 0.30);\n'
            printf '@define-color active_highlight rgba(255, 255, 255, 0.32);\n'
            printf '@define-color urgent_bg rgba(255, 59, 48, 0.16);\n'
            printf '@define-color urgent_fg #ff3b30;\n'
        } >"$tmp"
    else
        {
            printf '@define-color fg #f5f5f7;\n'
            printf '@define-color fg_dim rgba(245, 245, 247, 0.68);\n'
            printf '@define-color fg_soft rgba(245, 245, 247, 0.42);\n'
            printf '@define-color notch_bg rgba(28, 28, 30, 0.78);\n'
            printf '@define-color notch_border rgba(255, 255, 255, 0.14);\n'
            printf '@define-color notch_shadow rgba(0, 0, 0, 0.34);\n'
            printf '@define-color notch_highlight rgba(255, 255, 255, 0.08);\n'
            printf '@define-color item_hover rgba(255, 255, 255, 0.12);\n'
            printf '@define-color active_bg #0a84ff;\n'
            printf '@define-color active_fg #ffffff;\n'
            printf '@define-color active_border rgba(255, 255, 255, 0.22);\n'
            printf '@define-color active_shadow rgba(10, 132, 255, 0.36);\n'
            printf '@define-color active_highlight rgba(255, 255, 255, 0.26);\n'
            printf '@define-color urgent_bg rgba(255, 69, 58, 0.20);\n'
            printf '@define-color urgent_fg #ff453a;\n'
        } >"$tmp"
    fi

    mv "$tmp" "$WAYBAR_COLORS"
}

if [ "${1:-}" = "--lock-only" ]; then
    LOCK_ONLY=true
fi

HOUR=$(date +%H)

if [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 8 ]; then
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Dawn.png"
    WAYBAR_THEME=light
elif [ "$HOUR" -ge 8 ] && [ "$HOUR" -lt 18 ]; then
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Day.png"
    WAYBAR_THEME=light
elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 21 ]; then
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Dusk.png"
    WAYBAR_THEME=dark
else
    WALLPAPER="$WALLPAPER_DIR/26-Tahoe-Beach-Night.png"
    WAYBAR_THEME=dark
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
write_waybar_colors "$WAYBAR_THEME"

touch "$WAYBAR_STYLE" 2>/dev/null || true
