#!/usr/bin/env python3
"""B1 (2026-09-13, capture #13): the Backrooms' mirage doors as OLD-HOUSE YELLOWED PANEL DOORS.

    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_backrooms_door.py

Writes game/assets/textures/level_backrooms/backrooms_door_yellow.png: a six-panel door leaf,
nicotine-yellow paint over grime, drawn with Pillow (deterministic, seeded noise) and cropped to
the LEAF — no architrave, no wall, so it can hang on a quad sized from its own aspect (Issue 35's
rule: a picture of a wall must never be hung on a wall). Portrait 640 x 1344 (0.476), i.e. a
1.0 m wide leaf is 2.1 m tall — MirageDoor.SIZE.
"""

import os
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "textures", "level_backrooms", "backrooms_door_yellow.png"))
W, H = 640, 1344


def main():
    rng = random.Random(4141)
    base = (196, 172, 96)
    im = Image.new("RGB", (W, H), base)
    px = im.load()
    # Grime + paint mottle.
    for y in range(H):
        for x in range(W):
            n = rng.uniform(-14, 10)
            g = -22 * (y / H) ** 2                     # darker toward the floor
            r, gg, b = base
            px[x, y] = (max(0, min(255, int(r + n + g))), max(0, min(255, int(gg + n * 0.9 + g))), max(0, min(255, int(b + n * 0.5 + g * 0.7))))
    im = im.filter(ImageFilter.GaussianBlur(1.0))
    d = ImageDraw.Draw(im)
    # Six recessed panels: bevel = a dark edge on top/left, a light edge bottom/right (inset).
    margin, gap = 62, 44
    pw = (W - 2 * margin - gap) // 2
    ph_top, ph_mid, ph_bot = 300, 300, 330
    ys = [(margin, margin + ph_top), (margin + ph_top + gap, margin + ph_top + gap + ph_mid),
          (margin + ph_top + gap + ph_mid + gap, margin + ph_top + gap + ph_mid + gap + ph_bot)]
    for (y0, y1) in ys:
        for col in range(2):
            x0 = margin + col * (pw + gap)
            x1 = x0 + pw
            for i in range(14):
                shade = 150 - i * 6
                d.rectangle([(x0 + i, y0 + i), (x1 - i, y1 - i)], outline=(shade, shade - 18, shade - 60))
            d.rectangle([(x0 + 14, y0 + 14), (x1 - 14, y1 - 14)], fill=(184, 160, 88))
            d.line([(x0 + 14, y1 - 14), (x1 - 14, y1 - 14)], fill=(228, 206, 128), width=4)
            d.line([(x1 - 14, y0 + 14), (x1 - 14, y1 - 14)], fill=(228, 206, 128), width=4)
    # Brass knob + escutcheon on the right stile.
    kx, ky = W - 78, H // 2 + 20
    d.ellipse([(kx - 30, ky - 30), (kx + 30, ky + 30)], fill=(120, 96, 40), outline=(60, 44, 14), width=3)
    d.ellipse([(kx - 18, ky - 18), (kx + 18, ky + 18)], fill=(150, 124, 58))
    d.rectangle([(kx - 12, ky + 50), (kx + 12, ky + 110)], fill=(90, 70, 30))
    d.ellipse([(kx - 6, ky + 60), (kx + 6, ky + 72)], fill=(20, 16, 8))
    # Scuffs and a water stain near the floor.
    for _ in range(140):
        x, y = rng.randint(0, W - 1), rng.randint(H - 380, H - 1)
        d.ellipse([(x - 3, y - 1), (x + 3, y + 1)], fill=(120, 100, 52))
    st = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(st)
    sd.ellipse([(60, H - 300), (W - 60, H + 80)], fill=(70, 50, 20, 70))
    st = st.filter(ImageFilter.GaussianBlur(30))
    im = Image.alpha_composite(im.convert("RGBA"), st).convert("RGB")
    # Grade darker: near-white is the brightest paint this renderer has (Issue 63).
    im = im.point(lambda v: int(v * 0.72))
    im.save(OUT)
    lum = sum(im.convert("L").getdata()) / float(W * H)
    print("wrote", OUT, im.size, "mean luma %.1f" % lum)


if __name__ == "__main__":
    main()
