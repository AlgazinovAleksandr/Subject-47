extends Node3D

# Breach-owned containment approach (2026-09-22, redesigned 2026-09-23 — spec/levels/06-breach.md).
# The parent appends these cells to its single RoomBuilder build but keeps them OUT of Object 12's
# hunt navigation graph. The authored centreline is 283.8 m, ~71 s at the normal 4 m/s walk.
#
# ⭐ WHAT THE 2026-09-23 PASS IS FOR. The 2026-09-22 playtest called the approach "too boring" and
# said it "does not represent what will happen next". So every beat now points at Object 12 —
# its traces, its sounds and (since pass 3) TWO partial glimpses — and most of them TEACH A HUNT RULE
# before the hunt: it hates light (residue stops at every lit pool), hiding works (a gouged
# cabinet that held), it follows sound (the grating → the duct answers), and a door it batters
# goes silent, then dark, then crashes (the same sequence `breach_door_scare.gd` plays).
#
# ⚠️ THE REAL CREATURE IS UNTOUCHED. Nothing here reads or writes the level's `_creature`. Every
# beat uses its own one-shot speakers and the glimpses are separate visual-only puppets
# (`breach_approach_hand.gd`, `breach_approach_grille.gd`). No posture requirement, no timed lock,
# no forced wait, and ONE panic term, capped so it cannot kill — the dark room's (pass 3, the user's
# call). A player who walks straight through still gets every beat, in route order.
#
# ⚠️ Banned here because they are the Corridor's (03-corridor.md): mirrors, running silhouettes,
# footsteps following the player, a shadow under a door, bells, keys, false exits, loops.
#
# ⭐ PASS 3 (2026-09-23, the user's second playtest of the approach, every item grilled with them):
#   * PumpReturn's black slab is a slatted return-air GRILLE, and through it Object 12's back and
#     crown batter a door during the door tell (`breach_approach_grille.gd`, the second glimpse);
#   * the Plenum's doorway to Containment is COLLAPSED; the only way on is the porthole door, whose
#     wheel is missing its handle. A dead technician holds it (grip, eyes open, "don't… go in
#     there…"), and the wheel turns by CIRCLING THE MOUSE against a drag that drifts back;
#   * behind it, THE DARK ROOM — an experiment room lit only by a sparking junction box, where panic
#     rises to 42/50 and no further (the one panic term the approach owns, by the user's call);
#   * a passage into the enlarged CELL CHAMBER: the breached cell's spot, two bodies, glass that
#     crunches underfoot and a CCTV monitor looping the breakout;
#   * every floor-standing prop is SOLID (`_solid_box`, `_collide`). The first build had 89 box
#     visuals and 5 colliders, and the user walked through the receivers.
signal committed

const START_SPAWN := Vector3(-97, 0.1, -68)
const START_YAW := -PI / 2.0
const BACK_DOOR_POS := Vector3(-99.75, 1.2, -68)
const PORTHOLE_X := -44.5        # the porthole door, on the Plenum's north wall (z -33)
# ⚠️ The first corridor is THREE rooms, not one (A1). It used to be one 60 m box with a lamp every
# 8 m and its far end in view from the spawn. Two jogs (Service -> ServiceJog -> ServiceReturn)
# mean the far end is never visible; B1 (Issue 266) is what makes mixed heights safe elsewhere.
const ROOMS := [
	{ "name": "ApproachService", "pos": Vector2(-89, -68), "size": Vector2(22, 6), "h": 3.6 },        # x -100..-78  z -71..-65
	{ "name": "ApproachServiceJog", "pos": Vector2(-69, -62), "size": Vector2(26, 6), "h": 3.6 },     # x  -82..-56  z -65..-59
	{ "name": "ApproachServiceReturn", "pos": Vector2(-50, -68), "size": Vector2(20, 6), "h": 3.6 },  # x  -60..-40  z -71..-65
	{ "name": "ApproachPumpReturn", "pos": Vector2(-43, -55), "size": Vector2(6, 20), "h": 4.0 },     # x  -46..-40  z -65..-45
	{ "name": "ApproachObservation", "pos": Vector2(-73, -48), "size": Vector2(54, 6), "h": 3.4 },    # x -100..-46  z -51..-45
	{ "name": "ApproachInspectionTurn", "pos": Vector2(-97, -34), "size": Vector2(6, 22), "h": 3.4 }, # x -100..-94  z -45..-23
	# A4: the ceiling drops to 2.4 m. No crouch exists, so none is required (the player is 1.8 m).
	{ "name": "ApproachDamaged", "pos": Vector2(-78, -26), "size": Vector2(32, 6), "h": 2.4, "skin": "ruptured" }, # x -94..-62 z -29..-23
	{ "name": "ApproachPlenum", "pos": Vector2(-44, -28), "size": Vector2(36, 10), "h": 5.2 },        # x  -62..-26  z -33..-23
	{ "name": "ApproachContainment", "pos": Vector2(-11.5, -26), "size": Vector2(29, 6), "h": 3.4, "skin": "organic" }, # x -26..3 z -29..-23
	# ⭐ PASS 3: the cell CHAMBER, enlarged from 7 x 5 so the player walks THROUGH it — in from the dark
	# room's passage on its west wall, out through its old doorway into Containment. The breached
	# cell stands in it (BreachedCellSpot), with the bodies and the CCTV monitor round it.
	{ "name": "ApproachCell12", "pos": Vector2(-13.5, -33.5), "size": Vector2(13, 9), "h": 3.4, "skin": "organic" }, # x -20..-7 z -38..-29
	{ "name": "ApproachThreshold", "pos": Vector2(0, -13), "size": Vector2(6, 20), "h": 3.0 },        # x   -3..3    z -23..-3
	{ "name": "ApproachBayA", "pos": Vector2(-80, -41.5), "size": Vector2(10, 7), "h": 3.4 },         # x  -85..-75  z -45..-38
	{ "name": "ApproachBayB", "pos": Vector2(-63, -41.5), "size": Vector2(10, 7), "h": 3.4 },         # x  -68..-58  z -45..-38
	# ⭐ PASS 3: behind PumpReturn's grille. UNREACHABLE — its only opening is the grille aperture.
	{ "name": "ApproachIsolation4", "pos": Vector2(-38.5, -55), "size": Vector2(3, 6), "h": 3.0 },   # x  -40..-37  z -58..-52
	# ⭐ PASS 3: THE DARK ROOM, behind the porthole door, and the passage on to the cell chamber.
	{ "name": "ApproachDarkRoom", "pos": Vector2(-37, -38), "size": Vector2(18, 10), "h": 3.2 },     # x  -46..-28  z -43..-33
	{ "name": "ApproachDarkPassage", "pos": Vector2(-24, -36.5), "size": Vector2(8, 3), "h": 3.0 },  # x  -28..-20  z -38..-35
]
const DOORS := [
	{ "pos": Vector2(-80, -65), "width": 2.4, "dir": "z", "h": 2.8 },    # Service <-> ServiceJog (jog 1)
	{ "pos": Vector2(-58, -65), "width": 2.4, "dir": "z", "h": 2.8 },    # ServiceJog <-> ServiceReturn (jog 2)
	{ "pos": Vector2(-43, -65), "width": 2.4, "dir": "z", "h": 2.8 },    # ServiceReturn <-> PumpReturn
	{ "pos": Vector2(-46, -48), "width": 2.4, "dir": "x", "h": 2.8 },
	{ "pos": Vector2(-97, -45), "width": 2.4, "dir": "z", "h": 2.8 },
	{ "pos": Vector2(-94, -26), "width": 2.4, "dir": "x", "h": 2.8 },
	{ "pos": Vector2(-62, -26), "width": 2.4, "dir": "x", "h": 2.8 },
	# ⚠️ PASS 3: STILL CUT, NO LONGER A ROUTE. A collapsed duct section fills it, with a collider
	# (`_build_collapse`). The opening stays in the wall so the collapse has a hole to fall into.
	{ "pos": Vector2(-26, -26), "width": 2.4, "dir": "x", "h": 2.8 },
	{ "pos": Vector2(-13.5, -29), "width": 1.6, "dir": "z", "h": 2.3 },  # Containment <-> Cell12
	{ "pos": Vector2(0, -23), "width": 2.4, "dir": "z", "h": 2.8 },
	{ "pos": Vector2(0, -3), "width": 1.8, "dir": "z", "h": 2.5 },
	# These openings are sealed inspection windows, not alternate player routes.
	{ "pos": Vector2(-80, -45), "width": 7.0, "dir": "z", "h": 2.8 },
	{ "pos": Vector2(-63, -45), "width": 7.0, "dir": "z", "h": 2.8 },
	# ⭐ PASS 3. The grille aperture is a full-height cut filled above and below by steel housing.
	{ "pos": Vector2(-40, -55), "width": 2.0, "dir": "x", "h": 2.3 },    # PumpReturn | Isolation4 (grille)
	{ "pos": Vector2(PORTHOLE_X, -33), "width": 1.44, "dir": "z", "h": 2.4 },  # Plenum <-> DarkRoom (the porthole door)
	{ "pos": Vector2(-28, -36.5), "width": 1.4, "dir": "x", "h": 2.4 },  # DarkRoom <-> DarkPassage
	{ "pos": Vector2(-20, -36.5), "width": 1.4, "dir": "x", "h": 2.4 },  # DarkPassage <-> Cell12
]
# ⭐ PASS 3: the walk STOPS here, in front of the porthole door, for the handle and the wheel
# (`check_breach_approach.gd` does both through the real E ray and synthesized mouse circles).
const DOOR_STOP := Vector3(PORTHOLE_X, 0.1, -31.2)
# ⭐ PASS 4: and first HERE, at the far side of the Plenum, where the fused technician holds the handle.
const TECH_STOP := Vector3(-28.6, 0.1, -29.6)
const WALK_POINTS: Array[Vector3] = [
	START_SPAWN, Vector3(-80, 0.1, -68), Vector3(-80, 0.1, -62), Vector3(-58, 0.1, -62),
	Vector3(-58, 0.1, -68), Vector3(-43, 0.1, -68), Vector3(-43, 0.1, -48),
	Vector3(-97, 0.1, -48), Vector3(-97, 0.1, -26),
	Vector3(-78, 0.1, -26), Vector3(-33.0, 0.1, -26), TECH_STOP, Vector3(-35.0, 0.1, -26.8),
	Vector3(PORTHOLE_X, 0.1, -26.8), DOOR_STOP,
	Vector3(PORTHOLE_X, 0.1, -36.5), Vector3(-29.0, 0.1, -36.5), Vector3(-21.0, 0.1, -36.5),
	Vector3(-13.8, 0.1, -34.3), Vector3(-13.5, 0.1, -30.3), Vector3(-13.5, 0.1, -26),
	Vector3(0, 0.1, -26), Vector3(0, 0.1, -1.2),
]
# Every beat fires once per run, and in this order on a walk down WALK_POINTS. The test asserts
# the order from `beat_log`; the sequences' inner steps are logged too, after their parent.
const ROUTE_BEATS := ["arrival_lamps", "pa_1", "self_waking_lamp", "door_tell", "shutter",
	"smashed_lamp", "pa_2", "grating", "duct_knocks", "duct_crawl", "victim", "technician",
	"wheel_fitted", "porthole_open", "dark_room", "cell_chamber", "pa_3", "ceiling_drop", "threshold_quiet", "hand"]

const AUD := "res://assets/audio/level_6_breach/"
const HandScript := preload("res://scripts/breach_approach_hand.gd")
const TEX := "res://assets/textures/level_6_breach/"
const MASTER := "Master"
# ⚠️ There is NO "SFX" bus in this project (audio_buses.gd creates Ambience and Body only). The
# 2026-09-22 approach asked for "SFX" and silently fell back to Master, so nothing here could ever
# be ducked. Machinery and the bed go on Ambience (HoldBreath ducks it); story beats on Master.
const AMBIENCE := AudioBuses.AMBIENCE

# --- tuning (presentation only; none of these is a difficulty constant) ---------------------
const MOTION_RADIUS := 5.0          # a motion lamp clunks on as the player comes this close
const WAKE_LOOK_DOT := 0.7          # the self-waking lamp waits until it is in view…
const WAKE_FALLBACK_X := -73.0      # …or until the player is this far down ServiceJog anyway
const WAKE_HOLD := 2.0              # it holds ~2 s, then dies
const STORY_GAP := 0.5              # air between two story beats on the one channel
const HAND_MIN_DIST := 3.0
# 3–5 m (the 2026-09-23 legibility pass). At ~10 m the hand was a speck; at ~6.5 m a thin sliver
# that read as a hanging cable. Closer than 3 m it goes unseen (`hand_skipped`).
const HAND_MAX_DIST := 5.0
# ~41°, not 32°: at 3–5 m the hand sits 2.2 m to the side of the lane, so a strict cone would give a
# player walking straight a firing window of ~0.15 s. At 41° it is ~0.45 s. It still needs a look.
const HAND_LOOK_DOT := 0.75
const HAND_QUIET := 1.0             # the scream lands in silence, or not at all
# ⚠️ DELIBERATE (2026-09-24, the user's call): 4 dB over KONTUR's tannoy (kontur.gd:PA_LINE_DB −5).
# The Master-bus recording (probe_breach_music_mix.gd) measured the PA at −29.8 against the beds'
# −25.1 with NO music at all, so its lines ("seal integrity 61 %", "Object Twelve is not in its—")
# were half-lost. KONTUR keeps its own level.
const PA_DB := -1.0
const VENT_DB := -12.0              # approach_vent_bed RMS -16.2 dBFS -> ~-28 effective, under the bed
const VENT_LFO_DB := 3.0
const VENT_LFO_PERIOD := 7.5
const THRESHOLD_DUCK_DB := -26.0
# The machinery pool: loudest-300 ms of each generated one-shot, as measured by
# tools/make_sfx_breach_approach.py, so every one lands at the same loudness at the listener.
const MACHINERY := {
	"approach_mach_valve_hiss": -10.10, "approach_mach_relay_clunk": -17.52,
	"approach_mach_pipe_ticks": -19.45, "approach_mach_duct_pop": -12.78,
	"approach_mach_chain_rattle": -14.16, "approach_mach_bearing_whine": -6.45,
	"approach_mach_steam_sigh": -12.70, "approach_mach_metal_ping": -9.53,
	"approach_mach_conduit_buzz": -9.07, "approach_mach_gate_clank": -10.72,
	"approach_mach_fan_spindown": -7.20, "approach_mach_pressure_groan": -10.48,
}
const MACH_TARGET_DB := -24.0       # loud300 at the listener, a little under the beds
const MACH_GAP := Vector2(6.0, 14.0)
const MACH_DIST := Vector2(6.0, 15.0)
const MACH_BEHIND := 0.6            # ~60 % from the rear 120°

# --- pass 3 (2026-09-23) --------------------------------------------------------------------
const GrilleScript := preload("res://scripts/breach_approach_grille.gd")
const ProxyScript := preload("res://scripts/breach_approach_proxy.gd")
const GRILLE_LAYER := 1 << 18          # breach_approach_grille.gd:LAYER — the pump lamps skip it
const GRILLE_Z := -55.0                # on PumpReturn's EAST wall (x -40), where the tell comes from
const GRILLE_BOTTOM := 1.1
const GRILLE_TOP := 2.3
const ISO_DOOR_X := -37.2              # the battered door's face, on Isolation4's east wall
# ⚠️ 1.7 m NORTH of the grille's centre, not behind it (first render): the player walks up PumpReturn
# from the south, so the line of sight through the slats runs diagonally toward +z. Centred behind
# the grille, the creature showed as a sliver at the aperture's edge from the lane.
const ISO_DOOR_Z := -53.3
const ISO_STAND := Vector3(-38.05, 0.0, ISO_DOOR_Z)
const GRILLE_HITS := 5                 # `_door_tell`'s five thuds, one blow each
# ⚠️ DIFFICULTY-ADJACENT — THE USER'S CALL (2026-09-23, grilled): "Inside … completely dark …
# No jumpscares but the panic will rise." Capped at ~42/50 so it can never kill, reaching the cap in
# ~15–20 s against normal decay. Nothing on screen explains it. It is the approach's ONLY panic term.
const DARK_PANIC_CAP := 42.0           # 0.84 of player.gd:PANIC_MAX
const DARK_PANIC_RATE := 5.9           # player.gd:PANIC_DECAY_RATE 3.5 + 42 / 17.5 s
# ⚠️ WHEEL FEEL — THE USER'S CALL: "roughly 3 full turns / ~10–15 s", forgiving on a trackpad.
const WHEEL_TURNS := 3.0
const WHEEL_GEAR := 0.55               # wheel radians per radian the hand's motion turns through
const WHEEL_MAX_RATE := 1.9            # rad/s: circling faster slips, so three turns take >= 9.9 s
const WHEEL_DRIFT := 0.45              # rad/s back toward shut once you stop
const WHEEL_DRIFT_DELAY := 0.35
const WHEEL_SMOOTH := 0.4              # weight of each new motion event in the hand vector
const WHEEL_MIN_SPEED := 1.0           # px per event: slower than this, the direction is noise
const WHEEL_REVERSAL := 1.2            # rad: a jump bigger than this is a reversal, never a turn
const WHEEL_PICK := 0.6                # rad of consistent turning picks which way is "open"
const WHEEL_CREAK_STEP := PI / 6.0     # a creak every 30° of wheel
const WHEEL_REACH := 2.6               # further than this from the wheel and the hand lets go
const WHEEL_BANK := 0.25               # rad of turning carried past the rate cap (frantic spinning can't bank more)
const GLASS_STEP := 0.55               # metres between crunches on the chamber's shards
# ⚠️ PLACEHOLDERS at the user's FIXED paths — tools/make_sfx_breach_pass3.py. Drop the recordings
# in over them. Gains are set from the stand-ins' measured level (RMS in the comment).
const SND_WHISPER := "approach_whisper_dont_go_in"   # -20.6 RMS; story beat, Master
# ⭐ PASS 5 (2026-09-24): the USER's scream (`man_scream.wav`, prepared: 2.27 s, peak -1.6 dBFS, RMS
# -6.5 dBFS, -5.5 LUFS — very hot). It comes with his eyes opening, BEFORE the whisper. Its gain is set
# from the recorded mix (tests/probe_breach_music_mix.gd, the player at TECH_STOP, the victim scene
# still playing): -14.8 dB RMS at the listener (loudest 0.1 s window -12.7), 11.4 dB over everything
# else in that moment (-26.2), and 4.0 dB UNDER the kill sting (level_6_jumpscare, flat at -8 dB:
# -10.8). At -10 dB it measured -22.8, only 3.4 dB over the mix — not a jolt.
const SND_TECH_SCREAM := "approach_technician_scream"
const TECH_SCREAM_DB := -2.0
const VICTIM_TECH_DUCK := -14.0     # the victim scene behind the door ducks under his beat — never cut
const SND_GRIND := "approach_wheel_grind"            # loop, -14.2 RMS; machinery, Ambience
const SND_CREAK := "approach_wheel_creak"            # every 30°, -12.7 RMS
const SND_BOLTS := "approach_porthole_bolts"         # -11.7 RMS (stand-in: KONTUR's door_seal)
const SND_SWING := "approach_porthole_swing"         # -20.4 RMS (stand-in: the Lab's metal_creak)
const SND_CLACK := "approach_handle_clack"           # -22.4 RMS
const SND_SPARK := "approach_spark_burst"            # -19.1 RMS (stand-in: the Lab's breaker_spark)
const SND_BUZZ := "approach_spark_buzz"              # loop, -7.2 RMS (stand-in: breaker_buzz)
const SND_DARK_BED := "approach_darkroom_bed"        # loop, -15.9 RMS
const SND_GLASS := ["approach_glass_crunch_1", "approach_glass_crunch_2", "approach_glass_crunch_3"]
const SND_CRT := "approach_crt_hum"                  # loop, -15.2 RMS
const CCTV_VIDEO := "res://assets/video/breach_cctv_breakout.ogv"   # the user's clip replaces it
const CELL_SPOT := Vector3(-11.0, 0.0, -34.8)        # where the shared ContainmentCell stands (front -> -x)

# --- pass 4 (2026-09-23) --------------------------------------------------------------------
const FaceScript := preload("res://scripts/breach_approach_face.gd")
const FACE_LAYER := 1 << 16                          # breach_approach_face.gd:LAYER — the bay lamps skip it
const NICHE_D := 0.55                                # the shutter's niche: room for a head behind the roll
const SHUTTER_NEAR := 16.0                           # the shutter keeps cycling while the player is this close
const SHUTTER_MAX_CYCLES := 8
const FACE_LOOK_DOT := 0.8                           # a cycle opens face-up only if the niche is looked at…
const FACE_LOOK_DIST := 14.0                         # …from this close
const SHUTTER_WINDOW := Vector3(-62.4, 1.3, -45.0)   # bay B's glass, for "is the player near"
# The ceiling drop (Containment, south of the lane). Crossing DROP_TRIGGER_X drops the body ~2.3 m
# ahead and 1.2 m to the side of the walking line (z -26), where it can swing without touching it.
const DROP_TRIGGER_X := -9.2
const DROP_PIVOT := Vector3(-6.9, 2.55, -24.8)
const DROP_LAMP_ENERGY := 1.1                   # the work lamp on his chain (legibility, not a difficulty number)
# The fused technician, on the Plenum's east wall north of the collapse, where the player must look.
const TECH_WALL_X := -26.0
const TECH_Z := -30.4
const TECH_W := 1.30                                 # the relief's width (and height: the art is square); LIFE SIZE
const TECH_FACE_Y := 1.55                            # his eyes, at a man's height
const TECH_RELIEF_Z := 0.045                         # the relief off the wall face (the roots decal is at 0.022)
const TECH_WHEEL_OFF := 0.004                        # the wheel's plane off the FISTS' displaced surface (its tube sinks into them)
const TECH_MESH_N := 192                             # the bas-relief grid (192² cells over 1.3 m: 6.8 mm)
const TECH_RELIEF_DEPTH := 0.18                      # the height map's full scale; tools/make_breach_pass4_art.py:RELIEF_DEPTH
const TECH_SPREAD_W := 2.3                           # the roots decal behind him
const TECH_LAMP_ENERGY := 2.6                        # the caged lamp above him (legibility, not a difficulty number)
# Measured on the user's art, `…/approach/user/fused_technician_closed_D.jpg` (1024², on a 5 px grid);
# `tools/make_breach_pass4_art.py` carries the eye numbers too. Change them together.
const TECH_ART_HEAD_FRAC := 0.161                    # his head, ears included: 165 of 1024 px
const TECH_ART_EYES_UV := Vector2(0.506, 0.2)        # between his eyes, (491, 204.5) and (545, 203)
const TECH_ART_GRIPS_UV := [Vector2(0.4932, 0.5811), Vector2(0.5762, 0.6836)]   # the curl of each painted fist
const TECH_ART_WHEEL_R_PX := 83.0                    # a rim through both fists, on the art
const CARRIED_WHEEL := "THE VALVE WHEEL"             # the carried line while he has given it up and it is not fitted
const VALVE_R := TECH_ART_WHEEL_R_PX / 1024.0 * TECH_W   # the valve wheel's rim radius, 0.105 m (on the door and in his hands)
# ⚠️ PLACEHOLDERS at the user's fixed paths — tools/make_sfx_breach_pass4.py
const SND_DROP_CRASH := "approach_drop_crash"        # the hatch bursting and the body's weight hitting the chain
const SND_DROP_CHAIN := "approach_drop_chain"        # the chain rattling as it swings
const SND_FACE_BREATH := "approach_shutter_breath"   # a very low breath from the niche (optional)
# The walk-in music (the user's, prepared by tools/prepare_breach_music.py: 70.26 s, −14.4 LUFS).
# ⚠️⚠️ IT IS THE LEAD LAYER (the user, 2026-09-23, after watching the renders run: "I do not hear the
# music I sent you, I hear just the sound of the corridor … not too silent and not too loud"). At the
# first build's -17 dB it sat at -31.4 LUFS effective, 4 dB UNDER the vent bed (-27.5 LUFS), and 10 dB
# under it whenever a story beat ducked it. Gains below are set from a recording of the mix on a real
# walk (`tests/probe_breach_music_mix.gd`; the numbers are in the level spec).
const MUSIC_DB := -4.0
const MUSIC_STORY_DUCK := -6.0      # under the door tell, the victim and the other story beats
const MUSIC_WHISPER_DUCK := -14.0   # under the technician's whisper
const MUSIC_PA_DUCK := -17.0        # under a PA line: the tannoy is quiet and must stay intelligible
# ⭐ 2026-09-24: the BEDS (vent hum + the level's beds) dip too while a PA line plays. Raising PA_DB
# 4 dB left the tannoy level with the hum (~-27 vs ~-25 LUFS, probe_breach_music_mix.gd), so the
# hum makes room for the announcer instead of the announcer being pushed any hotter.
const BED_PA_DUCK := -4.0
const MUSIC_FADE_DB_S := 6.0        # coming back up after a beat
const MUSIC_DUCK_DB_S := 60.0       # going down for one: a 15 dB duck in 0.25 s, before the first word

var completed := false
var beat_log: Array[Dictionary] = []
var hand_fire_distance := -1.0   # camera to hand when the glimpse fired (the test asserts 3–5 m)
var _player: CharacterBody3D
var _builder: RoomBuilder
var _gate: Node3D
var _gate_blocker: CollisionShape3D
var _gate_sound: AudioStreamPlayer3D
var _steel: StandardMaterial3D
var _rust: StandardMaterial3D
var _dark: StandardMaterial3D
var _indicator: StandardMaterial3D
var _time := 0.0
var _configured := false
var _rng := RandomNumberGenerator.new()
var _fired: Dictionary = {}
var _timeline: Array = []
var _story_queue: Array = []
var _story_busy_until := -100.0
var _tail_until := -100.0
var _players: Array = []
var _tweens: Array = []
# lamps
var _clusters: Array = []
var _wake_lamp: Dictionary = {}
var _wake_performing := false
var _pump_lamps: Array = []
var _smashed_sputter: Dictionary = {}
var _door_lamp: Dictionary = {}
# props that act
var _shutter_pivot: Node3D
var _shutter_speaker: AudioStreamPlayer3D
var _grating: Node3D
var _housing: Node3D
var _residue_growth: Node3D
var _hand: HandScript
var _receivers: Array = []
# audio
var _vent: AudioStreamPlayer
var _bed_pa_db := 0.0                # the beds' PA dip, smoothed (BED_PA_DUCK while a line plays)
var _pa: AudioStreamPlayer
var _pa_chime_until := 0.0
var _whisper_until := 0.0           # the technician's scream and whisper are playing (the music makes room)
var _tech_beat_until := 0.0         # the technician's whole beat (the beds and the victim scene duck under it)
var _victim_speakers: Array = []    # [speaker, base gain] of the victim scene, for the duck
var _victim_duck_db := 0.0
var _mach_next := 8.0
var _mach_streams: Dictionary = {}
var _level_beds: Dictionary = {}
var _duck_db := 0.0
var _duck_target := 0.0
var _duck_speed := 60.0
var _threshold_quiet := false
# pass 3 — the grille
var _grille: Node3D
var _iso_lamp: Dictionary = {}
var _iso_door: Node3D
# pass 3 — the porthole door, the technician and the wheel
# ⚠️ Since pass 4 the "handle" IS THE WHOLE VALVE WHEEL (he holds it; the door has a bare spindle).
# The names `handle_taken` / `handle_fitted` and the snapshot key `approach_handle_taken` are KEPT so
# a saved snapshot still restores: taken = he has given the wheel up; fitted = it is on the spindle.
var handle_taken := false
var handle_fitted := false
var porthole_open := false
var wheel_engaged := false
var wheel_progress := 0.0              # radians of wheel turned toward open
var _porthole_pivot: Node3D
var _wheel: Node3D
var _bolts: Array = []
var _tech_mat: StandardMaterial3D
var _tech_tex_open: Texture2D
var _tech_tex_closed: Texture2D
var _tech_wheel: Node3D
var _tech_heights := PackedFloat32Array()     # the bas-relief's vertex heights, (TECH_MESH_N + 1)²
var _tech_busy := false
var _tech_head := Vector3.ZERO
var _wheel_sign := 0
var _wheel_pre := 0.0
var _wheel_v := Vector2.ZERO
var _wheel_last_ang := INF
var _wheel_pending := 0.0
var _wheel_idle := 0.0
var _wheel_creak_idx := 0
var _wheel_speed := 0.0
var _wheel_grind: AudioStreamPlayer3D
var _wheel_toast_t := -10.0
var wheel_turn_seconds := 0.0          # time engaged until open (the test reports it)
# pass 3 — the dark room
var _spark_light: OmniLight3D
var _spark_fx: Array = []
var _spark_speaker_pos := Vector3.ZERO
var _spark_queue: Array = []
var _spark_next := 1.0
var _dark_bed: AudioStreamPlayer
var _in_dark := false
var dark_panic_peak := 0.0
var spark_bursts := 0
# pass 3 — the cell chamber
var _glass_last := Vector3(INF, 0, INF)
var glass_crunches := 0
var _cell_spot: Marker3D
var _cctv_video: VideoStreamPlayer
var _cctv_mat: ShaderMaterial
var _cctv_stamp: Label3D
var _cctv_clock := 0.0
# pass 4 — the shutter face
var _face: Node3D
var _shutter_cycles := 0
var _shutter_busy := false
var _shutter_next := 0.0
var _face_done := false
var _face_cycle := -1                 # which cycle showed the face (1 since 2026-09-24: the FIRST opening)
var _niche_centre := Vector3.ZERO
# pass 4 — the ceiling drop
var _drop_rig: Node3D
var _drop_body: Node3D
var _drop_hatch: Node3D
var _drop_solid: CollisionShape3D
var _drop_t := -1.0
var drop_ahead := -1.0                # along-lane distance, camera to body, at the drop
var drop_distance := -1.0             # straight-line horizontal distance, camera to body, at the drop
var _containment_lamps: Array = []
var _drop_lamp: OmniLight3D
var _drop_bulb_mat: StandardMaterial3D
# pass 4 — the music
var _music: AudioStreamPlayer
var _music_db := MUSIC_DB


func configure(builder: RoomBuilder, player: CharacterBody3D, already_completed: bool) -> void:
	_builder = builder
	_player = player
	# ⚠️ Seeded FROM the engine RNG, never randomize(): the guards pin every level with
	# seed(n) (spec/systems/testing.md, "Nothing in game/scripts calls randomize()").
	_rng.seed = randi()
	_steel = _material(Color(0.25, 0.29, 0.28), 0.65)
	_dark = _material(Color(0.075, 0.09, 0.095), 0.5)
	_rust = RoomBuilder.make_material("res://assets/textures/level_6_breach/breach_wall_ruptured.png",
		Vector3(0.45, 0.45, 0.45), Color(0.27, 0.16, 0.1))
	_indicator = _material(Color(0.36, 0.5, 0.45), 0.0)
	_indicator.emission_enabled = true
	_indicator.emission = Color(0.16, 0.29, 0.22)
	_indicator.emission_energy_multiplier = 0.4
	_build_service()
	_build_pump_return()
	_build_observation()
	_build_inspection()
	_build_damaged()
	_build_plenum()
	_build_containment()
	_build_threshold()
	_configured = true
	if already_completed:
		seal_immediate()
	else:
		_start_beds()


# The level lowers its own beds for the approach and hands them over, so the silence beats can
# take them down with the approach's own Ambience-bus layers. Restored before `committed`.
func set_level_beds(beds: Array) -> void:
	for bed in beds:
		if bed is AudioStreamPlayer:
			_level_beds[bed] = bed.volume_db


func beat_names() -> PackedStringArray:
	var out := PackedStringArray()
	for b in beat_log:
		out.append(b["name"])
	return out


func hand_puppet() -> Node3D:
	return _hand if is_instance_valid(_hand) else null


# ============================================================== ROOM 1: the service corridor (A1)

func _build_service() -> void:
	# Ducts run along one wall of each leg, cable trays along the other — the lane stays clear.
	_box("ServiceDuct", Vector3(-89, 3.05, -70.3), Vector3(21.6, 0.7, 1.0), _steel)
	_box("ServiceJogDuct", Vector3(-69, 3.05, -59.7), Vector3(25.6, 0.7, 1.0), _steel)
	_box("ServiceReturnDuct", Vector3(-50, 3.05, -70.3), Vector3(19.6, 0.7, 1.0), _steel)
	for x in [-97.0, -92.5, -86.0, -81.5]:
		_box("DuctClamp", Vector3(x, 3.05, -70.3), Vector3(0.12, 0.82, 1.12), _dark)
	for x in [-79.0, -73.0, -66.0, -61.0]:
		_box("DuctClamp", Vector3(x, 3.05, -59.7), Vector3(0.12, 0.82, 1.12), _dark)
	for x in [-57.0, -51.0, -45.0]:
		_box("DuctClamp", Vector3(x, 3.05, -70.3), Vector3(0.12, 0.82, 1.12), _dark)
	_box("CableTray", Vector3(-90.5, 2.6, -65.4), Vector3(18.6, 0.1, 0.4), _dark)
	_box("CableTray", Vector3(-69, 2.6, -64.6), Vector3(19.0, 0.1, 0.4), _dark)
	_box("CableTray", Vector3(-51.5, 2.6, -65.4), Vector3(12.8, 0.1, 0.4), _dark)
	for x in range(-98, -41, 3):
		if x > -80 and x < -58:
			continue
		_box("ServiceFloorJoint", Vector3(x, 0.012, -68), Vector3(0.06, 0.018, 5.5), _dark)
	# ⭐ MOTION LAMPS in UNEVEN clusters, with one dead fitting: each cluster clunks on as the
	# player comes within MOTION_RADIUS, which teaches the rule inside the first ten seconds.
	# The spawn cluster is inside that radius, so arriving IS the first lesson.
	var cool := Color(0.52, 0.7, 0.73)
	_cluster("arrival", [Vector3(-98.2, 3.2, -68), Vector3(-97.0, 3.2, -68)], cool)
	_cluster("service_b", [Vector3(-90.0, 3.2, -68), Vector3(-88.8, 3.2, -68), Vector3(-87.6, 3.2, -68)], cool)
	_dead_fitting(Vector3(-84.0, 3.2, -68))
	_cluster("service_c", [Vector3(-80.4, 3.2, -68)], cool)
	_cluster("jog_a", [Vector3(-77.2, 3.2, -62), Vector3(-76.0, 3.2, -62)], cool)
	_cluster("jog_b", [Vector3(-65.0, 3.2, -62), Vector3(-63.8, 3.2, -62)], cool)
	_cluster("return_a", [Vector3(-57.0, 3.2, -68)], cool)
	_cluster("return_b", [Vector3(-50.4, 3.2, -68), Vector3(-49.2, 3.2, -68)], cool)
	# ⭐ THE RULE BREAKS: at the far end of the jog, ~20 m ahead of the player who has just
	# learned the rule, one lamp clunks on BY ITSELF, holds, and dies. Something else is here.
	_wake_lamp = _lamp(Vector3(-59.0, 3.2, -62), cool, 1.2, 10.0, false)
	# A shift roster with every name crossed out but one, lit by the arrival cluster.
	var board := _builder.wall_point("ApproachService", Vector2(0, 1), 1.55, 0.16)
	board.x = -93.4
	_backed_plate("ShiftRoster", TEX + "approach_shift_board.png", board, PI, Vector2(1.3, 0.85), 0.0)
	_sign("UTILITY INTAKE   /   06", Vector3(-89.0, 2.05, -65.18), PI, 0.009)
	# The jog's end wall points at the second turn: facing +x, ServiceReturn is on the LEFT.
	_sign("←  PRESSURE RETURN", _builder.wall_point("ApproachServiceJog", Vector2(1, 0), 2.1, 0.18), -PI / 2.0, 0.008)
	# Barrier tape at the first jog, strung to face INWARD — its printed side faces containment,
	# so it was put up to keep something IN — and torn through from that side. The player walks
	# up to its back and reads it mirrored.
	var tape := load(TEX + "approach_barrier_tape.png")
	for side in [-1.0, 1.0]:
		var half := _quad("BarrierTape", tape, Vector2(1.15, 0.0), true)
		half.position = Vector3(-80 + side * 0.66, 0.95, -65.0)
		half.rotation = Vector3(0, 0, side * 0.42)


func _build_pump_return() -> void:
	for z in [-60.0, -51.0]:
		_pressure_vessel(Vector3(-44.8, 0.0, z), 0.62, 2.35)
		var lamp := _lamp(Vector3(-41.2, 2.8, z), Color(0.68, 0.59, 0.38), 0.8, 8.0, true)
		# ⚠️ Never on the grille puppet: lit from the player's side it stops being a silhouette.
		(lamp["light"] as Light3D).light_cull_mask = 0xFFFFF & ~GRILLE_LAYER
		_pump_lamps.append(lamp)
	# PumpReturn (4.0 m) is taller than both neighbours: fill each doorway above the lower ceiling.
	_lintel(Vector3(-43, 0, -65), 2.4, 3.56, 4.1)    # ServiceReturn 3.6
	_lintel(Vector3(-46, 0, -48), 2.4, 3.36, 4.1)    # Observation 3.4
	_sign("RETURN LINE  /  ISOLATION DOOR 4  →", Vector3(-40.18, 2.9, -59.6), -PI / 2.0, 0.006)
	_build_grille()


# ⭐ P2 (2026-09-23, capture 1: "This looks weird … It should look way more realistic … should we
# see some kind of a real monster through it?"). The old `PressureManifold` was a flat black slab on
# the WEST wall — the wrong side of the room from the door tell. This is a steel return-air housing
# on the EAST wall, where the tell comes from, with a louvred grille you can see between: frame,
# depth, dust on every slat. Behind it is ApproachIsolation4, a small unreachable room with a steel
# door on its far wall. During the tell, Object 12's back and crown batter that door
# (`breach_approach_grille.gd`); in the silence it stills; the lamps die; when they come back it is
# gone and the door hangs open.
func _build_grille() -> void:
	var z := GRILLE_Z
	var half := 1.0                 # the aperture is the 2.0 m doorway cut in DOORS
	# matte, mid grey: at metallic 0.55 with nothing to reflect it rendered as a black column
	var housing := _material(Color(0.33, 0.35, 0.33), 0.15)
	housing.roughness = 0.6
	# the steel housing panels that fill the full-height cut below and above the grille: solid, and
	# 3 cm proud of both wall faces like `_lintel`, so no face is coplanar with the wall
	_solid_box("GrilleHousingLow", Vector3(-40, GRILLE_BOTTOM * 0.5, z), Vector3(0.26, GRILLE_BOTTOM, 2.1), housing)
	_solid_box("GrilleHousingHigh", Vector3(-40, (GRILLE_TOP + 4.1) * 0.5, z), Vector3(0.26, 4.1 - GRILLE_TOP, 2.1), housing)
	for dz in [-0.9, 0.9]:
		for y in [0.25, 3.3]:
			_box("HousingRivet", Vector3(-40.14, y, z + dz), Vector3(0.02, 0.05, 0.05), _dark)
	# the frame on the PumpReturn face: a heavy flanged border round the aperture
	var frame := _material(Color(0.13, 0.14, 0.13), 0.6)
	var cy := (GRILLE_BOTTOM + GRILLE_TOP) * 0.5
	var h := GRILLE_TOP - GRILLE_BOTTOM
	_box("GrilleFrameTop", Vector3(-40.17, GRILLE_TOP + 0.05, z), Vector3(0.1, 0.1, 2.2), frame)
	_box("GrilleFrameBottom", Vector3(-40.17, GRILLE_BOTTOM - 0.05, z), Vector3(0.1, 0.1, 2.2), frame)
	_box("GrilleFrameSideA", Vector3(-40.17, cy, z - half - 0.05), Vector3(0.1, h + 0.2, 0.1), frame)
	_box("GrilleFrameSideB", Vector3(-40.17, cy, z + half + 0.05), Vector3(0.1, h + 0.2, 0.1), frame)
	# the sleeve lining the cut, black: depth you can see into
	var lining := _material(Color(0.03, 0.035, 0.035), 0.3)
	_box("GrilleSleeveTop", Vector3(-39.97, GRILLE_TOP - 0.015, z), Vector3(0.3, 0.03, 2.0), lining)
	_box("GrilleSleeveBottom", Vector3(-39.97, GRILLE_BOTTOM + 0.015, z), Vector3(0.3, 0.03, 2.0), lining)
	_box("GrilleMullion", Vector3(-40.05, cy, z), Vector3(0.06, h, 0.05), frame)
	# the louvres: horizontal slats tilted 35° with their outer edge DOWN, so a standing player looks
	# level through the gaps (68 % open) while a lamp above cannot glare through them
	var slat_mat := _material(Color(0.24, 0.25, 0.23), 0.5)
	slat_mat.roughness = 0.8
	var dust := _material(Color(0.42, 0.4, 0.35), 0.0)
	dust.roughness = 1.0
	var y := GRILLE_BOTTOM + 0.07
	while y < GRILLE_TOP - 0.05:
		var slat := Node3D.new()
		slat.name = "GrilleLouvre"
		add_child(slat)
		slat.position = Vector3(-40.06, y, z)
		slat.rotation.z = deg_to_rad(-35)
		_box("LouvreBlade", Vector3.ZERO, Vector3(0.075, 0.012, 2.0), slat_mat, slat)
		_box("LouvreDust", Vector3(0.004, 0.008, 0.0), Vector3(0.06, 0.004, 1.98), dust, slat)
		y += 0.105
	# the aperture cannot be walked or climbed into
	_solid("GrilleBarrier", Vector3(-40.0, cy, z), Vector3(0.12, h, 2.0))
	# soot and dust streaks on the housing under the grille, where the return air drags them
	var streak := load(TEX + "approach_residue_trail.png")
	var q := _quad("GrilleSoot", streak, Vector2(1.6, 0.0), false, true)
	q.position = Vector3(-40.155, GRILLE_BOTTOM - 0.32, z)
	q.rotation = Vector3(0, -PI / 2.0, PI / 2.0 + 0.1)
	(q.material_override as StandardMaterial3D).albedo_color = Color(0.5, 0.48, 0.44, 0.6)
	_build_isolation_room()


# Behind the grille: the battered door, its lamp, and the puppet that batters it.
func _build_isolation_room() -> void:
	# ⚠️ PALE painted steel: the creature is a dark shape and must be seen AGAINST the door it batters
	# (first render: a dark leaf, and at each blow its body vanished into it)
	var steel := _material(Color(0.52, 0.53, 0.49), 0.1)
	steel.roughness = 0.7
	var door_frame := _material(Color(0.1, 0.1, 0.1), 0.5)
	var z := ISO_DOOR_Z
	_box("IsoDoorJambA", Vector3(ISO_DOOR_X, 1.1, z - 0.62), Vector3(0.12, 2.2, 0.1), door_frame)
	_box("IsoDoorJambB", Vector3(ISO_DOOR_X, 1.1, z + 0.62), Vector3(0.12, 2.2, 0.1), door_frame)
	_box("IsoDoorHead", Vector3(ISO_DOOR_X, 2.25, z), Vector3(0.12, 0.1, 1.34), door_frame)
	# what is behind the door once it is gone: black, 3 cm off the wall face
	var black := _material(Color(0, 0, 0), 0.0)
	black.roughness = 1.0
	_box("IsoDoorVoid", Vector3(-37.13, 1.1, z), Vector3(0.01, 2.2, 1.14), black)
	_iso_door = Node3D.new()
	_iso_door.name = "IsoDoorHinge"
	add_child(_iso_door)
	_iso_door.position = Vector3(ISO_DOOR_X - 0.04, 0, z - 0.56)
	_box("IsoDoorLeaf", Vector3(0, 1.08, 0.56), Vector3(0.06, 2.12, 1.1), steel, _iso_door)
	for yy in [0.55, 1.1, 1.65]:
		_box("IsoDoorBand", Vector3(-0.035, yy, 0.56), Vector3(0.02, 0.07, 1.06), _dark, _iso_door)
	_box("IsoDoorStencil", Vector3(-0.035, 1.9, 0.56), Vector3(0.01, 0.12, 0.5), _material(Color(0.5, 0.42, 0.12), 0.0), _iso_door)
	# its lamp lights everything EXCEPT the puppet: the door glows dull behind a dark shape
	_iso_lamp = _lamp(Vector3(-37.55, 2.5, z), Color(0.72, 0.62, 0.44), 1.1, 3.4, true)
	(_iso_lamp["light"] as Light3D).light_cull_mask = 0xFFFFF & ~GRILLE_LAYER
	_grille = GrilleScript.new()
	_grille.name = "ApproachGrilleGlimpse"
	add_child(_grille)
	if not _grille.setup(_creature_material(), ISO_STAND, ISO_DOOR_X - 0.03):
		_grille.queue_free()
		_grille = null


func grille_puppet() -> Node3D:
	return _grille if is_instance_valid(_grille) else null


# ============================================================== Observation + bays (A3)

const OBS_WORKING := [-94.0, -76.0, -58.0, -49.0]
const OBS_SMASHED := [-85.0, -67.0]
const POOL_R := 3.0      # the floor radius of a working spot's light: 3.1 m * tan(44°)

func _build_observation() -> void:
	# ⭐ LIGHT IS A WEAPON, TAUGHT BY THE WALLS. The working lamps are downlights with a hard-ish
	# edge; the residue trail runs everywhere EXCEPT inside those pools, and the two lamps on its
	# path are smashed. Nothing says so. The hunt's light weapon is the payoff.
	for x in OBS_WORKING:
		var spot := SpotLight3D.new()
		spot.name = "ObservationDownlight"
		spot.light_color = Color(0.56, 0.7, 0.66)
		# ⚠️ Stronger and HARDER (the legibility pass): at 4.0 / attenuation 0.6 the pools were dim
		# discs with soft rims, and the residue stopping at them did not register from ~6 m.
		spot.light_energy = 7.0
		spot.spot_range = 8.0
		spot.spot_angle = 44.0
		spot.spot_angle_attenuation = 0.15
		spot.shadow_enabled = false
		add_child(spot)
		spot.position = Vector3(x, 3.1, -48)
		spot.rotation = Vector3(-PI / 2.0, 0, 0)
		_box("DownlightFitting", Vector3(x, 3.26, -48), Vector3(0.6, 0.1, 0.6), _indicator)
		# a weak companion so the walls near a working lamp read; the pool is still the spot
		var spill := OmniLight3D.new()
		spill.light_color = Color(0.5, 0.64, 0.6)
		spill.light_energy = 0.3
		spill.omni_range = 6.0
		add_child(spill)
		spill.position = Vector3(x, 2.9, -48)
	for i in OBS_SMASHED.size():
		var x: float = OBS_SMASHED[i]
		var broken := _box("SmashedFitting", Vector3(x, 3.26, -48), Vector3(0.6, 0.1, 0.6), _dark)
		broken.rotation.z = 0.12
		var tube := _box("HangingTube", Vector3(x + 0.18, 2.95, -48.1), Vector3(0.04, 0.55, 0.04), _steel)
		tube.rotation.z = 0.35
		for s in 5:
			var shard := _box("GlassShard", Vector3(x + _rng.randf_range(-0.6, 0.6), 0.008,
				-48 + _rng.randf_range(-0.6, 0.6)), Vector3(0.08, 0.01, 0.05), _steel)
			shard.rotation.y = _rng.randf() * TAU
		if i == 1:
			# The first smashed lamp the player reaches still has a live tube in it.
			var spark := OmniLight3D.new()
			spark.light_color = Color(0.75, 0.85, 0.9)
			spark.light_energy = 1.4
			spark.omni_range = 4.0
			spark.visible = false
			add_child(spark)
			spark.position = Vector3(x, 2.9, -48)
			_smashed_sputter = {"light": spark, "pos": Vector3(x, 1.0, -48)}
	_residue_trail()
	for x in [-80.0, -63.0]:
		var glass := _material(Color(0.22, 0.32, 0.3, 0.16), 0.1)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_box("InspectionGlass", Vector3(x, 1.9, -45.01), Vector3(6.85, 1.65, 0.04), glass)
		_solid("InspectionWindowBarrier", Vector3(x, 1.4, -45.0), Vector3(7.0, 2.8, 0.1))
		# P6: the sill and mullions stand ~0.2 m proud of the barrier on the corridor side
		_solid_box("InspectionWindowSill", Vector3(x, 0.52, -45.05), Vector3(7.0, 1.04, 0.23), _steel)
		_box("InspectionHeader", Vector3(x, 2.77, -45.1), Vector3(7.05, 0.12, 0.2), _dark)
		for offset in [-3.45, 0.0, 3.45]:
			_solid_box("InspectionMullion", Vector3(x + offset, 1.92, -45.1), Vector3(0.09, 1.65, 0.19), _steel)
		for offset in [-2.2, 1.25, 2.8]:
			_box("WindowResidue", Vector3(x + offset, 2.1, -45.045), Vector3(0.055, 0.84, 0.018), _rust)
		_pressure_vessel(Vector3(x - 2.9, 0, -40.4), 0.75, 2.35)
		var bay_lamp := _lamp(Vector3(x, 2.7, -40.8), Color(0.43, 0.65, 0.56), 1.1, 6.5, true)
		# ⚠️ never on the shutter face: lit by the bay lamp its whole body shows, not a face in the dark
		(bay_lamp["light"] as Light3D).light_cull_mask = 0xFFFFF & ~FACE_LAYER
		# The bay's light spilling through the glass is the only light in the dark stretches:
		# enough to see the residue on the floor, and the gouged cabinet opposite bay A.
		var through := OmniLight3D.new()
		through.name = "BayWindowSpill"
		through.light_color = Color(0.43, 0.65, 0.56)
		through.light_energy = 0.8
		through.omni_range = 8.5
		through.light_cull_mask = 0xFFFFF & ~FACE_LAYER
		add_child(through)
		through.position = Vector3(x, 2.1, -45.8)
		_sign("INSPECTION   /   ISOLATED", Vector3(x, 0.78, -45.2), PI, 0.006)
	_solid_box("EmptyInspectionRack", Vector3(-78, 0.65, -40.2), Vector3(2.0, 1.3, 0.8), _dark)
	_build_shutter()
	# "98 %": the facility still believes the seal holds.
	var panel := _builder.wall_point("ApproachObservation", Vector2(0, -1), 1.6, 0.15)
	panel.x = -51.0
	_seal_panel("Seal98", TEX + "approach_seal_98.png", panel, 0.0, 0.5)
	_build_gouged_cabinet()


func _residue_trail() -> void:
	var trail := load(TEX + "approach_residue_trail.png")
	var pool := load(TEX + "approach_residue_pool.png")
	var k := 0
	var x := -99.0
	while x < -47.0:
		var clear := true
		for lx in OBS_WORKING:
			if absf(x - float(lx)) < POOL_R + 1.0:
				clear = false
		if clear:
			var tex: Texture2D = trail if k % 3 != 2 else pool
			var size := Vector2(1.8, 0.0) if k % 3 != 2 else Vector2(1.0, 0.0)
			_floor_decal("Residue", tex, Vector3(x, 0.024 + (k % 4) * 0.002, -48 + _rng.randf_range(-0.9, 0.9)),
				size, _rng.randf() * TAU)
			k += 1
		x += 1.25
	# ⭐ THE EDGE. One smear on each dark side of every working pool, laid along the corridor
	# with its ragged front reaching just into the pool's soft edge — that is where the residue
	# is lit, so that is where the player SEES it stop. (The first render kept every decal a
	# metre clear of the light, so no residue was ever lit at all.)
	for lx in OBS_WORKING:
		for dir in [-1.0, 1.0]:
			# the ragged front reaches ~0.35 m INTO the pool's hard rim: dark on lit floor, so the
			# residue is seen to stop there even from ~6 m (legibility pass; 0.18 m did not register)
			var ex: float = float(lx) + dir * (POOL_R + 0.55)
			if ex < -99.2 or ex > -46.6:
				continue
			var blocked := false
			for other in OBS_WORKING:
				if other != lx and absf(ex - float(other)) < POOL_R + 0.55:
					blocked = true
			if not blocked:
				# two across the corridor, so the fringe spans most of the rim, not a third of it
				for zc in [-49.05, -46.95]:
					_floor_decal("ResidueEdge", trail, Vector3(ex, 0.03 + k * 0.0005, zc + _rng.randf_range(-0.2, 0.2)),
						Vector2(1.8, 0.0), (0.0 if dir > 0 else PI) + _rng.randf_range(-0.25, 0.25))
					k += 1
	# a few smears climbing the walls in the dark stretches, never inside a pool
	# (x, wall) — solid wall only: the north wall is cut by two 7 m windows and the Inspection door.
	for spec in [[-88.0, -1.0], [-70.0, 1.0], [-64.0, -1.0], [-99.2, -1.0]]:
		var side := Vector2(0, spec[1])
		var p := _builder.wall_point("ApproachObservation", side, 0.75, 0.16)
		p.x = spec[0]
		var smear := _quad("WallResidue", trail, Vector2(1.15, 0.0), false, true)
		smear.position = p
		smear.rotation = Vector3(0, 0.0 if spec[1] < 0 else PI, _rng.randf_range(-0.6, 0.6))


# ⭐ HIDING WORKS: a locker deeply gouged OUTSIDE that held, with tallies scratched INSIDE. Its
# door hangs open now; whoever counted in there is gone. Not a HidingSpot — a lesson, not a tool.
func _build_gouged_cabinet() -> void:
	var base := _builder.wall_point("ApproachObservation", Vector2(0, -1), 0.0, 0.43)
	base.x = -81.2
	var steel := _material(Color(0.3, 0.33, 0.32), 0.5)
	var root := Node3D.new()
	root.name = "GougedCabinet"
	add_child(root)
	root.position = base
	_box("CabinetBack", Vector3(0, 1.03, -0.26), Vector3(0.9, 2.0, 0.04), steel, root)
	_box("CabinetSideL", Vector3(-0.43, 1.03, 0), Vector3(0.04, 2.0, 0.56), steel, root)
	_box("CabinetSideR", Vector3(0.43, 1.03, 0), Vector3(0.04, 2.0, 0.56), steel, root)
	_box("CabinetTop", Vector3(0, 2.05, 0), Vector3(0.9, 0.04, 0.56), steel, root)
	_box("CabinetFloor", Vector3(0, 0.06, 0), Vector3(0.82, 0.04, 0.5), steel, root)
	_box("CabinetShelf", Vector3(0, 1.62, -0.02), Vector3(0.82, 0.03, 0.48), steel, root)
	var inner := _quad("CabinetTallies", load(TEX + "approach_tallies.png"), Vector2(0.4, 0.8), false, false, root)
	inner.position = Vector3(0.18, 1.1, -0.225)
	var hinge := Node3D.new()
	hinge.name = "CabinetDoorHinge"
	root.add_child(hinge)
	# hinged on the EAST side, so a player walking west sees the gouged face first
	hinge.position = Vector3(0.45, 0, 0.29)
	hinge.rotation.y = deg_to_rad(62)
	# P6: the door hangs 0.86 m out into the corridor at body height — it is solid now
	_solid_box("CabinetDoor", Vector3(-0.44, 1.04, 0), Vector3(0.86, 1.96, 0.03), steel, hinge)
	var gouge := _quad("CabinetGouges", load(TEX + "approach_claw_gouge.png"), Vector2(0.62, 0.0), false, true, hinge)
	gouge.position = Vector3(-0.44, 1.25, 0.026)
	# The tallies are on the INSIDE of the door too: it faces the room now it hangs open.
	var door_tally := _quad("DoorTallies", load(TEX + "approach_tallies.png"), Vector2(0.34, 0.68), false, false, hinge)
	door_tally.position = Vector3(-0.44, 1.0, -0.026)
	door_tally.rotation.y = PI
	_solid("CabinetBody", base + Vector3(0, 1.03, 0), Vector3(0.9, 2.0, 0.56))


# ⭐ Bay B's pressure shutter (specced 2026-09-22 and never built): it rolls up, shows a black
# empty recess — nothing is behind it — holds, and rolls down again. Seen through the glass.
func _build_shutter() -> void:
	var cx := -62.4
	var wall := _builder.wall_point("ApproachBayB", Vector2(0, 1), 0.0, 0.1)   # the back wall face line
	var z := wall.z
	# ⭐ PASS 4: the roll stands NICHE_D forward of the back wall, so the "recess" is a real black
	# niche with room for a head in it (it used to be a 3 cm black panel on the wall).
	var f := z - NICHE_D                     # the roll's plane
	_box("ShutterJambL", Vector3(cx - 1.0, 1.25, f - 0.2), Vector3(0.2, 2.5, 0.36), _steel)
	_box("ShutterJambR", Vector3(cx + 1.0, 1.25, f - 0.2), Vector3(0.2, 2.5, 0.36), _steel)
	_box("ShutterDrum", Vector3(cx, 2.62, f - 0.24), Vector3(2.2, 0.34, 0.44), _steel)
	_box("ShutterSill", Vector3(cx, 0.04, f - 0.2), Vector3(2.2, 0.08, 0.36), _dark)
	var black := _material(Color(0.0, 0.0, 0.0), 0.0)
	black.roughness = 1.0
	_box("ShutterRecess", Vector3(cx, 1.22, z - 0.04), Vector3(1.8, 2.34, 0.03), black)
	# the niche's cheeks and head, black, from the back wall to the roll
	var depth := NICHE_D - 0.02
	for side in [-1.0, 1.0]:
		_box("NicheCheek", Vector3(cx + side * 0.915, 1.22, z - 0.05 - depth * 0.5), Vector3(0.03, 2.34, depth), black)
	_box("NicheHead", Vector3(cx, 2.405, z - 0.05 - depth * 0.5), Vector3(1.86, 0.03, depth), black)
	_box("NicheFloor", Vector3(cx, 0.015, z - 0.05 - depth * 0.5), Vector3(1.8, 0.03, depth), black)
	_niche_centre = Vector3(cx, 1.55, z - 0.3)
	_shutter_pivot = Node3D.new()
	_shutter_pivot.name = "ShutterRoll"
	add_child(_shutter_pivot)
	_shutter_pivot.position = Vector3(cx, 2.42, f - 0.22)
	# a PALE painted leaf against the black recess, so rolling it up reads even in a still frame
	# (the first render used dark steel and the closed and open frames looked the same)
	var leaf_paint := _material(Color(0.5, 0.52, 0.48), 0.25)
	_box("ShutterLeaf", Vector3(0, -1.16, 0), Vector3(1.8, 2.32, 0.05), leaf_paint, _shutter_pivot)
	for i in 11:
		# ribs on the ROOM side (-z): this wall faces the corridor through the glass
		_box("ShutterRib", Vector3(0, -0.12 - i * 0.2, -0.035), Vector3(1.78, 0.04, 0.03), _dark, _shutter_pivot)
	_shutter_speaker = _speaker(Vector3(cx, 1.6, f - 0.5), AMBIENCE, -4.0, 5.0, 30.0)
	# ⭐ THE FACE, waiting in the niche from the start, hidden. It stands with its head at ~1.7 m.
	_face = FaceScript.new()
	_face.name = "ApproachShutterFace"
	add_child(_face)
	if not _face.setup(_creature_material(), Vector3(cx, 0.0, z - 0.3)):
		_face.queue_free()
		_face = null


func face_puppet() -> Node3D:
	return _face if is_instance_valid(_face) else null


# ============================================================== Inspection turn (A11)

func _build_inspection() -> void:
	_lamp(Vector3(-97, 2.7, -40), Color(0.56, 0.67, 0.6), 0.7, 8.0, true)
	_lamp(Vector3(-97, 2.7, -30), Color(0.73, 0.48, 0.28), 0.7, 8.0, true)
	_solid_box("ReturnRiser", Vector3(-99.35, 1.5, -35), Vector3(0.6, 3.0, 9.0), _steel)
	# ⚠️ J-capture 3: this was an unlit Label3D reading "CONTAINMENT SERVICES →" — and the arrow
	# pointed the WRONG WAY. Facing this wall (+z), Damaged is on the left (-x is your right).
	var p := _builder.wall_point("ApproachInspectionTurn", Vector2(0, 1), 2.0, 0.18)
	_backed_plate("ServicesSign", TEX + "approach_sign_services.png", p, PI, Vector2(1.3, 0.45), 0.35)
	var wash := OmniLight3D.new()
	wash.light_color = Color(0.7, 0.62, 0.5)
	wash.light_energy = 0.45
	wash.omni_range = 3.2
	add_child(wash)
	wash.position = p + Vector3(0, 0.75, -0.7)


# ============================================================== Damaged (A4)

var _grating_pos := Vector3(-88.0, 0.0, -26.0)

func _build_damaged() -> void:
	# ⚠️ The ceiling is 2.4 m now, and RoomBuilder doorways are full-height holes: without a
	# lintel the taller neighbours would show a strip of void above this room's ceiling.
	_lintel(Vector3(-94, 0, -26), 2.4, 2.36, 3.5)
	_lintel(Vector3(-62, 0, -26), 2.4, 2.36, 5.3)
	# Compression: ducts crowd the low ceiling. The big one along the north side is where the
	# knocks come from; two cross ducts pass over the lane with ~0.3 m above the player's eyes.
	_box("DuctOverhead", Vector3(-78.0, 2.14, -27.55), Vector3(30.6, 0.46, 0.8), _rust)
	for x in [-92.0, -84.0, -76.0, -68.0]:
		_box("DuctBand", Vector3(x, 2.14, -27.55), Vector3(0.1, 0.52, 0.86), _dark)
	for x in [-86.0, -73.5]:
		_box("CrossDuct", Vector3(x, 2.23, -25.6), Vector3(0.7, 0.3, 3.6), _steel)
	_box("SouthPipe", Vector3(-78.0, 2.2, -23.45), Vector3(30.6, 0.16, 0.16), _dark)
	for x in [-90.0, -82.0, -70.0, -65.5]:
		_lamp(Vector3(x, 2.28, -24.3), Color(0.74, 0.48, 0.27), 0.95, 7.0, true)
	for x in [-89.0, -79.5, -71.0]:
		_solid_box("CableDrop", Vector3(x, 1.95, -28.4), Vector3(0.035, 0.8, 0.035), _dark)
	# ⭐ IT HEARS YOU: a loose grating in the lane. Step on it → it clangs → ~2 s → the duct
	# overhead answers with knocks → a scrape moves AWAY AHEAD with dust sifting from the seams.
	# The hunt's own rule (creature_object12.gd:notify_noise), taught with nothing at stake.
	_grating = Node3D.new()
	_grating.name = "LooseGrating"
	add_child(_grating)
	_grating.position = _grating_pos
	_box("GratingPlate", Vector3(0, 0.02, 0), Vector3(1.0, 0.03, 0.8), _steel, _grating)
	for i in 7:
		_box("GratingSlot", Vector3(0, 0.037, -0.33 + i * 0.11), Vector3(0.9, 0.004, 0.035), _dark, _grating)
	# "61 %", on the right-hand wall before the Plenum.
	var p := _builder.wall_point("ApproachDamaged", Vector2(0, 1), 1.5, 0.15)
	p.x = -68.2
	_seal_panel("Seal61", TEX + "approach_seal_61.png", p, PI, 0.5)


# ============================================================== Plenum (A5)

func _build_plenum() -> void:
	# ⚠️ PASS 3: the main duct stops short at x -31.5 with a torn end. Its last section is what fell
	# across the Containment doorway (`_build_collapse`).
	_box("MainVentilationPlenum", Vector3(-46, 4.4, -28.8), Vector3(29.0, 1.05, 3.8), _steel)
	_box("PlenumTornEnd", Vector3(-31.45, 4.2, -28.4), Vector3(0.08, 0.7, 3.0), _torn_metal())
	for x in [-58.0, -49.0, -40.0, -31.0]:
		_receivers.append(Vector3(x, 1.6, -30.6))
		_pressure_vessel(Vector3(x, 0.0, -30.6), 1.0, 3.25)
		_box("PlenumSuspension", Vector3(x, 4.65, -26.5), Vector3(0.1, 1.0, 0.1), _dark)
		_lamp(Vector3(x, 3.25, -24.1), Color(0.66, 0.49, 0.3), 1.0, 9.0, true)
	for x in [-55.0, -40.0]:
		_box("PlenumTray", Vector3(x, 3.7, -23.45), Vector3(13.5, 0.1, 0.45), _dark)
	_housing = _box("PressureReleaseHousing", Vector3(-41, 2.5, -29.4), Vector3(1.0, 0.6, 0.7), _rust)
	_lintel(Vector3(-26, 0, -26), 2.4, 3.36, 5.3)    # Plenum 5.2 over Containment 3.4
	_sign("RECEIVER BANK   /   PRESSURE LOST", Vector3(-44, 2.1, -23.18), PI, 0.008)
	_build_porthole_door()
	_build_technician()
	_build_collapse()
	# The residue that grows from under the door after the scream. A pivot at the door's foot,
	# so it spreads OUT into the room rather than into the wall.
	_residue_growth = Node3D.new()
	_residue_growth.name = "ResidueGrowth"
	add_child(_residue_growth)
	_residue_growth.position = Vector3(PORTHOLE_X, 0.03, -32.86)
	var patch := _floor_decal("GrowingResidue", load(TEX + "approach_residue_pool.png"),
		Vector3(0, 0, 0.7), Vector2(1.65, 0.0), 0.0, _residue_growth)
	(patch.material_override as StandardMaterial3D).roughness = 0.22
	_residue_growth.scale = Vector3(0.12, 1.0, 0.12)


# ⭐ P3 — THE ONLY WAY ON (2026-09-23, capture 3: "you should try to open that door before you are
# able to go to the next part … put some effort to get in … something different [from mashing]").
# The porthole door stands IN its doorway now (it was a picture on a wall). A victim is still heard
# behind it and never seen: the porthole is fogged, and there is no figure, no light change and no
# shadow under the door (the shadow under a door is the Corridor's).
#
# Its locking wheel is missing its handle. The dead technician beside it holds it; fit it, then
# circle the mouse to turn the wheel three times against a drag that drifts back when you stop.
func _build_porthole_door() -> void:
	var z := -33.0
	var root := Node3D.new()
	root.name = "PortholeDoor"
	add_child(root)
	root.position = Vector3(PORTHOLE_X, 0, z)
	var frame := _material(Color(0.1, 0.11, 0.1), 0.4)
	# the frame spans the wall's thickness and stands 5 cm proud of both faces; solid, so the
	# 1.44 m cut is a 1.36 m doorway exactly as wide as the leaf
	_solid_box("PortholeJambL", Vector3(-0.72, 1.2, 0), Vector3(0.12, 2.4, 0.3), frame, root)
	_solid_box("PortholeJambR", Vector3(0.72, 1.2, 0), Vector3(0.12, 2.4, 0.3), frame, root)
	_box("PortholeHead", Vector3(0, 2.46, 0), Vector3(1.56, 0.12, 0.3), frame, root)
	_box("PortholeSill", Vector3(0, 0.015, 0), Vector3(1.44, 0.03, 0.3), frame, root)
	# above the door, the full-height cut is filled up into the Plenum's ceiling
	_lintel(Vector3(PORTHOLE_X, 0, z), 1.44, 2.52, 5.3)
	# THE LEAF, on a hinge at its left jamb. It swings INTO the dark room (+rotation = toward -z).
	_porthole_pivot = Node3D.new()
	_porthole_pivot.name = "PortholePivot"
	root.add_child(_porthole_pivot)
	_porthole_pivot.position = Vector3(-0.68, 0, 0)
	var leaf_mat := _material(Color(0.26, 0.29, 0.27), 0.55)
	var leaf := _solid_box("PortholeLeaf", Vector3(0.68, 1.17, 0), Vector3(1.34, 2.3, 0.1), leaf_mat, _porthole_pivot)
	_box("PortholeKick", Vector3(0.68, 0.2, 0.06), Vector3(1.24, 0.3, 0.02), _dark, _porthole_pivot)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.19
	ring.outer_radius = 0.25
	var rim := MeshInstance3D.new()
	rim.name = "PortholeRim"
	rim.mesh = ring
	rim.material_override = _steel
	_porthole_pivot.add_child(rim)
	rim.position = Vector3(0.68, 1.72, 0.06)
	rim.rotation.x = PI / 2.0
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.02
	var fog := StandardMaterial3D.new()
	fog.albedo_texture = load(TEX + "approach_porthole_fog.png")
	fog.roughness = 0.2
	fog.metallic_specular = 0.8
	var glass := MeshInstance3D.new()
	glass.name = "PortholeFog"
	glass.mesh = disc
	glass.material_override = fog
	_porthole_pivot.add_child(glass)
	glass.position = Vector3(0.68, 1.72, 0.055)
	glass.rotation.x = PI / 2.0
	# the locking bars: from the wheel's hub out into both jambs. They slide in when it unlocks.
	for side in [-1.0, 1.0]:
		var bar := _box("PortholeBolt", Vector3(0.68 + side * 0.46, 1.05, 0.075), Vector3(0.62, 0.07, 0.05), _steel, _porthole_pivot)
		_bolts.append([bar, side])
		_box("BoltGuide", Vector3(0.68 + side * 0.52, 1.05, 0.065), Vector3(0.1, 0.13, 0.05), _dark, _porthole_pivot)
	# ⭐ PASS 4: A BARE SPINDLE. The door's valve wheel is gone; the technician across the Plenum holds
	# it to his chest. A square steel shaft stands out of a collar on the leaf, where the bolts meet:
	# the visible "something is missing". E with the wheel carried seats it here (`_wheel` shown).
	var collar := _cylinder("WheelSpindleCollar", Vector3(0.68, 1.05, 0.075), 0.045, 0.05, _dark, _porthole_pivot)
	collar.rotation.x = PI / 2.0
	_box("WheelSpindle", Vector3(0.68, 1.05, 0.14), Vector3(0.028, 0.028, 0.13), _steel, _porthole_pivot)
	_wheel = Node3D.new()
	_wheel.name = "PortholeWheel"
	_porthole_pivot.add_child(_wheel)
	_wheel.position = Vector3(0.68, 1.05, 0.17)
	_build_valve_wheel(_wheel)
	_wheel.visible = false
	_proxy("PortholeWheelInteract", Vector3(PORTHOLE_X + 0.0, 1.05, z + 0.26), Vector3(0.66, 0.66, 0.2),
		_on_wheel_interact, func() -> bool: return not porthole_open, _wheel_prompt)
	# ⚠️ THIS LAMP CASTS SHADOWS, unlike the approach's other lamps (only the technician's fill and the
	# spark light also do). Without them a 6 m omni over the door lit the dark room THROUGH the wall. A spot aimed away from the
	# wall missed the technician in the corner, whose eyes have to be seen. A wall lamp lighting its
	# own side of the wall is what a real one does.
	var lamp := OmniLight3D.new()
	lamp.name = "PortholeDoorLamp"
	lamp.light_color = Color(0.7, 0.6, 0.42)
	lamp.light_energy = 0.9
	lamp.omni_range = 6.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.position = Vector3(PORTHOLE_X, 2.85, z + 0.4)
	var fit_mat := _indicator.duplicate() as StandardMaterial3D
	_box("EmergencyFitting", Vector3(PORTHOLE_X, 2.98, z + 0.33), Vector3(0.65, 0.07, 0.19), fit_mat)
	var spot := lamp
	_door_lamp = {"light": spot, "mat": fit_mat}
	_light_on(_door_lamp, true)


# ⭐ THE FUSED TECHNICIAN (pass 4; he was slumped by the door in pass 3). The user: *"This looks way
# too unrealistic - should it look like a weird creature itself … And it looks very 2d now"* and *"it
# should probably be in the other part of that room - what for to keep the handle just besides the
# door"*. So he is grown INTO the Plenum's east wall, and he holds the porthole door's valve wheel
# (*"I do not see the wheel very clearly in its arms … make it more realistic and even more adjacent to
# the wall"*).
# ⭐ 2026-09-24: THE USER'S OWN ART. The user generated the relief (flux, `…/approach/user/`, variant D
# chosen): a realistic dead technician pressed into the wall, roots over and round him, everything below
# the waist swallowed, eyes closed, both painted hands curled in an EMPTY grip at his chest and belly.
# - ONE relief, flush on the wall (`TECH_RELIEF_Z` 4.5 cm, over the roots decal at 2.2 cm), life size:
#   his head (ears included) is 0.161 of the art's width, so `TECH_W` 1.30 m makes it 0.21 m, with his
#   eyes at `TECH_FACE_Y` 1.55 m. The swallowed body and the root spray are PAINTED, so there is no 3D
#   mass: the 56-lump sphere mound, the 3D arms and the sleeves are gone (the user called the spheres
#   unrealistic). A few thin 3D tendrils lap over the relief's edges and run down to the floor.
# - THE WHEEL is the only 3D part of him: the steel valve wheel pressed nearly flush to his chest
#   (`TECH_WHEEL_OFF` 4 cm off the relief), its rim passing through both painted fists
#   (`TECH_ART_GRIPS_UV`), so the painted fingers grip it. Taken, it vanishes and leaves his hands
#   curled round nothing.
# - A caged lamp above him rakes down across a normal map derived from the art.
# Taking it keeps pass 3's sequence: the grip, the eyes OPEN (the pair differs only at the eyes), a
# close hoarse whisper — "don't… go in there…" — then the eyes close for good. Once.
func _build_technician() -> void:
	var root := Node3D.new()
	root.name = "DeadTechnician"
	add_child(root)
	# on the east wall face, facing into the room (-x); local +x runs along the wall toward +z (the
	# viewer's right); y up; z out of the wall
	root.position = Vector3(TECH_WALL_X - 0.1, 0, TECH_Z)
	root.rotation.y = -PI / 2.0
	_tech_tex_closed = load(TEX + "approach_fused_closed.png")
	_tech_tex_open = load(TEX + "approach_fused_open.png")
	# ⭐ 2026-09-24 (the user: "a man holding a wheel looks very two D. Can we make it more three D?"):
	# a BAS-RELIEF MESH, displaced out of the wall by the art's height map, not a flat quad
	var relief := _build_relief_mesh()
	relief.name = "TechnicianBody"
	root.add_child(relief)
	relief.position = Vector3(0, _tech_art_top() - TECH_W * 0.5, 0)
	_tech_mat = relief.material_override as StandardMaterial3D
	_tech_head = root.to_global(_tech_uv(TECH_ART_EYES_UV, TECH_RELIEF_Z + _tech_height_at(TECH_ART_EYES_UV) + 0.03))
	var flesh := _growth_mat(Color(1.0, 0.92, 0.92))
	var deep := _growth_mat(Color(0.6, 0.52, 0.56))
	# 1. the SPREAD: the veins across the tiles behind him (the user's art, keyed and faded radially),
	# alpha-BLENDED so they thin away into the wall; the relief, drawn opaque in front, occludes it
	var spread := _quad("GrowthSpread", load(TEX + "approach_growth_spread.png"), Vector2(TECH_SPREAD_W, TECH_SPREAD_W), false, true, root)
	spread.position = Vector3(0.0, 0.03 + TECH_SPREAD_W * 0.5, 0.022)     # its bottom edge 3 cm above the floor
	var smat := spread.material_override as StandardMaterial3D
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.roughness = 0.5
	smat.metallic_specular = 0.55
	# 2. THREE thin 3D tendrils out of the swallowed body at the relief's foot, lying ON the wall and
	# curving down it to the floor: they lap over the relief's bottom edge and carry the growth to the
	# floor. (The first build also ran them out across the floor and laid short ones over the side edges:
	# they stood off the wall like spider legs and black sticks, so they are gone.)
	for spec in [[0.44, 0.035, 0.4, 0.8], [0.52, -0.045, 2.1, 1.0], [0.6, 0.05, 4.0, 0.9]]:
		_wall_tendril(root, _tech_uv(Vector2(spec[0], 0.88), 0.0), float(spec[1]), float(spec[2]), float(spec[3]), flesh)
	# 3. THE WHEEL, flush to his chest, its rim through both painted fists
	_tech_wheel = Node3D.new()
	_tech_wheel.name = "TechnicianWheel"
	root.add_child(_tech_wheel)
	_tech_wheel.position = _tech_wheel_centre()
	_tech_wheel.rotation.z = 0.2
	_build_valve_wheel(_tech_wheel)
	# 4. HIS LIGHT: a small caged lamp on the wall above him, raking down over the relief and catching
	# the wheel's bare steel, shadowed so the wall keeps it on his side
	var lamp_at := Vector3(0.0, _tech_art_top() + 0.14, 0.34)
	var cage := _material(Color(0.06, 0.06, 0.055), 0.6)
	_box("TechLampBracket", lamp_at + Vector3(0, 0.03, -0.18), Vector3(0.04, 0.04, 0.36), cage, root)
	for k in 4:
		var bar := _box("TechLampCage", lamp_at + Vector3(cos(k * PI / 2.0) * 0.045, -0.03, sin(k * PI / 2.0) * 0.045),
			Vector3(0.008, 0.09, 0.008), cage, root)
		bar.name = "TechLampCage"
	var bulb_mat := _material(Color(0.07, 0.06, 0.05), 0.0)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.8, 0.55)
	bulb_mat.emission_energy_multiplier = 0.85
	var bulb := MeshInstance3D.new()
	bulb.name = "TechLampBulb"
	var bm := SphereMesh.new()
	bm.radius = 0.028
	bm.height = 0.06
	bulb.mesh = bm
	bulb.material_override = bulb_mat
	root.add_child(bulb)
	bulb.position = lamp_at + Vector3(0, -0.04, 0)
	var spot := SpotLight3D.new()
	spot.name = "TechnicianLamp"
	spot.light_color = Color(0.95, 0.8, 0.6)
	spot.light_energy = TECH_LAMP_ENERGY
	spot.spot_range = 3.4
	spot.spot_angle = 44.0
	spot.spot_attenuation = 0.9
	spot.shadow_enabled = true
	root.add_child(spot)
	spot.position = lamp_at + Vector3(0, -0.06, 0.05)
	# aimed down across his face to his chest: the lamp is 0.34 m out on its bracket, so the light
	# rakes down the relief and the normal map models the brow, the cheekbones and the folds
	spot.look_at(root.to_global(_tech_uv(Vector2(0.5, 0.55), 0.05)), Vector3.UP)
	# a faint cool fill from the room so the lamp's shadows are not pure black
	var fill := OmniLight3D.new()
	fill.name = "TechnicianFill"
	fill.light_color = Color(0.55, 0.62, 0.6)
	fill.light_energy = 0.25
	fill.omni_range = 3.0
	fill.shadow_enabled = true
	add_child(fill)
	fill.global_position = root.to_global(Vector3(0.3, 1.2, 1.6))
	# P6: he is solid, a thin slab from the floor (the growth that swallowed his legs) to his head
	_collide(root, Vector3(1.0, 1.85, 0.24), Vector3(0.0, 0.925, 0.12))
	# E anywhere on him (face, body, the wheel) takes the wheel; larger than the solid box
	_proxy("TechnicianInteract", Vector3(0.0, 1.1, 0.25), Vector3(0.95, 1.6, 0.45),
		_on_technician_interact, _technician_can, func() -> String: return "E — take the wheel", root)


# ⭐ THE BAS-RELIEF. A grid of TECH_MESH_N² cells over the art, each vertex pushed out of the wall by
# `approach_fused_height.png` (tools/make_breach_pass4_art.py: the body inflated from measured capsules
# so the head, chest, arms and fists are round, ~13–17 cm proud; the growth 1–4 cm; a luminance detail
# term; no cliffs). The height is 16-bit in R/G; B is the alpha dilated by 5 px, and a cell is only built
# if one of its corners is under it, so the empty backdrop costs no triangles. Normals come from the
# height grid; the normal map carries the detail finer than the grid. Alpha scissor gives the silhouette,
# and it casts shadows: the lamp above throws the head, the fists and the wheel onto his body and the wall.
func _build_relief_mesh() -> MeshInstance3D:
	var himg: Image = (load(TEX + "approach_fused_height.png") as Texture2D).get_image()
	if himg.is_compressed():
		himg.decompress()
	var n := TECH_MESH_N
	var w := himg.get_width()
	var hh := himg.get_height()
	_tech_heights = PackedFloat32Array()
	_tech_heights.resize((n + 1) * (n + 1))
	var cover := PackedByteArray()
	cover.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var c := himg.get_pixel(mini(w - 1, int(float(i) / n * w)), mini(hh - 1, int(float(j) / n * hh)))
			var v16 := c.r8 * 256 + c.g8
			_tech_heights[j * (n + 1) + i] = float(v16) / 65535.0 * TECH_RELIEF_DEPTH
			cover[j * (n + 1) + i] = 1 if c.b8 > 10 else 0
	var dx := TECH_W / n
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n + 1:
		for i in n + 1:
			var hc := _tech_heights[j * (n + 1) + i]
			var hl := _tech_heights[j * (n + 1) + maxi(i - 1, 0)]
			var hr := _tech_heights[j * (n + 1) + mini(i + 1, n)]
			var hu := _tech_heights[maxi(j - 1, 0) * (n + 1) + i]
			var hd := _tech_heights[mini(j + 1, n) * (n + 1) + i]
			# y is up and j runs down the image, so d(height)/d(y) = (hu - hd) / 2dx
			var nrm := Vector3(-(hr - hl) / (2.0 * dx), -(hu - hd) / (2.0 * dx), 1.0).normalized()
			st.set_normal(nrm)
			st.set_uv(Vector2(float(i) / n, float(j) / n))
			st.add_vertex(Vector3((float(i) / n - 0.5) * TECH_W, (0.5 - float(j) / n) * TECH_W, TECH_RELIEF_Z + hc))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			if cover[a] + cover[b] + cover[c] + cover[d] == 0:
				continue
			# clockwise seen from the front (+z): Godot's front face
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tech_tex_closed
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.6
	var nrm_tex: Texture2D = load(TEX + "approach_fused_normal.png")
	if nrm_tex:
		m.normal_enabled = true
		m.normal_texture = nrm_tex
		m.normal_scale = 0.7
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# The relief's height (m, off its base) at an art UV, from the vertex grid (bilinear).
func _tech_height_at(uv: Vector2) -> float:
	var n := TECH_MESH_N
	if _tech_heights.size() != (n + 1) * (n + 1):
		return 0.0
	var fx := clampf(uv.x, 0.0, 1.0) * n
	var fy := clampf(uv.y, 0.0, 1.0) * n
	var i := mini(int(fx), n - 1)
	var j := mini(int(fy), n - 1)
	var tx := fx - i
	var ty := fy - j
	var h00 := _tech_heights[j * (n + 1) + i]
	var h10 := _tech_heights[j * (n + 1) + i + 1]
	var h01 := _tech_heights[(j + 1) * (n + 1) + i]
	var h11 := _tech_heights[(j + 1) * (n + 1) + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)


# The same, from a point in the technician's space.
func _tech_height_local(x: float, y: float) -> float:
	return _tech_height_at(Vector2(x / TECH_W + 0.5, (_tech_art_top() - y) / TECH_W))


# A thin tendril from `from` (on the relief) down the wall to the floor, swaying `sway` m side to side,
# tapering from 0.02 m to 0.006 m. In front of the relief it lies just proud of it; below the relief's
# foot it lies on the wall; it ends touching the floor.
func _wall_tendril(parent: Node3D, from: Vector3, sway: float, phase: float, reach: float, mat: Material) -> void:
	const SEGS := 10
	var bottom := _tech_art_top() - TECH_W
	var prev := Vector3.ZERO
	for i in SEGS + 1:
		var t := float(i) / SEGS
		var y := lerpf(from.y, 0.012, t * reach + (1.0 - reach) * t * t)
		var r := lerpf(0.02, 0.006, t)
		var x := from.x + sway * sin(t * PI * 1.3 + phase) - sway * sin(phase)
		# over the relief it lies ON the displaced surface; below its foot, on the wall
		var z := TECH_RELIEF_Z + _tech_height_local(x, y) + r * 0.7 if y > bottom + 0.02 else r + 0.004
		var p := Vector3(x, y, z)
		if i > 0:
			_limb(parent, prev, p, r, mat, "GrowthTendril")
		prev = p


# The relief's top edge in the technician's space: his eyes (`TECH_ART_EYES_UV`) sit at TECH_FACE_Y.
func _tech_art_top() -> float:
	return TECH_FACE_Y + TECH_ART_EYES_UV.y * TECH_W


# A point on the relief, from the art's UV (0..1, y down), `z` off the wall.
func _tech_uv(uv: Vector2, z: float) -> Vector3:
	return Vector3((uv.x - 0.5) * TECH_W, _tech_art_top() - uv.y * TECH_W, z)


# The wheel's centre: on the circle of radius VALVE_R through both painted fists, on the side toward his
# left shoulder (up and to the viewer's right), `TECH_WHEEL_OFF` off the relief.
func _tech_wheel_centre() -> Vector3:
	var g1 := _tech_uv(TECH_ART_GRIPS_UV[0], 0.0)
	var g2 := _tech_uv(TECH_ART_GRIPS_UV[1], 0.0)
	var m := Vector2((g1.x + g2.x) * 0.5, (g1.y + g2.y) * 0.5)
	var ch := Vector2(g2.x - g1.x, g2.y - g1.y)
	var perp := Vector2(-ch.y, ch.x).normalized()
	var t := sqrt(maxf(0.0, VALVE_R * VALVE_R - ch.length_squared() * 0.25))
	var c := m + perp * t
	# ⭐ AT THE HANDS' DISPLACED DEPTH, not the wall's: the rim's tube is centred at the fists' surface,
	# so it sinks into the curl of each painted fist (the fingers close over it) — but never into the
	# chest: the plane is also kept a tube's width clear of the highest point under the wheel's disc.
	var hands := maxf(_tech_height_at(TECH_ART_GRIPS_UV[0]), _tech_height_at(TECH_ART_GRIPS_UV[1]))
	var disc := 0.0
	for k in 25:
		var a := TAU * k / 25.0
		for rr in [0.0, 0.45, 0.8]:
			var q: Vector2 = c + Vector2(cos(a), sin(a)) * VALVE_R * float(rr)
			disc = maxf(disc, _tech_height_local(q.x, q.y))
	return Vector3(c.x, c.y, TECH_RELIEF_Z + maxf(hands + TECH_WHEEL_OFF, disc + 0.016))


# THE VALVE WHEEL, the porthole door's missing part: a bare-steel rim, five spokes, a hub with a
# square socket (the door's spindle seats in it) and a spinner knob on the rim. Built in the XY plane,
# facing +z. The same model on the door and in his arms. Bright, worn steel, never emissive: it reads
# because the lamp above him catches it.
func _build_valve_wheel(parent: Node3D) -> void:
	# (metallic 0.55, not 0.85: a mirror-metal rim reflects the dark room and read as dark grey in the
	# renders; the lamp has to be able to catch it)
	var steel := _material(Color(0.74, 0.74, 0.7), 0.55)
	steel.roughness = 0.34
	var rim := MeshInstance3D.new()
	rim.name = "WheelRim"
	var ring := TorusMesh.new()
	ring.inner_radius = VALVE_R - 0.013
	ring.outer_radius = VALVE_R + 0.013
	ring.rings = 40
	ring.ring_segments = 14
	rim.mesh = ring
	rim.material_override = steel
	parent.add_child(rim)
	rim.rotation.x = PI / 2.0
	for k in 5:
		var a := TAU * k / 5.0 + PI / 2.0
		var spoke := _limb(parent, Vector3(cos(a), sin(a), 0.0) * 0.028, Vector3(cos(a), sin(a), 0.0) * (VALVE_R - 0.01),
			0.0085, steel, "WheelSpoke")
		spoke.name = "WheelSpoke"
	var hub := _cylinder("WheelHub", Vector3(0, 0, 0.0), 0.032, 0.05, steel, parent)
	hub.rotation.x = PI / 2.0
	_box("WheelSocket", Vector3(0, 0, 0.026), Vector3(0.02, 0.02, 0.004), _dark, parent)
	var knob := _cylinder("WheelKnob", Vector3(VALVE_R * 0.9, 0, 0.035), 0.011, 0.055, _dark, parent)
	knob.rotation.x = PI / 2.0


# Object 12's growth: a tangle of wet tendrils (`approach_growth_flesh.png`, tools/make_breach_pass4_art.py)
# at a fixed WORLD scale, so a flattened lump and a thin vine carry the same size of strand. Matte-wet:
# the first build's roughness 0.26 turned every sphere into black plastic with one hot highlight.
# `tint` multiplies the texture (near white = as drawn). Never emissive.
func _growth_mat(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + "approach_growth_flesh.png")
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(2.2, -2.2, 2.2)
	m.roughness = 0.5
	m.metallic_specular = 0.55
	return m


# A vine lying on the wall: a chain of `SEGS` capsules from `from`, heading along `dir` (in the wall's
# x/y plane, unless `dir3` gives a 3D heading), bending a little at every joint and tapering to a point.
# It stays within a few centimetres of the wall (and of the floor, once it reaches it).
func _vine(parent: Node3D, from: Vector3, dir: Vector2, length: float, r0: float, mat: Material, dir3 := Vector3.ZERO,
		min_z := 0.015) -> void:
	const SEGS := 5
	var a := from
	var heading := dir3.normalized() if dir3 != Vector3.ZERO else Vector3(dir.x, dir.y, 0.0).normalized()
	for i in SEGS:
		var bend := _rng.randf_range(-0.45, 0.45)
		heading = heading.rotated(Vector3(0, 0, 1), bend).normalized() if dir3 == Vector3.ZERO else heading
		var b := a + heading * (length / SEGS)
		if dir3 == Vector3.ZERO:
			b.z = maxf(min_z, r0 * 0.5)
			if b.y < 0.02:
				# on the floor now: run out along it, away from the wall
				b.y = r0 * 0.5
				b.z = a.z + length / SEGS * 0.8
		var r := r0 * (1.0 - float(i) / SEGS * 0.75)
		_limb(parent, a, b, r, mat, "GrowthTendril")
		a = b


# A capsule from `a` to `b` in `parent`'s space: a limb, a tendril, a finger.
func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, label: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(a.distance_to(b) + r * 2.0, r * 2.2)
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi, true)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var up := Vector3(0, 1, 0)
	if absf(dir.dot(up)) > 0.999:
		mi.basis = Basis.IDENTITY if dir.y > 0 else Basis(Vector3(1, 0, 0), PI)
	else:
		var axis := up.cross(dir).normalized()
		mi.basis = Basis(axis, acos(clampf(up.dot(dir), -1.0, 1.0)))
	return mi


# ⚠️ THE PLENUM'S DOORWAY TO CONTAINMENT IS COLLAPSED (P3). The main duct's last section fell across
# it, with its flange, a snapped hanger and a spill of sheet metal and grit. It stays cut in the
# wall (DOORS) so the collapse has a hole to fill; the collider fills it completely.
func _build_collapse() -> void:
	var rust := _rust
	var root := Node3D.new()
	root.name = "CollapsedDuctSeal"
	add_child(root)
	root.position = Vector3(-26, 0, -26)
	# the fallen section: 3.2 m of duct lying diagonally across the opening, one end on the floor
	# of the Plenum, the other jammed up against the lintel
	var duct := _box("FallenDuct", Vector3(-0.7, 1.45, 0.0), Vector3(3.3, 0.95, 0.95), rust, root)
	duct.rotation = Vector3(0.12, 0.28, deg_to_rad(-38))
	var duct2 := _box("FallenDuctB", Vector3(-1.1, 0.5, -0.55), Vector3(2.4, 0.8, 0.8), _steel, root)
	duct2.rotation = Vector3(0.0, -0.5, deg_to_rad(8))
	_box("FallenFlange", Vector3(0.05, 2.55, 0.1), Vector3(0.12, 1.1, 1.1), _dark, root).rotation.z = 0.6
	var torn := _torn_metal()
	for spec in [[Vector3(-0.2, 0.9, 0.9), 0.6], [Vector3(-0.4, 1.9, -0.95), -0.9], [Vector3(-1.8, 0.2, 0.7), 1.3]]:
		var sheet := _box("BentSheet", spec[0], Vector3(1.1, 0.012, 0.7), torn, root)
		sheet.rotation = Vector3(spec[1], spec[1] * 0.5, 0.4)
	var hanger := _box("SnappedHanger", Vector3(-1.5, 3.9, 0.3), Vector3(0.08, 1.8, 0.08), _dark, root)
	hanger.rotation.z = 0.25
	for k in 14:
		var chunk := _box("CollapseGrit", Vector3(-_rng.randf_range(0.2, 2.2), 0.05, _rng.randf_range(-1.1, 1.1)),
			Vector3(_rng.randf_range(0.08, 0.25), _rng.randf_range(0.04, 0.12), _rng.randf_range(0.08, 0.2)), _dark, root)
		chunk.rotation.y = _rng.randf() * TAU
	for k in 3:
		var cable := _box("CollapseCable", Vector3(-0.3 - k * 0.5, 2.6, -0.4 + k * 0.4), Vector3(0.03, 1.3, 0.03), _dark, root)
		cable.rotation.z = 0.2 * (k - 1)
	# a duct reads as a duct by its flanges and its hollow end, not as a box (Issue 35)
	for d in [[duct, 3.3, 0.95], [duct2, 2.4, 0.8]]:
		var body: MeshInstance3D = d[0]
		var half: float = float(d[1]) * 0.5
		var w: float = d[2]
		for sx in [-1.0, 1.0]:
			for spec in [[Vector3(0, w * 0.5 + 0.03, 0), Vector3(0.06, 0.06, w + 0.12)], [Vector3(0, -w * 0.5 - 0.03, 0), Vector3(0.06, 0.06, w + 0.12)],
					[Vector3(0, 0, w * 0.5 + 0.03), Vector3(0.06, w + 0.12, 0.06)], [Vector3(0, 0, -w * 0.5 - 0.03), Vector3(0.06, w + 0.12, 0.06)]]:
				_box("DuctFlange", Vector3(sx * half, 0, 0) + spec[0], spec[1], _dark, body)
		_box("DuctMouth", Vector3(-half - 0.005, 0, 0), Vector3(0.01, w - 0.06, w - 0.06), _material(Color(0, 0, 0), 0.0), body)
	# on the Containment side, a buckled steel panel torn off the plenum's casing is jammed into the
	# opening: the first render saw straight through a gap beside the ducts
	var panel := Node3D.new()
	panel.name = "BuckledPanel"
	root.add_child(panel)
	panel.position = Vector3(0.22, 0, 0.0)
	var torn_panel := _material(Color(0.3, 0.3, 0.28), 0.4)
	for spec in [[Vector3(0, 0.65, -0.35), Vector3(0.05, 1.3, 1.5), Vector3(0.0, 0.18, 0.05)],
			[Vector3(0.03, 1.85, 0.2), Vector3(0.05, 1.2, 1.9), Vector3(0.0, -0.22, -0.08)],
			[Vector3(-0.02, 2.75, -0.4), Vector3(0.05, 0.7, 1.4), Vector3(0.0, 0.3, 0.12)]]:
		var sheet := _box("BuckledSheet", spec[0], spec[1], torn_panel, panel)
		sheet.rotation = spec[2]
	for k in 5:
		_box("PanelRivet", Vector3(0.06, 0.4 + k * 0.5, -0.9 + k * 0.4), Vector3(0.02, 0.04, 0.04), _dark, panel)
	# ⚠️ SOLID: the whole opening, both sides, plus the duct where it lies in the Plenum
	_solid("CollapsedDuctSealSolid", Vector3(-26, 1.68, -26), Vector3(0.4, 3.36, 2.44))
	_collide(duct, Vector3(3.3, 0.95, 0.95))
	_collide(duct2, Vector3(2.4, 0.8, 0.8))


# ============================================================== Containment (A6)

func _build_containment() -> void:
	var organic := RoomBuilder.make_material("res://assets/textures/level_6_breach/breach_wall_organic.png",
		Vector3(0.4, 0.4, 0.4), Color(0.2, 0.16, 0.08))
	for x in [-21.0, -5.0]:
		_solid_box("ContainmentWallDamage", Vector3(x, 1.5, -28.78), Vector3(5.2, 2.6, 0.12), organic)
	# ⚠️ The east lamp is short-range on purpose: approach lamps cast no shadows, so at 7.5 m it
	# lit the Threshold duct's end cap THROUGH the wall into a red panel (second render).
	for spec in [[-21.0, 7.5], [-13.0, 7.5], [-7.5, 5.5]]:
		_containment_lamps.append(_lamp(Vector3(spec[0], 2.5, -24.05), Color(0.7, 0.38, 0.22), 0.65, spec[1], true))
	for x in [-21.0, -13.0, -5.0]:
		_box("DamagedCableTray", Vector3(x, 2.8, -28.0), Vector3(6.7, 0.15, 0.5), _rust)
	# The chamber doorway: a head turns the full-height opening into a doorway. ⚠️ PASS 3: the bent
	# outward leaf, its punched plate and its seam are GONE — the cell is the shared glass tank now
	# (ContainmentCell, breached), standing in the chamber this doorway leads out of. What is left is
	# the frame of a security door that was torn away: its head, its jambs and one hinge stub.
	var dz := -29.0
	var steel := _material(Color(0.24, 0.26, 0.25), 0.6)
	_box("CellDoorHead", Vector3(-13.5, 2.85, dz), Vector3(1.7, 1.1, 0.26), steel)
	_solid_box("CellJambL", Vector3(-14.34, 1.15, dz), Vector3(0.08, 2.3, 0.26), _dark)
	_solid_box("CellJambR", Vector3(-12.66, 1.15, dz), Vector3(0.08, 2.3, 0.26), _dark)
	var stub := _box("TornHingeStub", Vector3(-14.26, 0.35, dz + 0.16), Vector3(0.05, 0.14, 0.12), _torn_metal())
	stub.rotation.x = 0.5
	var stub2 := _box("TornHingeStub", Vector3(-14.26, 1.9, dz + 0.16), Vector3(0.05, 0.14, 0.12), _torn_metal())
	stub2.rotation.x = -0.4
	# OBJECT 12, stencilled beside the door, and the dead seal panel facing it.
	var st := _builder.wall_point("ApproachContainment", Vector2(0, -1), 1.75, 0.16)
	st.x = -9.05
	var stencil := _quad("Object12Stencil", load(TEX + "approach_stencil_object12.png"), Vector2(1.8, 0.63), false, true)
	stencil.position = st
	var dead := _builder.wall_point("ApproachContainment", Vector2(0, 1), 1.6, 0.15)
	dead.x = -13.5
	_seal_panel("SealDead", TEX + "approach_seal_dead.png", dead, PI, 0.06)
	# Finger drags along both walls at crown height, leading out toward the threshold.
	var drags := load(TEX + "approach_finger_drags.png")
	# clear of the cell door, the stencil, the organic damage panel (x -7.6..-2.4) and the
	# Threshold doorway (x -1.2..1.2)
	for spec in [[-10.6, -1.0], [-7.2, 1.0], [-1.5, -1.0], [-2.6, 1.0]]:
		var p := _builder.wall_point("ApproachContainment", Vector2(0, spec[1]), 2.6, 0.16)
		p.x = spec[0]
		var q := _quad("FingerDrags", drags, Vector2(0.62, 0.0), false, true)
		q.position = p
		q.rotation = Vector3(0, 0.0 if spec[1] < 0 else PI, PI / 2.0 + _rng.randf_range(-0.08, 0.08))
	# Floor drag marks from the cell toward the hunt wing.
	var drag := load(TEX + "approach_drag_smear.png")
	var marks := [[-12.6, -27.6, 0.35], [-9.0, -26.9, 0.2], [-5.4, -26.2, 0.15], [-1.9, -25.4, 0.6],
		[0.2, -21.5, 1.45], [0.5, -17.2, 1.6]]
	for i in marks.size():
		var m: Array = marks[i]
		_floor_decal("DragMarks", drag, Vector3(m[0], 0.026 + i * 0.002, m[1]), Vector2(2.2, 0.0), m[2])
	_build_dark_room()
	_build_passage()
	_build_cell_chamber()
	_build_ceiling_drop()


# ============================================================== the ceiling drop (pass 4)

# ⭐ THE WALK-IN'S ONE SUDDEN SCARE (the user: *"there should be at least one place where the element
# of unexpectedness and suddenness will make the player scared … besides this hand"*). Where the user
# paused in Containment, a service duct runs under the ceiling beside the lane. As the player walks
# east past x DROP_TRIGGER_X, its hatch bursts open. The DRAGGED TECHNICIAN'S BODY drops out on a chain,
# upside down by the ankles, ~2.3 m ahead and 1.2 m to the side, with a crash, and the lamp beside it
# flickers. It swings and twists, then settles. It pays off the drag heard behind the porthole door.
# - Triggered by POSITION, never by gaze, so it is actually sudden. Once per run.
# - No panic, no creature, and it hangs clear of the lane.
# - ⚠️ 3D, not flat art (the user rejected "very 2d"). A body cocooned in Object 12's membrane, built
#   from capsules, with one bare arm hanging out.
func _build_ceiling_drop() -> void:
	var duct := _material(Color(0.2, 0.21, 0.2), 0.55)
	var x0 := -9.3
	var x1 := -4.5
	var zc := DROP_PIVOT.z
	var y0 := DROP_PIVOT.y
	var y1 := 3.34
	var xc := (x0 + x1) * 0.5
	var hx := DROP_PIVOT.x
	# the duct, from parts, with a real hole in its underside where the hatch is
	_box("DropDuctSideN", Vector3(xc, (y0 + y1) * 0.5, zc - 0.4), Vector3(x1 - x0, y1 - y0, 0.04), duct)
	_box("DropDuctSideS", Vector3(xc, (y0 + y1) * 0.5, zc + 0.4), Vector3(x1 - x0, y1 - y0, 0.04), duct)
	_box("DropDuctBottomW", Vector3((x0 + hx - 0.4) * 0.5, y0, zc), Vector3((hx - 0.4) - x0, 0.04, 0.84), duct)
	_box("DropDuctBottomE", Vector3((hx + 0.4 + x1) * 0.5, y0, zc), Vector3(x1 - (hx + 0.4), 0.04, 0.84), duct)
	for x in [x0, x1]:
		_box("DropDuctCap", Vector3(x, (y0 + y1) * 0.5, zc), Vector3(0.04, y1 - y0, 0.84), duct)
	for x in [-8.6, -5.2]:
		_box("DropDuctHanger", Vector3(x, y1 - 0.02, zc), Vector3(0.9, 0.04, 0.05), _dark)
	# the hatch, hinged on its west edge, flush and shut until the drop
	_drop_hatch = Node3D.new()
	_drop_hatch.name = "DropHatch"
	add_child(_drop_hatch)
	_drop_hatch.position = Vector3(hx - 0.4, y0, zc)
	_box("DropHatchPanel", Vector3(0.4, -0.01, 0), Vector3(0.78, 0.035, 0.78), duct, _drop_hatch)
	for k in 3:
		_box("DropHatchSlat", Vector3(0.14 + k * 0.26, -0.03, 0), Vector3(0.03, 0.02, 0.7), _dark, _drop_hatch)
	# the rig: pivot at the hatch; the body hangs below it and is hidden until it falls
	_drop_rig = Node3D.new()
	_drop_rig.name = "CeilingDrop"
	add_child(_drop_rig)
	_drop_rig.position = DROP_PIVOT
	_drop_body = Node3D.new()
	_drop_body.name = "CocoonedVictim"
	_drop_rig.add_child(_drop_body)
	var chain := _material(Color(0.24, 0.23, 0.21), 0.9)
	chain.roughness = 0.4
	for k in 5:
		var link := MeshInstance3D.new()
		link.name = "ChainLink"
		var t := TorusMesh.new()
		t.inner_radius = 0.022
		t.outer_radius = 0.034
		link.mesh = t
		link.material_override = chain
		_drop_body.add_child(link)
		link.position = Vector3(0, -0.05 - k * 0.055, 0)
		link.rotation = Vector3(PI / 2.0, 0.0, 0.0) if k % 2 == 0 else Vector3(PI / 2.0, PI / 2.0, 0.0)
	var membrane := _growth_mat(Color(1.0, 0.9, 0.86))
	var dark_membrane := _growth_mat(Color(0.55, 0.48, 0.52))
	# upside down: ankles at the top, head at the bottom
	_limb(_drop_body, Vector3(-0.05, -0.32, 0.0), Vector3(0.05, -0.32, 0.0), 0.075, dark_membrane, "CocoonAnkles")
	_limb(_drop_body, Vector3(0.0, -0.36, 0.0), Vector3(0.0, -1.05, 0.02), 0.155, membrane, "CocoonLegs")
	_limb(_drop_body, Vector3(0.0, -1.0, 0.02), Vector3(0.0, -1.62, 0.0), 0.205, membrane, "CocoonTorso")
	_limb(_drop_body, Vector3(0.0, -1.64, 0.02), Vector3(0.0, -1.84, 0.04), 0.125, dark_membrane, "CocoonHead")
	# the body's shape under the wrap: shoulders at the bottom (it hangs head-down), a narrower waist,
	# knees — so the cocoon reads as a PERSON bound up, not a capsule (the first render: a bronze buoy)
	for spec in [[Vector3(-0.19, -1.5, 0.02), 0.13], [Vector3(0.2, -1.52, 0.03), 0.13], [Vector3(-0.05, -0.62, -0.08), 0.13],
			[Vector3(0.06, -0.66, -0.07), 0.12], [Vector3(-0.2, -1.2, -0.02), 0.1]]:
		var lump := MeshInstance3D.new()
		lump.name = "CocoonForm"
		var lm := SphereMesh.new()
		lm.radius = spec[1]
		lm.height = spec[1] * 2.0
		lump.mesh = lm
		lump.material_override = membrane
		_drop_body.add_child(lump, true)
		lump.position = spec[0]
	# strands wound ROUND it: tilted binding rings, tight on the body, all the way down
	for k in 8:
		var y := -0.42 - k * 0.17
		var ring := MeshInstance3D.new()
		ring.name = "CocoonStrand"
		var tm := TorusMesh.new()
		var girth := 0.2 if y < -0.95 else 0.16
		tm.inner_radius = girth - 0.01
		tm.outer_radius = girth + 0.02
		tm.rings = 20
		ring.mesh = tm
		ring.material_override = dark_membrane
		_drop_body.add_child(ring, true)
		ring.position = Vector3(0.0, y, 0.02)
		ring.rotation = Vector3(0.28 * (1.0 if k % 2 else -1.0), 0.0, 0.2 * (1.0 if k % 3 else -1.0))
	for k in 3:
		_limb(_drop_body, Vector3(0.08 * k - 0.08, -1.86, 0.0), Vector3(0.1 * k - 0.1, -2.08 - 0.05 * k, 0.03), 0.012, membrane, "CocoonDrip")
	# HAIR hanging from the head, which is at the bottom: the one thing that makes a wrapped bundle read
	# as a person at a glance (the first render of this cocoon read as a punching bag)
	var hair := _material(Color(0.03, 0.025, 0.02), 0.0)
	hair.roughness = 0.9
	for k in 11:
		var a := TAU * k / 11.0
		var root_at := Vector3(cos(a) * 0.075, -1.9, 0.04 + sin(a) * 0.075)
		var tip := root_at + Vector3(cos(a) * 0.03 + _rng.randf_range(-0.02, 0.02), -_rng.randf_range(0.24, 0.4), sin(a) * 0.03)
		_limb(_drop_body, root_at, tip, _rng.randf_range(0.006, 0.011), hair, "CocoonHair")
	# ⭐ ONE BARE ARM hanging out of the cocoon: shoulder at the torso's side, hanging to the floor
	var skin := _material(Color(0.6, 0.57, 0.5), 0.0)
	skin.roughness = 0.6
	var shoulder := Vector3(0.2, -1.5, 0.05)
	var elbow := Vector3(0.26, -1.78, 0.1)
	var wrist := Vector3(0.24, -2.02, 0.08)
	_limb(_drop_body, shoulder, elbow, 0.048, skin, "HangingArmUpper")
	_limb(_drop_body, elbow, wrist, 0.04, skin, "HangingArmFore")
	var hand := Node3D.new()
	hand.name = "HangingHand"
	_drop_body.add_child(hand)
	hand.position = wrist + Vector3(0, -0.06, 0)
	_box("HangingPalm", Vector3.ZERO, Vector3(0.08, 0.1, 0.03), skin, hand)
	for k in 4:
		_limb(hand, Vector3(-0.028 + k * 0.019, -0.05, 0.0), Vector3(-0.03 + k * 0.02, -0.11, 0.02), 0.01, skin, "HangingFinger")
	# ⭐ THE WORK LAMP tangled in the chain, dragged out of the duct with him (the first render: the
	# Containment lamp is on the WALL side, so it backlit the body into a flat black shape, and the user
	# asked for a body that reads as 3D). It hangs on the lane side of the body, swings with it, and casts
	# a shadow, so the cocoon is modelled from the front and throws a moving shadow on the wall behind.
	var cord_top := Vector3(0.12, -0.12, -0.08)
	var bulb_at := Vector3(0.3, -0.62, -0.46)
	_limb(_drop_body, cord_top, bulb_at + Vector3(0, 0.06, 0), 0.006, _dark, "WorkLampCord")
	var cage := _material(Color(0.05, 0.045, 0.04), 0.0)
	_box("WorkLampCage", bulb_at, Vector3(0.09, 0.13, 0.09), cage, _drop_body)
	# a dark albedo and emission under 1.0, so it reads as a lit bulb and goes visibly dead with the light
	var bulb_mat := _material(Color(0.06, 0.05, 0.04), 0.0)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.72, 0.42)
	bulb_mat.emission_energy_multiplier = 0.9
	_drop_bulb_mat = bulb_mat
	var bulb := MeshInstance3D.new()
	bulb.name = "WorkLampBulb"
	var bm := SphereMesh.new()
	bm.radius = 0.028
	bm.height = 0.07
	bulb.mesh = bm
	bulb.material_override = bulb_mat
	_drop_body.add_child(bulb)
	bulb.position = bulb_at
	_drop_lamp = OmniLight3D.new()
	_drop_lamp.name = "WorkLampLight"
	_drop_lamp.light_color = Color(1.0, 0.72, 0.46)
	_drop_lamp.light_energy = DROP_LAMP_ENERGY
	_drop_lamp.omni_range = 3.2
	_drop_lamp.shadow_enabled = true
	_drop_body.add_child(_drop_lamp)
	_drop_lamp.position = bulb_at + Vector3(0, 0, -0.06)
	var body := StaticBody3D.new()
	body.name = "CocoonedVictimSolid"
	body.collision_layer = 1
	body.collision_mask = 1
	_drop_body.add_child(body)
	body.position = Vector3(0, -1.1, 0.02)
	_drop_solid = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 1.7
	_drop_solid.shape = cap
	_drop_solid.disabled = true
	body.add_child(_drop_solid)
	_drop_body.visible = false


func drop_rig() -> Node3D:
	return _drop_rig


func _ceiling_drop() -> void:
	_log_beat("ceiling_drop")
	var cam: Camera3D = _player.get_node_or_null("Camera3D")
	var eye: Vector3 = cam.global_position if cam else _player.global_position
	var body_at := Vector3(DROP_PIVOT.x, 1.3, DROP_PIVOT.z)
	drop_ahead = absf(body_at.x - eye.x)
	drop_distance = Vector2(body_at.x - eye.x, body_at.z - eye.z).length()
	_drop_body.visible = true
	_drop_solid.set_deferred("disabled", false)
	_one_shot(DROP_PIVOT, load(AUD + SND_DROP_CRASH + ".wav"), MASTER, 2.0, 4.0, 40.0)
	_one_shot(DROP_PIVOT + Vector3(0, -0.3, 0), load(AUD + SND_DROP_CHAIN + ".wav"), MASTER, 0.0, 3.0, 30.0)
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_property(_drop_hatch, "rotation:z", deg_to_rad(-118.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# the fall: out of the duct in 0.3 s, the chain snaps taut past its length and springs back
	_drop_body.position = Vector3(0, 1.9, 0)
	var fall := create_tween()
	_tweens.append(fall)
	fall.tween_property(_drop_body, "position:y", -0.12, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_drop_body, "position:y", 0.04, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_property(_drop_body, "position:y", 0.0, 0.1)
	_drop_t = 0.0
	# the work lamp on his chain catches, dies, catches (it is only lit while he is shown anyway)
	for spec in [[0.0, false], [0.34, true], [0.42, false], [0.5, true], [1.1, false], [1.16, true]]:
		_at(spec[0], func() -> void:
			if is_instance_valid(_drop_lamp):
				_drop_lamp.visible = spec[1]
				_drop_bulb_mat.emission_enabled = spec[1])
	# the lamp beside it stutters
	if _containment_lamps.size() >= 3:
		var lamp: Dictionary = _containment_lamps[2]
		for spec in [[0.0, false], [0.07, true], [0.16, false], [0.3, true], [0.62, false], [0.7, true]]:
			_at(spec[0], _light_on.bind(lamp, spec[1]))


# The swing: mostly ALONG the corridor (about z), barely across it (about x), so it never reaches the
# lane; a twist about the chain; both decaying to rest in a few seconds.
func _tick_drop(delta: float) -> void:
	if _drop_t < 0.0 or not is_instance_valid(_drop_rig):
		return
	_drop_t += delta
	var t := maxf(0.0, _drop_t - 0.3)
	var decay := exp(-t / 2.6)
	var w := 3.0
	_drop_rig.rotation = Vector3(0.05 * decay * sin(w * t + 1.1), 0.9 * exp(-t / 4.5) * sin(1.7 * t),
		0.3 * decay * sin(w * t))
	if _drop_t > 14.0:
		_drop_t = -1.0


# ============================================================== the dark room (P4)

# ⭐ P4 (2026-09-23, capture 3: "Inside maybe it can be completely dark, and some creepy objects like
# poisons, knives … No jumpscares but the panic will rise"). An experiment room lit ONLY by a
# sparking junction box: random 0.06–0.12 s bursts of a real, shadow-casting light, so the props are
# seen in snapshots. The sparks glow; nothing else does (SCARY.md §8.8). Every prop is built from
# parts. Avoided on purpose: "RUN" in blood, dolls, handprint spam, gore piles, glowing fluid.
# Panic rises while you are inside and stops at 42/50 (`_physics_process`); there is no jumpscare.
func _build_dark_room() -> void:
	_build_junction_box()
	_build_restraint_chair(Vector3(-38.6, 0, -39.1))
	_build_instrument_trolley(Vector3(-36.1, 0, -38.3))
	_build_vial_rack()
	_build_specimen_cart(Vector3(-43.3, 0, -42.35))
	_build_clipboard()
	_build_hose_and_bucket()
	# where the victim was dragged from the door he hammered on, out through the far doorway
	var drag := load(TEX + "approach_drag_smear.png")
	var marks := [[-43.9, -34.2, 0.35], [-40.6, -35.4, 0.25], [-37.0, -36.2, 0.1], [-33.2, -36.6, 0.0], [-29.6, -36.6, 0.05]]
	for i in marks.size():
		var m: Array = marks[i]
		_floor_decal("DarkDragMarks", drag, Vector3(m[0], 0.026 + i * 0.002, m[1]), Vector2(2.2, 0.0), m[2])
	var blood := load(TEX + "approach_blood_pool.png")
	_floor_decal("DrainStain", blood, Vector3(-38.5, 0.027, -38.4), Vector2(1.5, 0.0), 0.7)
	# the dark-room bed: a flat player that fades in only while you are inside
	_dark_bed = AudioStreamPlayer.new()
	_dark_bed.name = "DarkRoomBed"
	_dark_bed.stream = load(AUD + SND_DARK_BED + ".wav")
	_dark_bed.bus = AMBIENCE
	_dark_bed.volume_db = -60.0
	add_child(_dark_bed)
	_dark_bed.finished.connect(_dark_bed.play)


func _build_junction_box() -> void:
	var p := _builder.wall_point("ApproachDarkRoom", Vector2(0, -1), 1.75, 0.2)
	p.x = -37.5
	var root := Node3D.new()
	root.name = "SparkingJunctionBox"
	add_child(root)
	root.position = p
	var steel := _material(Color(0.22, 0.23, 0.22), 0.55)
	_box("JunctionBody", Vector3(0, 0, -0.02), Vector3(0.52, 0.64, 0.16), steel, root)
	_box("JunctionInner", Vector3(0, 0, 0.061), Vector3(0.46, 0.58, 0.004), _dark, root)
	for k in 3:
		_box("JunctionBreaker", Vector3(-0.14 + k * 0.14, 0.12, 0.075), Vector3(0.08, 0.16, 0.03), _material(Color(0.12, 0.12, 0.12), 0.2), root)
	# the cover, torn half off its hinge and hanging open
	var hinge := Node3D.new()
	hinge.name = "JunctionCoverHinge"
	root.add_child(hinge)
	hinge.position = Vector3(-0.27, 0, 0.07)
	hinge.rotation = Vector3(0.0, deg_to_rad(-118), deg_to_rad(-9))
	var cover := _box("JunctionCover", Vector3(0.26, 0, 0), Vector3(0.52, 0.64, 0.02), steel, hinge)
	# it sits beside the spark: its shadow was a black wedge across half the ceiling (first render)
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate := _quad("JunctionPlate", load(TEX + "approach_junction_plate.png"), Vector2(0.3, 0.0), false, false, hinge)
	plate.position = Vector3(0.26, 0.18, 0.012)
	# conduits up into the ceiling, and a burst of cable spilling out of the bottom
	for dx in [-0.16, 0.0, 0.16]:
		_box("JunctionConduit", Vector3(dx, 0.85, -0.04), Vector3(0.05, 1.1, 0.05), _dark, root)
	var cable_mat := _material(Color(0.05, 0.05, 0.05), 0.0)
	for spec in [[-0.12, 0.4, 0.2], [0.02, 0.62, -0.25], [0.15, 0.5, 0.35], [0.2, 0.78, -0.5]]:
		var c := _box("SpilledCable", Vector3(spec[0], -0.32 - spec[1] * 0.5, 0.05), Vector3(0.025, spec[1], 0.025), cable_mat, root)
		c.rotation = Vector3(0.25, 0.0, spec[2])
	# the frayed end the sparks come from, low on the right
	var tip := Vector3(0.2, -0.52, 0.16)
	_spark_speaker_pos = root.to_global(tip)
	_spark_light = OmniLight3D.new()
	_spark_light.name = "SparkLight"
	_spark_light.light_color = Color(0.78, 0.86, 1.0)
	_spark_light.light_energy = 3.4
	_spark_light.omni_range = 12.0      # far enough to catch the vial rack on the west wall
	_spark_light.omni_attenuation = 0.6
	_spark_light.shadow_enabled = true
	_spark_light.visible = false
	add_child(_spark_light)
	_spark_light.position = _spark_speaker_pos + Vector3(0, 0.05, 0.12)
	# the arc itself: the only thing in the room allowed to glow
	var arc_mat := StandardMaterial3D.new()
	arc_mat.albedo_color = Color(0.2, 0.22, 0.25)
	arc_mat.emission_enabled = true
	arc_mat.emission = Color(0.8, 0.88, 1.0)
	arc_mat.emission_energy_multiplier = 1.0
	var arc := MeshInstance3D.new()
	arc.name = "SparkArc"
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	arc.mesh = sm
	arc.material_override = arc_mat
	arc.visible = false
	add_child(arc)
	arc.position = _spark_speaker_pos
	_spark_fx.append(arc)
	var sparks := CPUParticles3D.new()
	sparks.name = "SparkShower"
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 24
	sparks.lifetime = 0.55
	sparks.explosiveness = 0.95
	sparks.direction = Vector3(0.3, 0.4, 1.0)
	sparks.spread = 55.0
	sparks.initial_velocity_min = 1.2
	sparks.initial_velocity_max = 3.2
	sparks.gravity = Vector3(0, -9.0, 0)
	var dot := SphereMesh.new()
	dot.radius = 0.006
	dot.height = 0.012
	dot.radial_segments = 4
	dot.rings = 2
	dot.material = arc_mat
	sparks.mesh = dot
	add_child(sparks)
	sparks.position = _spark_speaker_pos
	_spark_fx.append(sparks)
	# the buzz never stops; the bursts crack over it (machinery → Ambience)
	var buzz := _speaker(_spark_speaker_pos, AMBIENCE, -14.0, 2.5, 18.0)
	buzz.name = "SparkBuzz"
	buzz.stream = load(AUD + SND_BUZZ + ".wav")
	buzz.finished.connect(buzz.play)
	buzz.play()


# Bolted to the floor over a drain, facing the door. Worn armrests scored by fingernails.
func _build_restraint_chair(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "RestraintChair"
	add_child(root)
	root.position = at
	var steel := _material(Color(0.3, 0.31, 0.3), 0.6)
	var vinyl := _material(Color(0.1, 0.085, 0.075), 0.0)
	vinyl.roughness = 0.55
	var leather := _material(Color(0.2, 0.12, 0.07), 0.0)
	_box("ChairBasePlate", Vector3(0, 0.015, 0), Vector3(0.78, 0.03, 0.78), _dark, root)
	for bx in [-0.33, 0.33]:
		for bz in [-0.33, 0.33]:
			_cylinder("ChairFloorBolt", Vector3(bx, 0.04, bz), 0.02, 0.025, steel, root)
			_box("ChairLeg", Vector3(bx * 0.8, 0.26, bz * 0.8), Vector3(0.05, 0.46, 0.05), steel, root)
	_box("ChairSeat", Vector3(0, 0.52, 0), Vector3(0.56, 0.08, 0.52), vinyl, root)
	var back := _box("ChairBack", Vector3(0, 0.98, -0.27), Vector3(0.56, 0.78, 0.07), vinyl, root)
	back.rotation.x = deg_to_rad(-8)
	_box("ChairHeadrest", Vector3(0, 1.5, -0.33), Vector3(0.3, 0.2, 0.08), vinyl, root)
	_box("HeadStrap", Vector3(0, 1.5, -0.28), Vector3(0.32, 0.05, 0.02), leather, root)
	var scores := load(TEX + "approach_armrest_scores.png")
	for side in [-1.0, 1.0]:
		_box("ArmSupport", Vector3(side * 0.3, 0.63, 0.12), Vector3(0.04, 0.2, 0.04), steel, root)
		_box("Armrest", Vector3(side * 0.3, 0.75, -0.02), Vector3(0.1, 0.05, 0.52), vinyl, root)
		var top := _quad("ArmrestScores", scores, Vector2(0.5, 0.0), false, false, root)
		top.position = Vector3(side * 0.3, 0.7765, -0.02)
		top.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
		_box("WristStrap", Vector3(side * 0.3, 0.755, 0.1), Vector3(0.115, 0.065, 0.08), leather, root)
		_box("StrapBuckle", Vector3(side * 0.36, 0.755, 0.1), Vector3(0.012, 0.035, 0.03), steel, root)
		_box("AnkleStrap", Vector3(side * 0.26, 0.14, 0.26), Vector3(0.1, 0.06, 0.1), leather, root)
	var loose := _box("ChestStrapLoose", Vector3(0.24, 0.72, -0.2), Vector3(0.05, 0.62, 0.012), leather, root)
	loose.rotation.z = 0.18
	# the drain under its front edge, where everything runs to
	var drain := Node3D.new()
	drain.name = "FloorDrain"
	root.add_child(drain)
	drain.position = Vector3(0, 0.022, 0.52)
	_box("DrainRim", Vector3(0, 0, 0), Vector3(0.42, 0.012, 0.42), steel, drain)
	for k in 6:
		_box("DrainSlot", Vector3(0, 0.0065, -0.16 + k * 0.064), Vector3(0.34, 0.002, 0.03), _material(Color(0, 0, 0), 0.0), drain)
	_collide(root, Vector3(0.72, 1.6, 0.72), Vector3(0, 0.8, -0.02))


# An instrument trolley, everything laid out in order on its cloth — and one outline empty.
func _build_instrument_trolley(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "InstrumentTrolley"
	add_child(root)
	root.position = at
	var steel := _material(Color(0.42, 0.43, 0.42), 0.8)
	steel.roughness = 0.35
	for bx in [-0.42, 0.42]:
		for bz in [-0.22, 0.22]:
			_box("TrolleyLeg", Vector3(bx, 0.43, bz), Vector3(0.025, 0.82, 0.025), steel, root)
			_cylinder("TrolleyCaster", Vector3(bx, 0.03, bz), 0.03, 0.025, _dark, root).rotation.z = PI / 2.0
	_box("TrolleyTray", Vector3(0, 0.85, 0), Vector3(0.9, 0.02, 0.5), steel, root)
	for spec in [[Vector3(0, 0.875, 0.245), Vector3(0.9, 0.03, 0.01)], [Vector3(0, 0.875, -0.245), Vector3(0.9, 0.03, 0.01)],
			[Vector3(0.445, 0.875, 0), Vector3(0.01, 0.03, 0.5)], [Vector3(-0.445, 0.875, 0), Vector3(0.01, 0.03, 0.5)]]:
		_box("TrayLip", spec[0], spec[1], steel, root)
	_box("TrolleyShelf", Vector3(0, 0.3, 0), Vector3(0.86, 0.02, 0.46), steel, root)
	var cloth_tex := load(TEX + "approach_tray_cloth.png")
	var cloth := _quad("TrayCloth", cloth_tex, Vector2(0.84, 0.0), false, false, root)
	cloth.position = Vector3(0, 0.8625, 0)
	cloth.rotation = Vector3(-PI / 2.0, 0, 0)
	var cloth_h: float = (cloth.mesh as QuadMesh).size.y
	# nine instruments in order across the cloth, each on its traced outline — the sixth is missing
	var blade := _material(Color(0.62, 0.63, 0.62), 0.9)
	blade.roughness = 0.25
	var handle := _material(Color(0.18, 0.18, 0.19), 0.6)
	for i in 9:
		if i == 5:
			continue
		var u: float = (87.0 + 104.0 * i) / 1024.0
		var x := (u - 0.5) * 0.84
		var length := (200.0 + (i % 3) * 60.0) / 512.0 * cloth_h
		var y := 0.871
		_box("InstrumentHandle", Vector3(x, y, length * 0.18), Vector3(0.016, 0.012, length * 0.6), handle, root)
		_box("InstrumentBlade", Vector3(x, y - 0.002, -length * 0.3), Vector3(0.012 + (i % 3) * 0.006, 0.004, length * 0.4), blade, root)
	_box("DiscardedGlove", Vector3(0.1, 0.32, 0.05), Vector3(0.14, 0.02, 0.09), _material(Color(0.45, 0.47, 0.44), 0.0), root)
	_collide(root, Vector3(0.9, 0.9, 0.5), Vector3(0, 0.45, 0))


# Steel shelving on the west wall: vials in rows, and the dose on the rail under them climbs.
func _build_vial_rack() -> void:
	var root := Node3D.new()
	root.name = "VialRack"
	add_child(root)
	root.position = Vector3(-45.6, 0, -39.6)
	var steel := _material(Color(0.26, 0.27, 0.26), 0.6)
	for bz in [-1.05, 1.05]:
		for bx in [-0.2, 0.2]:
			_box("RackPost", Vector3(bx, 0.95, bz), Vector3(0.03, 1.9, 0.03), steel, root)
	var strip := load(TEX + "approach_dose_strip.png")
	var glass := _material(Color(0.6, 0.66, 0.64, 0.22), 0.0)
	glass.roughness = 0.1
	glass.metallic_specular = 0.9
	var levels := [0.8, 0.75, 0.7, 0.62, 0.55, 0.4, 0.2, 0.0]
	for row in 4:
		var y: float = 0.38 + row * 0.45
		_box("RackShelf", Vector3(0, y, 0), Vector3(0.44, 0.02, 2.14), steel, root)
		if row == 1 or row == 2:
			var q := _quad("DoseStrip", strip, Vector2(1.6, 0.0), false, false, root)
			q.position = Vector3(0.225, y - 0.045, 0)
			q.rotation.y = PI / 2.0
			for k in 8:
				var z := -0.7 + k * 0.2
				var tipped := row == 2 and k >= 6
				var vial := Node3D.new()
				vial.name = "Vial"
				root.add_child(vial)
				vial.position = Vector3(0.08, y + 0.06, z)
				if tipped:
					vial.rotation.z = PI / 2.0 - 0.1
					vial.position.y = y + 0.03
				_cylinder("VialGlass", Vector3.ZERO, 0.018, 0.1, glass, vial)
				_cylinder("VialCap", Vector3(0, 0.055, 0), 0.02, 0.014, _material(Color(0.35, 0.1, 0.08), 0.0), vial)
				var lvl: float = levels[k] * (0.85 if row == 1 else 1.0)
				if lvl > 0.0 and not tipped:
					var fluid := _material(Color(0.28, 0.18, 0.06, 0.85), 0.0)
					_cylinder("VialDose", Vector3(0, -0.05 + 0.045 * lvl, 0), 0.015, 0.09 * lvl, fluid, vial)
	# the bottom shelf: an empty ampoule box and a rack knocked over
	_box("AmpouleBox", Vector3(0.0, 0.46, -0.6), Vector3(0.3, 0.14, 0.4), _material(Color(0.5, 0.48, 0.42), 0.0), root)
	var knocked := _box("KnockedRack", Vector3(0.05, 0.43, 0.5), Vector3(0.3, 0.08, 0.5), steel, root)
	knocked.rotation.x = 0.3
	_collide(root, Vector3(0.46, 1.9, 2.14), Vector3(0, 0.95, 0))


# A steel cart under the junction box: specimen jars of something that cannot be named.
func _build_specimen_cart(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "SpecimenCart"
	add_child(root)
	root.position = at
	var steel := _material(Color(0.3, 0.31, 0.3), 0.6)
	_box("CartTop", Vector3(0, 0.8, 0), Vector3(1.2, 0.03, 0.5), steel, root)
	_box("CartShelf", Vector3(0, 0.28, 0), Vector3(1.16, 0.02, 0.46), steel, root)
	for bx in [-0.57, 0.57]:
		for bz in [-0.22, 0.22]:
			_box("CartLeg", Vector3(bx, 0.4, bz), Vector3(0.03, 0.8, 0.03), steel, root)
	var glass := _material(Color(0.55, 0.6, 0.56, 0.18), 0.0)
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fluid := _material(Color(0.32, 0.29, 0.16, 0.72), 0.0)
	fluid.roughness = 0.2
	var flesh := _material(Color(0.2, 0.14, 0.13), 0.0)
	flesh.roughness = 0.6
	var label := load(TEX + "approach_jar_label.png")
	var jars := [[Vector3(-0.38, 0.815, 0.02), 1.0, true], [Vector3(0.0, 0.815, -0.04), 0.85, false],
		[Vector3(0.36, 0.815, 0.05), 1.1, true], [Vector3(-0.2, 0.29, 0.0), 0.8, false], [Vector3(0.25, 0.29, 0.02), 0.9, false]]
	for j in jars.size():
		var spec: Array = jars[j]
		var k: float = spec[1]
		var jar := Node3D.new()
		jar.name = "SpecimenJar"
		root.add_child(jar)
		jar.position = spec[0]
		_cylinder("JarFluid", Vector3(0, 0.12 * k, 0), 0.095 * k, 0.22 * k, fluid, jar)
		# a lump that is not quite anything: an irregular mass, a second one fused to it
		var lump := MeshInstance3D.new()
		lump.name = "JarContents"
		var sm := SphereMesh.new()
		sm.radius = 0.06 * k
		sm.height = 0.1 * k
		lump.mesh = sm
		lump.material_override = flesh
		jar.add_child(lump)
		lump.position = Vector3(0.01, 0.11 * k, 0.0)
		lump.scale = Vector3(1.0, 0.7 + 0.2 * float(j % 2), 1.35)
		lump.rotation = Vector3(0.4 * j, 0.9 * j, 0.2)
		var bud := _cylinder("JarContents", Vector3(-0.03 * k, 0.15 * k, 0.02), 0.022 * k, 0.07 * k, flesh, jar)
		bud.rotation.z = 0.8
		_cylinder("JarGlass", Vector3(0, 0.14 * k, 0), 0.11 * k, 0.28 * k, glass, jar)
		_cylinder("JarLid", Vector3(0, 0.29 * k, 0), 0.115 * k, 0.03, _dark, jar)
		if spec[2]:
			var tag := _quad("JarLabel", label, Vector2(0.11, 0.0), false, false, jar)
			tag.position = Vector3(0, 0.1 * k, 0.113 * k)
	_collide(root, Vector3(1.2, 0.84, 0.5), Vector3(0, 0.42, 0))


func _build_clipboard() -> void:
	var p := _builder.wall_point("ApproachDarkRoom", Vector2(0, -1), 1.45, 0.18)
	p.x = -40.3
	var root := Node3D.new()
	root.name = "ExposureClipboard"
	add_child(root)
	root.position = p
	_box("ClipboardBoard", Vector3(0, 0, -0.012), Vector3(0.25, 0.34, 0.012), _material(Color(0.3, 0.22, 0.14), 0.0), root)
	var sheet := _quad("ClipboardLog", load(TEX + "approach_clipboard_log.png"), Vector2(0.21, 0.0), false, false, root)
	sheet.position = Vector3(0, -0.01, -0.004)
	_box("ClipboardClip", Vector3(0, 0.15, 0.0), Vector3(0.1, 0.035, 0.015), _steel, root)
	_cylinder("ClipboardNail", Vector3(0, 0.2, -0.03), 0.005, 0.05, _steel, root).rotation.x = PI / 2.0


# A hose coiled on a wall bracket, run across the floor to the drain, and a pail beside it.
func _build_hose_and_bucket() -> void:
	var p := _builder.wall_point("ApproachDarkRoom", Vector2(0, 1), 1.2, 0.2)
	p.x = -31.2
	var rubber := _material(Color(0.1, 0.13, 0.1), 0.0)
	rubber.roughness = 0.7
	var root := Node3D.new()
	root.name = "HoseReel"
	add_child(root)
	root.position = p
	root.rotation.y = PI
	_box("HoseBracket", Vector3(0, 0, -0.05), Vector3(0.08, 0.3, 0.1), _steel, root)
	for k in 3:
		var coil := MeshInstance3D.new()
		coil.name = "HoseCoil"
		var t := TorusMesh.new()
		t.inner_radius = 0.17
		t.outer_radius = 0.21
		coil.mesh = t
		coil.material_override = rubber
		root.add_child(coil)
		coil.position = Vector3(0, -0.02 * k, 0.03 + 0.045 * k)
		coil.rotation.x = PI / 2.0
	_cylinder("WallTap", Vector3(0, 0.42, 0.02), 0.025, 0.1, _steel, root).rotation.x = PI / 2.0
	# the run across the floor: lying flat, no collider (you step over a hose, not into it)
	var pts := [p + Vector3(0, -1.0, -0.1), Vector3(-31.4, 0.022, -33.6), Vector3(-33.6, 0.022, -35.4),
		Vector3(-36.3, 0.022, -37.2), Vector3(-38.0, 0.022, -38.5)]
	pts[0].y = 0.022
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := _cylinder("HoseRun", (a + b) * 0.5, 0.022, a.distance_to(b), rubber)
		seg.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
		seg.rotate_object_local(Vector3(1, 0, 0), PI / 2.0)
	_cylinder("HoseDrop", p + Vector3(0, -0.6, -0.1), 0.022, 1.1, rubber)
	# the pail, beside the drain: open-topped steel, something dark in it
	var pail := Node3D.new()
	pail.name = "Bucket"
	add_child(pail)
	pail.position = Vector3(-37.55, 0, -39.75)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.13
	cm.height = 0.3
	cm.cap_top = false
	var pail_mat := _material(Color(0.4, 0.41, 0.4), 0.7)
	pail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shell := MeshInstance3D.new()
	shell.name = "BucketShell"
	shell.mesh = cm
	shell.material_override = pail_mat
	pail.add_child(shell)
	shell.position = Vector3(0, 0.15, 0)
	var murk := _cylinder("BucketContents", Vector3(0, 0.2, 0), 0.148, 0.01, _material(Color(0.12, 0.05, 0.04), 0.0), pail)
	murk.name = "BucketContents"
	var bail := MeshInstance3D.new()
	bail.name = "BucketBail"
	var bt := TorusMesh.new()
	bt.inner_radius = 0.155
	bt.outer_radius = 0.165
	bail.mesh = bt
	bail.material_override = _steel
	pail.add_child(bail)
	bail.position = Vector3(0, 0.3, 0)
	bail.rotation = Vector3(0, 0, PI / 2.0 - 0.5)
	_collide_cylinder(pail, 0.16, 0.3).position = Vector3(0, 0.15, 0)


# ============================================================== the passage (P3)

func _build_passage() -> void:
	# a narrow service passage: a dead red lamp at the dark room end, a live one at the chamber end
	_lamp(Vector3(-22.6, 2.62, -36.5), Color(0.72, 0.3, 0.22), 0.55, 3.6, true)
	_box("PassagePipe", Vector3(-24, 2.72, -37.72), Vector3(8.0, 0.14, 0.14), _dark)
	_lintel(Vector3(-28, 0, -36.5), 1.4, 2.96, 3.3)    # the dark room 3.2 over the passage's 3.0
	_lintel(Vector3(-20, 0, -36.5), 1.4, 2.96, 3.5)    # the chamber 3.4 over the passage's 3.0
	var drag := load(TEX + "approach_drag_smear.png")
	for i in 3:
		_floor_decal("PassageDragMarks", drag, Vector3(-26.4 + i * 2.6, 0.026 + i * 0.002, -36.5 + (i - 1) * 0.15),
			Vector2(2.2, 0.0), 0.05 * (i - 1))


# ============================================================== the cell chamber (P5)

# ⭐ P5 — THE ESCAPE, TOLD (2026-09-23, capture 4: "the idea of the creature escaping is not
# developed enough … an empty cell which we saw in the Kontur … some bodies covered in blood"). The
# chamber the player walks through: the breached glass-tank cell (the shared `ContainmentCell`, see
# `BreachedCellSpot`), glass burst outward across the floor, two bodies, dead only, and a CCTV monitor
# on the security desk looping the breakout.
func _build_cell_chamber() -> void:
	_cell_spot = Marker3D.new()
	_cell_spot.name = "BreachedCellSpot"
	add_child(_cell_spot)
	_cell_spot.position = CELL_SPOT
	# ContainmentCell's front is its local -z; +PI/2 turns that toward world -x, at the player coming
	# in from the passage (KONTUR turns it the same way). ⚠️ -PI/2 would show them its gouged back.
	_cell_spot.rotation.y = PI / 2.0
	# ⭐ THE SHARED CELL, BREACHED (containment_cell.gd, the KONTUR agent's build of concept A). The
	# same tank KONTUR shows occupied: front pane burst out, 19 teeth in the frame, 102 shards on the
	# floor in front, the collar torn and swinging, blood inside, nobody in it. It owns ALL the glass
	# here: this file's own loose shards were removed rather than doubled up on its field.
	var cell := ContainmentCell.new()
	cell.name = "BreachedCell"
	cell.state = ContainmentCell.STATE_BREACHED
	cell.drain = true
	place_breached_cell(cell)
	# what walked out: residue from the spot to the doorway into Containment
	var trail := load(TEX + "approach_residue_trail.png")
	# ⚠️ clear of the tank's drain stain (it covers z <= -34.2 in front of the tank), so no two floor
	# layers of different owners ever lie a few mm apart
	for spec in [[-12.4, -32.6, 0.9], [-13.1, -31.2, 1.2], [-13.4, -29.9, 1.45]]:
		_floor_decal("CellResidueTrail", trail, Vector3(spec[0], 0.027, spec[1]), Vector2(1.6, 0.0), spec[2])
	_build_bodies()
	_build_cctv(Vector3(-17.8, 0, -29.55))
	# light: a caged lamp over the spot, and a dim red one by the entrance
	# ⚠️ Brighter than the approach's other lamps (the first render: the organic skin drank a 1.25 lamp
	# and both bodies were invisible). A second, dimmer fitting over the bodies.
	# the key light hangs over the tank's burst FRONT (not its roof): it lights the teeth, the open
	# tank and the glass on the floor. The tank's own lamp is emission only (its lit liners and back
	# wall), and is left ON so the empty tank reads against a lit interior.
	_lamp(Vector3(-12.9, 3.05, -34.8), Color(0.72, 0.82, 0.8), 2.1, 8.0, true)
	_lamp(Vector3(-16.4, 3.05, -31.7), Color(0.74, 0.7, 0.62), 1.2, 5.5, true)
	# an open steel shade over it (four crossed bars read as a black star from below: 06f, first render)
	var shade_mat := _material(Color(0.12, 0.12, 0.11), 0.6)
	shade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shade := _cylinder("LampShade", Vector3(-12.9, 3.12, -34.8), 0.26, 0.2, shade_mat, null, 0.1)
	(shade.mesh as CylinderMesh).cap_bottom = false
	_lamp(Vector3(-19.4, 2.7, -37.3), Color(0.72, 0.32, 0.24), 0.5, 4.5, true)
	var gouge := load(TEX + "approach_claw_gouge.png")
	for spec in [[Vector2(0, -1), -12.4, 2.25], [Vector2(1, 0), -33.2, 2.4]]:
		var gp := _builder.wall_point("ApproachCell12", spec[0], spec[2], 0.16)
		if spec[0].y != 0:
			gp.x = spec[1]
		else:
			gp.z = spec[1]
		var gq := _quad("CellGouges", gouge, Vector2(0.8, 0.0), false, true)
		gq.position = gp
		gq.rotation.y = 0.0 if spec[0].y < 0 else -PI / 2.0


# Dead only. Generated RGBA art on floor quads (tools/make_breach_pass3_art.py), each with a low
# solid box the size of the body (P6).
func _build_bodies() -> void:
	var blood := load(TEX + "approach_blood_pool.png")
	# the technician who was nearest the tank when it burst: face down in the glass
	var a := Node3D.new()
	a.name = "BodyFaceDown"
	add_child(a)
	a.position = Vector3(-16.9, 0, -32.4)
	a.rotation.y = 0.55
	_floor_decal("BodyPoolA", blood, Vector3(-0.3, 0.028, 0.1), Vector2(1.7, 0.0), 0.4, a)
	var qa := _floor_decal("BodyFaceDownArt", load(TEX + "approach_body_facedown.png"), Vector3(0, 0.034, 0), Vector2(1.8, 0.0), 0.0, a)
	(qa.material_override as StandardMaterial3D).roughness = 0.8
	_collide(a, Vector3(1.45, 0.26, 0.5), Vector3(0.05, 0.13, 0.0))
	# the guard, curled on his side in front of the desk he was watching the monitor from
	var b := Node3D.new()
	b.name = "BodyGuard"
	add_child(b)
	b.position = Vector3(-16.3, 0, -30.75)
	b.rotation.y = -0.12
	_floor_decal("BodyPoolB", blood, Vector3(0.2, 0.029, 0.15), Vector2(1.3, 0.0), 1.9, b)
	var qb := _floor_decal("BodyGuardArt", load(TEX + "approach_body_guard.png"), Vector3(0, 0.035, 0), Vector2(1.85, 0.0), 0.0, b)
	(qb.material_override as StandardMaterial3D).roughness = 0.8
	_collide(b, Vector3(1.55, 0.28, 0.46), Vector3(0.05, 0.14, 0.0))


# ⭐ THE GAME'S FIRST IN-WORLD VIDEO. A boxy CRT on the security desk, its screen a QuadMesh fed by
# `VideoStreamPlayer.get_video_texture()` through a shader that adds grain, scanlines, a rolling bar
# and dropouts; a Label3D timestamp ticks over it. ⚠️ SHADED, not self-lit: emission tops out at
# 0.55 (Issue 21, and §8.8's spirit — the screen reads as a screen, not as a lamp). The clip is a
# PLACEHOLDER (tools/make_breach_cctv_placeholder.py); the user's clip drops in at CCTV_VIDEO.
func _build_cctv(desk_at: Vector3) -> void:
	var steel := _material(Color(0.24, 0.25, 0.24), 0.5)
	var desk := Node3D.new()
	desk.name = "CCTVDesk"
	add_child(desk)
	desk.position = desk_at
	_box("DeskTop", Vector3(0, 0.76, 0), Vector3(1.5, 0.04, 0.66), steel, desk)
	for bx in [-0.7, 0.7]:
		for bz in [-0.29, 0.29]:
			_box("DeskLeg", Vector3(bx, 0.37, bz), Vector3(0.05, 0.74, 0.05), steel, desk)
	_box("DeskPedestal", Vector3(-0.5, 0.36, 0.0), Vector3(0.42, 0.62, 0.6), steel, desk)
	_collide(desk, Vector3(1.5, 0.78, 0.66), Vector3(0, 0.39, 0))
	# a chair knocked onto its side: built upright, then laid down about z, resting on its width
	var chair := Node3D.new()
	chair.name = "ToppledChair"
	add_child(chair)
	chair.position = desk_at + Vector3(-0.95, 0.23, -0.85)
	chair.rotation = Vector3(0, 0.6, PI / 2.0)
	var vinyl := _material(Color(0.12, 0.1, 0.09), 0.0)
	_box("ChairSeatT", Vector3(0, 0.45, 0), Vector3(0.46, 0.07, 0.44), vinyl, chair)
	_box("ChairBackT", Vector3(0, 0.72, -0.21), Vector3(0.42, 0.5, 0.06), vinyl, chair)
	_box("ChairStemT", Vector3(0, 0.23, 0), Vector3(0.04, 0.42, 0.04), steel, chair)
	_box("ChairBaseT", Vector3(0, 0.03, 0), Vector3(0.5, 0.04, 0.5), steel, chair)
	_collide(chair, Vector3(0.5, 0.95, 0.5), Vector3(0, 0.47, 0))
	# the monitor, turned toward the way the player comes in
	var mon := Node3D.new()
	mon.name = "CCTVMonitor"
	add_child(mon)
	mon.position = desk_at + Vector3(0.25, 0.78, 0.02)
	var to := Vector3(-20.0, 0, -36.5) - mon.position
	mon.rotation.y = atan2(to.x, to.z)
	var shell := _material(Color(0.36, 0.34, 0.3), 0.1)
	shell.roughness = 0.6
	_box("CRTFront", Vector3(0, 0.22, 0), Vector3(0.5, 0.42, 0.28), shell, mon)
	_box("CRTTube", Vector3(0, 0.21, -0.26), Vector3(0.36, 0.3, 0.24), shell, mon)
	_box("CRTFoot", Vector3(0, 0.012, -0.05), Vector3(0.3, 0.025, 0.28), _dark, mon)
	var bezel := _material(Color(0.14, 0.13, 0.12), 0.1)
	# the screen sits 7 mm proud of the shell's face and the bezel 5 mm proud of the screen: no
	# two faces closer than that, or the monitor flickers at a couple of metres
	for spec in [[Vector3(0, 0.395, 0.153), Vector3(0.46, 0.035, 0.012)], [Vector3(0, 0.06, 0.153), Vector3(0.46, 0.07, 0.012)],
			[Vector3(-0.215, 0.22, 0.153), Vector3(0.03, 0.34, 0.012)], [Vector3(0.215, 0.22, 0.153), Vector3(0.03, 0.34, 0.012)]]:
		_box("CRTBezel", spec[0], spec[1], bezel, mon)
	for kx in [0.12, 0.18]:
		_cylinder("CRTKnob", Vector3(kx, 0.06, 0.168), 0.012, 0.02, _dark, mon).rotation.x = PI / 2.0
	var led := StandardMaterial3D.new()
	led.albedo_color = Color(0.1, 0.02, 0.02)
	led.emission_enabled = true
	led.emission = Color(0.9, 0.1, 0.05)
	led.emission_energy_multiplier = 0.8
	_box("CRTLed", Vector3(-0.17, 0.06, 0.161), Vector3(0.01, 0.01, 0.004), led, mon)
	var screen := MeshInstance3D.new()
	screen.name = "CCTVScreen"
	var sq := QuadMesh.new()
	sq.size = Vector2(0.4, 0.3)
	screen.mesh = sq
	_cctv_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CCTV_SHADER
	_cctv_mat.shader = sh
	_cctv_mat.set_shader_parameter("has_video", 0.0)
	screen.material_override = _cctv_mat
	mon.add_child(screen)
	screen.position = Vector3(0, 0.225, 0.147)
	_cctv_stamp = Label3D.new()
	_cctv_stamp.name = "CCTVTimestamp"
	_cctv_stamp.font_size = 30
	_cctv_stamp.pixel_size = 0.00055
	_cctv_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cctv_stamp.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_cctv_stamp.modulate = Color(0.78, 0.9, 0.78, 0.8)
	_cctv_stamp.outline_size = 0
	_cctv_stamp.shaded = false
	mon.add_child(_cctv_stamp)
	_cctv_stamp.position = Vector3(-0.185, 0.365, 0.1495)
	_update_cctv_stamp()
	var glow := OmniLight3D.new()
	glow.name = "CCTVScreenSpill"
	glow.light_color = Color(0.6, 0.74, 0.64)
	glow.light_energy = 0.35
	glow.omni_range = 2.0
	glow.shadow_enabled = false
	mon.add_child(glow)
	glow.position = Vector3(0, 0.25, 0.5)
	var hum := _speaker(mon.global_position + Vector3(0, 0.2, 0), AMBIENCE, -16.0, 1.6, 10.0)
	hum.name = "CRTHum"
	hum.stream = load(AUD + SND_CRT + ".wav")
	hum.finished.connect(hum.play)
	hum.play()
	# the video: a VideoStreamPlayer is a Control, parked off-screen and transparent — it is only
	# ever seen through the quad. ⚠️ Headless builds decode nothing; the shader then shows static.
	_cctv_video = VideoStreamPlayer.new()
	_cctv_video.name = "CCTVVideo"
	_cctv_video.position = Vector2(-4000, -4000)
	_cctv_video.size = Vector2(4, 4)
	_cctv_video.self_modulate = Color(1, 1, 1, 0)
	_cctv_video.loop = true
	_cctv_video.volume_db = -80.0
	add_child(_cctv_video)
	if ResourceLoader.exists(CCTV_VIDEO):
		_cctv_video.stream = load(CCTV_VIDEO)
		_cctv_video.play()
		var tex := _cctv_video.get_video_texture()
		if tex != null:
			_cctv_mat.set_shader_parameter("video", tex)
			_cctv_mat.set_shader_parameter("has_video", 1.0)


func _update_cctv_stamp() -> void:
	var secs := 14 * 60 + 7 + int(_cctv_clock)
	_cctv_stamp.text = "CAM 04  CELL 12\n09-23  03:%02d:%02d" % [int(secs / 60.0) % 60, secs % 60]


func cctv_screen_material() -> ShaderMaterial:
	return _cctv_mat


# Seats the shared cell on its spot. `state` and `drain` must already be set: ContainmentCell reads
# both once, in `_ready()`, i.e. inside this add_child().
func place_breached_cell(cell: Node3D) -> void:
	_cell_spot.add_child(cell)


func breached_cell() -> Node3D:
	return _cell_spot.get_node_or_null("BreachedCell") if _cell_spot else null


const CCTV_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D video : source_color, filter_linear;
uniform float has_video = 0.0;
uniform float brightness = 0.55;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float t = TIME;
	uv.x += (hash(vec2(floor(uv.y * 240.0), floor(t * 24.0))) - 0.5) * 0.004;
	vec3 c = has_video > 0.5 ? texture(video, uv).rgb : vec3(0.14 + 0.1 * hash(uv * 300.0 + floor(t * 20.0)));
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 img = vec3(lum * 0.84, lum, lum * 0.8);
	float grain = hash(uv * vec2(480.0, 360.0) + floor(t * 30.0)) - 0.5;
	float scan = 0.8 + 0.2 * sin(uv.y * 280.0 * 3.14159);
	float roll = fract(uv.y - t * 0.11);
	float bar = smoothstep(0.0, 0.06, roll) * (1.0 - smoothstep(0.06, 0.16, roll));
	vec2 d = uv - 0.5;
	float vig = clamp(1.0 - dot(d, d) * 1.7, 0.0, 1.0);
	float drop = step(0.975, hash(vec2(floor(t * 7.0), 3.7)));
	img = mix(img, vec3(hash(uv * 900.0 + t)), drop * 0.85);
	img = clamp((img + grain * 0.1) * scan * vig + bar * 0.05, 0.0, 1.0);
	ALBEDO = img * 0.1;
	EMISSION = img * brightness;
	ROUGHNESS = 0.15;
	SPECULAR = 0.65;
}
"""


# ============================================================== Threshold (A7, A11)

const HAND_DUCT_X := -2.35
const HAND_Z := -16.5         # ~6.5 m past the corner, so the look lands right after the turn

func _build_threshold() -> void:
	for z in [-19.0, -10.0, -4.5]:
		_lamp(Vector3(1.6, 2.55, z), Color(0.54, 0.65, 0.58), 0.7, 7.0, true)
	_lintel(Vector3(0, 0, -23), 2.4, 2.96, 3.5)      # Containment 3.4 over the Threshold's 3.0
	# A big exhaust duct along the west wall with ONE open hatch in its underside. Built from
	# parts so the hatch is a real hole: the glimpse comes out of it.
	var zs := -21.5
	var ze := -4.2
	var zc := (zs + ze) * 0.5
	var duct := _material(Color(0.2, 0.22, 0.21), 0.55)
	_box("ExhaustSideW", Vector3(-2.825, 2.475, zc), Vector3(0.05, 0.95, ze - zs), duct)
	_box("ExhaustSideE", Vector3(-1.875, 2.475, zc), Vector3(0.05, 0.95, ze - zs), duct)
	_box("ExhaustTop", Vector3(HAND_DUCT_X, 2.925, zc), Vector3(0.9, 0.05, ze - zs), duct)
	var h0 := HAND_Z - 0.36
	var h1 := HAND_Z + 0.36
	_box("ExhaustBottomA", Vector3(HAND_DUCT_X, 2.025, (zs + h0) * 0.5), Vector3(0.9, 0.05, h0 - zs), duct)
	_box("ExhaustBottomB", Vector3(HAND_DUCT_X, 2.025, (h1 + ze) * 0.5), Vector3(0.9, 0.05, ze - h1), duct)
	_box("ExhaustCapS", Vector3(HAND_DUCT_X, 2.475, zs - 0.025), Vector3(1.0, 0.95, 0.05), duct)
	_box("ExhaustCapN", Vector3(HAND_DUCT_X, 2.475, ze + 0.025), Vector3(1.0, 0.95, 0.05), duct)
	for z in [-20.0, -13.0, -9.5, -6.0]:
		_box("ExhaustHanger", Vector3(-1.84, 2.96, z), Vector3(0.03, 0.08, 0.05), _dark)
	# The hatch grille hangs open from its WEST hinge — opened from inside — so it hangs behind
	# the hand as seen from the lane, never in front of it.
	var grille := Node3D.new()
	grille.name = "HatchGrille"
	add_child(grille)
	grille.position = Vector3(-2.8, 2.0, HAND_Z)
	grille.rotation.z = deg_to_rad(-72)
	_box("GrilleFrame", Vector3(0.35, 0, 0), Vector3(0.7, 0.03, 0.7), _dark, grille)
	# A11: the old Label3D sat inside the bulkhead rails' depth and was clipped (J-capture 6).
	# It is a plate on the wall BESIDE the bulkhead now, clear of the rails (x 0.94..1.10).
	var p := _builder.wall_point("ApproachThreshold", Vector2(0, 1), 1.95, 0.18)
	p.x = 1.98
	_backed_plate("WingSign", TEX + "approach_sign_containment_wing.png", p, PI, Vector2(1.3, 0.65), 0.3)
	for x in [-1.02, 1.02]:
		_solid_box("BulkheadRail", Vector3(x, 1.35, -3.06), Vector3(0.16, 2.7, 0.34), _steel)
	_gate = Node3D.new()
	_gate.name = "ContainmentBulkheadLeaf"
	add_child(_gate)
	_gate.position = Vector3(0, 4.05, -3)
	_box("BulkheadSteel", Vector3.ZERO, Vector3(1.84, 2.54, 0.24), _steel, _gate)
	var door_mat := _material(Color.WHITE, 0.45)
	door_mat.albedo_texture = load("res://assets/textures/level_6_breach/breach_door.png")
	# ⚠️ Cropped, not stretched: the plate is ~1.04 wide-to-tall and the leaf 0.72, and
	# check_art_aspect.gd measured the face at 1.436x since the approach shipped (2026-09-22).
	# The same crop the purge chamber's leaf uses.
	preload("res://scripts/door.gd").crop_uv_to_fit(door_mat, 1.82 / 2.52)
	for side in [-1.0, 1.0]:
		var face := MeshInstance3D.new()
		face.name = "BulkheadBreachFace"
		var quad := QuadMesh.new()
		quad.size = Vector2(1.82, 2.52)
		face.mesh = quad
		face.material_override = door_mat
		_gate.add_child(face)
		face.position.z = side * 0.125
		face.rotation.y = PI if side < 0 else 0.0
	for y in [-0.85, -0.3, 0.3, 0.85]:
		_box("BulkheadReinforcement", Vector3(0, y, -0.17), Vector3(1.68, 0.12, 0.1), _dark, _gate)
		_box("BulkheadInsideReinforcement", Vector3(0, y, 0.17), Vector3(1.68, 0.12, 0.1), _dark, _gate)
	_gate_blocker = _solid("ContainmentBulkheadBlocker", Vector3(0, 1.3, -3), Vector3(1.86, 2.6, 0.32))
	_gate_blocker.disabled = true
	_gate_sound = AudioStreamPlayer3D.new()
	_gate_sound.name = "BulkheadSlam"
	_gate_sound.stream = load(AUD + "blast_door_slam.wav")
	_gate_sound.volume_db = -7.0
	_gate_sound.max_distance = 22.0
	_gate_sound.unit_size = 4.0
	_gate_sound.bus = MASTER
	add_child(_gate_sound)
	_gate_sound.position = Vector3(0, 1.3, -3)
	# The glimpse puppet waits in the duct from the start; it is only ever SEEN from here.
	_hand = HandScript.new()
	_hand.name = "ApproachHandGlimpse"
	add_child(_hand)
	# the shoulder sits low in the duct and toward its lane side, so ~0.7 m of arm hangs out
	if not _hand.setup(_creature_material(), Vector3(HAND_DUCT_X + 0.2, 2.12, HAND_Z)):
		_hand.queue_free()
		_hand = null


# The real creature's material, read (never written): the puppet duplicates it.
func _creature_material() -> StandardMaterial3D:
	var level := get_parent()
	var creature: Node = level.get("_creature") if level else null
	if creature and creature.get("_material") is StandardMaterial3D:
		return creature.get("_material")
	return null


# ============================================================== the seal

func seal_immediate() -> void:
	completed = true
	_gate.position.y = 1.27
	_gate_blocker.set_deferred("disabled", false)
	_stop_all()


func _commit() -> void:
	# Player is fully clear before the blocker activates. No camera/input lock.
	completed = true
	_gate_blocker.set_deferred("disabled", false)
	_stop_all()
	var tween := create_tween()
	tween.tween_property(_gate, "position:y", 1.27, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_gate_sound.play)
	committed.emit()


# Everything the approach owns stops at the seal: speakers, the bed, the machinery, timelines,
# queued story beats, dips, and the puppet. The level's beds go back to their approach level
# BEFORE `committed` fires, so the level's own restore is the last word.
func _stop_all() -> void:
	_timeline.clear()
	_story_queue.clear()
	for t in _tweens:
		if t is Tween and t.is_valid():
			t.kill()
	_tweens.clear()
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	_players.clear()
	if is_instance_valid(_vent):
		_vent.stop()
	if is_instance_valid(_music):
		_music.stop()
		_music.queue_free()
	_music = null
	if is_instance_valid(_face):
		_face.queue_free()
	_face = null
	if is_instance_valid(_pa):
		_pa.stop()
	if is_instance_valid(_shutter_speaker):
		_shutter_speaker.stop()
	for bed in _level_beds:
		if is_instance_valid(bed):
			bed.volume_db = _level_beds[bed]
	_duck_db = 0.0
	_duck_target = 0.0
	for lamp in _pump_lamps + [_door_lamp]:
		if not lamp.is_empty():
			_light_on(lamp, true)
	if is_instance_valid(_hand):
		_hand.queue_free()
	_hand = null
	# pass 3
	if wheel_engaged:
		_release_wheel()
	if is_instance_valid(_wheel_grind):
		_wheel_grind.stop()
	if is_instance_valid(_grille):
		_grille.queue_free()
	_grille = null
	if is_instance_valid(_spark_light):
		_spark_light.visible = false
	for fx in _spark_fx:
		if fx is MeshInstance3D and is_instance_valid(fx):
			fx.visible = false
	_spark_queue.clear()
	if is_instance_valid(_dark_bed):
		_dark_bed.stop()
	if is_instance_valid(_cctv_video):
		_cctv_video.stop()
	for child in get_children():
		if child is AudioStreamPlayer3D and String(child.name) in ["SparkBuzz", "CRTHum"]:
			child.stop()


# ============================================================== the loop

func _process(delta: float) -> void:
	if not _configured or completed or not is_instance_valid(_player):
		return
	_time += delta
	var p := _player.global_position
	if p.z >= -1.5 and absf(p.x) < 2.0:
		_commit()
		return
	_tick_timeline()
	_tick_lamps(p)
	_tick_triggers(p)
	_tick_story()
	_tick_hand(p)
	_tick_machinery(p)
	_tick_audio(delta)
	_tick_wheel(delta)
	_tick_sparks(p)
	_tick_dark_bed(delta)
	_tick_glass(p)
	_tick_cctv(delta)
	_tick_shutter(p)
	_tick_drop(delta)


func _tick_timeline() -> void:
	var i := 0
	while i < _timeline.size():
		var e: Array = _timeline[i]
		if _time >= float(e[0]):
			_timeline.remove_at(i)
			(e[1] as Callable).call()
		else:
			i += 1


func _at(delay: float, fn: Callable) -> void:
	_timeline.append([_time + delay, fn])


func _log_beat(beat: String) -> void:
	beat_log.append({"name": beat, "t": _time, "pos": _player.global_position if is_instance_valid(_player) else Vector3.ZERO})
	var log_node := get_node_or_null("/root/DebugLog")
	if log_node:
		log_node.note("BREACH APPROACH BEAT %s at %.1f s" % [beat, _time])


func _once(beat: String) -> bool:
	if _fired.has(beat):
		return false
	_fired[beat] = true
	return true


func _in_room(p: Vector3, room: String, pad: float = 0.0) -> bool:
	for r in ROOMS:
		if r["name"] == room:
			var c: Vector2 = r["pos"]
			var h: Vector2 = r["size"] * 0.5
			return absf(p.x - c.x) <= h.x + pad and absf(p.z - c.y) <= h.y + pad
	return false


func _camera_dot(target: Vector3) -> float:
	var cam: Camera3D = _player.get_node_or_null("Camera3D")
	if cam == null:
		return 0.0
	return (-cam.global_basis.z).dot((target - cam.global_position).normalized())


# --- positional triggers, in route order ---------------------------------------------------

func _tick_triggers(p: Vector3) -> void:
	if p.x > -91.0 and _in_room(p, "ApproachService") and _once("pa_1"):
		_request_story("pa_1", _play_pa.bind("approach_pa_1", true), 0.9 + 7.7)
	if not _fired.has("self_waking_lamp") and _in_room(p, "ApproachServiceJog") and p.x > -78.5:
		if _camera_dot(_wake_lamp["light"].global_position) >= WAKE_LOOK_DOT or p.x > WAKE_FALLBACK_X:
			_once("self_waking_lamp")
			_self_waking_lamp()
	if p.z > -63.0 and _in_room(p, "ApproachPumpReturn") and _once("door_tell"):
		_request_story("door_tell", _door_tell, 4.2)
	if p.x < -56.0 and _in_room(p, "ApproachObservation") and _once("shutter"):
		# ⭐ 2026-09-24 (the user reversed it): the FIRST opening shows the face. Arming only: the first
		# cycle waits in `_tick_shutter()` until the player is looking at the niche, so it is never spent
		# on a back.
		_log_beat("shutter")
		_shutter_next = _time
	if not _smashed_sputter.is_empty() and p.distance_to(_smashed_sputter["pos"]) < 5.0 and _once("smashed_lamp"):
		_log_beat("smashed_lamp")
		_sputter()
	if p.x < -72.0 and _in_room(p, "ApproachObservation") and _once("pa_2"):
		_request_story("pa_2", _play_pa.bind("approach_pa_2", false), 8.8)
	if Vector2(p.x - _grating_pos.x, p.z - _grating_pos.z).length() < 0.8 and _once("grating"):
		_log_beat("grating")
		_it_hears_you()
	if p.x > -61.0 and _in_room(p, "ApproachPlenum") and _once("victim"):
		_request_story("victim", _victim, 12.3)
	if p.x > -15.0 and _in_room(p, "ApproachContainment") and _once("pa_3"):
		_request_story("pa_3", _play_pa.bind("approach_pa_3", false), 2.7)
	if _in_room(p, "ApproachDarkRoom", -0.3) and _once("dark_room"):
		_log_beat("dark_room")
	if _in_room(p, "ApproachCell12", -0.3) and _once("cell_chamber"):
		_log_beat("cell_chamber")
	if _in_room(p, "ApproachContainment", -0.2) and p.x > DROP_TRIGGER_X and p.x < DROP_PIVOT.x \
			and _once("ceiling_drop"):
		_ceiling_drop()
	if _in_room(p, "ApproachThreshold", -0.2) and p.z > -22.8 and _once("threshold_quiet"):
		_log_beat("threshold_quiet")
		_threshold_quiet = true
		_duck_to(THRESHOLD_DUCK_DB, 1.5)


# --- the one story channel -----------------------------------------------------------------
# PA lines, the door tell and the victim never talk over each other: a beat triggered while
# another is playing waits its turn. That is what lets a straight 4 m/s walk (which crosses the
# Plenum and Containment inside one victim sequence) still hear every line, in order.

func _request_story(beat: String, fn: Callable, duration: float) -> void:
	_story_queue.append([beat, fn, duration])


func _tick_story() -> void:
	if _story_queue.is_empty() or _time < _story_busy_until + STORY_GAP:
		return
	var e: Array = _story_queue.pop_front()
	_story_busy_until = _time + float(e[2])
	_log_beat(e[0])
	(e[1] as Callable).call()


func _story_idle(quiet: float) -> bool:
	return _story_queue.is_empty() and _time >= _story_busy_until + quiet and _time >= _tail_until + quiet


# ============================================================== the beats

# A PA line is playing, or its chime is (the music makes room for the tannoy's words).
func _pa_active() -> bool:
	return _time < _pa_chime_until or (is_instance_valid(_pa) and _pa.playing)


func _play_pa(base: String, chime: bool) -> void:
	if not is_instance_valid(_pa):
		_pa = AudioStreamPlayer.new()
		_pa.name = "ApproachPA"
		_pa.volume_db = PA_DB
		_pa.bus = MASTER
		add_child(_pa)
	var line := load(AUD + base + ".wav")
	if chime:
		# KONTUR's own chime: the same building, still talking.
		_pa_chime_until = _time + 1.0
		_play_flat(GameState.load_audio("pa_kontur_chime"), PA_DB)
		_at(0.9, func() -> void:
			_pa.stream = line
			_pa.play())
	else:
		_pa.stream = line
		_pa.play()


# A2 — the distant door tell, mirroring breach_door_scare.gd: batter roar and pounding (muffled,
# through the wall) → 1.2 s of silence → the local lamps dip for the last 0.8 s → the crash.
func _door_tell() -> void:
	# ⭐ PASS 3: the source is the battered door itself, behind the grille (it was a point in the
	# void behind the east wall). Still low-passed: it comes through louvres and a wall.
	var src := Vector3(ISO_DOOR_X + 0.1, 1.4, ISO_DOOR_Z)
	var roar := _one_shot(src, GameState.load_audio("breach_voice_batter"), MASTER, -4.0, 6.0, 45.0, 1400.0)
	var thud := GameState.load_audio("door_batter")
	for i in GRILLE_HITS:
		_at(i * GrilleScript.BEAT, func() -> void: _one_shot(src, thud, MASTER, -2.0, 6.0, 45.0, 1400.0))
	if is_instance_valid(_grille):
		_grille.batter(GRILLE_HITS)
		_log_beat("door_tell_grille_batter")
	_at(3.0, func() -> void:
		if is_instance_valid(roar):
			roar.stop()
		_log_beat("door_tell_silence")
		if is_instance_valid(_grille):
			_grille.still()
		_silence(1.2, -32.0))
	_at(3.4, func() -> void:
		_log_beat("door_tell_dark")
		if is_instance_valid(_grille):
			_grille.lights_out()
		for lamp in _pump_lamps + [_iso_lamp]:
			_light_on(lamp, false))
	_at(4.2, func() -> void:
		_log_beat("door_tell_crash")
		for lamp in _pump_lamps + [_iso_lamp]:
			_light_on(lamp, true)
		# the lights come back on an empty room and a door hanging broken open
		if is_instance_valid(_grille):
			_grille.queue_free()
			_grille = null
			_log_beat("door_tell_grille_gone")
		if is_instance_valid(_iso_door):
			_iso_door.rotation = Vector3(0.0, deg_to_rad(100.0), deg_to_rad(4.0))   # burst AWAY, into the black
		_one_shot(src, load(AUD + "approach_door_crash.wav"), MASTER, -3.0, 6.0, 45.0, 2600.0))
	_tail_until = _time + 8.2


func _self_waking_lamp() -> void:
	_log_beat("self_waking_lamp")
	_wake_performing = true
	var pos: Vector3 = _wake_lamp["light"].global_position
	_one_shot(pos, load(AUD + "approach_lamp_on.wav"), MASTER, 6.0, 5.0, 40.0)
	_light_on(_wake_lamp, true)
	_at(0.06, func() -> void: _light_on(_wake_lamp, false))
	_at(0.12, func() -> void: _light_on(_wake_lamp, true))
	_at(WAKE_HOLD, func() -> void:
		_log_beat("self_waking_lamp_dies")
		_one_shot(pos, load(AUD + "approach_lamp_die.wav"), MASTER, -2.0, 5.0, 40.0)
		_light_on(_wake_lamp, false))
	_at(WAKE_HOLD + 0.08, func() -> void: _light_on(_wake_lamp, true))
	_at(WAKE_HOLD + 0.2, func() -> void: _light_on(_wake_lamp, false))
	_at(WAKE_HOLD + 0.26, func() -> void: _light_on(_wake_lamp, true))
	_at(WAKE_HOLD + 0.45, func() -> void:
		_light_on(_wake_lamp, false)
		_wake_performing = false)


# ⭐ PASS 4, REVERSED 2026-09-24 by the user (*"now you can see the creature the second time the door
# opens, and the first time it opens you cannot see it. Let's make it vice versa"*): the FIRST opening
# shows the face, and it waits until the player is looking at the niche. The face stays still, turned
# to them, through the hold, and the roll comes down over it. Every later cycle is empty, while the
# player stays near bay B. Once per run.
func _cycle_shutter(face: bool = false) -> void:
	_shutter_busy = true
	_shutter_cycles += 1
	if face and is_instance_valid(_face):
		var cam: Camera3D = _player.get_node_or_null("Camera3D")
		_face.reveal(cam.global_position if cam else _player.global_position)
		_face_cycle = _shutter_cycles
		_log_beat("shutter_face")
		var breath := _one_shot(_niche_centre + Vector3(0, 0.2, 0), load(AUD + SND_FACE_BREATH + ".wav"), MASTER, -14.0, 2.0, 18.0)
		if breath:
			breath.pitch_scale = 0.8
	var motor := load(AUD + "approach_shutter_motor.wav")
	_shutter_speaker.stream = motor
	_shutter_speaker.play()
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_property(_shutter_pivot, "scale:y", 0.04, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.5)
	tw.tween_callback(func() -> void:
		_shutter_speaker.stream = motor
		_shutter_speaker.play())
	tw.tween_property(_shutter_pivot, "scale:y", 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_one_shot(_shutter_speaker.global_position, load(AUD + "approach_mach_relay_clunk.wav"), AMBIENCE, -6.0, 5.0, 30.0)
		if face and is_instance_valid(_face):
			_face.queue_free()
			_face = null
			_face_done = true
			_log_beat("shutter_face_gone")
		_shutter_busy = false
		_shutter_next = _time + _rng.randf_range(1.5, 3.0))


func _tick_shutter(p: Vector3) -> void:
	if not _fired.has("shutter") or _shutter_busy or _time < _shutter_next:
		return
	if _shutter_cycles >= SHUTTER_MAX_CYCLES or p.distance_to(SHUTTER_WINDOW) > SHUTTER_NEAR:
		return
	var cam: Camera3D = _player.get_node_or_null("Camera3D")
	var looking := cam != null and _camera_dot(_niche_centre) >= FACE_LOOK_DOT \
		and cam.global_position.distance_to(_niche_centre) <= FACE_LOOK_DIST
	if _shutter_cycles == 0 and not _face_done and is_instance_valid(_face):
		# the FIRST opening is the face's, and it waits for the look
		if looking:
			_cycle_shutter(true)
		return
	_cycle_shutter(false)     # every later cycle is empty


func _sputter() -> void:
	var spark: OmniLight3D = _smashed_sputter["light"]
	_one_shot(spark.global_position, load(AUD + "approach_lamp_die.wav"), MASTER, -12.0, 4.0, 25.0)
	for spec in [[0.0, true], [0.06, false], [0.19, true], [0.24, false]]:
		_at(spec[0], func() -> void: spark.visible = spec[1])


# A4 — it hears you.
func _it_hears_you() -> void:
	_one_shot(_grating_pos + Vector3(0, 0.1, 0), load(AUD + "approach_grating_clang.wav"), MASTER, -3.0, 4.0, 30.0)
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_property(_grating, "rotation:x", 0.045, 0.05)
	tw.tween_property(_grating, "rotation:x", -0.025, 0.08)
	tw.tween_property(_grating, "rotation:x", 0.0, 0.1)
	_at(2.0, func() -> void:
		_log_beat("duct_knocks")
		var x := clampf(_player.global_position.x + 1.0, -92.0, -66.0)
		var at := Vector3(x, 2.14, -27.55)
		_one_shot(at, load(AUD + "approach_duct_knocks.wav"), MASTER, 0.0, 5.0, 35.0)
		_dust(at + Vector3(0, -0.24, 0), 1.2)
		_one_shot(at, load(AUD + "approach_dust.wav"), AMBIENCE, -4.0, 3.0, 20.0)
		_at(2.0, _duct_crawl.bind(x)))


func _duct_crawl(from_x: float) -> void:
	_log_beat("duct_crawl")
	var start := Vector3(from_x, 2.14, -27.55)
	var end := Vector3(-63.0, 2.14, -27.55)
	var sp := _one_shot(start, load(AUD + "approach_duct_crawl.wav"), MASTER, -1.0, 5.0, 35.0)
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_property(sp, "position", end, 4.3)
	for i in 3:
		var t := 0.8 + i * 1.2
		var x := lerpf(from_x, end.x, t / 4.3)
		_at(t, _dust.bind(Vector3(x, 1.9, -27.55), 0.8))
	_tail_until = maxf(_tail_until, _time + 4.3)


# A5 — the victim behind the porthole door, and the building answering.
func _victim() -> void:
	var behind := Vector3(PORTHOLE_X, 1.3, -34.0)
	var deep := Vector3(PORTHOLE_X, 1.5, -36.5)
	_victim_shot(behind, load(AUD + "approach_victim_hammer.wav"), MASTER, -2.0, 5.0, 45.0, 3200.0)
	_at(3.4, func() -> void:
		_log_beat("victim_roar")
		_victim_shot(deep, load(AUD + "approach_victim_roar.wav"), MASTER, 4.0, 6.0, 50.0)
		for spec in [[0.0, false], [0.09, true], [0.5, false], [0.62, true], [1.05, false], [1.13, true]]:
			_at(spec[0], _light_on.bind(_door_lamp, spec[1])))
	_at(5.6, func() -> void:
		_log_beat("victim_scream")
		_victim_shot(behind, load(AUD + "approach_victim_scream.wav"), MASTER, -8.0, 5.0, 45.0, 3200.0))
	_at(8.3, func() -> void:
		_victim_shot(behind, load(AUD + "approach_building_scream.wav"), MASTER, -2.0, 6.0, 50.0, 4200.0))
	_at(8.5, _building_answers)
	_at(11.2, func() -> void:
		_log_beat("victim_thump")
		var thud := _victim_shot(behind + Vector3(0, -0.8, 0), GameState.load_audio("impact_thud"), MASTER, 2.0, 6.0, 40.0, 2400.0)
		if thud:
			thud.pitch_scale = 0.7
		_log_beat("victim_silence")
		_silence(1.1, -30.0))
	_at(12.3, func() -> void:
		_log_beat("victim_drag")
		var sp := _victim_shot(Vector3(PORTHOLE_X, 0.4, -34.0), load(AUD + "approach_drag.wav"), MASTER, 1.0, 5.0, 40.0, 2600.0)
		var tw := create_tween()
		_tweens.append(tw)
		# ⭐ PASS 3: it recedes the way the player will follow — across the dark room to its far door
		tw.tween_property(sp, "position", Vector3(-29.0, 0.4, -36.5), 4.3))
	_tail_until = _time + 16.6
	_mach_next = maxf(_mach_next, _time + 18.0)


# A victim-scene one-shot: the same as `_one_shot`, and remembered with its gain so it can DUCK under
# the technician's beat (pass 5) rather than being cut.
func _victim_shot(pos: Vector3, stream: AudioStream, bus: String, gain: float, unit: float,
		max_dist: float, cutoff: float = 20500.0) -> AudioStreamPlayer3D:
	var sp := _one_shot(pos, stream, bus, gain, unit, max_dist, cutoff)
	if sp:
		_victim_speakers.append([sp, gain])
		sp.volume_db = gain + _victim_duck_db
	return sp


func _building_answers() -> void:
	_log_beat("building_answers")
	for i in _receivers.size():
		var at: Vector3 = _receivers[i]
		_at(i * 0.14, func() -> void:
			var ring := _victim_shot(at, load(AUD + "approach_receiver_ring.wav"), MASTER, -7.0, 5.0, 35.0)
			if ring:
				ring.pitch_scale = 0.9 + 0.07 * i)
	_victim_shot(_housing.global_position, load(AUD + "approach_duct_rattle.wav"), MASTER, -3.0, 5.0, 35.0)
	var tw := create_tween()
	_tweens.append(tw)
	for k in 8:
		tw.tween_property(_housing, "rotation:z", 0.06 * (1 if k % 2 == 0 else -1) * (1.0 - k / 8.0), 0.07)
	tw.tween_property(_housing, "rotation:z", 0.0, 0.07)
	_at(0.35, func() -> void:
		_victim_shot(Vector3(-50, 4.4, -28.8), GameState.load_audio("pipe_groan"), MASTER, -6.0, 6.0, 40.0))
	for x in [-57.0, -46.0, -35.0]:
		_dust(Vector3(x, 3.6, -23.45), 1.6)
	_victim_shot(Vector3(-46, 3.6, -23.8), load(AUD + "approach_dust.wav"), AMBIENCE, 0.0, 4.0, 25.0)
	var grow := create_tween()
	_tweens.append(grow)
	grow.tween_property(_residue_growth, "scale", Vector3.ONE, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---- the glimpse ---------------------------------------------------------------------------

func _tick_hand(p: Vector3) -> void:
	if _fired.has("hand") or not is_instance_valid(_hand) or _hand.is_yanking():
		return
	if not (_in_room(p, "ApproachThreshold", -0.2) and p.z > -22.8):
		return
	var target: Vector3 = _hand.hand_point()
	var cam: Camera3D = _player.get_node_or_null("Camera3D")
	var d := cam.global_position.distance_to(target) if cam else 99.0
	if d < HAND_MIN_DIST:
		# walked past without ever looking: it goes, unseen and unheard
		_once("hand")
		_log_beat("hand_skipped")
		_hand.yank(func() -> void: pass)
		return
	if d > HAND_MAX_DIST or _camera_dot(target) < HAND_LOOK_DOT or not _story_idle(HAND_QUIET):
		return
	_once("hand")
	hand_fire_distance = d
	_log_beat("hand")
	# The scream follows the hand up into the duct and away along it.
	var sp := _one_shot(target, load(AUD + "approach_hand_scream.wav"), MASTER, -3.0, 6.0, 40.0)
	if sp:
		var tw := create_tween()
		_tweens.append(tw)
		tw.tween_interval(HandScript.LOOK_HOLD)
		tw.tween_property(sp, "position", target + Vector3(0, 0.8, 0), HandScript.WITHDRAW)
		tw.tween_property(sp, "position", target + Vector3(0, 0.8, 6.0), 2.5)
	_hand.yank(func() -> void: _log_beat("hand_gone"))


# ============================================================== pass 3: the technician

# ⭐ PASS 5 (2026-09-24, the user: "Take the wheel button is not active at first. Let's make it active
# straight away"): he answers AT ONCE. The old gate waited out the victim sequence behind the porthole
# door (12.3 s, and its drag) so it could not bury the whisper; now the victim scene DUCKS under his
# beat instead (`VICTIM_TECH_DUCK`, `_victim_shot`), and is never cut.
func _technician_can() -> bool:
	return not handle_taken and not _tech_busy


func _on_technician_interact() -> void:
	if not _technician_can() or not _once("technician"):
		return
	_tech_busy = true
	_log_beat("technician")
	# ⭐ PASS 5 (the user: "after we press an E something like a scream of this man should appear,
	# followed by this 'Don't go in there'"): the grip, then his eyes open WITH the scream, then the
	# whisper, then the eyes close. The music, the beds and the victim scene duck under all of it.
	var scream: AudioStream = load(AUD + SND_TECH_SCREAM + ".wav")
	var scream_len := scream.get_length() if scream else 0.0
	var whisper: AudioStream = load(AUD + SND_WHISPER + ".wav")
	var words := whisper.get_length() if whisper else 2.5
	var whisper_at := 0.5 + scream_len + 0.25
	_tech_beat_until = _time + whisper_at + words + 0.3
	_whisper_until = _tech_beat_until
	_story_busy_until = maxf(_story_busy_until, _time + whisper_at + words + 0.8)
	_mach_next = maxf(_mach_next, _time + whisper_at + words + 4.0)
	# the grip: the dead hands pull the wheel back against his chest, twice, for ~0.5 s
	var base := _tech_wheel.position
	var tw := create_tween()
	_tweens.append(tw)
	# (a small pull: the rim is 4 cm off the relief and must never pass through it)
	tw.tween_property(_tech_wheel, "position", base + Vector3(-0.01, -0.012, -0.012), 0.12)
	tw.tween_property(_tech_wheel, "position", base + Vector3(0.004, 0.0, 0.006), 0.1)
	tw.tween_property(_tech_wheel, "position", base + Vector3(-0.012, -0.016, -0.014), 0.12)
	tw.tween_property(_tech_wheel, "position", base, 0.16)
	_log_beat("technician_grip")
	_at(0.5, func() -> void:
		_tech_mat.albedo_texture = _tech_tex_open
		_log_beat("technician_eyes_open")
		# the scream, from his head: a jolt, on Master
		if scream:
			_one_shot(_tech_head, scream, MASTER, TECH_SCREAM_DB, 2.0, 30.0)
			_log_beat("technician_scream"))
	_at(whisper_at, func() -> void:
		# close and hoarse, from his head: a story beat, on Master
		_one_shot(_tech_head, whisper, MASTER, 3.0, 1.6, 12.0)
		_log_beat("technician_whisper"))
	_at(whisper_at + words + 0.25, func() -> void:
		if is_instance_valid(_tech_wheel):
			_tech_wheel.queue_free()
		_tech_wheel = null
		handle_taken = true
		GameState.set_carried(CARRIED_WHEEL)
		_one_shot(_tech_head + Vector3(0.2, -0.6, 0.2), load(AUD + SND_CLACK + ".wav"), MASTER, -10.0, 1.5, 10.0)
		_log_beat("technician_released"))
	_at(whisper_at + words + 0.8, func() -> void:
		_tech_mat.albedo_texture = _tech_tex_closed
		_tech_busy = false
		_log_beat("technician_eyes_closed"))


func technician_eyes_open() -> bool:
	return _tech_mat != null and _tech_mat.albedo_texture == _tech_tex_open


func technician_material() -> StandardMaterial3D:
	return _tech_mat


# ============================================================== pass 3: the wheel

func _wheel_prompt() -> String:
	if wheel_engaged:
		return "Circle the mouse to turn it  ·  E — let go"
	if handle_fitted:
		return "E — turn the wheel"
	if handle_taken:
		return "E — fit the wheel"
	return "E — try the spindle"


func _on_wheel_interact() -> void:
	if porthole_open or wheel_engaged:
		return
	if not handle_taken:
		# the bare spindle rattles in its collar; nothing turns
		_one_shot(_wheel.global_position, load(AUD + SND_CREAK + ".wav"), AMBIENCE, -12.0, 2.0, 12.0)
		if _time - _wheel_toast_t > 2.0:
			_wheel_toast_t = _time
			ScreenText.toast(get_tree(), "THE WHEEL IS MISSING", Color(0.8, 0.78, 0.7))
		return
	if not handle_fitted:
		handle_fitted = true
		_wheel.visible = true
		GameState.set_carried("")
		_one_shot(_wheel.global_position, load(AUD + SND_CLACK + ".wav"), MASTER, 0.0, 2.0, 16.0)
		if _once("wheel_fitted"):
			_log_beat("wheel_fitted")
	_engage_wheel()


func _engage_wheel() -> void:
	wheel_engaged = true
	_player.freeze_input()
	_wheel_v = Vector2.ZERO
	_wheel_last_ang = INF
	_wheel_pending = 0.0
	if not is_instance_valid(_wheel_grind):
		_wheel_grind = _speaker(_wheel.global_position, AMBIENCE, -60.0, 2.0, 16.0)
		_wheel_grind.name = "WheelGrind"
		_wheel_grind.stream = load(AUD + SND_GRIND + ".wav")
		_wheel_grind.finished.connect(_wheel_grind.play)
	_wheel_grind.volume_db = -60.0
	_wheel_grind.play()


func _release_wheel() -> void:
	wheel_engaged = false
	if is_instance_valid(_player):
		_player.unfreeze_input()
	if is_instance_valid(_wheel_grind):
		_wheel_grind.stop()


# ⚠️ LEVEL-LOCAL INPUT, read BEFORE the player's `_unhandled_input` and swallowed. While turning, the
# player is frozen (`freeze_input()`), so the camera does not move and E does not re-interact. E again,
# a movement key, or Esc lets go.
func _input(event: InputEvent) -> void:
	if not wheel_engaged:
		return
	if event is InputEventMouseMotion:
		_wheel_feed((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_release_wheel()
		get_viewport().set_input_as_handled()
		return
	for action in ["move_forward", "move_back", "move_left", "move_right", "ui_cancel"]:
		if event.is_action_pressed(action):
			_release_wheel()
			return


# ⭐ THE VIRTUAL HAND. It is the SMOOTHED MOTION VECTOR, and the wheel turns by how far its direction
# has turned. A circle of any size, anywhere on the pad, turns it through 2π per loop, and a straight
# line turns it through nothing. A position-based hand would need the circle drawn round a centre
# the player cannot see; this is what makes it forgiving on a trackpad. A reversal (a jump over
# 1.2 rad) counts as nothing, so rubbing back and forth never turns the wheel. Either direction
# works: the first 0.6 rad of consistent turning picks it, and going back the other way unwinds.
func _wheel_feed(rel: Vector2) -> void:
	if rel.length() < 0.05:
		return
	_wheel_v = _wheel_v.lerp(rel, WHEEL_SMOOTH)
	if _wheel_v.length() < WHEEL_MIN_SPEED:
		_wheel_last_ang = INF
		return
	var ang := _wheel_v.angle()
	if _wheel_last_ang != INF:
		var d := wrapf(ang - _wheel_last_ang, -PI, PI)
		if absf(d) <= WHEEL_REVERSAL:
			if _wheel_sign == 0:
				_wheel_pre += d
				if absf(_wheel_pre) >= WHEEL_PICK:
					_wheel_sign = 1 if _wheel_pre > 0.0 else -1
			else:
				_wheel_pending += d * float(_wheel_sign) * WHEEL_GEAR
	_wheel_last_ang = ang


func _tick_wheel(delta: float) -> void:
	if porthole_open or _wheel == null:
		return
	var step := 0.0
	if wheel_engaged:
		wheel_turn_seconds += delta
		# the wheel's stiffness: it turns at most WHEEL_MAX_RATE. ⚠️ The excess is CARRIED, into a
		# small reservoir, never thrown away: discarding it made the feel depend on the frame rate
		# (headless runs several `_process` frames per mouse event and lost ~60 % of every circle).
		var allowed := WHEEL_MAX_RATE * delta
		step = clampf(_wheel_pending, -allowed, allowed)
		_wheel_pending = clampf(_wheel_pending - step, -WHEEL_BANK, WHEEL_BANK)
		if _player.global_position.distance_to(_wheel.global_position) > WHEEL_REACH:
			_release_wheel()
	if step > 0.0005:
		_wheel_idle = 0.0
	else:
		_wheel_idle += delta
	wheel_progress = maxf(0.0, wheel_progress + step)
	if _wheel_idle > WHEEL_DRIFT_DELAY and wheel_progress > 0.0:
		wheel_progress = maxf(0.0, wheel_progress - WHEEL_DRIFT * delta)
	_wheel_speed = lerpf(_wheel_speed, absf(step) / maxf(delta, 0.0001), 0.2)
	var idx := int(floor(wheel_progress / WHEEL_CREAK_STEP))
	if idx > _wheel_creak_idx:
		_wheel_creak_idx = idx
		var creak := _one_shot(_wheel.global_position, load(AUD + SND_CREAK + ".wav"), AMBIENCE, -4.0, 2.0, 14.0)
		if creak:
			creak.pitch_scale = _rng.randf_range(0.9, 1.1)
	elif idx < _wheel_creak_idx:
		_wheel_creak_idx = idx
	if is_instance_valid(_wheel_grind) and _wheel_grind.playing:
		_wheel_grind.volume_db = lerpf(-40.0, -6.0, clampf(_wheel_speed / WHEEL_MAX_RATE, 0.0, 1.0))
	_wheel.rotation.z = -wheel_progress * float(_wheel_sign if _wheel_sign != 0 else 1)
	if wheel_progress >= WHEEL_TURNS * TAU:
		_open_porthole(false)


# Three turns in: the bolts draw back into the hub, a pause, and the door heaves open inward.
func _open_porthole(instant: bool) -> void:
	porthole_open = true
	if wheel_engaged:
		_release_wheel()
	if _wheel:
		_wheel.visible = true
	for entry in _bolts:
		var bar: Node3D = entry[0]
		bar.position.x -= float(entry[1]) * 0.3
	if instant:
		wheel_progress = WHEEL_TURNS * TAU
		_porthole_pivot.rotation.y = deg_to_rad(100.0)
		return
	if _once("porthole_open"):
		_log_beat("porthole_open")
	var door_at := Vector3(PORTHOLE_X, 1.2, -33.0)
	_one_shot(door_at, load(AUD + SND_BOLTS + ".wav"), MASTER, -3.0, 4.0, 30.0)
	_at(0.7, func() -> void:
		_log_beat("porthole_swung")
		_one_shot(door_at, load(AUD + SND_SWING + ".wav"), MASTER, 2.0, 4.0, 30.0)
		var tw := create_tween()
		_tweens.append(tw)
		tw.tween_property(_porthole_pivot, "rotation:y", deg_to_rad(7.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.3)
		tw.tween_property(_porthole_pivot, "rotation:y", deg_to_rad(100.0), 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))


func porthole_leaf_angle() -> float:
	return rad_to_deg(_porthole_pivot.rotation.y) if _porthole_pivot else 0.0


# ============================================================== pass 3: the dark room at runtime

# ⚠️ THE APPROACH'S ONE PANIC TERM (the user's call, 2026-09-23). While the player is inside the dark
# room, panic climbs at DARK_PANIC_RATE against the player's own decay and STOPS at DARK_PANIC_CAP.
# It is held there every physics frame, so nothing (not even sprinting, +6/s) can carry it to 50:
# it never kills here. Outside the room this does nothing and normal decay drains it.
# ⚠️ `_physics_process`, not `_process`: the player's decay runs per physics step too, and this node
# is later in the tree, so each step ends with the cap applied.
const PANIC_MAX := 50.0   # player.gd:PANIC_MAX

func _physics_process(delta: float) -> void:
	if not _configured or completed or not is_instance_valid(_player):
		return
	_in_dark = _in_room(_player.global_position, "ApproachDarkRoom", -0.3)
	if not _in_dark:
		return
	var panic: float = _player.get_panic_ratio() * PANIC_MAX
	if panic < DARK_PANIC_CAP:
		_player.add_panic(minf(DARK_PANIC_RATE * delta, DARK_PANIC_CAP - panic))
	elif panic > DARK_PANIC_CAP:
		_player.relieve_panic(panic - DARK_PANIC_CAP)
	dark_panic_peak = maxf(dark_panic_peak, _player.get_panic_ratio() * PANIC_MAX)


# Random bursts: 1–3 flashes of 0.06–0.12 s, 0.03–0.09 s apart, then 0.5–2.4 s of dark (one gap
# in five runs 2.6–4.8 s). Heard through the closed door; only run within earshot.
func _tick_sparks(p: Vector3) -> void:
	if _spark_light == null or p.distance_to(_spark_speaker_pos) > 32.0:
		return
	while not _spark_queue.is_empty() and _time >= float(_spark_queue[0][0]):
		_set_spark(bool(_spark_queue.pop_front()[1]))
	if not _spark_queue.is_empty() or _time < _spark_next:
		return
	var t := _time
	for i in _rng.randi_range(1, 3):
		var on := _rng.randf_range(0.06, 0.12)
		_spark_queue.append([t, true])
		_spark_queue.append([t + on, false])
		t += on + _rng.randf_range(0.03, 0.09)
	_spark_next = t + (_rng.randf_range(2.6, 4.8) if _rng.randf() < 0.2 else _rng.randf_range(0.5, 2.4))
	spark_bursts += 1
	var crack := _one_shot(_spark_speaker_pos, load(AUD + SND_SPARK + ".wav"), AMBIENCE, -2.0, 3.0, 22.0)
	if crack:
		crack.pitch_scale = _rng.randf_range(0.85, 1.15)


func _set_spark(on: bool) -> void:
	_spark_light.visible = on
	for fx in _spark_fx:
		if fx is MeshInstance3D:
			fx.visible = on
		elif on and fx is CPUParticles3D:
			(fx as CPUParticles3D).restart()


func spark_light() -> OmniLight3D:
	return _spark_light


func _tick_dark_bed(delta: float) -> void:
	if not is_instance_valid(_dark_bed):
		return
	var target := -12.0 if _in_dark else -60.0
	if _in_dark and not _dark_bed.playing:
		_dark_bed.play()
	_dark_bed.volume_db = move_toward(_dark_bed.volume_db, target, 30.0 * delta)
	if not _in_dark and _dark_bed.playing and _dark_bed.volume_db <= -59.0:
		_dark_bed.stop()


# ============================================================== pass 3: the cell chamber at runtime

func _tick_glass(p: Vector3) -> void:
	# the tank's own shard field (ContainmentCell spreads 102 pieces up to ~2.3 m in front of it)
	if not (p.x > -14.5 and p.x < -12.1 and p.z > -36.4 and p.z < -33.2):
		_glass_last = Vector3(INF, 0, INF)
		return
	if _glass_last.x != INF and Vector2(p.x - _glass_last.x, p.z - _glass_last.z).length() < GLASS_STEP:
		return
	_glass_last = p
	glass_crunches += 1
	var sp := _one_shot(Vector3(p.x, 0.05, p.z), load(AUD + String(SND_GLASS[glass_crunches % 3]) + ".wav"),
		MASTER, -4.0, 2.0, 14.0)
	if sp:
		sp.pitch_scale = _rng.randf_range(0.92, 1.08)


func _tick_cctv(delta: float) -> void:
	if _cctv_stamp == null:
		return
	var before := int(_cctv_clock)
	_cctv_clock += delta
	if int(_cctv_clock) != before:
		_update_cctv_stamp()
	# playback can take a frame or two to hand out its texture
	if _cctv_mat and float(_cctv_mat.get_shader_parameter("has_video")) < 0.5 and is_instance_valid(_cctv_video) \
			and _cctv_video.is_playing():
		var tex := _cctv_video.get_video_texture()
		if tex != null:
			_cctv_mat.set_shader_parameter("video", tex)
			_cctv_mat.set_shader_parameter("has_video", 1.0)


# ============================================================== pass 3: the snapshot

# Carried by `level_6_breach.gd:save_progress()` as "approach_handle_taken" / "approach_porthole_open".
func progress_state() -> Dictionary:
	return {"handle_taken": handle_taken, "porthole_open": porthole_open}


func restore_state(state: Dictionary) -> void:
	if not (bool(state.get("handle_taken", false)) or bool(state.get("porthole_open", false))):
		return
	handle_taken = true
	for beat in ["technician"]:
		_fired[beat] = true
	if is_instance_valid(_tech_wheel):
		_tech_wheel.queue_free()
	_tech_wheel = null
	if bool(state.get("porthole_open", false)):
		handle_fitted = true
		_fired["wheel_fitted"] = true
		_fired["porthole_open"] = true
		_open_porthole(true)
	else:
		GameState.set_carried(CARRIED_WHEEL)


# ============================================================== lamps

func _lamp(pos: Vector3, color: Color, energy: float, radius: float, lit: bool) -> Dictionary:
	var mat := _indicator.duplicate() as StandardMaterial3D
	_box("EmergencyFitting", pos, Vector3(0.65, 0.07, 0.19), mat)
	var light := OmniLight3D.new()
	light.name = "ApproachEmergencyLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	add_child(light)
	light.position = pos - Vector3(0, 0.13, 0)
	var lamp := {"light": light, "mat": mat}
	_light_on(lamp, lit)
	return lamp


# A dark fitting stays dark: its emission is off, so a blackout visibly kills it (emission rule).
func _light_on(lamp: Dictionary, on: bool) -> void:
	if lamp.is_empty() or not is_instance_valid(lamp["light"]):
		return
	(lamp["light"] as Light3D).visible = on
	(lamp["mat"] as StandardMaterial3D).emission_enabled = on


func _cluster(label: String, positions: Array, color: Color) -> void:
	var lamps: Array = []
	for pos in positions:
		lamps.append(_lamp(pos, color, 0.8, 8.0, false))
		_box("LampHanger", pos + Vector3(0, 0.2, 0), Vector3(0.02, 0.4, 0.02), _dark)
	_clusters.append({"name": label, "lamps": lamps, "lit": false})


func _dead_fitting(pos: Vector3) -> void:
	_lamp(pos, Color.WHITE, 0.0, 1.0, false)
	_box("LampHanger", pos + Vector3(0, 0.2, 0), Vector3(0.02, 0.4, 0.02), _dark)
	var tube := _box("DanglingTube", pos + Vector3(0.2, -0.28, 0), Vector3(0.035, 0.6, 0.035), _steel)
	tube.rotation.z = 0.5


func _tick_lamps(p: Vector3) -> void:
	if _wake_performing:
		return   # while the rule is being broken, the rule stays quiet
	for c in _clusters:
		if c["lit"]:
			continue
		for lamp in c["lamps"]:
			var lp: Vector3 = lamp["light"].global_position
			if Vector2(lp.x - p.x, lp.z - p.z).length() <= MOTION_RADIUS:
				_cluster_on(c)
				break


func _cluster_on(c: Dictionary) -> void:
	c["lit"] = true
	if c["name"] == "arrival":
		_log_beat("arrival_lamps")
	var first: Dictionary = c["lamps"][0]
	_one_shot(first["light"].global_position, load(AUD + "approach_lamp_on.wav"), AMBIENCE, 6.0, 5.0, 30.0)
	for lamp in c["lamps"]:
		_light_on(lamp, true)
		_at(0.05, _light_on.bind(lamp, false))
		_at(0.11, _light_on.bind(lamp, true))


# ============================================================== sound beds and machinery (A8)

func _start_beds() -> void:
	_vent = AudioStreamPlayer.new()
	_vent.name = "ApproachVentBed"
	_vent.stream = load(AUD + "approach_vent_bed.wav")
	_vent.volume_db = VENT_DB
	_vent.bus = AMBIENCE
	add_child(_vent)
	_vent.finished.connect(_vent.play)   # every .wav.import here is loop_mode=0
	_vent.play()
	# ⭐ PASS 4: the user's walk-in music, looped from the spawn, on AMBIENCE so every silence beat
	# (HoldBreath.dip) takes it down with the beds; faded out at the Threshold; stopped at the seal.
	var music: AudioStream = load(AUD + "approach_corridor_music.ogg")
	if music:
		if music is AudioStreamOggVorbis:
			(music as AudioStreamOggVorbis).loop = true
		_music = AudioStreamPlayer.new()
		_music.name = "ApproachMusic"
		_music.stream = music
		_music.bus = AMBIENCE
		_music.volume_db = MUSIC_DB
		add_child(_music)
		_music.play()
	for base in MACHINERY:
		_mach_streams[base] = load(AUD + base + ".wav")


func _tick_audio(delta: float) -> void:
	_duck_db = move_toward(_duck_db, _duck_target, _duck_speed * delta)
	if is_instance_valid(_music) and _music.playing:
		# under the story beats, never over them, and furthest under the PA; gone at the Threshold
		# (the hand's corner is silent)
		var target := MUSIC_DB
		if _threshold_quiet:
			target = -60.0
		elif _pa_active():
			target = MUSIC_DB + MUSIC_PA_DUCK
		elif _time < _whisper_until:
			target = MUSIC_DB + MUSIC_WHISPER_DUCK
		elif not _story_idle(0.0):
			target = MUSIC_DB + MUSIC_STORY_DUCK
		var rate := MUSIC_DUCK_DB_S if target < _music_db else MUSIC_FADE_DB_S
		_music_db = move_toward(_music_db, target, rate * delta)
		# + the approach's own silence duck, as the vent gets: HoldBreath refuses a second dip while one
		# is running, and the music must still drop out on a silence beat that lands inside another
		_music.volume_db = _music_db + _duck_db
		if _threshold_quiet and _music_db <= -59.5:
			_music.stop()
	var bed_target := BED_PA_DUCK if ((_pa_active() or _time < _tech_beat_until) and not _threshold_quiet) else 0.0
	# the victim scene behind the porthole door ducks under the technician's beat, never cut
	var vt := VICTIM_TECH_DUCK if _time < _tech_beat_until else 0.0
	_victim_duck_db = move_toward(_victim_duck_db, vt, (40.0 if vt < _victim_duck_db else 8.0) * delta)
	for i in range(_victim_speakers.size() - 1, -1, -1):
		var e: Array = _victim_speakers[i]
		if not is_instance_valid(e[0]):
			_victim_speakers.remove_at(i)
			continue
		(e[0] as AudioStreamPlayer3D).volume_db = float(e[1]) + _victim_duck_db
	_bed_pa_db = move_toward(_bed_pa_db, bed_target, (20.0 if bed_target < _bed_pa_db else 6.0) * delta)
	if is_instance_valid(_vent):
		_vent.volume_db = VENT_DB + VENT_LFO_DB * sin(TAU * _time / VENT_LFO_PERIOD) + _duck_db + _bed_pa_db
	for bed in _level_beds:
		if is_instance_valid(bed):
			bed.volume_db = _level_beds[bed] + _duck_db + _bed_pa_db


func _duck_to(db: float, fade: float) -> void:
	_duck_target = db
	_duck_speed = absf(db - _duck_db) / maxf(0.05, fade)


# A silence beat: the Ambience bus dips through the shared HoldBreath helper, and the level's own
# beds (on Master) dip with it through the local duck. Returns to the Threshold's quiet if the
# player has reached it, otherwise to nothing.
func _silence(hold: float, depth: float) -> void:
	HoldBreath.dip(get_tree(), hold)
	_duck_to(depth, 0.15)
	_at(hold, func() -> void: _duck_to(THRESHOLD_DUCK_DB if _threshold_quiet else 0.0, 0.4))
	_mach_next = maxf(_mach_next, _time + hold + 4.0)


func _tick_machinery(p: Vector3) -> void:
	if _threshold_quiet or _mach_streams.is_empty() or _time < _mach_next:
		return
	if not _story_idle(0.0):
		_mach_next = _time + 1.5
		return
	_mach_next = _time + _rng.randf_range(MACH_GAP.x, MACH_GAP.y)
	var keys: Array = _mach_streams.keys()
	var base: String = keys[_rng.randi() % keys.size()]
	var cam: Camera3D = _player.get_node_or_null("Camera3D")
	var fwd := Vector3(0, 0, -1)
	if cam:
		fwd = -cam.global_basis.z
	var yaw := atan2(-fwd.x, -fwd.z) + PI   # the direction BEHIND the listener
	if _rng.randf() > MACH_BEHIND:
		yaw += _rng.randf_range(PI / 3.0, 2.0 * PI - PI / 3.0)
	else:
		yaw += _rng.randf_range(-PI / 3.0, PI / 3.0)
	var d := _rng.randf_range(MACH_DIST.x, MACH_DIST.y)
	var at := p + Vector3(-sin(yaw) * d, _rng.randf_range(1.0, 3.0), -cos(yaw) * d)
	# unit_size 4: ~-8 dB at 10 m, so the gain puts every one-shot at MACH_TARGET_DB there.
	var sp := _one_shot(at, _mach_streams[base], AMBIENCE, MACH_TARGET_DB - float(MACHINERY[base]) + 8.0, 4.0, 30.0)
	if sp:
		sp.pitch_scale = _rng.randf_range(0.9, 1.1)


# ============================================================== audio helpers

func _speaker(pos: Vector3, bus: String, gain: float, unit: float, max_dist: float,
		cutoff: float = 20500.0) -> AudioStreamPlayer3D:
	var speaker := AudioStreamPlayer3D.new()
	speaker.name = "ApproachSpeaker"
	speaker.volume_db = gain
	speaker.max_db = 6.0
	speaker.max_distance = max_dist
	speaker.unit_size = unit
	speaker.attenuation_filter_cutoff_hz = cutoff
	speaker.bus = bus
	add_child(speaker)
	speaker.position = pos
	return speaker


func _one_shot(pos: Vector3, stream: AudioStream, bus: String, gain: float, unit: float,
		max_dist: float, cutoff: float = 20500.0) -> AudioStreamPlayer3D:
	if stream == null or completed:
		return null
	var sp := _speaker(pos, bus, gain, unit, max_dist, cutoff)
	sp.stream = stream
	_players.append(sp)
	sp.finished.connect(func() -> void:
		_players.erase(sp)
		sp.queue_free())
	sp.play()
	return sp


func _play_flat(stream: AudioStream, gain: float) -> void:
	if stream == null or completed:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = gain
	p.bus = MASTER
	add_child(p)
	_players.append(p)
	p.finished.connect(func() -> void:
		_players.erase(p)
		p.queue_free())
	p.play()


func _dust(pos: Vector3, extent: float) -> void:
	var dust := CPUParticles3D.new()
	dust.name = "DustSift"
	dust.one_shot = true
	dust.amount = 36
	dust.lifetime = 2.6
	dust.explosiveness = 0.55
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(extent * 0.5, 0.03, 0.25)
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 12.0
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.25
	dust.gravity = Vector3(0, -0.9, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	# specks, not squares: a flat quad particle renders as a lit square (the first render)
	var q := SphereMesh.new()
	q.radius = 0.008
	q.height = 0.016
	q.radial_segments = 4
	q.rings = 2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.38, 0.34, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	dust.mesh = q
	add_child(dust)
	dust.position = pos
	dust.emitting = true
	get_tree().create_timer(4.0).timeout.connect(dust.queue_free)


# ============================================================== geometry helpers

# A RoomBuilder doorway is a full-height hole. Where the room on one side is lower than the
# other, fill the hole above the low ceiling, 3 cm proud of both wall faces and 5 cm into each
# jamb so no face is coplanar with a wall, the low ceiling or the tall one (it tops out INSIDE
# the taller room's ceiling slab).
#
# ⚠️ AND IT IS SOLID. The first version was a mesh only, and check_shell_sealed.gd measured 55
# horizontal rays at 2.8 m leaving the level through the gap it only hid. At 2.36 m and up it
# cannot touch the player (a 1.8 m capsule), so a collider here does not seal the doorway.
func _lintel(at: Vector3, width: float, bottom: float, top: float) -> void:
	var along_x := false
	for d in DOORS:
		if Vector2(d["pos"]).distance_to(Vector2(at.x, at.z)) < 0.1:
			along_x = String(d["dir"]) == "z"
	var size := Vector3(width + 0.1, top - bottom, 0.26) if along_x else Vector3(0.26, top - bottom, width + 0.1)
	var centre := Vector3(at.x, (bottom + top) * 0.5, at.z)
	# steel, not near-black: against an unlit room beyond, a black lintel reads as the very void
	# it fills (legibility pass render 13a)
	_box("DoorwayLintel", centre, size, _steel)
	_solid("DoorwayLintelSolid", centre, size)


# Bare torn steel: lighter and shinier than the painted plate, so the torn edges catch the light.
func _torn_metal() -> StandardMaterial3D:
	var m := _material(Color(0.56, 0.56, 0.52), 0.85)
	m.roughness = 0.32
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _pressure_vessel(pos: Vector3, radius: float, height: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 16
	var body := MeshInstance3D.new()
	body.name = "PressureReceiver"
	body.mesh = cylinder
	body.material_override = _rust
	add_child(body)
	body.position = pos + Vector3(0, height * 0.5 + 0.12, 0)
	# ⚠️ P6: THE BUG THE USER WALKED INTO (capture 2, the Plenum). A receiver was a mesh and nothing
	# else. The collider covers the vessel and its foot (the foot is inside its radius).
	var solid := _collide_cylinder(body, radius + 0.07, height + 0.24)
	solid.position = Vector3(0, -0.12, 0)
	for y in [0.32, height - 0.1]:
		var band := TorusMesh.new()
		band.inner_radius = radius - 0.04
		band.outer_radius = radius + 0.07
		band.rings = 16
		band.ring_segments = 8
		var mesh := MeshInstance3D.new()
		mesh.mesh = band
		mesh.material_override = _steel
		add_child(mesh)
		mesh.position = pos + Vector3(0, y, 0)
	_box("ReceiverFoot", pos + Vector3(0, 0.1, 0), Vector3(radius * 1.7, 0.2, radius * 1.7), _dark)
	_box("PressureGauge", pos + Vector3(0, height * 0.65, radius + 0.02), Vector3(0.23, 0.25, 0.09), _steel)
	_box("GaugeFace", pos + Vector3(0, height * 0.65, radius + 0.073), Vector3(0.16, 0.17, 0.01), _indicator)


# Art always on a QuadMesh (Issue 24). `shaded` decals are lit; `alpha` ones are cutouts.
func _quad(label: String, tex: Texture2D, size: Vector2, double_sided: bool, alpha: bool = false,
		parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	var q := QuadMesh.new()
	# size.y <= 0 means "as tall as the art is": the height is DERIVED from the texture's own
	# aspect, so a decal can never be stretched (check_art_aspect.gd caught 1.48x and 1.11x on the
	# first build, when these sizes were typed).
	if size.y <= 0.0 and tex != null and tex.get_width() > 0:
		size.y = size.x * float(tex.get_height()) / float(tex.get_width())
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.85
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi


func _floor_decal(label: String, tex: Texture2D, pos: Vector3, size: Vector2, yaw: float,
		parent: Node3D = null) -> MeshInstance3D:
	var mi := _quad(label, tex, size, false, true, parent)
	mi.position = pos
	mi.rotation = Vector3(-PI / 2.0, yaw, 0)
	(mi.material_override as StandardMaterial3D).roughness = 0.25   # wet: it catches what light there is
	return mi


# A text plate on a thin backing, `emission` of its own texture (0 = lit by the room only).
func _backed_plate(label: String, tex_path: String, pos: Vector3, yaw: float, size: Vector2, emission: float) -> void:
	var root := Node3D.new()
	root.name = label
	add_child(root)
	root.position = pos
	root.rotation.y = yaw
	_box(label + "Backing", Vector3(0, 0, -0.035), Vector3(size.x + 0.06, size.y + 0.06, 0.03), _dark, root)
	var tex := load(tex_path)
	var q := _quad(label + "Face", tex, size, false, false, root)
	if emission > 0.0:
		var m := q.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = emission


# A seal-integrity display: a steel housing and a self-lit screen (dark albedo, emission ≤ 1.0).
func _seal_panel(label: String, tex_path: String, pos: Vector3, yaw: float, emission: float) -> void:
	var root := Node3D.new()
	root.name = label
	add_child(root)
	root.position = pos
	root.rotation.y = yaw
	_box(label + "Housing", Vector3(0, 0, -0.03), Vector3(0.74, 0.48, 0.08), _dark, root)
	var tex := load(tex_path)
	var q := _quad(label + "Screen", tex, Vector2(0.64, 0.4), false, false, root)
	q.position = Vector3(0, 0, 0.025)
	var m := q.material_override as StandardMaterial3D
	m.albedo_color = Color(0.5, 0.5, 0.5)
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = emission


func _sign(text: String, pos: Vector3, yaw: float, scale: float) -> void:
	var label := Label3D.new()
	label.name = "IndustrialWayfinding"
	label.text = text
	label.font_size = 36
	label.pixel_size = scale
	label.modulate = Color(0.57, 0.64, 0.57)
	label.no_depth_test = false
	label.shaded = true
	label.outline_size = 0
	add_child(label)
	label.position = pos
	label.rotation.y = yaw


func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.85
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _box(label: String, pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	(parent if parent != null else self).add_child(mesh)
	mesh.position = pos
	return mesh


func _solid(label: String, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return shape


# ⭐ P6 (2026-09-23): a visual box that is ALSO solid. The first build of this approach had 89
# `_box` visuals and 5 `_solid` colliders, so the user walked straight through the receivers
# ("you can just walk through these objects, they are not like real ones"). The collider is a
# CHILD of the mesh, so it inherits every transform the mesh has — a hinge, a tilt, a tween.
func _solid_box(label: String, pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := _box(label, pos, size, mat, parent)
	_collide(mi, size)
	return mi


func _collide(on: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = String(on.name) + "Solid"
	body.collision_layer = 1
	body.collision_mask = 1
	on.add_child(body)
	body.position = offset
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _collide_cylinder(on: Node3D, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = String(on.name) + "Solid"
	body.collision_layer = 1
	body.collision_mask = 1
	on.add_child(body)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	return body


# An interact volume on LAYER 2 (see breach_approach_proxy.gd), sized to `size` at `pos`.
func _proxy(label: String, pos: Vector3, size: Vector3, on_interact: Callable, can: Callable,
		prompt: Callable, parent: Node3D = null) -> StaticBody3D:
	var body: StaticBody3D = ProxyScript.new()
	body.name = label
	body.collision_layer = 2
	body.collision_mask = 0
	body.on_interact = on_interact
	body.can = can
	body.prompt = prompt
	(parent if parent != null else self).add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _cylinder(label: String, pos: Vector3, radius: float, height: float, mat: Material,
		parent: Node3D = null, top_radius: float = -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = cm
	mi.material_override = mat
	(parent if parent != null else self).add_child(mi)
	mi.position = pos
	return mi
