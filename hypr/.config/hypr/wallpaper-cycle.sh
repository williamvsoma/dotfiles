#!/bin/bash
# Cycle tahoe-beach wallpapers based on time of day

WALLPAPER_DIR="$HOME/.config/hypr/wallpapers/26-tahoe-beach"
HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"
WAYBAR_COLORS="$HOME/.config/waybar/colors.css"
HYPRLOCK_DIR="$HOME/.cache/hyprlock"
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
    prepare_lock_wallpaper "$WALLPAPER" "$LOCK_WALLPAPER_CACHE"
fi

if [ -s "$LOCK_WALLPAPER_CACHE" ]; then
    ln -sfn "$LOCK_WALLPAPER_CACHE" "$HYPRLOCK_WALLPAPER"
else
    ln -sfn "$WALLPAPER" "$HYPRLOCK_WALLPAPER"
fi

if [ "$LOCK_ONLY" = true ]; then
    exit 0
fi

# Update hyprpaper.conf and restart hyprpaper through systemd so it survives
# timer-triggered oneshot runs.
cat > "$HYPRPAPER_CONF" << EOF
wallpaper {
  monitor = HDMI-A-2
  path = $WALLPAPER
  fit_mode = cover
}

wallpaper {
  monitor =
  path = $WALLPAPER
  fit_mode = cover
}
EOF

systemctl --user restart hyprpaper.service

# Update waybar colors and reload the service.
cat > "$WAYBAR_COLORS" << EOF
@define-color fg $FG;
@define-color fg_dim $FG;
@define-color fg_soft $FG;
EOF

systemctl --user reload-or-restart waybar.service
