#!/usr/bin/env python3
"""C4 (2026-09-14): `wet_footprint.png` — one bare wet footprint (dark, translucent) for the
corridor's 'evidence behind you' trail, and `blind_map.png` — the blind room's one-glimpse plan.
Pillow, deterministic.
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_footprints.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "textures", "level_3_corridor"))


def footprint():
    # 122 x 256 = the 0.2 x 0.42 m quad in corridor.gd (check_art_aspect measures it; a square
    # source on that quad was a 2.1x squash). x coordinates are the old 256-square's, scaled.
    W, H = 122, 256
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ink = (70, 78, 88, 200)   # wet, a little blue, so it reads on the dark carpet
    sx = W / 256.0
    def X(v): return int(round((v - 128) * sx + W / 2.0))
    d.ellipse([(X(78), 96), (X(178), 236)], fill=ink)             # sole
    d.ellipse([(X(88), 150), (X(172), 246)], fill=ink)            # heel blend
    for cx, cy, r in [(96, 78, 14), (120, 62, 15), (144, 60, 14), (166, 70, 12), (184, 88, 10)]:
        rx = max(4, int(r * sx))
        d.ellipse([(X(cx) - rx, cy - r), (X(cx) + rx, cy + r)], fill=ink)
    im = im.filter(ImageFilter.GaussianBlur(2))
    im.save(os.path.join(OUT, "wet_footprint.png"))
    print("wet_footprint.png")


def blind_map():
    S = 512
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    paper = (210, 200, 170, 235)
    d.rectangle([(20, 20), (492, 492)], fill=paper)
    ink = (40, 30, 20, 255)
    d.rectangle([(90, 90), (422, 422)], outline=ink, width=8)        # the room
    d.rectangle([(226, 414), (286, 430)], fill=paper)                  # the door gap (south)
    d.line([(226, 422), (286, 422)], fill=(120, 20, 20, 255), width=6)
    d.ellipse([(96, 96), (136, 136)], fill=(150, 20, 20, 255))         # the lever: NW corner
    try:
        f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 26)
    except Exception:
        f = ImageFont.load_default()
    d.text((150, 100), "RELEASE", font=f, fill=ink)
    d.text((196, 436), "YOU ARE HERE", font=f, fill=ink)
    im.save(os.path.join(OUT, "blind_map.png"))
    print("blind_map.png")


if __name__ == "__main__":
    footprint()
    blind_map()
