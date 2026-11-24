#!/usr/bin/env python3
"""Pick two accent colours from a wallpaper for the desktop theme (2026-11-25).

usage: palette.py IMAGE OUT_BASENAME      writes OUT_BASENAME.lua and OUT_BASENAME.json
Accents keep the picture's hue but are pushed to a lightness/saturation that reads on the
Dracula background (#282a36); the rest of the palette stays Dracula.
"""
import colorsys, json, sys
from PIL import Image

DRACULA = ("bd93f9", "ff79c6")           # fallback: purple, pink

def hexs(r, g, b): return "%02x%02x%02x" % (int(r * 255 + .5), int(g * 255 + .5), int(b * 255 + .5))
def tone(h, l, s): return hexs(*colorsys.hls_to_rgb(h, l, s))
def hue_dist(a, b): d = abs(a - b) % 1.0; return min(d, 1.0 - d)

def pick(path):
    im = Image.open(path).convert("RGB")
    im.thumbnail((320, 320))
    q = im.quantize(colors=32, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()[:96]
    counts = {idx: n for n, idx in q.getcolors(maxcolors=256)}
    total = sum(counts.values())
    cands, loose = [], []
    for idx, n in counts.items():
        r, g, b = (pal[idx * 3 + k] / 255 for k in range(3))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        chroma = s * (1.0 - abs(2 * l - 1.0))         # how coloured it actually looks (0 for black/white/grey)
        weight = (n / total) ** 0.3                   # area, strongly compressed: a small vivid patch can win
        if chroma >= 0.10 and 0.08 <= l <= 0.92:
            cands.append((weight * (0.3 + chroma * 2.0), h, l, s))
        elif chroma >= 0.04:
            loose.append((chroma * weight, h, l, s))  # near-monochrome pictures: take their faint tint
    cands.sort(reverse=True); loose.sort(reverse=True)
    if not cands:
        cands = loose
    if not cands:
        return None
    _, h1, l1, s1 = cands[0]
    h2 = None
    for _, h, l, s in cands[1:]:
        if hue_dist(h, h1) > 0.12:                    # > 43 degrees apart
            h2 = h; break
    if h2 is None:
        h2 = (h1 + 0.11) % 1.0                        # analogous shift when the picture is monochrome
    return h1, h2

def main():
    src, out = sys.argv[1], sys.argv[2]
    r = pick(src)
    if r is None:
        accent, accent2 = DRACULA
        h1 = h2 = None
    else:
        h1, h2 = r
        accent  = tone(h1, 0.70, 0.85)                # vivid, light enough for 2px borders on dark
        accent2 = tone(h2, 0.68, 0.80)
    dim    = tone(h1, 0.32, 0.35) if h1 is not None else "44475a"
    pal = {"accent": accent, "accent2": accent2, "dim": dim, "source": src}
    with open(out + ".json", "w") as f: json.dump(pal, f)
    with open(out + ".lua", "w") as f:
        f.write("return { accent = %r, accent2 = %r, dim = %r }\n" % (accent, accent2, dim))
    print(accent, accent2, dim)

if __name__ == "__main__":
    main()
