#!/usr/bin/env python3
"""Level 6 approach, pass 4 (2026-09-23/24): the FUSED technician, from the user's generated art.

The user on the pass-3 technician: "This looks way too unrealistic … it looks very 2d now", and after
the first pass-4 renders: "I do not see the wheel very clearly in its arms. Can you make it more
realistic and make it even more adjacent to the wall?" The user then generated the art themselves
(flux-1-schnell, 8 steps; prompts in `assets_src/…/approach/user/prompts.txt`) and chose:

  * `fused_technician_closed_D.jpg` — THE BASE. A realistic dead technician pressed into the wall,
    roots spread over and round him, everything below the waist swallowed, eyes CLOSED, both hands
    curled at the chest and belly in an EMPTY grip (the 3D valve wheel goes between them in-game).
    Variants A, B, C and E are kept as raws and not used.
  * `growth_spread.jpg` — branching veins: the roots decal on the wall behind him.
  * `growth_flesh_tile.jpg` — the biomass surface for the 3D tendrils and the ceiling-drop cocoon.
All three are on a flat bright green, keyed here.

Outputs (in `game/assets/textures/level_6_breach/`):
  approach_fused_closed.png   D keyed (RGBA 1024², full frame so the in-game UV maths is the art's)
  approach_fused_open.png     the same with OPEN, bloodshot eyes composited in; the tool ASSERTS the
                              pair differs only inside the two eye boxes
  approach_fused_height.png   the bas-relief's height map (16-bit in R/G; B = dilated alpha)
  approach_fused_normal.png   a normal map from the height map's fine detail
  approach_growth_spread.png  the veins keyed, faded radially (the branches run off the frame)
  approach_growth_flesh.png   the biomass made seamless (offset and blend)

⭐ THE EYES. D has its eyes closed, so the OPEN eyes are PAINTED over them (`_paint_eye`), at 6x and
downsampled, in colours taken from the skin round each eye. (Transplanting the staring eyes of the
pass-4 raw was tried first: lit for another face, they read as pasted-on even colour-matched.)

⭐ THE KEY. Greenness k = G − max(R, B). Clear background is k > 70, OR green-dominant for its own
brightness (k / G > 0.33), which also takes the growth's dark-green shadows on the backdrop. The band
within 4 px of it gets a fractional alpha from k and is UNMIXED against the measured background colour;
then green-dominant and olive pixels are de-spilled to the mean of red and blue. The relief is drawn with alpha scissor at 0.5, so the tool
checks the pixels that survive the scissor at the edge for green.

Deterministic. Needs Pillow and numpy — use the image pack's venv:
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_breach_pass4_art.py
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_breach_pass3_art as p3  # noqa: E402

ROOT = p3.ROOT
USER = os.path.join(ROOT, "assets_src", "textures", "level_6_breach", "approach", "user")
OUT = p3.OUT

# Measured on fused_technician_closed_D.jpg (1024²) on a 5 px grid. `breach_approach.gd` carries the
# same numbers (TECH_ART_*); change both together.
D_EYES = [((491.0, 204.5), 12.5, 6.5), ((545.0, 203.0), 14.5, 7.0)]     # centre, half-length, half-height
EYE_PAD = 10


# ---------------------------------------------------------------- the green key

def key_green(img, band_px=4, k_clear=70.0, k_fg=-40.0):
    """RGBA from an RGB image on a flat bright green. See the module docstring."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    k = g - np.maximum(r, b)
    # CLEAR = green-dominant relative to its own brightness, so the growth's dark-green SHADOWS on the
    # green backdrop are keyed too (at a fixed k threshold they survived as an olive outline)
    score = k / (g + 10.0)
    clear = (k > k_clear) | ((score > 0.33) & (k > 18.0))
    bright = k > k_clear
    bg = a[bright].mean(axis=0)
    k_bg = float(np.median(k[bright]))
    # the band: within band_px of clear background, not clear itself
    m = Image.fromarray((clear * 255).astype(np.uint8))
    near = np.asarray(m.filter(ImageFilter.MaxFilter(band_px * 2 + 1))) > 0
    band = near & ~clear
    alpha = np.ones(k.shape, np.float32)
    alpha[clear] = 0.0
    frac = np.clip((k_bg - k) / (k_bg - k_fg), 0.0, 1.0)
    alpha[band] = frac[band]
    # unmix the band against the background: C = aF + (1-a)B
    out = a.copy()
    ab = np.maximum(alpha[band], 0.25)[:, None]
    out[band] = np.clip((a[band] - (1.0 - ab) * bg[None, :]) / ab, 0, 255)
    # de-spill: nothing opaque may be greener than its own red/blue
    rr, gg, bb = out[..., 0], out[..., 1], out[..., 2]
    lim = np.maximum(rr, bb)
    # where green is the top channel, clamp it to the MEAN of red and blue, not the max: (60, 60, 20)
    # olive becomes (60, 40, 20) brown instead of staying khaki
    lim_green = np.minimum(lim, 0.5 * (rr + bb) + 6.0)
    # and olive/khaki (green level with red, above blue): flux lit the growth's crevices with the backdrop
    olive = (gg > bb) & (gg >= rr - 6.0) & (gg > 0.5 * (rr + bb) + 12.0)
    gg = np.where(band | (gg > lim) | olive, np.minimum(gg, lim_green), gg)
    out[..., 1] = gg
    out[clear] = 0.0
    rgba = np.dstack([out, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA"), bg, k_bg


def taper_to_border(rgba, reach=60):
    """Growth that runs off the frame would end in a straight cut on the wall. Thin it instead: the
    closer to the frame edge, the harder the alpha is eroded, so roots taper out before the border."""
    a = rgba.getchannel("A")
    w, h = a.size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    base = np.asarray(a).astype(np.float32)
    outa = base.copy()
    for size, dmax in ((3, 48), (5, 36), (7, 26), (9, 16), (13, 8)):
        er = np.asarray(a.filter(ImageFilter.MinFilter(size))).astype(np.float32)
        sel = d < dmax
        outa[sel] = np.minimum(outa[sel], er[sel])
    outa[d < 3] = 0
    rgba = rgba.copy()
    rgba.putalpha(Image.fromarray(outa.astype(np.uint8)))
    return rgba


def fringe_report(rgba, name):
    """The pixels that survive the in-game alpha scissor (a >= 0.5) and touch a pixel that does not:
    how many of them are green? Asserted near zero; printed with the edge histogram's green share."""
    arr = np.asarray(rgba).astype(np.int32)
    a = arr[..., 3]
    solid = a >= 128
    m = Image.fromarray(((~solid) * 255).astype(np.uint8))
    touch = np.asarray(m.filter(ImageFilter.MaxFilter(5))) > 0
    edge = solid & touch
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    green = edge & (g > np.maximum(r, b) + 6)
    n_edge = int(edge.sum())
    frac = green.sum() / max(1, n_edge)
    allg = solid & (g > np.maximum(r, b) + 6)
    print(f"{name:32s} edge texels {n_edge:6d}  green {green.sum():5d} ({frac:.2%})   green anywhere opaque "
          f"{allg.sum() / max(1, solid.sum()):.2%}   edge mean RGB {tuple(int(v) for v in arr[edge][:, :3].mean(0))}")
    assert frac < 0.005, f"{name}: {frac:.2%} of the scissor edge is green — the key fringes"
    return frac


# ---------------------------------------------------------------- the eyes

def _ellipse_mask(size, centre, a, b, feather):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).ellipse([centre[0] - a, centre[1] - b, centre[0] + a, centre[1] + b], fill=255)
    return m.filter(ImageFilter.GaussianBlur(feather)) if feather > 0 else m


def _ring_stats(arr, centre, a, b, r0, r1):
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    q = ((xx - centre[0]) / a) ** 2 + ((yy - centre[1]) / b) ** 2
    sel = (q > r0 * r0) & (q < r1 * r1)
    px = arr[sel].astype(np.float32)
    return px.mean(0), px.std(0) + 1.0


def _paint_eye(img, centre, a, b_up, b_lo, ss=6):
    """Paint ONE open, bloodshot, staring eye into `img` (in place) at D's closed-lid line. Drawn at
    `ss`x and downsampled, in colours taken from the skin round the eye, so it sits in D's lighting:
    an almond opening (upper lid arcs up from the closed line, lower lid dips a little), a dim pink-red
    white, a dark grey-green iris with a darker ring under the upper lid, a black pupil, a red-rimmed
    lower lid, a dark upper lash line, a lid-crease shadow and one small catch-light."""
    cx, cy = centre
    arr = np.asarray(img).astype(np.float32)
    skin_mu, _sd = _ring_stats(arr, centre, a, max(b_up, 4.0), 1.25, 2.0)
    skin = tuple(float(v) for v in skin_mu)
    lumskin = sum(skin) / 3.0
    pad = int(a + 8)
    x0, y0 = int(cx - pad), int(cy - pad)
    size = 2 * pad
    big = img.crop((x0, y0, x0 + size, y0 + size)).resize((size * ss, size * ss), Image.LANCZOS)
    ov = Image.new("RGBA", big.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    ox, oy = (cx - x0) * ss, (cy - y0) * ss
    A, BU, BL = a * ss, b_up * ss, b_lo * ss

    def lid(sign, bb, power, n=40):
        return [(ox + A * t, oy - sign * bb * max(0.0, 1.0 - t * t) ** power) for t in [i / n * 2 - 1 for i in range(n + 1)]]
    upper = lid(1, BU, 0.75)
    lower = lid(-1, BL, 1.1)
    opening = upper + lower[::-1]
    # the crease shadow above the upper lid
    crease = lid(1, BU * 1.9, 0.7)
    d.polygon(crease + upper[::-1], fill=(0, 0, 0, 55))
    # the white: dim, pink-red, darker toward the corners (drawn as the opening, then corner shading)
    white = (skin[0] * 0.95, skin[1] * 0.62, skin[2] * 0.6)
    white = tuple(int(min(255, v * min(1.0, lumskin * 0.8 / max(1.0, sum(white) / 3.0)))) for v in white)
    d.polygon(opening, fill=white + (255,))
    mask = Image.new("L", big.size, 0)
    ImageDraw.Draw(mask).polygon(opening, fill=255)
    inner = Image.new("RGBA", big.size, (0, 0, 0, 0))
    di = ImageDraw.Draw(inner)
    for side in (-1, 1):   # corner shading and a few capillaries
        di.ellipse([ox + side * A * 0.95 - A * 0.45, oy - BU, ox + side * A * 0.95 + A * 0.45, oy + BL], fill=(60, 10, 12, 90))
        for k in range(3):
            yk = oy + (k - 1) * BU * 0.35
            di.line([(ox + side * A * 0.92, yk), (ox + side * A * 0.5, yk + (k - 1) * BU * 0.15)], fill=(150, 25, 28, 150), width=max(1, ss // 3))
    # the iris and pupil, looking straight out, the top tucked under the upper lid
    ir = A * 0.46
    icy = oy - BU * 0.15
    di.ellipse([ox - ir, icy - ir, ox + ir, icy + ir], fill=(52, 56, 48, 255))
    di.ellipse([ox - ir * 0.8, icy - ir * 0.8, ox + ir * 0.8, icy + ir * 0.8], fill=(78, 82, 66, 255))
    di.ellipse([ox - ir * 0.38, icy - ir * 0.38, ox + ir * 0.38, icy + ir * 0.38], fill=(8, 8, 8, 255))
    di.ellipse([ox + ir * 0.34, icy - ir * 0.62, ox + ir * 0.58, icy - ir * 0.38], fill=(225, 225, 220, 150))
    # the upper lid's shadow over the top of the eye
    di.polygon(upper + lid(1, BU * 0.35, 0.75)[::-1], fill=(0, 0, 0, 110))
    ov.paste(inner, (0, 0), Image.composite(inner.getchannel("A"), Image.new("L", big.size, 0), mask))
    # the lid edges: a dark upper lash line, a red-rimmed lower lid
    d.line(upper, fill=(34, 24, 22, 255), width=max(2, int(ss * 0.9)))
    d.line(lower, fill=(150, 62, 56, 220), width=max(1, int(ss * 0.6)))
    big = Image.alpha_composite(big.convert("RGBA"), ov)
    small = big.resize((size, size), Image.LANCZOS).convert("RGB")
    feather = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(feather).polygon(crease + lower[::-1], fill=255)
    feather = feather.filter(ImageFilter.GaussianBlur(ss * 0.8)).resize((size, size), Image.LANCZOS)
    img.paste(small, (x0, y0), feather)


def open_eyes(base_rgb):
    """D with OPEN, bloodshot, staring eyes painted over its closed ones (see `_paint_eye`)."""
    out = base_rgb.copy()
    for (c, a, b) in D_EYES:
        _paint_eye(out, c, a, b * 1.35, b * 0.6)     # wider than the socket's rest: a stare
    return out


def eye_boxes():
    return [(int(cx - a * 1.7 - EYE_PAD), int(cy - b * 3.0 - EYE_PAD), int(cx + a * 1.7 + EYE_PAD), int(cy + b * 3.0 + EYE_PAD))
            for (cx, cy), a, b in D_EYES]


# ---------------------------------------------------------------- the technician

def fused():
    raw = Image.open(os.path.join(USER, "fused_technician_closed_D.jpg")).convert("RGB")
    opened = open_eyes(raw)
    closed_k, bg, k_bg = key_green(raw)
    closed_k = taper_to_border(closed_k)
    alpha = closed_k.getchannel("A")
    # the open one: same alpha, same de-spilled colour everywhere outside the eyes
    open_rgb = np.asarray(opened).astype(np.float32)
    ck = np.asarray(closed_k).astype(np.float32)
    boxes = eye_boxes()
    merged = ck.copy()
    for x0, y0, x1, y1 in boxes:
        merged[y0:y1, x0:x1, :3] = open_rgb[y0:y1, x0:x1, :3]
    open_k = Image.fromarray(merged.astype(np.uint8), "RGBA")
    print(f"green key: background {tuple(int(v) for v in bg)}  k {k_bg:.0f}")
    fringe_report(closed_k, "approach_fused_closed.png")
    # the pair differs ONLY inside the eye boxes
    diff = np.abs(np.asarray(open_k).astype(np.int32) - np.asarray(closed_k).astype(np.int32)).max(axis=2)
    inside = np.zeros(diff.shape, bool)
    for x0, y0, x1, y1 in boxes:
        inside[y0:y1, x0:x1] = True
    n_in = int(((diff > 2) & inside).sum())
    n_out = int(((diff > 2) & ~inside).sum())
    assert n_out == 0, f"fused pair differs OUTSIDE the eyes at {n_out} texels"
    assert n_in > 200, f"fused pair barely differs at the eyes ({n_in} texels)"
    print(f"fused pair: {n_in} texels differ, all inside the two eye boxes {boxes}; 0 outside")
    p3.save(closed_k, "approach_fused_closed.png")
    p3.save(open_k, "approach_fused_open.png")
    # an eyes check sheet for the eye, at 6x
    x0 = min(b[0] for b in boxes) - 10
    y0 = min(b[1] for b in boxes) - 10
    x1 = max(b[2] for b in boxes) + 10
    y1 = max(b[3] for b in boxes) + 10
    sheet = Image.new("RGB", ((x1 - x0) * 6, (y1 - y0) * 12), (40, 40, 40))
    for i, img in enumerate((closed_k, open_k)):
        f = img.crop((x0, y0, x1, y1)).resize(((x1 - x0) * 6, (y1 - y0) * 6), Image.LANCZOS)
        sheet.paste(f, (0, i * f.height), f)
    sheet.save(os.path.join(USER, "fused_D_eyes_check.png"))
    del alpha


# ---------------------------------------------------------------- the bas-relief (2026-09-24)
#
# The user, of the flat relief: "a man holding a wheel looks very two D. Can we make it more three D?"
# So the relief is a real MESH displaced out of the wall (`breach_approach.gd:_build_relief_mesh`), and
# this builds its height map from the keyed art:
#   * the BODY (skin and coverall; not the red growth) is INFLATED from its silhouette: a distance
#     transform with a saturating profile, so the chest and head stand ~16 cm proud, the arms and hands
#     ~8–10 cm, falling to 0 at the body's edge;
#   * the GROWTH gets a shallow inflation of its own (1–4 cm, thin tips ~0);
#   * a light high-pass of the image luminance adds local relief (folds, the face, the knuckles);
#   * everything is blurred (no spikes) and forced to 0 at the silhouette.
# The height is stored 16-bit across R (high byte) and G (low byte); B is the alpha dilated by 5 px,
# which the mesh builder uses to skip empty cells without missing thin tendril tips.
RELIEF_DEPTH = 0.18     # metres at full scale; `breach_approach.gd:TECH_RELIEF_DEPTH` must match
ART_W_M = 1.30          # `breach_approach.gd:TECH_W`: the art's width in metres (for the normal map's slopes)


def _blur(arr, sigma):
    """Separable Gaussian blur of a float array (numpy; Pillow cannot blur mode F), edges clamped."""
    rad = max(1, int(sigma * 3))
    x = np.arange(-rad, rad + 1, dtype=np.float32)
    k = np.exp(-(x * x) / (2.0 * sigma * sigma))
    k /= k.sum()
    a = np.pad(arr.astype(np.float32), rad, mode="edge")
    a = sum(k[i] * a[:, i:i + a.shape[1] - 2 * rad] for i in range(2 * rad + 1))
    a = sum(k[i] * a[i:i + a.shape[0] - 2 * rad, :] for i in range(2 * rad + 1))
    return a


# The man's body in D, as capsules measured on the art (px): (p0, p1, radius, height m, profile power).
# Each gives a ROUNDED cross-section, h = H * (1 - (d / R)^2) ** power, d = the distance to its axis,
# so the head is a head and an arm is a cylinder, not a flat print; the union is the max, then blurred.
# (The first build inflated a colour-classified body mask with a distance transform; skin in shadow
# classified as growth, the face came out 4 cm proud and the chest a jagged "F".)
BODY = [
    ((513, 172), (513, 250), 72, 0.13, 0.5),     # the head (skull, face)
    ((513, 288), (513, 350), 46, 0.10, 0.5),     # the neck
    ((515, 445), (515, 690), 172, 0.15, 0.35),   # the torso, flattened on the front, sinking into the growth
    ((345, 372), (685, 372), 62, 0.12, 0.5),     # the shoulder line
    ((330, 385), (275, 585), 46, 0.095, 0.5),    # his right upper arm (image left)
    ((285, 602), (430, 615), 42, 0.095, 0.5),    # his right forearm, across to the fist
    ((695, 385), (795, 600), 46, 0.095, 0.5),    # his left upper arm
    ((790, 642), (660, 692), 42, 0.095, 0.5),    # his left forearm
    ((440, 600), (522, 594), 46, 0.17, 0.5),     # his right fist, on his chest
    ((568, 700), (652, 706), 50, 0.165, 0.5),    # his left fist, on his belly
]


def _capsule_height(shape, p0, p1, rad, hgt, power):
    hh, ww = shape
    yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float32)
    ax, ay = p1[0] - p0[0], p1[1] - p0[1]
    ll = max(1e-6, ax * ax + ay * ay)
    t = np.clip(((xx - p0[0]) * ax + (yy - p0[1]) * ay) / ll, 0.0, 1.0)
    d = np.hypot(xx - (p0[0] + t * ax), yy - (p0[1] + t * ay))
    q = np.clip(1.0 - (d / rad) ** 2, 0.0, 1.0)
    return hgt * q ** power


def fused_height():
    src = Image.open(os.path.join(OUT, "approach_fused_closed.png")).convert("RGBA")
    arr = np.asarray(src).astype(np.float32)
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    solid = a >= 128
    body_h = np.zeros(solid.shape, np.float32)
    for p0, p1, rad, hgt, power in BODY:
        body_h = np.maximum(body_h, _capsule_height(solid.shape, p0, p1, rad, hgt, power))
    body_h = _blur(body_h, 5.0)
    # ROUND falloffs from a blurred silhouette (a chessboard erosion distance gave staircase edges):
    # where the body's capsules meet the silhouette directly (the coverall's outer edges against the
    # backdrop), the height comes down over ~3.5 cm, or the mesh would stand off the wall like a cut-out
    # No hard mask multiply anywhere: the alpha scissor decides what is seen, and a height cut at the
    # silhouette (or at a hole between an arm and the body) is a cliff the mesh would show edge-on.
    sm = solid.astype(np.float32)
    inside_body = np.clip((_blur(sm, 12.0) - 0.5) / 0.45, 0.0, 1.0)
    inside_body = inside_body * inside_body * (3.0 - 2.0 * inside_body)
    inside_g = np.clip((_blur(sm, 4.0) - 0.3) / 0.55, 0.0, 1.0)
    h = np.maximum(body_h * inside_body, 0.035 * inside_g)
    h = _blur(h, 2.0)
    body_m = body_h > 0.02
    # local relief from the picture itself: brighter (lit, facing the lamp) = nearer
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
    hp = _blur(lum, 1.2) - _blur(lum, 10.0)
    fade_edge = np.clip((_blur(sm, 3.0) - 0.5) / 0.4, 0.0, 1.0)
    detail = hp * np.where(body_m, 0.03, 0.012) * fade_edge
    h = h + detail
    h = _blur(h, 1.0)
    # and the growth sinks into the wall toward the art's frame edge (the roots run off it)
    hh_, ww_ = h.shape
    yy, xx = np.mgrid[0:hh_, 0:ww_]
    dborder = np.minimum(np.minimum(xx, ww_ - 1 - xx), np.minimum(yy, hh_ - 1 - yy)).astype(np.float32)
    fb = np.clip((dborder - 6.0) / 50.0, 0.0, 1.0)
    h = h * (fb * fb * (3.0 - 2.0 * fb))
    h = np.clip(h, 0.0, RELIEF_DEPTH)
    # report where it stands
    def at(uv):
        y, x = int(uv[1] * h.shape[0]), int(uv[0] * h.shape[1])
        return float(h[y - 3:y + 4, x - 3:x + 4].max())
    print(f"relief height: max {h.max():.3f} m; face {at((0.505, 0.22)):.3f}  chest {at((0.5, 0.45)):.3f}  "
          f"right hand {at((0.47, 0.59)):.3f}  left hand {at((0.6, 0.69)):.3f}  root at (0.1, 0.3) {at((0.1, 0.3)):.3f}")
    # the highest step between neighbours, in metres over one texel (1.27 mm): a spike check
    sy, sx = np.abs(np.diff(h, axis=0)), np.abs(np.diff(h, axis=1))
    step = max(sy.max(), sx.max())
    where = np.unravel_index(np.argmax(sy), sy.shape) if sy.max() >= sx.max() else np.unravel_index(np.argmax(sx), sx.shape)
    print(f"relief height: steepest texel step {step * 1000:.1f} mm at px {where[::-1]}")
    assert h.max() > 0.12 and at((0.5, 0.45)) > 0.10, "the relief is too shallow"
    assert step < 0.02, "the height map has a spike or cliff"
    v = np.round(h / RELIEF_DEPTH * 65535.0).astype(np.uint32)
    dil = np.asarray(src.getchannel("A").filter(ImageFilter.MaxFilter(11)))
    out = np.dstack([(v >> 8).astype(np.uint8), (v & 255).astype(np.uint8), dil.astype(np.uint8)])
    p3.save(Image.fromarray(out, "RGB"), "approach_fused_height.png")
    # the NORMAL MAP from the height's fine detail only (the mesh carries the large shape): the height
    # minus a 4 px blur of itself, as real slopes (m per m), so the lamp shapes folds finer than the grid
    fine = h - _blur(h, 4.0)
    px_m = ART_W_M / h.shape[1]
    dx = np.zeros_like(fine)
    dy = np.zeros_like(fine)
    dx[:, 1:-1] = (fine[:, 2:] - fine[:, :-2]) / (2.0 * px_m)
    dy[1:-1, :] = (fine[2:, :] - fine[:-2, :]) / (2.0 * px_m)
    k = 0.6
    nx, ny, nz = -dx * k, dy * k, np.ones_like(fine)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.dstack([nx * inv, ny * inv, nz * inv]) * 0.5 + 0.5
    n[~solid] = (0.5, 0.5, 1.0)
    p3.save(Image.fromarray((n * 255).astype(np.uint8), "RGB"), "approach_fused_normal.png")
    # a height preview for the eye
    Image.fromarray((h / h.max() * 255).astype(np.uint8)).save(os.path.join(USER, "fused_D_height_preview.png"))


# ---------------------------------------------------------------- the growth

def spread():
    """The veins keyed off their green, and faded out radially: the branches run off every edge of the
    frame, and on the wall they must thin away into the tiles instead."""
    raw = Image.open(os.path.join(USER, "growth_spread.jpg")).convert("RGB")
    rgba, bg, k_bg = key_green(raw)
    w, h = rgba.size
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(xx - w / 2.0, yy - h / 2.0) / (w / 2.0)
    fade = np.clip((0.96 - r) / (0.96 - 0.55), 0.0, 1.0)
    fade = fade * fade * (3.0 - 2.0 * fade)
    a = np.asarray(rgba.getchannel("A")).astype(np.float32) * fade
    rgba.putalpha(Image.fromarray(a.astype(np.uint8)))
    print(f"spread key: background {tuple(int(v) for v in bg)}  k {k_bg:.0f}")
    fringe_report(rgba, "approach_growth_spread.png")
    p3.save(rgba, "approach_growth_spread.png")


def flesh():
    """The biomass tile made seamless: blend it with itself offset by half, the offset copy weighted at
    the borders (where it is continuous) and the original in the middle (where it is)."""
    raw = Image.open(os.path.join(USER, "growth_flesh_tile.jpg")).convert("RGB")
    a = np.asarray(raw).astype(np.float32)
    h, w = a.shape[:2]
    rolled = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)).astype(np.float32)
    wgt = np.clip(edge / (0.22 * w), 0.0, 1.0)
    wgt = wgt * wgt * (3.0 - 2.0 * wgt)
    out = a * wgt[..., None] + rolled * (1.0 - wgt[..., None])
    lr = np.abs(out[:, 0] - out[:, -1]).mean()
    tb = np.abs(out[0] - out[-1]).mean()
    inner = np.abs(out[:, w // 2] - out[:, w // 2 + 1]).mean()
    print(f"flesh tile seams: L-R {lr:.1f}  T-B {tb:.1f}  (an interior column pair {inner:.1f}; the raw was 38.3 / 30.4)")
    assert lr < inner * 1.6 + 2 and tb < inner * 1.6 + 2, "the flesh tile still has a seam"
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    p3.save(img, "approach_growth_flesh.png")
    sheet = Image.new("RGB", (w * 2, h * 2))
    for ix in range(2):
        for iy in range(2):
            sheet.paste(img, (ix * w, iy * h))
    sheet.resize((w, h)).save(os.path.join(USER, "growth_flesh_tiling_check.png"))


if __name__ == "__main__":
    which = sys.argv[1:] or ["fused", "height", "spread", "flesh"]
    if "fused" in which:
        fused()
    if "height" in which:
        fused_height()
    if "spread" in which:
        spread()
    if "flesh" in which:
        flesh()
