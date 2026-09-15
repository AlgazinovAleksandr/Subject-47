#!/usr/bin/env python3
"""Corridor spur + corner-branch SFX (2026-09-14, BACKLOG_Sep_14 C2/C3/C4). Own file, own seed —
appending to make_sfx.py would re-roll every later file's noise (its header says so).

  bell_ding      — a reception counter bell: 2.4 kHz + inharmonic partials, 1.8 s decay
  latch_release  — a spring latch letting go: click + short rattle
  wall_knock_wood / wall_knock_stone / wall_knock_metal — the blind room's per-wall bumps
  lever_hum_far / lever_hum_near — the blind room's two-layer beacon (loops, seamless)
  cupboard_growl — the pass-by stopping outside the slats (a low held rasp, 1.6 s)

    python3 tools/make_sfx_corridor_spurs.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
Prints each file's peak/RMS dBFS — set gains from those, never from a plausible number.
"""
import math, os, random, struct, wave

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "level_3_corridor"))


def write(name, samples, peak_dbfs=-1.0):
    peak = max(1e-9, max(abs(v) for v in samples))
    norm = (10 ** (peak_dbfs / 20.0)) / peak
    out = [max(-1.0, min(1.0, v * norm)) for v in samples]
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as wv:
        wv.setnchannels(1); wv.setsampwidth(2); wv.setframerate(SR)
        wv.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in out))
    rms = math.sqrt(sum(v * v for v in out) / len(out))
    print("%-18s %5.2fs  peak %5.1f dBFS  RMS %5.1f dBFS" % (name, len(out) / SR, peak_dbfs, 20 * math.log10(max(rms, 1e-9))))


def env(t, a, d):
    return (t / a) if t < a else math.exp(-(t - a) / d)


def bell():
    n = int(SR * 1.8); out = []
    parts = [(2400.0, 1.0, 0.55), (4120.0, 0.45, 0.30), (6300.0, 0.25, 0.18), (1230.0, 0.3, 0.9)]
    for i in range(n):
        t = i / SR
        s = sum(g * math.sin(2 * math.pi * f * t) * env(t, 0.002, d) for f, g, d in parts)
        out.append(s)
    return out


def latch():
    rng = random.Random(41); n = int(SR * 0.45); out = []
    for i in range(n):
        t = i / SR
        click = rng.uniform(-1, 1) * env(t, 0.001, 0.012) * 1.0
        rattle = rng.uniform(-1, 1) * (0.35 if 0.06 < t < 0.3 else 0.0) * (0.5 + 0.5 * math.sin(2 * math.pi * 38 * t))
        ring = 0.25 * math.sin(2 * math.pi * 1800 * t) * env(t, 0.001, 0.08)
        out.append(click + rattle + ring)
    return out


def knock(material):
    rng = random.Random(7 + len(material)); n = int(SR * 0.5); out = []
    f0, decay, noise = {"wood": (180.0, 0.09, 0.5), "stone": (95.0, 0.05, 0.9), "metal": (420.0, 0.35, 0.3)}[material]
    for i in range(n):
        t = i / SR
        s = math.sin(2 * math.pi * f0 * t) * env(t, 0.002, decay)
        s += 0.4 * math.sin(2 * math.pi * f0 * 2.7 * t) * env(t, 0.002, decay * 0.6)
        s += noise * rng.uniform(-1, 1) * env(t, 0.001, 0.02)
        out.append(s)
    return out


def hum(near):
    rng = random.Random(99 if near else 98); L = 6.0; n = int(SR * L); out = []
    f = 96.0 if near else 60.0
    for i in range(n):
        t = i / SR
        wob = 0.75 + 0.25 * math.sin(2 * math.pi * (1.0 / L) * 2 * t)       # 2 cycles per loop
        s = math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2.01 * t) * wob
        if near:
            s += 0.3 * math.sin(2 * math.pi * f * 3.98 * t) * wob + 0.15 * rng.uniform(-1, 1)
        out.append(s)
    xf = int(SR * 0.05)
    for i in range(xf):
        w = i / xf
        out[i] = out[i] * w + out[n - xf + i] * (1 - w)
    return out


def growl():
    rng = random.Random(23); n = int(SR * 1.6); out = []
    for i in range(n):
        t = i / SR
        f = 52.0 + 8.0 * math.sin(2 * math.pi * 1.7 * t)
        rasp = math.sin(2 * math.pi * f * t) * (0.5 + 0.5 * (math.sin(2 * math.pi * 31 * t) > 0))
        s = rasp + 0.5 * rng.uniform(-1, 1) * (0.5 + 0.5 * math.sin(2 * math.pi * 31 * t))
        out.append(s * env(t, 0.15, 0.6))
    return out


if __name__ == "__main__":
    write("bell_ding", bell(), -3.0)
    write("latch_release", latch(), -4.0)
    write("wall_knock_wood", knock("wood"), -4.0)
    write("wall_knock_stone", knock("stone"), -4.0)
    write("wall_knock_metal", knock("metal"), -4.0)
    write("lever_hum_far", hum(False), -6.0)
    write("lever_hum_near", hum(True), -6.0)
    write("cupboard_growl", growl(), -2.0)
