#!/usr/bin/env bash
# Per-workspace wallpapers (one fixed picture per workspace, crossfade on switch) via awww.
# Pool: ~/Pictures/Wallpapers (override with WALLPAPER_DIR). Landscape images only.
#
#   wallpaper.sh init        start awww-daemon if needed, show current workspace's picture
#   wallpaper.sh set [ID]    show the picture assigned to workspace ID (default: active one)
#   wallpaper.sh shuffle     re-pick a fresh random picture for every workspace, apply current
#   wallpaper.sh reroll      new random picture for the current workspace only
DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
STATE="$HOME/.cache/hypr-wallpapers"
LINK="$HOME/.config/hypr/current-wallpaper"
TRANSITION=(--transition-type fade --transition-duration 0.45 --transition-fps 120 --resize crop)
mkdir -p "$STATE"

pick() {
    local f w h
    for _ in 1 2 3 4 5 6; do
        f=$(find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | shuf -n1)
        read -r w h < <(identify -format '%w %h' "$f[0]" 2>/dev/null)
        [ -n "$w" ] && [ "$w" -ge "${h:-0}" ] && { echo "$f"; return; }
    done
    echo "$f"
}

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' ; }

ensure_daemon() {
    if ! awww query >/dev/null 2>&1; then
        setsid awww-daemon >/dev/null 2>&1 &
        for _ in $(seq 1 30); do awww query >/dev/null 2>&1 && break; sleep 0.1; done
    fi
}

wall_for() {   # prints the file assigned to workspace $1, assigning one if missing
    local ws="$1" f="$STATE/ws-$1"
    if [ ! -s "$f" ] || [ ! -r "$(cat "$f")" ]; then pick > "$f"; fi
    cat "$f"
}

apply() {      # show workspace $1's picture
    local ws="${1:-$(active_ws)}" img
    [ -n "$ws" ] || return 0
    img=$(wall_for "$ws")
    [ "$(cat "$STATE/current" 2>/dev/null)" = "$img" ] && return 0   # unchanged: no transition
    echo "$img" > "$STATE/current"
    ln -sfn "$img" "$LINK"
    awww img "$img" "${TRANSITION[@]}" >/dev/null 2>&1
}

case "${1:-set}" in
    init)    ensure_daemon; rm -f "$STATE/current"; apply ;;
    set)     ensure_daemon; apply "$2" ;;
    shuffle) rm -f "$STATE"/ws-* "$STATE/current"; ensure_daemon; apply ;;
    reroll)  ws=$(active_ws); rm -f "$STATE/ws-$ws" "$STATE/current"; ensure_daemon; apply "$ws" ;;
    *) echo "usage: $0 {init|set [ID]|shuffle|reroll}" >&2; exit 1 ;;
esac
