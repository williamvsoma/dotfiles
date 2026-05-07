#!/bin/bash
# Toggle CPU info popup
LOCK="/tmp/waybar-cpuinfo.lock"

if [ -f "$LOCK" ]; then
    kill $(cat "$LOCK") 2>/dev/null
    rm -f "$LOCK"
    exit 0
fi

LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 ~/.config/waybar/scripts/cpuinfo-popup.py &
echo $! > "$LOCK"
wait
rm -f "$LOCK"
