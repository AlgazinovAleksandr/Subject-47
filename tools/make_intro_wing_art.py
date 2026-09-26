"""The Intake Wing's art (the intro redesign, 2026-09-24) — game/assets/textures/intro/.

⚠️ CODE-BASED, NOT GENERATED, and that was forced: the Cloudflare flux quota was exhausted on the
day this landed (HTTP 429, "daily free allocation of 10,000 neurons"). Everything here is composed
with numpy + Pillow — the imagery from textures ALREADY SHIPPING in this room (`intro_wall.png` is
the peeling grey-green plaster of the cold-open video; `floor_intro.png` / `ceiling_intro.png` are
the ward's own), and everything with words drawn as typography. docs/TEXTURES.md carries a flux
prompt for each image so a generated replacement can be dropped in under the same file name.

  asylum_wall.png        1024^2  plaster over a dark painted wainscot; ONE TILE = 3.6 m square
                                 (the ward's height), floor at the bottom edge; seamless in x
  asylum_floor.png       1024^2  wet, stained concrete; seamless both ways
  asylum_floor_rough.png 512^2   its roughness map — the wet patches are what the bulbs glint on
  asylum_ceiling.png     1024^2  cracked plaster ceiling with damp rings; seamless both ways
  asylum_door.png        537x1024  a panelled ward door, peeling paint, wired-glass light
  tally_marks.png        1024x512  RGBA cutout: 46 marks, gouged into plaster
  reel_panel.png         768x256   the reel-to-reel's front panel, masking-tape "SESSION 46"
  file_subject47.png     1200x800  your file, open — and Subject 46's page, TERMINATED
  observer_log.png       600x800   the hall's clipboard page
  tray_label_issued.png  640x128   embossed label tape: SUBJECT 47 — ISSUED
  wristband_47.png       512x128   the band's printed tag

Deterministic (seeded).
    .venv/bin/python3 tools/make_intro_wing_art.py            (the first set)
    .venv/bin/python3 tools/make_intro_wing_art.py --pass2    (cell pad, porcelain, trolley steel,
        the DO NOT TOUCH tag, the STAND HERE mark, the stopped clock, the screen cloth, 5 slides)
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "game", "assets", "textures", "intro")
FONT_DIRS = [os.environ.get("IMAGE_PACK_FONTS", ""),
             os.path.expanduser("~/Downloads/claude-image-generation-main/.claude/skills/"
                                "level-1-image-generator/fonts"),
             "/Library/Fonts", "/System/Library/Fonts"]
rng = np.random.default_rng(4747)


def font(name, size):
    for d in FONT_DIRS:
        if not d:
            continue
        p = os.path.join(d, name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    raise SystemExit("font %s not found; set IMAGE_PACK_FONTS" % name)


def load(name, size):
    im = Image.open(os.path.join(TEX, name)).convert("RGB").resize(size, Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def save(arr, name):
    a = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    mode = "RGBA" if a.shape[2] == 4 else "RGB"
    Image.fromarray(a, mode).save(os.path.join(TEX, name))
    print("wrote", name, a.shape[1], "x", a.shape[0], mode)


def tent(n):
    """0 at both ends, 1 in the middle."""
    x = np.linspace(0.0, 1.0, n, endpoint=False) + 0.5 / n
    return 1.0 - np.abs(x * 2.0 - 1.0)


def seamless(a, axes=(0, 1)):
    """Blend an image with a half-rolled copy of itself so it wraps. The roll's own edges are
    the source's interior, which is continuous across the wrap by construction."""
    h, w = a.shape[:2]
    rolled = a
    wgt = np.ones((h, w), np.float32)
    if 1 in axes:
        rolled = np.roll(rolled, w // 2, axis=1)
        wgt = wgt * tent(w)[None, :]
    if 0 in axes:
        rolled = np.roll(rolled, h // 2, axis=0)
        wgt = wgt * tent(h)[:, None]
    wgt = np.clip(wgt * 2.2, 0.0, 1.0)[..., None]
    return a * wgt + rolled * (1.0 - wgt)


def periodic_noise(h, w, octaves=((2, 1.0), (4, 0.5), (8, 0.25), (16, 0.12)), seed=0):
    """Tileable value noise from integer-frequency sinusoids: periodic on the image by
    construction, so the stains it paints can never make a seam."""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    out = np.zeros((h, w), np.float32)
    for f, amp in octaves:
        for _ in range(3):
            fx, fy = r.integers(-f, f + 1), r.integers(-f, f + 1)
            if fx == 0 and fy == 0:
                fx = f
            ph = r.uniform(0, 2 * np.pi)
            out += amp * np.sin(2 * np.pi * (fx * x / w + fy * y / h) + ph)
    out -= out.min()
    return out / max(1e-6, out.max())


def blob_noise(h, w, scale, seed=0):
    """Organic tileable noise: white noise low-passed in the FREQUENCY domain, which is
    periodic by construction. ⚠️ Not `periodic_noise()` for stains: a handful of sinusoids makes
    diamond/contour patterns (the first render of the floor read as camouflage)."""
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((h, w)))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f *= np.exp(-(fx ** 2 + fy ** 2) * (scale ** 2))
    out = np.real(np.fft.ifft2(f)).astype(np.float32)
    out -= out.min()
    return out / max(1e-6, out.max())


# ---------------------------------------------------------------- surfaces

def make_wall():
    n = 1024
    plaster = load("intro_wall.png", (n, n))
    # The cold-open's walls read cooler and paler than intro_wall's olive: a small grade toward
    # grey-green, never a repaint.
    lum = plaster.mean(axis=2, keepdims=True)
    plaster = plaster * 0.55 + lum * np.array([0.93, 1.02, 0.99]) * 0.45
    plaster = seamless(plaster, axes=(1,))
    # The wainscot: the bottom 1.0 m of a 3.6 m tile, i.e. rows 740..1024. Painted DARK gloss
    # over the same plaster, so its chips and cracks line up with the wall above.
    top = int(n * (1.0 - 1.0 / 3.6))
    wav = periodic_noise(1, n, ((8, 1.0), (32, 0.5), (64, 0.3)), seed=11)[0]
    edge = (top + (wav - 0.5) * 10).astype(int)
    y = np.arange(n)[:, None]
    below = y >= edge[None, :]
    lumw = plaster.mean(axis=2, keepdims=True)
    wain = lumw * np.array([0.40, 0.49, 0.49]) * 0.95 + 0.02
    # Where the plaster above is PEELED (bright), the wainscot's paint has flaked too: lighter.
    peel = np.clip((lumw - 0.55) * 3.0, 0, 1)
    wain = wain * (1 - peel * 0.5) + plaster * peel * 0.5
    out = np.where(below[..., None], wain, plaster)
    # The dado line: a thin darker painted stripe riding the boundary.
    stripe = (y >= edge[None, :] - 4) & (y < edge[None, :] + 5)
    out = np.where(stripe[..., None], out * 0.55, out)
    # Floor grime creeping up the last ~12 cm, and a faint water line.
    grime = np.clip((y - (n - 40)) / 40.0, 0, 1)[..., None] if True else 0
    out = out * (1 - grime * 0.45)
    damp = periodic_noise(n, n, ((3, 1.0), (6, 0.5)), seed=12)
    tide = np.exp(-((y - (top - 90 - damp * 60)) / 26.0) ** 2)[..., None]
    out = out * (1 - tide * 0.12 * np.array([1.0, 1.05, 1.2]))
    save(np.clip(out, 0, 1), "asylum_wall.png")


def make_floor():
    n = 1024
    base = load("floor_intro.png", (n, n))
    base = seamless(base)
    wet = blob_noise(n, n, 260.0, seed=21) * 0.8 + blob_noise(n, n, 60.0, seed=23) * 0.2
    rust = blob_noise(n, n, 180.0, seed=22) * 0.75 + blob_noise(n, n, 30.0, seed=24) * 0.25
    grit = rng.random((n, n)).astype(np.float32)
    wet_m = np.clip((wet - 0.58) * 5.0, 0, 1)[..., None]
    rust_m = np.clip((rust - 0.64) * 4.0, 0, 1)[..., None]
    out = base * (1 - wet_m * 0.45)                        # wet concrete darkens
    out = out * (1 - rust_m * 0.35) + rust_m * 0.35 * np.array([0.30, 0.19, 0.11]) * base.mean()
    out = out * (0.94 + 0.06 * grit[..., None])
    out = out * np.array([0.97, 1.0, 1.0])
    save(np.clip(out, 0, 1), "asylum_floor.png")
    # Roughness: 0.85 dry, down to 0.25 in the puddles — the bulbs' highlights live there.
    rough = 0.85 - wet_m[..., 0] * 0.6
    img = Image.fromarray(np.clip(rough * 255, 0, 255).astype(np.uint8), "L").resize((512, 512))
    img.save(os.path.join(TEX, "asylum_floor_rough.png"))
    print("wrote asylum_floor_rough.png 512 x 512 L")


def make_ceiling():
    n = 1024
    base = load("ceiling_intro.png", (n, n))
    base = seamless(base)
    rings = blob_noise(n, n, 300.0, seed=31) * 0.85 + blob_noise(n, n, 40.0, seed=32) * 0.15
    # Damp stains: a soft brown patch with ONE darker tide-line at its edge (two made contours).
    ring = np.exp(-((rings - 0.66) / 0.010) ** 2)
    inside = np.clip((rings - 0.66) * 6.0, 0, 1)
    out = base * (1 - inside[..., None] * 0.18)
    out = out * (1 - ring[..., None] * 0.28 * np.array([0.8, 1.0, 1.35]))
    save(np.clip(out, 0, 1), "asylum_ceiling.png")


def make_door():
    w, h = 537, 1024          # 1.10 x 2.10 m leaf (WingDoor: 1.2 doorway - 2 x LEAF_GAP)
    paint = load("intro_wall.png", (w, h))
    lum = paint.mean(axis=2, keepdims=True)
    paint = paint * 0.4 + lum * np.array([0.95, 1.04, 1.0]) * 0.6
    paint = paint * 1.05 + 0.02
    img = Image.fromarray(np.clip(paint * 255, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img, "RGBA")
    m = 46                                     # stile width
    # Wired-glass light, top third.
    gx0, gy0, gx1, gy1 = m + 40, 70, w - m - 40, 380
    d.rectangle([gx0 - 14, gy0 - 14, gx1 + 14, gy1 + 14], fill=(40, 46, 44, 110))
    glass = np.zeros((gy1 - gy0, gx1 - gx0, 3), np.float32)
    yy = np.linspace(0, 1, gy1 - gy0)[:, None]
    glass[:] = (0.05 + 0.07 * (1 - yy))[..., None] * np.array([0.8, 1.0, 1.0])
    gimg = Image.fromarray((glass * 255).astype(np.uint8), "RGB")
    gd = ImageDraw.Draw(gimg)
    step = 22
    gw, gh = gimg.size
    for k in range(-gh, gw + gh, step):
        gd.line([(k, 0), (k + gh, gh)], fill=(92, 98, 96), width=2)
        gd.line([(k, gh), (k + gh, 0)], fill=(92, 98, 96), width=2)
    img.paste(gimg, (gx0, gy0))
    d.line([(gx0, gy0), (gx1, gy0)], fill=(20, 22, 22, 255), width=5)
    d.line([(gx0, gy0), (gx0, gy1)], fill=(20, 22, 22, 255), width=5)
    d.line([(gx0, gy1), (gx1, gy1)], fill=(200, 205, 198, 120), width=3)
    # Two recessed lower panels, bevelled: shadow top-left, catch-light bottom-right.
    for (px0, py0, px1, py1) in [(m + 34, 470, w - m - 34, 700), (m + 34, 760, w - m - 34, h - 70)]:
        d.rectangle([px0, py0, px1, py1], fill=(0, 0, 0, 38))
        d.line([(px0, py0), (px1, py0)], fill=(18, 20, 20, 200), width=7)
        d.line([(px0, py0), (px0, py1)], fill=(18, 20, 20, 200), width=7)
        d.line([(px0, py1), (px1, py1)], fill=(215, 220, 212, 110), width=4)
        d.line([(px1, py0), (px1, py1)], fill=(215, 220, 212, 110), width=4)
    # Edge wear: the stiles are darker where hands and trolleys hit them.
    arr = np.asarray(img).astype(np.float32) / 255.0
    x = np.arange(w)[None, :]
    yv = np.arange(h)[:, None]
    wear = np.clip(1 - np.minimum(x, w - 1 - x) / 22.0, 0, 1) * 0.35
    wear = wear + np.clip((yv - (h - 150)) / 150.0, 0, 1) * 0.35
    hand = np.exp(-(((x - w * 0.86) / 60.0) ** 2 + ((yv - h * 0.53) / 110.0) ** 2)) * 0.45
    arr = arr * (1 - np.clip(wear + hand, 0, 0.7)[..., None])
    img = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img, "RGBA")
    # Escutcheon plate + knob + keyhole.
    hx, hy = int(w * 0.86), int(h * 0.53)
    d.rounded_rectangle([hx - 22, hy - 70, hx + 22, hy + 70], 8, fill=(58, 52, 44, 255),
                        outline=(30, 26, 22, 255), width=3)
    d.ellipse([hx - 17, hy - 38, hx + 17, hy - 4], fill=(96, 86, 70, 255), outline=(40, 34, 28, 255), width=3)
    d.ellipse([hx - 6, hy + 22, hx + 6, hy + 34], fill=(10, 8, 8, 255))
    d.polygon([(hx - 3, hy + 30), (hx + 3, hy + 30), (hx + 5, hy + 50), (hx - 5, hy + 50)], fill=(10, 8, 8, 255))
    img.save(os.path.join(TEX, "asylum_door.png"))
    print("wrote asylum_door.png", w, "x", h)


def make_tally():
    w, h = 1024, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    marks = 46                     # a mark a day — or a mark a subject
    x0, y0 = 60, 50
    gx = x0
    gy = y0
    count = 0
    r = np.random.default_rng(46)
    while count < marks:
        in_group = min(5, marks - count)
        for k in range(min(4, in_group)):
            x = gx + k * 26 + r.normal(0, 2)
            top = gy + r.normal(0, 5)
            bot = gy + 118 + r.normal(0, 6)
            lean = r.normal(0, 4)
            for p in range(3):          # three passes of a fingernail, not one clean line
                off = r.normal(0, 1.4)
                d.line([(x + off, top), (x + lean + off, bot)],
                       fill=(26, 20, 16, int(200 + 55 * r.random())), width=int(r.integers(11, 17)))
            # the gouge's pale floor: exposed plaster inside the scratch
            d.line([(x + 1, top + 6), (x + lean + 1, bot - 6)], fill=(170, 160, 140, 150), width=3)
        if in_group == 5:
            d.line([(gx - 14, gy + 96 + r.normal(0, 4)), (gx + 96, gy + 20 + r.normal(0, 4))],
                   fill=(24, 18, 14, 240), width=15)
        count += in_group
        gx += 150 + r.normal(0, 8)
        if gx > w - 170:
            gx = x0 + r.normal(0, 14)
            gy += 150
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(os.path.join(TEX, "tally_marks.png"))
    print("wrote tally_marks.png", w, "x", h, "RGBA")


# ---------------------------------------------------------------- props with words

def make_reel_panel():
    w, h = 768, 256
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    streak = rng.random((1, w)).astype(np.float32) * 0.06
    alu = 0.50 + 0.10 * np.sin(x / w * 3.1) + streak - 0.04 * (y / h)
    arr = np.stack([alu * 0.97, alu, alu * 0.99], axis=2)
    img = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, w - 1, h - 1], outline=(40, 40, 40, 255), width=6)
    d.rectangle([0, int(h * 0.62), w, h], fill=(22, 22, 24, 255))            # black lower strip
    # Two VU meters.
    for cx in (150, 330):
        d.rounded_rectangle([cx - 78, 26, cx + 78, 128], 6, fill=(214, 200, 160, 255),
                            outline=(30, 30, 30, 255), width=4)
        for k in range(11):
            a = np.radians(210 + k * 12)
            r0, r1 = 58, 70 if k % 2 == 0 else 64
            d.line([(cx + r0 * np.cos(a), 118 + r0 * np.sin(a)), (cx + r1 * np.cos(a), 118 + r1 * np.sin(a))],
                   fill=(40, 34, 28, 255), width=2)
        d.arc([cx - 70, 48, cx + 70, 188], 212, 330, fill=(40, 34, 28, 255), width=2)
        d.arc([cx - 70, 48, cx + 70, 188], 300, 330, fill=(150, 30, 20, 255), width=4)
        a = np.radians(238)
        d.line([(cx, 118), (cx + 66 * np.cos(a), 118 + 66 * np.sin(a))], fill=(20, 20, 20, 255), width=3)
    # Piano keys.
    for k in range(6):
        kx = 36 + k * 70
        d.rounded_rectangle([kx, 172, kx + 58, 236], 5, fill=(200, 198, 190, 255) if k != 2 else (170, 40, 30, 255),
                            outline=(12, 12, 12, 255), width=3)
    # Knobs.
    for kx in (540, 640):
        d.ellipse([kx - 40, 150, kx + 40, 230], fill=(26, 26, 26, 255), outline=(90, 90, 90, 255), width=4)
        d.line([(kx, 190), (kx + 26, 162)], fill=(200, 200, 200, 255), width=4)
    # Masking tape label, written in marker: the reel's identity.
    tape = Image.new("RGBA", (250, 70), (222, 208, 160, 255))
    td = ImageDraw.Draw(tape)
    td.text((16, 10), "SESSION 46", font=font("BigShoulders-Bold.ttf", 46), fill=(24, 22, 60, 255))
    tape = tape.rotate(-3, expand=True, resample=Image.BICUBIC)
    img.paste(tape, (470, 30), tape)
    img.save(os.path.join(TEX, "reel_panel.png"))
    print("wrote reel_panel.png", w, "x", h)


def paper(w, h, tint=(236, 228, 206), seed=1):
    r = np.random.default_rng(seed)
    base = np.ones((h, w, 3), np.float32) * np.array(tint, np.float32) / 255.0
    base *= (0.93 + 0.07 * periodic_noise(h, w, ((2, 1.0), (5, 0.5)), seed=seed))[..., None]
    base *= (0.97 + 0.03 * r.random((h, w)))[..., None]
    return Image.fromarray(np.clip(base * 255, 0, 255).astype(np.uint8), "RGB")


def make_file():
    w, h = 1200, 800
    img = Image.new("RGB", (w, h), (0, 0, 0))
    folder = paper(w, h, (196, 160, 104), seed=3)
    img.paste(folder, (0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.line([(w // 2, 0), (w // 2, h)], fill=(120, 92, 56, 200), width=6)       # the fold
    mono = font("DMMono-Regular.ttf", 26)
    mono_s = font("DMMono-Regular.ttf", 21)
    head = font("BigShoulders-Bold.ttf", 44)
    # Left: YOUR intake sheet.
    left = paper(520, 700, seed=4)
    ld = ImageDraw.Draw(left)
    ld.text((30, 24), "INTAKE — SUBJECT 47", font=head, fill=(30, 30, 34))
    ld.rectangle([30, 90, 190, 290], outline=(60, 60, 60), width=3)
    ld.text((52, 175), "NO PHOTO", font=mono_s, fill=(110, 110, 110))
    rows = ["ADMITTED   04:12", "SEDATION   04:40", "RESTRAINT  3 PT", "PRIOR      NONE (?)",
            "", "REACTION TO DARK:", "   ________________", "REACTION TO VOICE:", "   ________________",
            "", "CONSENT    ON FILE"]
    for i, r_ in enumerate(rows):
        ld.text((210 if i < 4 else 30, 100 + i * 42 if i < 4 else 120 + i * 42), r_, font=mono_s, fill=(34, 34, 40))
    left = left.rotate(1.2, expand=True, resample=Image.BICUBIC, fillcolor=(196, 160, 104))
    img.paste(left, (40, 40))
    # Right: Subject 46's page, stapled on, stamped.
    right = paper(520, 700, (230, 224, 204), seed=5)
    rd = ImageDraw.Draw(right)
    rd.text((30, 24), "SUBJECT 46", font=head, fill=(30, 30, 34))
    rows = ["SESSION    46", "DURATION   11 DAYS", "RESPONSE   SEVERE", "", "FINAL NOTE:",
            "  subject would not stop", "  counting. marks on the", "  wall, cell 3. subject", "  asked for the lights",
            "  to stay off."]
    for i, r_ in enumerate(rows):
        rd.text((30, 110 + i * 40), r_, font=mono_s, fill=(34, 34, 40))
    stamp = Image.new("RGBA", (440, 110), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stamp)
    sd.rectangle([4, 4, 436, 106], outline=(170, 24, 20, 230), width=8)
    sd.text((24, 12), "TERMINATED", font=font("BigShoulders-Bold.ttf", 82), fill=(170, 24, 20, 230))
    stamp = stamp.rotate(14, expand=True, resample=Image.BICUBIC)
    stamp.thumbnail((380, 200))
    right.paste(stamp, (50, 470), stamp)
    right = right.rotate(-2.5, expand=True, resample=Image.BICUBIC, fillcolor=(196, 160, 104))
    img.paste(right, (620, 34))
    d = ImageDraw.Draw(img, "RGBA")
    d.line([(660, 70), (700, 62)], fill=(150, 150, 150, 255), width=5)         # the staple
    img.save(os.path.join(TEX, "file_subject47.png"))
    print("wrote file_subject47.png", w, "x", h)


def make_log():
    w, h = 600, 800
    img = paper(w, h, seed=7)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 70], fill=(70, 62, 52))                                  # clip board top
    d.rounded_rectangle([200, 8, 400, 60], 10, fill=(150, 150, 150), outline=(60, 60, 60), width=3)
    d.text((30, 96), "OBSERVATION LOG", font=font("BigShoulders-Bold.ttf", 46), fill=(30, 30, 34))
    mono = font("DMMono-Regular.ttf", 22)
    for i, r_ in enumerate(["04:12  admitted", "04:40  sedated", "05:55  straps checked",
                            "06:10  tray set out", "06:31  lights: cell only", "06:58  stirring",
                            "", "do NOT let it see", "the file."]):
        d.text((34, 180 + i * 50), r_, font=mono, fill=(34, 34, 44))
    img.save(os.path.join(TEX, "observer_log.png"))
    print("wrote observer_log.png", w, "x", h)


def make_tray_label():
    w, h = 640, 128
    img = Image.new("RGB", (w, h), (18, 18, 20))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(40, 40, 44), width=4)
    f = font("BigShoulders-Bold.ttf", 76)
    text = "SUBJECT 47 — ISSUED"
    tw = d.textlength(text, font=f)
    x = (w - tw) / 2
    d.text((x + 2, 20), text, font=f, fill=(4, 4, 4))           # the emboss's shadow
    d.text((x, 18), text, font=f, fill=(226, 226, 222))
    img.save(os.path.join(TEX, "tray_label_issued.png"))
    print("wrote tray_label_issued.png", w, "x", h)


def make_wristband():
    w, h = 512, 128
    img = paper(w, h, (232, 232, 226), seed=9)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 90, h], fill=(190, 40, 36))
    d.text((106, 16), "SUBJ 47", font=font("BigShoulders-Bold.ttf", 56), fill=(24, 24, 28))
    d.text((300, 22), "INTAKE 3", font=font("DMMono-Regular.ttf", 26), fill=(40, 40, 46))
    d.text((300, 62), "ADM 04:12", font=font("DMMono-Regular.ttf", 26), fill=(40, 40, 46))
    img.save(os.path.join(TEX, "wristband_47.png"))
    print("wrote wristband_47.png", w, "x", h)


# ================================================================ phases 4–5 (2026-09-24, second pass)
# ⚠️ Flux was retried for the slides the same day and still returned 429, so the two "photo" slides
# are COMPOSED too: the clinical ward photo from a render of this game's own ward
# (assets_src/textures/intro/slide_ward_source.png — re-shot after the ward was dressed), the
# vintage portrait from the Lab's monitor face (lab_monitor_face.png). The Rorschach cards are
# procedural on purpose — a symmetric ink blot is exactly what numpy is good at.

LAB = os.path.join(ROOT, "game", "assets", "textures", "level_1_lab")
SRC = os.path.join(ROOT, "assets_src", "textures", "intro")


def make_cell_pad():
    """The cell bed's pad: plain, dark, worn green-grey vinyl with body stains and a split seam —
    a restraint bed, not a tufted rug (the review's complaint about gurney_intro.png)."""
    w, h = 458, 1024                                   # 0.85 x 1.9 m, gurney_intro's own aspect
    base = np.ones((h, w, 3), np.float32) * np.array([0.23, 0.26, 0.24])
    grain = blob_noise(h, w, 6.0, seed=51)
    wear = blob_noise(h, w, 90.0, seed=52)
    base *= (0.9 + 0.2 * grain)[..., None]
    base *= (0.85 + 0.3 * wear)[..., None]
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    # A body's worth of darker stain down the middle, heavier at the hips and shoulders.
    for cy, sy, amp in [(0.3, 0.12, 0.35), (0.55, 0.14, 0.4), (0.8, 0.1, 0.2)]:
        m = np.exp(-(((x - w * 0.5) / (w * 0.22)) ** 2 + ((y - h * cy) / (h * sy)) ** 2))
        base *= (1 - amp * m * (0.6 + 0.4 * grain))[..., None]
    rust = np.exp(-(((x - w * 0.18) / 30.0) ** 2 + ((y - h * 0.62) / 60.0) ** 2))
    base = base * (1 - rust[..., None] * 0.5) + rust[..., None] * np.array([0.22, 0.12, 0.05]) * 0.5
    # Edge piping and a split seam near the head.
    edge = (np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y)) < 10)
    base[edge] *= 0.6
    img = Image.fromarray(np.clip(base * 255, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    d.line([(90, 150), (170, 162), (240, 150)], fill=(18, 20, 18), width=4)
    d.line([(96, 156), (236, 156)], fill=(120, 110, 80), width=1)
    img.save(os.path.join(TEX, "cell_pad.png"))
    print("wrote cell_pad.png", w, "x", h)


def make_porcelain():
    """Grimy porcelain for the cell sink: off-white glaze, brown rust runs, grey limescale."""
    n = 512
    base = np.ones((n, n, 3), np.float32) * np.array([0.78, 0.77, 0.72])
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    base *= (0.92 + 0.08 * blob_noise(n, n, 20.0, seed=61))[..., None]
    runs = np.zeros((n, n), np.float32)
    r = np.random.default_rng(62)
    for _ in range(9):
        cx = r.uniform(0, n)
        wdt = r.uniform(3, 10)
        runs += np.exp(-((x - cx) / wdt) ** 2) * np.clip((y - r.uniform(0, n * 0.5)) / (n * 0.5), 0, 1)
    runs = np.clip(runs, 0, 1) * (0.5 + 0.5 * blob_noise(n, n, 15.0, seed=63))
    base = base * (1 - runs[..., None] * 0.55) + runs[..., None] * np.array([0.35, 0.2, 0.08]) * 0.55
    scale = blob_noise(n, n, 60.0, seed=64)
    base *= (1 - np.clip((scale - 0.6) * 2.0, 0, 1) * 0.25)[..., None]
    save(seamless(np.clip(base, 0, 1)), "porcelain_grime.png")


def make_worn_steel():
    """Worn instrument-trolley steel: brushed grey, scuffs, a little rust at the edges."""
    n = 512
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    streak = np.repeat(rng.random((n, 1)).astype(np.float32), n, axis=1)
    base = 0.44 + 0.08 * streak + 0.06 * blob_noise(n, n, 30.0, seed=71)
    arr = np.stack([base * 0.97, base, base * 1.02], axis=2)
    rust = np.clip((blob_noise(n, n, 25.0, seed=72) - 0.7) * 4.0, 0, 1)
    arr = arr * (1 - rust[..., None] * 0.6) + rust[..., None] * np.array([0.33, 0.18, 0.08]) * 0.6
    save(seamless(np.clip(arr, 0, 1)), "worn_steel.png")


def make_tag():
    """The red cardboard tag on the tray: DO NOT TOUCH (Pillow)."""
    w, h = 384, 192
    img = Image.new("RGB", (w, h), (150, 22, 18))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, w - 5, h - 5], outline=(90, 10, 8), width=5)
    d.ellipse([18, h // 2 - 14, 46, h // 2 + 14], fill=(40, 6, 6))
    f = font("BigShoulders-Bold.ttf", 70)
    d.text((70, 18), "DO NOT", font=f, fill=(238, 228, 214))
    d.text((70, 96), "TOUCH", font=f, fill=(238, 228, 214))
    img.save(os.path.join(TEX, "tag_do_not_touch.png"))
    print("wrote tag_do_not_touch.png", w, "x", h)


def make_stand_mark():
    """The painted floor mark in calibration (a decal): a worn yellow box, STAND HERE."""
    n = 512
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([20, 20, n - 21, n - 21], outline=(200, 170, 40, 235), width=26)
    f = font("BigShoulders-Bold.ttf", 96)
    for i, t in enumerate(["STAND", "HERE"]):
        tw = d.textlength(t, font=f)
        d.text(((n - tw) / 2, 130 + i * 118), t, font=f, fill=(210, 180, 50, 235))
    a = np.asarray(img).astype(np.float32)
    wear = blob_noise(n, n, 8.0, seed=81)
    a[..., 3] *= np.clip(0.35 + wear * 0.9, 0, 1)
    save(a / 255.0, "stand_here_mark.png")


def make_clock():
    """The ward's stopped wall clock: 4:12 — the admission time on your file."""
    n = 512
    img = Image.new("RGB", (n, n), (18, 16, 14))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 8, n - 9, n - 9], fill=(206, 198, 176), outline=(40, 36, 30), width=10)
    f = font("DMMono-Regular.ttf", 44)
    c = n / 2
    for k in range(1, 13):
        a = np.radians(k * 30 - 90)
        t = str(k)
        tw = d.textlength(t, font=f)
        d.text((c + np.cos(a) * 185 - tw / 2, c + np.sin(a) * 185 - 26), t, font=f, fill=(30, 28, 24))
    for k in range(60):
        a = np.radians(k * 6 - 90)
        r0 = 222 if k % 5 else 210
        d.line([(c + np.cos(a) * r0, c + np.sin(a) * r0), (c + np.cos(a) * 232, c + np.sin(a) * 232)],
               fill=(40, 36, 30), width=3 if k % 5 == 0 else 1)
    for ang, ln, wd in [(np.radians(4 * 30 + 6 - 90), 120, 12), (np.radians(12 * 6 - 90), 175, 7)]:
        d.line([(c, c), (c + np.cos(ang) * ln, c + np.sin(ang) * ln)], fill=(20, 18, 16), width=wd)
    d.ellipse([c - 12, c - 12, c + 12, c + 12], fill=(20, 18, 16))
    arr = np.asarray(img).astype(np.float32) / 255.0
    arr *= (0.8 + 0.2 * blob_noise(n, n, 40.0, seed=91))[..., None]         # yellowed, dirty glass
    save(np.clip(arr, 0, 1), "clock_stopped.png")


def make_screen_cloth():
    """A folding privacy screen's stained curtain panel (portrait, 0.55 x 1.5 m)."""
    w, h = 376, 1024
    base = np.ones((h, w, 3), np.float32) * np.array([0.62, 0.62, 0.55])
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    folds = 0.85 + 0.15 * np.sin(x / w * 2 * np.pi * 5 + 0.3 * np.sin(y / 90.0))
    base *= folds[..., None]
    stain = blob_noise(h, w, 50.0, seed=95)
    base *= (1 - np.clip((stain - 0.55) * 2.0, 0, 1)[..., None] * 0.45 * np.array([0.8, 0.9, 1.2]))
    base *= (1 - np.clip((y - h * 0.8) / (h * 0.2), 0, 1) * 0.35)[..., None]   # dirt at the hem
    save(np.clip(base, 0, 1), "privacy_screen_cloth.png")


# ---------------------------------------------------------------- the projector's slides (4:3)

SW, SH = 800, 600


def _blot(seed, red=False):
    """A Rorschach card: ink blobs grown from random seeds, mirrored about the centre line."""
    r = np.random.default_rng(seed)
    hw = SW // 2
    field = np.zeros((SH, hw), np.float32)
    y, x = np.mgrid[0:SH, 0:hw].astype(np.float32)
    # Blobs crowd the FOLD (x = 0 of this half is the card's centre line): a real card is one
    # joined stain, not two islands.
    for _ in range(int(r.integers(26, 38))):
        cx = r.uniform(0.0, hw * 0.78) * r.uniform(0.3, 1.0)
        cy = r.uniform(SH * 0.12, SH * 0.88)
        rx = r.uniform(8, 48)
        ry = r.uniform(8, 64)
        field += np.exp(-(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2))
    edge = blob_noise(SH, hw, 3.0, seed=seed + 1)
    ink = np.clip((field + 0.35 * (edge - 0.5) - 0.62) * 8.0, 0, 1)
    full = np.concatenate([ink[:, ::-1], ink], axis=1)
    paper = np.ones((SH, SW, 3), np.float32) * np.array([0.9, 0.87, 0.78])
    paper *= (0.93 + 0.07 * blob_noise(SH, SW, 40.0, seed=seed + 2))[..., None]
    col = np.array([0.06, 0.05, 0.06])
    out = paper * (1 - full[..., None]) + col * full[..., None]
    if red:
        f2 = np.zeros((SH, hw), np.float32)
        for _ in range(4):
            cx, cy = r.uniform(hw * 0.05, hw * 0.45), r.uniform(SH * 0.1, SH * 0.35)
            f2 += np.exp(-(((x - cx) / r.uniform(20, 55)) ** 2 + ((y - cy) / r.uniform(20, 60)) ** 2))
        redink = np.clip((f2 + 0.2 * (edge - 0.5) - 0.5) * 6.0, 0, 1)
        redfull = np.concatenate([redink[:, ::-1], redink], axis=1)
        out = out * (1 - redfull[..., None]) + np.array([0.55, 0.05, 0.04]) * redfull[..., None]
    return out


def _slide_frame(arr):
    """Projector look: soft vignette and a hint of dust — the screen itself adds the rest."""
    y, x = np.mgrid[0:SH, 0:SW].astype(np.float32)
    v = 1 - 0.35 * (((x - SW / 2) / (SW / 2)) ** 2 + ((y - SH / 2) / (SH / 2)) ** 2)
    arr = arr * np.clip(v, 0.4, 1)[..., None]
    dust = (rng.random((SH, SW)) > 0.9993).astype(np.float32)
    return np.clip(arr * (1 - dust[..., None] * 0.8), 0, 1)


def _photo(src, size, sepia):
    im = Image.open(src).convert("L").resize(size, Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    a = np.clip((a - 0.04) * 1.6, 0, 1)                       # archival contrast
    a = a * 0.9 + 0.1 * rng.random(a.shape).astype(np.float32)  # grain
    tint = np.array([1.0, 0.9, 0.72]) if sepia else np.array([0.95, 0.95, 0.95])
    return a[..., None] * tint


def make_slides():
    # 0 — the title card.
    img = Image.new("RGB", (SW, SH), (14, 14, 14))
    d = ImageDraw.Draw(img)
    d.text((70, 150), "CALIBRATION", font=font("BigShoulders-Bold.ttf", 120), fill=(215, 210, 195))
    d.text((74, 300), "SUBJECT 47  ·  SERIES C", font=font("DMMono-Regular.ttf", 38), fill=(170, 165, 150))
    d.text((74, 380), "DO NOT LOOK AWAY UNTIL INSTRUCTED", font=font("DMMono-Regular.ttf", 30), fill=(170, 60, 50))
    save(_slide_frame(np.asarray(img).astype(np.float32) / 255.0), "slide_0_title.png")
    # 1 — the classic black card.
    save(_slide_frame(_blot(1101)), "slide_1.png")
    # 2 — "a clinical photograph of a ward": the game's own ward, as an archive print.
    ward = _photo(os.path.join(SRC, "slide_ward_source.png"), (SW - 80, SH - 140), False)
    card = np.ones((SH, SW, 3), np.float32) * 0.92
    card[40:40 + ward.shape[0], 40:40 + ward.shape[1]] = ward
    cimg = Image.fromarray((card * 255).astype(np.uint8), "RGB")
    ImageDraw.Draw(cimg).text((44, SH - 88), "WARD 4  ·  FIG. 2", font=font("DMMono-Regular.ttf", 34), fill=(30, 30, 30))
    save(_slide_frame(np.asarray(cimg).astype(np.float32) / 255.0), "slide_2.png")
    # 3 — a vintage portrait, eyes blacked out. The face is the Lab monitor's man, cropped.
    face = Image.open(os.path.join(LAB, "lab_monitor_face.png")).convert("RGB")
    fw, fh = face.size
    crop = face.crop((int(fw * 0.30), int(fh * 0.16), int(fw * 0.66), int(fh * 0.74)))
    tmp = os.path.join(SRC, "_face_tmp.png")
    crop.save(tmp)
    por = _photo(tmp, (420, 500), True)
    os.remove(tmp)
    card = np.ones((SH, SW, 3), np.float32) * np.array([0.86, 0.82, 0.72])
    card[40:540, 190:610] = por
    pimg = Image.fromarray((card * 255).astype(np.uint8), "RGB")
    pd = ImageDraw.Draw(pimg)
    pd.rectangle([214, 238, 586, 312], fill=(6, 6, 6))            # the bar over the eyes
    pd.text((196, 548), "No. 46", font=font("DMMono-Regular.ttf", 32), fill=(40, 34, 28))
    save(_slide_frame(np.asarray(pimg).astype(np.float32) / 255.0), "slide_3.png")
    # 4 — the escalation: black and RED (the card-II shape).
    save(_slide_frame(_blot(2207, red=True)), "slide_4.png")


# ================================================================ pass 3 — GENERATED art (2026-09-24, evening)
# The user generated the surfaces and the two photo slides themselves from the prompts in
# docs/TEXTURES.md, and one flux raw survived the day's quota (the wall plaster, the second CF
# key pair). The raws live in assets_src/textures/intro/user/ and …/flux/; this pass turns each
# into the SAME file name the level already loads, so no scene or script changes.
# ⚠️ Every surface is matched to the MEAN LUMINANCE of the texture it replaces: the lighting of this
# wing was measured against those (glass contrast 10.7x, the lit ward, the blackout), and a brighter
# albedo would silently re-tune all of it.

USER = os.path.join(ROOT, "assets_src", "textures", "intro", "user")
FLUX = os.path.join(ROOT, "assets_src", "textures", "intro", "flux")


def raw(path, size=None, box=None):
    im = Image.open(path).convert("RGB")
    if box:
        w, h = im.size
        im = im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
    if size:
        im = im.resize(size, Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def match_mean(arr, name):
    """Scale `arr` so its mean luminance equals the shipped texture it replaces."""
    old = np.asarray(Image.open(os.path.join(TEX, name)).convert("RGB")).astype(np.float32) / 255.0
    target = float(old.mean())
    cur = float(arr[..., :3].mean())
    return np.clip(arr * (target / max(cur, 1e-4)), 0, 1)


def user_wall():
    # The flux plaster replaces intro_wall.png as make_wall()'s source; the wainscot, dado line,
    # floor grime and tide line are still composed so they sit at the same height in every room.
    global load
    plaster = raw(os.path.join(FLUX, "wall_plaster_d.jpg"), (1024, 1024))
    lum = plaster.mean(axis=2, keepdims=True)
    plaster = plaster * 0.6 + lum * np.array([0.93, 1.0, 0.97]) * 0.4       # desaturate a touch
    plaster = plaster * (0.78 + 0.22 * blob_noise(1024, 1024, 90.0, seed=71))[..., None]  # grime
    tmp = os.path.join(FLUX, "_plaster_tmp.png")
    Image.fromarray(np.clip(plaster * 255, 0, 255).astype(np.uint8)).save(tmp)
    real_load = load
    load = lambda name, size: raw(tmp, size) if name == "intro_wall.png" else real_load(name, size)
    try:
        old = os.path.join(TEX, "asylum_wall.png")
        before = Image.open(old).convert("RGB")
        make_wall()
        after = np.asarray(Image.open(old).convert("RGB")).astype(np.float32) / 255.0
        before_mean = float(np.asarray(before).astype(np.float32).mean() / 255.0)
        after = np.clip(after * (before_mean / max(float(after.mean()), 1e-4)), 0, 1)
        save(after, "asylum_wall.png")
    finally:
        load = real_load
        os.remove(tmp)


def user_floor():
    base = seamless(raw(os.path.join(USER, "floor.png"), (1024, 1024)))
    base = match_mean(base, "asylum_floor.png")
    save(base, "asylum_floor.png")
    # Roughness from the image's own dark (damp) patches: wet 0.3, dry 0.85.
    lum = base.mean(axis=2)
    wet = np.clip((np.percentile(lum, 35) - lum) * 9.0, 0, 1)
    rough = 0.85 - wet * 0.55
    Image.fromarray(np.clip(rough * 255, 0, 255).astype(np.uint8), "L").resize((512, 512)).save(
        os.path.join(TEX, "asylum_floor_rough.png"))
    print("wrote asylum_floor_rough.png 512 x 512 L (from the generated floor)")


def user_ceiling():
    save(match_mean(seamless(raw(os.path.join(USER, "ceiling.png"), (1024, 1024))), "asylum_ceiling.png"),
         "asylum_ceiling.png")


def user_door():
    # The raw is square with the leaf filling it; the leaf is 1.10 x 2.10 m (537 x 1024). A uniform
    # stretch would turn the wired-glass light into a slot, so the stretch is PIECEWISE: the glass
    # band (top 36 %) is stretched least, the panelled lower leaf takes the rest.
    src = raw(os.path.join(USER, "door_intro.png"), None, (0.06, 0.0, 0.98, 1.0))
    h = src.shape[0]
    cut = int(h * 0.36)
    top = Image.fromarray((src[:cut] * 255).astype(np.uint8)).resize((537, 300), Image.LANCZOS)
    bot = Image.fromarray((src[cut:] * 255).astype(np.uint8)).resize((537, 1024 - 300), Image.LANCZOS)
    out = Image.new("RGB", (537, 1024))
    out.paste(top, (0, 0))
    out.paste(bot, (0, 300))
    arr = np.asarray(out).astype(np.float32) / 255.0
    save(match_mean(arr, "asylum_door.png"), "asylum_door.png")


def user_pad():
    arr = raw(os.path.join(USER, "bed_pad.png"), (458, 1024))
    save(match_mean(arr, "cell_pad.png"), "cell_pad.png")


def user_materials():
    save(match_mean(seamless(raw(os.path.join(USER, "porcelain.png"), (512, 512))), "porcelain_grime.png"),
         "porcelain_grime.png")
    # worn_steel.png was overwritten by the user's raw of the same name (kept in USER); its match
    # target is the raw itself, i.e. unscaled — the steel was never a lighting reference.
    save(seamless(raw(os.path.join(USER, "worn_steel.png"), (1024, 1024))), "worn_steel.png")
    # The cloth's stripes are vertical: crop a 376:1024 column instead of squashing the pleats.
    cw = 376 / 1024
    arr = raw(os.path.join(USER, "screen_cloth.png"), (376, 1024), (0.5 - cw / 2, 0.0, 0.5 + cw / 2, 1.0))
    save(match_mean(arr, "privacy_screen_cloth.png"), "privacy_screen_cloth.png")


def user_slides():
    # 2 — WARD 4: the generated archival photo, cropped to the slide's photo window.
    pw, ph = SW - 80, SH - 140
    asp = pw / ph
    hh = 1.0 / asp
    ward = raw(os.path.join(USER, "ward_photo.png"), (pw, ph), (0.0, 0.5 - hh / 2, 1.0, 0.5 + hh / 2))
    lum = ward.mean(axis=2, keepdims=True)
    ward = lum * np.array([0.95, 0.95, 0.95])
    card = np.ones((SH, SW, 3), np.float32) * 0.92
    card[40:40 + ph, 40:40 + pw] = ward
    cimg = Image.fromarray((card * 255).astype(np.uint8), "RGB")
    ImageDraw.Draw(cimg).text((44, SH - 88), "WARD 4  ·  FIG. 2", font=font("DMMono-Regular.ttf", 34), fill=(30, 30, 30))
    save(_slide_frame(np.asarray(cimg).astype(np.float32) / 255.0), "slide_2.png")
    # 3 — No. 46: the generated sepia intake portrait, a 420:500 column from the centre, and the
    # bar drawn over the eyes HERE (a generator puts it in the wrong place) — see EYE_BAR.
    bw = 420 / 500
    x0, x1 = 0.5 - bw / 2, 0.5 + bw / 2
    por = raw(os.path.join(USER, "portrait_46.png"), (420, 500), (x0, 0.0, x1, 1.0))
    card = np.ones((SH, SW, 3), np.float32) * np.array([0.86, 0.82, 0.72])
    card[40:540, 190:610] = por
    pimg = Image.fromarray((card * 255).astype(np.uint8), "RGB")
    pd = ImageDraw.Draw(pimg)
    # ⚠️ Measured on the RENDERED slide, not guessed from a thumbnail of the raw — the first
    # pass put the bar at 0.51 of the photo and it landed over the MOUTH (eyes are at y 215,
    # x 335..470 in slide pixels).
    pd.rectangle(EYE_BAR, fill=(6, 6, 6))
    pd.text((196, 548), "No. 46", font=font("DMMono-Regular.ttf", 32), fill=(40, 34, 28))
    save(_slide_frame(np.asarray(pimg).astype(np.float32) / 255.0), "slide_3.png")


EYE_BAR = (318, 190, 488, 242)   # slide pixels: x0, y0, x1, y1


# ================================================================ round one, three more stimuli
# (sixth hand playtest, 2026-09-26: "we need to show slightly more objects before we say move away
# for the first time"). Flux raws in assets_src/textures/intro/flux/ (prompts.txt), CF key #1, 4 steps.
# Same archival card as slide_2 / slide_3: a print on a pale card with a typed caption.

def _card(raw_path, box, size, caption, sepia, card_rgb):
    pw, ph = size
    photo = raw(raw_path, None, box)
    im = Image.fromarray((photo * 255).astype(np.uint8)).resize((pw, ph), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    lum = a.mean(axis=2, keepdims=True)
    tint = np.array([1.0, 0.9, 0.72]) if sepia else np.array([0.95, 0.95, 0.95])
    a = np.clip((lum - 0.03) * 1.25, 0, 1) * tint
    card = np.ones((SH, SW, 3), np.float32) * np.array(card_rgb)
    x0 = (SW - pw) // 2
    card[40:40 + ph, x0:x0 + pw] = a
    cimg = Image.fromarray((card * 255).astype(np.uint8), "RGB")
    ImageDraw.Draw(cimg).text((x0 + 4, 40 + ph + 12), caption, font=font("DMMono-Regular.ttf", 32), fill=(34, 32, 28))
    return np.asarray(cimg).astype(np.float32) / 255.0


def round_one_extra():
    save(_slide_frame(_card(os.path.join(FLUX, "stim_doll_a.jpg"), (0.0, 0.0, 1.0, 1.0), (500, 500),
                            "FIG. 5", False, (0.92, 0.92, 0.9))), "slide_5.png")
    save(_slide_frame(_card(os.path.join(FLUX, "stim_chair_a.jpg"), (0.0, 0.0, 1.0, 1.0), (500, 500),
                            "FIG. 6", False, (0.92, 0.92, 0.9))), "slide_6.png")
    # ⚠️ Cropped to the skull: flux lettered a garbled title and a margin of fake text round it.
    save(_slide_frame(_card(os.path.join(FLUX, "stim_skull_a.jpg"), (0.14, 0.12, 0.98, 0.86), (500, 440),
                            "FIG. 7", True, (0.86, 0.82, 0.72))), "slide_7.png")


if __name__ == "__main__" and "--round-one" in __import__("sys").argv:
    round_one_extra()


if __name__ == "__main__" and "--user-slides" in __import__("sys").argv:
    user_slides()


if __name__ == "__main__" and "--user" in __import__("sys").argv:
    # ⚠️ user_wall() is NOT run: rendered in the wing (2026-09-24), the flux plaster's large
    # crackle plates read as crazy paving and repeat visibly down the ward; the composed wall from
    # the room's own peeling plaster matches the cold-open video better. Kept for a better raw.
    user_floor()
    user_ceiling()
    user_door()
    user_pad()
    user_materials()
    user_slides()


if __name__ == "__main__" and "--pass2" in __import__("sys").argv:
    make_cell_pad()
    make_porcelain()
    make_worn_steel()
    make_tag()
    make_stand_mark()
    make_clock()
    make_screen_cloth()
    make_slides()


# ================================================================ pass 4 — SERIES D (fourth hand playtest, 2026-09-25)
# The calibration's second round: five flux photographs of ONE new thing (a pale, emaciated figure
# with its head wrapped in bandages — never one of the game's own creatures), each frame CLOSER than
# the last, so across ~8 s it approaches the camera. Raws + prompts in assets_src/textures/intro/flux/.
# The mount darkens as it comes: FIG 1-3 are archive prints on a black card, FIG 4 a bigger print,
# FIG 5 is the whole slide — the thing has outgrown the frame. Words are drawn here (flux cannot).
# ⚠️ The raws are 4-step drafts on purpose: generate.py takes no seed, so an 8-step "re-run" of a
# chosen draft is a DIFFERENT picture, not a sharper one; at 800x600 behind a projector the drafts
# hold up (read on the rendered slides).
SERIES_D = [
    # file, crop box (x0, y0, x1, y1) of the 1024^2 raw, photo window (w, h) on the card
    ("series_d_1b.jpg", (0.0, 0.18, 1.0, 0.82), (720, 460)),   # the far end of a ward
    ("series_d_2a.jpg", (0.0, 0.16, 1.0, 0.80), (720, 460)),   # behind the curtain
    ("series_d_3a.jpg", (0.0, 0.06, 1.0, 0.70), (720, 460)),   # on the bed
    ("series_d_4b.jpg", (0.0, 0.02, 1.0, 0.72), (760, 504)),   # at the glass
    ("series_d_5b.jpg", (0.0, 0.18, 1.0, 0.93), (SW, SH)),     # at the lens
]


def _archival(arr):
    """Cold black-and-white archive print: contrast, crushed blacks, grain."""
    lum = arr.mean(axis=2)
    lum = np.clip((lum - 0.05) * 1.45, 0, 1) ** 1.1
    lum = lum * 0.9 + 0.1 * rng.random(lum.shape).astype(np.float32)
    return lum[..., None] * np.array([0.93, 0.94, 0.95])


def make_series_d():
    # 0 — the title card, the calibration title's layout (make_slides), a new series.
    img = Image.new("RGB", (SW, SH), (10, 10, 10))
    d = ImageDraw.Draw(img)
    d.text((70, 150), "SERIES D", font=font("BigShoulders-Bold.ttf", 120), fill=(215, 210, 195))
    d.text((74, 300), "SUBJECT 47  ·  FIVE EXPOSURES", font=font("DMMono-Regular.ttf", 38), fill=(170, 165, 150))
    d.text((74, 380), "REMAIN SEATED", font=font("DMMono-Regular.ttf", 30), fill=(170, 60, 50))
    save(_slide_frame(np.asarray(img).astype(np.float32) / 255.0), "slide_d0_title.png")
    for k, (name, box, (pw, ph)) in enumerate(SERIES_D):
        n = k + 1
        photo = _archival(raw(os.path.join(FLUX, name), (pw, ph), box))
        card = np.ones((SH, SW, 3), np.float32) * 0.035
        x0 = (SW - pw) // 2
        y0 = 0 if ph >= SH else (30 if ph <= 460 else 14)
        card[y0:y0 + ph, x0:x0 + pw] = photo
        cimg = Image.fromarray((card * 255).astype(np.uint8), "RGB")
        cd = ImageDraw.Draw(cimg)
        label = "SERIES D  ·  FIG. %d" % n
        f = font("DMMono-Regular.ttf", 30 if ph < SH else 24)
        if ph < SH:
            cd.text((x0 + 4, y0 + ph + 16), label, font=f, fill=(170, 166, 156))
        else:
            # Full bleed: the label burned into the print's corner, like an archive stamp.
            cd.rectangle([22, SH - 58, 22 + 330, SH - 20], fill=(8, 8, 8))
            cd.text((32, SH - 54), label, font=f, fill=(190, 186, 176))
        save(_slide_frame(np.asarray(cimg).astype(np.float32) / 255.0), "slide_d%d.png" % n)


def make_patient_cutout():
    """The patient at the airlock hatch: a real RGBA cutout — his face out of the black. Alpha is the
    photo's own luminance (the background is black) under an oval feather, so no rectangle can
    show behind the bars even when the hatch light catches the quad's edge."""
    a = raw(os.path.join(FLUX, "patient_b.jpg"), (512, 512))
    lum = a.mean(axis=2)
    y, x = np.mgrid[0:512, 0:512].astype(np.float32)
    oval = np.clip(1.0 - (((x - 256) / 250) ** 2 + ((y - 250) / 262) ** 2), 0, 1)
    oval = np.clip(oval * 3.0, 0, 1)
    # ⚠️ The BACKGROUND is the dark reachable from the border — not every dark pixel: a luminance
    # key alone punched the open mouth and the eye sockets out of the face (first render).
    dark = lum < 0.07
    bg = np.zeros_like(dark)
    bg[0, :] = dark[0, :]; bg[-1, :] = dark[-1, :]; bg[:, 0] = dark[:, 0]; bg[:, -1] = dark[:, -1]
    while True:
        grown = bg.copy()
        grown[1:, :] |= bg[:-1, :]; grown[:-1, :] |= bg[1:, :]
        grown[:, 1:] |= bg[:, :-1]; grown[:, :-1] |= bg[:, 1:]
        grown &= dark
        if (grown == bg).all():
            break
        bg = grown
    soft = np.asarray(Image.fromarray((~bg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))) / 255.0
    alpha = soft.astype(np.float32) * oval
    gray = _archival(a) * np.array([1.04, 1.0, 0.94])      # a touch warm: bulb-lit skin
    save(np.concatenate([np.clip(gray, 0, 1), alpha[..., None]], axis=2), "patient_hatch.png")


if __name__ == "__main__" and "--series-d" in __import__("sys").argv:
    make_series_d()
    make_patient_cutout()


if __name__ == "__main__" and "--pass2" not in __import__("sys").argv and "--series-d" not in __import__("sys").argv \
        and not any(a.startswith("--user") for a in __import__("sys").argv) and "--round-one" not in __import__("sys").argv:
    make_wall()
    make_floor()
    make_ceiling()
    make_door()
    make_tally()
    make_reel_panel()
    make_file()
    make_log()
    make_tray_label()
    make_wristband()
