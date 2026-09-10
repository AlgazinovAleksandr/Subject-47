#!/usr/bin/env python3
"""KONTUR Recovery Archive, lot 14-D: the brass room plate "217" (2026-09-10, capture #13).

The lot used to be a flat brass-tinted box with a `Label3D` reading 217 in front of it. This
draws the plate as an image: a flux-generated blank engraved brass plate
(`assets_src/textures/level_5_kontur/archive_brass_plate_raw.jpg`, graded by
`tools/grade_ritual_textures.py` into `game/assets/textures/level_5_kontur/archive_brass_plate.png`)
with the number ENGRAVED by Pillow — dark serif digits with a thin highlight edge below, so
the glyphs read as cut into the metal rather than printed on it. Pillow because the digits
ARE the payload (the level's first legible 217 is on the Corridor's false door, the second is
this plate), and flux cannot be trusted with a numeral.

Deterministic. Needs Pillow:
    $PACK/.venv/bin/python3 tools/make_archive_plate.py
then `Godot --headless --path game --import`.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "game", "assets", "textures", "level_5_kontur", "archive_brass_plate.png")
OUT = os.path.join(ROOT, "game", "assets", "textures", "level_5_kontur", "archive_plate_217.png")
FONT = "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf"
FALLBACK_FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def main() -> None:
    base = Image.open(SRC).convert("RGB")
    # The plate is landscape on the lot (0.26 x 0.14 m); crop the square source to 13:7.
    w, h = base.size
    th = int(w * 7 / 13)
    base = base.crop((0, (h - th) // 2, w, (h - th) // 2 + th))
    w, h = base.size

    font_path = FONT if os.path.exists(FONT) else FALLBACK_FONT
    font = ImageFont.truetype(font_path, int(h * 0.62))
    text = "217"
    bbox = font.getbbox(text)
    tw, tht = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (w - tw) // 2 - bbox[0]
    y = (h - tht) // 2 - bbox[1]

    # Engraving: a soft dark cut, a hard dark core, and a one-pixel light lip below-right.
    cut = Image.new("L", (w, h), 0)
    ImageDraw.Draw(cut).text((x, y), text, font=font, fill=255)
    soft = cut.filter(ImageFilter.GaussianBlur(h * 0.012))
    out = base.copy()
    dark = Image.new("RGB", (w, h), (28, 20, 10))
    out = Image.composite(dark, out, soft.point(lambda v: int(v * 0.55)))
    out = Image.composite(Image.new("RGB", (w, h), (18, 13, 7)), out, cut)
    lip = Image.new("L", (w, h), 0)
    ImageDraw.Draw(lip).text((x + max(2, h // 120), y + max(2, h // 120)), text, font=font, fill=255)
    lip = Image.composite(Image.new("L", (w, h), 0), lip, cut)   # only where the core is NOT
    out = Image.composite(Image.new("RGB", (w, h), (214, 186, 120)), out, lip.point(lambda v: int(v * 0.8)))

    # Tarnish streaks so it is not a clean render.
    streak = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(streak)
    for i in range(7):
        sx = int(w * (0.08 + i * 0.13))
        sd.line([(sx, 0), (sx + int(w * 0.03), h)], fill=60, width=int(w * 0.02))
    streak = streak.filter(ImageFilter.GaussianBlur(w * 0.03))
    out = Image.composite(Image.new("RGB", (w, h), (40, 32, 18)), out, streak)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT, "PNG", optimize=True)
    print("wrote %s (%dx%d)" % (os.path.relpath(OUT, ROOT), w, h))


if __name__ == "__main__":
    main()
