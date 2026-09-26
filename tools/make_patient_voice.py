#!/usr/bin/env python3
"""The airlock patient's words — "They'll kill us. They'll kill ALL of us!" (2026-09-25).

A STAND-IN. The user's `patient_scream.ogg` is a wordless scream, and they asked for a second sound
that carries the words. The repo's ElevenLabs key answered HTTP 401 (invalid/expired) on the day, so
this is macOS `say` "Ralph" (deep US male) at 235 wpm, then made to sound shouted and ragged behind
the bars: pitched down 7 %, sped back up 12 %, a shaking vibrato, band-limited, driven hard into a
tanh soft-clip, a small hard-walled room, and limited to the level of a shout. Replace it by
dropping a real recording at the same path (see docs/TODO_sounds.md).

⚠️ It is NOT the observer, so it does not count against the intro's five-line voice budget — that
rule is about the experiment's voice on the tannoy.

Run:  python3 tools/make_patient_voice.py      (stdlib + macOS `say` + ffmpeg), then Godot --import.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "audio" / "intro" / "intro_patient_words.wav"
VOICE = "Ralph"
RATE = 235
LINE = "They'll kill us. [[slnc 120]] They'll kill ALL of us!"
CHAIN = ("asetrate={sr}*0.93,aresample=44100,atempo=1.12,vibrato=f=6.5:d=0.4,"
         "highpass=f=170,lowpass=f=4800,volume=24dB,asoftclip=type=tanh,"
         "aecho=0.8:0.55:28|61:0.32|0.18,afade=t=in:d=0.02,alimiter=limit=0.89:level=false")


def main() -> None:
    for tool in ("say", "ffmpeg", "ffprobe"):
        if shutil.which(tool) is None:
            sys.exit(f"error: `{tool}` not found")
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "raw.aiff"
        subprocess.run(["say", "-v", VOICE, "-r", str(RATE), "-o", str(raw), LINE], check=True)
        sr = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=sample_rate",
                             "-of", "csv=p=0", str(raw)], capture_output=True, text=True,
                            check=True).stdout.strip()
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(raw), "-af",
                        CHAIN.format(sr=sr), "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le",
                        str(OUT)], check=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
