#!/usr/bin/env python3
"""DeaDBeeF now-playing overlay (2026-11-25): a spinning record whose label is the cover art,
tonearm tracking the position, title / artist / album, and the real stream format
(DSD64 · 2.82 MHz · 1-bit, or FLAC · 24-bit / 96 kHz ...). GTK3 + gtk-layer-shell, bottom-right.

Pops up for HOLD seconds when a track starts, on pause / resume, or on demand (SIGUSR1: SUPER+SHIFT+M or a click on
the bar's music island), then fades away; moving the pointer over it keeps it. Hides at once when DeaDBeeF stops or quits.
SIGUSR1 while it is up dismisses it. Click: play/pause. Scroll: next / previous track.

  now-playing.py                   run the overlay
  now-playing.py --preview OUT.png render one frame with a sample track, no window
"""
import glob, hashlib, json, math, os, re, signal, subprocess, sys, time, warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gtk, Gdk, GLib, Pango, PangoCairo  # noqa: E402
import cairo  # noqa: E402

HOME   = os.path.expanduser("~")
CACHE  = os.path.join(HOME, ".cache", "now-playing")
ACCENT_CSS = os.path.join(HOME, ".config", "waybar", "accent.css")
SEP = ";;"                          # deadbeef turns tabs into "_" and eats < >, so use a plain multi-char separator
TF = SEP.join(("%isplaying%", "%ispaused%", "%artist%", "%title%", "%album%", "%path%", "%playback_time_seconds%", "%length_seconds%"))
PAD = 22                             # transparent margin that holds the shadow
W, H = 500 + 2 * PAD, 176 + 2 * PAD
DISC_C, DISC_R = (92 + PAD, 88 + PAD), 72
RPM = 100 / 3                       # 33⅓
HOLD = 7.0                      # seconds the card stays up after a trigger (hover keeps it)
DRACULA = dict(bg=(0x28/255, 0x2a/255, 0x36/255), fg=(0xf8/255, 0xf8/255, 0xf2/255),
               dim=(0x62/255, 0x72/255, 0xa4/255), accent=(0xbd/255, 0x93/255, 0xf9/255),
               accent2=(0xff/255, 0x79/255, 0xc6/255))
os.makedirs(CACHE, exist_ok=True)


def hexrgb(h): return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def read_accents():
    try:
        with open(ACCENT_CSS) as f:
            s = f.read()
        a = re.search(r"accent #([0-9a-f]{6})", s); b = re.search(r"accent2 #([0-9a-f]{6})", s)
        return hexrgb(a.group(1)) if a else DRACULA["accent"], hexrgb(b.group(1)) if b else DRACULA["accent2"]
    except OSError:
        return DRACULA["accent"], DRACULA["accent2"]


def deadbeef_running():
    return subprocess.run(["pgrep", "-x", "deadbeef-main"], capture_output=True).returncode == 0


def query():
    """-> dict(state, artist, title, album, path, pos, length) or None when nothing is loaded."""
    if not deadbeef_running():
        return None
    try:
        out = subprocess.run(["deadbeef", "--nowplaying-tf", TF], capture_output=True, text=True, timeout=2).stdout
    except (subprocess.TimeoutExpired, OSError):
        return None
    parts = out.rstrip("\n").split(SEP)
    if len(parts) < 8 or not parts[5]:
        return None
    # MPRIS is the reliable source for play/pause; the tf flags only say whether a track is loaded
    try:
        mp = subprocess.run(["playerctl", "-p", "DeaDBeeF", "status"], capture_output=True, text=True, timeout=2).stdout.strip()
    except (subprocess.TimeoutExpired, OSError):
        mp = ""
    if mp in ("Playing", "Paused", "Stopped"):
        state = mp.lower()
    else:
        playing, paused = parts[0] == "1", parts[1] == "1"
        state = "paused" if paused else ("playing" if playing else "stopped")
    def num(x):
        try: return float(x)
        except ValueError: return 0.0
    return dict(state=state, artist=parts[2], title=parts[3], album=parts[4], path=parts[5],
                pos=num(parts[6]), length=num(parts[7]))


_fmt_cache = {}
def probe_format(path):
    """ffprobe -> (short label, detail line) e.g. ('DSD64', 'DSD64 · 2.82 MHz · 1-bit · stereo')."""
    if path in _fmt_cache:
        return _fmt_cache[path]
    label, detail = "", ""
    try:
        out = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                              "stream=codec_name,codec_type,sample_rate,channels,bits_per_raw_sample,bits_per_sample:format=bit_rate",
                              "-of", "json", path], capture_output=True, text=True, timeout=5).stdout
        d = json.loads(out)
        a = next(s for s in d["streams"] if s.get("codec_type") == "audio")
        codec = a.get("codec_name", "")
        sr = int(a.get("sample_rate", 0)); ch = int(a.get("channels", 0))
        bits = int(a.get("bits_per_raw_sample") or a.get("bits_per_sample") or 0)
        kbps = int(d.get("format", {}).get("bit_rate", 0)) // 1000
        chs = {1: "mono", 2: "stereo"}.get(ch, f"{ch} ch")
        if codec.startswith("dsd"):
            rate = sr * 8                                  # ffprobe reports the packed byte rate
            n = round(rate / 44100)
            label = f"DSD{n}"
            detail = f"DSD{n} · {rate / 1e6:.2f} MHz · 1-bit · {chs}"
        else:
            name = {"flac": "FLAC", "alac": "ALAC", "mp3": "MP3", "aac": "AAC", "vorbis": "Vorbis", "opus": "Opus",
                    "pcm_s16le": "WAV", "pcm_s24le": "WAV", "wavpack": "WavPack", "ape": "APE"}.get(codec, codec.upper())
            label = name
            depth = f"{bits}-bit / " if bits else ""
            khz = f"{sr / 1000:g} kHz" if sr else ""
            detail = f"{name} · {depth}{khz} · {chs}"
            if kbps and codec in ("mp3", "aac", "vorbis", "opus"):
                detail += f" · {kbps} kbps"
    except Exception:
        pass
    _fmt_cache[path] = (label, detail)
    return label, detail


_cover_cache = {}
def find_cover(path, album, artist):
    """Folder art first, then the picture embedded in the file, then DeaDBeeF's own cache."""
    d = os.path.dirname(path)
    if d in _cover_cache:
        return _cover_cache[d]
    found = None
    for pat in ("*cover*", "*front*", "*folder*", "*"):
        hits = [f for e in ("jpg", "jpeg", "png") for f in glob.glob(os.path.join(d, f"{pat}.{e}"))]
        hits += [f for e in ("JPG", "PNG") for f in glob.glob(os.path.join(d, f"{pat}.{e}"))]
        if hits:
            found = sorted(hits)[0]; break
    if not found:
        out = os.path.join(CACHE, hashlib.md5(d.encode()).hexdigest() + ".jpg")
        if not os.path.exists(out):
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-an", "-c:v", "mjpeg", "-vframes", "1", out],
                           capture_output=True, timeout=10)
        if os.path.exists(out) and os.path.getsize(out) > 0:
            found = out
    if not found:
        key = f"{album} - {artist}".lower()
        for f in glob.glob(os.path.join(HOME, ".cache", "deadbeef", "covers2", "*")):
            if key and key in os.path.basename(f).lower():
                found = f; break
    _cover_cache[d] = found
    return found


def load_cover_surface(path, size):
    """Cover as a square cairo surface of `size` px, centre-cropped; None if unreadable."""
    try:
        from gi.repository import GdkPixbuf
        pb = GdkPixbuf.Pixbuf.new_from_file(path)
        w, h = pb.get_width(), pb.get_height()
        s = min(w, h)
        pb = pb.new_subpixbuf((w - s) // 2, (h - s) // 2, s, s).scale_simple(size, size, 2)  # 2 = BILINEAR
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
        cr = cairo.Context(surf)
        Gdk.cairo_set_source_pixbuf(cr, pb, 0, 0); cr.paint()
        return surf
    except Exception:
        return None


def rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def text(cr, s, x, y, size, rgb, bold=False, mono=False, max_w=None, alpha=1.0):
    layout = PangoCairo.create_layout(cr)
    fd = Pango.FontDescription(f"{'JetBrainsMono Nerd Font' if mono else 'Inter'} {'Bold ' if bold else ''}{size}")
    layout.set_font_description(fd)
    layout.set_text(s, -1)
    if max_w:
        layout.set_width(int(max_w * Pango.SCALE)); layout.set_ellipsize(Pango.EllipsizeMode.END)
    cr.set_source_rgba(*rgb, alpha); cr.move_to(x, y); PangoCairo.show_layout(cr, layout)
    return layout.get_pixel_size()[1]


def fmt_time(s):
    s = int(max(0, s)); return f"{s // 60}:{s % 60:02d}"


def draw(cr, st, angle, accent, accent2, cover):
    bg, fg, dim = DRACULA["bg"], DRACULA["fg"], DRACULA["dim"]
    # soft shadow, then the glass card with a hairline accent edge and an inner highlight
    cw, ch = W - 2 * PAD, H - 2 * PAD
    for i in range(10, 0, -1):
        rounded_rect(cr, PAD - i, PAD - i + 6, cw + 2 * i, ch + 2 * i, 12 + i)
        cr.set_source_rgba(0, 0, 0, 0.045); cr.fill()
    rounded_rect(cr, PAD + 0.5, PAD + 0.5, cw - 1, ch - 1, 12)
    cr.set_source_rgba(*bg, 0.80); cr.fill_preserve()
    cr.set_source_rgba(*accent, 0.35); cr.set_line_width(1); cr.stroke()
    rounded_rect(cr, PAD + 1.5, PAD + 1.5, cw - 3, ch - 3, 11)
    cr.set_source_rgba(1, 1, 1, 0.05); cr.set_line_width(1); cr.stroke()
    cx, cy = DISC_C
    # platter shadow
    g = cairo.RadialGradient(cx, cy, DISC_R - 4, cx, cy, DISC_R + 10)
    g.add_color_stop_rgba(0, 0, 0, 0, 0.45); g.add_color_stop_rgba(1, 0, 0, 0, 0)
    cr.set_source(g); cr.arc(cx, cy, DISC_R + 10, 0, 2 * math.pi); cr.fill()
    # record
    cr.save(); cr.translate(cx, cy); cr.rotate(angle)
    g = cairo.RadialGradient(-DISC_R * 0.4, -DISC_R * 0.4, 4, 0, 0, DISC_R)
    g.add_color_stop_rgb(0, 0.16, 0.16, 0.18); g.add_color_stop_rgb(1, 0.05, 0.05, 0.06)
    cr.set_source(g); cr.arc(0, 0, DISC_R, 0, 2 * math.pi); cr.fill()
    cr.set_line_width(0.8)
    for r in range(30, DISC_R - 3, 3):                       # grooves
        cr.set_source_rgba(1, 1, 1, 0.045 if r % 2 else 0.08)
        cr.arc(0, 0, r, 0, 2 * math.pi); cr.stroke()
    # light sheen across the grooves
    g = cairo.LinearGradient(-DISC_R, -DISC_R, DISC_R, DISC_R)
    for p, a in ((0.0, 0), (0.35, 0.0), (0.45, 0.07), (0.5, 0.0), (1.0, 0)):
        g.add_color_stop_rgba(p, 1, 1, 1, a)
    cr.set_source(g); cr.arc(0, 0, DISC_R, 0, 2 * math.pi); cr.fill()
    # label = cover
    LR = 27
    cr.save(); cr.arc(0, 0, LR, 0, 2 * math.pi); cr.clip()
    if cover is not None:
        cr.set_source_surface(cover, -LR, -LR); cr.paint()
    else:
        cr.set_source_rgb(*accent); cr.paint()
        cr.set_source_rgba(*bg, 0.9); cr.arc(0, 0, LR * 0.55, 0, 2 * math.pi); cr.set_line_width(2); cr.stroke()
    cr.restore()
    cr.set_source_rgba(*accent, 0.9); cr.set_line_width(1.2); cr.arc(0, 0, LR, 0, 2 * math.pi); cr.stroke()
    cr.set_source_rgb(0.02, 0.02, 0.02); cr.arc(0, 0, 2.8, 0, 2 * math.pi); cr.fill()
    cr.restore()
    # tonearm: pivot top-right of the platter, needle walks inward with the track position
    prog = (st["pos"] / st["length"]) if st and st.get("length") else 0.0
    px, py = cx + DISC_R + 10, cy - DISC_R - 2
    nr = (DISC_R - 4) - prog * ((DISC_R - 4) - 31)
    na = math.radians(-50)
    nx, ny = cx + nr * math.cos(na), cy + nr * math.sin(na)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    cr.set_source_rgba(0, 0, 0, 0.35); cr.set_line_width(5); cr.move_to(px + 1, py + 2); cr.line_to(nx + 1, ny + 2); cr.stroke()
    cr.set_source_rgb(0.78, 0.78, 0.80); cr.set_line_width(3.2); cr.move_to(px, py); cr.line_to(nx, ny); cr.stroke()
    cr.set_source_rgb(0.55, 0.55, 0.58); cr.arc(px, py, 6, 0, 2 * math.pi); cr.fill()
    cr.set_source_rgb(*accent); cr.arc(nx, ny, 2.6, 0, 2 * math.pi); cr.fill()
    # text block
    x0, maxw = 186 + PAD, W - 186 - 16 - 2 * PAD
    if st:
        y = 22 + PAD
        y += text(cr, st["title"] or os.path.basename(st["path"]), x0, y, 13.5, fg, bold=True, max_w=maxw) + 3
        y += text(cr, st["artist"], x0, y, 12, accent, max_w=maxw) + 1
        y += text(cr, st["album"], x0, y, 11, dim, max_w=maxw) + 10
        label, detail = probe_format(st["path"])
        y += text(cr, detail, x0, y, 9.5, accent2, mono=True, max_w=maxw) + 10
        # progress
        cr.set_source_rgba(*dim, 0.35); rounded_rect(cr, x0, y + 2, maxw, 3, 1.5); cr.fill()
        if prog > 0:
            cr.set_source_rgb(*accent); rounded_rect(cr, x0, y + 2, max(3, maxw * prog), 3, 1.5); cr.fill()
        text(cr, f"{fmt_time(st['pos'])} / {fmt_time(st['length'])}", x0, y + 10, 9.5, dim, mono=True)
        icon = "" if st["state"] == "playing" else ""
        text(cr, icon, W - PAD - 34, y + 7, 11, accent2, mono=True)
    else:
        text(cr, "DeaDBeeF", x0, 60 + PAD, 13, dim, bold=True)
        text(cr, "nothing playing", x0, 82 + PAD, 11, dim)


class Overlay(Gtk.Window):
    def __init__(self):
        super().__init__(title="now-playing")
        self.set_app_paintable(True)
        self.set_visual(self.get_screen().get_rgba_visual())
        self.set_default_size(W, H); self.set_size_request(W, H)
        gi.require_version("GtkLayerShell", "0.1")
        from gi.repository import GtkLayerShell
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "now-playing")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        edges = [GtkLayerShell.Edge.BOTTOM]
        if os.environ.get("NOWPLAYING_ANCHOR", "right") != "center":
            edges.append(GtkLayerShell.Edge.RIGHT)           # default: bottom-right corner
        for edge in edges:
            GtkLayerShell.set_anchor(self, edge, True)
            GtkLayerShell.set_margin(self, edge, 18 - PAD + 4)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        self.area = Gtk.DrawingArea(); self.add(self.area)
        self.area.connect("draw", self.on_draw)
        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.POINTER_MOTION_MASK)
        self.connect("motion-notify-event", lambda *_: self.touch())   # pointer over the card keeps it (enter/leave fire spuriously on map)
        self.connect("button-press-event", lambda *_: self.cmd("--toggle-pause"))
        self.connect("scroll-event", self.on_scroll)
        self.st, self.angle, self.last_t = None, 0.0, time.monotonic()
        self.speed = 0.0            # current angular velocity (rad/s); eases towards 33 1/3 rpm or 0
        self.fade = None
        self.cover, self.cover_dir = None, None
        self.accent, self.accent2 = read_accents()
        self.hide_at = 0.0          # monotonic time the card fades out (re-armed by every trigger and by hover)
        self.visible = False
        self.anim = None
        GLib.timeout_add(1000, self.poll); self.poll()
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, self.toggle)

    def cmd(self, arg):
        if deadbeef_running():
            subprocess.Popen(["deadbeef", arg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    def on_scroll(self, _w, ev):
        self.cmd("--next" if ev.direction == Gdk.ScrollDirection.DOWN else "--prev"); return True

    def toggle(self):
        if self.visible: self.hide_card()
        else: self.show_for()
        return True

    def touch(self):
        self.hide_at = max(self.hide_at, time.monotonic() + 3.0)   # every pointer move over the card buys 3 s
        return False

    def show_for(self, seconds=HOLD):
        """Show (or keep showing) the card and arm the auto-dismiss."""
        if not (self.st and self.st["state"] in ("playing", "paused")): return
        self.hide_at = time.monotonic() + seconds
        if not self.visible:
            self.visible = True
            self.set_opacity(0.0); self.show_all(); self.start_fade(1.0)
        self.ensure_anim()

    def hide_card(self):
        if self.visible:
            self.visible = False
            self.start_fade(0.0)
        self.ensure_anim()

    def start_fade(self, target):
        self.fade_target, self.fade_t0 = target, time.monotonic()
        self.fade_from = self.get_opacity()
        if self.fade is None:
            self.fade = GLib.timeout_add(16, self.fade_step)

    def fade_step(self):
        k = min(1.0, (time.monotonic() - self.fade_t0) / 0.28)
        k = 1 - (1 - k) ** 3                                     # ease-out cubic
        self.set_opacity(self.fade_from + (self.fade_target - self.fade_from) * k)
        if k >= 1.0:
            self.fade = None
            if self.fade_target == 0.0 and not self.visible:
                self.hide()
            return False
        return True

    def ensure_anim(self):
        playing = self.visible and self.st and self.st["state"] == "playing"
        want = playing or self.speed > 0.02
        if want and self.anim is None:
            self.last_t = time.monotonic()
            self.anim = GLib.timeout_add(33, self.tick)

    def tick(self):
        now = time.monotonic(); dt = now - self.last_t; self.last_t = now
        target = 2 * math.pi * RPM / 60 if (self.st and self.st["state"] == "playing" and self.visible) else 0.0
        rate = 2.2 if target > 0 else 1.1                        # spin-up ~1 s, spin-down ~2.5 s
        self.speed += (target - self.speed) * min(1.0, dt * rate)
        self.angle = (self.angle + self.speed * dt) % (2 * math.pi)
        self.area.queue_draw()
        if target == 0.0 and self.speed < 0.02:
            self.speed = 0.0; self.anim = None
            return False
        return True

    def poll(self):
        st = query()
        trigger = False
        if st and (self.st is None or st["path"] != self.st["path"]):
            trigger = True                                       # new track
            d = os.path.dirname(st["path"])
            if d != self.cover_dir:
                c = find_cover(st["path"], st["album"], st["artist"])
                self.cover = load_cover_surface(c, 54) if c else None
                self.cover_dir = d
            probe_format(st["path"])
        elif st and self.st and st["state"] != self.st["state"]:
            trigger = True                                       # pause / resume
        self.st = st
        self.accent, self.accent2 = read_accents()
        if not (st and st["state"] in ("playing", "paused")):
            self.hide_card()                                     # stopped or gone: no card
        elif trigger:
            self.show_for()
        elif self.visible and time.monotonic() >= self.hide_at:
            self.hide_card()
        if os.environ.get("NOWPLAYING_DEBUG"):
            print(f"poll t={time.monotonic():.1f} vis={self.visible} hide_at={self.hide_at:.1f} trig={trigger} st={st and st['state']} op={self.get_opacity():.2f}", file=sys.stderr, flush=True)
        if self.visible:
            self.area.queue_draw()
        return True

    def on_draw(self, _w, cr):
        cr.set_operator(cairo.OPERATOR_SOURCE); cr.set_source_rgba(0, 0, 0, 0); cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        draw(cr, self.st, self.angle, self.accent, self.accent2, self.cover)
        return True


def preview(out):
    sample = glob.glob(os.path.join(HOME, "archive/Music/*/*.dsf"))
    path = sorted(sample)[0] if sample else ""
    st = dict(state="playing", artist="The Alan Parsons Project", title="Time", album="The Turn of a Friendly Card",
              path=path, pos=97.0, length=304.4)
    cover = None
    if path:
        c = find_cover(path, st["album"], st["artist"]); cover = load_cover_surface(c, 54) if c else None
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    cr = cairo.Context(surf)
    a, b = read_accents()
    draw(cr, st, 0.6, a, b, cover)
    surf.write_to_png(out); print("wrote", out, "format:", probe_format(path)[1] if path else "-")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--preview":
        preview(sys.argv[2]); sys.exit(0)
    win = Overlay()
    win.connect("destroy", Gtk.main_quit)
    Gtk.main()
