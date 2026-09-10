#!/usr/bin/env python3
"""Turn a generated PALE-figure-on-a-DARK-background image into a real RGBA cutout.

The sibling of `cutout_alpha.py`, for the opposite polarity. That tool keys on LUMINANCE
("dark figure on a pale background") and cannot be pointed at a figure lit from below on black:
the figure's own hair and rags are as dark as the backdrop, and a luminance key punches holes
through them. This one keys on CONNECTIVITY instead — a flood fill from the image border over
pixels within `--tol` of the border's median colour is the background; everything it cannot
reach is figure. Black hair inside a pale outline stays opaque because the fill cannot get to
it. Same rule `flatten_alpha_checker.py` uses for baked checkerboards.

Then: a 1-px alpha feather so the edge is not scissors-cut, and a crop to the alpha bounding box
with a margin (the generator returns 1:1 however loudly you ask for portrait; the mesh is sized
from the texture, SCARY.md §7.1(4)).

Usage:
    tools/cutout_dark_bg.py IN.jpg OUT.png [--tol 34] [--margin 10]

⚠️ Re-import afterwards, or Godot keeps serving the old `.ctex`.
"""

import argparse
import sys
from collections import deque

from PIL import Image, ImageFilter


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--tol", type=float, default=34.0)
    ap.add_argument("--margin", type=int, default=10)
    # ⚠️ A billboard figure is UNSHADED: its albedo is its final colour, and a pale figure at
    # 0.6 m fills the screen — a flashbang in a renderer with no tonemapping (Issue 63). Grade
    # it down here, once, deterministically, rather than in a material every caller must get
    # right. 1.0 = untouched.
    ap.add_argument("--exposure", type=float, default=1.0)
    # ⚠️ SMOOTHNESS, the term that separates a studio backdrop from a dark garment. The
    # generator's "black background" is a soft radial gradient that reaches (24, 37, 45)
    # beside the torso — 62 units from the corner black, while the figure's rags sit at
    # (22, 30, 33), 48 units away. No colour tolerance tells them apart; a tolerance wide
    # enough for the halo eats the loincloth. But the backdrop is SMOOTH (local std under 1)
    # and cloth has folds (std well over 4), and the flood only crosses pixels that are both
    # near the reference colour AND locally flat. 0 disables the term.
    ap.add_argument("--smooth", type=float, default=4.0)
    # Morphological CLOSE on the figure mask (odd px). The smoothness-gated flood still leaks
    # into the flattest few pixels of a dark garment as thin streaks; a close of ~9 px refills
    # streaks while the backdrop halo it removed (tens of px wide) stays removed. 0 = off.
    ap.add_argument("--close", type=int, default=0)
    a = ap.parse_args()

    im = Image.open(a.src).convert("RGB")
    # ⚠️ The mask is computed on the ORIGINAL colours and the grade is applied afterwards.
    # Grading first darkens the figure's own rags and hair into the background tolerance and
    # the flood fill eats them — measured: opaque coverage fell from 51 % to 20 %.
    w, h = im.size
    px = im.load()
    # Reference background: the median of the border pixels.
    border = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)] \
        + [px[0, y] for y in range(h)] + [px[w - 1, y] for y in range(h)]
    ref = tuple(sorted(c[i] for c in border)[len(border) // 2] for i in range(3))
    tol2 = a.tol * a.tol

    flat = None
    if a.smooth > 0.0:
        import numpy as np
        g = np.asarray(im.convert("L"), dtype=np.float32)
        k = 5
        pad = k // 2
        gp = np.pad(g, pad, mode="edge")
        acc = np.zeros_like(g)
        acc2 = np.zeros_like(g)
        for dy in range(k):
            for dx in range(k):
                win = gp[dy:dy + h, dx:dx + w]
                acc += win
                acc2 += win * win
        mean = acc / (k * k)
        std = np.sqrt(np.maximum(acc2 / (k * k) - mean * mean, 0.0))
        flat = std <= a.smooth

    def is_bg_at(x, y):
        c = px[x, y]
        if (c[0] - ref[0]) ** 2 + (c[1] - ref[1]) ** 2 + (c[2] - ref[2]) ** 2 > tol2:
            return False
        return flat is None or bool(flat[y, x])

    def is_bg(c):
        return (c[0] - ref[0]) ** 2 + (c[1] - ref[1]) ** 2 + (c[2] - ref[2]) ** 2 <= tol2

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(px[x, y]):
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y * w + x] and is_bg(px[x, y]):
                seen[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and is_bg_at(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))

    alpha = Image.new("L", (w, h), 255)
    ap_ = alpha.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            if seen[row + x]:
                ap_[x, y] = 0
    if a.close and a.close > 1:
        k = a.close if a.close % 2 == 1 else a.close + 1
        alpha = alpha.filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.MinFilter(k))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))
    out = im.copy()
    if a.exposure != 1.0:
        from PIL import ImageEnhance
        out = ImageEnhance.Brightness(out).enhance(a.exposure)
    out.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox is None:
        print("no figure found", file=sys.stderr)
        sys.exit(1)
    x0, y0, x1, y1 = bbox
    m = a.margin
    out = out.crop((max(0, x0 - m), max(0, y0 - m), min(w, x1 + m), min(h, y1 + m)))
    out.save(a.dst, optimize=True)
    cw, ch = out.size
    opaque = sum(1 for v in out.getchannel("A").getdata() if v > 128)
    print("wrote %s  %dx%d  aspect %.3f  bg ref %s  opaque %.1f%%"
          % (a.dst, cw, ch, cw / ch, ref, 100.0 * opaque / (cw * ch)))


if __name__ == "__main__":
    main()
