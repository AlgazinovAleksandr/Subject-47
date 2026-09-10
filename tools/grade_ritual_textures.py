#!/usr/bin/env python3
"""Grade and crop the flux-generated tileable close-ups for THE FLOOD's six ritual pieces
(2026-09-10) and KONTUR's Recovery Archive lots, from `assets_src/textures/*/<name>_raw.jpg`
into `game/assets/textures/*/<name>.png`.

⚠️ GRADING HAPPENS HERE, NOT IN THE MATERIAL. Both levels are lit at 0.02-0.07 ambient by a
torch, and a near-white albedo (linen, enamel, bone, wax) is the brightest paint this renderer
has (Issue 63) — a white tin tray in KONTUR's dark half would be the one visible object in the
room. Each entry carries an optional crop (a flux "tileable" still lands a subject in the frame:
the porcelain came with a doll's FACE in it and the brass as a grid of tiles), a brightness
multiplier and a desaturation, and the result is resampled to a square so triplanar tiling has
no seam bias. Deterministic; re-run after regenerating a raw. Needs Pillow (the image pack's
venv): `$PACK/.venv/bin/python3 tools/grade_ritual_textures.py`.
"""
import os
import sys
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# name -> (level folder, crop box as fractions (l, t, r, b) or None, brightness, saturation, size)
SPEC = {
    "ritual_wax":        ("level_backrooms", None,                       0.62, 0.45, 1024),
    "ritual_leather":    ("level_backrooms", None,                       0.90, 0.90, 1024),
    "ritual_pages":      ("level_backrooms", (0.05, 0.38, 0.95, 0.92),   0.72, 0.85, 1024),
    "ritual_bone":       ("level_backrooms", None,                       0.70, 0.80, 1024),
    "ritual_brass":      ("level_backrooms", (0.36, 0.36, 0.64, 0.64),   0.85, 0.95, 512),
    "ritual_iron":       ("level_backrooms", None,                       0.80, 0.85, 1024),
    "ritual_cloth":      ("level_backrooms", None,                       0.55, 0.70, 1024),
    "ritual_porcelain":  ("level_backrooms", (0.00, 0.00, 0.45, 0.45),   0.72, 0.85, 512),
    "ritual_book_cover": ("level_backrooms", None,                       0.85, 0.90, 1024),
    "archive_rack_steel":   ("level_5_kontur", (0.00, 0.00, 0.72, 0.60), 0.70, 0.75, 1024),
    "archive_linen":        ("level_5_kontur", None,                     0.58, 0.85, 1024),
    "archive_bakelite":     ("level_5_kontur", None,                     0.85, 0.80, 1024),
    "archive_musicbox_wood":("level_5_kontur", None,                     0.80, 0.95, 1024),
    "archive_tin":          ("level_5_kontur", None,                     0.55, 0.80, 1024),
    "archive_brass_plate":  ("level_5_kontur", None,                     0.75, 0.90, 1024),
}


def grade(name: str, spec) -> str:
    level, crop, bright, sat, size = spec
    raw = os.path.join(ROOT, "assets_src", "textures", level, name + "_raw.jpg")
    out = os.path.join(ROOT, "game", "assets", "textures", level, name + ".png")
    im = Image.open(raw).convert("RGB")
    if crop:
        w, h = im.size
        im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    im = im.resize((size, size), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(sat)
    im = ImageEnhance.Brightness(im).enhance(bright)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out, "PNG", optimize=True)
    px = im.convert("L")
    mean = sum(px.getdata()) / (px.width * px.height)
    return "%-24s %4dx%-4d mean %5.1f/255 -> %s" % (name, im.width, im.height, mean,
                                                     os.path.relpath(out, ROOT))


if __name__ == "__main__":
    only = sys.argv[1:]
    for n, s in SPEC.items():
        if only and n not in only:
            continue
        print(grade(n, s))
