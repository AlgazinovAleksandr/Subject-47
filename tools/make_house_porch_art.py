#!/usr/bin/env python3
"""Level 2 back-porch art (2026-09-24): the witch, the three forest ghosts, the forest surfaces,
the night sky, the watermelon and the hole in the plaster.

Every input is a flux-1-schnell raw in assets_src/textures/level_2_house/porch/ (prompts in
prompts.txt there). Nothing here generates; it keys, grades, tiles and crops, deterministically.

  * FIGURES (witch, ghost woman, crawler, tall ghost, pine) were generated on a flat #00FF00
    screen and are keyed on GREEN DOMINANCE, the `cutout_green.py` rule. Two things that tool
    does not do and these raws need:
      - ENCLOSED screen pockets (the gap between a crawler's legs, the holes in a pine's
        foliage) are not reachable from the border, so a border flood leaves them opaque and
        the despill turns them olive. Here any screen component larger than POCKET_MIN px is
        background wherever it is.
      - ALPHA BLEED: the RGB under alpha 0 is replaced by the figure's own edge colour, so
        mipmapping / linear filtering in Godot cannot pull a green (or white) fringe back in.
    Then every figure is graded toward the moonlit, desaturated palette of `screamer_forest.png`
    — an unshaded billboard's albedo is its final colour (Issue 63).
  * TILEABLES (bark, floor) are flattened (low-frequency lighting divided out, so a
    vignette does not repeat on every tile) and made seamless with a two-pass half-offset blend
    in a narrow border band, variance-preserving so the band does not go grey and soft.
    The RIND is drawn from periodic noise instead (see rind()).
  * THE SKY is a 2:1 equirect built from two square raws (moon-behind-cloud + cloud only),
    cross-faded on both seams so it wraps, faded to a flat colour at the zenith row (every
    pixel of that row meets at one point on a sphere) and darkened below the horizon.
  * THE PLASTER HOLE keeps the black cavity, the lath and a ragged fringe of broken plaster;
    everything past the fringe is alpha 0 so it sits on the existing wall.

⚠️ `tall ghost` was asked to be keyed out of `screamer_forest.png`. Tried and rejected: that
creature's body is 6-30/255 against a 13-28/255 forest right beside it, so neither a colour
flood (`cutout_dark_bg.py`, any --tol) nor a luminance key separates them — the result was the
rim-lit edges of the creature floating in blotches of fog. It is a fresh green-screen raw.

Needs Pillow + numpy — use the image pack's venv:
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_house_porch_art.py
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import os
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets_src", "textures", "level_2_house", "porch")
OUT = os.path.join(ROOT, "game", "assets", "textures", "level_2_house")

POCKET_MIN = 60          # an enclosed screen component at least this big is background
SPECK_MAX = 150          # a detached island smaller than this (or 0.5 % of the figure) is noise
rng = np.random.default_rng(22409)


# ----------------------------------------------------------------------------- helpers
def load(name):
    return np.asarray(Image.open(os.path.join(RAW, name)).convert("RGB")).astype(np.float32)


def blur(arr, radius):
    """Gaussian blur (sigma = radius) of a float HxW or HxWx3 array: reflect-pad, FFT, crop.

    Pillow cannot blur a float ('F') image, and a mask blurred as 8-bit loses the soft ramp.
    """
    if arr.ndim == 3:
        return np.stack([blur(arr[..., c], radius) for c in range(arr.shape[2])], axis=-1)
    p = int(3 * radius) + 1
    a = np.pad(arr.astype(np.float32), p, mode="reflect")
    fy = np.fft.fftfreq(a.shape[0])[:, None]
    fx = np.fft.rfftfreq(a.shape[1])[None, :]
    g = np.exp(-2 * (np.pi * radius) ** 2 * (fx * fx + fy * fy))
    out = np.fft.irfft2(np.fft.rfft2(a) * g, s=a.shape)
    return out[p:-p, p:-p].astype(np.float32)


def lum(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def components(mask):
    """Yield (size, touches_border, index_arrays) for each 4-connected True component."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        pts = []
        border = False
        while q:
            y, x = q.popleft()
            pts.append((y, x))
            if y == 0 or x == 0 or y == h - 1 or x == w - 1:
                border = True
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        yield len(pts), border, pts


def shrink(mask, px):
    """Binary erosion by px (4-neighbour), numpy only."""
    m = mask.copy()
    for _ in range(px):
        n = m.copy()
        n[1:, :] &= m[:-1, :]
        n[:-1, :] &= m[1:, :]
        n[:, 1:] &= m[:, :-1]
        n[:, :-1] &= m[:, 1:]
        m = n
    return m


def bleed(rgb, alpha):
    """Fill the colour under low alpha with the nearby opaque colour (no fringe on filtering)."""
    a = alpha / 255.0
    out = rgb.copy()
    acc = np.zeros_like(rgb)
    wacc = np.zeros(alpha.shape, np.float32)
    for r in (2, 6, 16, 40):
        num = blur(rgb * a[..., None], r)
        den = blur(a, r)
        take = (wacc < 1e-3) & (den > 1e-3)
        acc[take] = num[take] / den[take][:, None]
        wacc[take] = 1.0
    fill = alpha < 250
    out[fill] = np.where(wacc[fill][:, None] > 0, acc[fill], out[fill])
    # blend: keep the real colour where the pixel is mostly opaque
    k = a[..., None]
    return out * (1 - k) + rgb * k


def grade(rgb, sat=0.55, exposure=1.0, tint=(0.95, 1.0, 1.08), gamma=1.0):
    """Desaturate toward a cold moonlit palette."""
    L = lum(rgb)[..., None]
    out = L + (rgb - L) * sat
    out = out * np.array(tint, np.float32) * exposure
    if gamma != 1.0:
        out = 255.0 * np.power(np.clip(out, 0, 255) / 255.0, gamma)
    return np.clip(out, 0, 255)


def fit(img, longest):
    w, h = img.size
    s = longest / max(w, h)
    if s < 1.0:
        img = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    return img


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, "PNG", optimize=True)
    if img.mode == "RGBA":
        a = np.asarray(img.getchannel("A"))
        border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
        assert border.max() < 40, f"{name}: opaque pixels on the border — not a cutout"
        opaque = (a > 128).mean()
        clear = (a == 0).mean()
        assert opaque > 0.01, f"{name}: almost nothing opaque"
        print(f"{name:28s} {img.width}x{img.height} RGBA  clear {clear:5.1%}  opaque {opaque:5.1%}")
    else:
        L = lum(np.asarray(img.convert("RGB")).astype(np.float32))
        print(f"{name:28s} {img.width}x{img.height} {img.mode}  mean lum {L.mean():5.1f}")


# ----------------------------------------------------------------------------- figures
def key_green(name, dominance=40.0, ratio=1.6, min_green=18.0):
    rgb = load(name)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = np.maximum(r, b)
    screen = (g >= min_green) & (((g - m) >= dominance) | (g >= ratio * np.maximum(m, 1)))
    bg = np.zeros_like(screen)
    for size, border, pts in components(screen):
        if border or size >= POCKET_MIN:
            ys, xs = zip(*pts)
            bg[list(ys), list(xs)] = True
    # and the reverse: specks of JPEG noise darker than the vignetted screen, e.g. (6, 8, 3) on
    # the border of tall_raw_a, are tiny islands of "figure" floating in the background
    islands = list(components(~bg))
    floor = max(SPECK_MAX, 0.005 * max(size for size, _, _ in islands))
    for size, border, pts in islands:
        if size < floor:
            ys, xs = zip(*pts)
            bg[list(ys), list(xs)] = True
    fig = shrink(~bg, 1)                       # eat the 1-px green-lit rim
    alpha = blur(fig.astype(np.float32) * 255.0, 0.9)
    # hard despill: nothing on these figures is legitimately green
    rgb[..., 1] = np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2]) + 4)
    return rgb, alpha


def figure(raw, out, longest=1024, margin=10, key=None, **g):
    rgb, alpha = key_green(raw, **(key or {}))
    rgb = grade(rgb, **g)
    rgb = bleed(rgb, alpha)
    ys, xs = np.nonzero(alpha > 8)
    y0, y1 = max(0, ys.min() - margin), min(alpha.shape[0], ys.max() + margin + 1)
    x0, x1 = max(0, xs.min() - margin), min(alpha.shape[1], xs.max() + margin + 1)
    arr = np.dstack([rgb, alpha])[y0:y1, x0:x1]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    save(fit(img, longest), out)


# ----------------------------------------------------------------------------- tileables
def flatten(rgb, radius=90):
    """Divide out low-frequency lighting so a vignette does not repeat every tile."""
    L = lum(rgb)
    low = blur(L, radius)
    return np.clip(rgb * (L.mean() / np.maximum(low, 1.0))[..., None], 0, 255)


def seamless(rgb, band_frac=0.18):
    """Two-pass half-offset blend in a border band, variance-preserving."""
    out = rgb
    for axis in (1, 0):
        n = out.shape[axis]
        band = max(4, int(n * band_frac))
        d = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(np.float32)
        w = np.clip(d / band, 0, 1)
        w = w * w * (3 - 2 * w)                                      # smoothstep
        w = w[None, :, None] if axis == 1 else w[:, None, None]
        rolled = np.roll(out, n // 2, axis=axis)
        mean = out.mean(axis=(0, 1), keepdims=True)
        mix = w * (out - mean) + (1 - w) * (rolled - mean)
        norm = np.sqrt(w * w + (1 - w) * (1 - w))
        out = np.clip(mean + mix / norm, 0, 255)
    return out


def tile(raw, out, size, crop=None, flat=90, **g):
    rgb = load(raw)
    if crop:
        x0, y0, x1, y1 = crop
        rgb = rgb[y0:y1, x0:x1]
    img = Image.fromarray(rgb.astype(np.uint8)).resize((size, size), Image.LANCZOS)
    rgb = np.asarray(img).astype(np.float32)
    if flat:
        rgb = flatten(rgb, flat)
    rgb = grade(rgb, **g)
    rgb = seamless(rgb)
    save(Image.fromarray(rgb.astype(np.uint8), "RGB"), out)


def pnoise(n, sigma):
    """Periodic (wrap-around) smooth noise in 0..1: an FFT blur with NO padding tiles by itself."""
    a = rng.random((n, n)).astype(np.float32)
    f = np.fft.fftfreq(n)
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (f[:, None] ** 2 + f[None, :] ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(a) * g))
    return (out - out.min()) / (out.max() - out.min())


def rind():
    """Drawn, not keyed: tileable by construction.

    ⚠️ The flux raws (rind_raw_a..d) are all photos of a SPHERE — curvature shading and stripes
    that converge — and the half-offset blend doubled every stripe where the halves met. So the
    stripes are drawn here from periodic noise, in the raw's own two greens (sampled from
    rind_raw_a: dark ground ~(22, 60, 22), stripe ~(150, 185, 70)), then aged and darkened.
    """
    n = 512
    y = np.arange(n, dtype=np.float32)[:, None]
    x = np.arange(n, dtype=np.float32)[None, :]
    stripes = 6
    period = n / stripes
    wander = (pnoise(n, 60)[:, :1] - 0.5) * 0.45 * period          # whole stripe meanders in x
    jag = (pnoise(n, 2.5) - 0.5) * 0.30 * period                    # ragged stripe edges
    width = 0.27 * period + (pnoise(n, 25) - 0.5) * 0.14 * period   # stripe thickness varies
    phase = (x + wander + jag) % period
    dist = np.abs(phase - period / 2)
    stripe = np.clip((width - dist) / 3.0, 0, 1)                    # 3-px soft edge
    # the pale stripe has a darker mottled core of little veins, like a real rind
    vein = np.clip((pnoise(n, 1.6) - 0.52) * 6, 0, 1)
    dark = np.array([22, 58, 24], np.float32)
    pale = np.array([104, 136, 60], np.float32)
    mid = np.array([70, 108, 44], np.float32)
    stripe_col = pale * (1 - 0.55 * vein[..., None]) + mid * 0.55 * vein[..., None]
    ground = dark * (0.85 + 0.3 * pnoise(n, 6)[..., None])
    rgb = ground * (1 - stripe[..., None]) + stripe_col * stripe[..., None]
    # age: soil smudges, fine grime speckle, a few pale scuffs
    smudge = np.clip((pnoise(n, 22) - 0.55) * 3.0, 0, 1)[..., None]
    soil = np.array([66, 54, 36], np.float32)
    rgb = rgb * (1 - 0.5 * smudge) + soil * 0.5 * smudge
    rgb = rgb * (0.82 + 0.36 * pnoise(n, 0.8)[..., None])
    scuff = np.clip((pnoise(n, 2.0) - 0.8) * 8, 0, 1)[..., None]
    rgb = rgb * (1 - 0.35 * scuff) + np.array([120, 120, 95], np.float32) * 0.35 * scuff
    rgb = grade(rgb, sat=0.7, exposure=0.72, tint=(1.0, 1.0, 1.0))
    save(Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB"), "watermelon_rind.png")


# ----------------------------------------------------------------------------- one-offs
def melon_flesh():
    rgb = load("flesh_raw_a.jpg")
    L = lum(rgb)
    ys, xs = np.nonzero(L > 40)
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    r = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 + 2
    box = (int(cx - r), int(cy - r), int(cx + r), int(cy + r))
    img = Image.fromarray(rgb.astype(np.uint8)).crop(box).resize((512, 512), Image.LANCZOS)
    rgb = grade(np.asarray(img).astype(np.float32), sat=0.85, exposure=0.8, tint=(1, 1, 1))
    save(Image.fromarray(rgb.astype(np.uint8), "RGB"), "watermelon_flesh.png")


def plaster_hole():
    rgb = load("hole_raw_a.jpg")
    L = lum(rgb)
    h, w = L.shape
    # damage = everything that is not intact white plaster (cavity + lath + cracks), taken as
    # the component that contains the centre
    damaged = L < 175
    seed = (h // 2, w // 2)
    region = np.zeros_like(damaged)
    q = deque([seed])
    region[seed] = True
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and damaged[ny, nx] and not region[ny, nx]:
                region[ny, nx] = True
                q.append((ny, nx))
    # ragged fringe of broken plaster: grow the damage by a noisy 6-30 px
    reach = blur(rng.random((h, w)).astype(np.float32), 9)
    reach = (reach - reach.min()) / (reach.max() - reach.min())
    grown = blur(region.astype(np.float32), 14)
    keep = grown > (0.02 + 0.30 * reach)
    keep = keep | region
    alpha = blur(keep.astype(np.float32) * 255.0, 1.4)
    # grade the pale plaster toward the House's stained brown wallpaper; the cavity stays black
    plaster = np.clip((L - 120) / 80.0, 0, 1)[..., None]
    warm = grade(rgb, sat=0.4, exposure=0.55, tint=(1.0, 0.93, 0.82))
    rgb = warm * plaster + grade(rgb, sat=0.6, exposure=0.75, tint=(1.0, 0.95, 0.88)) * (1 - plaster)
    rgb = bleed(rgb, alpha)
    ys, xs = np.nonzero(alpha > 8)
    cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) // 2 + 14
    arr = np.dstack([rgb, alpha])
    pad = np.zeros((h + 2 * half, w + 2 * half, 4), np.float32)
    pad[half:half + h, half:half + w] = arr
    arr = pad[cy:cy + 2 * half, cx:cx + 2 * half]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    save(img.resize((512, 512), Image.LANCZOS), "plaster_hole.png")


def night_sky():
    W, H = 2048, 1024
    S = 1280

    def prep(name, crop=None):
        im = Image.open(os.path.join(RAW, name)).convert("RGB")
        if crop:
            im = im.crop(crop)
        return np.asarray(im.resize((S, S), Image.LANCZOS)).astype(np.float32)

    moon = prep("sky_clouds_raw_c.jpg")                     # moon at its centre
    cloud = prep("sky_clouds_raw_b.jpg", (0, 0, 800, 800))  # crop out the crescent in its corner
    # place the moon at y ~ 330 (about 30 deg above the horizon): moon row S/2 -> 330
    # (the window runs off the bottom of the raw; mirror it — that part ends up below the
    # horizon and nearly black anyway)
    top = S // 2 - 330
    moon = np.concatenate([moon, moon[::-1]])[top:top + H]
    cloud = cloud[(S - H) // 2:(S - H) // 2 + H]
    # match the cloud half's level to the moon half's sky (away from the moon)
    cloud = cloud * (np.median(moon[:, :200]) / max(1.0, np.median(cloud)))
    canvas = np.zeros((H, W, 3), np.float32)
    weight = np.zeros((H, W), np.float32)
    ov = S * 2 - W                                          # 512 total, 256 per seam

    def place(img, x0):
        n = img.shape[1]
        ramp = np.ones(n, np.float32)
        k = ov // 2
        t = np.linspace(0, 1, k, dtype=np.float32)
        ramp[:k] = t
        ramp[-k:] = t[::-1]
        for i in range(n):
            x = (x0 + i) % W
            canvas[:, x] += img[:, i] * ramp[i]
            weight[:, x] += ramp[i]

    place(moon, 0)
    place(cloud, S - ov // 2)
    sky = canvas / np.maximum(weight, 1e-3)[..., None]
    # darker overall, cold, desaturated
    sky = grade(sky, sat=0.5, exposure=0.85, tint=(0.92, 0.98, 1.1), gamma=1.1)
    y = np.arange(H, dtype=np.float32)[:, None, None]
    # zenith: fade to the mean of the top rows so the pole does not pinch
    zen = sky[:40].mean(axis=(0, 1), keepdims=True)
    kz = np.clip(1 - y / 110.0, 0, 1)
    sky = sky * (1 - kz) + zen * kz
    # below the horizon: fade toward near-black
    kh = np.clip((y - 520) / 260.0, 0, 1)
    sky = sky * (1 - 0.85 * kh)
    save(Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8), "RGB"), "night_sky.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    # figures: an unshaded billboard's albedo is its final colour — graded toward screamer_forest
    figure("witch_raw_b.jpg", "house_witch.png", sat=0.5, exposure=0.78)
    figure("ghost_woman_raw_f.jpg", "forest_ghost_woman.png", sat=0.3, exposure=0.8)
    figure("crawler_raw_e.jpg", "forest_ghost_crawler.png", sat=0.35, exposure=0.72)
    # this raw's screen is vignetted to (1, 6, 2) in the corners: green is still 3x the other
    # channels there, so the ratio test holds once the absolute floor comes down
    figure("tall_raw_a.jpg", "forest_ghost_tall.png", key={"min_green": 4.0}, sat=0.45, exposure=0.8)
    figure("pine_raw_b.jpg", "forest_pine.png", sat=0.4, exposure=0.55, tint=(0.9, 1.0, 1.0))
    tile("bark_raw_c.jpg", "forest_bark.png", 512, sat=0.45, exposure=0.7, tint=(1.08, 1.0, 0.92))
    tile("floor_raw_b.jpg", "forest_floor.png", 1024, sat=0.55, exposure=0.55, tint=(1.0, 1.0, 1.0))
    rind()
    melon_flesh()
    plaster_hole()
    night_sky()


if __name__ == "__main__":
    main()
