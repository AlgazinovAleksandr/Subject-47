#!/usr/bin/env python3
"""KONTUR Recovery Archive: the security keycard hidden in one of the six lots (2026-09-10,
capture #13). It was a plain green emissive box. This draws a facility pass — a Cyrillic
K.O.N.T.U.R. header band, a mugshot SILHOUETTE (never a face — flux is not asked for one and
Pillow cannot draw one), a subject number, a barcode and a magnetic stripe on the back.
Two faces in one image, stacked: the top half is the FRONT, the bottom half the BACK, so
`kontur.gd` samples each with a uv1 sub-rect (the note/door crop convention).

Pillow, deterministic (a seeded pseudo-random barcode). Needs the image pack's venv:
    $PACK/.venv/bin/python3 tools/make_archive_keycard.py
then `Godot --headless --path game --import`.
"""
import os
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "textures", "level_5_kontur", "archive_keycard.png")
FONT_CYR = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
W, H = 1100, 700           # one face; the file is W x 2H
CARD = (168, 158, 132)      # aged cream plastic, darkened for the level's dark half
INK = (28, 26, 24)
OX = (98, 20, 18)           # the signs' oxblood


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    if not os.path.exists(path):
        path = FONT_BOLD
    return ImageFont.truetype(path, size)


def grain(im: Image.Image, seed: int, amount: int = 14) -> Image.Image:
    rnd = random.Random(seed)
    px = im.load()
    for y in range(0, im.height, 2):
        for x in range(0, im.width, 2):
            d = rnd.randint(-amount, amount)
            r, g, b = px[x, y]
            px[x, y] = (max(0, min(255, r + d)), max(0, min(255, g + d)), max(0, min(255, b + d)))
    return im


def front() -> Image.Image:
    im = Image.new("RGB", (W, H), CARD)
    d = ImageDraw.Draw(im)
    # Header band.
    d.rectangle([0, 0, W, int(H * 0.19)], fill=OX)
    f = font(FONT_CYR, int(H * 0.11))
    d.text((int(W * 0.04), int(H * 0.035)), "К.О.Н.Т.У.Р.", font=f, fill=(214, 196, 160))
    f2 = font(FONT_CYR, int(H * 0.05))
    d.text((int(W * 0.60), int(H * 0.07)), "ПРОПУСК  •  ОБЪЕКТ 12", font=f2, fill=(214, 196, 160))
    # Mugshot silhouette box.
    bx0, by0, bx1, by1 = int(W * 0.05), int(H * 0.25), int(W * 0.32), int(H * 0.92)
    d.rectangle([bx0, by0, bx1, by1], fill=(120, 112, 92), outline=INK, width=3)
    cx = (bx0 + bx1) // 2
    head_r = int((bx1 - bx0) * 0.20)
    d.ellipse([cx - head_r, by0 + int(H * 0.07), cx + head_r, by0 + int(H * 0.07) + 2 * head_r],
              fill=(44, 40, 36))
    d.rounded_rectangle([bx0 + int(W * 0.03), by0 + int(H * 0.07) + 2 * head_r - 10,
                         bx1 - int(W * 0.03), by1 - 6], radius=40, fill=(44, 40, 36))
    # Fields.
    f3 = font(FONT_CYR, int(H * 0.055))
    f4 = font(FONT_BOLD, int(H * 0.11))
    y = int(H * 0.27)
    for label, value in [("ФАМИЛИЯ", "————————"), ("ДОПУСК", "УРОВЕНЬ 4 / КРЫЛО 4"),
                         ("СУБЪЕКТ", "")]:
        d.text((int(W * 0.37), y), label, font=f3, fill=(70, 62, 52))
        d.text((int(W * 0.37), y + int(H * 0.06)), value, font=f3, fill=INK)
        y += int(H * 0.15)
    d.text((int(W * 0.37), int(H * 0.62)), "№ 47", font=f4, fill=INK)
    # A stamp, rotated.
    st = Image.new("RGBA", (int(W * 0.34), int(H * 0.16)), (0, 0, 0, 0))
    sd = ImageDraw.Draw(st)
    sd.rectangle([0, 0, st.width - 1, st.height - 1], outline=(140, 30, 26, 200), width=6)
    sd.text((int(st.width * 0.06), int(st.height * 0.18)), "ИЗЪЯТО", font=font(FONT_CYR, int(H * 0.09)),
            fill=(140, 30, 26, 190))
    st = st.rotate(-11, expand=True, resample=Image.BICUBIC)
    im.paste(st, (int(W * 0.56), int(H * 0.70)), st)
    return grain(im, 7)


def back() -> Image.Image:
    im = Image.new("RGB", (W, H), CARD)
    d = ImageDraw.Draw(im)
    d.rectangle([0, int(H * 0.10), W, int(H * 0.30)], fill=(22, 20, 20))     # mag stripe
    rnd = random.Random(217)
    x = int(W * 0.08)
    y0, y1 = int(H * 0.45), int(H * 0.80)
    while x < int(W * 0.92):
        bw = rnd.choice([3, 3, 5, 5, 8, 12])
        gap = rnd.choice([3, 5, 7])
        d.rectangle([x, y0, x + bw, y1], fill=INK)
        x += bw + gap
    f = font(FONT_BOLD, int(H * 0.055))
    d.text((int(W * 0.08), int(H * 0.83)), "23-Z  0047  0012  KONTUR-4", font=f, fill=INK)
    f2 = font(FONT_CYR, int(H * 0.04))
    d.text((int(W * 0.08), int(H * 0.34)),
           "НЕ ПЕРЕДАВАТЬ. ПРИ НАХОДКЕ ВЕРНУТЬ В АРХИВ ВОССТАНОВЛЕНИЯ.", font=f2, fill=(70, 62, 52))
    return grain(im, 12)


def main() -> None:
    sheet = Image.new("RGB", (W, 2 * H), CARD)
    sheet.paste(front(), (0, 0))
    sheet.paste(back(), (0, H))
    # Soften the crisp vector look a touch — this is a scuffed card under a torch.
    sheet = sheet.filter(ImageFilter.GaussianBlur(0.6))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, "PNG", optimize=True)
    print("wrote %s (%dx%d: front on top, back below)" % (os.path.relpath(OUT, ROOT), W, 2 * H))


if __name__ == "__main__":
    main()
