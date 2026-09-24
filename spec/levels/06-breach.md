# Level 6 — The Breach — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

### Shipped — 2026-09-24 pass 5: contained XOR killed, no frozen creature before a teleport, the technician's scream

**Why.** The user's fifth hand playtest (2026-09-24, session 01:23): four J-captures, 5 deaths, then a
real seal and the exit. Verbatim:
- *"Take the wheel button is not active at first. Let's make it active straight away"*
- *"after we press an E something like a scream of this man should appear, followed by this 'Don't go
  in there'"*. The user supplied `man_scream.wav`: 2.27 s, mono, −4 LUFS.
- *"it was told that the object contained get out but at the same time I was killed and the level was
  not finished … It is either contained and you can get out or you get killed"*.
  - The log: `KILL BLACK / FATAL FUNNEL` at 314.58, then `SEALED … LEAVE` at 316.93, then a restart.
  - The purge's timers kept running after the kill had claimed the death.
- *"now it is just standing in one place not moving"*. The user then clarified: *"Change nothing about
  this, the only thing I wanted is to avoid the situation when the object is not moving at all before
  teleporting."*

**Difficulty is kept as it is** (the user's call). The 5 deaths, 4 of them inside ExitVault at chase
5.5 with the seal race on, are the intended challenge. `BREACH_CHASE_SPEED` 5.5 and `SEAL_RACE` stay.

**What changes:**
1. **Contained XOR killed: the first outcome wins.**
   - When the kill sequence reserves the fatal transition, any purge in progress aborts: a race close,
     a pending confirm, the purge sequence. No `creature_trapped` and no "SEALED" objective.
   - `_on_creature_trapped` ignores a trap arriving during a kill.
   - The moment the door seals with Object 12 inside, it is purge-frozen, so contact can never fire
     after "contained".
2. **Never motionless before a teleport.** Nothing else about the AI changes.
   - While the Breach creature searches (a hidden player's roam, or the post-hide loss before
     `_relocate_near_player()`), arriving at a search point no longer stands and rotates for
     `SEARCH_TIME`. It keeps walking to another nearby reachable point until the existing relocation
     timer teleports it.
   - `SEARCH_TIME`, `HIDDEN_RELOCATE_INTERVAL`, detection and relocation are unchanged.
   - It is gated on the Breach's flags, so the Nightmare's Matron keeps today's search.
3. **The technician: prompt at once, then the scream, then the whisper.**
   - "E — take the wheel" works as soon as the player reaches him. If the victim scene is still
     playing, it ducks under his beat.
   - On E: the grip, then his eyes open with **the user's scream** (`approach_technician_scream.wav`,
     prepared from `man_scream.wav` with its gain set from the measured mix), then *"don't… go in
     there…"*, then his eyes close.
   - The music ducks under the scream as under the whisper.
4. **Pass 4's leftovers:** the tests for the face on the first cycle and for the relief depth, and the
   spec write-up for the shutter reversal and the 3D relief.

**Proof:**
- Regression tests force contact during a race close, and a seal completing as it lunges. Each ends in
  exactly one outcome.
- A motion test finds no ≥ 1.5 s zero-displacement window before any teleport, and confirms the
  Matron's search is unchanged.
- The technician's prompt is live on arrival, and the scream is followed by the whisper, measured on
  the mix.
- Plus the full suite.

**As built** (level-improver, 2026-09-24):
1. **Contained XOR killed** (`purge_chamber.gd`, `level_6_breach.gd`).
   - The level's `_death_claimed()`: its kill sequence is live, or ANY death transition is current (a
     panic death goes through Screamer and takes the same transition). The purge chamber gets it as
     `death_check`, and the level calls `_purge_chamber.abort_for_death()` the instant
     `_on_contact_death()` takes the fatal transition.
   - Aborting stops a held race close (the leaf stays where it is), and every timer callback
     (`_confirm_trap`, `_run_purge_sequence`, `_finish_purge`) carries the generation it was scheduled
     in, so a stale one does nothing. `interact()` refuses after an abort. `_on_creature_trapped()`
     ignores a trap under a claimed death. No "SEALED", no `creature_defeated`.
   - The reverse holds by construction: the race's shut `freeze_for_purge()`s Object 12 in the same
     frame, and the chamber checks for a claimed death at the top of every frame before it can shut,
     so within a frame the first outcome wins.
   - Measured (`check_breach_contained_xor_killed`, the real E ray and the real chase, the player 2.2 m
     inside the vault): **contact during the close** — killed at 0.97 s, the close never shut, no
     SEALED; **the seal as it lunges** — shut at 1.27 s with Object 12 1.53 m from the player, SEALED
     and contained, no death; **a death claimed during the pending confirm** — the chamber aborted, no
     SEALED.
2. **Never motionless before a teleport** (`creature_object12.gd`, gated on `forget_hidden_player and
   relocate_when_lost`, which only the Breach sets).
   - Arriving at a search point, the Breach's creature no longer stands turning for `SEARCH_TIME`: it
     walks to a neighbouring room (never the hidden player's), then another, while the SAME timer runs;
     at `SEARCH_TIME` the same give-up fires (a new roam destination for a hidden player,
     `_relocate_near_player()` otherwise), and `HIDDEN_RELOCATE_INTERVAL` relocations are untouched.
   - Measured (`check_breach_search_motion`): a hidden player's roam over 31 s, 3 relocations, the
     longest still window **0.10 s** (it was 4.5 s before a relocation); the post-hide loss, the
     longest still **0.08 s** before the teleport (it was **8.0 s**). With the Matron's flags the same
     creature still stands scanning for 8.0 s, as before.
3. **The technician: at once, the scream, the whisper** (`breach_approach.gd`).
   - "E — take the wheel" answers the moment he is looked at, even with the victim scene still playing.
     That scene's one-shots go through `_victim_shot()` and **duck 14 dB** under his beat
     (`VICTIM_TECH_DUCK`); they are never cut.
   - On E: the grip, then at 0.5 s his eyes open **with the user's scream**
     (`approach_technician_scream.wav`, 2.27 s, from his head), then at 3.0 s the whisper (still the TTS
     placeholder), then the release at 5.75 s (*CARRYING: THE VALVE WHEEL*) and the eyes close at 6.3 s.
   - The music ducks 14 dB (`MUSIC_WHISPER_DUCK`) and the beds 4 dB (`BED_PA_DUCK`) under the whole beat.
   - **The scream's gain is measured** (`probe_breach_music_mix.gd`, the player at `TECH_STOP`, the
     victim scene still playing): at `TECH_SCREAM_DB` −2 dB it is **−14.8 dB RMS** at the listener
     (loudest 0.1 s window −12.7), **11.4 dB over everything else** in that moment (−26.2), and **4.0 dB
     under the kill sting** (`level_6_jumpscare`, flat at −8 dB: −10.8). At −10 dB it measured −22.8,
     only 3.4 dB over the mix.
4. **Pass 4's leftovers** are in the pass-4 entry below: the face on the FIRST opening, the relief-depth
   checks, and the write-up of the shutter reversal and the 3D relief.
   - The painted open eyes were brightened and widened after the scream-moment render: at 1.5 m, at the
     game's half-scale 3D, the first cut vanished in the lamp's brow shadow.

**Proof.**
- `check_breach_contained_xor_killed.gd` (new, 7 checks) and `check_breach_search_motion.gd` (new, 6
  checks), both in the suite, both proven to fail with their fix removed.
- `check_breach_porthole.gd` (67): the prompt AT ONCE with the victim scene playing, the scream with
  the eyes, the whisper after it, the victim duck at −14 dB, the steps in order.
- `check_breach_approach.gd` (96): the route with `technician_scream` and `technician_whisper` as
  sequence steps.
- Renders: `backlogs/captures/breach-2026-09-23-pass4/03e_fused_face_1p5m_eyes_OPEN.png` and `03f_…`
  (the scream moment).

### Shipped — 2026-09-23 pass 4: the shutter face, the ceiling drop, the fused technician, the walk-in music, a harder hunt

**Why.** The user's third hand playtest (2026-09-23, session 17:40, six J-captures). They finished the
walk-in and the hunt with 0 deaths and a peak panic of 62 %. Their notes, verbatim:
- *"Maybe the face of the creature should appear behind this room which first opens and then
  closes?"* (bay B's shutter)
- *"This looks way too unrealistic - should it look like a weird creature itself, so that it does not
  look like an unrealistic human … And it looks very 2d now"* and *"it should probably be in the other
  part of that room - what for to keep the handle just besides the door"* (the technician)
- *"there should be at least one place where the element of unexpectedness and suddenness will make
  the player scared"* and *"I mean besides this hand"*
- *"Ins't it a bit too simple now to win the creature? Maybe make it just slightly harder"*

The log agrees. The flashlight was taken 12.4 s after the seal, before Object 12 appeared at 20 s. It
spawned 19.9 m away and was sealed 28.7 s later.

The user also supplied the walk-in music: `breach_corridor_music.wav`, for the corridor part only.

**What changes.** Every point was grilled one at a time and chosen by the user.

1. **The face behind the shutter: a quiet stare, not a jolt** (the user's call over "the face slams in").
   - (⭐ Reversed by the user 2026-09-24: the FIRST opening shows the face; see "As built" item 1.)
   - Bay B's roller shutter keeps cycling. It opens on the empty recess at least once, which teaches
     that the recess is empty.
   - On a later cycle, and only while the player is looking at it, Object 12's face and crown are in
     the dark recess: still, watching the player. Then the shutter rolls down over it. The next cycle
     is empty again.
   - Once per run.
   - A visual-only puppet in the `breach_approach_hand.gd` pattern: head and crown only, never
     emissive, no collider or `ScaryObject`, freed afterwards.
   - The approach now has three glimpses (grille, shutter, hand), knowingly accepted by the user.
2. **The walk-in's one sudden scare: the victim drops from the ceiling.**
   - In ApproachContainment, where the user paused, a ceiling hatch bursts open. The **dragged
     technician's body** drops on a chain right in front of the player with a crash, and the lamp
     flickers.
   - The body swings and twists, then settles. It pays off the drag heard behind the porthole door.
   - It is triggered by position, not by gaze, so it is actually sudden. Once per run.
   - No panic, no creature, and it never blocks the lane.
   - The body must read as 3D, not flat art: for example, cocooned in Object 12's organic membrane,
     built from parts, with one arm hanging out.
3. **The technician becomes a fused victim, moved to the far side of the Plenum.**
   - He is half-consumed by Object 12's growth and grown INTO the wall: torso and face embedded in the
     ruptured mass, one real 3D arm free, still clutching the handle. As part of the wall he reads as a
     relief, so the flatness stops being a problem.
   - He moves away from the porthole door to the other side of the room, so the player searches for
     the handle.
   - The grip, the eyes-open swap, the whisper and the story-channel wait are kept. (⭐ Pass 5 dropped
     the wait: he answers at once and the victim scene ducks; his scream comes before the whisper.)
   - ⭐ Corrected by the user after the renders: he holds **the whole valve wheel**, not the handle, and
     is life size and flush with the wall (see "As built" item 3).
4. **The walk-in music** (the user's `breach_corridor_music.wav`, 72 s, 6-channel, 96 kHz, 24-bit,
   124 MB).
   - Godot imports only mono or stereo, so it is converted to a **stereo, seamlessly looping OGG** for
     the game: `approach_corridor_music.ogg`, about 1–2 MB, with the gain set from its measured level
     (−10.5 LUFS source).
   - The 124 MB original moves unchanged to `assets_src/audio/level_6_breach/approach/` as a
     **local-only file**: one `.gitignore` line, approved with the choice.
   - ⭐ Corrected by the user after the renders: it is the LEAD layer, not a bed under the vent (see
     "As built" item 4 for the measured gains).
   - It starts at spawn, loops under the whole walk-in, dips with the silence beats (the door tell's,
     the victim's) through the `Ambience` bus, fades out at `threshold_quiet` so the hand's corner is
     silent, and stops at the seal.
   - Never in the hunt. Not on retries, which skip the approach.
5. **A slightly faster chase.**
   - The Breach sets `_creature.chase_speed = 5.5`, up from 5.0: a level-local constant, with the
     script's default left at 5.0.
   - The Nightmare's Matron keeps its 3.4.
   - A difficulty constant, chosen by the user.
6. **The seal becomes a race, behind ONE switch** (the user: *"make this feature easily
   irreversible, it is likely that after testing it I will say to restore it back"*).
   - A single constant, `SEAL_RACE := true` in `level_6_breach.gd`, passed to the purge chamber.
     **`false` restores today's instant slam exactly.**
   - With it on:
     - Pressing E starts the blast door grinding shut over a short close time while E is held.
     - Object 12, if it is inside, turns after a reaction delay and charges the door.
     - If it reaches the doorway before the door closes, the door jams and reopens: it is loose
       again, and the door can be tried again. That is not a death by itself.
     - If the door closes with it inside, the purge runs as before.
   - **Tuning rule:** close time and reaction delay are set so a seal **succeeds when it was lured deep
     into ExitVault** and **fails when it is near the doorway**. At 5.5 m/s it crosses the 7 m vault in
     about 1.3 s, so a 3 s close would be unwinnable.
   - The walk test must prove the level can still be won.

**As built** (level-improver, 2026-09-23; the parent built item 5 and prepared the music):
- **The route beats**, once each and in order, now end
  `… dark_room, cell_chamber, pa_3, ceiling_drop, threshold_quiet, hand`. The walk is **81.47 s**
  (walking only; it was 73.25 s), inside the agreed 60–90 s: the route now crosses the Plenum to the
  technician and back to the porthole door.
1. **The shutter face** (`_build_shutter`, `_tick_shutter`, `_cycle_shutter`, `breach_approach_face.gd`).
   - The roll stands `NICHE_D` 0.55 m forward of bay B's back wall, so the recess is a real black niche
     (a back panel, two cheeks, a head and a floor, all black) with room for a head in it.
   - ⭐ **REVERSED 2026-09-24 by the user** (*"now you can see the creature the second time the door
     opens, and the first time it opens you cannot see it. Let's make it vice versa"*): **the FIRST
     opening shows the face.** The `shutter` beat only arms it; the first cycle then WAITS until the
     player is looking at the niche (camera dot ≥ 0.8 within 14 m, and within 16 m of bay B's window),
     so it is never spent on a player's back. From the Observation corridor the niche is 9.8 m away,
     through the glass. A player who never looks never sees it open.
   - After the face, the shutter keeps cycling EMPTY (up 3.0 s, hold 2.5 s, down 3.0 s, then 1.5–3.0 s)
     while the player is within 16 m of the window, up to 8 cycles, looked at or not.
   - The face is `breach_approach_face.gd`: the hand's puppet contract, standing in the niche with its
     head at 1.78 m, 0.5 m behind the roll, turned to the camera when the cycle starts, and still. It is
     freed when the shutter is down (`shutter_face_gone`). Once per run.
   - **Head and crown only, done with light.** It is on render layer 17 (`1 << 16`), lit only by a
     small fill (energy 3.0, range 0.62 m) above and in front of the Head bone, and bay B's lamps and
     window spill are culled from that layer. Its material is the creature's with emission off **and
     albedo ×0.3**, because the level's ambient lights every layer and at full albedo the whole body
     stood grey in the niche.
   - A low breath placeholder plays from the niche as it opens (`approach_shutter_breath`).
2. **The ceiling drop** (`_build_ceiling_drop`, `_ceiling_drop`, `_tick_drop`).
   - A service duct built from parts runs along Containment's south side (x −9.3..−4.5, z −24.8 ± 0.4,
     y 2.55–3.34), with a real hole in its underside and a hinged hatch at x −6.9.
   - **Trigger: position only.** Crossing x > −9.2 in Containment, once. Measured: it fired with the
     player at x −9.17 and the body **2.27 m ahead** (2.56 m away), 1.2 m to the side of the lane.
   - The hatch bursts open (−118° in 0.12 s), the crash and the chain play, and the body falls 1.9 m in
     0.3 s, snaps taut past the chain's length and springs back. It swings mostly along the corridor
     and twists about the chain (peak 0.91 rad), and settles in ~20 s. Containment's third lamp stutters.
   - **The body is 3D parts, nothing flat:** a cocoon of capsules (ankles, legs, torso, head, upside
     down), shoulder and knee forms under the wrap, eight tilted binding strands, drips, hair hanging from
     the head, and **one bare arm** hanging out with a hand and fingers. The surface is
     `approach_growth_flesh.png` (below).
   - **A work lamp tangled in the chain** falls with him, on the lane side, and casts shadows. It
     catches, dies and catches again with the crash. The Containment lamp is on the wall side and
     backlit him into a flat black shape; the lamp models him from the front and throws a moving shadow
     on the wall behind.
   - Its collider (a capsule, r 0.24) is off until the drop and hangs clear of the lane: 120 of 120
     frame samples of rays along the lane (z −26 at three heights, z −25.6 at two) stayed clear
     through the swing, while the same ray along the body's line hit it on 106 of them.
   - No panic, no creature.
3. **The fused technician** (`_build_technician`, `_build_relief_mesh`), on the Plenum's east wall at
   z −30.4, **18.3 m from the porthole door**, north of the collapse. The route stops at `TECH_STOP`
   (−28.6, −29.6), 2.5 m from his face. ⭐ **Rebuilt 2026-09-24 from the user's own art and made a real
   bas-relief** (the user: *"a man holding a wheel looks very two D. Can we make it more three D?"*).
   - **The art is the user's**: `…/approach/user/fused_technician_closed_D.jpg` (flux, 8 steps; prompts
     in `prompts.txt` there), chosen from five. A realistic dead technician pressed into the wall, roots
     over and round him, everything below the waist swallowed, eyes closed, and both hands curled in an
     EMPTY grip at his chest and belly. Keyed off its green with no green left at the scissor edge.
   - **A displaced MESH, not a card.** A 192² grid over 1.30 m (6.8 mm cells; 37,249 vertices, 46,086
     triangles in the covered cells only), each vertex pushed out of the wall by
     `approach_fused_height.png`. That height map is built by `make_breach_pass4_art.py` from **capsules
     measured on the art** (head, neck, torso, shoulders, both arms, both fists) with rounded profiles,
     so the head is round and an arm is a cylinder, plus a shallow profile for the growth and a light
     luminance detail term, blurred, with no cliffs. Measured on the mesh: **chest 0.16 m proud, face
     0.14 m, fists 0.17 m, the growth 1–4 cm, 0.5 mm at the art's frame edge**. Normals come from the
     height grid; a normal map from the height's fine detail carries the folds finer than the grid.
     It **casts shadows**: the caged lamp throws his head, arms and the wheel onto him and the wall.
   - **Life size, grown from the wall**: his head (ears included) is 0.161 of the art's width, so
     `TECH_W` 1.30 m makes it 0.21 m, with his eyes at 1.55 m. The mesh's base is 4.5 cm off the wall,
     over the roots decal at 2.2 cm.
   - **The eyes** open by albedo swap on the same mesh: bloodshot, staring eyes PAINTED over D's closed
     ones (the tool asserts 0 texels differ outside the eye boxes).
   - **The wheel** (`VALVE_R` 0.105 m, bright bare steel, metallic 0.55) sits **between his painted fists
     at their displaced depth**: its rim passes through both fists (`TECH_ART_GRIPS_UV`, checked against
     the art's skin texels), its tube sunk into their curl, 0.22 m off the wall. Taken, it vanishes and
     leaves his painted hands curled round nothing. The door shows a bare spindle until it is fitted.
   - **No 3D mass**: the 56-lump sphere mound, the 3D arms, sleeves and hands are gone (the user called
     the spheres unrealistic); the swallowed body is the relief's. Three thin 3D tendrils come out of
     his swallowed foot, lie on the relief and then the wall, and reach the floor. The roots decal
     behind him is the user's `growth_spread.jpg`, keyed and faded radially, alpha-blended.
   - **His light**: a caged lamp on a bracket above him (a shadowed spot, energy 2.6, 44°) aimed down
     across his face to his chest; a faint cool fill.
   - The grip, the eye swap and the whisper are pass 3's. (Pass 4 kept pass 3's wait for the story
     channel, 7.2 s on a straight walk; ⭐ pass 5 dropped it — he answers at once, the victim scene
     ducks under his beat, and his eyes open with the user's scream before the whisper.)
   - He is solid (a box from the floor to his head, 24 cm deep), and E anywhere on him takes the wheel.
4. **The walk-in music** (`approach_corridor_music.ogg`, 70.26 s, −14.4 LUFS, made by the parent's
   `tools/prepare_breach_music.py`), **the lead layer**. ⭐ **Corrected after the user watched the
   renders** (*"I do not hear the music I sent you, I hear just the sound of the corridor … not too
   silent and not too loud"*): the first build's −17 dB put it 4 dB UNDER the vent bed, and 10 dB under
   it whenever a story beat ducked it.
   - It loops from the spawn on Ambience at **`MUSIC_DB` −4.0 dB**.
   - It ducks **−17 dB under a PA line** (and its chime), **−14 dB under the technician's whisper** and
     **−6 dB under every other story beat**, going down at 60 dB/s (the duck is in before the first
     word) and back up at 6 dB/s. It also carries the approach's own silence duck, and it fades from
     `threshold_quiet` and stops at −59.5 dB.
   - **Set by recording the mix on a real walk**, not by arithmetic: `tests/probe_breach_music_mix.gd`
     re-routes every speaker onto a meter bus with an `AudioEffectCapture` (headless works: the Dummy
     driver still mixes) and compares, per 0.1 s window, RMS at the listener:

     | segment | measured (power average) | median window | target |
     |---|---|---|---|
     | between beats: music − beds (vent, machinery, level beds) | **+3.5 dB** | +1.8 dB | +3–4 dB |
     | PA lines: PA − ducked music | +4.7 dB | **+7.0 dB** | ≥ +6 dB |
     | the whisper: whisper − ducked music | **+6.7 dB** | +5.3 dB | ≥ +6 dB |
     | other story beats: story − music | +4.5 dB | — | — |
     | the silences (Ambience dipped) | music −68 dB | | |

     The track is dynamic, so its loud passages lift the power averages and its quiet ones the medians.
     ⚠️ That recording also showed **the tannoy sat UNDER the vent bed even with no music at all** (PA
     −29.8 against beds −25.1 RMS at KONTUR's `PA_DB` −5). ⭐ **The user's call 2026-09-24: raise the
     announcer, Breach only** (built by the parent): `PA_DB` −1.0 (a DELIBERATE comment; KONTUR keeps its
     own), and `BED_PA_DUCK` −4 dB dips the vent hum and the level's beds while a PA line plays.
     Re-measured by the probe during PA lines: **PA −26.1, beds −29.0, ducked music −35.7**;
     `check_breach_approach` 96/0.
   - Measured on the full walk (`check_breach_approach`): −4.0 dB on quiet frames, −10.0 dB once a
     story beat has run 1.2 s, −21.0 dB under a PA line, the Ambience bus at −30 dB inside both
     silences, stopped at the hand. It played on 6,470 of 6,767 walk frames.
   - Freed at the seal. Never in the hunt, never on a return visit or a hunt retry.
5. **A slightly faster chase** (the parent): `BREACH_CHASE_SPEED := 5.5` in `level_6_breach.gd`, set on
   `_creature.chase_speed`. The script default stays 5.0, and the Matron keeps 3.4.
6. **The seal race** (`purge_chamber.gd`, behind `level_6_breach.gd:SEAL_RACE := true`).
   - `purge_chamber.gd` gains the exports `seal_race` (**default false**), `seal_close_time` and
     `seal_react_delay`. `SEAL_RACE`, `SEAL_CLOSE_TIME` 1.25 s and `SEAL_REACT_DELAY` 0.8 s live in the
     level. **With `seal_race` false, `interact()` runs the old instant slam, untouched** (asserted).
   - With it on, E starts the blast door grinding shut, and it advances only while E is **held** (the
     chamber polls `Input.is_action_pressed("interact")`). Letting go rolls it back open over 0.6 s and
     ends the attempt. The HUD prompt reads **"Hold E — seal the door"** (race off: the old "Press E").
   - A creature inside is purge-frozen at the press. After 0.8 s it is released and `force_chase`d, so
     it charges the doorway at the player.
   - If it comes within 0.8 m of the doorway plane first, the door **jams**: it is flung back open over
     0.4 s (`door_break`), the creature is held by the door for those 0.4 s (`force_block`), and it is
     loose. That is not a death by itself, and the door can be tried again.
   - A creature that was never inside but stands in the doorway jams it the same way: the leaf cannot
     grind shut through a body, and the blocker must never switch on inside one.
   - Fully shut, the old freeze → confirm → purge runs.
   - **The tuning rule, measured** (`check_breach_seal_race.gd -- --sweep`, creature active and facing
     the doorway at the press, which is its best case):

     | depth in ExitVault at the press | 1.0 | 2.0 | 2.5 | 2.75 | 3.0 | 3.25 | **3.5** | 3.75 | 4.0 | 4.5 | 5.5 | 6.5 |
     |---|---|---|---|---|---|---|---|---|---|---|---|---|
     | outcome | jam | jam | jam | jam | jam | jam | **shut** | shut | shut | shut | shut | shut |

     ExitVault is 7 m deep, so **the front half jams and the back half seals**. A jam lands 0.84–1.26 s
     into the close; at 3.5 m the leaf shuts with it 1.03 m from the doorway.
   - Placeholder grind: `approach_wheel_grind` pitched to 0.55.

**Audio still to come from the user.** Placeholders at their fixed paths, from
`tools/make_sfx_breach_pass4.py`:
- `approach_drop_crash` (from `approach_door_crash`)
- `approach_drop_chain` (from the House's `chain_rattle`)
- `approach_shutter_breath` (from KONTUR's `breathing_behind`, slowed and low-passed)
- the seal race's grind reuses `approach_wheel_grind` in code, pitched down.

**Art.** `tools/make_breach_pass4_art.py`:
- the fused pair (keyed, with the eye-only diff asserted);
- `approach_growth_flesh.png`, a tileable tangle of wet tendrils in the relief's palette, **drawn**, not
  generated: the Breach's organic wall texture (grey steel panels under growth) made every lump read as
  black plastic, and the flux quota was spent;
- `approach_growth_spread.png`, the roots decal;
- `approach_fused_normal.png`, the relief's normal map, derived from its own luminance.
Raws are in `assets_src/textures/level_6_breach/approach/pass4/`.

**What proves it.**
- **`check_breach_pass4.gd` (new, 57 checks).** Through the real player and the approach's own beat log:
  - the shutter (reversed 2026-09-24): looking away, the armed shutter opens nothing; the FIRST opening,
    on the look, shows the face, turned to the player (facing dot 1.000) and still; the puppet contract;
    **the player's camera renders its layer**; freed when the shutter is down; every later cycle empty;
  - the drop: fires once, by position, 1.5–2.5 m ahead; the hatch; 3D parts only; the work lamp on the
    lane side; the lane clear through the swing with the body-line positive control; the walk on and
    back; it settles;
  - the technician: the far side; ONE relief, a displaced **mesh** (37,249 vertices), its aspect its
    texture's; **life size** (head 0.21 m); **REAL DEPTH** (chest 0.16 m, face 0.14 m, fists 0.17 m,
    falling to 0.5 mm at the art's edge); no spikes; casts shadows; no sphere mass and no 3D limbs;
    a few thin tendrils lying on the surface; the grip points on the art's skin texels; the wheel
    between the painted fists, at their displaced depth; bright steel; the caged lamp above him; the
    normal map; the door's bare spindle; the fused pair; nothing glowing but the lamp's bulb; solid;
  - panic 0 throughout.
- **`check_breach_seal_race.gd` (new, 16 checks).** Race off: one press slams at once and purges, with the
  old "Press E". Race on: the prompt; deep (5.2 m) shuts and purges; shallow (1.6 m) jams, kills nobody,
  resets and swings open; letting go rolls back and releases it; nothing inside shuts, confirms nothing
  and reopens; a creature standing in the doorway (never inside) jams it too. `-- --sweep` prints the table above.
- **`check_breach_approach.gd` (96 checks).** The walk takes the wheel at `TECH_STOP` through the real E
  ray and fits and turns it at `DOOR_STOP`; the music's timeline (above), with the story duck and the PA
  duck each measured against the music's own idle level; `ceiling_drop` in the route order.
- **`check_breach_porthole.gd` (66 checks).** The technician is 18.3 m from the door and is walked to; the
  bare spindle does nothing without the wheel; fitting shows the wheel on the door; the carried line is
  `CARRIED_WHEEL`. Its spark-burst check now reads the SCHEDULED flash lengths from the approach's queue:
  measured as runs of lit physics frames it flaked under full-suite load, because the approach ticks in
  `_process` and one late frame merges two flashes 0.03 s apart into one rendered run.
- **`walk_level6_breach`, `check_purge_interact`, `check_purge_softlock`** hold E through the close.
  The walk lures the creature deep (sealed at 4.28 m in, shut at 1.24 s) and still completes.
- **`tests/probe_breach_music_mix.gd`** records the mix on a real walk (the table above).
- **Renders:** `screenshot_breach_pass4.gd` → `backlogs/captures/breach-2026-09-23-pass4/` (29 frames):
  the technician at 8 m, 4 m and 1.5 m, eyes closed and open, the wheel on his chest (`03a`–`03g`), at
  **45° and grazing along the wall** with the wheel (`03i`, `03j`) and at 45° with it gone (`03h`), and
  the door with the bare spindle and with the wheel fitted (`05a`, `05b`).

### Shipped — 2026-09-23 pass 3: an effort door, a dark room, the escape told, a hidden hunt start

**Why.** The user's second hand playtest of the approach (2026-09-23, session 12:32, five J-captures).
Every beat fired in order, and they liked the hand. Their notes, verbatim:
- *"This looks weird … It should look way more realistic … should we see some kind of a real monster
  through it?"* This was the leftover `PressureManifold` slab in PumpReturn.
- *"Now you can just walk throught these objects"*. **A bug:** the approach had 89 `_box` visuals and 5
  `_solid` colliders, and `_pressure_vessel` had none (Issue 269).
- *"you should try to open that door before you are able to go to the next part … put some effort to
  get in … something different [from mashing] … Inside … completely dark, and some creepy objects like
  poisons, knives … No jumpscares but the panic will rise."*
- *"the idea of the creature escaping is not developed enough … an empty cell which we saw in the
  Kontur … some bodies covered in blood … once you approach them they will seem alive for some moment
  and tell not to go there."*
- *"I do not like that the creature is just standing here at the moment the true level begins …
  appear at the random place in the level 20 seconds after you enter it"*

Every point was grilled one at a time and chosen by the user.

**The route now** (`breach_approach.gd`, 17 approach rooms):
Service → jogs → PumpReturn → Observation → Inspection → Damaged → Plenum → **the porthole door** →
**ApproachDarkRoom** (x −46..−28, z −43..−33, 3.2 m) → **ApproachDarkPassage** (x −28..−20,
z −38..−35) → **ApproachCell12**, now the cell chamber (x −20..−7, z −38..−29) → Containment →
Threshold → bulkhead.
- The walk is **73.25 s** straight at 4 m/s (walking only; it was 68.9 s). That is inside the agreed
  60–90 s.
- The route beats, once each and in order:
  `arrival_lamps, pa_1, self_waking_lamp, door_tell, shutter, smashed_lamp, pa_2, grating, duct_knocks,
  duct_crawl, victim, technician, wheel_fitted, porthole_open, dark_room, cell_chamber, pa_3,
  threshold_quiet, hand`.

1. **The hunt starts hidden** (built by the parent).
   - Object 12 is invisible, silent and inactive through the grace (20 s first attempt, 8 s retry).
   - When the grace ends it appears in a **random hunt room, far from the player and out of their
     line of sight, unannounced**. It never appears in EastVault or ExitVault.
   - The "IT IS AWAKE." scrawl and the objective change are removed.
   - `creature_object12.gd:spawn_unseen(min_dist, exclude)` reuses `_visible_to_player()` and is a
     no-op when `_rooms` is empty, so the Nightmare is unchanged.
   - **Absent** means invisible **and without a collider**, via `set_present(false)`. `_body` is a
     StaticBody3D under the ScaryObject, so a merely hidden body would have been an invisible wall at
     Junction1, and a glance at that empty doorway would still have charged gaze panic.
   - `SPAWN_UNSEEN_MIN` is **16 m** (about two rooms). If no room qualifies it is halved once, and if
     even that fails the creature stays where it is.
   - A won level keeps the body present, as before.
   - This replaced the visible dormant spawn at Junction1.
   - `check_breach_hunt_start` is at **84/0**: ten seeded starts from five player positions and
     facings gave 7 distinct spawn rooms, 17.8–40.1 m away. Its negative control is an impossible
     `min_dist`, which returns false and moves nothing.
2. **The PumpReturn grille** (`_build_grille`, `breach_approach_grille.gd`).
   - **The housing.** A matte steel return-air housing on PumpReturn's **east** wall at z −55. The old
     slab was on the west wall, the wrong side of the room from the tell. It has a heavy flanged frame
     round a 2.0 × 1.2 m aperture (y 1.1–2.3), a black sleeve for depth, a centre mullion, and 11
     louvres tilted 35° with dust on each. A standing player looks level between them, and they are
     about 68 % open. A barrier collider fills the aperture.
   - **The room behind.** **ApproachIsolation4** (x −40..−37, z −58..−52) is unreachable. On its east
     wall stands a pale steel door at z −53.3, lit by its own lamp.
   - **The puppet.** During the door tell, a puppet of Object 12 stands with its back to the grille and
     batters that door: five two-armed blows, one per `door_batter` thud, with the body pitching into
     each.
     - It stills in the tell's silence, arms raised.
     - Its own rim light dies with the lamps.
     - When the lights return (the crash) it has been freed, and the door hangs burst open onto black.
   - **Why at z −53.3, not behind the centre.** The player walks up PumpReturn from the south, so the
     line of sight through the slats runs diagonally north. Centred, the creature showed as a sliver at
     the aperture's edge.
   - **The puppet contract** (the hand's):
     - `CreatureAnim.build`, a duplicated material with emission off, `hold_pose` and never `halt`;
     - shadows off, no collider and no `ScaryObject`;
     - its own layer (1 << 18), so PumpReturn's lamps do not light it and it stays a silhouette.
   - It fires once per run, as part of the tell, and never faces the player.
   - The tell's sound source is that door now.
   - **The approach has two glimpses**, the grille and the hand. The user relaxed the earlier "exactly
     ONE glimpse" ruling. (Pass 4 adds a third, the shutter face, knowingly accepted by the user.)
3. **The porthole door is the only way on.**
   - **The collapse.** The Plenum's doorway to Containment (−26, −26) stays cut, and is filled by a
     collapse (`_build_collapse`):
     - the main duct's last section, fallen diagonally across it with its flanges and a hollow mouth
       (the duct overhead now stops at x −31.5 with a torn end);
     - a second section and bent sheets;
     - a buckled panel jammed in on the Containment side;
     - a collider that fills the opening.
   - **The porthole door** stands in its doorway (1.44 m cut, 1.34 m leaf on a hinge). Its lamp casts shadows
     (one of the approach's three shadow-casting lights, with the technician's fill and the spark), so it
     cannot light the dark room through the wall.
   - **The dead technician** is slumped in the corner left of the door, turned toward it (+0.6 rad),
     with his own shadowed fill. He holds the wheel's missing handle.
     ⚠️ **Superseded by pass 4:** he is now fused into the Plenum's far wall, 18.3 m from the door, life
     size, and his art is the `approach_fused_*` pair. **He holds the whole valve wheel, not a handle,
     and the door shows a bare spindle** ("E — fit the wheel", *CARRYING: THE VALVE WHEEL*). The sequence
     below (the story-channel wait, the grip, the eyes, the whisper) and the wheel's turning are
     unchanged; read "handle" below as "wheel".
     - He is generated art on a 1.2 m quad (`approach_technician_closed.png` and
       `approach_technician_open.png`): an eyes-open raw and the same image with lids painted over the
       two eye regions. The tool asserts that 0 texels differ
       outside the eyes.
     - **He does not answer until the story channel is idle.** The victim sequence behind this very
       door plays first; on a straight walk he answers ~11.5 s after the player reaches the door.
       ⚠️ **Superseded by pass 5:** he answers at once, and the victim scene ducks under his beat.
     - **Taking the handle (E):** the dead hand pulls it back twice (~0.5 s), the eyes OPEN at 0.50 s,
       and a close hoarse whisper plays from his head, *"don't… go in there…"*. The grip lets go at
       3.23 s and `set_carried("A WHEEL HANDLE")`. The eyes close for good at 3.78 s. It happens once.
   - **The wheel.** E fits the handle (a clack; the carried line clears) and takes hold of the wheel:
     `freeze_input()`, the prompt reads *"Circle the mouse to turn it · E — let go"*, and `_input`
     reads `InputEventMouseMotion.relative` and swallows it.
     - **The virtual hand is the smoothed motion vector.** The wheel turns by how far that vector's
       direction turns: 2π per loop of any size, anywhere on the pad.
     - A jump over 1.2 rad is a reversal and counts for nothing, so rubbing straight back and forth
       never turns it.
     - Either direction works: the first 0.6 rad picks it, and circling the other way unwinds.
     - The gear is 0.55; the wheel turns at most 1.9 rad/s, with the excess carried in a 0.25 rad bank.
     - It drifts back at 0.45 rad/s after 0.35 s idle; a creak plays every 30°, and a grind loop
       follows its speed.
     - E again, a movement key or Esc lets go, and so does walking 2.6 m away.
     - Measured: **three turns take 10.12 s** at a steady 0.7 mouse circles/s, and **13.0 s** with
       small slow trackpad circles (20 px, 0.4/s).
   - **Three turns open it:** the bolts draw into the hub (the bolt sound), and 0.7 s later the door
     heaves open inward to 100° over ~3.4 s (the swing sound).
   - **Progress survives navigation:** `save_progress()` carries `approach_handle_taken` and
     `approach_porthole_open`.
   - This is not a mash and not a KONTUR verb. It reverses *"without … another item puzzle"*, per the
     user's note.
4. **The dark room** (`_build_dark_room`).
   - **The light.** An experiment room lit only by a **sparking junction box** on its north wall. The
     box has its cover torn open, conduits, and a burst of cable, with a frayed end. It fires bursts of
     1–3 flashes, each 0.06–0.12 s and 0.03–0.09 s apart. The gaps are 0.5–2.4 s, and one in five runs
     2.6–4.8 s.
   - Each flash is a real, shadow-casting omni (range 12 m) plus a small glowing arc and a shower of
     sparks. Measured: 21–28 flashes in 24 s, lit on 7.5–10.9 % of frames.
   - **Only the sparks glow; no prop does** (§8.8). Every prop is built from parts:
     - a **vial rack** with rows of vials under a dose rail climbing 0.5 → 64 mg, the last two struck
       through and tipped;
     - a **trolley** with an instrument cloth, eight instruments laid out in order and one traced
       outline empty;
     - a **restraint chair** bolted over a floor drain, with fingernail-scored armrests and straps;
     - a **clipboard exposure log** of tallies, ending *"DAY 10 it does not need the dark"*;
     - a **hose** coiled on the wall and run to the drain, with a **bucket**;
     - a **cart of specimen jars** holding murky fluid and unidentifiable lumps;
     - the victim's **drag marks** from the door to the far doorway, which his drag sound now recedes
       toward.
   - A dark-room bed fades in only while the player is inside.
   - **No jumpscare.**
   - **Panic.** While inside, panic rises at 5.9/s against the player's own 3.5/s decay and **stops at
     42/50**. It is held there every physics frame, so sprinting cannot carry it on, and it never
     kills. Outside, normal decay drains it.
     - Measured: 9.0 at 2 s, 28.2 at 10 s, **the cap reached at 15.75 s**, peak 42.0000.
     - On the straight walk the peak is 12.2. Panic is exactly 0 on every frame before the room and
       only falls after it.
   - This is the approach's one panic term, by the user's call. Nothing on screen explains it.
5. **The escape told** (`_build_cell_chamber`).
   - The pass-2 bent-outward cell door, punched plate and cell interior are gone. The chamber doorway
     keeps its head, its jambs and two torn hinge stubs.
   - **The cell is the shared `ContainmentCell` in its BREACHED state**, the same tank KONTUR shows
     occupied (concept A; the KONTUR agent's build, `containment_cell.gd`, not edited here).
     - It stands on `BreachedCellSpot` at (−11, 0, −34.8), turned `+PI/2` like KONTUR's, so its front
       faces −x, at the player coming in from the passage.
     - Its front pane is gone: 19 teeth stay in the frame and 102 shards lie on the floor in front,
       with its stained drain.
     - The collar is torn and swinging, and there is blood inside. No occupant, no hum, no tracking,
       no panic.
     - Its own lamp (emission-only liners and back wall) is left on, so the empty tank reads against
       a lit interior.
     - It is set up by `place_breached_cell()`, with `state` and `drain` set before `add_child`.
   - The player walks **through** the chamber:
     - the tank's own glass (it **crunches underfoot**, three variants every 0.55 m; the crunch zone is
       the tank's shard field);
     - a residue trail from the cell's spot to the doorway;
     - two **bodies**, dead only: a lab worker face-down in the glass and a guard curled in front of
       the desk. Both are generated art on floor quads, keyed with a dark contact shadow, and each has
       a low solid collider;
     - a shaded key light over the tank's burst front, and a second fitting over the bodies.
   - **The CCTV monitor.** A boxy CRT on the security desk, turned toward the entrance, with a
     knocked-over chair beside it. Its screen is a QuadMesh fed by
     `VideoStreamPlayer.get_video_texture()`, the game's first in-world video.
     - A shader adds grain, scanlines, a rolling bar and dropouts. Emission is capped at 0.55, so the
       screen is shaded, not self-lit.
     - A Label3D timestamp ticks over it.
     - The CRT hum is on Ambience.
     - ⚠️ The clip is a **placeholder** (`tools/make_breach_cctv_placeholder.py`) at the user's fixed
       path, `game/assets/video/breach_cctv_breakout.ogv`.
6. **Every floor-standing approach prop is solid** (Issue 269).
   - `_solid_box()` and `_collide()` make the collider a child of the mesh, so it follows hinges and
     tilts. `_collide_cylinder()` covers the receivers.
   - Overhead props whose underside is above 1.8 m stay meshes.

**Audio: the user is supplying all of it.** Each sound has a stand-in at its final path under
`game/assets/audio/level_6_breach/`, from `tools/make_sfx_breach_pass3.py`:
- `approach_whisper_dont_go_in`
- `approach_wheel_grind` (loop) and `approach_wheel_creak`
- `approach_porthole_bolts` and `approach_porthole_swing`
- `approach_handle_clack`
- `approach_spark_burst` and `approach_spark_buzz` (loop)
- `approach_darkroom_bed` (loop)
- `approach_glass_crunch_1/2/3`
- `approach_crt_hum` (loop)

The list, with each stand-in's source, is in `docs/TODO_sounds.md`. Machinery and ambience are on
Ambience; the whisper, the clack, the bolts, the swing and the glass are on Master (Issue 267).

**Art.**
- `tools/make_breach_pass3_art.py` makes:
  - the technician pair;
  - the two bodies, keyed by a border flood fill with the halo turned into a dark contact shadow;
  - a blood pool;
  - the Pillow text: the dose rail, the clipboard, the jar label, the junction plate, the tray cloth
    and the armrest scores.
- Raws and prompts are in `assets_src/textures/level_6_breach/approach/pass3/`.

**What proves it.**
- **`check_breach_porthole.gd` (new, 62 checks).** It uses the real player: walked, the E ray, and
  mouse circles pushed through `Viewport.push_input`. It covers:
  - the collapse blocks physics rays at three heights, against an open-doorway control;
  - rays hit the collider of all 22 floor-prop classes;
  - the wheel refuses without the handle, and the technician refuses during the victim;
  - the handle's grip → eyes → whisper → release → eyes order;
  - the wheel turning, drifting back, ignoring a rub, unwinding, and letting go on E and on a
    movement key;
  - three trackpad turns in 13 s, then a ray-clear doorway;
  - dark-room panic reaching the cap at 15.75 s and never exceeding the user's pinned 42, even
    sprinting;
  - the spark timing, the glass and the CCTV;
  - the shared cell: breached (19 teeth, 102 shards), its front facing −x (a ray through the open
    front stops at its back wall, inside the tank), no `ScaryObject`, none of the approach's own glass
    on its field, and no placeholder left;
  - both snapshots.
- **`check_breach_approach.gd` (81 checks).** The full walk now does the handle and the wheel at the
  door. Panic is 0 before the dark room, capped inside and only draining after. The grille puppet is
  collider-free and freed before the seal.
- **`check_reachable`.** Its Breach row gains the documented gate `PortholeLeafSolid`. Without the gate,
  17 of 20 interactables measure unreachable.
- **Renders.** `screenshot_breach_pass3.gd` renders every beat into
  `backlogs/captures/breach-2026-09-23-pass3/` (29 frames). `06e` and `06f` are the breached tank.

### Shipped — 2026-09-23 legibility pass on the approach (from the parent's reading of the renders)

The approach passed its checks, but three beats did not read in the renders, and one geometry gap
remained. The user approved fixing all four before the playtest. None of it changes a gameplay
number. The renders are in `backlogs/captures/breach-2026-09-23-approach/`.

1. **The hand** (`11a`/`11b`) was a thin dark sliver at ~6.5 m that read as a hanging cable.
   - **It fires at 3–5 m** (`HAND_MAX_DIST` 5.0; measured **4.27 m** on the test walk). The look
     cone widens to ~41° (dot 0.75): at this range the hand hangs 2.2 m beside the lane, and a 32°
     cone would give a player walking straight a ~0.15 s window.
   - **About 0.7 m of arm hangs out.** The shoulder sits lower (2.12 m) and toward the duct's lane
     side (x −2.15).
   - ⚠️ **The rig has no finger bones**; `LeftHand` is one bone. So the fingers cannot be splayed or
     hooked over the hatch lip one by one. Instead the hand is turned 90° about the forearm, so its
     modelled fingers face the approach broadside, and flexed 30° at the wrist into a claw. This was
     chosen from rendered variants (0/90/180/270° × ±35°).
   - **Three lights make the silhouette.**
     - A raking light from the approach side, on the puppet's layer only.
     - A backdrop light that touches everything EXCEPT the puppet, putting a lit patch of tile
       behind the arm.
     - A glow in the hatch it comes out of.
   - The result is a dark claw against lighter tile. It is still non-emissive, never faces the
     player, fires once only when looked at, and is freed after.
2. **The cell** (`10a`/`10a2`/`10b`) had dents that read as stove knobs, and an interior that
   rendered black behind a leaf covering the whole opening. ⚠️ **Superseded by pass 3 (above):** the
   bent leaf, the punched plate and the cell interior are gone, and the cell is the shared glass tank in
   the enlarged chamber.
   - **The dents are punched out.** Three ragged holes (7-sided black holes, 6–7 torn steel petals
     peeled outward, bare-metal material) and a jagged split seam with a lifted lip between two of
     them.
   - **The leaf hangs open**, torn off its lower hinge: it swings 60° from its left jamb and is still
     folded at mid-height.
   - **The cell is lit.** The red lamp runs at 1.8, there is a fill by the door, and the restraint
     frame is mid steel. The restraints, straps and pool now show from the doorway.
3. **The residue rule** (`04c`/`04d`).
   - **Harder, stronger pools.** The four downlights run at energy 7 with angular attenuation 0.15,
     against 4 / 0.6 before, so each pool is a hard-edged bright disc. The companion omnis drop to
     0.3.
   - **Visible fronts.** Two edge smears per pool side, across the corridor, push their ragged fronts
     ~0.35 m into the rim, so residue shows dark on the lit floor where it stops.
4. **Every approach height step now has a lintel**, with a collider, in steel so it reads as solid
   against an unlit room.
   - The four new ones: PumpReturn/ServiceReturn (z −65), PumpReturn/Observation (x −46),
     Plenum/Containment (x −26), Containment/Threshold (z −23).
   - Damaged's two already had one.
   - Frames `13a`–`13e` show each lintel from the taller room.

**Proof:**
- `check_breach_approach` **58/58**. The new check is that the glimpse fires within 3–5 m. It went
  red at 6.14 m with the old ≤ 7 m trigger restored, then was reverted.
- `check_wall_overlap -- Breach` 0 findings.
- `check_shell_sealed`: 0 of 941 points leak.
- `check_doorways`: 0 blocked.
- `check_art_aspect` 94/0; `check_fixtures` 29 fittings.
- `tools/run_tests.sh breach` 10/10.

### Shipped — 2026-09-23 the approach shows Object 12's traces, its sounds and one glimpse

> ⚠️ **Partly superseded by passes 3 and 4 (the entries above).** What changed:
> - **Glimpses.** There are THREE since pass 4: the grille, the shutter face and the hand. The
>   "exactly ONE" ruling was relaxed by the user.
> - **Pass 4:** the route is 81.47 s, and the walk-in has the user's music. In the room table below,
>   bay B's shutter now rolls on a 0.55 m niche that shows the face once; the Plenum's technician is
>   fused into its far (east) wall, not by the door; Containment gains the duct and the ceiling drop.
> - **An item puzzle.** There is one now: the handle for the porthole door, again the user's call
>   (since pass 4 it is the whole valve wheel, and the door shows a bare spindle).
> - **The route.** It is 17 rooms and 73.25 s, not 13 rooms, 283.8 m and 68.9 s.
> - **Panic.** It is 0 except in the dark room, not 0 everywhere.
> - **The room table.** The PumpReturn row gains the grille and its puppet. The Plenum row's
>   porthole door now stands in a doorway that opens, and the victim's drag recedes across the dark
>   room. The Containment + Cell12 row's bent-outward door and cell interior are gone.
> - **The proof.** `check_breach_approach` is 81 checks, not 58.
>
> Everything else here still holds.

**Why.** 2026-09-22 hand playtest, all six J-captures inside the approach:
- *"This first part of the corridor is too boring."*
- *"the corridor itself is cool but it clearly lacks the scary parts, and it does not represent what
  will happen next. Shall we have like hallucinations of the creature you will see later, the same
  textures as there, some other kinds of things?"*

The old first corridor was one dead-straight 60 m box with a lamp every 8 m, and the whole route
carried four one-off events, none of them about Object 12.

**Rulings changed by the user (2026-09-23), overriding the 2026-09-22 entry below:**
- **The approach shows Object 12's traces, its sounds, and exactly ONE partial glimpse.** This
  replaces *"no visible creature or active pursuit"*, *"No monster silhouette"* and *"hidden, inactive
  and silent"*. Full hallucinations were offered and not chosen: the player met Object 12 in KONTUR's
  glass cell, so the approach's job is dread of meeting it loose, not a first reveal.
- **The REAL creature is unchanged.** Its AI, `breach_creature_voice.gd`, patrol, relocation and
  contact stay dormant and its body hidden until the seal. Every beat uses the approach's own
  speakers; the glimpse is a separate visual-only puppet.
- **Length stays 60–90 s at 4 m/s**, denser rather than longer. No forced waits, no item puzzle, no
  timed locks.

**Most beats teach a hunt rule before the hunt.**
- It hates light: residue stops at every lit pool.
- Hiding works: a gouged cabinet that held.
- It follows sound: the grating, and the duct that answers.
- A door it batters goes silent, then dark, then crashes: the same sequence `breach_door_scare.gd`
  plays in the hunt.

**The route** (`breach_approach.gd`): 13 rooms, 283.8 m of `WALK_POINTS`, measured **68.9 s** at the
4 m/s walk. Every beat fires once per run.

| Room | What is there |
|---|---|
| **ApproachService → ApproachServiceJog → ApproachServiceReturn** (three legs, two jogs, 3.6 m) | The far end is never in view: every leg ends in a wall 17–22 m ahead, with the next opening to the side. **Motion lamps** in uneven clusters clunk on (`lamp_on`) as the player comes within 5 m: a pair at the spawn, which lights on arrival (the first lesson), then a triple, a dead fitting with a dangling tube, and singles and pairs beyond. **The self-waking lamp** is at the far end of the jog, 19.5 m ahead as the player turns into it. It clunks on by itself when they look down the jog (or by x > −73), holds 2 s, then dies with `lamp_off_break` and stays dead. The clusters are held off while it performs. Also: a **shift roster** with 11 of 12 names struck through; **torn barrier tape** at the first jog, its printed side facing containment, so it was strung to keep something in (read mirrored on the way in). **PA line 1** plays at x > −91, after KONTUR's own chime. |
| **ApproachPumpReturn** | **The door tell**, through the east wall. The hunt's own batter roar (`breach_voice_batter`) and `door_batter` thuds every 0.6 s, muffled, for 3 s → 1.2 s of silence (an Ambience dip plus the level beds −32 dB) → the two PumpReturn lamps go dark for the last 0.8 s → `metal_crash` and the lights back. |
| **ApproachObservation + bays** | Four working downlights: spots with a hard-ish floor pool of radius 3.0 m. Two smashed ones, with glass on the floor. **The residue trail** runs everywhere except inside the pools; one smear on each dark side of every pool reaches just into its soft edge, which is where the residue is lit and seen to stop. The bay windows spill the only light into the dark stretches. The first smashed lamp still **sputters once** as the player nears it (`lamp_off_break`, quiet). A **"98 %" seal panel**. A **locker** deeply gouged outside, its door hanging open toward the approaching player, tallies scratched inside. **Bay B's roller shutter** rolls up over a black, empty recess, holds 2.5 s, and rolls down (`motor` both ways; a relay clunk at the bottom). **PA line 2**, with dropouts and a stuttered count, plays at x < −72. |
| **ApproachInspectionTurn** | The **"CONTAINMENT SERVICES ←"** plate: self-lit, washed by its own lamp. |
| **ApproachDamaged** (ceiling **2.4 m**) | Lintels fill both doorways above the low ceiling. A big duct runs along the north side; two cross ducts pass over the lane (bottom at 2.08 m); there is a pipe along the south wall. **The loose grating** at (−88, −26) clangs underfoot → 2.0 s → three knocks from the duct above the player → 2.0 s → **the crawl** moves away ahead along the duct to x −63 over 4.3 s, with dust sifting at three seams. A **"61 %" panel**. |
| **ApproachPlenum** | **The porthole door** on the far wall between two receivers, with a caged lamp over it. **The victim** starts at x > −61: hammering and begging (5.2 s) → +3.4 s the roar, low-passed, as the door lamp flickers → +5.6 s his scream → +8.3 s the building scream → +8.5 s **the building answers**: the four receivers ring in turn, the release housing rattles and shakes, a pipe groans, dust falls from the trays, and the residue under the door grows over 9 s → +11.2 s a thump (`impact_thud` at 0.7 pitch, the sound of the player's own death later), then 1.1 s of silence → +12.3 s the drag, receding behind the wall over 4.3 s. No figure, no light behind the glass, no shadow under the door. |
| **ApproachContainment + ApproachCell12** | Object 12's cell is **a real 7 × 5 m room** behind a steel door **folded outward** at mid-height, hanging open off its torn lower hinge, with three ragged holes punched out of its head plate at crown height and a split seam between two of them. Inside: a red lamp lighting it, torn restraints, gouges at 2.5 m, the pool. In the corridor: an **"OBJECT 12" stencil**, finger drags along both walls at 2.6 m, floor drag marks leading to the Threshold, a dead **"— — —" panel**. **PA line 3**, cut off mid-word, plays at x > −15. |
| **ApproachThreshold** | Entering ducks the Ambience layers and the level beds to −26 dB and stops the machinery. A big exhaust duct runs along the west wall with one open hatch, at z −16.5. **The glimpse.** The **"OBJECT 12 / CONTAINMENT WING"** plate is beside the bulkhead now, clear of its rails. Then the bulkhead. |

**The glimpse** (`breach_approach_hand.gd`):
- **It is a puppet built like `breach_kill_sequence.gd:55-66`.**
  - `CreatureAnim.build()` on a plain `Node3D`.
  - A **duplicated** creature material with emission off (`SCARY.md` §8.8).
  - `hold_pose(walk)`, never `halt()`.
  - Shadows off, and meshes on layer 1 << 17 with a fill light culled to that layer.
- **It shows one arm, lying face-down inside the duct.** The left arm is solved straight down out of
  the hatch; the right arm and both legs are solved flat inside it.
- **It cannot hurt.** No collider and no `ScaryObject`, so zero panic and no contact. It never faces
  the player and never approaches.
- **It fires once**, when all three hold:
  - the player is in the Threshold, 3–5 m from the hand;
  - their camera is within ~41° of it (dot 0.75; see the legibility pass);
  - the story channel has been quiet for 1 s.
- **Then:** a 0.15 s hold, a 0.5 s yank 0.8 m up into the duct, with `loud_screamer` following it up and
  6 m along the duct, and the puppet frees itself on arrival.
- **Walked past within 3 m without looking,** it goes unseen and unheard (`hand_skipped`).
- The level's `_creature` is never moved, shown or voiced.

**One story channel.** PA lines, the door tell and the victim never talk over each other. A beat
triggered while another is playing waits its turn, plus 0.5 s. That is why a straight 4 m/s walk,
which crosses the Plenum and Containment inside one victim sequence, still hears every line in order.
The machinery pool waits too, and the glimpse needs the channel quiet.

**Sound.**
- **The user's thirteen recordings.** Originals are copied unchanged to
  `assets_src/audio/level_6_breach/approach/`. Game copies (`approach_*`) are prepared by
  `tools/prepare_breach_approach_audio.py`, which decodes to FLOAT and normalises there. Four originals
  decode above full scale: `loud_screamer` +6.4, `loud_scream` +4.4, `metal_crash` +3.0,
  `door_part1_sound` +2.9 dBFS.
- **The knocks** are three single hits cut at clean attacks (3.712, 7.118 and 10.976 s) from the
  20.6 s `monster_knock` flurry.
- **Generated** by `tools/make_sfx_breach_approach.py` (seeded, stdlib):
  - the drag, the grating clang, the receiver ring, the duct rattle;
  - twelve machinery one-shots. None is footstep-like, and the drag's pulls have smooth attacks.
- **The PA's three lines** come from `tools/make_breach_pa.py`: KONTUR's announcer chain, the same
  "Daniel" voice, played non-positional on Master at `kontur.gd`'s −5 dB. This is the Breach half of
  `GAME_MECHANICS_IDEAS.md` N4.
  1. *"Containment status, Wing C. Object Twelve: secured. Seal integrity ninety-eight percent."*
  2. *"Seal integrity… sixty-one percent. Personnel on site… two hundred twelve… twelve…"*
  3. *"Object Twelve is not in its—"*
- **Buses:** the machinery pool, the ventilation bed, the lamp clunks, the shutter and the dust are on
  **Ambience**; the story beats are on Master.
- **The ventilation bed** runs at −12 dB (file RMS −16.2 dBFS), breathing ±3 dB over 7.5 s.
- **The machinery pool:** one-shots 6–14 s apart, 6–15 m away, 60 % from the rear 120°, ±10 % pitch,
  each set to −24 dBFS loudest-300 ms at 10 m.
- **Everything the approach owns stops at the seal.** The level beds go back to their approach level
  before `committed`.

**Art.**
- The residue, pool, drag, gouge and finger-drag decals are flux raws in
  `assets_src/textures/level_6_breach/approach/` (prompts beside them), keyed on darkness into real
  RGBA cutouts.
- The panels, roster, stencil, both signs, the tape, the tallies and the porthole fog are drawn by
  Pillow.
- Both come from `tools/make_breach_approach_art.py`. Every piece of art is on a QuadMesh.

**What proves it: `check_breach_approach.gd`, 58 checks (57 plus the legibility pass's 3–5 m check).** It is a physical walk sampled on every
physics frame (4,402 frames):
- panic exactly 0 on every frame;
- the real creature hidden, voiceless and dormant on every frame until the seal;
- all 14 route beats once, in route order, and all 11 sequence steps once, after their parent;
- the puppet has no collider and no `ScaryObject`, its own non-emissive material, and no shadow;
- a **negative control** stands in the Threshold facing away until the story channel is quiet, and
  the glimpse does not fire;
- facing up the Threshold fires it, and the puppet is freed **before** the seal;
- the machinery layers report the Ambience bus;
- the seal stops every approach speaker;
- the bulkhead, retry, return-visit and new-run checks.

`screenshot_breach_approach.gd` renders every beat (26 frames) through the real triggers.

### Shipped — 2026-09-23 the flashlight lives in EastVault; the first-attempt grace is 20 s

This overrides the room and the grace in the 2026-09-21 entry below; the pickup mechanics are
unchanged.

**Where the flashlight is.** `FLASHLIGHT_ROOM` is **EastVault**: the existing cabinet on the east wall
of the east-wing dead end, facing the WardA doorway at (10, 24).
- It is 33.1 m in a straight line from the purge door, and about 35 m walking across the spine. So
  recovering the light and luring Object 12 into ExitVault are two separate journeys through opposite
  wings.
- The ArchiveB cabinet is an ordinary hiding spot.
- Nothing in the level names the location. The cabinet's leaking beam is the only clue.
- The cabinet is named `FlashlightCabinet_<room>`, and the DebugLog line names the room.

**The grace.** `FAMILIARIZATION_FIRST` is **20 s**, and `FAMILIARIZATION_RETRY` stays **8 s**. A
retry resumes at the sealed checkpoint, where the 8 s tests route knowledge.

**What proves it: `check_breach_flashlight.gd`, 47 checks.**
- It asserts the EastVault position, the distance to the purge, and that ArchiveB is ordinary.
- It measures the creature still dormant at 8.2 s and awake at 20.2 s on a first attempt, and dormant
  at 7.6 s and awake by 8.4 s on a retry.
- It walks Junction1 → Atrium → WardA → EastVault physically and collects through the real E ray.
- It leaves the wing through the WardA ↔ Junction2 loop doorway.

**How visible the clue is**, measured by `probe_breach_eastvault_view.gd`. Renders read as images; the
numbers are 95th-percentile / mean luminance of the cabinet region, dark → lit:

| Where the player stands | Result |
|---|---|
| In line with the EastVault doorway, WardA at z ≈ 24, 8.8 m away | **28 → 55 / 11 → 22**: the pulse doubles the cabinet's brightness |
| WardA's north end (7, 29) | No change: the cabinet is out of line of sight |
| The Atrium entrance (4.6, 21) | No change: out of line of sight |

So the beam rewards looking INTO EastVault, not passing through WardA. That fits the user's no-hint
ruling. Whether it's enough on a cold first run is in NEEDS A PLAYTEST.

### Shipped — 2026-09-23 the approach's walls are built once

J-captures 3, 4 and 5 (*"Here we have a bug with the textures"*, *"Here also a bug with overlapping
textures"*) were **12 coincident wall pairs**.
- Abutting approach rooms of different ceiling heights each built a full slab on their shared plane,
  because `RoomBuilder` keyed its dedup on height as well. Six planes are affected, each split by its
  doorway:

  | Plane | Rooms (height) |
  |---|---|
  | z −65 | Service 3.6 / PumpReturn 4.0 |
  | x −46 | Observation 3.4 / PumpReturn 4.0 |
  | x −94 | Inspection 3.4 / Damaged 3.8 |
  | x −62 | Damaged 3.8 / Plenum 5.2 |
  | x −26 | Plenum 5.2 / Containment 3.4 |
  | z −23 | Containment 3.4 / Threshold 3.0 |

- The shared builder now keeps each plane's coverage with its heights and builds only what rises
  above an existing wall. This is Issue 266, specced in `spec/systems/scripts.md`.
- `check_wall_overlap.gd`: the Breach went from 12 findings to **0**. The full sweep is 14 scene-runs
  and 0 findings.
- **Ownership of a shared stretch follows build order.** The earlier room in `ROOMS + APPROACH.ROOMS`
  owns it. So where a tall tiled room abuts a lower skinned one, the lower room's side of that wall
  shows the taller room's skin.

### Shipped — 2026-09-21 chase and kill audio correction

The user hears the chase background but not the scream, and the contact kill lacks its intended
jumpscare sound. Object 12 now uses the exact existing
`res://assets/audio/level_backrooms/crate_jumpscare.ogg` for its chase vocal, layered over
`breach_voice_chase_background.wav`. The confirmed-contact attack uses the exact
`res://assets/audio/level_6_breach/level_6_jumpscare.wav`.
The chase vocal keeps directional panning but disables distance attenuation, the secondary
maximum-distance fade and attenuation filtering while chasing; batter/search retain their
normal spatial falloff. The selected chase clip plays at −6 dB against the existing −8 dB score;
the much hotter kill recording plays at −8 dB on Master, outside the ambience dip and through
the existing limiter. Door silence, hiding, stagger, purge, death ownership and scene cleanup
remain guarded. The requested files are reused unchanged. Rendered checks measure the voice
about 8.3 dB above the music at 3.5, 18 and 30 m while facing away. Kill playback and both impacts
peak at 0.826 in the complete output. The strengthened tests failed before the correction.

### Shipped — 2026-09-22 containment approach before the hunt (audited 2026-09-23)

> ⚠️ **Partly superseded by the 2026-09-23 approach redesign above.** Its "no visible creature",
> "No monster silhouette" and "hidden, inactive and silent" rules are replaced there, and so are
> its room table (the first corridor is three rooms now, Damaged is 2.4 m, and the cell is a room)
> and its sequence list. The audit below records the state BEFORE that redesign: the shutter has
> since been built and the one-shot rattle has become the machinery pool.
>
> **Audit against this entry (2026-09-23, reading the code in `breach_approach.gd`):**
> - **Built:** the physical route kept out of the creature's navigation graph, the dormant creature,
>   the bulkhead with its solid blocker, the grace starting at the seal (measured 8.0 s in the
>   playtest log), `static var _hunt_checkpoint`, the back door, and `check_breach_approach.gd` in
>   the suite.
> - **Partial:** the "intermittent" rattle is a single one-shot. The pipework is one duct and one
>   manifold. Every walkable room except Damaged and Containment uses the default wall skin.
> - **Never built:** the bay's cycling pressure shutter (a one-off lamp flicker stands in for it) and
>   a passing wall-overlap sweep.
> - This entry was never closed.

The user requests an atmospheric route before the existing Entry, with no visible creature or
active pursuit. Several connected corridors establish the facility through textures, localized
sounds and environmental details. The final bend conceals the existing hunting wing. Crossing
into the existing start area closes a physical door behind the player and prevents retreat;
only then does the existing arrival grace and flashlight hunt begin. Monster voice, relocation,
contact and patrol must remain inactive throughout the approach. Preserve the fixed Archive B
flashlight and the current hunt/purge/exit layout.

Approved pacing: 60–90 seconds of exploration, with maintenance, observation and damaged
containment passages, without forced waiting or another item puzzle. Approved retry behavior:
after reaching the hunt, death resumes at the sealed threshold. The user approved these choices
and explicitly requires separation from Level 3's Corridor (2026-09-21).

**Distinct identity, checked against `03-corridor.md`:** this is a failed industrial containment
plant, with oversized ventilation plenums, pressure vessels, cable trays, empty inspection bays
and mechanical pressure cycling. No hotel wallpaper/carpet, paintings, grandfather clocks,
mirrors, Manager, running silhouettes, footsteps following the player, bells/keys/false exits,
trap spurs, blind-room puzzle, shut-in escape QTE, or repeating supernatural corridor loop.
The requested final seal is a single containment bulkhead establishing the hunt boundary;
it never traps the player in a side room or requires escape input. Environmental beats come
from visible machinery, with no new panic terms or posture requirements.

Implementation: append a physically connected approach south of Entry using the existing
RoomBuilder; preserve the current hunt room graph for creature routing. Keep Object 12 hidden,
inactive and silent until the player has physically cleared the threshold. Delay its existing
eight-second activation timer until then. A level-local checkpoint survives death after reaching
the hunt and clears for a fresh run; ordinary navigation persists approach completion with the
level snapshot. The old back door moves to the approach entrance. Verify the complete route,
the sealing collider, pre-threshold inactivity, post-threshold timing, retries and a new run.

Sequence:

- Maintenance passage: cold emergency lighting, exposed pipework, an intermittent mechanical
  rattle from a visible loose fitting. The player can move freely and inspect the space.
- Observation passage: dirty observation windows into abandoned equipment bays; a pressure
  shutter cycles mechanically in one bay while the walking route stays lit. No monster silhouette.
- Damaged containment passage: the existing ruptured/organic materials become more prominent;
  a low structural groan leads into a final dogleg, followed by a brief quiet section.
- Threshold: enter the existing Entry, let the player clear the doorway, then close and latch
  a heavy containment door behind them. A physical blocker prevents return. Restore the
  present missing-flashlight objective and start the existing eight-second arrival grace here.

The route must earn its time through distinct spaces, not long identical hallways, mandatory
reading or timed locks. Keep full player control during the sealing beat. The approach needs
readable emergency lighting because the flashlight is still missing. A prototype walk should
measure travel time at the existing 4 m/s walking speed before claiming a 60–90-second duration.
Verification must walk through the physical threshold, attempt retreat against the closed door,
prove no creature sight/audio/contact before entry, and test retries, new runs and return visits.

### Shipped — 2026-09-21 fixed flashlight recovery in Archive B

> ⚠️ **The room and the first-attempt grace below are history.** They are superseded by the
> 2026-09-23 entry above: EastVault; 20 s first, 8 s retry. The pickup mechanics are unchanged.

The player starts without a usable flashlight. Recover it by entering the existing hiding
cabinet in ArchiveB (west wing, z 37.5), always the same cabinet on every attempt. The cabinet
contains a physical flashlight and leaks a faint intermittent beam. Entering collects it once,
leaves the player hidden, and keeps the recovered light off until F. Other cabinets remain
ordinary hiding spots. Existing emergency lighting makes doorways navigable without the torch.
The arrival grace becomes 8 seconds on first and repeat attempts, then normal patrol/detection
hunt the player during the search. Finding the flashlight is not required to activate the purge;
skilled escapes without it remain possible. Before recovery neither F nor the light weapon works.
The objective states the missing flashlight, then returns to the trap/escape goal after recovery.
Ordinary level navigation preserves recovery; death resets it in the same fixed cabinet. Old
already-purged saves imply recovery so completed visits do not demand another search. Use the
player's existing lock/unlock API, with no shared player or hiding behavior changes.
`check_breach_flashlight.gd` walks the western route with physical movement, uses the real E ray
on ordinary and pickup cabinets, checks F and hidden contact, walks the Ward B connection,
and reloads normal/death/older-completed progress. Rendered entry, clue and pickup were inspected.

### Shipped — 2026-09-20 contact kill: Object 12 at the lens

The user approved a more brutal animated kill and matching generated artwork after confirming
the supplied audio works. Only confirmed lethal contact starts this presentation; range, line of
sight, hiding safety and difficulty stay unchanged. `breach_kill_sequence.gd` replaces the primitive door hand / immediate
generic face with a short close-range attack using the actual hollow-crown mesh, skin and rig:
snap toward the attacker, forward surge, clawing grip, two forceful camera impacts, then black.
The built-in image generator produced `object12_kill_closeup.png` from a close-up of the actual
model (`screenshot_breach_reference.gd`); the prompt is retained in `assets_src/textures/level_6_breach/`.
The 1.45 s sequence uses a two-bone reach on each arm, a forward surge, camera recoil/FOV motion,
and impacts at 0.48 and 0.98 s. Brief artwork inserts (0.16 and 0.26 s) animate scale/rotation/shake
at those impacts, returning to the rig between them. HUD and interaction prompts hide during the
attack. A local fill light preserves readability with the torch off. The scene's fatal transition
is reserved before animation, chase audio stops, and the existing Screamer performs one restart
with both its static image and extra sting disabled. `level_6_jumpscare.wav` and `impact_thud`
play during the attack (the selected kill sound replaced the chase scream on 2026-09-21).
Door contact retains a slam on the second impact. The physical player
is no longer dragged into the door collider. `check_breach_kill.gd` verifies real contact/hidden/
blocked controls, rig/camera motion, artwork visibility, a single death/restart, duplicate and
competing callbacks, and stale-scene cancellation. Rendered phase captures were inspected.

### Shipped — 2026-09-20 supplied recordings and layered chase

The user's four recordings are preserved under `assets_src/audio/level_6_breach/`,
with prepared game WAV copies under `game/assets/audio/level_6_breach/`. The chase has two
simultaneous players: a repeating stereo background at the listener and a positional monster
scream (replaced by the requested Backrooms clip on 2026-09-21). `tools/prepare_breach_audio.py` decodes to float, trims trailing silence, folds voices to
mono and normalizes peaks to −1.5 dBFS before PCM conversion; pitch and dynamics are retained.
The background retains stereo and has a 0.35 s crossfade at its loop seam. Calls do not overlap
themselves and leave gaps after completion. Door roars accompany the existing thuds; hiding uses
the supplied search howl without changing AI knowledge. Music stops for door battering, hiding,
stagger, purge, death (including the door grab), loss of chase and scene exit. The supernatural
silent tail cuts both players. Playback gains are music −8 dB, chase scream −6 dB, batter −4 dB,
search −5 dB, with distance attenuation on batter/search only. Chase calls leave 3–5 s after their duration;
search calls leave 5–8 s. Durations: background 14.30 s, batter 6.71 s,
search 4.80 s. The batter recording is interrupted by the existing door silence, not allowed to
extend the door hold. `check_breach_voice.gd` passes 45 checks headless and rendered, including
actual decoded audio from both chase layers, loop wrap, transitions, long-clip gaps,
the real door sequence, hidden safety and scene cleanup. Human listening still judges the mix.

### Shipped — 2026-09-20 second replay: Object 12's voice and door impacts

The user confirmed hiding and the shorter door hold now work, but requested three distinct
monster screams and stronger door presentation. A Breach-owned voice controller uses
three vocal assets (the chase selection is updated above): a chase scream, a door-battering roar
layered with the existing punches, and a frustrated searching howl while the player is hidden.
Voices follow the creature's actual position, with irregular gaps, distance attenuation on batter/search and
one voice at a time. Hidden calls imply searching but never update AI knowledge or damage.
Door voice has priority over chase/search and stops with the pounding for the supernatural
silent tail. Purge, stagger, death and scene exit stop the voice; relocation cannot drag a
playing voice discontinuously across the map. Calls resume naturally from the new position.

Each batter impact also displaces the visible door leaves briefly (recoil, then settle), with
escalating force. The blocker and interaction volumes stay fixed. Impact signals feed the
presentation only; hold duration, blackout timing and the newly-confirmed hiding policy remain.
Real streamed audio, distinct clips, spatial following, silence/stagger/purge suppression,
hidden safety and cooldowns are guarded by `check_breach_voice.gd`; settled and mid-impact
door renders were inspected. The recoil holds its peak 0.05 s so it reads at lower frame rates.

### Shipped — 2026-09-20 hand-playtest follow-up

- **Supernatural door interruption (user-selected).** Breach slam doors hold for a random
  4–6 seconds per batter. Pounding stops for the final 1.2 seconds; after 0.4 seconds of silence,
  nearby room lamps and the player's torch go dark for the remaining 0.8 seconds. The door
  crashes open and light returns immediately. Ambience dips during the silence; body sounds
  remain. The player keeps movement and interaction. Effects are local to a nearby door,
  compose across overlapping doors, and restore on cancellation/scene exit. Other levels keep
  their existing slam-door timings. No panic charge or new death rule.
- **Hiding forgets the player.** Entering a hiding spot before contact clears Object 12's chase
  memory immediately. It wanders toward random reachable rooms away from the hiding room,
  with relocation attempts every 12 seconds of unblocked roaming, only when both departure
  and arrival are unseen. Five body samples check visibility. Hidden player
  coordinates may reject unsafe destinations but never become a search target. Exiting cover
  restores ordinary sight/noise detection, not automatic knowledge of the player. This behavior
  is enabled only for the Breach; the Nightmare's hunter keeps its current contract.
- **Creature depth.** The animated 3D mesh and original skin are retained. The Breach's resting
  emission is 0.025 (shared default remains 0.12). `breach_creature_surface.gd` applies procedural
  normal detail and varied roughness with stronger skin highlights to the duplicated material.
  The flashlight wound response is retained. Matching lit views were rendered before/after;
  the visual judgement remains a human playtest item.
- **Proof.** `check_breach_playtest.gd` drives real E-ray door/locker interactions, checks physical
  door obstruction, samples the timed silence and blackout, and verifies overlapping effects,
  F-off, hiding and scene-removal restoration. It runs 120 simulated seconds of hidden movement
  and searches with nonempty movement/relocation counts. The legacy policy reproduces exact
  hidden-coordinate leakage; `-- --legacy-hiding` makes the guard fail. Render with
  `-- --screenshots` (without `--headless`) for matching creature views and all door phases.

**Level 6 — THE BREACH (Object 12, Loose)** — `level_6_breach.gd` + `level_6_breach.tscn` — a
Nemesis/Mr.X-style pursuit level, direct continuation of KONTUR's facility: Object 12, the subject
KONTUR was built around, is now loose in a deeper containment wing. Built the same
`.tscn`-minimal / `PRESERVE`-whitelist / `RoomBuilder` pattern as `kontur.gd`, from a 20-room graph
(a main spine, west wing through Records/WestHall/ArchiveA–C to the ExitVault dead end,
and east wing through EastLock/WardA/EastVault/EastHall/EastCell, with bypass connections
back into the spine). **The seal room is ExitVault; the exit is in the Incinerator.** Lure the
creature west, seal it there, then return to the spine and its far end. Visual arc
extends KONTUR's two-tier skin system to three: facility → structural rupture → organic decay,
ending at a scorched-steel Incinerator.
- **Door-contact presentation** (original X1, 2026-09-14; revised by the user's 2026-09-20 request).
  `CreatureObject12.death_override` → `_on_contact_death()` now starts the same rigged kill in
  rooms and at doors. `GRAB_DOOR_DIST` 1.5 m still chooses the nearby door for a second-impact
  slam. The old primitive hand and physical player haul are superseded. `check_level6_breach.gd`
  drives the door variant; `check_breach_kill.gd` drives the room variant and safety controls.
- ⭐⭐ **DORMANT MEANS STILL SINCE 2026-09-07.** Object 12 played `shamble` at 0.5x while inactive —
  **0.515 m of hip excursion and a 57.9° arm swing** per cycle, the most mobile clip in the asset —
  while standing **16.0 m dead ahead of the player spawn, heading 0.0°, with unobstructed line of
  sight** through two doorways both centred on x = 0, under its own lamp, inside the torch beam, at
  ~9.4 % of screen height, casting a moving shadow. The level's very first frame was that. It now
  holds a frame of `walk` via `CreatureAnim.hold_pose()`; PATROL already walked and CHASE already
  ran, so the user's three-stage ask reduced entirely to this. ⚠️ **Not `halt()`** — bind pose.
- ⭐⭐ **IT USED TO WALK THROUGH WALLS, AND SINCE 2026-09-07 IT ROUTES.** `_move_toward()` assigns
  `_body.global_position` on a `StaticBody3D`, which cannot sweep or resolve — measured by
  `tests/probe_breach_creature_path.gd`: a chase into WardA crossed the west wall at
  (3.92, 0, 28.75), against a PATROL control of **0 crossings in 899 steps**. **The patrol loop was
  clean only because all five waypoints and every spine doorway are on x = 0**, which is also the
  real reason both bypass loops were unpatrolled — a constraint, not an oversight.
  `set_portals(ROOMS, DOORS)` is the fix: the same graph-agnostic contract as `set_waypoints()`, a
  BFS over the doorway graph, and the next doorway centre as the steering target. **Re-measured:
  0 crossings in 95 chase steps.** ⚠️ **Not a navmesh and not A\*** — 20 axis-aligned rooms and 25
  known doorways. ⚠️ **It falls back to the old beeline** whenever a room or a path is
  unresolvable, and that fallback is what makes it safe for the OTHER consumer: `dungeon.gd` runs
  this same script as the Matron in a GENERATED maze and is deliberately **not** given portals —
  an unfed router must be a no-op. Issue 172.
  - ⚠️⚠️ **THE ROUTER SHIPPED WITH TWO BUGS AND `walk_level6_breach.gd` CAUGHT BOTH** — the level's
    end-to-end win proof, written long before it. Read these before touching `_steer()`; they are
    the two ways an abutting-room graph goes wrong, and neither is visible by reading the code.
    **(b) A point ON a shared wall plane belongs to BOTH rooms.** `RoomBuilder` requires connected
    rooms to ABUT, so `_room_at()` returns whichever room the table happens to list first for a
    point on the plane. `walk_level6_breach.gd` places the player at exactly `z = 55.0` to seal the
    blast door (the collider is 0.15 m thick, so a pose off the plane cannot be hit by the interact
    ray) and the creature — **already inside the trap** — classified that player as next door and
    walked back out through the doorway to reach them. `_steer()` now asks *is the target inside MY
    room, padded by half a wall thickness* **before** asking which room the target is in.
    ⚠️ The general shape: **room membership is not a function at a boundary, it is a choice**, and
    "whichever room the table lists first" is a coin flip that changes when the table changes.
    Issue 178.
  - ⚠️⚠️ **AND THEN (a) TURNED OUT TO BE WRONG TOO — the shipped rule is "aim at the doorway, and
    when you are IN it, aim at the NEXT one".** Pushing the steer point 0.8 m PAST the portal
    un-deadlocks and then walks through the wall *beside* the opening: measured over the room
    graph, **98 of 391 traversals still clipped masonry, worst 2.37 m off the doorway centre**.
    The pad was wrong by the same kind of error — 0.6 m against **0.2 m walls**. These rooms are
    convex boxes, so a segment from any interior point to a point ON the boundary cannot leave the
    room, and one between two boundary points of a convex room stays inside it; aiming at the
    portal CENTRE is therefore exactly what puts the crossing point in the hole. `_steer()` builds
    the whole portal chain and returns the first doorway not yet reached (`PORTAL_ARRIVE` 0.35,
    inside a 1.8 m opening's half-width and far clear of `_move_toward()`'s 0.01 m bail);
    `SAME_ROOM_PAD` is 0.1, half a wall. **Re-measured, 624 traversals over every ordered room
    pair: 0 clipped, 0 failed to arrive, against a beeline control at 431 (69.1 %).**
    ⚠️ **The evidence lesson outlives the geometry one**: the single-traversal probe written
    alongside the first fix reported "0 wall crossings of 176 steps" and was correct about the one
    traversal it measured, on a build clipping a quarter of its routes. **A router is a claim
    about a graph — measure it on the graph** (`probe_breach_router_sweep.gd`).
- ⚠️⚠️ **A FAILED PURGE USED TO FREEZE IT FOR 2 h 46 m, AND THE RUN WAS THEN UNWINNABLE**
  (fixed 2026-09-07, Issue 173, reported as *"I stopped the creature using the flashlight and it
  did not start moving again"*). `freeze_for_purge()` set `_block_t = 9999.0` and
  `unfreeze_for_purge()` cleared it only `if _block_t >= 9999.0` — while `_process()` decremented
  `_block_t` every frame, so 1.2 s later at the confirm the guard was false and the unfreeze did
  nothing. **Every retry re-froze it.** Measured before the fix: 0.00 m of movement at t+2, t+10
  and t+30 s. The freeze is a flag now. ⚠️ `check_purge_interact.gd` drove this exact path and
  **quit before the 1.2 s confirm timer fired**, reporting ALL PASS for the whole life of the bug;
  it now runs past it and asserts the creature afterwards, including the retry.
- ⚠️⚠️ **WINNING USED TO SEAL YOU OUT OF THE EXIT** (2026-09-07, Issue 181). The blast door is
  the only way into the Incinerator, `trap_bounds` is that whole room (z 55…62), **and the exit
  door is inside it at z = 61.85** — and `_finish_purge()` never reopened. The level's own note
  says *"Lead it inside. Seal the door behind it"*, i.e. from PurgeAnte. Measured from the pose
  `check_purge_interact.gd` already presses at: `creature_defeated = true` — **the level is WON** —
  door still sealed, and six seconds of walking at the exit ends at **z = 54.52, 7.42 m short of
  it, for ever.** It now vents after `REOPEN_AFTER_PURGE` 2.0 s; `lure_into_trap()` is permanent,
  so there is nothing left to contain. Re-measured: z = 57.80 and closing.
  ⚠️ **Neither existing test could see this.** `walk_level6_breach.gd` seals from (1.8, 0.1, 55.0)
  — standing ON the doorway plane — so it is never measurably on the wrong side, and
  `check_purge_interact.gd` only drives the FAILED lure, which reopens by design. **"Did the win
  register" and "can the player still leave" are different questions.** `check_purge_softlock.gd`.
- ⚠️⚠️ **CONTACT NEEDS LINE OF SIGHT, AND THAT IS THE OTHER HALF OF THE STUNLOCK FIX**
  (2026-09-07, Issue 180). `_check_contact()` was a pure horizontal distance test, harmless only
  while `force_block()` suppressed the whole state dispatch — so lifting that suppression re-armed
  a check nothing else was holding back. Measured: player at z = 41.45, creature at z = 40.90, a
  **closed, battering slam door between them**, separation 0.550 m under `contact_dist` 1.0 — and
  it killed. A 0.4 m capsule cannot stand further back, so slamming a door in its face was a death
  sentence rather than the counter-play. It now requires `_has_los()`, the helper `_detect_player()`
  has always used. ⚠️ **Ship both or neither**: live contact stops the stunlock, the LOS term stops
  it reaching through steel.
- ⭐ **THE DOOR-SLAM STUNLOCK IS CLOSED** (Issue 176). `force_block()`'s early return sat above the
  whole state dispatch, so a battering creature could not kill you at any range and a stagger
  caught by a door silently gained 10 s; `check_blocks_path()` had no proximity term, so a door
  25 m away stopped it in open floor; and E could re-close a door the frame it broke open. Now:
  contact and the stagger clock both run during a block, battering needs the creature within
  `BATTER_REACH` 4 m, STAGGERED is excluded alongside PATROL, and a broken door will not re-latch
  for `RESLAM_COOLDOWN` 8 s. ⚠️ The proximity gate and the live contact check ship **together** —
  the first is what makes the second fair.
- ⭐ **ALL SEVEN DOORS LOOK LIKE ONE SET SINCE 2026-09-07** (the user's *"make sure all the doors
  look the same"*). The **PurgeChamber was the only untextured door in the game** — a flat-tinted
  `BoxMesh` at metallic 0.7 beside six doors carrying `breach_door.png`, on the level's win
  condition, and invisible to `check_art_aspect.gd` by construction (Issue 175). It now carries the
  same plate on `QuadMesh`es, both faces, cropped by `crop_uv_to_fit()`. One emission rule —
  **MULTIPLY at 0.08 everywhere**, replacing `door.gd`'s default ADD which laid a flat wash over
  the whole leaf — with the **red tint kept exclusive to the exit and back doors**, because
  red-means-exit is a game-wide convention and this is the level you are chased toward one in. One
  architrave profile (`slam_door.gd`'s jamb 0.08 / depth 0.26 / metallic 0.3) on the exit casing,
  and **the nine bare `RoomBuilder` openings are framed too** — built in `level_6_breach.gd`, never
  in `RoomBuilder` (shared by five levels), and with **no colliders**.
- **During the 8 s arrival grace the creature is inert.** While dormant it cannot see
  (`_detect_player` never runs), cannot hear (`notify_noise` returns early), cannot be hurt
  (`apply_light_damage` returns early) and cannot kill (`_contact` returns early) — and
  `activate()` permits contact on the very next tick. `backlogs/06-breach.md` C2.
- **Arrival grace** (level-owned): Object 12 stays dormant at Junction1 until the timer elapses,
  then activates for the rest of the run. **`FAMILIARIZATION_FIRST = 8 s` and
  `FAMILIARIZATION_RETRY = 8 s`** (2026-09-21) let the player orient at the entrance while
  leaving the flashlight search under threat. This replaces the previous 30/10-second waits.
- **`creature_object12.gd`** (`class_name CreatureObject12`) — a five-state machine
  (`PATROL → INVESTIGATE → CHASE → SEARCH → STAGGERED`), structurally descended from
  `creature_stalker.gd`'s build pattern (`ScaryObject → StaticBody3D → CollisionShape3D`, GLB
  load/arm-pose) but reusing `hollow_crown.glb` **retinted** via `CreatureAnim.apply_tint()` (sickly
  grey-green, with the Breach surface pass described above) rather than a new 3D asset.
  **CHASE follows the player through the doorway graph regardless of gaze** — the opposite of `creature_stalker.gd`'s
  "freeze while observed" rule, which would let a persistent chaser be cheesed by simply staring at
  it. Losing sight of an exposed player enters `SEARCH`, walks to the last-seen position and scans
  there for `SEARCH_TIME=8s`. (⭐ Since pass 5 the Breach's creature keeps WALKING to neighbouring
  rooms through that 8 s instead of standing, and the same give-up/relocation follows; the Matron still
  scans in place.) **Entering a hiding spot instead clears that memory and starts
  random wandering**, per the 2026-09-20 user ruling above. `CHASE_SPEED=5.0` sits
  deliberately between the player's walk (4.0) and sprint (6.4) — beatable only by sprinting, which
  costs `SPRINT_PANIC_RATE`. ⭐ **The Breach runs it at 5.5 since pass 4** (`BREACH_CHASE_SPEED`, the
  user's call), still under the sprint. Contact within `CONTACT_DIST=1.0` is **instant-fatal**.
  ⚠️ The FOV/facing check is deliberately **horizontal-only**: dotting the creature's (horizontal)
  facing against the *full 3D* direction to the player mixes in the CHEST(0.9)-vs-eye-height(~1.65)
  vertical gap, which can fail the dot-product test regardless of facing once the gap is a large
  fraction of a close-range distance — found by `tests/test_creature_object12.gd`, where a SEARCH
  scan converging on the stub player produced exactly this false-blind result
- **Light-as-weapon** (`apply_light_damage()`, driven every frame by `level_6_breach.gd`'s
  `_tick_light_weapon()`, which owns the geometric "is the player aiming a lit flashlight at it
  within FOV+LOS" check — the creature script itself stays graph/geometry-agnostic): available
  only after recovering the flashlight from Archive B. Sustained aim
  drains a `SHIELD_MAX=100` pool at `SHIELD_DRAIN_RATE=40/s` (~2.5s to empty); hitting 0 drops it
  into `STAGGERED` for `randf_range(STAGGER_MIN 5, STAGGER_MAX 7)` s — a **temporary repel, not a
  kill** (shield fully regenerates on recovery). ⚠️ **Draining and staggering both require
  `State.CHASE`** (BACKLOG #26, confirmed with the user: you can only blind it while it is actually
  chasing you). Previously the drain happened in every state while the stagger could only fire from
  CHASE/INVESTIGATE, so lighting up a patrolling or searching creature emptied the whole pool for no
  effect — indistinguishable from a blind that lasted no time, which is exactly how it was reported.
  `recovered` is now connected (it never was), so the end of the stagger is announced.
  `creature_stalker.gd`-style FOV/raycast code, but the CHASE *behavior* is intentionally not
  reused (see above)
- **Hiding** (`hiding_spot.gd`, 8 lockers/cabinets/desks spread across the rooms, never two in the
  same room): walk up + press E to hide/unhide — the existing `_try_interact()` path, no new input
  action. `player.gd` gained `enter_hiding()`/`exit_hiding()`/`is_hidden()`: movement blocks via the
  existing `_input_frozen` flag, but look is exempted and clamped to a ±55° peek cone
  (`_rotate_camera`'s `_hidden` branch) instead of the full range. The
  creature's own `_detect_player()` short-circuits `false` whenever `is_hidden()` is true.
  The Breach also clears chase memory before movement/contact and refuses hidden contact;
  merely suppressing sight was insufficient while relocation copied the player's position.
  - ⚠️⚠️ **THIS ENTRY CLAIMED FOOTSTEPS WERE "silenced for free by the existing `_is_moving`-gated
    chain — no separate suppression flag needed" AND THAT WAS FALSE** (corrected 2026-09-07,
    Issue 179). `_handle_footsteps()` needs only `_is_moving and is_on_floor()`, and
    `_apply_movement()` returns on `_input_frozen` ABOVE the line that recomputes `_is_moving` —
    so the flag latched `true` for anyone who **walked** to the locker, which is everyone, and a
    player hiding from a creature that hunts by noise broadcast footsteps the whole time. The
    same early return latched `_is_sprinting`, which is the worse half: **+6 panic/s standing
    still, decay suppressed, dead in 6.1 s**, and fatal to a HOLD apparition or a Smiler. Both
    flags are now cleared in both early returns. The claim was written from the code's intent and
    never measured; `check_frozen_sprint.gd` measures it.
- **Door-slam** (`slam_door.gd`, 6 interior doors at chokepoints, never on a dead-end): press E
  while passing through to slam it shut; `level_6_breach.gd::_tick_slam_doors()` scans every frame
  whether a closed door lies on the creature's path to its current CHASE/SEARCH/INVESTIGATE target
  (`check_blocks_path()`, a segment/AABB test) and calls `start_battering()`, which pauses the
  creature's movement (`force_block()`, any state, no state change) for a random 4–6 seconds,
  including the supernatural interruption above — a temporary delay, not a permanent block.
  `breach_door_scare.gd` restores torch influence via its light cull mask, preserving F-off and
  hiding's brightness ownership; both level audio beds dip 32 dB during the nearby silence.
  Deliberately **not** built on
  `door.gd` — its `UnlockCondition`/`extra_lock` machinery is irrelevant baggage for a non-exit door
- **The Purge Chamber** (`purge_chamber.gd`, one-shot, at the ArchiveC↔ExitVault threshold) — the
  **only permanent win condition**. A heavier blast-door escalation of `slam_door.gd`; `interact()`
  slams it shut, then confirms the creature's **actual** position against a world-space
  `trap_bounds` AABB (never a flag) before running the purge sequence (reuses `acid_hiss.wav` from
  `level_5_kontur` — `GameState.load_audio()` already scans every subdir, no file copy needed) and
  calling `creature.lure_into_trap()` (permanent). A mistimed lure just re-opens the door with a
  toast ("IT ISN'T IN THERE") — retryable, not a run-ender
  ⭐ **Since pass 4 (2026-09-23) the slam is a RACE while `SEAL_RACE` is on:** E held grinds it shut over
  1.25 s, a creature inside charges after 0.8 s, and one that reaches the doorway first jams it open. See
  the pass-4 entry above; `SEAL_RACE := false` restores the instant slam described here.
- ⭐ **THE EXIT AND BACK DOORS ARE REAL DOORS NOW (2026-09-03).** They were a hand-rolled
  `BoxMesh(1.0, 2.2, 0.15)` at albedo (0.15,0.01,0.01) with emission ×**1.5** — verbatim the
  UNTEXTURED branch `door.gd:26-40` documents as the "red brick" fallback it was superseded by —
  and this file has `preload`ed `door.gd` since the day it was written and simply never called its
  builder. ⚠️ It escaped `check_art_aspect.gd` for the same reason it looked wrong: **a prop with
  no texture has no aspect to be stretched**, and `level_6_breach/` had no door texture at all.
  Now `build_visual()` + `breach_door.png` (`tools/make_breach_door.py`, cropped off the generated
  plate's own floor and surround), plus a `_build_door_casing()` architrave so the leaf reads as
  seated rather than as a poster. ⚠️ The casing is **siblings, never children** (`door.gd` frees
  and flashes the leaf) and has **no colliders** (a collider on the only doorway wall is how this
  project seals a room by accident).
- ⚠️ **`PurgeChamber`'s frame used to poke through the ceiling** — jambs 3.1 m and a lintel topping
  out at 3.11 m in 3.0 m rooms, with both jambs buried in the wall beside a 2.2 m opening. Fixed;
  `check_wall_overlap.gd` forgives a prop INSIDE a slab by design (a flush fitting looks the same),
  which is why it never reported this.
- **Exit lock**: `_exit_door.extra_lock` stays true until `PurgeChamber.creature_trapped` flips a
  single `_creature_defeated` flag (this level needs one boolean, not KONTUR's eight-gate ledger),
  mirroring `kontur.gd`'s `_refresh_exit()` pattern
- **Fail economy**: deliberately **no** `DreadZone`/`DarkZone` and **no** additional trap props — the
  level's identity is the chase itself; the existing sprint-panic economy already supplies the
  "escape costs something" pressure. Fails: creature contact, panic bar fills (standard system)
- **Audio**: `ambient_breach.wav` (procedural, primary `AmbientPlayer` bed, `-8dB`) plus a secondary
  layer at `-14dB` mirroring `kontur.gd`'s optional `kontur_music` node — this is where the
  user-provided `mystical_sound.mp3` lives (as `ambient_breach_layer.mp3`), deliberately **never**
  the primary bed since an arbitrary sourced `.mp3` isn't guaranteed loop-clean. SFX generated by
  `tools/make_sfx_level6.py` into `game/assets/audio/level_6_breach/`. The separately controlled
  chase background and three supplied creature voices follow the 2026-09-20 entry above.
- Win: lure Object 12 into the Purge Chamber and seal it. Fail: creature contact, panic bar fills

## DECISIONS & GOTCHAS

**2026-09-23: pass 4, the user's calls, and what the renders changed.**
- **The user's words set every item** (grilled one at a time):
  - The shutter: *"Maybe the face of the creature should appear behind this room which first opens and
    then closes?"*, and they chose **a quiet stare** over "the face slams in". It first shipped on a
    looked-at cycle after an empty one; **the user reversed it 2026-09-24**: the first opening shows
    it (on the look), and never again.
  - The sudden scare: *"there should be at least one place where the element of unexpectedness and
    suddenness will make the player scared … besides this hand"*, and they chose the dragged victim
    dropping from the ceiling, triggered by position, with no panic.
  - The technician: *"way too unrealistic … it looks very 2d now"* and *"what for to keep the handle
    just besides the door"*, and they chose him fused into the wall on the Plenum's far side.
  - The music: the user's own track, for the walk-in only.
  - The hunt: *"Ins't it a bit too simple now to win the creature? Maybe make it just slightly harder"*,
    and they chose chase 5.5 m/s plus the seal race, the race behind ONE switch: *"make this feature
    easily irreversible, it is likely that after testing it I will say to restore it back"*.
    `SEAL_RACE := false` restores the instant slam exactly, and `check_breach_seal_race` asserts it.
- **The race's two times are the tuning rule's, measured, not guessed.** The rule was "succeeds when
  lured deep (the back half), fails near the doorway". 1.25 s / 0.8 s puts the line between 3.25 m
  (jam) and 3.5 m (shut) of a 7 m vault. ⚠️ The sweep stages the creature **facing the doorway** at the
  press, its best case; a creature caught facing away turns first and the player gains time.
  ⚠️ Changing `BREACH_CHASE_SPEED` moves this line: re-run `check_breach_seal_race.gd -- --sweep`.
- **The jam holds it only for the door's own 0.4 s swing** (`force_block(REOPEN_TIME)`), then it is
  loose and chasing. That is an open question for the user (a longer stagger would make a jam a second
  chance rather than a punishment).
- **"Hold E" is named on the prompt.** The old door taught a single tap; a tapped race door budges and
  rolls back, which reads as broken without the words. The prompt only changes with the race on.
- ⚠️⚠️ **THE FACE WAS ON A LAYER THE CAMERA CULLS (found by the first render, Issue 270).** The pass
  used `1 << 19` after the hand's 17 and the grille's 18. That is render layer 20, `player.gd`'s
  `MIRROR_ONLY_LAYER`, which the player's camera removes from its `cull_mask`. The face was revealed,
  visible, lit by a fill culled to its layer and passed every state check, and the render was an empty
  niche. It is on layer 17 (`1 << 16`) now, and `check_breach_pass4` asks the camera.
- **The level's ambient lights every layer.** A layer-culled fill cannot stop `_boost_ambient(0.28)`, so
  the face puppet's body stood grey in the black niche. Its albedo is ×0.3 and the fill ×3, so the
  ambient term sinks while the face keeps its light.
- **The drop needed its own light.** The only lamp near it is on the wall side, so the first render was
  a flat black shape. The work lamp tangled in the chain is on the lane side, swings with him and casts
  shadows.
- **The growth took three builds, all from reading renders.**
  - Glossy spheres and straight capsules in the Breach's organic WALL texture read as black balloons on
    sticks, radiating like a sea mine.
  - Matte lumps and jointed vines read as brown coins and insect legs.
  - What reads: a flat roots decal on the wall, a mound of many small lumps, a few drooping vines, all
    in one drawn tendril texture in the relief's palette. ⚠️ Radiating 3D sticks are the thing to avoid.
- **The user's two corrections after watching the renders run** (2026-09-23):
  - *"I do not hear the music I sent you, I hear just the sound of the corridor … not too silent and not
    too loud."* The first gain (−17 dB) was ARITHMETIC against the vent's LUFS and the comment beside it
    even said "4 dB under the vent bed". It is now set from a recording of the mix at the listener
    (`probe_breach_music_mix.gd`, Issue 271): music +3.5 dB over the beds between beats, the voices
    ≥ +6 dB over the ducked music. ⚠️ Re-run the probe after any change to a bed, a PA line or the music.
  - *"I do not see the wheel very clearly in its arms. Can you make it more realistic and make it even
    more adjacent to the wall? Think about it."* The item became the WHOLE valve wheel (the door has a
    bare spindle), he became life size (the old relief made his head 0.57 m across), the relief moved to
    the wall plane with growth over its edges, and a caged lamp above him lights him. The body art was
    not regenerated (no flux quota); see the as-built text.
- - **2026-09-24, pass 5, in the user's words:**
  - **"It is either contained and you can get out or you get killed."** The first outcome wins. The
    playtest's double outcome (killed at 314.58, SEALED at 316.93, then the restart) was the player
    killed INSIDE ExitVault while their held E ran the close on, and the purge's timers finished the
    win under the death (Issue 272).
  - **"Change nothing about this, the only thing I wanted is to avoid the situation when the object is
    not moving at all before teleporting."** Only the arrival behaviour changed, gated on the Breach's
    flags; `SEARCH_TIME`, `HIDDEN_RELOCATE_INTERVAL`, detection and relocation did not move (Issue 273).
  - **"Take the wheel button is not active at first. Let's make it active straight away"** and
    **"after we press an E something like a scream of this man should appear, followed by this 'Don't
    go in there'".** The victim scene ducks rather than gating him.
  - **Difficulty is kept as it is** (the user's call): chase 5.5 and `SEAL_RACE` on, with 5 deaths in
    the playtest, 4 of them inside ExitVault. Do not retune them from this playtest.
  - ⚠️ The open eyes at 1.5 m are small: a life-size face's eyes are ~3 cm, and the game renders 3D at
    half scale on HiDPI. The scream now carries the moment; the eyes open visibly but subtly.
**2026-09-24, three more of the user's calls:**
  - **The technician is the user's own art.** The user generated five candidates with flux and chose
    D (a realistic technician pressed into the wall, swallowed below the waist, hands in an empty
    grip); A, B, C and E are kept as raws. The spread and flesh textures are the user's too, replacing
    the Pillow-drawn ones.
  - **"A man holding a wheel looks very two D. Can we make it more three D?"** A flat relief plus a
    normal map was not enough, so he is a **bas-relief mesh** displaced by a height map.
    ⚠️ The height map is built from **capsules measured on the art**, not from a distance transform of
    a colour-classified body mask: that first attempt classified shadowed skin as growth, left the
    face 4 cm proud and the chest a jagged "F", and a chessboard erosion distance stair-stepped every
    edge. ⚠️ No hard mask may multiply the height (a cut at a hole or the silhouette is a cliff the mesh
    shows edge-on); the alpha scissor decides what is seen.
  - **The shutter face reversed**: *"now you can see the creature the second time the door opens, and
    the first time it opens you cannot see it. Let's make it vice versa."* The first opening shows it,
    and waits for the look so it is never wasted.
  - **The wheel sits at the fists' displaced depth**, its tube sunk into their curl, so the painted
    fingers close over it. It is smaller (0.105 m) because it has to pass through both painted fists.
  - ⚠️ **The painted-hand eyes-open composite** transplanted the staring eyes of the old flux raw first;
    lit for another face they read as pasted on, so the open eyes are painted in D's own skin light.
  - ⚠️ **3D tendrils must lie on the surface.** The first ones ran out across the floor and stood off
    the wall like spider legs; now three thin ones follow the displaced relief and the wall to the floor.
- **The flesh texture was drawn in Pillow, not generated** (superseded 2026-09-24 by the user's tile). The Cloudflare flux quota ran out mid-pass.
  If the user wants a photographic flesh surface, re-generate `approach_growth_flesh.png` (tileable)
  and nothing else changes.
- **The music carries the approach's own silence duck as well as the bus dip.** `HoldBreath.dip()`
  refuses a second dip while one is running, and the vent already worked this way.
- **The music check measures the duck against the music's own idle level.** A threshold built from
  `MUSIC_STORY_DUCK` read back stayed green with the duck set to 0.

**2026-09-23: pass 3, the user's calls, and what the renders changed.**
- **The user's words set every item.**
  - The grille: *"should we see some kind of a real monster through it?"*, and they chose its back and
    crown battering a door, over a shadow only or plain machinery.
  - The door: *"put some effort to get in … something different"*, and they chose a wheel missing its
    handle, held by a dead technician, over a pry bar or a wheel alone.
  - The dark room: *"completely dark … No jumpscares but the panic will rise"*, and they chose a
    sparking junction box over a red beacon or truly black, with panic capped at ~42/50 and no
    DarkZone.
  - The bodies: *"seem alive for some moment and tell not to go there"*, and they chose the grip, the
    eyes and the whisper on the technician; the chamber's bodies are dead only.
  - Not chosen: an in-world or fullscreen video corpse, cell concepts B and C, an announced spawn.
- **The two rules this reverses, both at the user's word:** "exactly ONE glimpse" (now two; three since
  pass 4), and "no
  item puzzle" (now the handle). **"No new panic terms" is reversed for the dark room only**, and the
  term there is capped so it cannot kill.
- **The technician waits for the story channel** (⚠️ reversed by pass 5 at the user's word: he answers
  at once and the victim scene ducks instead). A straight walk reaches the door while the victim
  is still hammering behind it, and the whisper under the roar was inaudible. He answers when the drag
  has gone, ~11.5 s after the door is reached (pass 4 moved him to the far wall: ~7.2 s after his wall
  is reached). ⚠️ If that wait reads as a broken prop, the lever is to
  start the victim earlier (in Damaged), not to un-gate him.
- **The wheel reads the MOTION's direction, not a position.** A position-based virtual hand needs the
  circle drawn round a centre the player cannot see; the motion vector's direction turns 2π per loop of
  any size, anywhere on the pad.
  - ⚠️ **The first build threw away every turn above the rate cap, and that was frame-rate
    dependent.** Headless runs several `_process` frames per mouse event, and 60 % of each circle was
    lost (1.85 rad in 2.5 s). The excess is now carried in a 0.25 rad bank.
  - The same mistake would have hit a player on a fast display.
- **Every render drove a fix.** Six were read as images before the numbers above were taken:
  - **The grille creature was a sliver at the aperture's edge.** The line of sight runs diagonally
    north, so it and the door moved 1.7 m north.
  - **Its dark body vanished into a dark door at each blow**, so the door is pale steel now.
  - **Its rim light kept its back glowing in the "dark"**, so the rim dies with the lamps.
  - **The housing was a black column**: metallic 0.55 with nothing to reflect. It is matte mid-grey
    now.
  - **The technician was a black silhouette, eyes and all.** He was turned away from the door lamp;
    he is now turned toward it (+0.6 rad) with a shadowed fill. After that the eyes-closed and
    eyes-open frames read clearly different.
  - **The Containment side of the collapse showed a see-through gap** beside the ducts, so a buckled
    panel fills it.
  - **The bodies and the vial rack were unlit.** The chamber got a 2.1 lamp plus a second fitting,
    and the spark light's range went 9.5 → 12 m.
  - **The junction box's cover threw a wedge of shadow across half the ceiling**, so the cover no
    longer casts shadows.
- **The door lamp casts shadows**, on purpose; so do the technician's fill and the spark light, and no
  other approach light does. A 6 m omni over the door lit
  the dark room through the wall, because approach lamps cast no shadows. A spot aimed away missed the
  technician.
- **The render script's own bug:** its waits counted frames at 60 fps. The windowed render runs faster,
  so a "16 s" wait expired in 8 s, and the technician was pressed while still (correctly) refusing.
  Real-time waits now.
- ⚠️ **`check_breach_approach`'s "panic exactly 0 on every frame" had to change.** It is now 0 before
  the dark room, ≤ 42 inside, and non-increasing after. The dark room's cap is PINNED at 42 in
  `check_breach_porthole`, never read back from the constant, so an edit to the constant cannot move
  the goalposts.
- **The checks can fail, proven with deliberate breaks, all reverted:**
  - Colliders off, the collapse's seal off, the cap 42 → 46, the technician un-gated, and the wheel's
    drift at 0 turned 9 `check_breach_porthole` checks red.
  - The grille puppet never freed, plus the dark-room panic applied in the Plenum, turned 3
    `check_breach_approach` checks red.
  - Removing the porthole gate from `check_reachable` made 17 of 20 Breach interactables unreachable.
- **The shared cell, placed (after the KONTUR agent's build landed).**
  - ⚠️ **The reserved spot had the wrong turn.** It was set up at −PI/2, assuming a +z front, but
    `ContainmentCell`'s front is local −z. It would have shown the player its gouged back. It is +PI/2,
    the same as KONTUR. `check_breach_porthole` asserts it (turning it back to −PI/2 turned 2 checks
    red).
  - **The glass was not doubled.** The tank throws 102 shards across almost exactly the patch where
    this file had laid 90 of its own and 5 slabs. The approach's were removed, and the crunch zone now
    follows the tank's field.
  - This file's residue trail was moved clear of the tank's drain stain, so no two floor layers of
    different owners lie a few mm apart.
  - The test names the cell by script path, never `is ContainmentCell`. Naming the class compiled it
    under `--script` before the autoloads existed, and its `GameState` failed to compile (Issue 82).
- **Placeholders, all at fixed paths the user's files replace:** twelve audio files and one video. They
  are listed in `docs/TODO_sounds.md`.

**2026-09-23: the legibility pass, candidly.** Every item was judged from renders read as images, and
some read better than others:
- **The hand reads.** At native resolution in `11a`, a long bony forearm and a hooked, splayed claw
  show dark against a lit tile patch, beside the hanging grille.
  - It is still small in a full frame, because this creature's arm is thin.
  - "Fingers hooked over the hatch lip" was not possible with a one-bone hand. The wrist flex is the
    hook this rig has.
- **The cell reads from the east side** (`10a2`): the doorway opens onto the red-lit cell, and the
  plate shows three ragged holes and a seam. Inside (`10b`), the restraints, straps and pool are
  visible.
  - **From the west** (`10a`, the way the player arrives), the hanging leaf is still a dark
    rectangle. That was not in the contract, and it is noted for the playtest.
- **The residue pools are hard, bright discs now.**
  - At ~4 m (`04d`), a wet residue front sits on the rim of the lit floor. That is the rule, and it
    reads.
  - At ~6 m (`04c`), the hard pool edge reads strongly but the residue fronts are small. The dark
    stretches between pools remain dark, by design.
- **The lintels read as steel headers** in `13b`–`13e`. `13a` is marginal because the room beyond is
  unlit in the staging; in play it is lit, since the player has just walked through it.

**2026-09-23: the approach redesign, where the build departs from the planned text, and why.**
- **Two jogs, no strip curtains.** The planned text allowed either. Three 3.6 m legs abutting on the
  z −65 plane mean every leg ends in a wall 17–22 m ahead with the next opening to the side, so the
  far end is never in view without a see-through prop.
- **The self-waking lamp fires at ~26 m of route, not ~40 m.** After the jogs, the only straight view
  of about 20 m is down ServiceJog. It fires as the player turns into it and looks (dot ≥ 0.7), or by
  x > −73, with the lamp 19.5 m ahead. It holds 2.0 s. `MOTION_RADIUS` is 5 m, so a cluster lights
  about one second before you reach it. On the first render the lamp's pool was faint at 19.5 m, so it
  runs at energy 1.2 / range 10.
- **The glimpse fires at ≤ 7 m, from a hatch 6.5 m past the corner.** *(Superseded by the legibility
  pass: at ≤ 5 m it fires at 4.27 m, and at ~6.5 m the hand still read as a cable.)* The first render let it fire at
  up to 12.5 m. It fired at about 10 m, where a creature's hand is a few pixels: a speck, not a hand.
  - The shoulder sits at 2.2 m inside the duct, so about 0.6 m of forearm and hand hangs below the
    duct floor at eye height.
  - The walk pose laid face-down points the forward foot straight down. The second render showed a
    clawed foot through the duct floor, reading as a second hand. Both legs and the other arm are now
    solved flat inside the duct.
  - The Containment's east lamp is 5.5 m range, not 7.5. Approach lamps cast no shadows, so it lit
    the duct's end cap through the Threshold wall into a red panel.
- **The Observation's lighting took three renders.** *(The legibility pass above pushed it further:
  energy 7, a hard edge, doubled fronts.)*
  - Spots alone, with the old omni lamps removed, left the dark stretches black and the residue
    invisible.
  - Residue kept a metre clear of the light was never lit at all.
  - What shipped: spots at energy 4, a weak omni beside each, the bay windows spilling light into the
    dark stretches, one wet smear per pool side whose front reaches into the penumbra, and roughness
    0.25 on the residue so it catches what light there is.
  - It is still a dark room. Whether the rule reads is in NEEDS A PLAYTEST.
- **The cell is a room (ApproachCell12), not a black panel.** A door bent outward needs depth and
  darkness behind it to read (Issue 35). *(Superseded by pass 3: the bent door is gone and the room is
  the enlarged chamber the route passes through.)*
- **Lintels on every height step.** They were built first on Damaged's two doorways, because dropping
  it to 2.4 m made those steps 1.0 and 2.8 m. The legibility pass added the other four, once they were
  approved.
  - They are solid: a mesh-only lintel let 55 rays leak (`check_shell_sealed`).
  - They are steel: a black one against an unlit room read as the void it fills.
- **One story channel, not a timeline.** At 4 m/s the victim sequence (12.3 s blocking plus a 4.3 s
  drag tail) spans the Plenum and most of Containment. Queued beats let PA line 3 wait for it rather
  than talk over it, and a lingering player loses nothing.
  - Measured on the straight walk: arrival 0.2 s, PA1 3.3, self-waking lamp 8.0, door tell 19.8,
    shutter 26.9, smashed lamp 28.4, PA2 30.9, grating 44.8, knocks 46.8, crawl 48.8, victim 51.9,
    PA3 64.8 (queued 0.5 s behind the victim), Threshold quiet 68.4.
  - The glimpse fired at 70.6 s, after the test's negative control had stood facing away.
- **Everything else as planned:**
  - KONTUR's chime before PA line 1 only; the failing system does not chime.
  - The smashed lamp's sputter is the mapping's "and the smashed lamps" use of `lamp_off_break`, at
    −12 dB.
  - The Plenum door lamp flickers on the roar; it does not break. Breaking it was not specced.
  - The thump reuses `impact_thud`, the contact kill's own impact, on purpose.
- ⚠️ **Two checks written for this pass could not fail until they were broken on purpose.**
  - "Is every speaker's bus a bus that exists?" stays green with the bus renamed to "SFX", because
    `AudioStreamPlayer.bus` reads back "Master" for a nonexistent bus (Issue 267). The check is now
    positive: the machinery layers must REPORT Ambience.
  - "Is the puppet freed?" was asked after the seal, and the seal frees it anyway. It is now asked on
    the frames right after the withdraw.
  - With five deliberate breaks in place (the shutter trigger removed, the free removed, the gaze gate
    removed, the bus renamed, panic injected), six checks went red.
- **What the full suite caught after the approach test was green.** Each item below is fixed:
  - **`check_shell_sealed`: 55 rays escaped at 2.8 m.** Damaged's lintels were meshes only, so they
    hid the gap above its 2.4 m ceiling without closing it. They carry colliders now. At 2.36 m and
    up they cannot touch a 1.8 m player; `check_doorways` still reports 0 blocked.
  - **`check_art_aspect`: stretched art.** The tape was 1.48× and the residue 1.11×, from typed
    sizes. Every approach decal now DERIVES its height from its texture. The bulkhead leaf's
    `breach_door.png` had been 1.436× since the approach shipped; it now takes the purge chamber's
    `crop_uv_to_fit()`. That one is outside A1–A15, flagged in the backlog.
  - **`check_fixtures`: a false waiver.** Its Breach row said "no fitting mesh", and that had been
    false since 2026-09-22, when the approach's lamps got housings. The row is measured now: 29
    fittings at load, none above emission 1.0, floor 24.

**2026-09-23: flashlight placement and grace, reversed on purpose.**
- **Placement.** On 2026-09-21 the user chose a middle-area cabinet (ArchiveB). On 2026-09-23 they
  reversed that:
  > "the flashlight should not be the same place where you need to seal the monster … they need to be
  > at different parts of the level".

  The 2026-09-22 log measured a 49 s hunt with 0 deaths, contaminated by a briefing that named the
  cabinet. Candidates considered:
  - EastCell: only ~20 m from the purge via WardC.
  - EastLock: ~21 m from the start and 7 m from the creature's spawn, so it's collected before the
    creature wakes.
  - EastVault: chosen.
- **The torch hint.** The user declined a hint in the approach (a technician's "…the east lockers—")
  and declined a wayfinding sign.
- **The grace.** The user chose 20 s over 12 and 15. This knowingly undoes the 2026-09-21 reason
  below, "the former first-attempt grace could outlast the entire direct walk to the item", for a
  first attempt only. Do not re-tighten it without the user.

**2026-09-23: the double walls were caught by a guard nobody ran.** `check_wall_overlap.gd` would have
failed the approach on the day it was built. Closing a spec entry is when that sweep gets run, and the
2026-09-22 entry was never closed. That's why the rule above says a change is not finished until its
spec says so.

**2026-09-21 fixed placement.** (Superseded 2026-09-23; kept for its reasoning.) The user chose a consistent middle-area cabinet. Archive B
requires a detour, connects to both the western loop and Ward B, and reuses safe hiding instead
of adding a vulnerable search animation. Collecting never forces the player to emerge or turn
on the torch. The former first-attempt grace could outlast the entire direct walk to the item;
eight seconds leaves orientation time while making the search a hunted phase. The purge remains
usable without the flashlight; recovering it after sealing preserves the escape objective.

⚠️ **Dated ⭐ entries live at the TOP of SPEC, not here.** They carry the level's *current* state and
override the older prose beneath them — that is how `CLAUDE.md` was written, and why entries say
things like *"every paragraph below that says 320 m is history"*.

⚠️ **The top-to-bottom order is NOT strictly newest-first.** Measured 2026-09-19: `01-lab.md`'s
2026-09-13 entry sits *above* the 2026-09-14 entry that reverts it, and `04-backrooms.md:302` sits
*below* the same-day entry that supersedes it. **Read the dates; where they tie, read the code.**

Use this section only for rationale that leaves **no trace** in the level — something tried and
abandoned. Anything describing what the level *is* belongs in SPEC.

**2026-09-20 ruling.** The user rejected the repeated cabinet-return loop and chose supernatural
interruption over physical door destruction. The old search-memory tension rule no longer applies
after successful hiding. No panic tax, forced camera turn, new pursuer or new death path was added.
The material pass keeps the existing mesh/skin; its realism still needs the user's judgement.

**Supplied recordings.** The chase MP3 decodes above full scale in float (peak about +19.77 dBFS);
direct int16 conversion would clip it. Normalize before conversion, never after. Keep the original
MP3/WAV files unchanged for future editing. The old procedural generator now writes only into
`assets_src/audio/level_6_breach/procedural_archive/`, preventing accidental replacement of the
user's search or batter sounds. New supplied recordings are prepared by `tools/prepare_breach_audio.py`.

### Superseded (moved out of SPEC verbatim, 2026-09-19 audit)

**1. The first portal-router fix — `PORTAL_PUSH` 0.8 m past the portal.** Superseded by SPEC's
*"AND THEN (a) TURNED OUT TO BE WRONG TOO"*: `PORTAL_PUSH` no longer exists in
`creature_object12.gd`, which aims at the portal CENTRE (`PORTAL_ARRIVE` 0.35, `SAME_ROOM_PAD`
0.1). Kept because it is bug **(a)** of the two the "THE ROUTER SHIPPED WITH TWO BUGS" entry
above still names, and the deadlock it measured is what the centre-aiming rule has to keep solving.

    **(a) Steer THROUGH a portal, never AT it.** `_steer()` returned the doorway's own centre;
    `_move_toward()` bails once its target is within 0.01 m and `_room_at()` still reports the room
    the creature started in, so it re-picks the same portal for ever and stands on the threshold.
    Measured: parked at **z = 54.99995 against a trap boundary at z = 55.0** — five hundredths of a
    millimetre short — and the level's only win condition never fired. `PORTAL_PUSH` 0.8 m past the
    portal, toward the next room's centre, is the fix.

**2. "Contact is a pure distance test, like every other creature."** Superseded twice over, by two
entries that are still in SPEC above it: contact now also requires `_has_los()` (⚠️⚠️ **CONTACT
NEEDS LINE OF SIGHT**, Issue 180), and a contact within `GRAB_DOOR_DIST` 1.5 m of a `SlamDoor` is
staged through `death_override` (⭐⭐ **THE GRAB THROUGH THE DOOR**) — while `dungeon.gd` runs the
same script with `lethal_contact` false, so "every other creature in the game" includes one that
does not kill at all. The distance term itself (`CONTACT_DIST=1.0`, instant-fatal) is unchanged and
stays in SPEC.

  (`Screamer.trigger()`), exactly like every other creature in the game — no grab/struggle QTE.

## NEEDS A PLAYTEST

- **Pass 5.**
  - **The seal.** Try to die inside ExitVault while holding E, and try sealing it as it lunges: does
    each end in exactly one outcome?
  - **The creature after you hide.** Does it keep prowling instead of standing, and does the teleport
    still land where you have time to move?
  - **The technician.** Does E work the moment you reach him, does the scream land (loud, but not the
    kill sting), and is "don't… go in there…" still heard after it? Do you notice his eyes open?
- **Pass 4, walk it straight, then slowly.**
  - **The shutter face** (reversed: the FIRST opening shows it, when you look). Did you see it? Did the
    quiet stare frighten, or read as a statue? A player who never looks at bay B never sees it open.
  - **The ceiling drop.** Does it make you jump? Does the body read as a person wrapped up (the hair,
    the bare arm), not as a bag? The crash and the chain are placeholders.
  - **The fused technician** (the user's art, a bas-relief mesh). Does he read as a real man grown out of
    the wall, from the front and walking past? Is the wheel in his fists seen from across the Plenum
    (the door's bare spindle is the other half of the clue)? Up close, the face can look mask-like: its
    features are painted on a smooth head form.
  - **The music.** Is it now the lead without being loud, is every PA line still intelligible over the
    ducked music (the tannoy sits under the vent bed even alone), and does its fade before the hand make
    the corner feel emptier?
  - **The seal race.** Is "Hold E" clear? Lured into the back half it seals; near the doorway it jams.
    Does that feel fair, and is the 0.4 s the jam holds it enough to get away? The user expects to
    judge whether to keep it (`SEAL_RACE`).
- **Walk the approach twice: once straight through, once stopping at the porthole door.**
  - Does every beat land, in order?
  - Does a straight walk feel rushed through the victim? PA line 3 queues behind it.
  - Is the approach still boring? That was the 2026-09-22 complaint the redesign answers.
- **Judge the mix by ear.** Automated checks prove playback and routing, not loudness:
  - The user's `lamp_on` is very quiet (RMS −40 dBFS after normalising) and plays at +6 dB. Is each
    clunk audible?
  - Does the muffled roar read as behind a door?
  - Does the hand's scream land, at −3 dB on Master?
  - Is the machinery pool noticeable without being busy? Does any of it sound like a footstep?
- **The Observation.** Can you see the residue stop at the light and the smashed lamps above it,
  without being told? The renders show a dark room.
- **The glimpse** now fires at 3–5 m (4.3 m on the test walk), a hooked claw against lit tile. Does it
  read as a hand in the 0.15 s before it is yanked away, and does the scream make it land?
- **Pass 3, walk it twice: straight, and slowly.**
  - **The grille.** Does the pounding make you look right, and do you see a back and a crown through
    the slats, not just shapes? From the lane it is small; up close it reads.
  - **The technician.** Do you wait out the victim at the door, or does the ~11 s before he answers
    feel like a broken prop? Does his eyes opening land, and is the whisper audible?
  - **The wheel.** Does circling the mouse read as turning it without being told twice? It takes about
    10 s circling steadily and 13 s with small trackpad circles. Is the drift-back felt, and is it
    fair?
  - **The dark room.** Panic reaches 42 in ~16 s inside, and nothing explains it. Does it feel like the
    room, or like a bug? Is the far doorway findable by spark and by the red lamp beyond it?
  - **The chamber.** Do the bodies and the CCTV loop tell the escape, and does the glass crunch? The
    CCTV clip is the placeholder until the user's arrives.
- **The breached tank** (`06e`/`06f`): does the empty tank with its burst front read as "it got out"
  straight after the CCTV loop, and does it match the tank the player saw occupied in KONTUR?
- **ApproachDamaged at 2.4 m.** Does it feel compressed without feeling like a bug? The cross ducts
  pass 0.33 m above the player's eyes.
- Judge the flashlight search, now in the **EastVault** cabinet with a 20 s first grace: is there
  enough light to navigate, is the leaking beam noticeable from WardA, and are there enough hiding
  opportunities before recovery? Then judge the lure across the spine to ExitVault. ⚠️ Brief the
  player WITHOUT naming the cabinet. The 2026-09-22 run was contaminated because the briefing named
  it.

- Judge the new 1.45 s contact attack: does the claw reach, generated close-up and two-impact
  rhythm feel forceful and match Object 12? Try contact in a room and beside an open door,
  including with the torch off. Automated timing/restart checks do not judge fear.
- Judge the supplied scream/background balance during a chase, the roar alongside door punches,
  and the searching howl from inside a locker. Both chase layers produced nonzero decoded audio
  simultaneously in the guard; that measures playback, not subjective loudness or fear.
- Replay the shorter doors: does silence → blackout → crash feel frightening and leave enough
  escape time? Compare the creature's revised surface under a moving torch and from a locker.
- Hide at several spots and judge whether the wandering/relocation leaves a useful window to
  emerge. The two-minute automated hunt proves target handling, not the player's sense of relief.
- Walk the west wing as the creature chases: the router was measured over the **old** 13-room
  graph (`probe_breach_router_sweep.gd`, 624 traversals). Re-run it over the 20-room graph and
  confirm the two new slam doors (`Slam_ArchiveB_WardB`, `Slam_WardC_EastHall`) actually gate the
  loops they are named for.
- Seal the creature in `ExitVault`, then walk to the exit in the Incinerator: Issue 181's softlock
  was measured when the trap room and the exit room were the same room. They are different rooms
  now, so confirm `REOPEN_AFTER_PURGE` still leaves a way back out of the west-wing dead end.
- Hide in each of the **eight** spots with the creature searching, and confirm the ±55° peek cone
  reads as a locker-door crack rather than as a stuck camera.
