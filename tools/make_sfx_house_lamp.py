#!/usr/bin/env python3
"""`lamp_wake` — the sound of the one lamp coming on at the far end of a dark house.

    python3 tools/make_sfx_house_lamp.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

Writes ONE file: game/assets/audio/level_2_house/lamp_wake.wav
Pure stdlib, seeded, byte-reproducible — the same contract as every other tools/make_sfx*.py.

⚠️ ITS OWN FILE, NOT AN ADDITION TO make_sfx_house.py. That generator seeds once at module scope
and writes its files in order, so appending an eighth call changes the RNG stream every later
call sees and silently rewrites sounds that are already balanced. `make_sfx_seam.py` and
`make_sfx_kontur_extra.py` exist for exactly this reason and their headers say so.

⚠️ THE BASE NAME MUST STAY GLOBALLY UNIQUE. `GameState.load_audio()` resolves by base name across
a hardcoded list of subdirs and the FIRST hit wins — `door_slam` exists in two folders and the
wrong one silently wins. `lamp_wake` was checked against every .wav/.ogg/.mp3 base name in the
project on 2026-09-03 and collides with nothing (`mirror_wake`, `candle_light` and `light_pop`
are the nearest neighbours).

WHAT IT IS. The House now stays pitch black until all three safe notes are found, and then
exactly one wall lamp — the one beside the combination lock, the length of the house away —
fades up over 2.2 s. The sound has to carry three things and no more:

  1. a contactor THUNK, so it reads as something being switched on rather than appearing;
  2. a filament/ballast rise that is slow enough to sit under a 2.2 s fade;
  3. a 50 Hz-ish mains hum that arrives with it and settles, so what is left behind is a lamp
     that is now audibly ON in a house that was silent.

⚠️ AND IT IS NOT A STING. The player is being rewarded, not attacked — no transient over about
-6 dBFS, no scream, nothing in the 2-4 kHz band that reads as a shriek. It is deliberately NOT
routed through `sfx_loudness.loudify()`, which is for scares; this file wants its crest factor.
It is peak-normalised like the rest of the House's SFX and its level is set at the call site.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

SR = 44100
SEED = 20260903
OUT_DIR = os.path.join(
    os.path.dirname(__file__), "..", "game", "assets", "audio", "level_2_house")
NAME = "lamp_wake.wav"
DUR = 3.1          # the fade is 2.2 s; the hum settles under it and tails out


class OnePole:
    def __init__(self, cutoff_hz: float) -> None:
        self.a = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / SR)
        self.y = 0.0

    def tick(self, x: float) -> float:
        self.y += self.a * (x - self.y)
        return self.y


def contactor_thunk(n: int) -> list:
    """A relay closing: a hard low knock with a tiny metallic click on top."""
    out = []
    lp = OnePole(220.0)
    for i in range(n):
        t = i / SR
        # pitch-dropping body, the sound of a solenoid seating
        f = 120.0 * math.exp(-t * 26.0) + 44.0
        body = math.sin(math.tau * f * t) * math.exp(-t * 22.0)
        click = lp.tick(random.uniform(-1.0, 1.0)) * math.exp(-t * 150.0)
        out.append(body * 0.9 + click * 0.5)
    return out


def filament_rise(n: int) -> list:
    """Bandpassed noise swelling in over ~1.6 s — the element warming, not a whoosh."""
    out = []
    hi = OnePole(1500.0)
    lo = OnePole(280.0)
    for i in range(n):
        t = i / SR
        x = random.uniform(-1.0, 1.0)
        band = hi.tick(x) - lo.tick(x)
        # slow S-curve up, then hold; nothing percussive
        env = 1.0 / (1.0 + math.exp(-(t - 0.85) * 4.6))
        env *= math.exp(-max(0.0, t - 2.0) * 1.6)
        # a little irregular flutter so it is a failing old fitting, not a synth pad
        flutter = 0.82 + 0.18 * math.sin(math.tau * 6.3 * t + math.sin(t * 21.0))
        out.append(band * env * flutter)
    return out


def mains_hum(n: int) -> list:
    """50 Hz plus its odd harmonics, arriving with the light and settling."""
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 1.1) * math.exp(-max(0.0, t - 1.9) * 1.1)
        v = (math.sin(math.tau * 50.0 * t)
             + 0.34 * math.sin(math.tau * 150.0 * t)
             + 0.12 * math.sin(math.tau * 250.0 * t))
        out.append(v * env * 0.34)
    return out


def main() -> int:
    random.seed(SEED)
    n = int(SR * DUR)
    total = [0.0] * n

    thunk = contactor_thunk(int(SR * 0.35))
    for i, s in enumerate(thunk):
        total[i] += s * 1.0

    for i, s in enumerate(filament_rise(n)):
        total[i] += s * 0.85

    for i, s in enumerate(mains_hum(n)):
        total[i] += s

    # gentle tail so it does not stop dead
    fade = int(SR * 0.45)
    for i in range(fade):
        total[n - 1 - i] *= i / fade

    peak = max(1e-9, max(abs(s) for s in total))
    norm = 0.89 / peak
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.normpath(os.path.join(OUT_DIR, NAME))
    frames = bytearray()
    for s in total:
        frames += struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))

    # Print the measurement, so the gain at the call site is derived rather than guessed.
    scaled = [s * norm for s in total]
    rms = math.sqrt(sum(s * s for s in scaled) / len(scaled))
    win = int(SR * 0.3)
    best = 0.0
    for i in range(0, len(scaled) - win, win // 4):
        seg = scaled[i:i + win]
        best = max(best, math.sqrt(sum(s * s for s in seg) / len(seg)))
    db = lambda v: 20.0 * math.log10(v) if v > 0 else -99.0
    print("wrote %s (%.2fs)" % (path, DUR))
    print("  peak %.2f dBFS   rms %.2f dBFS   loudest-300ms %.2f dBFS"
          % (db(0.89), db(rms), db(best)))
    print("  NOW RUN:  Godot --headless --path game --import")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
