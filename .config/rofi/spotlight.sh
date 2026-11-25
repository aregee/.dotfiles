#!/usr/bin/env bash
# Spotlight-style launcher: apps + open windows + files in one box.
# Type "!files foo" / "!drun foo" / "!window foo" to restrict to one source.
exec rofi -show combi -modes combi \
    -combi-modes "drun,window,files:$HOME/.config/rofi/files.sh" \
    -combi-hide-mode-prefix true -matching fuzzy -sort -sorting-method fzf \
    -display-combi "" -theme ~/.config/rofi/dracula.rasi
