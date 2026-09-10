#!/usr/bin/env python3
"""Chroma-key a generated figure off a GREEN SCREEN into a real RGBA cutout.

The third cutout tool, and the one to reach for first from now on (2026-09-10):

  * `cutout_alpha.py`   keys on LUMINANCE — a dark figure on a pale backdrop. Fails on a pale
                        figure, and on any figure with dark hair against a dark backdrop.
  * `cutout_dark_bg.py` floods a dark backdrop from the border. Fails where the generator's
                        "black background" is a soft gradient that brightens beside the
                        figure, because no colour tolerance separates that halo from a dark
                        garment; a smoothness gate leaks through motion-blurred cloth edges.
  * this one            asks the generator for a flat #00FF00 screen — which flux renders
                        reliably — and keys on GREEN DOMINANCE, which no skin, hair, rag,
                        blood or bone shares. A flood fill from the border keeps any greenish
                        pixel INSIDE the figure opaque, and a despill clamps the green fringe
                        the screen throws onto the silhouette.

Then a 1-px feather, a crop to the alpha bounding box, and an optional exposure grade —
applied AFTER the key, because a billboard figure is unshaded and its albedo is its final
colour (a pale figure at 0.6 m is a flashbang in a renderer with no tonemapping).

Usage:
    tools/cutout_green.py IN.jpg OUT.png [--dominance 40] [--min-green 80]
                                        [--margin 10] [--exposure 1.0]

⚠️ Re-import afterwards, or Godot keeps serving the old `.ctex`.
"""

import argparse
import sys
from collections import deque

from PIL import Image, ImageEnhance, ImageFilter


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--dominance", type=float, default=40.0,
                    help="G minus max(R, B) a pixel needs to count as screen")
    # ⚠️ A RATIO as well as a difference. The generator vignettes its screen: (30, 200, 40) in
    # the middle, (5, 20, 8) in the corners. The corners fail any absolute difference, but
    # green is still 2.5x the other channels there — and nothing on a body is.
    ap.add_argument("--ratio", type=float, default=1.6)
    ap.add_argument("--min-green", type=float, default=18.0)
    ap.add_argument("--margin", type=int, default=10)
    ap.add_argument("--exposure", type=float, default=1.0)
    a = ap.parse_args()

    im = Image.open(a.src).convert("RGB")
    w, h = im.size
    px = im.load()

    def is_screen(c):
        m = max(c[0], c[2])
        if c[1] < a.min_green:
            return False
        return (c[1] - m) >= a.dominance or c[1] >= a.ratio * max(m, 1)

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_screen(px[x, y]):
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y * w + x] and is_screen(px[x, y]):
                seen[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and is_screen(px[nx, ny]):
                seen[ny * w + nx] = 1
                q.append((nx, ny))

    alpha = Image.new("L", (w, h), 255)
    al = alpha.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            if seen[row + x]:
                al[x, y] = 0
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.9))

    # Despill: any opaque pixel that is still greener than its other channels is fringe.
    out = im.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = op[x, y]
            m = max(r, b)
            if g > m + 6:
                op[x, y] = (r, m + 3, b)
    if a.exposure != 1.0:
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
    opaque = sum(1 for v in out.getchannel("A").tobytes() if v > 128)
    print("wrote %s  %dx%d  aspect %.3f  opaque %.1f%%" % (a.dst, cw, ch, cw / ch, 100.0 * opaque / (cw * ch)))


if __name__ == "__main__":
    main()
