#!/usr/bin/env bash
# Waybar module: what DeaDBeeF is playing (2026-11-25). Click toggles the vinyl overlay, right-click play/pause.
pgrep -x deadbeef-main >/dev/null || { echo '{"text":"","class":"off"}'; exit 0; }
status=$(playerctl -p DeaDBeeF status 2>/dev/null)
line=$(deadbeef --nowplaying-tf '%artist% – %title%' 2>/dev/null | tail -n1)
line=${line//\"/\\\"}
case "$status" in
    Playing) cls=playing; icon=$'\uf001' ;;
    Paused)  cls=paused;  icon=$'\uf04c' ;;
    *) echo '{"text":"","class":"off"}'; exit 0 ;;
esac
printf '{"text":"%s  %s","class":"%s","tooltip":"%s"}\n' "$icon" "$line" "$cls" "$line"
