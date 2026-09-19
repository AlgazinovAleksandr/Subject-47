# Level 8 — The Void — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Level 8 — The Void (surreal broken geometry)** — `level_3.gd` + `void_fragments.gd` + `level_3.tscn`
⭐⭐ **REBUILT 2026-09-12 ON `RoomBuilder`** on the user's verdict *"too simple... too small, not
packed with actions at all"* — textures, music, vignette and the crowned stalkers kept, everything
else restructured (D9/D10). **Not yet hand-played after the rebuild.**
- **15 abutting rooms on an integer grid, 14 doorways** (`ROOMS`/`DOORS` class consts, `# x a..b
  z a..b` on every row): Threshold (spawn, BackDoor, two candles + one `CalmZone`, `CreatureA` dead
  ahead as the teaching beat) → Hall1 (PocketA trap) → Ward (the intro's gurneys) → Archive (dead
  end) / LoopIn → **LoopStraight 3 × 30 m** → LoopOut → Hall2 → **TileHall 12 × 10** → Morgue (the
  Lab's exam table and dead monitor) → Hall3 (PocketB trap) → ChildRoom (the House's bed, drawing,
  music box) → Sanctum (twist note, ExitDoor). Standable area **77 → 452 m²**.
  ⚠️ Rooms must ABUT: the Morgue was authored a metre short, the doorway cut the hall's wall and
  not the Morgue's, and the whole far wing measured unreachable (Issue 191).
- **The loop corridor** (`_build_loop` / `_on_loop_seam`): an `Area3D` at 60 % of the run sends a +z
  walker back exactly `LOOP_PERIOD` 15 m **keeping heading and velocity** (the Backrooms teleport
  zeroes velocity; seamlessness needs it kept); walking back out is allowed. Each lap `CreatureC`
  creeps 2 m closer and a torn page drops; lap 2 scrawls `AGAIN.`; the corridor's note breaks it.
- **The floating tiles** (`_build_tile_hall`): the room's `TileHall_Floor` is freed and a causeway of
  1.6 m tiles on 1 m beams (spine → a north and a south branch → an island) crosses a walled black
  pit (floor at `ABYSS_Y` −8, fall at `FALL_Y` −4 → `Screamer.trigger()`); the doorway bridges are the
  landing pads. `CreatureD` is **`watch_only`** while the player is inside `_tile_rect` — it watches,
  it never steps — and stalks the moment they are off (`check_void.gd` proves it with a control).
- **Fragment rooms** (`void_fragments.gd`, static builders from PARTS in void skin, no emission):
  gurney, exam_table, monitor, child_bed, crayon_drawing, music_box; art quads sized from their
  texture's aspect (the level's `check_art_aspect` samples).
- **Six `CreatureStalker`s** A–F, all `scrape_tell = true`, all **still lethal** (D10): Threshold,
  Ward, the loop's far end, the Morgue (D, seen through the doorway from the causeway), the child's
  bed, guarding the twist note. `START_GRACE` 5 s, the stare-off mechanic and the gaze cost unchanged.
- **Nine notes via `wall_point()` at 1.3 m**: safe = Threshold, Ward, LoopStraight (the loop
  breaker), Morgue (WEST wall — the south centre is the doorway), Archive; trap = PocketA, ChildRoom,
  PocketB (read-to-die kept); the twist in the Sanctum. `DarkZone`s on TileHall/Morgue/ChildRoom,
  a `DreadZone` over Hall3 + Sanctum, candle flames at emission ≤ 1.0.
- `save_progress()` → `{notes_read, loop_broken, loop_laps}`; `entered_from_ahead` spawns at the
  ExitDoor facing in. Test surface: `get_stalkers()`, `loop_laps()`, `loop_broken()`, `tile_rect()`.
- **Tests**: `walk_void.gd` (spawn → every note through the shipping ray → the loop sends you back
  ≥ 1 then never again → across the tiles → twist → ExitDoor found and unlocked) · `check_void.gd` ·
  a Void row in `autoplay_exit_reachable.gd` · Void poses in `screenshot_scene.gd`; every
  scene-parameterised guard's Void row is an assertion now (V-T4..T7 are moot).
- Win: read the twist note → exit door unlocks → walk through. Fail: a creature reaches you, you
  fall into the pit, a trap note read to the end, or the panic bar fills.


## DECISIONS & GOTCHAS

Dated change entries, newest first — why the level is the way it is, what was measured, what was
tried and rejected. ⚠️ Anything marked **DELIBERATE** or **the user's call** must not be
re-litigated without asking.

⚠️ `⚠️` gotchas that describe *current* behaviour stay inline in **SPEC** above: in this codebase
the rule and its reason are usually one sentence, and splitting them would break the sentence.

*No dated entries yet — this level's history is recorded inline in SPEC above. Add new entries
here, newest first, as the SPEC-FIRST protocol completes each change.*
