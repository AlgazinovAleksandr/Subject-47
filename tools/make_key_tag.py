#!/usr/bin/env python3
"""C4 (2026-09-15): the brass room-key fob for the Corridor's reception bell beat.

Ring the bell, the lights die, and when they come back a key with THIS tag lies beside the
bell — the only 217 in the level that opens anything. Pillow, deterministic (a number has to be
legible at arm's length, so it is drawn, never generated). Run with the image pack's venv:

    "$PACK/.venv/bin/python3" tools/make_key_tag.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os, random

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "textures",
                   "level_3_corridor", "key_tag_217.png")
W, H = 512, 320
random.seed(217)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# a worn brass oval fob with a hole at the left end
brass = (150, 112, 48, 255)
d.ellipse([8, 8, W - 8, H - 8], fill=brass, outline=(60, 42, 14, 255), width=6)
# grime: dark speckle, mostly near the rim
for _ in range(2600):
    x, y = random.randint(10, W - 10), random.randint(10, H - 10)
    cx, cy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
    if cx * cx + cy * cy < 1.0 and random.random() < 0.35 + 0.6 * (cx * cx + cy * cy):
        g = random.randint(40, 90)
        d.point((x, y), fill=(g, int(g * 0.75), int(g * 0.35), 255))
img = img.filter(ImageFilter.GaussianBlur(0.6))
d = ImageDraw.Draw(img)
d.ellipse([28, H / 2 - 22, 72, H / 2 + 22], fill=(0, 0, 0, 0), outline=(50, 34, 10, 255), width=5)

def font(size):
    for p in ["/System/Library/Fonts/Supplemental/Copperplate.ttc", "/System/Library/Fonts/Supplemental/Georgia.ttf",
              "/System/Library/Fonts/Supplemental/Times New Roman.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

# engraved number: a dark stamp with a faint highlight below-right, the way struck brass reads
big = font(150)
tw = d.textlength("217", font=big)
x0 = 100 + (W - 100 - tw) / 2
d.text((x0 + 3, 70 + 3), "217", font=big, fill=(190, 160, 95, 255))
d.text((x0, 70), "217", font=big, fill=(38, 24, 6, 255))
small = font(30)
tw2 = d.textlength("HOTEL VESPER", font=small)
d.text((100 + (W - 100 - tw2) / 2, 236), "HOTEL VESPER", font=small, fill=(52, 34, 10, 255))
img.save(OUT)
print("wrote", os.path.relpath(OUT), img.size)
