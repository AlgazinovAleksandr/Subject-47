---
name: new-level
description: Build a brand-new level for the horror game, end to end — design gate, spec first, code, assets, tests, docs. Use when the user wants to add, create or build a new level, or asks to implement one of the specced-but-unbuilt levels (OBSERVATION, THE ANECHOIC CHAMBER, THE RETURN). For changing or fixing an EXISTING level, use `level-work` instead.
---

# Building a new level

Nothing in this repo described how to do this before 2026-09-19. This is the reconstructed
procedure, verified against the code. **Three of its steps fail SILENTLY if you skip them** — they
are marked ⚠️ SILENT and are the reason this file exists.

⚠️ Work the phases in order. The spec is written in Phase 0, **before any code**, and the user
reviews it before Phase 1 starts. That is `CLAUDE.md`'s SPEC-FIRST rule, not a suggestion.

---

## Phase 0 — the design gate. No code until this is settled.

**Ask these before writing a line of spec.** Use `grill-me` — one question at a time, with your
recommendation on each.

1. **Append or insert?** Appending a level after the current last one touches ~6 things. **Inserting
   one triggers a 12-item renumber that must land as ONE commit** (see the last section). Establish
   which before anything else; it changes the size of the job by an order of magnitude.

2. **Where does it sit on the escalating-unreality curve?** `CLAUDE.md` calls this *"a hard
   constraint on new content, not a mood note"*: every level must be stranger than the one before
   it. The full ordering is in `spec/design/SCARY.md` §6.
   ⚠️ The curve is **already non-monotonic and deliberately unresolved** (Backrooms → KONTUR →
   Breach drops back to coherent real-world interiors). If the new level would deepen or resolve
   that dip, **stop and ask the user** — `CLAUDE.md` says *"do not resolve this silently in an
   implementation session."*

3. **Check it against the eleven anti-patterns** in `spec/design/SCARY.md` §8. Hard blocks:
   - §8.4 **a second chase level** — Level 6 is the one. *"Do not add a third pursuer."*
   - §8.2 **any HUD readout of progress toward a solution** — a compass, a warmer/colder, an
     "N of 8" bar. It removes the puzzle *and* hides that the real tell was never built.
   - §8.8 **emissive scary props** — no glowing monsters, eyes or anomalies. The engine's answer to
     "make it stand out in the dark" is **silhouette** and **audio**.

4. **Audit the fail economy against Issue 18.** For every posture the level *requires* — stand
   still, torch off, don't sprint — prove no zone charges panic for it. `player.gd:_update_panic` is
   an if/elif chain and a DarkZone branch also suppresses decay; KONTUR's Blackout room once charged
   **45 % of the bar in four seconds** for doing exactly what the room asked. Plan the assertion now:
   *"write the assertion into the level's test at the same time as the puzzle."*

5. **Write `spec/levels/NN-<name>.md`**, every planned beat marked `🔨 PLANNED`. Copy the SPEC-FIRST
   blockquote from `spec/levels/06-breach.md:3`. Sections: `## SPEC`, `## DECISIONS & GOTCHAS`,
   `## NEEDS A PLAYTEST`.
   ⚠️ If the design already lives in `spec/design/`, **point at it — never copy it**.
   `spec/levels/07-nightmare.md` is the model.

6. **Show the user `git diff spec/levels/NN-<name>.md` and STOP.** No code until they approve.

---

## Phase 1 — code

7. `const SCENE_<NAME> := "res://scenes/<file>.tscn"` in `game/scripts/game_state.gd` — **in level
   order**. `game/tests/lib/scenes.gd` reads these constants in declaration order.
8. Add the `N: get_tree().change_scene_to_file(SCENE_<NAME>)` arm to the `match current_level` in
   `game_state.gd:start_current_level()`. This is the **only** place index→scene is resolved;
   `advance_level()` / `go_back()` / `restart_current_level()` contain no per-level branching.
   ⚠️ SILENT: the `_:` fallback arm sends an unknown index to the **Intro** without erroring.
9. Update the `current_level` doc comment at the top of `game_state.gd`.
10. ⚠️ **Add the `META` row in `game/tests/lib/scenes.gd`** (`label`, `settle` in seconds — never a
    frame count — and `random`). **Without it, all nine scene sweeps go RED**: a `SCENE_*` that is
    in neither `META` nor `NOT_A_LEVEL` is reported as a finding by every one of them.
11. Create `game/scenes/<file>.tscn` by copying `game/scenes/level_6_breach.tscn` and changing
    **only** the script `ext_resource`, the root node name, and the `Player` spawn `Transform3D`.
    Those three lines are the entire difference between it and `dungeon.tscn`.
    ⚠️ You do **not** need a `HUDCanvas` node — `player.gd` instantiates it. The Flashlight values in
    the `.tscn` are dead; `player.gd:_ready()` overwrites them from `FLASH_*`.
12. Create `game/scripts/<file>.gd`:
    - `PRESERVE := ["Environment", "AmbientPlayer", "HUDCanvas", "Player"]`
    - `_clear_old_scene()` — **copy it verbatim** from `level_6_breach.gd`. ⚠️ `remove_child` BEFORE
      `queue_free`: `queue_free()` is deferred to end of frame, so the node still holds its name
      while `_ready()` builds the replacement, and Godot silently renames the new one (Issue 17).
    - `_ready()` in this order: capture the mouse → `GameState.current_level = N` →
      `_clear_old_scene()` → build → `_start_ambience()` → `_boost_ambient()` →
      `GameState.set_objective(...)` → `_restore_progress()` **last**.
    - ⚠️ `_boost_ambient()` must **duplicate** the Environment resource before editing it — it is a
      shared `.tscn` instance and mutating it in place leaks into every other level.
    - `_place_player()` branching on `GameState.entered_from_ahead`.
    - Doors via `door.gd:build_visual()`, never a hand-rolled BoxMesh; casings with **no colliders**
      or you seal the doorway and `check_doorways.gd` goes red.
13. **Decide `RandomAmbient.register_player()` in or out — and if out, write the reason as a
    comment.** `dungeon.gd` is the model: it stays out because the level's whole skill expression is
    distinguishing real positional tells from ambience, and RandomAmbient's blind 4 m pops would
    destroy that.

---

## Phase 2 — assets

14. Create `game/assets/textures/level_N_<name>/` and `game/assets/audio/level_N_<name>/`.
    ⚠️ **Asset folder numbers are identity, never index.** Two of the eight already disagree with
    the level they serve: `level_9_dungeon/` is **level 7**, and `level_4_void/` is **level 8**
    (`level_backrooms/` sidesteps it by carrying no number at all). Pick the number once and
    **never rename it** — renaming breaks every `.import` UID.
15. ⚠️ SILENT: **add the audio folder to `GameState.AUDIO_SUBDIRS`.** It is a hardcoded list. Without
    the entry, `load_audio()` returns **null for every file in that folder** and nothing errors.
    Also confirm every base name is **globally unique** — the extension loop is outermost, so a
    `.wav` in any other subdir beats a `.ogg` in the right one.
16. ⚠️ SILENT: **add the `LEVEL_SCREAMERS[N]` entry** in `game/scripts/screamer.gd`. A missing key
    falls through to a random `screamers/` face and the shared sting, with no error. The image goes
    in the level's own texture folder — `screamers/` is the DirAccess-scanned fallback pool for the
    intro and ending only.
17. Write `tools/make_sfx_<level>.py` — seeded, stdlib-only, **its own file**. Re-running a shared
    generator to add one sound silently rewrites every earlier file's noise.
18. `Godot --headless --path game --import`. Skipping this makes a new `class_name` unresolvable,
    which makes the level script fail to **parse**, which makes tests find nothing and pass.

---

## Phase 3 — tests

Nine sweeps enrol automatically once the `META` row exists (`check_wall_overlap`,
`check_note_mounting`, `check_art_aspect`, `check_prop_mounting`, `check_doorways`,
`check_shell_sealed`, `check_fixtures`, `check_spawn_blocked`, `check_reachable`). Everything below
is by hand.

19. A per-guard `CONFIG` row wherever the sweep needs waivers or a sample-size floor. A missing row
    is not an error — it means no waivers and a **vacuous** floor.
20. `game/tests/check_level_resume.gd` — `EXPECTED_CHAIN`, the backward loop, the screamer
    assertions, `_scene_for_level()`. Required **before the commit lands**.
21. `game/tests/autoplay_exit_reachable.gd` — a `ROUTES` entry.
22. `game/tests/walk_<level>.gd` — the end-to-end completability proof. ⚠️ **It must call `quit(1)`
    on failure.** `walk_level6_breach` was Level 6's only completability proof and could not fail at
    all for a whole era, on a level that had already shipped uncompletable once.
23. `check_scare_loudness.gd` `FLOORS` — a scream with no row is **never measured**.
24. `check_darkness.gd` — add the level (`WIDE_TORCH_LEVELS` if it keeps the default 18 m / 30° torch).
25. `tools/run_tests.sh` `TESTS=(` — every new test, with an accurate one-line comment. That array
    is the only index of what the suite covers.
26. Run `tools/run_tests.sh`. **Verify the nine sweeps picked the level up by reading their per-scene
    output — do not assume.**

---

## Phase 4 — docs

27. `.claude/rules/level-N-<name>.md` — `globs:` frontmatter (⚠️ **not `paths:`**) plus a one-line
    SPEC-FIRST pointer. Copy `.claude/rules/level-6-breach.md`.
28. `CLAUDE.md` in **four** places: the Structure arrow chain, the per-level index block, the
    Level-scenes table, and the `GameState` autoload row's index list.
29. `docs/TEXTURES.md` — a section per asset folder, one row per file, `where_used` naming the exact
    builder function.
30. `spec/systems/scripts.md` — a row for the level script and each new helper.
31. `spec/systems/testing.md` — a paragraph for each bespoke guard or walker added.
32. `docs/TODO_sounds.md` — rows for anything wired but not yet existing (each needs a code fallback).
33. `README.md` — the public blurb; and the controls line if a new input action was added.
34. `spec/design/proposed-levels.md` — if this was one of the three specced-unbuilt levels, move it
    off the list with a "shipped as Level N" note.

---

## Phase 5 — run it, then close the spec

35. ⚠️ **Run the game and look at it.** Not headless asserts — a `screenshot_*` pass whose PNGs you
    actually `Read`, and a walker whose log you actually read. Everything about how a level *looks*
    is invisible to the suite; that is why every spec has a `## NEEDS A PLAYTEST` section.
36. **Drop the `🔨 PLANNED` markers**, move the rationale and measured numbers into
    `## DECISIONS & GOTCHAS`, and **re-read the whole spec** for anything the build now contradicts.
    *A change is not finished until its spec says so.*
37. Report what you built, what you measured, and what the user should watch for. **Never commit.**

---

## ⚠️ Inserting a level: the 12-item renumber, in ONE commit

`CLAUDE.md` lists five things. The verified list is twelve, and **none of them fail loudly** — a
half-landed renumber is a playable game with the wrong faces and lost progress.

1. `game_state.gd` — the `current_level` comment
2. `game_state.gd` — the `SCENE_*` constants, in level order
3. `game_state.gd` — the `match` in `start_current_level()`
4. `screamer.gd` — `LEVEL_SCREAMERS` keys
5. **The eleven `GameState.current_level = N` assignments across ten scripts** — every level script
   sets its own index in `_ready()`, not just `level_3.gd`. ⚠️ Measured 2026-09-19; `ending.gd:13`
   and `intro_room.gd:153` both set 0, which is correct and must stay
6. `kontur.gd:1104` — the banishment's hard-coded destination (`= 4`, the Backrooms). This is
   `kontur.gd`'s **second** assignment; its own index is at `:241`. Easy to miss with one grep hit
7. **The eleven hard-coded-index `get_level_progress(N)` / `get_level_attempts(N)` call sites** —
   `level_1:403` `level_2:354` `corridor:625` `backrooms:208` `kontur:490` `kontur:508`
   `level_6_breach:152` `level_6_breach:267` `dungeon:258` `dungeon:1699` `level_3:643`.
   ⚠️ `game_state.gd:243` uses `current_level` and must **not** be touched
8. `tests/lib/scenes.gd` — the `META` dict and its `save_level_progress()` call
9. `tests/check_level_resume.gd` — `EXPECTED_CHAIN`, the backward loop, the `has(N)` assertions,
   `_scene_for_level()`
10. Every test pinning a level by index (the dungeon-seed tests, `check_void.gd`, `check_lab_cabinet.gd`)
11. Docs: `CLAUDE.md` ×4, `spec/design/proposed-levels.md`, `spec/design/SCARY.md`'s ordering table,
    and the `spec/levels/NN-*.md` filenames
12. ⚠️ **Do NOT rename the asset folders** — their numbers are identity, not index, and two already
    disagree with their level (`level_9_dungeon/` = 7, `level_4_void/` = 8). Renaming breaks UIDs.

⚠️ **The back-door chain does not work the way the docs describe.** `CLAUDE.md` and
`spec/design/proposed-levels.md` say "each level's back door names its predecessor". It does not —
`door.gd` carries no index; it just calls `GameState.go_back()`. The real chain is **the `match`
statement ↔ each level's self-assigned `current_level`**, and the two must agree.
`check_level_resume.gd` exists precisely to catch them disagreeing.
