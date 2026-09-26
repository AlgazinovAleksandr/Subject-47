#!/usr/bin/env python3
"""Procedural SFX for the redesigned Intro Room (see INTRO.md).

Pure-stdlib (wave/math/random), same conventions as make_sfx_extra.py.
Outputs 16-bit mono 44.1 kHz .wav files into game/assets/audio/intro/:

  switch_clunk.wav          heavy old wall-switch throw + spark-crackle tail
  fluorescent_buzz_on.wav   ceiling tubes stuttering on
  emergency_hum.wav         very quiet loopable electrical hum (path-glow bed)
  gurney_creak.wav          short metal-frame creak, plays as the player sits up

⭐ THE INTAKE WING (2026-09-24) adds the `intro_*` set below. Every one is a PROCEDURAL STAND-IN,
listed in docs/TODO_sounds.md with a description and a sourcing prompt; the user replaces a file
by dropping a real recording in under the same base name, and no code changes.

  intro_strap_buckle.wav    a leather restraint strap pulled through its buckle (cell, x3)
  intro_cell_buzz.wav       the cell door's electric release: buzzer + bolt clack
  intro_door_rattle.wav     a locked door's handle tried: rattle against the latch
  intro_door_creak.wav      an old wooden door on dry hinges swinging open: latch + long squeal
  intro_tap_rust.wav        the cell tap's first turn: pipe cough, sputter, gurgle
  intro_tap_water.wav       steady thin water into a steel basin (LOOP)
  intro_bulb_hum.wav        a bare filament bulb's mains buzz (LOOP)
  intro_power_cut.wav       the wing's power dying: relay slam + a falling whine
  intro_projector_run.wav   the slide projector's fan and lamp hum (LOOP)
  intro_projector_slide.wav a carousel slide change: clack, slide drop, click
  intro_airlock_buzzer.wav  the airlock's two-tone release buzzer
  intro_chair_sit.wav       sitting down in the calibration chair: a wooden creak + a strap slap
  intro_hatch_slam.wav      a body hitting the airlock hatch's steel bars: thud, bar ring, rattle
  intro_hatch_shutter.wav   the hatch's steel shutter dropped: rail scrape, heavy bang, latch
  intro_session46_tape.wav  ~40 s "SESSION 46" reel: motor, hiss, muffled wordless murmur,
                            breathing, a chair, a long silence and the tape running out

⚠️ `main()` writes ONLY the intro_* set. The four originals above are rewritten only with
`--all`: they are seeded and SHOULD regenerate identically, but nothing checks that, and a tool
run for new files must not be able to change shipped ones by accident.

Usage: python3 tools/make_sfx_intro.py          (the intro_* set)
       python3 tools/make_sfx_intro.py --all    (…and the four originals)
"""

import math
import os
import random
import struct
import sys
import wave

SR = 44100
AUDIO = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio")


# ⚠️ USER-SUPPLIED since 2026-09-24 (tools/import_intro_user_sfx.py renders the user's recordings into
# these slots). A re-run of this generator must never overwrite them; `--force-standins` does.
USER_SUPPLIED = {"intro_strap_buckle.wav", "intro_session46_tape.wav", "intro_power_cut.wav",
                 "intro_door_creak.wav", "intro_cell_buzz.wav"}


def write_wav(subdir, name, samples, peak_to=0.89):
    if subdir == "intro" and name in USER_SUPPLIED and "--force-standins" not in sys.argv:
        print("skip %s (user-supplied — see tools/import_intro_user_sfx.py)" % name)
        return
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = peak_to / peak
    out_dir = os.path.join(AUDIO, subdir)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.normpath(os.path.join(out_dir, name))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767))
        w.writeframes(bytes(frames))
    print(f"wrote {path} ({len(samples)/SR:.2f}s)")


class OnePole:
    def __init__(self, cutoff_hz):
        self.a = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / SR)
        self.y = 0.0

    def tick(self, x):
        self.y += self.a * (x - self.y)
        return self.y


def make_switch_clunk():
    """Heavy old asylum wall-switch throw — lower/heavier than the Lab's breaker
    clunk, with a short electrical spark-crackle tail instead of a hum surge."""
    random.seed(4702)
    dur = 0.75
    n = int(SR * dur)
    lp = OnePole(2600.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        # Click transient.
        click = math.exp(-t * 300.0) * random.uniform(-1.0, 1.0)
        # Low mechanical thunk, lower base + slower decay than breaker_throw's
        # 130 Hz/-6.0 so it reads heavier and older, not a duplicate.
        thunk_f = 110.0 * math.exp(-t * 5.0) + 40.0
        thunk = math.sin(2 * math.pi * thunk_f * t) * math.exp(-t * 12.0)
        out[i] = lp.tick(click * 0.7 + thunk * 0.9)
    # Spark-crackle tail: a handful of short noise bursts through a tight band,
    # in the last ~0.15s.
    tail_start = dur - 0.15
    bp = OnePole(3500.0)
    t0 = tail_start
    while t0 < dur:
        burst_len = int(0.012 * SR)
        off = int(t0 * SR)
        for i in range(burst_len):
            j = off + i
            if j >= n:
                break
            decay = math.exp(-i / burst_len * 5.0)
            spark = bp.tick(random.uniform(-1.0, 1.0)) * decay
            out[j] += spark * 0.5
        t0 += random.uniform(0.02, 0.045)
    return out


def make_fluorescent_buzz_on():
    """Ceiling tubes stuttering to life — 2-3 buzzy stutters then a steady tail."""
    random.seed(9142)
    stutters = [0.05, 0.08, 0.14]
    gaps = [0.09, 0.05]
    tail = 0.5
    dur = sum(stutters) + sum(gaps) + tail
    n = int(SR * dur)
    out = [0.0] * n

    def band_noise_gen():
        lo = OnePole(180.0)
        hi = OnePole(900.0)
        while True:
            noise = random.uniform(-1.0, 1.0)
            yield hi.tick(noise) - lo.tick(noise)

    gen = band_noise_gen()
    t_cursor = 0.0
    for k, s_len in enumerate(stutters):
        off = int(t_cursor * SR)
        s_n = int(s_len * SR)
        for i in range(s_n):
            j = off + i
            if j >= n:
                break
            t = i / SR
            env = min(1.0, t / 0.005) * min(1.0, (s_len - t) / 0.01)
            buzz = next(gen) * 0.6
            hum60 = 0.25 * math.sin(2 * math.pi * 60.0 * (off + i) / SR)
            out[j] = (buzz + hum60) * env
        t_cursor += s_len
        if k < len(gaps):
            t_cursor += gaps[k]

    # Steady tail: crossfades in right after the last stutter, decays to silence.
    tail_off = int(t_cursor * SR)
    tail_n = n - tail_off
    for i in range(tail_n):
        t = i / tail_n if tail_n > 0 else 0.0
        env = min(1.0, i / (0.02 * SR)) * (1.0 - t)
        hum = math.sin(2 * math.pi * 120.0 * (tail_off + i) / SR)
        noise = 0.06 * random.uniform(-1.0, 1.0)
        j = tail_off + i
        if 0 <= j < n:
            out[j] += (hum * 0.35 + noise) * env
    return out


def make_emergency_hum():
    """Very quiet, low, loopable electrical hum — the path-glow lights' bed."""
    random.seed(55)
    dur = 2.6
    n = int(SR * dur)
    lp = OnePole(150.0)
    out = []
    f1, f2 = 58.0, 63.0  # a few Hz apart -> slow beat throb
    for i in range(n):
        t = i / SR
        hum = math.sin(2 * math.pi * f1 * t) + math.sin(2 * math.pi * f2 * t)
        noise = 0.03 * random.uniform(-1.0, 1.0)
        out.append(lp.tick(hum * 0.5 + noise) * 0.35)
    fade = int(0.05 * SR)
    for i in range(fade):
        g = i / fade
        out[i] *= g
        out[n - 1 - i] *= g
    return out


def make_gurney_creak():
    """Short metal-frame creak/groan — a bed shifting under weight, not a pipe."""
    random.seed(1804)
    dur = 0.6
    n = int(SR * dur)
    lp = OnePole(1400.0)
    out = []
    base = 220.0
    for i in range(n):
        t = i / SR
        # Quick upward bend then settle, thinner/higher register than pipe_groan.
        f = base + 60.0 * math.exp(-t * 6.0) * math.sin(2 * math.pi * 4.0 * t)
        s = math.sin(2 * math.pi * f * t)
        s += 0.4 * math.sin(2 * math.pi * f * 1.9 * t)
        s += 0.22 * random.uniform(-1.0, 1.0)
        env = min(1.0, t / 0.03) * math.exp(-t * 3.2)
        out.append(lp.tick(s) * env * 0.65)
    return out


# ================================================================ the Intake Wing (2026-09-24)

def _loopify(out, xf_s=0.25):
    """Seamless loop: the last xf_s seconds are cross-faded into the first, then dropped.
    Every .wav.import here is loop_mode=0, so the level restarts it on `finished` — a click at
    the seam would be heard every cycle (tools/make_loop.py is the same idea for real files)."""
    xf = int(xf_s * SR)
    n = len(out) - xf
    res = out[:n]
    for i in range(xf):
        g = i / xf
        res[i] = res[i] * g + out[n + i] * (1.0 - g)
    return res


def make_strap_buckle():
    """Leather strap drawn back through a steel buckle: a stretchy creak, a slap of slack
    leather, and the tongue clinking free of its hole."""
    random.seed(4711)
    dur = 0.95
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(1800.0)
    # 1) leather creak 0.00-0.45 s: stick-slip friction = noise gated by a jittery pulse train
    phase = 0.0
    for i in range(int(0.45 * SR)):
        t = i / SR
        rate = 38.0 + 30.0 * math.sin(2 * math.pi * 1.7 * t) + random.uniform(-6, 6)
        phase += rate / SR
        pulse = max(0.0, math.sin(2 * math.pi * phase)) ** 6
        env = min(1.0, t / 0.04) * (1.0 - t / 0.45)
        out[i] += lp.tick(random.uniform(-1, 1)) * (0.25 + 0.9 * pulse) * env * 0.8
    # 2) slack leather slap at 0.47 s
    lp2 = OnePole(900.0)
    off = int(0.47 * SR)
    for i in range(int(0.08 * SR)):
        t = i / SR
        out[off + i] += lp2.tick(random.uniform(-1, 1)) * math.exp(-t * 55.0) * 0.9
    # 3) buckle tongue clink at 0.60 s: two inharmonic partials, fast decay, + a rattle 0.07 s on
    for start, amp in [(0.60, 0.7), (0.67, 0.35), (0.705, 0.18)]:
        off = int(start * SR)
        for i in range(int(0.25 * SR)):
            if off + i >= n:
                break
            t = i / SR
            ring = (math.sin(2 * math.pi * 2630.0 * t) + 0.6 * math.sin(2 * math.pi * 4115.0 * t)
                    + 0.35 * math.sin(2 * math.pi * 6230.0 * t))
            out[off + i] += ring * math.exp(-t * 26.0) * amp * 0.45
    return out


def make_cell_buzz():
    """An institutional door release: a harsh 1.1 s buzzer, then the bolt shooting back."""
    random.seed(2201)
    dur = 1.7
    n = int(SR * dur)
    out = [0.0] * n
    # Buzzer: a clipped 120 Hz square-ish tone with a rattling armature (AM at 31 Hz).
    for i in range(int(1.1 * SR)):
        t = i / SR
        sq = math.tanh(6.0 * math.sin(2 * math.pi * 120.0 * t))
        sq += 0.5 * math.tanh(4.0 * math.sin(2 * math.pi * 240.0 * t + 0.4))
        am = 0.75 + 0.25 * math.sin(2 * math.pi * 31.0 * t)
        env = min(1.0, t / 0.01) * min(1.0, (1.1 - t) / 0.02)
        out[i] += (sq * am + 0.15 * random.uniform(-1, 1)) * env * 0.5
    # Bolt: a heavy clack (low thump + bright transient) at 1.15 s.
    lp = OnePole(500.0)
    off = int(1.15 * SR)
    for i in range(int(0.5 * SR)):
        if off + i >= n:
            break
        t = i / SR
        thump = math.sin(2 * math.pi * (95.0 - 40.0 * t) * t) * math.exp(-t * 18.0)
        crack = lp.tick(random.uniform(-1, 1)) * math.exp(-t * 60.0) * 2.0
        ring = math.sin(2 * math.pi * 1520.0 * t) * math.exp(-t * 30.0) * 0.25
        out[off + i] += (thump + crack + ring) * 0.9
    return out


def make_door_rattle():
    """A locked door tried: the handle rattling against a latch that will not move."""
    random.seed(8080)
    dur = 0.7
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(2400.0)
    for k, start in enumerate([0.0, 0.11, 0.2, 0.33, 0.41]):
        off = int(start * SR)
        amp = [1.0, 0.7, 0.85, 0.5, 0.4][k]
        for i in range(int(0.12 * SR)):
            if off + i >= n:
                break
            t = i / SR
            knock = lp.tick(random.uniform(-1, 1)) * math.exp(-t * 70.0)
            tone = (math.sin(2 * math.pi * 780.0 * t) + 0.5 * math.sin(2 * math.pi * 1930.0 * t)) \
                * math.exp(-t * 45.0) * 0.4
            out[off + i] += (knock + tone) * amp
    return out


def make_door_creak():
    """An old wooden ward door opening: the latch clicks, the dry hinge squeals in stick-slip
    pulses that slow as the leaf swings, and the door knocks softly at its stop. ~1.6 s."""
    random.seed(1207)
    dur = 1.6
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(3000.0)
    for i in range(int(0.06 * SR)):
        t = i / SR
        out[i] += lp.tick(random.uniform(-1, 1)) * math.exp(-t * 90.0) * 1.2
    ph = 0.0
    slip = 0.0
    for i in range(int(0.08 * SR), int(1.35 * SR)):
        t = i / SR - 0.08
        f = 520.0 + 180.0 * math.sin(2 * math.pi * 0.8 * t) - 120.0 * t
        ph += f / SR
        slip += (26.0 - 12.0 * t) / SR
        gate = max(0.0, math.sin(2 * math.pi * slip)) ** 3
        env = min(1.0, t / 0.05) * max(0.0, 1.0 - t / 1.27)
        tone = math.sin(2 * math.pi * ph) + 0.5 * math.sin(4.02 * math.pi * ph) + 0.25 * math.sin(6.1 * math.pi * ph)
        out[i] += (tone * 0.5 + random.uniform(-1, 1) * 0.15) * (0.3 + 0.7 * gate) * env * 0.7
    off = int(1.38 * SR)
    for i in range(int(0.2 * SR)):
        if off + i >= n:
            break
        t = i / SR
        out[off + i] += math.sin(2 * math.pi * 110.0 * t) * math.exp(-t * 25.0) * 0.5
    return out


def make_tap_rust():
    """The first turn of a tap nobody has used: the pipe knocks, coughs air, sputters and
    gurgles before it runs. ~3.2 s; the level starts the clean loop as this ends."""
    random.seed(3303)
    dur = 3.2
    n = int(SR * dur)
    out = [0.0] * n
    # Pipe knocks: low, resonant, irregular.
    for start in [0.05, 0.32, 0.5, 0.95]:
        off = int(start * SR)
        for i in range(int(0.3 * SR)):
            if off + i >= n:
                break
            t = i / SR
            out[off + i] += math.sin(2 * math.pi * 72.0 * t) * math.exp(-t * 14.0) * 0.8
    # Sputter: bursts of air-and-water noise, band-passed, with gaps, thickening into a gurgle.
    lo = OnePole(300.0)
    hi = OnePole(2600.0)
    burst = 0.0
    for i in range(int(0.9 * SR), n):
        t = i / SR
        if random.random() < 0.0009 + 0.0006 * (t - 0.9):
            burst = 1.0
        burst *= 0.9994
        x = random.uniform(-1, 1)
        band = hi.tick(x) - lo.tick(x)
        # gurgle: bubbles = short chirps
        bub = 0.0
        if random.random() < 0.0025:
            bub = 1.0
        g = (t - 0.9) / (dur - 0.9)
        out[i] += band * (0.25 + 0.75 * burst) * min(1.0, g * 3.0) * 0.8
        out[i] += bub * random.uniform(0.3, 0.8)
    # soften the bubble clicks
    sm = OnePole(3500.0)
    return [sm.tick(v) for v in out]


def make_tap_water():
    """A thin steady stream into a steel basin (LOOP, 3.0 s): band noise + a faint splash
    shimmer. Mono, quiet — the basin, not a shower."""
    random.seed(6060)
    dur = 3.25
    n = int(SR * dur)
    lo = OnePole(420.0)
    hi = OnePole(5200.0)
    lo2 = OnePole(2200.0)
    out = []
    for i in range(n):
        t = i / SR
        x = random.uniform(-1, 1)
        band = hi.tick(x) - lo.tick(x)
        drops = lo2.tick(random.uniform(-1, 1)) * (0.5 + 0.5 * math.sin(2 * math.pi * 5.3 * t)
                                                     * math.sin(2 * math.pi * 0.7 * t))
        out.append(band * 0.7 + drops * 0.25)
    return _loopify(out, 0.25)


def make_bulb_hum():
    """A bare incandescent bulb on bad mains: 100 Hz filament buzz with its harmonics and a
    very slow unsteady wobble (LOOP, 4.0 s). Meant to be played quietly next to each bulb."""
    random.seed(1010)
    dur = 4.3
    n = int(SR * dur)
    lp = OnePole(1600.0)
    out = []
    for i in range(n):
        t = i / SR
        wob = 1.0 + 0.12 * math.sin(2 * math.pi * 0.37 * t) + 0.05 * math.sin(2 * math.pi * 1.9 * t)
        s = (math.sin(2 * math.pi * 100.0 * t) + 0.45 * math.sin(2 * math.pi * 200.0 * t)
             + 0.2 * math.sin(2 * math.pi * 300.0 * t) + 0.12 * math.tanh(3 * math.sin(2 * math.pi * 50.0 * t)))
        out.append(lp.tick(s * wob + 0.04 * random.uniform(-1, 1)))
    return _loopify(out, 0.3)


def make_power_cut():
    """The wing losing power: a heavy relay slam, every hum in the building dropping at once
    (a falling whine) and a last tick of cooling metal. ~2.4 s."""
    random.seed(5150)
    dur = 2.4
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(700.0)
    for i in range(int(0.35 * SR)):
        t = i / SR
        out[i] += (math.sin(2 * math.pi * (70.0 - 30.0 * t) * t) * math.exp(-t * 10.0)
                   + lp.tick(random.uniform(-1, 1)) * math.exp(-t * 40.0) * 2.2) * 0.9
    ph = 0.0
    for i in range(int(0.02 * SR), int(2.0 * SR)):
        t = i / SR
        f = 120.0 * math.exp(-(t - 0.02) * 1.6) + 18.0
        ph += f / SR
        env = math.exp(-(t - 0.02) * 1.3)
        out[i] += (math.sin(2 * math.pi * ph) + 0.4 * math.sin(4 * math.pi * ph)) * env * 0.45
    off = int(2.15 * SR)
    for i in range(int(0.2 * SR)):
        if off + i >= n:
            break
        t = i / SR
        out[off + i] += math.sin(2 * math.pi * 2900.0 * t) * math.exp(-t * 60.0) * 0.25
    return out


def make_session46_tape():
    """~40 s of a reel labelled SESSION 46, played back. SOUND ONLY and WORDLESS — the voice in
    this game is rationed to five lines (spec/levels/00-intro.md), so the 'interview' is a murmur
    you cannot make out: formant buzz shaped into syllables, low-passed through a wall of hiss.
      0-2 s    deck clunk, capstan motor spinning up, leader tape hiss
      2-14 s   two murmuring voices, turn about — a calm one and a slower one
      14-20 s  the slower voice falters; breathing, close to the mic
      20-23 s  a chair scrapes; a thump
      23-35 s  nothing but hiss and breathing, getting faster
      35-38 s  one sharp intake of breath — and the tape runs out: the tail flaps
    """
    random.seed(4646)
    dur = 40.0
    n = int(SR * dur)
    out = [0.0] * n
    # Hiss bed + motor whine throughout (after the start clunk).
    hs = OnePole(6000.0)
    hl = OnePole(900.0)
    for i in range(n):
        t = i / SR
        x = random.uniform(-1, 1)
        hiss = (hs.tick(x) - hl.tick(x)) * 0.12
        spin = min(1.0, t / 1.2)
        motor = math.sin(2 * math.pi * (47.0 * spin + 3.0) * t) * 0.05 * spin
        wow = 1.0 + 0.04 * math.sin(2 * math.pi * 0.55 * t)
        out[i] = (hiss + motor) * wow * (1.0 if t < 38.2 else 0.0)
    # Start clunk.
    lp = OnePole(600.0)
    for i in range(int(0.3 * SR)):
        t = i / SR
        out[i] += (math.sin(2 * math.pi * 85.0 * t) * math.exp(-t * 16.0)
                   + lp.tick(random.uniform(-1, 1)) * math.exp(-t * 50.0) * 1.5) * 0.7

    def murmur(t0, t1, f0, formants, amp, rate):
        """Wordless speech: a glottal pulse train through two resonators, gated into syllables."""
        r1 = OnePole(formants[0])
        r2 = OnePole(formants[1])
        ph = 0.0
        syl = 0.0
        on = True
        next_flip = t0
        wall = OnePole(700.0)          # heard through a wall / a cheap mic
        for i in range(int(t0 * SR), int(t1 * SR)):
            t = i / SR
            if t >= next_flip:
                on = not on
                next_flip = t + (random.uniform(0.09, 0.26) / rate if on else random.uniform(0.04, 0.5))
            syl += ((1.0 if on else 0.0) - syl) * 0.004
            f = f0 * (1.0 + 0.08 * math.sin(2 * math.pi * 0.9 * t) + 0.03 * random.uniform(-1, 1))
            ph += f / SR
            pulse = (ph % 1.0) ** 8 * 2.0 - 0.1
            v = r1.tick(pulse) * 0.8 + (r2.tick(pulse) - r1.y) * 0.5
            out[i] += wall.tick(v) * syl * amp

    # Turn-taking: interviewer (calmer, lower) and subject (slower, higher, breaking up).
    turns = [(2.2, 5.6, 105.0, (650, 1300), 1.0, 1.0), (6.0, 9.0, 165.0, (780, 1700), 0.8, 0.8),
             (9.4, 11.2, 105.0, (650, 1300), 1.0, 1.0), (11.6, 14.2, 170.0, (760, 1650), 0.7, 0.65),
             (14.8, 15.6, 175.0, (760, 1650), 0.5, 0.5)]
    for (a, b, f0, fm, amp, rate) in turns:
        murmur(a, b, f0, fm, amp * 0.9, rate)

    def breath(t0, length, amp, bright):
        b1 = OnePole(bright)
        b0 = OnePole(250.0)
        for i in range(int(length * SR)):
            j = int(t0 * SR) + i
            if j >= n:
                break
            u = i / (length * SR)
            env = math.sin(math.pi * u) ** 1.5
            x = random.uniform(-1, 1)
            out[j] += (b1.tick(x) - b0.tick(x)) * env * amp

    t = 15.8
    period = 2.4
    while t < 35.0:
        breath(t, period * 0.45, 0.55, 1800.0)          # in
        breath(t + period * 0.5, period * 0.4, 0.4, 1300.0)  # out
        t += period
        period = max(0.9, period * 0.93)                # quicker and quicker
    # The chair at ~20.5 s: a scrape (rising friction squeal) and a thump.
    ph = 0.0
    for i in range(int(20.4 * SR), int(21.3 * SR)):
        tt = i / SR - 20.4
        f = 210.0 + 260.0 * tt
        ph += f / SR
        out[i] += (math.sin(2 * math.pi * ph) * 0.4 + random.uniform(-1, 1) * 0.3) * math.sin(math.pi * tt / 0.9) * 0.6
    for i in range(int(0.4 * SR)):
        tt = i / SR
        out[int(21.6 * SR) + i] += math.sin(2 * math.pi * 60.0 * tt) * math.exp(-tt * 12.0) * 0.9
    # The sharp intake at 35.3 s, then the tape runs out at 38.2: the tail flapping on the reel.
    breath(35.3, 0.5, 1.1, 3200.0)
    for k in range(40):
        tt0 = 38.25 + k * (0.045 + 0.0012 * k)
        if tt0 > dur - 0.05:
            break
        amp = 0.6 * math.exp(-k * 0.06)
        off = int(tt0 * SR)
        for i in range(int(0.02 * SR)):
            tt = i / SR
            out[off + i] += random.uniform(-1, 1) * math.exp(-tt * 180.0) * amp
    return out


def make_projector_run():
    """A 1960s slide projector running (LOOP, 4 s): the cooling fan's broadband whirr with its
    blade-pass tone, the lamp transformer's 100 Hz hum."""
    random.seed(7070)
    dur = 4.3
    n = int(SR * dur)
    lo = OnePole(300.0)
    hi = OnePole(3000.0)
    out = []
    for i in range(n):
        t = i / SR
        x = random.uniform(-1, 1)
        fan = (hi.tick(x) - lo.tick(x)) * (0.8 + 0.2 * math.sin(2 * math.pi * 47.0 * t))
        blade = 0.25 * math.sin(2 * math.pi * 188.0 * t)
        hum = 0.3 * math.sin(2 * math.pi * 100.0 * t) + 0.12 * math.sin(2 * math.pi * 200.0 * t)
        out.append(fan * 0.6 + blade + hum)
    return _loopify(out, 0.3)


def make_projector_slide():
    """A carousel advancing: the gate clacks open, the slide drops in, the gate clicks shut."""
    random.seed(7171)
    dur = 0.55
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(2500.0)
    for start, amp, f in [(0.0, 1.0, 1400.0), (0.16, 0.5, 900.0), (0.3, 0.8, 2100.0)]:
        off = int(start * SR)
        for i in range(int(0.12 * SR)):
            if off + i >= n:
                break
            t = i / SR
            out[off + i] += (lp.tick(random.uniform(-1, 1)) * math.exp(-t * 80.0) * 1.3
                             + math.sin(2 * math.pi * f * t) * math.exp(-t * 55.0) * 0.4) * amp
    return out


def make_airlock_buzzer():
    """The airlock's release: a two-tone institutional buzz, a pause, and the bolts letting go."""
    random.seed(7272)
    dur = 2.2
    n = int(SR * dur)
    out = [0.0] * n
    for start, f0, ln in [(0.0, 150.0, 0.55), (0.7, 118.0, 0.8)]:
        off = int(start * SR)
        for i in range(int(ln * SR)):
            t = i / SR
            sq = math.tanh(5.0 * math.sin(2 * math.pi * f0 * t)) + 0.4 * math.tanh(4.0 * math.sin(2 * math.pi * f0 * 2.01 * t))
            env = min(1.0, t / 0.01) * min(1.0, (ln - t) / 0.03)
            out[off + i] += sq * env * 0.45
    lp = OnePole(450.0)
    off = int(1.65 * SR)
    for i in range(int(0.5 * SR)):
        if off + i >= n:
            break
        t = i / SR
        out[off + i] += (math.sin(2 * math.pi * (80.0 - 30.0 * t) * t) * math.exp(-t * 14.0)
                         + lp.tick(random.uniform(-1, 1)) * math.exp(-t * 45.0) * 1.8) * 0.8
    return out


def make_chair_sit():
    """Sitting down hard in an old wooden chair: joints creak under the weight, a loose leather
    wrist strap slaps the arm. ~1 s. (First hand playtest, 2026-09-24 — the chair on the mark.)"""
    random.seed(7373)
    dur = 1.0
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(900.0)
    # the weight landing: a dull wooden thump
    for i in range(int(0.25 * SR)):
        t = i / SR
        out[i] += (math.sin(2 * math.pi * (110.0 - 40.0 * t) * t) * math.exp(-t * 18.0)
                   + lp.tick(random.uniform(-1, 1)) * math.exp(-t * 35.0)) * 0.8
    # the joints: stick-slip creak with two wood resonances
    ph = 0.0
    slip = 0.0
    for i in range(int(0.08 * SR), int(0.75 * SR)):
        t = i / SR - 0.08
        f = 340.0 - 90.0 * t
        ph += f / SR
        slip += (22.0 - 10.0 * t) / SR
        gate = max(0.0, math.sin(2 * math.pi * slip)) ** 4
        env = min(1.0, t / 0.04) * max(0.0, 1.0 - t / 0.67)
        out[i] += (math.sin(2 * math.pi * ph) + 0.6 * math.sin(2 * math.pi * ph * 2.7)) * gate * env * 0.35
    # the strap slap at 0.62 s
    lp2 = OnePole(1600.0)
    off = int(0.62 * SR)
    for i in range(int(0.1 * SR)):
        t = i / SR
        out[off + i] += lp2.tick(random.uniform(-1, 1)) * math.exp(-t * 60.0) * 0.9
    return out


def make_hatch_slam():
    """A body hitting the airlock hatch's steel bars (fourth hand playtest, 2026-09-25): a dull,
    heavy thud, the bars ringing at their own pitches, and a rattle as they shake in the frame."""
    random.seed(4711)
    dur = 1.3
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(380.0)
    for i in range(int(0.4 * SR)):
        t = i / SR
        out[i] += (math.sin(2 * math.pi * (70.0 - 25.0 * t) * t) * math.exp(-t * 11.0)
                   + lp.tick(random.uniform(-1, 1)) * math.exp(-t * 30.0) * 2.2) * 0.9
    # five bars, slightly detuned, each ringing and decaying at its own rate
    for k, f in enumerate([612.0, 689.0, 741.0, 822.0, 947.0]):
        ph = random.uniform(0, 6.28)
        for i in range(n):
            t = i / SR
            out[i] += (math.sin(2 * math.pi * f * t + ph) + 0.35 * math.sin(2 * math.pi * f * 2.76 * t)) \
                * math.exp(-t * (4.5 + k * 0.7)) * 0.11
    # the rattle: bars knocking in their sockets, thinning out
    lp2 = OnePole(2600.0)
    for start in [0.05, 0.12, 0.17, 0.26, 0.31, 0.43, 0.58]:
        off = int(start * SR)
        amp = 0.7 * math.exp(-start * 2.5)
        for i in range(int(0.05 * SR)):
            t = i / SR
            out[off + i] += lp2.tick(random.uniform(-1, 1)) * math.exp(-t * 90.0) * amp
    return out


def make_hatch_shutter():
    """The hatch's steel shutter dropped: a short scrape down its rails, then a flat, heavy BANG
    with a sheet-metal ring, and the latch dropping into place."""
    random.seed(4712)
    dur = 1.6
    n = int(SR * dur)
    out = [0.0] * n
    lp = OnePole(1800.0)
    for i in range(int(0.16 * SR)):
        t = i / SR
        out[i] += lp.tick(random.uniform(-1, 1)) * (0.25 + t * 3.0) * 0.5 \
            * (0.6 + 0.4 * math.sin(2 * math.pi * 55.0 * t))
    off = int(0.16 * SR)
    lp2 = OnePole(700.0)
    for i in range(n - off):
        t = i / SR
        bang = math.sin(2 * math.pi * (88.0 - 30.0 * t) * t) * math.exp(-t * 9.0) * 1.1
        crack = lp2.tick(random.uniform(-1, 1)) * math.exp(-t * 40.0) * 2.4
        ring = (math.sin(2 * math.pi * 431.0 * t) + 0.6 * math.sin(2 * math.pi * 1187.0 * t)
                + 0.3 * math.sin(2 * math.pi * 2210.0 * t)) * math.exp(-t * 5.5) * 0.16
        out[off + i] += bang + crack + ring
    off2 = int(0.55 * SR)
    lp3 = OnePole(3000.0)
    for i in range(int(0.08 * SR)):
        t = i / SR
        out[off2 + i] += (lp3.tick(random.uniform(-1, 1)) * math.exp(-t * 80.0)
                          + math.sin(2 * math.pi * 1650.0 * t) * math.exp(-t * 60.0) * 0.3) * 0.45
    return out


def main():
    import sys
    if "--all" in sys.argv:
        write_wav("intro", "switch_clunk.wav", make_switch_clunk())
        write_wav("intro", "fluorescent_buzz_on.wav", make_fluorescent_buzz_on())
        write_wav("intro", "emergency_hum.wav", make_emergency_hum())
        write_wav("intro", "gurney_creak.wav", make_gurney_creak())
    write_wav("intro", "intro_strap_buckle.wav", make_strap_buckle())
    write_wav("intro", "intro_cell_buzz.wav", make_cell_buzz())
    write_wav("intro", "intro_door_rattle.wav", make_door_rattle())
    write_wav("intro", "intro_door_creak.wav", make_door_creak())
    write_wav("intro", "intro_tap_rust.wav", make_tap_rust())
    write_wav("intro", "intro_tap_water.wav", make_tap_water(), 0.5)
    write_wav("intro", "intro_bulb_hum.wav", make_bulb_hum(), 0.4)
    write_wav("intro", "intro_power_cut.wav", make_power_cut())
    write_wav("intro", "intro_session46_tape.wav", make_session46_tape(), 0.7)
    write_wav("intro", "intro_projector_run.wav", make_projector_run(), 0.45)
    write_wav("intro", "intro_projector_slide.wav", make_projector_slide())
    write_wav("intro", "intro_airlock_buzzer.wav", make_airlock_buzzer())
    write_wav("intro", "intro_chair_sit.wav", make_chair_sit())
    write_wav("intro", "intro_hatch_slam.wav", make_hatch_slam())
    write_wav("intro", "intro_hatch_shutter.wav", make_hatch_shutter())


if __name__ == "__main__":
    main()
