#!/usr/bin/env bash
set -euo pipefail

name="${1:?missing popup name}"
script="${2:?missing popup script}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/waybar-$name.pid"

is_our_popup() {
    local pid="$1"

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1
    tr '\0' ' ' <"/proc/$pid/cmdline" | grep -F -- "$script" >/dev/null
}

if [ -s "$pid_file" ]; then
    pid="$(<"$pid_file")"
    if is_our_popup "$pid"; then
        kill "$pid" 2>/dev/null || true
        rm -f "$pid_file"
        exit 0
    fi

    rm -f "$pid_file"
fi

LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 "$script" &
pid="$!"
printf '%s\n' "$pid" >"$pid_file"

cleanup() {
    rm -f "$pid_file"
}
trap cleanup EXIT

wait "$pid" || true
