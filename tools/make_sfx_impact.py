#!/usr/bin/env python3
"""`impact_thud` — the sub-bass hit under the false room 217's lunge (2026-09-10).

WHY THIS EXISTS
---------------
The user asked for the false door to be LOUDER — for the third time. The sting there is already
`all_levels_screamer` at -0.16 dBFS loudest-300 ms, i.e. at the Master hard limiter's ceiling;
no gain can make it louder and `tools/remaster_scares.py` has already said so. What is left is
CONTENT the scream does not have: a 45 Hz body hit with a 3 kHz click on the front, laid under
it at the moment the figure reaches your face. It is felt more than heard, it does not compete
with the scream's spectrum, and summed with it the limiter sees a denser signal — which is the
only kind of "louder" that exists past 0 dBFS.

Its own file: `make_sfx.py` seeds once at module scope and writes its five in order, so a sixth
appended there changes every later file's noise. Seeded, byte-reproducible, peak -1.0 dBFS.

    python3 tools/make_sfx_impact.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game/assets/audio/level_3_corridor/impact_thud.wav")
DUR = 0.55
PEAK_DBFS = -1.0


def main():
    rnd = random.Random(217)
    n = int(SR * DUR)
    out = []
    for i in range(n):
        t = i / SR
        # the body: a 45 Hz sine sweeping down to 30 Hz, decaying over ~0.4 s
        f = 45.0 - 15.0 * min(1.0, t / 0.35)
        body = math.sin(2 * math.pi * f * t) * math.exp(-t * 7.5)
        # a second harmonic for speakers that cannot reproduce 45 Hz
        body += 0.35 * math.sin(2 * math.pi * f * 2.0 * t) * math.exp(-t * 11.0)
        # the click on the front edge: 3 kHz, 8 ms
        click = math.sin(2 * math.pi * 3000.0 * t) * math.exp(-t * 320.0) * 0.6
        # a burst of noise for the "wood and cloth" of the impact, 60 ms
        noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 45.0) * 0.5
        out.append(body + click + noise)
    peak = max(abs(v) for v in out) or 1.0
    gain = (10 ** (PEAK_DBFS / 20.0)) / peak
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * gain)) * 32767)) for v in out)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    rms = math.sqrt(sum((v * gain) ** 2 for v in out) / n)
    print("wrote %s  peak %.1f dBFS  rms %.1f dBFS  %.2f s" % (OUT, PEAK_DBFS, 20 * math.log10(rms), DUR))


if __name__ == "__main__":
    main()
