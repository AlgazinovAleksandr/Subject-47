#!/usr/bin/env python3
"""F1 (2026-09-14, the user's pick: "rusted steel autopsy table with a stained sheet"). Two
textures for `flood_plate.gd`, from two flux generations in assets_src/ (kept as the only inputs):
  flood_steel_rust.png  — the table's steel, cropped clear of the generation's drain hole (the
                          table builds its own drain from parts), darkened for a room at 0.02.
  flood_sheet.png       — the stained sheet, 1024x561 = the 1.35 x 0.74 m sheet quad's aspect
                          (check_art_aspect measures it), darkened to ~0.45 mean luma because
                          near-white albedo is the brightest paint this renderer has (Issue 63),
                          with the OWNER'S LINE chalked along the near edge in Chalkduster.
The six piece outlines are NOT drawn here: they are thin pale 3D bars/rings in flood_plate.gd,
so they sit exactly on the slots the pieces are set in (and check_flood_drowned counts them).
⚠️ The quad is laid flat with rotation.x = -90, which sends the image's TOP to world -Z — the
edge the player stands at. So the sheet is composed in world orientation (text at the bottom,
reading toward +Z) and rotated 180° on save, and it comes out the right way up in the game.
Run with the image pack's venv (Pillow):
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_flood_altar_art.py
"""
import os, random
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets_src", "textures", "level_backrooms")
OUT = os.path.join(ROOT, "game", "assets", "textures", "level_backrooms")
LINES = ["SIX RELICS OF THE WARD.", "RETURN THEM TO ME."]   # == FloodPlate.SCRAWL
W, H = 1024, 561                                             # 1.35 : 0.74
random.seed(14)


def luma(im):
    px = im.convert("L")
    return sum(px.getdata()) / (px.width * px.height)


def rust():
    im = Image.open(os.path.join(SRC, "flood_steel_rust_raw.jpg")).convert("RGB")
    w, h = im.size
    im = im.crop((0, 0, int(w * 0.62), int(h * 0.55))).resize((1024, 1024), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(0.8)
    im = ImageEnhance.Brightness(im).enhance(0.52)
    out = os.path.join(OUT, "flood_steel_rust.png")
    im.save(out, "PNG", optimize=True)
    print("flood_steel_rust.png  mean luma %.1f" % luma(im))


def chalk_text(draw, font, text, cx, cy, fill):
    # Several jittered passes at low alpha: chalk skips and doubles rather than printing.
    bw = draw.textbbox((0, 0), text, font=font)
    tw = bw[2] - bw[0]
    x0 = cx - tw / 2.0
    for _ in range(5):
        dx, dy = random.uniform(-1.5, 1.5), random.uniform(-1.5, 1.5)
        draw.text((x0 + dx, cy + dy), text, font=font, fill=fill)


def sheet():
    im = Image.open(os.path.join(SRC, "flood_sheet_raw.jpg")).convert("RGB")
    w, h = im.size
    # keep the whole width; crop the height to the quad's aspect around the stained middle
    ch = int(w * H / W)
    y0 = max(0, (h - ch) // 2 - 40)
    im = im.crop((0, y0, w, y0 + ch)).resize((W, H), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(0.9)
    im = ImageEnhance.Brightness(im).enhance(0.48)
    # chalk lettering along the NEAR edge (bottom, world orientation)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Chalkduster.ttf", 44)
    except OSError:
        font = ImageFont.load_default()
    chalk = (226, 222, 210, 150)
    chalk_text(d, font, LINES[0], W / 2, H - 118, chalk)
    chalk_text(d, font, LINES[1], W / 2, H - 66, chalk)
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    im = Image.alpha_composite(im.convert("RGBA"), layer).convert("RGB")
    im = im.rotate(180)                      # see the header: image top -> world -Z
    out = os.path.join(OUT, "flood_sheet.png")
    im.save(out, "PNG", optimize=True)
    print("flood_sheet.png  %dx%d  mean luma %.1f" % (im.width, im.height, luma(im)))


if __name__ == "__main__":
    rust()
    sheet()
