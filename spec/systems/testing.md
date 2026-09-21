# Testing — the guards and what they actually prove

## Testing

`check_breach_flashlight.gd` covers missing/owned F behavior, physical walking from the entry
through Records to the fixed Archive B cabinet and out to Ward B, real E-ray hiding/pickup,
hidden contact safety, unowned weapon suppression, one-time collection, normal return, death
reset and older completed saves. `-- --screenshots` renders entry/clue/pickup to
`/tmp/breach_flashlight/`. Creature activation runs on the real clock; the creature is parked
for deterministic geometry/interaction checks. Existing weapon and hiding harnesses explicitly
start after recovery.

`check_breach_kill.gd` drives Object 12's real contact check with hidden, closed-door and distance
controls, then verifies the rig/skin identity, camera-visible mesh layer, animated arm reach,
two timed impacts, artwork/HUD visibility, one fatal restart and restored player input. Duplicate
contact and competing fatal requests cannot interrupt the owned sequence. Navigating during a
second wind-up frees the old rig and cannot restart/count a death in the replacement scene.
Run with `-- --screenshots` and a renderer to record phases in `/tmp/breach_attack/`.

`check_breach_playtest.gd` (2026-09-20) covers the supernatural door sequence and hiding-memory
policy through real E-rays, physical door collision, timed light/audio restoration, overlapping
effects, F-off, entering cover and scene removal. It drives 120 simulated seconds of hidden
movement and relocation and carries a live legacy-policy control that targets the cabinet.
`-- --legacy-hiding` deliberately disables the policy and must fail; `-- --screenshots` requires
a render target and writes matched material and door-phase evidence to `/tmp/breach_sep20/`.

`check_breach_voice.gd` covers the supplied three voices plus a separately layered chase
background. Its 42 checks include AudioEffectCapture measurements of both decoded chase streams,
actual background loop wrap, music continuing between screams, death/loss-of-chase/hiding/door/
stagger/purge suppression, scene removal, hidden safety and visible recoil without collider motion.
It drives the real E interaction and door silence clock. `-- --screenshots` renders settled and
mid-impact door frames to the same evidence directory. These checks prove playback and lifecycle;
the user judges the mix by listening in a manual playtest.

```bash
tools/run_tests.sh          # the whole headless suite, one summary table
tools/run_tests.sh -q       # summary + failing output only
tools/run_tests.sh maze     # only tests matching a substring
```

Exit code is the number of failing tests. The `TESTS` array in that script is the only index of
what the suite actually covers — keep the one-line comment beside each name accurate.

### ⚠️ Coverage by construction — the scene list is DERIVED (2026-08-17)

`game/tests/lib/scenes.gd` reads the `SCENE_*` constants straight out of `game_state.gd` and is the
**one scene list**. Nine guards iterate it — `check_wall_overlap`, `check_note_mounting`,
`check_art_aspect`, `check_prop_mounting`, `check_doorways`, `check_shell_sealed`, `check_fixtures`,
`check_spawn_blocked`, `check_reachable` — so **adding a level enrols it in all nine with nothing to
remember**, and a `SCENE_*` constant that is neither classified as a level (`META`) nor excluded by
name (`NOT_A_LEVEL`, currently the menu and the ending redirector) turns every one of them red.

This replaces eight hand-written wrappers, which are **deleted rather than left alongside** — two
ways to run one guard is how they drift. Enrolling a level used to mean remembering to write one,
and that was forgotten every single time it was possible to forget it: `check_wall_overlap.gd` and
`check_note_mounting.gd` ran on **one level out of nine** for their whole lives, and the first run
against the Corridor found 32 things and against the Backrooms 23.

A guard's per-scene row is an **override, not an enrolment** — waivers, sample-size floors and RNG
seeds. Reproduce one finding with a label filter or a raw path:

```bash
Godot --headless --path game --script res://tests/check_wall_overlap.gd -- Corridor
Godot --headless --path game --script res://tests/check_art_aspect.gd -- res://scenes/kontur.tscn
```

⚠️ **Randomised scenes are pinned by seeding the ENGINE RNG** (`Scenes.pin_rng(n)` -> `seed(n)`
before `change_scene_to_file`), not by a command-line argument — `run_tests.sh` has no per-test
argument mechanism, and needing one is exactly what kept six levels outside every geometry guard.
Nothing in `game/scripts` calls `randomize()`, so one seed fixes KONTUR's `_dark_x` **and** its
gate-1 colour, the Backrooms' arm assignment and the whole dungeon layout at once. Measured: seed 7
-> `_dark_x` +3.0, seed 3 -> -3.0, seed 11 -> 0.0 with the colours swapped. **Geometry sweeps run
several seeds; prop sweeps run one**, because which props a dungeon spawns varies with the seed and
a deferral list that only holds on some dungeons is worse than none.

### ⚠️ A `check_*` that never calls `quit(1)` is a PRINTER, and the runner cannot tell

**Five entries in the suite asserted nothing** until 2026-08-17 (cross-level X50): `check_fixtures`,
`check_window`, `check_morgue_props` and `check_spawn_blocked` walked the scene, printed what they
found and returned — exiting 0 whatever they saw — while `check_doorways` printed `BLOCKED <name>`
and then called `quit(0)` unconditionally. The runner listed all five as guarantees
("nothing seals a doorway", "ceiling fittings are not blown out", …) that the suite could not make.
Four are real guards now; `check_morgue_props` is `probe_morgue_props` and out of the list, its
claim being covered by `check_reachable`.

⚠️ **And a sixth, worse: `walk_level6_breach.gd` never called `quit()` at all** — every terminal
path printed `RESULT: FAIL (...)` and then `return true`, which ends the SceneTree loop and exits
**0**. That is the only end-to-end completability proof THE BREACH has, and it exists *because* that
level once shipped uncompletable. Fixed. **`grep -L "quit(" game/tests/*.gd` before trusting a green
column** — a test that cannot fail occupies a row in the coverage table and reports nothing.

### ⚠️ An ABSENCE assertion is trivially true of a level that failed to build

`check_dungeon_entities.gd` asserts eleven absences per seed — no `DarkZone`, no `DreadZone`, no
`ApparitionDirector` — and had nothing asserting the dungeon existed, so a `dungeon.gd` that threw
on its first line would have printed eleven comfortable OKs. It now asserts >= 9 rooms and exactly 7
sconces **first**, and plants a real `DarkZone` every run to prove the counter still counts. Every
ban-shaped guard in the project reads the same way (cross-level X51).

⚠️ **`--import` is not optional after adding a `class_name` or an asset** (the runner does it for
you). Godot caches class names in `.godot/global_script_class_cache.cfg`; until it rescans, a new
`class_name` is "not declared in the current scope", which makes every level script that uses it
fail to **parse**, which makes tests find nothing and report PASS. That exact sequence produced a
green "0 apparitions in 400 s".

⚠️ **A green run is not a good build — read the numbers.** Several tests exist because a
*passing* result was meaningless: `count_apparitions.gd` now asserts a minimum count (it once
reported "0 in 400 s" as a tidy pass on a build with the monster switched off), and
`check_apparition_clearance.gd` asserts its own sample size (it reported "0 spawns checked …
PASS" when the script under test failed to compile).

⚠️ **Three more vacuous passes were found on 2026-07-28/29, all of them green.** Read them as a
set, because the shape repeats: *the assertion ran, and measured nothing.*
- A bus-restore check sampled at "frame 130" — headless runs uncapped, so a frame count is not a
  clock; it landed mid-tween and reported a false failure. **Time-based now.**
- A door-clearance check called `swing_ajar()` and measured in the SAME frame. A `Tween` does not
  run until the next one, so it measured un-swung doors and reported a comfortable 2.81 m for a
  panel that had not moved. The real figure is 2.02 m.
- A painting-position check asserted only `y < 0.3`. A painting teleported THROUGH the floor to the
  world origin satisfies that. It now asserts the room and the facing as well.

⚠️ **A test that fails to PARSE exits 0 and the runner counted it as PASS** — Issue 44. `run_tests.sh`
now greps for `Parse Error` / `Failed to load script` and forces a failure. ⚠️ **And since
2026-08-16 it fails any test that prints `SCRIPT ERROR` at all** (Issue 78): a GDScript *runtime*
error aborts one call and carries on, so it changes neither the exit code nor the assertions after
it — a test can run, throw on every iteration, and report PASS. It caught three on the day it
landed, in three different files, all of them long-standing: `add_child` on a null container nine
times per run of `check_maze_chase`, a headless `save_png` on a null viewport texture in
`check_lab_hint` (whose debug screenshots had therefore **never** been written by the suite), and
a stale `current_scene` in `count_apparitions` on every scene reload. Parse errors mean *the test
never ran*; these mean *the test ran on fire*. ⚠️ When sweeping for them yourself, redirect
`> file 2>&1` and **not** `2>&1 > file` — the latter sends stderr to the terminal and greps a
stream that cannot contain the error. ⚠️ And never write
`bool(node.get("flag"))` in a test: a missing property throws, the throw aborts `_process` before
the stage counter AND before the timeout check, and the test loops forever (Issue 45 — one run hung
28 minutes on a 30-second timeout).

⚠️ **Two guards were pinned to ONE SCENE and nobody noticed (2026-08-16, Issue 71).**
`check_note_mounting.gd` hard-coded `level_1.tscn` and `check_wall_overlap.gd` defaults to it while
`run_tests.sh` invokes it bare — so the two checks that exist for "is this prop actually on a wall"
and "do two surfaces coincide" had run on **one level out of nine** since they were written. The
House's third note was found floating 1.40 m in mid-air by hand, in a playtest, with both green.
⚠️ **RESOLVED PROPERLY ON 2026-08-17**: both are now **sweeps over every scene in the game**, and
the wrappers that used to enrol a level one at a time are deleted. See "Coverage by construction"
at the top of this section. A level's peculiarities live in the guard's own per-scene row — the House's cellar is not in
`ROOMS`, and it has one note per room so the same-room separation pass legitimately finds zero
pairs.
⚠️ And a positive control built from one scene's literal coordinates **degrades into a no-op
everywhere else while still printing PASS** — `check_note_mounting.gd`'s controls are now derived
from the scene under test.

⚠️ **The Backrooms was wired on 2026-08-17 and produced 10 + 8 + 5 findings on the first run** —
the third level in a row where the first run of an existing guard found double digits, which is
the whole argument for the wrappers costing three lines each. Wiring it also fixed two faults in
the guards themselves, both of which mattered game-wide:
- **`check_note_mounting.gd` was not world-space** (cross-level X32). `_room_of()` / `_in_doorway()`
  compared a WORLD position against the level script's LOCAL `ROOMS`/`DOORS` table. Every level
  built at the origin got away with it; the Backrooms builds three zones in ONE SCENE at 0, +200 x
  and −200 x, so all four of its notes read as "not inside a room". `_origin` / `_zones` fix it.
  ⚠️ `check_wall_overlap.gd` never had this bug — everything in it is `global_position` — and the
  two sibling guards differing, with neither saying so, is the trap.
- **It also assumed every prop faces +Z.** A note LYING ON A TABLE is thin in Y, and the entry-arm
  clue note (the first thing read in that level) correctly reported "NOTHING behind it" and
  uselessly: there is nothing behind it, there is something UNDER it. `_front()` now takes the
  prop's own mesh's thin axis. Everything that passed before is thin in Z and measures identically.
- **`check_wall_overlap.gd` probed a flat prop at its CENTRE POINT ONLY** (X34) — meaningless for
  the Flood's 60 × 60 m water sheet, i.e. 3600 m² tested at one pixel. `_quad_grid` (default **1**,
  i.e. unchanged) samples N × N points, `_quad_ignore` waives documented cases with an asserted
  size, and `_self_test_quad_grid()` proves the mode catches something grid 1 misses, on the scene
  under test, every run.

⚠️ ~~**Four levels still have no `check_wall_overlap` wrapper** — KONTUR, Breach, Nightmare, Void.~~
**Retired 2026-09-19** — true before the H1 sweep rework, false since. There are no wrappers to have:
`check_wall_overlap.gd` iterates `tests/lib/scenes.gd` and sweeps **every** scene (see the top of
this file, and `check_wall_overlap.gd:108` — *"A ROW IS AN OVERRIDE, NOT AN ENROLMENT"*). A level
cannot be left out by being forgotten, only by being written down.

⚠️ **Three guards and a probe added 2026-09-07, and two of them found things nobody had reported.**
- `check_apparition_framing.gd` — **is the apparition on screen when it appears?** Nothing had ever
  asked. 24 poses in the Lab, deliberately half easy and half hostile, with the two passes of
  `_find_spot()` asserted separately: **8 of 23 in frustum before the fix, 23 of 23 after.**
  ⚠️ Its first version was itself vacuous — a uniformly hostile sample reported "19 of 19 in
  frustum, 19 of 19 needed the camera turn", which is a pass that proves only the fallback and
  would go equally green on a build that seized the camera every single time.
- `autoplay_lab_nook.gd` — **how far away is the nook figure when it appears, on a real walk?** The
  number the player's report was about, which nothing measured. It walks the wing, throws the
  breaker through the shipping ray, and covers both playstyles. It immediately found a second
  defect: the stand-still branch produced **no figure at all** (Issue 171).
- `check_cellar_key.gd` — extended from "the key gate works" to "**and the doorway is clear
  afterwards, on the walking route**". It had asserted blocked/blocked/blocked and stopped, and
  called `interact()` directly rather than going through the raycast. It also now asserts every
  one of the gate's meshes is ON the gate (Issue 170), at a **5 mm** tolerance — at 2 cm it caught
  two of the three displaced parts, which is how the third ships.
- `probe_breach_creature_path.gd` — a `probe_*`, written **before** any fix, as an assertion that
  should FAIL on the current build. It does: Object 12 walks through walls (Issue 172). Two of its
  three phases are controls, because the first question a red result raises is whether the probe is
  wrong.

⚠️ **Four guards added 2026-08-15 that nothing else names.** Each exists because the feature it
protects had already shipped broken once:
- `check_interact_reach.gd` — every interactable in Levels 6/7 answers E from a realistic
  distance AND from 25° off-axis, **aiming at the mesh, never at the collider**. Aiming at the
  collider is what let the previous version pass against colliders a player could not hit.
- `check_turn_mirror.gd` — the mirrors reflect, and the figure is on `MIRROR_ONLY_LAYER` so it
  is in the glass and NOT in the corridor. A reflection cannot be asserted; the wiring can.
- `check_lock_input.gd` — typed digits land, and the Esc hint survives a wrong guess.
- `check_corridor_repeats.gd` — no sound in the Corridor is a loop, and the score outlives the
  296 m hush.

⚠️ **`check_reachable.gd` (2026-08-17) is the guard nobody had: CAN THE PLAYER STAND WHERE THIS
OBJECT IS?** Every other geometry check in this project inspects a relationship between two objects
— `check_wall_overlap` asks *do two surfaces coincide*, `check_note_mounting` asks *is this prop on
a wall*, `check_doorways` asks *is a doorway sealed* (and only for `RoomBuilder` levels). A room no
route reaches is invisible to all of them, which is how the Backrooms Sprawl kept **eight sealed
alcoves and ten unreachable objects** through two playtests and four scene-parameterised guards
(Issue 90). It flood-fills the standable space from the spawn with the level's own capsule (0.125 m
grid, lazy BFS) and then drives the SHIPPING interact ray from up to 20 reachable cells per prop,
aiming at the **mesh**. **All nine scenes, 26 s.** Four verdicts, not two — `REACHABLE` / `INERT`
(the ray reaches it, the prop is refusing: `LabLocker` before its note) / `CONTAINED` (an ancestor
interactable is reachable: a page inside a drawer) / `DORMANT` (`visible == false` or
`PROCESS_MODE_DISABLED`, read from the node) — plus gates that open are opened for the fill and put
back before probing. That taxonomy is the whole difference between a guard and a nuisance.
⚠️ Its permanent control re-seals the Sprawl alcove that holds `SprawlNote` and requires the note to
be reachable BEFORE and unreachable AFTER; the first version asserted only the second half and was
green while measuring nothing. ⚠️ Its fill capsule is **2 cm narrower than the player's**, because a
grid of static placements is strictly harsher than a `move_and_slide` body — at full width a 6 mm
clip against the House cellar ramp hid the entire cellar. Companion: `check_sprawl_alcoves.gd`,
which asserts the Backrooms cut itself (8 mouths, capsule fit, 504 floor-continuity samples, shell
closure, dread coverage, the note's readability at ±25°, and the phone's freeze/pause guards).

⚠️ **`check_shell_sealed.gd` (2026-08-17) is the guard for the OTHER half of that idea: CAN THE
PLAYER SEE OUT OF THE LEVEL?** `check_reachable` asks whether a space can be entered; nothing asked
whether the shell around it is closed, which is why the `fix-void` skill exists as a manual
protocol. The Sprawl shipped with four 3.40 × 4.50 m holes in it and the player photographed the
sky (Issue 92). ⚠️ **Its interior sweep runs on ALL NINE LEVELS since 2026-08-17** — the perimeter
and alcove passes are Sprawl-specific, but "from everywhere a player can stand, is every horizontal
ray stopped, is there floor under them and ceiling over them" is a question every level has an
answer to and only one had ever been asked. Bounds and FLOOR LEVELS are derived from the level's own
CSG (the House has three storeys: ground, ramp, cellar), and every non-Backrooms scene gets a
control that deletes a real outside wall in front of a standable point and requires the sweep to see
daylight. Result: 0 escaping rays everywhere except **THE VOID, which has no shell at all — 142 rays
from 48 standable points, filed as an exact count in `backlogs/08-void.md`.** It fires ~66 000 rays
over all three Backrooms zones — a 0.25 m lateral perimeter
sweep at six heights, an outward-hemisphere fan from five points in each of the eight recesses, and
a 1.5 m interior floor grid filtered to places a 0.4 m capsule could stand — and every ray must be
stopped. ⚠️ A `GlitchWall` is walk-through **on purpose**, so a ray that hits nothing is forgiven
only if it crosses one's visible mesh AABB; that exemption list is COUNTED (exactly 8: 1 Lobby, 4
Sprawl, 3 Flood) with the same discipline `check_wall_overlap.gd` puts on `_allow`. ⚠️ **Two
permanent controls**, because the perimeter one proves nothing about the interior sweep's filters:
`AlcBackE1` is freed and both sweeps must go red. ⚠️ **Read its constants before believing a red.**
Three quarters of its first day's findings were its own sampling — a sample buried in a 0.2 m wall
slab (from inside a shape, every ray reports clear, and `hit_from_inside` does NOT help because CSG
collides as a concave trimesh; `intersect_point` is the query that answers it), a 45° ray threading
a room corner, and an eye 0.6 m above a 2.6 m ceiling because it stood on a 0.4 m platform. Each
lesson is written at the constant that removed it (Issue 94).

⚠️ **Five more added 2026-08-16, all for the Corridor, and four of them are the SAME missing idea:
is this flat thing the right size, in the right place, and shown undistorted?** Between cross-level
X1, X2 and Issue 35 that question had been re-derived by hand in every level pass and asserted
nowhere.
- `check_wall_overlap.gd` pointed at the Corridor — the longest procedural level in the game,
  which it had **never been run against**. First run: 32 findings. Carries the project's first
  documented **waiver list** — the six corners' floor/ceiling slabs, which `_build_geometry()`
  overlaps on purpose — and the waiver asserts its own size and refuses any pair whose two boxes
  stop sharing one material instance.
- `check_prop_mounting.gd` (`check_corridor_mounting.gd` until 2026-08-17) — the
  **maximum**-clearance half X1 has always been missing. A minimum-only check cannot see a prop that
  has drifted away from its wall, which is exactly what the player photographed.
- `check_art_aspect.gd` (`check_intro_art.gd` until 2026-08-17) — the aspect check written for the
  Intro, finally run somewhere else. It found 22 of 39 surfaces stretched here.
- `check_mirror_frustum.gd` — the framing of a reflection, which *can* be asserted even though the
  reflection cannot.
- `check_painting_fall.gd` — 200 positions along the path; the only prop in the game that was
  spawned at an unvalidated random offset.
⚠️ **`check_wall_overlap.gd` also stopped being blind to `BoxMesh`.** Its prop check collected
`QuadMesh` only, so the Corridor's doors and plate, the House's furniture and `intro_room.gd`'s
wheelchair were invisible to it in *both* directions. Solid props are now compared by FACE PLANE
(the same `_faces_fight` rule the geometry uses) — not by the centre-point test the quads use, which
produced 28 false positives across the Lab and the House, because a fixture flush to a ceiling and a
closed drawer in a counter are both legitimately "inside" something.

⚠️ **And one added 2026-08-16, for the bug class that had bitten three times in a week** (Lab Issues
65/67, House Issue 76): `autoplay_house_route.gd` — **can an interactable SEAL A ROUTE by being
used?** `autoplay_exit_reachable.gd` walks every level's exit with the world in its *pristine* state,
so nothing in the project had ever opened a prop and then asked whether you could still get past it.
Two halves, and **measurably neither subsumes the other**: a capsule flood fill of the whole ground
floor from a FIXED anchor (no previously-reachable free floor may become unreachable; every room in
`ROOMS` must still have reachable floor) catches **isolation**, and a real `ai_*` walk from the
kitchen counter to the cellar gate to the exit lock catches **narrowing**. Restoring the broken
drawer reddens the walk hard and leaves the flood fill entirely green.

Test naming: `check_*` assert, `walk_*` drive a physics body along a route, `autoplay_*` drive the
**real** player through `player.gd`'s `ai_*` surface (see `tests/autoplay/autoplayer.gd` for why
that exists rather than simulated key presses), `screenshot_*` need a render target so they run
**without** `--headless`, `probe_*` are throwaway diagnostics kept only when they document
something durable.

`.claude/agents/game-tester.md` is a subagent that runs the suite before a hand playtest,
reproduces failures with targeted probes and reports. It is explicitly forbidden from changing
difficulty constants — that is always the user's call. It is distinct from the `game-testing`
SKILL, which is the human-in-the-loop playtest protocol.



### Void human playtest regression coverage — 2026-09-20

The geometry-only `walk_void` remains separate from `walk_void_live`, which retains and activates
all five lethal creatures and uses the player's real movement, note/puzzle ray, and exit interaction.
`check_void_alignment` covers incorrect viewpoint rejection, the visible seal, torch-off solving,
southern-branch footing and event snapshots. `check_stalker_motion` has actual wall/door/gap
fixtures, measured mesh freeze and a contact lunge. `check_transition_race` drives the real shared
door and fatal paths in both orders, duplicate interactions and replacement scenes. All are registered
in `tools/run_tests.sh`; sample counts and positive controls prevent vacuous passes.


### The Void's 2026-09-20 playtest pass

`check_void_stare` (new): every Void stalker whispers; a 7 s stare fires exactly one hallucination
and the body never moves while watched (the dismissal included), then retreats on the first
unobserved frame; the panic-bar lie is a shader override that reverts and never moves `_panic`;
nothing fires with input frozen; on the tiles the blink is substituted. `check_stalker_motion` gains
the observed-frame-zero-displacement assertion on both the direct and the real physics path, with the
retreat's landing as its control. `check_void`, `check_void_alignment`, `walk_void`, `walk_void_live`
extend to the loop ladder (note refused below lap 2, the plug present at lap 2 and gone after the
read), the three viewpoints (each solves only its own set; a wrong press costs exactly 6 and opens
nothing; the seal stands until the third), the Morgue's new rect, and the shard → cradle → plate chain
(the plate intercepts the twist note's ray until the cradle is done). `check_doorways` learns
`LoopWallPlug`; `check_reachable` learns `SanctumPlate` (an occluder opened through
`move_aside_instantly()`, without which the twist note reads UNREACHABLE — the proof it can fail) and
`LoopWallPlug`. ⚠️ `walk_void_live` read `current_scene` during the scene switch and reported the
ending as missed once (2026-09-20, 24/25 with the human exit working); it now waits for a scene.


### The Void's 2026-09-20 pass 2 — a coverage probe as a guard

`check_void_alignment` now carries the coverage sweep that set the puzzle's tolerances: a 0.3 m grid
over each viewpoint tile at eye ± 0.15 m, facing ± 15°, asserting ≥ 70 % of cells align per view, that
no adjacent tile centre aligns, and that from an adjacent tile the prompt is absent AND the shipping ray
finds no keystone (the control that would have caught the evening run's 20 wrong presses). The
instrument itself is `probe_void_view_region.gd`, kept outside the suite. `check_void` asserts the loop
note has no collider and is invisible before lap 2, that the flicker hands the lamp back, that the new
sounds load and the bed loops. `check_void_stare` samples the eyelids meeting and parting.
`check_stalker_motion` proves the Void-only speed export (2.4× per tick) leaves the default at 0.25 m
per 12 ticks. ⚠️ Issue 228: a shared speed export re-prices every test that waits a fixed time next to
a creature — `check_void`'s watch-only control staged its own death at 3.0 m/s until it was moved.


### The Void's 2026-09-20 pass 3 — gates with controls, and two defects only a picture caught

`check_void_alignment` (121) asserts a socket refuses E with no anchor and with the wrong one, accepts
the right one, and that the seated keystone carries its view's family; `check_void` (93) measures the
child room, the seventeen drawers (exactly one page, through the ray), the hidden shard (unreachable by
ray before the table rearranges — a standing red control), the step-through's 1.2 s against a 0.76 s
control, and the exit's eight slabs off their true sub-rects before the assembly and on them after;
`check_transition_race` (29) races a death against the 1.2 s assembly — with `begin_transition` moved
below the animation it goes 3 red, the proof the token-first order is load-bearing. `walk_void` gained a
wall-clock deadline (Issue 224's hole). ⚠️ Issues 232 and 233 — a page the camera could not see into an
open drawer, and an assembled door that was a red grid because a seam lives in the mesh size — were
caught only by reading the screenshots; every guard was green on both. `check_flood_drowned` flaked once
in two full-suite runs (a Backrooms 2.0 s knock window, unrelated); filed as cross-level X70.


### The Void's 2026-09-20 pass 4 — the frames harness, and two lessons that recurred the same day

`check_void_frames` (75 checks, six seeded scrambles, ~110 s; `-- --seeds N` narrows it, `-- --trace`
prints panic transitions) is the `maze-tester` shape for THE HALL OF FRAMES: every scramble solvable by
the answer order, a wrong step never strands (the player lands on floor inside the room), every dwell
reachable from a human stance, the finish reachable, the note refuses while carrying (control) and
reads empty-handed, the figure never carries a collider or a `ScaryObject`, and no frame changes while
it is in view (control: the observation check removed → fails and names the slot). `check_void` (142)
proves the Morgue's west wall solid at frame 0 and that the plug is what stops it, E suppressed during
the lunge (control), the drawing's swap, the open drawer, the reacting Hall2 frame, the loop swap.
⚠️ Both Void guards **unregister `RandomAmbient`** before any zero-panic assertion (Issue 240). ⚠️ Issue
228 recurred in a brand-new stage the same day it was filed (Issue 238), and `walk_void_live`'s three
deaths in nine were the room NEXT to the one the bot was in (Issue 239) — a stare stance must have no
line of sight to any other stalker and stay outside `GAZE_RANGE`. The screenshot pass now runs five
in-scene actions before shooting (settle the hall, open the door, swap the drawing…), so the images are
of states the guards reached, not poses.

**The Void, pass 5 (2026-09-21).** `check_void` grew to 206 checks: a thirteen-stance sweep along the
Sanctum's west wall proves the twist note opens nothing while the stone stands (control: the refusal
removed → seven stances open the page) **and asserts the grazing band is NOT empty** — the plate cannot
close it, and a guard that assumed it could would be lying (Issue 242); the wedged shard refuses, frees on
the table's rearrangement and is takeable after; the gurney's touch volume passes 0.33 m above the
bed-slat approach ray (the first draft swallowed the slat — caught by the control); the corridor charge
fires once southbound, never northbound, with `_panic` unchanged and creature C protected. ⚠️ Three
lessons about the harness itself: `Object.call()` on a renamed method unwinds the stage and fails
nothing — `check_void` printed PASS with eight checks gone, so its count floor is now within ten of the
real count (Issue 245); its reload guard compared stage LABELS as if they were ordered (Issue 246); and two
brand-new stages staged their own deaths on creature C (Issue 228, a fourth and fifth time). `walk_void`
gained a 2 m corridor detour, because the shipping route uses the step-through and nothing else walks
the corridor southbound. The parent re-ran the wedged-guard control by hand; the first attempt matched
nothing and ran green — **a control with an empty diff proves nothing, check the diff first.**
