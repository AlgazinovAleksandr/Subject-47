# Level 7 — THE NIGHTMARE — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.


> ⚠️⚠️ **THE AUTHORITATIVE DESIGN FOR THIS LEVEL IS `spec/design/DUNGEON_NIGHTMARES.md` PART B**,
> together with its "Deviations from this spec — the 2026-09-12 redesign" section (D1–D8, marked
> *do not re-open*). This file is the **shipped-state summary** and a pointer to it — it must never
> become a second copy of that design. If the two ever disagree, DUNGEON_NIGHTMARES Part B plus its
> D-overrides wins, and this file is what gets corrected.

## SPEC

**Level 7 — THE NIGHTMARE (the dungeon)** — `dungeon.gd` + `dungeon_gen.gd` + `dungeon_rooms.gd` + `dungeon_map_ui.gd` + `dungeon.tscn`
- ⭐ **2026-09-13 (D1/D2):** candles **carry 6, 8 caches, a lit sconce refunds one**
  (`_on_sconce_interact`); the hunter's yaw is **eased at `TURN_RATE_DEG`** while the body keeps the
  routed line, rooms have hysteresis across shared planes (`_steer_room`), and doorway arrival is
  along the doorway's normal AND inside its opening (Issue 204). Router sweep 0 clipped; bot 3/3.
⭐⭐ **REDESIGNED 2026-09-12 ON THE USER'S VERDICT *"very simple to get killed"* — it is now HARD TO
LOSE and easy to get scared.** The decisions (D1–D8) are locked in `DUNGEON_NIGHTMARES.md`'s
"Deviations" section; that file's Part B is otherwise still the design, and this is the shipped
summary. **Not yet hand-played after the redesign.**
- ⚠️ **NOTHING IN THIS LEVEL KILLS. The panic bar is the only death** (D1). `check_dungeon_hunter.gd`
  greps `dungeon.gd` and `dungeon_rooms.gd` for `Screamer.trigger(` and drives every former death path
  live. Before this the level had six independent instant deaths and a six-seed bot run won 0
  (Issue 188). Do not add a fatal entity back without the user.
- **The hunter** (node `TheHunter`, `creature_object12.gd` with additive exports — `model =
  "parasite"`, `lethal_contact = false`, `relocate_when_lost = false`; the Breach's Object 12 is
  byte-identical in effect): the supplied **Parasite** model (`parasite.glb`, `CreatureAnim.MODELS`),
  chase **3.4 < the 4.0 walk**, patrol 1.5, hunts BY EAR (`_tick_noise`: sprint r 14, spark 12, door
  slam 16, sconce 18), screams every 10–20 s while hunting (`matron_shriek` / `parasite_growl`), the
  chase cue (`parasite_chase`, a 21 s loop) rises ONLY with CHASE + line of sight and fades ≤ 1.6 s
  after it is lost, waves ~60 s on / 30 s off, **wakes at sconce 3**, routed doorway to doorway via
  `set_portals(_gen.rooms, _gen.doorways)`. ⚠️ The cue and the voice live on the runtime
  **`"DungeonChase"`** bus under `Ambience` — the `"Dungeon"` bus is ducked −24 dB for the whole wave
  and would have silenced them (Issue 190).
  - **The catch** (`_on_hunter_caught`, D2): velocity zeroed → `freeze_input()` → `turn_to_face` →
    `HoldBreath.dip` → the body placed 0.6 m from the camera → `parasite_jumpscare` on Master +
    `jolt_camera` + **`CATCH_PANIC` 20** → it lets go, the wave ends, control returns. In-world, no
    fullscreen flash.
- **Still Ones** (`creature_stalker.gd`, `lethal = false`, `leash`, `watch_only`): a catch is a face
  flash (`dn_stillone_face.png` + `stillone_shriek`) + **12** and the statue topples for good.
  **Weeping Frames** ignite for GAZE PANIC ONLY and burn out inert (`set_ignites`, `_burn_out`).
  **The Hollow One is CUT** (`creature_hollow.gd` stays on disk, unused). **Beartraps are gone.**
  The spark (C) stays: a free light burst that wakes statues.
- **Room archetypes carry the scares** (D6, `dungeon_rooms.gd` — `build()` places props from parts on
  the doorway-free wall, `fire()` is one-shot and refused under a note/pause/freeze): gallery (a
  painting drops), scriptorium (a scrawl bleeds in — THERE IS NO WAY OUT / I FEEL I AM LOSING MY
  MIND …), cells (a leashed statue behind bars), well (the Child peeks over the rim), chapel (the
  Kneeling Man at the altar), crypt (a lid slides and the resident statue is standing in it), cistern
  (dark water, `UnseenWader`), **larder = the hunter's lair** (it appears 3 m behind you with LOS,
  `force_chase`, a 40 s wave even before sconce 3). The sconce count keeps TWO gates: hunter at 3,
  finale at 7.
  - ⚠️ **Floor props need a PROP-SAFE wall** (`DungeonGen.prop_sides()`: doorway-free, and no
    doorway in a perpendicular wall within `PROP_LANE` 3 m, because that doorway's line runs
    along the props). A chamber with none is re-dealt: entry chambers and the spawn → `cistern`,
    sconce chambers → a bench-less `gallery`, the bed chamber → a crypt with no sarcophagi
    (Issue 193; ~2.6 chambers per dungeon, counted by `check_dungeon_gen.gd`). Props sit within
    2.4 m of their wall and `SIDE_CLEAR` 1.25 m from the side walls, because the walkers aim door
    to door.
- **Generator** (`dungeon_gen.gd`, pure data): **24×24 lattice, 16 chambers**, `MAX_STRAIGHT` 7,
  sconces **≥ 3 rooms apart** (`SCONCE_MIN_GAP`, relaxed to 2 and counted in `sconce_relaxed`: 9 of
  200 seeds), `room_kinds` / `kind_of()` / `room_at(pos)` / `lair_room`, still exactly 7 sconces
  every seed. Measured over 200 seeds: 32–54 rooms, mean 39.9.
- **The found map** (D8, `dungeon_map_ui.gd`, **M** = `map` action): a folded plan on the
  Antechamber's candle rack (`MapPickup`); before it M toasts. Non-pausing `CanvasLayer` 48, drawn from
  the generator's room rects for `rooms_seen` only, lit sconces as amber discs, **never the player**
  (`check_dungeon_map.gd` greps the script for position reads). Closes under a screamer/pause.
- **The candle replaces the flashlight** (`candle.gd`): `kill_flashlight()` at entry; 60 s per candle,
  carry 6, `OmniLight3D` range 4.5, energy/attenuation 2.2/1.4 (the spec's 1.0/2.4 rendered black).
  **F** lights / blows out (blowing BANKS the remainder); **C** sparks free with a 1.2 s after-dip.
- **Darkness without fog** (§B7): black background, ambient 0.045, a 4.5 m light. Do not add a
  depth-fade shader.
- ⭐ The silence is still the tell: the hunter's spawn ducks the `"Dungeon"` bus and
  `set_no_decay(true)` — panic HOLDS, all the pressure is in what you do. Sprinting still deafens you.
- ⚠️ §B10's bans stand where they still apply and `check_dungeon_entities.gd` asserts them with a
  live `DarkZone` control: no `DarkZone`, no `DreadZone`, no `enable_standstill_panic()`, no
  `RandomAmbient`, no `ApparitionDirector`, no time limit — and now also no `CreatureHollow`, no
  beartraps, `TheHunter` non-lethal with `chase_speed < 4`, every statue and frame non-lethal.
- **Cross-level hints** unchanged (Lab morgue Trial 7 log, House cellar candle stub, the Hotel Vesper
  plate at d = 250). The PROTOCOL note's spark paragraph now hints at the map and the statues.
- `save_progress()`: `layout_seed`, `content_seed`, `sconces_lit`, `candles_held`, `in_dungeon`,
  **`map_found`, `rooms_seen`, `scares_fired`**. Seeds are RESTORED, never re-rolled; restored sconces
  are lit without firing their scares.
- ⭐ Waking is a video (`dungeon_wake.ogv`, `_after_blackout()`); going under keeps its 1.6 s fade.
  Both fades on the clip are added in post; the join is matched by LUMINANCE, measured — see
  `tests/screenshot_wake_cutscene.gd`.
- **Tests**: `check_dungeon_gen` (200 seeds) · `check_dungeon_entities` · `walk_dungeon` (8 seeds'
  ray passes at eye AND knee height, 2 seeds walked door to door — commit points along the doorway's
  NORMAL, Issue 194) · `check_dungeon_hunter` · `check_dungeon_rooms` · `check_dungeon_map` ·
  `screenshot_dungeon` / `screenshot_dungeon_rooms` (no `--headless`) · `autoplay/autoplay_dungeon.gd
  -- --seeds a,b,c` (asserts wins ≥ half the seeds and NO deaths; catches are counted, not evaded).
  ⚠️ Every walker budgets PHYSICS TICKS, never render frames (Issue 192).
- Win: light all seven sconces, sleep in the bed, leave by the Antechamber door. Fail: the panic bar
  filling. That is the whole list.

## NEEDS A PLAYTEST

⚠️ **THE NIGHTMARE HAS NEVER BEEN HAND-PLAYED SINCE THE 2026-09-12 REDESIGN.** The level was rebuilt
that day on the user's verdict *"very simple to get killed"* (D1–D8) and retuned again on 2026-09-13
(candles 4 → 6, caches 4 → 8, the sconce refund, the eased hunter yaw). Everything in SPEC above is
verified by headless guards and bot runs — `check_dungeon_gen` (200 seeds), `check_dungeon_entities`,
`check_dungeon_hunter`, `check_dungeon_rooms`, `check_dungeon_map`, `walk_dungeon`, `autoplay_dungeon`
— and none of it has been confirmed by a human at the controls.

Open for the first hand playtest:
- **Hard to lose, still frightening?** Six instant deaths were removed and the panic bar is now the only
  death. Nobody has felt whether that reads as sustained dread or as toothless.
- **The light budget after D1.** 6 carried + 8 caches + 7 sconce refunds against a 12–15 minute night
  is a measured budget, never a played one.
- **The catch** (`CATCH_PANIC` 20, in-world, no fullscreen flash): three catches without recovery fill
  the bar. Does a pursuer that cannot kill still read as a threat?
- **The found map (D8).** Whether players find it on the Antechamber's candle rack at all, and whether a
  map that never draws the player is orientation or frustration.
- **The wake video** (`dungeon_wake.ogv`): the join is matched by measured luminance, not by an eye.

⚠️ The dungeon is different every load — pin a seed with `-- --dungeon-seed N` so any capture is
reproducible. ⚠️ The rule that must survive every report: **NOTHING IN THIS LEVEL KILLS**; the panic
bar is the only death (D1). A request for a fatal entity goes back to the user, not into the code.

## DECISIONS & GOTCHAS

⚠️ **Dated ⭐ entries live at the TOP of SPEC, not here.** They carry the level's *current* state and
override the older prose beneath them — that is how `CLAUDE.md` was written, and why entries say
things like *"every paragraph below that says 320 m is history"*.

⚠️ **The top-to-bottom order is NOT strictly newest-first.** Measured 2026-09-19: `01-lab.md`'s
2026-09-13 entry sits *above* the 2026-09-14 entry that reverts it, and `04-backrooms.md:302` sits
*below* the same-day entry that supersedes it. **Read the dates; where they tie, read the code.**

Use this section only for rationale that leaves **no trace** in the level — something tried and
abandoned. Anything describing what the level *is* belongs in SPEC.

### Superseded claims — the 2026-09-19 spec audit

⚠️ **"carry 4" (candle bullet) → superseded 2026-09-13 by D1's carry 6.** The candle bullet in SPEC
said `carry 4` while the ⭐ 2026-09-13 entry above it already said 6; `candle.gd:36` is the truth
(`CARRY_CAP := 6`, raised from four on capture #014 *"four candles are not enough"*, alongside the
caches going from four to eight in `dungeon_gen.gd:48` and the sconce refund in
`dungeon.gd:_on_sconce_interact`). The number was corrected in place because the rest of that bullet is
current — the sixty-second burn, the 4.5 m light range and the 2.2/1.4 energy/attenuation all hold.
