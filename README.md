# dotfiles · deus-orion

![desktop](.config/hypr/assets/desktop.jpg)

Manjaro · **Hyprland 0.57 (Lua config)** · Waybar · rofi · mako · kitty · zsh + Powerlevel10k · Dracula

Bare git repo checked out over `$HOME` (`alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'`).

## What is different here

- **Accents follow the wallpaper, per workspace.** Every workspace has its own wallpaper
  (`.config/hypr/wallpaper.sh`, crossfade via awww). `palette.py` pulls two hues from each picture;
  on a workspace switch `hyprland.lua` reads the cached palette and recolours the border gradient in
  the same frame (angle turns 45° per workspace), and the script pushes the same accents into Waybar,
  kitty, rofi, mako and hyprlock through small include files with live reloads.
  `SUPER+SHIFT+P` snaps back to plain Dracula.
- **Lua-only behaviour** in `hyprland.lua`: no border on a workspace with a single window, unfocused
  windows dim after 22:00, `SUPER+SHIFT+F` focus mode (no gaps, square, thin borders, bar hidden).
- **DeaDBeeF now-playing overlay** (`now-playing.py`, GTK + gtk-layer-shell + cairo): a record spinning
  at 33⅓ with the cover as its label, a tonearm that tracks the position, and the real stream format
  read with ffprobe (DSD64 · 2.82 MHz · 1-bit, FLAC · 24-bit / 96 kHz …). Shows itself while music
  plays; `SUPER+SHIFT+M` toggles it; click pauses, scroll skips.
- **Waybar** (`.config/waybar/`): floating three-island bar, cava visualiser and now-playing modules.
- **rofi** (`.config/rofi/`): Spotlight-style combi launcher with a cached file index, power menu.

## Keys worth knowing

| key | does |
|---|---|
| `SUPER+Space` | Spotlight: apps + windows + files |
| `SUPER+Z` | dropdown terminal |
| `SUPER+SHIFT+W` / `SUPER+CTRL+W` | new wallpaper for this workspace / reshuffle all |
| `SUPER+SHIFT+F` | focus mode |
| `SUPER+SHIFT+M` | now-playing overlay |
| `SUPER+SHIFT+Q` | power menu |
| `SUPER+I` | keybind cheatsheet (type to filter, Esc closes) |
| `SUPER+CTRL+P` | aux display (HDMI-A-1) on in portrait / off; off by default |
| `ALT+CTRL+A` / `ALT+CTRL+SHIFT+A` | next / previous audio output (AirPlay, USB DAC, Odyssey, aux panel), moves playing streams along |

## Not in the repo

Dracula GTK theme (`~/.themes`), Bibata cursor (`~/.icons`), wallpapers (`~/Pictures/Wallpapers`).
The `accent.*` files are generated at runtime; the committed ones are just defaults.
