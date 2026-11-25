# Waybar music module body (2026-11-25); run by music.sh with cava on stdin. See music.sh.
import sys, json, subprocess, time, html, os
sys.stdout.reconfigure(write_through=True)
BARS = "▁▂▃▄▅▆▇█"
ANNOUNCE, FADE_IN, FADE_OUT = 4.0, 0.35, 0.9          # seconds the title stays, and its fades
PAUSE = "<span font_family=\"JetBrainsMono Nerd Font Propo\" size=\"large\" rise=\"-1pt\">\uf04c</span>"
_fmt = {}
def probe(url):
    path = url[7:] if url.startswith("file://") else url
    from urllib.parse import unquote; path = unquote(path)
    if path in _fmt: return _fmt[path]
    detail = ""
    try:
        out = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
            "stream=codec_name,codec_type,sample_rate,channels,bits_per_raw_sample,bits_per_sample:format=bit_rate",
            "-of", "json", path], capture_output=True, text=True, timeout=5).stdout
        d = json.loads(out); a = next(s for s in d["streams"] if s.get("codec_type") == "audio")
        codec = a.get("codec_name", ""); sr = int(a.get("sample_rate", 0)); ch = int(a.get("channels", 0))
        bits = int(a.get("bits_per_raw_sample") or a.get("bits_per_sample") or 0)
        kbps = int(d.get("format", {}).get("bit_rate", 0)) // 1000
        chs = {1: "mono", 2: "stereo"}.get(ch, f"{ch} ch")
        if codec.startswith("dsd"):
            rate = sr * 8; detail = f"DSD{round(rate / 44100)} · {rate / 1e6:.2f} MHz · 1-bit · {chs}"
        else:
            name = {"flac": "FLAC", "alac": "ALAC", "mp3": "MP3", "aac": "AAC", "vorbis": "Vorbis", "opus": "Opus",
                    "pcm_s16le": "WAV", "pcm_s24le": "WAV", "wavpack": "WavPack", "ape": "APE"}.get(codec, codec.upper())
            depth = f"{bits}-bit / " if bits else ""
            khz = f"{sr / 1000:g} kHz" if sr else ""
            detail = f"{name} · {depth}{khz} · {chs}"
            if kbps and codec in ("mp3", "aac", "vorbis", "opus"): detail += f" · {kbps} kbps"
    except Exception:
        pass
    _fmt[path] = detail; return detail
def mmss(us):
    s = int(max(0, us) // 1_000_000); return f"{s // 60}:{s % 60:02d}"
def sink_of_deadbeef():
    try:
        out = subprocess.run(["pactl", "list", "sink-inputs"], capture_output=True, text=True, timeout=2).stdout
        idx = None
        for ln in out.splitlines():
            ln = ln.strip()
            if ln.startswith("Sink:"): idx = ln.split()[1]
            if "application.name = \"Deadbeef\"" in ln: break
        else:
            idx = None
        if idx is None: return None
        for ln in subprocess.run(["pactl", "list", "sinks", "short"], capture_output=True, text=True, timeout=2).stdout.splitlines():
            f = ln.split("\t")
            if f[0] == idx: return f[1]
    except Exception:
        pass
    return None
def player():
    """-> dict(status, artist, title, album, pos, length, url) or None when DeaDBeeF is not running"""
    if subprocess.run(["pgrep", "-x", "deadbeef-main"], capture_output=True).returncode != 0: return None
    try:
        out = subprocess.run(["playerctl", "-p", "DeaDBeeF", "metadata", "--format",
            "{{status}};;{{artist}};;{{title}};;{{album}};;{{position}};;{{mpris:length}};;{{xesam:url}}"],
            capture_output=True, text=True, timeout=2).stdout.strip()
        f = out.split(";;")
        if len(f) < 7: return None
        return dict(status=f[0], artist=f[1], title=f[2], album=f[3], pos=float(f[4] or 0), length=float(f[5] or 0), url=f[6])
    except Exception:
        return None
STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-music.announced")   # last announced track
def remember(key):
    try:
        with open(STATE, "w") as f: f.write(key or "")
    except OSError:
        pass
def remembered():
    try:
        with open(STATE) as f: return f.read() or None
    except OSError:
        return None
st, last_key, shown_at, next_poll = None, remembered(), 0.0, 0.0   # a restart (watchdog, sink change) must not re-announce
print(json.dumps({"text": BARS[0] * 12, "class": "silent", "tooltip": ""}), flush=True)   # never leave the island empty
my_sink, next_sink_check = os.environ.get("MUSIC_SINK", ""), time.monotonic() + 10
quiet_since, resumed_at = None, 0.0                          # playing but all-zero bars: the capture stream died
was_playing = False
for line in sys.stdin:
    vals = [int(v) for v in line.strip().split(";") if v]
    if not vals: continue
    now = time.monotonic()
    if now >= next_sink_check:                              # DeaDBeeF moved to another output? restart on it
        next_sink_check = now + 10
        cur = sink_of_deadbeef()
        if cur and my_sink and cur != my_sink: sys.exit(0)
    if now >= next_poll:
        next_poll = now + 1.0
        st = player()
        playing = bool(st) and st["status"] == "Playing"
        if playing and not was_playing: resumed_at = now    # pause -> play: an AirPlay sink may have dropped our stream
        was_playing = playing
        key = st and st["status"] == "Playing" and (st["url"] or st["title"])
        if key and key != last_key: shown_at = now; remember(key)   # new track while playing -> announce it
        if key: last_key = key                              # keep the last track over pauses: resume is not a new track
    bars = "".join(BARS[min(v, 7)] for v in vals)
    loud = max(vals) > 0
    if st and st["status"] == "Playing" and not loud:
        quiet_since = quiet_since or now
        limit = 1.0 if now - resumed_at < 4.0 else 3.0        # right after a resume, give up fast
        if now - quiet_since > limit: sys.exit(0)              # let Waybar restart us on a fresh stream
    else:
        quiet_since = None
    out = {"text": bars, "class": "playing" if loud else "silent", "tooltip": ""}
    if st and st["status"] in ("Playing", "Paused"):
        line1 = (st["artist"] + " – " + st["title"]) if st["artist"] else st["title"]
        tip = [html.escape(line1)]
        if st["album"]: tip.append(html.escape(st["album"]))
        fmt = probe(st["url"]) if st["url"] else ""
        if fmt: tip.append(html.escape(fmt))
        if st["length"]: tip.append(mmss(st["pos"]) + " / " + mmss(st["length"]))
        out["tooltip"] = "\n".join(tip)
        if st["status"] == "Paused":
            out["text"] = PAUSE + "  " + bars; out["class"] = "paused"
        else:
            age = now - shown_at
            if age < ANNOUNCE:
                a = min(1.0, age / FADE_IN) if age < FADE_IN else (min(1.0, (ANNOUNCE - age) / FADE_OUT) if age > ANNOUNCE - FADE_OUT else 1.0)
                out["text"] = bars + "   <span font_family=\"Inter\" alpha=\"%d%%\">%s</span>" % (max(1, int(a * 100)), html.escape(line1))
                out["class"] = "announce"
    try:
        print(json.dumps(out), flush=True)
    except BrokenPipeError:
        break
