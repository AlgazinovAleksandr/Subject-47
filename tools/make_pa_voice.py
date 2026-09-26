#!/usr/bin/env python3
"""Synthesise the Lab's public-address announcement.

This is the spoken half of the LEVEL 4 HINT (the whiteboard in the observation room
is the other half — see tools/make_lab_whiteboard.py and CLAUDE.md). It fires once,
in level_1.gd:_restore_power(), because the PA can only wake up when the power does.

The line never says "wall" and never names the Backrooms. It describes the exit as
"the surface that will not hold still" and is cut off mid-sentence by the relay
dropping, so the player is left with a rule they have to recognise later rather than
an instruction they can follow now.

Voiced with macOS `say`, then degraded through ffmpeg into a 1970s tannoy: band-limited
to a telephone-ish 300-3000 Hz, lightly overdriven, laid over a mains hum, and topped
and tailed with relay clicks.

Run:  python3 tools/make_pa_voice.py            -> pa_trial4 only (the original behaviour)
      python3 tools/make_pa_voice.py intro      -> the five Intake Wing lines (2026-09-24)
      python3 tools/make_pa_voice.py all        -> both
(no venv needed — stdlib + say + ffmpeg)

⭐ A TABLE OF LINES SINCE 2026-09-24 (the Intake Wing). The observer who speaks in the intro is the
same person as the Lab's PA — same voice, same rate, same tannoy chain — so the five intro lines are
rows in `LINES` rather than a second tool. `pa_trial4`'s row is the old constants verbatim and its
ffmpeg commands are the old strings verbatim; with the noise source seeded identically in both, the
refactored tool writes a byte-identical file (checked by md5 when this landed).

⚠️ TWO TRAPS, both measured:
  * the output is NOT deterministic run to run: `anoisesrc` (the relay clicks) is unseeded, so two
    runs of the ORIGINAL tool already differed by md5. Byte-identity is only meaningful with the
    seed pinned on both sides.
  * the shipped Lab asset is `pa_trial4.OGG`, and this tool writes `pa_trial4.WAV` beside it.
    `GameState.load_audio()` tries wav BEFORE ogg, so running the trial4 row into the game folder
    silently REPLACES the Lab's PA with this regeneration. That is why the default is unchanged
    and the intro lines are opt-in by argument, never the other way round.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/audio/level_1_lab/pa_trial4.wav"
INTRO_DIR = ROOT / "game/assets/audio/intro"

VOICE = "Daniel"     # en_GB, dry and institutional — reads as a records clerk
RATE = 172           # words per minute; unhurried, bored, reading from a file

LINE = (
    "Addendum to trial four. "
    "Subjects continue to search for a door. "
    "Record shows there is no door. "
    "The way out is the surface that will not hold still. "
    "Through. Not around. "
    "Subject forty seven is not to be"
)

# group -> [(output path, text)]. `[[slnc N]]` is `say`'s own embedded silence, in ms — it is how
# the 46 -> 47 slip gets its catch: the observer reads the wrong number, stops, and corrects it.
# ⚠️ FIVE intro lines and no more — the voice is rationed (spec/levels/00-intro.md); every other
# observer line in the wing is a `ScreenText.caption` or paper. Each of these is ALSO captioned
# in game by the level, so the wording here must match `intro_room.gd`'s VO table.
LINES = {
    "trial4": [(OUT, LINE)],
    "intro": [
        # VO1 — the cell, as the wake-up settles.
        (INTRO_DIR / "pa_intro_morning.wav",
         # ⚠️ A CORRECTION, not a stutter (fourth hand playtest, 2026-09-25: "It should be like good
         # morning 46, I mean, 47").
         "Good morning, forty six. [[slnc 300]] I mean, [[slnc 200]] forty seven."),
        # VO2 — the ward door: the relay drops mid-sentence (the chain's own dead cut).
        (INTRO_DIR / "pa_intro_fault.wav", "We have a fault in"),
        # VO3 — calibration opens.
        (INTRO_DIR / "pa_intro_screen.wav", "Look at the screen, forty seven."),
        # VO4 — calibration closes.
        (INTRO_DIR / "pa_intro_better.wav", "Much better than last time."),
        # VO5 — the airlock.
        (INTRO_DIR / "pa_intro_proceed.wav", "You may proceed."),
    ],
}


def need(binary):
    if shutil.which(binary) is None:
        sys.exit(f"error: {binary} not found on PATH")


def main():
    need("say")
    need("ffmpeg")
    want = sys.argv[1] if len(sys.argv) > 1 else "trial4"
    groups = list(LINES) if want == "all" else [want]
    for g in groups:
        if g not in LINES:
            sys.exit(f"error: unknown group {g!r} (have: {', '.join(LINES)}, all)")
        for out, text in LINES[g]:
            render(out, text)


def render(OUT, LINE):
    """One line through the tannoy chain. ⚠️ The parameter names shadow the module constants on
    purpose: the body below is the pre-table `main()` VERBATIM, so pa_trial4's commands are
    unchanged string for string."""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        raw = tmp / "raw.aiff"
        subprocess.run(
            ["say", "-v", VOICE, "-r", str(RATE), "-o", str(raw), LINE],
            check=True,
        )

        # Voice chain, in order:
        #   highpass/lowpass  -> tannoy band-limiting, kills the "clean TTS" tell
        #   acrusher slightly -> cheap driver distortion
        #   atempo 0.97       -> a hair slow; tape-ish, subtly wrong
        #   aecho             -> short slapback = a hard-walled corridor
        #   afade out         -> the relay cuts the last word dead
        voice = tmp / "voice.wav"
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(raw),
            "-af",
            "atempo=0.97,"
            "highpass=f=320,lowpass=f=2900,"
            "acrusher=level_in=1:level_out=1:bits=10:mode=log:aa=0.4,"
            "aecho=0.7:0.6:55:0.28,"
            "volume=1.6,"
            # Softener on the attack only. NOTE: this must be t=in — an afade
            # t=out at st=0 silences the entire remainder of the stream.
            "afade=t=in:st=0:d=0.06",
            "-ar", "44100", "-ac", "1", str(voice),
        ], check=True)

        # Duration, so the hum bed and the trailing click line up with the speech.
        dur = float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", str(voice)],
            check=True, capture_output=True, text=True).stdout.strip())

        total = dur + 1.1   # 0.35 s of carrier before, ~0.75 s of dead air after

        # 50 Hz mains hum + its third harmonic = the sound of a live open channel.
        hum = tmp / "hum.wav"
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "lavfi", "-i", f"sine=frequency=50:duration={total:.3f}",
            "-f", "lavfi", "-i", f"sine=frequency=150:duration={total:.3f}",
            "-filter_complex",
            "[0:a]volume=0.055[a];[1:a]volume=0.022[b];[a][b]amix=inputs=2:normalize=0,"
            "highpass=f=40",
            "-ar", "44100", "-ac", "1", str(hum),
        ], check=True)

        # Relay clicks: a broadband tick at the head (channel opens) and one at the
        # very end (the cut). Built as filtered noise bursts.
        click = tmp / "click.wav"
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "lavfi", "-i", "anoisesrc=duration=0.05:color=white:amplitude=0.6",
            "-af", "highpass=f=900,lowpass=f=6000,afade=t=out:st=0:d=0.05",
            "-ar", "44100", "-ac", "1", str(click),
        ], check=True)

        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", str(hum), "-i", str(voice), "-i", str(click),
            "-filter_complex",
            # voice starts after the opening click; closing click lands on the cut
            f"[1:a]adelay=350|350[v];"
            f"[2:a]adelay=60|60[c1];"
            f"[2:a]adelay={int((dur + 0.42) * 1000)}|{int((dur + 0.42) * 1000)}[c2];"
            f"[0:a][v][c1][c2]amix=inputs=4:normalize=0:duration=longest,"
            f"alimiter=limit=0.92,"
            f"afade=t=in:st=0:d=0.04,afade=t=out:st={total - 0.25:.3f}:d=0.25",
            "-ar", "44100", "-ac", "1", "-sample_fmt", "s16", str(OUT),
        ], check=True)

    print(f"wrote {OUT} ({OUT.stat().st_size} bytes, ~{total:.2f}s)")


if __name__ == "__main__":
    main()
