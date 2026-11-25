#!/usr/bin/env python3
"""Keybind cheatsheet (2026-11-25): SUPER+I toggles a glass sheet of every bind, grouped, drawn from
`hyprctl binds -j`. The descriptions come from hyprland.lua's K(key, action, "group · what") calls, so the
sheet can never drift from the config. Type to filter, Esc (or SUPER+I again) closes."""
import json, os, re, signal, subprocess, sys, warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
import gi
gi.require_version("Gtk", "3.0"); gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell  # noqa: E402

HOME = os.path.expanduser("~")
ORDER = ["launch", "windows", "focus", "workspaces", "layout", "looks", "session", "clipboard", "screenshots", "media", "monitors", "mouse"]
COLUMNS = 4
MODS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]
KEYS = {"Return": "Enter", "space": "Space", "equal": "=", "minus": "−", "Escape": "Esc", "Tab": "Tab", "Print": "PrtSc",
        "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "mouse:272": "LMB", "mouse:273": "RMB",
        "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑", "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
        "XF86AudioMute": "Mute", "XF86AudioMicMute": "Mic mute", "XF86AudioPlay": "Play", "XF86AudioNext": "Next", "XF86AudioPrev": "Prev"}

def accent():
    try:
        s = open(os.path.join(HOME, ".config/waybar/accent.css")).read()
        m = re.search(r"accent #([0-9a-f]{6})", s); return "#" + m.group(1) if m else "#bd93f9"
    except OSError:
        return "#bd93f9"

def chips(b):
    out = [name for bit, name in MODS if b["modmask"] & bit]
    k = b["key"]; out.append(KEYS.get(k, k.upper() if len(k) == 1 else k)); return out

def load():
    raw = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True).stdout)
    groups = {}
    for b in raw:
        if not b.get("has_description") or " · " not in b["description"] or b.get("submap"): continue
        g, d = b["description"].split(" · ", 1)
        groups.setdefault(g, []).append((chips(b), d))
    # fold "go to 1" … "go to 9" into one row, and merge rows that mean the same thing (two keys for one action)
    for g, rows in groups.items():
        folded, seen = [], {}
        for keys, d in rows:
            m = re.fullmatch(r"(.*\D)(\d)", d)
            fam = (tuple(keys[:-1]), m.group(1)) if m and keys[-1].isdigit() else None
            if fam:
                if fam in seen: seen[fam][2].append(keys[-1]); continue
                seen[fam] = [keys[:-1], m.group(1), [keys[-1]]]; folded.append(seen[fam]); continue
            for row in folded:
                if row[1] == d and not isinstance(row[2], list):
                    row[0] = row[0] + ["/"] + keys; break
            else:
                folded.append([keys, d, None])
        groups[g] = [((k + [f"{n[0]}…{n[-1]}"], d + f"{n[0]}–{n[-1]}") if n else (k, d)) for k, d, n in folded]
    return [(g, groups[g]) for g in ORDER if g in groups] + [(g, r) for g, r in groups.items() if g not in ORDER]

CSS = """
window { background: transparent; }
.card { background: rgba(40,42,54,0.80); border: 1px solid alpha(ACCENT, 0.32); border-radius: 12px;
        padding: 22px 30px 26px 30px; box-shadow: 0 10px 34px rgba(0,0,0,0.45); }
.title { color: #f8f8f2; font-family: Inter; font-size: 15pt; font-weight: 600; }
.hint  { color: #6272a4; font-family: Inter; font-size: 10pt; }
.search { background: alpha(#f8f8f2, 0.06); border: 1px solid alpha(#f8f8f2, 0.10); border-radius: 8px; color: #f8f8f2;
          font-family: Inter; font-size: 11pt; padding: 4px 12px; min-height: 0; caret-color: ACCENT; }
.search:focus { border-color: alpha(ACCENT, 0.6); }
.group { color: ACCENT; font-family: Inter; font-size: 9.5pt; font-weight: 600; letter-spacing: 1.5px; margin-top: 6px; }
.key  { background: alpha(#f8f8f2, 0.08); border: 1px solid alpha(#f8f8f2, 0.11); border-radius: 6px; padding: 1px 7px;
        color: #f8f8f2; font-family: "JetBrainsMono Nerd Font"; font-size: 9.5pt; }
.plus { color: #6272a4; font-family: Inter; font-size: 9pt; }
.desc { color: alpha(#f8f8f2, 0.88); font-family: Inter; font-size: 11pt; }
"""

class Sheet(Gtk.Window):
    def __init__(self):
        super().__init__(title="cheatsheet")
        GtkLayerShell.init_for_window(self); GtkLayerShell.set_namespace(self, "cheatsheet")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        self.set_app_paintable(True); self.set_visual(self.get_screen().get_rgba_visual())
        prov = Gtk.CssProvider(); prov.load_from_data(CSS.replace("ACCENT", accent()).encode())
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, margin=30); self.add(outer)
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14); card.get_style_context().add_class("card"); outer.pack_start(card, False, False, 0)
        head = Gtk.Box(spacing=16); card.pack_start(head, False, False, 0)
        t = Gtk.Label(label="deus-orion  ·  keys", xalign=0); t.get_style_context().add_class("title"); head.pack_start(t, False, False, 0)
        self.search = Gtk.Entry(placeholder_text="type to filter", width_chars=28); self.search.get_style_context().add_class("search")
        self.search.connect("changed", self.filter); head.pack_end(self.search, False, False, 0)
        hint = Gtk.Label(label="Esc closes  ·  Super+I toggles"); hint.get_style_context().add_class("hint"); head.pack_end(hint, False, False, 12)
        cols = Gtk.Box(spacing=44); card.pack_start(cols, True, True, 0)
        boxes = [Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4) for _ in range(COLUMNS)]
        for b in boxes: cols.pack_start(b, True, True, 0)
        fill = [0] * COLUMNS; self.rows = []; self.groups = []
        for g, rows in load():
            i = fill.index(min(fill)); fill[i] += len(rows) + 2
            gl = Gtk.Label(label=g.upper(), xalign=0); gl.get_style_context().add_class("group")
            grid = Gtk.Grid(column_spacing=14, row_spacing=3); boxes[i].pack_start(gl, False, False, 0); boxes[i].pack_start(grid, False, False, 0)
            self.groups.append((gl, grid, []))
            for r, (keys, d) in enumerate(rows):
                kb = Gtk.Box(spacing=3)
                for j, k in enumerate(keys):
                    if k == "/": s = Gtk.Label(label=" / "); s.get_style_context().add_class("plus"); kb.pack_start(s, False, False, 0); continue
                    if j and keys[j - 1] != "/": p = Gtk.Label(label="+"); p.get_style_context().add_class("plus"); kb.pack_start(p, False, False, 0)
                    c = Gtk.Label(label=k); c.get_style_context().add_class("key"); kb.pack_start(c, False, False, 0)
                dl = Gtk.Label(label=d, xalign=0); dl.get_style_context().add_class("desc")
                grid.attach(kb, 0, r, 1, 1); grid.attach(dl, 1, r, 1, 1)
                self.groups[-1][2].append((kb, dl, (" ".join(keys) + " " + d).lower()))
        self.connect("key-press-event", self.on_key); self.connect("destroy", Gtk.main_quit)
        self.show_all(); self.set_opacity(0.0); self.fade(0.0, 1.0)
    def fade(self, a, b, step=0):
        n = 8; self.set_opacity(a + (b - a) * step / n)
        if step < n: GLib.timeout_add(14, self.fade, a, b, step + 1); return False
        if b == 0.0: Gtk.main_quit()
        return False
    def filter(self, entry):
        q = entry.get_text().strip().lower()
        for gl, grid, rows in self.groups:
            any_ = False
            for kb, dl, text in rows:
                ok = (not q) or all(w in text for w in q.split()); kb.set_visible(ok); dl.set_visible(ok); any_ |= ok
            gl.set_visible(any_); grid.set_visible(any_)
    def on_key(self, _w, ev):
        if ev.keyval == Gdk.KEY_Escape: self.fade(1.0, 0.0); return True
        return False

if __name__ == "__main__":
    me = os.getpid()
    others = [int(p) for p in subprocess.run(["pgrep", "-f", "cheatsheet\\.py$"], capture_output=True, text=True).stdout.split() if int(p) != me]
    if others:                                   # SUPER+I while open: close it
        for p in others: os.kill(p, signal.SIGTERM)
        sys.exit(0)
    sheet = Sheet()
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda *_: (sheet.fade(1.0, 0.0), False)[1])   # toggle-off fades too
    Gtk.main()
