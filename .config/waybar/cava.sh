#!/usr/bin/env bash
# Waybar module: tiny audio visualiser from cava's raw output (2026-11-25).
# Emits one JSON line per frame; class "silent" when nothing is playing so CSS can fade it.
exec cava -p "$HOME/.config/cava/waybar.conf" 2>/dev/null | python3 -I -u -c '
import sys, json
sys.stdout.reconfigure(write_through=True)
bars = "▁▂▃▄▅▆▇█"
for line in sys.stdin:
    vals = [int(v) for v in line.strip().split(";") if v]
    if not vals:
        continue
    text = "".join(bars[min(v, 7)] for v in vals)
    try:
        print(json.dumps({"text": text, "class": "silent" if max(vals) == 0 else "playing"}), flush=True)
    except BrokenPipeError:
        break
'
