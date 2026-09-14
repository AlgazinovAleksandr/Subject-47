# BACKLOG — 2026-09-14 (from the late run of 2026-09-13)

## Evidence
Run: main menu → Lab → House → Corridor → Backrooms → KONTUR (quit after the escort began; 1 death, the
bait keycard). Log: scratchpad `playtest_2334.log`; captures `debug_captures/001–015.png` (app data).

| # | Where | The user's note | What the log/code says |
|---|---|---|---|
| 1 | Lab wing | "Panel hum measuring the sound does not appear straightaway - I think it should be there from the beginning" | near-only rule from 2026-09-13 afternoon; REVERSED |
| 2 | Lab wing | "I did not see the jumpscare which usually appears before the light gets restored" | WING SCREAMER fired at 79.8 s, LAUGH at 89 s. `DoorLunger` has no emission and the torch is locked off: 12 % grey on black for 0.85 s, no camera pin |
| 3 | Lab | "Okay so I took the key card - but the monster does not appear" | keycard 225.5 s, left 265.7 s, no appearance. `appear()` found no spot in the morgue and aborted silently; `_apparition_fired`/`apparition_taught` latched anyway; the 30 s deadline runs on game time and the J-note pauses the tree |
| 4 | Corridor plea spur | "This room is useless - same escaping mechanics ... no note, nothing. Either make a more interesting escape mechanics and space or drop it" | plea spur shows nothing before the escape |
| 5 | Corridor corner 140 | "What I actually meant by fork is somewhere here - you need to turn right - what if you turn left?" | corner branches, not side loops |
| 6 | mirror spur | "Why we have press E here if I need to press tab?" | "Press E" on the spur's SlamDoor while battering (E does nothing) |
| 7 | same | "always pressing spaces is boring, need something else" | |
| 8 | Corridor | "needs slightly more variety ... launch an agent that will explore indie horrors" | survey done (appendix) |
| 9 | Backrooms | "The first correct note should be that there is no door - walk straight through ... the first note is spawned in the first right direction" | entry note front-loads arrows + Smiler; "WALK INTO IT" no longer exists in the world |
| 10 | Sprawl | "the jumpscare sound appear too late - maybe cut the silent part" | `crate_jumpscare.ogg` has 0.785 s of leading silence (from the source m4a) |
| 11 | Flood | "This brown piece looks too boring" | the altar's Backboard/Top: flat untextured slabs |
| 12 | Flood | "Decrease the font size - text does not fully fit" | "SIX RELICS OF THE WARD." is 1.75–1.90 m wide on a 1.45 m board at font 46 |
| 13 | KONTUR | "The kontur jumpscare needs to be regenerated - not a static 2d image but something creepy kicking you like the hotel manager" | `Screamer.trigger()` image; no lunge hook exists |
| 14, 15 | KONTUR cell | "You still did the prison cell in the wrong side - this is the first view" (glass) / "And you did this view" (bars) | the arrival antechamber is random; west glass dominates 5.85 m of the walk, bars 1.15 m |

## Decisions
| # | Area | Decision |
|---|---|---|
| L1 | Lab | **Apparition bug**: `appear()` returns bool and LOGS its abort; `_trigger_apparition` does not latch `_apparition_fired` / `apparition_taught` unless it appeared; on abort re-poll every 0.25 s until `APPARITION_DEADLINE`, which runs on the WALL clock (the debug capture pauses the tree). DebugLog line on arm + fire (the House's two lines, carried to level_1). |
| L2 | Lab | **Wing screamer unmissable**: `DoorLunger` material gains emission (`apparition.gd`'s 1.6 idiom, a `glow` param); the wing beat zeroes velocity, `freeze_input()`, `turn_to_face` UNCONDITIONALLY (0.45 s), holds ~1.4 s, `flee_to` instead of `queue_free`, the sting a child of the figure, plus a short-range `OmniLight3D` on the figure for the 1.4 s. |
| L3 | Lab | **Meter live everywhere** (revert near-only): `LabWingMeter.NEAR_HOPS` gating removed; `check_wing_meter` re-derived. |
| H — | House | (no items) |
| C1 | Corridor | **Spur 105 keeps note + Space-mash** (one instance of the verb). |
| C2 | Corridor | **Spur 245 → BELL-AND-WAIT**: a reception nook (desk, bell). E rings; footsteps approach from far down the hall and stop behind you; turn round → they stop, the door opens; don't turn (≥ 6 s facing the desk) → the door opens AND a key/page is on the desk (a `MovedProp`). No mash, no panic. |
| C3 | Corridor | **Spur 330 → PASS-BY CUPBOARD**: a `HidingSpot`-like slatted cupboard at the end; door seals; the Manager (`DoorLunger` with `manager_figure.png`) walks past the slats; move / torch on → it stops outside (no death, resets); hold still torch-off ~8 s → it passes, latch releases. The spur mirror moves INTO the cupboard's back wall (kept). |
| C4 | Corridor | **Corner branches at 320 and 365** (new table `CORNER_BRANCHES`, NOT `SIDE_PASSAGES`): at the corner the hall also continues straight (`at = corner + 0.001` idiom) 12–20 m. **Evidence behind you**: a wet-footprint decal trail on the incoming leg's floor leads INTO the wrong branch. 320's wrong branch = `LoopBack` to the previous corner (Backrooms teleport idiom) with a louder tell on return; **365's wrong branch = BLIND NAVIGATION**: torch dies, the room's map flashes 0.4 s behind you (intro switch idiom), find the release lever by feel (per-wall knock SFX, a two-layer hum on the lever), the wall opens back to the hall. ⚠️ the mouth cutter must carry a segment qualifier (a corner distance matches two segments). Branch length ≤ 20 m (the 22.5 m `_nearest_path_distance` crossover). The two side loops STAY. |
| C5 | Corridor | **Ajar-door rhythm break**: the 6 `AjarDoor`s open the same 12°; one more is added with a `Watcher` in its gap, visible only from one side; past it the door is shut. Zero panic. |
| C6 | Corridor | **E prompt leaks**: spur doors while battering and fork doors from the hall → `can_interact()` false (no prompt). |
| B1 | Backrooms | First hint = the verb: `NOTE_TEXT` cut to "There is no door. Walk into the wall." (arrow + Smiler rules move to later notes released by `_assign_round` rounds 2/3); the CORRECT arm's seam scrawl reads `NO DOOR. / WALK INTO IT.` (set at the end of `_assign_round`), the others keep their scrawls. |
| B2 | Sprawl | `crate_jumpscare.ogg` leading silence 0.785 s trimmed (regenerate from `assets_src/audio/level_backrooms/crate_jumpscare_raw.m4a` via a `tools/` script with ffmpeg `atrim`). |
| F1 | Flood | Board `font_size` 46 → 32 (fits 1.45 m with margins); **altar = rusted steel autopsy table with a stained sheet**: rust + sheet textures (flux via `level-3-image-generator`, graded), drain gutter, the six outlines chalked on the sheet, the board text as chalk on the sheet's edge (Pillow). |
| K1 | KONTUR | **Bars on the west face too** (plain grille, no gate furniture, no bar on the occupant's z = 0.12 line); `_port_panels`/`PORT_*` dead code removed; sightline sweep + `screenshot_cell_visibility` re-measured. |
| K2 | KONTUR | **In-world deaths**: `Screamer.trigger_with_lunge(tex, ahead, reach, time)` — freeze + turn, `DoorLunger` lunge to 0.5 m with the level's scream as a child, then `trigger()` (the funnel stays). Yellow phone + Perëkozhnik (exported `death_figure`, KONTUR only) use it. **Condemn** ends with STANDING-WHEN-THE-LIGHTS-RETURN: at `CONDEMN_FINAL_AT` lamps die, 2 s, return with the figure 1.5 m ahead in frame, then the lunge to black. A generated KONTUR figure cutout (`kontur_figure.png`, keyed like `manager_figure.png`). |
| X1 | Breach | **Grab through the door**: when Object 12's contact happens within 1.5 m of a `SlamDoor` the player is at, the death is the grab — an arm mesh through the gap, the player root tweened to 0.3 m from the leaf under freeze + turn, the leaf slams on the lens (black), then `trigger()`. Other contact deaths unchanged. |
| X2 | All | Backlog appendix: the survey's remaining beats (Exit 8, hall grows, numbers reverse, lift, trolley, rule-on-walls, stop-looking, two-door lie, save-state address, tape pause, silence drop, footstep skip, geometry lies, painted torch, runner turns, mirror one pass behind) filed as ideas, not built. |

## Build list (in order; verification named)
0. `BACKLOG_Sep_14.md` (notes, log evidence, decisions, appendix).
1. **L1** `level_1.gd` `_trigger_apparition`/`_tick_apparition`, `apparition.gd:appear()` → bool + DebugLog; `apparition_director.gd:arm()` returns the bool and latches `apparition_taught` only on true; wall-clock deadline (`Time.get_ticks_msec`). Test: `check_lab_apparition_timing` extended — force `_find_spot` to fail once (a control that fills the room) and assert a retry appears and the flag latches only then; `count_apparitions`.
2. **L2** `door_lunger.gd` `glow` param (emission 1.6) + optional light; `level_1.gd:_fire_wing_screamer` pin/hold/flee. Test: `check_wing_beats` (frozen, camera dot ≥ 0.9, hold ≥ 1.2 s, figure luminance vs black ≥ threshold via a render in `screenshot_wing_markers`-style harness `screenshot_wing_screamer.gd`).
3. **L3** `lab_wing_meter.gd` remove NEAR gating; `check_wing_meter` reverted to "reads everywhere, no reading outside".
4. **C6** `slam_door.gd` `can_interact()`: false while battering; fork doors expose `hall_side_locked`. Test: `check_corridor_events` (prompt target null from inside a shut spur and from the hall at a fork door).
5. **C2** `spur_bell.gd`: desk + bell prop (parts), `interact()` → footsteps tween (positional `footstep` 20 m → 1 m behind over 9 s), facing test (`_facing_dot(desk) > 0.5` held), outcomes; a `MovedProp` key page (`fork_note`-style page: "the guest was served"). Test: `check_corridor_events` C2 section (both outcomes driven by `ai_look_at`), `walk_corridor` (rings, waits, leaves).
6. **C3** `spur_cupboard.gd`: slatted cupboard (`HidingSpot` geometry idiom), seal on entry, Manager `DoorLunger` pass-by (12 m walk at 1.2 m/s past the slats, `manager_figure.png`), rule: still + torch off 8 s → release; move/torch → it stops outside, timer resets (no death). Mirror on the cupboard's back wall keeps the figure-behind-you beat. Test: `check_corridor_events` (release on stillness; stop on movement; zero panic; fallback release at 45 s), `walk_corridor`.
7. **C4** `corridor.gd` `CORNER_BRANCHES` [{corner: 320, kind: "loop"}, {corner: 365, kind: "blind"}]; mouth cutter with segment qualifier; straight continuation boxes via `_corridor_box` on the outgoing leg's `pt.side`; footprint decals (`tools/make_footprints.py`, Pillow RGBA) along the incoming leg into the branch; 320: `LoopBack` Area3D → teleport to the previous corner + tell escalation (a second trail, a slam); 365: `blind_room.gd` (torch `lock_flashlight`, 0.4 s map flash — a `Label3D`/quad with a Pillow map of the room, per-wall knock SFX `tools/make_sfx_blind.py`, lever `interact()` with the Lab beacon idiom, wall opens = a `CSGBox3D` freed). `corner_branches()` accessor. Tests: `walk_corridor` (both branches walked; 320 returns to corner 275's... previous corner 320→275 side; 365's lever found by walking the walls), `check_corridor_events` (branches ≥ 8 m from beats, trail decals inside the wrong branch only), `check_wall_overlap -- Corridor` (allowlist unchanged), `check_shell_sealed`, `check_noclip_fall`, `check_prop_mounting`.
8. **C5** `corridor.gd` seventh `AjarDoor` + `Watcher` in the gap (side-visible), `check_corridor_doors`.
9. **B1** `backrooms.gd` NOTE_TEXT / `_assign_round` scrawl / later notes; `check_backrooms_seam` (correct arm's scrawl text; entry note mentions the wall and NOT the arrows).
10. **B2** `tools/make_crate_jumpscare.py` (ffmpeg atrim 0.785 → ogg); `check_sprawl_crate` asserts the file's leading silence < 0.05 s (read the ogg via `AudioStreamOggVorbis` samples? simpler: the tool prints it; the test asserts stream length < 6.2 s).
11. **F1** `flood_plate.gd` font 32; `_build_table` → autopsy table (gutter, wheels, sheet quad with generated `flood_sheet.png`, rust `flood_steel_rust.png`), outlines chalked into the sheet art (Pillow over the flux sheet), board text on the sheet edge. `check_flood_puzzle`, `screenshot_flood_pieces`.
12. **K1** `containment_cell.gd` west grille; remove dead port code; `check_kontur_entities`, `screenshot_cell_visibility`.
13. **K2** `screamer.gd:trigger_with_lunge` (+ `_lunging` guard); `kontur.gd` phone + condemn (lights die/return/figure/lunge); `creature_shapechanger.gd` `death_figure` export; `kontur_figure.png` generated + keyed. Tests: `check_kontur_condemn` (final beat = lights out → figure in frame → `_is_triggering`), `check_kontur_phones` (yellow answer → lunge → trigger), `check_kontur_entities` (mimic kill path), all watching `_is_triggering` unchanged.
14. **X1** `level_6_breach.gd` `_check_contact` → if a `SlamDoor` within 1.5 m of the player: `_grab_death(door)` (arm mesh `breach_arm` from parts, root tween, leaf slam, black, `trigger()`); `check_level6_breach` / `walk_level6_breach` (grab path drives to `_is_triggering`, normal contact unchanged).
15. Docs: ISSUES (apparition latch + paused deadline; corner-distance double cut), CLAUDE.md bullets, memory. Full suite ALONE (`tools/run_tests.sh -q`), fix reds.

## Verification
Per item above; renders: wing screamer, bell nook, cupboard pass-by, corner branch + trail, blind room, ajar figure, altar, cell west face, KONTUR lunge/lights-return, Breach grab. Suite green at the end. Then offer (never launch unasked) a playtest.

## Appendix — indie-horror beats surveyed (not built; the user's future picks)
Exit 8 spot-the-anomaly stretch · the hall grows a metre per pass · room numbers count the wrong way ·
the lift that opens on the same hall · the housekeeping trolley that moves unobserved · the room with
its rule on its own walls (combination lock from picture-frame dates) · the exit that appears when you
stop looking · the two-door sound tell that lies once · the game addresses you by your save state ·
the tape you can pause (the room reacts) · the silence drop with nothing after · footsteps that skip a
beat · geometry that lies measurably (doors 3.6 → 3.4 m apart) · the painted calm-zone torch · the
runner that turns on you · the mirror one pass behind. Full list with sources in the session transcript.

## Status (2026-09-14, end of the implementation session)
**Built and green:** L1 (retry + wall-clock deadline; `check_lab_apparition_timing` 12/0,
`count_apparitions` PASS), L2 (glow + light + pin/hold/flee; luminance 0.0006 → 0.109), L3, C1–C6
(`walk_corridor` 24/0, `check_corridor_events` PASS, renders viewed), B1–B2, F1, K1
(`check_kontur_entities` PASS after a 0.1 m grille shift), K2 (`check_kontur_condemn`,
`check_kontur_phones` PASS; `screenshot_kontur_lunge` viewed), X1 (`check_level6_breach` PASS;
`screenshot_breach_grab` viewed). Issues 207–210.
**Decided without the user (flag for review):** F1's board `font_size` 32 became moot — the board
and its label are gone, the words are chalk on the sheet; the yellow phone's figure stands at
1.0 m (the desk has no collider); the Breach hand is parts, not a texture; the condemn bar is held
at 96 % while the lunge plays so the in-world death lands (the force-kill stays as a 3 s fallback).
**Not done:** `walk_level6_breach` was not extended (the grab is asserted in `check_level6_breach`
instead — the walker wins without contact). X2 is the appendix above.
**Suite (run alone, one Godot at a time; macOS killed the single run for memory at row ~98, the
rest ran individually):** 112 of the runner's rows green after four fixes the run surfaced —
`wet_footprint.png` regenerated at the quad's aspect (was a 2.1× squash), the painting-fall beat
keeps off every wall opening (a corner landed behind the 118 fork's return door), the C5 figure is a
`DoorLunger` billboard (a `Watcher` cannot stand in a doorway), and Issue 211 (every bend's outer
corner column was uncovered; the 365 mouth turned a pinhole into a hole). `walk_corridor`'s loop-end
leg now arrives on the loop-back firing rather than by distance.
The walker's last two reds were the blind room: it released the torch with `unlock_flashlight()`
(the light stayed off — a real bug, Issue 212, fixed with the force/restore pair) and the walker
reached the lever before the 1.2 s map flash (it now waits for it).
