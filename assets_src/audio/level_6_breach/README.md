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
