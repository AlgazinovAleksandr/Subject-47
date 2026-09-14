#!/usr/bin/env python3
"""H2 (2026-09-13): the fridge chain — `chain_rattle` (E on the chained door: links jerk against
the padlock) and `chain_drop` (the cut chain sliding off and hitting the floor).

    python3 tools/make_sfx_house_chain.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

Pure stdlib, seeded, its own file (make_sfx_house.py seeds once at module scope). Base names
checked unique on 2026-09-13.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "level_2_house"))


def env(t, a, d):
    return (t / a) if t < a else math.exp(-(t - a) / d)


def link(t, f, amp):
    return amp * env(t, 0.001, 0.035) * (math.sin(2 * math.pi * f * t) + 0.6 * math.sin(2 * math.pi * f * 2.3 * t) + 0.3 * math.sin(2 * math.pi * f * 3.9 * t))


def write(name, out):
    peak = max(abs(v) for v in out)
    norm = 0.9 / peak
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * norm)) * 32767)) for v in out))
    rms = math.sqrt(sum((v * norm) ** 2 for v in out) / len(out))
    print("wrote %s  %.2fs  RMS %.1f dBFS" % (path, len(out) / SR, 20 * math.log10(rms)))


def add(out, start, fn, length):
    s0 = int(start * SR)
    for i in range(int(length * SR)):
        j = s0 + i
        if j < len(out):
            out[j] += fn(i / SR)


def main():
    rng = random.Random(777)
    # Rattle: a burst of ~18 link clinks over 0.7 s, then two heavier padlock knocks.
    n = int(SR * 1.0)
    out = [0.0] * n
    t0 = 0.0
    for k in range(18):
        t0 += rng.uniform(0.018, 0.05)
        add(out, t0, (lambda a, f: (lambda t: link(t, f, a)))(rng.uniform(0.3, 0.7), rng.uniform(2400, 4200)), 0.08)
    for tk in [0.36, 0.62]:
        add(out, tk, lambda t: 0.8 * env(t, 0.002, 0.05) * (math.sin(2 * math.pi * 620 * t) + 0.4 * math.sin(2 * math.pi * 1650 * t)), 0.2)
    write("chain_rattle.wav", out)
    # Drop: a sliding cascade of links (density rising, pitch falling) then a heap on the boards.
    n = int(SR * 1.5)
    out = [0.0] * n
    t0 = 0.0
    k = 0
    while t0 < 0.55:
        t0 += rng.uniform(0.008, 0.03) * (1.0 - 0.5 * t0)
        add(out, t0, (lambda a, f: (lambda t: link(t, f, a)))(rng.uniform(0.25, 0.6), rng.uniform(2000, 4400) - 1200 * t0), 0.07)
        k += 1
    add(out, 0.58, lambda t: 1.0 * env(t, 0.003, 0.07) * (math.sin(2 * math.pi * (95 + 60 * math.exp(-t * 30)) * t) + 0.35 * rng.uniform(-1, 1) * env(t, 0.001, 0.02)), 0.4)
    for tk in [0.66, 0.73, 0.82, 0.95]:
        add(out, tk, (lambda a, f: (lambda t: link(t, f, a)))(rng.uniform(0.15, 0.35), rng.uniform(2200, 3600)), 0.08)
    write("chain_drop.wav", out)


if __name__ == "__main__":
    main()
