#!/usr/bin/env bash
set -euo pipefail

cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
cache_dir="${cache_home}/rofi-spotlight"
cache_file="${cache_dir}/files.list"
max_age_seconds=900

fd_command() {
    if command -v fd >/dev/null 2>&1; then
        printf '%s\n' fd
    elif command -v fdfind >/dev/null 2>&1; then
        printf '%s\n' fdfind
    else
        return 1
    fi
}

open_path() {
    local path="${1/#\~/$HOME}"
    path="${path%/}"

    if [[ ! -e "$path" ]]; then
        exit 0
    fi

    if command -v gio >/dev/null 2>&1; then
        gio open "$path" >/dev/null 2>&1 &
    else
        xdg-open "$path" >/dev/null 2>&1 &
    fi
}

build_cache() {
    mkdir -p "$cache_dir"

    local fd_bin
    if fd_bin="$(fd_command)"; then
        {
            "$fd_bin" . "$HOME" \
                --absolute-path \
                --color never \
                --hyperlink never \
                --follow \
                --max-depth 6 \
                --exclude .config \
                --exclude .cache \
                --exclude .git \
                --exclude .local/share/Trash \
                --exclude .npm \
                --exclude .venv \
                --exclude __pycache__ \
                --exclude build \
                --exclude dist \
                --exclude node_modules \
                --exclude target \
                2>/dev/null

            "$fd_bin" . "$HOME" \
                --absolute-path \
                --color never \
                --hyperlink never \
                --hidden \
                --max-depth 1 \
                --type f \
                2>/dev/null

            for root in "$HOME"/dotfiles; do
                [[ -d "$root" ]] || continue

                "$fd_bin" . "$root" \
                    --absolute-path \
                    --color never \
                    --hyperlink never \
                    --hidden \
                    --follow \
                    --max-depth 6 \
                    --exclude .cache \
                    --exclude .git \
                    --exclude node_modules \
                    2>/dev/null
            done
        } |
            sed "s#^${HOME}#~#" |
            sed '/[[:cntrl:]]/d' |
            sort -fu >"$cache_file"
    else
        {
            find "$HOME" -maxdepth 6 \
                \( -path "$HOME/.config" \
                -o -path "$HOME/.cache" \
                -o -path "$HOME/.git" \
                -o -path "$HOME/.local/share/Trash" \
                -o -path "$HOME/.*" \
                -o -path "*/node_modules" \
                -o -path "*/target" \
                -o -path "*/build" \
                -o -path "*/dist" \) -prune \
                -o -print 2>/dev/null

            find "$HOME" -maxdepth 1 -type f -name '.*' -print 2>/dev/null

            for root in "$HOME"/dotfiles; do
                [[ -d "$root" ]] || continue

                find "$root" -maxdepth 6 \
                    \( -path "*/.git" \
                    -o -path "*/node_modules" \
                    -o -path "*/.cache" \) -prune \
                    -o -print 2>/dev/null
            done
        } |
            sed "s#^${HOME}#~#" |
            sed '/[[:cntrl:]]/d' |
            sort -fu >"$cache_file"
    fi
}

cache_is_fresh() {
    [[ -s "$cache_file" ]] || return 1

    local now file_time age
    now="$(date +%s)"
    file_time="$(stat -c %Y "$cache_file")"
    age=$((now - file_time))

    (( age < max_age_seconds ))
}

if [[ $# -gt 0 ]]; then
    open_path "$1"
    exit 0
fi

if ! cache_is_fresh; then
    build_cache
fi

cat "$cache_file"
