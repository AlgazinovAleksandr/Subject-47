#!/usr/bin/env python3
"""H2 (2026-09-13): bake the House's THIRD safe digit onto the fridge head's forehead.

    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_head_digit.py

Reads game/assets/textures/level_2_house/house_fridge_thing.png (the RGBA head cutout) and writes
house_fridge_thing_digit.png with a dark, smeared "7" across the forehead — drawn as several
offset strokes so it reads as written in something, not typeset. The source is untouched
(house_fridge.gd falls back to it if the digit file is missing). The digit is the Bedroom note's
old one: the code stays 472.
"""

import os
from PIL import Image, ImageDraw, ImageFilter

DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "textures", "level_2_house"))
SRC = os.path.join(DIR, "house_fridge_thing.png")
OUT = os.path.join(DIR, "house_fridge_thing_digit.png")
DIGIT = "7"


def main():
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # A "7": a top bar and a diagonal, on the forehead (the face's forehead sits at ~22-40 % of
    # the height in this cutout), as thick smeared strokes.
    cx, top = w * 0.50, h * 0.235
    dw, dh = w * 0.16, h * 0.13
    ink = (78, 10, 12, 235)
    for ox, oy in [(0, 0), (6, 4), (-5, 3), (3, -5)]:
        d.line([(cx - dw / 2 + ox, top + oy), (cx + dw / 2 + ox, top + 6 + oy)], fill=ink, width=int(w * 0.022))
        d.line([(cx + dw / 2 + ox, top + 6 + oy), (cx - dw * 0.15 + ox, top + dh + oy)], fill=ink, width=int(w * 0.022))
    # A drip off the diagonal's foot.
    d.line([(cx - dw * 0.15, top + dh), (cx - dw * 0.17, top + dh * 1.35)], fill=(70, 8, 10, 200), width=int(w * 0.012))
    layer = layer.filter(ImageFilter.GaussianBlur(1.2))
    # Only where the head is (never over transparent canvas).
    mask = im.getchannel("A").point(lambda v: 255 if v > 30 else 0)
    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", (w, h), 0), mask))
    out = Image.alpha_composite(im, layer)
    out.save(OUT)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
