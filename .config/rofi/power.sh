#!/usr/bin/env bash
# rofi power menu (2026-11-25): lock / suspend / logout / reboot / shutdown, with a confirm step for the last three.
THEME="$HOME/.config/rofi/dracula.rasi"
menu() {   # $1 prompt, rest: lines
    local p="$1"; shift
    printf '%s\n' "$@" | rofi -dmenu -i -p "$p" -theme "$THEME" \
        -theme-str 'window { width: 320px; } listview { lines: 5; } element { padding: 10px 12px; } inputbar { enabled: false; }'
}
confirm() { [ "$(menu "$1?" "Yes" "No")" = "Yes" ]; }
choice=$(menu "power" "   Lock" "   Suspend" "   Log out" "   Reboot" "   Shut down")
case "$choice" in
    *Lock)        hyprlock ;;
    *Suspend)     systemctl suspend ;;
    *"Log out")   confirm "Log out" && hyprctl dispatch 'hl.dsp.exit()' ;;
    *Reboot)      confirm "Reboot" && systemctl reboot ;;
    *"Shut down") confirm "Shut down" && systemctl poweroff ;;
esac
