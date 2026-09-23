#!/usr/bin/env python3
"""PLACEHOLDER audio for Level 6's approach, pass 4 (2026-09-23), at the FIXED paths the user's own
recordings will replace. Drop each supplied file in at the same base name (.wav), then --import.

  approach_drop_crash.wav     the ceiling hatch bursting and the body's weight hitting the chain
                              stand-in: level_6_breach/approach_door_crash.wav (the user's metal_crash)
  approach_drop_chain.wav     the chain rattling as the body swings
                              stand-in: level_2_house/chain_rattle.wav
  approach_shutter_breath.wav a very low breath from the shutter niche (optional)
                              stand-in: level_5_kontur/breathing_behind.wav, lowered

Copies only (base names must be globally unique, so a copy is how a new name points at old audio).
Needs ffmpeg. Usage: python3 tools/make_sfx_breach_pass4.py
"""
import os
import shutil
import subprocess

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
A = os.path.join(ROOT, "game", "assets", "audio")
OUT = os.path.join(A, "level_6_breach")

COPIES = [
    (os.path.join(A, "level_6_breach", "approach_door_crash.wav"), "approach_drop_crash", ""),
    (os.path.join(A, "level_2_house", "chain_rattle.wav"), "approach_drop_chain", ""),
    (os.path.join(A, "level_5_kontur", "breathing_behind.wav"), "approach_shutter_breath",
     "asetrate=44100*0.82,aresample=44100,lowpass=f=1800"),
]


def main():
    ff = shutil.which("ffmpeg")
    assert ff, "ffmpeg is required"
    for src, name, af in COPIES:
        dst = os.path.join(OUT, name + ".wav")
        cmd = [ff, "-v", "error", "-y", "-i", src]
        if af:
            cmd += ["-af", af]
        cmd += ["-ac", "1", "-ar", "44100", "-sample_fmt", "s16", dst]
        subprocess.run(cmd, check=True)
        print("wrote", os.path.relpath(dst, ROOT))


if __name__ == "__main__":
    main()
