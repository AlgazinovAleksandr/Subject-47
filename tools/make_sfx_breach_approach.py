#!/usr/bin/env python3
"""Procedural SFX for Level 6's containment approach (2026-09-23, the user's call).

Pure stdlib (wave/math/random), seeded, so re-running reproduces byte-identical output. Writes
16-bit mono 44.1 kHz WAVs into game/assets/audio/level_6_breach/, every base name prefixed
`approach_` because `GameState.load_audio()` resolves by base name across all audio subdirs.

What it makes, and why each one is generated rather than recorded (the user supplied thirteen
recordings for the story beats and asked for these three kinds to be generated):

  approach_drag              the heavy drag receding behind the Plenum's porthole door
  approach_grating_clang     the loose floor grating in ApproachDamaged ("it hears you")
  approach_receiver_ring     the pressure receivers ringing when the building answers the scream
  approach_duct_rattle       the Plenum's duct rattling in answer (replaces the old one-shot
                             metal_creak "loose fitting")
  approach_mach_*            twelve one-shot machinery sounds for the random pool (A8): played
                             6-14 s apart, 6-15 m away, mostly from behind the listener

⚠️ NO FOOTSTEP-LIKE SOUND, by the user's rule and the spec's Corridor-motif ban ("footsteps
following the player" is the Corridor's). So: no paired or evenly spaced low thuds, no heel
clicks. Every impact here is a single event, a metallic ring, or an irregular high tick train;
the drag's pulls have SMOOTH attacks so a pull can never read as a step.

Usage:  python3 tools/make_sfx_breach_approach.py
Then:   /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""

import math
import os
import random
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfx_loudness import measure  # noqa: E402

SR = 44100
TAU = math.tau
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "level_6_breach")

rng = random.Random(6230)  # level 6, 2026-09-23


# ---------------------------------------------------------------- primitives

def n(seconds):
    return int(seconds * SR)


def silence(seconds):
    return [0.0] * n(seconds)


def write(name, samples, peak=0.89):
    top = max(1e-9, max(abs(s) for s in samples))
    g = peak / top
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.normpath(os.path.join(OUT_DIR, name + ".wav"))
    frames = bytearray()
    for s in samples:
        frames += struct.pack("<h", int(max(-1.0, min(1.0, s * g)) * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    pk, loud = measure([s * g for s in samples], SR)
    rms = math.sqrt(sum((s * g) ** 2 for s in samples) / len(samples))
    print(f"{name + '.wav':38s} {len(samples) / SR:5.2f}s  peak {pk:6.2f}  loud300 {loud:6.2f}  "
          f"RMS {20 * math.log10(max(rms, 1e-9)):6.2f} dBFS")


def mix_into(dst, src, at=0, gain=1.0):
    for i, s in enumerate(src):
        j = at + i
        if 0 <= j < len(dst):
            dst[j] += s * gain


def lowpass(buf, cutoff):
    a = math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for x in buf:
        y = (1 - a) * x + a * y
        out.append(y)
    return out


def highpass(buf, cutoff):
    lp = lowpass(buf, cutoff)
    return [x - l for x, l in zip(buf, lp)]


def bandpass(buf, lo, hi):
    return lowpass(highpass(buf, lo), hi)


def white(seconds):
    return [rng.uniform(-1, 1) for _ in range(n(seconds))]


def brown(seconds):
    y, out = 0.0, []
    for _ in range(n(seconds)):
        y = 0.985 * y + rng.uniform(-1, 1) * 0.12
        out.append(y)
    return out


def modes(seconds, partials, attack=0.002):
    """Sum of exponentially decaying sines: [(freq, amp, decay_s), ...] — struck metal."""
    out = [0.0] * n(seconds)
    for f, amp, dec in partials:
        ph = rng.random() * TAU
        for i in range(len(out)):
            t = i / SR
            env = min(1.0, t / attack) * math.exp(-t / dec)
            out[i] += amp * env * math.sin(TAU * f * t + ph)
    return out


def envelope(buf, points):
    """Piecewise-linear gain over (time_s, gain) points."""
    out = []
    k = 0
    for i, x in enumerate(buf):
        t = i / SR
        while k < len(points) - 2 and t > points[k + 1][0]:
            k += 1
        t0, g0 = points[k]
        t1, g1 = points[k + 1]
        g = g0 if t1 <= t0 else g0 + (g1 - g0) * max(0.0, min(1.0, (t - t0) / (t1 - t0)))
        out.append(x * g)
    return out


def reverb(buf, tail=1.6, wet=0.45):
    """A small Schroeder reverb (four combs + two all-passes) — distance, not a hall."""
    out_len = len(buf) + n(tail)
    dry = buf + [0.0] * (out_len - len(buf))
    combs = [(1557, 0.84), (1617, 0.83), (1491, 0.85), (1422, 0.86)]
    acc = [0.0] * out_len
    for d, fb in combs:
        line = [0.0] * d
        idx = 0
        for i in range(out_len):
            y = line[idx]
            line[idx] = dry[i] + y * fb
            idx = (idx + 1) % d
            acc[i] += y * 0.25
    for d, g in [(225, 0.5), (556, 0.5)]:
        line = [0.0] * d
        idx = 0
        for i in range(out_len):
            b = line[idx]
            x = acc[i]
            y = -g * x + b
            line[idx] = x + g * y
            idx = (idx + 1) % d
            acc[i] = y
    fade = n(0.4)
    out = [dry[i] * (1 - wet) + acc[i] * wet for i in range(out_len)]
    for i in range(fade):
        out[-1 - i] *= i / fade
    return out


def tanh_drive(buf, drive):
    return [math.tanh(x * drive) for x in buf]


# ---------------------------------------------------------------- the story one-shots

def drag():
    """A heavy body dragged over concrete in three long pulls, no thuds (not footsteps)."""
    total = 4.3
    out = [0.0] * n(total)
    scrape = bandpass(brown(total), 60, 900)
    grit = bandpass(white(total), 900, 3800)
    cloth = highpass(white(total), 2500)
    pulls = [(0.05, 1.15), (1.45, 1.05), (2.75, 1.35)]
    for i in range(len(out)):
        t = i / SR
        g = 0.0
        for start, dur in pulls:
            if start <= t <= start + dur:
                u = (t - start) / dur
                # smooth attack (0.3 of the pull), a hold and a long release: a pull, never a step
                if u < 0.3:
                    pull = math.sin(0.5 * math.pi * u / 0.3) ** 2
                elif u < 0.6:
                    pull = 1.0
                else:
                    pull = (1.0 - (u - 0.6) / 0.4) ** 2
                g = max(g, pull)
        wobble = 0.7 + 0.3 * math.sin(TAU * 7.3 * t + 1.7 * math.sin(TAU * 1.1 * t))
        crackle = 1.0 if rng.random() > 0.9965 else 0.0
        out[i] = g * (scrape[i] * 2.6 * wobble + grit[i] * 0.55 + cloth[i] * 0.08) \
            + crackle * g * rng.uniform(-0.5, 0.5)
    out = lowpass(out, 3200)
    return envelope(out, [(0, 1.0), (2.6, 1.0), (4.3, 0.55)])


def grating_clang():
    """A loose steel floor grating stepped on: one struck plate and its settling rattle."""
    out = modes(1.5, [(318, 0.55, 0.42), (597, 0.48, 0.30), (912, 0.40, 0.22), (1341, 0.34, 0.16),
                      (2027, 0.24, 0.10), (2893, 0.16, 0.06), (4110, 0.10, 0.03)])
    hit = envelope(bandpass(white(0.05), 400, 6000), [(0, 1.0), (0.05, 0.0)])
    mix_into(out, hit, 0, 1.3)
    # the grate rocking back into its frame: two smaller, damped, irregular knocks
    for at, g in [(0.105, 0.42), (0.187, 0.2)]:
        mix_into(out, modes(0.5, [(351, 0.5, 0.12), (1020, 0.35, 0.06), (2230, 0.2, 0.03)]), n(at), g)
    return reverb(out, tail=0.9, wet=0.28)


def receiver_ring():
    """A big pressure vessel ringing from a shock through its shell — a low, beating hum."""
    out = modes(3.4, [(88.0, 0.6, 2.2), (89.3, 0.45, 2.0), (141.7, 0.4, 1.6), (233.1, 0.3, 1.1),
                      (367.4, 0.2, 0.7), (602.0, 0.08, 0.35)], attack=0.03)
    return reverb(out, tail=1.2, wet=0.3)


def duct_rattle():
    """Thin sheet-metal duct rattling: an irregular buzz of tin impacts that dies away."""
    total = 1.4
    out = [0.0] * n(total)
    t = 0.0
    while t < 1.15:
        amp = math.exp(-t / 0.45)
        tick = modes(0.05, [(rng.uniform(1700, 2600), 0.6, 0.012), (rng.uniform(640, 820), 0.4, 0.02)])
        mix_into(out, tick, n(t), amp * rng.uniform(0.6, 1.0))
        t += rng.uniform(0.022, 0.05)
    mix_into(out, modes(1.2, [(211, 0.35, 0.5), (437, 0.2, 0.3)], attack=0.01), 0, 0.8)
    return reverb(out, tail=0.6, wet=0.22)


# ---------------------------------------------------------------- the machinery pool

def mach_valve_hiss():
    b = bandpass(white(2.2), 1800, 5200)
    return envelope(b, [(0, 0), (0.25, 0.7), (1.4, 1.0), (1.55, 0.2), (2.2, 0.0)])


def mach_relay_clunk():
    out = modes(0.6, [(180, 0.6, 0.06), (420, 0.4, 0.04), (3100, 0.25, 0.008)])
    mix_into(out, modes(0.3, [(2600, 0.5, 0.006), (5200, 0.3, 0.003)]), n(0.028), 0.6)
    return reverb(out, tail=0.5, wet=0.3)


def mach_pipe_ticks():
    out = [0.0] * n(2.6)
    t = 0.05
    while t < 2.2:
        f = rng.uniform(2800, 4600)
        mix_into(out, modes(0.08, [(f, 0.5, 0.01), (f * 1.53, 0.25, 0.006)]), n(t), rng.uniform(0.3, 1.0))
        t += rng.choice([0.07, 0.11, 0.19, 0.33, 0.48])
    return reverb(out, tail=0.4, wet=0.25)


def mach_duct_pop():
    out = modes(0.9, [(96, 0.7, 0.14), (205, 0.45, 0.1), (1180, 0.2, 0.05), (1630, 0.15, 0.04)], attack=0.004)
    return reverb(out, tail=0.8, wet=0.35)


def mach_chain_rattle():
    out = [0.0] * n(1.9)
    t = 0.0
    while t < 1.5:
        amp = 0.4 + 0.6 * math.sin(math.pi * t / 1.5)
        link = modes(0.06, [(rng.uniform(2200, 3900), 0.6, 0.015), (rng.uniform(5000, 6400), 0.3, 0.006)])
        mix_into(out, link, n(t), amp * rng.uniform(0.4, 1.0))
        t += rng.uniform(0.018, 0.06)
    return reverb(out, tail=0.6, wet=0.3)


def mach_bearing_whine():
    total = 3.0
    out = []
    ph = 0.0
    for i in range(n(total)):
        t = i / SR
        f = 900 + 420 * math.sin(math.pi * t / total) + 14 * math.sin(TAU * 5.1 * t)
        ph += TAU * f / SR
        env = math.sin(math.pi * t / total) ** 1.4
        out.append(env * (0.5 * math.sin(ph) + 0.18 * math.sin(2.01 * ph)))
    mix_into(out, [x * 0.05 for x in bandpass(white(total), 600, 2400)])
    return out


def mach_steam_sigh():
    b = lowpass(bandpass(white(2.6), 180, 2200), 1600)
    return envelope(b, [(0, 0), (0.6, 1.0), (1.3, 0.8), (2.6, 0.0)])


def mach_metal_ping():
    out = modes(1.0, [(1487, 0.5, 0.5), (2211, 0.35, 0.4), (3390, 0.2, 0.25), (743, 0.25, 0.6)])
    return reverb(out, tail=1.6, wet=0.55)


def mach_conduit_buzz():
    total = 1.6
    out = []
    for i in range(n(total)):
        t = i / SR
        s = sum(math.sin(TAU * 100 * k * t) / k for k in (1, 2, 3, 5, 7))
        env = min(1.0, t / 0.15) * (1.0 if t < 1.35 else 0.0)
        out.append(env * s * 0.3 * (0.8 + 0.2 * math.sin(TAU * 3.3 * t)))
    mix_into(out, envelope(bandpass(white(0.06), 1500, 7000), [(0, 1), (0.06, 0)]), n(1.35), 0.9)
    return tanh_drive(out, 1.6)


def mach_gate_clank():
    out = modes(1.2, [(71, 0.6, 0.5), (143, 0.45, 0.35), (389, 0.3, 0.2), (812, 0.2, 0.12), (1670, 0.1, 0.06)])
    return reverb(lowpass(out, 2400), tail=2.2, wet=0.6)


def mach_fan_spindown():
    total = 3.2
    out = []
    ph = 0.0
    for i in range(n(total)):
        t = i / SR
        f = 210 * (1 - t / total) ** 1.6 + 22
        ph += TAU * f / SR
        chop = 0.6 + 0.4 * math.sin(ph * 0.25)
        env = min(1.0, t / 0.1) * (1 - t / total)
        out.append(env * chop * (0.5 * math.sin(ph) + 0.2 * math.sin(3 * ph)))
    mix_into(out, [x * 0.06 for x in lowpass(white(total), 900)])
    return out


def mach_pressure_groan():
    total = 2.8
    out = []
    ph = 0.0
    for i in range(n(total)):
        t = i / SR
        f = 62 + 18 * math.sin(math.pi * t / total) + 5 * math.sin(TAU * 0.9 * t)
        ph += TAU * f / SR
        rough = 0.75 + 0.25 * math.sin(TAU * 31 * t + 2 * math.sin(TAU * 4 * t))
        env = math.sin(math.pi * t / total) ** 1.2
        out.append(env * rough * (math.sin(ph) + 0.4 * math.sin(2.02 * ph) + 0.2 * math.sin(3.1 * ph)))
    return reverb(lowpass(out, 1400), tail=1.0, wet=0.35)


STORY = [
    ("approach_drag", drag),
    ("approach_grating_clang", grating_clang),
    ("approach_receiver_ring", receiver_ring),
    ("approach_duct_rattle", duct_rattle),
]
POOL = [
    ("approach_mach_valve_hiss", mach_valve_hiss),
    ("approach_mach_relay_clunk", mach_relay_clunk),
    ("approach_mach_pipe_ticks", mach_pipe_ticks),
    ("approach_mach_duct_pop", mach_duct_pop),
    ("approach_mach_chain_rattle", mach_chain_rattle),
    ("approach_mach_bearing_whine", mach_bearing_whine),
    ("approach_mach_steam_sigh", mach_steam_sigh),
    ("approach_mach_metal_ping", mach_metal_ping),
    ("approach_mach_conduit_buzz", mach_conduit_buzz),
    ("approach_mach_gate_clank", mach_gate_clank),
    ("approach_mach_fan_spindown", mach_fan_spindown),
    ("approach_mach_pressure_groan", mach_pressure_groan),
]


def main():
    for name, fn in STORY + POOL:
        write(name, fn())
    print(f"{len(POOL)} machinery one-shots + {len(STORY)} story one-shots")


if __name__ == "__main__":
    main()
