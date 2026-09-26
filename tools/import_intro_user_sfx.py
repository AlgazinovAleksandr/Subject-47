#!/usr/bin/env python3
"""Drop the USER-SUPPLIED intro sounds into their game slots (2026-09-24, first intro playtest).

The raws live in assets_src/audio/intro/user/ (the user's own files, untouched). Each is trimmed,
folded to mono 44.1 kHz (every intro sound is played by an AudioStreamPlayer3D, and a stereo
stream does not spatialise), and its MEAN loudness is matched to the procedural stand-in it
replaces — the level's gains were set against those stand-ins, so a hotter or quieter file would
silently re-mix the room. A -1 dBFS limiter stops a gain-up from clipping.

  slot (game/assets/audio/intro/)   raw                          cut              target mean
  switch_stuck.wav                  switch_before_turn_on.wav    0.00 – 1.95 s    -18.5 dB (= switch_clunk)
  intro_strap_buckle.wav            leather.wav                  6.00 – 7.26 s    -21.0 dB
  intro_strap_buckle_2.wav          leather.wav                  11.10 – 12.10 s  -21.0 dB
  intro_strap_buckle_3.wav          leather.wav                  12.42 – 14.36 s  -21.0 dB
  intro_session46_tape.wav          old_recorder.wav             whole (40 s)     -23.5 dB
  intro_power_cut.wav               electricity_off.wav          0.00 – 10.60 s   -19.7 dB
  intro_door_creak.wav              door_creak.wav               0.00 – 3.55 s    -20.3 dB
  intro_cell_buzz.wav               metal_door.wav               whole (4.1 s)    -16.0 dB

The leather cuts are three separate takes between the raw's own silences (silencedetect at
-45 dB), so the three straps do not sound identical. `switch_stuck` needs no code: the first press
of the light switch has always played it when it exists (intro_room.gd:_on_switch_stuck), and the
working throw keeps `switch_clunk` — the user's call.

⚠️ tools/make_sfx_intro.py SKIPS these slots (USER_SUPPLIED) so a re-run cannot overwrite them.

Run:  python3 tools/import_intro_user_sfx.py      (needs ffmpeg), then Godot --import.
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "assets_src" / "audio" / "intro" / "user"
OUT = ROOT / "game" / "assets" / "audio" / "intro"

SLOTS = [
    # slot, raw, start, end (None = to the end), target mean dB, fade-out s
    ("switch_stuck.wav", "switch_before_turn_on.wav", 0.0, 1.95, -18.5, 0.15),
    ("intro_strap_buckle.wav", "leather.wav", 6.00, 7.26, -21.0, 0.08),
    ("intro_strap_buckle_2.wav", "leather.wav", 11.10, 12.10, -21.0, 0.08),
    ("intro_strap_buckle_3.wav", "leather.wav", 12.42, 14.36, -21.0, 0.08),
    ("intro_session46_tape.wav", "old_recorder.wav", 0.0, None, -23.5, 0.0),
    ("intro_power_cut.wav", "electricity_off.wav", 0.0, 10.60, -19.7, 0.4),
    ("intro_door_creak.wav", "door_creak.wav", 0.0, 3.55, -20.3, 0.1),
    ("intro_cell_buzz.wav", "metal_door.wav", 0.0, None, -16.0, 0.1),
]


def mean_db(path: Path) -> float:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "volumedetect",
                        "-f", "null", "-"], capture_output=True, text=True)
    m = re.search(r"mean_volume: (-?[0-9.]+) dB", r.stderr)
    return float(m.group(1))


def render(raw: Path, dst: Path, start: float, end, gain_db: float, fade: float) -> None:
    dur = (end - start) if end is not None else None
    chain = ["aformat=channel_layouts=mono", "aresample=44100", f"volume={gain_db:.2f}dB",
             "alimiter=limit=0.891:level=false"]
    if fade and dur:
        chain.append(f"afade=t=out:st={max(0.0, dur - fade):.3f}:d={fade:.3f}")
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{start:.3f}"]
    if dur:
        cmd += ["-t", f"{dur:.3f}"]
    cmd += ["-i", str(raw), "-af", ",".join(chain), "-c:a", "pcm_s16le", str(dst)]
    subprocess.run(cmd, check=True)


def main() -> None:
    tmp = OUT / "_probe_tmp.wav"
    for slot, rawname, start, end, target, fade in SLOTS:
        raw = RAW / rawname
        render(raw, tmp, start, end, 0.0, 0.0)          # the cut, unscaled, to measure it
        gain = target - mean_db(tmp)
        render(raw, OUT / slot, start, end, gain, fade)
        print(f"{slot:28s} <- {rawname:28s} gain {gain:+.1f} dB -> mean {mean_db(OUT / slot):.1f} dB")
    tmp.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
