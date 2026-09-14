# BACKLOG — 2026-09-13 playtest (main menu → the Breach's door)

**Evidence:** `playtest_log.txt` 2026-09-13T13:37, 23 J-captures (`debug_captures/001–023.png`),
1 death (KONTUR escort at 98 % panic), 0 script errors, 30:44 of play. The run stopped at the
Breach's spawn; **the Breach, THE NIGHTMARE and the Void were not played** and need their own
session once this backlog ships.

Every decision below is the user's, taken in the post-play discussion (their words in quotes).
"MEASURED" is what the log or a probe says; "INFERRED" is a reading of it. Difficulty constants
and design verdicts are the user's calls and are recorded as such.

Legend for cost: **S** ≤ 1 h · **M** half a day · **L** a day or more.

---

## 0. Cross-level

### X1 · Notes keep the level's sound (captures #8, #9)
- **Evidence:** *"When you open notes — the sounds completely disappear … while you are reading
  nothing can make you panic, as it is now, but you will hear the level sounds. And make it
  applicable to notes on every level."*
- **Diagnosis (MEASURED):** `note_ui.gd:show_note()` sets `get_tree().paused = true`; every
  `AudioStreamPlayer`/`3D` in the level is `PROCESS_MODE_INHERIT`, so the pause mutes them. The
  pause is what stops panic and entities — keep it.
- **Item:** `note_ui.gd` — on `show_note()` walk the current scene, collect every
  `AudioStreamPlayer` / `AudioStreamPlayer3D` that is `playing`, set `process_mode =
  PROCESS_MODE_ALWAYS` (remember the originals), restore in `_close()` and in the Issue-9
  self-drop path. `JournalUI` (TAB) gets the same treatment via a shared helper
  (`AudioBuses.keep_playing_through_pause(scene) -> Array` / `release(list)`), so the two pausing
  overlays cannot drift.
- **Verification:** new `check_note_audio.gd`: open a note in the House, assert the
  `AmbientPlayer` and a positional emitter are still `playing` with the tree paused and the
  player's panic unchanged over 2 s; close, assert `process_mode` restored. **S**

### X2 · Fatal-flash retirement pattern
Two beats this session asked for the fullscreen face to go (Backrooms crate #17, KONTUR strike
#20). The Corridor false door already did this on 2026-09-10 (`door_lunger.gd`, in-world lunge,
no `flash_scare`). Reuse that idiom: sting on Master after a `HoldBreath.dip`, the figure in the
world, the camera turned to it. Do not add a third fullscreen-flash variant.

### X3 · Known pre-existing red
`walk_kontur.gd`: `VinegarSign` at (−3.4, 1.4, 23.5) is buried in its wall (`kontur.gd`
unchanged since the 2026-09-10 commit). Fold into K-items below. **S**

---

## 1. The Lab (captures #1, #2)

### L1 · The dark wing, doubled, with three beats and a presence — the user's design
- **Evidence:** #1 at (−18.7, 12.4): *"I do not like that they are green. Let's make them dark
  red — more creepy. We should also make this dark location bigger."* Discussion: *"twice as
  big"*; a screamer *"in the middle of nowhere … when you actually are trying to find the light
  switcher"* using `screamer_forest.ogg` + `monster_in_the_dark.png` (supplied, 1536×1024 RGBA);
  *"at some moment when you are still trying to find the light switcher, a creepy laugh would
  appear"* (`creepy_laugh.ogg`, supplied); *"the lights would not turn on until you spend 20
  seconds in the dark room after turning on the light switcher … the jumpscare will appear very
  close to you, and then all the light gets restored"*; and the recommended presence that hunts
  by sound.
- **MEASURED:** the wing today is 10 rooms, ~50 m of walking, `WING_ROOMS` (`level_1.gd:2156`),
  markers `MARK_COLOUR` phosphor green at `MARK_EMISSION` 0.14 (`:2367`); the nook beat fires
  `NOOK_SCARE_DELAY` 5 s after the flip (`:1699`) at `NOOK_TRIGGER_DIST` 3 m, and
  `_light_the_wing()` (`:2167`) lights it in the same beat.
- **Items:**
  1. **Markers dark red.** `MARK_COLOUR` → `Color(0.55, 0.06, 0.05)`; keep `MARK_EMISSION`
     0.14 (the fade-with-distance stays). `check_wing_markers.gd` reads the colour: update its
     expectation to "red channel dominant". **S**
  2. **Twice the wing.** Extend `ROOMS`/`DOORS` (`:214–226`, `:458–461`, `WING_ROOMS`) from 10
     rooms / 3 decisions / 3 dead ends to ~20 rooms / 6 decisions / 6 dead ends, keeping the three
     z-bands rule (north ≥ 14.5, middle, south ≤ 10.5) and `BreakerNook` as the terminus at
     ≥ 45 m of path. Re-derive `_spawn_breaker_nook_zone()` bounds (`:2235`), the meter's graph
     (`_wing_meter.setup`, `:1662`), `NO_LAMP_ROOMS`, the markers (`_spawn_wing_markers`,
     `:2402`). `walk_lab_wing.gd` gets the new dead ends; `check_wing_meter.gd` re-measures
     Plant-style lies on the new graph. **L**
  3. **The presence** (`lab_wing_hunter.gd`, new, non-lethal): a `Watcher`-class figure that
     moves toward the player's last FOOTSTEP at 1.6 m/s while they walk, stops when they stop,
     never within 2.5 m; `bone_scrape`-style drag loop positional on it; contact = +12 panic +
     a jolt, then it drops back 6 m (the dungeon Still One's catch shape). Wakes on the first
     decision, sleeps when the wing lights. It listens through `player.is_moving()` only —
     no rule to learn beyond *stop and it stops*. **M**
  4. **The laugh.** One-shot `creepy_laugh` at a random wing room the player has NOT visited,
     60–110 s into the wing, positional, `unit_size` 12, nothing else happens. Assets:
     `creepy_laugh.ogg` → `game/assets/audio/level_1_lab/wing_laugh.ogg` (16 kHz stereo; measure
     RMS, set gain from it). **S**
  5. **The mid-search screamer.** Once, unannounced, between decision 2 and the nook, when the
     player is ≥ 8 m from the breaker: `monster_in_the_dark.png` as an in-world billboard
     (`Watcher`/`DoorLunger` idiom, sized from the cutout, placed by the nook figure's ladder
     `_place_nook_figure`-style with LOS) lunging to 0.7 m + `screamer_forest` on Master after
     a `HoldBreath.dip(0.5)`, +15 panic, no death, the figure gone in 0.6 s. Asset →
     `game/assets/textures/level_1_lab/wing_monster.png`. **M**
  6. **The breaker beat at 20 s.** `NOOK_SCARE_DELAY` 5 → 20 (the user's number; it becomes the
     new documented constant), the breathing runs the whole 20 s, the beacons die at the flip as
     now, `_light_the_wing()` fires only AFTER the figure beat completes (today it is in the
     same cleanup — keep the order, move the timing). The figure stays the existing
     `lab_nook_figure.png` at 2.4 m. **S**
- **Verification:** `walk_lab_wing.gd` (route + dead ends on the new graph), `check_wing_meter`,
  `check_wing_markers` (colour), new `check_wing_beats.gd` (laugh fires once, screamer fires
  once ≥ 8 m from the breaker with LOS and costs 15, the presence stops when the player stops
  and never enters 2.5 m, the wing lights ≥ 20 s after the flip), `screenshot_nook_scare.gd`
  re-run for the red markers and the monster billboard.

### L2 · The roaming apparition waits for the keycard (capture #2)
- **Evidence:** #2 at (−23.6, 7.8), in the wing: *"This creature should not appear while we are
  in the dark room … maybe for this level we can make it appear only after you take a card."*
  Decision: **only after the keycard.**
- **MEASURED:** `level_1.gd:1449` arms it at 42–50 s, `_apparition_is_fair()` (`:1463`) excludes
  the nook by `_in_breaker_nook` only for the NOOK room, and `APPARITION_DEADLINE` 65 s drops
  even that. It fired at t=162 s inside the wing (PANIC 38 %).
- **Item:** arm the Lab's HOLD apparition from `on_keycard_taken()` (`:2321`) instead of the
  clock: `_apparition_due = randf_range(8, 16)` after the pickup, deadline 30 s after that,
  `_apparition_is_fair()` also refuses while the player is in ANY `WING_ROOMS` room.
  `check_lab_apparition_timing.gd` rewritten: not before the keycard, within 30 s after. **S**

---

## 2. The House (captures #3–#10)

### H1 · Map game re-skin: hammer → glass case (capture #5)
- **Evidence:** *"The yellow object inside the map game does not really look like a key …
  more like a glass door behind which is the key and to break the glass we need to collect the
  hammer."* Decision: **re-skin the two existing stages**, no third waypoint (measured on this
  board every extra waypoint roughly halves the win rate: 82 → 57 → 21 %).
- **Items:** `maze_chase_ui.gd` `_make_icon` (`:1496`) call sites `:1419–1448`: the fragment
  icon becomes `house_map_hammer_icon.png`, the mark becomes `house_map_case_icon.png` (a glass
  case with a clearly drawn KEY inside, drawn by `tools/make_map_icons.py`, Pillow, no diffusion
  — icons are glyphs); `TargetSeal` bars replaced by the glass pane; on win a `glass_shatter`
  sting and a cracked-case icon for 0.4 s before the eject; caption text `The key is under
  glass. Find the hammer, then break it.` **S/M**
- **Verification:** `screenshot_maze_ui.gd` (icons legible at `ICON_DISPLAY_SIZE`),
  `check_maze_chase.gd` unchanged (28/40 floor 0.55 — no mechanic moved). Catch "yell" stays
  (user: *"keep it"*).

### H2 · The third digit is in the fridge, behind a chain (capture #7)
- **Evidence:** *"one number is hard to get — while the others are just there … let one stay
  free, another stay the way it is, and … the third one let's make it harder."* Decision: the
  Bedroom digit moves **onto the fridge head**; the fridge wears a **chain**; the **bolt cutters
  lie under the Bedroom bed**, seen only with the torch aimed low.
- **MEASURED:** `SafeNote_Bedroom` at `level_2.gd:605`; the fridge (`house_fridge.gd`) is
  optional today, +10 panic, head at `HEAD_HEIGHT` 0.46 on the lower shelf.
- **Items:**
  1. `house_fridge.gd`: `@export var chained := true`; a chain + padlock across the door
     (parts: 8 torus links along a diagonal, a padlock box); `can_interact()` true always, but
     `interact()` while chained plays `chain_rattle` and toasts nothing (the chain is the message,
     per the Lab drawer rule); `unchain()` drops the chain (falls, `chain_drop` sting).
  2. The digit: scrawled on the head's forehead (`house_head.png` gets the digit baked by
     `tools/make_head_digit.py` from the same source, or a small `Label3D` decal on the head
     mesh — prefer the baked texture); reading it is the Bedroom note's `read` equivalent:
     `_mark_safe_note("SafeNote_Head")` fires when the player gazes at the head ≥ 1.0 s within
     2 m after the reveal (gaze ray + timer), archived to the journal as text.
  3. `bolt_cutters.gd` (`KeyItem` pattern, `GameState.set_carried("BOLT CUTTERS")`): under the
     Bedroom bed at floor level, `_build_bed` (`:1103`) gets a clearance so the torch reaches
     under; visible only when the beam is within ~30° of the floor from the bed's foot
     (a `visible` gate on camera pitch + distance, no emission).
  4. `level_2.gd`: `SafeNote_Bedroom` removed; objective line unchanged (`OBJ_CODE` names 3
     notes — still true); `save_progress()` carries `fridge_chained`, `cutters_held`,
     `head_digit_read`.
- **Verification:** `check_house_fridge_chain.gd`: E on the chained fridge opens nothing;
  cutters found by the shipping ray from the bed's foot with pitch −35°, NOT from standing
  height; after `unchain()` the fridge opens and the head's digit registers; snapshot round
  trip; `autoplay_house_route.gd` still passes (the chain is not on a walkway). **M**

### H3 · The doll's noise louder (capture #6)
- **Evidence:** cellar, (3.8, −1.5, −3.8): *"Can we make the doll noise appearing in the room
  more loud?"* — the cellar child's `childe_scream` at +18 dB / `max_db` 24.
- **Item:** measure the file's loudest-300 ms; if under −3 dBFS re-master with
  `tools/sfx_loudness.py` (denser, not just gain); add a `HoldBreath.dip(0.4)` 0.3 s before the
  scream (contrast is the cheaper half of loud). `check_house_guest.gd` asserts the dip. **S**

### H4 · The lock falls and the door asks (capture #10)
- **Evidence:** *"When you unlock the lock it should fall and disappear and maybe a creepy red
  note saying are you sure you want to go there?"*
- **Item:** `level_2.gd` on `CombinationLock.unlocked` (`combination_lock.gd:212`): tween the
  lock body 0.9 m down with a bounce and a `lock_drop` clunk, `queue_free` at 1.2 s; then
  `ScreenText.scrawl("ARE YOU SURE YOU WANT TO GO IN THERE?", 3.0)` in blood, 0.6 s after the
  clunk. Zero panic. **S**
- **Verification:** `check_house_lock.gd` (new or extended `check_lock_input`): after the
  correct code the lock node is gone within 1.5 s and the scrawl label exists.

---

## 3. The Corridor (captures #11, #12)

### C1 · Bigger, branching, beats spread out, a 3D Manager, a whispering room
- **Evidence:** #11 at d≈108: *"I opened the 217 door and the jumpscare showed up. Then just
  after that the manager appeared."* #12 at d≈137: *"all the three things making me scared …
  appear in one place. Let's make the corridor level more big and extensive, where you can at
  some point turn the wrong side and get stuck somewhere … all the jumpscares will be in
  different parts of the level … maybe a manager 3d appearing on one of your turns (not next to
  the mirror) … one of the rooms might whisper something like I want to get out but I can't."*
  Decision on the wrong turn: **a dead end that shuts behind you for ten seconds.**
- **MEASURED (log):** panic 28 % at d 100 (false door), 74 % at d 107.7 (Manager flash,
  `MANAGER_DIST` 80–180 with the telegraph inside it), 38 % at d 133.7 (silhouette/paint).
  Three one-shots in 37 m.
- **Items:**
  1. **Length and branches.** `PATH_2D` (`corridor.gd:15`) grows from 7 segments / 320 m to
     ~10 segments / ~460 m, and `_build_geometry()` (`:812`) gains **three side passages**
     (`SIDE_PASSAGES := [{at, side, length}]`), each a 3 m-wide blind spur 12–18 m long off a
     corner, built with the same segment builder, the walls carrying the zone's skin.
  2. **The shut-in** (`dead_end_trap.gd`, new): an `Area3D` at the spur's end; on entry a
     `SlamDoor`-class leaf (reuse `slam_door.gd` with `door_width` 3.0) closes the spur mouth,
     the spur's torches die, `door_slam` + a `scratch_loop` at the mouth for 10 s, then the leaf
     opens with `door_break`. Zero panic term; the dark and the sound do the work. One spur holds
     the **whispering room**: a `Label3D`-free positional loop `corridor_plea` (*"I want to get
     out but I can't"*, generated with `tools/make_kontur_voice.py`'s recipe) behind the far
     wall, audible from the main corridor as you pass.
  3. **Spacing.** False door at the FIRST corner after the beartraps (unchanged rule), the
     Manager's telegraph window moved to a corner ≥ 60 m after it, the running creature ≥ 60 m
     after that, the two mirrors at the first and last corners as today. Asserted as pairwise
     distances in `check_corridor_events.gd`.
  4. **The 3D Manager.** Generate a full-length Manager figure with the image pack
     (flux, *"hotel manager in a dark red uniform, screaming, full body, black background"*),
     key the cutout with `tools/cutout_green.py`, and stage it as a `DoorLunger` at a turn that
     is not a mirror corner: it stands in the corridor ahead as you round the corner, lunges to
     0.6 m with `screamer_manager`, flees down the side passage (the shut-in spur), no
     fullscreen `flash_scare` (X2). `MANAGER_PANIC` 25 unchanged.
- **Verification:** `walk_corridor` (new: spawn → 217 with every spur entered and exited within
  12 s), `check_corridor_events.gd` (the three beats ≥ 50 m apart; the shut-in re-opens; the
  Manager figure in frustum on the turn), `check_wall_overlap`/`shell_sealed`/`reachable`
  sweeps at the new length, `screenshot_corridor_*` for the Manager figure. **L**

---

## 4. The Backrooms (captures #13–#18)

### B1 · Old-house yellow doors, more of them, none working (capture #13)
- **Item:** `mirage_door.gd` art → a generated yellowed panel door (`backrooms_door_yellow.png`,
  cropped to the leaf, sized from aspect) instead of the blood-red slab; `_spawn_mirage_doors()`
  (`backrooms.gd:1052`) places 6 in the Lobby and `backrooms_zone2.gd:705` 4 in the Sprawl.
  Every one still swings onto wallpaper for +10 (unchanged). ⚠️ The Lobby's real BACK door keeps
  the red so the convention holds. **S/M**

### B2 · The seam scrawl once, and reworded (captures #14, #15)
- **Evidence:** *"This text no door walk into it appears all the time … one time … is
  sufficient. Let's write something like it's simple to get here — and impossible to escape."*
  #15 at the utility room: *"you are here for a reason."*
- **Item:** `_spawn_seam_scrawls()` (`:1217`): the cap scrawl reads `EASY TO GET IN.` /
  `IMPOSSIBLE TO GET OUT.` and is shown on the FIRST cap only (a one-shot flag; later caps carry
  no text); the utility-room glitch wall reads `YOU ARE HERE FOR A REASON.` The seam SOUND tell
  stays on every cap (it is the completability guarantee). `check_backrooms_seam.gd` asserts one
  cap scrawl and the two texts. **S**

### B3 · The crate is a gift box; the scare is the figure + your sound (captures #16, #17)
- **Decision:** *"Let's make it look like a big gift box."* No fullscreen image: *"the
  animation of this 3d figure with this sound is sufficient."* The user will supply the sound —
  **reminder: ask for the file**; until then the slot uses `crate_shriek`.
- **Items:** `sprawl_crate.gd` rebuilt as a 1.2 m gift box from parts (box, lid, ribbon bands,
  a bow of four loops, wrapping albedo generated by flux, graded dark); `backrooms.gd:_on_crate…`
  drops `Screamer.flash_scare`, keeps the lid blow-off, and the `SprawlDweller` LUNGES to 0.6 m
  (the `door_lunger.gd` idiom) before its run, with the new sound on Master after a
  `HoldBreath.dip(0.5)`. `check_sprawl_crate.gd`: no `_black_panel` ever visible, nearest ≤ 1 m
  then the run as today. **M**

### B4 · "Should I follow it?" in the middle of the screen (capture #18)
- **Item:** `backrooms.gd:1430` — the objective stays but the beat also fires
  `ScreenText.scrawl("SHOULD I FOLLOW IT?", 3.0)` in red the moment the dweller goes through
  the wall. **S**

---

## 5. KONTUR (captures #19–#23)

### K1 · The containment cell reads as a cell from the front (capture #19)
- **Evidence:** *"This cell does not look finished. Should it look like a prison cell from the
  front view?"*
- **Item:** `containment_cell.gd:_build_shell()` (`:172`): the front (−z) face becomes a barred
  gate — 7 vertical bars Ø 0.03 m at 0.22 m pitch plus two cross-rails — over the port, and
  the three glazed faces get a bar grid behind the glass; the placard and wheel stay. Keep the
  liners (Issue 147/148 measurements). `check_kontur_entities.gd`'s visibility half re-run:
  bars must not drop any of the 23 headings below 3 clear body points. **M**

### K2 · A wrong action is fatal after ~20 s of rising dread (capture #20)
- **Evidence:** *"I do not like this 2d image with the weird sound. Let's drop it completely …
  write in red like You've done something wrong and you will pay for it. Your panic starts
  increasing and the tension in the room is becoming more and more intense until you die. It
  will last for around 20 seconds."* Decision confirmed: **fatal, no three-strike ledger.**
- **Items:** `kontur.gd:_strike()` (`:665`) → `_condemn(message)`: the red scrawl
  `YOU'VE DONE SOMETHING WRONG. YOU WILL PAY FOR IT.`, `set_no_decay(true)`, a driver that adds
  panic on an ease-in curve reaching `PANIC_MAX` at `CONDEMN_TIME` 20 s (so the bar's own
  screamer kills, no bespoke death path), the lamps pulse red and dim, `kontur_condemn_loop`
  (a rising drone from `tools/make_sfx_kontur_extra.py`'s recipe) pitch-rides 0.8 → 1.4.
  `FLASH_PATH`/`FLASH_AUDIO` and `STRIKE_PANIC` retire; `_strikes`, the Archive's
  "N OF 3 LOGGED" card (`_sync_archive_strikes`, `:2845`) and `save_progress()`'s `strikes` go
  (the card reads `LOT 23-Z · SUBJECT 47 — PENDING` always). `_forfeit()` (`:726`) becomes a
  condemn too. **M**
- **Verification:** `check_kontur_entities`/`check_kontur_phones`/`check_kontur_resume` updated
  from strikes to condemn: a wrong bottle → dead in 19–21 s with no `flash_scare`; a right
  action never condemns; the objective line reads the sentence.

### K3 · The dark figure stands closer (capture #21)
- **Item:** `_make_dark_figure(pos)` (`:1629`) — place it 2.6 m ahead on the approach line
  into the Blackout room rather than mid-room; keep the x offset from the real seam. Assert
  ≤ 3 m from the doorway in `check_kontur_blackout.gd`. **S**

### K4 · The phones say which key (capture #22)
- **Item:** `rotary_phone.gd` gets `prompt_text()` → `E — answer   ·   SPACE — smash` when
  smashable; `player.gd:_update_interact_prompt()` uses a prop's `prompt_text()` when present
  (additive; every other prop keeps `Press E`). `check_kontur_phones.gd` asserts the prompt. **S**

### K5 · The real blackout seam leaked under the torch (capture #23) — BUG
- **Evidence:** the user saw the REAL door with the torch on. Screenshot 023 shows two lit
  panels with the beam on.
- **Diagnosis (to MEASURE first):** `_update_dark_seams()` (`:3272`) drives the real seam's
  emission from `is_flashlight_on()`; if the seam is lit by the torch's own light (albedo not
  black) it shows under the beam regardless of emission. Probe: render the Blackout room torch
  ON and OFF from the capture's pose and read the real seam's luminance against its wall.
- **Item:** the real seam's material `albedo` → black, `emission_operator` MULTIPLY, and it must
  be `visible = false` (not merely emission 0) while the torch is on. `check_kontur_blackout.gd`
  asserts the real marker is invisible with the torch on and the decoys are not. **S**

### K6 · `VinegarSign` buried (X3) **S**

---

## 6. Not played this session
The Breach, THE NIGHTMARE (redesigned 2026-09-12) and the Void (rebuilt 2026-09-12) were not
reached. They keep their headless proofs (bot 4/4, `walk_void`, `check_void`) and need the next
hand session before anything about them goes on a backlog.

---

## Build order
1. **X1** notes keep sound (small, every level, the user asked twice).
2. **K5** the leaking seam (a bug), **K3**, **K4**, **K6**, **B2**, **B4**, **H4**, **H3**, **L1.1**,
   **L2** — the small directives, one guard each.
3. **H1** map re-skin, **H2** fridge chain + cutters, **B3** gift box + lunge (sound slot),
   **B1** yellow doors, **K1** the cell's bars, **K2** condemn.
4. **L1.2–1.6** the wing (biggest single build), then **C1** the Corridor.
5. Full suite alone (`tools/run_tests.sh -q`; three Godot instances OOM this machine), the
   screenshot harnesses for every visual item, docs (`CLAUDE.md` level sections,
   `ISSUES_SOLUTIONS.md`, `backlogs/0N-*.md`), tree left uncommitted for the user.

Open items for the user: the crate sound file (B3); whether the Manager figure generation is
acceptable when seen (C1.4); the wing's second half of names and dead ends (L1.2) will be
proposed as a diagram before geometry is built.

---

## Status — end of the 2026-09-13 implementation session

Built and verified (guard + render where visual): **X1, K3, K4, K5, K6, B1, B2, B3, B4, H1, H2,
H3, H4, L1.1–1.6, L2, K1, K2, C1.** Every item's named guard is green; new guards:
`check_note_audio`, `check_house_lock`, `check_house_fridge_chain`, `check_kontur_condemn`,
`check_wing_beats`, `walk_corridor`. Bugs found on the way: ISSUES_SOLUTIONS 197–201.

Decisions taken without the user (flag for review):
- K2 makes Gate 8's MISTIMED catch fatal (it calls `_strike()`); a softer per-gate rule is one line.
- K1 has NO bar grid behind the glass — each attempt blinded a sightline heading in
  `check_kontur_entities.gd`; the front gate is the cell.
- L1.2's layout (Cistern → LowerRun → Crossing → FarHall → Turn → Shaft → BreakerNook, with
  Sump/Vent/Gallery/Boiler dead) was built from the diagram in `level_1.gd:ROOMS` rather than
  waiting for a sign-off; every wing test was re-pointed at the new terminus.
- B3 uses the user's `jumpscare.m4a` (converted to `crate_jumpscare.ogg`).
- C1's Manager figure was generated with the image pack (`manager_figure.png`, raw in
  `assets_src/textures/level_3_corridor/`); the plea line is macOS `say` through the phone chain.

Not yet hand-played: everything above, plus the Breach, THE NIGHTMARE and the Void.
