# Level 4 — The Backrooms — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Level 4 — The Backrooms (liminal mono-yellow maze)** — `backrooms.gd` + `backrooms.tscn`
- **Entry = the noclip** (`_spawn_noclip()` in `corridor.gd`): the player never reaches room 217 — which now wears `backrooms_tear_door.png`, a black-wood door torn open on a red-lit void, sized from the artwork's own aspect. **Fifteen** metres out every torch dies and `player.kill_flashlight()` force-kills the light (F now only plays a dead-battery click), and the floor gives way **5 m short of the door** (user's call, 2026-08-15 — you see it, you never touch it). ⚠️ **It is a REAL fall (2026-08-15)**: `_ev_noclip_fall()` zeroes the player's `collision_mask`, so gravity takes them straight through the floor (measured 6.96 m in 1.2 s); input is frozen, the screen fades at −3 m and the Backrooms takes over at −9 m. It used to fade to black and wait 2 s with the player standing still, which is not a fall. No hole is cut: the corridor floor is one CSGBox3D per 45 m segment, and the blackout killed every light 10 m earlier so nobody could see one. ⚠️ **Three constants move together** — `NOCLIP_FALL_BEFORE_DOOR`, `NOCLIP_ONSET_BEFORE_END` and `RETURN_MARGIN` (14 → **18**). Re-entry from the Backrooms must land clear of BOTH trigger boxes or arriving re-fires the blackout, or the fall bounces the player straight back. `tests/check_noclip_fall.gd` asserts the relationships rather than the numbers, so any one of them can be retuned but not alone
- **Cyclic maze, no seamless portals** (design Q1): a 4-way intersection hub with three choice arms (N/E/W) built from `CSGBox3D`, triplanar `backrooms_wallpaper_albedo` walls + `backrooms_carpet_albedo` floor, recessed flickering fluorescents. The E/W arms dead-end in a `LoopBack` trigger that teleports you to an identical re-randomised hub — so it reads as an endless series of intersections without any continuous-portal seams
- **Win — three down-turns** (`_assign_round`, `_on_arm_entered`): an arrow decal on the hub columns marks exactly one arm with a DOWN arrow each round. Take it to advance the loop counter; the E/W arms loop back, and on the 3rd correct turn the win arm (N) is forced and opens into the exit utility room. The **glitch wall** there runs a screen-space vertex-jitter shader (`glitch_wall.gdshader`); walking into its `ExitTrigger` Area3D → `advance_level()` → The Void
  - ⚠️ **The counter now actually reaches (3/3)** (2026-08-17). `_on_exit_reached()` accepted at
    `_counter >= TURNS_TO_WIN - 1` and never incremented for the final walk, so the HUD printed
    (1/3) and (2/3) and then cut straight to the zone card — both playtest logs show the objective
    stuck at (2/3) at the moment `THE SPRAWL` appears. A progress meter that never completes reads
    as a bug rather than as a reward. The zone card is held back `ZONE_CARD_DELAY` = `CARD_LENGTH`
    (2.5 s, a full card) so the (3/3) gets its moment. ⚠️ Two tweens driving one
    `theme_override_colors/font_color` fight and the failure is SILENT — the loser's `.a = 0` lands
    on the winner's fade-in. So `_show_progress_text()` kills only for an **immediate** message
    (which pre-empts) and never for a **queued** card, because the thing a queued card waits for is
    exactly the message it would otherwise kill
  - ⚠️ **THE ARROW IS THE WHOLE PUZZLE AND IT WAS ILLEGIBLE** (rebuilt 2026-08-17, Issue 88).
    `arrow_decal.png` was a photograph of yellow wallpaper with a slightly darker arrow on it:
    measured from real frames, **2.2 % glyph-vs-panel contrast** while the panel carried 22 %
    against the column — every part of the sign with no information in it was ten times louder than
    the part that did. It was also RGB **with no alpha** on a `TRANSPARENCY_ALPHA` material, a
    square source stretched 1.556× onto a 0.45×0.70 quad, 0.45 m wide on a **0.28 m post** (38 % of
    it hanging in mid-air), 0.02 m clear of that post, and **emissive at 0.25**, i.e. self-lighting
    its own wallpaper background. A misread costs `WRONG_TURN_PANIC` 18 = 36 % of `PANIC_MAX`.
    Now: `backrooms_arrow_glyph.png`, a real RGBA cutout with **no background of its own** drawn by
    `tools/make_arrow_decal.py` (seeded, deterministic — an arrow is a geometric primitive and
    nothing generative should be asked for one), sized from its own aspect, **no emission at all**,
    on a post widened 0.28 → `ARROW_POST` 0.68 with `ARROW_CLEAR` 0.06. Measured contrast **89 %**.
    ⚠️ Widening the POST rather than shrinking the SIGN is the point: the sign is the thing that has
    to be readable at 15 m. `arrow_decal.png` is retired to `assets_src/textures/superseded/`
  - ⚠️ **THE HUB IS A 4-WAY INTERSECTION AGAIN, AND YOU CAN WALK THROUGH IT** (2026-08-17,
    Issue 93). The player photographed the hub: *"The scapes between columns to walk into are too
    small."* Measured with their own capsule, the only way into the E arm was a **1.01 m slot for an
    0.80 m capsule** — a 0.21 m band, which is also why `check_reachable.gd`'s 0.25 m grid had
    reported both zone-1 mirage doors unreachable and that finding had been filed as a false
    positive. Two causes, and the post was the smaller one:
    1. `_build_entry_arm()` centred the entry arm at `(lo - HALF) / 2`, i.e. the WHOLE ARM 1.5 m
       (= `HALF`) south of where its own comment said it was. Its two side walls therefore ran to
       `z = +0.15` — **1.65 m into the hub**, standing across the southern half of both the E and W
       mouths. It also produced the 3 × 1.5 m coincident floor/ceiling patch that
       the wall-overlap guard had **waived as deliberate**, and 1.35 m of sealed floor
       behind `EntryCap`. Now `span_mid = (-HALF + lo) / 2`, `span_len = (-HALF - lo) + T` — the same
       form `_build_choice_arm()` has always used, one `T/2` into the hub corner. The waiver is gone
       and `_min_allow` is 0, so any coincident pair at all now fails.
    2. the three arrow posts stood on the arm CENTRELINE, splitting whatever opening was left. Each
       now stands against the jamb **clockwise** from its arm (`jamb = Vector3(axis.z, 0, -axis.x)`:
       N→NE, E→SE, W→NW — three different corners, so no arrow can be mistaken for its neighbour's),
       buried `ARROW_BURY` 0.10 into that wall so no two faces are coplanar.
    Measured lane, widest contiguous run at the mouth plane plus a capsule diameter: **N 2.02 m ·
    E 2.04 m · W 2.38 m**, against 1.01 m before. ⚠️ **Both halves are load-bearing** — post back on
    the centreline gives 1.14 m everywhere; the old entry arm alone gives E 1.10 m and W 0.88 m.
    ⚠️ **The arrow art did not change at all** (same cutout, size, clearance, zero emission, 92.7 %
    contrast), and `check_backrooms_seam.gd` now also asserts, per arm, that the wrong-turn sensor
    spans at least the full lane and sits DEEPER into the arm than the arrow — the sign is read
    before the turn is scored, and nobody can slip past a mouth. ⚠️ Measure a lane with **rays and a
    point query, never `intersect_shape`**: a capsule centred on a CSG post comes back CLEAR
    (Issue 40)
  - ⚠️ **The scene now sets a BLACK BACKGROUND** (`_black_background()`, 2026-08-17). `backrooms.tscn`
    instances the shared `assets/elements/environment.tscn`, which is `BG_SKY` over a
    `ProceduralSkyMaterial` — so when the Sprawl turned out to have holes in it, the player
    photographed a **daylit horizon** inside the Backrooms. The Lab, House and Corridor all switched
    to black long ago for exactly this reason. ⚠️ It is a SECOND LAYER, never a substitute for
    closing the hole, and it is **not** a lighting pass: `ambient_light_color` and energy are
    untouched and only `ambient_light_source` is pinned to COLOR, dropping the 8 % sky contribution
    (0.0026 in linear ambient luminance)
- **Fail — wrong turn**: entering a non-down-arrow arm = `light_pop` + 15 panic + counter reset + teleport to the start (`_wrong_turn`). **Standing still** > 4 s raises panic (`player.enable_standstill_panic()`, +3/s) — the maze forbids rest. Plus the usual panic-bar-fills death
- **Dynamic dark zones**: one (always-wrong) arm goes black each round (`_apply_dark_arm` → lights off + `DarkZone`)
- **The Smiler** (`creature_smiler.gd`, ~50% per dark arm): a glowing `screamer_smiler.png` billboard at the dark arm's end. Its logic INVERTS the maze (design Q2): shine your flashlight on it **or** sprint → rush → `Screamer.trigger()` (fatal — the smiler image fills the screen via `LEVEL_SCREAMERS[4]`). Turn the light OFF and hold still (don't sprint) and it fades after 4 s. While engaged it calls `player.set_smiler_active(true)` to suspend the standstill + dark ticks and drives its own slow dread (+2.5/s) — freezing to survive is tense but fair
- **Footstep echo** (`player.enable_footstep_echo()`): every step replays at half-volume 0.4 s later, two paces behind you
- **Mirage doors** (`mirage_door.gd`): blood-red doors identical to the back doors; opening one swings onto blank wallpaper + 10 panic, mocking the hope of retreat
- **The rotary phone** (`rotary_phone.gd`): a 1970s phone on the carpet that rings (`rotary_ring`); answering (E) plays `phone_whisper` and opens a read-to-die trap note via `NoteUI.show_note(text, 11.0)` — hang up (close) to survive
- **The entry note** (`_spawn_intro_note()`, `ClueNote`): the first thing the level asks you to touch. ⭐ **It is a document since 2026-08-18** (`backrooms_note.png`, `tools/make_backrooms_note.py` — paper from flux, words from Pillow, `make_vesper_note.py`'s recipe in the Backrooms' register). It was an **untextured `BoxMesh`** at albedo (0.85, 0.82, 0.60) with ADD emission — a near-white self-lit card, photographed as the brightest object in its frame (capture 003, *"Again, make the note more like the backrooms atmosphere"*; the "again" is because the Corridor's entrance note was rebuilt for this the day before). ⚠️ **`NOTE_TEXT` is unchanged** — the artwork letters its opening paragraph verbatim, and carries **no invented letterhead**, because this page is signed *"— someone who is still in here"*. ⚠️ **Darker than the wallpaper is MEASURED, not a taste call**: paper **98.9/255** against the wallpaper's **171.9**, and `check_backrooms_seam.gd` asserts it against the wallpaper *file* so a re-skin cannot silently break it. Art on a `QuadMesh` sized from its own aspect, on a dark `NotePad` box that carries the sheet's edge; emission through `EMISSION_OP_MULTIPLY` at 0.45 (Issues 81 and 21)
- **THREE ZONES (Session 14).** One scene, three world-space offsets; each zone ends in a glitch
  wall that teleports you to the next. `backrooms.gd` orchestrates (`_enter_zone`, `_on_zone_mistake`)
  - **Zone 1 — THE LOBBY** (origin 0): the original hub + N/E/W arms. Three down-turns → its glitch
    wall now calls `_enter_zone(2)` instead of `advance_level()`. `WRONG_TURN_PANIC` 15 → 18
  - ⭐ **THE SEAM HAS A VOICE (2026-08-17).** The level's win verb is *walk into a blank wall*, and
    zone 1 demands it **three times before anything teaches it** — twice at the E/W loop-back caps,
    once at the utility room. The caps are the worse half: they are built from `_wall_mat`,
    identical to every other wall, and `LoopBack{E,W}` sits **0.30 m from the cap's inner face**, so
    the turn only counts once you are a foot from a plain wallpapered dead end. The playtester stood
    still for **86 seconds, 6.2 m down the CORRECT arm**, writing *"many players might get confused
    that you need to go through the wall"* — while looking at a **loop-back cap**, not at the glitch
    wall. Three channels answer it, none of them brightness and none of them panic:
    1. a **two-layer positional tell** — `seam_draw` (far cue, `unit_size 16`, `SEAM_FAR_DB` −15) for
       a bearing from the arm mouth, and `seam_rip` (near confirm, `unit_size 5`, −6) that only
       resolves in the last few metres. `tools/make_sfx_seam.py`, gains set from the files' measured
       levels (−12.7 / −20.8 dBFS RMS), both **under** `MUSIC_VOLUME_DB`;
    2. a **`Label3D` scrawl** reading `NO DOOR. / WALK INTO IT.` — quoting the Lab Observation
       whiteboard's `NO DOOR` verbatim, which is the hint the user asked twice to be made clearer.
    - ⚠️ **A THIRD CHANNEL WAS CUT ON THE VERIFICATION REPLAY (2026-08-17) — do not re-add it.**
      Twelve dark floor **drag marks** ran into each seam surface. The player judged them TWICE on
      one playthrough: *"These stripes look weird - remove them"* (utility room) and *"Yeah, remove
      the stripes. The hints on the walls are sufficient"* (an E-arm loop-back cap). `DRAG_Y`,
      `DRAG_SPEC` and `_spawn_seam_marks()` are gone; the function is now `_spawn_seam_scrawls()`.
      `check_backrooms_seam.gd` asserts the ABSENCE of any `DragMark*` node anywhere in the scene
      and asserts it measured all three scrawls, so removing them did not shrink the test.
      `GAME_MECHANICS_IDEAS.md` §5.1 carries the verdict in the user's own words
    - ⚠️ **ONE emitter pair, moved by `_assign_round()`** to whichever surface the round wants. Three
      permanent beacons would be noise rather than a bearing, and the wrong arms are unreachable
      anyway (their mouth sensor ejects you first).
    - ⚠️ **It must serve the CAPS, not only the glitch wall.** That is the specific reason this was
      chosen over the alternative below; `check_backrooms_seam.gd` asserts the cap case explicitly.
    - ⚠️ **THE TIMED GLOW WAS OFFERED AND DECLINED — do not re-pitch it.** The user's capture asked
      for *"the wall to shine one minute in"*. Measured, the glitch wall is **already the brightest
      surface in its room by 2.3×** (132.7 lum against side walls 56.9/58.9, ceiling 55.8, floor
      51.9) and a 10 % step from the decision point 15 m back. Luminance was never the missing
      channel, and a glow on the glitch wall would not have helped at all where the capture was
      actually taken.
    - ⚠️ **And it must not make zone 2 redundant.** Zone 2's whole puzzle is *find the wall by
      sound*, so zone 1's cue is deliberately **unmissable and singular** — what it teaches is the
      VERB. Zone 2 keeps its difficulty in **discrimination between four**, a different skill, and
      keeps its own two-layer `water`+`whisper` tell. Both are on **Master**, never the `"Backrooms"`
      bus, because a `SilenceZone` ducks that bus and a tell routed through it mutes itself.
    - **Zero panic.** The beacons are bare `AudioStreamPlayer3D`s with no script, no children and no
      Area3D; `check_backrooms_seam.gd` asserts that structurally
  - **Zone 2 — THE SPRAWL** (`backrooms_zone2.gd`, origin `(200,0,0)`): a 40×40 m pillar hall with a
    **4.5 m** ceiling — deliberately wrong-scale against zone 1's 3 m corridors. Four *identical*
    glitch walls, one real, randomised. Touching a
    fake = `go_solid()` and **nothing else** — ⚠️ **the 12 panic, the teleport, the `flash_scare`
    and the `light_pop` were all REMOVED on 2026-09-03 (D6): every wall here is now visibly RED and
    known to be a lie, so charging for testing one is charging for reading the level.** The one
    silent consequence is kept: a mistake still adds a Congregation figure, which costs no panic,
    makes no sound and moves nobody. `WRONG_WALL_PANIC` survives for zone 1's wrong-TURN path.
    ⭐ **ALL FOUR WALLS ARE PAINTED WRONG (2026-09-03, the user's design).** `is_real` was a PURE
    BOOL — read in exactly one place and driving nothing visual, so four walls built by one loop
    with the same size, texture, shader and tear meant the player could stand in front of the
    answer and learn nothing. Every wall now carries `GlitchWall.TINT_FAKE` (a red multiply on the
    wallpaper) until the runner has been through the real one, which then goes to `TINT_REAL`,
    i.e. `vec3(1.0)` — the level's own yellow returning, nothing added. ⚠️ It is a HUE change at
    matched luminance, because BRIGHTNESS was offered as this zone's mark and declined (the glitch
    wall is already the brightest surface in its room by 2.3×); the existing `set_agitated()` tear
    still carries the motion half. ⚠️ Recomputed from `_real_side` on every `_apply_gate()`, never
    differentially — a re-roll would otherwise leave a yellow wall that is no longer real.
    ⚠️ **AND A RED WALL IS NOW INERT**: `WRONG_WALL_PANIC` 12 and the teleport back to the spawn
    are gone (D6). Twelve panic was a fair price for a 1-in-4 guess and is not a fair price for the
    player checking that a wall painted WRONG is in fact wrong. The wall still goes solid, and
    `populate_one_more()` still adds a silent Congregation figure — no panic, no sound, no
    teleport. ⚠️ **Zone 3's penalty is untouched**; the Flood's decoys are a real discrimination
    test rather than a painted warning.
    ⭐ **AND THE ZONE IS DARKER**: `_enter_zone(2)` tweens ambient 0.2 → `SPRAWL_AMBIENT` 0.07 and
    `_enter_zone(3)` puts it back. ⚠️ 0.07, not the 0.02 the three darkened levels took — the
    user's brief here was "darker than usual, BUT NOT complete darkness", and this zone's puzzle is
    finding a crate by ear in a 40×40 m hall that has to keep a shape. `DEAD_LIGHT_CHANCE`
    0.3 → 0.55 and the strips 1.0 → `STRIP_ENERGY` 0.6. ⚠️ **The strips also FLICKER now** — they
    were appended to a `_lights` array that was never read again, so the Sprawl's 25-strip grid was
    dead-steady for its whole life while the Lobby next door flickered.
    ⭐⭐⭐ **THE REAL WALL IS THE END OF THE CRATE'S OWN RECESS (2026-09-10, captures #10/#11:
    *"it runs very far away through one of the yellow blocks, I cannot see it well"*).** All eight
    recesses are **`ALCOVE_D` 10 m deep** now; the four red perimeter walls are DECOYS FOREVER
    (`is_real = false`, keyed N/E/S/W); the fifth `GlitchWall` — the only real one — stands at the
    END of the recess the crate is in (`_real_side` = `"%s%d" % [side, k]`, e.g. `"S1"`,
    `exit_wall()` / `exit_axis()`), where the seven other recesses have an `AlcBack`. The crate
    stands `CRATE_IN` 2 m inside the mouth, the runner spawns `DWELLER_OUT` 1 m BEHIND it, and the
    run is ~7 m straight away from the player at `SPEED` 4 m/s: **1.74 s in frustum measured**
    (`screenshot_sprawl_run.gd`, FAIL under 1.6). ⚠️ **NO RE-ROLL**: `_randomise_real_wall()`,
    `_move_voice_to()` and `_voice` are deleted; a fake touch goes solid and adds a figure, the
    mark never moves. The `SilencePocket` and the `water`/`whisper` tells sit in the deep half of
    the crate's recess. Each non-crate recess gets a dim flickering strip (`RECESS_STRIP_*`);
    `FAR_DB` 6 → 7.5 for the deeper far corners. Nine glitch walls scene-wide
    (`check_shell_sealed.EXPECTED_GLITCH`). The paragraphs below that say "four identical walls,
    one real, randomised", "the mark follows a re-roll" and "runs across the hall" are the OLD
    zone. Guards: `check_sprawl_crate` (runner in view ≥ 1.6 s, crate 1.5–3 m in, exit keyed by
    recess, perimeter never real, `_mark_stays_put`), `check_sprawl_alcoves`, `check_sprawl_walls`
    (5 walls, 5 red → 4 red, the yellow one > HALF+1 from centre), `walk_backrooms`.
    ⭐⭐ **THE BOX IN THE DARK IS THE GATE** (`sprawl_crate.gd` + `sprawl_dweller.gd`, the user's own
    design, backlog 04 §16.4 and §18.3). A two-layer whisper (`sprawl_call_far`/`_near`, on
    **Master**) leads to a slatted crate standing in ONE recess chosen per run; E on it fires a
    survivable `flash_scare` and the thing that was inside **runs across the hall and out through
    the real wall** — and the real wall does not work until it does.
    ⚠️⚠️ **THIS FILE SAID THE OPPOSITE UNTIL 2026-08-18** — that the crate was a redundant second
    route and "must never become the only one" — and the user overturned it, having been told the
    fallback existed: *"it should run and go through the real wall which would not be active until
    it runs through."* Asked for twice, explicitly. The real wall is now **`GlitchWall.set_sealed()`**
    until the runner arrives: it looks exactly like its three neighbours and walking into it does
    **nothing**. ⚠️ Sealed is a COLLIDER, not a hidden node — `_side_runs()` cuts a 7 m gap in the
    perimeter for each wall, so in this zone the wall IS the shell and hiding it is a hole in the
    world. ⚠️ **The gate follows a re-roll** (`_apply_gate()` recomputes all four from `_real_side`;
    `revive()` rebuilds triggers from scratch, which is where a seal would silently drop), and it
    does **not** come back once the runner has been through.
    ⚠️⚠️ **WHICH MAKES THE WHISPER A COMPLETABILITY GUARANTEE**, and it was **inaudible everywhere**
    until this pass — Issue 131: the gains were set from the files' RMS and never against the bed
    they play over (the score is −22.0 dBFS effective; the far cue reached **−25.2 dBFS at the box**).
    Now +9.8 dB of margin at the crate and **+3.6 dB at the worst standable point in the zone**,
    measured on a 1593-point grid, and the loop has **no timer, no one-shot and no stop path** — the
    Flood's knock rule in a second place. ⚠️ The far cue carries the hall nearly **flat** and gives
    its bearing by PANNING; the near confirm owns the gradient. One emitter cannot do both across
    45 m and the arithmetic says so (Issue 112's other half).
    ⭐ **The camera is pinned to the run** (`backrooms.gd:_tick_crate_watch`, the user's *"Force my
    camera to see that action"*). `player.turn_to_face()`, `level_1.gd`'s nook reveal as the
    precedent. ⚠️ The run is **deferred by one `flash_scare` hold** — a run started on the press is
    watched through a fullscreen image — and the aim is **re-targeted every 0.18 s** because the
    thing moves, then held 1.1 s past the arrival aimed at the wall. `WATCH_MAX` 12 s is a safety
    valve, not a difficulty number.
    `check_sprawl_crate.gd` drives the whole thing cold — spawn → whisper → box → run → wall → out —
    through the real interact ray and the real `Area3D`, and asserts the gate in **both** directions.
    ⚠️ The runner is a **dedicated one-shot
    object, never a Congregation `Watcher`**: those are ruleless by construction and that is why the
    Congregation is legal beside a Smiler that kills you for looking. ⚠️ The mark is **motion**
    (`GlitchWall.set_agitated()`, tear 0.12 → 0.34), not brightness — the glitch wall is already the
    brightest surface in its room by 2.3× — and it **follows a re-roll**, because a mark left on a
    wall that is no longer real is worse than no mark. ⚠️ The crate's recess has its ceiling light
    **cut** (`_build_lights()` skips every strip within 11 m), so "hidden in the dark" is measured.
    ⚠️ **Zero panic**: the scare is `flash_scare` + a camera jolt and nothing else; whether it should
    cost anything is an open question (backlog 04 §16.5 / D31), not an omission. It IS **+14.6 dB
    louder** since 2026-08-18 (`crate_shriek.wav` −20.0 → **−5.4 dBFS RMS**, peak unchanged at −1.01,
    zero samples at full scale) — the user asked for it, and `flash_scare()` takes no gain, so the
    only lever was the file's average level.
    ⚠️ **The objective line is `None of these walls are real. Something in here is.`** (2026-09-03),
    then `It went through that one. Follow it.` once the dweller has run. Before that it read
    `Four walls tear. Something in here knows which one`, and before that it said
    *"Only one is thin — listen for it"*, which described the pre-gate zone: listening to the wall's
    own tell no longer opens anything, so the line named a verb that does not work.
    **The `SilenceZone` and the wall's own cue are FLAVOUR AND CONFIRMATION now, not the route**
    (2026-08-18). A `SilenceZone` around the real wall still ducks the whole `"Backrooms"` bus to
    −30 dB, and `_randomise_real_wall()` still spawns a positive cue AT that wall, deliberately kept
    off that bus so the pocket cannot duck the very tell it provides (**BUG_FIX.md 3.5**, added when
    playtest read pure silence as too subtle). ⚠️ Measured while making the crate the gate: outside
    the pocket that cue sits ~14 dB **under** the score, and inside it the bus ducks 30 dB and it
    emerges — so it has always worked by CONTRAST WITHIN THE POCKET rather than as a bearing across
    the hall, which is exactly the job it now has. **Do not delete it**: without it the real wall is
    silent until the runner arrives, and the run is the only cue there is.
    ⚠️ **That cue is `water` (`unit_size 16`) + `whisper` (`unit_size 9`), NOT `sprawl_wall_hum`.**
    This file described the hum as the tell for several sessions; the hum was a first pass at
    `unit_size 4.5`, audible only once you were already at the correct wall in a 40×40 m room with
    four identical ones, and it was replaced by the two-layer far-cue/near-confirm pattern
    (`backrooms_zone2.gd:187-225`). **`sprawl_wall_hum.wav` is still generated by
    `tools/make_sfx_backrooms.py:97` and is referenced by no `.gd` file at all** — it is an orphan.
    Do not "restore" it without re-reading that comment; the wide range is the whole point
    - ⚠️ **THE EIGHT ALCOVES WERE SEALED FOR THE WHOLE LIFE OF THE ZONE, AND ARE NOW OPEN**
      (2026-08-17, `backlogs/04-backrooms.md` §9, ISSUES_SOLUTIONS **Issue 90**).
      `_build_alcoves()` builds each recess as a floor, a back wall and two side walls OUTSIDE the
      perimeter, and nothing ever removed the perimeter in front of it — a ray from 3 m inside the
      hall was blocked at exactly the 3.00 m mouth plane on **all eight**. Behind that wall sat
      `SprawlNote` (the only readable object in 1600 m², and the page that states the zone's own
      tell), the off-hook `SprawlPhone`, the `LivingMirror`, two `MirageDoor`s and five props —
      every authored object in the zone except the pillars, the lights and the four glitch walls.
      `_side_runs()` now derives each side's solid runs by subtracting the openings (the 7 m
      glitch-wall gap + one 4.0 m **mouth** per alcove) from its full extent: **four segments per
      side, not two.** ⚠️ A mouth is `ALCOVE_W` **plus a wall thickness at each end**, so the
      perimeter stops at the OUTER face of the alcove's own side walls and the two boxes ABUT —
      cutting to the interior width instead leaves two end caps coplanar and both facing into the
      mouth. ⚠️ `ALCOVE_AT` replaced the literal `11.0` that had been repeated in four places, and
      `_side_runs()` reads it, so the mouths cannot drift away from the recesses. Measured:
      **+3 241 standing cells (+50.6 m²)**, interactables reachable **8/12 → 12/12**, route to the
      four glitch walls unchanged. Locked down by `tests/check_sprawl_alcoves.gd`, which re-seals
      one mouth every run to prove it can fail
    - ⚠️⚠️ **AND THEN FOUR OF THEM TURNED OUT TO BE OPEN AT THE BACK** (2026-08-17, verification
      replay, ISSUES_SOLUTIONS **Issue 92**). `_build_alcoves()` built the BACK wall of every E/W
      (`is_x`) recess with the SIDE wall's ternary — `(ALCOVE_D, h, T)`, a 3 m blade lying ALONG the
      depth axis and half sticking out of the building, where `(T, h, ALCOVE_W)` across it belonged.
      All four E/W recesses were **3.40 m wide × 4.50 m tall of open world**, and with `BG_SKY` still
      set the player photographed a daylit horizon from inside the Sprawl. The blade also stood
      across the walking line to that alcove's own `MirageDoor`, which is the red object in the
      capture. N and S were correct, which is why it read as a working feature.
      ⚠️ **It survived `check_sprawl_alcoves.gd`, written the same day for this exact zone**: its
      "shell closed" probe fires ONE ray outward from each recess's CENTRE, and the blade sits
      exactly on that line — the ray hit it at 0.15 m and reported the wall present. **One ray is a
      test of a point, not of a surface.** `tests/check_shell_sealed.gd` is the guard now: a 0.25 m
      lateral perimeter sweep at six heights, an outward-hemisphere fan from five points in each of
      the eight recesses, and a 1.5 m interior floor grid across **all three zones** — ~66 000 rays,
      with two permanent controls that punch this hole back open and require both sweeps to go red.
      A `GlitchWall` is a hole on purpose, so a ray that hits nothing is forgiven only if it crosses
      one; that exemption list is counted (exactly 8) like `check_wall_overlap.gd`'s `_allow`
    - ⚠️ **`SprawlDread` is `SIZE + 2 × (ALCOVE_D + T)` square, not `SIZE`** — widened with the cut
      so the eight recesses stay inside the no-decay zone. Outside a `DreadZone` decay runs at the
      full 3.5/s, so leaving it at the hall's own footprint would have handed the zone eight
      recovery pockets in a design that has exactly one anchor. This preserves the sealed build's
      pressure profile exactly; it is a decision, not a detail
    - ⚠️ **Three panic sources went live with the cut and none of them was tuned**: two
      `MirageDoor`s at `PANIC = 10` each (voluntary, one-shot) and `SprawlMirror`'s
      `GAZE_INTENSITY = 0.7` (**14 panic/s** while stared at, in a zone where decay is cancelled).
      `SprawlPhone` is zero — `open_note = false` and `rings = false`, asserted. The zone's
      `WRONG_WALL_PANIC` 12 was measured with all of this unreachable; treat the next playtest as
      the first real reading
    - ⚠️⚠️ **THE EIGHT ALCOVES ARE SEALED, AND EVERYTHING IN THEM IS UNREACHABLE** (measured
      2026-08-17, NOT fixed — it needs a decision). `_build_alcoves()` builds each recess as a
      floor, a back wall and two side walls OUTSIDE the perimeter, and nothing ever removes the
      run of perimeter wall in front of it: `_build_shell()`'s two runs span 3.5…20 and −20…−3.5
      and the alcoves are at **±11**. A ray from 3 m inside the hall is blocked at exactly the
      3.00 m mouth plane on all eight. Behind that wall: `SprawlNote` (the only readable object
      in 1600 m², and the page that states this zone's own tell), `SprawlPhone`, the
      `LivingMirror`, two `MirageDoor`s and five props. ⚠️ **This re-reads the playtest finding
      "SprawlNote was not read in either session"** — that was never a placement problem.
      Opening them adds ~10 reachable objects and eight rooms to a zone tuned without them, and a
      mis-cut hole in this shell is why `_catch_out_of_world()` exists. See
      `backlogs/04-backrooms.md` F1 and the ⚠️ block at `_build_alcoves()`
    - **THE CONGREGATION** (`congregation.gd`): 6–8 persistent `Watcher`s among the 36 pillars,
      growing by one per wrong wall (capped at 12). Zero panic, no collider, no kill radius, no
      fail state — unchanged, and it is what keeps the feature legal under `SCARY.md` §8.3.
      ⚠️ **Two defects fixed 2026-08-17, both of them the reason it read as inert** (Issue 85):
      - **The destination was never gated.** `CLAUDE.md` states the contract — *"a figure relocates
        only when it is BOTH out of view and ≥15 m away, so it never moves on screen"* — and only
        the SOURCE half was implemented. Measured over 90 s: **633 relocations, 20 m each, 65 of
        them landing in the player's view cone with line of sight** (10.3 %). `_pick_spot()` now
        takes `min_from_player` + `unseen_only`, and `would_be_seen()` re-implements
        `Watcher._is_seen()` for a candidate point.
      - **They never held still.** `SETTLE_MIN`/`SETTLE_MAX` (8–16 s, randomised per figure). A
        figure that has teleported five times since you last looked cannot support "there was one
        by that pillar", which is the entire product.
      - **And they were LIGHTER than the floor.** `watcher.gd`'s premise is "a dark shape OCCLUDING
        a lit surface"; measured here the figure was 43.7 lum at 2 m and 42.4 at 25 m (unshaded, so
        no falloff) against a floor at 29.5–36.3 and a ceiling at 28.8. `Congregation.FIGURE_TINT`
        (0.42, 0.42, 0.48) via `watcher.gd`'s new additive `figure_tint` → **18.5 rendered**
        - ⚠️⚠️ **HALVED TO (0.21, 0.21, 0.24) ON 2026-09-03 — A MODEST GAIN, AND THE FIRST
          MEASUREMENT BEHIND IT WAS RETRACTED.** An unshaded tint is a FIXED rendered luminance;
          the premise above is a claim about a **ratio**, and the darkness pass cut everything on
          the other side of it (ambient 0.2 → 0.07, `STRIP_ENERGY` 1.0 → 0.6, `DEAD_LIGHT_CHANCE`
          0.3 → 0.55) while the figure stood still. Measured by `probe_congregation_tint.gd`
          (figure vs what is DIRECTLY behind it, ONE figure isolated, two runs × three distances):
          at 2.5 / 4 / 8 m the old 0.42 gave **0.44·0.61 / 0.84·0.85 / 0.92·0.93** and 0.21 gives
          **0.32·0.51 / 0.71·0.82 / 0.83·1.02** — better where a figure is noticed, a wash at 8 m.
          ⚠️ **The claim that it went 0.90 → 0.45 and was "effectively gone" is WITHDRAWN**: that
          mask was built by hiding all six figures at once and averaged six silhouettes at six
          depths over 60 % of the frame. Issue 164. ⚠️ The ratio does **not** halve when the albedo
          does (alpha-blended cutout edges), so do not predict this constant arithmetically.
          ⚠️ **The residual is structural**: past ~8 m the background darkens to the figure's fixed
          luminance and the ratio reaches parity. Only a SHADED figure fixes that, and `watcher.gd`
          is deliberately unshaded — cross-level **X67**. ⚠️ Measure against what is directly behind
          the figure, never against the floor; the two disagree by 7× here
      - ⚠️ The **chorus** (a shared vocal bed scaling with how many are behind you) and **heads
        turning** were both offered this pass and **declined** — see `GAME_MECHANICS_IDEAS.md` §5
  - **Zone 3 — THE FLOOD** (`backrooms_zone3.gd`, origin `(-200,0,0)`): an 8-room flooded wing built
    with `RoomBuilder`, ankle-deep water (`apply_slow` refreshed per frame), near-black.
    ⚠️ **THE ROOMS ABUT; THEY USED TO OVERLAP** (fixed 2026-08-17, Issue 86). `Sump` and `Cistern`
    each overlapped `Basin` by 1×2 m, which — because `RoomBuilder` builds each room's walls on its
    own boundary — left **2 m wall stubs standing inside the Basin at x −5.10 and +4.90 and inside
    the Sump at x −6.10**, boxed both of the Basin's north corners into 1×2 m dead pockets, and
    coincided four floor/ceiling slab pairs. The Basin is the zone's largest room and holds the
    `DryPlatform` `CalmZone`, its only recovery anchor. Fixed by moving both chambers 1 m outward
    (`Sump (-9,21)→(-10,21)`, `Cistern (9,21)→(10,21)`) **with their doorways** (`(∓9,17)→(∓10,17)`
    — move a room, move its doors). Regression-locked by `check_wall_overlap.gd`, which sweeps this scene at 5x5 quad sampling.
    ⚠️ **The water is a BED, never a per-step sound** (2026-08-15, user's call, twice). The zone
    used to swap the player's footstep sample for `wade_step` — a synthesized splash+thud at
    0 dB, at the ear, on the un-duckable `Body` bus, every 0.5 s — against a `water.wav` bed
    measuring **−39.6 dBFS RMS** that at its shipped −6 dB was inaudible. The zone announced
    wading twice a second and never sounded wet. Now: no footstep swap anywhere, and eight
    `WaterBed_*` loops (one per room, `WATER_BED_DB` **+14**, `max_db` 3.0, staggered start
    offsets so eight copies of one loop don't comb-filter). ⚠️ **Set a bed's gain from the
    FILE's measured level** — `water.wav` sits ~20 dB below every other asset here, so a
    volume_db that reads as sensible means nothing. `tests/check_backrooms_audio.gd` measures
    the source WAV and asserts the result clears an absolute floor
    - ⚠️ It also cost P10's stated anchor (*"what you hear in the distance has to be audibly
      the same ACT you are performing"*). `UnseenWader` is unchanged and still reads, because
      the water it wades through is now the thing you can actually hear
    - **The tell is DARKNESS, and since 2026-08-17 the exit must first be EARNED**: six fragments
      out of the six drowned objects, set into the plate table in the Basin, and only then does the
      Sump seam exist at all (`flood_plate.gd`, the user's own design, backlog 04 §16.2). Until the
      plate is whole the seam is `set_armed(false)` — hidden **and not monitoring**, so wandering
      into the Sump early cannot clear the zone. Once armed the rule is unchanged: the real seam is
      visible only with the flashlight OFF, two decoys glow only with it ON. Clearing it →
      `advance_level()` → KONTUR.
      ⚠️⚠️ **THE SAFETY NET IS WHAT MAKES A MANDATORY SEARCH LEGAL**: an object with its fragment
      still in it **knocks every 5–11 s for ever**, so `sunken_item.gd:_process` is gated on
      `is_taken`, **never** on `is_searched` — hauling a lid and walking away must not silence the
      one object you still need. `check_flood_puzzle.gd` asserts it with a control.
      ⚠️ **The plate announces itself on three channels** — it stands 4.1 m from the wing's only
      lamp, it carries `SIX PIECES. / SET THEM HERE.` in dark lettering on a pale board (never a
      bright `Label3D`: unshaded means self-lit, §5.2(8)), and it runs a two-layer tell
      (`plate_hum`/`plate_ring`, **Master**) armed by the FIRST fragment rather than on entry.
      Measured over the water bed in all eight rooms (+8.3 dB worst), under the `flood_knock` at
      the table, and falling 7.6 dB across the wing. ⚠️ That gradient comes from `unit_size`, not
      `volume_db`: Godot clamps `volume_db + attenuation` to `max_db`, and the first build was flat
      to 0.4 dB (**Issue 112**).
      ⚠️ **The objective is one function** (`objective_text()`), it names a RULE and never the room,
      and since 2026-08-18 it names **no task either**: `Something in this wing is unfinished` until
      the plate is whole, then the unchanged `The way out does not show itself in the light`. It
      used to read `Six pieces are sunk in this wing (n/6)` — quantity, verb and score, before the
      player had found anything (playtest capture 005: *"The message should not be that obvious…
      do not write that hint"*).
      ⚠️⚠️ **REMOVING THE COUNTER IS SAFE BECAUSE THE KNOCKS ARE THE COUNTER** — an object still
      knocking is a piece outstanding, and that channel is permanent, positional and asserted, which
      the HUD number never was. Do not "restore" the counter believing the progress feedback was
      lost with it. The consequence is that the plate's three announcement channels (the only lit
      room · `SIX PIECES. / SET THEM HERE.` on its own board · the two-layer tell) now carry all of
      the discoverability weight, so they were re-measured rather than assumed.
      ⚠️ **`save_progress()` carries `flood_set` and `flood_held` as well as the emptied objects** —
      restoring one without the others manufactures an unwinnable wing through a back door.
      ⚠️ **There is NO `DarkZone` here, and this line used to say there was** (corrected
      2026-08-17, Issue 96 — the false version cost an analysis pass its framing). One was removed
      deliberately: a room solved by turning the light off must not also charge +3/s for the light
      being off, which through `player.gd`'s if/elif chain *also* suppresses decay — measured at
      +5/s with no way down, and three playtest deaths inside 10 s without the mechanic ever being
      attempted. Issue 18. The only pressure here is the floor-wide `DreadZone` (decay and pressure
      cancel exactly) plus the zone's own `DREAD_DRIP` **0.3/s while wading**, and the Basin's
      `DryPlatform` `CalmZone` nets about **−2.7/s** standing in it. `check_flood_drowned.gd`
      asserts the absence, because a deliberate omission with no test gets re-added by the next
      person who reads a doc
    - ⭐⭐ **THE ALTAR IS A RUSTED STEEL AUTOPSY TABLE WITH A STAINED SHEET (2026-09-14, F1, the
      user's pick).** `flood_plate.gd:_build_table()`: base plate, central pedestal, drain pipe, a
      rimmed steel top (`flood_steel_rust.png`, triplanar) with a gutter and a drain clear of the
      sheet, a linen sheet box with `flood_sheet.png` on a `QuadMesh` (1024×561 = the 1.35×0.74 m
      quad, `check_art_aspect` 1.001×) and a near-edge drape. **The owner's line is CHALKED ON THE
      SHEET** by `tools/make_flood_altar_art.py` (Chalkduster, the art rotated 180° because a flat
      quad's image top lands at world −Z) — the backboard and its `Label3D` are GONE, and
      `check_flood_puzzle` asserts the generator letters `SCRAWL` verbatim instead. The six outlines
      are pale 3D chalk on the sheet (still `Outline%d`, so they cannot drift from the slots).
    - ⭐⭐ **THE SIX PIECES ARE OBJECTS NOW, AND THE PLATE IS AN ALTAR (2026-09-10, capture #12:
      *"same pattern - like candle, old book, a skull"*, the user's choice: only the pieces, the
      containers stay).** `ritual_piece.gd` (`RitualPiece.build(kind)`) builds **candle · old book
      · skull · bell · iron key · doll** from parts with flux textures graded by
      `tools/grade_ritual_textures.py` (triplanar, per-kind scale; the book's cover art on a quad
      cropped to its aspect; the skull a MESH — cranium, jaw, sockets, nasal wedge — because the
      altar is seen from above). `DROWNED` gained a `piece` column (footlocker→candle,
      gurney→book, drawers→skull, suitcase→bell, toolchest→key, wheelchair→doll);
      `SunkenPiece` builds the piece where the shard's underside was. `flood_plate.gd` draws a
      pale **outline** per slot (rings for candle/skull/bell, bar frames for book/key/doll —
      `RitualPiece.OUTLINE`) with the SAME builder's copy hidden in it; `SLOT_KINDS` fixes the
      order and `seat_kinds()` fills a kind's OWN slot, so the altar shows which piece is missing.
      The zone holds `_held_kinds` (an array; `pieces_held()` still returns the count),
      `save_progress()` writes `flood_set`/`flood_held` as KIND ARRAYS and `restore_searched()`
      accepts the old ints (resolved against the restored objects' pieces in wing order). ⚠️ No
      emission anywhere, no collider on the piece itself, no rules — `check_flood_drowned.gd`
      asserts six distinct kinds, parts + textures, the six outlines and hidden copies, and still
      "nothing down here is self-lit"; `check_flood_puzzle.gd` asserts the six set are six kinds,
      a kind-array restore fills the named slot, and setting the candle fills the CANDLE slot.
      `screenshot_flood_pieces.gd` (⚠️ pose one frame, shoot the next — a pose set in the frame of
      the capture is not what the capture shows).
    - ⭐ **THE DROWNED (2026-08-17)** — the zone's searchable content, added after J-capture #5
      (*"the flood sublevel even though looks very cool feels very empty"*). **Six half-submerged
      objects** (`sunken_item.gd`), one per room, each a different silhouette built from parts —
      footlocker · ward gurney under a sheet · drawer bank · suitcase · tool chest · wheelchair.
      Each **knocks** while its fragment is still outstanding (`flood_knock`, `unit_size 6`, every
      5–11 s) and is **silent forever** once emptied: a to-do list you clear by ear, so the wing
      gets audibly emptier as you work it. ⚠️ **TWO PRESSES since 2026-08-17** (playtest capture
      005: *"Why the note appears just after I open the cabinet - I need to collect this note"*).
      E hauls it open (`flood_haul`) and reveals a **fragment lying in it** — no page, no journal
      entry, nothing else; a second, separate E lifts the fragment, and the page arrives then.
      `lab_cabinet_drawer.gd`'s beat. ⚠️ Which of the two nested bodies answers the ray is decided
      by STATE, never by aim — and because this body is on layer 1 (it is furniture) it cannot be
      made transparent to the ray, so while a fragment is present **both** targets take it. ⚠️ **Found by EAR, not by light** — a glinting object would
      argue with the zone's own tell, and a self-lit one is anti-pattern §5.2(8). ⚠️ **ZERO panic,
      no fail state, no new rule**; measured, a full six-object search costs **+11 of `PANIC_MAX`
      at worst** (36.7 s of wading × 0.3) against 37.5 points of headroom, and reading is free
      because `NoteUI` pauses the tree. ⚠️ **Nothing in the Sump** (it holds the real seam — a
      knock there would be a bearing to the exit) and **nothing in the Cistern** (it holds the
      beartrap — anti-pattern §5.2(11)); both asserted. The **Basin** object stands 2.7 m from the
      Basin decoy seam on purpose: lighting the room to look at what you hauled out shows you the
      decoy coming on and the real seam going out, in the same second, with nothing said
    - **Three events on the FRAGMENT count** (they keyed on the lid until 2026-08-17; an object
      standing open with its fragment still in it is not done), all channels rather than numbers:
      **1/6** every
      remaining object answers with one knock (the invitation — otherwise a player who searches the
      first thing they trip over never learns there is a set); **3/6** THE SURFACING — `flood_haul`
      once, 5–13 m away, *the same sound the player has just made three times*, which is `SCARY.md`
      P10's stated anchor and the only place in the game where the player performs an act
      distinctive enough to be echoed (no entity, no mesh, no repeat, and **not** the `UnseenWader`,
      which is untouched); **6/6** the wing is emptied — drips halve permanently, all eight water
      beds settle −3 dB for good, and one last knock lands ~3.5 m behind you from a wing with
      nothing left in it to knock. Emptied objects are recorded in `save_progress()`, so a
      back-door return does not re-fill the wing with knocking
    - Two non-teach HOLD apparitions (`Apparition.spawn`, `Rule.HOLD`, `teach=false`): one in the Throat,
    and (**BUG_FIX.md 4.4**) a second, identical in setup, in the Sump — the deepest, most remote room,
    which also holds the real seam — added after playtest read the zone as "nice vibe, not packed
    enough with action" despite the Throat encounter
  - Each new zone has exactly **one `CalmZone`** anchor (lit island / dry platform) — three
    net-positive-panic zones back to back is otherwise unsurvivable
- **Audio mix (Session 14)**: music −14 → **−4 dB**, hum −8 → **−12 dB** (the score now LEADS by
  8 dB); both routed through a runtime `"Backrooms"` bus so `SilenceZone` can duck them together;
  loop flags enabled in the `.import` files; `rotary_phone`/`mirage_door` emitters given explicit
  `volume_db` (they were an unset 0 dB, louder than everything else)
- Win: three zones, three glitch walls. Fail: wrong turns/wrong walls/standing still/the Smiler/a
  read-to-end phone call → panic bar fills


## DECISIONS & GOTCHAS

Dated change entries, newest first — why the level is the way it is, what was measured, what was
tried and rejected. ⚠️ Anything marked **DELIBERATE** or **the user's call** must not be
re-litigated without asking.

⚠️ `⚠️` gotchas that describe *current* behaviour stay inline in **SPEC** above: in this codebase
the rule and its reason are usually one sentence, and splitting them would break the sentence.

- ⭐ **2026-09-16 (`BACKLOG_Sep_16.md` R3–R6, R10):** you **arrive with the torch OFF** (F works;
  the Smiler killed the user 9 s in with the default-on torch); the correct arm's scrawl is
  **per round** (`ROUND_SCRAWLS`: NO DOOR / IT IS NOT A COINCIDENCE / YOU ARE HERE FOR A REASON);
  the Flood's calm island is a **raised tiled swimming pool with dark blue water** (deck
  `DryPlatform`, curbs, a ramp from the Descent side, a chrome ladder, a cold lamp) and setting
  the sixth relic makes **the relics wake** (`_relics_wake`: candle, bell, doll, lamp gutter, a
  groan from the Sump; zero panic). Seam transitions are deferred (Issue 216).
- ⭐ **2026-09-13 (B1/F1):** the crate sting plays **as the lunge starts** (`_start_the_lunge`), not
  on `lunged`; the Flood board reads **SIX RELICS OF THE WARD. / RETURN THEM TO ME.** and the
  pre-completion objective is *Someone down here kept relics of the ward.*
- ⭐ **2026-09-14 (`BACKLOG_Sep_14.md` B1–B2):** the entry note is **the verb only** ("There is no
  door. Walk into the wall."); the arrow and Smiler rules arrive as `RoundNote` in the hub from
  round 2, and the CORRECT arm's seam scrawl reads `NO DOOR. / WALK INTO IT.` each `_assign_round`.
  The crate's `crate_jumpscare.ogg` had 0.786 s of leading silence — trimmed by
  `tools/make_crate_jumpscare.py` (ffmpeg `atrim` from the raw in `assets_src/`).
- ⭐ **2026-09-13 (`BACKLOG_Sep_13.md` B1–B4):** the mirage doors are **old-house yellowed
  panel doors** (`backrooms_door_yellow.png`, 6 in the Lobby, 4 in the Sprawl; the red stays on
  the real back door); the cap scrawl reads **EASY TO GET IN. / IMPOSSIBLE TO GET OUT.** and
  comes down after the first loop-back, the glitch wall reads **YOU ARE HERE FOR A REASON.**;
  the Sprawl's crate is a **gift box** and the dweller **lunges to arm's length with the
  user's `crate_jumpscare.ogg`** before its run — **no fullscreen flash**; **SHOULD I FOLLOW
  IT?** scrawls when it goes through the wall.
