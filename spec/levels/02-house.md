# Level 2 — The House — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Level 2 — The House (abandoned domestic interior)** — rebuilt procedurally (Session 10)
- ⚠️ **THERE WAS NO NOTE COUNTER BEFORE THIS.** `_spawn_notes()` discarded two of the three safe
  notes' return values and only the cellar one's `read` signal was wired; `GameState.journal` is a
  whole-game de-duplicated array, not a per-level count. ⚠️ It counts by NODE NAME, not `+= 1` —
  `note.gd` emits `read` on every OPEN, so a player re-reading the living-room note three times
  would otherwise light the house without ever going down to the cellar for the third digit.
  ⚠️ `save_progress()` carries `safe_notes` AND `lock_lamp` together; restoring one without the
  other either lights a house whose code the player has not learned or re-darkens a solved one.
- ⚠️ **The cellar's `DarkZone` is GONE and the bedroom event's with it** (D4). The cellar one was
  the urgent case: it overlapped the `DreadZone` exactly, and `player.gd` adds dark tax ON TOP of
  dread pressure while the dark branch also suppresses decay — **+5/s with no way down**, in the
  one room that takes the torch away on purpose for 8.5 s and has a beartrap on the entry line.
  **The `DreadZone` stays**; it is the cellar's real pressure signature and does not depend on the
  torch.
- Built at runtime in `level_2.gd` via `RoomBuilder` from an 8-room ground floor (entry hall, hallway, living room, kitchen, landing, bedroom, bathroom, child's room) **plus a gently-lowered CELLAR** (`_build_cellar()`, floor at y=−1.5) reached by a walkable ramp. Same `.tscn`-minimal / `PRESERVE`-whitelist pattern as the Lab
- ⚠️ **THE CELLAR DOOR'S PLANKS AND PADLOCK WERE 1.5 m TOO HIGH** (fixed 2026-09-07, Issue 170,
  from *"Test whether the door in the basement at the house level works fine"*). The mechanism was
  perfect and six tests measured it green; the PICTURE was two thirds absent, because
  `cellar_gate.gd` positioned its children at `HEIGHT * 0.5 + offset` on a `BoxMesh` already centred
  on a body at y = 1.5. Two of three planks and ~75 % of the lock sat above the leaf inside
  `CellarShaftCap`, so the prop that exists *"so it reads as sealed rather than as a wall the
  builder forgot to cut a doorway in"* read as a blank slab, in a house at ambient 0.02.
  ⚠️ **`check_cellar_key.gd` had never re-checked the doorway AFTER a successful key-open** — the
  one direction a player cares about — and called `interact()` directly rather than through the
  raycast. It now walks there, presses E through the shipping ray, waits past the 0.9 s tween,
  asserts the doorway is clear, and walks down and back out.
- **Cellar key sub-quest**: a glowing `KeyItem` (`key_item.gd`) → `picked_up` → the player is now
  *carrying* the key (`GameState.set_carried`, shown on the HUD); the `CellarGate` (`cellar_gate.gd`)
  only opens when they walk down and press **E** on it. ⚠️ `picked_up` used to be wired straight to
  `_open_cellar_gate()`, so winning the Bathroom minigame flung the cellar open from the other end of
  the house and the key was a formality (BACKLOG #16). ⚠️ The ramp/shaft/ceiling use `rotation.x = -angle` (a +angle inverts the slope and drops the ceiling to knee height); the key sits clear of its (collision-less) stand so the interaction ray reaches it. **Session 11 fix (two parts):** (1) the ramp's TOP SURFACE is now continuous with the floors at both ends — it starts at z=1.7 where `RoomBuilder`'s doorway floor-bridge ends (both at y=0) and the bottom is extended 0.6 m under the cellar floor — so there's no end-lip to climb (`move_and_slide` can't step up; a tilted box poking ~0.14 m above the floor was the real "can't enter the cellar" block, *not* headroom). (2) The sloped ceiling is offset a constant 2.6 m along the ramp normal (~2.45 m vertical clearance) and a flat `CellarShaftCap` at y=3 seals the top; the ramp wears `house_wood_stairs.png`. Verified walkable BOTH ways by `tests/walk_cellar.gd`. **BUG_FIX.md 4.3** first moved the key into a 2-drawer search in the Landing; a later session **replaced that entirely** with a bigger quest, so Landing is empty again (a deliberate trade). **Current feature**: a folded paper map (`HouseMap`, `house_map_prop.gd`) on a stand in the **Bathroom** (`_spawn_bathroom_map()` — it moved Landing → Kitchen counter → Bathroom; the objective string has now been wrong THREE times, so re-check it whenever the quest moves — the four lines live together as `OBJ_*` consts at the top of `level_2.gd` now, because the fresh-level path and `_restore_progress()` had drifted apart twice. ⚠️ It is `The cellar is locked. Find the key.`: it used to read *"Find the folded map — it hides the cellar key"*, and the objective HUD was the ONLY thing anywhere in the level that named either the map or the key, so the one puzzle was solved on screen before the player entered a room (playtest 2026-08-16). ⚠️ **Replaced, not deleted** — the map is the only route to the key and nothing else in the game names it, so an empty objective would strand a player who never walks into the Bathroom) opens a full-screen, paused 2D maze-chase minigame (`MazeChaseUI`, `maze_chase_ui.gd`) — a fresh **16×9** **braided** randomized-DFS maze for every genuine **attempt**, i.e. on a win or a catch.
  - ⚠️⚠️ **THE OBJECTIVE IS TWO-STAGE SINCE 2026-08-16 (a user-requested redesign, approved after a brainstorm): COLLECT the torn fragment(s) of the map, THEN escape to the mark.** Shipped at **`fragment_count = 1`** — see the frontier below, and `backlogs/02-house.md` §9 P6 for all of it. The mark is genuinely **inert** — and visibly sealed, `TargetSeal` — until the last fragment is in hand; `_is_won()` is the single win predicate and it checks both halves. Fragments carry **no panic and no fail state**; a catch ends the attempt exactly as before (`CATCH_PANIC` 18, ejected to 3D, retryable, brand-new maze) and **fragments already collected are lost with it — there is deliberately no partial-progress carry-over**, and they also **re-arm on a close-and-reopen** exactly as the snares do, so ESC cannot become a checkpoint.
    - **Why, and it is not "a longer maze is a harder maze".** The user asked for a maze "more packed with actions"; the measurement (`backlogs/02-house.md` §7 P4, 200 seeds) said **the median winning run was 9.8 s**, p90 14.4 s. There is no room in ten seconds for a hunter, a patroller and five snares to *matter* — most runs ended before the patroller was ever met. The fragments buy **time on the board**, which is what turns the roster that already exists into decisions.
    - **Measured outcome: 232/400 = 58 % win rate, median run 21.7 s** (p10/p90 18.2/27.4 s; `check_maze_chase.gd` reports 28/40 and prints the duration every run). For scale: the build before this pass was 59 % at 9.8 s, and the one-stage control on this board is 80 % at 16.9 s.
    - ⚠️⚠️ **THE ONE FINDING TO KEEP IF EVERYTHING ELSE HERE IS REWRITTEN: length bought from the ROUTE is free, length bought from WAYPOINTS is not.** Measured, 200–400 seeds per point — 10×8: N=0 82 % at 10.9 s · N=1 57 % at 14.1 s · N=2 21 % at 17.0 s · N=3 14 % at 17.5 s, the hunter's kill rate going **3.5 % → 70 %** for a run only 60 % longer. Against that, simply making the board bigger left the one-stage control at **80 % and 16.9 s**. **The head start is a one-off budget and every waypoint spends it**: `MONSTER_START_DELAY` buys ~600 px of lead once, after which the player nets 240 − 172 = 68 px/s *and only while running directly away*; a heading change hands it back to a pursuer that never tires or resets. A longer route is still monotone flight; a waypoint is not. This is why the shipped design takes its duration from **`GRID_COLS`/`GRID_ROWS` and its structure from ONE fragment.**
    - ⚠️ **The original 30–45 s target is NOT met and was retired by the user (2026-08-16), who accepted that the target was probably wrong.** 16×9 with N=2 reaches 28 s but at 20 %. Going further needs `MONSTER_SPEED`/`MONSTER_START_DELAY` or a counter-play that gives the lead back — both the user's call, neither taken.
    - **`fragment_count`** is the shipped N; **`TOUR_BAND`** is the validate-and-reject band the whole tour (start → every fragment → mark) is generated into, ≤ `FRAGMENT_PLACE_ATTEMPTS` tries and then the best candidate — never a `while`, because this runs inside a **paused** overlay where a hang is indistinguishable from a crash (Cogmind's map-validation loop; Spelunky guarantees its solution path after generation rather than hoping for one). ⚠️ **The band is the second lottery fix and a bigger one than the patroller's**: unbanded on the shipped 16×9 board the win rate ran **91 % at a 41-cell tour down to 27 % at 72+**. Banding to **50…64** cuts the tour's p10–p90 spread from 42–77 to 48–69 while moving the mean barely at all (56.3 % unbanded → 58.0 % banded) — **it is a variance instrument, not a difficulty one, and that is the point.** ⚠️ **The window is about four points wide in both directions** — 54…70 measured 51.8 % and 52…66 measured 54.0 % (both under `check_maze_chase.gd`'s asserted 0.55 floor), while 46…60 measured 63 % (over the user's 59 % ceiling). ⚠️ **The band is board-specific**: it read `34…45` on the old 10×8 grid and must be **re-measured, never rescaled**, if the grid moves again.
    - ⚠️⚠️ **THE TOUR IS MONOTONE OUTWARD, and that is the difference between the feature working and not.** Fragment k is drawn from a band around `k/(N+1)` of the way along the route, so every waypoint is further from the spawn than the last. The first build placed them anywhere off the line and ordered them nearest-neighbour: **10/200 escapes, median catch at 5.6 s** — nearest-neighbour makes the first waypoint the one *closest to the hunter*, so the head start is spent walking out and back. **Detours yes, backtracking no.** ⚠️ And a fragment may never sit in a **dead end** (`_braid()` opens only 55 % of them): worth a measured 4 points, and asserted by `check_maze_gen.gd`.
    - ⚠️ **`_route_cells` means the whole TOUR now, not the direct line.** While it still meant the direct line, **39 % of all deaths were the patroller** — fragments are chosen for being off the direct line and the patroller was banded for being off the direct line, so the two were pushed into the same space by construction. Pointing `_compute_route()` at the tour put it back to 20 %.
    - ⚠️ **"Off the route" is measured as DETOUR COST**, `d(start,c) + d(c,mark) − d(start,mark)`, not as raw distance from the route cells. The obvious alternative is unusable here and the reason is worth keeping: the direct route already has a **median length of 28 cells in an 80-cell grid**, so "3+ cells clear of the route" is routinely an EMPTY set — a constraint that is usually unsatisfiable degrades silently to "place them anywhere", which is the shape of Issue 34's stub.
    - ⚠️ **`_place_monster()` now guards the first step toward `_tour[0]`, not toward the mark** — the player's opening move is toward the nearest fragment, and the mark is inert for the first half-minute. Same rule, corrected destination; `check_maze_gen.gd` moved with it.
  - ⚠️ **The patroller no longer starts on your artery (2026-08-16)** — the single largest source of the reported randomness, and a one-line omission: `_place_patroller()` required only `PATROL_MIN_START` cells from the player's *start cell* and never consulted `_route_cells`, which `_generate_maze()` has already computed by the time it runs (`_pick_patrol_target()` has avoided route cells since the day it shipped; only the START did not). Measured over 200 seeds: **40 % of instances began it ON the route, and those seeds won 28 % against 83–100 % once it was 3+ steps off** — a 3× swing in survival decided by a placement nobody chose. It is now banded to `PATROL_MIN_ROUTE_GAP` by bounded sampling with an accept-the-best fallback, then a deterministic sweep (there may genuinely be no such cell); `check_maze_gen.gd` asserts the band against an independent BFS, failing only when a *better* candidate existed and was not taken — **200/200 seeds on the shipped board**. ⚠️ **The constant is 5 here and was 3 on the 10×8 board: the cliff moves with the grid.** Measured at 400 seeds, gap ≥ 3 with band 46…62 gives 58 % at 20.7 s with a **33-point** spread across patroller-distance buckets; gap ≥ 5 with band 50…64 gives **the same 58 %, one second longer, with a 12-point spread**. Raising the bar alone overshoots to 63 %, so the headroom it frees is spent on a longer tour band — **the two constants were chosen together and must be re-measured together.** ⚠️ `PATROL_SPEED` / `PATROL_AGGRO` / `PATROL_CALM` / `PATROL_MIN_START` were **not** touched.
  - ⚠️⚠️ **THE BOARD IS 16×9 SINCE 2026-08-16 (was 10×8), and this is where the run's LENGTH comes from.** The user's call, taken on the frontier above: a longer route is still monotone flight from the spawn, so it buys duration at no cost in win rate (one-stage control: 82 % at 10.9 s on 10×8, **80 % at 16.9 s on 16×9**), whereas buying the same duration from waypoints cost 82 % → 14 %. ⚠️ **The size is bounded by the SCREEN, not by taste**: at `CELL_SIZE` 96 the playfield is 1536×864, and `_root` is anchored at the viewport centre, so the overlay needs 478 px above it for the caption and 508 px below for the counter and pips against 540 either way at 1080p — **nine rows is the last row that fits.** Verified in the real overlay by `screenshot_maze_ui.gd`, never on paper; this file has already put a caption across the middle of the parchment once by trusting arithmetic. ⚠️ **`TOUR_BAND` and `PATROL_MIN_ROUTE_GAP` are board-specific and were re-measured, not rescaled** (34…45 → 50…64 and 3 → 5); `FRAGMENT_MIN_DETOUR` was re-swept and stays 6. ⚠️ **`SNARE_COUNT` 5 is a much thinner scatter in 144 cells than in 80, so it was isolated rather than assumed: 232/400 with five snares, 232/400 with none — identical to the seed.** Reported, not retuned. (Caveat: the harness bot walks the route and `_place_snares()` excludes route cells, so that number bounds the snares' effect on route-walking, not on greedy corner-cutting.)
  - ⚠️ **The 2026-08-16 redesign moved ZERO difficulty constants.** `MONSTER_SPEED` 172, the patroller's three, all four `SNARE_*`, `CATCH_PANIC`, `MAZE_DRIP_RATE`, `PROXIMITY_*`, the spring/speed panic degradation and the 55 % braid floor are all untouched — the list is repeated at `MONSTER_SPEED` in the script. The difficulty came from **structure**.
  - **CURRENT MEASURED DIFFICULTY — quote these and nothing else:** `check_maze_chase.gd` **28/40**; the wider probe **232/400 = 58 %**; median run **21.7 s**; asserted floor **0.55 (22/40)**. ⚠️ **The old 37/40 and 26/40 figures are DEAD.** They predate both the two-stage objective and the patroller band, and the harness that produced them could not see either. Read the isolation table in `backlogs/02-house.md` §9 P6 before quoting any of it — the patroller band is a difficulty *reduction* of 23 points and the fragment spends all of it, so the net is 59 % → 57 % with a 45 % longer run and two lotteries closed.
  - ⚠️ **The panic drip is charged per second, so a longer run costs LIFE as well as time** — checked rather than assumed. Over 400 winning runs on the shipped board: median **7.9** of `PANIC_MAX` 50, p90 10.6, worst 15.8, against the one-stage control's 3.5 / 5.7 / 9.8. Per second that is 0.36 vs 0.32 — **proportional to time, not compounding**, across a board that doubled in area. A *caught* run is still the more expensive outcome (≈3.9 of drip plus `CATCH_PANIC` 18), so the longer board did not change which failure hurts most. `MAZE_DRIP_RATE` did not need to move and did not.
  - ⚠️ **Closing the map no longer re-rolls it** (2026-08-16, the user's call). `ui_cancel` closes for free and `HouseMap.interact()` reopens; `open()` used to regenerate unconditionally, so ESC was a free re-roll and the optimal play was shopping for an easy layout — measured, 134 s with ONE catch versus 13 s for the same puzzle. A maze now lives until it is won or you are caught (`_instance_live`); reopening resumes it from the start cell with every snare re-armed. **Strictly harder, chosen knowing that.** Nothing is memorizable across attempts, only within one.
  - ⚠️ **BRAIDED since 2026-08-15** — `_braid()` opens 55 % of dead ends into loops, because the user asked to "make more space so that you can actually bypass the monster" and in a PERFECT maze that is topologically impossible, not merely hard. `dungeon_gen.gd` already carried the same lesson.
  - **The roster:** a **patroller** (a second monster walking a circuit *off* the player's likely route, giving chase only within `PATROL_AGGRO`, slower than the hunter — measured, one wandering to random cells cost 9 seeds in 40 by standing in a corridor, which is a roadblock rather than a threat); **snares** (`SNARE_COUNT` 5, off-route, pinning the icon 1.2 s for 3 panic — never a second fail state; ⚠️ drawn at their TRUE `SNARE_RADIUS` in ice blue with a frost glyph since 2026-08-16, the disc having been `SNARE_RADIUS * 1.6` in diameter — radius 20.8 against a 26 px trigger, understating the hazard by 36 % of its area, in near-black brown on sepia parchment. Issue 74; the numbers themselves untouched); and a looping **chase track** (`chase.wav`, trimmed and crossfaded by `tools/make_loop.py`, on an `AudioStreamPlayer` child of the CanvasLayer so it survives the tree pause; Master bus, matching `combination_lock.gd`; stopped in `_close()` **and** `_hide_after_external_unpause()`).
  - ⚠️ **`MONSTER_SPEED` 172, raised 88 → 132 → 172** across two playtests on the user's call. The escape rate never moved at any of the three speeds; what changed is how fast a mistake is punished — hunted down 9.4 s after stopping at 132, **5.2 s at 172**. ⚠️ **Do not raise it again without re-running `check_maze_chase.gd`.**
  - ⚠️ **The hunter follows CORRIDORS, not a beeline.** It steers by a BFS distance field from the player's cell, recomputed when they change cell. It used to use a raw Euclidean beeline, which in a randomized-DFS *perfect* maze points into a wall most of the time — the corridor route is routinely 5–15× the straight line — so it jammed and could never close once the player left the start (BACKLOG #14: *"it can basically kill the player only at the beginning"*).
  - ⚠️ **`_place_monster()` avoids the FIRST STEP of the only route to its target.** In a spanning tree that cell is a roadblock the player cannot walk around — harmless while the monster drifted into walls, a measured 12-in-40 instant death once it followed corridors. Since the two-stage objective it guards the first step toward `_tour[0]` (a fragment), not toward the mark, which is inert for the first half-minute.
  - ⚠️⚠️ **ONE SPEED, WHATEVER THE PANIC (2026-09-10, capture #6: *"the ideal speed is constant"*).**
    The spring and the speed cap used to degrade with the 3D player's panic (`9→3`, `240→100`),
    and panic CARRIES ACROSS attempts — so a retry after a catch ran ~35 % slower than the first
    try, which the player read as the map "slowing down". Both House deaths that session were
    panic deaths INSIDE the map, not catches. Now `SPRING_K := 7.5` and `PLAYER_SPEED := 210.0`,
    between the old first- and second-run values; `_drag_step()` takes `panic_ratio` and ignores
    it. ⚠️ DELIBERATE at the constant. Catch panic, drip, proximity and every monster number
    untouched. `check_maze_speed.gd` feeds the same cursor at panic 0 and 0.9 and asserts identical
    travel, with a control on the retired lerp. The two bullets below describe the OLD behaviour.
  - **Drag physics:** the icon eases toward the cursor on an exponential spring rather than snapping, and both the ease rate and the speed cap degrade as panic rises (`SPRING_K_BASE=9.0→SPRING_K_PANIC=3.0`, `PLAYER_MAX_SPEED=240→PLAYER_MIN_SPEED=100`). Releasing the mouse freezes the icon instantly, no glide, so letting go never costs an unwanted catch.
  - **Panic climbs the whole time it is open:** a flat `MAZE_DRIP_RATE=0.9`/s plus a squared proximity term up to `PROXIMITY_MAX_RATE=5.0`/s, via the same "a paused UI's own `_process` still calls `player.add_panic()`" idiom `note_ui.gd` uses for trap notes — which means the UI **must** self-clear if a screamer fires and unpauses the tree out from under it (Issue 9 guard, copied verbatim from `combination_lock.gd`/`note_ui.gd`). Winning calls the unchanged `_build_cellar_key()` at the counter's other end for a real 3D pickup; getting caught (`CATCH_RADIUS=20px`) ejects back to 3D with a jolt + `CATCH_PANIC=18` (bracketed between `beartrap.gd`'s own 15/40 spring-vs-fail values) and the map is retryable. `house_drawer.gd` (the superseded Landing search) was deleted as dead code.
  - ⚠️ **Legibility (playtest 2026-07-25, capture #3)**: the caption was added as a second child of the `CenterContainer`, which overwrites every child's anchors/offsets — so it landed stacked dead-centre ON the parchment in a cream that matched it. It now hangs off `_root` with a black outline (`ScreenText._outline()` convention). The three icons are 1024×1024 PNGs whose ink fills only ~30–40 % of the canvas, in the same sepia as both the parchment and the wall rects, so each rendered as ~28 px of near-invisible scribble; `modulate` cannot fix that (it multiplies — no multiplier turns brown into saturated blue), so `_make_icon()` stacks a dark halo disc + a bright identity disc sized to `ICON_HALF_EXTENT` + the ink on top. See ISSUES_SOLUTIONS Issue 32.
  - **Test coverage:** `tests/screenshot_maze_ui.gd` drives the real `interact()` path — `screenshot_scene.gd` structurally cannot reach a UI behind a prop. Maze generation is stress-tested independently of any scene by `tests/check_maze_gen.gd` (200 seeds: connectivity, non-trivial target distance, valid monster and patroller placement), because the minigame is only ever opened by player interaction and a normal scene smoke test never exercises `_generate_maze()` at all.
- **THE GUEST (2026-07-28/29) — the house rearranges itself, one step per quest milestone.** The
  House is the only level with genuine backtracking pressure (Bathroom map → key → Kitchen → cellar
  → ChildRoom lock crosses the ground floor repeatedly), and this is what that traffic is for:
  | milestone | what changes |
  |---|---|
  | map solved | **arms** the child's-room painting; it comes off the wall **beside the exit lock** when you are within 4.5 m, facing it, **and can actually see it**, with `painting_fall` at +8 dB and a camera jolt |
  | key taken | (nothing) |
  | cellar gate opened | arms **the cellar sequence** (below) |
  | third note read | the **music box** has moved to the Hallway, still playing, between you and the exit |
  - ⚠️ **The music box move is the ONE beat still on `MovedProp`'s off-screen rule.** The painting,
    the cellar child and the Intro wheelchair were all moved to happens-in-front-of-you on playtest
    feedback across two sessions. In rooms this dark an anomaly nobody witnesses is one nobody gets;
    the music box survives because it is meant to be *discovered* on the way out, not watched
  - The music box is a **real object** (`music_box.gd`) with the loop as its CHILD — that is the only
    reason the sound travels with it. It used to be a bare `_loop_audio` with no body at all. **E
    winds it**: the crank turns and the tune comes up out of the room tone for ~22 s, re-windable
  - ⚠️ **The falling painting moved BEDROOM → CHILD'S ROOM (2026-08-16, the user's proposal).** Stage 1
    fires when the map is solved, and after that the Bedroom is off every remaining route — map → key
    → Kitchen → cellar → the exit lock never re-enters it — so the level's most expensive scripted
    beat was staged in a room the player had already finished with. The ChildRoom holds the exit lock
    and cannot be skipped. `painting_house.png` and the child's crayon drawing simply **swapped
    walls**; the drawing took the Bedroom's south wall. ⚠️ `_drop_painting()`'s landing offset now
    runs along the panel's **own forward** (`basis.z`) instead of the hard-coded `p.z + 0.55`, which
    was correct only for a panel facing +z and would have slid this one a metre sideways into the
    plaster
  - ⚠️ **…and then, one replay later, EAST WALL → NORTH WALL, BESIDE THE EXIT DOOR** (2026-08-16:
    *"let it be next to the door so once you approach the lock it falls"*). The right ROOM was not
    enough — on the east wall the beat merely happened somewhere in the same room. It now hangs at
    `PAINTING_X = 0.85` on the north wall; the exit door occupies x −1.33…−0.08, so there is ~0.5 m
    of wall between them and the panel is in the frame you are looking at while you work the lock.
    ⚠️ Not on a doorway — ChildRoom's only `RoomBuilder` doorway is SOUTH at (0, 14); the exit door
    in the north wall is a prop. The 0.55 m landing slide puts it at (0.85, 0.06, 18.29), clear of
    the small bed and clear of the walking line to the lock at x = −0.7
  - ⚠️ **The drop needs LINE OF SIGHT, not just range and a facing dot** (Issue 77). Distance +
    facing alone is a test for *pointing at*, and in a house it is satisfied through walls: the
    2026-08-16 log has the painting falling **1.5 s after the key was taken and ~130 s before the
    player entered the room**, through the Landing's south wall, to nobody. `_painting_in_sight()`
    is one ray from the eye, excluding the panel's own body and the player
  - ⚠️ **The fallen panel goes to `collision_layer = 2`** (`note.gd`'s raycast-hittable /
    movement-invisible convention). Pitched flat it is a 0.8 × 1.0 footprint standing 11 cm proud of
    the boards and `move_and_slide` cannot step up; measured, it split the north end of the room —
    the end the lock is on — from one free lane into two. Gaze panic is unaffected, because the gaze
    ray uses the default all-layers mask
  - ⚠️ The music-box wind is two streams that must both come back: the recording plays at `LOUD_DB`
    while the room-tone bed **ducks to `BED_DUCK_DB` rather than stopping**, and both return after
    `PLAY_TIME`. A duck with no restore is Issue 50's shape; `tests/check_music_box.gd` waits past
    the wind-down in real time and asserts the bed is back
- **THE CELLAR SEQUENCE** — three scripted beats on reaching the bottom of the ramp, timed to the
  user's spec: every lamp AND the torch die instantly → **5.5 s of nothing** → the child, screaming,
  ~3.2 m in front of wherever the player is facing → **3.0 s later** the lights return and it is gone
  - ⚠️ **The dark-zone and standstill taxes are SUSPENDED for the whole sequence**
    (`player.set_smiler_active(true)`). ⚠️ **The cellar's `DarkZone` was REMOVED in the darkness pass
    (D4) — the whole House is unlit until the three safe notes are read, and the cellar's `DreadZone`
    is kept.** The suspension stays: forcing the torch off would
    otherwise charge +3/s for a scripted event with no counter-play — Issue 18, and the player died
    there at 99 % panic on the run that prompted this
  - The figure is a `Watcher` (zero panic, no collider, no rules) at **1.95 m** — deliberately taller
    than a child, because at child height it read as small and far away rather than on top of you.
    `childe_scream` at +18 dB with `max_db` raised to 24, or the gain is clamped away
  - ⚠️ Two earlier placements FAILED SILENTLY and both are worth remembering: spawning it on the
    milestone put it two rooms from the player, `Watcher.spawn()`'s line-of-sight check failed
    through the walls, it returned null and the one-shot flag was already set — no figure, no
    scream, no darkness, ever. Spawn a scripted beat where the player IS
  - ⚠️ **Only ONE figure down here.** The atmosphere pass also put a `Watcher` in the far corner;
    it was cut, because the mood piece arrived first and spent the surprise the event needed
  - ⚠️ **IT IS POSTPONED, NEVER FIRED BLIND (2026-08-16).** `_cellar_child_appear()` re-arms itself on
    a 0.25 s timer while `NoteUI.is_open`, `get_tree().paused` **or** `player.is_input_frozen()` — the
    same three conditions `apparition_director.gd` refuses on, and the level's own set-piece checked
    none of them. It measurably needed to: the 2026-08-16 log has the child spawning at t=206.98
    *inside* a beartrap QTE that started at 205.48, with a countdown UI over the screen. And
    `SceneTreeTimer` defaults to `process_always = true`, so the old bare `create_timer()` fired
    straight through a tree pause as well. ⚠️ `CHILD_POSTPONE_MAX` (45 s) is the safety valve: the
    blackout's END is armed by the appearance, so a beat that postponed for ever would strand the
    player with no lamps and no torch. Past it, the figure is given up and the lights come back
  - ⚠️ **`require_los = true` on every `Watcher.spawn` here.** It was `false`, which `watcher.gd`
    restricts to `congregation.gd`, and the LOS ray is the ONLY probe that catches "inside a wall"
    (Issues 40/59) — so the `[3.2, 2.4, 1.8]` ladder below it was dead code. Measured with the flag
    off, a player facing the cellar's south wall from 0.7 m got the figure at z = −11.9, **2.5 m
    beyond the wall.** With it on, the ladder is refused and the room-centre fallback runs
  - ⚠️ **DELIBERATE (2026-08-16): the cellar beartrap STAYS on the forced-blind entry line.** It sits
    1.6 m past the blackout trigger on the only heading in, inside an 8.5 s window with no lamp and
    no torch, and it fired in both playtest sessions. The user was shown that measurement and chose
    to leave it. That is what makes the postponement guard above load-bearing rather than tidy —
    the collision will keep happening
- **The Kitchen** (42 m², previously ONE prop): sink, table and chairs built from real parts, plus
  a **fridge** (`house_fridge.gd`) — it hums, and on E the scream fires FIRST, the door swings 0.28 s
  later, and a head is revealed on the shelf as it clears. **10 panic, the only new panic term in the
  whole atmosphere pass**; voluntary, optional, off the quest path, one-shot, and inert afterwards
  - ⚠️ The carcass is an **open-fronted shell of five slabs**, not a solid box — see Issue 46
  - ⚠️ **The door is hinged on the +X edge and swings +105° OUT (fixed 2026-08-16, Issue 69).** The
    hinge used to sit on −X, and rotating that free edge by +105° carried it toward local −Z, i.e.
    *backwards through the shell* — the playtest capture of an "open" fridge contains no door and no
    handle at all, because both were inside the box. The hinge moved rather than the angle flipping,
    on the user's call: it is also the edge furthest along the approach from the Hallway doorway, so
    the panel uncovers the cavity toward the player instead of sweeping across the kitchen table
  - ⚠️ `REVEAL_DELAY = 0.62` was **NOT** retimed. The second half of that same report ("the head
    appears not immediately") is a symptom of the door: the head is meant to be revealed *as the door
    clears it*, and with nothing clearing, 0.62 s reads as a pause in front of an open box
  - ⚠️ The lower wire shelf is `SIZE.y * 0.34`, not 0.40 — at 0.40 it drew straight across the bottom
    7 cm of the face, which is the same capture. The head now RESTS on that shelf, clear of both
- **The kitchen drawer** (`kitchen_drawer.gd`) carries a second, independent hint for **KONTUR Gate 1**
  ("the black door is the way out, the red one is not a door" — the rule, never a position, since the
  colours swap per run). Gate 1's only other hint is in the Lab morgue behind a beartrap and two
  instant-fail objects, and getting it wrong BANISHES rather than costs a strike
  - ⚠️ **It opens BEFORE the note, and it opens OUTWARD (both fixed 2026-08-16, Issue 73).** It was
    Issue 58 verbatim — the slide Tween started and `NoteUI.show_note()` was called two statements
    later, and `show_note()` pauses the tree, so the drawer only moved once the page was dismissed.
    The note is now fired from the tween's `finished`. And `SLIDE` is **−0.34**: it was +0.34, which
    drove the panel 34 cm into the counter it is set into, so the corrected ordering would still have
    revealed nothing. `tests/check_open_then_read.gd` measures the slide at the moment the note
    appears **and** asserts the opened drawer is inside no CSG box
  - ⚠️ **ONLY THE VISUALS SLIDE — the collider never leaves the counter face (2026-08-16, Issue 76).**
    The tween moved `self`, a `StaticBody3D` whose child is the `CollisionShape3D`, so an open drawer
    put a 0.62 × 0.26 × 0.14 solid 34 cm out into the room. Measured with the player's own capsule:
    the free lane across the Kitchen at z = 7.40 went from **ONE 5.10 m span to two of 1.30 m and
    2.50 m**, and that lane was the only way past the counter — the playtester was carrying the cellar
    key. Everything visible now hangs off a `DrawerSlide` child; the body is fixed. **An interactable
    in this game may never move a collider into a walkway.** Guarded by `tests/autoplay_house_route.gd`
  - ⚠️ **And it is a DRAWER, not a panel.** It was a single 2 cm board with nothing behind it, so a
    34 cm slide out of a featureless counter rendered as a pale plank hanging in mid-air, which is what
    the user photographed and read as fallen debris. Two sides, a bottom and a back run back into the
    counter (invisible while shut); the handle moved to the **−z** face, having been on the one buried
    in the worktop
- ⚠️ **Furniture is built from PARTS, never one flat box.** Two rounds of playtest photographed the
  beds, chairs, table and music box and called them "boxes that do not make any sense". What makes a
  bed legible is the headboard and a mattress proud of the frame; what makes a chair legible is the
  back. Issue 35 in furniture form. The cellar's shelving/boiler/crates and the kitchen sink slab
  were **deleted** rather than rebuilt — they sat in near-total darkness and read as nothing
- 3 safe notes (one digit each — **the third is in the cellar**, forcing the descent), 2 trap notes (`is_trap`, read-to-die)
- Win: read the 3 safe notes, enter code **472** on the combination lock by the child's-room exit (`CODE_ENTERED`)
- Fail: read a trap note **fully**; the apparition rush; or panic bar fills. Read-to-die: trap notes feed +12 panic/s while open (`TRAP_PANIC_RATE` in `note.gd`, ticked by `note_ui.gd`); text bleeds red; close early to survive
- **The window + Forest scare** (`_spawn_window()`): a moonlit forest (`forest.png`) behind glass on the living-room north wall (quads rotated PI to face the room, inset 0.25 to sit proud of the wall, culling disabled). Press up (≤1.5 m) → SURVIVABLE `flash_scare(screamer_forest.png)` + jolt + 25 panic
- **Scares**: cursed props (bedroom painting 0.8, living-room mirror 1.2) + a TV-static gaze panel (`tv_static_face.png`); a one-way mirror (`living_mirror.gd`) in the bathroom; a music box (`music_box.wav`) in the child's room; the cellar is a `DreadZone`+`DarkZone` with water drips, a beartrap, and a non-teach HOLD apparition; pipe groans + random blackouts on timers; 3 `CorridorEvent` triggers (door slam +8, footsteps overhead +6, bedroom light dies +6 → `DarkZone`)
- **Lock penalty**: each wrong combination = harsh buzz (`lock_buzz.wav`) + 10 panic — brute-forcing the lock is itself a fail path


## DECISIONS & GOTCHAS

Dated change entries, newest first — why the level is the way it is, what was measured, what was
tried and rejected. ⚠️ Anything marked **DELIBERATE** or **the user's call** must not be
re-litigated without asking.

⚠️ `⚠️` gotchas that describe *current* behaviour stay inline in **SPEC** above: in this codebase
the rule and its reason are usually one sentence, and splitting them would break the sentence.

- ⭐ **2026-09-16 (H4, `BACKLOG_Sep_16c.md`):** the cellar child fires when the **cellar NOTE is
  closed** (`_arm_child_on_note_close`, a one-shot on `NoteUI.closed`), pinning the player at the
  note; the ramp's foot keeps only the scrawl. Its scream is **`screamer_house`** (baba yaga, the
  user's call) at 0 dB / `max_db` 6. **H5:** a red **WHERE AM I?** scrawl at `CELLAR_WHERE_AT` 0.7 s,
  held 2 s, faded by 4.7 s — timed to be GONE before the doll at 5.5 s.
- ⭐ **2026-09-16 (H2/H3):** the cellar's scripted HOLD apparition is **deleted** (it spent the
  doll 5 s early); the director's random one stays upstairs. The cellar blackout **pins the
  player** (`_begin_cellar_blackout` freezes; `_can_show_child` ignores that pin) until the child
  has appeared. "Collect the key." uses the lower caption slot.
- ⭐ **2026-09-15 (H1, Issue 214):** the cellar apparition **retries on an abort** — latches only
  when `ApparitionDirector.arm()` returns true, else respawns and re-polls every 0.25 s for 20 s
  (`_tick_apparition_retry`, refused while paused / a note is open).
- ⭐⭐ **2026-09-13 (H1b):** the map's glass is a **ROOM**: `_place_glass()` glazes every open edge of
  the key's cell (`_pane_rects`, solid to the icon and the monsters until `_break_glass()`); the mark
  is `house_map_key_icon.png` and the hammer icon was redrawn upright (`tools/make_map_icons.py`).
  `_is_won()` = fragments empty AND `_glass_broken` AND on the key; the hammer meets a pane through
  `_check_fragments()` → `_check_glass()`, so the bot harnesses hit it. 28/40 unchanged.
- ⭐⭐ **2026-09-13 (`BACKLOG_Sep_13.md` H1–H4):** the map game's stages are a **hammer** and a
  **glass case with the key in it** (`tools/make_map_icons.py`; the seal is a glass pane, a
  `glass_shatter` + cracked case for `WIN_HOLD` 0.4 s on the win; no mechanic moved). The
  **second digit is on the forehead of the head in the fridge** (`house_fridge_thing_digit.png`,
  read by gaze → `SafeNote_Head`), the fridge wears a **chain + padlock** (`chained`,
  `chain_tried` → the level cuts it if the **bolt cutters** are held), and the cutters lie
  half under the Bedroom bed, `visible` only with the torch aimed ≤ −30° from within 3.2 m
  (`bolt_cutters.gd`, `_tick_cutters`). `SafeNote_Bedroom` is gone; `SAFE_NOTES_TOTAL` stays 3.
  The cellar child's scream is re-mastered to −3 dBFS and lands 0.3 s into the dip. The
  correct code makes the lock FALL (`lock_drop.wav`) and the door asks **ARE YOU SURE YOU WANT
  TO GO IN THERE?** Guards: `check_house_fridge_chain`, `check_house_lock`, `check_maze_traps`.
- ⭐⭐ **AND DARKER STILL SINCE 2026-09-07** — the same change as the Lab, for the same reason:
  `set_torch_profile(11.0, 24.0)` and `DARK_AMBIENT` 0.02 → **0.0**, with every self-lit prop
  halved (the forest window 0.90 → 0.40, the TV static panel 0.70 → 0.30, notes 0.60 → 0.25, the
  cellar key's card 0.50 → 0.30, the two `LivingMirror` figures 0.50 → 0.25, the doors 0.08 →
  0.03). ⚠️ **And the cellar key's own `OmniLight3D` is OFF.** It was created as a child of the key
  and never appended to `_lights`, so `_drive_lights()` — the one function that holds this level's
  ten lamps at zero — had no idea it existed: from the moment the map minigame was won until the
  key was picked up it burned at 0.35 energy over a 2.5 m radius, i.e. it was the only real light
  source in the building. Kept at zero rather than deleted, so the decision has a record.
- ⭐ **PITCH BLACK UNTIL EVERY NOTE IS FOUND, AND THEN ONE LAMP (2026-09-03, the user's call).**
  `DARK_AMBIENT` 0.02, every lamp held at zero by `_drive_lights()`; reading all three SAFE notes
  fades up `Lamp_Lock` — the wall lamp beside the combination lock at the far end of the
  ChildRoom, which has existed at energy 0.4 since long before this — over `LAMP_ON_FADE` 2.2 s,
  with a new positional `lamp_wake` sting AT the lamp. ⚠️ **Only that one.** The Lab already owns
  the everything-at-once relief; this beat is a single warm point at the end of a black house that
  you then have to walk to, and a second lamp spends it.
- ⭐⭐ **THE CELLAR CHILD IS IN YOUR FACE AND THE CAMERA IS FORCED TO IT (2026-09-10, capture #7).**
  `_cellar_child_appear()` now tries a player-relative ladder — `CHILD_NEAR [1.7, 2.0, 2.4]` ahead,
  ±`CHILD_FAN_DEG` 25° at 2.0, 3.2 ahead, then 2.0/2.6 BEHIND, then the room centre — through
  `Watcher.spawn(require_los = true)`; on success it zeroes the velocity, `freeze_input()`s,
  `turn_to_face(child + 1.35 m, CHILD_TURN_TIME 0.45)` and dips the bed (`CHILD_DIP` 0.4), the Lab
  nook's idiom. `_end_cellar_blackout()` unfreezes. The bullet below still says "~3.2 m in front
  of wherever the player is facing" — that is the OLD ladder. `check_house_guest.gd` asserts ≤ 2.6
  m, dot ≥ 0.9 after the turn, pinned then released, and case (iii) (nose to the wall) now
  REQUIRES a figure behind and the turn. Zero panic as before.
- ⭐ **THE KITCHEN DRAWER IS TWO PRESSES NOW (2026-09-10, capture #5: *"The note should be
  physically seen in this cabinet before it will be taken"*).** E slides it open and a real page
  (`DrawerPage`, a nested layer-2 body on `DrawerSlide`, art `kontur_note_page.png` cropped to the
  quad's aspect, collider `disabled` until the slide finishes) lies in it; a second, separate E
  takes and reads it, and only then does `record_note()` run. `lab_cabinet_drawer.gd`'s beat, and
  the Flood's. `can_interact()` on the drawer is `not _opened`; the page's is "open and present".
  `check_open_then_read.gd`'s House section asserts no note and no journal entry after E1, that the
  shipping ray finds the PAGE, and that E2 archives exactly once. `check_wall_overlap.gd` waives
  `DrawerPageSheet` by name (it lies inside the counter while shut).
