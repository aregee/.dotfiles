#!/usr/bin/env bash
# SUPER+I: searchable list of current keybinds (awesome's hotkeys popup)
hyprctl binds -j | jq -r '
  def mods: [ (if .modmask % 2 >= 1 then "SHIFT" else empty end),
              (if (.modmask / 4 | floor) % 2 >= 1 then "CTRL" else empty end),
              (if (.modmask / 8 | floor) % 2 >= 1 then "ALT" else empty end),
              (if (.modmask / 64 | floor) % 2 >= 1 then "SUPER" else empty end) ] | join("+");
  .[] | "\(mods)\(if mods != "" then "+" else "" end)\(.key)\t\(.description // (.dispatcher + " " + .arg))"' \
  | column -t -s $'\t' | rofi -dmenu -i -p keys -theme-str 'window {width: 60%;}' >/dev/null
