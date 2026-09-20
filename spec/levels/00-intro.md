# Intro Room — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Intro Room** — a 12×18 m asylum ward, built at runtime by `intro_room.gd` (see `INTRO.md`)
Note text: *"You are Subject 47. This is a psychological experiment... Stay calm. Do not touch what you are not meant to touch. If something calls out to you — a voice, a ringing, anything that asks for an answer — do not answer it. You are not meant to speak to anyone but us. The door ahead is your first test. We are watching."* (the "do not answer" paragraph is **BUG_FIX.md 2.1** — plants a hint against the Backrooms rotary phone before the player ever meets it)
- ⚠️ **UNLOSEABLE, and it must stay that way.** Nothing here calls `add_panic()`; `RandomAmbient`
  is deliberately NOT registered (it carries 5/8/12 panic per event) and a level-local, zero-panic
  timer plays `floor_creak`/`pipe_groan`/`gurney_creak` instead. `tests/check_intro_beats.gd`
  samples peak panic through every beat and fails if it moves at all
- **"The ward is occupied" (2026-07-28, reworked 2026-08-16).** The room previously had *no scares
  whatsoever* — 60–120 s of nothing. Now: the **light switch sticks on the first press**
  (`LightSwitch.presses_needed = 2`) — it clunks, the plate blips, and one fluorescent stutters
  alight for 0.4 s, showing the ward you have been crossing blind, then dies. The two spare gurneys
  carry **sheeted forms**. Breathing (`nook_breath`) near `WallFront`, cut the instant the lights
  come on
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
  - ⚠️ **NO jumpscare in this room.** `INTRO.md` §2 specced a mid-fumble nightmare flash; it was
    built and then cut on the first playtest (*"the screamer at the intro level is not needed"*).
    The cold open on START already spends that image, and firing it again in the one room with no
    fail state teaches the player the image is free. `check_intro_beats.gd` asserts its ABSENCE
  - **The wheelchair turns to face the table** once the note is read — on **proximity + looking**
    (within `WHEELCHAIR_TURN_DIST` 3.2 m, dot > 0.55), with a caster creak, over 1.1 s. ⚠️ This
    deliberately INVERTS `MovedProp`'s happens-off-screen rule: an anomaly nobody witnesses is
    worth less than an event they certainly see, in a 90-second tutorial room. See the same call in
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
  - ⚠️ **The breathing is CLOSE, not far.** `FarBreath` sits 1.61 m from where the player wakes,
    inside its own `unit_size`, so it plays at full volume into the ear at the moment of sitting up
    and recedes as they cross the ward. This file described it as "at the far wall" for months; it
    never was. Keep it — something breathing behind you as you wake, which quietens as you walk
    away, beats a distant sound you could go and inspect, and the lights coming on delete it before
    you ever can. The node name is kept only because `check_intro_beats.gd` looks it up
- ⚠️ **The exit door is SEATED INTO `WallBack` and wears a jamb + lintel casing** (2026-08-16).
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

⚠️ Whatever the captures say, the two hard rules hold and are guarded: the room is **UNLOSEABLE**
(nothing calls `add_panic()`; `check_intro_beats.gd` fails if the bar moves at all) and there is **NO
jumpscare in it** (asserted as an absence).

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
