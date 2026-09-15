#!/usr/bin/env python3
"""`lock_drop` — a padlock coming off the child's-room door and hitting the boards (H4, 2026-09-13).

    python3 tools/make_sfx_house_lock.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

Writes ONE file: game/assets/audio/level_2_house/lock_drop.wav. Pure stdlib, seeded,
byte-reproducible. Its own file for the reason make_sfx_house_lamp.py gives: make_sfx_house.py
seeds once at module scope and appending a call there rewrites every later sound.

Base name checked unique across game/assets/audio on 2026-09-13 (nearest: lock_buzz).

Shape: a shackle CLICK (short bright metallic ping), 0.18 s of nothing (the fall), a heavy
KNOCK on the boards (low thud + wood ring), one lighter bounce, then a short rattle dying out.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio",
                                    "level_2_house", "lock_drop.wav"))


def env(t, a, d):
    return (t / a) if t < a else math.exp(-(t - a) / d)


def metal_ping(t, f, decay, amp):
    return amp * env(t, 0.002, decay) * (math.sin(2 * math.pi * f * t)
        + 0.5 * math.sin(2 * math.pi * f * 2.76 * t) + 0.3 * math.sin(2 * math.pi * f * 5.4 * t))


def knock(t, amp, rng):
    thud = math.sin(2 * math.pi * (70.0 + 40.0 * math.exp(-t * 30.0)) * t) * env(t, 0.003, 0.06)
    ring = 0.35 * math.sin(2 * math.pi * 410.0 * t) * env(t, 0.002, 0.05)
    noise = 0.25 * rng.uniform(-1, 1) * env(t, 0.001, 0.02)
    return amp * (thud + ring + noise)


def main():
    rng = random.Random(1313)
    n = int(SR * 1.35)
    out = [0.0] * n
    def add(start, fn, length):
        s0 = int(start * SR)
        for i in range(int(length * SR)):
            j = s0 + i
            if j < n:
                out[j] += fn(i / SR)
    add(0.0, lambda t: metal_ping(t, 2900.0, 0.05, 0.6), 0.25)          # shackle click
    add(0.22, lambda t: knock(t, 1.0, rng), 0.35)                        # boards
    add(0.24, lambda t: metal_ping(t, 1900.0, 0.08, 0.35), 0.3)          # body ring
    add(0.47, lambda t: knock(t, 0.45, rng), 0.25)                       # bounce
    add(0.49, lambda t: metal_ping(t, 2300.0, 0.05, 0.2), 0.2)
    for k in range(6):                                                   # rattle dying out
        add(0.62 + k * 0.055 + rng.uniform(0, 0.015),
            (lambda a: (lambda t: metal_ping(t, 2100.0 + rng.uniform(-200, 200), 0.03, a)))(0.14 * (0.72 ** k)), 0.12)
    peak = max(abs(v) for v in out)
    norm = 0.92 / peak
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * norm)) * 32767)) for v in out))
    rms = math.sqrt(sum((v * norm) ** 2 for v in out) / n)
    print("wrote %s  %.2fs  RMS %.1f dBFS" % (OUT, n / SR, 20 * math.log10(max(rms, 1e-9))))


if __name__ == "__main__":
    main()
