#!/usr/bin/env python3
"""Raise the average level of the game's SOURCED scare stings, in place.

    python3 tools/remaster_scares.py            # measure and rewrite
    python3 tools/remaster_scares.py --dry-run  # measure only, touch nothing
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

WHY, measured 2026-09-03. `screamer.gd` plays every sting at a hard-coded `0.0 dB` on Master
and takes no gain argument, so the FILE is the volume control. The eight fatal per-level
screamers measured, loudest-300 ms:

    dark_jumpscare       -0.18      screamer_house       -4.29
    all_levels_screamer  -0.23      kontur_scream        -6.26
    screamer_dungeon     -2.31      screamer_lab        -12.62   <-- the Lab's death sting
    screamer_corridor    -3.66      level_6_jumpscare    -4.22

The Lab's is **12 dB quieter than the loudest thing the same code path can play**, and every
one of them is already peak-normalised, so a gain cannot fix it. See `sfx_loudness.py` for why
the answer is saturation and not compression.

⚠️ THIS TOOL DELIBERATELY HANDLES ONLY THE **SOURCED** FILES.
The generated ones — `screamer_kontur`, `matron_shriek`, `child_laugh`, `glass_shatter`,
`creature_growl_near`, `screamer_breach` — are written by `make_sfx_kontur.py`,
`make_sfx_dungeon.py`, `make_sfx.py` and `make_sfx_level6.py`. Post-processing those in place
would be silently reverted the next time anyone re-ran a generator to add one sound. Their
generators pass `loud=` to their own `write_wav()` instead. **If you add a scare here, first
check `grep -rl '"<name>' tools/*.py` — if a generator owns it, fix the generator.**

⚠️ ORIGINALS ARE BACKED UP to `assets_src/audio/pre_remaster/` (gitignored) before the first
overwrite, and the tool refuses to re-process a file it has already processed unless the
backup is present — otherwise a second run saturates an already-saturated file and the
character keeps degrading with no way back.

⚠️ `.ogg` needs ffmpeg to decode and re-encode; `.wav` does not. ffmpeg is already a hard
dependency of `prepare_screamers.py` and `make_loop.py`, so this adds nothing new. Files whose
format cannot be handled are reported and skipped, never silently passed over.
"""

from __future__ import annotations

import math
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sfx_loudness import (LOUD_TARGET_DB, MIN_WORTH_DB, format_row, loudify,  # noqa: E402
                          measure)

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "game" / "assets" / "audio"
BACKUP = ROOT / "assets_src" / "audio" / "pre_remaster"

# (path relative to game/assets/audio, target loudest-300 ms dBFS, why it matters)
#
# ⚠️ Targets are NOT all the same. A fatal screamer fills the screen and ends the run, so it
# is aimed at the reference (-3.0, just under `shared/jumpscare.wav`'s -2.14). A positional
# one-shot that plays in the world at a negative volume_db is aimed lower, because raising its
# average level ALSO raises what the player hears from across a room, and two of these are
# already played at large positive gains at their call sites.
TARGETS = [
    # --- fatal per-level screamers (Screamer.LEVEL_SCREAMERS) -------------------------
    ("level_1_lab/screamer_lab.wav",            -3.0, "Level 1 fatal — the worst offender"),
    ("level_5_kontur/kontur_scream.ogg",        -3.0, "Level 5 fatal"),
    ("level_2_house/screamer_house.ogg",        -3.0, "Level 2 fatal"),
    ("level_3_corridor/screamer_corridor.ogg",  -3.0, "Level 3 fatal"),
    ("level_4_void/screamer_void.wav",          -3.0, "Level 8 fatal"),
    ("level_9_dungeon/screamer_dungeon.ogg",    -3.0, "Level 7 fatal"),
    ("level_6_breach/level_6_jumpscare.wav",    -3.0, "Level 6 fatal"),
    # --- survivable flash_scare payloads ---------------------------------------------
    ("level_2_house/screamer_forest.ogg",       -3.0, "House window flash"),
    ("intro/nightmare_scream.ogg",              -3.0, "main-menu cold open"),
    # --- positional world one-shots, aimed lower -------------------------------------
    # ⚠️ childe_scream is already played at +18 dB with max_db raised to 24 (level_2.gd
    # CHILD_VOLUME_DB); fridge_scream is a one-shot at the player's face. Both are aimed at
    # -5 rather than -3 so this pass does not compound a gain that was set by ear.
    ("level_2_house/childe_scream.wav",         -5.0, "cellar child, already +18 dB at the call site"),
    ("level_2_house/fridge_scream.ogg",         -5.0, "fridge reveal"),
]

# Files this tool must NEVER touch, with the reason. Checked at startup so the list cannot
# rot silently into "we forgot why".
FORBIDDEN = {
    "shared/chase.wav":
        "output of tools/make_loop.py, whose whole job is a seam matched to 0.7 dB; "
        "re-saturating it would move the seam. Also the one file referenced by a hardcoded "
        "path (maze_chase_ui.gd CHASE_PATH) rather than by base name.",
    "shared/half_scream.wav":
        "RandomAmbient's 12-panic event, deliberately distant and quiet; loudness here is "
        "a difficulty change, not a mix fix.",
    "shared/distant_scream.wav":
        "the word 'distant' is the design.",
}


def die(msg: str) -> None:
    print("remaster_scares: " + msg, file=sys.stderr)
    sys.exit(1)


def have_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def read_audio(path: Path):
    """-> (channels, sr, [ [ch0 samples], [ch1 samples], ... ]) as floats in [-1, 1].

    ⚠️ `wave` only reads PCM. `level_4_void/screamer_void.wav` is **WAVE_FORMAT_IEEE_FLOAT**
    (format tag 3) and raises `wave.Error: unknown format: 3` — so a `.wav` suffix is not a
    promise that the stdlib can open it. Anything `wave` refuses falls through to ffmpeg, and
    is written back as 16-bit PCM, which is what every other asset in the project already is.
    """
    if path.suffix == ".wav":
        try:
            with wave.open(str(path), "rb") as w:
                if w.getsampwidth() == 2:
                    ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
                    raw = struct.unpack("<%dh" % (n * ch), w.readframes(n))
                    return ch, sr, [[raw[i] / 32768.0 for i in range(c, len(raw), ch)]
                                    for c in range(ch)]
        except wave.Error:
            pass  # not PCM16 — ffmpeg below
    if not have_ffmpeg():
        return None
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "d.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(path),
                        "-c:a", "pcm_s16le", str(tmp)], check=True)
        return read_audio(tmp)


def write_audio(path: Path, sr: int, channels) -> None:
    """Write back in the SAME container the file arrived in."""
    n = len(channels[0])
    ch = len(channels)
    frames = bytearray()
    for i in range(n):
        for c in range(ch):
            v = int(max(-1.0, min(1.0, channels[c][i])) * 32767.0)
            frames += struct.pack("<h", v)
    if path.suffix == ".wav":
        with wave.open(str(path), "wb") as w:
            w.setnchannels(ch)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(bytes(frames))
        return
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "e.wav"
        with wave.open(str(tmp), "wb") as w:
            w.setnchannels(ch)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(bytes(frames))
        # ⚠️ q:a 8, NOT 6. The first pass used 6 and took `kontur_scream.ogg` from **336 kbps to
        # 172 kbps** — the tool was silently re-encoding a file it had already decoded once, so
        # every pass would compound. These are 1-5 s stings; the size difference is tens of KB
        # against a repo that carries 9.8 MB of creature, and the point of the pass was to make
        # them BETTER.
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(tmp),
                        "-c:a", "libvorbis", "-q:a", "8", str(path)], check=True)


def mono_of(channels):
    if len(channels) == 1:
        return channels[0]
    n = len(channels[0])
    return [sum(c[i] for c in channels) / len(channels) for i in range(n)]


def main() -> int:
    dry = "--dry-run" in sys.argv
    for rel, why in FORBIDDEN.items():
        if any(t[0] == rel for t in TARGETS):
            die("%s is in TARGETS but is forbidden: %s" % (rel, why))

    BACKUP.mkdir(parents=True, exist_ok=True)
    print("remaster_scares — target %.1f dBFS loudest-300 ms unless stated%s\n"
          % (LOUD_TARGET_DB, "   (DRY RUN)" if dry else ""))

    touched = skipped = failed = 0
    for rel, target, why in TARGETS:
        src = AUDIO / rel
        name = Path(rel).name
        if not src.exists():
            print("  %-28s MISSING (%s)" % (name, rel))
            failed += 1
            continue
        got = read_audio(src)
        if got is None:
            print("  %-28s UNREADABLE (needs ffmpeg?)" % name)
            failed += 1
            continue
        ch, sr, channels = got
        mono = mono_of(channels)
        before_peak, before_loud = measure(mono, sr)

        if before_loud >= target - 0.25:
            print("  %-28s already %6.2f dBFS (target %.1f) — skipped" % (name, before_loud, target))
            skipped += 1
            continue

        # Stereo-linked: derive the transform from the mono sum, then apply the SAME
        # per-sample gain to every channel, or the stereo image collapses toward the centre
        # wherever one side is louder than the other.
        #
        # ⚠️⚠️ AND THEN RE-CEILING ACROSS ALL CHANNELS. `sfx_loudness.loudify()` promises "the peak
        # is preserved, always" — and it does, FOR THE BUFFER IT IS GIVEN, which here is the mono
        # SUM. A per-sample gain derived from the sum and applied to a channel that is louder than
        # the sum at that instant pushes that channel past its own original peak. Measured
        # 2026-09-03 on the first pass: `fridge_scream.ogg` came back with **17.97 % of its
        # samples hard-clipped** against 2.92 % before. Found by an audit probe, not by
        # `check_scare_loudness.gd`, which decodes `.wav` only and has both `.ogg` files on its
        # unmeasurable list.
        loud_mono, info = loudify(mono, sr, target_db=target)

        gain = info["after_loud"] - info["before_loud"]
        if gain < MIN_WORTH_DB:
            print("  %-28s %6.2f dBFS, only %+.2f available at drive %.2f — NOT WORTH IT"
                  % (name, before_loud, gain, info["drive"]))
            skipped += 1
            continue

        out = []
        for c in channels:
            oc = []
            for i, s in enumerate(c):
                g = (loud_mono[i] / mono[i]) if abs(mono[i]) > 1e-9 else 1.0
                oc.append(s * g)
            out.append(oc)
        # The true ceiling is the loudest sample in ANY channel, before and after.
        peak_before = max(max(abs(s) for s in c) for c in channels)
        peak_after = max(max(abs(s) for s in oc) for oc in out)
        over_db = 0.0
        if peak_after > peak_before and peak_after > 1e-9:
            over_db = 20.0 * math.log10(peak_after / peak_before)
            k = peak_before / peak_after
            out = [[s * k for s in oc] for oc in out]
        # Belt and braces: nothing may leave here above full scale.
        out = [[max(-1.0, min(1.0, s)) for s in oc] for oc in out]

        # ⚠️⚠️ MEASURE WHAT CAME OUT, NOT WHAT `loudify()` PROMISED. `info` describes the MONO
        # SUM before the re-ceiling, and on a strongly asymmetric stereo file the re-ceiling is
        # not small: `fridge_scream.ogg` needed -7.38 dB to bring its loudest channel back to its
        # own original peak, which more than undid the +2.94 dB the row was about to claim. A
        # tool that reports a gain it did not deliver is worse than one that skips the file.
        _, delivered = measure(mono_of(out), sr)
        info["after_loud"] = delivered
        net = delivered - before_loud
        if net < MIN_WORTH_DB:
            print("  %-28s %6.2f dBFS, net %+.2f after re-ceiling %.2f dB of channel overshoot "
                  "— NOT WORTH IT" % (name, before_loud, net, over_db))
            skipped += 1
            continue
        if over_db > 0.05:
            print("      re-ceiled -%.2f dB: the mono-derived gain had pushed the loudest "
                  "CHANNEL that far past its own original peak" % over_db)

        print(format_row(name, info) + "   [%s]" % why)
        if not dry:
            bak = BACKUP / rel.replace("/", "__")
            if not bak.exists():
                shutil.copy2(src, bak)
            write_audio(src, sr, out)
        touched += 1

    print("\n  %d rewritten, %d already loud, %d failed" % (touched, skipped, failed))
    if not dry and touched:
        print("  originals -> %s" % BACKUP)
        print("  NOW RUN:  Godot --headless --path game --import")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
