#!/usr/bin/env bash
# Per-workspace wallpapers with a crossfade, plus accent colours derived from the picture (2026-11-25).
# Pool: ~/Pictures/Wallpapers (override with WALLPAPER_DIR), landscape for the main display; the side panel (portrait)
# draws from the vertical/ subfolder (the old awesome copland "wallpapersv" set).
#
#   wallpaper.sh init          start awww-daemon if needed, show current workspace's picture, pre-compute palettes
#   wallpaper.sh set [ID]      show the picture assigned to workspace ID (default: active one), push its accents
#                              (IDs above 10 are the side panel's tags: own picture on HDMI-A-1, no accents)
#   wallpaper.sh set-aux [ID]  side panel: show the picture of its tag ID (default: the one it is on)
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
MAIN="DP-3"; AUX="HDMI-A-1"; AUX_BASE=10      # like awesome: every screen renders its own wallpaper. Panel tags are 11..19 (hyprland.lua)
AUX_DIR="${WALLPAPER_DIR_AUX:-$DIR/vertical}"
TRANSITION=(--transition-type grow --transition-pos center --transition-duration 0.8 --transition-fps 120 --transition-bezier .4,0,.2,1 --resize crop)   # awww 0.12 caps every transition at ~0.3 s whatever you ask; grow-from-centre reads smoothest
mkdir -p "$STATE" "$PAL"

pick() {
    local f w h
    for _ in 1 2 3 4 5 6; do
        f=$(find "$DIR" -path "$AUX_DIR" -prune -o -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print | shuf -n1)
        read -r w h < <(identify -format '%w %h' "$f[0]" 2>/dev/null)
        [ -n "$w" ] && [ "$w" -ge "${h:-0}" ] && { echo "$f"; return; }
    done
    echo "$f"
}

pick_portrait() {   # the side panel stands in portrait: the vertical/ set first, else any portrait picture from the pool
    local f w h
    f=$(find "$AUX_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | shuf -n1)
    [ -n "$f" ] && { echo "$f"; return; }
    for _ in 1 2 3 4 5 6 7 8; do
        f=$(find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | shuf -n1)
        read -r w h < <(identify -format '%w %h' "$f[0]" 2>/dev/null)
        [ -n "$h" ] && [ "$h" -gt "${w:-0}" ] && { echo "$f"; return; }
    done
    echo "$f"
}

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' ; }
ws_on() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.name=="'"$1"'") | .activeWorkspace.id' ; }   # active workspace of output $1 ("" if off)
is_aux() { [ "${1:-0}" -gt "$AUX_BASE" ] 2>/dev/null; }

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
    find "$DIR" -path "$AUX_DIR" -prune -o -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print | while read -r f; do
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
    # Waybar: reload_style_on_change watches accent.css (imported by style.css) and re-reads the CSS in place — the old SIGUSR2 restarted the bar and flashed it
    pkill -SIGUSR1 -x kitty  2>/dev/null   # re-read kitty.conf
    makoctl reload >/dev/null 2>&1 || true
}

wall_for() {   # prints the file assigned to workspace $1, assigning one if missing
    local ws="$1" f="$STATE/ws-$1"
    if [ ! -s "$f" ] || [ ! -r "$(cat "$f")" ]; then { is_aux "$ws" && pick_portrait || pick; } > "$f"; fi
    cat "$f"
}

apply_aux() {  # side panel: its own picture per tag; the theme keeps following the main display
    local ws="${1:-$(ws_on "$AUX")}" img
    [ -z "$ws" ] && return 0
    img=$(wall_for "$ws")
    [ "$(cat "$STATE/aux-current" 2>/dev/null)" = "$img" ] && return 0
    echo "$img" > "$STATE/aux-current"
    awww img -o "$AUX" "${TRANSITION[@]}" "$img" >/dev/null 2>&1
}

apply() {      # show workspace $1's picture and its accents
    local ws="${1:-$(active_ws)}" img
    [ -z "$ws" ] || [ "$ws" -lt 1 ] 2>/dev/null && return 0
    is_aux "$ws" && { apply_aux "$ws"; return 0; }
    img=$(wall_for "$ws")
    echo "$ws" > "$STATE/active-ws"          # read by hyprland.lua on a config reload
    if [ "$(cat "$STATE/current" 2>/dev/null)" != "$img" ]; then   # unchanged: no transition
        echo "$img" > "$STATE/current"
        ln -sfn "$img" "$LINK"
        awww img -o "$MAIN" "${TRANSITION[@]}" "$img" >/dev/null 2>&1
    fi
    # shellcheck disable=SC2046
    write_accents $(palette "$img")
}

case "${1:-set}" in
    init)    ensure_daemon; rm -f "$STATE/current" "$STATE/aux-current" "$STATE/accent-current"; apply "$(ws_on "$MAIN")"; apply_aux; (palette_all &) ;;
    set)     ensure_daemon; apply "$2" ;;
    set-aux) ensure_daemon; apply_aux "$2" ;;
    shuffle) rm -f "$STATE"/ws-* "$STATE/current" "$STATE/aux-current"; ensure_daemon; apply "$(ws_on "$MAIN")"; apply_aux; hyprctl dispatch 'function() reapply_accent() end' >/dev/null 2>&1 ;;
    reroll)  ws=$(active_ws); rm -f "$STATE/ws-$ws" "$STATE/current"; ensure_daemon; apply "$ws"; hyprctl dispatch 'function() reapply_accent() end' >/dev/null 2>&1 ;;
    palette) palette "$2" ;;
    palette-all) palette_all ;;
    accent-reset) rm -f "$STATE/accent-current"; write_accents bd93f9 ff79c6 44475a ;;
    *) echo "usage: $0 {init|set [ID]|set-aux [ID]|shuffle|reroll|palette IMG|palette-all|accent-reset}" >&2; exit 2 ;;
esac
