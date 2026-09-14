#!/usr/bin/env python3
"""H1 (2026-09-13): the House map game's two stage icons — a HAMMER (the piece to collect) and a
GLASS CASE WITH A KEY IN IT (the mark), plus the case CRACKED (shown 0.4 s on the win).

    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_map_icons.py

Writes game/assets/textures/level_2_house/house_map_{hammer,case,case_broken}_icon.png — 1024²
RGBA, BLACK ink on transparency (maze_chase_ui.gd:_make_icon modulates the ink dark over a
coloured disc, so the art must be ink + alpha and nothing else). Pillow only, deterministic:
icons are glyphs and no diffusion model can be asked for an exact one (make_arrow_decal.py).
The ink fills ~70 % of the canvas — the old icons filled ~35 % and rendered as scribble (Issue 32).
"""

import os
from PIL import Image, ImageDraw

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "textures", "level_2_house"))
S = 1024
INK = (0, 0, 0, 255)


def hammer():
    """A claw hammer, UPRIGHT (2026-09-13 redraw — the first, rotated version read as a blob
    at the ~28 px the overlay gives it): a wide head across the top with a squared striking
    face on the left and a forked claw on the right, and a long straight handle down the
    middle with a flared grip. Every part is an axis-aligned block, which is what survives
    a 36x downscale."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Head bar.
    d.rounded_rectangle([(150, 150), (760, 400)], radius=40, fill=INK)
    # Striking face: a slightly taller block on the left end.
    d.rounded_rectangle([(120, 120), (300, 430)], radius=30, fill=INK)
    # Claw: two prongs curving down-right from the right end, split by a notch.
    d.polygon([(760, 150), (960, 120), (990, 300), (900, 470), (840, 420), (890, 300), (760, 400)], fill=INK)
    d.polygon([(890, 300), (960, 290), (900, 470), (840, 420)], fill=(0, 0, 0, 0))
    # Handle: straight down from the head's centre, with a flared grip at the bottom.
    d.rectangle([(400, 380), (520, 880)], fill=INK)
    d.rounded_rectangle([(380, 780), (540, 930)], radius=40, fill=INK)
    return im


def key():
    """The KEY, on its own — it lies in the glass room now (H1b, 2026-09-13)."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = 330, 512
    d.ellipse([(cx - 250, cy - 250), (cx + 250, cy + 250)], outline=INK, width=110)
    d.rectangle([(cx + 200, cy - 70), (960, cy + 70)], fill=INK)
    d.rectangle([(760, cy + 60), (840, cy + 240)], fill=INK)
    d.rectangle([(880, cy + 60), (960, cy + 190)], fill=INK)
    return im


def case(cracked=False):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # The case: a thick rectangular frame with a base plinth.
    d.rounded_rectangle([(150, 90), (874, 800)], radius=40, outline=INK, width=54)
    d.rectangle([(110, 800), (914, 900)], fill=INK)
    # Glass "shine": two thin diagonals in the top-left.
    d.line([(230, 330), (410, 150)], fill=INK, width=18)
    d.line([(230, 440), (520, 150)], fill=INK, width=12)
    # The key inside: bow (ring), shaft, two teeth. Big and unmistakable.
    cx, cy = 512, 470
    d.ellipse([(cx - 300, cy - 150), (cx - 40, cy + 110)], outline=INK, width=60)
    d.rectangle([(cx - 60, cy - 50), (cx + 320, cy + 30)], fill=INK)
    d.rectangle([(cx + 200, cy + 30), (cx + 260, cy + 130)], fill=INK)
    d.rectangle([(cx + 290, cy + 30), (cx + 340, cy + 100)], fill=INK)
    if cracked:
        # A crack web from a point of impact on the glass.
        px, py = 700, 250
        for ang, ln in [(20, 420), (75, 380), (130, 300), (190, 360), (250, 320), (300, 260), (340, 200)]:
            import math
            ex = px + math.cos(math.radians(ang)) * ln
            ey = py + math.sin(math.radians(ang)) * ln
            d.line([(px, py), (ex, ey)], fill=INK, width=22)
            mx, my = px + (ex - px) * 0.55, py + (ey - py) * 0.55
            d.line([(mx, my), (mx + math.cos(math.radians(ang + 60)) * 90, my + math.sin(math.radians(ang + 60)) * 90)], fill=INK, width=14)
        d.ellipse([(px - 40, py - 40), (px + 40, py + 40)], fill=INK)
    return im


def main():
    hammer().save(os.path.join(OUT, "house_map_hammer_icon.png"))
    key().save(os.path.join(OUT, "house_map_key_icon.png"))
    case().save(os.path.join(OUT, "house_map_case_icon.png"))
    case(True).save(os.path.join(OUT, "house_map_case_broken_icon.png"))
    for n in ["house_map_hammer_icon", "house_map_key_icon", "house_map_case_icon", "house_map_case_broken_icon"]:
        im = Image.open(os.path.join(OUT, n + ".png"))
        a = im.getchannel("A")
        cov = sum(1 for v in a.getdata() if v > 0) / float(S * S)
        print("%s  ink coverage %.1f %%" % (n, cov * 100))


if __name__ == "__main__":
    main()
