#!/usr/bin/env python3
"""Shared loudness pipeline for the game's scare stings. Pure stdlib, deterministic.

    from sfx_loudness import measure, loudify, LOUD_TARGET_DB

WHY THIS EXISTS.
Every screamer in the game is played by `screamer.gd` at a hard-coded `0.0 dB` on Master —
`flash_scare()` takes no gain argument and `trigger()` sets no `volume_db`. So **the choice
of file IS the volume control**, and on 2026-09-03 the eight fatal per-level screamers were
measured spanning **-12.62 dBFS (Lab) to -0.18 (dark_jumpscare)** in loudest-300 ms terms —
a 12 dB spread on assets that are all supposed to be "the loud one".

Every one of them is already peak-normalised, so **a gain cannot fix this**. The only lever
is CREST FACTOR, and this module is that lever:

    compress (envelope)  ->  peak normalise  ->  tanh saturate  ->  peak normalise back

⚠️ THE CRITICAL MEASUREMENT, from `make_sfx_mirror.py`'s own header (2026-08-17), reproduced
here because it is the reason this module saturates rather than merely compressing:

    shipped ...................................... -14.03 dBFS
    + envelope compression alone, six settings ... -14.6 .. -12.0
    + tanh drive 3 ............................... -5.69
    + tanh drive 6 ............................... -3.33
    + tanh drive 16 .............................. -1.82

Compression alone bought **2 dB in the best case and nothing in the worst**. That is physics,
not a tuning miss: limiting an envelope does not raise a waveform's RMS toward its peak.
`shared/jumpscare.wav`, the densest asset in the project, has a crest factor of 2.1 dB, and
2 dB of crest factor is only reachable with saturation.

⚠️ THE PEAK IS PRESERVED, ALWAYS. `loudify()` restores the input's own peak on the way out, so
nothing this module touches can start clipping the master that did not clip before. What
changes is the average level — which is exactly what "louder" means for a file that already
touches 0 dBFS.

⚠️ DRIVE IS SEARCHED, NOT TYPED. `loudify()` binary-searches the smallest drive that reaches
the requested target and stops there, because tanh distortion is monotone in drive and the
character of the sound degrades with it. A file that already meets its target is returned
untouched with `drive == 0.0`.
"""

from __future__ import annotations

import math

# The band every fatal sting is aimed at. `shared/jumpscare.wav` measures -2.14 dBFS
# loudest-300 ms and is the reference "this is what loud sounds like in this game";
# -3.0 leaves a hair of room so the quiet files are not driven harder than the loudest
# asset in the project.
LOUD_TARGET_DB = -3.0

# Ceiling on the search. Past ~16 the tanh buzz is audible as a character change rather
# than as loudness; make_sfx_mirror.py measured -1.82 dBFS at drive 16 and called it
# "audibly buzzing". A file that cannot reach its target by the ceiling is reported, not
# forced.
#
# ⚠️ 9.0, NOT 16.0, and the reason is a measurement rather than caution. Sweeping the eleven
# sourced stings on 2026-09-03, the drive each one needed to reach -3.0 dBFS had almost no
# relationship to how much it gained:
#
#     screamer_lab       drive 8.09  ->  +9.61 dB     <- worth it
#     kontur_scream      drive 2.05  ->  +3.19 dB     <- worth it
#     screamer_void      drive 9.26  ->  +1.22 dB     <- distortion bought for nothing
#     level_6_jumpscare  drive 8.91  ->  +1.20 dB     <- ditto
#     screamer_dungeon   drive 4.11  ->  +0.88 dB     <- ditto
#
# A file that needs a big drive for a small gain is a file that was ALREADY dense; tanh has
# nothing left to straighten and is just adding harmonics. Callers should also refuse to write
# a result whose gain is under MIN_WORTH_DB — see `remaster_scares.py`.
MAX_DRIVE = 9.0

# Below this, the loudness change is inaudible and the distortion is not. Callers use it to
# decide whether to write at all.
MIN_WORTH_DB = 1.5

WINDOW_S = 0.300


def db(v: float) -> float:
    return 20.0 * math.log10(v) if v > 1e-12 else -99.0


def measure(samples, sr: int):
    """(peak_dbfs, loudest_300ms_dbfs) for a mono float buffer in [-1, 1].

    ⚠️ The window RMS is computed from a prefix sum of squares, not by re-summing a window
    per position. The naive form is O(n*w) and on a 10 s file at 44.1 kHz that is 5.8e9
    multiplies — slow enough that a caller would be tempted to subsample, which is how a
    measurement stops measuring the loudest part.
    """
    n = len(samples)
    if n == 0:
        return -99.0, -99.0
    peak = max(abs(s) for s in samples)
    w = min(n, max(1, int(sr * WINDOW_S)))
    acc = 0.0
    prefix = [0.0] * (n + 1)
    for i, s in enumerate(samples):
        acc += s * s
        prefix[i + 1] = acc
    best = 0.0
    for i in range(0, n - w + 1):
        ms = (prefix[i + w] - prefix[i]) / w
        if ms > best:
            best = ms
    return db(peak), db(math.sqrt(best))


def compress(samples, sr: int = 44100, threshold=0.02, ratio=30.0,
             attack_ms=0.3, release_ms=12.0):
    """Deterministic feed-forward compressor. Lifted verbatim from `make_sfx_mirror.py`.

    Single pass, no randomness, no numpy — byte-identical across runs like every other
    generator in tools/. The attack/release constants were tuned at 44.1 kHz, which is the
    only rate any asset in this project uses; `sr` is a parameter so that assumption is
    visible rather than a bare literal buried in an exp().
    """
    atk = math.exp(-1.0 / (attack_ms * 0.001 * sr))
    rel = math.exp(-1.0 / (release_ms * 0.001 * sr))
    env = 0.0
    out = []
    for s in samples:
        rect = abs(s)
        coeff = atk if rect > env else rel
        env = coeff * env + (1.0 - coeff) * rect
        gain = 1.0
        if env > threshold:
            gain = (threshold + (env - threshold) / ratio) / env
        out.append(s * gain)
    return out


def saturate(samples, drive: float):
    return [math.tanh(s * drive) for s in samples]


def loudify(samples, sr: int, target_db: float = LOUD_TARGET_DB, max_drive: float = MAX_DRIVE):
    """Raise a buffer's loudest-300 ms toward `target_db` without moving its peak.

    Returns `(out_samples, info)` where info carries before/after measurements and the drive
    that was chosen, so a caller can PRINT the numbers rather than assert a typed constant.
    """
    before_peak, before_loud = measure(samples, sr)
    info = {
        "before_peak": before_peak,
        "before_loud": before_loud,
        "after_peak": before_peak,
        "after_loud": before_loud,
        "drive": 0.0,
        "reached": before_loud >= target_db,
    }
    if before_loud >= target_db:
        return list(samples), info

    # Compress once — it does not depend on the drive, and it is the expensive half.
    work = compress(samples, sr)
    p = max(1e-9, max(abs(s) for s in work))
    work = [s / p for s in work]

    original_peak = max(1e-9, max(abs(s) for s in samples))

    def at(drive: float):
        sat = saturate(work, drive)
        q = max(1e-9, max(abs(s) for s in sat))
        out = [s * (original_peak / q) for s in sat]
        return out, measure(out, sr)[1]

    # Monotone in drive, so bisect for the SMALLEST drive that clears the target.
    lo, hi = 1.0, max_drive
    out_hi, loud_hi = at(hi)
    if loud_hi < target_db:
        # Cannot reach it without buzzing. Take the ceiling and say so.
        info.update(after_peak=measure(out_hi, sr)[0], after_loud=loud_hi,
                    drive=hi, reached=False)
        return out_hi, info
    best_out, best_loud, best_drive = out_hi, loud_hi, hi
    for _ in range(9):
        mid = 0.5 * (lo + hi)
        cand, loud = at(mid)
        if loud >= target_db:
            best_out, best_loud, best_drive = cand, loud, mid
            hi = mid
        else:
            lo = mid
    info.update(after_peak=measure(best_out, sr)[0], after_loud=best_loud,
                drive=best_drive, reached=True)
    return best_out, info


def format_row(name: str, info: dict) -> str:
    mark = "" if info["reached"] else "   <-- COULD NOT REACH TARGET"
    if info["drive"] == 0.0:
        return "  %-28s already loud: %6.2f dBFS (skipped)" % (name, info["before_loud"])
    return ("  %-28s %6.2f -> %6.2f dBFS  (%+5.2f)  drive %5.2f   peak %6.2f -> %6.2f%s"
            % (name, info["before_loud"], info["after_loud"],
               info["after_loud"] - info["before_loud"], info["drive"],
               info["before_peak"], info["after_peak"], mark))
