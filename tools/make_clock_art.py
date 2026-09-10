#!/usr/bin/env python3
"""The Corridor's grandfather clock: its DIAL (drawn) and its WOOD (graded).

WHY THIS EXISTS
---------------
The clock at d = 48 m was a 2 x 3 m flat wall panel (`clock.png`, a photograph of a clock on
wallpaper) — the 2026-09-10 replay asked *"Shall we make that clock 3d?"* and the answer is
`grandfather_clock.gd`, a case built from parts with a pendulum that swings. That case needs
two textures this tool makes:

  clock_face.png     the dial — DRAWN with the code-based generator (Pillow via the pack's
                     `render.Design`), never flux: a dial is numerals, ticks and hands, and a
                     diffusion model cannot letter a clock face any more than it can a sign.
                     The hands are stopped at 2:17 — the room the level sends you to look for.
  clock_walnut.png   the case veneer — a flux generation (`clock_walnut_raw.jpg`, kept under
                     assets_src) GRADED here: the raw came back mid-brown and glossy, and
                     near-white is the brightest paint this renderer has (no tonemapping, no
                     glow; Issue 63). Multiplied to 0.55 and desaturated to 0.85 it reads as
                     old dark walnut under torchlight instead of a new kitchen cabinet.

USAGE
    IMAGE_PACK=~/Downloads/claude-image-generation-main \
    $IMAGE_PACK/.venv/bin/python3 tools/make_clock_art.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

Deterministic: the dial has no random element; the wood grade is a fixed multiply.
"""

import math
import os
import sys

PACK = os.environ.get("IMAGE_PACK", os.path.expanduser("~/Downloads/claude-image-generation-main"))
sys.path.insert(0, os.path.join(PACK, ".claude", "skills", "level-1-image-generator", "lib"))

from PIL import Image, ImageEnhance  # noqa: E402
from render import Design  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FACE_OUT = os.path.join(ROOT, "game/assets/textures/level_3_corridor/clock_face.png")
WOOD_RAW = os.path.join(ROOT, "assets_src/textures/level_3_corridor/clock_walnut_raw.jpg")
WOOD_OUT = os.path.join(ROOT, "game/assets/textures/level_3_corridor/clock_walnut.png")

# The hour the clock stopped at. 217 is the room; 2:17 is the time.
STOPPED_H = 2
STOPPED_M = 17

IVORY = (206, 192, 158)
IVORY_DK = (150, 134, 100)
FOX = (112, 78, 40)
INK = (34, 28, 22)
BLUED = (22, 26, 40)
BRASS = (150, 124, 66)


def dial():
    d = Design("1:1", background=IVORY)
    d.radial_gradient([(0.0, (214, 202, 170)), (0.62, (196, 180, 142)), (1.0, (128, 112, 80))],
                      center=(0.5, 0.5), radius=0.72)
    # Foxing — the brown blooms an old dial always has, kept under the numerals' contrast.
    d.overlay_glow((0.26, 0.70), FOX, 0.30, strength=0.34, mode="blend")
    d.overlay_glow((0.74, 0.30), FOX, 0.22, strength=0.28, mode="blend")
    d.overlay_glow((0.62, 0.78), (90, 70, 40), 0.18, strength=0.22, mode="blend")

    cx, cy = 0.5, 0.5
    # Chapter ring: two thin rings and sixty minute ticks, twelve of them longer.
    d.ring(cx, cy, 0.455, 0.006, INK)
    d.ring(cx, cy, 0.385, 0.004, INK)
    for i in range(60):
        a = math.radians(i * 6.0 - 90.0)
        r0 = 0.395 if i % 5 else 0.372
        r1 = 0.447
        w = 0.006 if i % 5 == 0 else 0.0025
        d.line(cx + math.cos(a) * r0, cy + math.sin(a) * r0,
               cx + math.cos(a) * r1, cy + math.sin(a) * r1, d.S(w) if hasattr(d, "S") else 4, INK)

    numerals = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
    for i, txt in enumerate(numerals):
        a = math.radians(i * 30.0 - 90.0)
        r = 0.315
        d.write(cx + math.cos(a) * r, cy + math.sin(a) * r, txt, role="serif_display",
                weight="bold", size=64, color=INK, align="center")

    # Maker's mark and a small seconds sub-dial that the hands never move.
    d.write(cx, cy - 0.17, "VESPER", role="serif_display", weight="bold", size=26,
            color=(96, 80, 52), align="center", tracking=8)
    d.write(cx, cy - 0.135, "217", role="mono", size=18, color=(110, 92, 60), align="center",
            tracking=4)
    d.ring(cx, cy + 0.17, 0.075, 0.003, INK)
    for i in range(12):
        a = math.radians(i * 30.0 - 90.0)
        d.line(cx + math.cos(a) * 0.062, cy + 0.17 + math.sin(a) * 0.062,
               cx + math.cos(a) * 0.072, cy + 0.17 + math.sin(a) * 0.072, 3, INK)
    d.line(cx, cy + 0.17, cx + math.cos(math.radians(150 - 90)) * 0.055,
           cy + 0.17 + math.sin(math.radians(150 - 90)) * 0.055, 4, BLUED)

    # The hands, stopped. Blued steel: a spade hour hand and a long thin minute hand.
    h_ang = math.radians((STOPPED_H % 12 + STOPPED_M / 60.0) * 30.0 - 90.0)
    m_ang = math.radians(STOPPED_M * 6.0 - 90.0)
    for ang, length, width in ((h_ang, 0.22, 0.026), (m_ang, 0.335, 0.018)):
        tail = 0.05
        d.line(cx - math.cos(ang) * tail, cy - math.sin(ang) * tail,
               cx + math.cos(ang) * length, cy + math.sin(ang) * length,
               max(3, int(width * 1500)), BLUED)
        # a spade near the tip
        sx, sy = cx + math.cos(ang) * (length * 0.62), cy + math.sin(ang) * (length * 0.62)
        d.ellipse(sx, sy, width * 1.1, width * 0.55 + length * 0.12, BLUED)
    d.disk(cx, cy, 0.022, BRASS)
    d.disk(cx, cy, 0.009, INK)

    d.vignette(strength=0.30, radius=0.98, power=1.5)
    d.save(FACE_OUT, grain=7, chroma=2, saturation=0.92, contrast=1.06)
    print("wrote", FACE_OUT)


def wood():
    if not os.path.exists(WOOD_RAW):
        print("no raw walnut at", WOOD_RAW, "— skipping the wood grade")
        return
    im = Image.open(WOOD_RAW).convert("RGB")
    im = ImageEnhance.Brightness(im).enhance(0.55)
    im = ImageEnhance.Color(im).enhance(0.85)
    im = ImageEnhance.Contrast(im).enhance(1.08)
    im.save(WOOD_OUT, optimize=True)
    px = im.resize((64, 64)).getdata()
    mean = sum(sum(p) / 3.0 for p in px) / len(px)
    print("wrote", WOOD_OUT, "mean %.1f/255" % mean)


if __name__ == "__main__":
    dial()
    wood()
