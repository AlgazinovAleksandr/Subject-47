#!/usr/bin/env python3
"""The grandfather clock's tick — a 1.0 s seamless loop (tick at 0.0 s, tock at 0.5 s).

Its own generator, NOT a new function appended to `make_sfx.py`: that file seeds once at module
scope and writes five files in order, so appending a sixth changes the RNG stream every later
call sees and silently rewrites `glass_shatter`/`beartrap_snap`/... (the `make_sfx_seam.py`
rule). Seeded, byte-reproducible.

The pendulum in `grandfather_clock.gd` swings a 2.0 s period, so one tick per half-swing.
Each transient decays inside 120 ms, so the loop seam is silence meeting silence. Peak is held
at -14 dBFS: the tick is room tone under the score, never a cue — it plays at -14 dB with
`unit_size` 4 and is inaudible from the far end of the segment by design.

    python3 tools/make_sfx_clock.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game/assets/audio/level_3_corridor/clock_tick.wav")
PEAK_DBFS = -14.0


def transient(pitch, dur, noise_amt, seed):
    rnd = random.Random(seed)
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 55.0)
        click = math.sin(2 * math.pi * pitch * t) * math.exp(-t * 180.0)
        body = math.sin(2 * math.pi * (pitch * 0.37) * t) * env * 0.6
        noise = (rnd.random() * 2 - 1) * math.exp(-t * 90.0) * noise_amt
        out.append(click * 0.9 + body + noise)
    return out


def main():
    total = int(SR * 1.0)
    buf = [0.0] * total
    for offset, pitch, seed in ((0.0, 2600.0, 217), (0.5, 2100.0, 218)):
        tr = transient(pitch, 0.14, 0.35, seed)
        start = int(offset * SR)
        for i, v in enumerate(tr):
            if start + i < total:
                buf[start + i] += v
    peak = max(abs(v) for v in buf) or 1.0
    gain = (10 ** (PEAK_DBFS / 20.0)) / peak
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * gain)) * 32767)) for v in buf)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    rms = math.sqrt(sum((v * gain) ** 2 for v in buf) / total)
    print("wrote %s  peak %.1f dBFS  rms %.1f dBFS" % (OUT, PEAK_DBFS, 20 * math.log10(rms)))


if __name__ == "__main__":
    main()
