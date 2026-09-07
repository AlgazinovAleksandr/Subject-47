#!/usr/bin/env python3
"""Crop and grade the generated blast door into THE BREACH's door leaf texture.

    <image-pack venv>/python3 tools/make_breach_door.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

INPUT   assets_src/textures/level_6_breach/breach_door_raw.jpg   (level-3-image-generator)
OUTPUT  game/assets/textures/level_6_breach/breach_door.png

Needs Pillow — run it with the image pack's venv, like `crop_kontur_art.py` and
`make_kontur_signs.py`.

WHY THIS EXISTS. `level_6_breach.gd:_make_door()` hand-rolled a `BoxMesh(1.0, 2.2, 0.15)` with
`albedo (0.15,0.01,0.01)` and `emission (0.35,0.02,0.02)` at multiplier **1.5** — the exact
untextured branch that `door.gd:26-40` documents as superseded, on a level that already
`preload`s `door.gd` and simply never calls its `build_visual()`. And `level_6_breach/` had no
door texture at all, which is why `check_art_aspect.gd` could never flag it: a prop with no
artwork has no aspect to be wrong.

⚠️ THE CROP IS THE POINT, NOT THE GRADE. Measured, the raw generation is mean luminance 75.3 —
the same as `dungeon_door.png` (75.8) and darker than `house_door.png` (143.8), so it is not
too bright by this project's standards despite reading as vivid orange. What it IS is a picture
of a door PLUS the wall around it PLUS the floor in front of it, which is Issue 35 / X24 exactly
— hang that on a leaf and you have mounted a photograph of a wall onto a wall.

⚠️ AND THE ASPECT IS SUPPOSED TO BE NEARLY SQUARE. A Breach doorway is 1.8 m wide and the leaf
is 2.2 m tall (0.82), and a Dungeon doorway is 2.2 m (1.00) — these are freight-sized openings,
not domestic doors, so the double-leaf plate in the generation is the right subject and a ~1.0
crop is correct rather than a mistake. `door.gd:build_visual(fit_to_art=false)` sizes the quad
to the DOOR, so the leaf's own dimensions rule and this file only has to not be a landscape
photo of a corridor.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageEnhance, ImageStat
except ImportError:
    print("make_breach_door: needs Pillow — run with the image pack's venv:\n"
          "  ~/Downloads/claude-image-generation-main/.venv/bin/python3 "
          "tools/make_breach_door.py", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets_src" / "textures" / "level_6_breach" / "breach_door_raw.jpg"
OUT = ROOT / "game" / "assets" / "textures" / "level_6_breach" / "breach_door.png"

# The generation frames the door inside a dark surround and stands it on a lit floor. Found by
# scanning for the floor's brightness step (below) and by eye for the surround; both are
# reported so a re-generation that reframes the subject is obvious rather than silent.
SURROUND_PX = 26
FLOOR_SEARCH_FROM = 0.90     # look for the floor in the bottom 10 % of the image

# ⚠️ A LIGHT TOUCH. The plate is already at the project's door-texture luminance; what it is
# not is *aged*. 0.86 exposure and a slight desaturation take the orange from "freshly painted
# hazard equipment" toward "twenty years in a flooded containment wing" without pushing it into
# the near-black band where `hotel_door_leaf.png` (mean 18.4) lives — this door is meant to be
# findable in a level lit at 0.28 ambient.
EXPOSURE = 0.86
SATURATION = 0.72


def find_floor_row(im: Image.Image) -> int:
    """Row where the floor starts, by the brightness step across the bottom of the frame."""
    g = im.convert("L")
    w, h = g.size
    start = int(h * FLOOR_SEARCH_FROM)
    rows = []
    for y in range(start, h):
        band = g.crop((0, y, w, y + 1))
        rows.append((y, ImageStat.Stat(band).mean[0]))
    if len(rows) < 4:
        return h
    # The floor is the first row whose mean jumps well clear of the door plate's own.
    base = sum(v for _, v in rows[:3]) / 3.0
    for y, v in rows:
        if v > base * 1.25 + 6.0:
            return y
    return h


def stats(im: Image.Image) -> str:
    g = im.convert("L")
    px = list(g.get_flattened_data()) if hasattr(g, "get_flattened_data") else list(g.getdata())
    hot = sum(1 for v in px if v > 229) / len(px)
    return "%dx%d aspect %.3f  mean %.1f  hot %.2f%%" % (
        im.width, im.height, im.width / im.height, ImageStat.Stat(g).mean[0], hot * 100.0)


def main() -> int:
    if not SRC.exists():
        print("make_breach_door: no source at %s\n"
              "  Generate it first:\n"
              "    $PACK/.venv/bin/python3 $PACK/.claude/skills/level-3-image-generator/"
              "generate.py \"<prompt>\" -o %s" % (SRC, SRC), file=sys.stderr)
        return 1
    raw = Image.open(SRC).convert("RGB")
    print("  source        " + stats(raw))

    floor_y = find_floor_row(raw)
    print("  floor detected at row %d of %d" % (floor_y, raw.height))
    box = (SURROUND_PX, SURROUND_PX, raw.width - SURROUND_PX, floor_y - SURROUND_PX // 2)
    leaf = raw.crop(box)
    print("  cropped       " + stats(leaf) + "   box %s" % (box,))

    leaf = ImageEnhance.Brightness(leaf).enhance(EXPOSURE)
    leaf = ImageEnhance.Color(leaf).enhance(SATURATION)
    print("  graded        " + stats(leaf)
          + "   (exposure %.2f, saturation %.2f)" % (EXPOSURE, SATURATION))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    leaf.save(OUT, "PNG")
    print("\n  wrote %s  (%.2f MB)" % (OUT, OUT.stat().st_size / 1e6))
    print("  NOW RUN:  Godot --headless --path game --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())
