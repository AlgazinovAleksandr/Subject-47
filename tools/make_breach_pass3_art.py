#!/usr/bin/env python3
"""Level 6 approach, pass 3 (2026-09-23): the dead technician's eye pair, the cell chamber's bodies,
and every dark-room surface that carries words.

Two kinds, as in tools/make_breach_approach_art.py (flux cannot be trusted with a letter):

  * BODIES from flux raws in assets_src/textures/level_6_breach/approach/pass3/ (prompts in
    prompts.txt there). Each raw is a figure on a WHITE backdrop, so alpha is keyed by a FLOOD FILL
    of near-white from the border, never by luminance: a luminance key would eat a pale face.
    Reachability-limited, like tools/flatten_alpha_checker.py, so a pale patch INSIDE the silhouette
    survives. Flux paints blood candy-red; it is pulled toward dried maroon.
  * PILLOW TEXT: the vial dose strip, the clipboard, the jar labels, the junction plate, the tray
    cloth with its one empty outline, the scored armrest top.

⭐ THE EYE PAIR (the user's rule: the two images must match EXACTLY except the eyes). The raw is
generated with the eyes OPEN, and the CLOSED variant is that same image with lids painted over the
two eye regions: skin sampled from the socket around each eye, a lash line, a crease. Painting a
closed lid is the easy direction; painting a convincing open eye is not. The tool ASSERTS that
the two outputs differ only inside the two eye boxes.

Deterministic. Needs Pillow — use the image pack's venv:
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_breach_pass3_art.py
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import math
import os
import random
from collections import deque

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets_src", "textures", "level_6_breach", "approach", "pass3")
RAW_OLD = os.path.join(ROOT, "assets_src", "textures", "level_6_breach", "approach")
OUT = os.path.join(ROOT, "game", "assets", "textures", "level_6_breach")
SUP = "/System/Library/Fonts/Supplemental/"
F_SIGN = SUP + "DIN Condensed Bold.ttf"
F_MONO = SUP + "Andale Mono.ttf"
F_BOLD = SUP + "Arial Bold.ttf"
F_HAND = SUP + "Courier New Bold.ttf"

rng = random.Random(6233)


def font(path, size):
    return ImageFont.truetype(path, size)


def check_cutout(img, name):
    a = img.getchannel("A")
    hist = a.histogram()
    total = img.width * img.height
    clear = hist[0] / total
    solid = sum(hist[180:]) / total
    border = [a.getpixel((x, 0)) for x in range(img.width)] + \
             [a.getpixel((x, img.height - 1)) for x in range(img.width)] + \
             [a.getpixel((0, y)) for y in range(img.height)] + \
             [a.getpixel((img.width - 1, y)) for y in range(img.height)]
    assert max(border) < 40, f"{name}: opaque pixels on the border — not a cutout"
    assert solid > 0.05, f"{name}: almost nothing opaque"
    # ⚠️ The histogram, not just `file` (CLAUDE.md): a keyed body must not carry a pale halo.
    rgb = img.convert("RGB")
    px = rgb.load()
    ap = a.load()
    pale = sum(1 for y in range(0, img.height, 2) for x in range(0, img.width, 2)
               if ap[x, y] > 128 and min(px[x, y]) > 235)
    opaque = sum(1 for y in range(0, img.height, 2) for x in range(0, img.width, 2) if ap[x, y] > 128)
    frac = pale / max(1, opaque)
    assert frac < 0.03, f"{name}: {frac:.1%} of the opaque texels are near-white — the key leaked"
    print(f"{name:40s} {img.width}x{img.height} RGBA  clear {clear:5.1%}  opaque {solid:5.1%}  "
          f"near-white {frac:4.1%}")


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    if img.mode == "RGBA":
        check_cutout(img, name)
    else:
        print(f"{name:40s} {img.width}x{img.height} {img.mode}")


# ---------------------------------------------------------------- white-key by flood fill

def _is_bg(p, lo):
    r, g, b = p[0], p[1], p[2]
    return min(r, g, b) >= lo and (max(r, g, b) - min(r, g, b)) < 34


def key_white(img, lo=205, keep_largest=False, erase=(), erase_poly=()):
    """Alpha = NOT(near-white pixels reachable from the border). Returns RGBA."""
    img = img.convert("RGB")
    w, h = img.size
    px = img.load()
    bg = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if _is_bg(px[x, y], lo):
                bg[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if _is_bg(px[x, y], lo) and not bg[y * w + x]:
                bg[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny * w + nx] and _is_bg(px[nx, ny], lo):
                bg[ny * w + nx] = 1
                q.append((nx, ny))
    alpha = Image.new("L", (w, h))
    alpha.putdata([0 if v else 255 for v in bg])
    for box in erase:
        ImageDraw.Draw(alpha).rectangle(box, fill=0)
    for poly in erase_poly:
        ImageDraw.Draw(alpha).polygon(poly, fill=0)
    if keep_largest:
        alpha = _largest_component(alpha)
    # Choke 1 px and feather, so no white fringe survives the edge.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.0))
    rgba = img.copy()
    rgba.putalpha(alpha)
    return rgba


def key_shadow(img, lo=120, protect=(), erase=()):
    """A figure lying on a white floor, with flux's soft pale shadow round it. The flood region is
    everything backdrop-coloured reachable from the border; in it, near-white goes fully clear and
    the grey halo becomes a DARK contact shadow (black, alpha from how dark it was), so on the
    game's dark floor the body sits in a shadow instead of wearing a pale outline. `protect`
    boxes are never flooded (white latex gloves and steel are backdrop-coloured too)."""
    img = img.convert("RGB")
    w, h = img.size
    px = img.load()
    guard = bytearray(w * h)
    for x0, y0, x1, y1 in protect:
        for y in range(max(0, y0), min(h, y1)):
            for x in range(max(0, x0), min(w, x1)):
                guard[y * w + x] = 1
    bg = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if _is_bg(px[x, y], lo) and not guard[y * w + x]:
                bg[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if _is_bg(px[x, y], lo) and not bg[y * w + x] and not guard[y * w + x]:
                bg[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            k = ny * w + nx
            if 0 <= nx < w and 0 <= ny < h and not bg[k] and not guard[k] and _is_bg(px[nx, ny], lo):
                bg[k] = 1
                q.append((nx, ny))
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if bg[y * w + x]:
                lum = max(r, g, b)
                a = 0 if lum >= 236 else int(min(150, (236 - lum) * 1.5))
                op[x, y] = (6, 6, 7, a)
            elif guard[y * w + x] and _is_bg((r, g, b), 216):
                op[x, y] = (0, 0, 0, 0)       # inside a protect box, the white floor still keys
            else:
                op[x, y] = (r, g, b, 255)
    # Second pass: flux's halo is not one flood region — JPEG chroma and the blood's pink fringe
    # (sat 40-60) wall pockets of it off. Anything still pale and grey-ish outside a protect box is
    # halo, never body, on these two raws (the one exception, a white collar, reads fine dark).
    for y in range(h):
        for x in range(w):
            r, g, b, a0 = op[x, y]
            if a0 > 0 and not guard[y * w + x] and max(r, g, b) > 84 and max(r, g, b) - min(r, g, b) < 34:
                op[x, y] = (6, 6, 7, 70)
    for box in erase:
        ImageDraw.Draw(out).rectangle(box, fill=(0, 0, 0, 0))
    a = out.getchannel("A").filter(ImageFilter.GaussianBlur(0.8))
    out.putalpha(a)
    return out


def _largest_component(alpha):
    w, h = alpha.size
    a = alpha.load()
    seen = bytearray(w * h)
    best = []
    for sy in range(0, h):
        for sx in range(0, w):
            if a[sx, sy] < 128 or seen[sy * w + sx]:
                continue
            comp = []
            q = deque([(sx, sy)])
            seen[sy * w + sx] = 1
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and a[nx, ny] >= 128:
                        seen[ny * w + nx] = 1
                        q.append((nx, ny))
            if len(comp) > len(best):
                best = comp
    out = Image.new("L", (w, h), 0)
    o = out.load()
    for x, y in best:
        o[x, y] = 255
    return out


def dry_blood(rgba, strength=1.0):
    """Flux paints blood candy-red. Pull strongly red, saturated pixels toward dried maroon."""
    r, g, b, a = rgba.split()
    rp, gp, bp = r.load(), g.load(), b.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            R, G, B = rp[x, y], gp[x, y], bp[x, y]
            red = R - max(G, B)
            if red > 50:
                k = min(1.0, (red - 50) / 90.0) * strength
                rp[x, y] = int(R * (1 - 0.42 * k))
                gp[x, y] = int(G * (1 - 0.35 * k))
                bp[x, y] = int(B * (1 - 0.30 * k))
    return Image.merge("RGBA", (r, g, b, a))


def crop_to_alpha(rgba, margin=10, max_side=1024):
    bbox = rgba.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    if bbox:
        bbox = (max(0, bbox[0] - margin), max(0, bbox[1] - margin),
                min(rgba.width, bbox[2] + margin), min(rgba.height, bbox[3] + margin))
        rgba = rgba.crop(bbox)
    if max(rgba.size) > max_side:
        k = max_side / max(rgba.size)
        rgba = rgba.resize((int(rgba.width * k), int(rgba.height * k)), Image.LANCZOS)
    a = rgba.getchannel("A")
    ImageDraw.Draw(a).rectangle([0, 0, a.width - 1, a.height - 1], outline=0, width=2)
    rgba.putalpha(a)
    return rgba, bbox


# ---------------------------------------------------------------- the technician's eye pair

# Measured on technician_open_raw_d.jpg (1024², the eyes located by their sclera): centre,
# half-length along the eye, half-height across it. The face is tilted, so the eyes' own axis is
# the line between them, ~-48° in image space.
# (Refit after the first paint: at 15 x 12 px the lid swallowed the socket and read as a cracked
# ball. The openings are ~20 x 13 px, on the line between the two centroids, -49.5°.)
EYES = [((475.5, 261.6), 10.5, 6.8), ((523.2, 205.7), 10.5, 6.6)]
EYE_AXIS = math.atan2(205.7 - 261.6, 523.2 - 475.5)


def _ellipse_mask(size, centre, a, b, ang, grow=0.0):
    w, h = size
    m = Image.new("L", size, 0)
    mp = m.load()
    cx, cy = centre
    ca, sa = math.cos(ang), math.sin(ang)
    x0, x1 = int(cx - a - 6), int(cx + a + 6)
    y0, y1 = int(cy - a - 6), int(cy + a + 6)
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            dx, dy = x - cx, y - cy
            u = dx * ca + dy * sa
            v = -dx * sa + dy * ca
            d = (u / (a + grow)) ** 2 + (v / (b + grow)) ** 2
            if d <= 1.0:
                mp[x, y] = 255
    return m


def paint_closed_eyes(img):
    """Same image, eyes shut: sunken lids sampled from each socket, a lash line and a crease."""
    out = img.copy().convert("RGB")
    px = img.convert("RGB").load()
    r = random.Random(47)
    for (cx, cy), a, b in EYES:
        # skin tone of the socket: a ring just outside the eye, skipping blood and highlights
        ring = []
        for k in range(360):
            t = math.radians(k)
            for rad in (a + 3.0, a + 5.0, a + 7.0):
                x = int(cx + math.cos(t) * rad)
                y = int(cy + math.sin(t) * rad * (b / a))
                R, G, B = px[x, y]
                if R - max(G, B) < 45 and 60 < R < 235:
                    ring.append((R, G, B))
        ring.sort(key=lambda c: sum(c))
        mid = ring[len(ring) // 3: 2 * len(ring) // 3] or ring
        base = tuple(sum(c[i] for c in mid) // len(mid) for i in range(3))
        lid = Image.new("RGB", img.size, base)
        # a soft vertical gradient ACROSS the eye: the upper lid is a touch lighter where it
        # bulges over the eyeball, darker toward the lash line
        lp = lid.load()
        ca, sa = math.cos(EYE_AXIS), math.sin(EYE_AXIS)
        for y in range(int(cy - a - 8), int(cy + a + 8)):
            for x in range(int(cx - a - 8), int(cx + a + 8)):
                dx, dy = x - cx, y - cy
                v = -dx * sa + dy * ca           # across the eye; negative = upper lid
                u = dx * ca + dy * sa
                shade = 1.0 - 0.14 * max(0.0, (v + b * 0.1) / b) - 0.06 * (u / a) ** 2
                n = r.uniform(-5, 5)
                lp[x, y] = tuple(max(0, min(255, int(c * shade + n))) for c in base)
        mask = _ellipse_mask(img.size, (cx, cy), a, b, EYE_AXIS, grow=3.0).filter(ImageFilter.GaussianBlur(1.4))
        out = Image.composite(lid.filter(ImageFilter.GaussianBlur(0.6)), out, mask)
        lines = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lines)
        # the lash line: closed lids meet a little BELOW the centre, curving down at the middle
        pts = []
        for i in range(-10, 11):
            u = a * 0.86 * i / 10.0
            v = b * 0.12 + b * 0.16 * (1 - (i / 10.0) ** 2)
            pts.append((cx + u * ca - v * sa, cy + u * sa + v * ca))
        d.line(pts, fill=(46, 30, 28, 240), width=2)
        # the crease: a faint shadow arc across the upper lid
        pts = []
        for i in range(-8, 9):
            u = a * 0.72 * i / 8.0
            v = -b * 0.46 - b * 0.12 * (1 - (i / 8.0) ** 2)
            pts.append((cx + u * ca - v * sa, cy + u * sa + v * ca))
        d.line(pts, fill=tuple(int(c * 0.7) for c in base) + (150,), width=1)
        lines = lines.filter(ImageFilter.GaussianBlur(0.5))
        out = Image.alpha_composite(out.convert("RGBA"), lines).convert("RGB")
    return out


def eye_boxes(pad=6):
    boxes = []
    for (cx, cy), a, b in EYES:
        boxes.append((int(cx - a - pad), int(cy - a - pad), int(cx + a + pad), int(cy + a + pad)))
    return boxes


def technician():
    raw = Image.open(os.path.join(RAW, "technician_open_raw_d.jpg")).convert("RGB")
    closed = paint_closed_eyes(raw)
    # One alpha for BOTH, keyed on the open image, so the silhouettes are identical by construction.
    # lo=100, not 200: the raw carries a soft grey corner shadow (114-210, low saturation) down his
    # right side, which a white key kept as a pale strip. Reachability still protects the navy suit
    # (it is darker than 100 wherever it borders the shadow) and the face (saturated skin).
    # The corner wall's shadow core (40-70, the same values as his navy suit) cannot be separated
    # by colour, so it is cut by hand: a polygon hugging the right edge of his sleeve and hip,
    # traced on the raw with 2-5 px of margin (tech_poly check image, 2026-09-23).
    # The second render showed a pale sliver of floor under his hip, so the cut now also follows the
    # underside of his leg (x 500..862, 8 px below the contour traced on the raw's 50 px grid).
    keyed = key_white(raw, lo=100, keep_largest=True, erase_poly=[[
        (878, 330), (1024, 330), (1024, 1024), (500, 1024), (500, 903), (600, 883), (700, 860),
        (790, 812), (845, 768), (862, 738), (872, 700), (868, 600), (880, 520), (880, 440)]])
    alpha = keyed.getchannel("A")
    pair = []
    for src in (raw, closed):
        rgba = src.copy()
        rgba.putalpha(alpha)
        rgba = dry_blood(rgba, 0.8)
        pair.append(rgba)
    # the same crop for both
    bbox = alpha.point(lambda v: 255 if v > 12 else 0).getbbox()
    m = 10
    bbox = (max(0, bbox[0] - m), max(0, bbox[1] - m), min(raw.width, bbox[2] + m), min(raw.height, bbox[3] + m))
    outs = []
    for rgba in pair:
        c = rgba.crop(bbox)
        a = c.getchannel("A")
        ImageDraw.Draw(a).rectangle([0, 0, a.width - 1, a.height - 1], outline=0, width=2)
        c.putalpha(a)
        outs.append(c)
    open_img, closed_img = outs
    # ⚠️ THE RULE: the two differ ONLY inside the eye boxes.
    diff = ImageChops.difference(open_img, closed_img).convert("L")
    boxes = [(x0 - bbox[0], y0 - bbox[1], x1 - bbox[0], y1 - bbox[1]) for x0, y0, x1, y1 in eye_boxes()]
    dp = diff.load()
    outside = 0
    inside = 0
    for y in range(diff.height):
        for x in range(diff.width):
            if dp[x, y] > 2:
                if any(b[0] <= x <= b[2] and b[1] <= y <= b[3] for b in boxes):
                    inside += 1
                else:
                    outside += 1
    assert outside == 0, f"technician pair differs OUTSIDE the eyes at {outside} texels"
    assert inside > 200, f"technician pair barely differs at the eyes ({inside} texels)"
    print(f"technician pair: {inside} texels differ, all inside the two eye boxes {boxes}; 0 outside")
    save(closed_img, "approach_technician_closed.png")
    save(open_img, "approach_technician_open.png")
    # A 4x close-up of both faces for a human to judge, kept out of the game tree.
    face = (min(b[0] for b in boxes) - 40, min(b[1] for b in boxes) - 40,
            max(b[2] for b in boxes) + 40, max(b[3] for b in boxes) + 40)
    sheet = Image.new("RGB", ((face[2] - face[0]) * 8, (face[3] - face[1]) * 4), (40, 40, 40))
    for i, img in enumerate((closed_img, open_img)):
        f = img.crop(face).resize(((face[2] - face[0]) * 4, (face[3] - face[1]) * 4), Image.LANCZOS)
        sheet.paste(f, (i * f.width, 0), f)
    sheet.save(os.path.join(RAW, "technician_pair_faces_check.png"))
    # where the hands are, in UV (the level parks the handle there)
    hand = (600, 700)
    print(f"technician hand UV ≈ ({(hand[0] - bbox[0]) / (bbox[2] - bbox[0]):.3f}, "
          f"{(hand[1] - bbox[1]) / (bbox[3] - bbox[1]):.3f}); crop {bbox}")


def bodies():
    raw = Image.open(os.path.join(RAW, "body_facedown_raw_a.jpg")).convert("RGB")
    # the three latex gloves and the stethoscope, traced on the raw's 100 px grid
    rgba = dry_blood(key_shadow(raw, lo=120, protect=[(468, 178, 562, 282), (100, 258, 228, 362),
                                                     (106, 638, 218, 732), (404, 222, 478, 310)]), 1.0)
    rgba, _ = crop_to_alpha(rgba)
    save(rgba, "approach_body_facedown.png")
    raw = Image.open(os.path.join(RAW, "body_side_raw_b.jpg")).convert("RGB")
    # ⚠️ flux gave this guard THREE boots; the middle one is erased (x 858.., y 505..572).
    rgba = dry_blood(key_shadow(raw, lo=120, erase=[(858, 506, 1000, 572)]), 1.0)
    rgba, _ = crop_to_alpha(rgba)
    save(rgba, "approach_body_guard.png")


# ---------------------------------------------------------------- blood pool (a keyed decal)

def blood_pool():
    img = Image.open(os.path.join(RAW_OLD, "residue_pool_raw.jpg")).convert("RGB")
    lum = img.convert("L")
    alpha = lum.point(lambda v: max(0, min(255, int((255 - v - 40) * 255 / 160))))
    shade = lum.point(lambda v: int(30 + v * 0.45))
    r = shade.point(lambda v: int(96 * v / 255 + 0.5 * max(0, v - 150)))
    g = shade.point(lambda v: int(18 * v / 255 + 0.4 * max(0, v - 150)))
    b = shade.point(lambda v: int(14 * v / 255 + 0.4 * max(0, v - 150)))
    rgba = Image.merge("RGBA", (r, g, b, alpha.filter(ImageFilter.GaussianBlur(0.8))))
    rgba, _ = crop_to_alpha(rgba, 12, 768)
    save(rgba, "approach_blood_pool.png")


# ---------------------------------------------------------------- dark-room text surfaces

def noise_layer(w, h, amount, seed, blur=0.0):
    r = random.Random(seed)
    img = Image.new("L", (w, h))
    img.putdata([128 + int(r.uniform(-amount, amount)) for _ in range(w * h)])
    return img.filter(ImageFilter.GaussianBlur(blur)) if blur else img


def grime(img, amount=18, seed=1):
    n = noise_layer(img.width, img.height, amount, seed, 1.2).point(lambda v: min(255, v + 110))
    return Image.blend(img, ImageChops.multiply(img, n.convert("RGB")), 0.6)


def dose_strip():
    """The label rail under a row of vials: the dose climbs by doubling, then stops being a dose."""
    w, h = 1600, 120
    img = Image.new("RGB", (w, h), (206, 200, 182))
    d = ImageDraw.Draw(img)
    f = font(F_MONO, 34)
    small = font(F_MONO, 20)
    doses = ["0.5", "1", "2", "4", "8", "16", "32", "64"]
    cell = w / len(doses)
    for i, dose in enumerate(doses):
        x = int(i * cell)
        d.line([(x, 0), (x, h)], fill=(90, 86, 78), width=2)
        d.text((x + 16, 18), f"{dose} mg", font=f, fill=(34, 32, 30))
        d.text((x + 16, 74), f"12-{chr(65 + i)}  /  DAY {i + 1}", font=small, fill=(70, 66, 60))
    # the last two cells are struck through by hand, and the last carries no dose at all
    for i in (6, 7):
        x = int(i * cell)
        d.line([(x + 10, 44), (x + cell - 12, 30)], fill=(128, 22, 18), width=5)
    d.text((int(7 * cell) + 60, 64), "—", font=font(F_HAND, 44), fill=(128, 22, 18))
    save(grime(img, amount=22, seed=61), "approach_dose_strip.png")


def clipboard():
    w, h = 720, 1000
    img = Image.new("RGB", (w, h), (214, 208, 190))
    d = ImageDraw.Draw(img)
    d.text((40, 36), "EXPOSURE LOG  —  SUBJECT 12", font=font(F_BOLD, 38), fill=(40, 38, 34))
    d.text((40, 92), "WING C  /  ROOM 4  /  DARK TRIAL", font=font(F_MONO, 26), fill=(80, 76, 70))
    d.line([(36, 136), (w - 36, 136)], fill=(90, 86, 78), width=3)
    r = random.Random(62)
    mono = font(F_MONO, 26)
    y = 160
    for day in range(1, 10):
        d.text((40, y), f"DAY {day}", font=mono, fill=(40, 38, 34))
        # tallies: how many minutes it would stay in the dark before it stopped moving
        groups = min(day + 1, 7)
        x = 190
        for g in range(groups):
            strokes = 5 if g < groups - 1 else r.randint(1, 4)
            for s in range(min(strokes, 4)):
                xx = x + s * 12 + r.randint(-2, 2)
                d.line([(xx, y + 2), (xx + r.randint(-3, 3), y + 30)], fill=(30, 30, 40), width=3)
            if strokes == 5:
                d.line([(x - 6, y + 26), (x + 44, y + 6)], fill=(30, 30, 40), width=3)
            x += 66
        y += 78
    # the last line is not a tally
    d.text((40, y + 10), "DAY 10  it does not need the dark", font=font(F_HAND, 30), fill=(128, 22, 18))
    save(grime(img, amount=24, seed=63), "approach_clipboard_log.png")


def jar_label():
    w, h = 400, 240
    img = Image.new("RGB", (w, h), (196, 188, 160))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 6, w - 7, h - 7], outline=(80, 70, 60), width=4)
    d.text((24, 22), "12-C", font=font(F_SIGN, 96), fill=(40, 34, 30))
    d.text((24, 140), "TISSUE  /  DAY 9", font=font(F_MONO, 30), fill=(60, 54, 48))
    d.text((24, 184), "DO NOT OPEN", font=font(F_MONO, 26), fill=(128, 22, 18))
    save(grime(img, amount=26, seed=64), "approach_jar_label.png")


def junction_plate():
    w, h = 480, 200
    img = Image.new("RGB", (w, h), (196, 160, 40))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(24, 22, 20), width=8)
    d.polygon([(40, 150), (80, 40), (96, 100), (130, 20), (104, 140), (88, 90)], fill=(24, 22, 20))
    d.text((160, 32), "JUNCTION 4", font=font(F_SIGN, 76), fill=(24, 22, 20))
    d.text((162, 122), "380 V  ·  ROOM 4", font=font(F_MONO, 30), fill=(24, 22, 20))
    save(grime(img, amount=20, seed=65), "approach_junction_plate.png")


def tray_cloth():
    """The instrument cloth: every tool laid in order and outlined, and ONE outline empty."""
    w, h = 1024, 512
    img = Image.new("RGB", (w, h), (92, 104, 96))       # surgical green, stained
    d = ImageDraw.Draw(img)
    for i in range(9):
        x = 70 + i * 104
        length = 200 + (i % 3) * 60
        y0 = (h - length) // 2
        d.rounded_rectangle([x, y0, x + 34, y0 + length], radius=14, outline=(60, 70, 64), width=4)
    # the gap: the 6th outline is traced darker, where something lay for a long time
    x = 70 + 5 * 104
    d.rounded_rectangle([x - 2, (h - 320) // 2 - 2, x + 36, (h + 320) // 2 + 2], radius=14,
                        outline=(40, 46, 42), width=6)
    img = grime(img, amount=30, seed=66)
    stain = noise_layer(w, h, 127, 67, 18).point(lambda v: 255 if v > 150 else 0).filter(ImageFilter.GaussianBlur(10))
    img = Image.composite(Image.new("RGB", (w, h), (64, 36, 30)), img, stain.point(lambda v: v // 3))
    save(img, "approach_tray_cloth.png")


def armrest_scores():
    """A worn armrest top, scored by fingernails along its length."""
    w, h = 1024, 160
    base = noise_layer(w, h, 20, 68, 1.4).point(lambda v: int(v * 0.35 + 30))
    img = Image.merge("RGB", (base.point(lambda v: v + 8), base.point(lambda v: v + 2), base))
    d = ImageDraw.Draw(img)
    r = random.Random(69)
    for k in range(34):
        x = r.randint(100, w - 80)
        y = r.randint(20, h - 40)
        ln = r.randint(40, 180)
        for s in range(r.choice((3, 4))):
            yy = y + s * 9
            d.line([(x, yy + 1), (x + ln, yy + r.randint(-4, 4) + 1)], fill=(10, 8, 8), width=3)
            d.line([(x, yy), (x + ln, yy + r.randint(-4, 4))], fill=(150, 140, 128), width=2)
    save(img, "approach_armrest_scores.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    technician()
    bodies()
    blood_pool()
    dose_strip()
    clipboard()
    jar_label()
    junction_plate()
    tray_cloth()
    armrest_scores()


if __name__ == "__main__":
    main()
