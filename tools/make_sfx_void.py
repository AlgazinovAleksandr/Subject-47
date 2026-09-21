#!/usr/bin/env python3
"""The Void's stare sounds (2026-09-20): `stalker_whisper` — the loop a fractured figure whispers
while you keep looking at it — and `blink`, the wet cut of the forced blink hallucination.

Pure-stdlib (wave/math/random), seeded and reproducible, 16-bit mono 44.1 kHz — the same contract
as tools/make_sfx.py. Writes SEVEN files into game/assets/audio/level_4_void/ (the loop's return
sounds `loop_slam`, `paper_drop` and `stone_grind` joined on 2026-09-20 evening — pass 2's ladder):

    python3 tools/make_sfx_void.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

WHY A SEPARATE FILE. Every other generator re-emits its own already-balanced set on each run;
this writes exactly what is new (make_sfx_mirror.py's reasoning). ⚠️ BASE NAMES MUST STAY
GLOBALLY UNIQUE — `GameState.load_audio()` resolves by base name across a hardcoded subdir list
and the first hit wins. `stalker_whisper` and `blink` were checked against every .wav/.ogg/.mp3
base name on 2026-09-20 (`whisper`, `whispers`, `whisper_dungeon`, `phone_whisper` are the near
neighbours; none collide).

THE WHISPER IS A SEAMLESS LOOP BY CONSTRUCTION (make_sfx_seam.py's rule): every modulation
frequency completes a whole number of cycles in the loop length, and the noise bed is a circular
buffer, so `finished -> play()` (creature_stalker.gd's re-trigger idiom, loop_mode=0 on every
.wav.import here) has no click. It is DELIBERATELY quiet and wordless — the level is not supposed
to tell you what it says. The stalker's WHISPER_MAX_DB is set from the RMS this prints.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "level_4_void")


def write_wav(name, samples):
    path = os.path.normpath(os.path.join(OUT, name + ".wav"))
    peak = max(1e-9, max(abs(x) for x in samples))
    scale = 0.89 / peak  # peak -1.0 dBFS, like the rest of the project
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    acc = sum((x * scale) ** 2 for x in samples)
    rms = math.sqrt(acc / len(samples))
    print("wrote %s  %.2fs  peak -1.0 dBFS  RMS %.1f dBFS" % (path, len(samples) / SR, 20.0 * math.log10(rms + 1e-12)))


class OnePole:
    def __init__(self, cutoff_hz):
        self.a = math.exp(-2.0 * math.pi * cutoff_hz / SR)
        self.y = 0.0

    def tick(self, x):
        self.y = (1.0 - self.a) * x + self.a * self.y
        return self.y


def circular_noise(n, cutoff_hz, rng, warmup=8192):
    """Low-passed noise generated as a ring: the filter runs `warmup` samples past the end and the
    tail is folded back over the head, so sample n-1 flows into sample 0."""
    lp = OnePole(cutoff_hz)
    raw = [lp.tick(rng.uniform(-1.0, 1.0)) for _ in range(n + warmup)]
    out = raw[:n]
    for i in range(warmup):
        w = i / float(warmup)
        out[i] = out[i] * w + raw[n + i] * (1.0 - w)
    return out


def make_stalker_whisper():
    """6.0 s loop. A breathy band of noise (the sibilance of speech with no words in it), gated by
    three 'syllable' pulses at 0.5, 0.8333 and 1.1667 Hz — 3, 5 and 7 whole cycles in 6 s — under a
    55 Hz undertone (330 cycles). Nothing in it is periodic at a pitch you could hum."""
    rng = random.Random(4708)
    n = SR * 6
    hiss = circular_noise(n, 3200.0, rng)
    body = circular_noise(n, 600.0, rng)
    out = []
    for i in range(n):
        t = i / float(SR)
        syl = (0.55 + 0.45 * math.sin(2 * math.pi * 0.5 * t)) \
            * (0.6 + 0.4 * math.sin(2 * math.pi * 0.8333333 * t + 1.1)) \
            * (0.7 + 0.3 * math.sin(2 * math.pi * 1.1666667 * t + 2.3))
        s = hiss[i] * 0.55 * syl + body[i] * 0.35 * (0.5 + 0.5 * syl)
        s += 0.06 * math.sin(2 * math.pi * 55.0 * t) * (0.6 + 0.4 * syl)
        out.append(s)
    return out


def make_blink():
    """0.32 s one-shot: a wet click (a short bright noise burst through a fast-closing low-pass)
    over a 42 Hz thump. The sound of an eyelid you did not decide to close."""
    rng = random.Random(4709)
    n = int(SR * 0.32)
    out = []
    lp = OnePole(2200.0)
    for i in range(n):
        t = i / float(SR)
        env = math.exp(-t * 26.0)
        cutoff_env = math.exp(-t * 40.0)
        lp.a = math.exp(-2.0 * math.pi * (300.0 + 5000.0 * cutoff_env) / SR)
        click = lp.tick(rng.uniform(-1.0, 1.0)) * env
        thump = math.sin(2 * math.pi * 42.0 * t) * math.exp(-t * 14.0) * 0.8
        out.append(click * 0.9 + thump)
    return out


def make_loop_slam():
    """0.9 s one-shot: a distant heavy door slam behind you — a 55 Hz thump with a fast bright
    transient, then a long low-passed tail. The corridor closing at your back on every send-back."""
    rng = random.Random(4710)
    n = int(SR * 0.9)
    out = []
    lp = OnePole(900.0)
    for i in range(n):
        t = i / float(SR)
        hit = lp.tick(rng.uniform(-1.0, 1.0)) * math.exp(-t * 18.0)
        thump = math.sin(2 * math.pi * 55.0 * t) * math.exp(-t * 7.0) * 0.9
        tail = lp.tick(rng.uniform(-1.0, 1.0)) * 0.25 * math.exp(-t * 3.2)
        out.append(hit * 0.7 + thump + tail)
    return out


def make_paper_drop():
    """0.55 s one-shot: a page fluttering down and settling — bright crinkle bursts that slow, then a
    soft tap. The note arriving where the torn pages lie."""
    rng = random.Random(4711)
    n = int(SR * 0.55)
    out = []
    hp_prev = 0.0
    for i in range(n):
        t = i / float(SR)
        flutter = (0.5 + 0.5 * math.sin(2 * math.pi * (14.0 - 10.0 * t) * t)) * math.exp(-t * 4.0)
        raw = rng.uniform(-1.0, 1.0)
        hp = raw - hp_prev * 0.92   # crude high-pass: crinkle, not rumble
        hp_prev = raw
        tap = math.sin(2 * math.pi * 180.0 * t) * math.exp(-(t - 0.42) * 60.0) if t > 0.42 else 0.0
        out.append(hp * 0.35 * flutter + tap * 0.5)
    return out


def make_stone_grind():
    """1.3 s one-shot: stone dragged over stone — low-passed noise with a slow 3 Hz judder and a
    40 Hz rumble that dies as the plug seats. The doorway walling itself up behind you."""
    rng = random.Random(4712)
    n = int(SR * 1.3)
    out = []
    lp = OnePole(420.0)
    for i in range(n):
        t = i / float(SR)
        env = min(1.0, t * 8.0) * math.exp(-max(0.0, t - 0.8) * 6.0)
        judder = 0.65 + 0.35 * math.sin(2 * math.pi * 3.0 * t)
        grind = lp.tick(rng.uniform(-1.0, 1.0)) * judder
        rumble = math.sin(2 * math.pi * 40.0 * t) * 0.35
        out.append((grind * 0.8 + rumble) * env)
    return out


def make_drawer_pull():
    """0.45 s one-shot: a stone drawer sliding open — a short low-passed scrape that decelerates,
    ending in a dull stop. Seventeen of these in the Morgue; only one drawer holds anything."""
    rng = random.Random(4713)
    n = int(SR * 0.45)
    out = []
    lp = OnePole(700.0)
    for i in range(n):
        t = i / float(SR)
        slide = lp.tick(rng.uniform(-1.0, 1.0)) * (0.9 - 1.6 * t) * (1.0 if t < 0.36 else 0.0)
        stop = math.sin(2 * math.pi * 95.0 * t) * math.exp(-(t - 0.36) * 45.0) if t >= 0.36 else 0.0
        out.append(max(-1.0, min(1.0, slide * 0.8 + stop * 0.6)))
    return out


def make_frame_drop():
    """0.7 s one-shot: falling THROUGH a doorway lying on the floor — a downward noise sweep with a
    reversed swell, then nothing. The step-through's only sound."""
    rng = random.Random(4714)
    n = int(SR * 0.7)
    out = []
    lp = OnePole(3000.0)
    for i in range(n):
        t = i / float(SR)
        cutoff = 3000.0 * math.exp(-t * 4.5) + 60.0
        lp.a = math.exp(-2.0 * math.pi * cutoff / SR)
        swell = min(1.0, t * 6.0) * math.exp(-max(0.0, t - 0.25) * 7.0)
        out.append(lp.tick(rng.uniform(-1.0, 1.0)) * swell * 0.9
                   + math.sin(2 * math.pi * (120.0 - 90.0 * t) * t) * 0.25 * swell)
    return out


def make_cradle_sting():
    """0.9 s one-shot, LOUD: the cradle's figure rising and lunging — a dense inharmonic cluster with a
    fast noise onset and a tanh soft-clip so it is dense rather than merely peaked (Issue 101). Its
    own file on purpose: a fatal sting reused for a survivable scare teaches that the fatal sound is
    free (the crate_shriek lesson). Zero panic accompanies it in the game."""
    rng = random.Random(4715)
    n = int(SR * 0.9)
    out = []
    lp = OnePole(2600.0)
    partials = [66.0, 97.0, 151.0, 233.0, 377.0, 610.0]
    for i in range(n):
        t = i / float(SR)
        onset = lp.tick(rng.uniform(-1.0, 1.0)) * math.exp(-t * 22.0) * 1.2
        env = min(1.0, t * 40.0) * math.exp(-max(0.0, t - 0.12) * 4.2)
        cluster = sum(math.sin(2 * math.pi * f * t * (1.0 + 0.08 * math.sin(2 * math.pi * 6.0 * t))) for f in partials) / 3.2
        out.append(math.tanh((onset + cluster * env) * 1.8))
    return out


def make_frame_tone():
    """0.6 s one-shot: a soft bowed tone (a single pitch — the game raises it an interval per stage with
    pitch_scale). Two partials, slow attack, so it reads as the room answering, not a UI chime."""
    n = int(SR * 0.6)
    out = []
    for i in range(n):
        t = i / float(SR)
        env = min(1.0, t * 12.0) * math.exp(-max(0.0, t - 0.15) * 5.5)
        out.append((math.sin(2 * math.pi * 196.0 * t) + 0.45 * math.sin(2 * math.pi * 392.0 * t + 0.4)) * 0.5 * env)
    return out


def make_frame_settle():
    """1.6 s one-shot: five stone frames sliding into one line — a stone_grind-like drag under a rising
    five-note cluster that lands together on the last."""
    rng = random.Random(4716)
    n = int(SR * 1.6)
    out = []
    lp = OnePole(500.0)
    notes = [196.0, 220.0, 247.0, 262.0, 294.0]
    for i in range(n):
        t = i / float(SR)
        grind = lp.tick(rng.uniform(-1.0, 1.0)) * 0.6 * (1.0 if t < 1.2 else math.exp(-(t - 1.2) * 12.0))
        chord = 0.0
        for k, f in enumerate(notes):
            start = 0.15 * k
            if t >= start:
                chord += math.sin(2 * math.pi * f * t) * 0.16 * min(1.0, (t - start) * 8.0)
        chord *= math.exp(-max(0.0, t - 1.25) * 4.0)
        out.append(grind + chord)
    return out


def make_shard_clatter():
    """0.5 s one-shot: a stone shard dropping into a stone basin — two hard clicks a few ms apart
    (the corner, then the flat), a short bright rattle, and a dull settle. The Archive table's
    wedged shard coming loose behind your back (pass 5's receipt)."""
    rng = random.Random(4718)
    n = int(SR * 0.5)
    out = []
    lp = OnePole(2600.0)
    for i in range(n):
        t = i / float(SR)
        click = 0.0
        for t0, amp in ((0.0, 1.0), (0.055, 0.7), (0.13, 0.45), (0.19, 0.3)):
            if t >= t0:
                click += amp * math.sin(2 * math.pi * 1900.0 * (t - t0)) * math.exp(-(t - t0) * 260.0)
        rattle = lp.tick(rng.uniform(-1.0, 1.0)) * 0.35 * math.exp(-t * 14.0) * (1.0 if t > 0.02 else 0.0)
        settle = math.sin(2 * math.pi * 130.0 * t) * 0.25 * math.exp(-max(0.0, t - 0.2) * 18.0) * (1.0 if t >= 0.2 else 0.0)
        out.append(click * 0.8 + rattle + settle)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav("stalker_whisper", make_stalker_whisper())
    write_wav("blink", make_blink())
    write_wav("loop_slam", make_loop_slam())
    write_wav("paper_drop", make_paper_drop())
    write_wav("stone_grind", make_stone_grind())
    write_wav("drawer_pull", make_drawer_pull())
    write_wav("frame_drop", make_frame_drop())
    write_wav("cradle_sting", make_cradle_sting())
    write_wav("frame_tone", make_frame_tone())
    write_wav("frame_settle", make_frame_settle())
    write_wav("shard_clatter", make_shard_clatter())


if __name__ == "__main__":
    main()
