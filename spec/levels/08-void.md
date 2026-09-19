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

## NEEDS A PLAYTEST

⚠️ **THE VOID HAS NEVER BEEN HAND-PLAYED SINCE THE 2026-09-12 REBUILD.** The level was restructured
that day on the user's verdict *"too simple... too small, not packed with actions at all"* — 15 rooms on
`RoomBuilder` in place of a 15 × 15 m ring of four identical rooms. Everything in SPEC above is verified
by headless guards (`walk_void`, `check_void`, the Void rows in the scene-parameterised guards, the Void
poses in `screenshot_scene.gd`); none of it has been confirmed by a human at the controls.

Open for the first hand playtest:
- **The loop corridor.** `walk_void` proves the seam sends you back ≥ 1 lap and then never again once
  the note is read. What nobody has judged is whether the return reads as *seamless* — a player who
  notices the teleport loses the whole beat. Velocity and heading are kept precisely for this.
- **The tile hall.** Falling into the pit is one of this level's four deaths. The causeway (1.6 m tiles,
  1 m beams, a spine plus two branches and an island) has been walked by a bot, never missed by a human.
- **`CreatureD`'s watch-only contract** — it watches while you are on the tiles and stalks the instant
  you are off. Proven by a control in `check_void.gd`; unproven as a feeling.
- **The far wing's endurance.** A `DreadZone` cancels decay across it while three `DarkZone`s punish a
  torch-off walk, with six lethal stalkers in play. That economy has never been under a real player's
  panic bar.
- **Where it sits on the unreality curve.** This is the last unreal level before the loop ending; the
  fragments (the intro's gurneys, the Lab's morgue, the House's child room) are wrong on purpose.

## DECISIONS & GOTCHAS

⚠️ **Dated ⭐ entries live at the TOP of SPEC, not here.** They carry the level's *current* state and
override the older prose beneath them — that is how `CLAUDE.md` was written, and why entries say
things like *"every paragraph below that says 320 m is history"*.

⚠️ **The top-to-bottom order is NOT strictly newest-first.** Measured 2026-09-19: `01-lab.md`'s
2026-09-13 entry sits *above* the 2026-09-14 entry that reverts it, and `04-backrooms.md:302` sits
*below* the same-day entry that supersedes it. **Read the dates; where they tie, read the code.**

Use this section only for rationale that leaves **no trace** in the level — something tried and
abandoned. Anything describing what the level *is* belongs in SPEC.

### Audit record — 2026-09-19 spec audit

⚠️ **"15 abutting rooms … 14 doorways" is EXACT and was VERIFIED, not narrowed.** `level_3.gd`'s
`ROOMS` const holds exactly 15 rows and `DOORS` exactly 14. A claim-checker `COUNT?` that reports 19/16
is counting the `#` comment lines inside those arrays (the Morgue-abutment warning and the LoopOut
bridge-overlap warning). No spec change was needed. ⚠️ `level_3.gd`'s own header comment still says
"~14 rooms over ~40 x 45 m" — that is a stale CODE comment, not a drift in this file.

⚠️ **Two claims above could not be verified from the code and were left standing, not edited.**
(1) *"Standable area 77 → 452 m²"*: the 77 m² figure is corroborated by `level_3.gd`'s header, but 452
appears nowhere in the repo and does not reconcile with the `ROOMS` table (the raw sum of the 15 room
footprints is ~710 m², ~590 with the tile hall's freed floor taken out), so whatever it measures is
narrower than the room table and is not written down. (2) *"a `DreadZone` over Hall3 + Sanctum"*:
`DreadFarWing` is one box spanning x −21.5…−10, z 19.5–42.5, which also covers PocketB and the
ChildRoom — Hall3 and the Sanctum are its ends, not its extent.
