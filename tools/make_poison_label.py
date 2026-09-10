#!/usr/bin/env python3
"""KONTUR poison bottle-label texture (Gate 2 shelf), matching the vinegar/bleach/water set.

WHY THIS EXISTS
---------------
KONTUR Gate 2 puts three bottles on a kitchen shelf (vinegar / bleach / water); their
labels (`label_{vinegar,bleach,water}_paper.png`) are flux crops keyed to real alpha by
`crop_kontur_art.py`. This adds a fourth: a HAZARD / poison label, drawn deterministically
with Pillow only — never flux, because the payload is legible words and a diffusion model
cannot letter a sign (the same rule the KONTUR sign generators state).

OUTPUT  game/assets/textures/level_5_kontur/label_poison_paper.png
  * RGBA cutout on a genuinely transparent background — near-binary alpha (mid ~0, like the
    shipped set), with a torn + taped silhouette so it reads as a real cutout, not a rect.
  * Aged cream paper, near-black ink, an oxblood caution band. KONTUR house palette
    (see make_kontur_signs.py): card ~(150,144,128), ink (26,24,21), band (96,30,26).
  * Bold "POISON", Russian "ЯД", and a Pillow-drawn skull-and-crossbones.

⚠️ TWO DELIBERATE DIFFERENCES FROM THE SHIPPED LABELS, both flagged for review:
  * ORIENTATION: this is PORTRAIT (~480x800) as requested. The shipped *_paper labels are
    all LANDSCAPE (bleach 1.360, water 1.971, vinegar 1.975). Mine differs on purpose.
  * BRIGHTNESS: paper mean luminance is held ~100-130/255 (near-white is the brightest
    paint this renderer has — Issue 63 — and KONTUR's Soviet half is dark). The shipped
    three measure 172-190, i.e. brighter; this one is intentionally darker.

DETERMINISTIC — fixed seed, re-runnable, byte-stable.

USAGE
    "$HOME/Downloads/claude-image-generation-main/.venv/bin/python3" tools/make_poison_label.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""

import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "game", "assets", "textures", "level_5_kontur",
                   "label_poison_paper.png")

W, H = 480, 800          # portrait, echoing the requested ~470x780
SEED = 4712

# KONTUR house palette (make_kontur_signs.py). PAPER tuned so the OPAQUE mean lands ~100-130.
PAPER    = (196, 184, 156)
INK      = (26, 24, 21)
INK_SOFT = (58, 54, 46)
BAND     = (96, 30, 26)
BAND_LT  = (196, 186, 168)   # light caption over the oxblood band
FOX      = (92, 66, 40)      # foxing / damp brown
TAPE     = (150, 141, 112)   # yellowed, aged tape (opaque, part of the silhouette)
TAPE_DK  = (120, 112, 88)

# ------------------------------------------------------------------ fonts
# "Pillow only": use macOS system faces that carry Cyrillic (Arial Bold / Arial Unicode).
# If none render Cyrillic, fall back to PIL's default and report it rather than fail.
FONT_CANDS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "DejaVuSans-Bold.ttf",   # Pillow-bundled last resort
]


def _renders_cyrillic(font):
    def mask(s):
        im = Image.new("L", (140, 140), 0)
        ImageDraw.Draw(im).text((10, 10), s, font=font, fill=255)
        return im.tobytes()
    # a real Cyrillic glyph must differ from a guaranteed-missing private-use glyph
    return mask("Я") != mask("")


def _pick_font_path():
    for p in FONT_CANDS:
        try:
            f = ImageFont.truetype(p, 60)
        except Exception:
            continue
        if _renders_cyrillic(f):
            return p, os.path.basename(p)
    return None, "PIL default (NO Cyrillic — 'ЯД' will not render)"


FONT_PATH, FONT_NAME = _pick_font_path()
_probe = ImageDraw.Draw(Image.new("L", (4, 4)))


def font(size):
    if FONT_PATH:
        return ImageFont.truetype(FONT_PATH, size)
    return ImageFont.load_default()


def fit_font(text, max_w, hi=210, lo=14):
    for s in range(hi, lo, -2):
        if _probe.textlength(text, font=font(s)) <= max_w:
            return font(s)
    return font(lo)


def clamp(v):
    return 0 if v < 0 else 255 if v > 255 else int(v)


# ------------------------------------------------------------------ paper texture
def make_paper(rng):
    base = Image.new("RGBA", (W, H), PAPER + (255,))
    px = base.load()
    for y in range(H):
        for x in range(W):
            n = rng.randint(-9, 6)
            r, g, b, _ = px[x, y]
            px[x, y] = (clamp(r + n), clamp(g + n), clamp(b + int(n * 0.85)), 255)

    d = ImageDraw.Draw(base, "RGBA")
    # broad damp stains
    for _ in range(6):
        cx, cy = rng.randint(0, W), rng.randint(0, H)
        rx, ry = rng.randint(70, 150), rng.randint(60, 130)
        a = rng.randint(14, 34)
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=FOX + (a,))
    # fine foxing specks
    for _ in range(85):
        cx, cy = rng.randint(6, W - 6), rng.randint(6, H - 6)
        r = rng.randint(1, 4)
        a = rng.randint(40, 110)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=FOX + (a,))
    # a couple of soft horizontal fold shadows
    for fy in (rng.randint(240, 300), rng.randint(500, 560)):
        d.line([(10, fy), (W - 10, fy)], fill=FOX + (26,), width=3)
    base = base.filter(ImageFilter.GaussianBlur(0.4))

    # vignette: darker toward the edges (also pulls the mean down where light won't reach)
    vig = Image.new("L", (W, H), 152)
    dv = ImageDraw.Draw(vig)
    dv.rounded_rectangle([34, 40, W - 34, H - 40], radius=28, fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(46))
    r, g, b, a = base.split()
    r = ImageChops.multiply(r, vig)
    g = ImageChops.multiply(g, vig)
    b = ImageChops.multiply(b, vig)
    return Image.merge("RGBA", (r, g, b, a))


# ------------------------------------------------------------------ silhouette (real alpha)
def make_silhouette(rng):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    ml, mt, mr = 30, 54, 450
    body_bottom = 716
    d.rounded_rectangle([ml, mt, mr, body_bottom], radius=20, fill=255)
    # torn bottom edge: jagged polygon hanging below the body
    pts = [(ml, body_bottom - 6)]
    x = ml
    while x < mr:
        step = rng.randint(20, 40)
        x = min(mr, x + step)
        pts.append((x, body_bottom + rng.randint(-10, 40)))
    pts += [(mr, body_bottom - 6)]
    d.polygon(pts, fill=255)
    # slight left/right deckle: bite a few small notches out
    for _ in range(7):
        ey = rng.randint(mt + 20, body_bottom - 20)
        if rng.random() < 0.5:
            ex, w = ml, rng.randint(4, 10)
        else:
            ex, w = mr - rng.randint(4, 10), rng.randint(4, 10)
        d.ellipse([ex - w, ey - 9, ex + w, ey + 9], fill=0)

    # two tape strips at the top — opaque, so they extend the cutout silhouette
    tape = Image.new("L", (W, H), 0)
    dt = ImageDraw.Draw(tape)
    dt.polygon([(46, 22), (196, 40), (188, 96), (38, 78)], fill=255)          # top-left
    dt.polygon([(W - 196, 40), (W - 46, 22), (W - 38, 78), (W - 188, 96)], fill=255)  # top-right
    m = ImageChops.lighter(m, tape)

    m = m.filter(ImageFilter.GaussianBlur(0.6))
    m = m.point(lambda a: 255 if a >= 128 else 0)   # near-binary, like the shipped set
    return m, tape.point(lambda a: 255 if a >= 128 else 0)


# ------------------------------------------------------------------ skull & crossbones
def bone(length, thick):
    pad = int(thick * 1.6)
    im = Image.new("RGBA", (int(length + 2 * pad), int(thick * 2.6 + 2 * pad)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cy = im.height / 2
    d.rounded_rectangle([pad, cy - thick * 0.36, pad + length, cy + thick * 0.36],
                        radius=thick * 0.36, fill=INK + (255,))
    for ex in (pad, pad + length):
        d.ellipse([ex - thick * 0.62, cy - thick * 1.15, ex + thick * 0.62, cy + 0.1],
                  fill=INK + (255,))
        d.ellipse([ex - thick * 0.62, cy - 0.1, ex + thick * 0.62, cy + thick * 1.15],
                  fill=INK + (255,))
    return im


def draw_bones(img, cx, cy, length, thick):
    for ang in (40, -40):
        L = bone(length, thick).rotate(ang, expand=True, resample=Image.BICUBIC)
        img.alpha_composite(L, (int(cx - L.width / 2), int(cy - L.height / 2)))


def draw_skull(img, cx, cy, w, h, paper_rgb):
    sm = Image.new("L", (W, H), 0)
    dm = ImageDraw.Draw(sm)
    dm.ellipse([cx - w / 2, cy - h / 2, cx + w / 2, cy + h * 0.18], fill=255)      # cranium
    dm.ellipse([cx - w * 0.44, cy - h * 0.12, cx + w * 0.44, cy + h * 0.40], fill=255)  # cheeks
    jw = w * 0.52
    dm.rounded_rectangle([cx - jw / 2, cy + h * 0.18, cx + jw / 2, cy + h * 0.54],
                         radius=w * 0.16, fill=255)                                # jaw
    sm = sm.filter(ImageFilter.GaussianBlur(1.0)).point(lambda a: 255 if a > 118 else 0)
    img.paste(Image.new("RGBA", (W, H), INK + (255,)), (0, 0), sm)

    d = ImageDraw.Draw(img, "RGBA")
    pf = paper_rgb + (255,)
    ew, eh = w * 0.25, h * 0.21
    for sx in (-1, 1):                                                            # eye sockets
        ecx = cx + sx * w * 0.19
        d.ellipse([ecx - ew / 2, cy - h * 0.15, ecx + ew / 2, cy - h * 0.15 + eh], fill=pf)
    d.polygon([(cx - w * 0.065, cy + h * 0.02), (cx + w * 0.065, cy + h * 0.02),
               (cx, cy + h * 0.17)], fill=pf)                                     # nasal cavity
    tw = max(2, int(w * 0.03))
    d.line([(cx - jw * 0.5, cy + h * 0.21), (cx + jw * 0.5, cy + h * 0.21)], fill=pf, width=tw)
    for i in range(-2, 3):                                                        # teeth gaps
        gx = cx + i * w * 0.115
        d.line([(gx, cy + h * 0.22), (gx, cy + h * 0.50)], fill=pf, width=tw)


# ------------------------------------------------------------------ compose
def main():
    rng = random.Random(SEED)
    img = make_paper(rng)
    sil, tape = make_silhouette(rng)

    # paint the tape strips (opaque, aged) into the paper RGB
    dtp = ImageDraw.Draw(img, "RGBA")
    img.paste(Image.new("RGBA", (W, H), TAPE + (255,)), (0, 0), tape)
    # a little tape texture / edge
    for _ in range(60):
        # sample only where tape is, cheaply: try random points in the top band
        x, y = rng.randint(30, W - 30), rng.randint(20, 100)
        if tape.getpixel((x, y)):
            dtp.point((x, y), fill=TAPE_DK + (255,))

    d = ImageDraw.Draw(img, "RGBA")
    cx = W // 2

    # oxblood caution band near the top
    d.rounded_rectangle([54, 112, W - 54, 176], radius=8, fill=BAND + (255,))
    d.rounded_rectangle([54, 112, W - 54, 176], radius=8, outline=INK + (200,), width=2)
    bf = fit_font("ОПАСНО ДЛЯ ЖИЗНИ", W - 150)
    d.text((cx, 144), "ОПАСНО ДЛЯ ЖИЗНИ", font=bf, fill=BAND_LT + (255,), anchor="mm")

    # double border frame
    d.rounded_rectangle([44, 190, W - 44, 706], radius=14, outline=INK_SOFT + (255,), width=3)
    d.rounded_rectangle([54, 200, W - 54, 696], radius=10, outline=INK_SOFT + (150,), width=1)

    # POISON
    pf = fit_font("POISON", W - 130)
    d.text((cx, 236), "POISON", font=pf, fill=INK + (255,), anchor="mm")
    d.line([(96, 276), (W - 96, 276)], fill=INK + (255,), width=3)

    # skull & crossbones
    scy = 392
    draw_bones(img, cx, scy, length=214, thick=26)
    draw_skull(img, cx, scy, w=150, h=190, paper_rgb=PAPER)

    # ЯД (Russian)
    d = ImageDraw.Draw(img, "RGBA")
    yf = fit_font("ЯД", W - 180, hi=170)
    d.text((cx, 556), "ЯД", font=yf, fill=INK + (255,), anchor="mm")

    # footer
    d.line([(96, 618), (W - 96, 618)], fill=INK + (255,), width=2)
    ff = fit_font("ОБРАЗЕЦ О-41 · СМЕРТЕЛЬНО", W - 90)
    d.text((cx, 648), "ОБРАЗЕЦ О-41 · СМЕРТЕЛЬНО", font=ff, fill=INK + (255,), anchor="mm")
    sf = fit_font("НЕ ВСКРЫВАТЬ БЕЗ РАЗРЕШЕНИЯ", W - 90)
    d.text((cx, 680), "НЕ ВСКРЫВАТЬ БЕЗ РАЗРЕШЕНИЯ", font=sf, fill=INK_SOFT + (255,), anchor="mm")

    # clip everything to the paper silhouette (this is the real alpha channel)
    r, g, b, _ = img.split()
    out = Image.merge("RGBA", (r, g, b, sil))
    out.save(OUT)

    # measure & report
    px = out.load()
    tot = 0.0
    n = 0
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            rr, gg, bb, aa = px[x, y]
            if aa > 0:
                tot += 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
                n += 1
    mean = tot / n if n else -1
    print(f"font used         : {FONT_NAME}")
    print(f"wrote             : {OUT}")
    print(f"dimensions        : {W}x{H}  (aspect W/H = {W / H:.3f}, portrait)")
    print(f"opaque paper mean : {mean:.1f} / 255   (target 100-130)")


if __name__ == "__main__":
    main()
