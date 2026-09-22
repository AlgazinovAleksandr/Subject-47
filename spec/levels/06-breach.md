# Level 6 — The Breach — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

### 🔨 PLANNED — 2026-09-23 approach redesign: its traces, its sounds, one glimpse

**Why.** 2026-09-22 hand playtest, all six J-captures inside the approach:
- *"This first part of the corridor is too boring."*
- *"the corridor itself is cool but it clearly lacks the scary parts, and it does not represent what
  will happen next. Shall we have like hallucinations of the creature you will see later, the same
  textures as there, some other kinds of things?"*

The diagnosis:
- The 60 m ApproachService is dead straight, with lamps spaced exactly every 8 m.
- The whole route carries four one-off events (a rattle, two pipe groans, one lamp flicker), and not
  one of them relates to Object 12.

**Rulings changed by the user (2026-09-23), overriding the 2026-09-22 entry below:**
- **The approach may show Object 12's traces, its sounds, and exactly ONE partial glimpse.**
  - This replaces *"no visible creature or active pursuit"*, *"No monster silhouette"* and *"hidden,
    inactive and silent"*.
  - Full hallucinations were offered and not chosen. The player has already seen Object 12 in
    KONTUR's glass cell, so the approach's job is dread of meeting it loose, not a first reveal.
- **The REAL creature is unchanged.**
  - The AI, `breach_creature_voice.gd`, patrol, relocation and contact all stay dormant, and its body
    stays hidden until the seal.
  - Every approach beat uses its own one-shot speakers. The glimpse is a separate visual-only puppet.
- **Length stays 60–90 s at 4 m/s**, denser rather than longer. No forced waits, no item puzzle, no
  timed locks.

**The route, beat by beat.** Every beat fires once per run.

| ≈ Time | Room | Beats |
|---|---|---|
| 0–15 s | ApproachService | **The straight line is broken.** Two jogs and/or hanging strip curtains, so the far end is never in view. Lamps come in uneven clusters with one dead gap. **Motion lamps:** each clunks on as the player comes within ~6 m, which teaches the rule. At ~40 m **one lamp ~20 m ahead clunks on by itself**, holds ~2 s, and dies (the rule breaks, so something else is here). A shift board with names crossed out; barrier tape strung *facing inward*, toward containment. **PA line 1.** |
| 15–22 s | ApproachPumpReturn | **The distant door tell**, through the wall. The same sequence the hunt's `breach_door_scare.gd` plays: Object 12's batter roar and pounding, muffled → silence → the local lamps dip → a crash. Learned here as a story event, recognised later as the hunt's warning. |
| 22–35 s | ApproachObservation + bays | **Seal panel "98 %".** **Light is a weapon, taught by the walls:** residue stops exactly at each working lamp's light edge, and the lamps along its path are smashed. **Hiding works:** one cabinet is deeply gouged outside but held, with scratched tallies inside. **Bay B's pressure shutter cycles** (the item the 2026-09-22 entry specced and never built); nothing is behind it. **PA line 2**, glitching. |
| 35–45 s | ApproachDamaged | **Compression:** the ceiling drops to ~2.4 m, cluttered with ducts. No crouch exists, so none is required. **It hears you:** a loose floor grating clangs underfoot → ~2 s → heavy knocks answer from the duct overhead → a scrape travels *away ahead* with dust sifting from the duct seam. This teaches the hunt's rule (it follows sound, `creature_object12.gd:notify_noise`). **Seal panel "61 %".** |
| 45–55 s | ApproachPlenum | **Release, and the peak.** A sealed door with a fogged porthole. **A victim heard, never seen:** a technician hammers and begs → Object 12's roar, muffled → a scream → **the building answers** (dust falls from the trays, the receivers ring, the duct rattle and pipe groan fire as responses, a lamp flickers on the roar) → a thump → silence → a heavy drag, receding. One residue patch visibly grows. No figure and no shadow under the door; the shadow is the Corridor's. |
| 55–65 s | ApproachContainment | **Object 12's breached cell:** an "OBJECT 12" stencil, the door **bent outward**, dents and finger drags at crown height (2.6 m), drag marks leading toward the hunt wing, **seal panel dead "— — —"**. **PA line 3 cuts off mid-word.** |
| 65–75 s | ApproachThreshold | The ambience ducks to near-silence. **The glimpse:** as the player turns the dogleg corner, long fingers of the real hollow-crown model withdraw up into a ceiling duct with a scream (the user chose the scream). Then quiet → the bulkhead slams behind them → the hunt. |

**The glimpse puppet** follows `breach_kill_sequence.gd:55-66`:
- `CreatureAnim.build()` on a plain `Node3D`, with a **duplicated** material (the wound flash tweens
  the shared one).
- It shows only a hand and forearm.
- No collider and no `ScaryObject`, so it adds zero panic and cannot kill.
- It is never emissive (`SCARY.md` §8.8), never faces the player, never approaches.
- Freed after the beat. The real `_creature` is never moved or shown.

**Sounds.** The user's recordings in `game/assets/audio/level_6_breach/new_sounds/`, with the mapping
confirmed by the user:

| File | Beat |
|---|---|
| `door_part1_sound` + `door_part_2_scream` | the technician |
| `creature_sound` | the roar behind his door |
| `loud_scream` | the scream the building answers |
| `monster_knock` (2–3 knocks cut from it) | the duct answer |
| `creature_crawl` | the receding duct scrape |
| `metal_crash` | the door tell's crash |
| `lamp_on` / `lamp_off_break` | motion lamps / the self-waking lamp dying and the smashed lamps |
| `motor` | the bay shutter |
| `ventilation` | the breathing bed |
| `dust` | falling dust |
| `loud_screamer` | the hand |

- **Generated** (the user's call): the drag, the grating clang and a 10–15 one-shot machinery pool,
  from a new seeded generator. The machinery pool subsumes the old one-shot rattle, plays mostly from
  behind, and never uses footstep-like sounds.
- **The PA's three lines** use KONTUR's announcer voice pipeline, so the Breach is the same facility
  still talking. This is the Breach half of the accepted `GAME_MECHANICS_IDEAS.md` N4. The lines are
  statements, never instructions or cues:
  1. *"Containment status, Wing C. Object Twelve: secured. Seal integrity ninety-eight percent."*
  2. *"Seal integrity… sixty-one percent. Personnel on site… two hundred twelve… twelve…"*
  3. *"Object Twelve is not in its—"*
- Supplied originals are copied unchanged to `assets_src/audio/level_6_breach/approach/`.
- Prepared game copies go through `tools/prepare_breach_audio.py`, which normalises in float first.
  Measured true peaks: `loud_screamer` **+4.8 dBTP**, `loud_scream` +3.9, `metal_crash` +2.3,
  `door_part_2_scream` +1.7. Direct int16 conversion would clip them.
- The approach's speakers stop asking for a nonexistent `"SFX"` bus, which silently falls back to
  Master. The silence beats duck the `Ambience` bus.

**Also fixed in this pass:**
- The "OBJECT 12 / CONTAINMENT WING" label is clipped by the bulkhead rails, which sit inside its
  depth (J-capture 6).
- The unlit, illegible "CONTAINMENT SERVICES →" label (J-capture 3).

**Guard rails:**
- No new panic term and no posture requirement.
- None of the Corridor motifs listed below.
- The facility stays grounded, so this pass does **not** resolve the unreality-curve question.

**Proof:**
- `check_breach_approach.gd` gets a physical walk that asserts:
  - panic stays exactly 0 for the whole approach
  - the real creature stays hidden, voiceless and dormant until the seal
  - every beat fires exactly once, in route order
  - the puppet carries no collider or `ScaryObject` and is freed
  - the bulkhead still blocks retreat
  - retries still skip the approach
- The authored route measures 60–90 s at 4 m/s.
- Rendered frames (read as images): room 1's lamp rhythm, the self-waking lamp, the cell, the
  porthole, the hand at its peak.

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

> ⚠️ **Partly superseded by the 2026-09-23 🔨 PLANNED redesign above.** Its "no visible creature",
> "No monster silhouette" and "hidden, inactive and silent" rules are replaced there.
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
  there for `SEARCH_TIME=8s`. **Entering a hiding spot instead clears that memory and starts
  random wandering**, per the 2026-09-20 user ruling above. `CHASE_SPEED=5.0` sits
  deliberately between the player's walk (4.0) and sprint (6.4) — beatable only by sprinting, which
  costs `SPRINT_PANIC_RATE`. Contact within `CONTACT_DIST=1.0` is **instant-fatal**.
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
