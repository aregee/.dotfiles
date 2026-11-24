-- Hyprland (Lua config, 0.57+) for deus-orion
-- Ported from ~/.config/awesome/rc.lua on 2026-11-24. Docs: https://wiki.hypr.land/configuring/
-- Reload: SUPER+CTRL+R (or `hyprctl reload`). Verify: `Hyprland --verify-config`

require("env")

------------------
---- MONITORS ----
------------------
-- Single 34" ultrawide (DisplayPort-2 under X11). Same mode as under awesome; FreeSync on.
-- Check connector names with: hyprctl monitors
hl.monitor({ output = "", mode = "3440x1440@175", position = "auto", scale = 1, vrr = 1 })   -- Odyssey G85SB OLED: 175 Hz max

---------------------
---- MY PROGRAMS ----
---------------------
local terminal = "kitty"
local menu     = "rofi -show drun -modi combi,drun,ssh"
local run      = "rofi -show run"
local browser  = "brave"
local editor   = "emacs"
local files    = "nautilus --new-window"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("waybar")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh init")   -- per-workspace wallpapers (awww), copland pool
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("gnome-keyring-daemon --daemonize --login")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/openrgb-single --startminimized")
    hl.exec_cmd("msm_notifier")
    -- workaround: Hyprland 0.57 misses input devices present at startup; re-announce them (see input-rescan.sh)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/input-rescan.sh 2")
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Dracula palette (matches the termite/kitty colours)
hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(bd93f9ee)", "rgba(ff79c6ee)" }, angle = 45 },
            inactive_border = "rgba(44475aaa)",
        },
        resize_on_border = true,
        allow_tearing = true,       -- only windows with the `immediate` rule actually tear (cs2 below)
        layout = "master",          -- awesome "tile": master left, stack right
    },
    decoration = {
        rounding = 10,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = true, range = 8, render_power = 3, color = 0xee1a1a1a },
        blur   = { enabled = true, size = 4, passes = 2, vibrancy = 0.17 },
    },
    animations = { enabled = true },
    master = {
        new_status = "slave",
        new_on_top = false,
        mfact = 0.55,
        orientation = "left",
    },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 1,
        focus_on_activate = true,
    },
    input = {
        kb_layout = "us",
        kb_model  = "pc105",
        follow_mouse = 1,
        sensitivity = 0,
        numlock_by_default = true,
    },
    binds = { workspace_back_and_forth = false },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.animation({ leaf = "global",     enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "quick",        style = "popin 87%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2, bezier = "quick" })
hl.animation({ leaf = "layers",     enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "easeOutQuint", style = "slide" })

--------------------
---- WORKSPACES ----
--------------------
-- each workspace has its own wallpaper; crossfade when the active workspace changes
hl.on("workspace.active", function(ws)
    local id = ws and ws.id or nil
    if ws and ws.special then return end
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh set " .. (id and tostring(id) or ""))
end)
-- awesome tags: home, web, dev, proc, lounge
local tags = { "home", "web", "dev", "proc", "lounge" }
for i, name in ipairs(tags) do
    hl.workspace_rule({ workspace = tostring(i), default_name = name, persistent = true })
end
-- dropdown terminal (SUPER+Z), like awesome's quake
hl.workspace_rule({ workspace = "special:quake", on_created_empty = "kitty --class quake", gaps_out = 40 })

---------------------
---- KEYBINDINGS ----
---------------------
local M = "SUPER"
local A = "ALT"

-- launchers
hl.bind(M .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(M .. " + SHIFT + Return", hl.dsp.exec_cmd("foot"))           -- fallback terminal (no GPU buffers)
hl.bind(M .. " + X",      hl.dsp.exec_cmd(menu))
hl.bind(M .. " + R",      hl.dsp.exec_cmd(run))
hl.bind(M .. " + Q",      hl.dsp.exec_cmd(browser))
hl.bind(M .. " + A",      hl.dsp.exec_cmd(editor))
hl.bind(M .. " + E",      hl.dsp.exec_cmd(files))
-- Spotlight-style: apps + windows + files in one box; SUPER+= calculator; SUPER+SHIFT+E rofi file browser
hl.bind(M .. " + space",     hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/rofi/spotlight.sh"))
hl.bind(M .. " + equal",     hl.dsp.exec_cmd("rofi -show calc -modes calc -no-show-match -no-sort -calc-command 'echo -n \"{result}\" | wl-copy' -theme ~/.config/rofi/dracula.rasi"))
hl.bind(M .. " + SHIFT + E", hl.dsp.exec_cmd("rofi -show filebrowser -theme ~/.config/rofi/dracula.rasi"))
hl.bind(M .. " + Z",      hl.dsp.workspace.toggle_special("quake"))
hl.bind(M .. " + Escape", hl.dsp.focus({ workspace = "previous" }))       -- awesome: tag history "go back"
hl.bind(A .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))                  -- awesome: lock screen
hl.bind(M .. " + W",      hl.dsp.exec_cmd("rofi -show drun"))             -- awesome: main menu
hl.bind(M .. " + I",      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/show-binds.sh"))  -- awesome: show help
hl.bind(M .. " + SHIFT + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh reroll"))   -- new picture for this workspace
hl.bind(M .. " + CTRL + W",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh shuffle"))  -- reshuffle all workspaces
hl.bind(M .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p clip | cliphist decode | wl-copy"))

-- session
hl.bind(M .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(M .. " + CTRL + R", function()
    hl.dispatch(hl.dsp.reload_config())
    hl.notification.create({ text = "Hyprland: config reloaded", timeout = 2000 })
end)
hl.bind(M .. " + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))   -- toggle bar
hl.bind(M .. " + CTRL + I", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/input-rescan.sh 0"))  -- re-detect keyboards/mice

-- windows
hl.bind(M .. " + SHIFT + C",    hl.dsp.window.close())
hl.bind(M .. " + F",            hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
hl.bind(M .. " + M",            hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }))
hl.bind(M .. " + CTRL + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(M .. " + T",            hl.dsp.window.pin())
hl.bind(M .. " + U",            hl.dsp.focus({ urgent_or_last = true }))
-- "minimize": park in a special workspace, SUPER+CTRL+N brings it back
hl.bind(M .. " + N",        hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(M .. " + CTRL + N", hl.dsp.workspace.toggle_special("minimized"))

-- focus (vim keys, as in awesome)
hl.bind(M .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(M .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(M .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(M .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(A .. " + J", hl.dsp.window.cycle_next())
hl.bind(A .. " + K", hl.dsp.window.cycle_next({ next = false }))
hl.bind(M .. " + Tab",         hl.dsp.focus({ last = true }))             -- awesome: focus history previous
hl.bind(M .. " + SHIFT + Tab", hl.dsp.window.cycle_next())                -- awesome: go forth
-- tags: SUPER+Left/Right all workspaces, ALT+Left/Right only non-empty ones
hl.bind(M .. " + Left",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind(M .. " + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(A .. " + Left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(A .. " + Right", hl.dsp.focus({ workspace = "e+1" }))
-- dynamic tags: SUPER+SHIFT+N new (empty) workspace, SUPER+SHIFT+R rename current one
hl.bind(M .. " + SHIFT + N", hl.dsp.focus({ workspace = "empty" }))
hl.bind(M .. " + SHIFT + R", hl.dsp.exec_cmd([[sh -c 'n=$(rofi -dmenu -p "rename workspace" -lines 0) && [ -n "$n" ] && hyprctl dispatch "hl.dsp.workspace.rename({ workspace = $(hyprctl activeworkspace -j | jq .id), name = \"$n\" })"']]))
-- magnify (ALT+SHIFT+M in awesome): float + centre the window
hl.bind(A .. " + SHIFT + M", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.center())
end)

-- move / swap (master layout)
hl.bind(M .. " + SHIFT + J",    hl.dsp.window.swap({ next = true }))
hl.bind(M .. " + SHIFT + K",    hl.dsp.window.swap({ prev = true }))
hl.bind(M .. " + CTRL + Return", hl.dsp.layout("swapwithmaster"))
hl.bind(M .. " + SHIFT + H",    hl.dsp.layout("addmaster"))
hl.bind(M .. " + SHIFT + L",    hl.dsp.layout("removemaster"))
hl.bind(M .. " + SHIFT + space", hl.dsp.layout("orientationnext"))     -- (SUPER+space is now the Spotlight launcher)
-- master width factor (ALT+SHIFT+H/L in awesome)
hl.bind(A .. " + SHIFT + L", hl.dsp.layout("mfact +0.05"))
hl.bind(A .. " + SHIFT + H", hl.dsp.layout("mfact -0.05"))
-- generic resize of the focused window
hl.bind(M .. " + " .. A .. " + L", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })
hl.bind(M .. " + " .. A .. " + H", hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
hl.bind(M .. " + " .. A .. " + K", hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
hl.bind(M .. " + " .. A .. " + J", hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })

-- gaps (ALT+CTRL +/- in awesome)
local gaps = 6
local function set_gaps(delta)
    gaps = math.max(0, gaps + delta)
    hl.config({ general = { gaps_in = gaps, gaps_out = gaps * 2 } })
end
hl.bind(A .. " + CTRL + equal", function() set_gaps(2) end)
hl.bind(A .. " + CTRL + minus", function() set_gaps(-2) end)

-- multi-monitor
hl.bind(M .. " + CTRL + J", hl.dsp.focus({ monitor = "+1" }))
hl.bind(M .. " + CTRL + K", hl.dsp.focus({ monitor = "-1" }))
hl.bind(M .. " + O",        hl.dsp.window.move({ monitor = "+1" }))

-- workspaces 1-9 (SUPER+N view, SUPER+SHIFT+N move window)
for i = 1, 9 do
    hl.bind(M .. " + " .. i,            hl.dsp.focus({ workspace = i }))
    hl.bind(M .. " + SHIFT + " .. i,    hl.dsp.window.move({ workspace = i }))
end
hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- mouse
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- clipboard bridge (SUPER+C / SUPER+V in awesome: primary <-> clipboard)
hl.bind(M .. " + C", hl.dsp.exec_cmd("sh -c 'wl-paste -p -n | wl-copy'"))
hl.bind(M .. " + V", hl.dsp.exec_cmd("sh -c 'wl-paste -n | wl-copy -p'"))

-- screenshots
hl.bind("Print",            hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
-- awesome ALT+P ran /usr/local/bin/screenshot (scrot -> ~/screenshots/<timestamp>.png)
hl.bind(A .. " + P",        hl.dsp.exec_cmd("sh -c 'hyprshot -m output -o ~/Pictures/Screenshots -f $(date +%Y%m%d%H%M%S).png'"))
hl.bind("SHIFT + Print",    hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(M .. " + Print",    hl.dsp.exec_cmd("hyprshot -m window"))

-- volume (PulseAudio / pipewire-pulse via pactl)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +2%"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -2%"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),  { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind(A .. " + CTRL + M", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ 100%"))
hl.bind(A .. " + CTRL + 0", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ 0%"))
-- media (mpc in awesome; playerctl covers mpd and browsers)
hl.bind(A .. " + CTRL + Up",    hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind(A .. " + CTRL + Down",  hl.dsp.exec_cmd("playerctl stop"),       { locked = true })
hl.bind(A .. " + CTRL + Left",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind(A .. " + CTRL + Right", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

----------------------
---- WINDOW RULES ----
----------------------
-- awesome rules: Brave -> web, Emacs -> dev
hl.window_rule({ name = "brave-web",  match = { class = "^([Bb]rave-browser|Brave)$" }, workspace = 2 })
hl.window_rule({ name = "emacs-dev",  match = { class = "^([Ee]macs)$" },               workspace = 3 })
hl.window_rule({ name = "quake-term", match = { class = "^quake$" }, float = true, size = "70% 50%", move = "15% 8%" })
hl.window_rule({ name = "float-utils",
    match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager|polychromatic.*|OpenRGB|xdg-desktop-portal-gtk)$" },
    float = true })
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true })
hl.window_rule({ name = "no-idle-when-fullscreen", match = { fullscreen = true }, idle_inhibit = "fullscreen" })
-- Counter-Strike 2: allow tearing (lowest latency) for this game only
hl.window_rule({ name = "cs2-tearing", match = { title = "^Counter-Strike 2$" }, immediate = true })   -- window class is the flatpak id, so match on title

hl.layer_rule({ match = { namespace = "^waybar$" },        blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^rofi$" },          blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^notifications$" }, blur = true, ignore_alpha = 0.2 })
