#!/usr/bin/env bash
# Per-workspace wallpapers with a crossfade, plus accent colours derived from the picture (2026-11-25).
# Pool: ~/Pictures/Wallpapers (override with WALLPAPER_DIR). Landscape images only.
#
#   wallpaper.sh init          start awww-daemon if needed, show current workspace's picture, pre-compute palettes
#   wallpaper.sh set [ID]      show the picture assigned to workspace ID (default: active one), push its accents
#   wallpaper.sh shuffle       re-pick a fresh random picture for every workspace, apply current
#   wallpaper.sh reroll        new random picture for the current workspace only
#   wallpaper.sh palette IMG   print "accent accent2 dim" for IMG (computes and caches it)
#   wallpaper.sh accent-reset  put every app back on the plain Dracula accents
#
# Accents land in: waybar/accent.css, kitty/accent.conf, rofi/accent.rasi, mako/accent, and the $accent lines of hyprlock.conf.
# Hyprland's own borders are set from hyprland.lua, which reads the same palette cache.
DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
STATE="$HOME/.cache/hypr-wallpapers"
PAL="$STATE/palette"
LINK="$HOME/.config/hypr/current-wallpaper"
CFG="$HOME/.config"
TRANSITION=(--transition-type fade --transition-duration 0.45 --transition-fps 120 --resize crop)
mkdir -p "$STATE" "$PAL"

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

# ---- palette -------------------------------------------------------------
palette() {   # prints "accent accent2 dim" for image $1; computed once per file name
    local b="$PAL/$(basename "$1")"
    [ -s "$b.json" ] || python3 -I "$HOME/.config/hypr/palette.py" "$1" "$b" >/dev/null 2>&1
    python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["accent"], d["accent2"], d["dim"])' "$b.json" 2>/dev/null \
        || echo "bd93f9 ff79c6 44475a"
}

palette_all() {   # background: palettes for the whole pool so the first visit to a workspace is already coloured
    find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | while read -r f; do
        [ -s "$PAL/$(basename "$f").json" ] || nice -n 19 python3 -I "$HOME/.config/hypr/palette.py" "$f" "$PAL/$(basename "$f")" >/dev/null 2>&1
    done
}

write_accents() {   # $1 accent $2 accent2 $3 dim  -> app include files; reload what can be reloaded live
    local a="$1" b="$2" d="$3"
    [ "$(cat "$STATE/accent-current" 2>/dev/null)" = "$a $b $d" ] && return 0
    echo "$a $b $d" > "$STATE/accent-current"
    printf '/* written by wallpaper.sh */\n@define-color accent #%s;\n@define-color accent2 #%s;\n@define-color accent-dim #%s;\n' "$a" "$b" "$d" > "$CFG/waybar/accent.css"
    printf '# written by wallpaper.sh\ncursor #%s\ncursor_text_color #282a36\nselection_background #%s\nselection_foreground #282a36\nurl_color #%s\nactive_border_color #%s\ninactive_border_color #%s\nactive_tab_background #%s\nactive_tab_foreground #282a36\n' "$a" "$a" "$b" "$a" "$d" "$a" > "$CFG/kitty/accent.conf"
    printf '/* written by wallpaper.sh */\n* { accent: #%s; pink: #%s; }\n' "$a" "$b" > "$CFG/rofi/accent.rasi"
    printf '# written by wallpaper.sh\nborder-color=#%s\n' "$a" > "$CFG/mako/accent"
    sed -i -e "s/^\$accent = rgb([0-9a-f]*)/\$accent = rgb($a)/" -e "s/^\$accent2 = rgb([0-9a-f]*)/\$accent2 = rgb($b)/" "$CFG/hypr/hyprlock.conf"
    pkill -SIGUSR2 -x waybar 2>/dev/null   # re-read CSS
    pkill -SIGUSR1 -x kitty  2>/dev/null   # re-read kitty.conf
    makoctl reload >/dev/null 2>&1 || true
}

wall_for() {   # prints the file assigned to workspace $1, assigning one if missing
    local ws="$1" f="$STATE/ws-$1"
    if [ ! -s "$f" ] || [ ! -r "$(cat "$f")" ]; then pick > "$f"; fi
    cat "$f"
}

apply() {      # show workspace $1's picture and its accents
    local ws="${1:-$(active_ws)}" img
    [ -z "$ws" ] || [ "$ws" -lt 1 ] 2>/dev/null && return 0
    img=$(wall_for "$ws")
    echo "$ws" > "$STATE/active-ws"          # read by hyprland.lua on a config reload
    if [ "$(cat "$STATE/current" 2>/dev/null)" != "$img" ]; then   # unchanged: no transition
        echo "$img" > "$STATE/current"
        ln -sfn "$img" "$LINK"
        awww img "${TRANSITION[@]}" "$img" >/dev/null 2>&1
    fi
    # shellcheck disable=SC2046
    write_accents $(palette "$img")
}

case "${1:-set}" in
    init)    ensure_daemon; rm -f "$STATE/current" "$STATE/accent-current"; apply; (palette_all &) ;;
    set)     ensure_daemon; apply "$2" ;;
    shuffle) rm -f "$STATE"/ws-* "$STATE/current"; ensure_daemon; apply; hyprctl dispatch 'function() reapply_accent() end' >/dev/null 2>&1 ;;
    reroll)  ws=$(active_ws); rm -f "$STATE/ws-$ws" "$STATE/current"; ensure_daemon; apply "$ws"; hyprctl dispatch 'function() reapply_accent() end' >/dev/null 2>&1 ;;
    palette) palette "$2" ;;
    palette-all) palette_all ;;
    accent-reset) rm -f "$STATE/accent-current"; write_accents bd93f9 ff79c6 44475a ;;
    *) echo "usage: $0 {init|set [ID]|shuffle|reroll|palette IMG|palette-all|accent-reset}" >&2; exit 2 ;;
esac
