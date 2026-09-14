extends Node3D

# Level 3 — The Corridor. A ~320 m zigzag hotel hallway, built procedurally
# from PATH_2D. The only test: walk it without panicking. Three zones:
#   A (0–90 m)    intact hotel — torches, paintings, the clock
#   B (90–230 m)  decay — blood, lights shatter, beartraps in the dark
#   C (230–320 m) nightmare — dead torches, the mirror, whispers, door 217

const W := 3.0   # corridor width
const H := 3.0   # corridor height
const T := 0.3   # wall thickness

# Corner points of the zigzag centerline (x, z). Segment lengths:
# 50 + 40 + 50 + 45 + 45 + 45 + 45 + 45 + 45 + 45 = 455 m.
# ⭐⭐ C1 (2026-09-13, the user: "make the corridor level more big and extensive, where you can at
# some point turn the wrong side and get stuck somewhere … all the jumpscares will be in different
# parts of the level"). Was 7 segments / 320 m; three more legs, three blind SIDE_PASSAGES with a
# ten-second shut-in each, the three big beats spread >= 50 m apart, the last-corner mirror at
# 410, and the dread zone / hush / noclip riding the new end. Corners: 50 90 140 185 230 275 320
# 365 410.
const PATH_2D: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, 50), Vector2(40, 50), Vector2(40, 100),
	Vector2(-5, 100), Vector2(-5, 145), Vector2(40, 145), Vector2(40, 190),
	Vector2(-5, 190), Vector2(-5, 235), Vector2(40, 235),
]

# C1: blind spurs off the main corridor — [walked distance of the mouth, side, length]. Each one
# is a 3 m-wide dead end; walk to its far end and a door slams across the mouth behind you and
# is battered for ten seconds before it gives (`dead_end_trap.gd` + `slam_door.gd`). Zero panic —
# the dark and the sound do the work. The second one is the WHISPERING ROOM: a voice behind its
# end wall, audible from the corridor as you pass ("I want to get out but I can't").
# ⚠️ Mouths must sit INSIDE a segment (never on a corner) and clear of every wall prop on that
# side: torches, ajar/fake doors, panels, plates, mirrors. Re-check those tables if one moves.
# ⭐ 2026-09-13 (the user: "these dead ends have nothing in them … they should all be different").
# Each spur has a KIND, and the shut-in is a Space-mash escape (`spur_escape.gd`) rather than a
# wait:
#   "note"   — a page on the end wall ("You are not the first to take this experiment"); at the
#              second bar a shadow crosses the strip of light under the door.
#   "plea"   — the whispering room: the voice behind the end wall RISES with every bar you force,
#              and stops mid-word at the third, as a wet hand-print appears on the inside of the door.
#   "mirror" — a mirror on the end wall. While you push, something stands behind you in the
#              glass, between you and the door. It is gone when the door gives.
# Zero panic in all three. SPUR_SHUT_TIME is the FALLBACK — the door's own batter clock — for a
# player who never pushes.
const SIDE_PASSAGES := [
	{ "at": 105.0, "side": -1.0, "len": 14.0, "whisper": false, "kind": "note" },
	{ "at": 245.0, "side": 1.0, "len": 16.0, "whisper": true, "kind": "bell" },
	{ "at": 330.0, "side": -1.0, "len": 12.0, "whisper": false, "kind": "cupboard" },
]
# ⭐ 2026-09-14 (BACKLOG_Sep_14 C2/C3, the user: "always pressing Space is boring"): the "plea"
# and "mirror" spurs are gone. 245 is the BELL-AND-WAIT reception nook (`spur_bell.gd`: ring, the
# steps come up behind you, the only decision is whether you turn round) and 330 is the PASS-BY
# CUPBOARD (`spur_cupboard.gd`: step in, the slats shut, the Manager walks past; hold still with the
# torch off). Neither has a trap volume, a mash bar or a panic term. Only spur 105 keeps the
# Space-mash (one instance of the verb, the user's call).
const SPUR_SHUT_TIME := 20.0          # fallback only (was 10, when waiting was the whole beat)
const SPUR_NOTE_TEXT := """You are not the first to take this experiment.

Room 217 was booked under my name too.

They let you push. They only want to see how long you push for."""
const SPUR_PLEA_STEP_DB := 4.0        # the plea rises this much per forced bar

# ⭐ C2 (2026-09-13, the user: "there are no forks — no situations where you must decide right
# or left"). Two FORKS: at `at` a second opening leaves the hall on `side` and runs OUT `out` m,
# ACROSS `across` m parallel to the hall, and back to rejoin it at `at + across` through a door
# that stands shut until you reach the loop's far corner, then opens onto the hall you came
# from. The wrong branch costs the walk and one scare; it carries a hidden note. No panic. The
# tells are quiet: the hall's carpet does not continue into the branch and a dead torch stands
# at its mouth. Both mouths are cut from the hall wall like the spurs' (`_build_geometry`).
const FORKS := [
	{ "at": 118.0, "side": 1.0, "out": 8.0, "across": 9.0 },
	{ "at": 380.0, "side": 1.0, "out": 8.0, "across": 9.0 },
]
const FORK_NOTE_TEXT := """There is a shorter way. There is always a shorter way.

It is never this one.

Go back to the hall. Keep walking."""
var _forks: Array = []

# ⭐ C4 (2026-09-14, capture #005: "what I meant by fork is at a corner — you need to turn right,
# but what if you turn left?"). At two corners the hall ALSO continues straight past the turn
# (a `_corridor_box` passage on the incoming leg's heading, cut into the facing wall). The tell
# is EVIDENCE BEHIND YOU: a trail of wet footprints on the incoming leg's floor runs INTO the
# wrong branch. 320's branch is a LOOP-BACK (walk to its end and you are standing at the previous
# corner again, with a slam behind you); 365's branch ends in the BLIND ROOM (`blind_room.gd`).
# Never in SIDE_PASSAGES: `check_corridor_events` indexes the spurs by position. Branches stay
# under 20 m — `_nearest_path_distance` clamps to segment ends and the zigzag legs are 45 m
# apart, so past ~22 m a branch would read as progress on the NEXT leg (save/resume, doors,
# the hush all read `_furthest_reached`).
const CORNER_BRANCHES := [
	{ "corner": 320.0, "len": 16.0, "kind": "loop" },
	{ "corner": 365.0, "len": 12.0, "kind": "blind" },
]
const TRAIL_STEP := 0.55          # m between footprints
const TRAIL_BEFORE := 10.0        # m of trail on the incoming leg
const TRAIL_INTO := 5.0           # m of trail into the branch
const BLIND_ROOM_SIZE := 6.0
var _branches: Array = []
const SPUR_TRAP_DEPTH := 3.0          # the last metres of the spur spring it
const PLEA_DB := 8.0    # corridor_plea.wav measured -11.9 dBFS peak / -34.8 mean incl. its 6 s tail (make_corridor_plea.py)
const PLEA_UNIT := 10.0

const TEX_DIR := "res://assets/textures/level_3_corridor/"

# Lit torches: [distance, side]. Zone A is generous, Zone B sparser.
# The three at 148–168 sit in the dark stretch and get shattered by the
# lights-out event before the player reaches them.
const TORCHES := [
	[8.0, 1.0], [20.0, -1.0], [32.0, 1.0], [44.0, -1.0], [56.0, 1.0],
	[68.0, -1.0], [80.0, 1.0],
	[100.0, 1.0], [120.0, -1.0], [134.0, 1.0],
	[148.0, -1.0], [158.0, 1.0], [168.0, -1.0],
	[176.0, 1.0], [196.0, -1.0], [214.0, 1.0],
	# C1: the longer middle keeps a few lit; Zone C proper (the dread zone) stays black.
	[236.0, 1.0], [258.0, -1.0], [300.0, 1.0], [330.0, 1.0], [352.0, -1.0],
]
const SHATTER_RANGE := Vector2(144.0, 172.0)  # torches extinguished by lights-out

const BEARTRAPS := [  # [distance, lateral offset]
	[150.0, 0.45], [155.0, -0.6], [162.0, 0.55], [168.0, 0.0], [292.0, -0.5],   # C1: 245 -> 292 (the whisper spur's mouth is at 245)
]

# ⚠️ Difficulty fix: DARK_ZONES used to have a second entry, Vector2(240, 318),
# which sat entirely INSIDE the dread zone below. player.gd's _update_panic()
# treats dark-zone and dread-zone pressure as ADDITIVE (dark tax is +3/s on top
# of the unconditional +2/s dread pressure), so any stretch tagged as both was a
# guaranteed +5/s with the flashlight off — and the noclip ending (_ev_noclip_onset)
# FORCE-KILLS the flashlight for the final ~10 m with zero player agency to avoid
# it. (⚠️ The second half of this reasoning is now HISTORY, not a live hazard: it used to add
# that "a long level with beartrap QTEs earlier can also burn through the 240 s battery before
# reaching here". The battery has been infinite since 2026-09-03 — see `player.gd:
# INFINITE_BATTERY` — so attrition can no longer force the tax. The force-kill above still can,
# which is why the zone stays dropped.) Either way it made the ending an unavoidable panic spike
# read as "impossible." Dropped entirely — the dread zone's own pressure is
# already this stretch's difficulty signature; it doesn't need a second, stacking
# mechanic under it.
const DARK_ZONES := [Vector2(145.0, 172.0)]
# Shortened from 230 (90 m of flat/no-recovery pressure) to 260 (60 m) — gives
# the player real decay time after the silhouette/floor-crack events instead of
# carrying whatever panic they had straight into the endurance stretch.
const DREAD_ZONE := Vector2(395.0, 455.0)  # Zone C tail: weak decay + constant pressure (C1: the last 60 m of 455)

# The Manager: a survivable scare that strikes once while you walk — a flash, a
# scream, a panic spike to ride out. Distance-triggered (not wall-time) at a
# random mid-hall point, so it always fires regardless of walk/run speed.
const MANAGER_SCARE_PATH := "res://assets/textures/level_3_corridor/screamer_manager.png"
const MANAGER_PANIC := 25.0
const MANAGER_DIST := Vector2(80.0, 180.0)  # walked-distance window for the fire point

var _manager_fired: bool = false
var _furthest_reached: float = 0.0

# THE RUNNING CREATURE (_ev_silhouette). All of the reasoning is at the function; these are
# the numbers it moved and the ones it deliberately did not.
const SILHOUETTE_TRIGGER := 340.0     # C1: was 219 — >= 60 m after the Manager's last telegraph (277)
const SILHOUETTE_CROSS := 348.0       # 8 m ahead of the trigger, as before
const SILHOUETTE_SIDE := 2.0          # was 1.2 — start/end BEHIND the walls (face 1.5 + T 0.3)
const SILHOUETTE_CROSS_TIME := 0.8    # 4.0 m of travel = 5.0 m/s, 0.6 s of it in view
# ⚠️ SET FROM THE FILE'S MEASURED LEVEL. `shared/jumpscare.wav` measures peak 0.0 dBFS, mean
# -2.8 dBFS — it is already a full-scale asset, so the gain is chosen against CLIPPING, not
# against a plausible number. At the 8-9 m crossing `unit_size` 8 gives about -1 dB of
# distance attenuation, so -3.0 lands the peak at about -4 dBFS and the mean at -6.8, against
# the old -14.0 at 23.5 m which landed at -23.4 / -26.2. That is +19.4 dB.
# ⚠️ And `max_db` is pinned to 0.0 for this one emitter: a player who SPRINTS at the crossing
# can be 4 m from it when it plays, where `_play_at`'s default max_db 6.0 would add another
# 6 dB and clip the master.
const SILHOUETTE_DB := -3.0
const SILHOUETTE_MAX_DB := 0.0
# ⚠️ DIFFICULTY CONSTANT — NOT TOUCHED (2026-08-17). The user asked for the beat to be closer
# and louder; both of those raise its impact on their own. Compounding it with a bigger number
# was explicitly declined. This level already peaked a playtest at 97 %.
const SILHOUETTE_PANIC := 20.0

# Turn mirrors: walk into the creature in the glass and it flashes back at you.
# [{pos, fired, flashes, woke}] — proximity-tested in _process. `fired` is the 2 m sting's
# one-shot, `woke` is the 14 m appearance cue's; two beats, two flags.
const TURN_MIRROR_SCARE_PATH := "res://assets/textures/level_3_corridor/mirror_with_creature.png"
const TURN_MIRROR_SCARE_DIST := 2.0
const TURN_MIRROR_PANIC := 12.0

# [path distance, gaze intensity]. TWO, and which two is the user's call — the first corner
# and the last, with the d=230 one removed on 2026-08-16. See the note in `_spawn_panels()`
# for the panic arithmetic, and `_pick_silent_mirror()` for why nothing is muted at two.
# A const rather than a literal in the loop so the tests can assert against the real table.
const TURN_MIRRORS := [[90.0, 1.5], [410.0, 2.2]]   # C1: the LAST corner is 410 now (was 275)

# ⭐ THE GLASS WAKES UP, AND YOU HEAR IT (2026-08-16).
#
# The user's verification replay: *"The mirror appears out of nowhere. I think it is good,
# generate a noisy sound for it so that it would scary the player."* They like the beat and
# want it reinforced — so this is deliberately NOT a second sting layered on the existing
# one. The two are different moments, 12 m apart:
#
#   at MirrorSurface.ACTIVE_DIST (14 m)  the SubViewport switches from UPDATE_DISABLED to
#                                        UPDATE_ALWAYS and the dark rectangle on the wall
#                                        ahead becomes a live corridor. THIS sound. Zero
#                                        panic, one-shot, positional, at the glass.
#   at TURN_MIRROR_SCARE_DIST (2 m)      the existing `flash_scare(..., "glass_shatter")`
#                                        + jolt + TURN_MIRROR_PANIC 12. Untouched.
#
# ⚠️ Fired from the same constant the reflection is gated on, deliberately: the sound is
# what the picture is doing. If ACTIVE_DIST ever moves, the cue moves with it.
const MIRROR_WAKE_FACING := 0.35   # same cone as DOOR_VIEW_DOT — it must be ahead of you
# ⚠️ SET FROM THE FILE'S MEASURED LEVEL, not from a plausible number (the Flood's water bed
# shipped 20 dB low that way) — and RE-MEASURED 2026-08-17, because the file itself changed.
#
# The user asked for this cue to be *"much louder"*. It could not simply be turned up: at the
# old +6.0 with `unit_size` 8 at a 14 m trigger the distance attenuation is -4.86 dB, so the
# file's -1.0 dBFS peak was landing at **+0.13 dBFS at the listener** — already fractionally
# clipping the master. The loudness had to come out of the FILE, and it did: `make_sfx_mirror`
# gained a compressor and a tanh drive and now measures peak -1.01, RMS -8.1, loudest-300 ms
# **-5.69 dBFS** (was -14.03). See that file for the six settings swept and why compression
# alone bought 2 dB.
#
#   before: 14 m trigger, +6.0 db, attenuation -4.86 -> loudest-300 ms -12.89 dBFS, peak +0.13
#   after :  7 m trigger, -1.5 db, attenuation +1.16 -> loudest-300 ms  -6.03 dBFS, peak -1.35
#
# **+6.9 dB where it is heard, and it stops clipping**, on top of firing at half the distance.
const MIRROR_WAKE_DB := -1.5
# ⚠️ The cue is a 1.45 s one-shot fired at 7 m and the player keeps walking, so by the end of
# it they can be 2 m from the emitter — where the default max_db 6.0 would add another 6 dB
# and put the peak at +3.5 dBFS. Pinned so the delivered peak can never exceed -1.0.
const MIRROR_WAKE_MAX_DB := 1.5

# ⭐ THE GLASS ANSWERS A STARE (2026-08-17). A rising, accelerating tone that comes OUT OF THE
# MIRROR while you hold your eyes on it, and stops the moment you look away.
#
# WHY. The 2026-08-17 playtest died here: standing at the 275 m mirror, panic ran
# 36 % -> 73 % -> 97 % -> dead in about fifteen seconds. That is the mirror's own gaze panel
# at `scare_intensity` 2.2 = 44 panic/s, and the user's ruling was verbatim *"Leave it -
# staring should be dangerous - but I guess adding heartbeat is a good idea."*
#
# ⚠️ SO THE COST IS UNCHANGED AND NO PANIC CONSTANT MOVED. `TURN_MIRRORS`'s 1.5 and 2.2 are
# exactly what they were. This adds **zero** panic — a channel, not a term.
#
# WHAT WAS ACTUALLY MISSING, measured rather than assumed. The heartbeat is real and it is
# audible: `shared/heartbeat.ogg` is -18.4 dBFS mean and `player.gd:_update_heartbeat()` lerps
# it -20 -> 0 dB against the panic ratio on the never-ducked BODY bus, so at the 72 % this
# player passed through it plays at about -24 dBFS. But it is a GLOBAL panic meter: it says
# "you are in trouble" and it has never said "the thing you are looking at is what is doing
# it". Panic in this level also comes from a dread zone, a dark zone, sprinting and five other
# events, so the heartbeat cannot single anything out. This can, because it is positional, it
# is gated on the same posture the damage is gated on, and it stops when the posture stops.
#
# ⚠️ THE RANGE MIRRORS `player.gd:GAZE_RANGE` (3.0). It is deliberately a copy rather than a
# read: the tell must cover exactly the volume in which the panel actually charges, and if
# that constant ever moves this comment is what says these two are a pair.
const MIRROR_STARE_RANGE := 3.0
# Tighter than MIRROR_WAKE_FACING 0.35 (a 70 deg half-cone). The panel charges off a single
# raycast down the centre of the screen, so "looking at it" here means roughly that, not
# "it is somewhere on screen" — 0.90 is a 26 deg half-cone.
const MIRROR_STARE_FACING := 0.90
const MIRROR_STARE_RAMP := 2.4      # seconds of held stare to reach full
const MIRROR_STARE_RELEASE := 1.6   # how fast the meter falls once you look away, per second
# ⚠️ SET FROM THE FILE'S MEASURED LEVEL. `mirror_stare.wav` measures peak -1.01 dBFS,
# RMS -11.2, loudest-300 ms -8.5. `unit_size` 8 at 1-3 m gives +8.5..+18 dB of attenuation
# GAIN, so `max_db` is what actually sets the ceiling here, not volume_db: at full ramp the
# delivered loudest-300 ms is about -8.5 + MIRROR_STARE_MAX_DB.
const MIRROR_STARE_DB := Vector2(-26.0, -3.0)   # volume_db at meter 0 -> 1
const MIRROR_STARE_MAX_DB := -3.0
# The loop carries a 2 Hz amplitude pulse, so pitch is also a RATE: 1.44 Hz -> 2.70 Hz. An
# accelerating pulse is the half of this that reads as a countdown rather than as atmosphere.
const MIRROR_STARE_PITCH := Vector2(0.72, 1.35)

# ⭐ THE FALSE ROOM 217 (2026-08-17). See `false_exit_door.gd` for what the lie is and
# `tools/make_false_door.py` for why the art is `door.png`'s leaf.
#
# WHERE, AND WHY THERE. The corner at **d = 185 m**, on the wall you walk straight at for the
# whole of segment 4. Against the constraints given:
#   * seen head-on — 45 m of straight approach, the longest uninterrupted sightline in the
#     level after the entrance;
#   * not a mirror corner — 90 m and 275 m are spoken for; 230 m was deliberately emptied on
#     2026-08-16 and is 8 m from the running silhouette, and 140 m is inside the Manager's
#     telegraph window;
#   * **135 m from the real exit**, so it cannot read as a near-miss of room 217;
#   * believable, because of what the player has just done: 185 m is the FIRST corner after
#     the lights-out event and the four beartraps in the 145-172 m dark stretch. They come out
#     of the dark and there is a red-lit doorway at the end of the hall. The promise is what
#     pulls them through the traps, and it is a lie.
const FALSE_DOOR_DIST := 185.0
const FALSE_DOOR_TEX := TEX_DIR + "hotel_door_217.png"
# ⭐⭐ THE THING COMES OUT OF THE DOOR NOW (2026-09-10, the user's replay: *"regenerate the image
# of the jumpscare behind the fake door. And maybe make it look more natural — like something
# is actually showing up from there and trying to make you scared and then runs away. Make it
# louder also"*). Until this pass E swung the leaf behind a 0.9 s FULLSCREEN picture
# (`screamer_false_door.png`, retired to assets_src/textures/superseded/). Now a generated
# cutout (`door_lunger.gd`) stands in the doorway as the leaf swings, lunges to arm's length
# with the sting and a jolt, holds there, then turns and sprints away round the corner into the
# dark stretch ahead. The camera is pinned on it for FALSE_DOOR_WATCH so the retreat is SEEN —
# that is the half the user asked for by name. Chosen over "lunge then a short flash" and "only
# a new picture" by the user.
# ⚠️ LOUDER, WITH NO HEADROOM LEFT: the sting is already at the Master limiter's ceiling (see
# below), so "louder" is (1) a longer pre-silence (FALSE_DOOR_SILENCE), (2) the sting on an
# emitter AT the figure with `max_db` 6 — at 0.6 m that is +6 dB into the limiter, denser not
# clipped — and (3) `impact_thud`, a sub-bass hit under it that the scream's spectrum does not
# carry (`tools/make_sfx_impact.py`). Nothing else in the beat moved: the 15 panic, the scrawl.
const FALSE_DOOR_FIGURE_PATH := TEX_DIR + "false_door_lunger.png"
const FALSE_DOOR_FIGURE_H := 2.0
const FALSE_DOOR_SILENCE := 1.0      # Ambience dip opened at E, so the sting lands in a hole
const FALSE_DOOR_LUNGE_AT := 0.30    # s after E — the leaf is ~50 deg open by then
const FALSE_DOOR_LUNGE_TIME := 0.22
const FALSE_DOOR_LUNGE_REACH := 0.6  # m from the eye it stops at
const FALSE_DOOR_HOLD := 0.28        # s in your face before it turns
const FALSE_DOOR_FLEE_SPEED := 6.0   # m/s — a sprint, the same 5-6 m/s band as the runner
const FALSE_DOOR_FLEE_AHEAD := 10.0  # path metres past the corner it runs to
const FALSE_DOOR_FLEE_FADE := 2.5    # ...fading over its last metres
const FALSE_DOOR_WATCH := 1.6        # s the camera is pinned to it from E
const FALSE_DOOR_IMPACT := "impact_thud"
# ⭐ THE SHARED SCREAMER STING (2026-08-18). Playtest capture 002: *"Use the sounds for shared
# screamers and make it louder."* This was `false_door_scream`, a purpose-made file
# (`tools/make_sfx_false_door.py`, now retired) chosen because every existing candidate was
# already something else's voice. The user overruled that, and they are right about the level
# it delivers.
#
# ⚠️ THERE IS NO GAIN TO SET HERE, WHICH IS WHY THE CHOICE OF FILE *IS* THE VOLUME CONTROL.
# `flash_scare` plays the stream on `Screamer`'s own `AudioStreamPlayer` at 0 dB and takes no
# volume argument, and `screamer.gd` is a shared file. So "louder" had to come out of the
# asset, and the delivered ceiling is the output's — measured, decoded and clamped to +/-1.0
# as the mixer will:
#
#   | file                        | peak    | RMS    | loudest 300 ms |
#   |-----------------------------|---------|--------|----------------|
#   | false_door_scream.wav (was) |  -1.01  | -6.37  |  -3.79 dBFS    |
#   | all_levels_screamer.mp3     |  +0.00  | -4.69  |  -0.16 dBFS    |   <- +3.63 dB
#
# That is essentially all the headroom there is: the new sting sits 0.16 dB off full scale, so
# nothing was — or could be — added on top without shipping distortion. What the switch really
# buys is DENSITY and RECOGNITION: `all_levels_screamer` is 1.85 s of near-brickwalled scream
# against 1.6 s peaking at -1, and it is the sting `_apply_level_av()` pairs with the shared
# `screamers/` image pool, i.e. the one the player already flinches at.
# ⚠️ AND IT IS DELIBERATELY NOT THIS LEVEL'S DEATH SOUND. The Corridor dies to
# `screamer_corridor` (`Screamer.LEVEL_SCREAMERS[3]`), so a survivable trap borrowing the
# shared sting does not teach the player that the sound they die to is free — the objection
# INTRO.md raises against reusing a death sting for a survivable beat does not apply here, and
# `check_corridor_events.gd` asserts the two stay different.
const FALSE_DOOR_SCREAM := "all_levels_screamer"
const FALSE_DOOR_SCRAWL := "IT WAS AN ILLUSION"
const FALSE_DOOR_SCRAWL_DELAY := 1.6    # from E: as the camera is handed back and it is gone
# The blood-red the game has spent three levels teaching means "the way out" — copied
# verbatim from `_dress_back_door()` and `door.gd:door_material()`. The deception is carried
# by this at range and by the 217 plate up close.
const FALSE_DOOR_GLOW_ALBEDO := Color(0.15, 0.01, 0.01)
# ⚠️ `_dress_back_door()` writes this as (0.35, 0.02, 0.02) at energy **1.5**. The RENDERED
# emission is the product, so it is expressed here as the product at energy 1.0 —
# 0.35 x 1.5 = 0.525 — which is byte-identical on screen and does not trip
# `check_fixtures.gd`'s "nothing above the 1.0 clamp" ceiling (Issue 21). It caught these
# bars on the first run, correctly by its own rule and wrongly about the outcome: 0.525 is
# nowhere near white. Expressing the product is the fix that keeps both true.
const FALSE_DOOR_GLOW_EMISSION := Color(0.20, 0.015, 0.012)
const FALSE_DOOR_GLOW_ENERGY := 1.0
# ⚠️⚠️ DIFFICULTY CONSTANT — **CONFIRMED BY THE USER, 2026-08-18.** They were shown this
# reasoning, the alternatives (25 to match the Manager, 20 to match the silhouette, 10 as a
# pure shock) and the worst-case arithmetic, and chose 15. Do not re-tune it without asking.
# The reasoning, so it can be argued with:
#   * this level's existing one-shot spikes are entry slam 10, Manager 25, silhouette 20,
#     floor crack 10, two turn-mirror flashes 12 each = **89 across a full traversal**;
#   * the beat is voluntary in form but effectively mandatory in practice — it is dressed to
#     be opened — so it belongs in the survivable tier, not the Manager's;
#   * it lands right after the beartrap stretch, where a caught-and-escaped player arrives
#     with 15 already spent, so 25 here is where it starts coin-flipping a run;
#   * 15 is exactly a beartrap snap and sits between the mirror flash (12) and the Manager
#     (25). Total one-shot panic for a full traversal becomes **104 of a 50-point bar**, on a
#     level that already peaked a playtest at 97 % and killed the player.
const FALSE_DOOR_PANIC := 15.0

var _turn_mirrors: Array = []
var _false_door: FalseExitDoor = null

const NOTE_TEXT := """Hotel Vesper — night audit.

The corridor between floors does not appear on the building plans. The staff do not walk it after dark.

You will.

Walk. Do not run. Do not stop for the things you hear behind you. The lights have been paid for where they still burn — rest beneath them.

One of the rooms on this floor is occupied. We are not permitted to say which, and we are not permitted to say when the guest will step out. It has happened before. It will happen once tonight.

Room 217 is waiting.

— The Management"""

var _segments: Array[Dictionary] = []
var _total_len: float = 0.0
var _torch_nodes: Array = []  # [distance, Torch3D]
var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _ceil_mat: StandardMaterial3D

@onready var _player: CharacterBody3D = $Player


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.current_level = 3

	_build_segments()
	_make_materials()
	_build_geometry()
	_spawn_torches()
	_spawn_panels()
	_spawn_beartraps()
	_spawn_dark_zones()
	_spawn_dread_zone()
	_spawn_doors()
	_spawn_intro_note()
	_spawn_events()
	_spawn_noclip()
	_start_ambience()
	_black_background()
	Vignette.spawn(self, Color(0.9, 0.8, 0.65, 1.0), 1.2)
	RandomAmbient.register_player(_player)
	# ⚠️ The Corridor is the ONLY level that caps this, and it is opt-in for that reason —
	# see random_ambient.gd:set_once_per_type(). At ~300 m this is the longest walk in the
	# game, so a global 18-35 s metronome cycled the same three sounds many times over
	# ("too many repeating sounds… falling painting", 2026-08-15). One creak, one painting,
	# one half-scream, and then this autoload is quiet for the rest of the hall.
	RandomAmbient.set_once_per_type(true)
	_pick_silent_mirror()
	_spawn_apparition_director()
	# SCARY.md P2's stop-delayed echo. Two extra steps after the player halts: they stop,
	# and something behind them takes two more strides and stops too. Zero panic. This is
	# the first level other than the Backrooms to use the echo at all.
	_player.enable_footstep_echo(2)
	GameState.set_objective("Find room 217 — keep walking, do not run")
	_place_player()


# The shared Environment renders a procedural SKY behind the level. In a sealed corridor
# nobody ever sees it — until a mirror does. The reflection camera sits behind the glass
# with its near plane pushed out to the mirror plane, which necessarily clips the ceiling
# slab as well as the wall, and the sky poured through the gap as a bright blue band across
# the top of every mirror.
#
# `level_1.gd:_boost_ambient()` and the House already switch to a black background for
# exactly this class of leak ("so any geometry gap reads as darkness rather than blue
# sky"). The Corridor never needed it before because it had nothing that could see out.
# ⚠️ Ambient energy is deliberately NOT touched — this level's darkness is tuned.
func _black_background() -> void:
	var we: WorldEnvironment = get_node_or_null("Environment/WorldEnvironment")
	if not we or not we.environment:
		return
	var env: Environment = we.environment.duplicate()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	we.environment = env


# One of the turn mirrors does not flash this run — ONLY while there are three or more.
#
# ⚠️ THE THRESHOLD IS 3, AND THAT IS THE WHOLE DECISION (2026-08-16). This roll exists for
# anti-habituation: three identical 12-panic flashes at 90/230/275 m was textbook, so one
# corner per run was made into just a corner. At two mirrors the same roll silences HALF the
# level's mirror beats instead of a third, which is a different rule wearing the same code —
# and it would leave the run the user just asked for (one at the start, one at the end) with
# a 50 % chance of having only ONE.
#
# It also keeps the panic profile exactly where it was. Three mirrors minus one mute = 2
# flashes x TURN_MIRROR_PANIC 12 = 24 per run; two mirrors with no mute = 24 per run. The
# level's flash budget is unchanged by the removal, which is the reason to do it this way
# rather than by deleting this function.
#
# Habituation is not a risk at two: they are 185 m and roughly two minutes apart, and since
# 2026-08-16 the approach to each one is announced by `mirror_wake` from 14 m out.
#
# ⚠️ Restore a third mirror to TURN_MIRRORS and this comes back on its own. Do not delete it.
const SILENT_MIRROR_MIN := 3

func _pick_silent_mirror() -> void:
	if _turn_mirrors.size() < SILENT_MIRROR_MIN:
		return
	_turn_mirrors[randi() % _turn_mirrors.size()]["flashes"] = false


# The Corridor was the ONLY level with an ApparitionDirector-shaped hole — the Lab, the
# House, KONTUR and the Backrooms Flood all get the shared HOLD apparition and this level
# never did, despite having 140 m of Zone B to fill.
#
# ⚠️ Suppressed in two places, both for Issue-18 double-jeopardy reasons:
#   * 145-172 m, the dark zone with the four beartraps in it. A HOLD apparition kills you
#     for fleeing, and a player clamped at 45 % speed mashing E cannot demonstrate that they
#     are standing their ground. (`is_input_frozen()` now covers the beartrap QTE as well —
#     that was Phase 0's fourth fix — but keeping the whole stretch clear is the belt to its
#     braces, since the trap can also be stepped on a moment after the spawn.)
#   * past 260 m, the DreadZone, where decay is cancelled so every point is permanent, and
#     where the noclip force-kills the flashlight with no player agency at all.
func _spawn_apparition_director() -> void:
	if not RANDOM_APPARITIONS:
		return
	var director := ApparitionDirector.new()
	director.name = "ApparitionDirector"
	director.suppress = func() -> bool:
		var d := _furthest_reached
		if d >= DARK_ZONES[0].x - 5.0 and d <= DARK_ZONES[0].y + 5.0:
			return true
		return d >= DREAD_ZONE.x
	add_child(director)


# ---------------------------------------------------------------- progress snapshot
#
# The Corridor has no puzzle state — the level IS the walk. What it has instead is 320
# metres, and that is exactly what makes re-entry painful: coming BACK from the
# Backrooms used to drop the player at the corridor mouth with the whole hall to walk
# again before they could reach the noclip and go forward. So the only thing worth
# remembering is how far they got.
#
# ⚠️ Deliberately capped short of the noclip ONSET, not just the fall. Respawning inside
# either trigger would re-fire it the instant the level loaded — the blackout would kill
# the flashlight on arrival, or the fall would bounce the player straight back to the
# Backrooms they were trying to leave.
#
# ⚠️ THIS MOVES WITH `NOCLIP_ONSET_BEFORE_END`. It was 14.0 against a 10 m onset (cap at
# 306, clearing the onset box by 3 m); the 2026-08-15 pass moved the onset to 15 m out, so
# 14.0 would have put the player INSIDE it. 18.0 caps re-entry at 302: 2 m clear of the
# onset box (304-306) and ~11 m clear of the fall. `tests/check_noclip_fall.gd` asserts
# both gaps so the pair cannot drift apart again.
const RETURN_MARGIN := 18.0

# --- "the hotel wakes up behind you" (2026-07-28) --------------------------------------
# Measured dead stretches before this pass: 90-138 m had NOTHING in it (48 m, ~12 s of pure
# walking), and 288-310 m was 22 m of decals with the DreadZone's rates cancelling exactly,
# so panic could not even move. Zone C had no lit torch after 214 m and no calm zone at all.
#
# Everything here is panic-neutral except the apparition, which the user approved
# explicitly. The Manager's existing 25 is RE-HOMED rather than added to.
const DOOR_BEHIND_DIST := 10.0     # how far past a door before it may open
const DOOR_AJAR_MIN := 24.0        # degrees
const DOOR_AJAR_MAX := 38.0
const DOOR_SWING_TIME := 1.6       # slow, and silent — see AjarDoor.swing_ajar()
const DOOR_SLAM_LEAD := 22.0       # metres past the ajar door before it slams
# C5: the seventh door (see _spawn_doors): on the note spur's side, between it and the fake door at 130.
const BREAK_DOOR_AT := 124.0
const BREAK_DOOR_SIDE := -1.0
const BREAK_DOOR_DEG := 14.0
var _break_door: Node3D = null
var _break_figure: Node = null
var _break_spawned: bool = false
var _break_done: bool = false
const DOOR_VIEW_DOT := 0.35        # above this the player is looking at it; do not move it

# P4 The False Ceiling. A telegraph that usually means nothing, then one that does.
#
# ⚠️ WAS FIVE (104/126/150/178/206), and the user reported the result plainly: "there are
# too many repeating sounds… the trumpet musical instrument." `telegraph_groan` is a 3.2 s
# descending brass fall (tools/make_sfx_atmos.py:78-111) and hearing it five times in
# 100 m stops reading as dread and starts reading as a loop.
#
# Cut to TWO on the user's call (2026-08-15): one warning that leads nowhere, and one that
# delivers the Manager. That keeps the shape of the beat — you learn the sound means
# something is coming, you are wrong once, and then you are right — which is the whole
# point of P4, while the instrument is heard twice instead of five times.
const TELEGRAPH_AT: Array[float] = [240.0, 277.0]   # C1: just past the 230 and 275 corners, >= 55 m after the false door
const TELEGRAPH_PAYOFF_DELAY := 0.9

# The last stretch goes silent (P5's spatial cousin) instead of staying merely quiet.
const HUSH_AT := 431.0   # C1: total - 24, as it was (296 of 320)

# The Corridor's score rides its own bus so the hush cannot silence it. Nested under
# Master rather than Ambience — see _start_ambience().
const _MUSIC_BUS := "CorridorScore"

# Whether this level arms random apparitions. Same const-plus-director split as
# level_1/level_2/kontur: the level says WHETHER, ApparitionDirector owns WHEN.
const RANDOM_APPARITIONS := true

var _ajar_doors: Array[Dictionary] = []
var _slam_index: int = -1
var _slam_dist: float = -1.0
var _watcher_door: int = -1
var _telegraph_payoff: int = 0     # which of the five actually delivers, per run
var _telegraphs_fired: int = 0
var _hushed: bool = false


func save_progress() -> Dictionary:
	return {
		"furthest": _furthest_reached,
		"manager_fired": _manager_fired,
		# ⚠️ P4's payoff index must persist. Re-rolling it on a back-door return would let a
		# player who already learned which telegraph delivers meet a different one, which is
		# the opposite of the anti-habituation the whole mechanic exists for.
		"telegraph_payoff": _telegraph_payoff,
		"telegraphs_fired": _telegraphs_fired,
		# Which mirrors carry a flash is also drawn per run (see _spawn_turn_mirror).
		"mirror_flash": _turn_mirrors.map(func(m: Dictionary) -> bool: return bool(m.get("flashes", true))),
		# ⚠️ A sprung trap must not re-arm on a back-door return. It is also the only lasting
		# record in the level that the player fell for it, which is why the restore path opens
		# the leaf rather than merely disabling it.
		"false_door_used": _false_door != null and _false_door.is_used(),
	}


func _place_player() -> void:
	if not _player:
		return
	if not GameState.entered_from_ahead:
		return                       # the .tscn already puts them at the mouth
	var data := GameState.get_level_progress(3)
	var dist: float = minf(float(data.get("furthest", 0.0)), _total_len - RETURN_MARGIN)
	if dist <= 1.0:
		return
	var pt := _path_point(dist)
	_player.global_position = pt.pos + Vector3(0, 0.1, 0)
	# Face back the way they came, toward the exit — they re-entered through it.
	_player.rotation.y = atan2(pt.dir.x, pt.dir.z)
	_manager_fired = bool(data.get("manager_fired", false))
	_telegraph_payoff = int(data.get("telegraph_payoff", _telegraph_payoff))
	_telegraphs_fired = int(data.get("telegraphs_fired", 0))
	var flags: Array = data.get("mirror_flash", [])
	for i in mini(flags.size(), _turn_mirrors.size()):
		_turn_mirrors[i]["flashes"] = bool(flags[i])
	if bool(data.get("false_door_used", false)) and _false_door != null:
		_false_door.set_used_instantly()


func _process(delta: float) -> void:
	# Deferred to here because the clearance probes need a physics frame — see
	# _make_mirror_real(). One-shot; the array is cleared by the call.
	if not _mirror_figure_spots.is_empty():
		_spawn_mirror_figures()
	_tick_false_door_watch(delta)

	# Falling through the floor owns the rest of the frame — nothing below this point
	# (turn-mirror proximity, the hush, door slams) means anything once the level is over.
	if _noclip_fired:
		_tick_fall()
		return

	# Walk into a turn mirror and the creature in the glass flashes at you once.
	var pp := _player.global_position
	# Cheap high-water mark for the progress snapshot. Path distance is not recoverable
	# from a position (the hall zigzags and doubles back in x), so track it as we go.
	_furthest_reached = maxf(_furthest_reached, _nearest_path_distance(pp))
	for m in _turn_mirrors:
		_tick_mirror_wake(m, pp)
		_tick_mirror_stare(m, pp, delta)
		if m.fired:
			continue
		var mp: Vector3 = m.pos
		if Vector2(pp.x - mp.x, pp.z - mp.z).length() <= TURN_MIRROR_SCARE_DIST:
			m.fired = true
			# ⚠️ Whether a mirror flashes is a per-run flag (`_pick_silent_mirror`). It was
			# drawn at random while there were three of them at 90/230/275 m — the mirror
			# sits 1.45 m past each corner so a normal turn ALWAYS trips it, and three
			# identical 12-panic flashes was textbook habituation by the third corner. At
			# the current TWO mirrors nothing is muted and both flash; the run's total is 24
			# either way. See _pick_silent_mirror().
			if not bool(m.get("flashes", true)):
				continue
			Screamer.flash_scare(TURN_MIRROR_SCARE_PATH, "glass_shatter", 0.6)
			_player.jolt_camera(0.07, 0.5)
			_player.add_panic(TURN_MIRROR_PANIC)

	_tick_doors()
	_tick_hush()
	_tick_break_door()


# The glass coming alive, given a sound. See MIRROR_WAKE_DB for what fires when and why
# this is not the 2 m `flash_scare`.
#
# ⚠️ ONE-SHOT PER MIRROR, and gated on FACING as well as distance. Distance alone would fire
# it at the player's back — the mirror is on the wall you face at a corner, so on the way
# out of the corner you cross 14 m again walking away from it. `MIRROR_WAKE_FACING` is not
# consumed on failure: a player who wanders into range looking at the floor gets the cue the
# moment they look up, rather than losing it.
#
# ⚠️ ZERO PANIC. The corner already carries TURN_MIRROR_PANIC 12 and a 30-40/s gaze panel;
# this is a channel, not a term (GAME_MECHANICS_IDEAS' governing finding).
func _tick_mirror_wake(m: Dictionary, pp: Vector3) -> void:
	if bool(m.get("woke", false)):
		return
	var mp: Vector3 = m.pos
	# ⚠️ HORIZONTAL, matching the 2 m sting's test three lines down in `_process`. `pp` is
	# the player's feet and the glass hangs at y=1.5, so a straight 3D distance would quietly
	# shave the trigger radius to 13.92 m and make the cue disagree with the render gate it
	# is supposed to be announcing.
	if Vector2(pp.x - mp.x, pp.z - mp.z).length() > MirrorSurface.ACTIVE_DIST:
		return
	if _facing_dot(mp) < MIRROR_WAKE_FACING:
		return
	m.woke = true
	_play_on(self, "mirror_wake", mp, MIRROR_WAKE_DB, MIRROR_WAKE_MAX_DB)


# The stare meter. Rises while the player is inside the gaze panel's own reach AND pointed at
# the glass; falls otherwise. Drives volume and pitch on the mirror's own looping emitter.
#
# ⚠️ ZERO PANIC, and it must stay that way — the whole point is that it makes an EXISTING cost
# legible. Adding a number here would be taxing the posture twice (Issue 18's shape).
#
# ⚠️ NOT ONE-SHOT, unlike the wake cue. Look away and it recedes; look back and it climbs
# again from where it fell to. A one-shot warning teaches the lesson once and then goes quiet
# for the second mirror, which is the one that killed the player.
func _tick_mirror_stare(m: Dictionary, pp: Vector3, delta: float) -> void:
	var p: AudioStreamPlayer3D = m.get("stare_player")
	if p == null or not is_instance_valid(p):
		return
	var mp: Vector3 = m.pos
	var near := Vector2(pp.x - mp.x, pp.z - mp.z).length() <= MIRROR_STARE_RANGE
	var staring: bool = near and _facing_dot(mp) >= MIRROR_STARE_FACING
	var meter: float = float(m.get("stare", 0.0))
	if staring:
		meter = minf(1.0, meter + delta / MIRROR_STARE_RAMP)
	else:
		meter = maxf(0.0, meter - delta * MIRROR_STARE_RELEASE)
	m.stare = meter

	if meter <= 0.0:
		if p.playing:
			p.stop()
		return
	if not p.playing:
		p.play()
	p.volume_db = lerpf(MIRROR_STARE_DB.x, MIRROR_STARE_DB.y, meter)
	p.pitch_scale = lerpf(MIRROR_STARE_PITCH.x, MIRROR_STARE_PITCH.y, meter)


# THE ANCHOR: doors you have already walked past open behind you.
#
# ⚠️ SILENTLY, and that is the mechanic. A creak at the moment of opening would give the
# player something to attribute it to and make this an event; without one it is a
# discrepancy, and it works RETROACTIVELY — one door standing ajar makes every door already
# passed a question. (Condemned's mannequins, via SCARY.md P6.)
#
# ⚠️ Also gated on not being looked at. The door must never move in view: a prop visibly
# swinging on its own is a different, cheaper effect, and this level has no supernatural
# register to spend yet at 90 m.
func _tick_doors() -> void:
	var here := _furthest_reached
	for d in _ajar_doors:
		var node: AjarDoor = d.node
		if not is_instance_valid(node):
			continue
		if not bool(d.opened):
			if here < float(d.dist) + DOOR_BEHIND_DIST:
				continue
			if _looking_at(node.global_position):
				continue
			d.opened = true
			node.swing_ajar(randf_range(DOOR_AJAR_MIN, DOOR_AJAR_MAX), DOOR_SWING_TIME)
			# One door in Zone B has someone standing in it. No rules, no panic, no sound,
			# gone when you look again — and BEHIND the player, per the "never scare from
			# the front" placement clause (GAME_MECHANICS_IDEAS N1).
			if int(d.dist) == _watcher_door:
				var pt := _path_point(float(d.dist))
				Watcher.spawn(self, (pt.pos as Vector3) + (pt.side as Vector3) * 1.1,
					"res://assets/textures/shared/watcher_figure.png", 4.0)
		elif _slam_index >= 0 and int(d.dist) == _slam_index and here >= _slam_dist:
			# The one that is HEARD. By now the player has probably already noticed doors
			# standing open, so the slam lands as confirmation rather than as a jump.
			_slam_index = -1
			_play_at("door_slam", node.global_position + Vector3(0, 1.0, 0), 0.0)
			node.slam()


func _looking_at(target: Vector3) -> bool:
	# ⚠️ The no-camera and the degenerate-geometry cases answer DIFFERENTLY here, and always
	# have: no camera means leave the doors alone entirely (false), while a door directly on
	# top of the player is assumed visible (true). Collapsing the two into one default flips
	# the first, so the split is kept explicit.
	if _player.get_node_or_null("Camera3D") == null:
		return false
	return _facing_dot(target, 1.0) > DOOR_VIEW_DOT


# Horizontal cosine between where the player is looking and a world point. `degenerate` is
# what to answer when the question is meaningless (no camera, or the point is on top of the
# player): `_looking_at` wants "assume visible, leave the door alone", the mirror cue wants
# "not yet".
func _facing_dot(target: Vector3, degenerate: float = -1.0) -> float:
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return degenerate
	var to_it := target - cam.global_position
	to_it.y = 0.0
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if to_it.length() < 0.05 or fwd.length() < 0.05:
		return degenerate
	return fwd.normalized().dot(to_it.normalized())


# The last 22 m before the noclip were mechanically frozen and content-free. They get the
# one thing this level has never had: silence. The whisper loop and the ambient bed die, and
# the player's own footsteps — on the un-duckable Body bus — are all that is left for the
# walk into the drop.
func _tick_hush() -> void:
	if _hushed or _furthest_reached < HUSH_AT:
		return
	_hushed = true
	var idx := AudioServer.get_bus_index(AudioBuses.AMBIENCE)
	if idx == -1:
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(idx, v),
		AudioServer.get_bus_volume_db(idx), -40.0, 3.0)


# ⚠️ THE HUSH MUST NOT OUTLIVE THE LEVEL. Audio buses are global and survive a scene
# change, and this level ducks `Ambience` by 40 dB roughly 20 m before it ends — so for the
# life of the project every level after the Corridor played with its ambience 40 dB down.
# It surfaced as "the music in the Backrooms disappeared after I got there from the
# corridor, but starting the Backrooms from scratch it was there" (2026-08-15).
#
# `GameState.start_current_level()` now resets every bus on every load, which is the real
# guarantee; this is the level cleaning up after itself so it is not the thing relying on
# it. Both, deliberately — the same belt-and-braces `silence_zone.gd` uses.
func _exit_tree() -> void:
	var idx := AudioServer.get_bus_index(AudioBuses.AMBIENCE)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, 0.0)


# P4 — the telegraph that usually means nothing, plus N3's announced-but-unbounded window.
#
# Four of the five fire and are followed by NOTHING AT ALL. The fifth, drawn per run, is
# followed 0.9 s later by the Manager's EXISTING flash_scare — so a 25-panic startle becomes
# a ~100 m dread structure at zero additional panic cost. A non-event cannot be unfair,
# which makes this the cheapest legal scare in the whole document.
func _telegraph(index: int) -> void:
	_telegraphs_fired += 1
	_play_at("telegraph_groan", _player.global_position + Vector3(0, 1.6, 0), -4.0)
	HoldBreath.dip(get_tree(), 1.2)
	if index != _telegraph_payoff:
		return                     # …and nothing happens. Four times out of five.
	get_tree().create_timer(TELEGRAPH_PAYOFF_DELAY).timeout.connect(_ev_manager)


# ---------------------------------------------------------------- path helpers

func _build_segments() -> void:
	var d := 0.0
	for i in range(PATH_2D.size() - 1):
		var p0 := PATH_2D[i]
		var p1 := PATH_2D[i + 1]
		var seg_len := p0.distance_to(p1)
		_segments.append({
			"p0": p0, "dir": (p1 - p0) / seg_len, "len": seg_len, "start_d": d,
		})
		d += seg_len
	_total_len = d


# Point on the centerline at walked distance `dist`.
# Returns pos (floor level), dir (walk direction) and side (lateral unit vector).
# Approximate path distance of a world position, by walking the segment table. Good
# enough for a respawn marker; it is never used for anything the player can see.
func _nearest_path_distance(pos: Vector3) -> float:
	var here := Vector2(pos.x, pos.z)
	var best_d := 0.0
	var best_sq := INF
	for seg in _segments:
		var p0: Vector2 = seg.p0
		var dir: Vector2 = seg.dir
		var seg_len: float = seg.len
		var t: float = clampf((here - p0).dot(dir), 0.0, seg_len)
		var closest: Vector2 = p0 + dir * t
		var d_sq: float = closest.distance_squared_to(here)
		if d_sq < best_sq:
			best_sq = d_sq
			best_d = float(seg.start_d) + t
	return best_d


func _path_point(dist: float) -> Dictionary:
	for i in range(_segments.size()):
		var seg: Dictionary = _segments[i]
		if dist <= seg.start_d + seg.len or i == _segments.size() - 1:
			var t: float = clampf(dist - seg.start_d, 0.0, seg.len)
			var p: Vector2 = seg.p0 + seg.dir * t
			var dir3 := Vector3(seg.dir.x, 0, seg.dir.y)
			return {
				"pos": Vector3(p.x, 0, p.y),
				"dir": dir3,
				"side": Vector3(dir3.z, 0, -dir3.x),
			}
	return {}


# ---------------------------------------------------------------- geometry

func _make_materials() -> void:
	# Negative y: triplanar V grows upward in world space, which renders the
	# texture upside-down on walls — flip so the wainscot sits at the floor.
	_wall_mat = _make_mat(TEX_DIR + "wall.png", Vector3(1.0 / 3.6, -1.0 / 3.0, 1.0 / 3.6), Color(0.25, 0.2, 0.14))
	_floor_mat = _make_mat(TEX_DIR + "carpet.png", Vector3(0.5, 0.5, 0.5), Color(0.16, 0.12, 0.05))
	_ceil_mat = _make_mat("", Vector3.ONE, Color(0.10, 0.085, 0.07))


func _make_mat(tex_path: String, uv_scale: Vector3, fallback: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.92
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		# Triplanar = 1 texture unit per (1/scale) world metres, independent of
		# CSG face size. Wall y-scale 1/3 fits exactly one wainscot row per 3 m.
		mat.uv1_triplanar = true
		mat.uv1_scale = uv_scale
	else:
		mat.albedo_color = fallback
	return mat


func _build_geometry() -> void:
	for i in range(_segments.size()):
		var seg: Dictionary = _segments[i]
		var n: Vector2 = Vector2(seg.dir.y, -seg.dir.x)  # side normal (2D)
		# Footprint extends half a width past interior corners so overlapping
		# floor/ceiling boxes cover the corner squares.
		var lo := 0.0 if i == 0 else -W / 2.0
		var hi: float = seg.len if i == _segments.size() - 1 else seg.len + W / 2.0

		_corridor_box("Seg%dFloor" % i, seg, lo, hi, 0.0, W + 2.0 * T, -T / 2.0, T, _floor_mat)
		_corridor_box("Seg%dCeiling" % i, seg, lo, hi, 0.0, W + 2.0 * T, H + T / 2.0, T, _ceil_mat)

		for side in [1.0, -1.0]:
			# ⚠️ The OUTER wall of a bend starts one wall thickness BEFORE lo (Issue 211,
			# 2026-09-14): lo is -W/2 (the corner's inner face), the incoming leg's wall ends at
			# that same face, so the T x T column at the bend's outer corner belonged to nobody
			# — a pinhole at every corner, sampled by the shell sweep only along a diagonal, and
			# a real 0.3 m hole once the 320 branch mouth removed the wall beside it. The side
			# the previous leg attaches on is overridden to lo + W below, so only the outer wall
			# takes this; it ABUTS the incoming leg's wall end (no overlap).
			var wa := lo if i == 0 else lo - T
			var wb := hi
			# Leave a corridor-wide opening where the adjacent segment attaches.
			if i > 0 and (-_segments[i - 1].dir as Vector2).distance_to(n * side) < 0.01:
				wa = lo + W
			if i < _segments.size() - 1 and (_segments[i + 1].dir as Vector2).distance_to(n * side) < 0.01:
				wb = hi - W
			if wb - wa > 0.01:
				# C1: subtract every side-passage mouth on this segment and side, so the wall is
				# emitted as one box per remaining interval.
				var intervals: Array = [[wa, wb]]
				var mouths: Array = []
				for sp in SIDE_PASSAGES:
					mouths.append([float(sp["at"]), float(sp["side"])])
				for fk in FORKS:   # C2: two mouths per fork — out and back in
					mouths.append([float(fk["at"]), float(fk["side"])])
					mouths.append([float(fk["at"]) + float(fk["across"]), float(fk["side"])])
				for cb in CORNER_BRANCHES:   # C4: the facing wall at a corner, on the OUTGOING leg only
					var cm := _corner_branch_mouth(float(cb["corner"]))
					if int(cm["seg"]) == i:
						mouths.append([float(cm["at"]), float(cm["side"])])
				for mo in mouths:
					if signf(float(mo[1])) != signf(side):
						continue
					var at_local: float = float(mo[0]) - float(seg.start_d)
					if at_local < 0.0 or at_local > float(seg.len):
						continue
					var cut := [at_local - W / 2.0, at_local + W / 2.0]
					var next: Array = []
					for iv in intervals:
						if cut[1] <= iv[0] or cut[0] >= iv[1]:
							next.append(iv)
							continue
						if cut[0] > iv[0]:
							next.append([iv[0], cut[0]])
						if cut[1] < iv[1]:
							next.append([cut[1], iv[1]])
					intervals = next
				var k := 0
				for iv in intervals:
					if iv[1] - iv[0] <= 0.01:
						continue
					var wall_name := "Seg%dWall%s%s" % [i, "A" if side > 0 else "B", ("" if k == 0 else str(k))]
					_corridor_box(wall_name, seg, iv[0], iv[1], side * (W + T) / 2.0, T, H / 2.0, H + 2.0 * T, _wall_mat)
					k += 1

		if i == 0:
			_corridor_box("StartCapWall", seg, lo - T, lo, 0.0, W + 2.0 * T, H / 2.0, H + 2.0 * T, _wall_mat)
		if i == _segments.size() - 1:
			_corridor_box("EndCapWall", seg, hi, hi + T, 0.0, W + 2.0 * T, H / 2.0, H + 2.0 * T, _wall_mat)
	_build_spurs()
	_build_forks()
	_build_corner_branches()


# C1: the blind side passages. Each is built with the same box helper on a synthetic segment
# whose p0 is the mouth's INNER wall face and whose dir points out through the wall. The floor,
# ceiling and side walls start at `T` — the main corridor's own slabs already cover the wall's
# thickness under and over the opening — so no two surfaces coincide (Issue 20).
var _spurs: Array = []

func _build_spurs() -> void:
	for i in range(SIDE_PASSAGES.size()):
		var sp: Dictionary = SIDE_PASSAGES[i]
		var pt := _path_point(float(sp["at"]))
		var side: float = float(sp["side"])
		var n2 := Vector2(pt.side.x, pt.side.z) * side
		var p0: Vector2 = Vector2(pt.pos.x, pt.pos.z) + n2 * (W / 2.0)
		var seg := { "p0": p0, "dir": n2, "len": float(sp["len"]), "start_d": 0.0 }
		var L: float = float(sp["len"])
		_corridor_box("Spur%dFloor" % i, seg, T, L, 0.0, W + 2.0 * T, -T / 2.0, T, _floor_mat)
		_corridor_box("Spur%dCeiling" % i, seg, T, L, 0.0, W + 2.0 * T, H + T / 2.0, T, _ceil_mat)
		for s2 in [1.0, -1.0]:
			_corridor_box("Spur%dWall%s" % [i, "A" if s2 > 0 else "B"], seg, T, L,
				s2 * (W + T) / 2.0, T, H / 2.0, H + 2.0 * T, _wall_mat)
		_corridor_box("Spur%dEndCap" % i, seg, L, L + T, 0.0, W + 2.0 * T, H / 2.0, H + 2.0 * T, _wall_mat)
		# One torch half-way down, on the spur's own right-hand wall. It dies with the shut-in.
		var dir3 := Vector3(n2.x, 0, n2.y)
		var lat3 := Vector3(dir3.z, 0, -dir3.x)
		var torch := Torch3D.new()
		torch.name = "Spur%dTorch" % i
		torch.position = Vector3(p0.x, 0, p0.y) + dir3 * (L * 0.55) + lat3 * (W / 2.0 - 0.12) + Vector3(0, 1.9, 0)
		var inward: Vector3 = -lat3
		torch.rotation.y = atan2(inward.x, inward.z)
		add_child(torch)
		# The door across the mouth, open, hinged on the jambs the wall cut left. Local +x must
		# run ALONG the corridor (the leaves span the opening); the doorway plane is local z = 0.
		var door := SlamDoor.new()
		door.name = "Spur%dDoor" % i
		door.door_width = W
		door.door_height = H
		door.door_texture = TEX_DIR + "hotel_door_leaf.png"
		door.batter_time = SPUR_SHUT_TIME
		door.player_operable = false   # C6: the shut-in owns it; no "Press E"
		door.position = Vector3(p0.x, 0, p0.y) + dir3 * (T / 2.0)
		var md: Vector3 = pt.dir
		# + PI so the open leaves swing INTO the spur, not out across the hall (render-checked
		# 2026-09-13: the first orientation parked a 1.5 m leaf in the corridor).
		door.rotation.y = atan2(-md.z, md.x) + PI
		add_child(door)
		# ⚠️ The leaves are HIDDEN while the spur is open (render-checked twice, 2026-09-13: an open
		# 1.5 m leaf parked itself in the corridor whichever way the door was turned). The frame
		# stays — a framed opening off the hall — and the leaves appear as they slam.
		for h in door.get_children():
			if h is Node3D and String(h.name).begins_with("Hinge"):
				(h as Node3D).visible = false
		var kind: String = String(sp.get("kind", "note"))
		# The trap at the far end — only the kinds whose shut-in is sprung by ARRIVING.
		var trap: DeadEndTrap = null
		if kind == "note":
			trap = DeadEndTrap.new()
			trap.name = "Spur%dTrap" % i
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(W, H, SPUR_TRAP_DEPTH) if absf(dir3.z) > 0.5 else Vector3(SPUR_TRAP_DEPTH, H, W)
			col.shape = shape
			trap.add_child(col)
			trap.position = Vector3(p0.x, H / 2.0, p0.y) + dir3 * (L - SPUR_TRAP_DEPTH / 2.0)
			add_child(trap)
		var entry := { "index": i, "door": door, "torch": torch, "trap": trap, "mouth": Vector3(p0.x, 0, p0.y),
			"dir": dir3, "lat": lat3, "len": L, "scrape": null, "kind": kind, "plea": null,
			"handprint": null, "figure": null, "escape": null, "mirror": null, "note": null, "strip": null,
			"bell": null, "cupboard": null }
		if trap:
			trap.sprung.connect(_on_spur_sprung.bind(entry))
		_spurs.append(entry)
		# The whispering room: a voice behind the end wall, audible from the corridor.
		if bool(sp.get("whisper", false)):
			var plea := GameState.load_audio("corridor_plea")
			if plea:
				var pl := AudioStreamPlayer3D.new()
				pl.name = "Spur%dPlea" % i
				pl.stream = plea
				pl.volume_db = PLEA_DB
				pl.unit_size = PLEA_UNIT
				pl.max_db = 0.0
				pl.bus = AudioBuses.AMBIENCE
				add_child(pl)
				pl.position = Vector3(p0.x, 1.4, p0.y) + dir3 * (L + 0.6)
				pl.finished.connect(pl.play)
				pl.play()
				entry["plea"] = pl
		_dress_spur(entry)


# What each spur holds BEFORE the door shuts — the kind's fixture (see SIDE_PASSAGES).
func _dress_spur(entry: Dictionary) -> void:
	var i: int = int(entry["index"])
	var mouth: Vector3 = entry["mouth"]
	var dir3: Vector3 = entry["dir"]
	var L: float = float(entry["len"])
	var end_face: Vector3 = mouth + dir3 * (L - WALL_INSET)   # inner face of the end cap
	var back: Vector3 = -dir3                                  # the end wall faces the mouth
	match String(entry["kind"]):
		"note":
			var xform := Transform3D(Basis(Vector3.UP, atan2(back.x, back.z)), end_face + Vector3(0, 1.45, 0))
			entry["note"] = _spawn_wall_page("Spur%dNote" % i, xform, TEX_DIR + "spur_note.png", 0.6, SPUR_NOTE_TEXT)
		"bell":
			_dress_bell_spur(entry, end_face, back)
		"cupboard":
			_dress_cupboard_spur(entry, end_face, back)


# C2: the reception nook — a desk against the end wall with a counter bell on it (E rings it).
func _dress_bell_spur(entry: Dictionary, end_face: Vector3, back: Vector3) -> void:
	var i: int = int(entry["index"])
	var dir3: Vector3 = entry["dir"]
	var lat3: Vector3 = entry["lat"]
	var wood := _make_mat(TEX_DIR + "clock_walnut.png", Vector3(0.6, 0.6, 0.6), Color(0.16, 0.10, 0.05))
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.55, 0.42, 0.18)
	brass.metallic = 0.8
	brass.roughness = 0.35
	var desk_c: Vector3 = end_face + back * 0.55          # 1.1 m deep desk, its back against the end wall
	var yaw: float = atan2(back.x, back.z)
	var desk := Node3D.new()
	desk.name = "Spur%dDesk" % i
	desk.position = desk_c
	desk.rotation.y = yaw
	add_child(desk)
	for part in [["DeskTop", Vector3(1.8, 0.06, 1.0), Vector3(0, 0.95, 0)], ["DeskFront", Vector3(1.8, 0.92, 0.05), Vector3(0, 0.46, 0.475)],
			["DeskShelf", Vector3(1.7, 0.04, 0.9), Vector3(0, 0.55, 0)], ["DeskEndL", Vector3(0.05, 0.92, 1.0), Vector3(-0.875, 0.46, 0)],
			["DeskEndR", Vector3(0.05, 0.92, 1.0), Vector3(0.875, 0.46, 0)]]:
		var b := CSGBox3D.new()
		b.name = String(part[0])
		b.size = part[1]
		b.position = part[2]
		b.use_collision = true
		b.material = wood
		desk.add_child(b)
	# the bell: a brass dome on a base, its own body on layer 1 so the interact ray finds it
	var bell := StaticBody3D.new()
	bell.name = "Spur%dBell" % i
	bell.set_script(_BELL_PROP_SCRIPT)
	bell.position = desk_c + back * 0.25 + Vector3(0, 0.98, 0) + lat3 * 0.25
	add_child(bell)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.07
	bc.bottom_radius = 0.075
	bc.height = 0.02
	base.mesh = bc
	base.material_override = brass
	base.position = Vector3(0, 0.01, 0)
	bell.add_child(base)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	dome.mesh = sm
	dome.material_override = brass
	dome.position = Vector3(0, 0.05, 0)
	bell.add_child(dome)
	var btn := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.012
	bm.bottom_radius = 0.012
	bm.height = 0.03
	btn.mesh = bm
	btn.material_override = brass
	btn.position = Vector3(0, 0.11, 0)
	bell.add_child(btn)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.22, 0.2, 0.22)
	col.shape = shape
	col.position = Vector3(0, 0.08, 0)
	bell.add_child(col)
	# a "RING FOR SERVICE" plate on the desk front, and the beat itself
	var beat := SpurBell.new()
	beat.name = "Spur%dBellBeat" % i
	add_child(beat)
	beat.setup(self, entry["door"], desk_c + Vector3(0, 0.98, 0), entry["mouth"], dir3)
	bell.set("beat", beat)
	entry["bell"] = beat
	# the spur's lamp for this one is the desk lamp: a warm omni over the desk
	var lamp := OmniLight3D.new()
	lamp.name = "Spur%dDeskLamp" % i
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.7
	lamp.omni_range = 4.0
	lamp.position = desk_c + Vector3(0, 2.0, 0)
	add_child(lamp)


# C3: the linen cupboard at the spur's end — two sides, a shelf, a slatted door hinged open
# toward the spur, a mirror on the back wall (the end wall), and the Area3D that seals it.
func _dress_cupboard_spur(entry: Dictionary, end_face: Vector3, back: Vector3) -> void:
	var i: int = int(entry["index"])
	var dir3: Vector3 = entry["dir"]
	var lat3: Vector3 = entry["lat"]
	var wood := _make_mat(TEX_DIR + "clock_walnut.png", Vector3(0.6, 0.6, 0.6), Color(0.13, 0.09, 0.05))
	var cw := 1.1      # interior width
	var cd := 0.8      # interior depth
	var ch := 2.3
	var yaw: float = atan2(back.x, back.z)      # local +z = toward the mouth (the door's face)
	var root := Node3D.new()
	root.name = "Spur%dCupboard" % i
	root.position = end_face + back * (cd / 2.0)
	root.rotation.y = yaw
	add_child(root)
	for part in [["CupSideL", Vector3(0.05, ch, cd), Vector3(-(cw / 2.0 + 0.025), ch / 2.0, 0)],
			["CupSideR", Vector3(0.05, ch, cd), Vector3(cw / 2.0 + 0.025, ch / 2.0, 0)],
			["CupTop", Vector3(cw + 0.1, 0.05, cd), Vector3(0, ch + 0.025, 0)],
			["CupShelf", Vector3(cw, 0.03, cd * 0.5), Vector3(0, 1.95, -cd * 0.25)]]:
		var b := CSGBox3D.new()
		b.name = String(part[0])
		b.size = part[1]
		b.position = part[2]
		b.use_collision = true
		b.material = wood
		root.add_child(b)
	# the slatted door: a hinge at the left front edge, seven slats with gaps
	var hinge := Node3D.new()
	hinge.name = "CupHinge"
	hinge.position = Vector3(-cw / 2.0, 0, cd / 2.0)
	root.add_child(hinge)
	for k in 7:
		var slat := CSGBox3D.new()
		slat.name = "CupSlat%d" % k
		slat.size = Vector3(cw, 0.16, 0.03)
		slat.position = Vector3(cw / 2.0, 0.3 + k * 0.3, 0)
		slat.use_collision = false
		slat.material = wood
		hinge.add_child(slat)
	var stile := CSGBox3D.new()
	stile.name = "CupStile"
	stile.size = Vector3(0.05, ch, 0.04)
	stile.position = Vector3(cw - 0.025, ch / 2.0, 0)
	stile.use_collision = false
	stile.material = wood
	hinge.add_child(stile)
	# the shut door is solid: a body on the hinge, enabled only while shut (spur_cupboard.gd)
	var body := StaticBody3D.new()
	body.name = "CupDoorBody"
	var bcol := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(cw, ch, 0.06)
	bcol.shape = bsh
	bcol.position = Vector3(cw / 2.0, ch / 2.0, 0)
	body.add_child(bcol)
	hinge.add_child(body)
	var open_deg := -105.0
	hinge.rotation.y = deg_to_rad(open_deg)
	# the mirror on the back wall (the end wall), inside
	var mx := Transform3D(Basis(Vector3.UP, atan2(back.x, back.z)), end_face + Vector3(0, 1.45, 0))   # end_face is already WALL_INSET off the cap
	var quad := _spawn_quad(mx, Vector2(0.7, 1.3), TEX_DIR + "mirror.png")
	if quad:
		quad.name = "Spur%dCupboardMirror" % i
		MirrorSurface.attach(quad)
		_spawn_frame_bars(mx, Vector2(0.7, 1.3), "MirrorFrame_Cup%d" % i, Color(0.085, 0.070, 0.042), 0.04, 0.06)
		entry["mirror"] = quad
	# the beat
	var beat := SpurCupboard.new()
	beat.name = "Spur%dCupboardBeat" % i
	add_child(beat)
	var mouth: Vector3 = entry["mouth"]
	var L: float = float(entry["len"])
	var walk_from: Vector3 = mouth + dir3 * 1.0 - lat3 * (W / 2.0 - 0.7)
	var walk_to: Vector3 = end_face - dir3 * (cd + 1.2) + lat3 * (W / 2.0 - 0.7)
	beat.setup(hinge, open_deg, walk_from, walk_to, MANAGER_FIGURE_PATH, 2.0)
	beat.sealed.connect(func() -> void: bcol.disabled = false)
	beat.released.connect(func(_r: String) -> void: bcol.disabled = true)
	bcol.disabled = true
	entry["cupboard"] = beat
	# the Area3D inside: stepping in seals it
	var area := Area3D.new()
	area.name = "Spur%dCupboardArea" % i
	var acol := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(cw * 0.8, ch, cd * 0.6)
	acol.shape = ash
	acol.position = Vector3(0, ch / 2.0, -cd * 0.1)
	area.add_child(acol)
	root.add_child(area)
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			beat.seal())


# A readable page on a wall: `note.gd` body + a dark pad + the art quad sized from its own aspect.
# The intro note's recipe (`_spawn_intro_note`) stood up.
func _spawn_wall_page(name: String, xform: Transform3D, tex_path: String, width: float, text: String) -> StaticBody3D:
	var note := StaticBody3D.new()
	note.name = name
	note.set_script(_NOTE_SCRIPT)
	note.note_text = text
	note.transform = xform
	add_child(note)
	var page_w := width
	var page_h := width * 1.05
	var has_art: bool = ResourceLoader.exists(tex_path)
	if has_art:
		var tex: Texture2D = load(tex_path)
		page_h = page_w * float(tex.get_height()) / float(tex.get_width())
	var pad := MeshInstance3D.new()
	pad.name = "NotePad"
	pad.mesh = BoxMesh.new()
	(pad.mesh as BoxMesh).size = Vector3(page_w * 0.97, page_h * 0.97, 0.006)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.09, 0.08, 0.06)
	paper.roughness = 0.95
	pad.set_surface_override_material(0, paper)
	note.add_child(pad)
	if has_art:
		var page := MeshInstance3D.new()
		page.name = "NotePage"
		var qm := QuadMesh.new()
		qm.size = Vector2(page_w, page_h)
		page.mesh = qm
		page.position = Vector3(0, 0, 0.004)
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(tex_path)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.9
		page.set_surface_override_material(0, m)
		note.add_child(page)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(page_w, page_h, 0.06)
	col.shape = box
	note.add_child(col)
	return note


# The shut-in. The door slams across the mouth, the spur's torch dies, something batters the
# door from the corridor side for SPUR_SHUT_TIME (the SlamDoor's own batter clock, which also
# refuses E while it runs), a scrape rides under it, and then the door gives (`door_break`).
# Zero panic; one-shot per spur.
func _on_spur_sprung(entry: Dictionary) -> void:
	var door: SlamDoor = entry["door"]
	if not is_instance_valid(door):
		return
	for h in door.get_children():
		if h is Node3D and String(h.name).begins_with("Hinge"):
			(h as Node3D).visible = true
	door.call("_set_closed", true)
	_play_at("door_slam", entry["mouth"] + Vector3(0, 1.2, 0), 3.0)
	door.start_battering(null)
	var torch: Torch3D = entry["torch"]
	if is_instance_valid(torch):
		torch.extinguish()
	var s := GameState.load_audio("bone_scrape")
	if s:
		var pl := AudioStreamPlayer3D.new()
		pl.name = "Spur%dScrape" % int(entry["index"])
		pl.stream = s
		pl.volume_db = 0.0
		pl.unit_size = 8.0
		pl.bus = AudioBuses.AMBIENCE
		add_child(pl)
		pl.position = entry["mouth"] + Vector3(0, 1.0, 0) - (entry["dir"] as Vector3) * 0.8
		pl.finished.connect(pl.play)
		pl.play()
		entry["scrape"] = pl
		door.broken_open.connect(func() -> void:
			if is_instance_valid(pl):
				pl.finished.disconnect(pl.play)
				pl.stop()
				pl.queue_free(), CONNECT_ONE_SHOT)
	# The way out: mash Space (spur_escape.gd). Each bar is a beat; the third forces the door.
	var esc := SpurEscape.new()
	esc.name = "Spur%dEscape" % int(entry["index"])
	add_child(esc)
	esc.setup(door)
	esc.begin()
	entry["escape"] = esc
	esc.bar_filled.connect(func(n: int) -> void: _on_spur_bar(entry, n))
	esc.escaped.connect(func() -> void: _on_spur_escaped(entry))
	door.broken_open.connect(func() -> void: _on_spur_open(entry), CONNECT_ONE_SHOT)
	if String(entry["kind"]) == "mirror":
		_spur_mirror_figure(entry)
	if String(entry["kind"]) == "note":
		_spur_light_strip(entry)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("SHUT-IN spur %d (%s)" % [int(entry["index"]), String(entry["kind"])])


# The mirror spur: something stands BEHIND the player, between them and the shut door, and it is
# only in the glass — `MIRROR_ONLY_LAYER`, the turn mirrors' idiom. Freed when the door gives.
func _spur_mirror_figure(entry: Dictionary) -> void:
	var p := _player_node()
	if p == null:
		return
	var dir3: Vector3 = entry["dir"]
	var mouth: Vector3 = entry["mouth"]
	var here: Vector3 = p.global_position
	# 1.8 m back toward the mouth, never past the door.
	var back_d: float = minf(1.8, (here - mouth).dot(dir3) - 1.0)
	var pos: Vector3 = here - dir3 * back_d
	pos.y = 0.0
	var w := Watcher.spawn(self, pos, TURN_MIRROR_FIGURE_PATH, 0.0, false, MIRROR_FIGURE_HEIGHT)
	if w == null:
		push_warning("corridor: no clear spot for the spur mirror figure")
		return
	w.persistent = true
	w.name = "Spur%dFigure" % int(entry["index"])
	_set_mirror_only(w)
	entry["figure"] = w


func _on_spur_bar(entry: Dictionary, n: int) -> void:
	match String(entry["kind"]):
		"note":
			if n == 2:
				_spur_shadow_cross(entry)
		"plea":
			var pl := entry["plea"] as AudioStreamPlayer3D
			if is_instance_valid(pl):
				pl.volume_db += SPUR_PLEA_STEP_DB
				pl.max_db = maxf(pl.max_db, PLEA_DB + SPUR_PLEA_STEP_DB * n)
		_:
			pass


# The note spur's shut-in: with its torch dead, the only light left is the corridor's, leaking
# under the shut door as a thin warm strip (an unshaded quad at the threshold, facing into the
# spur). It exists so that a shadow can cross it. Freed when the door gives.
func _spur_light_strip(entry: Dictionary) -> void:
	var mouth: Vector3 = entry["mouth"]
	var dir3: Vector3 = entry["dir"]
	var strip := MeshInstance3D.new()
	strip.name = "Spur%dLightStrip" % int(entry["index"])
	var qm := QuadMesh.new()
	qm.size = Vector2(W - 0.1, 0.12)
	strip.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.95, 0.80, 0.55)
	m.emission_enabled = true
	m.emission = Color(0.95, 0.80, 0.55)
	m.emission_energy_multiplier = 1.0
	strip.set_surface_override_material(0, m)
	strip.transform = Transform3D(Basis(Vector3.UP, atan2(dir3.x, dir3.z)), mouth + dir3 * (T / 2.0 + 0.03) + Vector3(0, 0.07, 0))
	add_child(strip)
	entry["strip"] = strip
	var door: Node = entry["door"]
	door.broken_open.connect(func() -> void:
		if is_instance_valid(strip):
			strip.queue_free(), CONNECT_ONE_SHOT)


# A shadow crosses the strip of light under the door: a black quad standing just in front of the
# strip, tweened across the width in 1.2 s, then freed. No sound — the scrape is already there.
func _spur_shadow_cross(entry: Dictionary) -> void:
	var mouth: Vector3 = entry["mouth"]
	var dir3: Vector3 = entry["dir"]
	var lat3: Vector3 = entry["lat"]
	var sh := MeshInstance3D.new()
	sh.name = "Spur%dShadow" % int(entry["index"])
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.26)
	sh.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	sh.set_surface_override_material(0, m)
	var basis := Basis(Vector3.UP, atan2(dir3.x, dir3.z))
	var y := 0.08
	var from := mouth + dir3 * (T / 2.0 + 0.06) + lat3 * (W / 2.0 + 0.4) + Vector3(0, y, 0)
	var to := mouth + dir3 * (T / 2.0 + 0.06) - lat3 * (W / 2.0 + 0.4) + Vector3(0, y, 0)
	sh.transform = Transform3D(basis, from)
	add_child(sh)
	var tw := create_tween()
	tw.tween_property(sh, "position", to, 1.4).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(sh.queue_free)
	HoldBreath.dip(get_tree(), 0.6)


# The third bar forced the door.
func _on_spur_escaped(entry: Dictionary) -> void:
	if String(entry["kind"]) == "plea":
		var pl := entry["plea"] as AudioStreamPlayer3D
		if is_instance_valid(pl):
			if pl.finished.is_connected(pl.play):
				pl.finished.disconnect(pl.play)
			pl.stop()   # mid-word
		var hp := entry["handprint"] as Node3D
		if is_instance_valid(hp):
			hp.visible = true


# The door is open again (forced or the fallback clock): the spur's shut-in dressing goes.
func _on_spur_open(entry: Dictionary) -> void:
	var fig := entry["figure"] as Node
	if is_instance_valid(fig):
		fig.queue_free()
		entry["figure"] = null
	var esc := entry["escape"] as SpurEscape
	if is_instance_valid(esc):
		esc.finish()


func _player_node() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


# C5: the figure in the seventh door's gap. Spawned as the player comes within reach (so the
# Watcher's ray probes run with physics live), freed the moment they are past; the door shuts.
func _tick_break_door() -> void:
	if _break_done or _break_door == null or _player == null:
		return
	var d: float = _nearest_path_distance(_player.global_position)
	if not _break_spawned and d > BREAK_DOOR_AT - 12.0 and d < BREAK_DOOR_AT - 1.0:
		_break_spawned = true
		var pt := _path_point(BREAK_DOOR_AT)
		var into: Vector3 = (pt.side as Vector3) * BREAK_DOOR_SIDE
		var spot: Vector3 = pt.pos + into * (W / 2.0 - 0.3) + (pt.dir as Vector3) * 0.25
		spot.y = 0.0
		# A DoorLunger billboard, not a Watcher: it stands IN the doorway's gap, 0.3 m off the
		# wall plane, and Watcher.spawn()'s 0.9 m clearance fan refuses that by construction.
		# Same contract — no collider, no rules, no panic.
		var w := DoorLunger.build(self, spot, TURN_MIRROR_FIGURE_PATH, 1.85)
		w.name = "BreakDoorFigure"
		w.appear(0.01)
		_break_figure = w
		if _break_door.has_method("swing_ajar"):
			_break_door.call("swing_ajar", BREAK_DOOR_DEG, 0.01)   # already ajar when you first see it
	elif _break_spawned and d > BREAK_DOOR_AT + 3.0:
		_break_done = true
		if is_instance_valid(_break_figure):
			_break_figure.queue_free()
		_break_figure = null
		if is_instance_valid(_break_door) and _break_door.has_method("slam"):
			_break_door.call("slam")


func spurs() -> Array:
	return _spurs


func forks() -> Array:
	return _forks


func corner_branches() -> Array:
	return _branches


# Where a corner branch's mouth is: the OUTGOING segment's wall that faces the incoming leg's
# heading. Returns {seg, at, side}: `at` is the corner distance nudged 1 mm onto the outgoing leg
# (so the incoming leg's `at_local > len` guard skips it — a corner distance belongs to both
# segments) and `side` is the outgoing segment's side whose normal points along the incoming
# heading.
func _corner_branch_mouth(corner_d: float) -> Dictionary:
	for i in range(_segments.size()):
		var seg: Dictionary = _segments[i]
		if absf(float(seg["start_d"]) - corner_d) < 0.01 and i > 0:
			var d_in: Vector2 = _segments[i - 1]["dir"]
			var n: Vector2 = Vector2(seg.dir.y, -seg.dir.x)
			var side: float = 1.0 if n.dot(d_in) > 0.0 else -1.0
			return { "seg": i, "at": corner_d + 0.001, "side": side }
	return { "seg": -1, "at": corner_d, "side": 1.0 }


func _build_corner_branches() -> void:
	var branch_floor := _make_mat(TEX_DIR + "floor_crack.png", Vector3(0.6, 0.6, 0.6), Color(0.09, 0.08, 0.07))
	for i in range(CORNER_BRANCHES.size()):
		var cb: Dictionary = CORNER_BRANCHES[i]
		var corner_d: float = float(cb["corner"])
		var L: float = float(cb["len"])
		var cm := _corner_branch_mouth(corner_d)
		if int(cm["seg"]) < 0:
			push_warning("corridor: corner branch %d has no corner at d=%.0f" % [i, corner_d])
			continue
		var d_in2: Vector2 = _segments[int(cm["seg"]) - 1]["dir"]
		var corner2: Vector2 = _segments[int(cm["seg"])]["p0"]
		var p0: Vector2 = corner2 + d_in2 * (W / 2.0)          # the facing wall's inner face
		var seg := { "p0": p0, "dir": d_in2, "len": L, "start_d": 0.0 }
		var kind := String(cb["kind"])
		var room_len: float = L if kind != "blind" else L - BLIND_ROOM_SIZE
		_corridor_box("Branch%dFloor" % i, seg, T, room_len, 0.0, W + 2.0 * T, -T / 2.0, T, branch_floor)
		_corridor_box("Branch%dCeil" % i, seg, T, room_len, 0.0, W + 2.0 * T, H + T / 2.0, T, _ceil_mat)
		for s2 in [1.0, -1.0]:
			_corridor_box("Branch%dWall%s" % [i, "A" if s2 > 0 else "B"], seg, T, room_len, s2 * (W + T) / 2.0, T, H / 2.0, H + 2.0 * T, _wall_mat)
		var dir3 := Vector3(d_in2.x, 0, d_in2.y)
		var lat3 := Vector3(dir3.z, 0, -dir3.x)
		var mouth := Vector3(p0.x, 0, p0.y)
		var entry := { "index": i, "corner": corner_d, "kind": kind, "mouth": mouth, "dir": dir3, "lat": lat3, "len": L,
			"end": mouth + dir3 * room_len, "room": null, "loops": 0 }
		_branches.append(entry)
		# the trail: wet footprints on the incoming leg, then INTO the branch
		_spawn_footprint_trail(corner_d, dir3, lat3, mouth)
		if kind == "loop":
			_corridor_box("Branch%dEndCap" % i, seg, room_len, room_len + T, 0.0, W + 2.0 * T, H / 2.0, H + 2.0 * T, _wall_mat)
			var lb := DeadEndTrap.new()
			lb.name = "Branch%dLoopBack" % i
			var col := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(W, H, 1.6) if absf(dir3.z) > 0.5 else Vector3(1.6, H, W)
			col.shape = sh
			lb.add_child(col)
			lb.position = mouth + dir3 * (room_len - 1.2) + Vector3(0, H / 2.0, 0)
			add_child(lb)
			lb.sprung.connect(_on_branch_loop_back.bind(entry))
		else:
			_build_blind_room(entry, seg, room_len, branch_floor)


# The wet trail: alternating left/right prints along the hall's last TRAIL_BEFORE metres, then
# on into the branch. Floor decals, no collider, no panic — just something you can read.
func _spawn_footprint_trail(corner_d: float, dir3: Vector3, lat3: Vector3, mouth: Vector3) -> void:
	var tex := TEX_DIR + "wet_footprint.png"
	if not ResourceLoader.exists(tex):
		return
	var k := 0
	var d := corner_d - TRAIL_BEFORE
	while d < corner_d - 0.4:
		var pt := _path_point(d)
		var pos: Vector3 = pt.pos + lat3 * (0.18 if k % 2 == 0 else -0.18) + Vector3(0, FLOOR_DECAL_Y + 0.004, 0)
		_spawn_footprint(pos, dir3, k)
		d += TRAIL_STEP
		k += 1
	var into := T + 0.4
	while into < TRAIL_INTO:
		var pos2: Vector3 = mouth + dir3 * into + lat3 * (0.18 if k % 2 == 0 else -0.18) + Vector3(0, FLOOR_DECAL_Y + 0.004, 0)
		_spawn_footprint(pos2, dir3, k)
		into += TRAIL_STEP
		k += 1


func _spawn_footprint(pos: Vector3, dir3: Vector3, k: int) -> void:
	var q := MeshInstance3D.new()
	q.name = "Footprint%d_%d" % [int(pos.x * 10), k]
	var qm := QuadMesh.new()
	qm.size = Vector2(0.2, 0.42)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_DIR + "wet_footprint.png")
	m.emission_enabled = true
	m.emission = Color(0.25, 0.28, 0.32)
	m.emission_energy_multiplier = 0.12   # a sheen, not a lamp: the trail must be read, not announced
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.2
	m.metallic_specular = 0.9
	q.set_surface_override_material(0, m)
	var yaw := atan2(dir3.x, dir3.z)
	q.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.BACK, 0.0 if k % 2 == 0 else PI), pos)
	q.scale = Vector3(1.0 if k % 2 == 0 else -1.0, 1.0, 1.0)
	add_child(q)


# The loop-back: the branch's end puts you at the PREVIOUS corner, facing the way you were
# walking, with a slam behind you. Repeatable; each time the trail is a little louder (a second
# slam), never a panic term.
func _on_branch_loop_back(entry: Dictionary) -> void:
	var p := _player_node()
	if p == null:
		return
	entry["loops"] = int(entry["loops"]) + 1
	# the previous corner along the path (corners are the segments' start_d values)
	var prev_d: float = 0.0
	for sg in _segments:
		var sd: float = float(sg["start_d"])
		if sd < float(entry["corner"]) - 1.0 and sd > prev_d:
			prev_d = sd
	var pt := _path_point(prev_d + 1.5)
	p.velocity = Vector3.ZERO
	p.global_position = (pt.pos as Vector3) + Vector3(0, 0.1, 0)
	if p.has_method("turn_to_face"):
		p.call("turn_to_face", (pt.pos as Vector3) + (pt.dir as Vector3) * 8.0 + Vector3(0, 1.6, 0), 0.01)
	HoldBreath.dip(get_tree(), 0.6)
	_play_at("door_slam", (pt.pos as Vector3) - (pt.dir as Vector3) * 2.0 + Vector3(0, 1.2, 0), 3.0)
	if int(entry["loops"]) >= 2:
		_play_at("door_slam", (pt.pos as Vector3) - (pt.dir as Vector3) * 6.0 + Vector3(0, 1.2, 0), 1.0)
	# re-arm the trap for the next time
	var lb := get_node_or_null("Branch%dLoopBack" % int(entry["index"]))
	if lb:
		lb.set("_sprung", false)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("CORNER BRANCH %d: looped back to the previous corner (x%d)" % [int(entry["index"]), int(entry["loops"])])


# The blind room at the end of the 365 branch: a BLIND_ROOM_SIZE square, the branch's wall
# materials (wood at the sides of the entry, stone at the far wall, metal on the lever wall so
# they KNOCK differently), a portcullis at its mouth, the map on the wall behind the entry,
# the lever in the far-left corner.
func _build_blind_room(entry: Dictionary, seg: Dictionary, room_len: float, floor_mat: Material) -> void:
	var i: int = int(entry["index"])
	var dir3: Vector3 = entry["dir"]
	var lat3: Vector3 = entry["lat"]
	var R := BLIND_ROOM_SIZE
	var a0 := room_len              # the room spans a0 .. a0 + R along the branch
	_corridor_box("Blind%dFloor" % i, seg, a0, a0 + R, 0.0, R + 2.0 * T, -T / 2.0, T, floor_mat)
	_corridor_box("Blind%dCeil" % i, seg, a0, a0 + R, 0.0, R + 2.0 * T, H + T / 2.0, T, _ceil_mat)
	# side walls (wood), far wall (stone), the entry wall either side of the mouth (metal)
	_corridor_box("Blind%dWallWood" % i, seg, a0, a0 + R, (R + T) / 2.0, T, H / 2.0, H + 2.0 * T, _wall_mat)
	_corridor_box("Blind%dWallWood2" % i, seg, a0, a0 + R, -(R + T) / 2.0, T, H / 2.0, H + 2.0 * T, _wall_mat)
	_corridor_box("Blind%dWallStone" % i, seg, a0 + R, a0 + R + T, 0.0, R + 2.0 * T, H / 2.0, H + 2.0 * T, _wall_mat)
	for s2 in [1.0, -1.0]:
		_corridor_box("Blind%dWallMetal%s" % [i, "A" if s2 > 0 else "B"], seg, a0 - T, a0, s2 * (W / 2.0 + T + (R - W) / 4.0), (R - W) / 2.0, H / 2.0, H + 2.0 * T, _wall_mat)
	var mouth: Vector3 = entry["mouth"]
	var room_mouth: Vector3 = mouth + dir3 * a0
	var centre: Vector3 = mouth + dir3 * (a0 + R / 2.0)
	# the portcullis: a slab across the room's mouth, hidden + non-solid until sealed
	var gate := Node3D.new()
	gate.name = "Blind%dGate" % i
	add_child(gate)
	var slab := CSGBox3D.new()
	slab.name = "Slab"
	slab.size = Vector3(W, H, 0.12) if absf(dir3.z) > 0.5 else Vector3(0.12, H, W)
	slab.position = room_mouth - dir3 * 0.2 + Vector3(0, H / 2.0, 0)
	slab.material = _make_mat("", Vector3.ONE, Color(0.06, 0.05, 0.05))
	gate.add_child(slab)
	# the map, on the entry wall INSIDE the room, beside the mouth (behind you as you walk in)
	var mx := Transform3D(Basis(Vector3.UP, atan2(dir3.x, dir3.z)), room_mouth + dir3 * 0.03 + lat3 * ((W / 2.0 + R / 2.0) / 2.0) + Vector3(0, 1.5, 0))
	var map_quad := _spawn_quad(mx, Vector2(1.0, 1.0), TEX_DIR + "blind_map.png")
	if map_quad:
		map_quad.name = "Blind%dMap" % i
		var mm := map_quad.get_surface_override_material(0) as StandardMaterial3D
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var map_light := OmniLight3D.new()
	map_light.name = "Blind%dMapLight" % i
	map_light.light_energy = 2.5
	map_light.omni_range = 5.0
	map_light.light_color = Color(0.85, 0.9, 1.0)
	map_light.position = centre + Vector3(0, 2.4, 0)
	add_child(map_light)
	# the lever, far-left corner (left = -lat3 for someone walking in)
	var lever := StaticBody3D.new()
	lever.name = "Blind%dLever" % i
	lever.set_script(_BLIND_LEVER_SCRIPT)
	lever.position = mouth + dir3 * (a0 + R - 0.4) - lat3 * (R / 2.0 - 0.5) + Vector3(0, 1.1, 0)
	add_child(lever)
	var lm := _make_mat("", Vector3.ONE, Color(0.35, 0.3, 0.2))
	var plate := CSGBox3D.new()
	plate.size = Vector3(0.24, 0.5, 0.06)
	plate.material = lm
	plate.use_collision = false
	lever.add_child(plate)
	var arm := CSGBox3D.new()
	arm.size = Vector3(0.05, 0.4, 0.05)
	arm.position = Vector3(0, 0.05, -0.15)
	arm.rotation.x = 0.5
	arm.material = _make_mat("", Vector3.ONE, Color(0.5, 0.1, 0.08))
	arm.use_collision = false
	lever.add_child(arm)
	var lcol := CollisionShape3D.new()
	var lsh := BoxShape3D.new()
	lsh.size = Vector3(0.5, 0.7, 0.5)
	lcol.shape = lsh
	lever.add_child(lcol)
	# the room
	var room := BlindRoom.new()
	room.name = "Blind%dRoom" % i
	add_child(room)
	room.position = centre
	room.setup(gate, map_quad, map_light, lever, {
		"Blind%dWallWood" % i: "wood", "Blind%dWallWood2" % i: "wood", "Blind%dWallStone" % i: "stone",
		"Blind%dWallMetalA" % i: "metal", "Blind%dWallMetalB" % i: "metal", "Slab": "metal"})
	lever.set("room", room)
	entry["room"] = room
	# stepping past the mouth seals it
	var area := Area3D.new()
	area.name = "Blind%dEnter" % i
	var acol := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(W, H, 1.2) if absf(dir3.z) > 0.5 else Vector3(1.2, H, W)
	acol.shape = ash
	area.add_child(acol)
	area.position = room_mouth + dir3 * 1.2 + Vector3(0, H / 2.0, 0)
	add_child(area)
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			room.seal())


# The loop is three legs of boxes on synthetic segments, every box ABUTTING its neighbour (never
# overlapping — coincident faces are this project's oldest bug class, check_wall_overlap):
#   A  out from the hall (mouth at `at`) to the far corner
#   B  across, parallel to the hall, between the two far corners (its floor owns both corners)
#   C  back to the hall (mouth at `at + across`), through the door
func _build_forks() -> void:
	var branch_floor := _make_mat(TEX_DIR + "floor_crack.png", Vector3(0.6, 0.6, 0.6), Color(0.09, 0.08, 0.07))
	for i in range(FORKS.size()):
		var fk: Dictionary = FORKS[i]
		var at: float = float(fk["at"])
		var s: float = float(fk["side"])
		var LA: float = float(fk["out"])
		var LB: float = float(fk["across"])
		var pt := _path_point(at)
		var d2 := Vector2(pt.dir.x, pt.dir.z)
		var n2 := Vector2(pt.side.x, pt.side.z) * s
		var p0: Vector2 = Vector2(pt.pos.x, pt.pos.z) + n2 * (W / 2.0)     # A's mouth, at the wall face
		var segA := { "p0": p0, "dir": n2, "len": LA, "start_d": 0.0 }
		var pB0: Vector2 = p0 + n2 * LA                                    # B's centreline = the corner squares' centres
		var segB := { "p0": pB0, "dir": d2, "len": LB, "start_d": 0.0 }
		var pC0: Vector2 = pB0 + d2 * LB                                    # C starts at its corner, runs back to the hall
		var segC := { "p0": pC0, "dir": -n2, "len": LA, "start_d": 0.0 }
		var far_a: float = LA - W / 2.0 - T                                 # A stops where B's floor begins
		var hh: float = H / 2.0
		var wall_h: float = H + 2.0 * T
		# A
		_corridor_box("Fork%dAFloor" % i, segA, T, far_a, 0.0, W + 2.0 * T, -T / 2.0, T, branch_floor)
		_corridor_box("Fork%dACeil" % i, segA, T, far_a, 0.0, W + 2.0 * T, H + T / 2.0, T, _ceil_mat)
		_corridor_box("Fork%dAFar" % i, segA, T, far_a + T + W, s * (W + T) / 2.0, T, hh, wall_h, _wall_mat)   # the wall away from B, to B's outer wall
		_corridor_box("Fork%dANear" % i, segA, T, far_a, -s * (W + T) / 2.0, T, hh, wall_h, _wall_mat)        # the wall toward B, open at the corner
		# B (its floor covers both corners)
		_corridor_box("Fork%dBFloor" % i, segB, -W / 2.0 - T, LB + W / 2.0 + T, 0.0, W + 2.0 * T, -T / 2.0, T, branch_floor)
		_corridor_box("Fork%dBCeil" % i, segB, -W / 2.0 - T, LB + W / 2.0 + T, 0.0, W + 2.0 * T, H + T / 2.0, T, _ceil_mat)
		# B's lateral: n_B = (d2.y, -d2.x) = pt.side = s * n2 -> lateral +s is OUTWARD (away from the hall)
		_corridor_box("Fork%dBOuter" % i, segB, -W / 2.0 - T, LB + W / 2.0 + T, s * (W + T) / 2.0, T, hh, wall_h, _wall_mat)
		_corridor_box("Fork%dBInner" % i, segB, W / 2.0 + T, LB - W / 2.0 - T, -s * (W + T) / 2.0, T, hh, wall_h, _wall_mat)
		# C (mirrors A; its lateral +s is also the side away from B)
		# ⚠️ C runs from the CORNER CENTRE to the hall's wall face (LA away), so its boxes end at
		# LA - T — one wall thickness short of the face, like the spurs' start at T. The first build
		# ended them at LA - W/2 - T (A's arithmetic, where p0 IS the face) and left a 1.5 m hole in
		# the floor inside the door; the walker fell through it (probe_forks.gd found it).
		_corridor_box("Fork%dCFloor" % i, segC, W / 2.0 + T, LA - T, 0.0, W + 2.0 * T, -T / 2.0, T, branch_floor)
		_corridor_box("Fork%dCCeil" % i, segC, W / 2.0 + T, LA - T, 0.0, W + 2.0 * T, H + T / 2.0, T, _ceil_mat)
		_corridor_box("Fork%dCFar" % i, segC, -W / 2.0, LA - T, s * (W + T) / 2.0, T, hh, wall_h, _wall_mat)
		_corridor_box("Fork%dCNear" % i, segC, W / 2.0 + T, LA - T, -s * (W + T) / 2.0, T, hh, wall_h, _wall_mat)

		var dir3 := Vector3(n2.x, 0, n2.y)
		var fwd3 := Vector3(d2.x, 0, d2.y)
		var mouthA := Vector3(p0.x, 0, p0.y)
		var mouthC := Vector3(p0.x, 0, p0.y) + fwd3 * LB
		# The tell: a DEAD torch on A's jamb.
		var dead := Torch3D.new()
		dead.name = "Fork%dDeadTorch" % i
		dead.position = mouthA + dir3 * 0.6 + fwd3 * (-(W / 2.0) + 0.12) + Vector3(0, 1.9, 0)
		dead.rotation.y = atan2(fwd3.x, fwd3.z)
		add_child(dead)
		dead.extinguish()
		# The door at C's mouth: shut until the far corner is reached, then it opens onto the hall.
		var door := SlamDoor.new()
		door.name = "Fork%dDoor" % i
		door.door_width = W
		door.door_height = H
		door.door_texture = TEX_DIR + "hotel_door_leaf.png"
		door.batter_time = 9999.0
		door.player_operable = false   # C6: the far corner opens it; no "Press E" from the hall
		door.position = mouthC + dir3 * (T / 2.0)
		door.rotation.y = atan2(-fwd3.z, fwd3.x) + PI
		add_child(door)
		# The hidden note, on B's outer wall, halfway along.
		var note_pos: Vector3 = Vector3(pB0.x, 0, pB0.y) + fwd3 * (LB / 2.0) + dir3 * (W / 2.0 - WALL_INSET) + Vector3(0, 1.45, 0)
		var back3 := -dir3
		var nx := Transform3D(Basis(Vector3.UP, atan2(back3.x, back3.z)), note_pos)
		var note := _spawn_wall_page("Fork%dNote" % i, nx, TEX_DIR + "fork_note.png", 0.6, FORK_NOTE_TEXT)
		# Triggers: A's mouth (the scare) and B's far corner (the door opens).
		var entry := { "index": i, "door": door, "mouthA": mouthA, "mouthC": mouthC, "cornerA": Vector3(pB0.x, 0, pB0.y),
			"cornerC": Vector3(pC0.x, 0, pC0.y), "dir": dir3, "fwd": fwd3, "note": note, "scared": false, "opened": false, "figure": null }
		_forks.append(entry)
		var tA := DeadEndTrap.new()
		tA.name = "Fork%dEnter" % i
		var cA := CollisionShape3D.new()
		var shA := BoxShape3D.new()
		shA.size = Vector3(W, H, 1.6) if absf(dir3.z) > 0.5 else Vector3(1.6, H, W)
		cA.shape = shA
		tA.add_child(cA)
		tA.position = mouthA + dir3 * 1.6 + Vector3(0, H / 2.0, 0)
		add_child(tA)
		tA.sprung.connect(_on_fork_entered.bind(entry))
		var tC := DeadEndTrap.new()
		tC.name = "Fork%dCorner" % i
		var cC := CollisionShape3D.new()
		var shC := BoxShape3D.new()
		shC.size = Vector3(W, H, W)
		cC.shape = shC
		tC.add_child(cC)
		tC.position = Vector3(pC0.x, H / 2.0, pC0.y)
		add_child(tC)
		tC.sprung.connect(_on_fork_corner.bind(entry))
	# Doors start SHUT (after the level is built, so the collider is live).
	for e in _forks:
		(e["door"] as SlamDoor).call("_set_closed", true)


# Into the wrong branch: something stands at the far corner, and is gone as you approach.
func _on_fork_entered(entry: Dictionary) -> void:
	if entry["scared"]:
		return
	entry["scared"] = true
	var spot: Vector3 = entry["cornerC"]
	var w := Watcher.spawn(self, spot, TEX_DIR + "corridor_mirror_figure.png", 6.0, false, MIRROR_FIGURE_HEIGHT)
	if w:
		w.name = "Fork%dFigure" % int(entry["index"])
		entry["figure"] = w
	HoldBreath.dip(get_tree(), 0.8)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("FORK %d entered (wrong branch)" % int(entry["index"]))


# The far corner: the door back onto the hall opens by itself.
func _on_fork_corner(entry: Dictionary) -> void:
	if entry["opened"]:
		return
	entry["opened"] = true
	var door: SlamDoor = entry["door"]
	if is_instance_valid(door):
		door.call("_set_closed", false)
		_play_at("creak", entry["mouthC"] + Vector3(0, 1.2, 0), 0.0)


# Axis-aligned CSG box spanning [a, b] along the segment direction,
# `lateral` metres off the centerline, `width` across, `height` tall.
func _corridor_box(box_name: String, seg: Dictionary, a: float, b: float,
		lateral: float, width: float, y_center: float, height: float, mat: Material) -> void:
	var n: Vector2 = Vector2(seg.dir.y, -seg.dir.x)
	var mid2: Vector2 = seg.p0 + (seg.dir as Vector2) * ((a + b) / 2.0) + n * lateral
	var box := CSGBox3D.new()
	box.name = box_name
	box.use_collision = true
	if absf(seg.dir.x) > 0.5:
		box.size = Vector3(b - a, height, width)
	else:
		box.size = Vector3(width, height, b - a)
	box.position = Vector3(mid2.x, y_center, mid2.y)
	if mat:
		box.material = mat
	add_child(box)


# ---------------------------------------------------------------- props

func _spawn_torches() -> void:
	for entry in TORCHES:
		var dist: float = entry[0]
		var side: float = entry[1]
		var pt := _path_point(dist)
		var torch := Torch3D.new()
		torch.position = pt.pos + (pt.side as Vector3) * side * (W / 2.0 - 0.12) + Vector3(0, 1.9, 0)
		var inward: Vector3 = -(pt.side as Vector3) * side
		torch.rotation.y = atan2(inward.x, inward.z)
		add_child(torch)
		_torch_nodes.append([dist, torch])


func _spawn_panels() -> void:
	# Plain decor panels: [dist, side, w, h, texture, y_center]
	var decor := [
		[60.0, 1.0, 1.5, 1.2, "painting.png", 1.8],
		[180.0, -1.0, 1.5, 1.2, "painting.png", 1.8],
		[110.0, 1.0, 2.4, 1.8, "blood_corridor.png", 1.4],
		[150.0, -1.0, 2.4, 1.8, "blood_corridor.png", 1.4],
		[200.0, 1.0, 2.4, 1.8, "blood_corridor.png", 1.4],
		[246.0, -1.0, 2.4, 1.8, "blood_corridor.png", 1.4],
		[282.0, 1.0, 2.4, 1.8, "blood_corridor.png", 1.4],
		[308.0, -1.0, 2.4, 1.8, "blood_corridor.png", 1.4],
		[240.0, 1.0, 2.0, 3.0, "torch.png", 1.5],   # dead torches — Zone C
		[262.0, -1.0, 2.0, 3.0, "torch.png", 1.5],
		[300.0, 1.0, 2.0, 3.0, "torch.png", 1.5],
		[255.0, -1.0, 1.8, 1.2, "carpet.png", 1.6],  # wall-hung carpet
	]
	for p in decor:
		_spawn_quad(_panel_transform(p[0], p[1], p[5]), Vector2(p[2], p[3]), TEX_DIR + p[4])

	_spawn_kontur_hint()

	# Floor crack decals (static decor; the live crack event spawns its own)
	for crack in [[258.0, 0.4], [296.0, -0.5]]:
		var pt := _path_point(crack[0])
		var quad := _spawn_quad(Transform3D(), Vector2(1.6, 1.2), TEX_DIR + "floor_crack.png")
		if quad:
			quad.position = pt.pos + (pt.side as Vector3) * crack[1] \
				+ Vector3(0, FLOOR_DECAL_Y, 0)
			quad.rotation_degrees.x = -90.0
			# ⚠️ A decal lying on the floor must not cast. The player's flashlight is the one
			# `shadow_enabled` light in every level, so a quad hovering above the carpet
			# throws a hard black rectangle that slides as you walk — which is the opposite
			# of a crack in the floor.
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Cursed panels (gaze fills panic): [dist, side, w, h, texture, y_center, intensity]
	# The plain mirror.png stays a full-height side-wall panel — now one on each
	# wall in Zone C so the player is flanked by their own reflection.
	# ⚠️ The clock is NOT in this table any more (2026-09-10): it is a CASE built from parts by
	# `_spawn_grandfather_clock()` below, at the same d = 48 on the same wall, with the same
	# scare_intensity 1.0 — the user's call, made knowing it killed them at 14 s.
	var cursed := [
		[25.0, -1.0, 1.5, 1.2, "painting.png", 1.8, 0.8],
		[268.0, 1.0, 1.5, 1.2, "painting.png", 1.8, 1.2],
		[285.0, -1.0, 2.0, 3.0, "mirror.png", 1.5, 2.5],
		[288.0, 1.0, 2.0, 3.0, "mirror.png", 1.5, 2.0],
	]
	for p in cursed:
		_spawn_cursed_panel(p[0], p[1], Vector2(p[2], p[3]), TEX_DIR + p[4], p[5], p[6])
	_spawn_grandfather_clock()


# ⭐ THE GRANDFATHER CLOCK IS A CASE, NOT A PICTURE OF ONE (2026-09-10, the user's replay:
# *"Shall we make that clock 3d?"*). It stood in the `cursed` table above as a 2 x 3 m wall
# panel carrying `clock.png` — a photograph of a clock on wallpaper, the Issue-35 shape the
# rest of this level's props were rebuilt out of one by one. `grandfather_clock.gd` builds it
# from parts with a pendulum swinging behind glass and a drawn dial stopped at 2:17; the case
# stands on the floor against the +X wall with its back WALL_INSET clear of the plaster.
# ⚠️⚠️ `CLOCK_INTENSITY` 1.0 IS THE USER'S CALL (2026-09-10) — see the header of
# `grandfather_clock.gd`. The chime at d 46 (`_ev_clock_chime`) is unchanged and still speaks
# from the clock's own position.
const CLOCK_DIST := 48.0
const CLOCK_SIDE := 1.0
const CLOCK_INTENSITY := 1.0
var _clock: GrandfatherClock = null


func _spawn_grandfather_clock() -> void:
	var pt := _path_point(CLOCK_DIST)
	var side3: Vector3 = pt.side
	var inward: Vector3 = -side3 * CLOCK_SIDE
	var pos: Vector3 = pt.pos + side3 * CLOCK_SIDE * (W / 2.0 - WALL_INSET - GrandfatherClock.DEPTH / 2.0)
	# The same yaw rule as the panels: the case's local +z is its FRONT and must face the hall.
	var xform := Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.z)), pos)
	_clock = GrandfatherClock.build(self, xform, CLOCK_INTENSITY,
		TEX_DIR + "clock_face.png", TEX_DIR + "clock_walnut.png")

	# The creature in the glass: an ornate mirror set on the wall the player walks
	# straight at when reaching a turn — miss the turn and you walk into it.
	#
	# ⚠️ TWO MIRRORS, NOT THREE (2026-08-16, the user's call on their verification replay:
	# *"the mirror appears too often - can we make it two time, once at the exact place it
	# shows up for the first time, and the second time is when it appears last"*). The FIRST
	# (d=90, the corner where Zone A ends) and the LAST (d=275, deep in Zone C) are kept;
	# the middle one at d=230 is gone, frame, figure and gaze panel with it.
	#
	# What that cost the level's panic profile, measured rather than assumed:
	#   * flash panic is UNCHANGED at 24 per run. With three mirrors `_pick_silent_mirror()`
	#     muted exactly one, so every run took 2 x TURN_MIRROR_PANIC 12. With two mirrors and
	#     no mute (see `_pick_silent_mirror`) it is still 2 x 12.
	#   * one GAZE panel is gone: d=230 carried `scare_intensity` 2.0 = 40 panic/s. Neither
	#     logged traversal ever stopped there, so its measured contribution was 0 both times;
	#     what is removed is a worst case, not an observed cost.
	#
	# ⚠️ DELIBERATE (2026-08-16): the gaze intensities are UNCHANGED, and that was a decision.
	# Measured in the playtest log, standing still at the 90 m mirror: panic 23 % → 53 % →
	# 72 % in **1.0 second** — `scare_intensity 1.5` x `PANIC_BASE_RATE` 20 = **30 panic/s**,
	# and both of the user's traversals peaked (75 % and 72 %) on this one object. It was
	# raised as a possible difficulty defect and the user's call was to LEAVE IT: the number
	# was set when the mirror was a flat painting nobody had any reason to stare at, and it
	# will be re-judged in play now that the glass actually reflects. Do not re-file this as
	# a bug; it is a difficulty constant with a decision already attached.
	for tm in TURN_MIRRORS:
		_spawn_turn_mirror(tm[0], tm[1])

	# Locked hotel room doors that knock back, plus plain decor doors for atmosphere.
	for fd in [[35.0, -1.0], [130.0, 1.0], [252.0, 1.0]]:
		_spawn_fake_door(fd[0], fd[1])
	# ⚠️ These six were flat, inert `QuadMesh`es glued to the wallpaper — pure decor, with
	# no way to open because there was nothing there to open. They are real hinged doors
	# now, which gives the level the one rule a haunted hotel corridor has always wanted:
	# doors you have already walked past open behind you. See _tick_doors().
	for dd in [[18.0, 1.0], [72.0, -1.0], [112.0, 1.0], [164.0, -1.0], [210.0, 1.0], [300.0, -1.0]]:
		# The hinge is shifted half a width along the wall so the door stays centred where
		# the old flat decal was — AjarDoor's panel extends from its origin along local +x.
		#
		# ⚠️ `WALL_INSET`, not the 0.14 this shipped with. `AjarDoor` now hinges on its own
		# BACK FACE, so the whole leaf lives in front of this plane and the closed door sits
		# 3 cm off the wallpaper like every other flush prop in the level. At 0.14 with the
		# old centre-hinge the leaf floated 9.0 cm out with nothing behind it, which is
		# capture C2. See `_panel_transform`'s note and `ajar_door.gd`.
		var xf := _panel_transform(dd[0], dd[1], 0.0, WALL_INSET) \
			.translated_local(Vector3(-AjarDoor.WIDTH / 2.0, 0.0, 0.0))
		var d := AjarDoor.build(self, xf, TEX_DIR + "hotel_door_leaf.png")
		d.name = "AjarDoor_%d" % int(dd[0])
		_ajar_doors.append({ "node": d, "dist": float(dd[0]), "opened": false })
		_spawn_door_frame(dd[0], dd[1], AjarDoor.WIDTH, AjarDoor.HEIGHT, "AjarFrame_%d" % int(dd[0]))
	# ⭐ C5 (2026-09-14): THE RHYTHM BREAK. Six doors that swing ajar the same way teach a rhythm;
	# the SEVENTH, at BREAK_DOOR_AT, is already ajar when you arrive and something stands in its
	# gap — a Watcher just inside the leaf's plane, visible only from the far side of the hall
	# (the leaf hides it from the near side), and gone once you are past. Zero panic.
	var bx := _panel_transform(BREAK_DOOR_AT, BREAK_DOOR_SIDE, 0.0, WALL_INSET) \
		.translated_local(Vector3(-AjarDoor.WIDTH / 2.0, 0.0, 0.0))
	var bd := AjarDoor.build(self, bx, TEX_DIR + "hotel_door_leaf.png")
	bd.name = "AjarDoor_break"
	_spawn_door_frame(BREAK_DOOR_AT, BREAK_DOOR_SIDE, AjarDoor.WIDTH, AjarDoor.HEIGHT, "AjarFrame_break")
	_break_door = bd   # swung ajar as the player approaches (see _tick_break_door)


# Transform flush against the wall at `dist` on `side`, quad facing inward.
#
# `depth_inset` is how far the origin sits IN from the wall's inner face.
#
# ⚠️ THE DEFAULT IS THE LEVEL'S MOUNTING CONVENTION, and it is now 0.03 (2026-08-16). It was
# 0.02, which is EXACTLY `check_wall_overlap.gd`'s `MIN_CLEAR` — and that check grows the
# wall box by MIN_CLEAR and asks whether the prop is inside, with `AABB.has_point()`
# including its own boundary. So every flat decal in this level sat precisely on the
# threshold and was reported: 20 findings the first time the guard was ever pointed at this
# scene. 0.03 clears it with a millimetre to spare and is not a visible difference on a
# wall in a corridor lit at 0.45.
#
# ⚠️ It is NOT the value to pass for anything with depth. `AjarDoor` hinges on its own BACK
# FACE (see `ajar_door.gd`), so 0.03 there means "the closed leaf sits 3 cm off the
# wallpaper" — which is what it should be, and what it was not: the doors shipped at
# `depth_inset = 0.14`, i.e. floating 9 cm off the wall, and the user photographed them
# ("some of the doors in the corridor are not linked to the walls").
const WALL_INSET := 0.03
# Floor decals ride the same convention as wall decals, for the same reason: at the old
# 0.012 they sat inside `MIN_CLEAR` of the floor slab and were reported.
const FLOOR_DECAL_Y := 0.03
func _panel_transform(dist: float, side: float, y_center: float,
		depth_inset: float = WALL_INSET) -> Transform3D:
	var pt := _path_point(dist)
	var inward: Vector3 = -(pt.side as Vector3) * side
	var pos: Vector3 = pt.pos + (pt.side as Vector3) * side * (W / 2.0 - depth_inset) \
		+ Vector3(0, y_center, 0)
	return Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.z)), pos)


# KONTUR HINT 3/4 — the answer to KONTUR's Gate 3 (the offering): "RECOVERED ITEMS ARE BAIT.
# LEAVE THEM." Reads as hotel signage here; only two levels later does it mean anything.
#
# ⚠️ REBUILT 2026-08-16. It was a **2.0 x 3.0 m full-height wall panel** wearing the raw
# `kontur_plate.png` — a 1.333 landscape source on a 0.667 portrait mesh, **stretched 2.00x**,
# the worst distortion measured anywhere in this level, on the one prop in it whose entire
# payload is four words the player has to be able to READ. The old comment defended the
# full-height panel on the grounds that "the art carries its own wallpaper+wainscot
# background" — which is Issue 35 stated as a justification rather than as the defect it is.
#
# Now: the art is cropped to the plate and alpha-masked to its outline
# (`tools/crop_corridor_art.py`), and it hangs at plate size, at eye height, undistorted.
const KONTUR_HINT_DIST := 172.0
# ⚠️ 1.15 m is larger than a real hotel notice plate and that is the point: this is the only
# hint for KONTUR's Gate 3 planted in this level, its payload is four words, and it hangs at
# d=172 in a stretch lit at 0.45. Legibility from the corridor centreline wins over plate
# realism. The level's own decor panels are 2.0-2.4 m wide, so it is still the small thing
# on that wall.
const KONTUR_HINT_WIDTH := 1.15
const KONTUR_HINT_Y := 1.62      # eye height for a 1.7 m camera, read while walking past

func _spawn_kontur_hint() -> void:
	var tex_path := TEX_DIR + "kontur_plate_crop.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path)
	# ⚠️ Height from the CROP's own aspect. Hard-coding it is how the 2.00x got here.
	var h: float = KONTUR_HINT_WIDTH * float(tex.get_height()) / float(tex.get_width())
	var quad := _spawn_quad(_panel_transform(KONTUR_HINT_DIST, -1.0, KONTUR_HINT_Y),
		Vector2(KONTUR_HINT_WIDTH, h), tex_path)
	if quad == null:
		return
	quad.name = "KonturHintPlate"
	var mat: StandardMaterial3D = quad.get_surface_override_material(0)
	# The alpha mask keys away the generator's own damask wallpaper at the plate's ogee
	# corners — without this the cutout renders as an opaque rectangle (Issue 25's cousin).
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.4
	mat.roughness = 0.5
	# Faintly self-lit so it can be found at all: d=172 is 4 m past the last torch of the
	# dark stretch. Well under 1.0 — above that it clamps to flat white (Issue 21).
	#
	# ⚠️ TEXTURED EMISSION, AND `EMISSION_OP_MULTIPLY`. Both halves matter, and the second one
	# is the trap: Godot's default `emission_operator` is **ADD**, so setting an emission
	# COLOUR alongside an emission TEXTURE adds a flat wash over the whole surface rather
	# than tinting the artwork. Measured here: a near-black plate (source mean RGB 59,59,50)
	# rendered as a pale cream slab with the lettering knocked out of it, photographed in
	# `15_kontur_plate.png`. This level's exit door already documents the same symptom two
	# functions down ("the emission was reading as its flat colour rather than modulating the
	# texture") without naming the cause. With MULTIPLY the brass bead and the gold letters
	# are what glow, which is what a torch-lit plate does.
	mat.emission_enabled = true
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission = Color(1.0, 0.92, 0.70)
	mat.emission_texture = load(tex_path)
	mat.emission_energy_multiplier = 0.9


func _spawn_quad(xform: Transform3D, size: Vector2, tex_path: String) -> MeshInstance3D:
	if not ResourceLoader.exists(tex_path):
		return null
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(tex_path)
	mat.roughness = 0.9
	quad.set_surface_override_material(0, mat)
	quad.transform = xform
	# Named from its own artwork. Godot calls an unnamed MeshInstance3D "@MeshInstance3D@NN",
	# which is unreadable in every test report this level produces — and this level's props
	# are all built in code, so nothing else would ever name them.
	quad.name = "Decal_%s" % tex_path.get_file().get_basename()
	add_child(quad)
	return quad


func _spawn_cursed_panel(dist: float, side: float, size: Vector2, tex_path: String,
		y_center: float, intensity: float) -> void:
	_make_cursed_panel_at(_panel_transform(dist, side, y_center), size, tex_path, intensity)


# A turn mirror sits flush on the wall directly ahead at a corner (the wall you
# face if you fail to turn), so you approach the creature in the glass head-on.
func _spawn_turn_mirror(corner_dist: float, intensity: float) -> void:
	var pt := _path_point(corner_dist)
	var dir_in: Vector3 = pt.dir  # at a corner distance, _path_point returns the incoming segment
	var pos: Vector3 = pt.pos + dir_in * (W / 2.0 - WALL_INSET) + Vector3(0, 1.5, 0)
	var face := -dir_in
	var xform := Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)), pos)
	var quad := _make_cursed_panel_at(xform, Vector2(1.4, 1.95), TURN_MIRROR_SCARE_PATH, intensity)
	_make_mirror_real(quad, pt, face)
	# ⚠️ The frame is GEOMETRY, and it has to be. `MirrorSurface.attach()` replaces the quad's
	# material with the live reflection, which throws away the ornate border that
	# `mirror_with_creature.png` used to paint — so since the mirrors started reflecting they
	# have been unframed rectangles of corridor floating on the wallpaper. Issue 35's rule
	# again: silhouette carries a prop.
	_spawn_frame_bars(xform, Vector2(1.4, 1.95), "MirrorFrame_%d" % int(corner_dist),
		Color(0.085, 0.070, 0.042), 0.055, 0.075)
	# `flashes` is decided in _pick_silent_mirror(), which is now a no-op at two mirrors —
	# see the ⚠️ there. `woke` is the appearance cue's one-shot; `fired` is the 2 m
	# flash's. Two different beats, two different flags, deliberately not merged.
	_turn_mirrors.append({
		"pos": pos, "fired": false, "flashes": true, "woke": false,
		"stare": 0.0, "stare_player": _spawn_stare_emitter(pos, int(corner_dist)),
	})


# The per-mirror stare loop. Built stopped; `_tick_mirror_stare()` starts and rides it.
# See the MIRROR_STARE_* block for what this is for and why it costs no panic.
func _spawn_stare_emitter(pos: Vector3, corner_dist: int) -> AudioStreamPlayer3D:
	var stream := GameState.load_audio("mirror_stare")
	if stream == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "MirrorStare_%d" % corner_dist
	p.stream = stream
	p.unit_size = 8.0
	p.max_db = MIRROR_STARE_MAX_DB
	p.volume_db = MIRROR_STARE_DB.x
	p.position = pos
	# ⚠️ Every .wav.import in this project is `loop_mode = 0`, so a loop is restarted in code.
	# Without this the tell plays once for three seconds and then leaves the player staring at
	# a silent mirror while the panel keeps charging — the exact failure it exists to prevent.
	p.finished.connect(p.play)
	add_child(p)
	return p


# Build a gaze-panic panel (StaticBody + textured quad + collision + ScaryObject)
# at an arbitrary transform.
func _make_cursed_panel_at(xform: Transform3D, size: Vector2, tex_path: String,
		intensity: float) -> MeshInstance3D:
	# The ScaryObject must be an ANCESTOR of the collider — player.gd's gaze check
	# walks UP from the ray-hit StaticBody. Previously it was a child of the body,
	# so no cursed panel (paintings, clock, mirrors) ever fed gaze panic.
	# ScaryObject is a plain Node (no transform) and breaks the spatial chain, so
	# the world transform lives on the StaticBody3D itself (parent non-spatial ->
	# the body's local transform IS its global transform).
	var scary := ScaryObject.new()
	scary.scare_intensity = intensity
	add_child(scary)

	var body := StaticBody3D.new()
	body.transform = xform
	scary.add_child(body)

	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	else:
		mat.albedo_color = Color(0.1, 0.08, 0.06)
	mat.roughness = 0.9
	quad.set_surface_override_material(0, mat)
	body.add_child(quad)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, 0.1)
	col.shape = shape
	body.add_child(col)
	return quad


# ⭐ Turn a painted mirror into a REFLECTING one, and put something in it that is not in
# the corridor (2026-08-15).
#
# The old turn mirror was `mirror_with_creature.png` on a flat quad — the user's report was
# "it does not really look like a mirror," and it wasn't: nothing in this project reflected
# anything (no ReflectionProbe, no SSR, no SubViewport). See mirror_surface.gd.
#
# The creature is now a real `Watcher` standing in the corridor on MIRROR_ONLY_LAYER: the
# player's camera drops that layer (player.gd:_ready), the reflection camera keeps it. So
# the glass shows a figure over your shoulder, you turn round, and the corridor is empty —
# which is a far better beat than a painted figure, and it costs no panic and has no rules
# (watcher.gd), so it cannot kill anyone by surprise.
#
# ⚠️ Everything else about the turn mirror is untouched: the ScaryObject gaze intensity, the
# 2 m one-shot `flash_scare`, and `_pick_silent_mirror()`'s anti-habituation roll. Those are
# playtest-derived and were not part of this change.
const MIRROR_FIGURE_DIST := 7.0    # metres in front of the glass, i.e. behind the player
# ⭐ OFF THE CENTRELINE, AND THAT IS THE WHOLE ANSWER TO "MAKE IT MOVE AGAIN" (2026-08-16).
#
# User report on the verification replay: *"It used to be in a way that the reflection in the
# mirror moves, now it is static."* Diagnosed in full above `_aim()` in mirror_surface.gd —
# the reflection is live, and the motion that was lost was the old camera inheriting the
# player's HEADING and panning with the mouse, which a mirror cannot do. What the user chose,
# once shown that, was the geometric fix, and this is it.
#
# ⚠️ A POINT ON THE MIRROR'S AXIS IS A FIXED POINT OF THE PROJECTION UNDER AXIAL MOTION.
# The player walks the centreline; the mirror hangs on that axis; the figure stood exactly on
# it. Measured — the figure's position across the glass over the whole 12 m -> 1 m approach,
# in pixels of the 551 px pane:
#
#     offset 0.00 m    275.5 px at every distance   ->    0.0 px of travel. Zero. Exactly.
#     offset 0.45 m    163.6 -> 253.4 px            ->   89.7 px  (16.3 % of the pane)
#     offset 0.60 m    126.4 -> 246.0 px            ->  119.6 px  (21.7 % of the pane)
#
# So on the centreline the one thing the player is looking at was the one thing that
# mathematically could not move as they walked toward it. Strafing always worked (~146 px per
# 0.5 m); the APPROACH is what was dead, and the approach is what a corridor gives you.
#
# ⚠️ THE PREVIOUS COMMENT HERE BLAMED THE WALLS, AND IT WAS WRONG. It read: *"an earlier
# 0.55 m offset ... the billboard is 1.6 m wide, so at 0.55 off-centre its edge came within
# 0.15 m of the wall of a 3 m corridor and the clearance fan refused it."* `Watcher.FIT_RADIUS`
# is a flat **0.9 m** and is NOT scaled by the billboard's width, and the corridor's wall face
# is at W/2 = 1.5 m — so the walls alone permit up to 0.6 m. What actually refused those
# placements was WALL PROPS: the fan's 0.9 m reach at 0.55 m offset extends to 1.45 m, and a
# cursed panel's collider (`painting.png` at d=268, side +1) spans 1.43-1.53 m. Re-derived and
# then measured per mirror by `check_mirror_figure.gd`.
#
# ⚠️ IT IS A LADDER, NOT A CONSTANT, and that is the important part. A refused
# `Watcher.spawn()` returns null and the old loop simply `continue`d — so a figure could
# vanish from a mirror in silence, which is exactly how this level lost two of three once
# before. `_spawn_mirror_figures()` walks these candidates in order and takes the first that
# FITS, per mirror, recording what it settled on in `_mirror_figure_offsets` so a test can
# assert both that every mirror got a figure and that it is not secretly back on the axis.
const MIRROR_FIGURE_SIDE := 0.45
# Tried in order, per mirror: the full offset both ways, then progressively less. The corridor
# is symmetric, so a mirror blocked on one side is nearly always clear on the other.
# ⚠️ 0.0 IS DELIBERATELY NOT IN THIS LIST. Falling back to the centreline would restore the
# exact zero-parallax placement this change exists to remove, and would do it silently.
# `MIRROR_FIGURE_SIDE_MIN` is the floor a figure is allowed to end up at; below that the level
# would rather have no figure, and `check_mirror_figure.gd` fails if one ever does.
const MIRROR_FIGURE_SIDE_LADDER := [0.45, -0.45, 0.36, -0.36, 0.28, -0.28]
const MIRROR_FIGURE_SIDE_MIN := 0.25
# ⭐ A DEDICATED FIGURE, AND IT IS YOU (2026-08-16). The user flagged the mirror twice —
# *"can we generate a creepy weird image like it's the main character but without eyes or
# something like this"* — and the second time unprompted. This is a gaunt, chalk-pale,
# EYELESS adult in the asylum gown from the Intro ward. The gown is what identifies it: the
# game never shows the player their own face, so there is no canonical one to draw, and the
# garment they woke up in does the work instead.
#
# ⚠️ CORRIDOR MIRRORS ONLY. `watcher_figure.png` is shared with this level's own doorway
# Watcher, the House cellar child and the Sprawl's Congregation — swapping it would rewrite
# three other levels' occupants. New asset, new name.
#
# ⚠️ A real RGBA cutout (192x804, alpha extrema 0..255) or it billboards as a solid
# rectangle: the `apparition_figure.jpg` bug. Made with
# `tools/cutout_alpha.py --green`, from `assets_src/textures/level_3_corridor/`.
const TURN_MIRROR_FIGURE_PATH := "res://assets/textures/level_3_corridor/corridor_mirror_figure.png"
# ⚠️ Person-sized. `Watcher.SIZE.y` defaults to 2.4 m, which was survivable while the art
# had headroom baked into it; this cutout is head-to-bare-feet, so 2.4 would put a
# two-and-a-half-metre giant in the glass.
const MIRROR_FIGURE_HEIGHT := 1.85

# [{base, side}] — the ON-AXIS point 7 m down the corridor, and the unit vector across it.
# The lateral offset is chosen per mirror in _spawn_mirror_figures(), which needs physics.
var _mirror_figure_spots: Array[Dictionary] = []
# What each figure actually settled on, in metres, signed. Read by check_mirror_figure.gd —
# the point of recording it is that "the figure spawned" and "the figure spawned somewhere
# with parallax" are different claims and only the second one is worth anything.
var _mirror_figure_offsets: Array[float] = []

func _make_mirror_real(quad: MeshInstance3D, pt: Dictionary, face: Vector3) -> void:
	if quad == null:
		return
	MirrorSurface.attach(quad)

	# The figure stands down the corridor the mirror looks along — the stretch the player
	# has just walked. `face` points from the glass back into that corridor.
	var side_vec: Vector3 = Vector3(face.z, 0, -face.x)
	var fig_pos: Vector3 = quad.global_position + face * MIRROR_FIGURE_DIST
	fig_pos.y = 0.0
	# ⚠️ QUEUED, not spawned here. `Watcher.spawn()` clearance-probes with raycasts, and
	# during `_ready()` the CSG colliders this level has just built are not yet registered
	# with the physics server — so the probe is querying an empty world and its answers are
	# meaningless. Measured: called inline, one of three figures survived; called from the
	# first _process tick, all three do, and the same call from a test probe at t=1 s always
	# worked, which is what pointed at timing rather than at placement.
	_mirror_figure_spots.append({ "base": fig_pos, "side": side_vec })


# Runs once, on the first frame, when physics knows about the level.
func _spawn_mirror_figures() -> void:
	for i in _mirror_figure_spots.size():
		var spot: Dictionary = _mirror_figure_spots[i]
		var base: Vector3 = spot["base"]
		var side_vec: Vector3 = spot["side"]
		var w: Watcher = null
		var used := 0.0
		# ⚠️ The LADDER. Take the largest offset that FITS at this particular mirror rather
		# than one constant applied blind — the corridor is symmetric so a spot blocked by a
		# wall prop on one side is almost always clear on the other, and a silently refused
		# spawn is how this level lost two of three figures once already.
		for off in MIRROR_FIGURE_SIDE_LADDER:
			# ⚠️ `require_los = false` because the player is 90+ m away round two corners, so
			# an LOS check would refuse every one of these. The clearance fan and head-room
			# probes still run, and the base point is on the corridor centreline, so it cannot
			# land inside geometry — the case require_los normally guards.
			w = Watcher.spawn(self, base + side_vec * off, TURN_MIRROR_FIGURE_PATH, 0.0,
				false, MIRROR_FIGURE_HEIGHT)
			if w != null:
				used = off
				break
		_mirror_figure_offsets.append(used)
		if w == null:
			# ⚠️ LOUD. The old code did a bare `continue` here, so a mirror with no figure in
			# it looked exactly like a mirror with a figure in it that you had not spotted.
			push_warning("corridor: no clear spot for MirrorFigure%d at %s — the glass is empty"
				% [i, str(base.round())])
			continue
		# ⚠️ PERSISTENT, or it deletes itself. A default Watcher is an apparition: it expires
		# at MAX_LIFETIME and rolls to vanish whenever the player looks away and back. These
		# are fixtures — the thing in the glass has to be there every time you pass the
		# corner, and the look-away roll is meaningless for a figure the player's camera
		# cannot see at all.
		w.persistent = true
		# ⚠️ Named distinctly. Watcher.spawn() calls every one of them "Watcher", and Godot
		# silently renames the collisions — which made a test counting them by name report
		# one figure where three existed. The name also says what this one IS: not a roaming
		# Watcher, a fixture that lives in a mirror.
		w.name = "MirrorFigure%d" % i
		# Render it ONLY into mirrors. Watcher builds its own billboard quad, so walk its
		# meshes rather than assuming a shape.
		_set_mirror_only(w)
	_mirror_figure_spots.clear()


func _set_mirror_only(n: Node) -> void:
	if n is VisualInstance3D:
		n.layers = 1 << (MirrorSurface.MIRROR_ONLY_LAYER - 1)
	for c in n.get_children():
		_set_mirror_only(c)


func _spawn_fake_door(dist: float, side: float) -> void:
	var body := FakeDoor.new()
	body.name = "FakeDoor_%d" % int(dist)
	body.transform = _panel_transform(dist, side, AjarDoor.HEIGHT / 2.0)
	add_child(body)

	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	# ⚠️ Leaf-sized, from the CROPPED art's own aspect (2026-08-16). This was 1.4 x 2.1 with
	# the uncropped `ordinary_hotel_door.png` on it — a 0.800 source on a 0.667 mesh, 1.29x
	# squashed, and the art it was squashing was a picture of a door *plus the wall around
	# it*, so three of these were hanging a photograph of a wall on a wall (Issue 35).
	mesh.size = Vector2(AjarDoor.WIDTH, AjarDoor.HEIGHT)
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	var door_tex := TEX_DIR + "hotel_door_leaf.png"
	if ResourceLoader.exists(door_tex):
		mat.albedo_texture = load(door_tex)
	else:
		mat.albedo_color = Color(0.15, 0.1, 0.06)
	mat.roughness = 0.9
	quad.set_surface_override_material(0, mat)
	body.add_child(quad)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(AjarDoor.WIDTH, AjarDoor.HEIGHT, 0.1)
	col.shape = shape
	body.add_child(col)

	_spawn_door_frame(dist, side, AjarDoor.WIDTH, AjarDoor.HEIGHT, "FakeFrame_%d" % int(dist))


# ⭐ THE ARCHITRAVE THE ARTWORK USED TO DEPICT, AS REAL GEOMETRY (2026-08-16).
#
# `ordinary_hotel_door.png` was a door plus its casing plus the wallpaper either side, and
# every door in this level was that picture on a flat rectangle — Issue 35's exact shape:
# *"when a prop is meant to sit on a surface, art whose background IS that surface guarantees
# it reads as flat, no matter how the mesh is built."* The art is cropped to the leaf now
# (`tools/crop_corridor_art.py`) and the casing is four boxes standing proud of the wall with
# the leaf recessed inside them. Silhouette carries a prop; art does not (Issue 35).
#
# ⚠️ NOT a child of the AjarDoor. The leaf rotates; a frame parented to it would swing open
# with the door, which is the one thing a door frame may never do.
#
# ⚠️ No collider. In a 3 m hall a 6 cm bead either side of every door is a walkable-width
# problem waiting to happen, and `check_corridor_doors.gd`'s soft-lock assertion measures
# meshes. These are decoration in the strict sense: they are seen and never touched.
const FRAME_BEAD := 0.075     # how wide the casing reads on the wall
const FRAME_PROUD := 0.085    # how far it stands off the wallpaper
const FRAME_SINK := 0.01      # ...and how far it is buried, so no seam line shows

func _spawn_door_frame(dist: float, side: float, leaf_w: float, leaf_h: float,
		node_name: String) -> void:
	# Origin on the leaf's centre, on the level's own wall inset. No bottom bar: the floor is
	# the threshold, and a bar across a doorway a player walks past reads as a tripping
	# hazard rather than as joinery.
	_spawn_frame_bars(_panel_transform(dist, side, leaf_h / 2.0), Vector2(leaf_w, leaf_h),
		node_name, Color(0.055, 0.047, 0.038), FRAME_BEAD, FRAME_PROUD, false)


# Four (or three) bars framing a panel, standing `proud` off the wall so the panel inside
# them reads as recessed. Shared by the door architraves and the turn-mirror frames.
#
# `xform` is the PANEL's transform — origin at its centre, `WALL_INSET` off the wall face,
# +z into the corridor — so the bars are sunk `WALL_INSET + FRAME_SINK` in local z to bury
# their back edge in the wallpaper and leave no seam line.
func _spawn_frame_bars(xform: Transform3D, size: Vector2, node_name: String,
		colour: Color, bead: float, proud: float, with_bottom: bool = true,
		emission: Color = Color.BLACK, emission_energy: float = 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	# ⚠️ OPT-IN, default OFF — the door architraves and the mirror frames render byte-identically
	# to before. Only the false exit door's casing lights up, because the blood-red glow is the
	# convention this game has taught for "the way out" and that is the whole deception.
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy

	var root := Node3D.new()
	root.name = node_name
	root.transform = xform
	add_child(root)

	var back := WALL_INSET + FRAME_SINK      # local z of the bars' back face (negative)
	var depth := back + proud
	var half_w := size.x / 2.0 + bead / 2.0
	var half_h := size.y / 2.0 + bead / 2.0
	# [x, y, width, height], in the panel's own frame.
	var bars := [
		[-half_w, 0.0, bead, size.y + 2.0 * bead],
		[half_w, 0.0, bead, size.y + 2.0 * bead],
		[0.0, half_h, size.x, bead],
	]
	if with_bottom:
		bars.append([0.0, -half_h, size.x, bead])
	for i in bars.size():
		var b: Array = bars[i]
		var mi := MeshInstance3D.new()
		mi.name = "%s_Bar%d" % [node_name, i]
		var bm := BoxMesh.new()
		bm.size = Vector3(b[2], b[3], depth)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(b[0], b[1], (proud - back) / 2.0)
		root.add_child(mi)


func _spawn_beartraps() -> void:
	for entry in BEARTRAPS:
		var pt := _path_point(entry[0])
		var trap := Beartrap.new()
		trap.position = pt.pos + (pt.side as Vector3) * entry[1]
		add_child(trap)


func _spawn_dark_zones() -> void:
	for zone_range in DARK_ZONES:
		_spawn_zone_boxes(zone_range, func() -> Area3D: return DarkZone.new())


func _spawn_dread_zone() -> void:
	_spawn_zone_boxes(DREAD_ZONE, func() -> Area3D: return DreadZone.new())


# Cover [range.x, range.y] of the path with axis-aligned Area3D boxes, one per
# segment slice. `make_zone` constructs the zone node type.
func _spawn_zone_boxes(zone_range: Vector2, make_zone: Callable) -> void:
	for seg in _segments:
		var a: float = maxf(zone_range.x, seg.start_d)
		var b: float = minf(zone_range.y, seg.start_d + seg.len)
		if b - a < 0.5:
			continue
		var zone: Area3D = make_zone.call()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(W, H, b - a)
		col.shape = shape
		zone.add_child(col)
		var mid2: Vector2 = seg.p0 + (seg.dir as Vector2) * ((a + b) / 2.0 - seg.start_d)
		zone.position = Vector3(mid2.x, H / 2.0, mid2.y)
		zone.rotation.y = atan2(seg.dir.x, seg.dir.y)
		add_child(zone)


# ---------------------------------------------------------------- doors & note

const _DOOR_SCRIPT := preload("res://scripts/door.gd")
const _NOTE_SCRIPT := preload("res://scripts/note.gd")
const _BELL_PROP_SCRIPT := preload("res://scripts/bell_prop.gd")
const _BLIND_LEVER_SCRIPT := preload("res://scripts/blind_lever.gd")


func _spawn_doors() -> void:
	# Exit: room 217 at the far end. Reaching it IS the win — unlock NONE.
	#
	# ⚠️ DELIBERATE (2026-08-18) — **THE REAL 217 CARRIES NO NUMBER, AND MUST NOT.**
	# Nine ordinary doors in this level read 307; the only legible "217" anywhere in the
	# game is the one on the FALSE door at d=185 (`FALSE_DOOR_TEX`). So the number the
	# objective sends you to find has only ever lied to you. That was put to the user with
	# the alternatives — number the real one too, or number it and rewrite the objective
	# after the trap springs — and they chose to leave it unnumbered:
	#   * `backrooms_tear_door.png` is a hole in reality, not a hotel door. Nothing else in
	#     320 m looks remotely like it, so the player does not need a numeral to know;
	#   * numbering the real one would make the tell "the SECOND 217 is the real one",
	#     which is a worse lesson than "the hotel's numbering is part of the illusion";
	#   * the way out is not a room, and never was.
	# Do not "fix" this by adding a plate. The asymmetry is the point.
	var end_pt := _path_point(_total_len)
	var exit_door: StaticBody3D = _make_door_body("ExitDoor")
	# Room 217 is a lie — you never walk through it. The noclip floor trigger in
	# front of it drops you into the Backrooms instead (see _spawn_noclip).
	exit_door.advances_level = false
	exit_door.position = end_pt.pos + Vector3(end_pt.dir.x, 0, end_pt.dir.z) * -0.08
	var exit_inward: Vector3 = -(end_pt.dir as Vector3)
	exit_door.rotation.y = atan2(exit_inward.x, exit_inward.z)
	_dress_exit_door(exit_door)

	_spawn_false_exit_door()

	# Back door at the start, returns to The House (blood-red per convention).
	var start_pt := _path_point(0.0)
	var back_door: StaticBody3D = _make_door_body("BackDoor")
	back_door.advances_level = false
	back_door.goes_back = true
	back_door.position = start_pt.pos + Vector3(start_pt.dir.x, 0, start_pt.dir.z) * 0.08
	back_door.rotation.y = atan2(start_pt.dir.x, start_pt.dir.z)
	_dress_back_door(back_door)


# The wall you walk straight at when you fail to turn at a corner — the same surface
# `_spawn_turn_mirror()` hangs its glass on, expressed once so the two cannot drift apart.
# Returns the transform of a panel of `width` CENTRED on the corridor axis, standing at the
# level's own WALL_INSET, with local +z facing back down the corridor you arrived along.
func _corner_wall_transform(corner_dist: float, y_center: float) -> Transform3D:
	var pt := _path_point(corner_dist)
	var dir_in: Vector3 = pt.dir     # at a corner distance, _path_point returns the INCOMING leg
	var pos: Vector3 = pt.pos + dir_in * (W / 2.0 - WALL_INSET) + Vector3(0, y_center, 0)
	var face := -dir_in
	return Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)), pos)


func _spawn_false_exit_door() -> void:
	var centre := _corner_wall_transform(FALSE_DOOR_DIST, FalseExitDoor.HEIGHT / 2.0)
	_false_door = FalseExitDoor.build(self, centre, FALSE_DOOR_TEX)
	_false_door.name = "FalseExitDoor"
	# ⚠️ `build()` sizes the leaf from the artwork, so the hinge offset has to be read back
	# rather than assumed: the origin sits at the hinge and the leaf runs along local +x, so
	# the body is shifted half a leaf along -x to centre it on the corridor axis.
	var w: float = _false_door.width()
	var hinge := centre
	hinge.origin = centre.origin - centre.basis.x * (w / 2.0) - Vector3(0, FalseExitDoor.HEIGHT / 2.0, 0)
	_false_door.global_transform = hinge
	_false_door.opened.connect(_on_false_door_opened)

	# The architrave, in the blood-red exit livery. ⚠️ Sibling, never a child: the leaf
	# rotates and a frame that swings with the door is the one thing a door frame may not do
	# (Issue 79's lesson, recorded on the ajar doors).
	_spawn_frame_bars(centre, Vector2(w, FalseExitDoor.HEIGHT), "FalseExitFrame",
		FALSE_DOOR_GLOW_ALBEDO, FRAME_BEAD * 1.5, FRAME_PROUD, false,
		FALSE_DOOR_GLOW_EMISSION, FALSE_DOOR_GLOW_ENERGY)

	# ⚠️ AND A REAL LIGHT, not just emission. Emission renders a coloured shape but lights
	# nothing, and this door has to be legible as THE WAY OUT from 45 m down an unlit hall —
	# which means the wall around it has to be washed red, the way the level's own torches
	# wash their brackets. Range 5 keeps it clear of the 145-172 m dark stretch (13 m away),
	# which must stay dark because four beartraps live in it.
	var glow := OmniLight3D.new()
	glow.name = "FalseExitGlow"
	glow.light_color = Color(1.0, 0.14, 0.10)
	glow.light_energy = 0.40
	glow.omni_range = 4.5
	glow.shadow_enabled = false
	glow.position = centre.origin + centre.basis.z * 0.5
	add_child(glow)


# The consequence, owned by the LEVEL. See FALSE_DOOR_PANIC for the number and why it is
# flagged provisional.
var _lunger: DoorLunger = null
var _lunge_watch_t := -1.0      # < 0: the camera is not pinned
var _lunge_reaim := 0.0


func _on_false_door_opened() -> void:
	# t = 0 (E). The world goes quiet first — the sting lands in a hole, which is where its
	# loudness actually comes from (`screamer.gd:flash_scare()`'s pre-silence, longer here).
	HoldBreath.dip(get_tree(), FALSE_DOOR_SILENCE)
	# The figure stands in the doorway, INSIDE the leaf's own 0.10 m box at the wall plane and
	# at alpha 0, so the closed door hides it twice over until the leaf has swung.
	var centre := _corner_wall_transform(FALSE_DOOR_DIST, 0.0)
	var at: Vector3 = centre.origin + centre.basis.z * 0.05
	_lunger = DoorLunger.build(self, at, FALSE_DOOR_FIGURE_PATH, FALSE_DOOR_FIGURE_H)
	# ⚠️ THE PIN. The user asked to SEE it come out and run — so for FALSE_DOOR_WATCH the camera
	# is re-aimed at it every WATCH_REAIM (the `backrooms.gd:_tick_crate_watch()` idiom), with
	# the velocity zeroed by hand because a frozen walker still coasts (Issue 49).
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	_player.freeze_input()
	_lunge_watch_t = 0.0
	_lunge_reaim = 0.0
	get_tree().create_timer(FALSE_DOOR_LUNGE_AT).timeout.connect(_false_door_lunge)
	# ⚠️ The scrawl is delayed past the beat on purpose: this is the one line in the level
	# where the GAME speaks to the player rather than the hotel speaking to Subject 47
	# (ScreenText.BLOOD — KONTUR's banishment accusation and the escort corridor's lie are the
	# other two), and it must not print over the thing it is about.
	var t := get_tree().create_timer(FALSE_DOOR_SCRAWL_DELAY)
	t.timeout.connect(func() -> void: ScreenText.scrawl(get_tree(), FALSE_DOOR_SCRAWL, 3.6))


# t = FALSE_DOOR_LUNGE_AT. The leaf is half open: the figure resolves and comes for the face.
func _false_door_lunge() -> void:
	if not is_instance_valid(_lunger) or not is_instance_valid(_player):
		return
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	var eye: Vector3 = cam.global_position if cam else _player.global_position + Vector3(0, 1.6, 0)
	var to := _lunger.global_position - eye
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.01 else Vector3(-1, 0, 0)
	var feet := Vector3(eye.x + dir.x * FALSE_DOOR_LUNGE_REACH, 0.0, eye.z + dir.z * FALSE_DOOR_LUNGE_REACH)
	_lunger.lunge_to(feet, FALSE_DOOR_LUNGE_TIME)
	# Both sounds are CHILDREN of the figure, so they travel with it (the runner's rule).
	_play_on(_lunger, FALSE_DOOR_SCREAM, Vector3(0, 1.5, 0), 0.0, 6.0)
	_play_on(_lunger, FALSE_DOOR_IMPACT, Vector3(0, 1.0, 0), 0.0, 6.0)
	_player.jolt_camera(0.12, 0.6)
	_player.add_panic(FALSE_DOOR_PANIC)
	_lunger.lunged.connect(func() -> void:
		get_tree().create_timer(FALSE_DOOR_HOLD).timeout.connect(_false_door_flee)
	)


# It has had its moment: it turns and goes, round the corner into the leg ahead.
func _false_door_flee() -> void:
	if not is_instance_valid(_lunger):
		return
	var pt := _path_point(FALSE_DOOR_DIST + FALSE_DOOR_FLEE_AHEAD)
	_lunger.flee_to(pt.pos as Vector3, FALSE_DOOR_FLEE_SPEED, FALSE_DOOR_FLEE_FADE)


func _tick_false_door_watch(delta: float) -> void:
	if _lunge_watch_t < 0.0:
		return
	_lunge_watch_t += delta
	if _lunge_watch_t >= FALSE_DOOR_WATCH or not is_instance_valid(_lunger) \
			or not is_instance_valid(_player):
		_lunge_watch_t = -1.0
		if is_instance_valid(_player):
			_player.unfreeze_input()
		return
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	_lunge_reaim -= delta
	if _lunge_reaim <= 0.0:
		_lunge_reaim = 0.18
		_player.turn_to_face(_lunger.global_position + Vector3(0, 1.2, 0), 0.18)


func _make_door_body(door_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = door_name
	body.set_script(_DOOR_SCRIPT)
	add_child(body)
	var col := CollisionShape3D.new()
	col.name = door_name + "Col"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.8, 0.2)
	col.shape = shape
	col.position.y = 1.4
	body.add_child(col)
	return body


func _dress_exit_door(body: StaticBody3D) -> void:
	var quad := MeshInstance3D.new()
	quad.name = "DoorMesh"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 3.0)
	quad.mesh = mesh
	# ⚠️ Sized from the ARTWORK's aspect, not chosen: `backrooms_tear_door.png` is
	# 774x1458 (1:1.884), so a 3.0 m tall panel is 1.593 wide. The old `door.png` was
	# 2:3 and the quad was 2.0x3.0 to match it; keeping 2.0 here would stretch the new
	# door 26% wide (SCARY.md §7.1(4)). 1.593 also happens to match the collider width
	# (1.6, see _make_door_body), which the old art did not.
	var tex_path := TEX_DIR + "backrooms_tear_door.png"
	var has_art: bool = ResourceLoader.exists(tex_path)
	if has_art:
		mesh.size = Vector2(1.593, 3.0)
	# ⚠️ UNSHADED, not emissive — and this door is the one place in the game where that is
	# the right answer. Measured, in this order:
	#
	#   emission 0.35-red @ 0.6, no emission_texture .. a flat red slab, art invisible.
	#     This was the reported bug: a red wash painted OVER the picture.
	#   door_material() — 0.6-red @ 0.08 WITH the texture .. the art, but uniformly red,
	#     because unlike the Lab's pale steel or the House's timber this artwork is
	#     already near-black, so a red tint is all that survives.
	#   white tint @ 0.42, then @ 0.14 ............... a flat LIGHT-GREY slab, and dropping
	#     the energy barely moved it; at 0.0 the door went black (sampled 16,12,12). The
	#     emission was reading as its flat colour rather than modulating the texture.
	#
	# The artwork measures 22/255 mean luma, so there is no emission tint that both lights
	# it and preserves it. Unshaded sidesteps the whole argument: the quad renders the art
	# exactly as authored — a black door with a red-lit tear already glowing inside it —
	# and is self-lit by definition, so it stays findable after the blackout force-kills
	# the flashlight. That is the only thing the blood-red door convention is really for.
	# `mirror_surface.gd` uses the same shading mode for the same reason.
	var mat: StandardMaterial3D
	if has_art:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = load(tex_path)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat = _DOOR_SCRIPT.door_material("")
	quad.set_surface_override_material(0, mat)
	quad.position.y = 1.5
	body.add_child(quad)


func _dress_back_door(body: StaticBody3D) -> void:
	var door_mesh := MeshInstance3D.new()
	door_mesh.name = "DoorMesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 2.2, 0.15)
	door_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.01, 0.01)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.02, 0.02)
	mat.emission_energy_multiplier = 1.5
	door_mesh.set_surface_override_material(0, mat)
	door_mesh.position.y = 1.1
	body.add_child(door_mesh)


# ⚠️ WIDTH only. The depth is derived from `vesper_note.png`'s own aspect — a hard-coded pair
# is how a 3.97x stretch got into the Intro's gurney decal.
const NOTE_PAGE_W := 0.24

func _spawn_intro_note() -> void:
	var pt := _path_point(4.0)
	var table_pos: Vector3 = pt.pos + (pt.side as Vector3) * (W / 2.0 - 0.45)

	var table := CSGBox3D.new()
	table.name = "NoteTable"
	table.size = Vector3(0.5, 1.2, 0.4)
	table.use_collision = true
	table.position = table_pos + Vector3(0, 0.6, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.10, 0.05)
	wood.roughness = 0.8
	table.material = wood
	add_child(table)

	var note := StaticBody3D.new()
	note.name = "IntroNote"
	note.set_script(_NOTE_SCRIPT)
	note.note_text = NOTE_TEXT
	note.position = table_pos + Vector3(0, 1.25, 0)
	# ⚠️ THE BODY IS YAWED ONTO THE PLAYER'S APPROACH, AND THE APPROACH IS DERIVED
	# (2026-08-18). Playtest capture 001 at (0.90, 0.00, 3.30): *"Turn it 180 degrees, it is
	# currently the wrong side from the place I enter the room"* — the page lay with its
	# lettering pointing back down the corridor, so the first document in the level was
	# upside down to the only person who could ever read it.
	# `pt.dir` is the direction a player walking the path is travelling when they reach this
	# table, taken from `PATH_2D` itself rather than assumed to be +z; yawing the body so its
	# local **+Z is that direction** turns "away from the reader" into a local axis that every
	# child can be built against, and it survives the table ever moving to another segment.
	var approach: Vector3 = (pt.dir as Vector3).normalized()
	note.rotation.y = atan2(approach.x, approach.z)
	add_child(note)

	# ⭐ THE PAGE IS A PAGE NOW (2026-08-17). Playtest capture: *"The note looks boring. Can we
	# generate an image that will make it look more like haunted-hotel style?"* It was an
	# untextured `BoxMesh` — albedo (0.05,0.05,0.04), emission (0.55,0.50,0.35) at 0.6 — i.e.
	# a flat olive-cream slab, and the first thing this level asks the player to interact with.
	# Identical defect to the d=250 plate's, fixed the same way (`tools/make_vesper_note.py`).
	#
	# ⚠️ Art on a QUAD, never on a BoxMesh face (Issue 24), and the quad is sized from the
	# ARTWORK's own aspect (Issue X2 / `check_art_aspect.gd`, which sweeps this level).
	# ⚠️ The sheet is still a real object rather than a floating decal: a thin `BoxMesh` carries
	# the edge and the paper quad sits 1 mm proud of its top face.
	var tex_path := TEX_DIR + "vesper_note.png"
	var has_art: bool = ResourceLoader.exists(tex_path)
	var page_w := NOTE_PAGE_W
	var page_d := NOTE_PAGE_W / 0.9501
	if has_art:
		var tex: Texture2D = load(tex_path)
		page_d = page_w * float(tex.get_height()) / float(tex.get_width())

	var note_mesh := MeshInstance3D.new()
	note_mesh.name = "NotePad"
	note_mesh.mesh = BoxMesh.new()
	(note_mesh.mesh as BoxMesh).size = Vector3(page_w * 0.97, 0.006, page_d * 0.97)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.09, 0.08, 0.06)
	paper.roughness = 0.95
	note_mesh.set_surface_override_material(0, paper)
	note.add_child(note_mesh)

	if has_art:
		var page := MeshInstance3D.new()
		page.name = "NotePage"
		var qm := QuadMesh.new()
		qm.size = Vector2(page_w, page_d)
		page.mesh = qm
		# ⚠️ FLAT, FACE UP, AND THE LETTERING READS FROM THE APPROACH (2026-08-18).
		# This was `rotation_degrees.x = -90`, which lays the quad flat correctly and then
		# sends its local +Y — the top of the artwork — to world **-Z**, i.e. straight back
		# down the corridor into the face of the arriving player. Capture 001 is a photograph
		# of `HOTEL VESPER` upside down.
		# Written as an explicit basis rather than as a second euler term because Godot
		# composes `rotation_degrees` in YXZ order, so which of x/y/z carries the flip is not
		# obvious from reading it, and getting it wrong fails silently — the page still lies
		# flat and still renders, it is just unreadable.
		#   X = (-1, 0, 0)   Y = (0, 0, 1) → the text's up, along the body's own +Z
		#   Z = (0, 1, 0)    → the quad's normal, world up
		page.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
		page.position.y = 0.004
		var page_mat := StandardMaterial3D.new()
		page_mat.albedo_texture = load(tex_path)
		page_mat.roughness = 0.95
		# The generated sheet is an RGBA cutout with the torn deckle edge keyed out.
		page_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# ⚠️ FAINTLY SELF-LIT, and through `EMISSION_OP_MULTIPLY`. Godot's default is ADD, which
		# lays a flat wash over the artwork and knocks the lettering out of it (Issue 81, the
		# KONTUR hint plate two functions down). With MULTIPLY it is the paper's own tone that
		# glows. Well under 1.0 — above that it clamps to flat white (Issue 21).
		page_mat.emission_enabled = true
		page_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		page_mat.emission = Color(1.0, 0.94, 0.78)
		page_mat.emission_texture = load(tex_path)
		page_mat.emission_energy_multiplier = 0.55
		page.set_surface_override_material(0, page_mat)
		note.add_child(page)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 0.12, 0.45)
	col.shape = shape
	note.add_child(col)

	_spawn_nightmare_plate()


# NIGHTMARE HINT 3/3 — and DUNGEON_NIGHTMARES.md §B2 calls it "the single most
# important hint in the game".
#
# THE NIGHTMARE's flagship tell is that the ambient bed and the music CUT OUT when a
# primary entity spawns. That is a mechanic made of an ABSENCE, and an absence
# cannot teach itself: a player who has never been told that the music is a signal
# hears silence and assumes the audio broke. The level does have a one-shot in-level
# scrawl for it, but a hint planted four levels earlier — in a place the player has
# already walked, that means nothing at the time — is the KONTUR pattern and by far
# the better version.
#
# Deliberately a NOTE rather than one of the wall-panel decals: notes are archived
# in the TAB journal, and a hint the player has to still remember four levels later
# needs to be re-readable.
#
# ⚠️ REBUILT 2026-08-16, and the note text is UNCHANGED. The prop was an untextured
# `BoxMesh` — `albedo_color = (0.20, 0.17, 0.09)`, emission 0.3 — i.e. a flat olive
# rectangle, which is exactly what capture C3 photographs (*"This note does not match the
# level vibe. Can we generate it in a more weird and old way?"*). It is now built from parts
# the way `kontur_mailbox.gd` and the roster lock are: a backing plate, a bead frame of four
# thin bars, four corner screws, and a recessed art `QuadMesh` carrying `vesper_plate.png`
# (`tools/make_vesper_plate.py`). ⚠️ Art on a QUAD, never on a BoxMesh face — a textured box
# renders a magnified crop of its own art (Issue 24).
#
# ⚠️ The art carries the HEADING ONLY. Everything that matters is in `note_text`, which is
# the only thing in the game that teaches THE NIGHTMARE's silence, and which the TAB journal
# keeps re-readable four levels later. A plate that paraphrased it would be a second, worse
# copy of the most important hint in the game.
#
# ⚠️ The old comment claimed this is "not in Zone C's near-black stretch". It is: d=250 is
# inside `DREAD_ZONE` and 36 m past the last lit torch at d=214. That is why the ART quad —
# not the body (Issue 27/33) — carries the emission.
const PLATE_W := 0.44
const PLATE_BEAD := 0.028
const PLATE_BACK_T := 0.022

func _spawn_nightmare_plate() -> void:
	const D := 250.0
	var art_path := TEX_DIR + "vesper_plate.png"
	# Art height from the artwork's own aspect (900x600), never chosen by hand.
	var art_h := PLATE_W * 2.0 / 3.0
	if ResourceLoader.exists(art_path):
		var t: Texture2D = load(art_path)
		art_h = PLATE_W * float(t.get_height()) / float(t.get_width())

	var plate := StaticBody3D.new()
	plate.name = "LowerFloorsPlate"
	plate.set_script(_NOTE_SCRIPT)
	plate.note_text = "HOTEL VESPER — NOTICE TO NIGHT STAFF\n\n" \
		+ "WE STOPPED PLAYING MUSIC ON THE LOWER FLOORS.\n\n" \
		+ "The subjects complained they couldn't hear it stop.\n\n" \
		+ "Anyone working below the third landing is reminded that the absence of " \
		+ "the score is not a fault of the system. Do not report it. Do not go " \
		+ "looking for the fault. Stand still and listen to what is left."
	# ⚠️ `_panel_transform`, not a hand-rolled position and rotation. The old pair put the
	# body's +Z INTO the wall — invisible while the prop was a symmetric box, and a
	# guaranteed blank rectangle the moment it gained a one-sided art quad.
	plate.transform = _panel_transform(D, 1.0, 1.55)
	add_child(plate)

	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.055, 0.048, 0.030)
	back_mat.metallic = 0.55
	back_mat.roughness = 0.5

	var back := MeshInstance3D.new()
	back.name = "PlateMesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(PLATE_W + 2.0 * PLATE_BEAD, art_h + 2.0 * PLATE_BEAD, PLATE_BACK_T)
	back.mesh = bm
	back.material_override = back_mat
	back.position = Vector3(0, 0, PLATE_BACK_T / 2.0)
	plate.add_child(back)

	# Bead frame: four thin bars standing proud, so the art sits in a recess rather than on
	# a slab. This is what makes it read as an object at two metres in the dark.
	var half_w := PLATE_W / 2.0 + PLATE_BEAD / 2.0
	var half_h := art_h / 2.0 + PLATE_BEAD / 2.0
	var bars := [
		[0.0, half_h, PLATE_W + 2.0 * PLATE_BEAD, PLATE_BEAD],
		[0.0, -half_h, PLATE_W + 2.0 * PLATE_BEAD, PLATE_BEAD],
		[-half_w, 0.0, PLATE_BEAD, art_h],
		[half_w, 0.0, PLATE_BEAD, art_h],
	]
	for i in bars.size():
		var b: Array = bars[i]
		var bar := MeshInstance3D.new()
		bar.name = "PlateBead%d" % i
		var bbm := BoxMesh.new()
		bbm.size = Vector3(b[2], b[3], PLATE_BACK_T + 0.012)
		bar.mesh = bbm
		bar.material_override = back_mat
		bar.position = Vector3(b[0], b[1], (PLATE_BACK_T + 0.012) / 2.0)
		plate.add_child(bar)

	# Four countersunk screws, in the bead, at the corners.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var screw := MeshInstance3D.new()
			screw.name = "PlateScrew"
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.008
			cyl.bottom_radius = 0.008
			cyl.height = 0.010
			screw.mesh = cyl
			screw.material_override = back_mat
			screw.rotation.x = PI / 2.0
			screw.position = Vector3(sx * half_w, sy * half_h, PLATE_BACK_T + 0.016)
			plate.add_child(screw)

	# THE ART, on a QuadMesh (Issue 24: a textured BoxMesh face renders a magnified crop),
	# recessed 4 mm inside the bead. ⚠️ Emission lives HERE and not on the body — Issue
	# 27/33's documented split: a prop must not wear its own art as a glow, but a plate that
	# has to be FOUND 36 m past the last torch needs the artwork itself to be faintly lit.
	if ResourceLoader.exists(art_path):
		var art := MeshInstance3D.new()
		art.name = "PlateArt"
		var qm := QuadMesh.new()
		qm.size = Vector2(PLATE_W, art_h)
		art.mesh = qm
		var art_mat := StandardMaterial3D.new()
		art_mat.albedo_texture = load(art_path)
		art_mat.roughness = 0.45
		art_mat.metallic = 0.3
		art_mat.emission_enabled = true
		# ⚠️ MULTIPLY — see `_spawn_kontur_hint()`. With Godot's default ADD operator the
		# flat colour is added over the whole plate and the gold heading disappears into a
		# uniform wash.
		art_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		art_mat.emission = Color(1.0, 0.88, 0.62)
		art_mat.emission_texture = load(art_path)
		art_mat.emission_energy_multiplier = 0.9
		art.set_surface_override_material(0, art_mat)
		art.position = Vector3(0, 0, PLATE_BACK_T + 0.004)
		plate.add_child(art)

	var pcol := CollisionShape3D.new()
	var pshape := BoxShape3D.new()
	pshape.size = Vector3(PLATE_W + 0.1, art_h + 0.1, 0.14)
	pcol.shape = pshape
	pcol.position = Vector3(0, 0, PLATE_BACK_T / 2.0)
	plate.add_child(pcol)


# ---------------------------------------------------------------- events

func _spawn_events() -> void:
	_spawn_event(6.0, _ev_entry_slam)
	_spawn_event(46.0, _ev_clock_chime)
	_spawn_event(72.0, _ev_painting_fall)
	_spawn_event(138.0, _ev_lights_out)
	_spawn_event(188.0, _ev_whisper_oneshot)
	# ⚠️ The SECOND scripted painting fall was removed 2026-08-15. Between this level's two
	# placements and `RandomAmbient` rolling `painting_fall` as one of its three events every
	# 18-35 s, the same crash was landing many times in one walk. One scripted fall, and the
	# ambient roll is now capped (see `_ready`'s RandomAmbient.set_once_per_type call).
	# ⚠️ 205 -> SILHOUETTE_TRIGGER (219). See _ev_silhouette for the measurement: at 205 the
	# figure crossed 23.5 m away and rendered 4.9 % of the screen's height in a near-black
	# corridor, which the player photographed and called "too far away from me".
	_spawn_event(SILHOUETTE_TRIGGER, _ev_silhouette)
	_spawn_event(395.0, _ev_whisper_loop)   # C1: at the dread zone's mouth (was 235)
	_spawn_event(372.0, _ev_floor_crack)    # C1: was 250

	# ⚠️ The Manager no longer gets a `_spawn_event` of its own. It used to drop at
	# randf_range(80, 180) and fire COLD — a hard cut to a fullscreen image, which is F1's
	# diagnosis exactly. It is now the payoff of ONE of five identical telegraphs
	# (see _telegraph), so the same 25 panic buys ~100 m of dread instead of 0.85 s of
	# startle. MANAGER_DIST is retained only as the window TELEGRAPH_AT sits inside.
	_telegraph_payoff = randi() % TELEGRAPH_AT.size()
	for i in TELEGRAPH_AT.size():
		_spawn_event(TELEGRAPH_AT[i], _telegraph.bind(i))

	# Which door slams, and which one has someone standing in it. Both drawn from the
	# Zone-B doors only (90-230 m), the stretch this pass exists to fill.
	var zone_b: Array[int] = []
	for d in _ajar_doors:
		var dist: float = float(d.dist)
		if dist >= 90.0 and dist <= 230.0:
			zone_b.append(int(dist))
	if not zone_b.is_empty():
		_slam_index = zone_b.pick_random()
		_slam_dist = float(_slam_index) + DOOR_SLAM_LEAD
		_watcher_door = zone_b.pick_random()


# ---------------------------------------------------------------- the noclip

# The player never reaches room 217. The corridor plunges black and the flashlight dies,
# and then the floor gives way SHORT of the door — they can see it, torn open and lit
# from inside, and never get to touch it. Replaces the old clean door advance.
#
# ⚠️ The fall used to be AT the door (trigger centred at d = 318.5, i.e. its leading face
# 2.75 m out). The user's call 2026-08-15 was to drop the player ~5 m short, so the door
# stays a thing seen rather than a thing reached.
const NOCLIP_FALL_BEFORE_DOOR := 5.0   # metres from the door plane to the trigger's near face
const NOCLIP_TRIGGER_DEPTH := 2.5
# The blackout moved with it. At the old d = 310 onset a 5 m-earlier fall left barely 4 m
# of dark walking; at 15 m out the run-up is ~9 m again, which is what the beat is for.
const NOCLIP_ONSET_BEFORE_END := 15.0

var _noclip_armed: bool = false
var _noclip_fired: bool = false

func _spawn_noclip() -> void:
	_spawn_event(_total_len - NOCLIP_ONSET_BEFORE_END, _ev_noclip_onset)
	# Floor trigger, placed so its NEAR face — the one the player walks into — sits
	# NOCLIP_FALL_BEFORE_DOOR from the door. The door body itself is at _total_len - 0.08.
	var door_d: float = _total_len - 0.08
	# ⚠️ PLUS half the depth. The near face is at centre - depth/2, so to put that face
	# 5 m from the door the centre goes 5 m out and then half a box back TOWARD it.
	# Subtracting instead (the obvious-looking arithmetic) placed the fall 7.5 m out —
	# caught by check_noclip_fall.gd before the level was ever launched.
	var centre_d: float = door_d - NOCLIP_FALL_BEFORE_DOOR + NOCLIP_TRIGGER_DEPTH / 2.0
	var pt := _path_point(centre_d)
	var area := CorridorEvent.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, H, NOCLIP_TRIGGER_DEPTH)
	col.shape = shape
	area.add_child(col)
	area.position = pt.pos + Vector3(0, H / 2.0, 0)
	area.rotation.y = atan2(pt.dir.x, pt.dir.z)
	area.fired.connect(_ev_noclip_fall)
	add_child(area)


func _ev_noclip_onset() -> void:
	# Pitch black: every torch dies and the flashlight is force-killed (F now
	# only clicks). The last stretch before the floor goes is walked blind.
	_noclip_armed = true
	for entry in _torch_nodes:
		entry[1].extinguish()
	if _player.has_method("kill_flashlight"):
		_player.kill_flashlight()
	_play_at("creak", _path_point(_total_len - 6.0).pos + Vector3(0, 1.5, 0), 2.0)


# Where the floor gives way, in path distance. Exposed so tests can assert the gap to the
# door and to the re-entry cap without re-deriving the arithmetic (which is how the two
# constants drifted apart in the first place).
func noclip_fall_distance() -> float:
	return (_total_len - 0.08) - NOCLIP_FALL_BEFORE_DOOR + NOCLIP_TRIGGER_DEPTH / 2.0


# ⭐ THE FLOOR GIVES WAY AND YOU ACTUALLY FALL (2026-08-15, user's call).
#
# ⚠️ This used to fade to black and wait two seconds, which is not a fall — the player
# stood still while the screen dimmed. Reported as "there is still no such thing as the
# visual like you are falling; I want like you just walk and fall through the floor."
#
# The player is a CharacterBody3D, so zeroing its `collision_mask` means nothing holds it
# up any more: `player.gd:_apply_gravity()` already runs every frame and `is_on_floor()`
# goes false, so it accelerates downward through the floor under real gravity. The camera
# falls with it and the corridor rushes up past the view.
#
# ⚠️ Done this way rather than by cutting a hole. The corridor floor is ONE CSGBox3D per
# 45 m segment (`_build_geometry`), so there is no local piece to delete the way
# `kontur.gd:_open_the_void()` deletes a room's floor — it would need a CSG subtraction and
# a collision rebuild, for a hole nobody can see: the blackout killed every light 10 m ago.
# What the player is owed here is the SENSATION, and that is entirely in the falling.
const FALL_FADE_AT := -3.0     # metres below the floor before the screen starts to go
const FALL_ADVANCE_AT := -9.0  # and where the Backrooms takes over

# ⭐ THE FALL IS NOW SHOWN, NOT SIMULATED (user's call): the cutscene covers the screen the
# instant the floor gives way, so what the player sees is entirely the video — the shaft, the
# watchers leaning over the hole, the walls turning Backrooms-yellow — and the Backrooms loads
# when it ends rather than at a depth.
#
# ⚠️ The physics fall below is UNCHANGED and still runs, invisibly, behind the video. Two
# reasons, both load-bearing:
#   1. `tests/check_noclip_fall.gd` asserts the player actually drops >1 m in 1.2 s. That guard
#      exists because this ending shipped twice as a fade with the player standing still.
#   2. `CutscenePlayer.play()` returns null headless and if the file is missing, and then the
#      old depth-driven fade/advance in `_tick_fall()` is what completes the level.
# So the video is a presentation layer over the fall, never a replacement for it.
const FALL_VIDEO := "res://assets/video/fall_scene.ogv"

var _fall_cutscene: bool = false

func _ev_noclip_fall() -> void:
	if not _noclip_armed or _noclip_fired:
		return
	_noclip_fired = true

	_player.collision_mask = 0
	# No steering on the way down; you are falling, not flying.
	if _player.has_method("freeze_input"):
		_player.freeze_input()

	var cutscene := CutscenePlayer.play(self, FALL_VIDEO)
	if cutscene != null:
		_fall_cutscene = true
		cutscene.finished.connect(_on_fall_cutscene_finished)
	else:
		# Fallback path: no video, so the break has to be sold in-engine as it always was.
		# Keep the jolt and the creak — they are the sound of it breaking. With the cutscene
		# they are dropped, because the clip carries its own floor-collapse audio and the
		# camera shake is behind an opaque overlay where nobody can see it.
		_player.jolt_camera(0.12, 0.5)
		_play_at("creak", _player.global_position, 3.0)

	set_process(true)   # _process drives the rest — see _tick_fall()


func _on_fall_cutscene_finished() -> void:
	if not _noclip_fired:
		return
	_noclip_armed = false      # belt and braces against a second entry
	GameState.advance_level()  # -> The Backrooms


var _fall_fading: bool = false

# Driven from _process while the player is falling. Deliberately not an `await` chain: the
# distance fallen is what advances the level, so a slow frame or a long drop cannot desync
# the fade from the transition the way a fixed 2 s timer did.
func _tick_fall() -> void:
	if not _noclip_fired or _player == null or not is_instance_valid(_player):
		return
	# The cutscene owns the fade (it is opaque) and the transition (it advances on `finished`).
	# The body below is the no-video fallback only.
	if _fall_cutscene:
		return
	var y: float = _player.global_position.y
	if not _fall_fading and y <= FALL_FADE_AT:
		_fall_fading = true
		var layer := CanvasLayer.new()
		layer.layer = 80
		add_child(layer)
		var fade := ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fade)
		var tween := create_tween()
		tween.tween_property(fade, "color:a", 1.0, 0.8)
	if y <= FALL_ADVANCE_AT:
		_noclip_armed = false      # belt and braces against a second entry
		GameState.advance_level()  # -> The Backrooms


func _spawn_event(dist: float, callback: Callable) -> void:
	var pt := _path_point(dist)
	var ev := CorridorEvent.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, H, 2.0)
	col.shape = shape
	ev.add_child(col)
	ev.position = pt.pos + Vector3(0, H / 2.0, 0)
	ev.rotation.y = atan2(pt.dir.x, pt.dir.z)
	ev.fired.connect(callback)
	add_child(ev)


func _play_at(base_name: String, pos: Vector3, volume_db: float = 0.0) -> void:
	_play_on(self, base_name, pos, volume_db)


# The same one-shot, parented to an arbitrary node so it can MOVE with it. `_play_at` is this
# with `self` as the host, which is what every static cue in the level wants; the running
# silhouette wants the emitter travelling with the thing making the noise.
#
# ⚠️ `max_db` is a real parameter and not decoration: it caps the gain distance attenuation is
# allowed to ADD, so a sound authored near full scale that the player can end up standing on
# top of will clip the master unless it is pinned. See SILHOUETTE_MAX_DB.
func _play_on(host: Node, base_name: String, pos: Vector3, volume_db: float = 0.0,
		max_db: float = 6.0) -> void:
	var stream := GameState.load_audio(base_name)
	if not stream:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 8.0
	p.max_db = max_db
	host.add_child(p)
	p.position = pos
	p.finished.connect(p.queue_free)
	p.play()


# ⭐ C1 (2026-09-13): THE MANAGER IS IN THE WORLD. It used to be a fullscreen `flash_scare`
# (`screamer_manager.png`); the user asked for "a manager 3d appearing on one of your turns (not
# next to the mirror)". Now a `DoorLunger` wearing the generated full-length figure
# (`manager_figure.png`, keyed by tools/cutout_black.py) stands MANAGER_AHEAD metres down the
# corridor as the telegraph pays off, lunges to arm's length with the same `screamer_manager`
# sting, then flees back the way the player came. MANAGER_PANIC 25 unchanged. Survivable.
const MANAGER_FIGURE_PATH := TEX_DIR + "manager_figure.png"
const MANAGER_AHEAD := 6.0
const MANAGER_LUNGE_TIME := 0.32
const MANAGER_LUNGE_REACH := 0.6
const MANAGER_HOLD := 0.3
const MANAGER_FLEE_BACK := 14.0
var _manager_fig: DoorLunger = null

func _ev_manager() -> void:
	# Survivable: a figure, a scream, a panic spike — only fatal if you were already near the
	# edge. Guarded so it never double-fires.
	if _manager_fired:
		return
	_manager_fired = true
	var d_now: float = _nearest_path_distance(_player.global_position)
	var pt := _path_point(d_now + MANAGER_AHEAD)
	var fig := DoorLunger.build(self, pt.pos, MANAGER_FIGURE_PATH, 2.0)
	fig.name = "ManagerFigure"
	_manager_fig = fig
	HoldBreath.dip(get_tree(), 0.6)
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	var eye: Vector3 = cam.global_position if cam else _player.global_position + Vector3(0, 1.6, 0)
	var to_player := Vector3(eye.x - pt.pos.x, 0.0, eye.z - pt.pos.z).normalized()
	var feet := Vector3(eye.x, 0.0, eye.z) - to_player * MANAGER_LUNGE_REACH
	# The eye is brought onto it: this is a beat the player is meant to SEE (Issue 113's rule).
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	_player.freeze_input()
	_player.turn_to_face(pt.pos + Vector3(0, 1.1, 0), 0.25)
	fig.lunged.connect(func() -> void:
		var s := GameState.load_audio("screamer_manager")
		if s:
			var a := AudioStreamPlayer.new()
			a.stream = s
			a.bus = "Master"
			add_child(a)
			a.finished.connect(a.queue_free)
			a.play()
		_player.jolt_camera(0.12, 0.6)
		_player.add_panic(MANAGER_PANIC)
		get_tree().create_timer(MANAGER_HOLD, false).timeout.connect(func() -> void:
			if is_instance_valid(fig):
				var back := _path_point(maxf(0.0, d_now - MANAGER_FLEE_BACK))
				fig.flee_to(back.pos, 6.0, 2.5)
			if is_instance_valid(_player):
				_player.unfreeze_input()))
	get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		if is_instance_valid(fig):
			fig.lunge_to(feet, MANAGER_LUNGE_TIME))


func _ev_entry_slam() -> void:
	# The way back slams shut behind you.
	_play_at("door_slam", _path_point(0.5).pos + Vector3(0, 1.2, 0), 2.0)
	_player.add_panic(10.0)


func _ev_clock_chime() -> void:
	_play_at("clock_chime", _panel_transform(48.0, 1.0, 1.5).origin, 1.0)
	_player.add_panic(10.0)


func _ev_lights_out() -> void:
	_play_at("glass_shatter", _path_point(150.0).pos + Vector3(0, 2.4, 0), 3.0)
	for entry in _torch_nodes:
		if entry[0] >= SHATTER_RANGE.x and entry[0] <= SHATTER_RANGE.y:
			entry[1].extinguish()


func _ev_whisper_oneshot() -> void:
	_play_at("whispers", _path_point(200.0).pos + Vector3(0, 1.5, 0), -6.0)


func _ev_silhouette() -> void:
	# ⭐ THE RUNNING CREATURE — REBUILT CLOSER, LOUDER AND PERSON-SHAPED (2026-08-17).
	#
	# The user's capture, taken at d=222 seconds after this fired: *"When the creature is
	# running in front of you. Firstly, it is too far away from me. Can we make it run when
	# I'm much closer so that I can actually see it. Secondly, can we make the sounds of this
	# jumpscare much louder?"*
	#
	# MEASURED, and the complaint is exact. The event triggered at d=205 and the figure ran
	# across at d=228.5 — **23.5 m** down an unlit hall (the last torch is at d=214). A 1.75 m
	# capsule at 23.5 m stands 4.85 % of the screen's height, 52 px at 1080p, and at
	# `albedo 0.02` with nothing lit behind it there was nothing to occlude. The sound was
	# `jumpscare` at volume_db -14 with `unit_size` 8, i.e. -9.4 dB of distance attenuation on
	# top: it landed at about **-26 dBFS**, quieter than the level's own whispers loop.
	#
	# THREE CHANGES, no difficulty constant among them:
	#  1. the trigger moved 205 -> SILHOUETTE_TRIGGER 219, and the crossing 228.5 ->
	#     SILHOUETTE_CROSS 227. That is **8 m at the moment it fires**, and closer still by
	#     the end of the run, against 23.5 m. Measured apparent height 4.85 % -> 13.4 % of the
	#     screen, a 2.8x linear / 7.6x area increase (`check_silhouette.gd` unprojects the real
	#     figure through the real camera and asserts it).
	#  2. it is built from PARTS in a running pose rather than being one capsule. Bringing a
	#     pill-shaped prop closer only makes it legible as a pill (Issue 35 — silhouette
	#     carries a prop). Head, chest, pelvis, two swinging arms, two striding legs, leaning
	#     into the run.
	#  3. the sound is `SILHOUETTE_DB` and it RIDES THE FIGURE — the player is a child of the
	#     mesh, so the scream sweeps across your view with the thing making it instead of
	#     playing from a fixed point.
	#
	# ⚠️ `SILHOUETTE_PANIC` 20 is UNCHANGED and is a difficulty constant. Moving the event
	# closer already increases its impact; the number was deliberately not compounded.
	#
	# ⚠️ THE CROSSING POINT IS 3 m SHORT OF THE CORNER, NOT ON IT. At 227 the walls stand at
	# x = -3.5 and -6.5 with 0.3 m of thickness behind each, so the figure starts and ends
	# BEHIND SOLID WALL (SILHOUETTE_SIDE 2.0 > 1.5 + T) and is only ever seen mid-corridor. At
	# the old 228.5 the +x start was level with the corner mouth, where segment 6 opens out —
	# close enough to matter now that the player is 8 m away instead of 23.
	var pt := _path_point(SILHOUETTE_CROSS)
	var fig := _build_runner()
	fig.name = "SilhouetteRunner"
	add_child(fig)
	var side3: Vector3 = pt.side
	var start: Vector3 = pt.pos + side3 * SILHOUETTE_SIDE
	var end: Vector3 = pt.pos - side3 * SILHOUETTE_SIDE
	fig.position = start
	# Face the way it is running, so the legs and arms read as a stride rather than as a figure
	# sliding sideways. ⚠️ A Node3D's forward is **−Z**, so to point −Z along the travel
	# direction (−side) the yaw is `atan2(side.x, side.z)`. The obvious `atan2(-side.x, -side.z)`
	# is off by π and renders a figure sprinting BACKWARDS — which is legible in a screenshot
	# and, at eight metres, in play.
	fig.rotation.y = atan2(side3.x, side3.z)
	var tween := create_tween()
	tween.tween_property(fig, "position", end, SILHOUETTE_CROSS_TIME)
	tween.tween_callback(fig.queue_free)
	# ⚠️ A CHILD of the figure, so it travels. `_play_at` parents to the level and the emitter
	# would sit still while the thing screaming ran past it.
	_play_on(fig, "jumpscare", Vector3(0, 1.3, 0), SILHOUETTE_DB, SILHOUETTE_MAX_DB)
	_player.add_panic(SILHOUETTE_PANIC)


# The running figure, built from parts. Kept dark and barely emissive on purpose: this is a
# shape that OCCLUDES the flashlight-lit wall behind it, not a lit prop (watcher.gd's rule).
func _build_runner() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.03)
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.05, 0.07)
	mat.emission_energy_multiplier = 0.4

	# [name, mesh, position, rotation_degrees]. Local +z is the direction of travel.
	var parts := [
		["Head", _sphere(0.105), Vector3(0, 1.63, 0.06), Vector3.ZERO],
		["Neck", _capsule(0.05, 0.14), Vector3(0, 1.50, 0.04), Vector3.ZERO],
		["Chest", _capsule(0.155, 0.52), Vector3(0, 1.22, 0.05), Vector3(12, 0, 0)],
		["Pelvis", _capsule(0.135, 0.24), Vector3(0, 0.93, 0.0), Vector3.ZERO],
		["ArmLead", _capsule(0.055, 0.60), Vector3(-0.20, 1.22, 0.20), Vector3(-52, 0, 6)],
		["ArmTrail", _capsule(0.055, 0.60), Vector3(0.20, 1.22, -0.16), Vector3(46, 0, -6)],
		["LegLead", _capsule(0.075, 0.86), Vector3(-0.10, 0.55, 0.24), Vector3(-34, 0, 0)],
		["LegTrail", _capsule(0.075, 0.86), Vector3(0.10, 0.52, -0.26), Vector3(30, 0, 0)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.name = String(p[0])
		mi.mesh = p[1]
		mi.position = p[2]
		mi.rotation_degrees = p[3]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
	return root


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0 + 0.001)
	return m


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m


func _ev_whisper_loop() -> void:
	# Constant low whispers for the rest of the walk (Zone C).
	var stream := GameState.load_audio("whispers")
	if not stream:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = -10.0
	p.unit_size = 14.0
	p.max_db = -4.0
	add_child(p)
	p.position = _path_point(290.0).pos + Vector3(0, 1.5, 0)
	p.finished.connect(p.play)
	p.play()


func _ev_floor_crack() -> void:
	# The floor splits under your feet.
	_play_at("creak", _player.global_position, 4.0)
	_player.jolt_camera(0.06, 0.45)
	_player.add_panic(10.0)
	if ResourceLoader.exists(TEX_DIR + "floor_crack.png"):
		var quad := _spawn_quad(Transform3D(), Vector2(1.8, 1.4), TEX_DIR + "floor_crack.png")
		if quad:
			quad.position = Vector3(_player.global_position.x, FLOOR_DECAL_Y,
				_player.global_position.z)
			quad.rotation_degrees.x = -90.0
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# A painting comes off the wall behind you.
#
# ⚠️ REWRITTEN 2026-08-16. This was the only visual prop in the game spawned at an
# UNVALIDATED random world offset:
#
#     var pt := _path_point(_player.global_position.length())        # dead: |v| != path d
#     var painting_pos := _player.global_position \
#         + Vector3(randf_range(-2, 2), 1.8, randf_range(-2, 2))
#
# The corridor's walkable half-width is 1.1 m and its walls are at ±1.5 m, so one of those
# two axes is always the LATERAL one and was being drawn U(-2, 2) against it: the painting's
# CENTRE landed outside the corridor about a quarter of the time, and the quad is 1.5 m wide
# and was yawed `randf_range(-PI, PI)`, so it intersected a wall far more often than that.
# No raycast, no `wall_point()`, no clearance probe. That is Issue 77 — *"a scripted beat
# with a facing check and no line of sight: the painting that fell through a wall"* — in a
# second level, unguarded. The `pt` line was computed and never used, and this was the only
# function in the file commented in Russian.
#
# Now: the painting hangs on a REAL WALL, on the side the player is facing LESS (N1 — never
# scare from in front; the beat is a crash behind you), at the player's own path distance,
# and the position is derived from `_panel_transform()` like every other wall prop in the
# level rather than from an offset. `check_painting_fall.gd` asserts the result from 200
# positions along the whole path, with raycasts against the built CSG.
const PAINTING_SIZE := Vector2(1.5, 1.2)
const PAINTING_Y := 1.8

func _ev_painting_fall() -> void:
	var xf := painting_fall_transform()
	# ⚠️ A skipped painting beats an embedded one — `apparition.gd:appear()`'s rule, for the
	# same reason. The sound and the panic still land; only the picture is withheld, and only
	# when there is provably no wall anywhere to hang it on.
	var backed := _has_backing(xf)
	_play_at("painting_fall", xf.origin if backed else _player.global_position, 1.5)
	_player.add_panic(8.0)
	if not backed:
		return

	var quad := _spawn_quad(xf, PAINTING_SIZE, TEX_DIR + "painting.png")
	if quad:
		# ⚠️ Falls in the wall's own frame: it rotates about its local Z (tipping in the
		# plane of the wall) and drops. The old version yawed it a random ±180° first, which
		# is what turned a picture coming off a wall into a plank spinning through one.
		var tween := create_tween()
		tween.tween_property(quad, "rotation:z", PI / 2.0, 0.35).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(quad, "position:y", 0.12, 0.4).set_ease(Tween.EASE_IN)
		tween.tween_callback(quad.queue_free)


# Where the painting would fall right now. Split out so a test can ask 200 times without
# spawning 200 paintings or firing 200 sounds — and so the placement rule is provably the
# same one the event uses, rather than a re-implementation of it.
func painting_fall_transform() -> Transform3D:
	var here: float = clampf(_nearest_path_distance(_player.global_position),
		2.0, _total_len - 2.0)
	# The wall the player is facing LESS. Both side walls of a corridor are near 90° off the
	# heading, so this is a soft preference rather than a guarantee — but it is never the
	# wall they are staring at.
	var fwd: Vector3 = -_player_camera_basis().z
	fwd.y = 0.0
	var preferred: float = 1.0 if fwd.dot(_path_point(here).side as Vector3) <= 0.0 else -1.0

	# ⚠️ A corridor CORNER has no wall on the outside of the turn: `_build_geometry()` cuts a
	# corridor-width opening out of the wall where the next segment attaches, so a 1.5 m wide
	# painting placed within ~2 m of a corner hangs partly in mid-air. Walk outward from the
	# player's own position until both a side and a distance have a wall behind all three
	# sample points.
	for step in [0.0, 2.5, -2.5, 5.0, -5.0, 8.0, -8.0]:
		var d: float = clampf(here + step, 2.0, _total_len - 2.0)
		for s in [preferred, -preferred]:
			# 2026-09-14: keep off every WALL OPENING on that side — spur and fork mouths, the
			# corner-branch mouths, the rhythm-break door. A fork's return door stands in its
			# mouth with a jamb proud of the wall, and check_painting_fall found a corner behind
			# it at d 124.5 (the 118 fork's return mouth is at 127).
			if _near_wall_opening(d, s):
				continue
			var xf := _panel_transform(d, s, PAINTING_Y)
			if _has_backing(xf):
				return xf
	return _panel_transform(here, preferred, PAINTING_Y)


# Every opening cut into the hall's side walls, as [d, side]; a painting must not straddle one.
func _near_wall_opening(d: float, side: float) -> bool:
	var margin: float = PAINTING_SIZE.x / 2.0 + W / 2.0 + 0.6
	var openings: Array = []
	for sp in SIDE_PASSAGES:
		openings.append([float(sp["at"]), float(sp["side"])])
	for fk in FORKS:
		openings.append([float(fk["at"]), float(fk["side"])])
		openings.append([float(fk["at"]) + float(fk["across"]), float(fk["side"])])
	for cb in CORNER_BRANCHES:
		var cm := _corner_branch_mouth(float(cb["corner"]))
		openings.append([float(cm["at"]), float(cm["side"])])
	openings.append([BREAK_DOOR_AT, BREAK_DOOR_SIDE])
	for o in openings:
		if signf(float(o[1])) == signf(side) and absf(d - float(o[0])) < margin:
			return true
	return false


# Is there wall behind the whole width of a painting hung at `xf`? Three rays — the centre
# and both edges — fired from just in front of the picture plane into the wall.
#
# ⚠️ Rays, never `intersect_shape`: a shape query against CSG reports NOTHING when it lies
# wholly inside the slab, i.e. it approves exactly the case being rejected (Issue 40).
func _has_backing(xf: Transform3D) -> bool:
	var space := get_viewport().world_3d.direct_space_state
	var n: Vector3 = xf.basis.z.normalized()
	var right: Vector3 = xf.basis.x.normalized()
	for lat in [-PAINTING_SIZE.x / 2.0 + 0.05, 0.0, PAINTING_SIZE.x / 2.0 - 0.05]:
		var from: Vector3 = xf.origin + right * lat + n * 0.25
		var q := PhysicsRayQueryParameters3D.create(from, from - n * 0.65)
		q.collide_with_areas = false
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return false
		# ⚠️ It has to be the WALL, not another prop. Without this the probe is satisfied by
		# the door at d=210 or by a blood decal, and the painting lands ON one of them —
		# measured, 14 of 200 sampled positions did exactly that. The corridor's structural
		# geometry is the only CSG in the scene; every prop is a MeshInstance3D + a body.
		if not (hit["collider"] is CSGShape3D):
			return false
		# ⚠️ AND NOTHING STANDS BETWEEN THE HALL AND THE PICTURE PLANE (2026-09-10). The three
		# rays above START 0.25 m off the wall, i.e. INSIDE a 0.38 m deep prop standing against
		# it — and a ray that starts inside a body does not report it. The grandfather clock at
		# d = 48 is exactly that prop: `check_painting_fall.gd` found the picture hung inside
		# the case on the first run after the clock landed. So a fourth ray per sample, from
		# 1.2 m out in the hall to just short of the plane, must reach it untouched.
		var clear_q := PhysicsRayQueryParameters3D.create(xf.origin + right * lat + n * 1.2,
			from)
		clear_q.collide_with_areas = false
		clear_q.exclude = [_player.get_rid()]
		if not space.intersect_ray(clear_q).is_empty():
			return false
	return true


func _player_camera_basis() -> Basis:
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam:
		return cam.global_transform.basis
	return _player.global_transform.basis

# ---------------------------------------------------------------- ambience

func _start_ambience() -> void:
	var ambient: AudioStreamPlayer = get_node_or_null("AmbientPlayer")
	if not ambient:
		return
	# ⚠️ NOT on the duckable `Ambience` bus (2026-08-15, user's call: "let's leave music to
	# be present in the entire level"). `_tick_hush()` pulls `Ambience` down by 40 dB for
	# the last 25 m, which used to take this bed with it and leave the walk to the fall in
	# total silence. On its own bus the hush still silences the WORLD — the whispers loop
	# and RandomAmbient's one-shots, which is the beat the hush exists for — while the
	# score plays through to the floor giving way. Same reasoning as `kontur.gd` keeping
	# `kontur_music` off the ducked path.
	# ⚠️ Ensure BEFORE assigning. Godot resolves a bus by name at assignment time and falls
	# back to Master silently if it does not exist yet — which would look like it worked
	# and leave the score un-bussed. (`check_audio_buses.gd` documents the same trap.)
	AudioBuses.ensure_music_bus(_MUSIC_BUS)
	ambient.bus = _MUSIC_BUS
	var s := GameState.load_audio("ghost_house")
	if s:
		ambient.stream = s
	if ambient.stream:
		ambient.volume_db = -6.0
		ambient.finished.connect(ambient.play)
		ambient.play()
