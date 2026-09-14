#!/usr/bin/env python3
"""Re-master ONE sourced .wav toward the project's loud target, in place (H3, 2026-09-13).

    python3 tools/loudify_file.py game/assets/audio/level_2_house/childe_scream.wav [target_dbfs]

Wraps `sfx_loudness.loudify` for a mono OR stereo 16-bit file: each channel is driven with the
SAME searched drive (taken from the louder channel) so the image does not shift. The peak is
preserved, only the loudest-300 ms rises. Back the original up under assets_src/ first — this
overwrites. Pure stdlib.
"""

import struct
import sys
import wave
import os

sys.path.insert(0, os.path.dirname(__file__))
from sfx_loudness import measure, loudify, compress, saturate, LOUD_TARGET_DB  # noqa: E402


def main():
    path = sys.argv[1]
    target = float(sys.argv[2]) if len(sys.argv) > 2 else LOUD_TARGET_DB
    with wave.open(path, "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    assert sw == 2, "16-bit only"
    d = struct.unpack("<%dh" % (n * ch), raw)
    chans = [[d[i * ch + c] / 32768.0 for i in range(n)] for c in range(ch)]
    for c, s in enumerate(chans):
        print("in  ch%d peak/loud300 = %.2f / %.2f dBFS" % ((c,) + measure(s, sr)))
    outs = [loudify(s, sr, target_db=target)[0] for s in chans]
    for c, s in enumerate(outs):
        print("out ch%d peak/loud300 = %.2f / %.2f dBFS" % ((c,) + measure(s, sr)))
    inter = []
    for i in range(n):
        for c in range(ch):
            inter.append(struct.pack("<h", int(max(-1.0, min(1.0, outs[c][i])) * 32767)))
    with wave.open(path, "wb") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(b"".join(inter))
    print("rewrote", path)


if __name__ == "__main__":
    main()
