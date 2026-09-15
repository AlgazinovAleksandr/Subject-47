#!/usr/bin/env python3
"""C1 (2026-09-13): art for the Corridor's three DIFFERENT dead-end spurs.

  * spur_note.png — the page on the first spur's end wall ("You are not the first…"), on the same
    torn Hotel Vesper paper as `vesper_note.png` (assets_src/.../vesper_note_paper_raw.jpg), the
    same PAPER_GAIN darkening and the same flood-fill alpha cutout, so the two documents read as
    one hotel's stationery. Words by Pillow — flux cannot letter.
  * spur_handprint.png — a dark, wet hand-print pressed on the inside of the second spur's door
    at the moment the plea behind the wall stops. RGBA, ink + alpha only.

    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_spur_art.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets_src", "textures", "level_3_corridor", "vesper_note_paper_raw.jpg")
OUT_DIR = os.path.join(HERE, "game", "assets", "textures", "level_3_corridor")
SHEET_BOX = (134, 127, 896, 929)
PAPER_GAIN = 0.66
PAPER_MIN_LUMA = 46
INK = (58, 44, 28)
FONT_DIRS = [os.environ.get("IMAGE_PACK_FONTS", ""),
             os.path.expanduser("~/Downloads/claude-image-generation-main/.claude/skills/level-1-image-generator/fonts"),
             os.path.expanduser("~/Downloads/claude-image-generation-main/fonts"), "/Library/Fonts", "/System/Library/Fonts"]

LINES = [
    "You are not the first",
    "to take this experiment.",
    "",
    "Room 217 was booked",
    "under my name too.",
    "",
    "They let you push.",
    "They only want to see",
    "how long you push for.",
]


def _font(names, size):
    for d in FONT_DIRS:
        if not d:
            continue
        for n in names:
            p = os.path.join(d, n)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


FORK_LINES = [
    "There is a shorter way.",
    "There is always",
    "a shorter way.",
    "",
    "It is never this one.",
    "",
    "Go back to the hall.",
    "Keep walking.",
]


def note(lines=None, out_name="spur_note.png", seed=217):
    lines = lines or LINES
    sheet = Image.open(SRC).convert("RGB").crop(SHEET_BOX)
    w, h = sheet.size
    ink = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ink)
    ital = _font(["CrimsonPro-Italic.ttf", "Georgia Italic.ttf", "Georgia.ttf"], int(h * 0.046))
    random.seed(seed)
    y = int(h * 0.20)
    for line in lines:
        if line:
            x = int(w * 0.14) + random.randint(-8, 8)
            d.text((x, y), line, font=ital, fill=INK + (225,))
        y += int(h * 0.062)
    out = Image.alpha_composite(sheet.convert("RGBA"), ink).convert("RGB")
    px = out.load()
    for yy in range(h):
        for xx in range(w):
            r, g, b = px[xx, yy]
            px[xx, yy] = (int(r * PAPER_GAIN), int(g * PAPER_GAIN), int(b * PAPER_GAIN))
    # flood-fill alpha from the centre (the candle in the corner is bright too; only connectivity tells)
    lum = out.convert("L").load()
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    seen = bytearray(w * h)
    stack = [(w // 2, h // 2)]
    thr = int(PAPER_MIN_LUMA * PAPER_GAIN)
    while stack:
        x, yv = stack.pop()
        i = yv * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if lum[x, yv] < thr:
            continue
        mp[x, yv] = 255
        if x > 0: stack.append((x - 1, yv))
        if x < w - 1: stack.append((x + 1, yv))
        if yv > 0: stack.append((x, yv - 1))
        if yv < h - 1: stack.append((x, yv + 1))
    mask = mask.filter(ImageFilter.MaxFilter(3))
    rgba = out.convert("RGBA")
    rgba.putalpha(mask)
    rgba.save(os.path.join(OUT_DIR, out_name))
    print("%s %dx%d" % (out_name, w, h))


def handprint():
    S = 768
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    col = (52, 10, 8, 215)
    # palm
    d.ellipse([(250, 330), (520, 640)], fill=col)
    d.polygon([(250, 480), (520, 480), (540, 700), (230, 700)], fill=col)
    # four fingers + thumb
    for cx, top, wid in [(300, 90, 62), (370, 50, 66), (445, 60, 66), (515, 120, 58)]:
        d.rounded_rectangle([(cx - wid // 2, top), (cx + wid // 2, 400)], radius=wid // 2, fill=col)
    d.rounded_rectangle([(150, 330), (260, 400)], radius=35, fill=col)
    d.rounded_rectangle([(120, 300), (230, 380)], radius=40, fill=col)
    im = im.rotate(-8, resample=Image.BICUBIC)
    # smudge: blur the whole print, then a few drips
    im = im.filter(ImageFilter.GaussianBlur(4))
    d = ImageDraw.Draw(im)
    random.seed(7)
    for _ in range(6):
        x = random.randint(280, 520)
        y0 = random.randint(600, 690)
        d.line([(x, y0), (x + random.randint(-6, 6), y0 + random.randint(30, 90))], fill=(60, 10, 8, 200), width=random.randint(4, 8))
    im.save(os.path.join(OUT_DIR, "spur_handprint.png"))
    print("spur_handprint.png")


CARD_LINES = [
    "HOTEL VESPER",
    "GUEST CARD",
    "",
    "Rm 217. Checked in",
    "under your name.",
    "",
    "The guest did not",
    "turn round. Good.",
    "The guest may proceed.",
]


if __name__ == "__main__":
    note()
    note(FORK_LINES, "fork_note.png", 4051)
    note(CARD_LINES, "bell_card.png", 1217)
    handprint()
