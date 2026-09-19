# Level 1 — The Lab — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Level 1 — The Lab (institutional wing)** — rebuilt procedurally (Session 10)
- ⭐⭐ **2026-09-16 (`BACKLOG_Sep_16b.md` W1, Issue 217):** the dark-wing payoff is **breathing
  cuts → 1 s silence → the figure at arm's length**: `_nook_breath_cut` → `_nook_reveal` builds a
  glowing `DoorLunger` "NookFigure" placed by `_place_nook_figure` (a ray fan off the player's
  own corridor, ALWAYS finite), pins and turns the camera, scream over a `HoldBreath` dip, lunges
  to `NOOK_LUNGE_DIST` 0.65, holds 0.4 s, +20, flees as the wing lights. The watch and the
  3 m trigger are gone (the user's redesign); the log records distance and room.
- ⭐⭐ **2026-09-15 (`BACKLOG_Sep_15.md` L1, the user's design):** the taught HOLD apparition
  appears **3 s after the FIRST breaker** (`_arm_apparition("breaker 1")` from `_on_breaker_flipped`,
  `APPARITION_AT` (3, 3), the retry idiom of Issue 207 kept, camera brought to it if needed) and it
  is **the ONLY apparition in the Lab**: `RANDOM_APPARITIONS = false`, no keycard arming, no
  director. `count_apparitions` asserts exactly one appearance; `check_lab_apparition_timing`
  asserts nothing before the first breaker.
- ⭐⭐ **2026-09-13 (evening playtest, `BACKLOG_Sep_13b.md` L1/L2):** **nothing fullscreen before
  the keycard** — the nook payoff keeps its turned-camera figure, scream and +20 but the
  `lab_nook_face.png` flash is GONE (the figure holds `NOOK_FIGURE_HOLD` 0.6 s instead), and the
  wing is **28 rooms with two LOOPS** (Plant→PlantDrop→Cistern; NorthVault→VaultRun→VaultNeck→
  Gallery→Riser) and every dead end two rooms deep (PumpPit, SumpWell, VentShaft, BoilerPit); the
  PANEL HUM meter is **near-only** (`LabWingMeter.NEAR_HOPS` 3, doorway hops) and the laugh window
  is 30–70 s. Issue 205 (two doorways closer than 2.6 m z-fight their bridges).
- ⭐⭐ **2026-09-14 (`BACKLOG_Sep_14.md` L1–L3, the user's second run):** the HOLD apparition
  **retries on an abort and latches only on an appearance** (`Apparition.appear() -> bool`,
  `ApparitionDirector.arm()` returns it, deadline on the wall clock — Issue 207; the second run
  never saw it); the **wing screamer is unmissable**: the `DoorLunger` glows (`set_glow` 1.6 +
  `add_light`, Issue 208), the player is pinned and turned to it, it holds `WING_SCREAM_HOLD` 1.4 s
  and flees (centre luminance 0.0006 → 0.109, `screenshot_wing_screamer.gd`); and the **PANEL HUM
  meter is live everywhere in the wing again** (the near-only gating is reverted, the user's call).
- ⭐⭐ **THE WING IS TWENTY-EIGHT ROOMS SINCE 2026-09-13 (`BACKLOG_Sep_13.md` L1, the user's
  design).** `SouthHall` now runs on into a second tier — Cistern (the old nook) → LowerRun →
  Crossing → FarHall → Turn → Shaft → **BreakerNook at (−57, 16.5), breaker on its WEST wall**
  (`BREAKER_POS` (−59.85, 1.1, 16.5)) — with Sump, Vent, Gallery and Boiler as new dead ends:
  6 decisions, 4 dead ends, ~62 m of path. The markers are **dark red** (`MARK_COLOUR`), the
  breaker beat waits **`NOOK_SCARE_DELAY` 20 s** of breathing, and the wing carries three beats
  (`_tick_wing_beats`): **the presence** (`lab_wing_hunter.gd`, follows your footstep trail at
  1.6 m/s while you walk, stops when you stop, never inside 2.5 m, a contact is +12 and it drops
  back 6 m; wakes at Junction, sleeps when the wing lights), **the laugh** (`wing_laugh.ogg`,
  once, 30–70 s in, from a room you have not visited) and **the mid-search screamer**
  (`wing_monster.png` as a `DoorLunger`, once, ≥ 8 m from the breaker, +15, no fullscreen
  image). The HOLD apparition arms from the FIRST BREAKER now (`APPARITION_AT` 3 s after it,
  deadline 30) and never fires in the wing (`_in_wing()`). Guards: `walk_lab_wing`,
  `check_wing_meter`, `check_wing_markers` (30 doorways), `check_wing_beats`,
  `check_lab_apparition_timing`. Issue 200 was found on the way.
- ⭐⭐ **DARKER STILL SINCE 2026-09-07 — THE BEAM, NOT THE AMBIENT.** The user: *"you need to come
  closer to the objects with the flashlights to see them."* Ambient was already 0.02 and every lamp
  already held at zero, so the only lever left was the torch: `level_1.gd` calls
  `player.set_torch_profile(TORCH_RANGE 11.0, TORCH_ANGLE 24.0)` in `_ready()` — Godot runs a
  child's `_ready()` before its parent's, so the level narrows the 18 m / 30° default afterwards —
  and `DARK_AMBIENT` goes **0.02 → 0.0**. ⚠️ **Lab and House ONLY.** KONTUR, the Corridor and the
  Breach keep the wide beam, and `level_6_breach.gd:LIGHT_WEAPON_DOT` (= `cos(FLASH_ANGLE)`) with
  it; a global narrowing would silently desync the light weapon from the light.
  ⚠️ **And everything that lights ITSELF is halved** (cross-level X64/X65, resolved by the user):
  notes 0.60 → 0.25, the morgue monitor 0.85 → 0.30, the keycard 0.70 → 0.30, the surgical tray
  0.35 → 0.20, the Observation mirror figure 0.50 → 0.25, the exit and back doors 0.08 → 0.03. At
  ambient 0.0 a self-lit prop is the only thing visible at distance. **Dimmed, not killed**: the
  Observation maintenance note gates the locker that gates the third breaker, so a note nobody can
  find is a level nobody can finish. ⚠️ `note.gd`, `door.gd` and `living_mirror.gd` gained an
  ADDITIVE `emission_scale` defaulting to 1.0, so every other level renders byte for byte as
  before. ⚠️ `check_darkness.gd` reads the CONSTANTS off `player.gd` and is therefore blind to a
  per-level override — it now also asserts the light each scene ends up with, with a control that
  plants the default back and requires red.
  ⚠️ **MEASURED, `tests/screenshot_torch_reach.gd`** (prop's own screen rectangle against a ring of
  the wall around it — contrast, never an absolute level, Issue 62). Lab, torch ON: the Records
  locker reads **0.233 / 0.311 / 0.273** at 2 / 3 / 4.5 m; an exam table **0.089 → 0.034** from
  2 m to 8 m, and by 8 m it is DARKER than the wall behind it (ratio 0.42) — a silhouette rather
  than an object. Torch OFF, every prop in both levels reads **0.0000–0.0004**, i.e. the unlit
  world is genuinely black rather than nearly black. ⚠️ Read the MEAN, not the peak: the crosshair
  is a 0.698-luminance `Label` dead centre and lands inside every prop's bounding box.
- ⭐⭐ **RECORDS IS LIT BEFORE THE POWER, AND THE WING'S DOORWAYS GLOW (2026-09-10, captures #3/#4,
  the user's choice: *"Doorway markers + lit Records"*).** `PRE_POWER_LIT := {"Lamp_Records":
  EMERGENCY_ENERGY}` — `_drive_lights()` substitutes that base for a named lamp while `_power_on`
  is false, so Records is the ONE lit room before the breakers (its 11 m spill through the wing
  entrance is the "home bearing"); everything else stays at zero and `check_darkness.gd` asserts
  that exactly those names burn and nothing else. And every doorway inside the 28-room dark wing
  wears four **photoluminescent strips** (`_spawn_wing_markers()`, `WingMark_<i>_<room>_<side>`,
  `MARK_EMISSION` 0.14, dark red, no collider) that **fade with distance** — full inside `MARK_NEAR`
  6 m, gone past `MARK_FAR` 12 m — so the topology is read locally rather than as a lit map. They
  show DOORWAYS, never the answer: the rooms stay black and the beacon + meter still own the
  bearing (the user's *"easier but not too easy"*). `check_wing_markers.gd` (13 checks) and
  `screenshot_wing_markers.gd`.
- ⭐ **PITCH BLACK UNTIL THE POWER IS RESTORED (2026-09-03, the user's call).** `_boost_ambient`
  runs at `DARK_AMBIENT` 0.0 and `_drive_lights()` holds every lamp — and every fitting's
  emission — at ZERO while `_power_on` is false; the third breaker raises the lot and tweens the
  ambient back to `LIT_AMBIENT` 0.35 over 1.2 s. ⚠️ **The lamps are not deleted**:
  `check_fixtures.gd` asserts a minimum FITTING COUNT per level (Lab ≥ 8) and every fitting is
  created by `_add_lamp()`, so darkening by deletion turns that guard red — and
  `_on_breaker_flipped()`/`_restore_power()` both use `entry[1] > 0.0` to tell "spawned dark on
  purpose" (the Morgue, the 28-room wing) from "currently unlit", which zeroing would erase
  (Issue 36). ⚠️ `_accent_lamp()` now appends to `_lights` too — it did not, so its three prop
  glows were the only lights in the building and burned through the level's own blackouts.
  ⚠️ **The Morgue and the wing stay dark after the power returns**, exactly as before.
- ⚠️ **The morgue's `DarkZone` is GONE** (D4). It charged +3/s for having the torch off, which was
  a fair price for a CHOICE while the rest of the Lab was lit; with the level at 0.02 the torch is
  mandatory everywhere, so the tax stopped distinguishing the morgue from anything else and only
  ever fired in moments the player had no say over. Issue 18. `check_darkness.gd` asserts the
  absence with a control.
- Built at runtime in `level_1.gd` via `RoomBuilder` from a 10-room graph (`ROOMS`/`DOORS`): reception → main corridor with 2 exam rooms → a cross-junction onto the records room and a **sealed morgue** → observation room → exit vestibule. The `.tscn` keeps only `Player`/`Environment`/audio/`HUDCanvas`; `_clear_old_scene()` frees the old hand-built nodes via a `PRESERVE` whitelist
- **Power-restore quest**: 3 `Breaker`s (`breaker.gd`) — Exam1, Records, and BreakerNook (see below). Each `flipped` → `_on_breaker_flipped()`; the third → `_restore_power()` lifts the lamps to full and drops the `MorgueShutter` (a `CSGBox3D` gating the morgue doorway). Three tiers, and **each tier is a different verb — see it / read for it / hear it**. Exam1 stays lit-and-obvious on its wall centre. ⚠️ **No breaker self-illuminates** — the panel used to wear its own art as an `emission_texture` (0.25) and the lever glowed at 0.7, which made even the deliberately-hidden Records one the brightest object in the level (playtest capture #1; ISSUES_SOLUTIONS Issue 33, an Issue-27 recurrence). `glows` now gates only the lever *indicator* at `INDICATOR_EMISSION = 0.12`, because red-vs-green is state feedback rather than an affordance. Records' note and warning sign live on its previously-unused north wall (their old spot became the DarkCorridor doorway)
  - ⚠️ **`_restore_power()` must skip the rooms spawned dark.** `_spawn_lights()` gives EVERY room in `ROOMS` a lamp and hands the twenty-nine `NO_LAMP_ROOMS` one at energy 0.0 — dark because the lamp is off, not because there is no lamp. `_restore_power()` used to raise all of them unconditionally, floodlighting the Morgue (whose whole design is `DarkZone` + beartrap + don't-look triggers) and the entire navigate-by-ear wing. It now carries the same `if entry[1] > 0.0` guard `_on_breaker_flipped()` always had. ISSUES_SOLUTIONS **Issue 36**; regression-locked by `tests/check_lab_locker.gd`
- **Records breaker — the locker** (`lab_locker.gd`, 2026-07-26): the panel isn't merely hidden, it is **physically sealed** behind a steel locker standing flush against it, so the interaction ray hits the locker first. ⚠️ **The locker is a COVER; the GATE is `Breaker.blocked` (2026-08-16).** Occlusion degrades continuously and a three-stage push therefore opened at stage two: measured, one shove leaves the panel unreachable but two clears it entirely and the player found that on the first playtest (*"Even though I did not pull the case till the end, I still could flip the breaker"*). `breaker.gd` now has `blocked` / `unblock()` / `can_interact()`; `level_1.gd` sets it on the Records breaker and clears it **only** from `LabLocker.moved` — after the third bar and the settle tween — and again in `_restore_progress()`, because `move_aside_instantly()` deliberately does not emit `moved`. While blocked the breaker is completely inert: no prompt, no interact target, E does nothing. ISSUES_SOLUTIONS **Issue 57**; `tests/check_lab_breaker_gate.gd` drives the real `ai_interact()` path at 1 and 2 shoves and carries a positive control. Two gates: (1) `unlocked` flips only when the player reads the **maintenance note on Observation's south wall**, the opposite corner of the floor — before that, `interact()` prints a flat refusal toast; (2) the push itself, a tug-of-war bar fed by mashing **SPACE** (`push_effort`, a new `project.godot` action on `KEY_SPACE`) at `PUSH_PER_PRESS 0.10` against `PUSH_DECAY 0.18`/s. It takes **`SHOVES_NEEDED = 3` full bars**, not one — each fill lurches the locker and resets the bar (playtest 2026-07-26: *"probably we need to require more effort — currently too simple"*). ⚠️ **The travel is FRONT-LOADED onto the last bar (2026-08-16), and the locker is 1.4 m wide, not 1.0.** The flag above held, and the same player filed the prop as broken anyway on the next replay — *"I did 2 out of 3 rounds. Even though I cannot flip the breaker, I can see it very well. I should not see it fully once I do all 3 out of 3"* — because **a panel in plain sight that refuses to answer E reads as a bug, not as a locked door**. So the two intermediate lurches are now `SHOVE_DIST 0.14 m`, inside the 0.35 m the wider carcass overhangs the panel by, and the third bar slides the remaining 0.82 m of `TOTAL_TRAVEL 1.10` and is the one that actually reveals it. Measured by ray-sampling the panel's front face on a 13x17 grid from six eye positions (`check_lab_breaker_gate.gd`, 5304 rays): **0.0 % visible after 1 and after 2 shoves, 100 % front-on after 3**, against 15.4 % / 84.6 % / 100 % for the old uniform profile. ⚠️ **No difficulty constant moved** — `SHOVES_NEEDED`, `PUSH_PER_PRESS`, `PUSH_DECAY` and `PUSH_PANIC` are the user's call and are untouched; only what you can SEE at each stage changed. ISSUES_SOLUTIONS **Issue 57's amendment**. Staged rather than one longer bar on purpose: the note says it "moves in fits", and a single 10 s bar with no intermediate feedback reads as broken rather than as heavy. Failing just aborts and is retryable; `PUSH_PANIC 1.2`/s is the only cost. ⚠️ **Letting go keeps the shoves you have already made** — only the bar resets. The toast used to say *"the locker settles back"* and the maintenance note said *"it slides back the moment you stop"*; both were false, and both are what made the partial-shove bypass read as intended behaviour. Both were rewritten (2026-08-16). ⚠️ **The gate is HARD and there is deliberately NO pointer to the note** (confirmed with the user) — a player who never searches Observation cannot restore power. Don't soften it without asking
  - ⚠️ **Before the note it is COMPLETELY inert**, not merely refusing (playtest: *"press E should not even appear"*). `LabLocker.can_interact()` returns false, and `player.gd:_update_interact_prompt()` now consults an **optional `can_interact()`** on any prop before showing "Press E" *or* setting `_interact_target` — so E does literally nothing. Props without the method behave exactly as before; this is the general opt-out the project lacked
  - The push **does not pause the tree** (unlike `maze_chase_ui.gd`/`combination_lock.gd`) — `beartrap.gd` is the closer relative. `player.freeze_input()` blocks movement *and* look for free (`_apply_movement` and `_unhandled_input` both early-return on `_input_frozen`), which is the camera pin; the world keeps running behind you. The player is tweened onto a brace mark 0.9 m in front first — not framing polish, it is what stops the slide passing through them. ⚠️ `ARM_DELAY` is load-bearing: `interact` both *starts* the push and *cancels* it, and `_process` polls `Input.is_action_just_pressed`, so without it the opening press closes it on frame one (`note_ui.gd`'s `_block_close` exists for the same collision)
  - ⚠️ **The old spark/flicker tell is DELETED** (`_tick_breaker_spark` + its light, `BUG_FIX.md 4.1`). It did not hide the breaker, it pointed at it: the tell was the loudest and brightest thing in Records, so "search the room" collapsed into "walk toward the crackle". Do not re-add an ambient tell here. `breaker_spark.wav` and `BREAKER_SPARK_MIN/MAX` survive — `_tick_dark_breaker_tell` still uses them for the nook's flavour transient. The Records filing-cabinet bank was trimmed 3 → 2 units and shifted west to clear the locker's footprint
- **The dark wing — navigate-by-ear maze (rebuilt, playtest 2026-07-25)**: Exam2's breaker lives in **`BreakerNook`** at the far end of a **28-room lightless maze** off Records' west wall. Previous passes had 4 rooms and exactly one binary choice, which playtest called out as "too simple… make the geometry harder, and probably add some real audio so we can navigate based on that" (capture #2). Layout — `DarkCorridor` → `Junction` (**decision 1**, three ways) → *west* `WestCorridor`→`Plant` **(dead)** / *north* `NorthSpur`→`NorthVault` **(dead)** / *south* `SouthSpur`→`SouthHall` (**decision 3**) → `PumpRoom` **(dead)** or `BreakerNook`. Six decision points, four dead ends, ~62 m of walking; the terminus is ~48 m from Records' lamp, four times its 11 m range. ⚠️ Rooms are kept in three disjoint z-bands (north ≥14.5, middle 10.5–14.5, south ≤10.5) so limbs can't collide as the graph grows; a doorway only cuts walls its **span** overlaps (`room_builder.gd:199`), so planes are safely reused between bands. All 28 rooms are in `NO_LAMP_ROOMS` and share **one** flashlight-lock `Area3D` (`_spawn_breaker_nook_zone()`, bounds x −60..−12 / z 0.8..24 — re-derive it whenever `ROOMS` changes) that calls `player.lock_flashlight()` on entry and symmetrically `unlock_flashlight()` on exit; leaving is always the safety valve. It must stay **one** zone — adjacent Area3Ds fire `body_exited` before `body_entered` and would strobe the lock. **No `DarkZone`** anywhere in the wing (would double-tax the exact posture the premise requires — Issue 18)
  - **The tell is a real two-layer positional beacon** (`_spawn_dark_beacon`): a far cue (`breaker_hum`, `unit_size 16`) that carries the length of the wing and gives a **bearing**, plus a near confirm (`breaker_buzz`, `unit_size 9`) that only resolves in the last room or two and distinguishes "right branch" from merely "right direction". Both are continuous loops at the breaker, self-restarting via `finished → play` (every `.wav.import` here is `loop_mode=0`); both generated by `tools/make_sfx_extra.py`. Pattern lifted from `backrooms_zone2.gd`, whose header comment is a post-mortem of this same mistake. The 8–12 s `breaker_spark` transient stays on top as flavour only
  - ⚠️ **DELIBERATE (2026-08-16) — there IS a meter again, and it is not the old one.** `lab_wing_meter.gd` (`LabWingMeter`), a bottom-of-screen "PANEL HUM" scale shown only inside the wing and freed the instant the breaker is thrown. Added on the user's **explicit call**, made after being shown ISSUES_SOLUTIONS Issue 34 *and* `GAME_MECHANICS_IDEAS` §5.2(2), both of which name this widget as a thing the project does not build (*"finding your way through sounds only in the complete dark is hard for the unexperienced user"*). **Do not re-litigate it and do not delete it as a regression.** ⚠️ **The condition attached to it is that it may not LIE.** The deleted `panic_hud.set_breaker_proximity()` measured straight-line distance and read a warm ~0.43 from inside a dead end — it pointed at a wall, and it also masked the fact that `_spawn_dark_breaker_tell()` was a one-line stub that spawned nothing (Issue 34). This one runs **Dijkstra over the wing's own doorway graph** (`setup(ROOMS, DOORS, WING_ROOMS, breaker_pos, "BreakerNook")`) and normalises against the furthest room's path distance, so the scale is derived from the geometry rather than typed in. Measured on the shipped layout: **Plant reads 0.04** — 30.0 m of walking against 6.6 m of straight line, a 4.6× lie the old bar would have reported as 0.79 — while the real route reads 0.15 → 0.31 → 0.37 → 0.46 → 0.65 → 0.80 → 0.96, and outside the wing it reports **no reading at all**. Locked down by `tests/check_wing_meter.gd`. It is a scalar: the two-layer beacon still owns BEARING, which is the half of a maze a number cannot answer
  - ⚠️ **The panel DID leak, and the measurement that said otherwise was wrong (2026-08-16).** The user reported it twice — *"I can see this breaker visually - it should appear only when I am very close to it"*, then, from 9.4 m with the torch off, *"I am standing far away from the breaker and I see it. Should be darker"* with a screenshot of a black frame containing a legible pale rectangle. The first probe reported *"peak ~1.5 of 255, wall 0.0000, does not leak"* and that conclusion is **retracted**: it compared an ABSOLUTE level against a background of zero (against 0.0000, 1.5/255 is not dim, it is the only thing in the frame), it averaged an 11x11 box at the panel's CENTRE when the leak was the panel's bright BORDER, and it sampled un-scaled `unproject_position()` coordinates into a HiDPI image so it was reading the wall, not the panel. See ISSUES_SOLUTIONS **Issue 62** — *a measurement that is physically correct and perceptually wrong*.
  - **The real cause was the ART.** `lab_breaker_panel.png` shipped as an opaque RGB PNG whose background was a **baked alpha checkerboard** — 20.05 % of its texels above 0.90 sRGB, border ring 0.974 — and near-white albedo is the brightest thing obtainable in a level with no glow, no fog and no tonemapping. `tools/flatten_alpha_checker.py` flood-fills that background dark from the image border and crops; the original is kept at `assets_src/textures/level_1_lab/lab_breaker_panel_raw.png`. On top of that, `Breaker` now tints a `glows = false` panel with `PANEL_TINT_DIM` (0.28) instead of `PANEL_TINT` (0.6). Re-measured as CONTRAST against the wall around it, torch locked off — panel max / p99.5 / pixels brighter than the surrounding wall: **4.1 · 4.1 · 856-of-9153 (9.4 %) before → 1.0 · 0.0 · 0-of-9153 after**, at 6, 10, 15 m and at the player's own capture pose alike. The panel is now DARKER than its wall. ISSUES_SOLUTIONS **Issue 63**; guarded headlessly by `tests/check_nook_dark.gd` and re-measurable on a display with `tests/screenshot_nook_panel.gd`. ⚠️ **The beacon and the meter remain the only ways to find it.**
  - **The wing lights up afterwards** (`_light_the_wing()`, called from `_nook_cleanup` — ⚠️ **and from
    `_restore_progress()` with `silent = true` since 2026-09-03**, because it is the ONLY caller of that
    function and a restored breaker never emits `flipped` again, so a back-door return used to rebuild
    the wing dark with its flashlight-lock zone respawned: a lightless 50 m maze whose puzzle was already
    solved and could not be re-solved. The tweens and the unlock are STATE and are restored; the toast
    is the EVENT and is suppressed): the flashlight-lock `Area3D` is freed, `unlock_flashlight()` is called, and the **28 wing rooms** fade to `WING_LIT_ENERGY 0.5`. Playtest 2026-07-26: *"after the jumpscare we need to turn on the light — because very hard to escape the place"* — the log showed 110 s of wandering afterwards, ending in a dead end. Partly this feature's own doing: throwing the breaker kills the beacons, so the scare removed the only landmark and then asked for a 50 m walk back in the dark. The darkness was never the point in itself; it was the cost of the navigate-by-ear puzzle, and that puzzle is *solved* the moment the breaker is thrown. ⚠️ This is a deliberate, narrow exception to Issue 36 covering `WING_ROOMS` **only** — the Morgue is in `NO_LAMP_ROOMS` too and must stay pitch black, because its `DarkZone`, beartrap and two don't-look triggers all assume a room searched by torchlight ⚠️ The toast now also says the torch works again (**[F]**) — `unlock_flashlight()` only clears the flag, and while the lock was on, F answered with the same dead-battery click a flat battery gives. The 2026-08-16 player pressed F once on the way in and never again: 306 s afterwards, including the whole DarkZone morgue, and a death in it. See `player.gd`'s locked-vs-dead split. ⚠️ **Deliberately SURVIVABLE** — no rule, no fail state. Flipping this breaker is mandatory, and an unavoidable event must never coin-flip a death; a player who can't SEE a figure materialise also can't judge "hold still or flee" (the KONTUR Gate 7 / Backrooms Flood mistake). The cost is real anyway: 20 of `PANIC_MAX` 50, then ~50 m back through the maze, where sprinting is +6/s with decay suppressed
  - ⚠️ The figure is **unshaded**, so the flare cannot light it — unshaded materials ignore lights entirely. (⚠️ 2026-07-27: the rest of this sentence used to claim *"nothing in this project casts shadows"* — that is **false**. The player's flashlight is a `shadow_enabled` `SpotLight3D` in all nine level scenes and renders real cast shadows; only the static `OmniLight3D` room lamps don't cast, which `level_1.gd:173-175` deliberately relies on. See `GAME_MECHANICS_IDEAS.md` §2.0a.) Its **alpha** is what's driven; the flare only throws the walls into relief. And `lab_nook_figure.png` must stay a real RGBA cutout or it billboards as a solid rectangle (the `apparition_figure.jpg` bug). `_place_nook_figure()` fans raycasts — ahead, ±90°, then behind — and takes the first direction with ≥1.8 m clearance, because the breaker is on the west wall and a naive forward spawn lands *inside* it; in practice it lands behind the player, between them and the way out
  - Verified by `tests/walk_lab_wing.gd` — drives a `CharacterBody3D` the whole route under gravity and proves each dead end dead with raycasts against the built CSG, never against the `DOORS` array that produced it — and by `tests/screenshot_nook_scare.gd`, which polls for the figure's alpha and for Screamer's panel to photograph both moments (a frame counter can't catch a 0.2 s window)
- **Guarded keycard** in the dark morgue (⚠️ **a `Beartrap` — the `DarkZone` was REMOVED in the
  2026-09-03 darkness pass (D4)**: the whole Lab is unlit until the three breakers are thrown, so a
  zone taxing the torch being off would charge for a posture the level now imposes, Issue 18): the card sits on a cart *between* the surgical tray and the face-monitor (both `trigger_object.gd` — instant fail on E or 3 s gaze), with a cursed poster (`poster_lab.png`, gaze panic) on the wall. Taking it fires `on_keycard_taken()`: 1.6 s light-blackout stutter + creak + 8 panic. **BUG_FIX.md 4.2**: the monitor trigger moved off the cart onto the morgue's east wall (`wall_point("Morgue", Vector2(1,0), …)`, `y_rot=PI/2` so its -z-facing screen quad turns to face -x into the room) — the wall directly opposite the only doorway (west, x=6), so it's the first thing visible on entry instead of something found at an angle on the cart. The tray is unaffected
- **Observation room**: a one-way mirror (`living_mirror.gd`) — a figure appears in the glass only when you are NOT looking head-on. The north wall carries the Backrooms whiteboard and, since 2026-08-16, **a printed transcript of the PA line pinned beside it** (`PA_NOTE_TEXT`, offset `WHITEBOARD_NOTE_OFFSET` off the same `wall_point`). The tannoy fires once, 1.4 s after the power returns, on top of the "Power restored" objective — and it is not a `Note`, so it never reached the journal. `_announce_trial_four()` now calls `GameState.record_note()` with the identical text, so the spoken and printed halves collapse to one TAB entry (playtest capture #2: *"shall we put another note next to this image, and this image remains untouched?"* — the artwork is untouched; what the diagram lacked was a sentence)
- **Records — the filing cabinets are real furniture, and the bank is a search** (`lab_cabinet.gd` + `lab_cabinet_drawer.gd`, 2026-08-16, capture #4: *"These object look way too useless"*). Two units, the same 0.7 × 1.3 × 0.6 footprint as the flat boxes they replace so all the clearance arithmetic above still holds, now built from plinth / carcass / top overhang / four proud drawer faces / handles / card holders, **flat-tinted and untextured** (Issue 35's answer in `kontur_mailbox.gd` and `intro_room.gd:_build_wheelchair()`). ⚠️ **The bank is a SEARCH, and the page must be TAKEN (2026-08-16, second revision).** It used to be one openable drawer on one unit, opening straight into the note; the player asked for the obvious better thing — *"Maybe we can do it in a way I could open all the boxes and only one would contain the note? Also I need to take it to start reading, now it reads automatically"*. So the cabinet itself no longer interacts at all: it is a carcass, and each of its four drawers is its own `LabCabinetDrawer` with its own interact volume. **Eight drawers across the bank, exactly one holding the page.** Opening an empty one slides it out and shows you the wrong paperwork — **no panic, no penalty, no fail state, nothing gated behind it**; the price of looking in the wrong place is the looking. ⚠️ **And it says NOTHING** (2026-08-16, verification replay): an empty drawer used to print a line of flavour, and the user cut it — *"What for to write these messages? They are not needed, the player will see there is nothing in there"*. The drawer sliding out with folders and no page IS the message; do not re-add a caption over something already on screen. The page in the right one lies in the tray as an OBJECT, and a **second, separate E** takes and reads it (`kontur_mailbox.gd`'s open-then-read beat, one step further). Opening stays **ONE effortless press** — the stiffness is KONTUR's mailbox only, confirmed with the user. ⚠️ **E CLOSES AN OPEN DRAWER AGAIN — the drawers are a TOGGLE (2026-08-16, third revision).** A drawer stands 0.34 m into the room while open, so it both hides and *shadows* every slot beneath it, and the bank used to seal itself as you searched it top-down (*"I cannot see what is under the top storages. I need to be able to close them by pressing the E button"*). Measured by ray from a standing eye position: with one drawer open **6 of 8** drawers in the bank answer E; with them shut, **8 of 8**. Issue 67. Closing is one effortless press too, and uses the same `metal_creak` pitched down and eased IN. ⚠️ **Which of the two nested props answers the ray is decided by STATE, never by aim** (`_refresh_layer()`): shut → the drawer (E opens); open with the page inside → the page (E takes it, the drawer goes inert); open and empty → the drawer (E shuts it). A single ray cannot reliably choose between a drawer face and a page lying 0.10 m behind and below it in a 0.26 m slot. The one consequence: **the drawer holding the page cannot be shut until the page is out of it**, which costs a press the player wanted to make anyway. ⚠️ **Closing resets nothing** — a page already taken never comes back. (There was a `_searched` flag and a `drawers_searched` snapshot key here; both existed only to stop the flavour line repeating, so both went with it rather than staying as a field nobody reads.) ⚠️ **Which drawer holds it is randomised per run** and captured in `save_progress()` (`hint_cab` / `hint_slot` / `hint_taken` / `drawers_opened`), never re-rolled on a back-door return — KONTUR's `_dark_x` rule. ⚠️ A drawer's interact volume is **0.08 m deep, not 0.20**: a volume proud of the face intercepts the downward rays aimed at the drawers BELOW it, which made 6 of 8 unreachable (Issue 65). ⚠️ And the page's own grab volume is **`disabled` until its drawer opens and disabled again the moment it starts closing**, not merely refusing — `can_interact()` false makes a prop inert, not transparent, so a page protruding 1 cm past its shut drawer's volume made **the one drawer holding the hint un-openable** (Issue 66). The close path disables it FIRST, before the tween starts, or the toggle reintroduces that bug on the return trip. Measured by `tests/check_lab_cabinet.gd` (8 of 8 answer E at 1.1 m and 25° off-axis; exactly one page; zero panic; the placement moves between runs and survives a snapshot; **the whole toggle cycle — close, reopen, the page collider in both directions, and taken-state surviving a close — and that an empty drawer puts NO text on the screen, counted as root-parented `Label`s across the open**) and `tests/check_open_then_read.gd` (opening shows nothing; the second press finds the PAGE, not the drawer). ⚠️ **The note is the Backrooms FLOOD's missing cross-level hint**: *some things are only there when the light is off*, stated as a RULE and never as a place (`kitchen_drawer.gd`'s rule, for the same reason), with a second paragraph that also covers the Smiler. The Flood's darkness tell was the one puzzle tell in the game with no earlier-level hint at all. Archived via `GameState.record_note()` on being taken, and the page is removed from the drawer once it is in your hands. ⚠️ **Both units are identical in every respect** — same parts, same four drawers, same faces and card holders. Nothing about the bank may hint at which drawer is the one, which is why the empty drawers have folders in them too
- **Scares**: random blackouts (all lamps stutter dark ~1.5 s) and pipe groans (`pipe_groan.wav`) on
  timers; a taught **HOLD apparition** (`apparition.gd`, `teach=true`). ⭐ **IT IS ON A CLOCK SINCE
  2026-09-03 (the user's call), NOT A TRIPWIRE.** It was armed by a `CorridorEvent` at z = 6.0 with
  a 3×3×1.5 extent, i.e. a near face at z = 5.25 — and the player spawns at z = −1.5 facing +z down
  an unobstructed 3 m corridor, so the game's designed teaching beat for the HOLD rule fired
  **6.75 m / about 1.7 seconds** into the level, identically, every run. It now arms at
  `randf_range(APPARITION_AT)` = 3 s and fires on the first poll that passes the same four
  fairness conditions `apparition_director.gd:_can_fire()` uses (not paused, no `NoteUI`, not
  `is_input_frozen()`, not `_in_breaker_nook`) — a HOLD apparition KILLS YOU FOR FLEEING, so it
  must not materialise at a moment the player cannot demonstrate standing their ground.
  ⚠️ `APPARITION_DEADLINE` 30 s drops those gates: the beat teaches a rule the player is killed by
  later, so it may be delayed but never cancelled. `check_lab_apparition_timing.gd`
- **Notes (2026-08-16 pass)**: every note now goes on a wall through `wall_point()`. ⚠️ The **TRIAL 7** page (NIGHTMARE hint 1/3) hung **in the morgue's doorway** for the life of the feature — `wall_point("Morgue", (-1,0))` returns the west wall's CENTRE and the morgue's only door is at exactly that centre, so there was no wall behind it (capture #7, *"the note is floating in the air"*); it moved to the morgue's **NORTH wall**, offset east of the cursed poster by `MORGUE_TRIAL7_OFFSET` (2.4 m), and was **trimmed 97 → 50 words** (capture #8) keeping both load-bearing facts verbatim in meaning — they hold while watched, and THE LIGHT ATTRACTS THEM. The **Reception briefing** note was hand-typed at (2.4, 1.4, −2.6) with the wall face at x = 2.90 — the first note in the game after the intro, floating 0.50 m out in the room — and is now `wall_point("Reception", (1,0), …)`. The **Records warning sign** was raised 1.8 → 2.05 m: at 1.8 it overlapped the night-log note beneath it by 11 cm with its layer-1 body 3 cm in front. ⚠️ **TRIAL 7 moved TWICE.** Its first destination was the south wall **1.6 m from the KONTUR circular**, which fixed the doorway and put both pages in one frame — *"These two notes at the morgue are at the same place. Let's at least put them into different parts of the room"*, with two `NOTE READ` events 1.7 s apart in the log (Issue 68). Separation is now **6.19 m and on opposite walls**; neither page leaves the morgue, because both are cross-level hints filed behind the beartrap and the instant-fail triggers on purpose. All of it is regression-locked by `tests/check_note_mounting.gd`, which fires a ray backwards along each prop's own normal and requires solid geometry within 0.35 m — ⚠️ a direction `check_wall_overlap.gd` structurally cannot see, since it only asserts MINIMUM clearances (cross-level item X1) — and which now also groups notes by room and refuses any same-room pair closer than `MIN_NOTE_SEPARATION` (2.5 m) **or** sharing a wall plane. ⚠️ That second guard is general and worth knowing about in every level: `wall_point(room, side) + a lateral offset` is the obvious way to place a second wall prop and it is exactly the move that produces this defect
- Win: restore power → take keycard from the morgue → exit door (`KEYCARD`). Fail: trigger object, apparition rush (if you sprint), or panic bar fills

## DECISIONS & GOTCHAS

⚠️ **Dated ⭐ entries live at the TOP of SPEC, not here.** They carry the level's *current* state and
override the older prose beneath them — that is how `CLAUDE.md` was written, and why entries say
things like *"every paragraph below that says 320 m is history"*.

⚠️ **The top-to-bottom order is NOT strictly newest-first.** Measured 2026-09-19: `01-lab.md`'s
2026-09-13 entry sits *above* the 2026-09-14 entry that reverts it, and `04-backrooms.md:302` sits
*below* the same-day entry that supersedes it. **Read the dates; where they tie, read the code.**

Use this section only for rationale that leaves **no trace** in the level — something tried and
abandoned. Anything describing what the level *is* belongs in SPEC.

⚠️ **Superseded 2026-09-16 (W1, the ⭐⭐ entry at the top of SPEC) — the old nook payoff.**
The watch, the 3 m position trigger, the 5 s of breathing and the `lab_nook_face.png` fullscreen
flash are all gone: `NOOK_SCARE_DELAY` is 20 s, `_nook_breath_cut` → `_nook_reveal` runs the beat,
and `_tick_nook_watch` / `NOOK_TRIGGER_DIST` stay declared but are never armed. Kept for the
rationale — why the scream leads the picture, and the 0.30 s *it moved* → *it's on you* gap:

  - **The payoff — the breathing, then a scripted reveal you are TURNED to face** (`_on_nook_breaker_flipped`, hooked to *that breaker's own* `flipped`, never to the shared 3/3 counter: the player picks the order, so "the third one flipped" needn't be the one standing in the dark). Beat: the beacons **stop and free** the instant the lever throws (the hum you navigated 50 m by dies with the equipment) → `nook_breath` starts, repositioned every frame to 1.1 m behind the player's head (`unit_size 3.0`) so it follows if they walk → after the unchanged `NOOK_SCARE_DELAY = 5 s` a **watch arms** (`_tick_nook_watch`) → it fires as soon as the player is `NOOK_TRIGGER_DIST = 3 m` from the figure's mark, with `NOOK_WATCH_TIMEOUT = 6 s` as the backstop for someone who never moves → t+0.00 the positional `nook_scream` at the mark **leads**, horizontal velocity is zeroed, `freeze_input()`, and `player.turn_to_face()` swings the camera over `NOOK_TURN_TIME = 0.45 s` → t+0.45 the arc-flare + the `lab_nook_figure.png` billboard alpha-tweened 0→1, held `NOOK_REVEAL_TIME = 0.15` → t+0.75 `Screamer.flash_scare(lab_nook_face.png, "dark_jumpscare", 1.6)` + `NOOK_SCARE_PANIC = 20`, and control comes back with the picture. The documented 0.30 s *it moved* → *it's on you* gap is preserved, now measured from the moment the figure becomes VISIBLE rather than from the scream; `flash_scare` never stops its audio, so `dark_jumpscare`'s 3.5 s tail deliberately keeps ringing after the picture drops

⚠️ **Superseded 2026-09-16 (W1) — the designed-marks placement ladder.** `_clamp_into_room()`
and the KNOWN-marks list no longer exist; `_place_nook_figure()` now fans 14 headings off the
camera at the `NOOK_LUNGE_FROM` distances and is ALWAYS finite. The camera turn (`turn_to_face`),
the rays-only validation and the eye→chest line-of-sight check all survive in the new code:

  - ⚠️ **The position trigger and the camera turn are the USER'S OWN DESIGN** (2026-08-16, capture #6: *"sometimes I cannot see the creature which gives the jumpscare… it must appear at the place the player is looking at"*, and their proposal, *"you need to pass 3 metres away from the breaker - the camera turns exactly at the needed position and then this creature… appears"*). It replaced a four-heading fan off the camera whose **fallback was unvalidated**: with no heading clear it placed a 1.5 m billboard 1.5 m directly behind the player's head having checked nothing, and two of its four headings were outside the FOV by construction. Measured across 100 poses in BreakerNook/SouthHall/SouthSpur, only **27 %** of placements were already in frustum — that is the lottery the turn removes. `_place_nook_figure()` now tries a short list of KNOWN marks (the designed spot on BreakerNook's centre line, mid-room, then points back along the route the player walked, each pulled clear of its room's walls by `_clamp_into_room()`), validates with **rays only** (Issue 40) including the eye→chest line of sight — which is the member of the set that catches "inside a wall", because an outward fan cannot: CSG backfaces do not collide (**Issue 59**) — and, if nothing fits, **skips the figure and keeps the sting** rather than burying it. `tests/check_nook_figure.gd`

⚠️ **Superseded 2026-09-16 (W1) — the 2026-09-07 "appears close" pass.** It is written against
the watch + anchor + player-relative ladder, none of which survive; `NOOK_MIN_FRAMING` is no
longer consulted and the `flash_scare` half of the sting is now `_play_at(NOOK_FLASH_AUDIO, …)`
at the player. The measurements and Issue 171 are kept:

  - ⭐⭐ **AND IT APPEARS CLOSE NOW (2026-09-07)** — the user: *"once you escape the dark place the
    creature in the dark corridor appears a bit too far away - let's make it closer and again more
    loud."* Two faults, one of them silent. **(1)** `_place_nook_figure()` tried the ANCHOR first,
    and `_tick_nook_watch()` only fires once the player is `NOOK_TRIGGER_DIST` 3.0 m from that
    anchor — so candidate one was, by construction, never nearer than 3 m. Worse, the watch is not
    armed until a `SceneTreeTimer` **5 s after the flip**, and 5 s at 4.0 m/s is up to 20 m, so
    `far_enough` is true on the very first tick and the figure landed wherever the player had got
    to. **The 3 m threshold essentially never bound.** The ladder now tries player-relative marks
    (2.4 / 2.8 / ±25° at 2.6 / 3.4) first and demotes the world marks to fallbacks. Measured on a
    real walk (`tests/autoplay_lab_nook.gd`): **10.26 m → 2.40 m**, i.e. the 2.3 m billboard goes
    from ~18 % to **~70 % of screen height**. **(2)** `back` was `anchor - player`, which REVERSES
    when you are standing on the anchor — a player who threw the lever and did not move is within
    1.7 m of it and may be either side, and standing east made `back` point WEST into the wall the
    breaker is bolted to. Every candidate then clamped to the same x and failed `NOOK_MIN_FRAMING`:
    **the stand-still branch produced no figure at all**, which is the branch the five seconds of
    breathing are designed to encourage. Inside the nook `back` is now taken from the breaker's own
    position. Issue 171.
  - ⚠️ **"LOUDER" CAME FROM THE DISTANCE, NOT FROM A GAIN, and no gain moved.** `nook_scream` is
    positional AT the figure through `_play_at()` (`unit_size 8.0`, `max_db 6.0`), so its delivered
    level is a function of the ladder above: **−13.67 dBFS at 20 m against +2.29 at 2.6 m, i.e.
    +16 dB from placement alone**. There was nothing left to add — the emitter is already pinned to
    its ceiling inside 4 m and the file peaks at 0.00 dBFS under a −0.5 limiter. A `HoldBreath.dip()`
    was added under the scream for contrast. ⚠️ The `flash_scare` half **cannot** be made louder at
    all: `dark_jumpscare.mp3` is effectively a full-scale square wave (92.5 % of its samples exceed
    ±1.0, crest factor 0.24 dB) played at 0 dB with no gain argument.

⚠️ **Superseded 2026-09-13 (`BACKLOG_Sep_13.md` L1.6) — the breathing is 20 s, not 5 s, and the
3 m trigger is dead code.** `NOOK_SCARE_DELAY := 20.0`; the user's own 3.0 m number survives only
as an unarmed constant:

  - ⚠️ `NOOK_TRIGGER_DIST` (3.0) is the user's own number and did NOT move, nor did the 5 s of
    breathing. Fixing the placement is the smaller, truer change.

⚠️ **Superseded 2026-09-15 — `DEBUG_APPARITION` and `_tick_debug_apparition()` no longer exist.**
The constant was renamed `RANDOM_APPARITIONS` (and is `false` in the Lab, so there is no director
here at all); the wing suppression it describes survives as `_in_wing()` / `_in_breaker_nook` in
`_apparition_is_fair()`. The double-jeopardy reasoning is the part worth keeping:

  - The Lab's `DEBUG_APPARITION` fatal-apparition timer is suppressed for the whole wing (`_in_breaker_nook` flag checked in `_tick_debug_apparition`) — a player who can't see the apparition materialise has no fair way to judge "hold still or flee," the same double-jeopardy mistake KONTUR Gate 7 and the Backrooms Flood already made once each

⚠️ **Superseded 2026-09-15 (the ⭐⭐ 2026-09-15 entry) — there is NO `ApparitionDirector` in the
Lab.** `RANDOM_APPARITIONS := false`, and `_spawn_apparition_director()` returns immediately when
it is false, so the director is never built here and its `suppress` callable (which does still read
`not GameState.has_keycard`) is unreachable code in this level. `count_apparitions.gd` asserts
"exactly one, no director here". The clause this replaces:

  `ApparitionDirector` is suppressed until `GameState.has_keycard` (`on_keycard_taken()` pushes its
  clock so the scripted HOLD goes first; `count_apparitions` asserts zero before the keycard). The

⚠️ **Numbers corrected in place 2026-09-19 (spec audit), with what they used to say.** Each was
true when it was written and was left behind by a later pass; the code is the source for every
new value:

- the wing's room count — **21 → 28** in the `THE WING IS …` headline, and **ten-room → 28-room**
  in the 2026-09-10 markers entry, the Issue-36 lamp note, the 2026-07-25 wing entry and
  `_light_the_wing`'s "ten wing rooms". `WING_ROOMS` has 28 names; the loops and the deeper dead
  ends landed the evening of 2026-09-13, after the 21-room entry was written.
- **7 dead ends → 4** (and, in the 2026-07-25 entry, *three decision points, three dead ends,
  ~50 m* → *six, four, ~62 m*). Derived from `DOORS`: the branch points are Junction, SouthHall,
  Cistern, LowerRun, Crossing and Turn (6), and the only degree-1 rooms besides the terminus are
  PumpPit, SumpWell, VentShaft and BoilerPit (4) — Plant, NorthVault and Gallery stopped being
  dead ends when the two loops were added.
- the terminus is **~28 m → ~48 m** from Records' lamp (Records centre (−9, 12.5) to BreakerNook
  centre (−57, 16.5)), which is why "four times its 11 m range" still holds.
- the flashlight-lock zone's bounds — **x −37..−12 / z 4.2..24 → x −60..−12 / z 0.8..24**.
  `_spawn_breaker_nook_zone()` builds a 48 × h × 23.2 box centred at (−36, h/2, 12.4).
  ⚠️ The *code comment* above that function still describes the old ten-room union; the spec now
  follows the code, not the comment.
- the laugh window — **60–110 s → 30–70 s** (`WING_LAUGH_AT := Vector2(30.0, 70.0)`; the code's own
  note: *"was 60–110: a brisk player reached the breaker first (2026-09-13)"*).
- the wing markers — **green → dark red**. `MARK_COLOUR := Color(0.55, 0.06, 0.05)` is the
  emission; `MARK_ALBEDO` (0.05, 0.08, 0.05) is the unlit body colour, which is probably where
  "green" came from.
- `check_wing_markers` — **21 doorways → 30** (the guard's own `_ok()` at line 113 says
  "21 + 9 for the 2026-09-13 loops/deeper ends") and **12 checks → 13** (`_ok()` is called 13 times).
- `NO_LAMP_ROOMS` — **eleven → twenty-nine** (Morgue + all 28 wing rooms).
- `DARK_AMBIENT` — **0.02 → 0.0** in the 2026-09-03 blackout entry, which the 2026-09-07 beam entry
  above it had already changed. `const DARK_AMBIENT := 0.0`.
- the HOLD apparition — **arms from the KEYCARD, `APPARITION_AT` 8–16 s → arms from the FIRST
  BREAKER, `APPARITION_AT` 3 s**, and **`APPARITION_DEADLINE` 65 s → 30 s**, and *"arms at
  `randf_range(APPARITION_AT)` = 42–50 s"* → *"= 3 s"*. Code: `APPARITION_AT := Vector2(3.0, 3.0)`,
  `APPARITION_DEADLINE := 30.0`, `_arm_apparition("breaker 1")` called from `_on_breaker_flipped`.
  ⚠️ The clock therefore starts **at the first breaker**, not at level load — the sentence in the
  *Scares* bullet that says "it now arms at … = 3 s" is counting from that moment. Keycard arming
  lasted from 2026-09-13 to 2026-09-15; level-start arming before that.

⚠️ **`ROOMS` has 38 entries, and the SPEC line that says "a 10-room graph (`ROOMS`/`DOORS`)" means
the PRE-WING CORE** — the ten rooms it then lists: Reception, MainHall1, Exam1, Exam2, CrossHall,
Records, Morgue, MainHall2, Observation, ExitVestibule. The other 28 are `WING_ROOMS`, appended to
the same array. Said explicitly here because the number is right about the sentence and wrong about
the array, and a future reader will try to "fix" one or the other.

⚠️ **Left standing, because it cannot be excised without rewording — the 2026-09-13 evening entry
still says the PANEL HUM meter is "near-only".** The 2026-09-14 entry directly above it reverts
that ("live everywhere in the wing again, the user's call"), and the code agrees:
`lab_wing_meter.gd:set_active()` carries *"2026-09-14: live everywhere again (the user's call;
near-only lasted one playtest)"*, and `near_enough()` / `NEAR_HOPS` survive only as a public API
nothing calls. **The 2026-09-14 entry wins.**

⚠️ **Two older sub-bullets in the wing section still describe the pre-W1 figure and were left in
SPEC rather than guessed at.** "The figure is **unshaded**, so the flare cannot light it" describes
an arc-flare `_nook_reveal()` no longer builds (the figure is a glowing `DoorLunger` with its own
`add_light`), and the same bullet's *"`_place_nook_figure()` fans raycasts — ahead, ±90°, then
behind — and takes the first direction with ≥1.8 m clearance"* is the old fan; the current one tries
14 headings at the `NOOK_LUNGE_FROM` distances against `NOOK_FIG_CLEAR` 0.85. The shadow-casting
correction in that bullet is still true and is why it was not moved wholesale.

⚠️ **Left standing, and reported rather than guessed at — `NOOK_FIGURE_HOLD` 0.6 s.** The
2026-09-13 entry says the figure "holds `NOOK_FIGURE_HOLD` 0.6 s instead" of the deleted fullscreen
flash. The constant is still declared at `level_1.gd:1851` but **nothing reads it any more**: the
W1 beat holds for `NOOK_LUNGE_HOLD` 0.4 s and cleans up on a
`NOOK_TURN_TIME + NOOK_LUNGE_TIME + NOOK_LUNGE_HOLD + NOOK_FLASH_HOLD` timer. The 2026-09-16 entry
at the top of SPEC ("holds 0.4 s") is the current one. Same for `NOOK_REVEAL_TIME`, `NOOK_FLASH_AT`
and `NOOK_MIN_FRAMING`, which are now declared-and-unread.

## NEEDS A PLAYTEST

Claims in this spec that reading the code cannot settle. None of them is known to be wrong; none is
currently evidenced against the level as it now stands.

- **The W1 nook payoff has never been hand-played.** Breathing for `NOOK_SCARE_DELAY` 20 s → cut →
  `NOOK_SILENCE_GAP` 1 s of nothing → glowing lunge to 0.65 m. Whether 20 s of breathing reads as
  dread or as a wait, and whether the cut-to-silence lands, is a play question.
- **"~62 m of path" and "~50 m of walking back"** — path length through the 28-room wing. Summing
  the doorway-to-doorway legs of the main route gives ≈58 m in a straight line through the
  doorways; real walking rounds corners, so ~62 m is plausible but unmeasured.
- **The PANEL HUM meter's readings** (*Plant 0.04; the real route 0.15 → 0.31 → 0.37 → 0.46 → 0.65
  → 0.80 → 0.96*) were measured on the **21-room** layout, before the two loops. The Dijkstra
  normalisation is against the furthest room's path distance, and the furthest room changed.
- **Every luminance and dB figure**: the torch-reach contrasts (0.233 / 0.311 / 0.273; 0.089 →
  0.034; 0.0000–0.0004 with the torch off), the wing screamer's 0.0006 → 0.109 centre luminance,
  the panel's 4.1 → 1.0 contrast against its wall, and the scream's −13.67 dBFS at 20 m vs
  +2.29 dBFS at 2.6 m. All are re-measurable, none is re-measured here.
- **"~18 % → ~70 % of screen height"** for the figure — measured against the 2026-09-07 ladder that
  no longer exists.
- **The markers read as doorways, not as a map** (`MARK_EMISSION` 0.14, dark red, full inside 6 m,
  gone past 12 m) — the user's *"easier but not too easy"* is a feel judgement, and the marker set
  grew from 21 doorways to 30 since it was made.
- **The wing is navigable at 28 rooms.** `walk_lab_wing.gd` proves the geometry and the dead ends;
  it does not prove that a player without the map finds BreakerNook in a tolerable time.
