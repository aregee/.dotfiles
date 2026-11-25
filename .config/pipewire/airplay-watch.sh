#!/usr/bin/env bash
# airplay-watch.sh — keeps the AirPlay (raop) sink honest. PipeWire's raop sink dies quietly every so often (log floods
# with "error sending control packet: -9", or the sink sits IDLE while music plays) and WirePlumber then moves the
# streams to the next sink and never back. Every 5 s, while the raop sink is the DEFAULT output:
#   dead session  → suspend + resume the sink (a fresh RTSP session), then move the streams back
#   streams moved → move them back
# Quiet when another output is selected (audio-cycle.sh), so it never fights a deliberate choice.
PATTERN='raop_sink[.]Den[.]'          # which receiver to guard (regex on the sink name)
EVERY=5; COOLDOWN=30; last=0; idle_since=0
log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
sink() { pactl list sinks short 2>/dev/null | awk -v p="$PATTERN" '$2 ~ p {print $2; exit}'; }
state() { pactl list sinks short 2>/dev/null | awk -v s="$1" '$2==s {print $NF; exit}'; }
inputs() { pactl list sink-inputs short 2>/dev/null | awk '{print $1}'; }
inputs_off() { pactl list sink-inputs 2>/dev/null | awk -v idx="$1" '/^Sink Input #/{i=substr($3,2)} /^\s*Sink:/{if ($2!=idx) print i}'; }
sink_index() { pactl list sinks short 2>/dev/null | awk -v s="$1" '$2==s {print $1; exit}'; }
playing() { [ "$(playerctl -p DeaDBeeF status 2>/dev/null)" = Playing ]; }
recover() {
    local s=$1 why=$2 now; now=$(date +%s); [ $((now - last)) -ge $COOLDOWN ] || return
    last=$now; log "recover ($why)"
    pactl suspend-sink "$s" 1; sleep 2; pactl suspend-sink "$s" 0; sleep 3
    for i in $(inputs); do pactl move-sink-input "$i" "$s" 2>/dev/null; done
    notify-send -t 2500 -a Audio -h string:x-canonical-private-synchronous:airplay "AirPlay reconnected ($why)"
}
while sleep $EVERY; do
    s=$(sink); [ -n "$s" ] || { idle_since=0; continue; }
    [ "$(pactl get-default-sink 2>/dev/null)" = "$s" ] || { idle_since=0; continue; }
    flood=$(journalctl --user -u pipewire --since "-${EVERY}s" 2>/dev/null | grep -c 'Bad file descriptor')
    if [ "$flood" -ge 3 ]; then recover "$s" "dead session"; continue; fi
    if playing; then
        idx=$(sink_index "$s"); off=$(inputs_off "$idx")
        if [ -n "$off" ]; then
            st=$(state "$s")
            [ "$st" = RUNNING ] || [ "$st" = IDLE ] || recover "$s" "sink $st"
            for i in $off; do pactl move-sink-input "$i" "$s" 2>/dev/null && log "moved stream $i back"; done
            continue
        fi
        st=$(state "$s")
        if [ "$st" = RUNNING ]; then idle_since=0
        else now=$(date +%s); [ "$idle_since" = 0 ] && idle_since=$now
             [ $((now - idle_since)) -ge 10 ] && { recover "$s" "stuck $st while playing"; idle_since=0; }
        fi
    else idle_since=0; fi
done
