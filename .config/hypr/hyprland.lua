-- Hyprland (Lua config, 0.57+) for deus-orion
-- Ported from ~/.config/awesome/rc.lua on 2026-11-24. Docs: https://wiki.hypr.land/configuring/
-- Reload: SUPER+CTRL+R (or `hyprctl reload`). Verify: `Hyprland --verify-config`

require("env")

------------------
---- MONITORS ----
------------------
-- Single 34" ultrawide (DisplayPort-2 under X11). Same mode as under awesome; FreeSync on.
-- Check connector names with: hyprctl monitors
hl.monitor({ output = "DP-3", mode = "3440x1440@175", position = "0x0", scale = 1, vrr = 1 })   -- Odyssey G85SB OLED: 175 Hz max; pinned at 0x0 so an extra panel never shifts it
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })                 -- anything unknown: preferred mode, placed to the right
-- Auxiliary 1080p panel to the right (HDMI-A-1): normally serves the Mac, so it stays OFF unless asked. SUPER+CTRL+P runs
-- aux-display.sh toggle, which keeps the wish in ~/.cache/hypr-aux-on and calls aux_display(true|false): portrait beside
-- the ultrawide (transform 3 = 270°, the way the stand holds it), 8-bit, no VRR — the panel's safest link.
-- The panel re-announces itself every few minutes and Hyprland re-applies the registered rule on every hotplug, so the
-- rule itself follows the state file, and monitor.added re-applies it too.
local AUX = "HDMI-A-1"
local AUX_STATE = os.getenv("HOME") .. "/.cache/hypr-aux-on"
local AUX_ON = { output = AUX, disabled = false, mode = "preferred", position = "3440x-240", scale = 1, transform = 3, bitdepth = 8, vrr = 0 }   -- 1080x1920, centred on the ultrawide
local function aux_wanted() local f = io.open(AUX_STATE); if f then f:close(); return true end; return false end
if aux_wanted() then hl.monitor(AUX_ON) else hl.monitor({ output = AUX, disabled = true }) end
function aux_display(on)             -- global: `hyprctl dispatch 'function() aux_display(true) end'` works too
    if on then hl.monitor(AUX_ON) else hl.monitor({ output = AUX, disabled = true }) end
    hl.exec_cmd("notify-send -t 1500 -a Hyprland '" .. (on and "aux display: portrait" or "aux display: off") .. "'")
end
hl.on("monitor.added", function() if aux_wanted() then hl.monitor(AUX_ON) end end)   -- hotplug re-check: keep it as asked

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
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh init")   -- per-workspace wallpapers (awww) + wallpaper-derived accents
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("gnome-keyring-daemon --daemonize --login")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/openrgb-single --startminimized")
    hl.exec_cmd("msm_notifier")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/now-playing.py")   -- DeaDBeeF vinyl overlay (shows itself while playing)
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
        rounding = 12,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = true, range = 28, render_power = 2, color = 0x66000000, color_inactive = 0x44000000, offset = { 0, 8 } },
        blur   = { enabled = true, size = 10, passes = 3, vibrancy = 0.22, noise = 0.012, contrast = 0.92, brightness = 0.88, popups = true },
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
hl.animation({ leaf = "windows",    enabled = true, speed = 3.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "quick",        style = "popin 87%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2.4, bezier = "quick" })
hl.animation({ leaf = "border",     enabled = true, speed = 4.5, bezier = "easeOutQuint" })   -- border colour glides with the wallpaper crossfade (0.45 s)
hl.animation({ leaf = "layers",     enabled = true, speed = 2.6, bezier = "easeOutQuint", style = "popin 94%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.6, bezier = "easeOutQuint", style = "slidefade 18%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "easeOutQuint", style = "slidefadevert 15%" })

--------------------
---- WORKSPACES ----
--------------------
-- Each workspace has its own wallpaper (crossfade on switch) and the window borders take that
-- wallpaper's colours. wallpaper.sh computes a palette per picture (palette.py) into
-- ~/.cache/hypr-wallpapers/palette/<file>.lua; it is read here, so the borders change in the same
-- frame as the workspace, before the picture even starts fading. The gradient angle turns with
-- the workspace number. The other apps (waybar, kitty, rofi, mako, hyprlock) get the same accents
-- from wallpaper.sh through small include files.
local STATE   = os.getenv("HOME") .. "/.cache/hypr-wallpapers"
local DRACULA = { accent = "bd93f9", accent2 = "ff79c6", dim = "44475a" }
local accent_follows_wallpaper = true
local current_ws = 1
do  -- on a config reload we may not be on workspace 1; wallpaper.sh records the active one
    -- (hyprctl cannot be called from here: the compositor is busy loading this file)
    local f = io.open(os.getenv("HOME") .. "/.cache/hypr-wallpapers/active-ws", "r")
    if f then
        local id = tonumber(f:read("*l")); f:close()
        if id and id > 0 then current_ws = id end
    end
end

local function workspace_palette(id)
    local f = io.open(STATE .. "/ws-" .. tostring(id), "r")
    if not f then return DRACULA end
    local img = f:read("*l"); f:close()
    local name = img and img:match("[^/]+$")
    if not name then return DRACULA end
    local ok, pal = pcall(dofile, STATE .. "/palette/" .. name .. ".lua")
    if ok and type(pal) == "table" and pal.accent then return pal end
    return DRACULA
end

local function apply_accent(id)
    local p = accent_follows_wallpaper and workspace_palette(id) or DRACULA
    local angle = ((id - 1) * 45) % 360
    hl.config({ general = { col = {
        active_border   = { colors = { "rgba(" .. p.accent .. "ee)", "rgba(" .. p.accent2 .. "ee)" }, angle = angle },
        inactive_border = "rgba(" .. p.dim .. "aa)",
    } } })
end

-- late at night unfocused windows dim a little; checked whenever the workspace changes
local function apply_time_of_day()
    local h = tonumber(os.date("%H"))
    local night = (h >= 22 or h < 7)
    hl.config({ decoration = { inactive_opacity = night and 0.94 or 1.0, dim_inactive = night, dim_strength = 0.10 } })
end

hl.on("workspace.active", function(ws)
    if not ws or ws.special then return end
    local id = ws.id
    if id and id > 0 then current_ws = id; apply_accent(id); apply_time_of_day() end
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh set " .. (id and tostring(id) or ""))
end)
apply_time_of_day()
apply_accent(current_ws)   -- at login we start on workspace 1; after a reload the next switch re-applies
-- wallpaper.sh calls this after a reroll/shuffle so the borders follow the new picture without a workspace switch:
--   hyprctl dispatch 'function() reapply_accent() end'
function reapply_accent() apply_accent(current_ws) end
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
-- K(key, action, "group · what it does" [, opts]): hl.bind with a description. `hyprctl binds -j` carries the
-- description, and cheatsheet.py (SUPER+I) draws the sheet from it, so this file is the only source of truth.
local function K(key, action, desc, opts)
    opts = opts or {}
    opts.description = desc
    hl.bind(key, action, opts)
end

-- launchers
K(M .. " + Return", hl.dsp.exec_cmd(terminal), "launch · terminal")
K(M .. " + SHIFT + Return", hl.dsp.exec_cmd("foot"), "launch · fallback terminal (foot)")           -- fallback terminal (no GPU buffers)
K(M .. " + X", hl.dsp.exec_cmd(menu), "launch · app menu")
K(M .. " + R", hl.dsp.exec_cmd(run), "launch · run a command")
K(M .. " + Q", hl.dsp.exec_cmd(browser), "launch · browser")
K(M .. " + A", hl.dsp.exec_cmd(editor), "launch · editor")
K(M .. " + E", hl.dsp.exec_cmd(files), "launch · files")
-- Spotlight-style: apps + windows + files in one box; SUPER+= calculator; SUPER+SHIFT+E rofi file browser
K(M .. " + space", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/rofi/spotlight.sh"), "launch · Spotlight: apps, windows, files")
K(M .. " + equal", hl.dsp.exec_cmd("rofi -show calc -modes calc -no-show-match -no-sort -calc-command 'echo -n \"{result}\" | wl-copy' -theme ~/.config/rofi/dracula.rasi"), "launch · calculator")
K(M .. " + SHIFT + E", hl.dsp.exec_cmd("rofi -show filebrowser -theme ~/.config/rofi/dracula.rasi"), "launch · file browser")
K(M .. " + Z", hl.dsp.workspace.toggle_special("quake"), "launch · dropdown terminal")
K(M .. " + Escape", hl.dsp.focus({ workspace = "previous" }), "workspaces · back to previous")       -- awesome: tag history "go back"
K(A .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"), "session · lock screen")                  -- awesome: lock screen
K(M .. " + W", hl.dsp.exec_cmd("rofi -show drun"), "launch · app menu (plain)")             -- awesome: main menu
K(M .. " + I", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/cheatsheet.py"), "session · this cheatsheet")  -- awesome: show help
K(M .. " + SHIFT + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh reroll"), "looks · new wallpaper here")   -- new picture for this workspace
K(M .. " + CTRL + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh shuffle"), "looks · reshuffle all wallpapers")  -- reshuffle all workspaces
K(M .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p clip | cliphist decode | wl-copy"), "clipboard · history")

-- session
K(M .. " + SHIFT + Q", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/rofi/power.sh"), "session · power menu")   -- power menu (lock / suspend / logout / reboot / shutdown)
K(M .. " + CTRL + R", function()
    hl.dispatch(hl.dsp.reload_config())
    hl.exec_cmd("notify-send -t 2000 -a Hyprland 'config reloaded'")
end, "session · reload config")
K(M .. " + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"), "looks · toggle bar")   -- toggle bar
K(M .. " + CTRL + I", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/input-rescan.sh 0"), "session · re-detect input devices")  -- re-detect keyboards/mice

-- windows
K(M .. " + SHIFT + C", hl.dsp.window.close(), "windows · close")
K(M .. " + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }), "windows · fullscreen")
K(M .. " + M", hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }), "windows · maximise")
K(M .. " + CTRL + space", hl.dsp.window.float({ action = "toggle" }), "windows · float / tile")
K(M .. " + T", hl.dsp.window.pin(), "windows · pin on every workspace")
K(M .. " + U", hl.dsp.focus({ urgent_or_last = true }), "windows · urgent or last")
-- "minimize": park in a special workspace, SUPER+CTRL+N brings it back
K(M .. " + N", hl.dsp.window.move({ workspace = "special:minimized" }), "windows · minimise")
K(M .. " + CTRL + N", hl.dsp.workspace.toggle_special("minimized"), "windows · show minimised")

-- focus (vim keys, as in awesome)
K(M .. " + H", hl.dsp.focus({ direction = "left" }), "focus · left")
K(M .. " + L", hl.dsp.focus({ direction = "right" }), "focus · right")
K(M .. " + K", hl.dsp.focus({ direction = "up" }), "focus · up")
K(M .. " + J", hl.dsp.focus({ direction = "down" }), "focus · down")
K(A .. " + J", hl.dsp.window.cycle_next(), "focus · next window")
K(A .. " + K", hl.dsp.window.cycle_next({ next = false }), "focus · previous window")
K(M .. " + Tab", hl.dsp.focus({ last = true }), "focus · last focused")             -- awesome: focus history previous
K(M .. " + SHIFT + Tab", hl.dsp.window.cycle_next(), "focus · cycle windows")                -- awesome: go forth
-- tags: SUPER+Left/Right all workspaces, ALT+Left/Right only non-empty ones
K(M .. " + Left", hl.dsp.focus({ workspace = "m-1" }), "workspaces · previous")
K(M .. " + Right", hl.dsp.focus({ workspace = "m+1" }), "workspaces · next")
K(A .. " + Left", hl.dsp.focus({ workspace = "e-1" }), "workspaces · previous non-empty")
K(A .. " + Right", hl.dsp.focus({ workspace = "e+1" }), "workspaces · next non-empty")
-- dynamic tags: SUPER+SHIFT+N new (empty) workspace, SUPER+SHIFT+R rename current one
K(M .. " + SHIFT + N", hl.dsp.focus({ workspace = "empty" }), "workspaces · new empty")
K(M .. " + SHIFT + R", hl.dsp.exec_cmd([[sh -c 'n=$(rofi -dmenu -p "rename workspace" -lines 0) && [ -n "$n" ] && hyprctl dispatch "hl.dsp.workspace.rename({ workspace = $(hyprctl activeworkspace -j | jq .id), name = \"$n\" })"']]), "workspaces · rename")
-- magnify (ALT+SHIFT+M in awesome): float + centre the window
K(A .. " + SHIFT + M", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.center())
end, "windows · magnify (float + centre)")

-- move / swap (master layout)
K(M .. " + SHIFT + J", hl.dsp.window.swap({ next = true }), "layout · swap with next")
K(M .. " + SHIFT + K", hl.dsp.window.swap({ prev = true }), "layout · swap with previous")
K(M .. " + CTRL + Return", hl.dsp.layout("swapwithmaster"), "layout · swap with master")
K(M .. " + SHIFT + H", hl.dsp.layout("addmaster"), "layout · add master")
K(M .. " + SHIFT + L", hl.dsp.layout("removemaster"), "layout · remove master")
K(M .. " + SHIFT + space", hl.dsp.layout("orientationnext"), "layout · next orientation")     -- (SUPER+space is now the Spotlight launcher)
-- master width factor (ALT+SHIFT+H/L in awesome)
K(A .. " + SHIFT + L", hl.dsp.layout("mfact +0.05"), "layout · master wider")
K(A .. " + SHIFT + H", hl.dsp.layout("mfact -0.05"), "layout · master narrower")
-- generic resize of the focused window
K(M .. " + " .. A .. " + L", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), "layout · grow right", { repeating = true })
K(M .. " + " .. A .. " + H", hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), "layout · grow left", { repeating = true })
K(M .. " + " .. A .. " + K", hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), "layout · grow up", { repeating = true })
K(M .. " + " .. A .. " + J", hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), "layout · grow down", { repeating = true })

-- gaps (ALT+CTRL +/- in awesome)
local gaps = 6
local function set_gaps(delta)
    gaps = math.max(0, gaps + delta)
    hl.config({ general = { gaps_in = gaps, gaps_out = gaps * 2 } })
end
K(A .. " + CTRL + equal", function() set_gaps(2) end, "layout · gaps bigger")
K(A .. " + CTRL + minus", function() set_gaps(-2) end, "layout · gaps smaller")

-- focus mode (SUPER+SHIFT+F): no gaps, square corners, thin borders, bar hidden; same key restores
local focus_mode = false
function toggle_focus_mode()   -- global: `hyprctl dispatch 'function() toggle_focus_mode() end'` works too
    focus_mode = not focus_mode
    if focus_mode then
        hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 1 },
                    decoration = { rounding = 0, shadow = { enabled = false } } })
    else
        hl.config({ general = { gaps_in = gaps, gaps_out = gaps * 2, border_size = 2 },
                    decoration = { rounding = 12, shadow = { enabled = true } } })
    end
    hl.exec_cmd("pkill -SIGUSR1 waybar")
    hl.exec_cmd("notify-send -t 1500 -a Hyprland '" .. (focus_mode and "focus mode" or "focus mode off") .. "'")
end
K(M .. " + SHIFT + F", toggle_focus_mode, "looks · focus mode")

-- SUPER+SHIFT+M: show/hide the DeaDBeeF vinyl overlay (it appears on its own while music plays)
K(M .. " + SHIFT + M", hl.dsp.exec_cmd("pkill -USR1 -f now-playing.py"), "looks · record overlay")

-- From the awesome config: a workspace with a single tiled window gets no border.
-- Hyprland has no built-in rule for this, but the Lua API lets us count windows on every change.
local function lone_window_borders(win)
    local ws = win and win.workspace
    if not ws or ws.special then return end
    local n = tonumber(ws.windows) or 0
    if win.floating then n = 2 end                       -- a floating window always keeps its edge
    hl.config({ general = { border_size = (n <= 1 and not focus_mode) and 0 or (focus_mode and 1 or 2) } })
end
for _, ev in ipairs({ "window.open", "window.close", "window.move_to_workspace", "window.active" }) do
    hl.on(ev, function(win) pcall(lone_window_borders, win) end)
end

-- SUPER+SHIFT+P: accents follow the wallpaper (default) <-> plain Dracula everywhere
function toggle_accent_source()   -- global, like toggle_focus_mode
    accent_follows_wallpaper = not accent_follows_wallpaper
    apply_accent(current_ws)
    if accent_follows_wallpaper then
        hl.exec_cmd("sh -c 'rm -f " .. STATE .. "/accent-current; " .. os.getenv("HOME") .. "/.config/hypr/wallpaper.sh set'")
    else
        hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/wallpaper.sh accent-reset")
    end
    hl.exec_cmd("notify-send -t 1500 -a Hyprland '" .. (accent_follows_wallpaper and "accents: wallpaper" or "accents: Dracula") .. "'")
end
K(M .. " + SHIFT + P", toggle_accent_source, "looks · accents: wallpaper / Dracula")

-- multi-monitor
K(M .. " + CTRL + J", hl.dsp.focus({ monitor = "+1" }), "monitors · focus next")
K(M .. " + CTRL + K", hl.dsp.focus({ monitor = "-1" }), "monitors · focus previous")
K(M .. " + O", hl.dsp.window.move({ monitor = "+1" }), "monitors · move window to next")
K(M .. " + CTRL + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/aux-display.sh toggle"), "monitors · aux display: portrait / off")

-- workspaces 1-9 (SUPER+N view, SUPER+SHIFT+N move window)
for i = 1, 9 do
    K(M .. " + " .. i, hl.dsp.focus({ workspace = i }), "workspaces · go to " .. i)
    K(M .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), "workspaces · move window to " .. i)
end
K(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "workspaces · scroll next")
K(M .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "workspaces · scroll previous")

-- mouse
K(M .. " + mouse:272", hl.dsp.window.drag(), "mouse · drag window", { mouse = true })
K(M .. " + mouse:273", hl.dsp.window.resize(), "mouse · resize window", { mouse = true })

-- clipboard bridge (SUPER+C / SUPER+V in awesome: primary <-> clipboard)
K(M .. " + C", hl.dsp.exec_cmd("sh -c 'wl-paste -p -n | wl-copy'"), "clipboard · primary → clipboard")
K(M .. " + V", hl.dsp.exec_cmd("sh -c 'wl-paste -n | wl-copy -p'"), "clipboard · clipboard → primary")

-- screenshots
K("Print", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"), "screenshots · screen → clipboard")
-- awesome ALT+P ran /usr/local/bin/screenshot (scrot -> ~/screenshots/<timestamp>.png)
K(A .. " + P", hl.dsp.exec_cmd("sh -c 'hyprshot -m output -o ~/Pictures/Screenshots -f $(date +%Y%m%d%H%M%S).png'"), "screenshots · screen → file")
K("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m region"), "screenshots · region")
K(M .. " + Print", hl.dsp.exec_cmd("hyprshot -m window"), "screenshots · window")

-- volume (PulseAudio / pipewire-pulse via pactl)
K("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +2%"), "media · volume up", { locked = true, repeating = true })
K("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -2%"), "media · volume down", { locked = true, repeating = true })
K("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), "media · mute", { locked = true })
K("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), "media · mic mute", { locked = true })
K(A .. " + CTRL + M", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ 100%"), "media · volume 100 %")
K(A .. " + CTRL + A", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/audio-cycle.sh next"), "media · next audio output", { locked = true })
K(A .. " + CTRL + SHIFT + A", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/audio-cycle.sh prev"), "media · previous audio output", { locked = true })
-- media (mpc in awesome; playerctl covers mpd and browsers)
K(A .. " + CTRL + Up", hl.dsp.exec_cmd("playerctl play-pause"), "media · play / pause", { locked = true })
K(A .. " + CTRL + Down", hl.dsp.exec_cmd("playerctl stop"), "media · stop", { locked = true })
K(A .. " + CTRL + Left", hl.dsp.exec_cmd("playerctl previous"), "media · previous", { locked = true })
K(A .. " + CTRL + Right", hl.dsp.exec_cmd("playerctl next"), "media · next", { locked = true })
K("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "media · play / pause", { locked = true })
K("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "media · next", { locked = true })
K("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "media · previous", { locked = true })

----------------------
---- WINDOW RULES ----
----------------------
-- awesome rules: Brave -> web, Emacs -> dev
hl.window_rule({ name = "brave-web",  match = { class = "^([Bb]rave-browser|Brave)$" }, workspace = 2 })
hl.window_rule({ name = "emacs-dev",  match = { class = "^([Ee]macs)$" },               workspace = 3 })
hl.window_rule({ name = "take-term", match = { class = "^take-term$" }, float = true, size = "1180 560", center = true })   -- clip stage
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
hl.layer_rule({ match = { namespace = "^now-playing$" },   blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^cheatsheet$" },    blur = true, ignore_alpha = 0.2 })
