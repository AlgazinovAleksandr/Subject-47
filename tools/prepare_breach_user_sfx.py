#!/usr/bin/env python3
"""Swap the user's recordings in for the Breach approach placeholders; originals never modified.

The user dropped five recordings on 2026-09-24. Their originals live, unchanged, in
assets_src/audio/level_6_breach/approach/user/. Each replaces a placeholder AT ITS EXISTING GAME PATH,
so no code has to change except the purge door, which gets its own file (the bulkhead keeps
blast_door_slam, the user's call).

⚠️ LOUDNESS-MATCHED, NOT PEAK-NORMALISED. Every placeholder's playback gain in breach_approach.gd /
purge_chamber.gd was set from THAT file's measured RMS (the Issue 271 lesson: set a gain from the file,
never from a plausible number). So each new file is scaled to the placeholder's RMS (REF_RMS, measured
before the swap), and the mix the Master-bus probe measured stays where it was. A soft-knee limiter
above -3 dBFS keeps the peak under -0.3 dBFS without an audible clip. The purge slam is matched on
PEAK instead: it is one impact plus a 5 s reverb tail, and matching its whole-file RMS would make the
impact far hotter than the slam it replaces.

Mono, 44.1 kHz, 16-bit, like every placeholder. The valve-wheel grind loops (breach_approach.gd and the
seal race's pitched-down blast door both restart it), so its seam is crossfaded.

Requires ffmpeg. Deterministic.
"""
import array
import math
from pathlib import Path
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets_src/audio/level_6_breach/approach/user'
OUT = ROOT / 'game/assets/audio/level_6_breach'
RATE = 44100
CEIL = 10 ** (-0.3 / 20.0)
KNEE = 10 ** (-3.0 / 20.0)

# source -> (target, match mode, reference dBFS, loop seam seconds)
JOBS = [
    ('drop_chain.wav',       'approach_drop_chain.wav',     'rms',  -17.56, 0.0),
    # ⭐ 2026-09-24 (the user: "should be louder"): +4 dB denser than the placeholder it replaced. The
    # measured loudest window was already -7.5 dB at the listener, so a plain gain only hits the Master
    # limiter; raising the RMS through the soft knee packs more energy into the impact instead.
    ('drop_crash.wav',       'approach_drop_crash.wav',     'rms',  -10.7, 0.0),
    ('wheel_grind.wav',      'approach_wheel_grind.wav',    'rms',  -14.16, 0.4),
    ('metal_door_open.wav',  'approach_porthole_swing.wav', 'rms',  -20.44, 0.0),
    ('metal_door_close.wav', 'purge_door_slam.wav',         'peak', -1.01,  0.0),
    # The fused technician's scream when E is pressed (pass 5, 2026-09-24). A NEW file with no
    # placeholder to match, so it is peak-normalised; breach_approach.gd sets its gain from the
    # measured mix (probe_breach_music_mix.gd).
    ('man_scream.wav',       'approach_technician_scream.wav', 'peak', -1.5, 0.0),
]


def decode(path):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1',
                                   '-ar', str(RATE), '-f', 'f32le', '-'])
    return array.array('f', raw)


def crossfade_loop(s, seam):
    n = int(seam * RATE)
    if n < 2 or len(s) <= 2 * n:
        return s
    for i in range(n):
        t = i / (n - 1)
        s[i] = s[len(s) - n + i] * math.cos(t * math.pi / 2) + s[i] * math.sin(t * math.pi / 2)
    return s[:len(s) - n]


def limit(x):
    a = abs(x)
    if a <= KNEE:
        return x
    y = KNEE + (1.0 - KNEE) * math.tanh((a - KNEE) / (1.0 - KNEE))
    return math.copysign(y, x)


def main():
    for src, dst, mode, ref, seam in JOBS:
        s = crossfade_loop(decode(SRC / src), seam)
        rms = math.sqrt(sum(x * x for x in s) / len(s))
        peak = max(abs(x) for x in s)
        cur = rms if mode == 'rms' else peak
        gain = (10 ** (ref / 20.0)) / cur
        out = [limit(x * gain) for x in s]
        top = max(abs(x) for x in out)
        if top > CEIL:
            out = [x * CEIL / top for x in out]
        pcm = array.array('h', (int(round(max(-1.0, min(1.0, x)) * 32767)) for x in out))
        with wave.open(str(OUT / dst), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        f_rms = math.sqrt(sum(x * x for x in out) / len(out))
        print('%-22s -> %-28s %5.2f s  RMS %6.2f dBFS  peak %6.2f dBFS  (%s-matched to %.2f)'
              % (src, dst, len(out) / RATE, 20 * math.log10(f_rms),
                 20 * math.log10(max(abs(x) for x in out)), mode, ref))


if __name__ == '__main__':
    main()
