#!/usr/bin/env python3
"""PLACEHOLDER audio for Level 6's approach, pass 3 (2026-09-23): every sound the pass needs, at
the FIXED game path the user's own recording will replace.

⚠️ THESE ARE STAND-INS. The user is supplying real recordings for all of them (the whisper, the
wheel grind, the bolts and the hatch swing, the handle clack, the spark bursts and buzz, the dark-room
bed, three glass crunches, the CRT hum). Drop each supplied file at the path printed below — same
base name, `.wav` — and re-run `--import`; no code changes. `breach_approach.gd` reads every one by
its fixed path and sets its gain from the level this tool measures, so a supplied file that is much
louder or quieter than the stand-in wants its `*_DB` constant re-read (the constants are commented).

Three kinds, the brief's own list:
  * GENERATED here (stdlib, seeded): the wheel grind loop, the per-30° creak, the handle clack, the
    dark-room bed loop, three glass crunches, the CRT hum loop.
  * COPIED from existing game files, re-encoded under the new base name: the spark burst
    (level_1_lab/breaker_spark), the spark buzz (level_1_lab/breaker_buzz), the bolts
    (level_5_kontur/door_seal), the hatch swing (level_1_lab/metal_creak). Base names must be
    globally unique, so a copy is the only way to point a new name at old audio.
  * SPOKEN by macOS `say -v Whisper`: "don't… go in there…", then roughened (a breath bed, a band
    limit). Needs `say` and `ffmpeg` on the machine; the tool says so and skips if either is missing.

Usage:  python3 tools/make_sfx_breach_pass3.py
Then:   /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""

import math
import os
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfx_loudness import measure  # noqa: E402

SR = 44100
TAU = math.tau
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT_DIR = os.path.join(ROOT, "game", "assets", "audio", "level_6_breach")
GAME_AUDIO = os.path.join(ROOT, "game", "assets", "audio")

rng = random.Random(62303)


def n(seconds):
    return int(seconds * SR)


def report(name, samples):
    pk, loud = measure(samples, SR)
    rms = math.sqrt(sum(s * s for s in samples) / max(1, len(samples)))
    print(f"{name + '.wav':38s} {len(samples) / SR:5.2f}s  peak {pk:6.2f}  loud300 {loud:6.2f}  "
          f"RMS {20 * math.log10(max(rms, 1e-9)):6.2f} dBFS")


def write(name, samples, peak=0.89):
    top = max(1e-9, max(abs(s) for s in samples))
    g = peak / top
    out = [max(-1.0, min(1.0, s * g)) for s in samples]
    path = os.path.join(OUT_DIR, name + ".wav")
    frames = bytearray()
    for s in out:
        frames += struct.pack("<h", int(s * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    report(name, out)


def read_mono(path):
    with wave.open(path, "rb") as w:
        ch, sw, sr, nf = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(nf)
    assert sw == 2, f"{path}: expected 16-bit"
    vals = struct.unpack("<%dh" % (len(raw) // 2), raw)
    mono = [sum(vals[i:i + ch]) / (ch * 32768.0) for i in range(0, len(vals), ch)]
    return mono, sr


def lowpass(buf, cutoff):
    a = math.exp(-TAU * cutoff / SR)
    y, out = 0.0, []
    for x in buf:
        y = (1 - a) * x + a * y
        out.append(y)
    return out


def highpass(buf, cutoff):
    return [x - l for x, l in zip(buf, lowpass(buf, cutoff))]


def white(seconds):
    return [rng.uniform(-1, 1) for _ in range(n(seconds))]


def modes(seconds, partials, attack=0.002):
    out = [0.0] * n(seconds)
    for f, amp, dec in partials:
        ph = rng.random() * TAU
        for i in range(len(out)):
            t = i / SR
            out[i] += amp * min(1.0, t / attack) * math.exp(-t / dec) * math.sin(TAU * f * t + ph)
    return out


def mix_into(dst, src, at=0, gain=1.0):
    for i, s in enumerate(src):
        j = at + i
        if 0 <= j < len(dst):
            dst[j] += s * gain


def seamless(buf, xfade):
    """Crossfade the tail over the head (equal power) so `finished -> play` has no seam."""
    k = n(xfade)
    body = buf[:len(buf) - k]
    for i in range(k):
        t = i / k
        body[i] = body[i] * math.sqrt(t) + buf[len(buf) - k + i] * math.sqrt(1 - t)
    return body


# ---------------------------------------------------------------- generated

def wheel_grind():
    """Steel on steel under load: a slowly wandering friction tone over grit, looped."""
    L = 3.0 + 0.6
    grit = lowpass(highpass(white(L), 900), 5200)
    tone = []
    f = 186.0
    ph = 0.0
    for i in range(n(L)):
        t = i / SR
        f = 186.0 + 22.0 * math.sin(TAU * 0.37 * t) + 9.0 * math.sin(TAU * 1.9 * t)
        ph += TAU * f / SR
        stick = 0.55 + 0.45 * abs(math.sin(TAU * 7.3 * t + math.sin(TAU * 0.8 * t)))
        tone.append((0.5 * math.sin(ph) + 0.25 * math.sin(2.02 * ph) + 0.12 * math.sin(3.1 * ph)) * stick)
    out = [0.55 * g + 0.45 * s for g, s in zip(grit, tone)]
    write("approach_wheel_grind", seamless(out, 0.6), peak=0.7)


def wheel_creak():
    """One ratchet step of a seized handwheel: a short dry creak with a metallic tick on top."""
    L = 0.42
    out = [0.0] * n(L)
    ph = 0.0
    for i in range(n(0.3)):
        t = i / SR
        f = 420 - 260 * t / 0.3
        ph += TAU * f / SR
        env = math.sin(math.pi * min(1.0, t / 0.3)) ** 0.7
        out[i] += env * (math.sin(ph) + 0.4 * math.sin(2.7 * ph)) * (0.6 + 0.4 * rng.random())
    mix_into(out, modes(0.2, [(2350, 0.5, 0.03), (3910, 0.3, 0.02), (1180, 0.4, 0.05)]), n(0.01), 0.8)
    write("approach_wheel_creak", highpass(out, 140), peak=0.8)


def handle_clack():
    """The handle seating on the wheel's square boss: a hard steel clack and a short ring."""
    out = [0.0] * n(0.6)
    mix_into(out, modes(0.6, [(612, 0.8, 0.09), (1837, 0.5, 0.05), (2961, 0.35, 0.03), (4410, 0.2, 0.015)], 0.0006))
    click = highpass(white(0.012), 2500)
    mix_into(out, click, 0, 0.9)
    mix_into(out, modes(0.3, [(890, 0.4, 0.04), (2210, 0.3, 0.02)]), n(0.07), 0.5)
    write("approach_handle_clack", out, peak=0.85)


def darkroom_bed():
    """The dark room: a failing transformer hum, the room's own air, and a tick of dripping. Looped."""
    L = 12.0 + 1.5
    air = lowpass(white(L), 380)
    hum = []
    for i in range(n(L)):
        t = i / SR
        wob = 1.0 + 0.08 * math.sin(TAU * 0.11 * t)
        hum.append(0.4 * math.sin(TAU * 50 * t) * wob + 0.22 * math.sin(TAU * 100 * t) + 0.08 * math.sin(TAU * 150 * t))
    out = [0.7 * a + 0.3 * h for a, h in zip(air, hum)]
    t = 0.7
    while t < L - 0.5:
        drip = modes(0.25, [(1900 + rng.uniform(-300, 300), 0.5, 0.04), (3100, 0.2, 0.02)], 0.001)
        mix_into(out, drip, n(t), rng.uniform(0.06, 0.14))
        t += rng.uniform(1.1, 2.9)
    write("approach_darkroom_bed", seamless(out, 1.5), peak=0.6)


def glass_crunch(k):
    """A boot on broken safety glass: a dense cluster of tiny bright fractures, then grit."""
    L = 0.5
    out = [0.0] * n(L)
    count = 26 + k * 6
    for _ in range(count):
        at = n(abs(rng.gauss(0.05, 0.05)))
        f = rng.uniform(2800, 7800)
        mix_into(out, modes(0.05, [(f, 1.0, rng.uniform(0.004, 0.012)), (f * 1.53, 0.5, 0.006)], 0.0003), at,
                 rng.uniform(0.2, 0.7))
    grit = lowpass(highpass(white(0.35), 1200), 6500)
    for i in range(len(grit)):
        grit[i] *= math.exp(-i / n(0.08))
    mix_into(out, grit, n(0.01), 0.5)
    write(f"approach_glass_crunch_{k}", out, peak=0.85)


def crt_hum():
    """An old CRT left on: mains hum, a faint 15.7 kHz line whistle, and static hiss. Looped."""
    L = 6.0 + 1.0
    hiss = highpass(white(L), 3000)
    out = []
    for i in range(n(L)):
        t = i / SR
        h = 0.5 * math.sin(TAU * 50 * t) + 0.3 * math.sin(TAU * 100 * t) + 0.1 * math.sin(TAU * 250 * t)
        whine = 0.05 * math.sin(TAU * 15734 * t)
        out.append(0.55 * h + 0.25 * hiss[i] * (0.8 + 0.2 * math.sin(TAU * 0.3 * t)) + whine)
    write("approach_crt_hum", seamless(out, 1.0), peak=0.55)


# ---------------------------------------------------------------- copies and speech

def ffmpeg_to_wav(src, dst_name, extra=""):
    ff = shutil.which("ffmpeg")
    if not ff:
        print(f"  ! ffmpeg missing: {dst_name} not written")
        return False
    dst = os.path.join(OUT_DIR, dst_name + ".wav")
    cmd = [ff, "-v", "error", "-y", "-i", src]
    if extra:
        cmd += ["-af", extra]
    cmd += ["-ac", "1", "-ar", str(SR), "-sample_fmt", "s16", dst]
    subprocess.run(cmd, check=True)
    mono, _ = read_mono(dst)
    report(dst_name + "  (copy)", mono)
    return True


def copies():
    ffmpeg_to_wav(os.path.join(GAME_AUDIO, "level_1_lab", "breaker_spark.wav"), "approach_spark_burst")
    ffmpeg_to_wav(os.path.join(GAME_AUDIO, "level_1_lab", "breaker_buzz.wav"), "approach_spark_buzz")
    ffmpeg_to_wav(os.path.join(GAME_AUDIO, "level_5_kontur", "door_seal.wav"), "approach_porthole_bolts")
    # the lab's metal creak, slowed and lowered: a heavy hatch, not a locker
    ffmpeg_to_wav(os.path.join(GAME_AUDIO, "level_1_lab", "metal_creak.ogg"), "approach_porthole_swing",
                  "asetrate=44100*0.72,aresample=44100,lowpass=f=3200")


def whisper():
    say = shutil.which("say")
    ff = shutil.which("ffmpeg")
    if not say or not ff:
        print("  ! `say` or ffmpeg missing: approach_whisper_dont_go_in not written")
        return
    with tempfile.TemporaryDirectory() as tmp:
        aiff = os.path.join(tmp, "w.aiff")
        wav = os.path.join(tmp, "w.wav")
        subprocess.run([say, "-v", "Whisper", "-r", "105", "-o", aiff, "don't...   go in there..."], check=True)
        subprocess.run([ff, "-v", "error", "-y", "-i", aiff, "-af",
                        "highpass=f=260,lowpass=f=5200,apad=pad_dur=0.4", "-ac", "1", "-ar", str(SR),
                        "-sample_fmt", "s16", wav], check=True)
        voice, _ = read_mono(wav)
    # hoarse: a breath bed under the voice, following its envelope, and a slight drive
    env, e = [], 0.0
    for s in voice:
        e = max(abs(s), e * 0.9993)
        env.append(e)
    breath = lowpass(highpass(white(len(voice) / SR + 0.1), 700), 4200)
    out = [math.tanh(1.6 * v) + 0.35 * env[i] * breath[i] for i, v in enumerate(voice)]
    write("approach_whisper_dont_go_in", out, peak=0.8)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    wheel_grind()
    wheel_creak()
    handle_clack()
    darkroom_bed()
    for k in (1, 2, 3):
        glass_crunch(k)
    crt_hum()
    copies()
    whisper()


if __name__ == "__main__":
    main()
