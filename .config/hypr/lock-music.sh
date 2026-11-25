#!/usr/bin/env bash
# one line for hyprlock: what DeaDBeeF is playing, or nothing
pgrep -x deadbeef-main >/dev/null || exit 0
[ "$(playerctl -p DeaDBeeF status 2>/dev/null)" = "Playing" ] || exit 0
deadbeef --nowplaying-tf '%artist%  ·  %title%' 2>/dev/null | tail -n1
