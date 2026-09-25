extends Node3D

const OPENING_NOTE := "You are Subject 47.\n\nThis is a psychological experiment. Your fear response is being monitored.\n\nThe entity you may encounter is a product of your own mind — it cannot harm you unless you believe it can.\n\nStay calm. Do not touch what you are not meant to touch.\n\nIf something calls out to you — a voice, a ringing, anything that asks for an answer — do not answer it. You are not meant to speak to anyone but us.\n\nThe door ahead is your first test.\n\nWe are watching."

const ENDING_NOTE := "This is not an experiment.\n\nThere is no exit.\n\nThey already know where you are."

const TEX := "res://assets/textures/intro/"
const BASE_ENERGY := 1.8

# The twist ending's reveal — the observation room behind the eight levels, closing the loop the
# Lab's Observation tape opens. It replaces a bare 2 s pause; see _on_ending_note_closed().
# ⚠️ It ends on ~1.5 s of black BY CONSTRUCTION, because `Screamer.trigger_to_menu()` fires the
# instant it finishes and needs somewhere dark to land. If the clip is ever regenerated, keep
# that tail (assets_src/README.md records how it is padded on in transcode).
const ENDING_VIDEO := "res://assets/video/ending_scene.ogv"

# Room + beat geometry. ⭐ THE INTAKE WING (2026-09-24): the ward is one room of six, built by
# `RoomBuilder` from ROOMS / DOORS below (INTRO.md §1's "one room, not RoomBuilder" is superseded —
# six rooms is a graph). The WARD keeps its centre, size, height and every prop; the walls are
# RoomBuilder.T 0.2 thick now (were 0.3), and every constant derived from WALL_T re-derives.
const ROOM_SIZE := Vector2(12.0, 18.0)     # the WARD, x, z
const ROOM_HEIGHT := 3.6
const WING_H := 3.0                        # cell, corridor, hall, airlock

# ⚠️ Rooms ABUT, never overlap (Issues 19/20/23). The ward is x -6..6, z -9..9; the corridor
# runs north off its front wall; the cell and the hall hang off the corridor's west wall and share
# ONE wall with each other (z = 20) — that wall carries the one-way glass. Calibration is south
# of the ward's back wall, the airlock off calibration's west wall.
const WARD := {"name": "Ward", "pos": Vector2(0, 0), "size": Vector2(12, 18), "h": 3.6}
const ROOMS := [
	WARD,
	{"name": "Corridor", "pos": Vector2(-3, 17), "size": Vector2(2.4, 16), "h": WING_H},
	{"name": "Cell", "pos": Vector2(-6.2, 22), "size": Vector2(4, 4), "h": WING_H},
	{"name": "Hall", "pos": Vector2(-7.2, 17), "size": Vector2(6, 6), "h": WING_H},
	{"name": "Calibration", "pos": Vector2(0, -15), "size": Vector2(8, 12), "h": 3.4},
	{"name": "Airlock", "pos": Vector2(-5.5, -18.5), "size": Vector2(3, 3), "h": WING_H},
]
# Every doorway carries a WingDoor of the same name. `h` is the taller of the two rooms, which is
# how high RoomBuilder cuts the opening — the door's infill fills it to there.
# ⚠️ The HALL door is at the SOUTH end of the hall's east wall on purpose: stepping in facing
# west, the glass (x -7.3..-5.1, z 20) is 61-85 degrees off the view axis — outside a 16:9
# frame's half-width of ~54 — so the occupant appearing behind it is not witnessed.
const DOORS := [
	# yaw turns WingDoor's local +z; swing picks which side the leaf opens into. Each open leaf lies
	# along a wall, clear of the route.
	# ⚠️ The CELL door opens OUT, into the corridor. Swung into the cell, its leaf and the foot of
	# the bed walled off the cell's whole south strip — the sink and the tap were unreachable
	# (check_reachable, 2026-09-24: "Tap … nearest cell 1.50 m").
	{"name": "CellDoor", "pos": Vector2(-4.2, 22), "width": 1.2, "dir": "x", "h": WING_H,
		"yaw": -PI / 2.0, "swing": -1.0},
	{"name": "HallDoor", "pos": Vector2(-4.2, 15), "width": 1.2, "dir": "x", "h": WING_H,
		"yaw": -PI / 2.0, "swing": 1.0},
	{"name": "WardEntryDoor", "pos": Vector2(-3, 9), "width": 1.2, "dir": "z", "h": 3.6,
		"yaw": PI, "swing": 1.0},
	{"name": "WardDoor", "pos": Vector2(0, -9), "width": 1.2, "dir": "z", "h": 3.6,
		"yaw": PI, "swing": 1.0},
	{"name": "AirlockDoor", "pos": Vector2(-4, -18.5), "width": 1.2, "dir": "x", "h": 3.4,
		"yaw": PI / 2.0, "swing": -1.0},
]
# Openings that are NOT passages: cut by RoomBuilder like a doorway, then closed below `sill` and
# above `top` with wall, and glazed. Kept out of DOORS so check_doorways / check_note_mounting do
# not treat the glass as a way through.
const WINDOWS := [
	{"name": "ObservationGlass", "pos": Vector2(-6.2, 20), "width": 2.2, "dir": "z",
		"sill": 0.85, "top": 2.1},
]
# The cell. The bed runs north-south with its head at the north wall; the player wakes sitting up
# at the head end, facing south — straight at the one-way glass, which from this side is a dark,
# blank pane.
const CELL_GURNEY_POS := Vector3(-6.4, 0, 22.55)
const CELL_WAKE_POS := Vector3(-6.4, 0.0, 23.1)     # body xz; y is GURNEY_TOP_Y
const CELL_STAND_POS := Vector3(-5.45, 0.05, 22.9)  # beside the bed, once the straps are off
# The bed's restraints, as offsets from CELL_GURNEY_POS (x, z): two wrists beside the hips, the
# ankles. ⭐ Already UNBUCKLED since the third hand playtest (2026-09-25) — scenery, not a beat.
const STRAPS := [Vector2(-0.34, -0.25), Vector2(0.34, -0.25), Vector2(0.0, -0.78)]
const WARD_ENTRY := Vector3(-3, 0, 9)
const WAKEUP_TWEEN_TIME := 1.2           # lying, coming to; + SIT_UP_TIME 0.9 + STAND_TIME 1.2 = 3.3 s
const NIGHTMARE_TEXT := "IT WAS ONLY A DREAM."
const PATH_GLOW_ENERGY := 0.12
const PATH_GLOW_RANGE := 1.4
const PATH_GLOW_Y := 0.35          # fixed low "ankle" height — not the switch's mounting height
const GURNEY_POS := Vector3(0, 0, 7.0)
const GURNEY_TOP_Y := 0.6           # frame top 0.5, mattress top 0.6 — see _build_gurney()
# The two occupied beds. GLIMPSE_GURNEY_POS is deliberately close to the middle ceiling
# tube — see _glimpse_light() for why that tube and not the far one.
const GLIMPSE_GURNEY_POS := Vector3(3.6, 0, 1.8)
const FAR_GURNEY_POS := Vector3(4.5, 0, 6.0)
# ⚠️ The inner face of a wall is HALF A WALL THICKNESS in from its nominal boundary. Every
# prop mounted on a wall in this room is derived from these two, never hand-computed — the
# exit door was placed at a literal z and ended up floating 0.275 m clear of WallBack for
# the life of the project (playtest 2026-08-16 capture #3: "the door is not connected to
# the wall"). RoomBuilder.wall_point() exists for exactly this reason in the graph levels;
# this room is hand-built, so it derives them here instead.
const WALL_T := RoomBuilder.T                                  # 0.2 (was a hand-built 0.3)
const WALL_BACK_FACE_Z := -ROOM_SIZE.y / 2.0 + WALL_T / 2.0    # -8.9
const WALL_LEFT_FACE_X := -ROOM_SIZE.x / 2.0 + WALL_T / 2.0    # -5.9
const WALL_RIGHT_FACE_X := ROOM_SIZE.x / 2.0 - WALL_T / 2.0    #  5.9
# How far a wall-mounted prop's BACK face sits inside the wall. Never 0 — coplanar faces
# z-fight (Issues 19/20/23); a small negative clearance buries the back face instead.
const WALL_BITE := 0.02
# ⚠️ Was a hand-written -5.77, which stood the 0.04-deep plate 0.060 m clear of WallLeft's
# inner face — the same defect as the exit door at a fifth of the scale, and the reason the
# plate shows a floating side edge in the 2026-08-16 capture. Centred here, its back face
# lands 10 mm INSIDE the wall (never coplanar), its face 30 mm proud, and light_switch.gd's
# art quad 36 mm clear of the wall — check_wall_overlap.gd wants at least 20 mm.
const SWITCH_POS := Vector3(WALL_LEFT_FACE_X + 0.01, 1.3, -1.0)
const TABLE_POS := Vector3(0, 0.4, 0.0)
# Panel extents; _corrupt_room() boards across this.
# ⚠️ WIDTH IS DERIVED FROM THE ARTWORK, not chosen (2026-08-15). `intro_lab_door.png` is
# 780x1511 after cropping, i.e. 1:1.937, and a texture squashed onto a mismatched quad is
# SCARY.md §7.1(4) — the same fault that made KONTUR's roster plate render as a stretched
# picture on a box. 2.2 / 1.937 = 1.136. Changing the height means changing the width too.
const DOOR_SIZE := Vector3(1.136, 2.2, 0.15)
# ⚠️ DERIVED, never a literal. The leaf's BACK face lands WALL_BITE inside WallBack, which
# is exactly the convention level_1.gd / level_2.gd / kontur.gd / dungeon.gd already use.
# It was a hand-written -8.5 until 2026-08-16 and the leaf floated 0.275 m clear of the
# wall, full height, full width, with open air behind it — measured with sideways rays at
# four heights, all clear. That also dragged the game's FINAL beat with it, because
# _corrupt_room()'s planks are derived from this constant (correctly) and inherited the
# error: they hung 0.485 m in front of blank concrete.
const EXIT_DOOR_POS := Vector3(0, 1.1, WALL_BACK_FACE_Z - WALL_BITE + DOOR_SIZE.z / 2.0)
# ⭐ The Intake Wing: the advancing `ExitDoor` is in the AIRLOCK now, seated into its south wall
# (z = -20) by the same derivation. EXIT_DOOR_POS above is where it stands in the TWIST ENDING,
# which builds the ward alone and boards that door over exactly as before.
const AIRLOCK_EXIT_POS := Vector3(-5.5, 1.1, -20.0 + WALL_T / 2.0 - WALL_BITE + DOOR_SIZE.z / 2.0)
# The casing — two jambs and a lintel standing proud of the wall, lapping CASING_LAP over
# the leaf's edges so the leaf reads as RECESSED INSIDE a frame rather than stuck on a flat
# wall. The lap is what removes every coplanar face between casing and leaf.
const CASING_W := 0.14              # jamb width / lintel height
const CASING_D := 0.24              # WALL_BITE inside the wall … 0.09 proud of the leaf face
const CASING_LAP := 0.018
const WHEELCHAIR_POS := Vector3(2.4, 0.0, -3.0)    # floor anchor — open floor between the table and the door
# ⚠️ z DERIVED (was a literal -8.77, which the 0.3 -> 0.2 wall change would have left 13 cm off
# the wall): 3 cm proud of the back wall's face, clear of the ward door's frame at x ±0.8.
const WALL_CHART_POS := Vector3(3.5, 1.8, WALL_BACK_FACE_Z + 0.03)
# ⚠️ Sized from `wall_chart_intro.png` (1402x1122 = 1.2496), not chosen. At the old
# 0.6 x 0.9 the chart was squashed 1.87x onto a PORTRAIT quad and its text — a legible
# patient observation chart, the only readable environment storytelling in the room — was
# unreadable at any distance.
const WALL_CHART_SIZE := Vector2(1.125, 0.90)
# The torn page's own sub-rect inside `intro_note.png`'s square, black-backed canvas, and
# the sheet size derived from it: 0.297 * (0.835 / 0.970) = 0.2557. See _build_table_note_candle().
const NOTE_UV_OFFSET := Vector2(0.085, 0.015)
const NOTE_UV_SCALE := Vector2(0.835, 0.970)
const NOTE_SIZE := Vector2(0.2557, 0.297)
# ⭐ 0.30 since 2026-09-24 (was 0.22): the ward is DRESSED now and at 0.22 its furniture was a
# silhouette. Post-switch only — the blind walk and the glimpse happen at ambient 0 (measured).
const NORMAL_AMBIENT := 0.30
# ⚠️ …AND A COLOUR, because the energy alone is a dead lever here: the shared environment's
# ambient colour is (0.04, 0.03, 0.02), and measured, even energy 1.0 moved the lit ward's frame
# 13.1 -> 13.3 of 255. The switch tweens the colour too, so only the LIT ward changes; before the
# switch (the blind walk, the glimpse) the colour is the shared one and the energy is 0.
const LIT_AMBIENT_COLOR := Color(0.28, 0.29, 0.31)
# ⭐ The panic CEILING (2026-09-24, the Intake Wing). The bar may move here — calibration teaches
# it — but player.set_panic_ceiling() pins it at 60 % of PANIC_MAX, so the screamer is unreachable
# by construction. It also closes the old hole: sprint +6/s had no level-0 exemption and ~8.3 s of
# Shift killed you in the one room with no fail state. check_intro_panic_ceiling.gd.
const PANIC_CEILING := 0.6

# --- "the ward is occupied" (2026-07-28) ---------------------------------------------
# This room had ZERO scares: no panic source, no RandomAmbient, no ApparitionDirector, no
# objective line — 60-120 s of nothing, which is a full level's worth of dead air relative
# to everything after it. Everything added below is DREAD ONLY: the intro has never had a
# fail state and deliberately still doesn't, so nothing here calls add_panic().
const SWITCH_PRESSES := 2           # the first press does not work — see _on_switch_stuck
const STIFF_SWITCH_TEXT := "Press harder."   # the user's own wording, 2026-08-16
const GLIMPSE_ENERGY := 0.55        # weak, dying; the working reveal settles at 0.9
const GLIMPSE_TIME := 0.4           # how long the ward is visible before it goes again
const AMBIENT_MIN := 20.0           # level-local scare metronome, ZERO panic (not
const AMBIENT_MAX := 40.0           # RandomAmbient, which carries 5/8/12)
const BREATH_VOLUME_DB := -22.0     # the thing at the far wall you walked away from

# The wheelchair turns WHILE YOU WATCH, close up, with a sound (playtest 2026-07-28).
# ⚠️ This deliberately INVERTS SCARY.md P6's MovedProp rule, which only ever applies a delta
# while the player is >6 m away and facing elsewhere. The user's call, and the reasoning is
# that an anomaly nobody notices is worth less than an event they certainly see: P6's
# asymmetry ("if the player never notices, nothing happens") is a virtue in a level with
# something else going on, and a wasted beat in a 90-second tutorial room.
const WHEELCHAIR_TURN_DIST := 3.2   # must be close
const WHEELCHAIR_TURN_DOT := 0.55   # …and actually looking at it
const WHEELCHAIR_TURN_DEG := 34.0
const WHEELCHAIR_TURN_TIME := 1.1   # slow enough to read as turning, not as snapping
# Mix, not difficulty: see the measurements in _tick_wheelchair().
# ⚠️ +1.0 SINCE 2026-09-10 (was -7.6), the user's call on a replay: *"Can we make the noise of this
# wheelchair even louder?"* The old value matched the creak fallback's loudness; the file itself is
# -2.3 dBFS RMS, so at +1.0 with a raised `max_db` the caster lands at ~+2 dBFS RMS at the 2.7 m the
# beat fires from — the Master hard limiter (-0.5 dBFS) takes the peaks. There is no headroom past
# this: the next lever is CONTRAST, which is why the turn now opens with a HoldBreath dip.
const WHEELCHAIR_SFX_DB := 1.0
const WHEELCHAIR_SFX_MAX_DB := 8.0      # Godot's default ceiling is 3.0 and would eat the gain
const WHEELCHAIR_SFX_DIP := 0.35        # seconds of Ambience silence under the caster
const WHEELCHAIR_SFX_FADE_START := 1.1  # == WHEELCHAIR_TURN_TIME: full level for the whole turn
const WHEELCHAIR_SFX_FADE_TIME := 0.5   # then a settle tail, instead of the file's hard cut at 2.0 s

# Nodes that must survive a clear-and-rebuild pass. This scene is never reloaded
# mid-playthrough in the normal flow, but the twist ending reuses this same
# scene/script, so the pattern is genuinely exercised, not just precautionary.
const PRESERVE := ["Environment", "AmbientPlayer", "Player"]

const _DOOR_SCRIPT := preload("res://scripts/door.gd")
const _NOTE_SCRIPT := preload("res://scripts/note.gd")

# --- the Intake Wing's voice, light and pacing (2026-09-24) --------------------------------------
# ⚠️ FIVE lines, no more (spec: "the voice is rationed"). Each is also a ScreenText.caption, and
# the caption is the SAME WORDS — tools/make_pa_voice.py's LINES table is the other copy. Only VO1
# plays in this build; VO2-5 land with the ward retrofit and calibration (phases 4-5).
const VO := {
	"morning": ["pa_intro_morning", "Good morning, forty-six— forty-seven."],
	"fault": ["pa_intro_fault", "—we have a fault in—"],
	"screen": ["pa_intro_screen", "Look at the screen, forty-seven."],
	"better": ["pa_intro_better", "Much better than last time."],
	"proceed": ["pa_intro_proceed", "You may proceed."],
}
const VO_DB := 4.0                   # the Lab's PASpeaker gain: same chain, same speaker
# Wing lighting. ⚠️ Emission ≤ 0.55 on every bulb (check_fixtures; Issue 21 — above 1.0 clamps
# to flat white, and at this light energy emission is most of a surface's colour).
const WING_AMBIENT := 0.035          # enough that a shadowed wall is a shape, not a hole
const BULB_EMISSION := 0.5
const BULB_COLOR := Color(1.0, 0.9, 0.74)
const CELL_BULB_ENERGY := 1.1        # the cell is the brightest room: the glass has to read
const HALL_BULB_ENERGY := 0.8        # …and the hall the darker, or the glass is a mirror (≥ 5×, measured)
const CORRIDOR_BULB_ENERGY := 0.75

@onready var player: CharacterBody3D = $Player

var candle_light: OmniLight3D
var note: Node

var _flicker_time: float = 0.0
var _red_light: OmniLight3D = null   # ending only: slow blood-red throb
var _candle_lit: bool = false        # gates _process()'s candle flicker until the switch flips
var _env: Environment = null
var _path_glow_lights: Array[OmniLight3D] = []
var _path_glow_audio: AudioStreamPlayer3D = null
var _ceiling_lights: Array[OmniLight3D] = []
var _switch_flipped: bool = false     # half of the exit lock; the note is the other half
var _far_breath: AudioStreamPlayer3D = null   # cut when the lights come on
var _ambient_timer: Timer = null              # level-local, zero-panic scare metronome
var _wheelchair_armed: bool = false           # armed when the note is read
var _wheelchair_turned: bool = false          # one-shot
var _glimpse_form: Node3D = null              # the sheeted form that is gone after the reveal
var _candle_flame: MeshInstance3D = null      # hidden while the room is dark — it is emissive
var _cobweb_index: int = 0                    # unique node names — Issue 17

# --- the Intake Wing -------------------------------------------------------------------------
var _builder: RoomBuilder = null
var _wall_mat: StandardMaterial3D = null
var _doors: Dictionary = {}                   # name -> WingDoor
var _beats: Dictionary = {}                   # the ledger: beat name -> true (see _advance)
var _bulbs: Array = []                        # [OmniLight3D, energy, bulb material, hum player]
var _straps: Array[Node3D] = []               # the restraints — visual only, never interactable
var _strap_visuals: Array = []                # per strap: [[pivot, side], ...]
var _cell_speaker: AudioStreamPlayer3D = null
var _hall_state: int = 0                      # 0 never entered · 1 occupant present · 2 gone for good
var _occupant: Node3D = null
var _tap_stream: MeshInstance3D = null
var _tap_mat: StandardMaterial3D = null
var _tap_audio: AudioStreamPlayer3D = null
var _tap_on: bool = false
var _reel_audio: AudioStreamPlayer3D = null
var _reels: Array[Node3D] = []
var _smoke: Array = []                        # [MeshInstance3D, StandardMaterial3D, phase]
var _monitor_lamp: StandardMaterial3D = null
var _monitor_light: OmniLight3D = null


func _ready() -> void:
	GameState.current_level = 0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_clear_old_scene()
	player.set_panic_ceiling(PANIC_CEILING)

	_build_room()
	if not GameState.is_ending:
		_build_wing()
	_build_gurney(GURNEY_POS)                    # the player's own — never occupied
	# ⚠️ Occupied. The two spare beds were bare, which made the ward read as storage; a
	# covered body on each makes it read as a ward with other subjects in it.
	#
	# ⚠️ This used to add "…and it is the strongest thing available at level 0's strictly
	# ordinary register — nothing supernatural, nothing that moves". That is no longer true
	# and was already not true when it was written: the WHEELCHAIR in this same room turns to
	# face you unaided, which is a larger breach of that register and was accepted on the
	# user's own call (2026-07-28). The empty bed below (2026-08-16) is a smaller one, and it
	# is unwitnessable by construction — no sound, no panic, no camera move, nothing looks at
	# the player, and it happens while the room is pitch black. See _on_switch_flipped().
	_build_gurney(FAR_GURNEY_POS, true)
	# The bed the glimpse shows, and the bed that is empty afterwards.
	_glimpse_form = _build_gurney(GLIMPSE_GURNEY_POS, true)
	_build_iv_stand(Vector3(0.8, 0, 6.5))
	_build_iv_stand(Vector3(4.4, 0, 1.0))        # beside the glimpse bed, inside the same pool
	_build_wheelchair()
	_build_wall_chart()
	_build_table_note_candle()
	_build_exit_door()
	_build_cabinets()
	_build_ward_dressing()
	if not GameState.is_ending:
		_build_ward_finds()
		_build_speakers()
		_build_calibration()
	_spawn_cobwebs()
	_start_ambience()

	if GameState.is_ending:
		note.note_text = ENDING_NOTE
		NoteUI.closed.connect(_on_ending_note_closed, CONNECT_ONE_SHOT)
		_corrupt_room()
		return

	note.note_text = OPENING_NOTE
	# The ward is shut and pitch black; the wing is lit by its own bulbs (see _build_wing()).
	_darken_scene(WING_AMBIENT)
	player.lock_flashlight()
	player.freeze_input()
	_spawn_light_switch()
	_refresh_doors()
	# The back door: coming back from the Lab, the wing is already solved (spec/levels/README.md).
	if GameState.entered_from_ahead:
		_restore_progress()
		return
	_play_wakeup_beat()


func _clear_old_scene() -> void:
	for child in get_children():
		if PRESERVE.has(child.name):
			continue
		# ⚠️ remove_child BEFORE queue_free. queue_free() is deferred to the end of the
		# frame, so a node freed this way is STILL A CHILD — and still holding its name
		# — while _ready() builds the replacement level. Godot then renames the new
		# node on the collision (Issue 17), and every later get_node("ExitDoor") in
		# these levels silently missed: probed on the Lab, both doors came back as
		# @StaticBody3D@332 / @334. remove_child() detaches immediately, so the name is
		# free by the time the new door is added. (Found 2026-07-27 by the autoplay
		# harness, which is the first thing that ever looked a door up by name.)
		remove_child(child)
		child.queue_free()


# ⭐ THE SOUNDTRACK PLAYS ONCE (first hand playtest, 2026-09-24, capture #2: *"when the soundtrack
# ends it starts again - and we hear that sound of like dreaming and waking up again"*).
# `ambient_asylum` (162 s) opens on the dream-to-waking swell; self-looped, that swell came back every
# 162 s. Now it plays once and the AmbientPlayer moves on to the user's `intro_second_music` (83 s),
# which loops. Its gain is set from the files' MEASURED means (−11.1 dB against the first track's
# −24.3), i.e. SECOND_MUSIC_OFFSET_DB below the first track's level. No second file -> silence;
# the wing's room tone and the metronome carry on, and the dream never replays.
const FIRST_MUSIC := "ambient_asylum"
const SECOND_MUSIC := "intro_second_music"
const SECOND_MUSIC_OFFSET_DB := -13.0
var _music_base_db := 0.0

func _start_ambience() -> void:
	var ambient: AudioStreamPlayer = get_node_or_null("AmbientPlayer")
	if ambient:
		ambient.bus = AudioBuses.AMBIENCE   # duckable — see audio_buses.gd
		_music_base_db = ambient.volume_db
		var s := GameState.load_audio(FIRST_MUSIC)
		if s:
			ambient.stream = s
		if ambient.stream:
			ambient.finished.connect(_on_first_music_finished, CONNECT_ONE_SHOT)
			ambient.play()


func _on_first_music_finished() -> void:
	var ambient: AudioStreamPlayer = get_node_or_null("AmbientPlayer")
	if ambient == null:
		return
	var s := GameState.load_audio(SECOND_MUSIC)
	if s == null:
		return
	ambient.stream = s
	ambient.volume_db = _music_base_db + SECOND_MUSIC_OFFSET_DB
	ambient.finished.connect(ambient.play)
	ambient.play()


# ---------------------------------------------------------------- geometry

func _make_box(box_name: String, size: Vector3, pos: Vector3) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	box.use_collision = true
	add_child(box)
	return box


func _build_room() -> void:
	# ⭐ RoomBuilder since 2026-09-24. The ending builds the WARD ALONE with no doorways, so its
	# four walls are unbroken — the same sealed room the twist has always boarded up.
	_builder = RoomBuilder.new()
	_builder.name = "WingBuilder"
	_wall_mat = RoomBuilder.make_material(TEX + "asylum_wall.png",
		Vector3(1.0 / 3.6, 1.0 / 3.6, 1.0 / 3.6), Color(0.42, 0.46, 0.43))
	# ⚠️ One tile = 3.6 m = the ward's height, and the texture's BOTTOM EDGE is the floor: the
	# dark wainscot band is painted into the bottom 1.0 m of the tile (tools/make_intro_wing_art.py),
	# so a scale that is not exactly 1/3.6 floats it off the floor or up the wall.
	# ⚠️ AND WORLD-SPACE triplanar. make_material()'s triplanar is OBJECT-local by default, i.e.
	# measured from each wall box's CENTRE (h/2): the ward's 3.6 m walls put the band mid-wall and
	# the window's sill and head boxes each started the pattern afresh (first render). World space
	# puts y = 0 on the floor for every box, which is what a painted band needs.
	_wall_mat.uv1_world_triplanar = true
	# ⚠️ …which also flips V: make_material() negates V for OBJECT-space triplanar, and in world
	# space that negation put the band at the CEILING (second render). Positive V here.
	_wall_mat.uv1_scale.y = absf(_wall_mat.uv1_scale.y)
	_builder.wall_mat = _wall_mat
	var floor_mat := RoomBuilder.make_material(TEX + "asylum_floor.png",
		Vector3(0.3, 0.3, 0.3), Color(0.2, 0.21, 0.2))
	if ResourceLoader.exists(TEX + "asylum_floor_rough.png"):
		floor_mat.roughness_texture = load(TEX + "asylum_floor_rough.png")
		floor_mat.roughness = 1.0
	_builder.floor_mat = floor_mat
	_builder.ceil_mat = RoomBuilder.make_material(TEX + "asylum_ceiling.png",
		Vector3(0.3, 0.3, 0.3), Color(0.25, 0.26, 0.25))
	add_child(_builder)
	if GameState.is_ending:
		_builder.build([WARD], [])
	else:
		# Windows are cut like doorways and then closed around the glass (_build_windows()).
		_builder.build(_rooms_with_skins(), DOORS + WINDOWS)

	# Ceiling fluorescents — off until the switch is flipped, then flickered up
	# in _on_switch_flipped(). No fixture mesh: this room reads as plain damp
	# concrete, not a lab with a distinct fitting texture.
	# ⚠️ Names are UNIQUE per tube. Three siblings all called "CeilingLight" meant Godot
	# renamed two of them to @OmniLight3D@NNN (Issue 17 — the same rename that silently
	# broke every door lookup in four levels), so only one was ever findable by name.
	# Nothing depended on it yet; a suffix costs nothing and keeps them addressable.
	for i in [0, 1, 2]:
		var z: float = [6.0, 0.0, -6.0][i]
		var light := OmniLight3D.new()
		light.name = "CeilingLight_%d" % i
		light.position = Vector3(0, ROOM_HEIGHT - 0.3, z)
		light.light_energy = 0.0
		light.light_color = Color(0.75, 0.8, 0.85)
		light.omni_range = 9.0
		light.shadow_enabled = true
		add_child(light)
		_ceiling_lights.append(light)
		_add_ward_fixture(light)


# Per-room skins (level_1.gd:_rooms_with_skins' pattern). The observers' HALL keeps the ward's old
# plain, dry floor — the one room in the wing somebody mops — which is the cheapest legible
# difference between their side of the glass and yours.
func _rooms_with_skins() -> Array:
	var hall_floor := RoomBuilder.make_material(TEX + "floor_intro.png",
		Vector3(0.35, 0.35, 0.35), Color(0.22, 0.22, 0.21))
	var skins := {"Hall": {"floor_mat": hall_floor}}
	var out: Array = []
	for r in ROOMS:
		var room: Dictionary = r.duplicate()
		if skins.has(room["name"]):
			room.merge(skins[room["name"]])
		out.append(room)
	return out


# ⚠️ pad_tex defaults to the plain worn-vinyl `cell_pad.png` (2026-09-24 polish): the tufted
# sunburst `gurney_intro.png` must not appear anywhere in the wing (the coordinator's review).
func _build_gurney(pos: Vector3, occupied: bool = false, pad_tex: String = "cell_pad.png") -> Node3D:
	# ⚠️ Unique per bed, for the same Issue-17 reason as the ceiling tubes and the sheeted
	# forms: three gurneys all called "GurneyFrame" means Godot silently renames two of
	# them, and anything that looks one up by name finds only the first.
	var tag := "%.0f_%.0f" % [pos.x * 10.0, pos.z * 10.0]
	# ⭐ A FRAME FROM PARTS (2026-09-24, the review: "gurney frames with rails/legs so they don't
	# read as boxes"). `GurneyFrame_*` is now the DECK — same 0.9 x 2.0 footprint, same top face
	# at y = 0.5 (check_intro_sheet measures the hem against exactly that) — on four tubular legs
	# with casters, a low side rail each side, an undercarriage shelf, and (empty beds only) a
	# tubular head rail. The sheet's drape hangs past the deck ends, so an occupied bed gets no
	# head rail: a post there would pierce the cloth.
	var frame := CSGBox3D.new()
	frame.name = "GurneyFrame_" + tag
	frame.size = Vector3(0.9, 0.08, 2.0)
	frame.position = pos + Vector3(0, 0.46, 0)
	frame.use_collision = true
	var fm := _steel_mat()
	frame.material = fm
	add_child(frame)
	_gurney_parts(pos, tag, not occupied)

	var mattress := CSGBox3D.new()
	mattress.name = "GurneyMattress_" + tag
	mattress.size = Vector3(0.85, 0.1, 1.9)
	mattress.position = pos + Vector3(0, 0.55, 0)
	mattress.use_collision = true
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.35, 0.33, 0.3)
	mm.roughness = 0.9
	mattress.material = mm
	add_child(mattress)

	# The gurney art is a top-facing photo, not a texture wrapped around the box
	# (a BoxMesh/CSGBox3D crops instead of fitting a whole image to one face —
	# see the QuadMesh rule in CLAUDE.md). Sits a hair proud of the mattress top.
	#
	# ⚠️ ONLY on the empty bed (2026-08-16). Two reasons, both measured. (1) A covered bed
	# shows a SHEET, not a mattress — the drape in _build_sheeted_form() covers the whole
	# mattress, so this decal was rendering underneath something opaque. (2) The decal plane
	# sat at y=0.605 and the old sheet boxes spanned 0.600-0.800, so the art plane physically
	# cut through the bottom 5 mm of the body.
	if not occupied:
		var mtex_path := TEX + pad_tex
		if ResourceLoader.exists(mtex_path):
			var decal := MeshInstance3D.new()
			decal.name = "GurneyMattressArt_" + tag
			var qm := PlaneMesh.new()
			# ⚠️ SIZED FROM THE MATTRESS, and the ART is what was made to match — see A6.
			# The source used to be a 1672x941 LANDSCAPE photo of a whole gurney (frame,
			# side rails, buckle straps and the concrete floor around it) squashed 3.97x
			# onto this portrait quad, i.e. a second, rotated, miniature gurney printed on
			# the bed. Playtest 2026-08-16 capture #2 read its two pads as "a pillow and a
			# blanket". It is now a plain stained pad at this quad's own aspect.
			qm.size = Vector2(0.85, 1.9)
			decal.mesh = qm
			decal.position = pos + Vector3(0, 0.605, 0)
			var dm := StandardMaterial3D.new()
			dm.albedo_texture = load(mtex_path)
			dm.roughness = 0.9
			decal.set_surface_override_material(0, dm)
			add_child(decal)

	if occupied:
		return _build_sheeted_form(pos)
	return null


# ── THE COVERED BODY ────────────────────────────────────────────────────────────────────
#
# ⚠️ ONE CONTINUOUS SMOOTH SURFACE — NOT BOXES, AND NOT MORE BOXES (2026-08-16, second
# revision). The history matters, because the first fix made it worse:
#
#   v1  two axis-aligned CSG boxes (a long low mound + a head bump 6 cm proud of it).
#       Playtest capture #2: *"Is it a human on the bed? Or a pillow and a blanket?"*
#   v2  eleven axis-aligned CSG boxes — head, shoulders, chest, abdomen, hips, thighs,
#       knees, shins, two feet, on a slab drape. Playtest capture: *"This still does not
#       look realistic."* It read as a STACK OF BLOCKS: every part was individually legible
#       as a discrete rectangular step with hard 90° corners, and — the thing that actually
#       killed it — their top faces were all horizontal planes taking identical light, so
#       from standing eye height the whole mass was one uniform flat bright shape.
#
# The lesson is structural, not a tuning miss: **axis-aligned boxes cannot make a draped
# organic mass.** More parts made the wrong silhouette more detailed. So this is built from
# a smooth field instead — the surface is a heightfield sampled from a soft union of
# ellipsoidal blobs (head / neck / shoulders / chest / waist / hips / two thighs / two knees
# / two shins / two feet), blended with a polynomial smooth-max so the features are IMPLIED
# by one continuous skin rather than stacked as steps. Normals are analytic central
# differences, so the shading is a gradient across the whole form and there is not a single
# flat facet on it.
#
# The same field carries the drape: outside a rounded-rectangle boundary the height plunges
# to a hem below the mattress line, which is what makes it read as cloth hanging off a bed
# rather than as an object sitting on one. Corner radius is why the sheet corners are round.
#
# ⚠️ Nothing here is axis-symmetric. A real body under a sheet is never square to the frame:
# the head is tipped off-centre, the shoulders sit slightly the other way, one knee is higher
# and further down the bed than the other, the feet splay, and the whole form carries a small
# yaw. That asymmetry is doing as much work as the curvature.
#
# ⚠️ NOT emissive, and a dull off-white rather than a bright one (Issues 21/27/33). At this
# room's light energy a pale emissive form would be the brightest thing in a pitch-dark ward
# — it would announce itself during the blind walk, and the point is that you do not see
# these until the lights come on and then nobody mentions it. The fabric texture multiplies
# DOWN into the same measured colour v2 shipped with; see SHEET_TINT.
#
# ⚠️ Never called for the player's own gurney: something solid on the bed you spawn lying
# on would push the player out of the world, and tests/check_spawn_blocked.gd asserts
# exactly that nothing invisible blocks a spawn.
#
# Returns the parent node, so the level can remove a whole form in one call (see B2 /
# _on_switch_flipped()).

# Sheet footprint. Xin/Zin are the flat top; beyond them the hem falls away over SKIRT_W,
# so the sheet is 1.02 x 2.10 m over a 0.85 x 1.9 mattress on a 0.9 x 2.0 frame.
#
# ⚠️ THE HEM MUST NOT REACH THE FRAME'S TOP FACE (y = 0.5, i.e. 0.10 below the mattress
# top) anywhere the sheet is still OVER the frame (|x| <= 0.45 and |z| <= 1.0). The worst
# point is the frame's own corner (0.45, 1.0), where the SDF is 0.051 -> 0.060 m of drop,
# 0.038 m of clearance. Every full-depth hem point is outside the frame in at least one
# axis, so it hangs free. Change SKIRT_W, HEM or CORNER_R and this needs re-checking —
# check_intro_geometry.gd asserts it.
const SHEET_XIN := 0.425
const SHEET_ZIN := 0.965
const SHEET_CORNER_R := 0.02       # cloth has no truly square corners, but see the frame
                                   # clearance note above — a big radius drops the CORNERS
                                   # early and pushes the hem through the frame's top face
const SHEET_SKIRT_W := 0.085       # horizontal run of the fall-off
const SHEET_HEM := 0.13            # how far below the mattress top the hem hangs
const SHEET_LIFT := 0.014          # the flat sheet rides this far above the mattress —
                                   # never 0, which would be coplanar (Issues 19/20/23)
const SHEET_CELL := 0.024          # sampling resolution; ~44 x 89 vertices per bed
const SHEET_SMOOTH_K := 0.052      # blob blend radius — the "one skin" knob. ⚠️ Too large
                                   # and the neck pinch and the gap between the legs are
                                   # smoothed away, which is most of what makes it a body
const SHEET_WRINKLE := 0.0035       # cloth undulation; small, but it is what stops the flat
                                   # areas rendering as a single uniform plane
const SHEET_YAW_DEG := 1.8         # nothing in this room is perfectly square to the frame
const SHEET_TINT := Color(0.553, 0.560, 0.591)   # DERIVED — see _sheet_material()

# cx, cz, rx, rz, height. Supine, head toward -z, ~1.72 m crown to sole.
#
# ⚠️ THE BODY MUST BE NARROW ENOUGH TO LEAVE A GUTTER. The first draft gave the shoulders
# rx 0.37 against a mattress half-width of 0.425, so the mound reached almost the full width
# of the bed and the sheet never came back down to the mattress on either side — measured, it
# rendered as *a mattress with a slight bulge*, which is the v1 complaint again. Measured on
# the current numbers, the sheet is back down to 0.02 m by |x| = 0.24 at every station: a
# 0.19 m flat gutter each side, and that gutter is what tells the eye the mound is a body
# lying ON the bed rather than the bed itself.
#
# ⚠️ NOTHING MAY BE TALLER THAN IT IS WIDE. A blob whose height exceeds its radius renders
# as a CONE, and a render of an earlier pass had two of them at the foot of the bed: it read
# as a ridge of rock, not a person. The extremities are the ones that go wrong, because they
# are the small features. Measured side silhouette on these numbers, crown to sole:
#   head 0.203 · neck 0.104 · shoulders 0.228 · chest 0.253 · waist 0.172 · hips 0.221
#   · thighs 0.175 · knees 0.140 · shins 0.108 · foot tent 0.164
#
# ⚠️ ONE foot tent, not two. Two separate foot blobs made two spikes; a real sheet spans the
# toes as a single peak, and that peak at the end of the bed is the whole morgue image.
#
# ⚠️ CLOTH BRIDGES CONCAVITIES; it does not dive into them. Two leg blobs alone put a
# 55-degree-per-side crevasse down the middle of the legs — measured, adjacent vertices'
# normals 110 degrees apart, which is a crease, not a fold. The wide, low blob at
# (−0.004, 0.605) IS the sheet spanning between the legs: it fills the valley floor to
# 0.117 while leaving the two leg ridges at 0.140/0.128, and it takes the worst normal
# split anywhere on the top of the sheet down to 71 degrees. (A box corner is 90 and two
# coincident faces are 180 — see check_intro_sheet.gd, which asserts this.)
const SHEET_BLOBS := [
	[ 0.030, -0.700, 0.150, 0.185, 0.205],   # head, tipped to one side
	[ 0.018, -0.550, 0.100, 0.090, 0.105],   # neck — the pinch that makes the head a head
	[-0.012, -0.415, 0.255, 0.190, 0.230],   # shoulders, the widest point
	[-0.015, -0.215, 0.230, 0.305, 0.252],   # chest, the highest
	[-0.005,  0.020, 0.195, 0.260, 0.176],   # waist — a dip, not a step
	[ 0.000,  0.220, 0.235, 0.250, 0.220],   # hips
	[-0.098,  0.420, 0.175, 0.300, 0.175],   # thigh L
	[ 0.092,  0.432, 0.169, 0.300, 0.167],   # thigh R, a touch further down the bed
	[-0.094,  0.640, 0.148, 0.200, 0.140],   # knee L, the raised one
	[ 0.084,  0.662, 0.142, 0.195, 0.129],   # knee R
	[-0.089,  0.762, 0.124, 0.180, 0.108],   # shin L
	[ 0.079,  0.775, 0.118, 0.175, 0.101],   # shin R
	[-0.004,  0.605, 0.245, 0.315, 0.118],   # ⚠️ THE SHEET SPANNING THE LEGS — see below
	[-0.006,  0.855, 0.148, 0.105, 0.165],   # the foot tent — both feet, one peak
]


# `form_name` (2026-09-24): the hall glimpse's occupant is built by this same function but must NOT
# be named SheetedForm_* — check_intro_beats / check_intro_sheet count those as the WARD's two
# covered beds, and the occupant is neither in the ward nor always there.
func _build_sheeted_form(pos: Vector3, form_name: String = "") -> Node3D:
	# Unique per bed, for the same Issue-17 reason as the ceiling tubes.
	var tag := "%.0f_%.0f" % [pos.x * 10.0, pos.z * 10.0]
	var form := Node3D.new()
	form.name = form_name if form_name != "" else "SheetedForm_" + tag
	# Origin AT the mattress top (frame top 0.5, mattress top 0.6), so every height below is
	# stated as a height above the bed rather than as a world y.
	form.position = pos + Vector3(0, GURNEY_TOP_Y, 0)
	form.rotation.y = deg_to_rad(SHEET_YAW_DEG)
	add_child(form)

	var mi := MeshInstance3D.new()
	mi.name = "SheetSurface"
	mi.mesh = _build_sheet_mesh()
	mi.set_surface_override_material(0, _sheet_material())
	form.add_child(mi)

	# ⚠️ ONE collider, and it is a plain box, not the surface. The gurney frame and mattress
	# under this are already solid, so the only thing a collider here changes is whether you
	# can walk your face through the mound — and a 4 000-triangle trimesh collider for that
	# would be absurd. v2 put collision on the drape slab for the same reason.
	var body := StaticBody3D.new()
	body.name = "SheetCollider"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.66, 0.19, 1.84)
	shape.shape = box
	shape.position = Vector3(0, 0.095, 0)
	body.add_child(shape)
	form.add_child(body)

	return form


# Polynomial smooth maximum. `k` is the blend width in metres: at k=0 this is max().
func _smax(a: float, b: float, k: float) -> float:
	var h: float = clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)


# Signed distance to the rounded rectangle that bounds the flat top of the sheet.
# Negative inside, 0 on the boundary, positive out in the skirt.
func _sheet_sdf(x: float, z: float) -> float:
	var qx: float = absf(x) - (SHEET_XIN - SHEET_CORNER_R)
	var qz: float = absf(z) - (SHEET_ZIN - SHEET_CORNER_R)
	var outside := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length()
	return outside + minf(maxf(qx, qz), 0.0) - SHEET_CORNER_R


# Height of the sheet above the mattress top at (x, z).
func _sheet_height(x: float, z: float) -> float:
	var h := SHEET_LIFT
	for b in SHEET_BLOBS:
		var dx: float = (x - b[0]) / b[2]
		var dz: float = (z - b[1]) / b[3]
		var q: float = dx * dx + dz * dz
		if q >= 1.0:
			continue
		# (1-q)^2 * (1 + 0.9q): a bell with ZERO tangent at the rim, so a blob melts into
		# the sheet instead of meeting it at a crease. An ellipsoid dome (sqrt) has a
		# vertical rim and would put a hard edge round every feature — the v2 failure in
		# curved form.
		var t: float = 1.0 - q
		h = _smax(h, b[4] * t * t * (1.0 + 0.9 * q), SHEET_SMOOTH_K)

	# Cloth undulation. Two incommensurate wavelengths so it never reads as a pattern.
	h += SHEET_WRINKLE * (sin(7.3 * x + 4.1 * z + 0.7) * 0.6
		+ sin(5.1 * z - 2.2 * x + 2.3) * 0.4
		+ sin(11.7 * x + 1.1) * 0.25)

	# The hem. `t^1.7` has zero slope where it leaves the mattress (a rounded fold) and is
	# still accelerating downward at the hem (cloth hanging, not a chamfer).
	var d := _sheet_sdf(x, z)
	if d > 0.0:
		var t: float = clampf(d / SHEET_SKIRT_W, 0.0, 1.0)
		# A hem that varies a little along its length reads as cloth; a dead-level one
		# reads as a machined edge.
		var hem: float = SHEET_HEM * (1.0 + 0.16 * sin(9.0 * z + 1.3) + 0.10 * sin(11.0 * x))
		h -= hem * pow(t, 1.7)
	return h


# A heightfield surface over the sheet's footprint, with ANALYTIC normals (central
# differences), so every triangle is smooth-shaded from the field rather than flat-shaded
# from its own plane.
#
# ⚠️ INDEXED, and every quad is emitted. A first pass skipped quads whose centre lay past
# the hem, to get rounded sheet corners — and the skipped cells left a SAWTOOTH along the
# whole front hem, clearly visible in the first render. The outline is a plain rectangle
# now; the corner droop comes from the SDF instead, which is what a real sheet corner does.
func _build_sheet_mesh() -> ArrayMesh:
	var xg: float = SHEET_XIN + SHEET_SKIRT_W
	var zg: float = SHEET_ZIN + SHEET_SKIRT_W
	var nx := int(ceil(2.0 * xg / SHEET_CELL))
	var nz := int(ceil(2.0 * zg / SHEET_CELL))
	var e := SHEET_CELL * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(nz + 1):
		for ix in range(nx + 1):
			var x: float = -xg + 2.0 * xg * float(ix) / float(nx)
			var z: float = -zg + 2.0 * zg * float(iz) / float(nz)
			var dhdx: float = (_sheet_height(x + e, z) - _sheet_height(x - e, z)) / (2.0 * e)
			var dhdz: float = (_sheet_height(x, z + e) - _sheet_height(x, z - e)) / (2.0 * e)
			st.set_normal(Vector3(-dhdx, 1.0, -dhdz).normalized())
			# One texture tile per metre, so the weave stays square on a 1.02 x 2.10 sheet.
			st.set_uv(Vector2(x + 0.5, z + 0.5))
			st.add_vertex(Vector3(x, _sheet_height(x, z), z))

	var stride := nx + 1
	for iz in range(nz):
		for ix in range(nx):
			var i0: int = iz * stride + ix
			var i1: int = i0 + 1
			var i2: int = i0 + stride + 1
			var i3: int = i0 + stride
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i3)

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


func _sheet_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.97
	m.metallic = 0.0
	# ⚠️ Two-sided. The surface is a single skin with an open hem, so the underside of the
	# fall is visible at grazing angles; culling it would show a hole in the sheet.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var path := TEX + "sheet_linen.png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		# ⚠️ The tint is DERIVED, not chosen. `sheet_linen.png` has a measured mean of
		# sRGB(0.804, 0.777, 0.688); multiplied in LINEAR space by SHEET_TINT that lands on
		# sRGB(0.440, 0.430, 0.400) — exactly the flat colour the previous version shipped
		# with and which the playtest never complained about. Same discipline as the gurney
		# pad regeneration (A6): match what shipped, do not guess a new brightness. Emission
		# stays at zero; a self-lit sheet in a pitch-dark ward would give the beds away
		# during the blind walk (Issues 21/27/33).
		m.albedo_color = SHEET_TINT
	else:
		m.albedo_color = Color(0.44, 0.43, 0.40)
	return m


# Thin pole + small "bag" + flat base — enough silhouette to read as an IV stand
# without needing a texture (per the grill-me decision: too simple a shape to
# justify one).
func _build_iv_stand(pos: Vector3) -> void:
	var pole := CSGCylinder3D.new()
	pole.name = "IVStandPole"
	pole.radius = 0.02
	pole.height = 1.4
	pole.position = pos + Vector3(0, 0.7, 0)
	pole.use_collision = true
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.55, 0.55, 0.58)
	pm.metallic = 0.7
	pm.roughness = 0.4
	pole.material = pm
	add_child(pole)

	var base := CSGCylinder3D.new()
	base.name = "IVStandBase"
	base.radius = 0.16
	base.height = 0.03
	base.position = pos + Vector3(0, 0.015, 0)
	base.material = pm
	add_child(base)

	var bag := MeshInstance3D.new()
	bag.name = "IVStandBag"
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.16
	bag.mesh = sm
	bag.position = pos + Vector3(0, 1.42, 0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.75, 0.7, 0.4, 0.75)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bag.set_surface_override_material(0, bm)
	add_child(bag)


# Full 3D CSG build — same level of detail as _build_gurney()/_build_cabinets(),
# replacing the earlier flat billboard cutout (which read as visibly 2D from an
# angle). Wheels are CSGCylinder3D tipped on their side: the default cylinder
# axis is local Y (stands like a can), so rotation.z=90 lays it over onto a
# horizontal axis — the flat round faces then point left/right, like a real
# wheel, instead of up/down.
func _build_wheelchair() -> void:
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.1, 0.09, 0.09)
	frame_mat.metallic = 0.75
	frame_mat.roughness = 0.45

	var fabric_mat := StandardMaterial3D.new()
	fabric_mat.albedo_color = Color(0.16, 0.13, 0.11)
	fabric_mat.roughness = 0.9

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.5, 0.48, 0.45)
	rim_mat.metallic = 0.8
	rim_mat.roughness = 0.4

	var wc := Node3D.new()
	wc.name = "Wheelchair"
	wc.position = WHEELCHAIR_POS
	add_child(wc)

	var seat := CSGBox3D.new()
	seat.size = Vector3(0.46, 0.05, 0.46)
	seat.position = Vector3(0, 0.48, 0)
	seat.use_collision = true
	seat.material = fabric_mat
	wc.add_child(seat)

	var back := CSGBox3D.new()
	back.size = Vector3(0.46, 0.5, 0.05)
	back.position = Vector3(0, 0.74, -0.23)
	back.use_collision = true
	back.material = fabric_mat
	wc.add_child(back)

	# Armrests + their support posts (front + back, tying them to the seat).
	for sx in [-1.0, 1.0]:
		var arm := CSGBox3D.new()
		arm.size = Vector3(0.035, 0.045, 0.42)
		arm.position = Vector3(sx * 0.25, 0.62, -0.02)
		arm.material = frame_mat
		wc.add_child(arm)
		var post_front := CSGCylinder3D.new()
		post_front.radius = 0.014
		post_front.height = 0.14
		post_front.position = Vector3(sx * 0.25, 0.55, 0.18)
		post_front.material = frame_mat
		wc.add_child(post_front)
		var post_back := CSGCylinder3D.new()
		post_back.radius = 0.014
		post_back.height = 0.24
		post_back.position = Vector3(sx * 0.25, 0.6, -0.22)
		post_back.material = frame_mat
		wc.add_child(post_back)
		# Seat-to-axle side rail.
		var rail := CSGBox3D.new()
		rail.size = Vector3(0.03, 0.03, 0.5)
		rail.position = Vector3(sx * 0.25, 0.3, -0.05)
		rail.material = frame_mat
		wc.add_child(rail)

	# Big rear wheels + hand rims.
	for sx in [-1.0, 1.0]:
		var wheel := CSGCylinder3D.new()
		wheel.radius = 0.27
		wheel.height = 0.035
		wheel.rotation_degrees.z = 90.0
		wheel.position = Vector3(sx * 0.28, 0.27, -0.1)
		wheel.use_collision = true
		wheel.material = frame_mat
		wc.add_child(wheel)
		var rim := CSGCylinder3D.new()
		rim.radius = 0.22
		rim.height = 0.015
		rim.rotation_degrees.z = 90.0
		rim.position = Vector3(sx * 0.30, 0.27, -0.1)
		rim.material = rim_mat
		wc.add_child(rim)

	# Small front casters + their forks.
	for sx in [-1.0, 1.0]:
		var caster := CSGCylinder3D.new()
		caster.radius = 0.06
		caster.height = 0.03
		caster.rotation_degrees.z = 90.0
		caster.position = Vector3(sx * 0.19, 0.06, 0.21)
		caster.material = frame_mat
		wc.add_child(caster)
		var fork := CSGCylinder3D.new()
		fork.radius = 0.012
		fork.height = 0.14
		fork.position = Vector3(sx * 0.19, 0.13, 0.21)
		fork.material = frame_mat
		wc.add_child(fork)

	# Footrest.
	var footrest := CSGBox3D.new()
	footrest.size = Vector3(0.36, 0.025, 0.11)
	footrest.position = Vector3(0, 0.11, 0.3)
	footrest.material = frame_mat
	wc.add_child(footrest)
	var footrest_post := CSGCylinder3D.new()
	footrest_post.radius = 0.012
	footrest_post.height = 0.3
	footrest_post.position = Vector3(0, 0.25, 0.3)
	footrest_post.material = frame_mat
	wc.add_child(footrest_post)


# Same PlaneMesh + rotation.x=-90 pattern, mounted on WallBack (a Z-normal wall —
# deliberately not a side wall, which would need a different, unverified
# rotation axis to avoid the image rendering sideways).
func _build_wall_chart() -> void:
	var tex_path := TEX + "wall_chart_intro.png"
	if not ResourceLoader.exists(tex_path):
		return
	var chart := MeshInstance3D.new()
	chart.name = "WallChart"
	var qm := PlaneMesh.new()
	qm.size = WALL_CHART_SIZE
	chart.mesh = qm
	chart.rotation_degrees.x = 90.0
	chart.position = WALL_CHART_POS
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(tex_path)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	chart.set_surface_override_material(0, mat)
	add_child(chart)


func _build_table_note_candle() -> void:
	# ⭐ A TABLE, not a black cube (2026-09-24, the review). `Table` is now the TOP — a 5 cm slab
	# whose upper face is still TABLE_TOP_Y 0.8, so the note, the candle and every test that
	# measures them are where they were — on four turned legs with an apron and a stretcher.
	var table := CSGBox3D.new()
	table.name = "Table"
	table.size = Vector3(1.2, 0.05, 0.6)
	table.position = Vector3(TABLE_POS.x, TABLE_TOP_Y - 0.025, TABLE_POS.z)
	table.use_collision = true
	const TABLE_MAT_PATH := "res://assets/materials/objects/table.tres"
	if ResourceLoader.exists(TABLE_MAT_PATH):
		table.material = load(TABLE_MAT_PATH)
	add_child(table)
	var wood := _mat(Color(0.16, 0.11, 0.07), 0.75)
	for lx in [-0.53, 0.53]:
		for lz in [-0.23, 0.23]:
			_mcyl("TableLeg", 0.028, 0.75, Vector3(TABLE_POS.x + lx, 0.375, TABLE_POS.z + lz), wood, null,
				Vector3.ZERO, 0.022)
	for sz in [-1.0, 1.0]:
		_mbox("TableApron", Vector3(1.1, 0.09, 0.025), Vector3(TABLE_POS.x, 0.72, TABLE_POS.z + sz * 0.24), wood)
	for sx in [-1.0, 1.0]:
		_mbox("TableApron", Vector3(0.025, 0.09, 0.5), Vector3(TABLE_POS.x + sx * 0.54, 0.72, TABLE_POS.z), wood)
	_mbox("TableStretcher", Vector3(1.06, 0.03, 0.03), Vector3(TABLE_POS.x, 0.18, TABLE_POS.z), wood)
	_solid("TableBody", Vector3(1.2, 0.75, 0.6), Vector3(TABLE_POS.x, 0.375, TABLE_POS.z))

	_build_candle()

	# Matches level_1.gd:_make_note()'s exact ordering: the note is added to the
	# tree (triggering note.gd's _ready()) before its mesh/collision children are
	# attached — this is the proven-working pattern elsewhere in the project.
	note = StaticBody3D.new()
	note.name = "Note"
	note.set_script(_NOTE_SCRIPT)
	note.position = TABLE_POS + Vector3(0, 0.4, 0)
	add_child(note)

	# Slab for edge/depth + a QuadMesh for the art (CLAUDE.md rule — a BoxMesh
	# crops instead of showing the whole texture per face; door.gd:build_visual()
	# is the house pattern). The note had no texture applied at all until now —
	# note.gd's _style_mesh() runs in _ready(), before this mesh exists (see the
	# add-to-tree-before-children comment above), so it never touched it.
	var note_slab := MeshInstance3D.new()
	var nbm := BoxMesh.new()
	nbm.size = Vector3(NOTE_SIZE.x, 0.005, NOTE_SIZE.y)
	note_slab.mesh = nbm
	var slab_mat := StandardMaterial3D.new()
	slab_mat.albedo_color = Color(0.7, 0.67, 0.58)
	note_slab.set_surface_override_material(0, slab_mat)
	note.add_child(note_slab)

	var note_face := MeshInstance3D.new()
	note_face.name = "NoteFace"   # addressed by tests/check_art_aspect.gd
	# PlaneMesh lies flat facing +Y by default — no rotation needed, same
	# technique _build_gurney()'s mattress art uses.
	var nqm := PlaneMesh.new()
	nqm.size = NOTE_SIZE
	note_face.mesh = nqm
	note_face.position = Vector3(0, 0.0035, 0)
	var note_mat := StandardMaterial3D.new()
	var note_tex_path := TEX + "intro_note.png"
	if ResourceLoader.exists(note_tex_path):
		var ntex := load(note_tex_path)
		note_mat.albedo_texture = ntex
		note_mat.emission_enabled = true
		note_mat.emission_texture = ntex
		note_mat.emission_energy_multiplier = 0.5
		# ⚠️ UV-CROPPED TO THE PAPER (2026-08-16). `intro_note.png` is a 1254x1254 SQUARE
		# canvas with the torn page photographed on a black backdrop, and it was mapped
		# whole onto a 0.21 x 0.297 A4 quad — so the sheet was squashed 1.41x AND wore a
		# black mat around it. Sampling the page's own sub-rect fixes both at once and
		# needs no new asset: the effective source aspect becomes 0.835 / 0.970 = 0.861,
		# which is what NOTE_SIZE is derived from.
		note_mat.uv1_scale = Vector3(NOTE_UV_SCALE.x, NOTE_UV_SCALE.y, 1.0)
		note_mat.uv1_offset = Vector3(NOTE_UV_OFFSET.x, NOTE_UV_OFFSET.y, 0.0)
	else:
		note_mat.albedo_color = Color(0.85, 0.82, 0.7)
	note_face.set_surface_override_material(0, note_mat)
	note.add_child(note_face)

	var note_col := CollisionShape3D.new()
	var nbs := BoxShape3D.new()
	nbs.size = Vector3(NOTE_SIZE.x, 0.005, NOTE_SIZE.y)
	note_col.shape = nbs
	note.add_child(note_col)

	# note.gd emits `read` on OPEN (not on close — reading to the end is a mechanic
	# reserved for trap notes), which is the same hook level_1.gd uses to unlock the
	# Records locker. Not connected during the twist ending: that note's job is to end
	# the game, and _corrupt_room() has already deleted the exit door by then.
	if not GameState.is_ending:
		note.read.connect(_on_intro_note_read)


# ⚠️ There was NO CANDLE (2026-08-16). `_build_table_note_candle()` created a `Table`, a
# `Note` and an `OmniLight3D` called `CandleLight` — and no mesh at all. The light hung
# 2.2 m above the table, a metre below the ceiling, with nothing under it. The
# hand-built .tscn had a candle before this room was rebuilt procedurally; the rebuild kept
# the light and lost the emitter, and nobody noticed because the light never came on either
# (see _on_switch_flipped()).
#
# ⚠️ The FLAME is the one legitimately self-lit thing in this room, and it is capped well
# under 1.0 with a dark albedo (Issues 21/27/33): above 1.0 emission clamps to flat white,
# and the actual illumination is the OmniLight's job, not the mesh's.
const CANDLE_XZ := Vector2(0.3, 0.0)   # on the table top, clear of the note at x=0
const TABLE_TOP_Y := 0.8               # table centre 0.4, height 0.8

func _build_candle() -> void:
	var base := Vector3(TABLE_POS.x + CANDLE_XZ.x, TABLE_TOP_Y, TABLE_POS.z + CANDLE_XZ.y)

	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.60, 0.56, 0.46)
	wax.roughness = 0.85

	# ⚠️ No colliders anywhere in the candle. It stands 0.3 m from the note, and a body
	# here would answer the interaction raycast before the note does.
	var collar := CSGCylinder3D.new()
	collar.name = "CandleCollar"
	collar.radius = 0.045
	collar.height = 0.022
	collar.position = base + Vector3(0, 0.011, 0)
	collar.material = wax
	add_child(collar)

	var stub := CSGCylinder3D.new()
	stub.name = "CandleStub"
	stub.radius = 0.032
	stub.height = 0.16
	# Overlaps the collar rather than sitting on it — no coplanar faces.
	stub.position = base + Vector3(0, 0.095, 0)
	stub.material = wax
	add_child(stub)

	var wick := CSGCylinder3D.new()
	wick.name = "CandleWick"
	wick.radius = 0.004
	wick.height = 0.045
	wick.position = base + Vector3(0, 0.19, 0)
	var wick_mat := StandardMaterial3D.new()
	wick_mat.albedo_color = Color(0.06, 0.05, 0.04)
	wick_mat.roughness = 1.0
	wick.material = wick_mat
	add_child(wick)

	var flame := MeshInstance3D.new()
	flame.name = "CandleFlame"
	var sm := SphereMesh.new()
	sm.radius = 0.017
	sm.height = 0.055
	flame.mesh = sm
	flame.position = base + Vector3(0, 0.222, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.30, 0.12, 0.03)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.62, 0.22)
	fm.emission_energy_multiplier = 0.85
	flame.set_surface_override_material(0, fm)
	add_child(flame)
	# ⚠️ Tracked so _darken_scene() can hide it. It is the only emissive surface in the
	# room, and an emissive mesh is visible with every light in the world switched off —
	# a lit-looking candle throwing no light would give the blind fumble a landmark it is
	# not supposed to have, and would flatly contradict the twist ending's dead candle.
	_candle_flame = flame

	candle_light = OmniLight3D.new()
	candle_light.name = "CandleLight"
	# ⚠️ AT the flame, not 2 m over it. The tube above the table is deliberately left dead
	# in _on_switch_flipped() "so the note is lit by the candle alone" — for that sentence
	# to be true the candle has to actually be where the candle is.
	candle_light.position = base + Vector3(0, 0.235, 0)
	candle_light.light_color = Color(1, 0.58, 0.18, 1)
	candle_light.light_energy = BASE_ENERGY
	candle_light.shadow_enabled = true
	candle_light.omni_range = 5.5
	add_child(candle_light)


func _on_intro_note_read() -> void:
	GameState.intro_note_read = true
	# Observation only, and optional: DebugLog is a playtest autoload that CLAUDE.md says
	# can be removed from project.godot outright, so this must never be a hard reference.
	# It exists because "did they read the note?" was unanswerable from the 2026-08-16 log,
	# and the exit is sealed until they do.
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("INTRO note read — exit lock half two satisfied")
	_refresh_exit_lock()
	_arm_wheelchair()


# The wheelchair turns to face the table — and you WATCH it happen.
#
# It has stood at WHEELCHAIR_POS since this room was rebuilt, fully modelled, doing nothing.
# It sits in the open floor between the table and the door, so the walk from reading the note
# to leaving passes it.
#
# Armed on the note being read, then fired by proximity: the player has to be within
# WHEELCHAIR_TURN_DIST **and looking at it**, so unlike the MovedProp version this cannot be
# missed. It turns over WHEELCHAIR_TURN_TIME with a metal creak.
#
# ⚠️ Rotation only, no translation. Wheeling it across the floor would need clearance checks
# against the table and the door; a 34° turn cannot collide with anything and is the more
# unsettling read anyway — nothing moved, something is facing you.
func _arm_wheelchair() -> void:
	_wheelchair_armed = true


func _tick_wheelchair() -> void:
	if not _wheelchair_armed or _wheelchair_turned:
		return
	var wc := get_node_or_null("Wheelchair") as Node3D
	if not wc or not player:
		return
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return
	# ⚠️ HORIZONTAL-ONLY, both tests (2026-08-16). The facing test below was already
	# horizontal for the stated reason; the DISTANCE test was not, and that made the beat
	# unreachable. The camera sits 1.65 m above the chair's floor anchor, so a full-3D
	# radius of WHEELCHAIR_TURN_DIST 3.2 is really sqrt(3.2^2 - 1.65^2) = 2.741 m of floor
	# — and the walk from the note to the exit door passes the chair at 3.0 m. It could not
	# fire at any yaw, and the 2026-08-16 playtest is the log of it not firing. The chair
	# also moved x 3.0 -> 2.4 (WHEELCHAIR_POS) so the clearance is ~0.8 m rather than a
	# knife-edge 0.2: a beat that only fires on a perfect line is worse than one that never
	# fires, because nobody can tell it is broken. WHEELCHAIR_TURN_DIST is unchanged.
	var to_it := wc.global_position - cam.global_position
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	to_it.y = 0.0
	if to_it.length() > WHEELCHAIR_TURN_DIST:
		return
	if fwd.length() < 0.01 or to_it.length() < 0.01:
		return
	if fwd.normalized().dot(to_it.normalized()) < WHEELCHAIR_TURN_DOT:
		return

	_wheelchair_turned = true
	# ⚠️ THE SOUND OUTLASTS THE MOTION, ON PURPOSE, AND IS FADED RATHER THAN TRUNCATED.
	# `wheelchair.wav` is a user-supplied sample (2026-08-16), measured: 2.009 s, mono
	# 44.1 kHz, and it does NOT decay — its last 0.1 s is still at -1.3 dBFS RMS, i.e. the
	# file ENDS at full level. The turn is WHEELCHAIR_TURN_TIME 1.1 s. Three options and why
	# this one:
	#   * stop it at 1.1 s -> a creak that ends the instant the chair does, which reads as a
	#     recording being cut, and the brief's own rule is that a creak finishing before the
	#     motion is worse than no creak;
	#   * let it run to 2.009 s -> a hard cut at full amplitude 0.9 s after the chair stops;
	#   * FADE_START/FADE_TIME: full level for the whole turn, then a 0.5 s decay under the
	#     settle. The caster is still complaining after the chair has stopped moving, which is
	#     what a real one does.
	# A gain envelope is a mix decision, not a pitch-shift or a time-stretch (the brief
	# forbids those, and neither is used).
	#
	# ⚠️ GAIN IS SET FROM THE FILE'S MEASURED LEVEL, not from a plausible number. The old
	# `gurney_creak` fallback is -11.9 dBFS RMS and was played here at +2.0 dB; wheelchair.wav
	# is -2.3 dBFS RMS, i.e. 9.6 dB hotter, so 2.0 - 9.6 = -7.6 landed at the same loudness.
	# Same rule as the Flood's water bed (CLAUDE.md, Level 4 zone 3).
	# ⚠️ 2026-09-10: the user asked for louder still, so the gain is now +1.0 with `max_db` 8.0
	# (see the constants) and the world is taken away for WHEELCHAIR_SFX_DIP first — the same
	# pre-silence `screamer.gd:flash_scare()` uses. Ambience only; the caster is on Master.
	HoldBreath.dip(get_tree(), WHEELCHAIR_SFX_DIP)
	var s := GameState.load_audio("wheelchair")
	if not s:
		# Degrade rather than error, matching the rest of this file: the intro's own
		# metal-on-metal creak is the closest existing thing to a caster under load.
		s = GameState.load_audio("gurney_creak")
	if s:
		var p := AudioStreamPlayer3D.new()
		p.name = "WheelchairTurnSfx"
		p.stream = s
		p.volume_db = WHEELCHAIR_SFX_DB
		p.max_db = WHEELCHAIR_SFX_MAX_DB
		p.unit_size = 4.0
		p.position = wc.position
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		# Connected, never awaited (Issue 6): an awaited timer dies with whatever started it.
		var fade := create_tween()
		fade.tween_interval(WHEELCHAIR_SFX_FADE_START)
		fade.tween_property(p, "volume_db", WHEELCHAIR_SFX_DB - 40.0,
			WHEELCHAIR_SFX_FADE_TIME)
		fade.tween_callback(p.queue_free)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(wc, "rotation:y", wc.rotation.y + deg_to_rad(WHEELCHAIR_TURN_DEG),
		WHEELCHAIR_TURN_TIME)


# ⭐ THE DOOR LEDGER (2026-09-24). One place decides every door in the wing, the way Issue 16 gave
# KONTUR's exit one — so no half of a gate can silently stop mattering. `_advance(beat)` records a
# beat and re-derives every lock from the whole ledger; nothing else writes a lock.
#   straps  -> the cell door buzzes open
#   torch   -> the ward entry unlocks
#   lit + the note read -> the ward's far door (and, until calibration exists, the airlock exit)
func _advance(beat: String) -> void:
	_beats[beat] = true
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("INTRO beat: " + beat)
	_refresh_doors()


func _refresh_doors() -> void:
	var entry: WingDoor = _doors.get("WardEntryDoor")
	if entry:
		entry.locked = not _beats.has("torch")
		entry.locked_message = "Locked. Collect your issue first."
	var ward_msg := ""
	if not _switch_flipped:
		ward_msg = "Find the light switch first."
	elif not GameState.intro_note_read:
		ward_msg = "Read the note on the table first."
	var ward: WingDoor = _doors.get("WardDoor")
	if ward:
		ward.locked = ward_msg != ""
		ward.locked_message = ward_msg
	# Calibration -> the airlock: open once the observers are satisfied (VO4).
	var airlock: WingDoor = _doors.get("AirlockDoor")
	if airlock:
		airlock.locked = not _beats.has("calibrated")
		airlock.locked_message = "Locked."
	# The advancing exit: the ward's gate first (the note cannot be skipped — BACKLOG #12), then
	# the airlock's "You may proceed."
	var exit_door := get_node_or_null("ExitDoor")
	if exit_door and not GameState.is_ending:
		var exit_msg := ward_msg
		if exit_msg == "" and not _beats.has("proceed"):
			exit_msg = "Not yet."
		exit_door.extra_lock = exit_msg != ""
		exit_door.locked_message = exit_msg if exit_msg != "" else "LOCKED"


# Kept under its old name: tests and older call sites know it. It IS the ledger.
func _refresh_exit_lock() -> void:
	_refresh_doors()


func _build_exit_door() -> void:
	var body := StaticBody3D.new()
	body.name = "ExitDoor"  # _corrupt_room() looks this up by name — keep it exact
	body.set_script(_DOOR_SCRIPT)
	body.unlock_condition = _DOOR_SCRIPT.UnlockCondition.NONE
	body.advances_level = true
	# The door glows blood-red (findable in the dark, per project convention) and
	# would otherwise be walkable the instant the player wakes up, skipping the
	# whole dark-fumble/switch/reveal beat entirely — extra_lock seals it until
	# BOTH the switch is thrown and the note is read, same mechanism KONTUR uses
	# for its exit.
	#
	# ⚠️ The note half is BACKLOG #12: "you can access level 1 without reading the
	# intro note. It cannot be that way." That note is not flavour — it is where the
	# player is told they are Subject 47, told the rules the whole game then enforces
	# ("Stay calm", "do not touch what you are not meant to touch"), and warned in
	# advance not to answer the Backrooms phone. Walking past it makes several later
	# levels read as arbitrary cruelty.
	body.extra_lock = not GameState.is_ending
	body.locked_message = "Find the light switch first."
	# In the airlock normally; on the ward's back wall in the twist ending (boarded over there).
	body.position = EXIT_DOOR_POS if GameState.is_ending else AIRLOCK_EXIT_POS
	add_child(body)

	# ⚠️ Was `""` for the life of the project — the ONLY door in a textured level with no
	# art, so the first door the player ever sees rendered as a flat red box at emission
	# 1.5 while every later level had a real door. The textured branch of
	# `door.gd:door_material()` drops emission to 0.08 by itself; do not raise it (Issue
	# 21 — at 0.5 the red swamps the steel and the door renders salmon pink).
	_DOOR_SCRIPT.build_visual(body, DOOR_SIZE, TEX + "intro_lab_door.png")

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 0.2)
	col.shape = shape
	body.add_child(col)

	_build_door_casing(body.position.x, body.position.z - DOOR_SIZE.z / 2.0 + WALL_BITE)


# The jambs and lintel that make the leaf read as a door SET INTO the wall.
#
# Seating the leaf correctly (EXIT_DOOR_POS) stops it floating, but a flush panel on a flat
# wall still reads as a panel: a real opening has a frame around it and the leaf sits back
# inside that frame. These three boxes are the whole difference, and they cost nothing.
#
# ⚠️ SIBLINGS of ExitDoor, never children. _corrupt_room() frees ExitDoor by name, and the
# boarded-over ending wants the frame to survive — planks nailed across a doorway need a
# doorway to be nailed across.
#
# ⚠️ NO COLLIDERS. A collider on the only doorway wall is this project's documented way of
# silently sealing a room (the Lab's Records warning sign did exactly that). The leaf has
# its own collider and the wall behind is solid, so these are visual only.
func _build_door_casing(cx: float, face_z: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.12, 0.12)
	mat.metallic = 0.35
	mat.roughness = 0.8

	var z := face_z - WALL_BITE + CASING_D / 2.0
	var half_in := DOOR_SIZE.x / 2.0 - CASING_LAP     # jamb inner face, lapping over the leaf
	var lintel_y := DOOR_SIZE.y - CASING_LAP + CASING_W / 2.0

	# ⚠️ Every junction here OVERLAPS rather than abuts, and each overlap is named:
	#   * the jambs run UP INTO the lintel (top at lintel_y, lintel spans lintel_y ± W/2)
	#   * the lintel OVERHANGS the jambs by CASING_LAP, so no side face is ever coplanar
	#   * the jambs run WALL_BITE below the floor, so no bottom face is coplanar with it
	# Two coplanar visible faces is this project's single most common bug class.
	for spec in [
		["DoorJambL", Vector3(CASING_W, lintel_y + WALL_BITE, CASING_D),
			Vector3(cx - (half_in + CASING_W / 2.0), lintel_y / 2.0 - WALL_BITE / 2.0, z)],
		["DoorJambR", Vector3(CASING_W, lintel_y + WALL_BITE, CASING_D),
			Vector3(cx + half_in + CASING_W / 2.0, lintel_y / 2.0 - WALL_BITE / 2.0, z)],
		["DoorLintel", Vector3(2.0 * (half_in + CASING_W + CASING_LAP), CASING_W, CASING_D),
			Vector3(cx, lintel_y, z)],
	]:
		var mi := MeshInstance3D.new()
		mi.name = spec[0]
		var bm := BoxMesh.new()
		bm.size = spec[1]
		mi.mesh = bm
		mi.position = spec[2]
		mi.set_surface_override_material(0, mat)
		add_child(mi)


# ⚠️ REBUILT 2026-08-16 (Issue 24 / Issue 35). `cabinet_intro.png` is a 1672x941 LANDSCAPE
# front elevation of a WIDE two-door medical cabinet — glazed panels, visible bottles,
# hinges, a keyhole. It was applied straight onto the material of a 0.6 x 1.8 x 0.5
# CSGBox3D, which does two wrong things at once:
#   * a box does not map a whole texture per face, it renders a magnified CROP (Issue 24 —
#     the exit doors did exactly this until they were split into slab + quad)
#   * the carcass was a TALL NARROW locker turned side-on (0.6 deep, 0.5 wide), so it
#     presented a 0.5 m sliver to the room and the art disagreed with the object entirely
# The carcass now matches what the art depicts, and the art lives on a QuadMesh sized from
# its own aspect, inset inside the carcass edge so the body reads as a frame around a door.
const CABINET_SIZE := Vector3(0.45, 0.90, 1.60)     # depth (into the room), height, width
const CABINET_ART := Vector2(1.4215, 0.80)          # 1.4215 / 0.80 = 1.7769 = 1672 / 941
const CABINET_ART_PROUD := 0.03

func _build_cabinets() -> void:
	var cabinet_tex_path := TEX + "cabinet_intro.png"
	var cabinet_tex: Texture2D = load(cabinet_tex_path) if ResourceLoader.exists(cabinet_tex_path) else null
	var half_d := CABINET_SIZE.x / 2.0
	# x is derived from the wall face, never written down — see WALL_BACK_FACE_Z's comment.
	var left_x := WALL_LEFT_FACE_X - WALL_BITE + half_d
	var right_x := WALL_RIGHT_FACE_X + WALL_BITE - half_d
	var y := CABINET_SIZE.y / 2.0
	# [position, facing] — facing is the outward normal of the front face, +1 = +x.
	var specs := [
		[Vector3(left_x, y, 4.0), 1.0],
		[Vector3(right_x, y, 2.0), -1.0],
		[Vector3(right_x, y, -4.0), -1.0],
	]
	for i in range(specs.size()):
		var pos: Vector3 = specs[i][0]
		var facing: float = specs[i][1]
		var body := CSGBox3D.new()
		body.name = "Cabinet%d" % i
		body.size = CABINET_SIZE
		body.position = pos
		body.use_collision = true
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.14, 0.16, 0.14)
		bm.metallic = 0.4
		bm.roughness = 0.7
		body.material = bm
		add_child(body)

		if not cabinet_tex:
			continue
		var art := MeshInstance3D.new()
		art.name = "CabinetArt%d" % i
		var qm := QuadMesh.new()
		qm.size = CABINET_ART
		art.mesh = qm
		# A QuadMesh faces +Z; rotating +90 deg about Y turns that to +X, and its own width
		# axis lands along z, which is the axis the carcass is wide on.
		art.rotation.y = facing * PI / 2.0
		art.position = pos + Vector3(facing * (half_d + CABINET_ART_PROUD), 0, 0)
		var am := StandardMaterial3D.new()
		am.albedo_texture = cabinet_tex
		am.metallic = 0.3
		am.roughness = 0.75
		art.set_surface_override_material(0, am)
		add_child(art)


# ---------------------------------------------------------------- darkness / reveal beat

func _darken_scene(energy: float) -> void:
	var we: WorldEnvironment = get_node_or_null("Environment/WorldEnvironment")
	if we and we.environment:
		_env = we.environment.duplicate()
		_env.ambient_light_energy = energy
		we.environment = _env
	if candle_light:
		candle_light.light_energy = 0.0
		candle_light.visible = false
	if _candle_flame:
		_candle_flame.visible = false


# ⭐ THE WAKE-UP IS ONE MOVE (third hand playtest, 2026-09-25). The strap release was the most-
# reported beat of all three playtests (#1 *"feels like you stood up and then tried to do it"*, #2
# *"What is this big object at the place where my legs should be?"*, #3 *"Let's draw the legs to make
# it look realistic"*), and the user's call was *"let's remove this buckling thing entirely … you do
# not need to free yourself from the bed. You just stand up and continue"*. So: you come to LYING,
# looking up at the caged bulb → "IT WAS ONLY A DREAM." → you SIT UP → you STAND beside the bed, facing
# the door (~3 s, input frozen throughout) → control. The restraints are already open (someone let
# you out); VO1 plays as you stand and the door releases when it ends. Nothing ever looks down your
# own body, so there are no legs to draw.
const WAKE_CAM_LYING := 0.3          # the eye over the body, lying on the pillow
const WAKE_CAM_SITTING := 0.85       # …sitting up on the mattress
const STANDING_EYE := 1.65
const WAKE_PITCH_LYING := 1.3        # waking: straight up at the ceiling
const WAKE_LOOK_AT := Vector3(-6.2, 2.4, 22.2)   # the caged bulb over the cell
const SIT_UP_TIME := 0.9
const STAND_TIME := 1.2

func _play_wakeup_beat() -> void:
	player.global_position = CELL_WAKE_POS + Vector3(0, GURNEY_TOP_Y, 0)
	player.rotation.y = 0.0   # identity faces -Z: down the bed, at the glass
	player.camera.position.y = WAKE_CAM_LYING - 0.06
	player.camera.rotation.x = WAKE_PITCH_LYING

	var creak := GameState.load_audio("gurney_creak")
	if creak:
		var p := AudioStreamPlayer3D.new()
		p.stream = creak
		p.position = CELL_GURNEY_POS
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()

	# Coming to: the head settles on the pillow and the eyes find the bulb.
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player.camera, "position:y", WAKE_CAM_LYING, WAKEUP_TWEEN_TIME)
	var eye := CELL_WAKE_POS + Vector3(0, GURNEY_TOP_Y + WAKE_CAM_LYING, 0)
	var to_bulb := WAKE_LOOK_AT - eye
	var bulb_pitch := atan2(to_bulb.y, Vector2(to_bulb.x, to_bulb.z).length())
	t.tween_property(player, "rotation:y", atan2(-to_bulb.x, -to_bulb.z), WAKEUP_TWEEN_TIME)
	t.tween_property(player.camera, "rotation:x", bulb_pitch, WAKEUP_TWEEN_TIME)
	t.finished.connect(_on_wakeup_finished)


func _on_wakeup_finished() -> void:
	# player.gd reads its pitch from `_pitch`, not from the camera; the tweens move the camera.
	player.set("_pitch", player.camera.rotation.x)
	ScreenText.scrawl(get_tree(), NIGHTMARE_TEXT, 4.0)
	_start_local_ambient()
	_sit_up()


# Up off the pillow: the eye rises to sitting height and levels out, looking down the bed.
func _sit_up() -> void:
	var t := create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player.camera, "position:y", WAKE_CAM_SITTING, SIT_UP_TIME)
	t.tween_property(player.camera, "rotation:x", -0.15, SIT_UP_TIME)
	t.tween_property(player, "rotation:y", 0.0, SIT_UP_TIME)
	_sfx_at("gurney_creak", CELL_GURNEY_POS, -2.0, 3.0)
	t.finished.connect(_stand_up)


# One observer line: the tannoy in the room the player is in, plus its caption (same words).
# `then` runs when the line finishes — or at once if the file is missing (headless / stripped).
func _say(key: String, then: Callable = Callable(), speaker: AudioStreamPlayer3D = null) -> void:
	var line: Array = VO[key]
	_caption(String(line[1]), 4.0, Color(0.82, 0.84, 0.78))
	var sp: AudioStreamPlayer3D = speaker if speaker else _cell_speaker
	var s := GameState.load_audio(String(line[0]))
	if s == null or sp == null:
		if then.is_valid():
			then.call()
		return
	sp.stream = s
	sp.play()
	# ⚠️ A timer on the stream's LENGTH, not `finished`: a player that never finishes (a
	# stripped or silent audio driver) would otherwise leave you strapped to the bed forever.
	if then.is_valid():
		get_tree().create_timer(s.get_length() + 0.25).timeout.connect(then)


# ⚠️ NO MID-FUMBLE JUMPSCARE HERE, and do not re-add one.
#
# `INTRO.md` §2 specced one ("~50-60% of the way: ONE scripted jolt — nightmare image
# flashes again for ~0.35 s + camera jolt"), it was never built, this pass built it, and the
# user cut it on the first playtest (2026-07-28): *"the screamer at the intro level is not
# needed."*
#
# The reasoning is sound and worth keeping: the cold-open jumpscare on START already spends
# that exact image, and firing it a second time four minutes into the game — in the one room
# that has no fail state — teaches the player that the image is free. Everything else in this
# room is dread that costs nothing and threatens nothing, and a startle in the middle of it
# is the only beat that was working at a different register from the rest.
#
# The dark walk is now carried entirely by the breathing behind you, the ambient
# metronome, and the stuck switch at the end of it.


# Something breathing in the dark ward.
#
# ⭐ SUPERSEDED IN PART (2026-09-24, the Intake Wing): you no longer wake in the ward. The emitter is
# spawned at the BLACKOUT (the ward door opening, _on_ward_entry_opened()), at the same (0, 1.4, 8.4)
# — 3 m from the ward entry, i.e. close and to one side as you step into the dark. The reasoning
# below (close, not far; deleted by the lights; never inspectable) still holds; the "1.61 m from where
# the player wakes" measurement is history.
#
# ⚠️ It is CLOSE, not far, and that is the beat (measured and confirmed 2026-08-16). This
# was documented for months as "at the far wall" — it is not. The emitter sits at z=+8.4
# and the player wakes on the gurney at z=+7.0: **1.61 m**, well inside its unit_size of
# 5.0, so it plays at its full BREATH_VOLUME_DB straight into the ear at the moment of
# sitting up. Then it recedes as they walk to the switch at the other end of the room.
#
# Keep it that way. Something breathing right behind you as you wake, which quietens the
# further you get from it, is a better opening than a distant sound you could walk toward
# and inspect — and it is the one beat in the room the player cannot resolve, because the
# lights coming on delete it (see _on_switch_flipped()). The node name FarBreath is kept
# only because tests/check_intro_beats.gd looks it up by name.
#
# ⚠️ On the duckable Ambience bus, so flash_scare's HoldBreath pre-duck takes it with the
# rest of the world.
func _spawn_far_breath() -> void:
	var s := GameState.load_audio("nook_breath")
	if not s:
		return
	_far_breath = AudioStreamPlayer3D.new()
	_far_breath.name = "FarBreath"
	_far_breath.stream = s
	_far_breath.volume_db = BREATH_VOLUME_DB
	_far_breath.unit_size = 5.0
	_far_breath.bus = AudioBuses.AMBIENCE
	# Just inside WallFront, the one wall in the room with nothing on it at all — and
	# 1.6 m from where the player wakes. See the note above; this is deliberate.
	_far_breath.position = Vector3(0, 1.4, ROOM_SIZE.y / 2.0 - 0.6)
	add_child(_far_breath)
	# Every .wav.import in this project is loop_mode=0, so loops are self-restarted.
	_far_breath.finished.connect(_far_breath.play)
	_far_breath.play()


# A level-LOCAL scare metronome at zero panic.
#
# ⚠️ Deliberately NOT RandomAmbient.register_player(). That autoload is global and carries
# 5 / 8 / 12 panic per event, which would give this room a fail state by the back door and
# break the "unloseable intro" rule. This plays the same kinds of sound and adds nothing.
func _start_local_ambient() -> void:
	_ambient_timer = Timer.new()
	_ambient_timer.one_shot = true
	_ambient_timer.timeout.connect(_on_local_ambient)
	add_child(_ambient_timer)
	_ambient_timer.start(randf_range(AMBIENT_MIN, AMBIENT_MAX))


func _on_local_ambient() -> void:
	var pick: String = ["floor_creak", "pipe_groan", "gurney_creak"].pick_random()
	var s := GameState.load_audio(pick)
	if s:
		var p := AudioStreamPlayer3D.new()
		p.stream = s
		p.volume_db = -8.0
		p.bus = AudioBuses.AMBIENCE
		# Somewhere in the room that is not on top of the player.
		p.position = Vector3(
			randf_range(-ROOM_SIZE.x / 2.0 + 1.0, ROOM_SIZE.x / 2.0 - 1.0),
			randf_range(0.3, 2.4),
			randf_range(-ROOM_SIZE.y / 2.0 + 1.0, ROOM_SIZE.y / 2.0 - 1.0))
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	if _ambient_timer:
		_ambient_timer.start(randf_range(AMBIENT_MIN, AMBIENT_MAX))


func _spawn_path_glow() -> void:
	# ⭐ From the WARD ENTRY now (2026-09-24): the blind walk starts at the door you came in by.
	var g0 := Vector2(WARD_ENTRY.x, WARD_ENTRY.z - 0.8)
	var g1 := Vector2(SWITCH_POS.x, SWITCH_POS.z)
	for progress in [0.2, 0.45, 0.7, 0.9]:
		var xz := g0.lerp(g1, progress)
		var light := OmniLight3D.new()
		light.name = "PathGlow"
		light.position = Vector3(xz.x, PATH_GLOW_Y, xz.y)
		light.light_energy = PATH_GLOW_ENERGY
		light.omni_range = PATH_GLOW_RANGE
		light.light_color = Color(0.6, 0.45, 0.3)
		add_child(light)
		_path_glow_lights.append(light)

	var hum := GameState.load_audio("emergency_hum")
	if hum:
		_path_glow_audio = AudioStreamPlayer3D.new()
		_path_glow_audio.stream = hum
		_path_glow_audio.volume_db = -18.0
		var mid := g0.lerp(g1, 0.5)
		_path_glow_audio.position = Vector3(mid.x, PATH_GLOW_Y, mid.y)
		add_child(_path_glow_audio)
		_path_glow_audio.finished.connect(_path_glow_audio.play)
		_path_glow_audio.play()


func _spawn_light_switch() -> void:
	var sw := LightSwitch.new()
	sw.name = "LightSwitch"   # findable by name for tests/check_intro_gate.gd
	sw.position = SWITCH_POS
	# The switch's own local +Z is its face normal; WallLeft is at x=-6.0 so "into
	# the room" is +X. Without this the plate stood parallel to the wall instead
	# of flush against it — visible edge-on, not as a mounted switch.
	sw.rotation.y = PI / 2.0
	sw.presses_needed = SWITCH_PRESSES
	sw.stuck.connect(_on_switch_stuck)
	sw.flipped.connect(_on_switch_flipped)
	add_child(sw)


# The first press does not work.
#
# The switch clunks, and one tube at the FAR end of the ward — the end the player is
# walking toward — stutters alight for GLIMPSE_TIME and dies. That is the whole beat: for
# a third of a second the room is not an abstract dark space, it is a ward with things in
# it, and then it is taken away again. Nothing chases, nothing spawns, no panic is added
# (this room has no fail state and must not gain one).
#
# ⚠️ WHICH TUBE — overridden 2026-08-16, and the old reasoning is kept because it was
# sound. It used to be the FAR tube (z=-6), on the grounds that the glimpse should show the
# player somewhere they have NOT been: they wake at z=+7 and the table, wheelchair and door
# are all at negative z. That argument is fine and it lost to a measurement. The far tube
# has omni_range 9 from z=-6, and everything the whole "the ward is occupied" pass built —
# both sheeted beds, both IV stands — sat at z=+5..+6.5, eleven metres away and completely
# out of reach. The best beat in the room was lighting bare floor. It is now the MIDDLE
# tube (z=0), with one occupied bed pulled into its pool (GLIMPSE_GURNEY_POS).
#
# The middle tube is chosen over simply moving the beds because of what happens LATER:
# _on_switch_flipped() deliberately leaves the tube over the table dead forever. So this
# 0.4 s flash is the only moment in the entire game that the centre of the ward is lit from
# above, and for the rest of the level that exact spot is a hole in the ceiling light.
#
# ⚠️ Raises a LIGHT, never emission (Issues 21/27/33). And it tweens back to exactly 0.0
# rather than to a small value, so a stuck press cannot leave the room permanently dimly
# lit and rob the reveal of its contrast.
func _on_switch_stuck(_press_index: int) -> void:
	# ⚠️ LOUD, and told in words (playtest 2026-07-28: *"the switch starting from the second
	# time is fine, but you need to accompany it with the sound and something like press E
	# again"*). The clunk was already here at default volume and did not register, and a
	# stuck switch that gives no feedback is indistinguishable from a broken game — which was
	# the one risk this beat carried. Two channels now: a heavier clunk plus a dead spark,
	# and an explicit prompt.
	# Prefers a purpose-made `switch_stuck` if one exists (see TODO_sounds.md) and otherwise
	# layers the working clunk with a dead spark. The guard means dropping the real file in
	# needs no code change.
	if GameState.load_audio("switch_stuck"):
		_play_at_switch("switch_stuck", 3.0)
	else:
		_play_at_switch("switch_clunk", 4.0)
		_play_at_switch("breaker_spark", -6.0)
	_show_switch_text(STIFF_SWITCH_TEXT, 3.0)

	var tube := _glimpse_light()
	if tube:
		var t := create_tween()
		t.tween_property(tube, "light_energy", GLIMPSE_ENERGY, 0.06)
		t.tween_interval(GLIMPSE_TIME)
		t.tween_property(tube, "light_energy", 0.0, 0.10)
		# A dying tube, not a working one: the buzz is quiet and it stops with the light.
		var buzz := GameState.load_audio("fluorescent_buzz_on")
		if buzz:
			var bp := AudioStreamPlayer3D.new()
			bp.stream = buzz
			bp.volume_db = -12.0
			bp.position = tube.position
			add_child(bp)
			bp.finished.connect(bp.queue_free)
			bp.play()


# The tube the stuck press briefly wakes: the one over the table, which is also the one
# _on_switch_flipped() leaves dead forever. See that function's ⚠️ for the full reasoning.
func _glimpse_light() -> OmniLight3D:
	for light in _ceiling_lights:
		if is_equal_approx((light as OmniLight3D).position.z, TABLE_POS.z):
			return light
	return null


# The stuck-press line.
#
# Local rather than ScreenText.toast() for one reason: toast() is hard-anchored to
# PRESET_CENTER, i.e. it lands on the crosshair, which is by definition on the object it is
# describing — the 2026-08-16 capture is the text printed across the switch plate. Fixing
# that properly means an anchor argument on screen_text.gd, which is a shared file with 18
# call sites in 11 other files and is out of scope for a level pass; it is filed in
# backlogs/00-cross-level.md instead. The outline convention matches ScreenText._outline().
func _show_switch_text(text: String, seconds: float) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 45
	add_child(canvas)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.position.y -= 210.0
	lbl.add_theme_color_override("font_color", ScreenText.BLOOD)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.modulate.a = 0.0
	canvas.add_child(lbl)

	# Connected, never awaited — an awaited timer dies with the node that started it
	# (Issue 6), which is the same reason ScreenText cleans up this way.
	var t := canvas.create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.25)
	t.tween_interval(seconds)
	t.tween_property(lbl, "modulate:a", 0.0, 0.6)
	t.finished.connect(canvas.queue_free)


func _play_at_switch(base_name: String, volume_db: float = 0.0) -> void:
	var s := GameState.load_audio(base_name)
	if not s:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.position = SWITCH_POS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _on_switch_flipped() -> void:
	_play_at_switch("switch_clunk")

	# ⚠️ FIRST, before a single light moves. One of the two covered beds — the one the
	# stuck press showed you (GLIMPSE_GURNEY_POS) — is empty when the lights come on.
	#
	# This is the whole point of the glimpse. Without it that 0.4 s flash is a mood beat
	# and nothing more; with it, the flash is the only evidence that the room used to be
	# different, and a player who did not look during it loses nothing and never knows.
	#
	# It is SCARY.md P6 / MovedProp's register, not a scare: no sound, no panic, no camera
	# move, no acknowledgement, and nothing ever looks at the player. It is unwitnessable
	# by construction — the room is still pitch black on this line, the switch is 9.5 m
	# from the bed, and the first flicker tween is not created until further down.
	#
	# ⚠️ queue_free(), not `visible = false`. Node3D visibility is inherited but CSG
	# COLLISION is not — hiding the form would leave an invisible body on the mattress
	# (the same trap glitch_wall.gd's set_seam_visible() documents from the other side).
	if is_instance_valid(_glimpse_form):
		_glimpse_form.queue_free()
	_glimpse_form = null

	player.unlock_flashlight()

	_switch_flipped = true
	_refresh_exit_lock()
	# The switch is the wing's power, not just the ward's: every bulb that died with the blackout
	# comes back with it (the torch already has, two lines up).
	_restore_wing_power()

	for light in _path_glow_lights:
		var t := create_tween()
		t.tween_property(light, "light_energy", 0.0, 0.6)
		t.finished.connect(light.queue_free)
	_path_glow_lights.clear()

	if _path_glow_audio:
		_path_glow_audio.finished.disconnect(_path_glow_audio.play)
		var at := create_tween()
		at.tween_property(_path_glow_audio, "volume_db", -40.0, 0.6)
		at.finished.connect(_path_glow_audio.queue_free)
		_path_glow_audio = null

	# The breathing stops with the darkness. It is never available for inspection under
	# the lights — a sound the player cannot go and check is a sound they keep.
	if _far_breath:
		_far_breath.finished.disconnect(_far_breath.play)
		var bt := create_tween()
		bt.tween_property(_far_breath, "volume_db", -50.0, 0.5)
		bt.finished.connect(_far_breath.queue_free)
		_far_breath = null

	# ⚠️ One tube stays dead — the one over the table (z = TABLE_POS.z), so the note the
	# player has to walk over and read is lit by the candle alone. The reveal otherwise
	# floods the room evenly and hands back every shadow the fumble just earned; leaving a
	# hole in the middle of the ceiling keeps the one place the player MUST stand still
	# lit by a single flickering source.
	for light in _ceiling_lights:
		if is_equal_approx((light as OmniLight3D).position.z, TABLE_POS.z):
			continue
		_flicker_on(light, 0.9)

	# ⚠️ `visible` MUST be restored, not just the energy (fixed 2026-08-16). `_darken_scene()`
	# hides this light for the blind fumble and nothing ever un-hid it, so for the life of
	# the procedural room the candle tweened up to a perfectly good 1.97 energy on a node
	# that was still invisible — and a hidden Node3D light emits NOTHING. Combined with the
	# tube above deliberately staying dead, the note the player is REQUIRED to read was the
	# darkest object in the room. `tests/check_intro_beats.gd` asserted the dead tube and
	# never the lit candle, i.e. it asserted the absence half of its own sentence.
	candle_light.visible = true
	if _candle_flame:
		_candle_flame.visible = true
	var ct := create_tween()
	ct.tween_property(candle_light, "light_energy", BASE_ENERGY, 1.0)
	ct.finished.connect(func(): _candle_lit = true)

	var buzz := GameState.load_audio("fluorescent_buzz_on")
	if buzz:
		var bp := AudioStreamPlayer3D.new()
		bp.stream = buzz
		bp.position = Vector3(0, ROOM_HEIGHT - 0.3, 0)
		add_child(bp)
		bp.finished.connect(bp.queue_free)
		bp.play()

	if _env:
		var et := create_tween()
		et.set_parallel(true)
		et.tween_property(_env, "ambient_light_energy", NORMAL_AMBIENT, 1.2)
		et.tween_property(_env, "ambient_light_color", LIT_AMBIENT_COLOR, 1.2)

	_show_controls_hint()


func _flicker_on(light: Light3D, target: float) -> void:
	var t := create_tween()
	for i in range(3):
		t.tween_property(light, "light_energy", target * randf_range(0.15, 0.6), 0.05)
		t.tween_property(light, "light_energy", 0.0, 0.05)
	t.tween_property(light, "light_energy", target, 0.3)


# ================================================================ THE INTAKE WING (2026-09-24)
#
# Five rooms around the ward, in the derelict-asylum look of the cold-open video (intro_scene.ogv:
# peeling grey-green plaster over a dark wainscot, bare caged bulbs, wet stained floors). The
# experiment's own kit — the tannoy, the camera and its red lamp, the one-way glass, the tray — is
# newer than the building, and that contrast is the "someone is running this" tell.
#   Cell      wake strapped; three straps; sink, smashed mirror, 46 tally marks, your wristband
#   Corridor  the dream's corridor, awake. Nothing happens
#   Hall      the observers' side of the glass; the torch is ISSUED here; your bed is occupied
#   Ward      the old intro, entered through a door that kills every light in the wing
#   Calibration / Airlock   phase 5; for now a lit room and the advancing ExitDoor
#
# ⚠️ ZERO PANIC ANYWHERE IN THIS SECTION. The bar must read exactly 0 through cell, hall and ward
# (check_intro_beats); only calibration moves it. Nothing here calls add_panic, registers with
# RandomAmbient, or builds a ScaryObject.

func _build_wing() -> void:
	_build_doors()
	_build_windows()
	_build_bulbs()
	_build_cell()
	_build_hall()
	_build_corridor()


# ---------------------------------------------------------------- small builders

func _mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _mbox(n: String, size: Vector3, pos: Vector3, m: Material, parent: Node = null,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	mi.set_surface_override_material(0, m)
	(parent if parent else self).add_child(mi)
	return mi


func _mcyl(n: String, r: float, h: float, pos: Vector3, m: Material, parent: Node = null,
		rot: Vector3 = Vector3.ZERO, r_top: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var cm := CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	mi.set_surface_override_material(0, m)
	(parent if parent else self).add_child(mi)
	return mi


func _art(n: String, size: Vector2, pos: Vector3, rot: Vector3, tex_file: String,
		emission: float = 0.0, parent: Node = null, alpha: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.position = pos
	mi.rotation = rot
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	if ResourceLoader.exists(TEX + tex_file):
		var tex: Texture2D = load(TEX + tex_file)
		m.albedo_texture = tex
		if emission > 0.0:
			m.emission_enabled = true
			m.emission_texture = tex
			m.emission_energy_multiplier = emission
	else:
		m.albedo_color = Color(0.6, 0.58, 0.5)
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	(parent if parent else self).add_child(mi)
	return mi


# A solid, invisible box collider — furniture stops the player; its meshes are separate.
func _solid(n: String, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.position = pos
	b.rotation.y = rot_y
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	c.shape = sh
	b.add_child(c)
	add_child(b)
	return b


func _sfx_at(base_name: String, pos: Vector3, db: float = 0.0, unit: float = 4.0) -> AudioStreamPlayer3D:
	var s := GameState.load_audio(base_name)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.unit_size = unit
	p.position = pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


# A looping emitter (every .wav.import here is loop_mode=0, so loops restart themselves).
func _loop_at(n: String, base_name: String, pos: Vector3, db: float, unit: float) -> AudioStreamPlayer3D:
	var s := GameState.load_audio(base_name)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.stream = s
	p.volume_db = db
	p.unit_size = unit
	p.bus = AudioBuses.AMBIENCE
	p.position = pos
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	return p


# ---------------------------------------------------------------- doors, glass, bulbs

func _build_doors() -> void:
	for d in DOORS:
		var wd := WingDoor.new()
		wd.name = String(d["name"])
		wd.door_width = float(d["width"])
		wd.door_height = float(d["h"])
		wd.swing_sign = float(d.get("swing", 1.0))
		wd.texture_path = TEX + "asylum_door.png"
		wd.infill_material = _wall_mat
		var p: Vector2 = d["pos"]
		wd.position = Vector3(p.x, 0, p.y)
		wd.rotation.y = float(d.get("yaw", 0.0))
		add_child(wd)
		_doors[wd.name] = wd
	# The cell door is opened BY THE LEVEL, after the third strap; E on it before then rattles.
	(_doors["CellDoor"] as WingDoor).locked = true
	(_doors["CellDoor"] as WingDoor).locked_message = "Locked."
	(_doors["WardEntryDoor"] as WingDoor).opened.connect(_on_ward_entry_opened)


# The one-way glass in the cell/hall wall. RoomBuilder cut it full height like a doorway; this
# closes it with wall below the sill and above the head (CSG, the wall's own material, exactly T
# deep — faces continue the wall's, adjacent not overlapping), frames it, and glazes it.
#
# ⚠️ TWO SINGLE-SIDED QUADS, back to back — no SubViewport, no mirror tech (the plan's call). The
# CELL side is an opaque dark gloss pane: from your bed it is a blank black window that throws
# the bulb back at you. The HALL side is near-clear, and because each quad culls its back face, from
# the hall you look straight through the (culled) cell-side quad into the lit cell. It reads because
# the hall is DARKER than the cell (HALL_BULB_ENERGY vs CELL_BULB_ENERGY) — the same physics that
# makes a real one work. Neither quad casts a shadow, so the cell's light does spill into the hall.
func _build_windows() -> void:
	var frame_mat := _mat(Color(0.14, 0.15, 0.15), 0.7, 0.3)
	for w in WINDOWS:
		var p: Vector2 = w["pos"]
		var wid: float = w["width"]
		var sill: float = w["sill"]
		var top: float = w["top"]
		var sb := _make_box(String(w["name"]) + "_Sill", Vector3(wid, sill, WALL_T), Vector3(p.x, sill / 2.0, p.y))
		sb.material = _wall_mat
		var hh := WING_H - top
		var hb := _make_box(String(w["name"]) + "_Head", Vector3(wid, hh, WALL_T), Vector3(p.x, top + hh / 2.0, p.y))
		hb.material = _wall_mat
		# Frame: lapping 2 cm into the opening (WingDoor's jamb rule) and 3 cm proud of each face.
		var fd := 0.26
		var fw := 0.07
		var mid := (sill + top) / 2.0
		for side in [-1.0, 1.0]:
			_mbox("GlassFrameV", Vector3(fw, top - sill + fw * 2.0 - 0.04, fd),
				Vector3(p.x + side * (wid / 2.0 + fw / 2.0 - 0.02), mid, p.y), frame_mat)
		_mbox("GlassFrameSill", Vector3(wid + fw * 2.0, fw, fd), Vector3(p.x, sill + fw / 2.0 - 0.02, p.y), frame_mat)
		_mbox("GlassFrameHead", Vector3(wid + fw * 2.0, fw, fd), Vector3(p.x, top - fw / 2.0 + 0.02, p.y), frame_mat)
		var gsize := Vector2(wid - 0.04, top - sill - 0.04)
		# Cell side: faces +z (the cell is north of the glass).
		var cell_q := MeshInstance3D.new()
		cell_q.name = "GlassCellSide"
		var q1 := QuadMesh.new()
		q1.size = gsize
		cell_q.mesh = q1
		cell_q.position = Vector3(p.x, mid, p.y + 0.004)
		# Not pure black: at 0.025 albedo it rendered as a hole in the wall; a little albedo and a
		# rougher gloss make it read as a pane that catches the bulb.
		cell_q.material_override = _mat(Color(0.05, 0.06, 0.065), 0.22, 0.6)
		cell_q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cell_q)
		# Hall side: faces -z, a faint tint over a clear view.
		var hall_q := MeshInstance3D.new()
		hall_q.name = "GlassHallSide"
		var q2 := QuadMesh.new()
		q2.size = gsize
		hall_q.mesh = q2
		hall_q.position = Vector3(p.x, mid, p.y - 0.004)
		hall_q.rotation.y = PI
		var gm := _mat(Color(0.30, 0.36, 0.36, 0.14), 0.05, 0.0)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hall_q.material_override = gm
		hall_q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hall_q)
		# ⚠️ The pane is SOLID. Quads have no collision, so without this the opening was air: the
		# interact ray reached the cell's straps and wristband from the hall, through the glass.
		var pane := _solid(String(w["name"]) + "_Pane", Vector3(wid, top - sill, 0.04), Vector3(p.x, mid, p.y))
		pane.set_meta("glass", true)


# Bare bulbs in wire cages, on a cord from the ceiling — the cold open's lighting, exactly.
# ⚠️ Shadowed: the wing's rooms share 0.2 m walls, and an unshadowed OmniLight lights straight
# through them (the cell's bulb would light the hall's floor and desk through the glass wall).
const WING_BULBS := [
	["Cell", Vector3(-6.2, WING_H - 0.6, 22.2), CELL_BULB_ENERGY, 6.0],
	["Hall", Vector3(-8.3, WING_H - 0.6, 16.6), HALL_BULB_ENERGY, 5.0],
	["Corridor0", Vector3(-3.0, WING_H - 0.55, 12.0), CORRIDOR_BULB_ENERGY, 5.5],
	["Corridor1", Vector3(-3.0, WING_H - 0.55, 17.5), CORRIDOR_BULB_ENERGY, 5.5],
	["Corridor2", Vector3(-3.0, WING_H - 0.55, 22.8), CORRIDOR_BULB_ENERGY, 5.5],
	["Calibration", Vector3(0.0, 3.4 - 0.6, -15.0), 0.8, 8.0],
	["Airlock", Vector3(-5.5, WING_H - 0.6, -18.5), 0.7, 4.0],
]

func _build_bulbs() -> void:
	for b in WING_BULBS:
		_add_bulb(String(b[0]), b[1], float(b[2]), float(b[3]))


func _add_bulb(n: String, pos: Vector3, energy: float, rng: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Bulb_" + n
	light.position = pos
	light.light_energy = energy
	light.light_color = BULB_COLOR
	light.omni_range = rng
	light.omni_attenuation = 1.3
	light.shadow_enabled = true
	add_child(light)
	var dark_metal := _mat(Color(0.08, 0.08, 0.08), 0.6, 0.5)
	# The cord runs from the socket to the ceiling (0.55-0.6 m above the bulb).
	# ⚠️ Shadowless, all of it: the socket sits between the bulb and the ceiling, and as a caster it
	# threw a black disc a metre across onto the ceiling right over every bulb (first render).
	for part in [_mcyl("BulbCord", 0.005, 0.56, Vector3(0, 0.34, 0), dark_metal, light),
			_mcyl("BulbSocket", 0.022, 0.07, Vector3(0, 0.075, 0), dark_metal, light)]:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm := _mat(Color(0.16, 0.14, 0.11), 0.4)   # DARK albedo: the glow is emission (Issue 21)
	bm.emission_enabled = true
	bm.emission = BULB_COLOR
	bm.emission_energy_multiplier = BULB_EMISSION
	var bulb := MeshInstance3D.new()
	bulb.name = "BulbGlass"
	var sm := SphereMesh.new()
	sm.radius = 0.042
	sm.height = 0.1
	bulb.mesh = sm
	bulb.set_surface_override_material(0, bm)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(bulb)
	# The cage: four wires and two rings. Shadowless too — a cage that shadows its own bulb blacks
	# out the room in four stripes.
	var wire := _mat(Color(0.1, 0.1, 0.1), 0.5, 0.6)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		var w := _mbox("CageWire", Vector3(0.005, 0.15, 0.005),
			Vector3(cos(a) * 0.062, -0.01, sin(a) * 0.062), wire, light)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [0.055, -0.08]:
		var ring := MeshInstance3D.new()
		ring.name = "CageRing"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.058
		tm.outer_radius = 0.066
		ring.mesh = tm
		ring.position = Vector3(0, y, 0)
		ring.set_surface_override_material(0, wire)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		light.add_child(ring)
	var hum := _loop_at("BulbHum_" + n, "intro_bulb_hum", pos, -24.0, 1.2)
	_bulbs.append([light, energy, bm, hum])


# ---------------------------------------------------------------- the blackout / the power

# ⭐ The ward door's `opened` fires BEFORE the leaf moves, so the ward is never seen lit: every
# bulb in the wing dies, the torch is taken (locked — the switch gives it back), the ambient goes to
# zero, and the dark walk begins — path glow from this door to the switch, breathing in the ward.
func _on_ward_entry_opened() -> void:
	if _beats.has("blackout"):
		return
	_advance("blackout")
	# VO2: the observer, mid-sentence, cut off by the same relay that takes the lights.
	_say("fault", Callable(), _ward_speaker)
	_sfx_at("intro_power_cut", WARD_ENTRY + Vector3(0, 2.2, 0.5), 2.0, 8.0)
	HoldBreath.dip(get_tree(), 0.4)
	for b in _bulbs:
		(b[0] as Light3D).light_energy = 0.0
		(b[2] as StandardMaterial3D).emission_energy_multiplier = 0.0
		if b[3]:
			(b[3] as AudioStreamPlayer3D).stop()
	if _monitor_light:
		_monitor_light.visible = false
	if _env:
		_env.ambient_light_energy = 0.0
	player.lock_flashlight()
	_spawn_path_glow()
	_spawn_far_breath()


func _restore_wing_power() -> void:
	for b in _bulbs:
		_flicker_on(b[0] as Light3D, float(b[1]))
		var m := b[2] as StandardMaterial3D
		var t := create_tween()
		t.tween_property(m, "emission_energy_multiplier", BULB_EMISSION, 0.6)
		if b[3]:
			(b[3] as AudioStreamPlayer3D).play()
	if _monitor_light:
		_monitor_light.visible = true


# ---------------------------------------------------------------- the cell

func _build_cell() -> void:
	_build_gurney(CELL_GURNEY_POS, false, "cell_pad.png")
	_build_straps()
	_build_bedside()
	_build_sink()
	_build_cell_kit()
	# 46 marks, gouged into the plaster beside the bed. ⚠️ ABOVE THE DADO LINE (1.0 m): dark marks
	# on the dark wainscot were invisible (the review: "read small"); on the pale plaster, 1.3 m wide,
	# they read from the bed.
	_art("TallyMarks", Vector2(1.3, 0.65), Vector3(-8.2 + WALL_T / 2.0 + 0.025, 1.5, 23.05),
		Vector3(0, PI / 2.0, 0), "tally_marks.png", 0.0, null, true)


# ⭐ LEATHER STRAPS WITH A BUCKLE (2026-09-24, the review: "flat brown sticks"). Each loose end is a
# thin band from a PIVOT on the frame's edge, ending in a steel ring buckle with its tongue; the
# anchored end drops down the frame's side. The ankle strap is two halves, so each hangs clear of the
# floor. ⭐ ALREADY UNBUCKLED (third hand playtest, 2026-09-25): every loose end is built swung over
# its pivot and hanging down the bed's side. They are SCENERY — plain Node3D, no interact(), no
# prompt: someone let you out, and the figure strapped to the same bed through the glass is the
# contrast.
const STRAP_BAND_T := 0.008
const STRAP_BAND_W := 0.06
const STRAP_PIVOT_X := 0.462           # just outside the deck's 0.45 half-width
const STRAP_WRIST_LEN := 0.36
const STRAP_ANKLE_LEN := 0.46
# ⭐ The straps lie OVER the sheet: pivots 2.4 cm above the pad (the sheet rides at ~1.4 cm plus its
# wrinkle). Since the sheet is PLAIN (2026-09-25) there are no shins to clear, so the ankle halves
# meet just above the cloth instead of 0.14 m up over a leg crest.
const STRAP_PIVOT_Y := 0.024
const ANKLE_APEX := 0.035

func _build_straps() -> void:
	var leather := _mat(Color(0.19, 0.12, 0.07), 0.62)
	var steel := _mat(Color(0.62, 0.62, 0.6), 0.3, 0.85)
	for i in STRAPS.size():
		var off: Vector2 = STRAPS[i]
		var ankles := i == 2
		var base := CELL_GURNEY_POS + Vector3(off.x, GURNEY_TOP_Y, off.y)
		var prop := Node3D.new()
		prop.name = "Strap_%d" % i
		prop.position = base
		add_child(prop)
		var pivots: Array = []
		var sides: Array = [-1.0, 1.0] if ankles else [signf(off.x)]
		for side in sides:
			var length: float = STRAP_ANKLE_LEN if ankles else STRAP_WRIST_LEN
			var px: float = side * STRAP_PIVOT_X - off.x
			# The anchored end, down the frame's side (it never moves).
			_mbox("StrapAnchor", Vector3(STRAP_BAND_T, 0.15, STRAP_BAND_W),
				Vector3(px, -0.07, 0), leather, prop)
			var pivot := Node3D.new()
			pivot.name = "StrapPivot"
			pivot.position = Vector3(px, STRAP_PIVOT_Y, 0)
			if ankles:
				pivot.rotation.z = -side * atan2(ANKLE_APEX - STRAP_PIVOT_Y, STRAP_PIVOT_X)
			prop.add_child(pivot)
			# The loose end lies inward across the pad, a hair proud of it.
			_mbox("StrapBand", Vector3(length, STRAP_BAND_T, STRAP_BAND_W),
				Vector3(-side * length * 0.5, 0.0, 0), leather, pivot)
			# The buckle ring (four bars) and its tongue, at the loose end. On the ankle strap
			# only the +x half carries it — the -x half is the tongue end it buckles to.
			if not ankles or side > 0.0:
				var bx: float = -side * (length - 0.02)
				for spec in [[Vector3(0.006, 0.007, 0.07), Vector3(bx - 0.024, 0.004, 0)],
						[Vector3(0.006, 0.007, 0.07), Vector3(bx + 0.024, 0.004, 0)],
						[Vector3(0.054, 0.007, 0.006), Vector3(bx, 0.004, 0.032)],
						[Vector3(0.054, 0.007, 0.006), Vector3(bx, 0.004, -0.032)]]:
					_mbox("BuckleRing", spec[0], spec[1], steel, pivot)
				_mbox("BuckleTongue", Vector3(0.04, 0.005, 0.005), Vector3(bx - side * 0.004, 0.009, 0), steel, pivot)
			pivots.append([pivot, side])
		_straps.append(prop)
		_strap_visuals.append(pivots)
		_release_strap(i)


# Open: every loose end of this strap is swung up and over its pivot and hangs down the side.
func _release_strap(i: int) -> void:
	for pv in _strap_visuals[i]:
		var pivot: Node3D = pv[0]
		var side: float = pv[1]
		pivot.rotation.z = -side * 1.5 * PI


func _build_bedside() -> void:
	var steel := _mat(Color(0.30, 0.32, 0.30), 0.6, 0.4)
	var at := Vector3(-7.47, 0, 23.35)
	_mbox("BedsideCab", Vector3(0.4, 0.55, 0.38), at + Vector3(0, 0.275, 0), steel)
	_mbox("BedsideTop", Vector3(0.44, 0.03, 0.42), at + Vector3(0, 0.565, 0), _mat(Color(0.36, 0.37, 0.35), 0.5, 0.4))
	_mbox("BedsideDrawer", Vector3(0.34, 0.14, 0.012), at + Vector3(0, 0.42, -0.196), _mat(Color(0.26, 0.28, 0.26), 0.6, 0.4))
	_solid("BedsideBody", Vector3(0.44, 0.58, 0.42), at + Vector3(0, 0.29, 0))
	# The wristband: a note. It lies flat, so its thin axis is vertical and check_note_mounting
	# measures its backing straight down into the cabinet top.
	var band := StaticBody3D.new()
	band.name = "WristbandNote"
	band.set_script(_NOTE_SCRIPT)
	band.note_text = "A hospital wristband, cut through. Printed on it:\n\nSUBJ 47 · INTAKE 3 · ADM 04:12\n\nThe cut is clean, and recent. Somebody took it off you while you slept — and left it where you would find it."
	band.position = at + Vector3(0.02, 0.585, -0.02)
	band.rotation.y = 0.35
	add_child(band)
	var ring := MeshInstance3D.new()
	ring.name = "Band"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.03
	tm.outer_radius = 0.036
	ring.mesh = tm
	ring.scale = Vector3(1.0, 0.45, 1.25)
	ring.position = Vector3(-0.03, 0.004, 0)
	ring.set_surface_override_material(0, _mat(Color(0.78, 0.78, 0.74), 0.5))
	band.add_child(ring)
	var tag := MeshInstance3D.new()
	tag.name = "WristbandTag"
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.08, 0.02)
	tag.mesh = pm
	tag.position = Vector3(0.06, 0.004, 0)
	var tmat := StandardMaterial3D.new()
	if ResourceLoader.exists(TEX + "wristband_47.png"):
		tmat.albedo_texture = load(TEX + "wristband_47.png")
		tmat.emission_enabled = true
		tmat.emission_texture = tmat.albedo_texture
		tmat.emission_energy_multiplier = 0.2
	tag.set_surface_override_material(0, tmat)
	band.add_child(tag)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, 0.02, 0.12)
	col.shape = sh
	band.add_child(col)


# The sink, its tap, and the mirror that is not there any more.
const SINK_Z := 21.0

func _build_sink() -> void:
	var wx := -8.2 + WALL_T / 2.0            # the west wall's inner face
	# ⭐ A BASIN, not a white box (2026-09-24, the review). An open tapered bowl (a CylinderMesh
	# with no top cap, both faces drawn so you see into it), a rolled rim, a splash-back against
	# the wall, a tapered pedestal, a drain — all in grimy porcelain with rust runs.
	var porcelain := _mat(Color(0.86, 0.85, 0.8), 0.32)
	if ResourceLoader.exists(TEX + "porcelain_grime.png"):
		porcelain.albedo_texture = load(TEX + "porcelain_grime.png")
	var bowl_m := porcelain.duplicate() as StandardMaterial3D
	bowl_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var root := Node3D.new()
	root.name = "Sink"
	root.position = Vector3(wx + 0.25, 0, SINK_Z)
	add_child(root)
	var bowl := MeshInstance3D.new()
	bowl.name = "SinkBowl"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.13
	cm.height = 0.17
	cm.cap_top = false
	cm.radial_segments = 28
	bowl.mesh = cm
	bowl.scale = Vector3(1.0, 1.0, 1.25)
	bowl.position = Vector3(0, 0.78, 0)
	bowl.set_surface_override_material(0, bowl_m)
	root.add_child(bowl)
	var rim := MeshInstance3D.new()
	rim.name = "SinkRim"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.19
	tm.outer_radius = 0.235
	tm.rings = 28
	rim.mesh = tm
	rim.scale = Vector3(1.0, 0.7, 1.22)
	rim.position = Vector3(0, 0.865, 0)
	rim.set_surface_override_material(0, porcelain)
	root.add_child(rim)
	_mbox("SinkSplash", Vector3(0.05, 0.2, 0.6), Vector3(-0.235, 0.95, 0), porcelain, root)
	_mcyl("SinkPedestal", 0.07, 0.7, Vector3(0, 0.35, 0), porcelain, root, Vector3.ZERO, 0.055)
	_mcyl("SinkDrain", 0.024, 0.006, Vector3(0, 0.698, 0), _mat(Color(0.08, 0.07, 0.06), 0.4, 0.6), root)
	_mcyl("SinkDrainRing", 0.032, 0.004, Vector3(0, 0.696, 0), _mat(Color(0.45, 0.4, 0.32), 0.35, 0.8), root)
	_solid("SinkBody", Vector3(0.45, 0.87, 0.5), root.position + Vector3(0, 0.435, 0))
	# Tap: a spout off the splash-back, a drop, a cross handle.
	var chrome := _mat(Color(0.45, 0.43, 0.40), 0.35, 0.8)
	_mcyl("TapSpout", 0.012, 0.15, Vector3(-0.14, 1.0, 0), chrome, root, Vector3(0, 0, PI / 2.0))
	_mcyl("TapNose", 0.011, 0.05, Vector3(-0.07, 0.98, 0), chrome, root)
	_mbox("TapHandleA", Vector3(0.03, 0.012, 0.09), Vector3(-0.17, 1.1, 0), chrome, root)
	_mbox("TapHandleB", Vector3(0.03, 0.09, 0.012), Vector3(-0.17, 1.1, 0), chrome, root)
	# The water. Hidden until the tap is used; its colour is driven (_on_tap_used).
	_tap_mat = _mat(Color(0.42, 0.2, 0.07, 0.85), 0.1)
	_tap_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tap_stream = _mcyl("TapWater", 0.0055, 0.27, Vector3(-0.07, 0.84, 0), _tap_mat, root)
	_tap_stream.visible = false
	var tap := UseProp.new()
	tap.name = "Tap"
	tap.prompt = "E — turn the tap"
	tap.max_uses = 0
	# Generous and a little proud of the wall: the spout is 12 mm thick, and a ray to it from a low
	# eye clips the basin rim unless the volume reaches up to the handle.
	tap.position = root.position + Vector3(-0.12, 1.07, 0)
	add_child(tap)
	tap.add_box_shape(Vector3(0.26, 0.26, 0.28))
	tap.used.connect(_on_tap_used)
	_tap_audio = AudioStreamPlayer3D.new()
	_tap_audio.name = "TapAudio"
	_tap_audio.position = root.position + Vector3(0, 0.85, 0)
	_tap_audio.unit_size = 2.5
	add_child(_tap_audio)
	# The mirror: frame and backing board only, the glass gone — a few shards left in the corners.
	# ⚠️ NO reflection of any kind (the plan's call); the shards are dark gloss that only ever
	# catch the bulb.
	var frame_m := _mat(Color(0.20, 0.18, 0.15), 0.6, 0.3)
	var mz := SINK_Z
	var my := 1.62
	var fx := wx + 0.012
	# Both bite a few mm into the wall — never coplanar with its face (Issues 19/20/23).
	_mbox("MirrorBack", Vector3(0.012, 0.6, 0.44), Vector3(wx + 0.004, my, mz),
		_mat(Color(0.10, 0.09, 0.08), 0.9))
	for sy in [-1.0, 1.0]:
		_mbox("MirrorFrameH", Vector3(0.035, 0.05, 0.52), Vector3(fx, my + sy * 0.315, mz), frame_m)
	for sz in [-1.0, 1.0]:
		_mbox("MirrorFrameV", Vector3(0.035, 0.68, 0.05), Vector3(fx, my, mz + sz * 0.245), frame_m)
	var shard_m := _mat(Color(0.06, 0.07, 0.08), 0.05, 0.9)
	for sh in [[Vector3(fx + 0.004, my + 0.24, mz - 0.17), 0.7, Vector2(0.09, 0.05)],
			[Vector3(fx + 0.004, my - 0.22, mz + 0.16), -0.5, Vector2(0.12, 0.06)],
			[Vector3(fx + 0.004, my + 0.2, mz + 0.18), 2.3, Vector2(0.07, 0.04)]]:
		_mbox("MirrorShard", Vector3(0.004, (sh[2] as Vector2).y, (sh[2] as Vector2).x), sh[0], shard_m, null,
			Vector3(float(sh[1]), 0, 0))


# The observers' kit, newer than the building: a camera with its red lamp, a tannoy.
func _build_cell_kit() -> void:
	var nz := 24.0 - WALL_T / 2.0            # the north wall's inner face
	var kit := _mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	var cam := Node3D.new()
	cam.name = "CellCamera"
	cam.position = Vector3(-4.75, 2.62, nz - 0.2)
	add_child(cam)
	_mbox("CamBracket", Vector3(0.05, 0.05, 0.2), Vector3(0, 0.06, 0.1 - 0.005), kit, cam)
	var body := Node3D.new()
	cam.add_child(body)
	body.look_at_from_position(cam.position, CELL_GURNEY_POS + Vector3(0, 0.8, 0.3), Vector3.UP)
	body.position = Vector3.ZERO
	_mbox("CamBody", Vector3(0.11, 0.09, 0.22), Vector3(0, 0, -0.02), _mat(Color(0.62, 0.62, 0.58), 0.5, 0.2), body)
	_mcyl("CamLens", 0.03, 0.05, Vector3(0, 0, -0.15), kit, body, Vector3(PI / 2.0, 0, 0))
	_monitor_lamp = _mat(Color(0.2, 0.02, 0.02), 0.4)
	_monitor_lamp.emission_enabled = true
	_monitor_lamp.emission = Color(1.0, 0.08, 0.05)
	_monitor_lamp.emission_energy_multiplier = 0.5
	var lamp := MeshInstance3D.new()
	lamp.name = "MonitorLamp"
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.028
	lamp.mesh = sm
	lamp.position = Vector3(0.03, 0.055, -0.08)
	lamp.set_surface_override_material(0, _monitor_lamp)
	body.add_child(lamp)
	_monitor_light = OmniLight3D.new()
	_monitor_light.name = "MonitorLampLight"
	_monitor_light.light_color = Color(1.0, 0.1, 0.06)
	_monitor_light.light_energy = 0.12
	_monitor_light.omni_range = 1.0
	_monitor_light.position = cam.position + Vector3(0, 0.06, -0.08)
	add_child(_monitor_light)
	# The tannoy, high on the north wall over the bed's west side.
	var spk_pos := Vector3(-7.55, 2.55, nz - 0.08)
	_mbox("TannoyBox", Vector3(0.32, 0.22, 0.14), spk_pos + Vector3(0, 0, 0.01), kit)
	_mbox("TannoyGrille", Vector3(0.26, 0.16, 0.01), spk_pos + Vector3(0, 0, -0.065), _mat(Color(0.05, 0.05, 0.05), 0.9))
	_cell_speaker = AudioStreamPlayer3D.new()
	_cell_speaker.name = "CellSpeaker"
	_cell_speaker.position = spk_pos
	_cell_speaker.unit_size = 14.0
	_cell_speaker.volume_db = VO_DB
	add_child(_cell_speaker)


# Off the bed and on your feet, facing the cell door. VO1 speaks as you rise; the door releases
# when the line ends (_say's timer on the stream's length, so a silent audio driver cannot strand you).
func _stand_up() -> void:
	_say("morning", _release_cell_door)
	var from := player.global_position
	var to := CELL_STAND_POS
	var t := create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_player_pos, from, to, STAND_TIME)
	t.tween_property(player.camera, "position:y", STANDING_EYE, STAND_TIME)
	var door: WingDoor = _doors.get("CellDoor")
	if door:
		# turn_to_face measures from where the body IS (the bed); aim from where it WILL be (the
		# floor), and give it a level head: its pitch uses the current eye height (0.85).
		var d := door.global_position + (from - to)
		player.turn_to_face(Vector3(d.x, from.y + WAKE_CAM_SITTING, d.z), STAND_TIME)
	t.finished.connect(_on_stood_up)


func _set_player_pos(v: Vector3) -> void:
	player.global_position = v
	player.velocity = Vector3.ZERO


# ⚠️ The beat is still called "straps" — it means "out of the bed" (the hall glimpse and the
# back-door restore key off it); there is nothing left to unbuckle.
func _on_stood_up() -> void:
	player.unfreeze_input()
	_advance("straps")


func _release_cell_door() -> void:
	var door: WingDoor = _doors.get("CellDoor")
	if door == null:
		return
	_sfx_at("intro_cell_buzz", door.global_position + Vector3(0, 2.2, 0), 2.0, 5.0)
	get_tree().create_timer(1.15).timeout.connect(_open_cell_door)


func _open_cell_door() -> void:
	var door: WingDoor = _doors.get("CellDoor")
	if door:
		door.unlock()
		door.open()


# ---------------------------------------------------------------- the tap

func _on_tap_used(times: int) -> void:
	_tap_on = not _tap_on
	_tap_stream.visible = _tap_on
	if not _tap_on:
		_tap_audio.stop()
		return
	if times == 1:
		# The first turn: the pipe coughs rust for three seconds, then runs clear.
		_tap_mat.albedo_color = Color(0.42, 0.2, 0.07, 0.85)
		_play_tap("intro_tap_rust")
		var t := create_tween()
		t.tween_interval(2.6)
		t.tween_property(_tap_mat, "albedo_color", Color(0.72, 0.8, 0.84, 0.38), 0.9)
		get_tree().create_timer(3.2).timeout.connect(_on_tap_rust_done)
	else:
		_play_tap("intro_tap_water")


func _on_tap_rust_done() -> void:
	if _tap_on:
		_play_tap("intro_tap_water")


func _play_tap(base: String) -> void:
	var s := GameState.load_audio(base)
	if s == null:
		return
	if _tap_audio.finished.is_connected(_tap_audio.play):
		_tap_audio.finished.disconnect(_tap_audio.play)
	_tap_audio.stream = s
	_tap_audio.volume_db = -6.0
	_tap_audio.play()
	if base == "intro_tap_water":
		_tap_audio.finished.connect(_tap_audio.play)


# ---------------------------------------------------------------- the hall

const DESK_POS := Vector3(-6.2, 0, 19.42)
const DESK_TOP := 0.76

func _build_hall() -> void:
	_build_desk()
	_build_reel()
	_build_torch_tray()
	var dt := DESK_POS + Vector3(0, DESK_TOP, 0)
	# Your file, open on the desk in front of the observer's chair — Subject 46's page stapled in.
	var file := StaticBody3D.new()
	file.name = "SubjectFile"
	file.set_script(_NOTE_SCRIPT)
	file.note_text = FILE_TEXT
	file.position = dt + Vector3(-0.7, 0.004, -0.12)
	# ⚠️ Lying flat with its OWN +z pointing UP (a QuadMesh on a body pitched -90°), not a
	# PlaneMesh on an upright body: check_prop_mounting reads a prop's facing off its +z, and an
	# upright body lying on a desk measured as a wall panel 0.21 m in front of the chair behind it.
	file.rotation = Vector3(-PI / 2.0, 0.08, 0)
	add_child(file)
	var fq := MeshInstance3D.new()
	fq.name = "FileFace"
	var fpm := QuadMesh.new()
	fpm.size = Vector2(0.42, 0.28)
	fq.mesh = fpm
	var fm := StandardMaterial3D.new()
	if ResourceLoader.exists(TEX + "file_subject47.png"):
		fm.albedo_texture = load(TEX + "file_subject47.png")
		fm.emission_enabled = true
		fm.emission_texture = fm.albedo_texture
		fm.emission_energy_multiplier = 0.25
	fq.set_surface_override_material(0, fm)
	file.add_child(fq)
	var fc := CollisionShape3D.new()
	var fsh := BoxShape3D.new()
	fsh.size = Vector3(0.42, 0.28, 0.02)
	fc.shape = fsh
	file.add_child(fc)
	# The observation log, on a clipboard hung on the south wall.
	var lp := _builder.wall_point("Hall", Vector2(0, -1), 1.45, 0.13)
	lp.x = -8.6
	var logn := StaticBody3D.new()
	logn.name = "ObserverLog"
	logn.set_script(_NOTE_SCRIPT)
	logn.note_text = LOG_TEXT
	logn.position = lp
	add_child(logn)
	_mbox("Clipboard", Vector3(0.27, 0.37, 0.012), Vector3(0, 0, -0.012), _mat(Color(0.26, 0.19, 0.12), 0.8), logn)
	_art("LogPage", Vector2(0.24, 0.32), Vector3(0, -0.015, 0.0), Vector3.ZERO, "observer_log.png", 0.25, logn)
	var lc := CollisionShape3D.new()
	var lsh := BoxShape3D.new()
	lsh.size = Vector3(0.3, 0.4, 0.06)
	lc.shape = lsh
	logn.add_child(lc)
	# The cabinet: three cut wristbands in one of its drawers.
	var cab := LabCabinet.new()
	cab.name = "HallCabinet"
	cab.position = Vector3(-10.2 + WALL_T / 2.0 + LabCabinet.SIZE.z / 2.0 + 0.01, 0, 16.9)
	cab.rotation.y = PI / 2.0
	add_child(cab)
	cab.assign_note(BANDS_TEXT, 2)
	# The observers' dressing: two chairs (one shoved back), an ashtray still smoking, a coffee
	# still steaming, a microphone. Nobody is here. Nobody has been gone long.
	_build_chair(Vector3(-6.95, 0, 18.72), 0.1)
	_build_chair(Vector3(-5.45, 0, 18.25), -0.55)
	_build_ashtray(dt + Vector3(-1.15, 0, -0.05))
	_build_cup(dt + Vector3(-0.1, 0, -0.18))
	_build_mic(dt + Vector3(-0.35, 0, 0.18))
	_build_desk_lamp(dt + Vector3(0.45, 0, 0.2))


func _build_desk() -> void:
	var wood := _mat(Color(0.22, 0.16, 0.11), 0.7)
	var steel := _mat(Color(0.18, 0.19, 0.19), 0.5, 0.6)
	var p := DESK_POS
	_mbox("DeskTop", Vector3(2.6, 0.04, 0.72), p + Vector3(0, DESK_TOP - 0.02, 0), wood)
	for lx in [-1.25, 1.25]:
		for lz in [-0.31, 0.31]:
			_mbox("DeskLeg", Vector3(0.045, DESK_TOP - 0.04, 0.045), p + Vector3(lx, (DESK_TOP - 0.04) / 2.0, lz), steel)
	_mbox("DeskModesty", Vector3(2.46, 0.36, 0.02), p + Vector3(0, 0.52, 0.3), steel)
	_solid("DeskBody", Vector3(2.6, DESK_TOP, 0.72), p + Vector3(0, DESK_TOP / 2.0, 0))


func _build_chair(at: Vector3, yaw: float) -> void:
	var seat_m := _mat(Color(0.16, 0.2, 0.18), 0.8)
	var steel := _mat(Color(0.2, 0.2, 0.2), 0.5, 0.6)
	var c := Node3D.new()
	c.name = "ObserverChair"
	c.position = at
	c.rotation.y = yaw
	add_child(c)
	_mbox("Seat", Vector3(0.44, 0.05, 0.42), Vector3(0, 0.46, 0), seat_m, c)
	_mbox("Back", Vector3(0.42, 0.34, 0.04), Vector3(0, 0.75, -0.22), seat_m, c, Vector3(-0.12, 0, 0))
	for lx in [-0.19, 0.19]:
		for lz in [-0.18, 0.18]:
			_mbox("ChairLeg", Vector3(0.025, 0.44, 0.025), Vector3(lx, 0.22, lz), steel, c)
		_mbox("BackPost", Vector3(0.025, 0.36, 0.025), Vector3(lx, 0.62, -0.2), steel, c)
	_solid("ChairBody", Vector3(0.46, 0.9, 0.46), at + Vector3(0, 0.45, 0), yaw)


# A thin rising wisp: a few soft, faint, billboarded strips whose alpha breathes (_tick_props).
# ⚠️ NOT emissive and faint (albedo alpha ≤ 0.16): the ask was a wisp, and a bright smoke column
# is a light source in a dim room.
func _build_wisp(base: Vector3, height: float, strips: int, tint: float) -> void:
	var img := Image.create_empty(16, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 16:
			var a := (1.0 - absf(x - 7.5) / 8.0) * sin(PI * float(y) / 63.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	for k in strips:
		var mi := MeshInstance3D.new()
		mi.name = "Wisp"
		var qm := QuadMesh.new()
		# Sized from the 16x64 soft-column texture (0.25), like every textured quad (check_art_aspect).
		var strip_h := height / float(strips) * 1.6
		qm.size = Vector2(strip_h * 0.25, strip_h)
		mi.mesh = qm
		mi.position = base + Vector3(0, height * (float(k) + 0.5) / float(strips), 0)
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = Color(tint, tint, tint, 0.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_smoke.append([mi, m, float(k) * 1.3, base])


func _build_ashtray(at: Vector3) -> void:
	_mcyl("Ashtray", 0.065, 0.025, at + Vector3(0, 0.0125, 0), _mat(Color(0.12, 0.13, 0.12), 0.2, 0.3), null,
		Vector3.ZERO, 0.075)
	_mcyl("Cigarette", 0.0045, 0.075, at + Vector3(0.04, 0.03, 0.0), _mat(Color(0.8, 0.78, 0.72), 0.9), null,
		Vector3(0, 0, PI / 2.0 - 0.15))
	var ember := _mat(Color(0.2, 0.05, 0.0), 0.8)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.35, 0.08)
	ember.emission_energy_multiplier = 0.45
	var e := MeshInstance3D.new()
	e.name = "Ember"
	var sm := SphereMesh.new()
	sm.radius = 0.005
	sm.height = 0.01
	e.mesh = sm
	e.position = at + Vector3(0.078, 0.035, 0.0)
	e.set_surface_override_material(0, ember)
	add_child(e)
	_build_wisp(at + Vector3(0.078, 0.04, 0.0), 0.5, 4, 0.62)


func _build_cup(at: Vector3) -> void:
	var cer := _mat(Color(0.7, 0.68, 0.62), 0.3)
	_mcyl("Cup", 0.038, 0.09, at + Vector3(0, 0.045, 0), cer, null, Vector3.ZERO, 0.042)
	_mcyl("Coffee", 0.036, 0.004, at + Vector3(0, 0.08, 0), _mat(Color(0.08, 0.04, 0.02), 0.15))
	var h := MeshInstance3D.new()
	h.name = "CupHandle"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.018
	tm.outer_radius = 0.026
	h.mesh = tm
	h.position = at + Vector3(0.045, 0.045, 0)
	h.rotation = Vector3(PI / 2.0, 0, 0)
	h.set_surface_override_material(0, cer)
	add_child(h)
	_build_wisp(at + Vector3(0, 0.09, 0), 0.22, 2, 0.75)


func _build_mic(at: Vector3) -> void:
	var m := _mat(Color(0.14, 0.14, 0.14), 0.4, 0.6)
	_mcyl("MicBase", 0.06, 0.02, at + Vector3(0, 0.01, 0), m)
	_mcyl("MicStem", 0.007, 0.26, at + Vector3(0, 0.15, 0), m)
	_mcyl("MicHead", 0.022, 0.07, at + Vector3(0, 0.29, -0.02), _mat(Color(0.3, 0.3, 0.3), 0.5, 0.7), null,
		Vector3(PI / 2.0 - 0.4, 0, 0))


func _build_desk_lamp(at: Vector3) -> void:
	var m := _mat(Color(0.12, 0.22, 0.14), 0.4, 0.4)
	_mcyl("LampBase", 0.07, 0.025, at + Vector3(0, 0.0125, 0), m)
	_mcyl("LampStem", 0.008, 0.3, at + Vector3(0, 0.16, 0), m)
	_mcyl("LampShade", 0.09, 0.1, at + Vector3(0, 0.33, -0.02), m, null, Vector3(0.25, 0, 0), 0.035)
	var sl := SpotLight3D.new()
	sl.name = "DeskLamp"
	sl.position = at + Vector3(0, 0.3, -0.03)
	sl.rotation = Vector3(-PI / 2.0 + 0.25, 0, 0)
	sl.light_color = Color(1.0, 0.82, 0.55)
	sl.light_energy = 1.2
	sl.spot_range = 1.8
	sl.spot_angle = 50.0
	sl.shadow_enabled = true
	add_child(sl)
	var bm := _mat(Color(0.15, 0.12, 0.08), 0.5)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.85, 0.6)
	bm.emission_energy_multiplier = BULB_EMISSION
	var bulb := MeshInstance3D.new()
	bulb.name = "DeskLampBulb"
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	bulb.mesh = sm
	bulb.position = Vector3(0, -0.02, 0)
	bulb.set_surface_override_material(0, bm)
	sl.add_child(bulb)
	_bulbs.append([sl, 1.2, bm, null])


# The reel-to-reel: E plays the SESSION 46 reel — sound only, and wordless (the voice is rationed).
func _build_reel() -> void:
	var at := DESK_POS + Vector3(0.82, DESK_TOP, -0.02)
	var prop := UseProp.new()
	prop.name = "ReelToReel"
	prop.prompt = "E — play the reel"
	prop.max_uses = 0
	prop.position = at
	add_child(prop)
	var body_m := _mat(Color(0.09, 0.09, 0.1), 0.5, 0.3)
	_mbox("DeckBody", Vector3(0.44, 0.13, 0.34), Vector3(0, 0.065, 0), body_m, prop)
	_mbox("DeckPlate", Vector3(0.42, 0.01, 0.32), Vector3(0, 0.135, 0), _mat(Color(0.42, 0.42, 0.4), 0.35, 0.8), prop)
	_art("DeckPanel", Vector2(0.36, 0.12), Vector3(0, 0.065, -0.174), Vector3(0, PI, 0), "reel_panel.png", 0.12, prop)
	var reel_m := _mat(Color(0.12, 0.12, 0.13), 0.4, 0.5)
	var tape_m := _mat(Color(0.2, 0.12, 0.07), 0.6)
	for sx in [-0.105, 0.105]:
		var reel := Node3D.new()
		reel.name = "Reel"
		reel.position = Vector3(sx, 0.15, 0.03)
		prop.add_child(reel)
		_mcyl("ReelFlange", 0.085, 0.008, Vector3.ZERO, reel_m, reel)
		_mcyl("TapePack", 0.06 if sx < 0 else 0.035, 0.012, Vector3(0, 0.002, 0), tape_m, reel)
		_mcyl("ReelHub", 0.014, 0.02, Vector3(0, 0.01, 0), _mat(Color(0.6, 0.6, 0.58), 0.3, 0.8), reel)
		for k in 3:
			_mbox("ReelSpoke", Vector3(0.07, 0.004, 0.01), Vector3(0, 0.009, 0), reel_m, reel, Vector3(0, k * PI / 3.0, 0))
		_reels.append(reel)
	_mbox("TapeRun", Vector3(0.2, 0.01, 0.003), Vector3(0, 0.15, -0.09), tape_m, prop)
	prop.add_box_shape(Vector3(0.46, 0.2, 0.36), Vector3(0, 0.09, 0))
	prop.used.connect(_on_reel_used)
	_reel_audio = AudioStreamPlayer3D.new()
	_reel_audio.name = "ReelAudio"
	_reel_audio.position = at + Vector3(0, 0.15, 0)
	_reel_audio.unit_size = 3.0
	_reel_audio.volume_db = 2.0
	add_child(_reel_audio)


func _on_reel_used(_times: int) -> void:
	if _reel_audio.playing:
		_reel_audio.stop()
		return
	var s := GameState.load_audio("intro_session46_tape")
	if s:
		_reel_audio.stream = s
		_reel_audio.play()


# The torch, ISSUED: an old steel instrument trolley against the hall's south wall.
# ⭐ REBUILT FROM PARTS (2026-09-24, the review: "a flat untextured blue-grey box"): four tubular
# legs on casters, two trays with raised lips, a push handle, worn steel — and a small clamp lamp
# over the top tray, so the one thing on it reads in a dark room. The lamp's bulb is a fitting at
# emission 0.4 (Issue 21 / check_fixtures); the light on the torch is a SpotLight, not a glow.
func _build_torch_tray() -> void:
	var at := Vector3(-6.0, 0, 14.0 + WALL_T / 2.0 + 0.26)
	var steel := _steel_mat()
	var dark := _mat(Color(0.08, 0.08, 0.08), 0.5, 0.4)
	var hw := 0.3
	var hd := 0.2
	for lx in [-hw, hw]:
		for lz in [-hd, hd]:
			_mcyl("TrolleyLeg", 0.012, 0.8, at + Vector3(lx, 0.47, lz), steel)
			_mcyl("TrolleyCaster", 0.035, 0.022, at + Vector3(lx, 0.035, lz), dark, null, Vector3(0, 0, PI / 2.0))
			_mbox("TrolleyFork", Vector3(0.03, 0.05, 0.018), at + Vector3(lx, 0.07, lz), steel)
	for ty in [0.86, 0.32]:
		_mbox("TrolleyTray", Vector3(hw * 2.0 + 0.04, 0.012, hd * 2.0 + 0.04), at + Vector3(0, ty, 0), steel)
		for sz in [-1.0, 1.0]:
			_mbox("TrayLip", Vector3(hw * 2.0 + 0.04, 0.035, 0.008), at + Vector3(0, ty + 0.02, sz * (hd + 0.016)), steel)
		for sx in [-1.0, 1.0]:
			_mbox("TrayLip", Vector3(0.008, 0.035, hd * 2.0 + 0.04), at + Vector3(sx * (hw + 0.016), ty + 0.02, 0), steel)
	# The push handle at the +x end.
	for lz in [-hd, hd]:
		_mcyl("HandlePost", 0.01, 0.18, at + Vector3(hw + 0.02, 0.96, lz), steel)
	_mcyl("HandleBar", 0.013, hd * 2.0 + 0.02, at + Vector3(hw + 0.02, 1.05, 0), steel, null, Vector3(PI / 2.0, 0, 0))
	# ⚠️ Stops BELOW the top tray: the torch lies in it, and a body reaching up past the tray's
	# floor answered every interact ray aimed at the torch (check_reachable, 2026-09-24).
	_solid("TrolleyBody", Vector3(0.66, 0.8, 0.46), at + Vector3(0, 0.4, 0))
	# The clamp lamp over the top tray.
	_mcyl("ClampPost", 0.008, 0.42, at + Vector3(-hw + 0.02, 1.07, -hd + 0.02), dark)
	_mcyl("ClampArm", 0.007, 0.26, at + Vector3(-hw + 0.13, 1.27, -hd + 0.02), dark, null, Vector3(0, 0, PI / 2.0))
	_mcyl("ClampShade", 0.05, 0.07, at + Vector3(-hw + 0.25, 1.24, -hd + 0.02), dark, null, Vector3.ZERO, 0.02)
	var lamp := SpotLight3D.new()
	lamp.name = "TrayLamp"
	lamp.position = at + Vector3(-hw + 0.25, 1.21, -hd + 0.02)
	lamp.rotation = Vector3(-PI / 2.0, 0, 0)
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 0.9
	lamp.spot_range = 1.3
	lamp.spot_angle = 38.0
	lamp.shadow_enabled = true
	add_child(lamp)
	var bm := _mat(Color(0.15, 0.12, 0.08), 0.5)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.85, 0.6)
	bm.emission_energy_multiplier = 0.4
	var bulb := MeshInstance3D.new()
	bulb.name = "TrayLampBulb"
	var sm := SphereMesh.new()
	sm.radius = 0.018
	sm.height = 0.036
	bulb.mesh = sm
	bulb.position = Vector3(0, 0.0, 0.0)
	bulb.set_surface_override_material(0, bm)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(bulb)
	_bulbs.append([lamp, 0.9, bm, null])
	# The label on a placard hung from the top tray's front lip, facing the room (+z).
	_mbox("LabelPlate", Vector3(0.27, 0.07, 0.02), at + Vector3(0, 0.815, hd + 0.05), _mat(Color(0.1, 0.1, 0.1), 0.6))
	_art("TrayLabel", Vector2(0.25, 0.05), at + Vector3(0, 0.815, hd + 0.064), Vector3.ZERO,
		"tray_label_issued.png", 0.35)
	var torch := KeyItem.new()
	torch.name = "IssuedTorch"
	# ⚠️ The key to the torch IS in the pickup line (the coordinator's call, 2026-09-24): the
	# shared KeyItem's toast is the only feedback — no second, red hint on top of it.
	torch.label_text = "Torch issued — F"
	torch.position = at + Vector3(0.05, 0.895, 0.02)
	torch.rotation.y = 0.2
	add_child(torch)
	var black := _mat(Color(0.08, 0.08, 0.08), 0.45, 0.5)
	_mcyl("TorchBody", 0.02, 0.19, Vector3(-0.03, 0, 0), black, torch, Vector3(0, 0, PI / 2.0))
	_mcyl("TorchHead", 0.03, 0.06, Vector3(0.09, 0, 0), black, torch, Vector3(0, 0, PI / 2.0), 0.022)
	_mcyl("TorchLens", 0.026, 0.004, Vector3(0.121, 0, 0), _mat(Color(0.7, 0.72, 0.7), 0.1, 0.3), torch,
		Vector3(0, 0, PI / 2.0))
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.3, 0.1, 0.12)
	col.shape = sh
	torch.add_child(col)
	torch.picked_up.connect(_on_torch_taken)


func _on_torch_taken() -> void:
	player.unlock_flashlight()
	_advance("torch")


# ---------------------------------------------------------------- the glimpse through the glass

# ⭐ Someone is strapped to the bed you just left. Spawned the first time the player is properly
# INSIDE the hall (0.6 m past the threshold — see the HallDoor's placement in DOORS for why that
# is unwitnessed) and gone the first time they step back out into the corridor. Never again.
# Zero panic, no sound, no sting: SCARY P6's register, like the ward's empty bed.
const HALL_IN_MARGIN := 0.6
const HALL_OUT_MARGIN := -0.1

func _in_hall(p: Vector3, margin: float) -> bool:
	return p.x > -10.2 + margin and p.x < -4.2 - margin and p.z > 14.0 + margin and p.z < 20.0 - margin


func _tick_hall() -> void:
	if _hall_state == 2 or not _beats.has("straps"):
		return
	var p := player.global_position
	if _hall_state == 0 and _in_hall(p, HALL_IN_MARGIN):
		_hall_state = 1
		_spawn_occupant()
	elif _hall_state == 1 and not _in_hall(p, HALL_OUT_MARGIN):
		_hall_state = 2
		# queue_free, never visible = false: a hidden node keeps its collider (see the ward's
		# empty bed, _on_switch_flipped()).
		if is_instance_valid(_occupant):
			_occupant.queue_free()
		_occupant = null


func _spawn_occupant() -> void:
	_occupant = _build_sheeted_form(CELL_GURNEY_POS, "CellOccupant")
	# Head to the NORTH, the way you lay: the form is authored head-to -z.
	_occupant.rotation.y += PI
	var leather := _mat(Color(0.13, 0.08, 0.05), 0.75)
	# Three straps across the sheet, in the form's own frame (head at -z there): chest, wrists
	# over the thighs, ankles. Each rides the sheet at its height and drops over both edges.
	for band in [[-0.28, 0.25], [0.3, 0.2], [0.78, 0.12]]:
		var z: float = band[0]
		var h: float = band[1]
		_mbox("OccupantStrap", Vector3(0.5, 0.012, 0.07), Vector3(0, h + 0.012, z), leather, _occupant)
		for side in [-1.0, 1.0]:
			_mbox("OccupantStrapDrop", Vector3(0.24, 0.012, 0.07), Vector3(side * 0.36, h * 0.45, z), leather,
				_occupant, Vector3(0, 0, side * -0.9))


# ---------------------------------------------------------------- the corridor

# The dream's corridor, awake: doors down both sides and one at the far end, none of them yours.
const CORRIDOR_FAKE_DOORS := [
	[Vector3(-1.8 - WALL_T / 2.0, 0, 11.5), -PI / 2.0],
	[Vector3(-1.8 - WALL_T / 2.0, 0, 16.0), -PI / 2.0],
	[Vector3(-1.8 - WALL_T / 2.0, 0, 20.5), -PI / 2.0],
	[Vector3(-4.2 + WALL_T / 2.0, 0, 11.5), PI / 2.0],
	[Vector3(-3.0, 0, 25.0 - WALL_T / 2.0), PI],
]

func _build_corridor() -> void:
	for i in CORRIDOR_FAKE_DOORS.size():
		var d := WingDoor.new()
		d.name = "CorridorDoor_%d" % i
		d.flush = true
		d.texture_path = TEX + "asylum_door.png"
		d.locked = true
		d.position = CORRIDOR_FAKE_DOORS[i][0]
		d.rotation.y = CORRIDOR_FAKE_DOORS[i][1]
		add_child(d)
	# A drip somewhere past the far door. Nothing else happens here.
	_loop_at("CorridorDrip", "water_drip", Vector3(-3.0, 0.4, 24.4), -12.0, 3.0)


# ---------------------------------------------------------------- per-frame

func _tick_props(delta: float) -> void:
	for s in _smoke:
		var mi: MeshInstance3D = s[0]
		var m: StandardMaterial3D = s[1]
		var ph: float = s[2]
		var base: Vector3 = s[3]
		m.albedo_color.a = 0.10 + 0.06 * sin(_flicker_time * 1.3 + ph)
		mi.position.x = base.x + 0.02 * sin(_flicker_time * 0.9 + ph * 2.0)
		mi.position.z = base.z + 0.015 * sin(_flicker_time * 0.7 + ph)
	if _reel_audio and _reel_audio.playing:
		for r in _reels:
			r.rotation.y -= delta * 3.2
	# The camera's red lamp blinks while the wing has power (it dies in the blackout).
	var powered := _switch_flipped or not _beats.has("blackout")
	if _monitor_lamp:
		var on := powered and fmod(_flicker_time, 2.0) < 1.2
		_monitor_lamp.emission_energy_multiplier = 0.5 if on else (0.08 if powered else 0.0)
		if _monitor_light:
			_monitor_light.light_energy = 0.12 if on else 0.0


const FILE_TEXT := "INTAKE — SUBJECT 47\n\nAdmitted 04:12. Sedated 04:40. Restraint: three-point.\nPrior sessions: none (?)\n\nReaction to dark: ________\nReaction to voice: ________\n\nConsent: on file.\n\n—\n\nStapled behind it, a second page.\n\nSUBJECT 46 — SESSION 46\nDuration: eleven days. Response: severe.\n\nFinal note: subject would not stop counting. Marks on the wall, cell 3. Subject asked for the lights to stay off.\n\nStamped across it in red: TERMINATED."
const LOG_TEXT := "OBSERVATION LOG — SUBJECT 47\n\n04:12  admitted\n04:40  sedated\n05:55  straps checked\n06:10  tray set out\n06:31  lights: cell only\n06:58  stirring\n\nAnd at the bottom, in pencil, underlined twice:\n\ndo NOT let it see the file."
const BANDS_TEXT := "Three hospital wristbands, snipped through, held together with a rubber band.\n\nSUBJ 44 · SUBJ 45 · SUBJ 46\n\nOn the back of 46, in biro: he counted the days on the wall."


# ================================================================ PHASES 4–5 (2026-09-24, second pass)
#
# The ward dressed to the wing's standard, the ward's finds, VO2 at the blackout, CALIBRATION (the
# only room in the level that moves the panic bar — pinned at the 0.6 ceiling), the AIRLOCK, and the
# back-door restore.

# ---------------------------------------------------------------- shared small builders

func _steel_mat() -> StandardMaterial3D:
	var m := _mat(Color(0.62, 0.63, 0.62), 0.42, 0.75)
	if ResourceLoader.exists(TEX + "worn_steel.png"):
		m.albedo_texture = load(TEX + "worn_steel.png")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(1.5, 1.5, 1.5)
	return m


# The gurney's frame, from parts: legs on casters, low side rails, an undercarriage shelf, and a
# tubular head rail on empty beds (see _build_gurney's ⭐ for why occupied beds get none).
func _gurney_parts(pos: Vector3, tag: String, head_rail: bool) -> void:
	var steel := _steel_mat()
	var dark := _mat(Color(0.07, 0.07, 0.07), 0.6, 0.3)
	for lx in [-0.4, 0.4]:
		for lz in [-0.92, 0.92]:
			_mcyl("GurneyLeg_" + tag, 0.018, 0.36, pos + Vector3(lx, 0.24, lz), steel)
			_mcyl("GurneyCaster_" + tag, 0.045, 0.028, pos + Vector3(lx, 0.045, lz), dark, null, Vector3(0, 0, PI / 2.0))
			_mbox("GurneyFork_" + tag, Vector3(0.04, 0.06, 0.02), pos + Vector3(lx, 0.085, lz), steel)
	for sx in [-1.0, 1.0]:
		_mcyl("GurneyRail_" + tag, 0.014, 1.96, pos + Vector3(sx * 0.462, 0.43, 0), steel, null, Vector3(PI / 2.0, 0, 0))
	_mbox("GurneyShelf_" + tag, Vector3(0.78, 0.015, 1.7), pos + Vector3(0, 0.16, 0), steel)
	if head_rail:
		for sx in [-0.4, 0.4]:
			_mcyl("GurneyHeadPost_" + tag, 0.014, 0.42, pos + Vector3(sx, 0.69, 1.0), steel)
		_mcyl("GurneyHeadBar_" + tag, 0.016, 0.84, pos + Vector3(0, 0.9, 1.0), steel, null, Vector3(0, 0, PI / 2.0))
		_mcyl("GurneyHeadBar_" + tag, 0.012, 0.8, pos + Vector3(0, 0.76, 1.0), steel, null, Vector3(0, 0, PI / 2.0))


# ---------------------------------------------------------------- THE WARD, dressed

# The three ceiling tubes get the fitting the Lab's lamps wear (level_1.gd:_add_fixture) — a dark
# housing and a dark-albedo diffuser whose EMISSION follows its light (_tick_ward_fittings), so a
# dead tube is a dead fitting and the glimpse's 0.4 s stutter shows in the fitting too.
# ⚠️ Emission ≤ 0.55 (FIXTURE_EMISSION in the Lab; Issue 21).
const WARD_FIXTURE_EMISSION := 0.5
var _ward_fixtures: Array = []                # [OmniLight3D, StandardMaterial3D]

func _add_ward_fixture(light: OmniLight3D) -> void:
	var housing := MeshInstance3D.new()
	housing.name = "TubeHousing"
	var hm := BoxMesh.new()
	hm.size = Vector3(0.24, 0.08, 1.3)
	housing.mesh = hm
	housing.position = Vector3(0, 0.25, 0)
	housing.set_surface_override_material(0, _mat(Color(0.11, 0.115, 0.11), 0.7, 0.3))
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(housing)
	var dmat := _mat(Color(0.1, 0.1, 0.095), 0.6)
	dmat.emission_enabled = true
	dmat.emission = Color(0.85, 0.9, 1.0)
	dmat.emission_energy_multiplier = 0.0
	var diffuser := MeshInstance3D.new()
	diffuser.name = "TubeDiffuser"
	var dm := BoxMesh.new()
	dm.size = Vector3(0.16, 0.04, 1.2)
	diffuser.mesh = dm
	diffuser.position = Vector3(0, 0.2, 0)
	diffuser.set_surface_override_material(0, dmat)
	diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(diffuser)
	_ward_fixtures.append([light, dmat])


func _tick_ward_fittings() -> void:
	for f in _ward_fixtures:
		var e: float = (f[0] as OmniLight3D).light_energy
		(f[1] as StandardMaterial3D).emission_energy_multiplier = WARD_FIXTURE_EMISSION * clampf(e / 0.9, 0.0, 1.0)


# The ward was "a bare dark box" in the review. Asylum furniture along its empty walls, all
# zero-panic, none of it in the path glow's line (ward entry -> switch) or the wheelchair's.
func _build_ward_dressing() -> void:
	_build_stripped_bed(Vector3(-5.0, 0, -5.4))
	_build_chair_stack(Vector3(-5.05, 0, 7.95))
	_build_privacy_screen(Vector3(3.3, 0, 8.25))
	# A floor drain, near the beds (a disc, 6 mm proud — never coplanar with the floor).
	_mcyl("FloorDrain", 0.13, 0.008, Vector3(1.8, 0.002, 3.6), _mat(Color(0.05, 0.05, 0.05), 0.4, 0.6))
	for k in 5:
		_mbox("DrainSlot", Vector3(0.2, 0.004, 0.012), Vector3(1.8, 0.008, 3.6 - 0.08 + k * 0.04),
			_mat(Color(0.25, 0.23, 0.2), 0.4, 0.7))
	# The stopped clock, high on the west wall — 4:12, the time on your file.
	var cz := 2.0
	var cx := WALL_LEFT_FACE_X
	_mcyl("ClockRim", 0.2, 0.05, Vector3(cx + 0.025, 2.55, cz), _mat(Color(0.12, 0.1, 0.08), 0.5, 0.4), null,
		Vector3(0, 0, PI / 2.0))
	_art("ClockFace", Vector2(0.36, 0.36), Vector3(cx + 0.055, 2.55, cz), Vector3(0, PI / 2.0, 0),
		"clock_stopped.png", 0.0)


func _build_stripped_bed(at: Vector3) -> void:
	# An iron bedstead with no mattress: head and foot boards of bars, side rails, a sagging wire
	# lattice. Rust-dark iron. Solid (one collider for the whole frame).
	var iron := _mat(Color(0.2, 0.15, 0.11), 0.7, 0.55)
	for ez in [-1.0, 1.0]:
		var z: float = at.z + ez * 0.98
		var top: float = 1.0 if ez > 0.0 else 0.8
		for sx in [-0.44, 0.44]:
			_mcyl("BedPost", 0.02, top, Vector3(at.x + sx, top * 0.5, z), iron)
		_mcyl("BedBoardTop", 0.016, 0.9, Vector3(at.x, top - 0.04, z), iron, null, Vector3(0, 0, PI / 2.0))
		_mcyl("BedBoardMid", 0.012, 0.9, Vector3(at.x, 0.42, z), iron, null, Vector3(0, 0, PI / 2.0))
		for k in 5:
			_mcyl("BedBoardBar", 0.008, top - 0.46, Vector3(at.x - 0.3 + k * 0.15, 0.42 + (top - 0.46) * 0.5, z), iron)
	for sx in [-0.44, 0.44]:
		_mcyl("BedSideRail", 0.015, 1.94, Vector3(at.x + sx, 0.42, at.z), iron, null, Vector3(PI / 2.0, 0, 0))
	for k in 9:
		_mcyl("BedWire", 0.004, 1.9, Vector3(at.x - 0.36 + k * 0.09, 0.38, at.z), iron, null, Vector3(PI / 2.0, 0, 0))
	for k in 11:
		_mcyl("BedWire", 0.004, 0.86, Vector3(at.x, 0.38, at.z - 0.85 + k * 0.17), iron, null, Vector3(0, 0, PI / 2.0))
	_solid("StrippedBedBody", Vector3(0.94, 0.9, 2.0), at + Vector3(0, 0.45, 0))


func _build_chair_stack(at: Vector3) -> void:
	# Three steel-framed chairs stacked in the corner, each a little askew.
	for k in 3:
		var c := Node3D.new()
		c.name = "StackedChair"
		c.position = at + Vector3(0.02 * k, 0.1 * k, -0.03 * k)
		c.rotation.y = 0.35 + 0.08 * k
		add_child(c)
		var seat_m := _mat(Color(0.2, 0.22, 0.19), 0.8)
		var steel := _mat(Color(0.25, 0.25, 0.24), 0.5, 0.6)
		_mbox("Seat", Vector3(0.42, 0.04, 0.4), Vector3(0, 0.46, 0), seat_m, c)
		_mbox("Back", Vector3(0.4, 0.3, 0.035), Vector3(0, 0.76, -0.2), seat_m, c, Vector3(-0.1, 0, 0))
		for lx in [-0.18, 0.18]:
			for lz in [-0.17, 0.17]:
				_mcyl("ChairLeg", 0.011, 0.44, Vector3(lx, 0.22, lz), steel, c)
			_mcyl("BackPost", 0.011, 0.34, Vector3(lx, 0.63, -0.19), steel, c)
	_solid("ChairStackBody", Vector3(0.6, 1.2, 0.6), at + Vector3(0, 0.6, 0))


func _build_privacy_screen(at: Vector3) -> void:
	# A three-leaf folding screen: tubular frames with stained cloth, zig-zagged.
	var steel := _mat(Color(0.35, 0.36, 0.35), 0.45, 0.7)
	var leaf_w := 0.55
	var leaf_h := 1.55
	var yaws := [0.5, -0.5, 0.5]
	var x := at.x
	var z := at.z
	for k in 3:
		var leaf := Node3D.new()
		leaf.name = "ScreenLeaf"
		leaf.position = Vector3(x, 0, z)
		leaf.rotation.y = yaws[k]
		add_child(leaf)
		for sx in [-leaf_w * 0.5, leaf_w * 0.5]:
			_mcyl("ScreenPost", 0.012, leaf_h + 0.2, Vector3(sx, (leaf_h + 0.2) * 0.5, 0), steel, leaf)
		for y in [0.2, leaf_h + 0.15]:
			_mcyl("ScreenBar", 0.01, leaf_w, Vector3(0, y, 0), steel, leaf, Vector3(0, 0, PI / 2.0))
		var cloth := MeshInstance3D.new()
		cloth.name = "ScreenCloth"
		var qm := QuadMesh.new()
		qm.size = Vector2(leaf_w - 0.04, leaf_h - 0.1)   # ⚠️ 0.51 x 1.45 ≈ the cloth art's 0.367
		cloth.mesh = qm
		cloth.position = Vector3(0, 0.2 + (leaf_h - 0.05) * 0.5, 0)
		var cm := _mat(Color(0.8, 0.8, 0.76), 0.95)
		if ResourceLoader.exists(TEX + "privacy_screen_cloth.png"):
			cm.albedo_texture = load(TEX + "privacy_screen_cloth.png")
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloth.material_override = cm
		leaf.add_child(cloth)
		# The next leaf starts where this one ends.
		x += cos(yaws[k]) * leaf_w
		z -= sin(yaws[k]) * leaf_w
	_solid("PrivacyScreenBody", Vector3(1.6, 1.7, 0.5), Vector3((at.x + x) * 0.5, 0.85, (at.z + z) * 0.5))


# The ward's FINDS (phase 4): a bank of three filing cabinets against the back wall, one page each.
# Journal-archived like every safe note (lab_cabinet_drawer.gd archives with current_level).
const WARD_FINDS := [
	["CONSENT FORM — SERIES C\n\nI, the undersigned, consent to observation under conditions of darkness, isolation and controlled distress, and to the use of restraint where the observers judge it necessary.\n\nI understand I may withdraw at any time by informing the observers.\n\nSigned: ______________\n\nThe signature line is empty. Someone has written 47 in the margin, and crossed out 46 above it.", 1],
	["A paper pill envelope, torn open. Two white tablets left inside.\n\nSUBJ 47 — CHLORPROMAZINE 100 mg — AT INTAKE\nSUBJ 47 — ——— — IF DISTRESSED\n\nThe second drug's name has been scratched off the label.", 3],
	["Night staff journal, a loose page:\n\n\"46 is asking again who is behind the glass. Told him nobody. Told him the lights stay on for his own good. He said he can hear someone breathing in the ward when the power goes.\n\nThe power has not gone. Not once.\"", 0],
]

func _build_ward_finds() -> void:
	for k in WARD_FINDS.size():
		var cab := LabCabinet.new()
		cab.name = "WardCabinet%d" % k
		cab.position = Vector3(-4.7 + k * 0.76, 0, WALL_BACK_FACE_Z + LabCabinet.SIZE.z / 2.0 + 0.01)
		add_child(cab)
		cab.assign_note(String(WARD_FINDS[k][0]), int(WARD_FINDS[k][1]))


# ---------------------------------------------------------------- the voice's other speakers

var _ward_speaker: AudioStreamPlayer3D = null
var _calib_speaker: AudioStreamPlayer3D = null
var _airlock_speaker: AudioStreamPlayer3D = null

func _make_speaker(n: String, pos: Vector3, face_yaw: float) -> AudioStreamPlayer3D:
	var kit := _mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	var box := Node3D.new()
	box.name = n + "Box"
	box.position = pos
	box.rotation.y = face_yaw
	add_child(box)
	_mbox("TannoyBox", Vector3(0.32, 0.22, 0.14), Vector3(0, 0, -0.01), kit, box)
	_mbox("TannoyGrille", Vector3(0.26, 0.16, 0.01), Vector3(0, 0, 0.065), _mat(Color(0.05, 0.05, 0.05), 0.9), box)
	var sp := AudioStreamPlayer3D.new()
	sp.name = n
	sp.position = pos
	sp.unit_size = 14.0
	sp.volume_db = VO_DB
	add_child(sp)
	return sp


func _build_speakers() -> void:
	# ⚠️ On walls with no doorway at the spot, the faces derived from the room table.
	# 10 cm off the face: the box is 14 cm deep about -1 cm, so its back hangs 2 cm clear.
	_ward_speaker = _make_speaker("WardSpeaker", Vector3(-4.6, 2.9, ROOM_SIZE.y / 2.0 - WALL_T / 2.0 - 0.1), PI)
	_calib_speaker = _make_speaker("CalibrationSpeaker", Vector3(4.0 - WALL_T / 2.0 - 0.1, 2.8, -13.0), -PI / 2.0)
	_airlock_speaker = _make_speaker("AirlockSpeaker", Vector3(-6.3, 2.45, -17.0 - WALL_T / 2.0 - 0.1), PI)


# ---------------------------------------------------------------- CALIBRATION

# ⭐ The one room in the intro that teaches the panic bar. Panic moves here and ONLY here (the
# cell, hall and ward stay at exactly 0) and the level's ceiling pins it at 0.6, so nothing in this
# room can kill. Two lessons, each a thing the rest of the game punishes:
#   1. GAZE   — the projector's slides are a ScaryObject; SITTING in the subject's chair and watching
#               them fills the bar. At LOOK_AWAY_AT the monitor says LOOK AWAY., and the lesson
#               completes after AWAY_TIME of not looking (the level's own camera-dot test).
#   2. TOUCH  — a red-tagged tray, DO NOT TOUCH, live throughout; E spikes the bar to the ceiling.
# (A third, WALK TO THE LINE — the sprint cost — was cut on the second hand playtest, 2026-09-25.)
const SCREEN_POS := Vector3(0, 1.75, -21.0 + WALL_T / 2.0 + 0.04)
const SCREEN_SIZE := Vector2(2.4, 1.8)                 # 4:3, the slides' own aspect
const MARK_POS := Vector3(0, 0, -18.6)                  # the CHAIR's spot: the seated eye is 2.4 m from the screen
const TRAY_STAND_POS := Vector3(2.7, 0, -17.3)
const SLIDES := ["slide_0_title.png", "slide_1.png", "slide_2.png", "slide_3.png", "slide_4.png"]
# Gaze intensity per slide (× player.PANIC_BASE_RATE 20/s): 0.8, 1.4, 2.0, 2.8, 3.6 panic/s —
# the ladder up. Measured: ~11 s of watching from the title reaches LOOK_AWAY_AT on slide 3.
const SLIDE_INTENSITY := [0.04, 0.07, 0.1, 0.14, 0.18]
const SLIDE_TIME := 4.0
const LOOK_AWAY_AT := 0.35
const AWAY_TIME := 1.5
const AWAY_DOT := 0.5                                   # looking > 60° off the screen is "away"
const WATCH_DOT := 0.85
# ⭐ Two clocks (first hand playtest): CALIB_TIMEOUT counts only SEATED time, so it can no longer
# wave through a player who never sat down to watch; a player who will not sit at all is let
# through after UNSEATED_TIMEOUT. Both end in "NOTED." — the lesson untaught, never a dead end.
const CALIB_TIMEOUT := 60.0
const UNSEATED_TIMEOUT := 90.0
const SEATED_EYE := 1.2                                 # seated eye height over the floor
const SEAT_TIME := 0.9
const SCREEN_EMISSION := 0.45

var _calib_state: int = 0      # 0 not entered · 1 watching · 2 look away · 3 answered (GOOD./NOTED.) · 5 done
var _seated: bool = false
var _unseated_t: float = 0.0
var _chair_prop: UseProp = null
var _chair_body: StaticBody3D = null
var _calib_t: float = 0.0
var _slide_i: int = 0
var _slide_t: float = 0.0
var _away_t: float = 0.0
var _screen_scary: ScaryObject = null
var _screen_mat: StandardMaterial3D = null
var _projector_light: SpotLight3D = null
var _projector_audio: AudioStreamPlayer3D = null
var _lens_mat: StandardMaterial3D = null
var _airlock_state: int = 0
var _captions: Array[String] = []                      # every observer caption, in order (tests)

# ⚠️ Captions QUEUE. ScreenText.caption() prints every line in the same slot, and the first tour
# printed "STAND ON THE MARK." straight over the still-fading VO3 caption. Each line waits until the
# previous one has faded (0.5 in + hold + 1.0 out), so two observer lines never share the screen.
var _caption_free_at: float = 0.0

# `stale_when` (optional): checked when a QUEUED line's turn comes — if it returns true the line is
# dropped. "SIT DOWN." queues behind VO3's caption, and a player who sat during VO3 saw the order
# arrive after obeying it (2026-09-25).
func _caption(text: String, seconds: float = 3.0, color: Color = Color(0.86, 0.84, 0.72),
		stale_when: Callable = Callable()) -> void:
	_captions.append(text)
	var now := Time.get_ticks_msec() / 1000.0
	var wait := maxf(0.0, _caption_free_at - now)
	_caption_free_at = now + wait + 0.5 + seconds + 1.0
	if wait <= 0.01:
		ScreenText.caption(get_tree(), text, seconds, color)
	else:
		get_tree().create_timer(wait).timeout.connect(func() -> void:
			if stale_when.is_valid() and bool(stale_when.call()):
				return
			ScreenText.caption(get_tree(), text, seconds, color))


func _build_calibration() -> void:
	# The screen: a pull-down projection screen on the south wall — roller case, weighted bar —
	# and the ScaryObject ancestor pattern (level_1.gd:1183): ScaryObject (a plain Node) -> a
	# StaticBody3D carrying its OWN world transform -> the collider the gaze ray hits + the slide.
	_mcyl("ScreenRoller", 0.05, 2.6, SCREEN_POS + Vector3(0, SCREEN_SIZE.y * 0.5 + 0.08, 0.02),
		_mat(Color(0.1, 0.1, 0.1), 0.5, 0.4), null, Vector3(0, 0, PI / 2.0))
	_mbox("ScreenWeight", Vector3(2.46, 0.03, 0.03), SCREEN_POS + Vector3(0, -SCREEN_SIZE.y * 0.5 - 0.02, 0.02),
		_mat(Color(0.1, 0.1, 0.1), 0.5, 0.4))
	_screen_scary = ScaryObject.new()
	_screen_scary.name = "ProjectorScary"
	_screen_scary.scare_intensity = 0.0
	add_child(_screen_scary)
	var body := StaticBody3D.new()
	body.name = "ProjectorScreen"
	body.position = SCREEN_POS
	_screen_scary.add_child(body)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(SCREEN_SIZE.x, SCREEN_SIZE.y, 0.03)
	col.shape = sh
	body.add_child(col)
	var q := MeshInstance3D.new()
	q.name = "ScreenSlide"
	var qm := QuadMesh.new()
	qm.size = SCREEN_SIZE
	q.mesh = qm
	_screen_mat = _mat(Color(0.5, 0.5, 0.48), 0.9)
	_screen_mat.emission_enabled = true
	_screen_mat.emission_energy_multiplier = 0.0
	q.material_override = _screen_mat
	body.add_child(q)
	_set_slide(-1)
	# The projector on its cart, behind where you stand.
	var cart := Vector3(0.9, 0, -13.9)
	var steel := _steel_mat()
	for lx in [-0.25, 0.25]:
		for lz in [-0.2, 0.2]:
			_mcyl("ProjCartLeg", 0.012, 0.8, cart + Vector3(lx, 0.4, lz), steel)
	_mbox("ProjCartTop", Vector3(0.58, 0.02, 0.46), cart + Vector3(0, 0.8, 0), steel)
	_mbox("ProjCartShelf", Vector3(0.54, 0.015, 0.42), cart + Vector3(0, 0.25, 0), steel)
	var dark := _mat(Color(0.14, 0.13, 0.12), 0.45, 0.5)
	_mbox("ProjectorBody", Vector3(0.3, 0.15, 0.34), cart + Vector3(0, 0.885, 0), dark)
	_mcyl("ProjectorCarousel", 0.14, 0.05, cart + Vector3(0, 0.99, 0.02), _mat(Color(0.3, 0.28, 0.24), 0.5, 0.2))
	_mcyl("ProjectorLens", 0.042, 0.14, cart + Vector3(0, 0.89, -0.23), dark, null, Vector3(PI / 2.0, 0, 0))
	_lens_mat = _mat(Color(0.12, 0.12, 0.12), 0.1)
	_lens_mat.emission_enabled = true
	_lens_mat.emission = Color(1.0, 0.95, 0.85)
	_lens_mat.emission_energy_multiplier = 0.0
	var lens := MeshInstance3D.new()
	lens.name = "ProjectorLensGlass"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.034
	cm.bottom_radius = 0.034
	cm.height = 0.006
	lens.mesh = cm
	lens.rotation.x = PI / 2.0
	lens.position = cart + Vector3(0, 0.89, -0.302)
	lens.set_surface_override_material(0, _lens_mat)
	add_child(lens)
	_solid("ProjectorCartBody", Vector3(0.6, 1.05, 0.5), cart + Vector3(0, 0.52, 0))
	_projector_light = SpotLight3D.new()
	_projector_light.name = "ProjectorBeam"
	add_child(_projector_light)
	_projector_light.look_at_from_position(cart + Vector3(0, 0.89, -0.31), SCREEN_POS, Vector3.UP)
	_projector_light.light_color = Color(1.0, 0.96, 0.86)
	_projector_light.light_energy = 0.0
	_projector_light.spot_range = 9.0
	_projector_light.spot_angle = 16.0
	_projector_light.shadow_enabled = true
	_projector_audio = AudioStreamPlayer3D.new()
	_projector_audio.name = "ProjectorAudio"
	_projector_audio.position = cart + Vector3(0, 0.9, 0)
	_projector_audio.unit_size = 3.0
	_projector_audio.volume_db = -4.0
	add_child(_projector_audio)
	# ⭐ No floor mark any more (first hand playtest, 2026-09-24): the subject's chair stands where
	# the mark was, and SIT DOWN. replaces STAND HERE — see _sit_in_chair().
	# ⚠️ NO LINE (second hand playtest, 2026-09-25, capture #4: *"What for to cross that line? I think
	# looking away while sitting in the chair and then standing up is sufficient"*). The walk to a
	# painted line — and its sprint caption, HEART RATE 131 — is gone: GOOD. stands you up and the
	# observer answers straight away. The intro no longer teaches the sprint cost; the Lab's first
	# note still says DO NOT RUN.
	_build_forbidden_tray()
	_build_subject_chair()
	_build_eeg_cart()


# ⭐ Calibration dressing (polish, 2026-09-24 — "the room is bare"): the subject's chair, EMPTY,
# facing the screen beside the mark — wooden, with leather wrist straps on its arms (the cell's
# straps, again) — and an electrode cart beside it with its leads trailing to the chair. Zero panic,
# no light of their own (the projector and the room's one bulb light them), clear of the mark, the
# walk to the line and the route to the airlock door.
# ⭐ ON THE MARK since the first hand playtest (capture #3) — the chair IS where you watch from.
const SUBJECT_CHAIR_POS := MARK_POS
const EEG_CART_POS := Vector3(-1.25, 0, -19.45)

func _build_subject_chair() -> void:
	var wood := _mat(Color(0.26, 0.17, 0.1), 0.65)
	var leather := _mat(Color(0.19, 0.12, 0.07), 0.62)
	var steel := _mat(Color(0.62, 0.62, 0.6), 0.3, 0.85)
	var c := Node3D.new()
	c.name = "SubjectChairFrame"   # ⚠️ not "SubjectChair" — that is the E volume's name (Issue 17)
	c.position = SUBJECT_CHAIR_POS
	c.rotation.y = 0.0                       # square to the screen (it faces -z)
	add_child(c)
	for lx in [-0.23, 0.23]:
		for lz in [-0.22, 0.22]:
			_mbox("ChairLeg", Vector3(0.05, 0.46, 0.05), Vector3(lx, 0.23, lz), wood, c)
		_mbox("ArmPost", Vector3(0.045, 0.24, 0.045), Vector3(lx, 0.58, -0.2), wood, c)
		_mbox("ArmRest", Vector3(0.07, 0.035, 0.5), Vector3(lx, 0.715, -0.01), wood, c)
		# A wrist strap across each arm, buckle up.
		_mbox("WristStrap", Vector3(0.09, 0.012, 0.055), Vector3(lx, 0.739, -0.1), leather, c)
		_mbox("WristBuckle", Vector3(0.03, 0.008, 0.04), Vector3(lx + signf(lx) * 0.03, 0.748, -0.1), steel, c)
		_mbox("BackPost", Vector3(0.05, 0.62, 0.05), Vector3(lx, 0.77, 0.22), wood, c, Vector3(0.1, 0, 0))
	_mbox("ChairSeat", Vector3(0.52, 0.05, 0.5), Vector3(0, 0.485, 0), wood, c)
	for k in 3:
		_mbox("BackSlat", Vector3(0.44, 0.07, 0.025), Vector3(0, 0.68 + k * 0.17, 0.24 + k * 0.017), wood, c,
			Vector3(0.1, 0, 0))
	_mbox("ChestStrap", Vector3(0.46, 0.05, 0.012), Vector3(0, 0.86, 0.215), leather, c, Vector3(0.1, 0, 0))
	for lx in [-0.23, 0.23]:
		_mbox("AnkleStrap", Vector3(0.07, 0.04, 0.07), Vector3(lx, 0.12, -0.22), leather, c)
	# ⚠️ The solid body stops at the SEAT: above it is the chair's E volume (layer 2, the UseProp),
	# which a solid body reaching up to the backrest would swallow. The body is switched OFF while
	# you sit in it, or move_and_slide would push a seated capsule out of the chair.
	# ⚠️ NO SHADOWS (the second hand-play review, 2026-09-25). The projector stands BEHIND the chair,
	# so the backrest threw its shadow across the lower half of the screen — and the player has no
	# body, so a seated player saw an EMPTY chair's silhouette standing in front of the slides
	# (measured: hiding the frame removed it; the camera itself sits 0.18 m in front of the backrest).
	for part in c.get_children():
		if part is GeometryInstance3D:
			(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_body = _solid("SubjectChairBody", Vector3(0.6, 0.46, 0.58), SUBJECT_CHAIR_POS + Vector3(0, 0.23, 0))
	_chair_prop = UseProp.new()
	_chair_prop.name = "SubjectChair"
	_chair_prop.prompt = "E — sit"
	_chair_prop.enabled = false
	_chair_prop.position = SUBJECT_CHAIR_POS + Vector3(0, 0.8, 0)
	add_child(_chair_prop)
	_chair_prop.add_box_shape(Vector3(0.6, 0.62, 0.58))
	_chair_prop.used.connect(_sit_in_chair)


func _build_eeg_cart() -> void:
	var steel := _steel_mat()
	var dark := _mat(Color(0.12, 0.12, 0.11), 0.5, 0.4)
	var cream := _mat(Color(0.62, 0.6, 0.52), 0.6)
	var at := EEG_CART_POS
	for lx in [-0.22, 0.22]:
		for lz in [-0.17, 0.17]:
			_mcyl("EegCartLeg", 0.012, 0.7, at + Vector3(lx, 0.36, lz), steel)
			_mcyl("EegCaster", 0.03, 0.02, at + Vector3(lx, 0.03, lz), dark, null, Vector3(0, 0, PI / 2.0))
	_mbox("EegCartTop", Vector3(0.5, 0.02, 0.4), at + Vector3(0, 0.72, 0), steel)
	_mbox("EegCartShelf", Vector3(0.46, 0.015, 0.36), at + Vector3(0, 0.22, 0), steel)
	# The machine: a cream-enamel case with a paper-chart roll, dials and a row of lead sockets.
	var box := Node3D.new()
	box.name = "EegMachine"
	box.position = at + Vector3(0, 0.73, 0)
	box.rotation.y = -0.5                     # turned toward the chair
	add_child(box)
	_mbox("EegCase", Vector3(0.44, 0.2, 0.3), Vector3(0, 0.1, 0), cream, box)
	_mbox("EegPanel", Vector3(0.4, 0.14, 0.01), Vector3(0, 0.1, 0.152), dark, box)
	for k in 4:
		_mcyl("EegDial", 0.018, 0.012, Vector3(-0.14 + k * 0.07, 0.13, 0.16), _mat(Color(0.7, 0.68, 0.6), 0.4, 0.5), box,
			Vector3(PI / 2.0, 0, 0))
	_mcyl("EegChartRoll", 0.03, 0.36, Vector3(0, 0.23, -0.05), _mat(Color(0.86, 0.84, 0.78), 0.9), box,
		Vector3(0, 0, PI / 2.0))
	_mbox("EegChartPaper", Vector3(0.34, 0.003, 0.14), Vector3(0, 0.205, 0.06), _mat(Color(0.86, 0.84, 0.78), 0.9), box,
		Vector3(-0.35, 0, 0))
	# Loose leads: sagging from the sockets to the floor between the cart and the chair, then
	# coiling up the chair's leg — thin dark cables, each a few straight runs (no colliders).
	var lead := _mat(Color(0.05, 0.05, 0.05), 0.6)
	var sock := box.global_transform * Vector3(0, 0.06, 0.16)
	var chair_foot := SUBJECT_CHAIR_POS + Vector3(-0.2, 0.03, 0.1)
	for k in 3:
		var a: Vector3 = sock + Vector3(-0.05 + k * 0.05, 0, 0)
		var floor_pt := a.lerp(chair_foot, 0.45) + Vector3(0.05 * k, 0, 0)
		floor_pt.y = 0.012
		var up_pt := chair_foot + Vector3(0.03 * k, 0.45 + 0.08 * k, 0)
		for seg in [[a, floor_pt], [floor_pt, chair_foot + Vector3(0.03 * k, 0.012, 0)],
				[chair_foot + Vector3(0.03 * k, 0.012, 0), up_pt]]:
			var p0: Vector3 = seg[0]
			var p1: Vector3 = seg[1]
			var mid := (p0 + p1) * 0.5
			var length := p0.distance_to(p1)
			if length < 0.02:
				continue
			var mi := _mcyl("EegLead", 0.004, length, mid, lead)
			mi.look_at_from_position(mid, p1, Vector3.UP if absf((p1 - p0).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT)
			mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_solid("EegCartBody", Vector3(0.52, 0.95, 0.42), at + Vector3(0, 0.47, 0))


func _build_forbidden_tray() -> void:
	var at := TRAY_STAND_POS
	var steel := _steel_mat()
	for lx in [-0.22, 0.22]:
		for lz in [-0.15, 0.15]:
			_mcyl("TrayStandLeg", 0.011, 0.86, at + Vector3(lx, 0.43, lz), steel)
	_mbox("TrayStandTop", Vector3(0.5, 0.012, 0.36), at + Vector3(0, 0.866, 0), steel)
	for sz in [-1.0, 1.0]:
		_mbox("TrayLip", Vector3(0.5, 0.03, 0.008), at + Vector3(0, 0.885, sz * 0.176), steel)
	for sx in [-1.0, 1.0]:
		_mbox("TrayLip", Vector3(0.008, 0.03, 0.36), at + Vector3(sx * 0.246, 0.885, 0), steel)
	_solid("TrayStandBody", Vector3(0.5, 0.84, 0.36), at + Vector3(0, 0.42, 0))
	# ⭐ WHAT IS NOT TO BE TOUCHED (polish, 2026-09-24 — "DO NOT TOUCH" needs an object): a loaded
	# syringe beside a small dark vial, and a scalpel on a folded cloth. Real silhouettes, lit by
	# their own clamp lamp. ⚠️ NOTHING on the tray is emissive — SCARY.md §8.8 forbids a self-lit
	# scary prop; the lamp's bulb is the only emitter, and it is on the lamp.
	var top := 0.872
	var glass := _mat(Color(0.75, 0.8, 0.78, 0.45), 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var liquid := _mat(Color(0.28, 0.05, 0.04), 0.2)
	var s_at := at + Vector3(-0.06, top + 0.014, 0.03)
	var s_rot := Vector3(0, 0.35, PI / 2.0)
	var syringe := Node3D.new()
	syringe.name = "Syringe"
	syringe.position = s_at
	syringe.rotation = s_rot
	add_child(syringe)
	_mcyl("SyringeBarrel", 0.012, 0.11, Vector3.ZERO, glass, syringe)
	_mcyl("SyringeDose", 0.009, 0.05, Vector3(0, -0.025, 0), liquid, syringe)
	_mcyl("SyringePlunger", 0.004, 0.07, Vector3(0, 0.085, 0), steel, syringe)
	_mcyl("SyringeThumb", 0.014, 0.004, Vector3(0, 0.12, 0), steel, syringe)
	_mcyl("SyringeFlange", 0.02, 0.004, Vector3(0, 0.055, 0), glass, syringe)
	_mcyl("SyringeNeedle", 0.0012, 0.06, Vector3(0, -0.085, 0), steel, syringe)
	_mcyl("VialGlass", 0.014, 0.05, at + Vector3(-0.17, top + 0.025, -0.06), glass)
	_mcyl("VialLiquid", 0.011, 0.03, at + Vector3(-0.17, top + 0.016, -0.06), liquid)
	_mcyl("VialCap", 0.0145, 0.012, at + Vector3(-0.17, top + 0.056, -0.06), _mat(Color(0.5, 0.48, 0.4), 0.3, 0.8))
	_mbox("TrayCloth", Vector3(0.2, 0.006, 0.12), at + Vector3(0.04, top + 0.003, 0.1), _mat(Color(0.82, 0.8, 0.74), 0.95), null,
		Vector3(0, 0.12, 0))
	_mbox("Scalpel", Vector3(0.15, 0.004, 0.012), at + Vector3(0.04, top + 0.009, 0.1), steel, null, Vector3(0, -0.3, 0))
	_mbox("ScalpelBlade", Vector3(0.04, 0.003, 0.016), at + Vector3(0.105, top + 0.009, 0.08), _mat(Color(0.8, 0.8, 0.82), 0.15, 0.95),
		null, Vector3(0, -0.3, 0))
	# The tag: a card propped on the tray, turned to the room and tilted back so it reads from
	# the middle of the room (0.32 m wide: ~19 px capitals at 2 m on a 1080p frame).
	var to_room := Vector2(0.0 - at.x, -15.0 - at.z).normalized()
	var card := Node3D.new()
	card.name = "TrayTagCard"
	# At the tray's FAR corner from the room, so the syringe, vial and scalpel are in front of it.
	card.position = at + Vector3(0.14, top + 0.078, -0.1)
	card.rotation = Vector3(-0.35, atan2(to_room.x, to_room.y), 0)
	add_child(card)
	_mbox("TagBacking", Vector3(0.33, 0.165, 0.004), Vector3(0, 0, -0.004), _mat(Color(0.3, 0.05, 0.04), 0.8), card)
	_art("TrayTag", Vector2(0.32, 0.16), Vector3(0, 0, 0.001), Vector3.ZERO, "tag_do_not_touch.png", 0.0, card)
	# The clamp lamp, on the back of the stand: a gooseneck, a shade, and a small clinical pool.
	var dark := _mat(Color(0.08, 0.08, 0.08), 0.5, 0.4)
	_mcyl("TrayLampPost", 0.009, 0.62, at + Vector3(0.22, 1.18, -0.15), dark)
	_mcyl("TrayLampNeck", 0.007, 0.3, at + Vector3(0.12, 1.5, -0.1), dark, null, Vector3(0.3, 0, PI / 2.0 - 0.5))
	_mcyl("TrayLampShade", 0.055, 0.07, at + Vector3(0.0, 1.46, -0.04), dark, null, Vector3.ZERO, 0.02)
	var tl := SpotLight3D.new()
	tl.name = "ForbiddenTrayLamp"
	add_child(tl)
	tl.look_at_from_position(at + Vector3(0.0, 1.43, -0.04), at + Vector3(0, top, 0.02), Vector3.UP)
	tl.light_color = Color(0.95, 0.97, 1.0)
	tl.light_energy = 1.7
	tl.spot_range = 1.6
	tl.spot_angle = 30.0
	tl.shadow_enabled = true
	var tbm := _mat(Color(0.12, 0.12, 0.12), 0.5)
	tbm.emission_enabled = true
	tbm.emission = Color(0.95, 0.97, 1.0)
	tbm.emission_energy_multiplier = 0.35
	var tb := MeshInstance3D.new()
	tb.name = "TrayLampBulb"
	var tsm := SphereMesh.new()
	tsm.radius = 0.016
	tsm.height = 0.032
	tb.mesh = tsm
	tb.set_surface_override_material(0, tbm)
	tb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tl.add_child(tb)
	var tray := UseProp.new()
	tray.name = "ForbiddenTray"
	tray.position = at + Vector3(0, 0.9, 0)
	add_child(tray)
	tray.add_box_shape(Vector3(0.5, 0.1, 0.36))
	tray.used.connect(_on_tray_touched)


func _set_slide(i: int) -> void:
	_slide_i = i
	if i < 0:
		# Off: a dead grey screen, no light, no gaze source.
		_screen_mat.albedo_texture = null
		_screen_mat.emission_texture = null
		_screen_mat.albedo_color = Color(0.36, 0.36, 0.34)
		_screen_mat.emission_energy_multiplier = 0.0
		if _screen_scary:
			_screen_scary.scare_intensity = 0.0
		return
	var path: String = TEX + String(SLIDES[i])
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_screen_mat.albedo_texture = tex
		_screen_mat.emission_texture = tex
	_screen_mat.albedo_color = Color(1, 1, 1)
	_screen_mat.emission_energy_multiplier = SCREEN_EMISSION
	_screen_scary.scare_intensity = float(SLIDE_INTENSITY[i]) if _seated else 0.0
	_sfx_at("intro_projector_slide", _projector_audio.position, -4.0, 3.0)


func _projector_on(on: bool) -> void:
	_projector_light.light_energy = 1.6 if on else 0.0
	_lens_mat.emission_energy_multiplier = 0.4 if on else 0.0
	if on:
		var s := GameState.load_audio("intro_projector_run")
		if s:
			_projector_audio.stream = s
			if not _projector_audio.finished.is_connected(_projector_audio.play):
				_projector_audio.finished.connect(_projector_audio.play)
			_projector_audio.play()
		_set_slide(0)
		_slide_t = 0.0
	else:
		if _projector_audio.finished.is_connected(_projector_audio.play):
			_projector_audio.finished.disconnect(_projector_audio.play)
		_projector_audio.stop()
		_set_slide(-1)


func _in_calibration(p: Vector3) -> bool:
	return p.x > -4.0 and p.x < 4.0 and p.z > -21.0 and p.z < -9.4


func _in_airlock(p: Vector3) -> bool:
	return p.x > -7.0 and p.x < -4.25 and p.z > -20.0 and p.z < -17.0


# How squarely the camera faces the screen (1 = dead centre) and how far it is from it.
func _screen_dot() -> float:
	var cam: Camera3D = player.camera
	var to: Vector3 = SCREEN_POS - cam.global_position
	return (-cam.global_basis.z).normalized().dot(to.normalized())


func _screen_dist() -> float:
	var cam: Camera3D = player.camera
	return cam.global_position.distance_to(SCREEN_POS)


func _tick_calibration(delta: float) -> void:
	if GameState.is_ending or _calib_state == 5:
		_tick_airlock()
		return
	var p := player.global_position
	match _calib_state:
		0:
			if _beats.has("blackout") and _in_calibration(p):
				_calib_state = 1
				_calib_t = 0.0
				_advance("calibration")
				_say("screen", _on_screen_line_done, _calib_speaker)
		1:
			# The slides run — and the screen is a gaze source — only while you are seated.
			_screen_gate()
			if not _seated:
				_unseated_t += delta
				if _unseated_t > UNSEATED_TIMEOUT:
					_finish_gaze("NOTED.")
				return
			_calib_t += delta
			_tick_slides(delta)
			var watching := _screen_dot() >= WATCH_DOT and _screen_dist() <= 3.3
			if player.get_panic_ratio() >= LOOK_AWAY_AT and watching:
				_calib_state = 2
				_away_t = 0.0
				_caption("LOOK AWAY.", 3.0)
			elif _calib_t > CALIB_TIMEOUT:
				_finish_gaze("NOTED.")
		2:
			_tick_slides(delta)
			if _screen_dot() < AWAY_DOT:
				_away_t += delta
				if _away_t >= AWAY_TIME:
					_finish_gaze("GOOD.")
			else:
				_away_t = 0.0


func _tick_slides(delta: float) -> void:
	if _slide_i < 0:
		return
	_slide_t += delta
	if _slide_t >= SLIDE_TIME:
		_slide_t = 0.0
		# Title once, then round the four stimuli.
		_set_slide(1 + (_slide_i % (SLIDES.size() - 1)))


func _on_screen_line_done() -> void:
	if _calib_state != 1:
		return
	_projector_on(true)
	_chair_prop.enabled = true
	_caption("SIT DOWN.", 3.5, Color(0.86, 0.84, 0.72), func() -> bool: return _seated)


# The screen is a gaze source only while you sit: standing, the projector runs its title card and
# nothing on it can move the bar.
func _screen_gate() -> void:
	if _slide_i < 0 or _screen_scary == null:
		return
	_screen_scary.scare_intensity = float(SLIDE_INTENSITY[_slide_i]) if _seated else 0.0


# ⭐ THE CHAIR (first hand playtest, 2026-09-24, capture #3: *"It was said do not look away until
# instructed - but when I will be instructed? They are repeated in circles."*). Measured on the
# player's own spot: 3.44 m from the screen, outside GAZE_RANGE 3.0 — the gaze ray never reached it,
# panic never moved, and the 60 s fallback let them through untaught. Seated, the eye is ~2.4 m away.
# The body is pinned with player.begin_qte() — the MOVEMENT-ONLY pin (look stays free, so the lesson
# "look away" is still yours to perform); it also refuses E and sprint, which is right in a chair.
func _sit_in_chair(_times: int) -> void:
	if _seated or _calib_state != 1:
		return
	_seated = true
	_chair_prop.enabled = false
	for c in _chair_body.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	player.begin_qte()
	player.velocity = Vector3.ZERO
	_sfx_at("intro_chair_sit", SUBJECT_CHAIR_POS + Vector3(0, 0.5, 0), 0.0, 3.0)
	var from := player.global_position
	var to := SUBJECT_CHAIR_POS + Vector3(0, 0.02, 0.06)
	var t := create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_player_pos, from, to, SEAT_TIME)
	t.tween_property(player.camera, "position:y", SEATED_EYE - 0.02, SEAT_TIME)
	var cam: Camera3D = player.camera
	# turn_to_face measures pitch from the CURRENT eye; aim for the screen as seen from the seat.
	var aim := SCREEN_POS + (from - to) + Vector3(0, cam.position.y - (SEATED_EYE - 0.02), 0)
	player.turn_to_face(aim, SEAT_TIME)


func _stand_from_chair() -> void:
	if not _seated:
		return
	_seated = false
	var from := player.global_position
	# To the WEST of the chair: the projector cart stands north-east, in the line of the walk.
	var to := SUBJECT_CHAIR_POS + Vector3(-0.85, 0.05, 0.3)
	var t := create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_player_pos, from, to, SEAT_TIME)
	t.tween_property(player.camera, "position:y", 1.65, SEAT_TIME)
	t.finished.connect(_on_stood_from_chair)


func _on_stood_from_chair() -> void:
	player.end_qte()
	for c in _chair_body.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = false


func _finish_gaze(caption: String) -> void:
	_calib_state = 3
	_stand_from_chair()
	_projector_on(false)
	_advance("gaze")
	_caption(caption, 2.0)
	get_tree().create_timer(2.4).timeout.connect(_on_gaze_noted)


func _on_gaze_noted() -> void:
	_say("better", _on_calibrated, _calib_speaker)


func _on_calibrated() -> void:
	_calib_state = 5
	_advance("calibrated")
	var d: WingDoor = _doors.get("AirlockDoor")
	if d:
		_sfx_at("intro_cell_buzz", d.global_position + Vector3(0, 2.2, 0), 0.0, 5.0)


func _on_tray_touched(_times: int) -> void:
	# ⚠️ The only add_panic in the intro, and it cannot kill: the level's ceiling pins it at 0.6.
	player.add_panic(player.PANIC_MAX)
	_advance("tray")
	_caption("WE SAID NOT TO TOUCH IT. NOTED.", 3.5)


func _tick_airlock() -> void:
	if _airlock_state != 0 or not _beats.has("calibrated") or _beats.has("proceed"):
		return
	if _in_airlock(player.global_position):
		_airlock_state = 1
		_sfx_at("intro_airlock_buzzer", Vector3(-5.5, 2.4, -18.5), 0.0, 5.0)
		get_tree().create_timer(2.3).timeout.connect(func(): _say("proceed", _on_proceed, _airlock_speaker))


func _on_proceed() -> void:
	_advance("proceed")


# ---------------------------------------------------------------- the back door (the Lab -> here)

# ⭐ spec/levels/README.md's contract. GameState captures this on the way OUT; coming back through
# the Lab's back door (entered_from_ahead) the wing is built SOLVED and you stand in the airlock.
func save_progress() -> Dictionary:
	return {"beats": _beats.keys(), "note_read": GameState.intro_note_read}


func _restore_progress() -> void:
	if not GameState.entered_from_ahead:
		return
	var data := GameState.get_level_progress(0)
	for b in ["straps", "torch", "blackout", "calibration", "gaze", "calibrated", "proceed"]:
		_beats[b] = true
	for b in data.get("beats", []):
		_beats[String(b)] = true
	GameState.intro_note_read = true
	# The cell: nobody on the bed, the door open (the straps were built open).
	_hall_state = 2
	for d in _doors.values():
		(d as WingDoor).move_aside_instantly()
	# The ward: lit, the glimpse bed empty, the candle burning, the wheelchair already turned.
	_switch_flipped = true
	var sw := get_node_or_null("LightSwitch")
	if sw:
		sw.set("_used", true)
		sw.set("_presses", SWITCH_PRESSES)
	if is_instance_valid(_glimpse_form):
		_glimpse_form.queue_free()
	_glimpse_form = null
	for light in _ceiling_lights:
		if not is_equal_approx((light as OmniLight3D).position.z, TABLE_POS.z):
			(light as OmniLight3D).light_energy = 0.9
	candle_light.visible = true
	candle_light.light_energy = BASE_ENERGY
	if _candle_flame:
		_candle_flame.visible = true
	_candle_lit = true
	_wheelchair_armed = false
	_wheelchair_turned = true
	var wc := get_node_or_null("Wheelchair") as Node3D
	if wc:
		wc.rotation.y += deg_to_rad(WHEELCHAIR_TURN_DEG)
	if _env:
		_env.ambient_light_energy = NORMAL_AMBIENT
		_env.ambient_light_color = LIT_AMBIENT_COLOR
	_calib_state = 5
	_airlock_state = 1
	player.unlock_flashlight()
	player.unfreeze_input()
	# In the airlock, facing back into the wing (east, toward calibration).
	player.global_position = Vector3(-5.2, 0.05, -18.2)
	player.rotation.y = -PI / 2.0
	player.camera.position.y = 1.65
	player.camera.rotation.x = 0.0
	player.set("_pitch", 0.0)
	_refresh_doors()


# ---------------------------------------------------------------- twist ending (unchanged)

# The twist ending: same room, visibly wrong. The candle is dead, the room
# throbs blood-red, the exit is boarded over, and the new note is the only
# brightly lit thing left.
#
# ⚠️ FIXED 2026-07-27 (INTRO.md §7's deferred follow-up). Every position below used to
# be a literal computed against the OLD 5.6 m room: the planks sat at z = -2.45 while
# the door is at z = -8.5, so the game's FINAL BEAT rendered three boards floating in
# open space in the middle of the ward. They are now derived from EXIT_DOOR_POS and
# DOOR_SIZE, so they follow the door if the room is ever rescaled again. The spotlight
# at (0, 2.8, 0) was always correct — TABLE_POS is (0, 0.4, 0) — and is left alone.
func _corrupt_room() -> void:
	candle_light.light_energy = 0.0
	candle_light.visible = false
	# The candle is DEAD in the ending, which now means the stub stays and the flame goes.
	# (The ending branch of _ready() never calls _darken_scene(), so this is the only place
	# that hides it here.)
	if _candle_flame:
		_candle_flame.visible = false

	_red_light = OmniLight3D.new()
	_red_light.light_color = Color(0.8, 0.06, 0.04)
	_red_light.light_energy = 0.5
	# Range was 7.0 for a 5.6 m room. In an 18 m ward that left the far half unlit,
	# so the throb — the whole visual of the corrupted room — only reached the table.
	_red_light.omni_range = 11.0
	_red_light.shadow_enabled = true
	_red_light.position = Vector3(0, 2.4, ROOM_SIZE.y * -0.25)
	add_child(_red_light)

	# The door you came through is gone — planks where it used to be.
	var exit_door := get_node_or_null("ExitDoor")
	if exit_door:
		exit_door.queue_free()
	var plank_mat := StandardMaterial3D.new()
	plank_mat.albedo_color = Color(0.10, 0.07, 0.04)
	plank_mat.roughness = 0.95
	# Boarded flush across the doorway, standing proud of where the door panel was so
	# the planks never z-fight the back wall (the coincident-surface family, Issue 20).
	#
	# ⚠️ 2026-08-16: this DERIVATION was already correct — it was fixed on 2026-07-27
	# precisely so the boards would follow the door. What was wrong was the door: at the
	# old EXIT_DOOR_POS.z the planks landed 0.485 m in front of the wall face, so the game's
	# final beat was three boards hovering in open air with blank concrete behind them.
	# Seating the door fixed this for free, and the planks now sit inside the casing's
	# recess, which is what boards nailed across a doorway are supposed to look like.
	var plank_z := EXIT_DOOR_POS.z + DOOR_SIZE.z / 2.0 + 0.06
	for plank in [
		[Vector3(0, EXIT_DOOR_POS.y + 0.55, plank_z), 0.35],
		[Vector3(0, EXIT_DOOR_POS.y - 0.05, plank_z), -0.3],
		[Vector3(0, EXIT_DOOR_POS.y - 0.65, plank_z), 0.15],
	]:
		var mesh_inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.7, 0.22, 0.06)
		mesh_inst.mesh = mesh
		mesh_inst.set_surface_override_material(0, plank_mat)
		mesh_inst.position = plank[0]
		mesh_inst.rotation.z = plank[1]
		add_child(mesh_inst)

	# Harsh cold spotlight pinning the note to the table.
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.95, 0.93, 0.85)
	spot.light_energy = 4.0
	spot.spot_range = 4.0
	spot.spot_angle = 18.0
	spot.shadow_enabled = true
	spot.position = Vector3(0, 2.8, 0)
	spot.rotation_degrees.x = -90.0
	add_child(spot)

	# Low whisper loop under everything.
	var stream := GameState.load_audio("whispers")
	if stream:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -14.0
		add_child(p)
		p.finished.connect(p.play)
		p.play()


func _show_controls_hint() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)

	var lbl := Label.new()
	lbl.text = "WASD — move    ·    E — interact    ·    F — flashlight    ·    Shift — run"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.position.y -= 60.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58, 0.9))
	lbl.add_theme_font_size_override("font_size", 18)
	canvas.add_child(lbl)

	var tween := create_tween()
	tween.tween_interval(8.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tween.tween_callback(canvas.queue_free)


# Room is ROOM_SIZE wide/deep, ceiling at ROOM_HEIGHT -> webs nestle into the top
# corners (each spanning the two walls + ceiling) with per-web variation in size,
# tilt, roll and position so they read as grown, not stamped. Seeded for
# reproducibility.
func _spawn_cobwebs() -> void:
	var cobweb_tex: Texture2D = load(TEX + "cobweb_intro.png") \
		if ResourceLoader.exists(TEX + "cobweb_intro.png") else null
	if not cobweb_tex:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 870261 if not GameState.is_ending else 870262

	# ⚠️ From the wall FACES (2026-09-24): with 0.3 walls "- 0.1" sat 5 cm INSIDE the plaster and
	# only the inward pull below got the webs out; with RoomBuilder's 0.2 it would be on the face.
	var corner_x := ROOM_SIZE.x / 2.0 - WALL_T / 2.0 - 0.05
	var corner_z := ROOM_SIZE.y / 2.0 - WALL_T / 2.0 - 0.05
	var y_anchor := ROOM_HEIGHT - 0.05

	# Top corners as (x sign, z sign). The opening room only webs the two back
	# corners; the corrupted ending fills all four, denser.
	var corners := [Vector2(-1, -1), Vector2(1, -1)]
	if GameState.is_ending:
		corners.append(Vector2(-1, 1))
		corners.append(Vector2(1, 1))

	for c in corners:
		var count := rng.randi_range(1, 2) if not GameState.is_ending else rng.randi_range(2, 3)
		for i in range(count):
			_make_cobweb(cobweb_tex, c.x, c.y, rng, corner_x, corner_z, y_anchor)
		# In the ending, a few extra webs sag lower down the corner walls.
		if GameState.is_ending and rng.randf() < 0.7:
			_make_cobweb(cobweb_tex, c.x, c.y, rng, corner_x, corner_z, rng.randf_range(1.2, 1.9))


func _make_cobweb(tex: Texture2D, sx: float, sz: float, rng: RandomNumberGenerator,
		corner_x: float, corner_z: float, y_anchor: float) -> void:
	var corner := Vector3(sx * corner_x, y_anchor, sz * corner_z)
	var inward := Vector3(-sx, 0, -sz).normalized()
	# Pull inward off the exact corner and drop a little, with jitter.
	var pos: Vector3 = corner + inward * rng.randf_range(0.08, 0.55) \
		+ Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.55, -0.05), rng.randf_range(-0.12, 0.12))
	# Normal faces into the room and downward so the web droops toward the player.
	var normal := (inward + Vector3(0, -rng.randf_range(0.5, 0.9), 0)).normalized()

	var mesh_inst := MeshInstance3D.new()
	# ⚠️ UNIQUE per web (Issue 17, the third instance of it in this file). Every web was
	# called "CobwebIntro", so Godot renamed all but the first to @MeshInstance3D@NN and
	# they were unaddressable — which is how two of them slipped past a name filter in
	# tests/check_art_aspect.gd.
	_cobweb_index += 1
	mesh_inst.name = "CobwebIntro_%d" % _cobweb_index
	var quad := QuadMesh.new()
	var s := rng.randf_range(0.7, 1.3)
	quad.size = Vector2(s, s * rng.randf_range(0.85, 1.15))
	mesh_inst.mesh = quad

	var basis := _basis_from_normal(normal)
	basis = basis.rotated(normal, rng.randf_range(0.0, TAU))  # random roll
	mesh_inst.transform = Transform3D(basis, pos)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, rng.randf_range(0.5, 0.85))  # vary how thick each web reads
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.set_surface_override_material(0, mat)
	add_child(mesh_inst)


# Orthonormal basis whose local +Z (a QuadMesh's face normal) equals `normal`.
func _basis_from_normal(normal: Vector3) -> Basis:
	normal = normal.normalized()
	var up := Vector3.UP
	if absf(normal.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x := up.cross(normal).normalized()
	var y := normal.cross(x).normalized()
	return Basis(x, y, normal)


func _process(delta: float) -> void:
	_flicker_time += delta
	if _red_light:
		# Slow arrhythmic throb, like something breathing through the walls.
		_red_light.light_energy = 0.5 \
			+ maxf(0.0, sin(_flicker_time * 1.7)) * 0.35 \
			+ sin(_flicker_time * 0.6) * 0.1
		return
	_tick_wheelchair()
	_tick_hall()
	_tick_props(delta)
	_tick_ward_fittings()
	_tick_calibration(delta)
	if not candle_light or not _candle_lit:
		return
	candle_light.light_energy = BASE_ENERGY \
		+ sin(_flicker_time * 7.3) * 0.18 \
		+ sin(_flicker_time * 13.7) * 0.09 \
		+ sin(_flicker_time * 3.1) * 0.06


func _on_ending_note_closed() -> void:
	# One beat of the corrupted room before the reveal takes the screen. The red throb and the
	# planked door are all the player has actually seen of it — the note overlay covered
	# everything else — so cutting straight to video would spend a room nobody looked at.
	await get_tree().create_timer(1.0).timeout
	# ⚠️ Not cosmetic. The mouse is captured and the cutscene is opaque, so without this the
	# player walks blind around the ward for the length of the clip, with footsteps playing.
	player.freeze_input()
	var cutscene := CutscenePlayer.play(self, ENDING_VIDEO)
	if cutscene != null:
		await cutscene.finished
	else:
		# Headless, or no file: the original 2 s pause, to the frame.
		await get_tree().create_timer(1.0).timeout
	# The twist ending is the ONLY death that uses this image — never the random
	# intro/ending fallback pool.
	Screamer.trigger_to_menu("res://assets/textures/screamers/shared_screamer.png")
