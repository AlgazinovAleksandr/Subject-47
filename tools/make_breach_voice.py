#!/usr/bin/env python3
"""Three reproducible, wordless Object 12 voices. Stdlib glottal/formant synthesis.

Historical prototypes only; never overwrites the user's shipped recordings.
Voices use separate pitch/envelope/formant profiles, not pitched copies of a death sting.
"""
import math
from pathlib import Path
import random
import struct
import wave

from sfx_loudness import measure

SR = 44100
OUT = Path(__file__).resolve().parents[1] / 'assets_src/audio/level_6_breach/procedural_archive'


def voice(kind):
    duration, seed, formants = {
        'chase': (2.45, 1201, [(610, 100), (1230, 160), (2450, 280)]),
        'batter': (1.85, 1202, [(420, 110), (970, 190), (1850, 320)]),
        'search': (3.25, 1203, [(360, 90), (790, 130), (1620, 230)]),
    }[kind]
    rng = random.Random(seed)
    filters = []
    for centre, width in formants:
        radius = math.exp(-math.pi * width / SR)
        filters.append([2 * radius * math.cos(math.tau * centre / SR),
                        radius * radius, 1 - radius, 0.0, 0.0])
    samples, phase, subphase, breath = [], 0.0, 0.0, 0.0
    for i in range(int(SR * duration)):
        t, x = i / SR, i / (SR * duration)
        if kind == 'chase':
            pitch = 83 + 100 * math.sin(math.pi * x * 0.8) + 9 * math.sin(31 * t)
            envelope = min(1, t / .045) * min(1, (duration - t) / .5)
        elif kind == 'batter':
            pulse = (t % .60) / .60
            pitch = 64 + 65 * math.exp(-pulse * 4) + 7 * math.sin(47 * t)
            envelope = (.25 + .75 * math.exp(-pulse * 3)) * min(1, t / .025) * min(1, (duration - t) / .16)
        else:
            pitch = 66 + 43 * math.sin(math.pi * x) + 6 * math.sin(19 * t)
            envelope = math.sin(math.pi * x) ** .8
        phase += pitch * (1 + rng.uniform(-.022, .022)) / SR
        subphase += pitch * .493 / SR
        p = phase % 1
        # Abrupt glottal opening + slow closing, with a second, inharmonic throat voice.
        source = (2 * p - 1) * .7 + rng.uniform(-1, 1) * .25
        vocal = 0.0
        for j, f in enumerate(filters):
            y = f[2] * source + f[0] * f[3] - f[1] * f[4]
            f[4], f[3] = f[3], y
            vocal += y * (1.0, .7, .35)[j]
        white = rng.uniform(-1, 1)
        breath += .1 * (white - breath)
        rough = .7 + .3 * math.sin(math.tau * (27 + 4 * math.sin(t * 5)) * t)
        throat = .20 * math.sin(math.tau * subphase) * rough
        samples.append(math.tanh((vocal * .9 + throat + breath * .20) * 1.3) * envelope)
    peak = max(map(abs, samples))
    samples = [s * .72 / peak for s in samples]
    return samples


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in ('chase', 'batter', 'search'):
        samples = voice(kind)
        path = OUT / f'breach_voice_{kind}.wav'
        with wave.open(str(path), 'wb') as output:
            output.setparams((1, 2, SR, len(samples), 'NONE', 'not compressed'))
            output.writeframes(b''.join(struct.pack('<h', round(s * 32767)) for s in samples))
        peak, rms = measure(samples, SR)
        print(f'{path.name}: {len(samples) / SR:.2f}s, peak {peak:.2f} dBFS, loudest 300ms {rms:.2f} dBFS')


if __name__ == '__main__':
    main()
