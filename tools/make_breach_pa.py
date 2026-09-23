#!/usr/bin/env python3
"""Synthesise the Breach approach's three PA lines (2026-09-23, GAME_MECHANICS_IDEAS N4).

Modelled on tools/make_kontur_voice.py, and deliberately the SAME voice and tannoy chain: the
same bored clerk ("Daniel", 172 wpm), the same band-limit / driver overdrive / slapback / 50 Hz
mains carrier / relay clicks. The point is that the Breach is the same facility still talking,
so the player who heard KONTUR's announcements recognises the building's voice here. What
changes is the register, degrading line by line from clinical to broken:

  approach_pa_1   clean — the status report the facility still believes
  approach_pa_2   glitching — digital dropouts between phrases and a stuttered count
  approach_pa_3   cut off MID-WORD by a burst of broken signal, then dead air

⚠️ The lines are STATEMENTS, never instructions or cues (N4's rule, and pa_trial4's convention):
no route, no puzzle answer, no proximity readout. Texts are verbatim from
spec/levels/06-breach.md.

This tool does NOT modify make_kontur_voice.py, make_pa_voice.py or any file they write.
Deterministic (fixed `say` voice and rate, seeded noise). Writes three WAVs into
game/assets/audio/level_6_breach/ and prints each file's measured peak and RMS, because the
game sets playback gain from those numbers.

Run:  python3 tools/make_breach_pa.py      (stdlib + macOS `say` + ffmpeg)
"""

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "game/assets/audio/level_6_breach"

PA_VOICE = "Daniel"   # en_GB — the same clerk as pa_trial4 and KONTUR's pa_kontur_*
PA_RATE = 172
SEED = 6123

LINE_1 = "Containment status, Wing C. Object Twelve: secured. Seal integrity ninety-eight percent."
# Line 2 is spoken in fragments so the glitches can sit BETWEEN phrases, where a failing
# channel drops out, rather than chopping words at random.
LINE_2 = ["Seal integrity.", "sixty-one percent.", "Personnel on site.", "two hundred twelve.", "twelve."]
# Line 3: the whole sentence is never spoken. "Object Twelve is not in its" plus the first
# syllable of the next word, then the signal breaks.
LINE_3_HEAD = "Object Twelve is not in its"
LINE_3_TAIL = "containment"
LINE_3_TAIL_KEEP = 0.17   # seconds of the next word before the cut: "con—"

VOICE_CHAIN = ("atempo=0.97,"
               "highpass=f=320,lowpass=f=2900,"
               "acrusher=level_in=1:level_out=1:bits=10:mode=log:aa=0.4,"
               "aecho=0.7:0.6:55:0.28,"
               "volume=1.6")


def need(binary):
    if shutil.which(binary) is None:
        sys.exit(f"error: {binary} not found on PATH")


def run(cmd):
    p = subprocess.run([str(c) for c in cmd], capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit(f"error: command failed ({p.returncode}):\n  {' '.join(map(str, cmd))}\n{p.stderr}")
    return p


def dur(path):
    return float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                      "-of", "default=nw=1:nk=1", path]).stdout.strip())


def measure(path):
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path,
               "-af", "volumedetect", "-f", "null", "-"]).stderr

    def grab(key):
        m = re.search(key + r":\s*(-?\d+(?:\.\d+)?) dB", err)
        return float(m.group(1)) if m else float("nan")

    return grab("max_volume"), grab("mean_volume")


def voice(text, dest, tmp, trim=None):
    raw = tmp / (dest.stem + "_raw.aiff")
    run(["say", "-v", PA_VOICE, "-r", PA_RATE, "-o", raw, text])
    chain = VOICE_CHAIN + ",afade=t=in:st=0:d=0.04"
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", raw]
    if trim is not None:
        cmd += ["-t", f"{trim:.3f}"]
    run(cmd + ["-af", chain, "-ar", "44100", "-ac", "1", dest])
    return dest


def silence(seconds, dest):
    run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i",
         f"anullsrc=r=44100:cl=mono", "-t", f"{seconds:.3f}", dest])
    return dest


def glitch(seconds, dest, seed, squeal=0.0):
    """A burst of broken signal: bit-crushed band-limited noise, optionally a feedback tone."""
    inputs = ["-f", "lavfi", "-i",
              f"anoisesrc=duration={seconds:.3f}:color=white:amplitude=0.5:seed={seed}"]
    graph = ("[0:a]highpass=f=500,lowpass=f=3200,"
             "acrusher=level_in=1:level_out=1.4:bits=3:mode=lin:aa=0,"
             "tremolo=f=38:d=0.9[n]")
    if squeal > 0.0:
        inputs += ["-f", "lavfi", "-i", f"sine=frequency=1830:duration={seconds:.3f}"]
        graph += (f";[1:a]volume={squeal},afade=t=out:st=0:d={seconds:.3f}[s];"
                  "[n][s]amix=inputs=2:normalize=0")
    else:
        graph = graph.replace("[n]", "")
    run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph,
         "-ar", "44100", "-ac", "1", dest])
    return dest


def stutter(src, dest, tmp, chunk=0.075, repeats=3):
    """Repeat the first `chunk` seconds of `src` — the channel catching on a syllable."""
    head = tmp / (dest.stem + "_head.wav")
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-t", f"{chunk:.3f}", head])
    return concat([head] * repeats + [src], dest)


def concat(parts, dest):
    ins = []
    for p in parts:
        ins += ["-i", p]
    graph = "".join(f"[{i}:a]" for i in range(len(parts))) + f"concat=n={len(parts)}:v=0:a=1"
    run(["ffmpeg", "-y", "-loglevel", "error", *ins, "-filter_complex", graph,
         "-ar", "44100", "-ac", "1", dest])
    return dest


def broadcast(voice_track, name, tmp, tail_click=True, dead_air=0.75):
    """Carrier hum + relay clicks around a voice track, exactly as KONTUR's build_pa()."""
    d = dur(voice_track)
    total = d + 0.35 + dead_air
    hum = tmp / f"{name}_hum.wav"
    run(["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", f"sine=frequency=50:duration={total:.3f}",
         "-f", "lavfi", "-i", f"sine=frequency=150:duration={total:.3f}",
         "-filter_complex",
         "[0:a]volume=0.055[a];[1:a]volume=0.022[b];[a][b]amix=inputs=2:normalize=0,highpass=f=40",
         "-ar", "44100", "-ac", "1", hum])
    click = tmp / f"{name}_click.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i",
         f"anoisesrc=duration=0.05:color=white:amplitude=0.6:seed={SEED}",
         "-af", "highpass=f=900,lowpass=f=6000,afade=t=out:st=0:d=0.05",
         "-ar", "44100", "-ac", "1", click])
    out = OUT_DIR / f"{name}.wav"
    tail_ms = int((d + 0.42) * 1000)
    graph = "[1:a]adelay=350|350[v];[2:a]adelay=60|60[c1];"
    mix = "[0:a][v][c1]"
    count = 3
    if tail_click:
        graph += f"[2:a]adelay={tail_ms}|{tail_ms}[c2];"
        mix += "[c2]"
        count = 4
    fade_out = 0.25 if dead_air > 0.2 else 0.02
    graph += (f"{mix}amix=inputs={count}:normalize=0:duration=longest,alimiter=limit=0.92,"
              f"afade=t=in:st=0:d=0.04,afade=t=out:st={total - fade_out:.3f}:d={fade_out}")
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", hum, "-i", voice_track, "-i", click,
         "-filter_complex", graph, "-ar", "44100", "-ac", "1", "-sample_fmt", "s16", out])
    return out


def build_1(tmp):
    return broadcast(voice(LINE_1, tmp / "l1.wav", tmp), "approach_pa_1", tmp)


def build_2(tmp):
    frags = [voice(t, tmp / f"l2_{i}.wav", tmp) for i, t in enumerate(LINE_2)]
    # "twelve… twelve…": the second catches on its first syllable, like a skipping channel.
    frags[4] = stutter(frags[4], tmp / "l2_4s.wav", tmp)
    parts = [frags[0], glitch(0.18, tmp / "g1.wav", SEED + 1), silence(0.22, tmp / "s1.wav"),
             frags[1], silence(0.55, tmp / "s2.wav"),
             frags[2], glitch(0.11, tmp / "g2.wav", SEED + 2), silence(0.30, tmp / "s3.wav"),
             frags[3], silence(0.42, tmp / "s4.wav"), frags[4]]
    return broadcast(concat(parts, tmp / "l2.wav"), "approach_pa_2", tmp)


def build_3(tmp):
    head = voice(LINE_3_HEAD, tmp / "l3_head.wav", tmp)
    cut = voice(LINE_3_TAIL, tmp / "l3_tail.wav", tmp, trim=LINE_3_TAIL_KEEP)
    burst = glitch(0.34, tmp / "g3.wav", SEED + 3, squeal=0.35)
    track = concat([head, silence(0.04, tmp / "s5.wav"), cut, burst], tmp / "l3.wav")
    # No tail click and almost no dead air: the channel does not close, it dies.
    return broadcast(track, "approach_pa_3", tmp, tail_click=False, dead_air=0.05)


def main():
    for b in ("say", "ffmpeg", "ffprobe"):
        need(b)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        outs = [build_1(tmp), build_2(tmp), build_3(tmp)]
    print("--- Breach approach PA: measured levels (game gains are set from these) ---")
    for p in outs:
        peak, rms = measure(p)
        print(f"{p.name:<20} peak={peak:.1f} dBFS  rms={rms:.1f} dBFS  ({dur(p):.2f}s)")


if __name__ == "__main__":
    main()
