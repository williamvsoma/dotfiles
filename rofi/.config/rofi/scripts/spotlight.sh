#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config="${config_home}/rofi/config.rasi"
files_script="${config_home}/rofi/scripts/spotlight-files.sh"

if [[ "${1:-}" == "--calc" ]]; then
    shift

    exec rofi \
        -show calc \
        -modi calc \
        -no-history \
        -no-persist-history \
        -no-show-match \
        -no-sort \
        -lines 0 \
        -calc-command "printf '%s' '{result}' | wl-copy" \
        -theme-str 'entry { placeholder: "Calculate"; }' \
        "$@" \
        -config "$config"
fi

exec rofi \
    -show combi \
    -modes "combi,drun,files:${files_script}" \
    -combi-modes "drun,files" \
    -display-files "Files" \
    -theme-str 'entry { placeholder: "Search apps and files"; }' \
    "$@" \
    -config "$config"
