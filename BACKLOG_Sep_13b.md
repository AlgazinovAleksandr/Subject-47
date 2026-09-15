# BACKLOG — 2026-09-13 (evening playtest, run killed by macOS in the dungeon)

## Evidence
The run: main menu → Lab → House → Corridor → Backrooms (Lobby, Sprawl, Flood) → KONTUR → THE
NIGHTMARE, where the OS killed the game for low memory (8 GB machine, 3D at 5120×2880, the editor
open ~7 h). The `DebugLog` log and typed J-notes were LOST — the relaunch overwrote them
(`debug_log.gd` now rotates the previous session aside and flushes per line). The 15 captures
survive in `~/Library/Application Support/Godot/app_userdata/horror_game/debug_captures_2026-09-13T17-34-39/`.
The notes below are the user's, dictated from memory afterwards.

| # | Where | The user's note (paraphrased) | Diagnosis (code) |
|---|---|---|---|
| 001 | Lab, power restored | Geometry/path to the breaker too simple; breaker too easy to find. Did not HEAR the wing sound, did not SEE the mid-wing screamer; only the post-breaker jumpscare "and another creature that makes no sense there". | Laugh rolls 60–110 s of WING time and never fires after the flip → skipped by a brisk player. Presence scrape −3 dB only while walking, figure near-black. Screamer gate at 25 s wing time — should have fired; unverifiable without the log. "Other creature" = ApparitionDirector random apparition (~90–135 s from level start, independent of the keycard). |
| 002 | Lab, fullscreen face | Saw the shared creature BEFORE the keycard; agreed it comes only after. | The face is the nook payoff's own `flash_scare(lab_nook_face.png)`, fired after the third breaker, always before the keycard. |
| 003 | House, key stool | Map hammer icon does not read as a hammer. Glass should not cover the key: a glass room you break into with the hammer, then collect the key. | `house_map_hammer_icon.png` (make_map_icons.py). Case icon on the mark cell. |
| 004–007 | Corridor spurs | Dead ends have nothing: door onto a wall, wait, nothing scares you. Wants Space-mash to open, creepy notes ("you are not the first taking this experiment"), lights off, music, a shadow, a door with nothing behind it. No FORKS anywhere. | `_on_spur_sprung`: door shut, torch dies, scrape + thuds, 10 s timer. No interact path. Single 455 m path. |
| 008 | Backrooms crate | The jumpscare sound arrives only when the creature runs away. | `crate_jumpscare` plays on `lunged` (t=0.675 s), 0.35 s before the run; the lunge starts at 0.175 s with no sound. |
| 009 | Flood altar | "SIX PIECES. SET THEM HERE." reads weird; want a collector's/occult voice. | `flood_plate.gd:SCRAWL`, Label3D on a 1.45 m board. |
| 010 | KONTUR hammer | Looks 2D from the side, floats. | An upright 0.4 m `QuadMesh` (not a billboard) standing on the bench. |
| 011 | KONTUR cell | Still not a prison cell from the front. | Solid steel leaf + port + five thin bars 0.16 m proud. |
| — | KONTUR condemn | 20 s of nothing, then the screamer. | `_tick_condemn`: red lamps, drone, panic curve only. |
| 013 | KONTUR dark figure | Had to turn to see it; should appear where the camera points, as close as now. | Fixed position (dark_x ± 1.6, z 53.6), no frustum test. |
| 014 | Dungeon | Four candles not enough. Parasite moves weirdly / gets stuck. | Budget 8×60 = 480 s vs 12–15 min target; sconces refund nothing. `_move_toward` snaps yaw every frame; `_room_at` ambiguity on shared wall planes → doorway ping-pong. |
| crash | Dungeon | "when I saw this creature the game crashed" | OS low-memory kill. Parasite GLB 5 MB + 3×1024² PNGs uncompressed; framebuffers at 5120×2880. |

## Decisions (the user's, 2026-09-13)
| # | Level | Decision |
|---|---|---|
| L1 | Lab | **No fullscreen image before the keycard.** The nook payoff keeps the turned-camera figure + `nook_scream` but loses `flash_scare(lab_nook_face.png)`; the `ApparitionDirector` in the Lab arms only after the keycard; the wing screamer stays in-world. |
| L2 | Lab | **Wing harder**: two loop connections (maze, not tree), wrong branches two rooms deep, the PANEL HUM meter shown only within 3 rooms (path) of the breaker, laugh window 60–110 → **30–70 s** of wing time. Beacon unchanged. |
| H1 | House | **Glass pane across the key cell's doorway** in the map minigame: hammer shatters the pane on contact, then drag into the cell and touch the key to win. Regenerate the hammer icon (it does not read as a hammer). |
| C1 | Corridor | **Spur shut-ins are Space-mash escapes and each of the three is DIFFERENT** (user: "they need to present something different"): note on the end wall, torch dies, mash bar (locker idiom) forces the door; fallback opens at 20 s. Zero panic. |
| C2 | Corridor | **Two forks**, wrong branch = 25 m loop back to the fork through a door, carrying a hidden note + one scare; subtle tell only; no panic for the wrong choice. |
| B1 | Backrooms | Crate sting plays at the **start** of the lunge, not its end. |
| F1 | Flood | Board reads **SIX RELICS OF THE WARD. / RETURN THEM TO ME.**; pre-completion objective rewritten in the same voice; post-completion line unchanged. |
| K1 | KONTUR | Hammer is a **3D part-built hammer lying on the bench**, not an upright quad. |
| K2 | KONTUR | Cell front = **open barred face, no steel door**: 9 bars at 0.2 m pitch, two rails, a gate section with a lock plate; sightline test re-measured. |
| K3 | KONTUR | **Condemn escalation** over the 20 s: 0–6 whispers + camera roll; 6–12 edge figures that vanish when looked at + discordant bed; 12–18 accelerating black→red cuts with the scrawl bleeding back; 18–20 a figure at arm's length, then the bar kills. |
| K4 | KONTUR | Blackout figure **appears where the camera points** (frustum-first placement, fallback `turn_to_face`), same 2.6 m closeness. |
| D1 | Dungeon | Candles: **carry 6, 8 caches, each lit sconce refunds one candle**; burn stays 60 s. |
| D2 | Dungeon | Parasite movement made natural: turn-rate smoothing, doorway-oscillation fix, feet no longer skating. |
| X1 | Crash | **3D at half resolution on HiDPI** + VRAM-compressed creature textures; measure RSS in the dungeon before/after, target < 1 GB. |

## Build list (in order; each item names its verification)

### 0. Backlog file + evidence hardening (done in code already for the log)
- Write `BACKLOG_Sep_13b.md` at the repo root: per level — capture #, the user's words, diagnosis, decision, items with file/function, verification, cost.

### 1. X1 — memory (first, because every later render-verify runs the game)
- `game/project.godot`: `rendering/scaling_3d/scale` — set at runtime in `player.gd:_ready()` or a `GameState` hook: if `DisplayServer.screen_get_scale() > 1.0` → `get_viewport().scaling_3d_scale = 0.5` (UI unaffected under `canvas_items` stretch). Keep 1.0 elsewhere.
- Creature textures (`parasite_*.png`, `hollow_crown_texture_0.png`): `.import` → `compress/mode=2` (VRAM compressed), `mipmaps/generate=true`; re-import.
- Verify: `ps -o rss` sampled over 60 s in `dungeon.tscn` before/after (use `--quit-after` in frames; earlier attempt used 1500 frames = 25 s, which is why RSS read 0 — use 6000). Record the numbers in the backlog. Also check `SubViewport` mirrors are unaffected (`check_mirror_frustum`).

### 2. L1 — Lab figures before the keycard
- `level_1.gd:_nook_reveal()` (~:1985-2002): drop the `Screamer.flash_scare(...)` call; keep the figure, the scream, the +20 panic and the timing to `_nook_cleanup`. `NOOK_FLASH_*` constants go or become the cleanup delay.
- `level_1.gd:_spawn_apparition_director()` (:1633-1645): the director's `suppress` also returns true until `GameState.has_keycard` (or arm it from `on_keycard_taken()`).
- Tests: `check_dark_payoffs`, `autoplay_lab_nook`, `screenshot_nook_scare` (no Screamer panel expected), `count_apparitions` (Lab row: first appearance only after keycard), `check_lab_apparition_timing`.

### 3. L2 — wing harder
- `level_1.gd` ROOMS/DOORS: add two loops (e.g. Plant↔Cistern via a new `PlantDrop` room; NorthVault↔Gallery via `VaultRun`), extend Sump/Boiler/Vent/PumpRoom by one room each (2-deep dead ends). Re-derive `_spawn_breaker_nook_zone()` bounds, `WING_ROOMS`, `NO_LAMP_ROOMS`, `_spawn_wing_markers`.
- `lab_wing_meter.gd`: `set_active` only when Dijkstra path distance to the breaker ≤ 3 rooms (expose room-hops); outside that, hidden. `check_wing_meter` re-derived (no reading beyond 3 rooms, gradient inside).
- `WING_LAUGH_AT` 60–110 → 30–70.
- Tests: `walk_lab_wing` (route + every dead end dead + loops walkable), `check_wing_markers` (doorway count), `check_wing_beats`, `check_wall_overlap -- Lab`, `check_reachable`, `screenshot_wing_markers`.

### 4. H1 — House map glass pane + hammer icon
- `maze_chase_ui.gd`: the case icon becomes a pane drawn across the mark cell's entrance edge (the single open wall of the mark cell — pick the mark so it has exactly one opening, or draw the pane across the edge on the tour's approach); `_is_won()` = hammer held AND pane broken AND icon in the mark cell. Pane break on contact with the hammer: `glass_shatter` + cracked pane for `WIN_HOLD`, then the cell opens. No difficulty constant moves.
- `tools/make_map_icons.py`: new hammer icon (Pillow-drawn silhouette: head + claw + handle, high contrast) — replace `house_map_hammer_icon.png`.
- Tests: `check_maze_traps` (pane blocks before hammer, opens after), `check_maze_chase` (win rate still ≥ 0.55 — the route is unchanged so expect ~58 %), `screenshot_maze_ui` (icon legible).

### 5. C1 — three DIFFERENT spur shut-ins
- `dead_end_trap.gd` / new `spur_escape.gd`: a Space-mash bar (copy `lab_locker.gd`'s `_process` polling of `push_effort`, PUSH_PER_PRESS/DECAY, freeze-free variant — the player must be able to turn), `SlamDoor` gains `force_open()`; fallback `SPUR_SHUT_TIME` 10 → 20 s.
- Per-spur variants (`SIDE_PASSAGES` gains a `"kind"`):
  - spur 1 (105 m): **the note** — end-wall page "You are not the first to take this experiment" (a `note.gd` page, archived), torch dies, mash to leave; a shadow (`Watcher` on the far side) crosses the light under the door at the third bar.
  - spur 2 (245 m, whisper): **the plea** — the whisper behind the wall rises while you push; at the last bar the end wall's plea stops mid-word and a hand-print appears on the door (decal).
  - spur 3 (330 m): **the mirror**: a `MirrorSurface` on the end wall; the reflection shows the door OPEN behind you while it is shut; at escape, the reflected figure is gone.
- Tests: `walk_corridor` (mash path through each spur), `check_corridor_events` (three distinct kinds, zero panic, fallback opens), `screenshot_corridor` poses.

### 6. C2 — two forks
- `corridor.gd`: `FORKS := [{at, side, ...}]` at two corners (candidates 140 and 365 — clear of mirrors 90/410, the false door 185, silhouette 340/348, Manager 240–277). Build with `_corridor_box` on synthetic segments: wrong branch = 3 legs (out 8 m, across 9 m, back 8 m) rejoining 6 m before the fork through an `AjarDoor` that swings open onto the main hall; carries a `_spawn_intro_note`-style note and one scare (a `Watcher` seen once at the far leg / a lights-die `CorridorEvent`). Main-wall cutter loop extended for fork mouths. Tell: the carpet runner continues on the correct branch only; a dead torch marks the wrong one.
- Zero panic. `PATH_2D` distance unchanged (455).
- Tests: `walk_corridor` (both branches walkable, loop rejoins), `check_corridor_events` (≥ 50 m pairwise still), `check_wall_overlap -- Corridor` (allowlist re-counted), `check_shell_sealed`, `check_noclip_fall`.

### 7. B1 — crate sting timing
- `backrooms_zone2.gd:_start_the_lunge()`: play `crate_jumpscare` here (move the emitter creation out of `_on_dweller_lunged`), extend `HoldBreath.dip` to cover it; fix the stale `flash_scare` comments at :779-806 and `sprawl_crate.gd:12`.
- Test: `check_sprawl_crate` asserts the sting player is playing before the lunge tween finishes.

### 8. F1 — Flood board text
- `flood_plate.gd:SCRAWL` → "SIX RELICS OF THE WARD.\nRETURN THEM TO ME." (23 chars: drop `font_size` 46 → 40 if the line overruns 1.45 m — measure in `screenshot_flood_pieces`). `backrooms_zone3.gd:358` pre-completion objective → "Someone down here was collecting." (post line unchanged; `check_flood_puzzle:591` keeps "does not show itself").
- Tests: `check_flood_puzzle`, `screenshot_flood_pieces`.

### 9. K1 — 3D hammer
- `kontur.gd:_spawn_gate6_hammer`: replace the quad with parts (steel head box + claw wedge, hickory handle cylinder, ferrule), lying flat on the bench top (y 0.75 + half-thickness), `kontur_hammer.png` retired to `assets_src/textures/superseded/`. Collider around the parts.
- Tests: `check_kontur` (hammer parts, resting on the bench: downward ray from the head lands on the bench top within 1 cm), `check_interact_reach` (KONTUR row), `screenshot_kontur_b`.

### 10. K2 — open barred cell front
- `containment_cell.gd`: remove the door leaf + port + wheel + rail + chevrons; the −z face becomes 9 bars (Ø 40 mm, 0.2 m pitch, full height), two rails, a hinged gate section (0.7 m wide, its own bars + lock plate, static), placard moved to the plinth. `check_kontur_entities.gd` sightline sweep re-run (23 headings ≥ 3 body points clear) and the "plug the port" control replaced by "plug the gate".
- Tests: `check_kontur_entities`, `check_kontur_blackout` (`charge()` still lunges toward −z), `screenshot_cell_visibility`.

### 11. K3 — condemn escalation
- `kontur.gd:_tick_condemn`: stage table keyed on `t`: 
  - 0–6: `_play_at("phone_whisper"…)` at the ear (reuse), `_hallucination_roll(p)`;
  - 6–12: `_spawn_hallucination_figures()` variant that spawns edge `Watcher`s in the CURRENT room every 2 s and frees a figure the frame it enters the frustum; `kontur_condemn_bed` (new, `tools/make_sfx_kontur_condemn.py` extended: detuned choir) fades in on Master;
  - 12–18: `ScreenText`-level black then red full-screen `ColorRect`s (new helper `_condemn_flash(black 0.3 s, red 0.25 s)`) at 3 s, 2 s, 1.2 s, 0.7 s intervals; the scrawl re-drawn at 50 % alpha each cut;
  - 18–20: one `Watcher` 1.2 m ahead in frustum, then the existing `add_panic(pmax)`.
  - Every beat guarded on `NoteUI.is_open`/paused (they postpone, the clock does not).
- Tests: `check_kontur_condemn` extended: stage beats fire at their times, figures never persist in view, the flash overlay is freed on death, no beat before `t` 0.
- Render: `screenshot_kontur_condemn` (new, needs a display): frames at 4/9/15/19 s.

### 12. K4 — Blackout figure where you look
- `kontur.gd:_tick_blackout_figure`: on first torch-off inside the window, place the figure with `apparition.gd`-style frustum-first scan at 2.6 m (reuse `Apparition._find_spot` logic via a static helper or copy `_scan`+`_fits` minimal), fallback `turn_to_face`. Never on the real seam's x.
- Tests: `check_kontur_entities` (figure in frustum from 6 poses incl. facing away), `screenshot_kontur_b`.

### 13. D1 — candles
- `candle.gd:CARRY_CAP` 4 → 6; `dungeon_gen.gd:CANDLE_CACHES` 4 → 8; `dungeon.gd:_on_sconce_interact` → `_candle.add_candle()` + toast. Save/restore `candles_held` unchanged.
- Tests: `check_dungeon_gen` (8 caches, distinct rooms), `check_dungeon_hunter`/`autoplay_dungeon` (budget), `check_dungeon_entities`.

### 14. D2 — Parasite movement
- `creature_object12.gd`: `TURN_RATE_DEG` 240 °/s — `_body.rotation.y` moves toward the desired yaw with `lerp_angle`, never snapped, in `_move_toward` (and `place_body` keeps the snap); `_room_at` hysteresis: keep the previous room while the point is within `SAME_ROOM_PAD` of it; `PORTAL_ARRIVE` = `min(0.35, door half-width * 0.3)` → for 2.2 m doors 0.33 (unchanged) but the arrive test is along the doorway NORMAL (crossed the plane), not radius; `play_locomotion` fed the actual per-frame displacement / delta (smoothed) so feet stop skating.
- Probe: `probe_breach_router_sweep.gd` still 0 clipped; new `probe_dungeon_hunter_path.gd` over 3 seeds: max heading change per frame ≤ TURN_RATE·delta, no position stalls > 1 s while a target is ≥ 2 m away.
- Tests: `walk_level6_breach`, `check_level6_breach`, `check_dungeon_hunter`, `check_creature_anim`, `autoplay_dungeon -- --seeds 101,202,303`.

### 15. Docs + suite
- `ISSUES_SOLUTIONS.md` (lost-log incident + crash; router oscillation), `CLAUDE.md` ⭐ bullets per level, `BACKLOG_Sep_13b.md` Status, memory file update (index line is stale).
- `tools/run_tests.sh -q` alone at the end; fix reds; tree left uncommitted.

## Verification (end-to-end)
- Per item as above; `tools/run_tests.sh -q` last (one Godot at a time).
- RSS measurement table (before/after) in the backlog.
- Renders: nook (no fullscreen), wing markers, maze UI, three spurs, a fork, the Flood board, the KONTUR hammer/cell/condemn/figure, dungeon candles.
- Then offer the user a playtest (never launch unasked).

## Status (end of 2026-09-13, evening)
All fifteen items built and verified. Numbers: dungeon renderer memory 577 → 295 MB; Lab wing 28
rooms / 30 doorways; House map 28/40 escapes unchanged; corridor walker 700 s budget (three mash
escapes + two loops); router sweep 0 clipped; dungeon bot 3/3, 0 deaths. Decisions taken without
the user: the nook figure holds 0.6 s now that no picture follows it; the plea spur's hand-print
is on the END WALL (a forced door swings its leaves away); the fork door is a full-width `SlamDoor`
(a 0.97 m leaf in a 3 m mouth read wrong); the Parasite's legs still play at the configured
speed, not the measured one (skipped — `play_locomotion` restarts the clip). Not hand-played.
Suite: the whole `tools/run_tests.sh` list is green, but it was run in two halves — the runner was
killed by macOS for memory at row 70 (Chrome, VS Code and the idle Godot editor were holding the
machine), so rows 71–115 ran one by one with the same verdict grep. Three turn-mirror guards were
taught to ignore the spur mirror and the Corridor fitting allowance rose 24 → 26 for the two dead
fork torches. Issues 202–206 written.
