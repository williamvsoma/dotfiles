#!/usr/bin/env bash
set -euo pipefail

name="${1:?missing popup name}"
script="${2:?missing popup script}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/waybar-$name.pid"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
log_file="$state_dir/$name.log"

is_our_popup() {
    local pid="$1"

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1

    local cmdline
    cmdline="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)" || return 1
    [[ "$cmdline" == *"$script"* ]]
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

mkdir -p "$state_dir"
LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 "$script" >"$log_file" 2>&1 &
pid="$!"
printf '%s\n' "$pid" >"$pid_file"

cleanup() {
    rm -f "$pid_file"
}
trap cleanup EXIT

wait "$pid" || true
