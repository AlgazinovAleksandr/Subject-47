#!/usr/bin/env python3
"""Level 6 approach art (2026-09-23): Object 12's traces, and every surface that carries words.

Two kinds, per the project's image rule (flux cannot be trusted with a letter):

  * KEYED DECALS from flux raws in assets_src/textures/level_6_breach/approach/ (prompts in
    prompts.txt there). Each raw is a dark mark on a WHITE backdrop, so alpha is keyed on
    DARKNESS (the cutout_alpha.py idea) and the colour is re-tinted to one residue palette so the
    trail reads as one substance from room to room. Real RGBA, cropped to the mark.
  * PILLOW TEXT: the three seal panels, the shift roster, the OBJECT 12 stencil, the two signs
    the 2026-09-22 captures flagged, the barrier tape, the tally scratches and the fogged
    porthole glass. System fonts only, so the tool needs nothing outside macOS.

⚠️ Checked after writing: every RGBA output must have transparent pixels at its border and a
nonzero opaque area, or it is a solid rectangle in the game (CLAUDE.md: a billboard texture
must be a real RGBA cutout). The tool asserts both and prints the alpha histogram.

Deterministic (seeded noise). Needs Pillow — use the image pack's venv:
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_breach_approach_art.py
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets_src", "textures", "level_6_breach", "approach")
OUT = os.path.join(ROOT, "game", "assets", "textures", "level_6_breach")
SUP = "/System/Library/Fonts/Supplemental/"
F_SIGN = SUP + "DIN Condensed Bold.ttf"
F_MONO = SUP + "Andale Mono.ttf"
F_BOLD = SUP + "Arial Bold.ttf"
F_HAND = SUP + "Courier New Bold.ttf"

rng = random.Random(6230)


def font(path, size):
    return ImageFont.truetype(path, size)


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    if img.mode == "RGBA":
        a = img.getchannel("A")
        hist = a.histogram()
        total = img.width * img.height
        clear = hist[0] / total
        solid = sum(hist[180:]) / total   # paint alpha tops out below 255 on purpose
        border = [a.getpixel((x, 0)) for x in range(img.width)] + \
                 [a.getpixel((x, img.height - 1)) for x in range(img.width)]
        assert max(border) < 40, f"{name}: opaque pixels on the border — not a cutout"
        assert solid > 0.01, f"{name}: almost nothing opaque"
        print(f"{name:40s} {img.width}x{img.height} RGBA  clear {clear:5.1%}  opaque {solid:5.1%}")
    else:
        print(f"{name:40s} {img.width}x{img.height} {img.mode}")


# ---------------------------------------------------------------- keyed decals

def key_dark(raw, out_name, tint, lo=40, hi=200, crop=None, max_side=1024, gloss=0.0):
    """Alpha from darkness: L >= 255-lo is clear, L <= 255-hi is opaque, linear between."""
    img = Image.open(os.path.join(RAW, raw)).convert("RGB")
    if crop:
        img = img.crop(crop)
    lum = img.convert("L")
    alpha = lum.point(lambda v: max(0, min(255, int((255 - v - lo) * 255 / (hi - lo)))))
    # Keep the source's own shading as a value modulation of one shared residue colour.
    shade = lum.point(lambda v: int(40 + v * 0.55))
    r = shade.point(lambda v: int(tint[0] * v / 255 + gloss * max(0, v - 150)))
    g = shade.point(lambda v: int(tint[1] * v / 255 + gloss * max(0, v - 150)))
    b = shade.point(lambda v: int(tint[2] * v / 255 + gloss * max(0, v - 150)))
    rgba = Image.merge("RGBA", (r, g, b, alpha))
    # A soft 1-px feather, then clear a 2-px frame so the border test is honest.
    rgba.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.8)))
    bbox = rgba.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    if bbox:
        m = 12
        bbox = (max(0, bbox[0] - m), max(0, bbox[1] - m),
                min(rgba.width, bbox[2] + m), min(rgba.height, bbox[3] + m))
        rgba = rgba.crop(bbox)
    if max(rgba.size) > max_side:
        k = max_side / max(rgba.size)
        rgba = rgba.resize((int(rgba.width * k), int(rgba.height * k)), Image.LANCZOS)
    a = rgba.getchannel("A")
    ImageDraw.Draw(a).rectangle([0, 0, a.width - 1, a.height - 1], outline=0, width=2)
    rgba.putalpha(a)
    save(rgba, out_name)


RESIDUE = (70, 84, 60)     # black-green, the creature's residue — one colour everywhere
DRAG = (86, 64, 50)


def decals():
    key_dark("residue_trail_raw.jpg", "approach_residue_trail.png", RESIDUE, gloss=0.5)
    key_dark("residue_pool_raw.jpg", "approach_residue_pool.png", RESIDUE, gloss=0.6)
    key_dark("drag_smear_raw.jpg", "approach_drag_smear.png", DRAG, gloss=0.3)
    # The raw's torn square border is not a gouge: keep only the diagonal slashes inside it.
    key_dark("claw_gouge_raw.jpg", "approach_claw_gouge.png", (60, 58, 56), lo=60, hi=210,
             crop=(250, 190, 800, 820))
    key_dark("finger_drags_raw.jpg", "approach_finger_drags.png", RESIDUE, lo=50, hi=210)


# ---------------------------------------------------------------- text surfaces

def noise_layer(w, h, amount, seed, blur=0.0):
    r = random.Random(seed)
    img = Image.new("L", (w, h))
    img.putdata([128 + int(r.uniform(-amount, amount)) for _ in range(w * h)])
    return img.filter(ImageFilter.GaussianBlur(blur)) if blur else img


def grime(img, amount=18, seed=1):
    """Mottle a flat surface: multiply by soft noise so nothing reads as a clean render."""
    n = noise_layer(img.width, img.height, amount, seed, 1.2).point(lambda v: min(255, v + 110))
    return Image.blend(img, ImageChops.multiply(img, n.convert("RGB")), 0.6)


def centered(draw, y, text, f, fill, w):
    bb = draw.textbbox((0, 0), text, font=f)
    draw.text(((w - (bb[2] - bb[0])) // 2 - bb[0], y), text, font=f, fill=fill)


def seal_panel(name, value, colour, dead=False):
    w, h = 640, 400
    img = Image.new("RGB", (w, h), (46, 49, 48))
    d = ImageDraw.Draw(img)
    d.rectangle([14, 14, w - 15, h - 15], fill=(30, 32, 31))
    d.rectangle([38, 38, w - 39, h - 39], fill=(6, 9, 8))
    for sx, sy in [(24, 24), (w - 25, 24), (24, h - 25), (w - 25, h - 25)]:
        d.ellipse([sx - 5, sy - 5, sx + 5, sy + 5], fill=(70, 72, 70))
    small = font(F_MONO, 26)
    dim = tuple(int(c * 0.55) for c in colour)
    centered(d, 58, "WING C  /  CONTAINMENT SEAL", small, dim, w)
    centered(d, 92, "INTEGRITY", small, dim, w)
    # Fit the value inside the screen: "— — —" in DIN at 190 px is wider than the whole panel
    # and ran straight through the bezel on the first render.
    size = 190
    big = font(F_SIGN, size)
    while d.textbbox((0, 0), value, font=big)[2] > w - 140:
        size -= 10
        big = font(F_SIGN, size)
    centered(d, 140 + (190 - size) // 2, value, big, colour, w)
    if dead:
        # A cracked, dead screen: the last value is not there, only dashes and a fracture.
        crack = [(120, 60), (210, 150), (190, 230), (300, 300), (330, 380)]
        d.line(crack, fill=(90, 96, 92), width=3)
        d.line([(210, 150), (320, 120), (420, 170)], fill=(70, 76, 72), width=2)
        d.line([(300, 300), (420, 280), (520, 330)], fill=(70, 76, 72), width=2)
    else:
        # scanlines
        for y in range(40, h - 40, 4):
            d.line([(40, y), (w - 41, y)], fill=(0, 0, 0), width=1)
        centered(d, h - 86, "STATUS NOMINAL" if value.startswith("98") else "STATUS  —  DEGRADED",
                 small, dim, w)
    save(grime(img, seed=len(name)), name)


def shift_board():
    w, h = 1100, 720
    img = Image.new("RGB", (w, h), (196, 190, 172))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, 70], fill=(150, 146, 132))
    head = font(F_BOLD, 38)
    d.text((34, 14), "SUBLEVEL K-9  ·  WING C  ·  SHIFT ROSTER", font=head, fill=(40, 38, 34))
    mono = font(F_MONO, 30)
    cols = [40, 110, 470, 700]
    y = 96
    for label, x in zip(["#", "NAME", "POST", "SHIFT"], cols):
        d.text((x, y), label, font=mono, fill=(70, 66, 60))
    d.line([(34, y + 40), (w - 34, y + 40)], fill=(90, 86, 78), width=2)
    names = ["ORLOV  V.", "PETRENKO  A.", "KASYANOV  M.", "SOKOLOVA  D.", "BELOV  I.",
             "NAZAROV  T.", "GRISHIN  P.", "ZUEVA  L.", "MOROZ  K.", "LAPIN  O.", "YUDIN  R.",
             "KRAVETS  S."]
    posts = ["SEAL 1", "SEAL 1", "SEAL 2", "OBS. BAY", "OBS. BAY", "PLENUM", "PLENUM", "CELL 12",
             "CELL 12", "SERVICE", "SERVICE", "PLENUM"]
    y += 54
    for i, (nm, post) in enumerate(zip(names, posts)):
        row = y + i * 45
        shift = "06:00" if i % 2 == 0 else "18:00"
        for text, x in zip([f"{i + 1:02d}", nm, post, shift], cols):
            d.text((x, row), text, font=mono, fill=(38, 36, 32))
        if i < len(names) - 1:
            # struck through by hand, a little unevenly — a marker, not a ruler
            x0 = cols[1] - 10 + rng.randint(-6, 6)
            x1 = w - 70 + rng.randint(-20, 10)
            yy = row + 17 + rng.randint(-3, 3)
            d.line([(x0, yy), (x1, yy + rng.randint(-5, 5))], fill=(128, 22, 18), width=5)
    # The last name is not struck. Somebody was still counting.
    d.text((cols[3] + 110, y + 11 * 45), "?", font=font(F_HAND, 38), fill=(128, 22, 18))
    save(grime(img, amount=22, seed=11), "approach_shift_board.png")


def stencil():
    w, h = 1200, 420
    paint = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(paint)
    f = font(F_SIGN, 300)
    text = "OBJECT 12"
    bb = d.textbbox((0, 0), text, font=f)
    x = (w - (bb[2] - bb[0])) // 2 - bb[0]
    y = (h - (bb[3] - bb[1])) // 2 - bb[1] + 10
    d.text((x, y), text, font=f, fill=255)
    # stencil bridges: two horizontal cuts through every glyph
    for by in (y + int((bb[3] - bb[1]) * 0.36), y + int((bb[3] - bb[1]) * 0.70)):
        d.rectangle([0, by, w, by + 12], fill=0)
    # overspray: a blurred halo plus speckle, and paint dropout inside the letters
    halo = paint.filter(ImageFilter.GaussianBlur(7)).point(lambda v: int(v * 0.35))
    speck = noise_layer(w, h, 127, 77).point(lambda v: 255 if v > 246 else 0)
    speck = ImageChops.multiply(speck, paint.filter(ImageFilter.GaussianBlur(26)).point(lambda v: min(255, v * 3)))
    dropout = noise_layer(w, h, 127, 78, 2.0).point(lambda v: 0 if v < 96 else 255)
    body = ImageChops.multiply(paint, dropout)
    alpha = ImageChops.lighter(ImageChops.lighter(body, halo), speck).point(lambda v: int(v * 0.86))
    a = alpha.copy()
    ImageDraw.Draw(a).rectangle([0, 0, w - 1, h - 1], outline=0, width=3)
    rgb = Image.new("RGB", (w, h), (206, 190, 138))   # faded safety yellow
    rgba = rgb.copy()
    rgba.putalpha(a)
    save(rgba, "approach_stencil_object12.png")


def hazard_band(d, x0, y0, x1, y1, step=46):
    d.rectangle([x0, y0, x1, y1], fill=(196, 160, 40))
    for sx in range(x0 - (y1 - y0), x1, step * 2):
        d.polygon([(sx, y1), (sx + step, y1), (sx + step + (y1 - y0), y0), (sx + (y1 - y0), y0)],
                  fill=(24, 22, 20))


def sign_wing():
    w, h = 1040, 520
    img = Image.new("RGB", (w, h), (52, 56, 54))
    d = ImageDraw.Draw(img)
    hazard_band(d, 0, 0, w, 64)
    hazard_band(d, 0, h - 40, w, h)
    centered(d, 92, "OBJECT 12", font(F_SIGN, 230), (226, 222, 206), w)
    centered(d, 330, "CONTAINMENT WING", font(F_SIGN, 110), (226, 222, 206), w)
    centered(d, 444, "SUBLEVEL K-9  ·  AUTHORISED PERSONNEL", font(F_MONO, 26), (150, 150, 140), w)
    save(grime(img, seed=21), "approach_sign_containment_wing.png")


def sign_services():
    w, h = 1040, 360
    img = Image.new("RGB", (w, h), (52, 56, 54))
    d = ImageDraw.Draw(img)
    hazard_band(d, 0, 0, w, 40)
    # the arrow points LEFT: facing this wall from the Inspection turn, Damaged is on your left
    d.polygon([(60, 200), (190, 100), (190, 160), (300, 160), (300, 240), (190, 240), (190, 300)],
              fill=(226, 222, 206))
    d.text((340, 96), "CONTAINMENT", font=font(F_SIGN, 124), fill=(226, 222, 206))
    d.text((344, 226), "SERVICES  ·  RECEIVER BANK", font=font(F_SIGN, 64), fill=(180, 178, 166))
    save(grime(img, seed=22), "approach_sign_services.png")


def barrier_tape():
    w, h = 2048, 96
    img = Image.new("RGB", (w, h), (214, 176, 36))
    d = ImageDraw.Draw(img)
    f = font(F_SIGN, 70)
    x = 10
    phrase = "CONTAINMENT LINE  —  DO NOT CROSS  —  "
    while x < w:
        d.text((x, 14), phrase, font=f, fill=(22, 20, 18))
        x += d.textbbox((0, 0), phrase, font=f)[2]
    d.rectangle([0, 0, w, 6], fill=(22, 20, 18))
    d.rectangle([0, h - 7, w, h], fill=(22, 20, 18))
    save(grime(img, amount=14, seed=31), "approach_barrier_tape.png")


def tallies():
    w, h = 512, 1024
    base = noise_layer(w, h, 18, 41, 1.5).point(lambda v: int(v * 0.42 + 20))
    img = Image.merge("RGB", (base, base.point(lambda v: v + 3), base.point(lambda v: v + 2)))
    d = ImageDraw.Draw(img)
    r = random.Random(42)
    x0, y0 = 70, 120
    for group in range(11):
        gx = x0 + (group % 3) * 130 + r.randint(-8, 8)
        gy = y0 + (group // 3) * 190 + r.randint(-10, 10)
        for i in range(4):
            x = gx + i * 22 + r.randint(-3, 3)
            d.line([(x + 1, gy + 1), (x + r.randint(-6, 6) + 1, gy + 120 + 1)], fill=(12, 12, 12), width=4)
            d.line([(x, gy), (x + r.randint(-6, 6), gy + 120)], fill=(178, 180, 176), width=3)
        d.line([(gx - 14, gy + 96), (gx + 84, gy + 26)], fill=(12, 12, 12), width=4)
        d.line([(gx - 15, gy + 95), (gx + 83, gy + 25)], fill=(186, 188, 182), width=3)
    # the last group is unfinished: two strokes
    gx, gy = x0 + 2 * 130, y0 + 3 * 190 + 40
    for i in range(2):
        d.line([(gx + i * 22, gy), (gx + i * 22 + 3, gy + 120)], fill=(178, 180, 176), width=3)
    save(img, "approach_tallies.png")


def porthole_fog():
    w = h = 512
    base = noise_layer(w, h, 40, 51, 9).point(lambda v: int(v * 0.35 + 18))
    img = Image.merge("RGB", (base, base.point(lambda v: v + 9), base.point(lambda v: v + 7)))
    d = ImageDraw.Draw(img)
    r = random.Random(52)
    for _ in range(26):   # condensation runs: pale, thin, downward
        x = r.randint(40, w - 40)
        y = r.randint(20, h // 2)
        d.line([(x, y), (x + r.randint(-4, 4), y + r.randint(60, 260))], fill=(80, 92, 88), width=r.randint(2, 4))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    save(img, "approach_porthole_fog.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    decals()
    seal_panel("approach_seal_98.png", "98 %", (120, 220, 150))
    seal_panel("approach_seal_61.png", "61 %", (230, 170, 70))
    seal_panel("approach_seal_dead.png", "— — —", (120, 128, 124), dead=True)
    shift_board()
    stencil()
    sign_wing()
    sign_services()
    barrier_tape()
    tallies()
    porthole_fog()


if __name__ == "__main__":
    main()
