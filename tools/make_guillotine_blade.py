"""game/assets/textures/level_2_house/guillotine_blade.png (2026-09-24 d) from
assets_src/textures/level_2_house/porch/blade_raw_p1_a.jpg.

flux would not draw the oblique edge (12 raws: flared trapezoids, shields, windows, triangles
with no weight). p1_a has the right WEIGHT (two bolted iron bars, bolt heads, through-holes) and
good worn steel, so: key it, keep the weight as drawn, unwarp the flared steel into a rectangle
flush under the lower bar, and CUT the oblique edge geometrically (low on the LEFT, high on the
right, as house_guillotine.gd's +12 deg Edge box). The ground bevel and the dark stains along the
new edge are painted here, since the raw's own edge (a rusty strip) is cut away.
Deterministic (seeded). Reuses make_house_porch_art.py's key_green / grade / bleed / blur.

    .venv/bin/python3 tools/make_guillotine_blade.py
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import importlib.util
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("porch", os.path.join(ROOT, "tools", "make_house_porch_art.py"))
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)

W_OUT, H_OUT = 1024, 576
MARGIN = 5
rng = np.random.default_rng(92409)

rgb, alpha = P.key_green("blade_raw_p1_a.jpg")
H, W = alpha.shape
solid = alpha > 128

# --- measure: the lower bar is the widest run; the seam is where the steel starts (narrower)
ext = []
for y in range(H):
    xs = np.nonzero(solid[y])[0]
    ext.append((xs.min(), xs.max()) if len(xs) else None)
wide = [y for y in range(H) if ext[y] and ext[y][1] - ext[y][0] > 800]
bar_top = min(wide)
bar_bot = bar_top
while ext[bar_bot + 1] and ext[bar_bot + 1][1] - ext[bar_bot + 1][0] > 800:
    bar_bot += 1                                    # the first CONTIGUOUS wide run only
bar_rows = list(range(bar_top, bar_bot + 1))
bx0 = int(np.median([ext[y][0] for y in bar_rows]))
bx1 = int(np.median([ext[y][1] for y in bar_rows]))
seam = bar_bot + 1
top = min(y for y in range(H) if ext[y])
print("weight top", top, "bar", bar_top, bar_bot, "x", bx0, bx1, "seam", seam)

bw = bx1 - bx0 + 1
target_h_total = round((bw + 2 * MARGIN) / (W_OUT / H_OUT)) - 2 * MARGIN
steel_low = target_h_total - (seam - top)          # steel height at the low (left) side
steel_high = int(steel_low * 0.28)                  # …and at the high (right) side
print("total h", target_h_total, "steel low", steel_low, "high", steel_high)

# --- unwarp the flared steel: each source row's [x_l+4, x_r-4] stretched onto [bx0, bx1]
steel = np.zeros((steel_low, bw, 3), np.float32)
tx = np.linspace(0, 1, bw)
for i in range(steel_low):
    y = seam + 2 + i                                # skip the bar's bottom shadow line
    xl, xr = ext[y]
    sx = (xl + 4) + tx * ((xr - 4) - (xl + 4))
    for c in range(3):
        steel[i, :, c] = np.interp(sx, np.arange(W), rgb[y, :, c])

# --- canvas in raw scale
Hc = seam - top + steel_low
canvas = np.zeros((Hc, bw, 3), np.float32)
a = np.zeros((Hc, bw), np.float32)
canvas[: seam - top] = rgb[top:seam, bx0:bx1 + 1]
a[: seam - top] = alpha[top:seam, bx0:bx1 + 1]
canvas[seam - top:] = steel

# the oblique edge: distance (px, positive = inside the steel) from the cut line
y0 = seam - top
yy, xx = np.mgrid[0:Hc, 0:bw].astype(np.float32)
y_edge = y0 + steel_low - (xx / (bw - 1)) * (steel_low - steel_high)
slope = (steel_low - steel_high) / (bw - 1)
d = (y_edge - yy) / np.sqrt(1 + slope * slope)
steel_zone = yy >= y0
a[steel_zone] = (np.clip(d + 0.5, 0, 1) * 255.0)[steel_zone]
# steel's vertical sides: 1 px soft, like the keyed bar above them
a[steel_zone & (xx < 1)] *= 0.5
a[steel_zone & (xx > bw - 2)] *= 0.5

# --- the ground bevel: a paler, finely streaked band along the edge
BEVEL = 20.0
# grinding streaks parallel to the edge: 1-D noise indexed by the distance from it
lines = np.interp(d, np.linspace(0, BEVEL, 200), rng.random(200).astype(np.float32))
bev = np.where(d > BEVEL, 0, np.clip((BEVEL - d) / 3.0, 0, 1))  # hard shoulder, 3 px ramp
bev_col = P.lum(canvas)[..., None] * (1.18 + 0.10 * (lines[..., None] - 0.5)) + 10
canvas = np.where((steel_zone & (bev > 0))[..., None], canvas * (1 - bev[..., None]) + bev_col * bev[..., None], canvas)
# the shoulder line (where the bevel meets the flat) and the honed lip
shoulder = np.exp(-((d - BEVEL) ** 2) / 2.0) * steel_zone
canvas *= (1 - 0.35 * shoulder)[..., None]
lip = np.exp(-((d - 1.5) ** 2) / 1.5) * steel_zone
canvas = canvas * (1 - 0.3 * lip[..., None]) + 200 * 0.3 * lip[..., None]

# --- a little rust bleeding down from the bar onto the steel under it
rust_n = P.blur(rng.random((Hc, bw)).astype(np.float32), 4)
rust_n = (rust_n - rust_n.min()) / (rust_n.max() - rust_n.min())
under = np.clip(1 - (yy - y0) / 45.0, 0, 1) * steel_zone
rk = (np.clip(rust_n - 0.45, 0, 1) * 1.6 * under * 0.6)[..., None]
canvas = canvas * (1 - rk) + np.array([110, 58, 30], np.float32) * rk
# sparse rust blooms and pitting over the whole steel face, and the flat steel a shade duller
rb = P.blur(rng.random((Hc, bw)).astype(np.float32), 9)
rb = (rb - rb.min()) / (rb.max() - rb.min())
pit = P.blur(rng.random((Hc, bw)).astype(np.float32), 1.0)
pit = (pit - pit.min()) / (pit.max() - pit.min())
bloom = (np.clip((rb - 0.66) * 4.0, 0, 1) * (0.55 + 0.45 * pit) * steel_zone)[..., None] * 0.7
canvas = canvas * (1 - bloom) + np.array([98, 56, 32], np.float32) * (0.8 + 0.4 * pit[..., None]) * bloom
canvas = np.where(steel_zone[..., None], canvas * 0.86, canvas)

# --- grade: desaturated, a touch dark
canvas = P.grade(canvas, sat=0.55, exposure=0.9, tint=(1.0, 0.99, 0.97))
# --- dark dried stains, concentrated at the edge, a few runs up the blade from it
n1 = P.blur(rng.random((Hc, bw)).astype(np.float32), 6)
n1 = (n1 - n1.min()) / (n1.max() - n1.min())
n2 = P.blur(rng.random((Hc, bw)).astype(np.float32), 1.5)
n2 = (n2 - n2.min()) / (n2.max() - n2.min())
reach = 55 + 90 * P.blur(rng.random((1, bw)).astype(np.float32), 25)[0] / 1.0   # varies along x
reach = 30 + 110 * (reach - reach.min()) / (reach.max() - reach.min())
near = np.clip(1 - d / reach[None, :], 0, 1) ** 1.6
stain = np.clip((n1 * 0.75 + n2 * 0.25) - (1 - near) * 0.9 - 0.25, 0, 1) * 3.2
# a few narrow runs (dried trickles) perpendicular to the edge
runs = np.zeros(bw, np.float32)
for cx in rng.choice(np.arange(60, bw - 60), 5, replace=False):
    w = rng.uniform(2.5, 6)
    runs += np.exp(-((np.arange(bw) - cx) ** 2) / (2 * w * w)) * rng.uniform(0.6, 1.0)
run_len = 25 + 70 * rng.random(bw)
run_len = P.blur(run_len[None, :].astype(np.float32), 8)[0]
runs2 = runs[None, :] * np.clip(1 - d / run_len[None, :], 0, 1) * (0.6 + 0.4 * n2)
stain = np.clip(np.maximum(stain, runs2 * 0.9), 0, 1) * steel_zone * (d > -1)
stain_col = np.array([60, 17, 13], np.float32)   # applied AFTER the grade, so it stays red
k = (0.82 * stain)[..., None]
canvas = canvas * (1 - k) + (stain_col * (0.7 + 0.6 * n2[..., None])) * k

canvas = P.bleed(canvas, a)

# --- pad with margin, resize to exactly 1024 x 576
pad = np.zeros((Hc + 2 * MARGIN, bw + 2 * MARGIN, 4), np.float32)
pad[MARGIN:MARGIN + Hc, MARGIN:MARGIN + bw, :3] = canvas
pad[MARGIN:MARGIN + Hc, MARGIN:MARGIN + bw, 3] = a
# bleed colour into the margin too
pad[..., :3] = P.bleed(pad[..., :3], pad[..., 3])
img = Image.fromarray(np.clip(pad, 0, 255).astype(np.uint8), "RGBA")
print("pre-resize", img.size)
img = img.resize((W_OUT, H_OUT), Image.LANCZOS)
out = os.path.join(ROOT, "game", "assets", "textures", "level_2_house", "guillotine_blade.png")
arr = np.asarray(img).copy()
arr[..., 3][arr[..., 3] < 3] = 0
arr[..., 3][arr[..., 3] >= 250] = 255              # float round-off left the body at 254
img = Image.fromarray(arr, "RGBA")
img.save(out, "PNG", optimize=True)
A = arr[..., 3]
border = np.concatenate([A[0], A[-1], A[:, 0], A[:, -1]])
print("saved", out, img.size, "border max", border.max(),
      "clear %.1f%%  opaque %.1f%%" % (100 * (A == 0).mean(), 100 * (A > 128).mean()))
