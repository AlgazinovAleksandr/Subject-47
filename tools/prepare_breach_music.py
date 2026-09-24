#!/usr/bin/env python3
"""Prepare the user's Breach walk-in music; the original is never modified.

Source: assets_src/audio/level_6_breach/approach/breach_corridor_music.wav — the user's master,
72 s, 6-channel (5.1), 96 kHz, 24-bit, 124 MB, kept local-only (see .gitignore). Godot imports
only mono or stereo, so this makes the game copy:

  1. ffmpeg decodes to 48 kHz stereo float (its standard 5.1 -> stereo downmix, centre and LFE
     folded in) — float, so a hot master cannot clip before normalisation.
  2. The loop seam is crossfaded: the last SEAM seconds are blended into the first SEAM seconds and
     the tail is dropped, so the end flows back into the start with no click and no gap.
  3. Peak-normalised to -1.5 dBFS, like tools/prepare_breach_audio.py.
  4. Encoded to Ogg Vorbis (q5) at game/assets/audio/level_6_breach/approach_corridor_music.ogg.
     The level sets `loop = true` on the stream itself.

Requires ffmpeg. Deterministic: same input, same output.
"""
import array
import math
from pathlib import Path
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets_src/audio/level_6_breach/approach/breach_corridor_music.wav'
OUTPUT = ROOT / 'game/assets/audio/level_6_breach/approach_corridor_music.ogg'
RATE = 48000
SEAM = 1.5          # seconds of crossfade at the loop point
PEAK_DB = -1.5


def main():
    raw = subprocess.check_output([
        'ffmpeg', '-v', 'error', '-i', str(SOURCE), '-ar', str(RATE), '-ac', '2',
        '-f', 'f32le', '-'])
    s = array.array('f', raw)
    frames = len(s) // 2
    n = int(SEAM * RATE)
    # Equal-power crossfade of the tail into the head; the tail is then cut off.
    for i in range(n):
        t = i / (n - 1)
        a = math.cos(t * math.pi / 2.0)      # head fades IN from the tail's level
        b = math.sin(t * math.pi / 2.0)
        for c in range(2):
            head = s[i * 2 + c]
            tail = s[(frames - n + i) * 2 + c]
            s[i * 2 + c] = tail * a + head * b
    body = s[:(frames - n) * 2]
    peak = max(abs(x) for x in body) or 1.0
    gain = (10 ** (PEAK_DB / 20.0)) / peak
    pcm = array.array('h', (max(-32767, min(32767, int(round(x * gain * 32767.0)))) for x in body))
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / 'music.wav'
        with wave.open(str(wav_path), 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        subprocess.check_call(['ffmpeg', '-v', 'error', '-y', '-i', str(wav_path),
                               '-c:a', 'libvorbis', '-q:a', '5', str(OUTPUT)])
    secs = (frames - n) / RATE
    print('%s: %.2f s loop, source peak %.2f dBFS -> %.1f dBFS, seam %.1f s'
          % (OUTPUT.relative_to(ROOT), secs, 20 * math.log10(peak), PEAK_DB, SEAM))


if __name__ == '__main__':
    main()
