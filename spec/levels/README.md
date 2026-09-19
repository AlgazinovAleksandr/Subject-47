# Levels — shared systems and conventions

### Random Apparition (the "monster" — `apparition.gd`, Session 10)
- ⭐ **2026-09-15 (L2, the user's call): `apparition_snarl.ogg` (user-supplied) is the ARRIVAL sting
  of every HOLD apparition** (`ARRIVAL_STING_DEFAULT`); the fatal rush plays `all_levels_screamer`
  (my call, flagged). The 2026-09-07 paragraph below that puts the snarl on the rush is history.
A reusable figure that materialises at a scripted-but-randomised moment and tests the player's
**response**, not their reflexes. `Apparition.spawn(parent, rule, pos, teach)` returns the right
node for one of three rules:
- `RULE_HOLD` (the new flagship): on `appear()` it fades in ~7 m ahead, where the player is
  already looking, with a low drone, and adds steady dread. **Survive by NOT fleeing** for
  `HOLD_TIME` (4 s) → it fades; **flee and it rushes** → fatal `Screamer.trigger()` (or, in
  teach mode, a survivable `flash_scare`). Fleeing (`_is_fleeing()`, Session 11) = `is_sprinting()`
  **OR** backing away — the horizontal distance growing past `_spawn_dist + FLEE_MARGIN` (0.7 m).
  Turning the camera while holding your ground never trips it (fair; matches "stand still until it
  fades"). Enforces "Walk. Do not run." — the Lab briefing note states the rule.
  ⭐⭐ **CLOSE, LOUD, WITH A STARTLE GRACE (2026-09-10, capture #2, the user's choice: ALL HOLD
  apparitions).** `APPEAR_DIST_MIN 1.8` / `MAX 3.0` (was 2.5 / 7.0); every arrival plays
  `arrival_sting` (default `all_levels_screamer`, an `AudioStreamPlayer3D` "ArrivalSting" at 0 dB /
  `max_db` 6 / unit 8, fired at t = 0 or at `TURN_TIME * 0.55` when the camera is being turned)
  inside the drone's 0.6 s pre-dip; KONTUR's gate 7 no longer overrides `appear_audio`. And
  **`STARTLE_GRACE` 0.7 s**: `_is_fleeing()` is not evaluated for the first 0.7 s after arrival and
  `_spawn_dist` is re-based at the boundary, so the flinch away from a scream at 2 m is forgiven
  and the DECISION to run is still a death (SCARY §8.11's shape). `test_apparition.gd` (sprint in
  the grace → survived; at 1.0 s → rushed) and `check_apparition_framing.gd` (distance in
  `[MIN_DIST − 0.05, √(MAX² + nudge²) + 0.05]`, the sting playing). The next paragraph's 2.5 / 7.0
  are the old numbers.
  ⚠️ **Distance is RANDOMISED per appearance** (BACKLOG #10): `APPEAR_DIST_MIN 2.5` ..
    `APPEAR_DIST_MAX 7.0`, replacing a single fixed value (7.0, then 4.0). A fixed distance
    frames every appearance identically, so the second one is never a surprise.
    `FLEE_MARGIN` is therefore **proportional** — `maxf(0.7, _spawn_dist * 0.2)` — because a
    flat 0.7 m is a 10% allowance at 7 m and a 28% allowance at 2.5 m, and an instinctive
    half-step back from something that appeared on top of you would otherwise be a death.
    Sprinting is still an instant fail at any distance, so the rule itself is untouched; only
    the flinch is forgiven
- ⚠️⚠️ **BUG_FIX.md 3.3 WAS APPLIED TO THE WRONG FUNCTION, AND THIS ENTRY DESCRIBED THE INTENDED
  STATE FOR MONTHS (corrected 2026-09-07, Issue 168).** The purpose-made `apparition_snarl` was
  commissioned for the rush and wired into `_play_drone()` — the APPEARANCE — while `_play_sting()`
  kept the House's door creak. Measured: appearance `apparition_snarl` at **−2.39 dBFS** loudest-300
  ms, fatal rush `creak` at **−34.40**. *The telegraph before a lunge that kills you was 32 dB
  quieter than the thing it telegraphs.* They are now on the events they were made for, which is
  also the right signal: a HOLD apparition is survived by standing your ground, and a snarl on
  arrival argues for the flight that kills you.
- ⚠️ **`max_db` WAS THE BINDING CONSTRAINT AND NOBODY HAD LOOKED.** Godot clamps
  `volume_db + attenuation` to `max_db`, default **3.0**, and `unit_size 10` reaches +12.0 dB at
  2.5 m — so the emitter was pinned to +3 at every distance under 7.1 m and `volume_db` did nothing
  at all in the range the apparition appears in. Ceiling 3.0 → 6.0, gain −2 → +2, which lands the
  drone within 0.2 dB of where the snarl was. ⚠️ **The real lever was neither**: both files are at
  or within 1 dB of full scale under a −0.5 dBFS Master limiter, so `HoldBreath.dip()` was added —
  the same 0.6 s pre-silence that made the black flash work, on the one scare in the game with no
  duck at all
- `RULE_STARE` / `RULE_LOOKAWAY` just spawn the existing `CreatureStalker` / `CreatureSmiler`
- **Fairness rule:** each rule's first encounter is `teach=true` (survivable) so the player learns
  the tell before it can kill — same philosophy as the Void's `CreatureA` + `START_GRACE`. The Lab
  hosts the taught HOLD apparition; the House reuses a non-teach one in the cellar
- ⭐⭐ **IT APPEARS WHERE YOU ARE LOOKING SINCE 2026-09-07** (the user: *"it appeared when I was not
  looking at it. Let's force the creature appear when you look at it - in the worst case we can
  force the camera spin"*). `HEADINGS_DEG` sweeps the full circle and the camera's 75° VERTICAL fov
  is **±53.75° horizontally** at 16:9, so **five of the ten headings were off-screen by
  construction** — and `LATERAL_NUDGES` reaches ±1.6 m, a further 45° at the 1.6 m floor. Measured,
  **8 of 23 placements from hostile poses were in frustum**. `_find_spot()` now runs the fan twice:
  pass one accepts only candidates inside `Camera3D.is_position_in_frustum()`, pass two is the old
  behaviour verbatim, and if only an out-of-frame spot fits the camera is brought to it with
  `turn_to_face()` under a brief `freeze_input()` (`level_1.gd`'s nook reveal, which solved this
  same lottery in 2026-08-16 and was never carried across). **23 of 23 after; the easy poses still
  do not seize the camera.** ⚠️ **The test is the FRUSTUM, never a heading whitelist** — the nudges
  move the realised bearing, and a whitelist says nothing about PITCH. ⚠️ **The freeze is fairness,
  not framing**: `_is_fleeing()` is horizontal distance growing, so a figure behind you turns
  walking forward into a flee, and the flinch away from a loud arrival must not be scored as one.
  `SCARY.md` §8.11. ⚠️ It must zero `velocity.x/z` by hand (Issue 49). `check_apparition_framing.gd`
- **Visible spawn.** ⚠️ The old one-ray version *created* BACKLOG #8 ("sometimes the monster
  appears in the textures"): `clampf(wall_hit - WALL_MARGIN, MIN_DIST, APPEAR_DIST)` let the
  `MIN_DIST` floor **override the wall it had just detected**, so facing a wall 1 m away placed
  the 1.6 m-wide billboard at 1.6 m — inside it. `appear()` now fans over 10 headings x 3
  distance fractions x 9 lateral nudges, validating each candidate with `_fits()`, and
  **aborts (`queue_free`, no figure) if nothing fits** — a skipped apparition beats an embedded
  one. `_fits()` uses **rays only**: line-of-sight from the player's eye (which also catches
  "the point is inside a wall", since the segment must cross its near face), a head-room ray, a
  top-down column ray (catches standing inside a bench), and a 16-ray horizontal fan at
  `FIG_FIT_RADIUS`. ⚠️ **Do not switch `_fits()` to `intersect_shape`** — a shape query against
  CSG reports NOTHING when wholly inside the slab, i.e. it silently approves exactly the case
  being rejected (Issue 40; `tests/probe_shape_vs_csg.gd` is the evidence). ⚠️ The fan is 16
  rays, not 8: at 45° spacing every ray flies through a DOORWAY's opening and reports clear
  while the billboard's edges are buried in the jambs. Locked down by
  `tests/check_apparition_clearance.gd`, which also asserts the fix did not make the apparition
  stop appearing.
- **`ApparitionDirector` (`apparition_director.gd`, BACKLOG #6):** one node, added as a child
  by `level_1.gd`/`level_2.gd`/`kontur.gd`, replacing the three identical `DEBUG_APPARITION` +
  `DEBUG_APPAR_INTERVAL = 60.0` countdowns they each used to carry. Levels now only say
  *whether* they want random apparitions (`const RANDOM_APPARITIONS`); the director owns
  **when**. Fires on a randomised `MIN_GAP..MAX_GAP` (90-180 s) after a `LEVEL_GRACE` of 45 s,
  and only when the appearance would be coherent and fair: no paused tree / open `NoteUI`,
  `player.is_input_frozen()` false (a HOLD apparition kills you for fleeing, and a player
  clamped in a beartrap escape or the locker push *cannot* demonstrate they are standing their
  ground — the Issue 18 double-jeopardy shape), panic below 60%, at least
  `MIN_GAP_AFTER_AMBIENT` since `RandomAmbient` last fired, and any level-supplied `suppress`
  callable false (the Lab passes `_in_breaker_nook`).
  ⚠️ `MIN_GAP_AFTER_AMBIENT` **must stay well under `RandomAmbient.MIN_INTERVAL` (18 s)** — at
  30 s the condition was effectively unsatisfiable and the feature silently produced ZERO
  apparitions in a 400 s run (ISSUES_SOLUTIONS Issue 39). `OVERDUE_AFTER` drops the soft
  conditions after 60 s of being held back, so an appearance can be delayed but never cancelled.
  ⚠️ **`ApparitionDirector.arm(apparition, force_teach)` is the ONLY way a HOLD apparition
  should be made to appear** — it owns the global `GameState.apparition_taught` ledger, so the
  first one in a run is survivable *wherever* it happens. All four scripted encounters (Lab
  corridor, House cellar, Backrooms Flood x2) go through it. Before this the teach flag was
  hard-coded per site, so a player who missed the Lab's trigger could meet a lethal one first.
  Measured by `tests/count_apparitions.gd`, which now **asserts** a minimum count and gap, and
  counts *appearances* (`visible`) rather than instantiations.
- ⚠️ **Don't hang a wall panel/prop on a room's only doorway wall.** `wall_point(room, side, …)`
  returns the wall *centre*, which is exactly where a doorway sits — a decal/mirror/desk collider
  there silently blocks the entrance (Session 11 bug: the Records warning sign sealed the third
  breaker room; the bathroom mirror, observation desk and kitchen counter were the same class).
  Check the `DOORS` table and place props on a wall without a doorway
- ⚠️ `apparition_figure` must be a **transparent PNG** (a `.jpg` has no alpha → the billboard shows
  as a solid rectangle). Code prefers `.png` then `.jpg` via `Apparition._resolve_tex`

## Level progress & backtracking (BACKLOG #30)

Reported as *"the level always starts from the beginning ... I will need to pass all the levels
from the beginning, which is not how it should work."* It was literally true:
`advance_level()`, `go_back()` and `restart_current_level()` were the same function in three
coats — all called `start_current_level()`, which called `reset_level_state()` and reloaded the
scene, rebuilding it from `_ready()`. Every puzzle's state lived in a level-script local.

**The contract.** A level script MAY implement:

```gdscript
func save_progress() -> Dictionary      # called by GameState on the way OUT
func _restore_progress() -> void        # the level calls this itself, LAST in _ready()
```

`GameState._capture_progress()` calls the first via `has_method`, so a level that implements
neither simply behaves as it always did. `get_level_progress(n)` returns `{}` for an unvisited
level. What each stores:

| Level | Keys |
|---|---|
| 1 Lab | which breakers (by node name), power, locker unlocked/moved, keycard, scare one-shots, **and the Records bank's randomised hint slot + which drawers were left open** |
| 2 House | map solved, key carried, cellar open, code entered, scare one-shots |
| 3 Corridor | furthest path distance reached (there is no puzzle state — the level IS the walk) |
| 4 Backrooms | which of the three zones, the loop counter, which of the Flood's six searchable objects have been emptied, **and the plate's state — fragments set and fragments still in hand** (restoring one without the others strands the player in a wing with silent objects and an empty frame) |
| 5 KONTUR | the 8-gate ledger, strikes, forfeit, hammer, held bottle, and `_dark_x` |
| 6 Breach | `creature_defeated` |

⚠️ **A DEATH still wipes the level.** `restart_current_level()` erases that level's snapshot on
purpose — the no-checkpoint fail philosophy in `COMMENTS.md` is deliberate, and this feature is
about *navigation*, not about softening failure. `tests/check_level_resume.gd` asserts both
directions.

**Level attempts** (`GameState.level_attempts` + `get_level_attempts(level)`, 2026-07-27) is the
deliberate counter-example: it records how many times you have *died* on a level and therefore
**survives** the wipe above, cleared only by `go_to_main_menu()` (i.e. per run). It is incremented
by `restart_current_level()`, so it counts deaths and nothing else — walking back and forth through
back doors never touches it. Level 6 is the only consumer so far (the 30 s → 10 s familiarization
window). ⚠️ It is **not** a difficulty-scaling system; adding one would need its own decision.

⚠️ **KONTUR must restore its randomisations too** (`_dark_x`, and which door is black).
Restoring the gate ledger while re-rolling the answers would mark gates passed whose puzzles now
have different solutions.

**Directional spawn.** `GameState.entered_from_ahead` is true when the player came back through
the NEXT level's back door. Each level then places them at its **exit** end rather than its
entrance — you came back through the exit, so that is where you should be standing. For the
320 m Corridor this is the whole difference between a walk and a re-run; it uses the saved
furthest distance, capped short of the noclip trigger so re-entry does not immediately fall
through again.

**The Backrooms back door.** ⚠️ A deliberate softening of "no way out behind you". The Backrooms
is entered by a one-way noclip fall and its entry arm was capped, so it was the only level with
no back door at all — and KONTUR's back door leads *there*, which meant walking back from KONTUR
stranded the player with no exit but re-clearing all three zones. There is now one blood-red
door in the entry cap, returning to the Corridor.

**The notes journal** is the cheaper half of the same problem — see the `JournalUI` autoload row.
Most players who want to go back want one sentence from one note, and TAB gives them that
without moving.

