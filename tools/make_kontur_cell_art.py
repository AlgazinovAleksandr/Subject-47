#!/usr/bin/env python3
"""Object 12's containment tank (K-CELL, 2026-09-23): every texture `containment_cell.gd` wears.

The user picked concept A, "the glass tank" (backlogs/captures/breach-2026-09-23-cell-concepts/
A_glass_tank.jpg). The same cell stands occupied in KONTUR and burst open in the Breach, so these
files serve both levels and live beside the script that loads them.

Three kinds, following the project's image rule (flux cannot be trusted with a letter):

  * KEYED DECALS from flux raws in assets_src/textures/level_5_kontur/cell/ (prompts.txt there).
    Each raw is a dark mark on a WHITE backdrop, so alpha is keyed on DARKNESS (the idea behind
    tools/make_breach_approach_art.py). The colour is graded from the source toward DRIED blood:
    flux paints fresh arterial red, and a tank somebody hosed down weeks ago does not hold that.
  * THE BACK WALL, a full opaque texture: the flux steel plate with its four torn gouges, cropped
    to the quad's own aspect (check_art_aspect.gd) and lit from the top by the caged lamp. The
    lamp is EMISSION ONLY, because check_darkness.gd asserts nothing burns in KONTUR's Soviet
    half, so the pool of light the lamp would throw is painted into this texture instead. The
    cell uses the texture as its emission map as well as its albedo. The wall is the lit surface
    the occupant is a shadow against (Issue 147).
  * PROCEDURAL / PILLOW: the impact crack the charge reveals (a spiderweb from one blow, seeded),
    and the enamel placard (Russian + English, system fonts that carry Cyrillic: DIN Condensed
    Bold, Arial Narrow Bold, measured by rendering distinct glyphs for Ж Ъ Б Ы).

⚠️ Every RGBA output is checked after writing: transparent pixels on its whole border and a
nonzero opaque area. Otherwise it renders as a solid rectangle (CLAUDE.md: a billboard texture must
be a real RGBA cutout).

Deterministic (seeded). Needs Pillow, so use the image pack's venv:
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_kontur_cell_art.py
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets_src", "textures", "level_5_kontur", "cell")
OUT = os.path.join(ROOT, "game", "assets", "textures", "level_5_kontur")
SUP = "/System/Library/Fonts/Supplemental/"
F_SIGN = SUP + "DIN Condensed Bold.ttf"
F_NARROW = SUP + "Arial Narrow Bold.ttf"

# The back-wall quad in containment_cell.gd is 1.66 x 2.30 m. The texture is cropped to that aspect
# so check_art_aspect.gd holds (10 % tolerance) and nothing is squashed.
BACK_ASPECT = 1.66 / 2.30
SIDE_ASPECT = 1.60 / 2.30      # the two side liners


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    if img.mode == "RGBA":
        a = img.getchannel("A")
        hist = a.histogram()
        total = img.width * img.height
        clear = hist[0] / total
        solid = sum(hist[160:]) / total
        border = [a.getpixel((x, 0)) for x in range(img.width)] + \
                 [a.getpixel((x, img.height - 1)) for x in range(img.width)] + \
                 [a.getpixel((0, y)) for y in range(img.height)] + \
                 [a.getpixel((img.width - 1, y)) for y in range(img.height)]
        assert max(border) < 40, f"{name}: opaque pixels on the border, so it is not a cutout"
        assert solid > 0.01, f"{name}: almost nothing opaque"
        print(f"{name:32s} {img.width}x{img.height} RGBA  clear {clear:5.1%}  opaque {solid:5.1%}")
    else:
        lum = img.convert("L")
        h = lum.histogram()
        mean = sum(i * v for i, v in enumerate(h)) / (img.width * img.height)
        print(f"{name:32s} {img.width}x{img.height} {img.mode}  mean L {mean:5.1f}/255")


# ---------------------------------------------------------------- keyed decals

def dried(src_rgb):
    """Fresh flux red graded toward dried oxblood. Saturated red keeps a little of its red, and
    the black-brown stays black-brown."""
    r, g, b = src_rgb.split()
    r = r.point(lambda v: int(v * 0.36 + 16))
    g = g.point(lambda v: int(v * 0.20 + 9))
    b = b.point(lambda v: int(v * 0.18 + 7))
    return Image.merge("RGB", (r, g, b))


def key_dark(raw, lo=38, hi=190, crop=None, max_side=1024):
    """Alpha from darkness: L >= 255-lo is clear, L <= 255-hi is opaque, linear between."""
    img = Image.open(os.path.join(RAW, raw)).convert("RGB")
    if crop:
        img = img.crop(crop)
    lum = img.convert("L")
    alpha = lum.point(lambda v: max(0, min(255, int((255 - v - lo) * 255 / (hi - lo)))))
    rgba = dried(img).convert("RGBA")
    rgba.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.8)))
    bbox = rgba.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    if bbox:
        m = 14
        bbox = (max(0, bbox[0] - m), max(0, bbox[1] - m),
                min(rgba.width, bbox[2] + m), min(rgba.height, bbox[3] + m))
        rgba = rgba.crop(bbox)
    if max(rgba.size) > max_side:
        k = max_side / max(rgba.size)
        rgba = rgba.resize((int(rgba.width * k), int(rgba.height * k)), Image.LANCZOS)
    a = rgba.getchannel("A")
    ImageDraw.Draw(a).rectangle([0, 0, a.width - 1, a.height - 1], outline=0, width=3)
    rgba.putalpha(a)
    return rgba


def fade_top(rgba, frac):
    """The claw-drag raw's streaks run off the top of the frame, so keyed as-is they start on a
    hard horizontal line, which reads as a rectangle. Ramp the alpha in over the top `frac`."""
    a = rgba.getchannel("A")
    ramp = Image.new("L", a.size, 255)
    rows = max(1, int(a.height * frac))
    for y in range(rows):
        ImageDraw.Draw(ramp).line([(0, y), (a.width, y)], fill=int(255 * (y / rows) ** 1.6))
    rgba.putalpha(ImageChops.multiply(a, ramp))
    return rgba


def drags():
    return fade_top(key_dark("cell_claw_drags_raw.jpg", lo=30, hi=170), 0.30)


def decals():
    save(key_dark("cell_blood_smear_raw.jpg"), "cell_blood_smear.png")
    save(drags(), "cell_claw_drags.png")
    stain = key_dark("cell_floor_stain_raw.jpg", lo=26, hi=150)
    # The stain is a floor soak, not a wet pool: pull it browner and let it thin out.
    r, g, b, a = stain.split()
    stain = Image.merge("RGBA", (r.point(lambda v: int(v * 0.9 + 6)), g.point(lambda v: int(v * 0.9 + 5)),
                                 b.point(lambda v: int(v * 0.85 + 3)), a.point(lambda v: int(v * 0.86))))
    save(stain, "cell_floor_stain.png")


# ---------------------------------------------------------------- the back wall

def back_wall():
    img = Image.open(os.path.join(RAW, "cell_back_wall_raw.jpg")).convert("RGB")
    w, h = img.size
    cw = int(round(h * BACK_ASPECT))
    x0 = (w - cw) // 2
    img = img.crop((x0, 0, x0 + cw, h))
    w, h = img.size

    # Dried blood run down from the gouges: the claw-drag decal, shrunk and laid under the tears.
    run = drags()
    k = (w * 0.58) / run.width
    run = run.resize((int(run.width * k), int(run.height * k)), Image.LANCZOS)
    r, g, b, a = run.split()
    run = Image.merge("RGBA", (r.point(lambda v: int(v * 0.7)), g.point(lambda v: int(v * 0.7)),
                               b.point(lambda v: int(v * 0.7)), a.point(lambda v: int(v * 0.72))))
    img.paste(run, (int(w * 0.21), int(h * 0.44)), run)

    # The caged lamp hangs under the ceiling, near the top of this wall: a hot pool at the top
    # centre falling away toward the floor and the corners. Multiplied in, so the gouges' bright
    # scraped lips stay the brightest thing (they are what a silhouette reads against).
    lamp = Image.new("L", (w, h))
    px = []
    for y in range(h):
        for x in range(w):
            dx = (x / w - 0.5) / 0.62
            dy = (y / h - 0.02) / 0.95
            d2 = dx * dx + dy * dy
            px.append(int(255 * (0.30 + 0.70 * math.exp(-d2 * 1.6))))
    lamp.putdata(px)
    img = ImageChops.multiply(img, Image.merge("RGB", (lamp, lamp, lamp)))
    # A cold grade: the steel is green-grey under a sodium-free work lamp, like the concept.
    r, g, b = img.split()
    img = Image.merge("RGB", (r.point(lambda v: int(v * 0.92)), g, b.point(lambda v: int(v * 0.96))))
    img = img.resize((740, 1024), Image.LANCZOS)
    save(lift(img), "cell_back_wall.png")


# ⚠️ THE LIFT IS A MEASUREMENT, NOT TASTE. The cell wears these as EMISSION_OP_MULTIPLY maps at
# energy 1.0, so the PNG's brightness IS the backdrop the occupant is a shadow against (Issue 147).
# Ungraded (means 0.144 / 0.104 sRGB), tests/screenshot_cell_visibility.gd measured the occupant at
# contrast 0.005-0.10 through both side panes at 2 m. A gamma lift keeps the gouges' bright lips
# the brightest thing in the frame and the corners dark.
BACK_GAMMA = 0.62
SIDE_GAMMA = 0.50


def lift(img, gamma=BACK_GAMMA):
    lut = [int(round(255 * (i / 255) ** gamma)) for i in range(256)]
    return img.point(lut * 3)


def side_wall():
    """The one-sided liners inside the two side panes: the same steel plate as the back wall but
    with NO gouges (a repeated gouge on three walls reads as a copy), graded by the same lamp. Built
    from the raw's plain lower band, mirrored into a tall panel at the liner quad's aspect."""
    img = Image.open(os.path.join(RAW, "cell_back_wall_raw.jpg")).convert("RGB")
    w, h = img.size
    band = img.crop((int(w * 0.06), int(h * 0.64), int(w * 0.94), int(h * 0.97)))
    band = band.resize((740, int(740 * band.height / band.width)), Image.LANCZOS)
    tall = int(round(740 / SIDE_ASPECT))
    panel = Image.new("RGB", (740, tall))
    y = 0
    flip = False
    while y < tall:
        tile = band.transpose(Image.FLIP_TOP_BOTTOM) if flip else band
        panel.paste(tile, (0, y))
        y += tile.height
        flip = not flip
    lamp = Image.new("L", panel.size)
    px = []
    for yy in range(panel.height):
        for xx in range(panel.width):
            dx = (xx / panel.width - 0.5) / 0.75
            dy = (yy / panel.height - 0.0) / 0.9
            px.append(int(255 * (0.34 + 0.66 * math.exp(-(dx * dx + dy * dy) * 1.4))))
    lamp.putdata(px)
    panel = ImageChops.multiply(panel, Image.merge("RGB", (lamp, lamp, lamp)))
    save(lift(panel, SIDE_GAMMA), "cell_side_wall.png")


# ---------------------------------------------------------------- the impact crack

def crack():
    """One blow from inside: a crushed centre, radial fractures and polygon rings between them."""
    rng = random.Random(1212)
    W = 1024
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W * 0.5, W * 0.47
    line = (214, 224, 219)
    n = 15
    rays = []
    for i in range(n):
        ang = (i + rng.uniform(-0.3, 0.3)) * math.tau / n
        length = rng.uniform(0.30, 0.47) * W
        pts = [(cx, cy)]
        r = 0.0
        a = ang
        while r < length:
            r += rng.uniform(22, 48)
            a += rng.uniform(-0.12, 0.12)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        rays.append(pts)
        for j in range(len(pts) - 1):
            t = j / max(1, len(pts) - 1)
            width = max(1, int(round(4.2 * (1.0 - t) + 1)))
            alpha = int(235 - 130 * t)
            d.line([pts[j], pts[j + 1]], fill=line + (alpha,), width=width)
        # a branch or two off each ray
        for _ in range(rng.randint(0, 2)):
            j = rng.randint(2, max(2, len(pts) - 2))
            if j >= len(pts):
                continue
            bx, by = pts[j]
            ba = ang + rng.choice([-1, 1]) * rng.uniform(0.35, 0.8)
            bl = rng.uniform(40, 120)
            d.line([(bx, by), (bx + math.cos(ba) * bl, by + math.sin(ba) * bl)],
                   fill=line + (120,), width=1)
    # concentric rings: connect neighbouring rays at a few radii, jagged
    for ring_r in [0.055, 0.11, 0.18, 0.27]:
        for i in range(n):
            p0 = rays[i]
            p1 = rays[(i + 1) % n]
            k0 = min(len(p0) - 1, max(1, int(ring_r * W / 35)))
            k1 = min(len(p1) - 1, max(1, int(ring_r * W / 35) + rng.randint(-1, 1)))
            if rng.random() < 0.18 and ring_r > 0.1:
                continue
            a = p0[k0]
            b = p1[k1]
            mid = ((a[0] + b[0]) / 2 + rng.uniform(-9, 9), (a[1] + b[1]) / 2 + rng.uniform(-9, 9))
            alpha = int(200 - ring_r * 360)
            d.line([a, mid, b], fill=line + (alpha,), width=2 if ring_r < 0.15 else 1)
    # crushed centre: short chips and a frosted bruise
    for _ in range(90):
        a = rng.uniform(0, math.tau)
        r0 = rng.uniform(0, 34)
        r1 = r0 + rng.uniform(6, 22)
        d.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
                (cx + math.cos(a + 0.2) * r1, cy + math.sin(a + 0.2) * r1)],
               fill=line + (190,), width=2)
    bruise = Image.new("L", (W, W), 0)
    ImageDraw.Draw(bruise).ellipse([cx - 30, cy - 28, cx + 30, cy + 30], fill=120)
    bruise = bruise.filter(ImageFilter.GaussianBlur(9))
    base = img.getchannel("A")
    img.putalpha(ImageChops.lighter(base, bruise))
    a = img.getchannel("A")
    ImageDraw.Draw(a).rectangle([0, 0, W - 1, W - 1], outline=0, width=6)
    img.putalpha(a)
    save(img, "cell_glass_crack.png")


# ---------------------------------------------------------------- the placard

def centered(draw, y, text, f, fill, w):
    bb = draw.textbbox((0, 0), text, font=f)
    draw.text(((w - (bb[2] - bb[0])) // 2 - bb[0], y - bb[1]), text, font=f, fill=fill)


def fit(draw, text, path, size, max_w):
    f = ImageFont.truetype(path, size)
    while draw.textbbox((0, 0), text, font=f)[2] > max_w and size > 10:
        size -= 4
        f = ImageFont.truetype(path, size)
    return f


def placard():
    # ⚠️ MID-TONE ENAMEL, not white. Emission is most of a surface's colour in this project and
    # the plate hangs in a room lit at 0.02: the same reasoning as make_kontur_signs.py's CARD.
    w, h = 1200, 450
    img = Image.new("RGB", (w, h), (152, 147, 132))
    d = ImageDraw.Draw(img)
    d.rectangle([10, 10, w - 11, h - 11], outline=(70, 66, 58), width=6)
    d.rectangle([22, 22, w - 23, 104], fill=(98, 28, 24))
    centered(d, 40, "К.О.Н.Т.У.Р.   ·   ИЗОЛЯТОР Б-12", fit(d, "К.О.Н.Т.У.Р.   ·   ИЗОЛЯТОР Б-12",
                                                            F_NARROW, 52, w - 120), (196, 186, 170), w)
    ink = (24, 22, 19)
    centered(d, 128, "ОБЪЕКТ 12", fit(d, "ОБЪЕКТ 12", F_SIGN, 168, w - 160), ink, w)
    centered(d, 300, "OBJECT 12  —  CONTAINED", fit(d, "OBJECT 12  —  CONTAINED", F_SIGN, 70, w - 180),
             (44, 41, 36), w)
    centered(d, 376, "НЕ ОТКРЫВАТЬ  ·  DO NOT OPEN  ·  СТЕКЛО 60 ММ",
             fit(d, "НЕ ОТКРЫВАТЬ  ·  DO NOT OPEN  ·  СТЕКЛО 60 ММ", F_NARROW, 44, w - 170),
             (112, 24, 20), w)
    for sx, sy in [(44, 132), (w - 45, 132), (44, h - 44), (w - 45, h - 44)]:
        d.ellipse([sx - 11, sy - 11, sx + 11, sy + 11], fill=(66, 62, 55))
        d.ellipse([sx - 5, sy - 5, sx + 5, sy + 5], fill=(40, 38, 34))
    # enamel chips and grime, seeded
    rng = random.Random(4712)
    for _ in range(26):
        x = rng.randint(20, w - 20)
        y = rng.randint(20, h - 20)
        r = rng.randint(3, 14)
        d.ellipse([x - r, y - int(r * 0.7), x + r, y + int(r * 0.7)], fill=(58, 54, 48))
    noise = Image.new("L", (w, h))
    noise.putdata([128 + rng.randint(-26, 26) for _ in range(w * h)])
    noise = noise.filter(ImageFilter.GaussianBlur(1.4)).point(lambda v: min(255, v + 105))
    img = Image.blend(img, ImageChops.multiply(img, Image.merge("RGB", (noise, noise, noise))), 0.65)
    # a rust run from the lower-right screw
    run = Image.new("L", (w, h), 0)
    ImageDraw.Draw(run).line([(w - 45, h - 40), (w - 52, h - 4)], fill=150, width=9)
    run = run.filter(ImageFilter.GaussianBlur(3))
    img = Image.composite(Image.new("RGB", (w, h), (92, 52, 30)), img, run)
    save(img, "cell_placard.png")


if __name__ == "__main__":
    decals()
    back_wall()
    side_wall()
    crack()
    placard()
