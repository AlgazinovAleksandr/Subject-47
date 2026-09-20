# Twist Ending — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Twist Ending**
Final door loads back to the intro room — **corrupted** (`_corrupt_room()` in `intro_room.gd`, fires when `GameState.is_ending`): candle dead, slow blood-red throb light, exit door replaced by planks (no way forward), harsh cold spotlight pinning the new note to the table, extra cobwebs, low whisper loop. Closing the note → **1 s in the corrupted room → `ending_scene.ogv` → `Screamer.trigger_to_menu()`**.
- ⭐ **The reveal is a video since 2026-08-17** (`_on_ending_note_closed()`): a slow pull back off a wall of CRT monitors showing every empty room in the institution, with motionless figures in lab coats watching them, one of whom turns to look at the camera. It closes the loop the Lab's Observation tape opens, and it replaces what was previously *a bare two-second pause*. The whole payoff of eight levels used to be a note and a still JPEG
- ⚠️ **The 1 s beat before it is deliberate.** The note overlay covers the screen, so the red throb and the planked door are all the player has actually seen of the corrupted room; cutting straight to video spends a room nobody looked at. The no-video fallback path restores the original 2 s exactly
- ⚠️ **The clip ends on black by construction**, because `trigger_to_menu()` fires the instant it finishes. Veo delivered only 0.70 s of black; the shipped `.ogv` pads it with `tpad` (`assets_src/README.md`). ⚠️ **The pad buys less than the arithmetic says**: the cloned frames are identical, Theora run-length-codes duplicates, and **Godot stops at the last decoded frame rather than the container duration** — 1.3 s of padding bought 0.26 s, for **0.96 s of black actually on screen** against `ffprobe`'s nominal 1.46. That clears the real requirement (do not end on a lit frame). If it is ever regenerated, re-measure with `signalstats` — the tail is invisible by eye — and never compute a cutscene's playback length from a container field
- Both cutscene paths have a harness: `tests/screenshot_ending_cutscene.gd` and `tests/screenshot_wake_cutscene.gd`. ⚠️ They run **without `--headless`** (`CutscenePlayer.play()` returns null there by design, which is what keeps the suite green) and so are not in `tools/run_tests.sh`. ⚠️ Both key their samples to `VideoStreamPlayer.get_stream_position()`, never to a wall clock — the ending one photographed the *screamer* and reported it as "the clip's last frame" twice before that was fixed
- ⚠️ `player.freeze_input()` is not cosmetic: the mouse is captured and `CutscenePlayer` is opaque, so without it the player walks blind around the ward for ten seconds with footsteps playing

## DECISIONS & GOTCHAS

⚠️ **Dated ⭐ entries live at the TOP of SPEC, not here.** They carry the level's *current* state and
override the older prose beneath them — that is how `CLAUDE.md` was written, and why entries say
things like *"every paragraph below that says 320 m is history"*.

⚠️ **The top-to-bottom order is NOT strictly newest-first.** Measured 2026-09-19: `01-lab.md`'s
2026-09-13 entry sits *above* the 2026-09-14 entry that reverts it, and `04-backrooms.md:302` sits
*below* the same-day entry that supersedes it. **Read the dates; where they tie, read the code.**

Use this section only for rationale that leaves **no trace** in the level — something tried and
abandoned. Anything describing what the level *is* belongs in SPEC.

*No superseded passages: the 2026-09-19 audit checked every claim in SPEC against `intro_room.gd`
(`_corrupt_room()`, `_on_ending_note_closed()`), `ending.gd` and `cutscene_player.gd` and found
none of them contradicted.*

## NEEDS A PLAYTEST

- The whole reveal chain is unverifiable headless by design (`CutscenePlayer.play()` returns null
  without a render target, and the two harnesses are outside `tools/run_tests.sh`). Close the
  ending note and watch it through **once, in the real app**: 1 s of the corrupted room → the
  monitor-wall pull-back → the screamer to the menu, with no walking or footsteps under the clip.
- ⚠️ Watch the tail. The black at the end is **0.96 s of decoded frames**, not the 1.46 s the
  container advertises; if the clip is ever regenerated, the one thing a playtest must catch is the
  cut landing on a LIT frame. (`intro_room.gd:12` still describes it as "~1.5 s of black" — the
  container figure, not the measured one.)
- The 1 s beat only pays off if the corrupted room reads in that second: red throb reaching past
  the table (`omni_range` 11.0 in an 18 m ward) and the planked-over doorway both legible before
  the video takes the screen.
