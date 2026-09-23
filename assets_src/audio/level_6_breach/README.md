# Object 12 recordings

These four originals were supplied by the user on 2026-09-20 and are preserved unchanged.
The game uses prepared WAV copies in `game/assets/audio/level_6_breach/`:

| Original | Game file | Use |
| --- | --- | --- |
| `breach_voice_chase_background.mp3` | `breach_voice_chase_background.wav` | Stereo chase background, repeats while chasing |
| `breach_voice_scream_chase.mp3` | `breach_voice_scream_chase.wav` | Positional chase scream over the background |
| `breach_voice_batter.mp3` | `breach_voice_batter.wav` | Positional roar alongside door punches |
| `breach_voice_search.wav` | `breach_voice_search.wav` | Positional howl while the player is safely hidden |

From the repository root, run `python3 tools/prepare_breach_audio.py` to rebuild game copies.
This requires ffmpeg. The preparation trims silent tails, converts voices to mono, blends the
background loop seam and normalizes peaks before PCM conversion. The supplied chase MP3 has
float samples above full scale; converting straight to int16 would clip it.

Playback gains and spacing live in `game/scripts/breach_creature_voice.gd`. The full batter
recording is longer than the door hold, so the supernatural silence intentionally cuts it off.
The `procedural_archive/` folder contains superseded synthetic material, unused by the game.

## Approach recordings (2026-09-23)

The user supplied thirteen more recordings for the containment approach. They are copied here,
**byte-identical**, in `approach/`; the user's own folder `game/assets/audio/level_6_breach/new_sounds/`
was left in place. Game copies are prepared by `python3 tools/prepare_breach_approach_audio.py`
(ffmpeg). It decodes to float and normalises there, because `loud_screamer`, `loud_scream`,
`metal_crash` and `door_part1_sound` decode above full scale.

| Original | Game file | Use (the user's mapping) |
| --- | --- | --- |
| `door_part1_sound.wav` | `approach_victim_hammer.wav` (0–5.2 s) | The technician hammering and begging behind the porthole door |
| `door_part_2_scream.mp3` | `approach_victim_scream.wav` (0.25–3.85 s) | His scream |
| `creature_sound.wav` | `approach_victim_roar.wav` (0–4.4 s, low-passed 650 Hz twice) | Object 12's roar behind that door, muffled |
| `loud_scream.wav` | `approach_building_scream.wav` | The scream the building answers |
| `monster_knock.wav` | `approach_duct_knocks.wav` | Three knocks cut at clean attacks (3.712, 7.118, 10.976 s), placed at 0 / 0.66 / 1.52 s |
| `creature_crawl.wav` | `approach_duct_crawl.wav` | The scrape moving away through the duct |
| `metal_crash.wav` | `approach_door_crash.wav` (from its 0.513 s onset) | The door tell's crash |
| `lamp_on.wav` | `approach_lamp_on.wav` | Motion lamps clunking on |
| `lamp_off_break.flac` | `approach_lamp_die.wav` (1.04–3.6 s) | The self-waking lamp dying; the smashed lamp's sputter |
| `motor.wav` | `approach_shutter_motor.wav` | Bay B's roller shutter |
| `ventilation.wav` | `approach_vent_bed.wav` (stereo, 0.6 s crossfaded seam) | The breathing bed |
| `dust.wav` | `approach_dust.wav` | Dust sifting down |
| `loud_screamer.mp3` | `approach_hand_scream.wav` (0–4.6 s) | The hand in the duct |

Playback gains and scheduling live in `game/scripts/breach_approach.gd`.
