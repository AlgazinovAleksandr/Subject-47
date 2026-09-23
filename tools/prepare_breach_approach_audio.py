#!/usr/bin/env python3
"""Prepare the user's thirteen approach recordings for Level 6's approach (2026-09-23).

The sibling of `tools/prepare_breach_audio.py`, and it follows the same rule: decode to FLOAT,
shape and normalise there, and only then convert to 16-bit PCM. Four of these originals decode
ABOVE full scale (loud_screamer +6.4, loud_scream +4.4, metal_crash +3.0, door_part1 +2.9 dBFS
measured through the same mono/44.1 kHz decode used here), so converting straight to int16
would bake clipping into the game copies.

Sources are the UNCHANGED originals in `assets_src/audio/level_6_breach/approach/`, copied there
byte-for-byte from the user's `game/assets/audio/level_6_breach/new_sounds/`. Nothing here
writes into either folder. Outputs go to `game/assets/audio/level_6_breach/` with an
`approach_` prefix, because `GameState.load_audio()` resolves by BASE NAME across every audio
subdir and names like `dust` or `motor` would be one careless file away from a silent collision.

Every output is mono (the approach plays them positionally) except the ventilation bed, which
keeps its stereo image and gets a crossfaded loop seam like the chase background. Each is
peak-normalised to -1.5 dBFS; the runtime sets loudness from the RMS this prints.

Run from the repo root (stdlib + ffmpeg):
    python3 tools/prepare_breach_approach_audio.py
then  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import array
import math
from pathlib import Path
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets_src/audio/level_6_breach/approach'
OUTPUT = ROOT / 'game/assets/audio/level_6_breach'
RATE = 44100
PEAK_DB = -1.5

# (output base name, source file, start s, end s, extra ffmpeg filter, fade-out s)
# Windows were chosen from measured envelopes (see the 2026-09-23 spec entry).
CUTS = [
    # The technician: hammering and begging, trimmed to the part the sequence uses.
    ('approach_victim_hammer', 'door_part1_sound.wav', 0.0, 5.2, '', 0.6),
    # Object 12's roar BEHIND A STEEL DOOR: baked low-pass, so the muffling is deterministic.
    ('approach_victim_roar', 'creature_sound.wav', 0.0, 4.4, 'lowpass=f=650,lowpass=f=650', 0.6),
    # His scream: the loud body of the recording, not its 7.5 s decay.
    ('approach_victim_scream', 'door_part_2_scream.mp3', 0.25, 3.85, '', 0.5),
    # The scream the building answers.
    ('approach_building_scream', 'loud_scream.wav', 0.0, 2.86, '', 0.25),
    ('approach_duct_crawl', 'creature_crawl.wav', 0.0, 4.34, '', 0.3),
    # The door tell's crash starts at its own onset (0.513 s) so code can time it.
    ('approach_door_crash', 'metal_crash.wav', 0.48, 4.47, '', 0.4),
    ('approach_lamp_on', 'lamp_on.wav', 0.04, 1.30, '', 0.2),
    # The dying lamp: from its first crackle (1.070 s) through the tinkle.
    ('approach_lamp_die', 'lamp_off_break.flac', 1.04, 3.60, '', 0.5),
    ('approach_shutter_motor', 'motor.wav', 0.0, 3.76, '', 0.12),
    ('approach_dust', 'dust.wav', 0.0, 5.5, '', 0.3),
    # The hand in the duct. The user chose a scream here.
    ('approach_hand_scream', 'loud_screamer.mp3', 0.0, 4.6, '', 0.8),
]

# Three heavy knocks cut from the 20.6 s flurry at clean attacks (silence before each),
# each held 0.30 s with a steep tail, placed at irregular gaps so they read as a body.
KNOCK_SOURCE = 'monster_knock.wav'
KNOCK_ONSETS = [3.712, 7.118, 10.976]
KNOCK_AT = [0.0, 0.66, 1.52]
KNOCK_LEN = 0.30


def decode(name, start=0.0, end=None, channels=1, extra=''):
    cmd = ['ffmpeg', '-v', 'error', '-i', str(SOURCE / name), '-ss', str(start)]
    if end is not None:
        cmd += ['-t', str(end - start)]
    if extra:
        cmd += ['-af', extra]
    cmd += ['-ar', str(RATE), '-ac', str(channels), '-f', 'f32le', '-']
    return array.array('f', subprocess.check_output(cmd))


def fade(samples, channels, fade_in, fade_out):
    frames = len(samples) // channels
    n_in = min(frames, int(fade_in * RATE))
    n_out = min(frames, int(fade_out * RATE))
    for i in range(n_in):
        for c in range(channels):
            samples[i * channels + c] *= i / max(1, n_in)
    for i in range(n_out):
        g = i / max(1, n_out)
        for c in range(channels):
            samples[(frames - 1 - i) * channels + c] *= g
    return samples


def write(name, samples, channels):
    peak = max(map(abs, samples)) or 1.0
    gain = 10 ** (PEAK_DB / 20) / peak
    pcm = array.array('h', (round(max(-1.0, min(1.0, x * gain)) * 32767) for x in samples))
    dest = OUTPUT / f'{name}.wav'
    with wave.open(str(dest), 'wb') as out:
        out.setparams((channels, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(pcm.tobytes())
    rms = math.sqrt(sum((x * gain) ** 2 for x in samples) / len(samples))
    # Loudest 300 ms, the same window tools/sfx_loudness.py reports.
    win = int(0.3 * RATE) * channels
    loud = 0.0
    for i in range(0, max(1, len(samples) - win), max(1, win // 3)):
        seg = samples[i:i + win]
        loud = max(loud, math.sqrt(sum((x * gain) ** 2 for x in seg) / len(seg)))
    print(f'{dest.name:34s} {len(samples) / channels / RATE:5.2f}s  src peak '
          f'{20 * math.log10(peak):+5.2f} dBFS -> {PEAK_DB:.1f}  RMS {20 * math.log10(rms):6.2f}  '
          f'loud300 {20 * math.log10(max(loud, 1e-9)):6.2f} dBFS')


def build_knocks():
    total = int((KNOCK_AT[-1] + KNOCK_LEN + 0.05) * RATE)
    out = array.array('f', [0.0] * total)
    for onset, at in zip(KNOCK_ONSETS, KNOCK_AT):
        # A 3 kHz low-pass puts the knock inside a steel duct rather than on the listener.
        hit = decode(KNOCK_SOURCE, onset - 0.008, onset + KNOCK_LEN, 1, 'lowpass=f=3000')
        n = len(hit)
        tail = int(0.18 * RATE)
        for i in range(n):
            g = 1.0
            if i < 80:
                g = i / 80
            elif i > n - tail:
                g = ((n - i) / tail) ** 2
            j = int(at * RATE) + i
            if j < total:
                out[j] += hit[i] * g
    return out


def build_vent_bed():
    # Stereo, full length, with a 0.6 s crossfade at the seam so `finished -> play` loops clean.
    samples = decode('ventilation.wav', 0.0, None, 2)
    channels = 2
    frames = len(samples) // channels
    count = int(0.6 * RATE)
    body = samples[count * channels:(frames - count) * channels]
    for i in range(count):
        mix = i / (count - 1)
        for c in range(channels):
            body.append(samples[(frames - count + i) * channels + c] * (1 - mix)
                        + samples[i * channels + c] * mix)
    return body


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, src, start, end, extra, fade_out in CUTS:
        samples = decode(src, start, end, 1, extra)
        write(name, fade(samples, 1, 0.006, fade_out), 1)
    write('approach_duct_knocks', build_knocks(), 1)
    write('approach_vent_bed', build_vent_bed(), 2)


if __name__ == '__main__':
    main()
