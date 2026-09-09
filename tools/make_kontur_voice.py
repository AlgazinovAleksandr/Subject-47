#!/usr/bin/env python3
"""Synthesise KONTUR's spoken atmosphere: one phone-line warning + four PA tannoy
announcements + a two-tone attention chime.

Modelled EXACTLY on tools/make_pa_voice.py — same macOS `say` -> ffmpeg tannoy
degrade (band-limit ~300-3000 Hz, cheap driver overdrive, a 50 Hz mains-hum bed,
relay clicks head and tail). Read that file first; the PA chain here is a copy of it.

Two registers:
  * The PA lines (pa_kontur_1..4) are the SAME degrade as pa_trial4, voiced by the
    same bored clerk ("Daniel"), so they read as the building talking to itself.
  * The phone line (phone_green_voice) is a DIFFERENT en_GB voice ("Shelley") band-
    limited much harder and stripped of the mains carrier, so it reads as a person
    down a line rather than the tannoy. It never names a colour, a code, or a puzzle
    room — it is dread, not an instruction.

Everything is deterministic (fixed `say` voices/rates, seeded noise for the clicks
and the phone-line hiss) and re-runnable. It writes six WAVs into
game/assets/audio/level_5_kontur/ and PRINTS each file's measured peak & RMS dBFS,
because the game sets playback gains from those numbers.

This tool does NOT touch pa_trial4 and does NOT modify make_pa_voice.py.

Run:  python3 tools/make_kontur_voice.py     (no venv needed — stdlib + say + ffmpeg)
"""

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "game/assets/audio/level_5_kontur"

# --- voices -----------------------------------------------------------------
PA_VOICE = "Daniel"      # en_GB, dry & institutional — the same clerk as pa_trial4
PA_RATE = 172            # words per minute; unhurried, bored, reading from a file
PHONE_VOICE = "Shelley"  # en_GB, DIFFERENT from the PA so it reads as a person
PHONE_RATE = 166         # a touch slower — someone choosing their words on a line

SEED = 4712              # seeds every anoisesrc so the ticks/hiss are reproducible

# --- lines (verbatim — atmosphere only: no colour, no code, no gate answer) --
PA_LINES = {
    "pa_kontur_1": "Attention. Air handling in the lower archive is offline. This is not a fault.",
    "pa_kontur_2": "All personnel. The oh six hundred count did not reconcile. A recount is not scheduled.",
    "pa_kontur_3": "Maintenance to the switchboard. The lines are ringing again. We did not connect them.",
    "pa_kontur_4": "The subject is not staff. The subject is not a visitor. File accordingly.",
}

PHONE_LINE = (
    "If it ever gets loose, it follows sound. "
    "There is a chamber at the end that locks from the outside. "
    "Lead it in, and seal it from where you stand. "
    "Do not still be inside when the door drops."
)

# The BLUE phone: a dead line that answers anyway. Same voice as the green line,
# slower and sicker. No colour, code, or puzzle room — pure despair.
BLUE_RATE = 150          # slower than the green line — resigned, giving up

BLUE_LINE = (
    "There is no exit. There was never an exit. "
    "You are not getting off this floor. None of them did. "
    "Put it down. It does not matter. Put it down."
)


def need(binary):
    if shutil.which(binary) is None:
        sys.exit(f"error: {binary} not found on PATH")


def run(cmd):
    """Run a command, surfacing ffmpeg/say stderr verbatim if it fails."""
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit(f"error: command failed ({p.returncode}):\n  {' '.join(map(str, cmd))}\n{p.stderr}")
    return p


def probe_dur(path):
    return float(run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(path)]).stdout.strip())


def measure(path):
    """Return (peak_dBFS, rms_dBFS) via ffmpeg volumedetect."""
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
               "-af", "volumedetect", "-f", "null", "-"]).stderr

    def grab(key):
        m = re.search(key + r":\s*(-?\d+(?:\.\d+)?) dB", err)
        return float(m.group(1)) if m else float("nan")

    return grab("max_volume"), grab("mean_volume")


def say_to(voice, rate, line, dest):
    run(["say", "-v", voice, "-r", str(rate), "-o", str(dest), line])


# --- PA tannoy: an exact copy of pa_trial4's chain, minus the mid-sentence cut -
def build_pa(name, line, tmp):
    raw = tmp / f"{name}_raw.aiff"
    say_to(PA_VOICE, PA_RATE, line, raw)

    # Voice chain (order matters), identical to make_pa_voice.py:
    #   atempo 0.97       -> a hair slow; tape-ish, subtly wrong
    #   highpass/lowpass  -> tannoy band-limiting, kills the "clean TTS" tell
    #   acrusher slightly -> cheap driver distortion
    #   aecho             -> short slapback = a hard-walled corridor
    #   afade in (attack) -> softens the opening consonant only
    voice = tmp / f"{name}_voice.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw),
         "-af",
         "atempo=0.97,"
         "highpass=f=320,lowpass=f=2900,"
         "acrusher=level_in=1:level_out=1:bits=10:mode=log:aa=0.4,"
         "aecho=0.7:0.6:55:0.28,"
         "volume=1.6,"
         "afade=t=in:st=0:d=0.06",
         "-ar", "44100", "-ac", "1", str(voice)])

    dur = probe_dur(voice)
    total = dur + 1.1   # 0.35 s of carrier before, ~0.75 s of dead air after

    # 50 Hz mains hum + its third harmonic = the sound of a live open channel.
    hum = tmp / f"{name}_hum.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", f"sine=frequency=50:duration={total:.3f}",
         "-f", "lavfi", "-i", f"sine=frequency=150:duration={total:.3f}",
         "-filter_complex",
         "[0:a]volume=0.055[a];[1:a]volume=0.022[b];[a][b]amix=inputs=2:normalize=0,"
         "highpass=f=40",
         "-ar", "44100", "-ac", "1", str(hum)])

    # Relay clicks: a broadband tick at the head (channel opens) and one at the
    # tail (the cut). Seeded so the tick is byte-reproducible.
    click = tmp / f"{name}_click.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i",
         f"anoisesrc=duration=0.05:color=white:amplitude=0.6:seed={SEED}",
         "-af", "highpass=f=900,lowpass=f=6000,afade=t=out:st=0:d=0.05",
         "-ar", "44100", "-ac", "1", str(click)])

    out = OUT_DIR / f"{name}.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-i", str(hum), "-i", str(voice), "-i", str(click),
         "-filter_complex",
         f"[1:a]adelay=350|350[v];"
         f"[2:a]adelay=60|60[c1];"
         f"[2:a]adelay={int((dur + 0.42) * 1000)}|{int((dur + 0.42) * 1000)}[c2];"
         f"[0:a][v][c1][c2]amix=inputs=4:normalize=0:duration=longest,"
         f"alimiter=limit=0.92,"
         f"afade=t=in:st=0:d=0.04,afade=t=out:st={total - 0.25:.3f}:d=0.25",
         "-ar", "44100", "-ac", "1", "-sample_fmt", "s16", str(out)])
    return out


# --- phone line: same idea, HARDER band-limit, a person not the tannoy --------
def build_phone(tmp):
    name = "phone_green_voice"
    raw = tmp / f"{name}_raw.aiff"
    say_to(PHONE_VOICE, PHONE_RATE, PHONE_LINE, raw)

    # Telephone chain:
    #   highpass/lowpass x2 -> a STEEP ~450-3000 Hz passband (harder than the PA's)
    #   acrusher            -> mild codec grit
    #   aecho (tiny)        -> handset-cavity colour, not a corridor
    #   volume -> alimiter   -> the "light overdrive": soft-clipped into the limiter
    #   no atempo, no mains hum: those are the tannoy's tells, and this is a caller
    voice = tmp / f"{name}_voice.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw),
         "-af",
         "highpass=f=450,highpass=f=450,lowpass=f=3000,lowpass=f=3000,"
         "acrusher=level_in=1:level_out=1:bits=9:mode=log:aa=0.35,"
         "aecho=0.6:0.5:14:0.16,"
         "volume=2.0,"
         "afade=t=in:st=0:d=0.05",
         "-ar", "44100", "-ac", "1", str(voice)])

    dur = probe_dur(voice)
    total = dur + 0.7

    # A faint band-limited line hiss — an open line, not a mains carrier.
    line = tmp / f"{name}_line.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i",
         f"anoisesrc=duration={total:.3f}:color=pink:amplitude=0.03:seed={SEED + 1}",
         "-af", "highpass=f=300,lowpass=f=3000,volume=0.6",
         "-ar", "44100", "-ac", "1", str(line)])

    # One pickup click at the head (the receiver connecting). No tail click.
    click = tmp / f"{name}_click.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i",
         f"anoisesrc=duration=0.045:color=white:amplitude=0.5:seed={SEED + 2}",
         "-af", "highpass=f=900,lowpass=f=5000,afade=t=out:st=0:d=0.045",
         "-ar", "44100", "-ac", "1", str(click)])

    out = OUT_DIR / f"{name}.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-i", str(line), "-i", str(voice), "-i", str(click),
         "-filter_complex",
         f"[1:a]adelay=180|180[v];"
         f"[2:a]adelay=40|40[c1];"
         f"[0:a][v][c1]amix=inputs=3:normalize=0:duration=longest,"
         f"alimiter=limit=0.9,"
         f"afade=t=in:st=0:d=0.03,afade=t=out:st={total - 0.22:.3f}:d=0.22",
         "-ar", "44100", "-ac", "1", "-sample_fmt", "s16", str(out)])
    return out


# --- the BLUE phone: the SAME Shelley telephone chain as the green line, but a
#     dead line that answers anyway — slower, grittier, and doubled over itself
#     with a multi-tap echo so it reads as "wrong". --------------------------------
def build_blue_phone(tmp):
    name = "phone_blue_voice"
    raw = tmp / f"{name}_raw.aiff"
    say_to(PHONE_VOICE, BLUE_RATE, BLUE_LINE, raw)

    # Same steep ~450-3000 Hz telephone band as phone_green_voice, made sick:
    #   atempo 0.95        -> a hair slow; the line is not right
    #   acrusher bits=8    -> more codec grit than the green line's bits=9
    #   aecho (multi-tap)  -> two overlapping repeats double the voice = "wrong"
    #   volume -> alimiter  -> the same light overdrive, soft-clipped
    voice = tmp / f"{name}_voice.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw),
         "-af",
         "atempo=0.95,"
         "highpass=f=450,highpass=f=450,lowpass=f=3000,lowpass=f=3000,"
         "acrusher=level_in=1:level_out=1:bits=8:mode=log:aa=0.3,"
         "aecho=0.8:0.6:75|130:0.5|0.35,"
         "volume=2.0,"
         "afade=t=in:st=0:d=0.05",
         "-ar", "44100", "-ac", "1", str(voice)])

    dur = probe_dur(voice)
    total = dur + 0.8

    # A hollow dead-line bed: faint pink hiss + a low sub drone (no dial tone —
    # the line is dead, it only answers).
    bed = tmp / f"{name}_bed.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i",
         f"anoisesrc=duration={total:.3f}:color=pink:amplitude=0.035:seed={SEED + 4}",
         "-f", "lavfi", "-i", f"sine=frequency=66:duration={total:.3f}",
         "-filter_complex",
         "[0:a]highpass=f=280,lowpass=f=3000,volume=0.6[h];"
         "[1:a]volume=0.03[d];"
         "[h][d]amix=inputs=2:normalize=0",
         "-ar", "44100", "-ac", "1", str(bed)])

    # One pickup click at the head — the dead line connecting.
    click = tmp / f"{name}_click.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i",
         f"anoisesrc=duration=0.045:color=white:amplitude=0.5:seed={SEED + 5}",
         "-af", "highpass=f=900,lowpass=f=5000,afade=t=out:st=0:d=0.045",
         "-ar", "44100", "-ac", "1", str(click)])

    out = OUT_DIR / f"{name}.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-i", str(bed), "-i", str(voice), "-i", str(click),
         "-filter_complex",
         f"[1:a]adelay=200|200[v];"
         f"[2:a]adelay=40|40[c1];"
         f"[0:a][v][c1]amix=inputs=3:normalize=0:duration=longest,"
         f"alimiter=limit=0.9,"
         f"afade=t=in:st=0:d=0.03,afade=t=out:st={total - 0.22:.3f}:d=0.22",
         "-ar", "44100", "-ac", "1", "-sample_fmt", "s16", str(out)])
    return out


# --- two-tone attention chime: no `say`, sine pair, same degrade family -------
def build_chime(tmp):
    name = "pa_kontur_chime"

    # Two descending tones (bing-bong), each ~0.28 s with a bell-ish decay.
    tones = tmp / f"{name}_tones.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", "sine=frequency=660:duration=0.30",
         "-f", "lavfi", "-i", "sine=frequency=523:duration=0.30",
         "-filter_complex",
         "[0:a]afade=t=in:st=0:d=0.01,afade=t=out:st=0.20:d=0.10,volume=0.7[t1];"
         "[1:a]afade=t=in:st=0:d=0.01,afade=t=out:st=0.20:d=0.10,volume=0.7[t2];"
         "[t1][t2]concat=n=2:v=0:a=1",
         "-ar", "44100", "-ac", "1", str(tones)])

    # Band-limit + light overdrive, exactly the tannoy voice treatment.
    band = tmp / f"{name}_band.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tones),
         "-af",
         "highpass=f=320,lowpass=f=2900,"
         "acrusher=level_in=1:level_out=1:bits=10:mode=log:aa=0.4,"
         "volume=1.3",
         "-ar", "44100", "-ac", "1", str(band)])

    dur = probe_dur(band)
    total = dur + 0.45

    hum = tmp / f"{name}_hum.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", f"sine=frequency=50:duration={total:.3f}",
         "-f", "lavfi", "-i", f"sine=frequency=150:duration={total:.3f}",
         "-filter_complex",
         "[0:a]volume=0.05[a];[1:a]volume=0.02[b];[a][b]amix=inputs=2:normalize=0,"
         "highpass=f=40",
         "-ar", "44100", "-ac", "1", str(hum)])

    # Relay click at the head, like the rest.
    click = tmp / f"{name}_click.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i",
         f"anoisesrc=duration=0.05:color=white:amplitude=0.6:seed={SEED + 3}",
         "-af", "highpass=f=900,lowpass=f=6000,afade=t=out:st=0:d=0.05",
         "-ar", "44100", "-ac", "1", str(click)])

    out = OUT_DIR / f"{name}.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-i", str(hum), "-i", str(band), "-i", str(click),
         "-filter_complex",
         f"[1:a]adelay=140|140[t];"
         f"[2:a]adelay=60|60[c1];"
         f"[0:a][t][c1]amix=inputs=3:normalize=0:duration=longest,"
         f"alimiter=limit=0.92,"
         f"afade=t=in:st=0:d=0.03,afade=t=out:st={total - 0.15:.3f}:d=0.15",
         "-ar", "44100", "-ac", "1", "-sample_fmt", "s16", str(out)])
    return out


def main():
    need("say")
    need("ffmpeg")
    need("ffprobe")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Every output, in report order, keyed by base name. Naming targets on the
    # command line builds only those (deterministic, so the rest stay byte- and
    # timestamp-identical); with no args it builds all seven.
    builders = {
        "phone_green_voice": build_phone,
        "phone_blue_voice": build_blue_phone,
    }
    for pa_name, pa_line in PA_LINES.items():
        builders[pa_name] = (lambda tmp, n=pa_name, ln=pa_line: build_pa(n, ln, tmp))
    builders["pa_kontur_chime"] = build_chime

    wanted = sys.argv[1:] or list(builders)
    unknown = [w for w in wanted if w not in builders]
    if unknown:
        sys.exit(f"error: unknown target(s): {', '.join(unknown)}\n"
                 f"known: {', '.join(builders)}")

    results = []
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        for name in wanted:
            results.append(builders[name](tmp))

    print("\n--- KONTUR voice: measured levels (game gains are set from these) ---")
    for path in results:
        peak, rms = measure(path)
        print(f"{path.name:<24} peak={peak:.1f} dBFS  rms={rms:.1f} dBFS  "
              f"({path.stat().st_size} bytes, {probe_dur(path):.2f}s)")


if __name__ == "__main__":
    main()
