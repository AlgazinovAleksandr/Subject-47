#!/usr/bin/env python3
"""`corridor_plea` — the whispering room's voice (C1, 2026-09-13): "I want to get out but I
can't", behind the end wall of the second side passage, audible from the corridor.

    python3 tools/make_corridor_plea.py      (stdlib + macOS `say` + ffmpeg, like make_kontur_voice.py)
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

Writes game/assets/audio/level_3_corridor/corridor_plea.wav: the line said twice, slowly, then
~6 s of silence so the loop breathes. Same telephone-style chain as the KONTUR green phone
(steep 450-3000 Hz passband, mild codec grit, a tiny echo), plus a longer reverb tail so it
reads as a voice in a closed room rather than down a line. Deterministic. Prints peak/RMS —
`corridor.gd:PLEA_DB` is set from it.
"""

import os
import subprocess
import tempfile

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "level_3_corridor", "corridor_plea.wav"))
LINE = "I want to get out. But I can't. I want to get out... but I can't."
VOICE = "Shelley"
RATE = 120


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(r.stderr)
    return r


def main():
    tmp = tempfile.mkdtemp()
    raw = os.path.join(tmp, "raw.aiff")
    run(["say", "-v", VOICE, "-r", str(RATE), "-o", raw, LINE])
    voice = os.path.join(tmp, "voice.wav")
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af",
         "highpass=f=450,highpass=f=450,lowpass=f=3000,lowpass=f=3000,"
         "acrusher=level_in=1:level_out=1:bits=9:mode=log:aa=0.35,"
         "aecho=0.7:0.5:40|90|170:0.35|0.25|0.15,"
         "volume=1.8,afade=t=in:st=0:d=0.1,apad=pad_dur=6",
         "-ar", "44100", "-ac", "1", "-sample_fmt", "s16", OUT])
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", OUT, "-af", "volumedetect", "-f", "null", "-"]).stderr
    for l in err.splitlines():
        if "mean_volume" in l or "max_volume" in l:
            print(l.strip())
    print("wrote", OUT)


if __name__ == "__main__":
    main()
