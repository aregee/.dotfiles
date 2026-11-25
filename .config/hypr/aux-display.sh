#!/usr/bin/env bash
# aux-display.sh on|off|toggle — the HDMI-A-1 side panel (normally on the Mac). Stateless: asks Hyprland first.
AUX=HDMI-A-1
state=$(hyprctl monitors all -j | python3 -I -c "import sys,json; m=[m for m in json.load(sys.stdin) if m['name']=='$AUX']; print('absent' if not m else ('off' if m[0]['disabled'] else 'on'))")
[ "$state" = absent ] && { notify-send -t 2000 -a Hyprland "aux display: not connected"; exit 1; }
want=$1; [ "$want" = toggle ] && { [ "$state" = on ] && want=off || want=on; }
[ "$want" = "$state" ] && exit 0
GPU=alsa_card.pci-0000_0b_00.1
old_prof=$(pactl list cards | awk '/Name: '"$GPU"'/{f=1} f && /Active Profile:/{print $3; exit}'); old_def=$(pactl get-default-sink)
STATE=$HOME/.cache/hypr-aux-on; [ "$want" = on ] && touch "$STATE" || rm -f "$STATE"      # the Lua rule and its monitor.added handler follow this
hyprctl dispatch "function() aux_display($([ "$want" = on ] && echo true || echo false)) end" >/dev/null
# WirePlumber jumps the GPU's single HDMI/DP audio profile to a panel that just appeared, which silently moves sound
# off the Odyssey. Put the profile, the default sink and the streams back where they were.
if [ "$want" = on ] && [ -n "$old_prof" ]; then
    sleep 3
    now_prof=$(pactl list cards | awk '/Name: '"$GPU"'/{f=1} f && /Active Profile:/{print $3; exit}')
    if [ "$now_prof" != "$old_prof" ]; then
        pactl set-card-profile "$GPU" "$old_prof" 2>/dev/null
        for _ in $(seq 20); do pactl list sinks short | grep -q "$old_def" && break; sleep 0.1; done
    fi
    if [ "$(pactl get-default-sink)" != "$old_def" ] && pactl list sinks short | grep -q "$old_def"; then
        pactl set-default-sink "$old_def"
        case $old_def in alsa_output.pci-0000_0b_00.1.*) for inp in $(pactl list sink-inputs short | awk '{print $1}'); do pactl move-sink-input "$inp" "$old_def" 2>/dev/null; done;; esac
    fi
fi
