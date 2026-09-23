#!/usr/bin/env python3
"""PLACEHOLDER for the Breach cell chamber's CCTV loop (2026-09-23 pass 3).

⚠️ THE USER WILL GENERATE THE REAL CLIP. Drop it at game/assets/video/breach_cctv_breakout.ogv,
converted with the Theora recipe in assets_src/README.md (Godot's VideoStreamPlayer decodes Ogg
Theora and nothing else), then re-run `--import`. Nothing in the code names this tool.

What the stand-in shows, so the monitor tells the story until then: a fixed high camera on a
glass tank in a dim cell. A dark shape stands in the tank; it slams the glass twice, the glass
bursts outward, a smear rushes the lens, the signal drops out, and the tank is empty. Monochrome,
grainy, 480x360 at 15 fps, 8 s, looping. The grain, scanlines and timestamp are NOT baked in:
`breach_approach.gd` lays those over whatever clip is playing (a shader and a Label3D), so the
user's clip gets the same treatment.

Needs Pillow (the image pack's venv) and ffmpeg with libtheora:
    ~/Downloads/claude-image-generation-main/.venv/bin/python3 tools/make_breach_cctv_placeholder.py
"""
import math
import os
import random
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "video", "breach_cctv_breakout.ogv")
W, H, FPS, SECONDS = 480, 360, 15, 8.0
rng = random.Random(1203)

# the tank, as a box seen from a high corner
TANK_FRONT = [(170, 120), (330, 120), (330, 300), (170, 300)]
TANK_BACK = [(205, 95), (355, 95), (355, 250), (205, 250)]


def room(draw):
    draw.rectangle([0, 0, W, H], fill=(38, 42, 38))
    draw.polygon([(0, 260), (W, 230), (W, H), (0, H)], fill=(28, 31, 28))        # floor
    draw.polygon([(0, 0), (120, 0), (90, 260), (0, 270)], fill=(33, 37, 33))    # side wall


def tank(draw, burst):
    draw.polygon(TANK_BACK, outline=(92, 100, 92), fill=(46, 52, 47))
    for a, b in zip(TANK_FRONT, TANK_BACK):
        draw.line([a, b], fill=(110, 118, 108), width=3)
    draw.line([TANK_FRONT[0], TANK_FRONT[1]], fill=(120, 128, 118), width=4)
    draw.line([TANK_FRONT[3], TANK_FRONT[2]], fill=(120, 128, 118), width=4)
    draw.line([TANK_FRONT[0], TANK_FRONT[3]], fill=(120, 128, 118), width=4)
    draw.line([TANK_FRONT[1], TANK_FRONT[2]], fill=(120, 128, 118), width=4)
    if burst:
        r = random.Random(7)
        for _ in range(22):   # jagged remains round the frame, shards on the floor
            x = r.randint(172, 328)
            draw.line([(x, 122), (x + r.randint(-14, 14), 122 + r.randint(6, 30))], fill=(150, 158, 148), width=2)
            draw.line([(x, 298), (x + r.randint(-14, 14), 298 - r.randint(6, 26))], fill=(150, 158, 148), width=2)
        for _ in range(60):
            x = r.randint(90, 380)
            y = r.randint(290, 350)
            draw.line([(x, y), (x + r.randint(-5, 5), y + r.randint(-3, 3))], fill=(160, 168, 156), width=1)
        draw.ellipse([205, 245, 300, 275], fill=(18, 18, 18))   # the stain it left


def figure(img, cx, cy, scale, blur, alpha=235):
    lay = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(lay)
    s = scale
    d.ellipse([cx - 14 * s, cy - 92 * s, cx + 14 * s, cy - 58 * s], fill=alpha)           # head
    d.polygon([(cx - 16 * s, cy - 104 * s), (cx - 4 * s, cy - 88 * s), (cx + 4 * s, cy - 88 * s),
               (cx + 16 * s, cy - 104 * s), (cx + 8 * s, cy - 84 * s), (cx - 8 * s, cy - 84 * s)], fill=alpha)  # crown
    d.polygon([(cx - 26 * s, cy - 60 * s), (cx + 26 * s, cy - 60 * s), (cx + 18 * s, cy), (cx - 18 * s, cy)], fill=alpha)
    d.line([(cx - 24 * s, cy - 56 * s), (cx - 38 * s, cy + 6 * s)], fill=alpha, width=int(7 * s) + 1)
    d.line([(cx + 24 * s, cy - 56 * s), (cx + 38 * s, cy + 6 * s)], fill=alpha, width=int(7 * s) + 1)
    d.line([(cx - 10 * s, cy), (cx - 12 * s, cy + 52 * s)], fill=alpha, width=int(8 * s) + 1)
    d.line([(cx + 10 * s, cy), (cx + 12 * s, cy + 52 * s)], fill=alpha, width=int(8 * s) + 1)
    lay = lay.filter(ImageFilter.GaussianBlur(blur))
    img.paste(Image.new("RGB", (W, H), (8, 9, 8)), (0, 0), lay)


def frame(t):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    room(d)
    burst = t >= 3.3
    tank(d, burst)
    if t < 2.4:
        figure(img, 262 + math.sin(t * 1.3) * 2, 262, 1.0, 1.6)
    elif t < 3.3:
        # two slams against the glass: it lurches forward and back
        k = (t - 2.4) / 0.45
        lunge = abs(math.sin(k * math.pi))
        figure(img, 258, 270 + lunge * 16, 1.0 + lunge * 0.12, 1.8 + lunge * 2)
        if 2.85 < t < 2.95 or 3.15 < t < 3.25:
            d.line([(210, 150), (250, 200), (300, 170)], fill=(190, 198, 188), width=2)   # a crack flashes
    elif t < 3.9:
        # the burst: a white flash, then the smear rushes the lens
        k = (t - 3.3) / 0.6
        if k < 0.15:
            d.rectangle([0, 0, W, H], fill=(210, 220, 208))
        figure(img, 250 - 60 * k, 250 + 140 * k, 1.2 + 4.2 * k * k, 5 + 22 * k, 250)
    elif t < 4.6:
        pass   # dropout: the whole frame is noise (below)
    # grain in the footage itself (the shader adds its own on top)
    noise = Image.effect_noise((W, H), 34 if 3.9 <= t < 4.6 else 14).convert("RGB")
    amt = 0.92 if 3.9 <= t < 4.6 else 0.12
    img = Image.blend(img, noise, amt)
    img = img.convert("L").convert("RGB")
    # a green-grey CCTV cast
    r, g, b = img.split()
    img = Image.merge("RGB", (r.point(lambda v: int(v * 0.86)), g, b.point(lambda v: int(v * 0.8))))
    return img


def main():
    ff = shutil.which("ffmpeg")
    assert ff, "ffmpeg is required"
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        count = int(SECONDS * FPS)
        for i in range(count):
            frame(i / FPS).save(os.path.join(tmp, f"f{i:04d}.png"))
        subprocess.run([ff, "-v", "error", "-y", "-framerate", str(FPS), "-i", os.path.join(tmp, "f%04d.png"),
                        "-c:v", "libtheora", "-q:v", "7", "-an", OUT], check=True)
    print(f"wrote {OUT} ({os.path.getsize(OUT)} bytes, {SECONDS:.0f} s at {FPS} fps)")


if __name__ == "__main__":
    main()
