# Twist Ending — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Twist Ending**
Final door loads back to the intro room — **corrupted** (`_corrupt_room()` in `intro_room.gd`, fires when `GameState.is_ending`): candle dead, slow blood-red throb light, exit door replaced by planks (no way forward), harsh cold spotlight pinning the new note to the table, extra cobwebs, low whisper loop. Closing the note → **1 s in the corrupted room → `ending_scene.ogv` → `Screamer.trigger_to_menu()`**.
- ⚠️ **The 1 s beat before it is deliberate.** The note overlay covers the screen, so the red throb and the planked door are all the player has actually seen of the corrupted room; cutting straight to video spends a room nobody looked at. The no-video fallback path restores the original 2 s exactly
- ⚠️ **The clip ends on black by construction**, because `trigger_to_menu()` fires the instant it finishes. Veo delivered only 0.70 s of black; the shipped `.ogv` pads it with `tpad` (`assets_src/README.md`). ⚠️ **The pad buys less than the arithmetic says**: the cloned frames are identical, Theora run-length-codes duplicates, and **Godot stops at the last decoded frame rather than the container duration** — 1.3 s of padding bought 0.26 s, for **0.96 s of black actually on screen** against `ffprobe`'s nominal 1.46. That clears the real requirement (do not end on a lit frame). If it is ever regenerated, re-measure with `signalstats` — the tail is invisible by eye — and never compute a cutscene's playback length from a container field
- Both cutscene paths have a harness: `tests/screenshot_ending_cutscene.gd` and `tests/screenshot_wake_cutscene.gd`. ⚠️ They run **without `--headless`** (`CutscenePlayer.play()` returns null there by design, which is what keeps the suite green) and so are not in `tools/run_tests.sh`. ⚠️ Both key their samples to `VideoStreamPlayer.get_stream_position()`, never to a wall clock — the ending one photographed the *screamer* and reported it as "the clip's last frame" twice before that was fixed
- ⚠️ `player.freeze_input()` is not cosmetic: the mouse is captured and `CutscenePlayer` is opaque, so without it the player walks blind around the ward for ten seconds with footsteps playing


## DECISIONS & GOTCHAS

Dated change entries, newest first — why the level is the way it is, what was measured, what was
tried and rejected. ⚠️ Anything marked **DELIBERATE** or **the user's call** must not be
re-litigated without asking.

⚠️ `⚠️` gotchas that describe *current* behaviour stay inline in **SPEC** above: in this codebase
the rule and its reason are usually one sentence, and splitting them would break the sentence.

- ⭐ **The reveal is a video since 2026-08-17** (`_on_ending_note_closed()`): a slow pull back off a wall of CRT monitors showing every empty room in the institution, with motionless figures in lab coats watching them, one of whom turns to look at the camera. It closes the loop the Lab's Observation tape opens, and it replaces what was previously *a bare two-second pause*. The whole payoff of eight levels used to be a note and a still JPEG
