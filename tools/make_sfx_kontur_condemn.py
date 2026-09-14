#!/usr/bin/env python3
"""`kontur_condemn` — the drone under the 20 s sentence (K2, 2026-09-13). LOOPS.

    python3 tools/make_sfx_kontur_condemn.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

Writes ONE file: game/assets/audio/level_5_kontur/kontur_condemn.wav — an 8 s seamless loop of
two detuned low tones with a slow beat and a grainy upper partial. The RISE is done in-engine
(`kontur.gd:_tick_condemn` rides pitch_scale 0.8 -> 1.4), so the file itself is steady.
Seamless by construction: every modulation completes whole cycles in the loop. Own file, own
seed, for the reason make_sfx_kontur_extra.py's header gives. Prints the measured RMS/peak —
`CONDEMN_DRONE_DB` is set from that.
"""

import math
import os
import random
import struct
import wave

SR = 44100
LOOP_S = 8.0
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio",
                                    "level_5_kontur", "kontur_condemn.wav"))
# K3 (2026-09-13): the DISCORDANT BED that fades in at 6 s of the sentence — a detuned choir
# cluster (a minor second and a tritone against the root, each voice a little sharp or flat),
# slow amplitude wobble, no beat. Own seed, own file; the drone above is unchanged.
OUT_BED = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio",
                                        "level_5_kontur", "kontur_condemn_bed.wav"))


def bed():
    rng = random.Random(4041)
    n = int(SR * LOOP_S)
    voices = []
    for base in [220.0, 233.1, 311.1, 466.2]:          # A3, Bb3 (minor 2nd), Eb4 (tritone), Bb4
        for k in range(3):
            voices.append((base * (1.0 + rng.uniform(-0.009, 0.009)), rng.uniform(0, 6.28), rng.uniform(0.4, 1.0)))
    out = []
    for i in range(n):
        t = i / SR
        wob = 0.6 + 0.4 * math.sin(2 * math.pi * (1.0 / LOOP_S) * 1 * t)          # 1 cycle per loop
        s = 0.0
        for f, ph, g in voices:
            # a soft "vowel": fundamental + two quiet partials
            s += g * (math.sin(2 * math.pi * f * t + ph) + 0.35 * math.sin(2 * math.pi * 2 * f * t + ph) + 0.15 * math.sin(2 * math.pi * 3 * f * t))
        out.append(s * wob / len(voices))
    xf = int(SR * 0.25)
    for i in range(xf):
        w = i / xf
        out[i] = out[i] * w + out[n - xf + i] * (1 - w)
    peak = max(abs(v) for v in out)
    norm = 0.7 / peak
    with wave.open(OUT_BED, "wb") as wv:
        wv.setnchannels(1); wv.setsampwidth(2); wv.setframerate(SR)
        wv.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * norm)) * 32767)) for v in out))
    rms = math.sqrt(sum((v * norm) ** 2 for v in out) / n)
    print("wrote %s  %.1fs  RMS %.1f dBFS" % (OUT_BED, LOOP_S, 20 * math.log10(rms)))


def main():
    rng = random.Random(2020)
    n = int(SR * LOOP_S)
    # Grainy circular noise bed, low-passed.
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    lp = [0.0] * n
    a = 1.0 - math.exp(-2 * math.pi * 400.0 / SR)
    y = 0.0
    for k in range(2):                       # two passes round the loop so the state is circular
        for i in range(n):
            y += a * (noise[i] - y)
            lp[i] = y
    out = []
    for i in range(n):
        t = i / SR
        beat = 0.5 + 0.5 * math.sin(2 * math.pi * (1.0 / LOOP_S) * 2 * t)          # 2 cycles
        slow = 0.5 + 0.5 * math.sin(2 * math.pi * (1.0 / LOOP_S) * 3 * t + 1.0)    # 3 cycles
        f1, f2 = 55.0, 55.0 * 1.0075
        s = 0.55 * math.sin(2 * math.pi * f1 * t) + 0.45 * math.sin(2 * math.pi * f2 * t)
        s += 0.25 * math.sin(2 * math.pi * 110.5 * t) * (0.6 + 0.4 * beat)
        s += 0.12 * math.sin(2 * math.pi * 164.0 * t) * slow
        s += 0.18 * lp[i] * (0.5 + 0.5 * beat)
        out.append(s)
    # Fundamental phases must close over the loop: 55 Hz * 8 s = 440 cycles exactly; 55*1.0075*8
    # = 443.3 — so window the detuned partial's phase error away with a tiny crossfade.
    xf = int(SR * 0.05)
    for i in range(xf):
        w = i / xf
        out[i] = out[i] * w + out[n - xf + i] * (1 - w)
    peak = max(abs(v) for v in out)
    norm = 0.85 / peak
    with wave.open(OUT, "wb") as wv:
        wv.setnchannels(1); wv.setsampwidth(2); wv.setframerate(SR)
        wv.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * norm)) * 32767)) for v in out))
    rms = math.sqrt(sum((v * norm) ** 2 for v in out) / n)
    print("wrote %s  %.1fs  RMS %.1f dBFS  peak %.1f dBFS" % (OUT, LOOP_S, 20 * math.log10(rms), 20 * math.log10(0.85)))


if __name__ == "__main__":
    main()
    bed()
