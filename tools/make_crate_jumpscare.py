#!/usr/bin/env python3
"""B2 (2026-09-14): `crate_jumpscare.ogg` from the user's `crate_jumpscare_raw.m4a`, with the
0.785 s of LEADING SILENCE trimmed off — the second playtest in a row said the sting arrived
late, and the file was the reason (make_sfx_* rules: fix the source pipeline, never the shipped
file in place). Prints the remaining lead so a test can assert it.

    python3 tools/make_crate_jumpscare.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
"""
import os, re, subprocess

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets_src", "audio", "level_backrooms", "crate_jumpscare_raw.m4a")
OUT = os.path.join(HERE, "game", "assets", "audio", "level_backrooms", "crate_jumpscare.ogg")
FFMPEG = "/opt/homebrew/bin/ffmpeg"


def lead_silence(path):
    r = subprocess.run([FFMPEG, "-i", path, "-af", "silencedetect=n=-45dB:d=0.05", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.search(r"silence_end: ([0-9.]+)", r.stderr)
    return float(m.group(1)) if m else 0.0


if __name__ == "__main__":
    lead = lead_silence(SRC)
    print("source leading silence: %.3f s" % lead)
    subprocess.run([FFMPEG, "-y", "-ss", "%.3f" % max(0.0, lead - 0.01), "-i", SRC, "-c:a", "libvorbis", "-q:a", "6", OUT], check=True, capture_output=True)
    print("wrote %s  leading silence now: %.3f s" % (OUT, lead_silence(OUT)))
