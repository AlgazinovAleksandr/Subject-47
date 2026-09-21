#!/usr/bin/env python3
"""Prepare the user's four Object 12 recordings; originals are never overwritten.

Requires ffmpeg. Decode to float before peak normalization: the supplied chase MP3
decodes above full scale, so conversion directly to int16 would bake in clipping.
"""
import array
import math
from pathlib import Path
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets_src/audio/level_6_breach'
OUTPUT = ROOT / 'game/assets/audio/level_6_breach'
RATE = 44100
RECORDINGS = [
    ('breach_voice_batter.mp3', .14, 6.85, 1),
    ('breach_voice_scream_chase.mp3', 0, 4.35, 1),
    ('breach_voice_search.wav', 0, 4.8, 1),
    ('breach_voice_chase_background.mp3', 0, 14.65, 2),
]


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, start, end, channels in RECORDINGS:
        raw = subprocess.check_output([
            'ffmpeg', '-v', 'error', '-i', str(SOURCE / name),
            '-ss', str(start), '-t', str(end - start), '-ar', str(RATE),
            '-ac', str(channels), '-f', 'f32le', '-',
        ])
        samples = array.array('f', raw)
        frames = len(samples) // channels
        if 'background' in name:
            count = int(.35 * RATE)
            body = samples[count * channels:(frames - count) * channels]
            for i in range(count):
                mix = i / (count - 1)
                for c in range(channels):
                    body.append(samples[(frames - count + i) * channels + c] * (1 - mix)
                                + samples[i * channels + c] * mix)
            samples = body
        else:
            count = int(.012 * RATE)
            for i in range(count):
                for c in range(channels):
                    samples[i * channels + c] *= i / count
                    samples[-(i + 1) * channels + c] *= i / count
        # Normalize BEFORE converting to PCM. Keep the source's dynamics and pitch.
        gain = 10 ** (-1.5 / 20) / max(map(abs, samples))
        pcm = array.array('h', (round(x * gain * 32767) for x in samples))
        dest = OUTPUT / (Path(name).stem + '.wav')
        with wave.open(str(dest), 'wb') as output:
            output.setparams((channels, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(pcm.tobytes())
        rms = math.sqrt(sum((x * gain) ** 2 for x in samples) / len(samples))
        print(f'{dest.name}: {len(samples) / channels / RATE:.2f}s, '
              f'peak -1.50 dBFS, RMS {20 * math.log10(rms):.2f} dBFS')


if __name__ == '__main__':
    main()
