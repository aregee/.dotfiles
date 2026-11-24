#!/bin/sh
# Hyprland 0.57.2 only registers input devices that appear AFTER its InputManager exists;
# devices present at startup are opened by libinput but never surface in Hyprland (hyprctl devices).
# Re-announce them: synthetic remove + add uevents make libinput drop and re-add every input device,
# which Hyprland now sees. Runs once at session start (hyprland.lua) and on SUPER+CTRL+I.
# Needs the scoped sudo rule in /etc/sudoers.d/10-hypr-input-rescan.
sleep "${1:-2}"
sudo -n /usr/bin/udevadm trigger --subsystem-match=input --action=remove
sleep 0.5
sudo -n /usr/bin/udevadm trigger --subsystem-match=input --action=add
