# Intro Room — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

### ⭐ THE INTAKE WING (2026-09-24) — the intro is six rooms now, and this block is the current state

A 5–8 minute, six-space intake wing in the derelict-asylum look of the cold-open video
(`intro_scene.ogv`: peeling grey-green plaster over a dark wainscot, caged bare bulbs, wet stained
floors), built at runtime by `intro_room.gd` on **`RoomBuilder`** (`ROOMS` / `DOORS` / `WINDOWS` / `HATCHES`
— `ROOMS` also carries `PatientCell`, the unenterable dark behind the airlock's barred hatch).
The experiment's own kit — tannoys, camera, red monitor lamp, one-way glass, trolley, projector — is
newer than the building, and that contrast is the "someone is running this" tell. The old ward is
room 4, at its original coordinates, and keeps every beat described below this block. Designed with
the user in a grill-me session; every row below is their call.

| # | Space | What happens | Leaves when |
|---|---|---|---|
| 1 | **Cell** 4×4 (`CELL_GURNEY_POS`) | you wake **LYING** on the bed, the eye at the pillow (`WAKE_CAM_LYING`), finding the caged bulb; "IT WAS ONLY A DREAM."; you **sit up and stand** beside the bed in one frozen move (3.3 s, no input — see ⭐ No buckling below); the three restraints are **already unbuckled**, hanging down the bed's sides, a detail and not interactable; **VO1** *"Good morning, forty-six. I mean — forty-seven."* from a wall tannoy as you stand; sink + tap (E: rust-brown for 3.2 s, then clear); mirror frame with the glass smashed out (no reflection); 46 tally marks above the dado; wristband note on a bedside cabinet; camera + blinking red lamp | none — VO1 ends → `intro_cell_buzz` → the metal door swings OUT into the corridor (5.2 s after you stand) |
| 2 | **Corridor** 2.4×16 | the dream's corridor, awake — caged bulbs, five locked flush doors (`WingDoor` `flush`), wet floor, hum. **Nothing happens.** | — |
| 3 | **Observation hall** 6×6 | the observers' side: desk with the **reel-to-reel** (E → "SESSION 46", sound only, reels spin), **your file** with Subject 46's TERMINATED page stapled in, steaming cup, ashtray with a faint wisp, mic, desk lamp; two chairs (one shoved back); a `LabCabinet` whose drawer holds the 44/45/46 wristbands page; the observation log on the wall; the **torch trolley** "SUBJECT 47 — ISSUED" (a `KeyItem`, toast *"Torch issued — F"*, `unlock_flashlight()`). Through the **one-way glass** — two back-to-back single-sided quads + a solid pane collider — **someone is strapped to the bed you just left** (`CellOccupant`, spawned 0.6 m inside the hall on your first entry, `queue_free()`d on your first step back into the corridor, never again; zero panic, no sound) | torch taken → the ward entry unlocks |
| 4 | **Ward** 12×18 (the old room) | the entry door's `opened` fires **before the leaf moves**: **VO2** *"—we have a fault in—"*, every bulb in the wing and the ambient to 0, torch locked, `FarBreath` + path glow from the entry → the old beats: the 2-press switch, glimpse, empty bed, candle + note, wheelchair. Dressed: a fitting on each tube (emission follows its light, ≤ 0.5), a real table, gurneys from parts, a stripped bedstead, stacked chairs, a privacy screen, a floor drain, a wall clock stopped at **4:12**, and three filing cabinets (consent form with 47 written over 46, a pill envelope, a night-staff journal page — all journal-archived). The switch restores the wing's bulbs and tweens the ambient to 0.30 **and** `LIT_AMBIENT_COLOR` | lit **and** note read (today's two locked messages) |
| 5 | **Calibration** 8×12 | **VO3** *"Look at the screen, forty-seven."* → the projector (title card, then SEVEN stimuli — black Rorschach, "WARD 4" archival photo, restraint chair, skull plate, eyeless doll, the "No. 46" portrait with eyes barred, red Rorschach — 2.5 s each, advancing only while you face the screen, LOOK AT THE SCREEN. if you turn away) is a `ScaryObject` gaze source stepping 0.02 → 0.14; the subject's empty strapped **chair stands on the spot** (an electrode cart beside it): caption **SIT DOWN.** → **E on the chair** seats you — body pinned by `player.begin_qte()` (movement only; look stays free), the eye 1.2 m up and **2.39 m** from the screen, well inside `GAZE_RANGE` 3.0 — and the slides run (and move the bar) **only while you sit** → once the LAST stimulus has been shown (a count, not a panic threshold — the tray can pre-load panic), caption **LOOK AWAY.** → 1.5 s with the camera > 60° off the screen → **GOOD.** — and you STAY in the chair: ⭐ **SERIES D** (see below) — five photographs of one new thing coming closer, **STAY SEATED. THEY CANNOT REACH YOU.**, `E — stand up` shown, ~10 s → **GOOD.**, projector off, and you are stood up beside the chair → **VO4** *"Much better than last time."* (no walk to a line — cut on the second hand playtest). The **DO NOT TOUCH** tray (syringe, vial, scalpel on a cloth, its own clamp lamp) is live throughout: E → `add_panic(PANIC_MAX)`, pinned at 0.6, **WE SAID NOT TO TOUCH IT. NOTED.** at once on its own line, once. A player who won't watch is let through with **NOTED.** after `CALIB_TIMEOUT` 60 s **seated**, or `UNSEATED_TIMEOUT` 90 s never sitting (round one's NOTED. skips SERIES D); a player who stands up mid-SERIES D and won't sit again, after `SERIES_D_UNSEATED_TIMEOUT` 45 s | after VO4 → the airlock door buzzes |
| 6 | **Airlock** 3×3 | ⭐ opening the airlock door: **the patient at the hatch** (see below) — a barred hatch dead ahead in the west wall, a patient slams into the bars SCREAMING (the same frame), then shouts *"They'll kill us. They'll kill ALL of us!"*, is dragged back into the dark, the light dies, a steel shutter bangs down; **then** buzzer, **VO5** *"You may proceed."*, and `ExitDoor` (seated at `AIRLOCK_EXIT_POS`, with casing) unlocks **as the line starts** → the Lab | — |

**The rules of the wing:**
- ⭐ **UNLOSEABLE BY CONSTRUCTION — the panic CEILING.** `player.set_panic_ceiling(PANIC_CEILING)`
  (0.6) clamps panic to 60 % of `PANIC_MAX` in `_update_panic`, `add_panic` and `set_panic_ratio`,
  so `Screamer.trigger()` cannot be reached from panic, sprint included. The bar is **exactly 0**
  through cell, corridor, hall and ward; only calibration moves it. **NO FULLSCREEN screamer**, still
  (the patient at the hatch is IN-WORLD, zero panic, and never touches `Screamer` — see below).
  `check_intro_panic_ceiling.gd` (20 s of real sprint peaks at exactly 0.600; `add_panic(MAX)` → 0.6;
  control at the default ceiling), `check_intro_beats.gd` (0 before calibration, ≤ 0.6 overall).
- **The voice is rationed — five lines, no more** (the user: *"be careful with TTS … mix between
  notes, text on the screen and TTS"*). macOS `say` "Daniel" through `tools/make_pa_voice.py intro`
  — the same person as the Lab's `pa_trial4`. Every other observer line is a queued `_caption()`
  (a line waits for the previous one to fade); everything else is paper, journal-archived. ⚠️ The
  patient at the hatch is NOT the observer and is outside the budget: his words are their own file
  (`intro_patient_words`) and their own on-screen line (`_patient_line()`), never the queue.
- **The torch is ISSUED in the hall and taken by the ward's blackout**; the switch gives both back.
- **The soundtrack plays ONCE.** `ambient_asylum` (**trimmed to 1:25**, with a 4 s fade, on the user's call, 2026-09-25 — the original 162 s file is kept in `assets_src/audio/intro/ambient_asylum_full.ogg`) is not
  self-looped; its `finished` hands `AmbientPlayer` to the user's `intro_second_music` (83 s), which
  loops, at `SECOND_MUSIC_OFFSET_DB` −13 dB (measured means −11.1 vs −24.3 dB). No second file →
  silence; the dream never replays. `check_intro_soundtrack.gd`.
- **Coming back from the Lab** (`save_progress()` / `_restore_progress()`) builds the wing SOLVED —
  five doors open, power on, the torch yours, straps hanging, nobody on the bed, the ward lit with
  its glimpse bed already empty, no voice, SERIES D not replayed, the airlock hatch's shutter DOWN
  and the patient never again — and puts you in the airlock facing calibration.
  `check_intro_resume.gd`.
- **The ending builds the WARD ONLY**: `build([WARD], [])`, sealed; `ExitDoor` + casing back on the
  ward's back wall at `EXIT_DOOR_POS`; `_corrupt_room()` and the ending video exactly as before.
  `check_intro_ending.gd`. *Follow-up, not built:* the ending wakes you strapped in the same cell —
  *"Good morning, forty-eight."*
- **The cold open's scream stops with its flash** — `main_menu.gd` calls
  `flash_scare(…, 0.8, true)` (`cut_audio`). `check_cold_open_scream.gd`.
- **Proof it walks:** `autoplay_intro_route.gd` drives cell → Lab scene change on the shipping paths
  (real ray, `ai_move_dir`; the wake-up needs no input) in **75.4 s** of game time (cell 8.7 s,
  calibration 39.0 s with both rounds, airlock 8.9 s); ≈ 5.5 min for a human with reading, the tape
  and looking round (an estimate, not a measurement).
- **Art:** the surfaces, door, pad, sink porcelain, steel, screen cloth and the two photo slides are
  **generated** (the user's raws in `assets_src/textures/intro/user/`, processed by
  `tools/make_intro_wing_art.py --user` / `--user-slides`); the wall stays composed on purpose;
  everything with words is Pillow. **Six sounds are the user's own recordings** (raws in
  `assets_src/audio/intro/user/`, rendered by `tools/import_intro_user_sfx.py`, loudness matched
  to the stand-in each replaced): `switch_stuck` (the first, stuck press), three buckle takes (⚠️ **unused** since
  the third hand playtest removed the buckling),
  `intro_session46_tape`, `intro_power_cut` (~10.6 s), `intro_door_creak`, `intro_cell_buzz` (a
  heavy metal door) — plus, since the fourth hand playtest, the patient's wordless `patient_scream`.
  The rest are procedural stand-ins in `docs/TODO_sounds.md`, `intro_chair_sit`, `intro_hatch_slam`,
  `intro_hatch_shutter` and the `say` stand-in `intro_patient_words` among them. The SERIES D slides
  and the patient's face are **flux** (`tools/make_intro_wing_art.py --series-d`, raws + prompts in
  `assets_src/textures/intro/flux/`).

### ⭐ No buckling — the wake-up is one move (third hand playtest, 2026-09-25)

- **Lying under the caged bulb → "IT WAS ONLY A DREAM." → sit up → stand beside the bed**, one
  continuous sequence with input frozen: `WAKEUP_TWEEN_TIME` 1.2 s coming to + `SIT_UP_TIME` 0.9 s +
  `STAND_TIME` 1.2 s = **3.3 s**, ending at `CELL_STAND_POS` on the 1.65 m standing eye, turned to the
  cell door; then control. No E presses, no head turns to straps, no `CellLegsSheet` — nothing ever
  looks down your own body, so there are no legs to draw.
- **The restraints stay as a detail, already UNBUCKLED**: three `Strap_N` plain `Node3D`s (no
  `UseProp`, no collider), released at build by `_release_strap(i)`, their loose ends hanging down the
  bed's sides. Someone let you out; the figure strapped to the same bed through the glass is the
  contrast. They are not interactable and do not stop the interact ray.
- **VO1** *"Good morning, forty-six. I mean — forty-seven."* starts as you stand; when its stream
  ends (`_say(…, _release_cell_door)`) `intro_cell_buzz` sounds and the door swings open 1.15 s later —
  measured **5.2 s after you stood** (4.6 s with the old, shorter take), with no input. E is first met on the tap, the wristband note
  and the doors.
- The beat key recorded when you stand is still `"straps"` (it now means *out of the bed*); the
  restore and `check_intro_glimpse.gd` key on it.
- `intro_strap_buckle`, `_2`, `_3` are **unused** — left on disk, marked so in `docs/TODO_sounds.md`.

### ⭐ The fourth hand playtest's changes (2026-09-25)

- **"You may proceed." means it.** The `proceed` beat — and `ExitDoor`'s unlock — fire as VO5
  STARTS (`_on_proceed()`), not when its stream ends. `check_intro_beats.gd` asserts the exit is open
  while `AirlockSpeaker` is still playing.
- **VO1 is a correction, not a stutter**: *"Good morning, forty-six. I mean — forty-seven."*
  (`tools/make_pa_voice.py intro`, caption to match). Still five lines.
- **The soundtrack's first track is 1:25** (85 s, 4 s fade, re-cut from
  `assets_src/audio/intro/ambient_asylum_full.ogg`), then `intro_second_music` loops as before.
- ⭐ **SERIES D — hold still, they cannot reach you.** Round one's **GOOD.** (the look-away lesson,
  unchanged) does NOT stand you up. The chair keeps you (`_calib_state` 6); after `SERIES_D_DELAY`
  3.0 s the projector clacks back on with a new carousel (`SERIES_D`): a title card
  (`slide_d0_title`, 2.5 s, *SERIES D · SUBJECT 47 · FIVE EXPOSURES · REMAIN SEATED*), then five flux
  photographs of **one new thing** — pale, emaciated, its head wrapped in bandages — each a CLOSER
  frame, 1.6 s apiece (`SERIES_D_SLIDE_TIME`): the far end of a ward · behind a curtain · crouched on a
  bed · at a wired-glass window · lunging at the lens (FIG. 5 is full bleed, the thing has outgrown the
  frame). Captions **SERIES D.** then **STAY SEATED. THEY CANNOT REACH YOU.** (queued, landing on
  FIG. 1). Each figure is a gaze source at `SERIES_D_INTENSITY` (six steps: the title card 0.02, then 0.12 · 0.2 · 0.3 · 0.4 · 0.5, × 20/s) while you sit;
  watched straight through, the bar reaches the 0.6 ceiling by FIG. 4 and is pinned there.
  Sitting through all five completes it: **GOOD.**, projector off, you stand, then VO4 → the airlock
  door. The pin is `player.begin_qte()`, which refuses the player's own E, so the level polls E itself
  and shows **`E — stand up`** (`StandHint`) while the round runs; standing early stops the slides,
  repeats **SIT DOWN.**, and re-sitting runs round two again from its title card. It teaches the rule
  the Lab's first apparition kills you for — do not run. ⚠️ New monsters only, never the game's own
  creatures (it would spoil every later first appearance). Round one's NOTED. (a timeout) skips it.
- ⭐ **THE PATIENT AT THE AIRLOCK HATCH — in-world, not fullscreen.** A 0.6 m barred hatch
  (`HATCHES`, cut like a window, closed around with CSG, a steel frame, five bars and a cross-bar, a
  solid collider) sits in the airlock's **west** wall, dead ahead as you step through the AirlockDoor —
  `check_intro_beats.gd` proves the doorway's ray reaches its bars. Behind it, `PatientCell`
  (1.6 × 1.8 m, skinned near-black so the lit ward's 0.30 ambient cannot grey the dark). A steel
  shutter hangs raised in rails above it from the start. The AirlockDoor's `opened` (fires before the
  leaf moves; once) starts it. ⭐ **The user's order** (2026-09-25: *"first a scream and a very sudden
  one. And secondly, they will kill all us"*): at **`HATCH_SLAM_AT` 0.35 s** — the leaf ~40 % open,
  the hatch already in view — ON ONE FRAME a patient (`patient_hatch.png`, a flux face as a real RGBA
  cutout) slams into the bars, the user's wordless **`patient_scream`** starts with `intro_hatch_slam`,
  the bars shake, a low light snaps on between the bars and his face (lit from below, spilling striped
  light into the airlock) and the wing's ambience bus dips 8 dB — no lead-in, nothing rising before
  it, the dip never ahead of the scream → when the scream has run its length (+0.08 s), still pressed
  to the bars under his light, he shouts **`intro_patient_words`** (*"They'll kill us. They'll kill
  ALL of us!"*) with his own line on screen (`_patient_line()`: dirty yellow `PATIENT_CAPTION_COLOR`,
  above the observer's slot, never queued) → only when the words end is he dragged back from the bars
  into the dark (0.4 s) → the light stutters out 0.45 s after the words → the shutter drops at 0.95 s
  and BANGS (`intro_hatch_shutter`; any voice tail muffled 14 dB behind the steel) → beat `hatch` →
  **`HATCH_AFTER` 1.0 s** of quiet → only then may the airlock's buzzer and VO5 run (measured: the
  exit opens 3.3 s after the shutter). Gains from the files' measured levels: scream `SCREAM_DB`
  −2 (its mean is already −1.2 dB), words 4 dB under it (+7.5, the files' 13.5 dB gap), stand-ins +6,
  `max_db` 8; the master limiter takes the peaks. ⚠️ ZERO panic (nothing is a `ScaryObject`, nothing
  calls `add_panic`), `Screamer` is never touched, and it never replays — not on a back-door return
  (`_hatch_restore()`: shutter down, dark, empty), not on a second `opened`.

### ⭐ Fifth hand playtest fixes (2026-09-26) — built

1. **SERIES D tells you to look back, and waits for you** (capture #1: *"When you look away you do
   not even understand that at some moment you need to look back - should be said"*). Measured from
   the log: round one ended on GOOD. at 96.4 s while the player was (correctly) looking away;
   SERIES D ran on a plain timer and completed at 110.0 s with nobody watching it. Now: as the
   projector comes back on, the observer REPEATS VO3 — *"Look at the screen, forty-seven."* (the
   same recording, so still five lines) — then STAY SEATED. THEY CANNOT REACH YOU.; the slides only
   advance while the camera faces the screen (`AWAY_DOT`), and after 1.5 s looking away the caption
   **LOOK AT THE SCREEN.** repeats (at most every 4 s). Proof: `check_intro_beats.gd` looks away
   during SERIES D and asserts the slide does not advance and the reminder appears, then looks back
   and it completes. **Proved red** with the gate and the VO3 replay disabled (3 checks), then restored.
2. **The patient's scream hits harder** (the user: *"The jumpscare when you enter the final door
   should be louder"*). The file is already at full scale (−1.2 dB mean, 0.0 peak), so there is no
   level headroom — the levers are contrast and distance: the ambience dip on the slam frame goes
   −8 → **−24 dB** (the music and beds all but vanish under it), the scream and words no longer
   fall off with distance across the airlock (`HATCH_UNIT` 3 → 6 m), and the scream is driven
   +6 dB harder into the master limiter (`SCREAM_DB` −2 → +4, `HATCH_MAX_DB` 8 → 12). Still in-world,
   zero panic. Proof: `check_intro_beats.gd` reads the constants and asserts the dip and gains.

### ⭐ Sixth hand playtest fixes (2026-09-26) — built

1. **The tray's rebuke is immediate** (capture #1: *"If you touch you should get the trigger
   immediately and the note we said not touch. Now even though I did it before I first saw the
   message sit down"*). Measured: the tray was touched 4.5 s into calibration; the panic spike was
   instant, but WE SAID NOT TO TOUCH IT. NOTED. went through the observer's caption queue behind
   VO3's caption and SIT DOWN. Now it is shown the moment the tray is touched (its own immediate
   line above the caption slot, `_immediate_line()` — the patient's helper, generalised — so it can
   never collide with a queued SIT DOWN.).
2. **Round one shows SEVEN stimuli, and LOOK AWAY. comes after the last** (capture #2: *"we need to
   show slightly more objects before we say move away for the first time"*; the user chose 7, and a
   count, not a panic threshold). Measured: LOOK AWAY. fired on panic ≥ 0.35 — the tray had already
   put panic at 0.60, so it fired almost as the player sat (GOOD. 14 s after the tray, ≤ 1 slide
   seen); even untouched it came on the third stimulus (~11 s). Now: title + **7 stimuli** — the two
   ink blots, the ward photo and the No. 46 portrait, plus **three new flux slides** in the same
   archival frame (a doll with blacked-out eyes, an empty restraint chair under a lamp, a clinical
   skull illustration) — **2.5 s each, advancing only while you face the screen** (the same gaze gate
   as SERIES D), and LOOK AWAY. once the last has been shown. Panic climbs across the round (a
   ladder, pinned at the 0.6 ceiling) but no longer decides when the lesson ends, so the tray cannot
   cut it short. Order: black blot · WARD 4 photo · restraint chair · skull plate · doll · No. 46 ·
   red blot. Proof: `check_intro_beats.gd` pre-loads the bar to 0.6 exactly as the tray does, sits,
   and asserts all seven are shown before LOOK AWAY. (measured 18.7 s); with the old panic trigger
   restored it fails at 0.0 s — the playtester's bug, reproduced. The immediate rebuke is asserted
   on the touch frame (red with the queued caption restored).

**Declined in the grill-me — do not re-pitch:** a calm-light lesson in calibration · level previews
or photos of the player on the projector · bed curtains · a KONTUR gate-8 catch in the airlock · the
voice degrading room by room · a clean/modern clinic look.

**The Ward (room 4 of the wing; before 2026-09-24 it was the whole intro)** — 12×18 m, built at runtime by `intro_room.gd` (see `INTRO.md` for its original design)
Note text: *"You are Subject 47. This is a psychological experiment... Stay calm. Do not touch what you are not meant to touch. If something calls out to you — a voice, a ringing, anything that asks for an answer — do not answer it. You are not meant to speak to anyone but us. The door ahead is your first test. We are watching."* (the "do not answer" paragraph is **BUG_FIX.md 2.1** — plants a hint against the Backrooms rotary phone before the player ever meets it)
- ⚠️ **UNLOSEABLE, and it must stay that way** — since 2026-09-24 by the panic CEILING (⭐ above),
  not by an absence: "nothing here calls `add_panic()`" was never enough, because sprint charged
  +6/s with no level-0 exemption. `RandomAmbient` is still deliberately NOT registered (it carries
  5/8/12 panic per event); a level-local, zero-panic timer plays `floor_creak`/`pipe_groan`/
  `gurney_creak` instead. The bar is exactly 0 through the ward; `check_intro_beats.gd` asserts it
- **"The ward is occupied" (2026-07-28, reworked 2026-08-16).** The room previously had *no scares
  whatsoever* — 60–120 s of nothing. Now: the **light switch sticks on the first press**
  (`LightSwitch.presses_needed = 2`) — it clunks, the plate blips, and one fluorescent stutters
  alight for 0.4 s, showing the ward you have been crossing blind, then dies. The two spare gurneys
  carry **sheeted forms**. Breathing (`nook_breath`, `FarBreath`) spawned at the blackout, cut the
  instant the lights come on
  - ⚠️ **The glimpse uses the MIDDLE tube (z=0), not the far one** (2026-08-16). It was the far
    tube (z=−6) on the sound grounds that the flash should show somewhere the player has *not*
    been — and that lost to a measurement: with `omni_range` 9 from z=−6, both sheeted beds and
    both IV stands sat at z=+5…+6.5, **11 m away and completely out of reach**, so the best beat in
    the room lit bare floor. One occupied bed was moved to `GLIMPSE_GURNEY_POS (3.6, 0, 1.8)`. The
    middle tube specifically, because `_on_switch_flipped()` leaves it dead forever: the 0.4 s
    flash is the only time the centre of the ward is ever lit from above, and afterwards that spot
    is a permanent hole in the ceiling light. `check_intro_beats.gd` asserts the lit tube's range
    reaches an occupied bed — the old "and it is the FAR end" assertion was true and useless
  - ⭐ **One bed is EMPTY afterwards** (2026-08-16). The bed the glimpse showed loses its covered
    form the instant the switch throws, while the room is still pitch black. No sound, no panic, no
    camera move, no acknowledgement, nothing looks at you — `MovedProp`'s register (SCARY P6)
    applied to a state change, and unwitnessable by construction. It is what gives the glimpse a
    purpose: the flash stops being a mood beat and becomes the only evidence the room used to be
    different. A player who did not look during it loses nothing and never knows. ⚠️ It is
    `queue_free()`, never `visible = false` — CSG collision is not inherited from a hidden parent
  - ⚠️ **The sheeted forms are ONE SMOOTH SURFACE, not boxes — and specifically not MORE boxes**
    (rebuilt 2026-08-16, second revision). This prop has been rejected on a replay twice:
    | version | what it was | the user's verdict |
    |---|---|---|
    | v1 | two axis-aligned boxes — a mound and a head bump 6 cm proud of it | *"Is it a human on the bed? Or a pillow and a blanket?"* |
    | v2 | eleven axis-aligned boxes — head, shoulders, chest, abdomen, hips, thighs, knees, shins, two feet, on a slab drape | *"This still does not look realistic."* — it read as a **stack of blocks**: every part legible as a discrete rectangular step, hard 90° corners, top faces coplanar and taking identical light |
    The lesson is structural, not a tuning miss: **axis-aligned boxes cannot make a draped organic
    mass**, and more parts made the wrong silhouette more detailed. v3 is a `SurfaceTool`
    heightfield — an indexed, welded grid sampled from a soft union of ellipsoidal blobs (head /
    neck / shoulders / chest / waist / hips / two thighs / two knees / two shins / one foot tent),
    blended with a polynomial smooth-max, with **analytic central-difference normals** so the
    shading is a gradient and there is not one flat facet on it. The same field carries the drape:
    past a rounded-rectangle boundary the height plunges to a hem below the mattress line
    - ⚠️ **The body must be narrow enough to leave a GUTTER.** The first draft of v3 gave the
      shoulders `rx` 0.37 against a mattress half-width of 0.425 and rendered as *a mattress with a
      slight bulge* — the v1 complaint again. The sheet is back down to 0.02 m by |x| = 0.24 at
      every station, and that flat gutter is what says the mound is a body lying ON the bed
    - ⚠️ **Nothing may be taller than it is wide** — a blob whose height exceeds its radius renders
      as a cone, and one render had two of them at the foot of the bed. There is **one** foot tent
      spanning both feet, not two: that single peak at the end of the bed is the whole morgue image
    - ⚠️ **Cloth BRIDGES concavities.** Two leg blobs alone put a 55°-per-side crevasse down the
      middle of the legs (measured: adjacent normals 110° apart). A wide low blob at (−0.004,
      0.605) *is* the sheet spanning between the legs; worst normal split on the shipped build is
      **71.5°**, against a box corner's 90° and a coincident pair's 180°
    - The texture (`sheet_linen.png`, generated) went on **last, on a silhouette that already
      worked** — it is not the fix, and `check_intro_sheet.gd` passes with the file deleted. Its
      tint is DERIVED so the mean colour lands on the `(0.44, 0.43, 0.40)` v2 shipped with
    - Silhouette, crown to sole: head 0.203 · neck 0.104 · shoulders 0.228 · chest 0.253 · waist
      0.172 · hips 0.221 · thighs 0.175 · knees 0.140 · shins 0.108 · foot tent 0.164
    - **`tests/check_intro_sheet.gd`** exists because the property the user rejected — the SHAPE —
      was the one thing nothing measured: `check_wall_overlap` had no opinion, `check_intro_beats`
      only counted the forms, and `check_art_aspect` skips it for carrying no flat quad. It asserts
      off the BUILT MESH ARRAYS (never the generator's own height function): no right angles, the
      mound is smooth-shaded not faceted, it is one welded surface, the side silhouette has ≥3
      landmarks separated by real troughs, it drapes below the mattress, and **no hem vertex is
      inside the gurney frame's AABB**. Verified red against a faithful rebuild of v2
  - ⚠️ **The mattress decal is only on the EMPTY bed.** A covered bed shows a sheet, and the decal
    plane physically intersected the old sheet boxes
  - ⚠️ Each gurney's `GurneyFrame_*` / `GurneyMattress_*` / `SheetedForm_*` carries a **position
    tag** in its node name. All three gurneys used the bare name `GurneyFrame`, so Godot silently
    renamed two of them and anything looking one up by name found only the first — Issue 17, the
    fourth instance in this one file
  - ⚠️ **NO FULLSCREEN jumpscare in this room** (or anywhere in the intro). `INTRO.md` §2 specced a
    mid-fumble nightmare flash; it was built and then cut on the first playtest (*"the screamer at
    the intro level is not needed"*). The cold open on START already spends that image, and firing it
    again in the one room with no fail state teaches the player the image is free.
    `check_intro_beats.gd` asserts its ABSENCE (`Screamer` neither triggering nor flashing, its black
    panel never shown). ⭐ The patient at the airlock hatch (2026-09-25) is the user's IN-WORLD scare —
    it is not this, and it is asserted not to be
  - **The wheelchair turns to face the table** once the note is read — on **proximity + looking**
    (within `WHEELCHAIR_TURN_DIST` 3.2 m, dot > 0.55), with a caster creak, over 1.1 s. ⚠️ This
    deliberately INVERTS `MovedProp`'s happens-off-screen rule: an anomaly nobody witnesses is
    worth less than an event they certainly see, in a short tutorial room. See the same call in
    the House
    - ⚠️ **Both tests are HORIZONTAL-ONLY, and the chair sits at x = 2.4** (2026-08-16). The facing
      test was already horizontal; the DISTANCE test was not, and the camera is 1.65 m above the
      chair's floor anchor — so a 3.2 m 3D radius was really **2.741 m of floor**, and the walk
      from the note to the exit door passes at 3.0 m. **The beat could not fire at any yaw**, and
      the 2026-08-16 playtest is the log of it not firing. The chair also moved x 3.0 → 2.4 so the
      clearance is ~0.8 m rather than a knife-edge 0.2: a beat that only fires on a perfect line is
      worse than one that never fires, because nobody can tell it is broken. `WHEELCHAIR_TURN_DIST`
      is unchanged
    - ⚠️ **The sound is `intro/wheelchair.wav`** (user-supplied, 2026-08-16), replacing the
      `gurney_creak` fallback the beat had used for its whole life because `wheelchair_turn` never
      existed. Measured: 2.009 s, mono 44.1 kHz, −2.3 dBFS RMS — **9.6 dB hotter than
      `gurney_creak`**, so the gain is `WHEELCHAIR_SFX_DB = −7.6` (the old call played the creak at
      +2.0), set from the file's level rather than from a plausible number. And the file **does not
      decay** — its last 0.1 s is still at −1.3 dBFS — so it is played at full level for the whole
      1.1 s turn and then faded over 0.5 s (`WHEELCHAIR_SFX_FADE_START` / `_FADE_TIME`), because
      the alternatives are a creak that stops dead with the chair or a hard cut at full amplitude
      0.9 s after it. `check_intro_beats.gd` asserts the STREAM, not just that something plays — a
      working fallback is exactly what hides a missing asset
    - ⚠️ **SUPERSEDED — the `−7.6` in the paragraph above is HISTORY** (audited 2026-09-19).
      `intro_room.gd:116` ships `WHEELCHAIR_SFX_DB := 1.0` with `WHEELCHAIR_SFX_MAX_DB := 8.0`; the
      ⭐ entry immediately below carries the live value. The measurement, the fade constants and the
      stream assertion in that paragraph are untouched and still current.
  - ⭐ **LOUDER AGAIN (2026-09-10, capture #1: *"Can we make the noise of this wheelchair even
    louder?"*).** `WHEELCHAIR_SFX_DB` −7.6 → **+1.0**, `max_db` **8.0** (it was the default 3.0,
    which clamped `volume_db + attenuation` — the gain would have done nothing inside 2.5 m), and a
    `HoldBreath.dip(0.35)` on `Ambience` as the turn starts, because contrast is the cheaper half
    of loud. The peaks go into the Master limiter. Still zero panic; `check_intro_beats.gd` reads
    the constants off the script and asserts `max_db >= 8`.
  - ⚠️ **The breathing is CLOSE, not far.** `FarBreath` is spawned at the blackout at (0, 1.4, 8.4),
    ~3 m from the ward entry — in the dark, just off your shoulder as you come through the door —
    and cut the instant the lights come on. (Until 2026-09-24 it sat 1.61 m from the ward bed you
    woke on; you now wake in the cell.) The node name is kept only because `check_intro_beats.gd`
    looks it up
- ⚠️ **The ward's back-wall door — `ExitDoor` in the ENDING, the calibration door in normal play — is
  SEATED into the wall and wears a jamb + lintel casing** (2026-08-16; since 2026-09-24 the walls are
  RoomBuilder's 0.2 m and no node is called `WallBack` — tests find the wall by ray).
  `EXIT_DOOR_POS` was a literal and the leaf floated **0.275 m clear of the wall**, full height,
  full width, with open air behind it — playtest capture: *"the door is not connected to the
  wall"*. It is now derived from `WALL_BACK_FACE_Z` + `DOOR_SIZE` (back face 20 mm inside the wall,
  the same convention `level_1/2/kontur/dungeon` already use), and `_build_door_casing()` adds two
  jambs and a lintel so the leaf reads as recessed. ⚠️ The casing is **siblings of `ExitDoor`, never
  children** (the ending frees the door and needs the frame), and has **no colliders** (a collider
  on the only doorway wall is how this project seals a room by accident)
- ⚠️ `_corrupt_room()`'s planks/red light are derived from `EXIT_DOOR_POS` + `DOOR_SIZE`. They were
  literals from the OLD 5.6 m room and floated in open space 6 m from the door — the game's final
  beat, visibly broken, for the life of the bigger ward. ⚠️ **The derivation was right and the
  anchor was wrong**: until the door was seated (above) the planks still hung 0.485 m in front of
  blank concrete. Both are now asserted, in the normal room and under `GameState.is_ending`, by
  `tests/check_intro_geometry.gd`
- ⚠️ **There is a real candle now, and its light is `visible`** (2026-08-16). `_darken_scene()` hides
  the candle light for the blind fumble and nothing ever un-hid it, so it tweened to a healthy 1.97
  energy on a hidden node — **a hidden `Node3D` light emits nothing** — and there was no candle mesh
  at all, only an `OmniLight3D` hanging 2.2 m above the table. With the tube above the table
  deliberately dead, the note the player is *required* to read had no light on it whatsoever.
  ISSUES_SOLUTIONS **Issue 55**; the flame is the room's only emissive surface and is hidden during
  the fumble with the light
- ⚠️ **Every textured quad is sized from its own artwork.** Four of five were stretched, worst 3.97×
  (`gurney_intro.png` was a 1672×941 landscape photo of a whole gurney — frame, rails and the floor
  around it — squashed onto a portrait mattress quad; it is now a plain stained pad at the quad's
  aspect). The cabinets were rebuilt to match their art too: a wide two-door medical cabinet on a
  `QuadMesh`, not a landscape photo cropped onto a tall narrow box face (Issue 24).
  `tests/check_art_aspect.gd` asserts mesh aspect against **effective** texture aspect (pixel aspect
  × `uv1_scale`, because the note deliberately UV-crops a square, black-backed source)

## NEEDS A PLAYTEST

This room HAS been hand-played (2026-07-28, 2026-08-16, 2026-09-10) — unlike Levels 7 and 8, which have
not been played at all since their 2026-09-12 rebuilds. What has landed here since the last capture and
has not yet been seen or heard by a player:
- **The louder wheelchair** (2026-09-10). `WHEELCHAIR_SFX_DB` +1.0, `WHEELCHAIR_SFX_MAX_DB` 8.0 and the
  0.35 s `HoldBreath` dip were built in answer to capture #1 (*"even louder"*) and never replayed. There
  is no headroom past this — the next lever is contrast only — so the replay verdict decides the beat.
- **The v3 sheeted form.** v1 and v2 were each rejected on a replay; v3 (the `SurfaceTool` heightfield) is
  asserted by `check_intro_sheet.gd`, but there is no recorded human verdict on the one property that was
  rejected twice: whether it reads as a body.
- **The seated exit door + casing and the derived `_corrupt_room()` planks** (2026-08-16). Both are now
  asserted by `check_intro_geometry.gd` in the normal room and under `GameState.is_ending`, but the ending
  pass is a geometry assertion, not a played beat.

- ⭐ **THE WHOLE INTAKE WING (2026-09-24) has never been played by a human.** Driven end to end and
  screenshot-toured room by room, but these are judgment calls only a player can make:
  - **Length and pace** — 75.4 s driven, ≈ 5.5 min estimated; is calibration (39.0 s driven, two
    rounds now) too long?
  - **The one-way glass** — does the player notice someone is on their bed, and notice it is gone?
  - **The hall's darkness** (`HALL_BULB_ENERGY` 0.8, kept low so the glass reads at 10.7× contrast).
  - **The five voice lines** — TTS stand-ins; are five too many or too few against the captions?
  - **The remaining stand-in sounds** (`docs/TODO_sounds.md`) — six are the user's now.
- ⭐ **Built from the first hand playtest (2026-09-24) and not yet replayed:** the chair on the
  calibration spot (does SIT DOWN. read, and does the pin feel like being strapped in?); the
  soundtrack handing over to `intro_second_music` at 1:25 (is −13 dB the right level?).
- ⭐ **Built from the third hand playtest (2026-09-25):** the no-buckling wake. The fourth hand
  playtest went through it and its only capture there was VO1's wording (fixed); still unjudged
  directly — 3.3 s of frozen sit-up-and-stand, and now **5.2 s** standing before the door buzzes (the
  new VO1 is longer). ⚠️ The locked cell door answers the ray meanwhile (prompt + locked rattle).
- ⭐ **Built from the fourth hand playtest (2026-09-25) and not yet replayed:**
  - **SERIES D** — do five figures in ~10 s read as ONE thing coming closer, is `E — stand up` a
    real temptation or just noise, and does the lesson land ("I don't need to run")?
  - **The patient at the hatch** — is it seen from the doorway (the tour says yes: dead ahead), does
    the face read behind the bars at 3 m, is the scream too loud at `SCREAM_DB` −2 against the
    ducked beds, and does 1.0 s of quiet after the shutter before the buzzer feel right?
  - **The stand-ins** — `intro_patient_words` is a `say` voice (the ElevenLabs key is invalid);
    `intro_hatch_slam` / `intro_hatch_shutter` are procedural. `docs/TODO_sounds.md` carries prompts.

⚠️ Whatever the captures say, the two hard rules hold and are guarded: the room is **UNLOSEABLE**
(the panic ceiling; `check_intro_panic_ceiling.gd` + `check_intro_beats.gd`) and there is **NO
FULLSCREEN screamer in it** (asserted as an absence — the patient at the hatch is in-world and
zero-panic).

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

⚠️ **`WHEELCHAIR_SFX_DB = −7.6` (2026-08-16) → superseded 2026-09-10 by `+1.0` / `max_db` 8.0.**
The −7.6 was derived from the file's own measured level (2.009 s, mono 44.1 kHz, −2.3 dBFS RMS, 9.6 dB
hotter than `gurney_creak`); the shipped +1.0 was set on the user's *"even louder"* call instead, so the
derivation is history but the measurement behind it is not. The losing clause sits mid-sentence inside a
paragraph that is otherwise current (the sound file, the no-decay fade, the stream assertion), and could
not be lifted out without rewording surviving prose — so it is flagged in place in SPEC rather than moved,
and recorded here. Truth from the code: `intro_room.gd:116-117`.

### The Intake Wing (2026-09-24) — measured, tried, rejected

- **Why it was rebuilt.** In-engine the lit ward was a bare dark box (black-cube table, slab
  cabinets, empty walls, no visible fittings), 4 interactables, a 60–120 s run, and it taught none of
  the rules the game kills you with. And it was **loseable**: `player.gd` charged sprint +6/s with
  decay suppressed and no level-0 exemption, so ~8.3 s of Shift fired the screamer — in the room
  whose hint line says *"Shift — run"*. `check_intro_beats.gd` never sprinted, so it could not see it.
- **The cold-open scream bled ~9 s into the wake-up.** Probed before the fix: `nightmare_scream.ogg`
  (10.28 s) still playing at 2.8 s of a 0.8 s flash — `flash_scare()` never stopped `_audio`.
- **Glass contrast:** from the hall, the cell behind the glass averages 34.8/255 against the hall
  wall's 3.2 (**10.7×**, at `HALL_BULB_ENERGY` 0.8; 0.55 gave ~10× but left the hall unreadable).
  From the cell the pane is 11 against the wall's 40 — a dark pane with the bulb's highlight.
- **Ambient ENERGY is a dead lever in this scene** — the shared environment's ambient colour is
  (0.04, 0.03, 0.02): energy 1.0 moved the lit ward 13.1 → 13.3/255. The switch tweens the COLOUR
  too (`LIT_AMBIENT_COLOR` = (0.28, 0.29, 0.31)), and the lit frame reaches 15.8/255. ⚠️ Setting a flat colour at LOAD (the Lab's `_boost_ambient`)
  was tried and reverted: the blackout went 3.1 → 0.4 (ISSUES_SOLUTIONS Issue 282).
- **Blackout timing:** the power dies on `WingDoor.opened`, emitted **before** the leaf moves —
  otherwise the torch lights the ward through the opening before the glimpse.
- **The cell door opens OUTWARD**: inward, its leaf plus the foot of the bed sealed off the sink,
  and the glass had no collider, so E worked through it — both caught by `check_reachable`
  (Issue 279).
- **Colliders stop below their tops** on the torch trolley and the tray stand: reaching past, they
  answered the rays aimed at the torch / the tray's objects.
- **Calibration:** 11.6 s of watching reaches LOOK AWAY.
- **Art:** the free flux quota was exhausted on the first key pair and the build fell back to
  composed art (only the first of the two CF key pairs had been tried — see
  `spec/systems/assets-and-audio.md`). The user then generated the surfaces and photo slides; each
  is luminance-matched to the texture it replaced so the measured lighting above still holds. A
  flux wall raw was rendered in the wing and **rejected** — its large crackle plates read as crazy
  paving and repeated down the ward. The first "No. 46" slide put the eye bar over the MOUTH (placed
  from a thumbnail estimate); the bar rectangle in `tools/make_intro_wing_art.py` is now measured
  on the rendered slide. The tufted
  `gurney_intro.png` ("a strange tufted rug") is on no bed any more and is unreferenced.
- **Captions queue:** the first tour printed "STAND ON THE MARK." straight over VO3's caption
  (Issue 281).

### The first hand playtest (2026-09-24, three J-captures) — what it answered

⚠️ **Its strap and legs items are superseded** by the third hand playtest below (no buckling at all);
kept as the history of why.

Three items left NEEDS A PLAYTEST with these answers; each was the user's own call.
- **The strap release read as STANDING** — capture #1: *"The way of unbuckling does not look natural.
  It feels like you stood up and then tried to do it. You should probably be doing it when lying and
  just moving your head, make it more realistic. And think what to do with the legs"*. Measured: the
  wake tween ended at `WAKE_CAM_SITTING`, 0.85 m over the pad (1.45 m in the world against 1.65
  standing), pitched down an EMPTY mattress. Now the wrists come off lying (eye 0.30 over the body,
  0.90 in the world; head roll ±0.42 rad on the pillow — the upright camera's only way to say
  "turned on the pillow"), the wrists moved from beside the chest to beside the HIPS so the lying
  eye's ray reaches them, and the ankles come off sitting up over `CellLegsSheet` (legs-only
  `SHEET_BLOBS[5:]`; the straps ride 2.4 cm over the sheet and the ankle halves rise to a 0.14 m
  apex over the 0.108 m shin crest, or a flat band went through the legs).
- **The soundtrack looped its own opening** — capture #2: *"when the soundtrack ends it starts
  again - and we hear that sound of like dreaming and waking up again"*. See the ⭐ rule above.
- **"LOOK AWAY." never came** — capture #3: *"It was said do not look away until instructed - but
  when I will be instructed? They are repeated in circles."*. Measured by replaying the player's own
  spot, (0.16, −17.54): the camera was **3.44 m** from the screen, outside `GAZE_RANGE` 3.0, so the
  gaze ray found nothing, panic never moved, the slides cycled, and the 60 s fallback passed them
  untaught. A floor mark only asks; a chair PUTS you there: seated, the eye is **2.39 m** away and
  LOOK AWAY. comes after **11.1 s** of watching. ⚠️ The chair's visual node is `SubjectChairFrame`,
  not `SubjectChair` — the first build gave both the same name and Godot renamed the E volume
  (Issue 17 again; `check_intro_beats` caught it as "the chair does not answer the ray").
- **The stand-in sounds** — the user supplied six recordings (the ⭐ art/sounds rule above).
- ⚠️ **`check_reachable` had been probing the intro from a SITTING eye.** It reads the eye off the
  camera at load, which was 0.85 (and would now be 0.30, lying): its intro row carries `eye` 1.65,
  and the camera is put there before probing.
- **The subject chair casts NO shadow** (review of the seated view, 2026-09-25). The projector stands
  behind the chair, so its backrest threw a shadow across the lower half of the screen, and the
  player has no body, so a seated player saw an EMPTY chair's silhouette in front of the slides.
  Measured: the camera sits 0.18 m in front of the backrest (at 2.33 m from the screen); hiding the
  chair frame removed the silhouette. Every part of `SubjectChairFrame` has
  `cast_shadow = SHADOW_CASTING_SETTING_OFF`.
- **A queued caption can go stale**: "SIT DOWN." queues behind VO3's caption, and a player who sat
  during VO3 saw the order arrive after they had obeyed it. `_caption(…, stale_when)` drops a queued
  line whose condition is true when its turn comes; "SIT DOWN." passes `_seated`.

### The second hand playtest (2026-09-25, four J-captures)

⚠️ **Its legs-sheet item is superseded** by the third hand playtest below (`CellLegsSheet` is gone).

- **The legs are a PLAIN sheet** (captures #1–#2: *"What is this big object at the place where my legs
  should be? Looks very weird, let's make it plain"* · *"Let's make a plain bed sheet or at least
  looking like normal legs without bed sheet at all"*). The legs-only heightfield put a 0.22 m hip
  mound a hand's width from the lying eye. Now `_build_sheet_mesh([])` — the same sheet with no
  body under it; `check_intro_beats.gd` reads the built mesh and asserts nothing rises above 3 cm
  (measured 0.018 m). `ANKLE_APEX` 0.14 → 0.035: there are no shins to clear.
- **"The soundtrack started again" was the END of the first track** (capture #3; the user's own
  diagnosis after the switch was shown to work in-engine: *"the issue is with the ending of this
  track"*). `ambient_asylum.ogg` was trimmed to 2:15 with a 4 s fade (then to **1:25** on the fourth playtest) (ffmpeg, from the kept
  original); `intro_second_music` still follows it.
- **No walk to the line** (capture #4: *"What for to cross that line? I think looking away while
  sitting in the chair and then standing up is sufficient"*). `GOOD.` → stood up → VO4 → the airlock
  buzzes. The line, its lamp, `LINE_Z` and the sprint caption are gone, so ⚠️ **the intro no longer
  teaches that sprinting costs panic** — the Lab's first note still says DO NOT RUN, and the panic
  ceiling still holds against a sprint (`check_intro_panic_ceiling.gd`).

### The third hand playtest (2026-09-25) — the buckling is gone

The strap release was the most-reported beat of all three playtests: #1 *"It feels like you stood up
and then tried to do it"*, #2 *"What is this big object at the place where my legs should be?"*, #3
*"Let's draw the legs to make it look realistic"*. Three rounds of fixing the *presentation* (lying
release, a legs mound, a plain sheet) each produced a new complaint about the same beat. The user's
call: *"let's remove this buckling thing entirely … you do not need to free yourself from the bed.
You just stand up and continue"*. Do not re-pitch a restraint interaction in the cell.
- **Measured:** lying → standing is **3.3 s** (1.2 + 0.9 + 1.2), eye 1.65 ± 0.02 at `CELL_STAND_POS`,
  input free; the door opens **4.6 s** after you stand with no input; zero panic; the cell leg of
  `autoplay_intro_route.gd` is **8.0 s** (whole route 58.2 s). `check_intro_beats.gd` 89 checks.
- **Proved able to fail:** skipping the build-time release → "already UNBUCKLED … 0 hung"; dropping
  `_release_cell_door` from VO1 → "when VO1 ends the cell door releases"; not chaining the sit-up into
  the stand → the standing, VO1 and door checks. All three went red and were restored.
- **Removed:** `_build_legs_sheet`, the strap focus / E-poll / per-strap buckle code, `VO1_DELAY`,
  `STRAP_SOUNDS`, `STRAP_PROMPT`, and the route's `Input.action_press` plumbing. The restraints keep
  their meshes and `_release_strap(i)` pose; nothing else reads them.
- ⚠️ The beat key is still `"straps"` — renaming it would touch the restore and
  `check_intro_glimpse.gd` for no player-visible gain.

### The fourth hand playtest (2026-09-25) — two new scares, both on the user's terms

The user's words, per capture: #1 *"The door cannot be opened straight after you say you may
proceed"* and *"with the screen experiment it is a good idea to make another iteration where some
monsters will be shown. So the player learns no need to hide from monsters"*; #2 *"after you open this
door it is a good idea to have a screamer of another asylum patient saying they will kill all of us"*;
#3 *"It should be like good morning 46, I mean, 47"*. The user chose "hold still — they cannot reach
you", NEW monsters, and an IN-WORLD patient (not fullscreen). `patient_scream.ogg` is wordless (the
user), so the words are a second file.
- **Measured:** the exit had stayed "Not yet." for ~2.4 s after "You may proceed." appeared; now open
  while VO5 plays. SERIES D run 10.5 s (2.5 s title + 5 × 1.6 s) → panic pinned at 0.6000. The hatch:
  slam and scream on the SAME frame, 0.34 s after the door opened; the words 2.45 s after the scream
  starts; the shutter 3.34 s after the words start; exit open 3.3 s after the shutter; zero panic
  across it. Route 75.4 s driven (was 58.2). `check_intro_beats.gd` 126 checks,
  `check_intro_resume.gd` +5.
- **The order was changed once, on the user's word.** The first build (the parent's brief) ran slam →
  words → scream-while-dragged-back; the user then asked for *"first a scream and a very sudden one.
  And secondly, they will kill all us"*. `HATCH_SLAM_AT` went 0.55 → 0.35 s at the same time (0.55
  read as a pause after the door moved). Do not reintroduce a lead-in or a duck ahead of the scream.
- **Proved able to fail** (each disabled, red, restored): GOOD. standing you up (no SERIES D) → 2 red;
  no E-poll → 6 red; words/scream swapped + no buzzer gate → order and airlock red; the buzzer gate
  alone → "buzzer waited" + "HATCH_AFTER of silence" red (the exit opened 0.21 s after the shutter);
  the patient's words back through `_caption()` → the own-line checks red; the scream 0.3 s after the
  slam → "ON THE SLAM'S FRAME" red; no `_hatch_restore()` →
  3 resume checks red, including the patient replaying on a second `opened`.
- ⚠️ **Bugs found on the way** (ISSUES_SOLUTIONS 284, 283): the chair's `UseProp.max_uses` defaults to ONE, so after the first sit
  the chair was inert and a player who stood mid-SERIES D could never sit again (`max_uses = 0`). And
  the first tour showed the patient's words queued behind VO4's fading caption — read only after the
  shutter had come down; his words now have their own line, synced to the voice.
- **Rejected:** a fullscreen patient (the fullscreen face means "you died" everywhere else); the
  game's own creatures on the slides (spoils their first appearances — the same reason level
  previews were declined); 8-step flux re-runs (`generate.py` takes no seed, so a re-run is a
  different picture, not a sharper one — the 4-step drafts were read on the rendered slides).

### The fifth hand playtest (2026-09-26, one J-capture + one note)

- **SERIES D must say "look back", and wait** (capture #1: *"When you look away you do not even
  understand that at some moment you need to look back - should be said"*). Round one ends on LOOK
  AWAY, so the player faces the wall when round two starts; in the log SERIES D ran its timer out
  (GOOD. at 96.4 s → complete at 110.0 s) with nobody watching. VO3 is REPLAYED (not a sixth line),
  the slides advance only while the camera faces the screen, and LOOK AT THE SCREEN. repeats every
  4 s after 1.5 s away. Driven seated and watching, the round still takes 10.5 s.
- **Louder patient** (*"The jumpscare when you enter the final door should be louder"*). The file
  has no headroom (0.0 dB peak), so: ambience hole −8 → −24 dB on the slam frame, `HATCH_UNIT`
  3 → 6 m (no fall-off across the airlock), `SCREAM_DB` −2 → +4 into the master limiter,
  `HATCH_MAX_DB` 8 → 12. ⚠️ Beyond this the only lever left is a different, punchier recording.

### The sixth hand playtest (2026-09-26, two J-captures)

- **The tray's rebuke waited in the queue** (#1: *"If you touch you should get the trigger immediately
  and the note we said not touch. Now even though I did it before I first saw the message sit
  down"*). Touched 4.5 s into calibration, behind VO3's caption and SIT DOWN. Now `_immediate_line`.
- **LOOK AWAY. came too soon** (#2: *"we need to show slightly more objects before we say move away
  for the first time"*). The panic trigger (≥ 0.35) was pre-loaded by the tray (0.60), so the lesson
  ended as the player sat — ≤ 1 slide. The user chose SEVEN stimuli and a COUNT: three new flux
  slides (doll, restraint chair, skull plate), 2.5 s each, gaze-gated, LOOK AWAY. after the last.
  ⚠️ `LOOK_AWAY_AT` is gone; do not bring a panic threshold back as the trigger — the tray will
  always be able to pre-load it.

