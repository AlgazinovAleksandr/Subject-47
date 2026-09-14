#!/usr/bin/env python3
"""Key a BLACK-background figure to real alpha (L1.5, 2026-09-13: monster_in_the_dark.png).

    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/cutout_black.py <in> <out> [LO HI] [--crop]

`LO HI` override the thresholds (a dark-clothed figure on pure black wants ~3 12; the wing
monster's black is dirtier and wants the 10 34 defaults). `--crop` trims to the opaque bounds
plus a margin, so a quad sized from the aspect is the FIGURE, not the canvas.

Luminance below LO -> transparent, above HI -> opaque, a soft ramp between — and the alpha is
blurred slightly so the ramp does not alias. The figure itself is dark, so the thresholds are
LOW (the eyes/teeth are the bright parts; the body sits at 15-60/255 against a 0-8 backdrop).
An unshaded billboard of the raw file would be a black RECTANGLE with a face in it; in a
pitch-black wing that is invisible until the torch or a marker catches its edge.
"""

import sys
from PIL import Image, ImageFilter

LO, HI = 10, 34


def main():
    src, dst = sys.argv[1], sys.argv[2]
    args = [x for x in sys.argv[3:] if not x.startswith("--")]
    lo, hi = (int(args[0]), int(args[1])) if len(args) >= 2 else (LO, HI)
    im = Image.open(src).convert("RGBA")
    lum = im.convert("L")
    a = lum.point(lambda v: 0 if v <= lo else (255 if v >= hi else int(255 * (v - lo) / (hi - lo))))
    a = a.filter(ImageFilter.GaussianBlur(1.0))
    im.putalpha(a)
    if "--crop" in sys.argv:
        bbox = a.point(lambda v: 255 if v > 8 else 0).getbbox()
        if bbox:
            m = 12
            im = im.crop((max(0, bbox[0] - m), max(0, bbox[1] - m), min(im.size[0], bbox[2] + m), min(im.size[1], bbox[3] + m)))
            a = im.getchannel("A")
    im.save(dst)
    cov = sum(1 for v in a.getdata() if v > 0) / float(im.size[0] * im.size[1])
    print("wrote", dst, im.size, "opaque coverage %.1f %%" % (cov * 100))


if __name__ == "__main__":
    main()
