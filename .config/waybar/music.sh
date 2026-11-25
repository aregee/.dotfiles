#!/usr/bin/env bash
# Waybar music module (2026-11-25): cava bars are the body; the title fades in for a few seconds on a
# track change and fades out again. Hover: artist/title, album, format, position. Click: vinyl overlay.
# One JSON line per cava frame (30/s); track state refreshed once a second from DeaDBeeF's MPRIS (music.py).
# cava listens to the monitor of the sink DeaDBeeF is actually playing to (AirPlay, HDMI, USB DAC...);
# music.py exits when that sink changes and Waybar restarts us (restart-interval) on the new one.
sink_of_deadbeef() {
    local idx
    idx=$(pactl list sink-inputs | awk '/^Sink Input/{s=""} /Sink: /{s=$2} /application.name = "Deadbeef"/{print s; exit}')
    [ -n "$idx" ] && pactl list sinks short | awk -v i="$idx" '$1==i{print $2; exit}'
}
SINK=$(sink_of_deadbeef); [ -n "$SINK" ] || SINK=$(pactl get-default-sink)
CONF="${XDG_RUNTIME_DIR:-/tmp}/cava-waybar.conf"
sed "s|^source = .*|source = ${SINK}.monitor|" "$HOME/.config/cava/waybar.conf" > "$CONF"
export MUSIC_SINK="$SINK"
exec cava -p "$CONF" 2>/dev/null | python3 -I -u "$HOME/.config/waybar/music.py"
