#!/usr/bin/env bash
# audio-cycle.sh [next|prev] [--dry-run] — step the default output through every connected device and move the
# playing streams along. The GPU's HDMI/DP audio is ONE card with one active profile, so its displays (Odyssey on DP,
# the portrait panel on HDMI) never show up as sinks at the same time: those are listed as profiles here and
# switched with set-card-profile before the sink exists. mako names the device.
dir=${1:-next}; dry=0; [ "$2" = --dry-run ] && dry=1
GPU=alsa_card.pci-0000_0b_00.1
SKIP="MacBook"                       # sinks to leave out of the rotation (regex on the sink name), e.g. the Mac's own AirPlay receiver
cards=$(pactl list cards)
# candidates: "sink:<name>" for every non-GPU sink, "profile:<profile>" for every available GPU stereo profile
cands=(); labels=()
while read -r _ name _; do
    case $name in alsa_output.pci-0000_0b_00.1.*) continue;; esac
    [ -n "$SKIP" ] && printf "%s" "$name" | grep -qE "$SKIP" && continue
    cands+=("sink:$name"); labels+=("$(pactl list sinks | awk -v s="$name" '$1=="Name:" && $2==s {f=1} f && /Description:/ {sub(/^[ \t]*Description: /,""); print; exit}')")
done < <(pactl list sinks short)
while read -r prof rest; do
    prof=${prof%:}; n=${prof#output:hdmi-stereo-extra}; [ "$n" = "$prof" ] && n=0
    port="hdmi-output-$n"
    label=$(printf '%s\n' "$cards" | awk -v p="$port:" '$1==p {f=1} f && /device.product.name/ {gsub(/.*= "|"$/,""); print; exit} f && /^[ \t]*hdmi-output-/ && $1!=p {exit}')
    [ -n "$label" ] || label=$(printf '%s\n' "$cards" | awk -v p="$port:" '$1==p {sub(/^[^:]*: /,""); sub(/ \(type:.*/,""); print; exit}')
    cands+=("profile:$prof"); labels+=("$label")
done < <(printf '%s\n' "$cards" | awk '/Name: '"$GPU"'/{f=1} f && /^Card #/ && !/0b_00.1/{exit} f && /output:hdmi-stereo[^ ]*: .*available: yes/{print $1}')
n=${#cands[@]}; [ "$n" -gt 1 ] || { notify-send -t 1500 -a Audio "only one output"; exit 0; }
# where are we? the default sink, or (for the GPU) its active profile
cur=$(pactl get-default-sink); i=-1
case $cur in alsa_output.pci-0000_0b_00.1.*) curkey="profile:$(printf '%s\n' "$cards" | awk '/Name: '"$GPU"'/{f=1} f && /Active Profile:/{print $3; exit}')";; *) curkey="sink:$cur";; esac
for k in "${!cands[@]}"; do [ "${cands[$k]}" = "$curkey" ] && i=$k; done
[ "$dir" = prev ] && i=$(( (i - 1 + n) % n )) || i=$(( (i + 1) % n ))
new=${cands[$i]}; label=${labels[$i]}
[ "$dry" = 1 ] && { echo "would switch: $curkey -> $new ($label)"; printf '  list: %s\n' "${cands[@]}"; exit 0; }
case $new in
    profile:*) prof=${new#profile:}; pactl set-card-profile "$GPU" "$prof"
               sink="alsa_output.pci-0000_0b_00.1.${prof#output:}"
               for _ in $(seq 20); do pactl list sinks short | grep -q "$sink" && break; sleep 0.1; done;;
    sink:*)    sink=${new#sink:};;
esac
pactl set-default-sink "$sink"
for inp in $(pactl list sink-inputs short | awk '{print $1}'); do pactl move-sink-input "$inp" "$sink" 2>/dev/null; done
notify-send -t 1800 -a Audio -h string:x-canonical-private-synchronous:audio-out "output: $label"
