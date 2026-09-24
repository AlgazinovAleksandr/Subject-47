extends Node3D

# Level 2 — The House (expanded). Built procedurally with RoomBuilder: entry hall,
# central hallway, living room + kitchen, an upper landing onto the bedroom,
# bathroom and child's room, plus a gently-descending CELLAR reached by a ramp and
# sealed by a gate until you find the cellar key in the kitchen. Win: read the
# three safe notes (one digit each — the third is in the cellar), enter the code
# on the lock by the exit. Scares: window/forest, living-room TV, a one-way mirror
# in the bathroom, a music box in the child's room, cursed props, scripted events,
# pipe groans, random blackouts, and a "hold your nerve" apparition in the dark.
#
# ⭐⭐ 2026-09-24 — THE PORCH (the user's design, Granny-referenced; spec/levels/02-house.md).
# The living-room window is a real opening in the west wall now; the forest scare BURSTS it and
# behind it are a porch with a GUILLOTINE and a moonlit forest that kills you if you stay out
# (`_tick_forest_clock`, a user-approved level-local panic term). Digit 2's chain: the witch's
# note -> the window -> the first porch visit (arms the painting) -> the painting falls -> the
# WATERMELON in the hole behind it -> the guillotine -> the BOLT CUTTERS -> the fridge chain.
# Geometry lives in house_outdoors.gd / house_window.gd; the props in house_guillotine.gd and
# house_watermelon.gd; every BEAT is here.

const TEX := "res://assets/textures/level_2_house/"
const PRESERVE := ["Environment", "AmbientPlayer", "CreakPlayer", "HUDCanvas", "Player"]

const _DOOR_SCRIPT := preload("res://scripts/door.gd")
const _NOTE_SCRIPT := preload("res://scripts/note.gd")
const _LOCK_SCRIPT := preload("res://scripts/combination_lock.gd")

# Whether this level arms random apparitions. Pacing and the teach/fatal decision live
# in ApparitionDirector — see level_1.gd's note on why the old DEBUG_* pair went away.
const RANDOM_APPARITIONS := true

const CREAK_MIN := 15.0
const CREAK_MAX := 40.0
const PIPE_MIN := 14.0
const PIPE_MAX := 30.0
# ⭐ THE HOUSE IS PITCH BLACK UNTIL EVERY NOTE IS FOUND (2026-09-03, the user's call).
#
# ⚠️ AND THEN ONLY ONE LAMP COMES ON. Not the house — the wall lamp beside the combination lock
# at the far end of the ChildRoom, with a sting. That is the whole payoff: a single warm point
# at the end of a black house that you then have to walk to. `_restore_power()`'s
# everything-at-once relief is the Lab's beat and would spend this one.
#
# ⚠️ Lamps are NOT deleted — `check_fixtures.gd` asserts a minimum fitting count per level
# (House >= 6) and every fitting is created by `_add_lamp()`. `_drive_lights()` holds them at
# zero instead, exactly as the Lab does.
# ⭐ 0.0, NOT 0.02 (2026-09-07). See the identical block in `level_1.gd`: ambient decides whether
# the unlit house is black or nearly black, and the BEAM below decides how far you can see.
const DARK_AMBIENT := 0.0

# ⭐ THE HOUSE'S OWN TORCH — `player.gd`'s defaults are 18 m / 30 deg and a child's `_ready()`
# runs before its parent's, so this narrows the beam afterwards. Lab and House only.
const TORCH_RANGE := 11.0
const TORCH_ANGLE := 24.0

# ⭐ EVERYTHING THAT LIGHTS ITSELF IS HALVED (D3 — cross-level X64/X65, the user's call
# 2026-09-07). Measured in the dark House before the change, brightest first: the living-room
# forest window 0.90, the TV static panel 0.70, notes 0.60, the cellar key's card 0.50 and the
# one-way mirror figures 0.50, the beartrap 0.12, the exit and back doors 0.08.
# ⚠️ `_SCALE` values are MULTIPLIERS into a shared script; the rest are ABSOLUTE energies on a
# level-local quad. Mixing the two up is how one of these silently becomes a no-op.
const EM_NOTE_SCALE := 0.42     # note.gd's 0.60 -> 0.25 (and its trap 0.50 -> 0.21)
const EM_DOOR_SCALE := 0.375    # door.gd's 0.08 -> 0.03
const EM_MIRROR_SCALE := 0.5    # living_mirror.gd's 0.50 -> 0.25
# (EM_FOREST, the old painted-forest window's 0.40, is gone with that window — 2026-09-24.)
const EM_TV := 0.30             # was 0.70
const EM_KEYCARD := 0.30        # was 0.50, and 0.80 on the untextured fallback
const LAMP_ON_FADE := 2.2
const SAFE_NOTES_TOTAL := 3

const BLACKOUT_MIN := 24.0
const BLACKOUT_MAX := 44.0

const FOREST_SCARE_PATH := TEX + "screamer_forest.png"
const FOREST_SCARE_DIST := 1.5
const FOREST_SCARE_PANIC := 25.0
const FOREST_SCARE_HOLD := 0.8      # Screamer.flash_scare()'s hold — the image is up this long

# --- THE GUEST (2026-07-28) -----------------------------------------------------------
# The House is the only level in the game with genuine backtracking pressure: the Bathroom
# map -> the key -> the Kitchen -> the cellar -> back to the ChildRoom lock crosses the
# ground floor repeatedly, and every route passes through the Landing, which was EMPTY.
#
# So nothing is ever seen. The house is simply not arranged the way you left it, one step
# per quest milestone, with no sound, no event and no acknowledgement — SCARY.md P6, whose
# whole mechanic is the asymmetry that **if the player never notices, nothing happens**.
#
# ⚠️ ZERO PANIC, all four stages. The fridge below is the only new panic in this level.
const GUEST_HALLWAY_SPOT := Vector3(0.0, 0.11, 7.4)     # Hallway, between you and the exit
# The child stands at the Landing end of the Hallway — framed by a 3 m corridor, on the
# route back from the cellar, so it is seen head-on rather than found in a corner.
const GUEST_CHILD_SPOT := Vector3(0.0, 0.0, 10.0)
const CHILD_VOLUME_DB := 18.0        # "the scream should be much louder" (2026-07-29)
# The cellar sequence, timed exactly as specified on the 2026-07-29 playtest.
const CHILD_APPEAR_DELAY := 5.5      # dark first, then the child
# H5 (2026-09-16, the user): a red WHERE AM I? while you are pinned in the dark — up at
# CELLAR_WHERE_AT, held CELLAR_WHERE_HOLD, and GONE (0.6 in + hold + 1.4 out = 4.7 s) before the
# doll at CHILD_APPEAR_DELAY. It must never share the screen with the figure.
const CELLAR_WHERE_TEXT := "WHERE AM I?"
const CELLAR_WHERE_AT := 0.7
const CELLAR_WHERE_HOLD := 2.0
const CHILD_HOLD := 3.0              # …and the lights come back this long after
const CHILD_DIST := 3.2              # the FAR end of the ladder now (was the first try)
# ⭐ 2026-09-10 — near-first (the user: *"the doll should appear very close to you"*). At 1.7 m a
# 1.95 m figure is ~75 % of the screen's height; the camera is turned onto it whichever
# candidate wins, so a placement BEHIND the player is now on the ladder too.
const CHILD_NEAR := [1.7, 2.0, 2.4]  # ahead, tried in this order; then a fan at CHILD_NEAR[1]
const CHILD_FAN_DEG := 25.0
const CHILD_TURN_TIME := 0.45        # NOOK_TURN_TIME, the Lab's proven number
const CHILD_DIP := 0.4               # Ambience silence under the scream
const CHILD_SCREAM_LEAD := 0.3       # H3: the dip lands first; the scream 0.3 s into it
# ⚠️ 1.25 -> 1.95 m ("the child should be way bigger"). Taller than a real child on purpose:
# this is a jumpscare at three metres in a pitch-black cellar, not a figure seen across a
# room, and at child height it read as small and far away rather than as on top of you.
const CHILD_HEIGHT := 1.95

# The falling painting comes off the wall in front of you, loudly. It hangs on the ChildRoom's
# NORTH wall, beside the exit door, so approaching the combination lock is what drops it.
const PAINTING_TRIGGER_DIST := 4.5
const PAINTING_TRIGGER_DOT := 0.45
const PAINTING_FALL_TIME := 0.45
const PAINTING_FALL_DB := 8.0
# Offset along the north wall from its centre. The exit door occupies x -1.33..-0.08, so this
# puts the panel on the other side of it with ~0.5 m of wall between the two.
const PAINTING_X := 0.85

# The fridge — the single new panic term in the atmosphere pass. Voluntary, optional,
# off the quest path, one-shot. See house_fridge.gd's header.
const FRIDGE_PANIC := 10.0

# The footsteps overhead, after the scripted one-shot. Zero panic, on a long gap.
const OVERHEAD_MIN := 40.0
const OVERHEAD_MAX := 70.0

# The four objective lines, in one place so the fresh-level path and _restore_progress()
# cannot drift apart (they have, twice).
const OBJ_FIND_KEY := "The cellar is locked. Find the key."
const OBJ_COLLECT_KEY := "Collect the cellar key"
const OBJ_UNLOCK_CELLAR := "Unlock the cellar door under the kitchen stairs"
const OBJ_CODE := "Read the 3 notes for the code, then enter it at the exit lock"
const OBJ_LOCK_LIT := "Something switched on at the far end of the house"

# The cellar's cross-level hint for THE NIGHTMARE (level 7), on the wall AND on screen.
const CELLAR_HINT := "TIMING IS EVERYTHING\nIN THE NIGHTMARE."
const CELLAR_CAPTION_TIME := 4.0

# ================================================================ THE PORCH (2026-09-24)
# The user's design, grilled 2026-09-24 (backlogs/02-house-porch.md §2 — final). The spec entry at
# the top of spec/levels/02-house.md is the contract.

# Openings RoomBuilder cuts that are NOT doorways, so they stay out of `DOORS` (which
# `check_doorways.gd` rays straight through and would find the window's pane in). Both are full-
# height cuts; `_build_wall_fillers()` closes them back down to a window and a hole.
const WINDOW_AT := Vector3(-8.5, 0.0, 6.0)   # the opening's centre on the LivingRoom west wall
const WINDOW_W := 1.4
const WINDOW_H := 2.3                        # to the lintel's underside
const NICHE_W := 0.62                        # the hole behind the falling painting…
const NICHE_Y := Vector2(1.19, 1.81)         # …0.62 x 0.62, inside the 0.8 x 1.0 panel
# ⚠️ 0.28 m behind the ChildRoom's north inner face — "about 0.3 m", and BOUNDED: the painting
# hangs 6 cm proud of the wall directly over this hole, and `check_note_mounting.gd` requires a
# wall within 0.35 m behind every wall panel. The recess's own back plate is that wall (0.34 m
# from the panel's centre). The first build put it 0.34 m back and the panel measured 0.40.
const NICHE_BACK_Z := 19.18
const WALL_CUTS := [
	{ "pos": Vector2(-8.5, 6.0), "width": 1.4, "dir": "x" },     # the tall west window
	{ "pos": Vector2(0.85, 19.0), "width": 0.62, "dir": "z" },   # the hole (PAINTING_X)
]
# The ring cut of `plaster_hole.png`: its painted-black middle made transparent (it would hide
# the fruit), so the REAL recess shows through a ragged plaster edge that covers the cut's
# square corners. Clear radius 0.328 of the quad, ring out to ~0.47 — sized so both hold.
const HOLE_DECAL := TEX + "plaster_hole_ring.png"
const HOLE_DECAL_SIZE := 0.96
const HOLE_DECAL_Z := 18.86                  # 2 cm+ clear of every CSG face (the wall is 18.9)

# ⚠️ ABOUT 0.6 s AFTER THE FLASH CLEARS, the pane shatters inward. Measured from the END of
# `flash_scare()`'s 0.8 s hold, not its start: at 0.6 s from the start the burst would happen
# UNDER the fullscreen face and the one moment the player can see the glass go would be spent.
const WINDOW_BREAK_DELAY := 0.6

const PORCH_SCRAWL := "SHALL I PUT SOMETHING THERE?"
const PORCH_SCRAWL_TIME := 3.0
const PORCH_SCRAWL_REPEAT := 4.0             # E on the empty lunette re-thinks it, no faster
const PORCH_VISIT_DWELL := 2.0               # on the deck this long, or facing the guillotine
const PORCH_GHOST_DELAY := 4.0               # the guaranteed tree-line pass after the scrawl
const PORCH_GHOST_WAIT_MAX := 6.0            # …waiting this much longer for a look at the yard
const GUILLOTINE_AT := Vector3(-10.35, 0.0, 7.75)

# ⚠️⚠️ THE FOREST CLOCK — A NEW PANIC TERM, EXPLICITLY APPROVED BY THE USER (grill Q4, 2026-09-24).
# ⚠️ DELIBERATE — the user's call 2026-09-24. Do not retune without them.
# d = metres past the porch rail (HouseOutdoors.forest_depth). ZERO on the deck — the guillotine
# is worked standing there (Issue 18: never tax the posture a puzzle requires). Off the deck the
# rate starts at exactly player.gd's PANIC_DECAY_RATE, so at the tree line the bar HOLDS, and
# rises linearly to FOREST_RATE_DEEP at FOREST_DEEP: net +2 /s, i.e. ~25 s from calm to death.
# Sprinting (+6 /s, and it suppresses decay) stacks on top — deliberately. Suspended while the
# tree is paused, a note is open, or input is frozen. A level-driven `add_panic(rate * delta)`,
# the idiom of KONTUR's phone — player.gd is untouched.
const FOREST_RATE_EDGE := 3.5    # ⚠️ DELIBERATE — the user's call 2026-09-24 (= PANIC_DECAY_RATE)
const FOREST_RATE_DEEP := 5.5    # ⚠️ DELIBERATE — the user's call 2026-09-24
const FOREST_DEEP := 20.0        # ⚠️ DELIBERATE — the user's call 2026-09-24

# The ghosts: zero panic, no collider, no rules — pictures that run and scream (DoorLunger).
const GHOST_GAP_MIN := 6.0
const GHOST_GAP_MAX := 10.0
const GHOST_MIN_DEPTH := 2.0     # only once you are properly out among the trees
const GHOST_RUN_HALF := Vector2(3.5, 5.0)
const GHOST_FAN_DEG := 25.0
const GHOST_KINDS := [
	{ "kind": "woman", "tex": "forest_ghost_woman.png", "height": 1.75, "speed": 5.5,
		"sound": "ghost_woman_scream", "near": 8.0, "far": 14.0 },
	{ "kind": "crawler", "tex": "forest_ghost_crawler.png", "height": 0.95, "speed": 7.0,
		"sound": "ghost_crawler_screech", "near": 8.0, "far": 13.0 },
	# The forest creature from the window scare, far off.
	# ⚠️ `glow`: its cutout averages 38/255 and at 16 m among dark trunks it measured as nearly
	# nothing in the render (screenshot_house_porch.gd, 12_ghost_tall) — DoorLunger.set_glow, the
	# Lab wing's Issue-208 knob, below 1.0 (Issue 21).
	{ "kind": "tall", "tex": "forest_ghost_tall.png", "height": 3.1, "speed": 3.0,
		"sound": "ghost_tall_howl", "near": 14.0, "far": 19.0, "glow": 0.6 },
]

# The witch: a note and three silent, zero-panic glimpses. She NEVER moves toward you, chases or
# kills (SCARY §8.4 — the Breach stays the only chase level).
const WITCH_TEX := TEX + "house_witch.png"
const WITCH_HEIGHT := 1.65
const WITCH_RETRY := 0.3
const WITCH_2_PATIENCE := 20.0   # glimpse 2 needs the Hallway BEHIND you; past this it is dropped
const WITCH_1_SPOTS_X := [-19.0, -21.0, -17.5]   # along the view line through the glass
const WITCH_2_SPOTS := [Vector3(0, 0, 4.2), Vector3(0, 0, 5.4), Vector3(0.5, 0, 4.6),
	Vector3(-0.5, 0, 4.6), Vector3(0, 0, 6.6)]
const WITCH_3_SPOTS := [Vector3(-17.0, 0, 9.5), Vector3(-17.5, 0, 12.5), Vector3(-18.0, 0, 7.0),
	Vector3(-16.5, 0, 4.0), Vector3(-17.0, 0, 1.0), Vector3(-18.5, 0, 6.0)]
const WITCH_NOTE_TEXT := "An old woman lives in this house.\n\nShe follows you everywhere, even when you think you are alone.\n\nDo not look for her.\n\nShe likes to hide things inside fruit."

var _builder: RoomBuilder
var _lights: Array = []           # [OmniLight3D, base_energy, fixture_material]

# Emission on a lamp's visible bulb at full brightness, driven down in step with
# light_energy by _drive_lights() — including _ev_bedroom_dark, which kills the
# bedroom lamp permanently, so its bulb goes visibly dead with it.
# ⚠️ Must stay below 1.0 — Linear tonemapping with no glow clamps anything higher
# to flat white. See the fuller note on level_1.gd's FIXTURE_EMISSION.
const FIXTURE_EMISSION := 0.6
var _window_pos: Vector3
var _forest_fired: bool = false
# THE GUEST. `_guest_stage` is the number of stages already applied, and it is what
# save_progress carries — a back-door return must not un-rearrange the house.
var _music_box: CSGBox3D = null
var _guest_child_done: bool = false
var _child_armed_on_note: bool = false   # H4: the note's close is what starts the blackout
var _child_dark: bool = false        # every lamp in the house is out while the child is here
var _child_node: Watcher = null      # the figure during the cellar sequence
var _painting_armed: bool = false    # milestone reached; falls when you look at it
var _painting_fallen: bool = false
var _bedroom_painting: StaticBody3D = null
var _guest_stage: int = 0
var _guest_props: Array[MovedProp] = []
var _overhead_timer: float = 0.0     # recurring footsteps, armed by _ev_footsteps_above
var _fridge_opened: bool = false
var _creak_timer: float = 0.0
var _pipe_timer: float = 0.0
var _blackout_clock: float = 0.0
var _blackout_timer: float = 0.0
var _cellar_gate: CellarGate
var _has_cellar_key: bool = false
var _map_solved: bool = false
var _safe_1: Node3D
var _safe_notes_read: Array[String] = []   # by node name — a re-read must not double-count
var _lock_lamp_on: bool = false
var _lock_lamp_gain: float = 0.0   # 0..1, tweened by _light_the_lock(); see _drive_lights()
var _tv_card: Label3D
var _tv_card_clock: float = 12.0   # time until the test card next surfaces
var _tv_card_hold: float = 0.0     # time the card stays legible

# --- the porch pass (2026-09-24) -------------------------------------------------------------
var _window: HouseWindow = null
var _outdoors: HouseOutdoors = null
var _guillotine: HouseGuillotine = null
var _melon: HouseWatermelon = null
var _hole_decal: MeshInstance3D = null
var _melon_state: String = "wall"          # wall | held | placed | cut
var _porch_visited: bool = false
var _porch_dwell: float = 0.0
var _porch_ghost_t: float = -1.0           # >= 0: counting to the guaranteed tree-line pass
var _scrawl_cooldown: float = 0.0
var _forest_rate: float = 0.0              # the clock's current charge, /s (0 = not charging)
var _ghost_clock: float = 0.0
var _ghost_last: int = -1
var _ghosts_spawned: int = 0
var _witch_note_read: bool = false
var _witch_fired: Array[int] = []           # which of the three glimpses have happened
var _witch_node: Watcher = null
var _witch_retry: float = 0.0
var _witch_seen_glass: bool = false         # glimpse 1: seen through the pane at least once
var _witch_unseen_t: float = 0.0
var _witch_2_wait: float = -1.0             # >= 0 while glimpse 2 is pending
var _witch_3_pending: bool = false
var _witch_logged: Dictionary = {}
var _forest_beds: Array = []                # [AudioStreamPlayer3D, base_db] — the night outside


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.current_level = 2

	_clear_old_scene()
	_build_geometry()
	_place_player()
	_spawn_lights()
	_spawn_notes()
	_spawn_witch_note()
	_spawn_lock_and_doors()
	_spawn_window()
	_spawn_porch()
	_spawn_cursed_props()
	_spawn_niche()
	_spawn_tv()
	_spawn_bathroom_mirror()
	_spawn_landing_mirror()
	_spawn_cellar_contents()
	_spawn_cellar_props()
	_spawn_music_box()
	_spawn_room_props()
	_spawn_events()
	_spawn_apparition_director()
	_start_ambience()
	_boost_ambient(DARK_AMBIENT)
	var pl0 := _player()
	if pl0 and pl0.has_method("set_torch_profile"):
		pl0.set_torch_profile(TORCH_RANGE, TORCH_ANGLE)

	Vignette.spawn(self, Color(1.0, 0.88, 0.72, 1.0), 1.4)
	RandomAmbient.register_player(_player())
	# ⚠️ STATE THE GOAL, NEVER THE SOLUTION (2026-08-16, playtest capture B2: *"I do not think
	# this hint to find the cellar key is needed. The player will figure it out"*). The line
	# read `Find the folded map — it hides the cellar key`, and the objective HUD was the ONLY
	# thing anywhere in the level that mentioned the map or the key — there is no note, scrawl,
	# prop or caption about either. So the level's one puzzle was solved on the HUD before the
	# player had entered a room.
	#
	# ⚠️ It is REPLACED, not deleted (the user's call). The map is the only route to the key
	# and nothing else in the game names it, so an empty objective would strand a player who
	# never walks into the Bathroom. A goal is fair; a pointer is not.
	#
	# ⚠️ This string has now been wrong three times — re-check it whenever the key quest moves.
	# It said "kitchen" when the key was a Landing drawer search, then "somewhere upstairs"
	# (playtest 2026-07-25) after the drawers were deleted and the quest became the folded map
	# in the BATHROOM (_spawn_bathroom_map), then it named the map outright.
	GameState.set_objective(OBJ_FIND_KEY)
	_restore_progress()      # last — overrides the fresh-level objective above
	_creak_timer = randf_range(CREAK_MIN, CREAK_MAX)
	_pipe_timer = randf_range(PIPE_MIN, PIPE_MAX)
	_blackout_clock = randf_range(BLACKOUT_MIN, BLACKOUT_MAX)


func _player() -> CharacterBody3D:
	return get_node_or_null("Player") as CharacterBody3D


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


# ---------------------------------------------------------------- geometry

const ROOMS := [
	{ "name": "EntryHall", "pos": Vector2(0, 0), "size": Vector2(3, 6) },
	{ "name": "Hallway", "pos": Vector2(0, 7), "size": Vector2(3, 8) },
	{ "name": "LivingRoom", "pos": Vector2(-5, 6), "size": Vector2(7, 6) },
	{ "name": "Kitchen", "pos": Vector2(5, 6), "size": Vector2(7, 6) },
	{ "name": "Landing", "pos": Vector2(0, 12.5), "size": Vector2(8, 3) },
	{ "name": "Bedroom", "pos": Vector2(-7, 12.5), "size": Vector2(6, 6) },
	{ "name": "Bathroom", "pos": Vector2(6.5, 12.5), "size": Vector2(5, 4) },
	{ "name": "ChildRoom", "pos": Vector2(0, 16.5), "size": Vector2(5, 5) },
]

const DOORS := [
	{ "pos": Vector2(0, 3), "width": 1.6, "dir": "z" },       # EntryHall <-> Hallway
	{ "pos": Vector2(-1.5, 6), "width": 1.4, "dir": "x" },    # Hallway <-> LivingRoom
	{ "pos": Vector2(1.5, 6), "width": 1.4, "dir": "x" },     # Hallway <-> Kitchen
	{ "pos": Vector2(0, 11), "width": 1.6, "dir": "z" },      # Hallway <-> Landing
	{ "pos": Vector2(-4, 12.5), "width": 1.4, "dir": "x" },   # Landing <-> Bedroom
	{ "pos": Vector2(4, 12.5), "width": 1.4, "dir": "x" },    # Landing <-> Bathroom
	{ "pos": Vector2(0, 14), "width": 1.6, "dir": "z" },      # Landing <-> ChildRoom
	{ "pos": Vector2(5, 3), "width": 1.6, "dir": "z" },       # Kitchen -> cellar ramp (gated)
]


func _build_geometry() -> void:
	_builder = RoomBuilder.new()
	_builder.wall_mat = RoomBuilder.make_material(
		TEX + "house_wall.png", Vector3(0.35, 0.35, 0.35), Color(0.4, 0.32, 0.26))
	_builder.floor_mat = RoomBuilder.make_material(
		TEX + "house_floor.png", Vector3(0.35, 0.35, 0.35), Color(0.28, 0.2, 0.13))
	_builder.ceil_mat = RoomBuilder.make_material(
		TEX + "house_ceiling.png", Vector3(0.35, 0.35, 0.35), Color(0.2, 0.16, 0.13))
	add_child(_builder)
	# ⚠️ DOORS + WALL_CUTS: the window and the hole are RoomBuilder cuts (full height, the only
	# kind it makes) but not doorways — see WALL_CUTS. `_build_wall_fillers()` closes them down.
	_builder.build(_rooms_with_skins(), DOORS + WALL_CUTS)
	_build_wall_fillers()
	_build_cellar()


# The two WALL_CUTS are full-height gaps; this puts the wall back where it should be.
#
# ⚠️ Every filler is EXACTLY the gap's width and the wall's full 0.2 m thickness: its end faces
# ABUT the wall segments either side (overlap 0, which `check_wall_overlap.gd` skips), and its
# room-facing face is coplanar-but-adjacent with theirs in the SAME triplanar material instance,
# so the wallpaper runs straight across without a seam. Embedding a filler into the walls
# instead would put two faces in one plane inside an overlap — Issue 23's family.
func _build_wall_fillers() -> void:
	var wm: Material = _builder.wall_mat
	# The window: a lintel over the 2.3 m opening, up to the 3.0 m wall top.
	_box("WindowLintel", Vector3(WINDOW_AT.x, (WINDOW_H + 3.0) / 2.0, WINDOW_AT.z),
		Vector3(0.2, 3.0 - WINDOW_H, WINDOW_W), wm)
	# The hole: wall below it and above it, then a shallow box behind it, outside the house.
	var x := PAINTING_X
	_box("NicheFillLow", Vector3(x, NICHE_Y.x / 2.0, 19.0), Vector3(NICHE_W, NICHE_Y.x, 0.2), wm)
	_box("NicheFillHigh", Vector3(x, (NICHE_Y.y + 3.0) / 2.0, 19.0), Vector3(NICHE_W, 3.0 - NICHE_Y.y, 0.2), wm)
	var inside := StandardMaterial3D.new()
	inside.albedo_color = Color(0.13, 0.11, 0.09)
	inside.roughness = 1.0
	var d := NICHE_BACK_Z - 19.1                  # the housing's depth outside the wall
	var zc := 19.1 + d / 2.0
	var h := NICHE_Y.y - NICHE_Y.x
	_box("NicheSill", Vector3(x, NICHE_Y.x - 0.05, zc), Vector3(NICHE_W, 0.1, d), inside)
	_box("NicheTop", Vector3(x, NICHE_Y.y + 0.05, zc), Vector3(NICHE_W, 0.1, d), inside)
	for sx in [-1.0, 1.0]:
		_box("NicheSide", Vector3(x + sx * (NICHE_W / 2.0 + 0.05), (NICHE_Y.x + NICHE_Y.y) / 2.0, zc),
			Vector3(0.1, h + 0.2, d), inside)
	_box("NicheBack", Vector3(x, (NICHE_Y.x + NICHE_Y.y) / 2.0, NICHE_BACK_Z + 0.05),
		Vector3(NICHE_W + 0.2, h + 0.2, 0.1), inside)


# Mutable copy of ROOMS with per-room skins so the kitchen and bathroom read as
# their own rooms rather than more of the same wallpaper.
func _rooms_with_skins() -> Array:
	var skins := {}
	var kw := TEX + "house_kitchen_wall.png"
	if ResourceLoader.exists(kw):
		skins["Kitchen"] = { "wall_mat": RoomBuilder.make_material(
			kw, Vector3(0.4, 0.4, 0.4), Color(0.4, 0.36, 0.28)) }
	var bw := TEX + "house_bathroom_tile.png"
	if ResourceLoader.exists(bw):
		skins["Bathroom"] = { "wall_mat": RoomBuilder.make_material(
			bw, Vector3(0.5, 0.5, 0.5), Color(0.5, 0.52, 0.5)) }
	var out: Array = []
	for r in ROOMS:
		var room: Dictionary = r.duplicate()
		if skins.has(room["name"]):
			room.merge(skins[room["name"]])
		out.append(room)
	return out


# Entry vs. exit spawn — see level_1.gd's note. Coming back from the Corridor you have
# just stepped out of the child's-room exit, not the front door.
const ENTRY_SPAWN := Vector3(0, 0.1, -2.0)
const EXIT_SPAWN := Vector3(0, 0.1, 17.6)

func _place_player() -> void:
	var p := _player()
	if not p:
		return
	if GameState.entered_from_ahead:
		p.global_position = EXIT_SPAWN
		p.rotation = Vector3(0, 0, 0)
	else:
		p.global_position = ENTRY_SPAWN
		p.rotation = Vector3(0, PI, 0)  # face +z into the house


# ---------------------------------------------------------------- progress snapshot
# See GameState.level_progress. A death still wipes this; it only survives navigation.

func save_progress() -> Dictionary:
	return {
		"map_solved": _map_solved,
		"has_cellar_key": _has_cellar_key,
		"cellar_open": is_instance_valid(_cellar_gate) and bool(_cellar_gate.get("_opened")),
		"code_correct": GameState.level2_code_correct,
		"forest_fired": _forest_fired,
		# ⚠️ SCARY.md P6's explicit warning: "register moved props in save_progress() so a
		# back-door return does not un-move them." One int covers all four stages because
		# they are monotonic.
		"guest_stage": _guest_stage,
		"fridge_open": _fridge_opened,
		# ⚠️ BOTH, not just the flag. Restoring `lock_lamp` without `safe_notes` would light the
		# house for a player who then still has to find every note to learn the code; restoring
		# `safe_notes` without `lock_lamp` would leave a solved house dark until they re-read a
		# note they have already read. They describe one state and travel together — the same
		# rule KONTUR's gate ledger had to learn the hard way (Issues 141/142).
		"safe_notes": _safe_notes_read.duplicate(),
		"lock_lamp": _lock_lamp_on,
		# H2: the chain and the cutters travel together with the digit (SafeNote_Head above).
		"fridge_chained": bool(get_node("Fridge").call("is_chained")) if get_node_or_null("Fridge") else true,
		# ⭐ 2026-09-24: "the cutters have been TAKEN" (from the guillotine's basket). They are on the
		# carried line only while the fridge is still chained — `_refresh_carried()` decides that.
		"cutters_held": _cutters_held,
		# ⭐ THE PORCH (2026-09-24). Every one of these is a STATE to force on a back-door return,
		# never an event to replay: a broken window stays broken silently, a fallen painting is on
		# the floor, the fruit is wherever it was left.
		"window_broken": is_instance_valid(_window) and _window.is_broken(),
		"porch_visited": _porch_visited,
		# ⚠️ Explicit, NOT derived from guest_stage any more. Stage 1 (the map) used to arm the
		# painting and `_force_guest_stages()` dropped it on restore from that int; the porch arms
		# it now, and a player can solve the map without ever having seen the porch.
		"painting_armed": _painting_armed,
		"painting_fallen": _painting_fallen,
		"melon_state": _melon_state,
		"witch_note": _witch_note_read,
		"witch_glimpses": _witch_fired.duplicate(),
	}


func _restore_progress() -> void:
	var data := GameState.get_level_progress(2)
	if data.is_empty():
		return
	_forest_fired = bool(data.get("forest_fired", false))
	GameState.level2_code_correct = bool(data.get("code_correct", false))

	# ⚠️ THE LAMP COMES BACK ON INSTANTLY, not by re-firing the beat. `_light_the_lock()` would
	# tween it up and play the sting again, i.e. announce a discovery the player already made
	# two levels ago. This is `MovedProp`'s restore rule: force the STATE, never replay the EVENT.
	_safe_notes_read.clear()
	for k in data.get("safe_notes", []):
		_safe_notes_read.append(String(k))
	# H2: state, never the event — no chain_drop sting, no pickup toast.
	_cutters_held = bool(data.get("cutters_held", false))
	var fr := get_node_or_null("Fridge")
	if fr and not bool(data.get("fridge_chained", true)):
		fr.call("mark_unchained")      # the cutters were spent on it; `_refresh_carried()` agrees
	_restore_porch(data)
	if bool(data.get("lock_lamp", false)):
		_lock_lamp_on = true
		# ⚠️ AND THE GAIN, or a restored house arrives with the lamp at zero and never fades up:
		# `_light_the_lock()` is the only thing that tweens it and it is deliberately not called
		# here (that would replay the sting). State, not event — the same split the Lab's
		# `_light_the_wing(true)` makes.
		_lock_lamp_gain = 1.0
		# ⚠️ THE OBJECTIVE IS WRITTEN AT THE BOTTOM OF THIS FUNCTION, NOT HERE. It used to be set
		# on this line and the cellar/key chain below then overwrote it every time — and that
		# chain is EARLIER in the quest, because the third safe note is in the cellar, so a lamp
		# that is on implies a cellar that is open. A restored house therefore told a player who
		# had already read all three notes to go and open the cellar.
		pass

	# The house stays rearranged. Forced rather than re-armed: the player already saw these
	# moved before they left, so waiting for another look-away would visibly un-move them.
	var stage := int(data.get("guest_stage", 0))
	if stage > 0:
		_force_guest_stages(stage)
	# A fridge that has been opened must not be re-openable for another 10 panic.
	if bool(data.get("fridge_open", false)):
		_fridge_opened = true
		var fridge := get_node_or_null("Fridge")
		if fridge:
			fridge.queue_free()
	if bool(data.get("map_solved", false)):
		_map_solved = true
		var map := get_node_or_null("HouseMap")
		if map:
			map.queue_free()          # already solved; don't offer the minigame again
	if bool(data.get("cellar_open", false)):
		if is_instance_valid(_cellar_gate):
			_cellar_gate.open()
		GameState.set_objective(OBJ_CODE)
	elif bool(data.get("has_cellar_key", false)):
		_has_cellar_key = true
		GameState.set_objective(OBJ_UNLOCK_CELLAR)
	elif _map_solved:
		# Won the map but never picked the key up — it is still lying on the counter.
		GameState.set_objective(OBJ_COLLECT_KEY)

	# LAST, so it wins: the lamp is the furthest point reached in this level. See above.
	if _lock_lamp_on:
		GameState.set_objective(OBJ_LOCK_LIT)
	# Every held item at once — the key, the fruit, the cutters (2026-09-24).
	_refresh_carried()


# ---------------------------------------------------------------- cellar (lowered)

const CELLAR_Y := -1.5
const CELLAR_CENTER := Vector2(5, -6)
const CELLAR_SIZE := Vector2(7, 7)
const CELLAR_H := 2.6
const CELLAR_WALL_T := 0.2
const CELLAR_WALL_CLEAR := 0.06

var _cellar_mat: StandardMaterial3D


# `RoomBuilder.wall_point()` for the CELLAR, which is not a RoomBuilder room and so had no
# equivalent — which is exactly why the third note was hand-typed and ended up 1.40 m out in
# mid-air (capture A4). Same contract as the real one: `side` is a unit direction, the return
# is `clearance` metres in front of that wall's INNER FACE (the shell is CELLAR_WALL_T thick
# and centred on the nominal boundary, so the face is T/2 in). The 3 cm floor mirrors
# RoomBuilder.MIN_FACE_CLEAR — below that a prop is buried in the wall (Issue 11) and at
# exactly 0 it is coplanar and z-fights.
func _cellar_wall_point(side: Vector2, y: float, clearance := CELLAR_WALL_CLEAR) -> Vector3:
	var half: Vector2 = CELLAR_SIZE * 0.5
	var inset: float = CELLAR_WALL_T / 2.0 + maxf(clearance, 0.03)
	return Vector3(
		CELLAR_CENTER.x + side.x * (half.x - inset),
		y,
		CELLAR_CENTER.y + side.y * (half.y - inset))


func _build_cellar() -> void:
	_cellar_mat = RoomBuilder.make_material(
		TEX + "house_basement_concrete.png", Vector3(0.35, 0.35, 0.35), Color(0.18, 0.18, 0.19))
	var c := CELLAR_CENTER
	var s := CELLAR_SIZE
	var x0 := c.x - s.x / 2.0
	var x1 := c.x + s.x / 2.0
	var z0 := c.y - s.y / 2.0   # far (south) edge
	var z1 := c.y + s.y / 2.0   # near (north) edge, where the ramp enters: z=-2.5

	# Floor + ceiling.
	_box("CellarFloor", Vector3(c.x, CELLAR_Y - 0.15, c.y), Vector3(s.x, 0.3, s.y), _cellar_mat)
	_box("CellarCeiling", Vector3(c.x, CELLAR_Y + CELLAR_H + 0.15, c.y), Vector3(s.x, 0.3, s.y), _cellar_mat)
	# Side + far walls.
	# ⚠️ Nudged 1 cm west. The cellar shell reaches y=+1.1 (CELLAR_Y + CELLAR_H), so
	# above ground level it runs alongside the ground-floor walls, and this one shared
	# a plane with a RoomBuilder wall — coincident faces z-fight. 1 cm cannot open a
	# gap (the slab is 0.2 thick and still overlaps everything it did before), it just
	# breaks the tie. Asserted by tests/check_wall_overlap.gd.
	_box("CellarWallW", Vector3(x0 - 0.01, CELLAR_Y + CELLAR_H / 2.0, c.y), Vector3(0.2, CELLAR_H, s.y), _cellar_mat)
	_box("CellarWallE", Vector3(x1, CELLAR_Y + CELLAR_H / 2.0, c.y), Vector3(0.2, CELLAR_H, s.y), _cellar_mat)
	_box("CellarWallS", Vector3(c.x, CELLAR_Y + CELLAR_H / 2.0, z0), Vector3(s.x, CELLAR_H, 0.2), _cellar_mat)
	# Near wall split for the ramp opening (1.6 wide at x=5).
	_box("CellarWallN_A", Vector3(2.7, CELLAR_Y + CELLAR_H / 2.0, z1), Vector3(2.4, CELLAR_H, 0.2), _cellar_mat)
	_box("CellarWallN_B", Vector3(7.3, CELLAR_Y + CELLAR_H / 2.0, z1), Vector3(2.4, CELLAR_H, 0.2), _cellar_mat)

	# The descent ramp. Its top surface MUST be continuous with the floors at both ends
	# or the player can't walk it: a tilted box pokes an end-lip above the floor where
	# it meets it, and Godot's move_and_slide does not climb steps (the real "can't
	# enter the cellar" bug — the player jammed against the top lip). So:
	#   • the top starts at z=1.7, exactly where RoomBuilder's doorway floor-bridge ends
	#     (both at y=0) — the walker crosses bridge→ramp on one flush plane;
	#   • the bottom meets the cellar floor at y=-1.5 and is extended 0.6 m further south
	#     so its lower end-lip is buried under the cellar floor.
	const RAMP_T := 0.3
	var p_top := Vector3(5, 0.0, 1.7)
	var p_bot := Vector3(5, CELLAR_Y, z1)               # cellar near wall, floor level
	var along := (p_bot - p_top).normalized()
	var ang := atan2(-along.y, -along.z)                # slope below horizontal (>0)
	var up_n := Vector3(0, cos(ang), sin(ang))          # ramp top-face normal (points up)
	var s_bot := p_bot + along * 0.6                    # bury the bottom end under the floor
	var surf_mid := (p_top + s_bot) * 0.5
	var ramp_len := (s_bot - p_top).length()

	var stairs_tex: String = TEX + "house_wood_stairs.png"
	var ramp_mat: Material = _cellar_mat
	if ResourceLoader.exists(stairs_tex):
		ramp_mat = RoomBuilder.make_material(stairs_tex, Vector3(0.5, 0.5, 0.5), Color(0.25, 0.17, 0.1))
	var ramp := CSGBox3D.new()
	ramp.name = "CellarRamp"
	ramp.size = Vector3(2.2, RAMP_T, ramp_len)
	ramp.position = surf_mid - up_n * (RAMP_T * 0.5)    # drop centre so the TOP face is the surface line
	ramp.rotation.x = -ang
	ramp.use_collision = true
	ramp.material = ramp_mat
	add_child(ramp)
	# Shaft side walls — parallel to the ramp, offset ±1.2 m in x, raised to seal the
	# sides from the ramp up past the cap.
	for sx in [-1.0, 1.0]:
		var w := CSGBox3D.new()
		w.size = Vector3(0.2, 3.6, ramp_len + 0.4)
		w.position = surf_mid + Vector3(sx * 1.2, 1.4, 0)
		w.rotation.x = -ang
		w.use_collision = true
		w.material = _cellar_mat
		add_child(w)
	# Sloped ceiling, offset a CONSTANT 2.6 m along the ramp normal so headroom is
	# uniform (~2.45 m vertical over the 1.8 m player) the whole way down.
	var shaft_ceil := CSGBox3D.new()
	shaft_ceil.name = "CellarShaftCeiling"
	shaft_ceil.size = Vector3(2.6, 0.3, ramp_len)
	shaft_ceil.position = surf_mid + up_n * 2.6
	shaft_ceil.rotation.x = -ang
	shaft_ceil.use_collision = true
	shaft_ceil.material = _cellar_mat
	add_child(shaft_ceil)
	# Flat cap at kitchen-ceiling height (y=3) over the shaft mouth: seals the wedge
	# above the sloped ceiling (the background is black now, so any residual gap reads
	# as darkness rather than sky).
	var cap := CSGBox3D.new()
	cap.name = "CellarShaftCap"
	cap.size = Vector3(3.0, 0.3, 7.0)
	cap.position = Vector3(5, 3.0, -0.15)
	cap.use_collision = true
	cap.material = _cellar_mat
	add_child(cap)


# ---------------------------------------------------------------- lighting

func _spawn_lights() -> void:
	for r in ROOMS:
		var c: Vector3 = _builder.room_center(r["name"])
		var warm := 0.9
		if r["name"] == "Bedroom" or r["name"] == "ChildRoom":
			warm = 0.75   # bedrooms a touch dimmer / moodier
		_add_lamp(r["name"], Vector3(c.x, 2.6, c.z), warm, Color(0.95, 0.8, 0.6))
	# A dim, cold bulb in the cellar.
	_add_lamp("Cellar", Vector3(CELLAR_CENTER.x, CELLAR_Y + 2.2, CELLAR_CENTER.y), 0.5, Color(0.6, 0.65, 0.7))


func _add_lamp(lamp_name: String, pos: Vector3, energy: float, color: Color) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp_" + lamp_name
	lamp.position = pos
	lamp.light_energy = energy
	lamp.light_color = color
	lamp.omni_range = 10.0
	add_child(lamp)
	_lights.append([lamp, energy, _add_fixture(lamp, color)])


# A visible bulb-and-shade for a ceiling lamp — the domestic counterpart to the
# Lab's fluorescent fitting. See the note in level_1.gd:_add_fixture for why this
# matters: levels 1 and 2 were the only ones lighting rooms with lights that had
# no geometry, and that (not brightness) is what made them read as empty.
#
# Ambient and light energy are unchanged; this only gives the eye a source.
func _add_fixture(lamp: OmniLight3D, color: Color) -> StandardMaterial3D:
	var flex := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.012
	fm.bottom_radius = 0.012
	fm.height = 0.34
	flex.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.1, 0.09, 0.08)
	flex.set_surface_override_material(0, fmat)
	flex.position = Vector3(0, 0.3, 0)
	lamp.add_child(flex)

	var shade := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.07
	sm.bottom_radius = 0.2
	sm.height = 0.18
	shade.mesh = sm
	var smat := StandardMaterial3D.new()
	# ⚠️ Dark albedo on purpose: the shade sits centimetres from its own point
	# light, and a bright albedo renders as a blown-out white slab. See the note in
	# level_1.gd:_add_fixture — the glow belongs to the bulb's emission.
	smat.albedo_color = Color(0.16, 0.13, 0.1)
	smat.roughness = 0.9
	shade.set_surface_override_material(0, smat)
	shade.position = Vector3(0, 0.1, 0)
	lamp.add_child(shade)

	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.05
	bm.height = 0.1
	bulb.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = color.darkened(0.85)
	bmat.emission_enabled = true
	bmat.emission = color
	bmat.emission_energy_multiplier = FIXTURE_EMISSION
	bulb.set_surface_override_material(0, bmat)
	bulb.position = Vector3(0, 0.02, 0)
	lamp.add_child(bulb)
	return bmat


# ---------------------------------------------------------------- notes

func _spawn_notes() -> void:
	# Three safe notes — one digit each (code 472). The third is in the cellar.
	# ⭐ 2026-09-24: on the living room's NORTH wall (its centre — the wall has no doorway). It was
	# the WEST wall's centre, which is exactly where the tall window is now: a note there would be
	# read with your face at the glass, inside FOREST_SCARE_DIST, i.e. the scare would fire over
	# the page. The north wall is 3.4 m from the window centre.
	_safe_1 = _make_note(_builder.wall_point("LivingRoom", Vector2(0, 1), 1.4, 0.13), PI,
		"The first number is scratched by the door frame. It is 4.", false, "SafeNote_Living")
	# H2 (2026-09-13): the second digit is no longer a page on the Bedroom wall — it is written
	# on the forehead of the head in the chained fridge (see _tick_head_digit). The user: "one
	# number is hard to get — while the others are just there".
	# The cellar note is THE GUEST's last trigger: reading it is the deepest point of the
	# route, so the walk back up is the longest single stretch the player will make with
	# their back to the whole house.
	# ⚠️ HUNG ON THE SOUTH WALL, not hand-computed (fixed 2026-08-16, playtest capture A4:
	# *"This note is floating in the air"*). It was at
	# `Vector3(CELLAR_CENTER.x - 1.5, CELLAR_Y + 1.4, CELLAR_CENTER.y - 2.0)` = (3.5, -0.1,
	# -8.0) with `y_rot = 0`, i.e. facing +z with the nearest wall behind it — the south wall's
	# inner face — a measured **1.40 m** away. It was the only note in the level not placed by
	# a wall_point() helper, and the cellar had no such helper because it is not a RoomBuilder
	# room. It has one now; see _cellar_wall_point().
	var cellar_note := _make_note(
		_cellar_wall_point(Vector2(0, -1), CELLAR_Y + 1.4) + Vector3(-1.5, 0.0, 0.0), 0.0,
		"Third digit — the one she always used — 2.\n\nDon't forget. Don't forget. Don't forget.",
		false, "SafeNote_Cellar")
	if cellar_note:
		cellar_note.read.connect(func() -> void:
			_advance_guest(4)
			_arm_child_on_note_close())

	# ⚠️ THERE WAS NO NOTE COUNTER BEFORE THIS (2026-09-03). `_spawn_notes()` discarded two of the
	# three safe notes' return values and only the cellar one's `read` signal was ever wired;
	# `GameState.journal` is a de-duplicated array across the whole game, not a per-level count.
	# `_make_note()` already returns the body and `note.gd:17` already has `signal read`, so this
	# is three connections and an int.
	# ⚠️ Connected to `read`, which fires on OPEN. Reading-to-the-end is a mechanic reserved for
	# TRAP notes; requiring it here would make the lights depend on surviving something.
	for n in [_safe_1, cellar_note]:
		if n:
			n.read.connect(_on_safe_note_read.bind(n))
	# Two trap notes (read-to-die).
	_make_note(_builder.wall_point("Bathroom", Vector2(1, 0), 1.3, 0.1), -PI / 2.0,
		"it got in it got in it got in it got in it got in\n\nDONT READ THIS dont read this stop stop stop stop", true)
	_make_note(_builder.wall_point("ChildRoom", Vector2(-1, 0), 1.3, 0.1), PI / 2.0,
		"Subject 44 was removed on day 3.\nSubject 45 was removed on day 1.\nSubject 46 was removed on day 6.\n\nYou are not going to make it.", true)


# Returns the note body so a caller can hook its `read` signal (note.gd emits that on OPEN,
# which is the generic hook the project lacked until level_1.gd's locker gate needed it).
# Existing call sites ignore the return — additive.
# ⚠️⚠️ `note_name` EXISTS BECAUSE THE LAMP COUNTER IS KEYED ON IT (2026-09-03). Notes used to be
# added anonymously, so Godot auto-named them `@StaticBody3D@NNN` — and that number depends on how
# many nodes were created before, which is NOT the same on a fresh load as on a back-door return
# (`_restore_progress()` frees and rebuilds props first). So `_safe_notes_read`, restored from a
# snapshot, matched nothing: a returning player's two saved keys plus two freshly-read ones made
# FOUR entries and lit the lamp **without the cellar note ever being found** — i.e. without the
# third digit, which is the whole reason the descent is mandatory.
# Issue 17's family (Godot silently renames colliding siblings and anything keyed on the name
# then finds the wrong node), reached from the other direction.
func _make_note(pos: Vector3, y_rot: float, text: String, trap: bool,
		note_name: String = "") -> StaticBody3D:
	var note := StaticBody3D.new()
	note.set_script(_NOTE_SCRIPT)
	note.note_text = text
	note.is_trap = trap
	note.position = pos
	note.rotation.y = y_rot
	if note_name != "":
		note.name = note_name
	add_child(note)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.42, 0.01)
	mesh.mesh = bm
	mesh.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(trap, EM_NOTE_SCALE))
	note.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.5, 0.12)
	col.shape = shape
	note.add_child(col)
	return note


# ---------------------------------------------------------------- lock + doors

const LOCK_SIZE := Vector2(0.36, 0.45)


func _spawn_lock_and_doors() -> void:
	var exit := _make_door("ExitDoor", true, false)
	exit.unlock_condition = _DOOR_SCRIPT.UnlockCondition.CODE_ENTERED
	exit.position = Vector3(-0.7, 1.225, 18.9)
	exit.rotation.y = PI

	# The combination lock, mounted directly on the exit door as a CHILD of it
	# (local coordinates -> inherits the door's position/rotation automatically)
	# instead of a separate wall panel 1.4 m away. Local z=0.1 sits proud of
	# the door's own face quad (at local z=0.079) so it doesn't z-fight and is
	# the first thing the interact raycast hits.
	var lock := StaticBody3D.new()
	lock.name = "ExitLock"
	lock.set_script(_LOCK_SCRIPT)
	lock.position = Vector3(0.0, -0.35, 0.1)
	exit.add_child(lock)
	lock.connect("unlocked", _on_exit_lock_unlocked.bind(lock))
	if GameState.level2_code_correct:
		lock.queue_free()   # resume path: a code already entered means a lock already on the floor

	# Artwork on a QuadMesh (CLAUDE.md rule — a BoxMesh crops instead of showing
	# the whole texture). house_lock_transparent.png has a real alpha channel (no
	# backing plate needed — it hangs directly against the door's own wood
	# texture); house_lock.png/lock_face.png stay as opaque fallbacks.
	var lface := MeshInstance3D.new()
	var lqm := QuadMesh.new()
	lqm.size = LOCK_SIZE
	lface.mesh = lqm
	lface.position = Vector3(0, 0, 0.01)
	var lmat := StandardMaterial3D.new()
	var lock_tex_path := TEX + "house_lock_transparent.png"
	if not ResourceLoader.exists(lock_tex_path):
		lock_tex_path = TEX + "house_lock.png"
	if not ResourceLoader.exists(lock_tex_path):
		lock_tex_path = TEX + "lock_face.png"
	if ResourceLoader.exists(lock_tex_path):
		lmat.albedo_texture = load(lock_tex_path)
	lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lmat.alpha_scissor_threshold = 0.5
	lmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lmat.metallic = 0.3
	lmat.roughness = 0.7
	lface.set_surface_override_material(0, lmat)
	lock.add_child(lface)

	var lcol := CollisionShape3D.new()
	var ls := BoxShape3D.new()
	ls.size = Vector3(LOCK_SIZE.x, LOCK_SIZE.y, 0.15)
	lcol.shape = ls
	lock.add_child(lcol)

	_add_lamp("Lock", Vector3(-0.7, 1.5, 18.75), 0.4, Color(0.8, 0.6, 0.4))

	var back := _make_door("BackDoor", false, true)
	back.position = Vector3(0, 1.225, -2.85)


# H4 (2026-09-13, capture #10, the user's design): the lock FALLS off the door and is gone, then
# the door asks. `unlocked` is emitted while the dial UI still has the tree paused, and the lock
# inherits the pause, so the whole beat rides one Tween on the lock: it starts the frame the UI
# closes (Issue 58's shape, on purpose — the fall is what the player sees the UI close onto).
# Zero panic; the scrawl is a question, not a rule.
const LOCK_FALL := 0.9                     # metres, to the floor at the foot of the door
const LOCK_SCRAWL := "ARE YOU SURE YOU WANT TO GO IN THERE?"
func _on_exit_lock_unlocked(lock: Node3D) -> void:
	if not is_instance_valid(lock):
		return
	# The interact ray must not find a falling lock (E would reopen the dials).
	lock.set("collision_layer", 0)
	var tw := lock.create_tween()
	tw.tween_callback(func() -> void: _play_at("lock_drop", lock.global_position, 2.0))
	tw.tween_property(lock, "position:y", lock.position.y - LOCK_FALL, 0.55) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lock, "rotation:z", deg_to_rad(28.0), 0.4)
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void: ScreenText.scrawl(get_tree(), LOCK_SCRAWL, 3.0))
	tw.tween_interval(0.6)
	tw.tween_callback(lock.queue_free)


func _make_door(door_name: String, advances: bool, goes_back: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = door_name
	body.set_script(_DOOR_SCRIPT)
	body.advances_level = advances
	body.goes_back = goes_back
	add_child(body)
	_DOOR_SCRIPT.build_visual(body, Vector3(1.25, 2.45, 0.15), TEX + "house_door.png",
		EM_DOOR_SCALE)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.25, 2.45, 0.2)
	col.shape = shape
	body.add_child(col)
	return body


# ---------------------------------------------------------------- window/forest + THE PORCH
#
# ⭐⭐ 2026-09-24 — the Porch pass. The old window (a painted `forest.png` quad behind glass on the
# NORTH wall, which backed onto the Bedroom 0.5 m away) is deleted. The window is a real opening
# in the living room's WEST wall now — see house_window.gd — and the forest behind it is real.

func _spawn_window() -> void:
	_window = HouseWindow.new()
	_window.name = "HouseWindow"
	_window.position = WINDOW_AT
	add_child(_window)
	_window.burst.connect(_on_window_burst)
	# The forest scare's trigger point (`_tick_forest`, 2-D distance): the glass's centre.
	_window_pos = WINDOW_AT + Vector3(0, 1.15, 0)


func _burst_window() -> void:
	if not is_instance_valid(_window) or _window.is_broken():
		return
	_window.break_pane(true)


func _on_window_burst(animated: bool) -> void:
	# A burst window has spent its scare, however it burst (the restore path and the reachability
	# sweep's gate break it without the flash) — or the face would fire on the deck.
	_forest_fired = true
	if is_instance_valid(_witch_node) and _witch_node.name == "Witch1":
		_witch_node.queue_free()
		_witch_node = null
	if not animated:
		return
	var p := _player()
	if p:
		p.jolt_camera(0.06, 0.4)
	_log("PORCH window burst — the pane is gone, the porch is open")


func _spawn_porch() -> void:
	_outdoors = HouseOutdoors.new()
	_outdoors.name = "HouseOutdoors"
	add_child(_outdoors)
	_outdoors.build()

	_guillotine = HouseGuillotine.new()
	_guillotine.name = "Guillotine"
	_guillotine.position = GUILLOTINE_AT
	# Its front (the basket, the lunette) turned toward the window: you meet it head-on as you
	# step out, and it is in the frame from inside the living room.
	var to_window := Vector2(WINDOW_AT.x - GUILLOTINE_AT.x, WINDOW_AT.z - GUILLOTINE_AT.z)
	_guillotine.rotation.y = atan2(to_window.x, to_window.y)
	add_child(_guillotine)
	_guillotine.empty_tried.connect(_on_guillotine_empty_tried)
	_guillotine.loaded.connect(_on_guillotine_loaded)
	_guillotine.cut.connect(_on_guillotine_cut)
	_guillotine.cutters_taken.connect(_on_guillotine_cutters_taken)

	_ghost_clock = randf_range(GHOST_GAP_MIN, GHOST_GAP_MAX)

	# The night outside: one bed on the porch, one out in the trees. Faint through the glass,
	# fuller once it is broken, full outside (`_tick_outdoor_audio`). Every .wav/.ogg here imports
	# loop_mode=0, so the loop is restarted in code.
	var s := GameState.load_audio("porch_forest_night")
	if s:
		for spec in [[Vector3(-10.5, 1.8, 6.0), -10.0, 5.0, 18.0], [Vector3(-26.0, 2.5, 6.0), -6.0, 10.0, 30.0]]:
			var a := AudioStreamPlayer3D.new()
			a.name = "ForestNight"
			a.stream = s
			a.volume_db = float(spec[1]) - 18.0
			a.unit_size = float(spec[2])
			a.max_distance = float(spec[3])
			a.bus = AudioBuses.AMBIENCE
			a.position = spec[0]
			add_child(a)
			a.finished.connect(a.play)
			a.play()
			_forest_beds.append([a, float(spec[1])])


# The witch's note, on a small side table a few steps ahead of the spawn in the Entry Hall.
# Journal-archived by note.gd like any safe page, but it is NOT a safe note: it carries no digit,
# its name does not start with "SafeNote_", and nothing connects it to `_on_safe_note_read`, so
# SAFE_NOTES_TOTAL and the lock lamp never see it. Nor is it a trap.
func _spawn_witch_note() -> void:
	var base := Vector3(1.1, 0.0, -0.6)
	var top := _make_prop(base + Vector3(0, 0.76, 0), Vector3(0.46, 0.04, 0.36),
		Color(0.30, 0.22, 0.15), 0.0, TEX + "house_wood_stairs.png")
	top.name = "WitchTable"
	for dx in [-0.19, 0.19]:
		for dz in [-0.14, 0.14]:
			_make_prop(base + Vector3(dx, 0.37, dz), Vector3(0.04, 0.74, 0.04), Color(0.2, 0.15, 0.1))
	# Lying FLAT on the top, face up, 5 mm clear of it.
	var note := _make_note(base + Vector3(0.02, 0.79, 0.0), 0.0, WITCH_NOTE_TEXT, false, "WitchNote")
	note.rotation = Vector3(-PI / 2.0, deg_to_rad(-12.0), 0.0)
	note.read.connect(_on_witch_note_read)


func _on_witch_note_read() -> void:
	if not _witch_note_read:
		_log("WITCH note read")
	_witch_note_read = true


# The hole behind the falling painting and the fruit in it. The decal is hidden and the fruit is
# inert until the painting comes down (`_reveal_niche()`, called from `_drop_painting()`).
func _spawn_niche() -> void:
	_hole_decal = MeshInstance3D.new()
	_hole_decal.name = "PlasterHole"
	var qm := QuadMesh.new()
	qm.size = Vector2(HOLE_DECAL_SIZE, HOLE_DECAL_SIZE)
	_hole_decal.mesh = qm
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(HOLE_DECAL):
		m.albedo_texture = load(HOLE_DECAL)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
	else:
		m.albedo_color = Color(0.25, 0.22, 0.19)
	m.roughness = 1.0
	_hole_decal.set_surface_override_material(0, m)
	_hole_decal.position = Vector3(PAINTING_X, (NICHE_Y.x + NICHE_Y.y) / 2.0, HOLE_DECAL_Z)
	_hole_decal.rotation.y = PI       # a QuadMesh faces +Z; the room is at -Z of this wall
	_hole_decal.visible = false
	add_child(_hole_decal)

	_melon = HouseWatermelon.new()
	_melon.name = "HouseWatermelon"
	_melon.position = Vector3(PAINTING_X, NICHE_Y.x + HouseWatermelon.GIRTH / 2.0 + 0.004, 19.04)
	_melon.on_force_reveal = _force_painting_down
	add_child(_melon)
	_melon.picked_up.connect(_on_melon_taken)


func _reveal_niche() -> void:
	if is_instance_valid(_hole_decal):
		_hole_decal.visible = true
	if is_instance_valid(_melon):
		_melon.reveal()


# The painting's restore path, as a callable: `HouseWatermelon.move_aside_instantly()` (the
# reachability sweep's gate) and nothing else. Same end state as a player who watched it fall.
func _force_painting_down() -> void:
	_painting_armed = true
	_drop_painting(false)


func _arm_painting() -> void:
	if _painting_armed:
		return
	_painting_armed = true
	_log("GUEST painting armed (first porch visit)")


func _restore_porch(data: Dictionary) -> void:
	_witch_note_read = bool(data.get("witch_note", false))
	_witch_fired.clear()
	for g in data.get("witch_glimpses", []):
		_witch_fired.append(int(g))
	# A forest scare that fired is a window that burst — the burst always follows the flash.
	if (bool(data.get("window_broken", false)) or _forest_fired) and is_instance_valid(_window):
		_window.break_pane(false)
	_porch_visited = bool(data.get("porch_visited", false))
	_painting_armed = bool(data.get("painting_armed", false)) or _porch_visited
	if bool(data.get("painting_fallen", false)):
		_drop_painting(false)
	_melon_state = String(data.get("melon_state", "wall"))
	if _melon_state != "wall" and is_instance_valid(_melon):
		_melon.queue_free()
		_melon = null
	if is_instance_valid(_guillotine):
		_guillotine.melon_in_hand = _melon_state == "held"
		_guillotine.restore(_melon_state, _cutters_held)


# ⭐ THE CARRIED LINE LISTS EVERYTHING HELD (2026-09-24). `GameState.set_carried()` takes ONE
# string and every call site used to write its own item into it — so taking the bolt cutters
# while carrying the cellar key REPLACED "cellar key" on the HUD with "BOLT CUTTERS", and using
# either one cleared the line while the other was still in hand. The level now owns one list and
# rewrites the whole line from state every time anything changes. The cutters are "held" only
# while the fridge they exist for is still chained.
func _refresh_carried() -> void:
	var items := PackedStringArray()
	if _has_cellar_key:
		items.append("cellar key")
	if _melon_state == "held":
		items.append("watermelon")
	if _cutters_held and _fridge_chained():
		items.append("bolt cutters")
	GameState.set_carried(" · ".join(items))


func _fridge_chained() -> bool:
	var fr := get_node_or_null("Fridge")
	return fr != null and not fr.is_queued_for_deletion() and bool(fr.call("is_chained"))


func _on_melon_taken() -> void:
	_melon = null
	_melon_state = "held"
	if is_instance_valid(_guillotine):
		_guillotine.melon_in_hand = true
	_refresh_carried()
	_witch_2_wait = 0.0          # she is at the far end of the Hallway, behind you
	_log("PORCH watermelon taken from the hole behind the painting")


func _on_guillotine_empty_tried() -> void:
	if _scrawl_cooldown > 0.0:
		return
	_scrawl_cooldown = PORCH_SCRAWL_REPEAT
	ScreenText.scrawl(get_tree(), PORCH_SCRAWL, PORCH_SCRAWL_TIME)
	_log("PORCH guillotine: E on the empty lunette — the thought again")


func _on_guillotine_loaded() -> void:
	_melon_state = "placed"
	if is_instance_valid(_guillotine):
		_guillotine.melon_in_hand = false
	_refresh_carried()
	if _witch_2_wait >= 0.0 and not _witch_fired.has(2):
		_witch_2_wait = -1.0
		_log("WITCH glimpse 2 ABANDONED — the fruit reached the lunette first")
	_log("PORCH guillotine loaded")


func _on_guillotine_cut() -> void:
	_melon_state = "cut"
	var p := _player()
	if p:
		p.jolt_camera(0.04, 0.3)
	_witch_3_pending = true      # …and she watches from the tree line
	_log("PORCH guillotine: the blade dropped; the bolt cutters are in the basket")


func _on_guillotine_cutters_taken() -> void:
	_cutters_held = true
	_refresh_carried()
	_log("PORCH bolt cutters taken from the guillotine's basket")


# ---------------------------------------------------------------- the porch: the first visit

func _tick_porch(delta: float) -> void:
	_scrawl_cooldown = maxf(0.0, _scrawl_cooldown - delta)
	var p := _player()
	if not p:
		return
	if not _porch_visited and HouseOutdoors.on_deck(p.global_position):
		_porch_dwell += delta
		var facing := is_instance_valid(_guillotine) \
			and _facing(p, _guillotine.global_position + Vector3(0, 1.0, 0), 0.6)
		if facing or _porch_dwell >= PORCH_VISIT_DWELL:
			_on_first_porch_visit()
	# The guaranteed tree-line pass, once the player is looking out at the yard (or it has waited
	# long enough — then it runs anyway and is heard).
	if _porch_ghost_t >= 0.0:
		_porch_ghost_t += delta
		if _porch_ghost_t >= PORCH_GHOST_DELAY:
			if _looking_at_yard(p) or _porch_ghost_t >= PORCH_GHOST_DELAY + PORCH_GHOST_WAIT_MAX:
				_porch_ghost_t = -1.0
				_spawn_tree_line_ghost(p)


# The first time you are out on the deck: the thought, the painting armed, and a ghost to come.
func _on_first_porch_visit() -> void:
	if _porch_visited:
		return
	_porch_visited = true
	ScreenText.scrawl(get_tree(), PORCH_SCRAWL, PORCH_SCRAWL_TIME)
	_scrawl_cooldown = PORCH_SCRAWL_REPEAT
	_arm_painting()
	_porch_ghost_t = 0.0
	_log("PORCH first visit — SHALL I PUT SOMETHING THERE?")


func _facing(p: CharacterBody3D, target: Vector3, min_dot: float) -> bool:
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return false
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var to := target - cam.global_position
	to.y = 0.0
	if fwd.length() < 0.01 or to.length() < 0.01:
		return false
	return fwd.normalized().dot(to.normalized()) >= min_dot


func _cam_forward(p: CharacterBody3D) -> Vector3:
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	var fwd := -cam.global_basis.z if cam else Vector3.FORWARD
	fwd.y = 0.0
	return fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD


func _looking_at_yard(p: CharacterBody3D) -> bool:
	return _cam_forward(p).x < -0.35


# ---------------------------------------------------------------- the forest clock

# ⚠️ A USER-APPROVED PANIC TERM (grill Q4, 2026-09-24) — see FOREST_RATE_EDGE. Zero on the deck
# and indoors; from the rail outward it starts at exactly the player's decay (the bar HOLDS) and
# climbs to FOREST_RATE_DEEP at FOREST_DEEP m.
func forest_rate_at(d: float) -> float:
	if d <= 0.0:
		return 0.0
	return lerpf(FOREST_RATE_EDGE, FOREST_RATE_DEEP, clampf(d / FOREST_DEEP, 0.0, 1.0))


var _forest_deepest: float = 0.0

func _tick_forest_clock(delta: float) -> void:
	var p := _player()
	if not p:
		return
	# Suspended — not merely paused with the tree — while a page is open or the player is pinned.
	if get_tree().paused or NoteUI.is_open \
			or (p.has_method("is_input_frozen") and p.is_input_frozen()):
		return
	var d := HouseOutdoors.forest_depth(p.global_position)
	var rate := forest_rate_at(d)
	if rate > 0.0 and _forest_rate <= 0.0:
		_forest_deepest = d
		_log("FOREST clock ON at d=%.1f m (%.2f /s)" % [d, rate])
	elif rate <= 0.0 and _forest_rate > 0.0:
		_log("FOREST clock OFF — back on the deck (deepest %.1f m)" % _forest_deepest)
	_forest_deepest = maxf(_forest_deepest, d)
	_forest_rate = rate
	if rate > 0.0:
		p.add_panic(rate * delta)


# ---------------------------------------------------------------- the ghosts
#
# Zero panic, no collider, no ScaryObject, no rules: a `DoorLunger` figure (the Corridor's
# run-away billboard) that appears ahead, runs ACROSS the view between the trunks with its scream
# on it, fades over its last 2 m and frees itself. They exist only out among the trees.

func _tick_ghosts(delta: float) -> void:
	var p := _player()
	if not p:
		return
	if HouseOutdoors.forest_depth(p.global_position) <= GHOST_MIN_DEPTH:
		return
	_ghost_clock -= delta
	if _ghost_clock > 0.0:
		return
	_ghost_clock = randf_range(GHOST_GAP_MIN, GHOST_GAP_MAX) if _spawn_cadence_ghost(p) else 1.0


func _spawn_cadence_ghost(p: CharacterBody3D) -> bool:
	var fwd := _cam_forward(p)
	var k := randi() % GHOST_KINDS.size()
	if k == _ghost_last:
		k = (k + 1) % GHOST_KINDS.size()
	var spec: Dictionary = GHOST_KINDS[k]
	for attempt in range(6):
		var dist: float = randf_range(float(spec["near"]), float(spec["far"])) * (1.0 - 0.12 * attempt)
		var dir := fwd.rotated(Vector3.UP, deg_to_rad(randf_range(-GHOST_FAN_DEG, GHOST_FAN_DEG)))
		var c := p.global_position + dir * dist
		c.y = 0.0
		if not _in_yard_margin(c, 1.0):
			continue
		var side := dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
		var half := randf_range(GHOST_RUN_HALF.x, GHOST_RUN_HALF.y)
		var a := _clamp_yard(c - side * half)
		var b := _clamp_yard(c + side * half)
		if a.distance_to(b) < 3.0:
			continue
		_spawn_ghost(k, a, b, p)
		_ghost_last = k
		return true
	return false


# The guaranteed one: along the tree line, across the view from the porch, ~4 s after the thought.
func _spawn_tree_line_ghost(p: CharacterBody3D) -> void:
	var fwd := _cam_forward(p)
	var line_x := -19.5
	var z := 6.0
	if fwd.x < -0.2:
		z = p.global_position.z + fwd.z * ((line_x - p.global_position.x) / fwd.x)
	z = clampf(z, HouseOutdoors.YARD_Z.x + 4.0, HouseOutdoors.YARD_Z.y - 4.0)
	var dir := Vector3(0, 0, 1.0 if randf() < 0.5 else -1.0)
	_spawn_ghost(0, Vector3(line_x, 0, z) - dir * 5.0, Vector3(line_x, 0, z) + dir * 5.0, p)


func _spawn_ghost(k: int, a: Vector3, b: Vector3, p: CharacterBody3D) -> void:
	var spec: Dictionary = GHOST_KINDS[k]
	var g := DoorLunger.build(self, a, TEX + String(spec["tex"]), float(spec["height"]))
	g.name = "ForestGhost"
	if spec.has("glow"):
		g.set_glow(float(spec["glow"]))
	g.appear(0.25)
	# The cutouts all run to the RIGHT; a billboard's +X is the camera's right, so a figure
	# crossing to the left is mirrored with a negative U scale (the texture repeats).
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	var mat := g.get("_mat") as StandardMaterial3D
	if cam and mat and (b - a).dot(cam.global_basis.x) < 0.0:
		mat.uv1_scale = Vector3(-1, 1, 1)
	g.flee_to(b, float(spec["speed"]), 2.0)
	var voices: Array[AudioStreamPlayer3D] = []
	for v in [[String(spec["sound"]), 0.0, 7.0, float(spec["height"]) * 0.7],
			["forest_run_leaves", -6.0, 4.0, 0.2]]:
		var s := GameState.load_audio(String(v[0]))
		if s == null:
			continue
		var ap := AudioStreamPlayer3D.new()
		ap.stream = s
		ap.volume_db = float(v[1])
		ap.unit_size = float(v[2])
		ap.max_db = 4.0
		ap.max_distance = 45.0
		ap.position = Vector3(0, float(v[3]), 0)
		g.add_child(ap)
		ap.play()
		voices.append(ap)
	# The figure frees itself at the end of its run; its scream is let finish where it was.
	g.gone.connect(func() -> void:
		for ap in voices:
			if is_instance_valid(ap) and ap.playing:
				ap.reparent(self)
				ap.finished.connect(ap.queue_free)
	)
	_ghosts_spawned += 1
	_log("FOREST ghost %s  %s -> %s  (player at %s, d=%.1f m)" % [spec["kind"],
		a.snappedf(0.1), b.snappedf(0.1), p.global_position.snappedf(0.1),
		HouseOutdoors.forest_depth(p.global_position)])


func _in_yard_margin(c: Vector3, m: float) -> bool:
	return c.x <= HouseOutdoors.YARD_X.y - m and c.x >= HouseOutdoors.YARD_X.x + m \
		and c.z >= HouseOutdoors.YARD_Z.x + m and c.z <= HouseOutdoors.YARD_Z.y - m


func _clamp_yard(c: Vector3) -> Vector3:
	return Vector3(clampf(c.x, HouseOutdoors.YARD_X.x + 1.0, HouseOutdoors.YARD_X.y - 0.5), 0.0,
		clampf(c.z, HouseOutdoors.YARD_Z.x + 1.0, HouseOutdoors.YARD_Z.y - 1.0))


# ---------------------------------------------------------------- the witch
#
# Three one-shot glimpses, each a `Watcher` — zero panic, no collider, no rules — placed where
# the player can see her and NEVER moving toward them. A glimpse that cannot be placed yet stays
# PENDING (retried every WITCH_RETRY s, logged once); nothing is latched until a figure exists.

func _tick_witch(delta: float) -> void:
	var p := _player()
	if not p:
		return
	if get_tree().paused or NoteUI.is_open \
			or (p.has_method("is_input_frozen") and p.is_input_frozen()):
		return
	_tick_witch_glass(delta, p)
	_witch_retry -= delta
	if _witch_retry > 0.0:
		return
	_witch_retry = WITCH_RETRY
	if is_instance_valid(_witch_node):
		# One at a time — but she FOLLOWS you: a later glimpse that is due takes her from wherever
		# she was last left standing, provided nobody is looking at her there (a Watcher only
		# leaves on its own by lifetime, approach or a look-back roll, and glimpse 2 is left
		# behind you in the Hallway while you carry the fruit out to the porch).
		var due := (_witch_2_wait >= 0.0 and not _witch_fired.has(2)) \
			or (_witch_3_pending and not _witch_fired.has(3))
		if due and _witch_node.name != "Witch1" and not _witch_node.is_visible_to_player():
			_witch_node.queue_free()
			_witch_node = null
		return
	# 1. The note read, the glass still in: she is in the yard beyond it, seen from the room.
	if not _witch_fired.has(1) and _witch_note_read and is_instance_valid(_window) \
			and not _window.is_broken():
		_try_witch_1(p)
	# 2. The fruit taken: at the far end of the Hallway, behind you.
	if _witch_2_wait >= 0.0 and not _witch_fired.has(2):
		_witch_2_wait += WITCH_RETRY
		if _witch_2_wait > WITCH_2_PATIENCE:
			_witch_2_wait = -1.0
			_log("WITCH glimpse 2 ABANDONED — no spot behind the player in %.0f s" % WITCH_2_PATIENCE)
		else:
			_try_witch_2(p)
	# 3. The fruit cut: she watches from the tree line.
	if _witch_3_pending and not _witch_fired.has(3) and not is_instance_valid(_witch_node):
		_try_witch_3(p)


func _try_witch_1(p: CharacterBody3D) -> void:
	if not _in_room(p.global_position, "LivingRoom"):
		return
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return
	var eye := cam.global_position
	var to_win := _window_pos - eye
	to_win.y = 0.0
	# Not when the face is about to come through the glass anyway.
	if to_win.length() < FOREST_SCARE_DIST + 1.0 or not _facing(p, _window_pos, 0.8):
		return
	var dir := to_win.normalized()
	if dir.x > -0.2:
		return
	for x in WITCH_1_SPOTS_X:
		var t: float = (float(x) - eye.x) / dir.x
		var cand := Vector3(float(x), 0.0, eye.z + dir.z * t)
		if not _in_yard_margin(cand, 1.5):
			continue
		if not _clear_through_glass(p, cand):
			continue
		# ⚠️ `require_los` FALSE, and only here, with the argument watcher.gd demands: Watcher's
		# own LOS ray would stop on the PANE (a layer-1 collider — it has to be, it blocks the
		# player) and refuse every spot. `_clear_through_glass()` is that same ray with only the
		# pane excluded, so it still catches "inside a wall/trunk" exactly as the LOS probe would.
		var w := Watcher.spawn(self, cand, WITCH_TEX, 4.0, false, WITCH_HEIGHT)
		if w:
			_witch_seen_glass = false
			_witch_unseen_t = 0.0
			_witch_placed(1, w, p)
			return
	_witch_postponed(1)


func _try_witch_2(p: CharacterBody3D) -> void:
	var fwd := _cam_forward(p)
	for c in WITCH_2_SPOTS:
		var to: Vector3 = c - p.global_position
		to.y = 0.0
		if to.length() < 5.0 or fwd.dot(to.normalized()) > 0.2:
			continue                      # too close, or not BEHIND the player
		var w := Watcher.spawn(self, c, WITCH_TEX, 5.0, true, WITCH_HEIGHT)
		if w:
			_witch_2_wait = -1.0
			_witch_placed(2, w, p)
			return
	_witch_postponed(2)


func _try_witch_3(p: CharacterBody3D) -> void:
	if not (HouseOutdoors.on_deck(p.global_position) or HouseOutdoors.forest_depth(p.global_position) > 0.0):
		return
	var fwd := _cam_forward(p)
	# In view but off-centre first — seen from the corner of the eye — then anywhere in view.
	var ranked: Array = []
	for c in WITCH_3_SPOTS:
		var to: Vector3 = c - p.global_position
		to.y = 0.0
		if to.length() < 4.0:
			continue
		var dot := fwd.dot(to.normalized())
		if dot < 0.35:
			continue
		ranked.append([0 if (dot >= 0.55 and dot < 0.93) else 1, c])
	ranked.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for r in ranked:
		var w := Watcher.spawn(self, r[1], WITCH_TEX, 6.0, true, WITCH_HEIGHT)
		if w:
			_witch_3_pending = false
			_witch_placed(3, w, p)
			return
	_witch_postponed(3)


# Glimpse 1 is seen THROUGH the pane, which `Watcher._is_seen()` cannot see past (its ray stops on
# the pane), so its look-away rule never runs. This is that rule for her: once she has been seen,
# half a second out of view and she is gone.
func _tick_witch_glass(delta: float, p: CharacterBody3D) -> void:
	if not is_instance_valid(_witch_node) or _witch_node.name != "Witch1":
		return
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	var at := _witch_node.global_position + Vector3(0, WITCH_HEIGHT / 2.0, 0)
	var seen := cam != null and _facing(p, at, 0.55) and _clear_through_glass(p, _witch_node.global_position)
	if seen:
		_witch_seen_glass = true
		_witch_unseen_t = 0.0
	elif _witch_seen_glass:
		_witch_unseen_t += delta
		if _witch_unseen_t > 0.5:
			_witch_node.queue_free()
			_witch_node = null
			_log("WITCH glimpse 1 gone (looked away)")


func _clear_through_glass(p: CharacterBody3D, cand: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 1.2, 0),
		cand + Vector3(0, 1.2, 0))
	q.collision_mask = 1
	var skip: Array[RID] = [p.get_rid()]
	if is_instance_valid(_window) and _window.pane_body():
		skip.append(_window.pane_body().get_rid())
	q.exclude = skip
	return space.intersect_ray(q).is_empty()


func _witch_placed(n: int, w: Watcher, p: CharacterBody3D) -> void:
	_witch_fired.append(n)
	_witch_node = w
	w.name = "Witch%d" % n
	_log("WITCH glimpse %d at %s  (player at %s)" % [n, w.global_position.snappedf(0.1),
		p.global_position.snappedf(0.1)])


func _witch_postponed(n: int) -> void:
	if _witch_logged.has(n):
		return
	_witch_logged[n] = true
	_log("WITCH glimpse %d postponed — no placement yet, retrying" % n)


func _in_room(pos: Vector3, room_name: String) -> bool:
	for r in ROOMS:
		if r["name"] != room_name:
			continue
		var c: Vector2 = r["pos"]
		var h: Vector2 = r["size"] * 0.5
		return absf(pos.x - c.x) <= h.x and absf(pos.z - c.y) <= h.y and pos.y > -0.5
	return false


# ---------------------------------------------------------------- the night outside, heard

func _tick_outdoor_audio(delta: float) -> void:
	if _forest_beds.is_empty():
		return
	var p := _player()
	if not p:
		return
	var outside := HouseOutdoors.on_deck(p.global_position) \
		or HouseOutdoors.forest_depth(p.global_position) > 0.0
	var open := is_instance_valid(_window) and _window.is_broken()
	var offset := 0.0 if outside else (-8.0 if open else -18.0)
	for b in _forest_beds:
		var a: AudioStreamPlayer3D = b[0]
		a.volume_db = move_toward(a.volume_db, float(b[1]) + offset, 12.0 * delta)


func _log(msg: String) -> void:
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg:
		dbg.note(msg)


# ---------------------------------------------------------------- cursed props

func _spawn_cursed_props() -> void:
	# ⚠️ THE FALLING PAINTING MOVED BEDROOM -> CHILD'S ROOM (2026-08-16, playtest capture B4:
	# *"Usually the player would not return to this room to see the painting fall — shall we
	# switch child painting and this one places, so that the falling painting will be next to
	# the lock and the player is guaranteed to enter it"*). The two panels swapped places:
	# `painting_house.png` is here now, and the child's crayon drawing took over the Bedroom's
	# south wall (see _spawn_room_props).
	#
	# It is the right trade. THE GUEST's stage 1 fires on the map being solved, and after that
	# the Bedroom is off every remaining route — map -> key -> Kitchen -> cellar -> the exit
	# lock never re-enters it — so the level's most expensive scripted beat was being staged in
	# a room the player had already finished with. The ChildRoom holds the exit lock and cannot
	# be skipped.
	#
	# ⚠️ NORTH WALL, BESIDE THE EXIT DOOR (2026-08-16, second replay: *"Let's make this painting
	# be next to the wall … I mean next to the door — let it be next to the door so once you
	# approach the lock it falls"*). It hung on the ChildRoom's east wall for one session: the
	# right ROOM but the wrong wall, so approaching the lock did not stage the beat, it merely
	# happened somewhere in the same room.
	#
	# The exit door is at x = -0.7 on the north wall and is 1.25 wide (x -1.33..-0.08), so
	# PAINTING_X puts the 0.8 m panel at x 0.45..1.25 — the far side of the same wall, half a
	# metre clear of the leaf, in the frame you are looking at while you work the lock.
	#
	# ⚠️ It is NOT on a doorway. `wall_point()` returns the wall CENTRE, and a collider there
	# seals the room — but ChildRoom's only RoomBuilder doorway is SOUTH at (0, 14); the exit
	# door in the north wall is a prop, and the offset keeps the panel clear of it anyway.
	# ⚠️ And where it LANDS matters as much as where it hangs: `_drop_painting()` slides it
	# 0.55 m along its own forward, i.e. to (PAINTING_X, 0.06, 18.29) — inside the room, clear
	# of the small bed at (1.5, 16.5) and clear of the walking line to the lock at x = -0.7.
	# The tarnished mirror stays in the living room, untouched.
	_bedroom_painting = _make_cursed_body(
		_builder.wall_point("ChildRoom", Vector2(0, 1), 1.5, 0.16) + Vector3(PAINTING_X, 0, 0),
		Vector2(0.8, 1.0), PI, 0.8, Color(0.1, 0.08, 0.07), TEX + "painting_house.png")
	_bedroom_painting.name = "FallingPainting"
	_make_cursed_body(_builder.wall_point("LivingRoom", Vector2(0, -1), 1.5, 0.08),
		Vector2(0.7, 1.1), 0.0, 1.2, Color(0.05, 0.07, 0.08), "")


# Returns the StaticBody3D so a caller can keep a handle on it — THE GUEST needs one for
# the bedroom painting. Every existing call site ignores the return, so this is additive.
#
# ⚠️ ScaryObject is a plain Node with no transform, which BREAKS the Node3D chain, so the
# body's local transform IS its global transform. That is why the world position lives on
# the body (Issue 10) and why MovedProp's global_position arithmetic works on it unchanged.
func _make_cursed_body(pos: Vector3, size: Vector2, y_rot: float, intensity: float,
		albedo: Color, tex_path: String) -> StaticBody3D:
	var scary := ScaryObject.new()
	scary.scare_intensity = intensity
	add_child(scary)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = y_rot
	scary.add_child(body)
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	else:
		mat.albedo_color = albedo
		mat.metallic = 0.8
		mat.roughness = 0.15
	quad.set_surface_override_material(0, mat)
	body.add_child(quad)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, 0.1)
	col.shape = shape
	body.add_child(col)
	return body


# ---------------------------------------------------------------- new scares

func _spawn_tv() -> void:
	# A dead TV in the living room whose static resolves into a face — gaze panic.
	var pos: Vector3 = _builder.room_center("LivingRoom") + Vector3(2.6, 0.9, -2.4)
	var scary := ScaryObject.new()
	scary.scare_intensity = 1.0
	add_child(scary)
	var body := StaticBody3D.new()
	body.position = pos
	scary.add_child(body)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.8, 0.55, 0.08)
	screen.mesh = sm
	var mat := StandardMaterial3D.new()
	# The face art is a .jpg on disk; resolve .png then .jpg (it was looking only for
	# .png, so the TV silently fell back to a grey screen).
	var tv_tex := Apparition._resolve_tex(TEX + "tv_static_face")
	if tv_tex != "":
		mat.albedo_texture = load(tv_tex)
		mat.emission_enabled = true
		mat.emission_texture = load(tv_tex)
		mat.emission_energy_multiplier = EM_TV
	else:
		mat.albedo_color = Color(0.05, 0.06, 0.06)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.15, 0.12)
		mat.emission_energy_multiplier = EM_TV
	screen.set_surface_override_material(0, mat)
	body.add_child(screen)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(0.8, 0.55, 0.1)
	col.shape = cs
	body.add_child(col)
	# Static hiss loop.
	_loop_audio("tv_static", pos, -14.0)

	# KONTUR HINT 2/4 — the answer to KONTUR's Gate 2 (which bottle). Every so often
	# the static resolves into a broadcast test card for a few seconds, then loses it
	# again: you have to be in the room, looking, at the right moment. Rendered as
	# text over the screen so it needs no new texture. See kontur.gd.
	# ⚠️ DELIBERATELY LEFT UNSHADED (2026-09-03). `Label3D` is self-lit by default, and the
	# 2026-09-03 darkness pass made every OTHER Label3D in the game `shaded = true` — painted
	# stencils and printed cards have to be found by the torch like anything else (`kontur.gd`
	# carries that note). This one is the exception and the reason is diegetic: it is text ON A
	# CRT, and a television is a light source. A shaded test card would be invisible in a black
	# house unless the player happened to be shining a torch at the screen, which is the one
	# place a glow belongs. It is also KONTUR Gate 2's only hint outside the Lab morgue.
	_tv_card = Label3D.new()
	_tv_card.name = "KonturTestCard"
	_tv_card.text = "O-41 RETARDS ON CONTACT\nWITH ACETIC ACID.\n\nHOUSEHOLD VINEGAR.\nNOTHING ELSE."
	_tv_card.font_size = 44
	_tv_card.pixel_size = 0.0016
	_tv_card.modulate = Color(0.75, 0.95, 0.8, 0.0)
	_tv_card.outline_size = 0
	_tv_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tv_card.position = pos + Vector3(0, 0, 0.05)   # proud of the +z screen face
	add_child(_tv_card)


# The Landing was 24 m² of nothing — and it is the hub EVERY route crosses (Bathroom map ->
# Kitchen -> cellar -> ChildRoom lock all pass through it), so it was the highest-traffic
# empty space in the game.
#
# A LivingMirror rather than another gaze panel. The House already has five cursed panels
# and the living-room mirror at intensity 1.2 kills from full in ~2 s of staring, so a sixth
# would just be more of the same tax. LivingMirror's figure appears only when you are NOT
# looking head-on (LOOK_DOT 0.8) — which is exactly how you cross a hub — and it costs
# nothing at all unless the player chooses to stand and stare.
#
# ⚠️ NOT placed with wall_point(). Every one of the Landing's four walls has a doorway at
# its centre (z=11, z=14, x=-4, x=+4), and wall_point() returns the wall CENTRE — so the
# usual idiom would have sealed an exit, which is the Session-11 bug that walled off the
# third breaker room. This is hand-placed OFF-centre on the south wall, east of the
# Hallway doorway (which spans x -0.8..0.8).
func _spawn_landing_mirror() -> void:
	# South wall plane is z=11; the inner face is T/2 (0.1) in from that, and the figure
	# hangs 0.05 behind the glass, so 0.22 of inset is the documented minimum.
	var mirror := LivingMirror.new()
	mirror.emission_scale = EM_MIRROR_SCALE
	mirror.name = "LandingMirror"
	mirror.position = Vector3(2.5, 1.5, 11.22)
	mirror.rotation.y = PI      # LivingMirror faces local -Z; PI turns it to face +z
	add_child(mirror)


# The cellar was 49 m² with four objects in it — atmospherically the heaviest room in the
# level and physically almost bare.
#
# ⚠️ NO NEW PANIC HERE, deliberately. This leg already carries a DreadZone at net-zero
# decay, a DarkZone, a beartrap worth 55 and an 18-panic HOLD apparition, and the level has
# no CalmZone anywhere — so it is the one stretch with no recovery mechanism at all. What it
# needed was things to search, not more cost.
func _spawn_cellar_props() -> void:
	var cx: float = CELLAR_CENTER.x
	var cz: float = CELLAR_CENTER.y
	var floor_y: float = CELLAR_Y

	# ⚠️ NO FURNITURE BOXES DOWN HERE, and do not add any back without art for them.
	#
	# This pass originally put shelving, a dead boiler and two stacked crates in the cellar,
	# reasoning that 49 m² holding four objects needed "things to search". They were untextured
	# flat-shaded CSG boxes in a room lit by one 0.5-energy lamp, so in practice they were
	# invisible smudges — confirmed by tests/screenshot_level.gd, shot `05_cellar`. Playtest
	# 2026-07-29 called the level's boxes out generally and asked for most of them to go.
	#
	# The cellar's atmosphere was never carried by props: it is a DreadZone plus a DarkZone
	# plus a beartrap plus a HOLD apparition plus the third note, and adding silhouettes that
	# cannot be seen only made the room look unfinished under a torch.

	# The NIGHTMARE hint, spoken to the screen the moment the player reaches the bottom of the
	# ramp. A scrawl rather than a caption: this is the experiment's voice, the same register
	# as the intro's "IT WAS ONLY A DREAM." and the KONTUR banishment line, and it matches the
	# blood-red text on the shelf so the two read as one thing.
	# H4 (2026-09-16, the user: "you need to be stuck in this level after you read the note"):
	# the blackout no longer fires here at the ramp's foot — it fires when the cellar NOTE is
	# closed (`_arm_child_on_note_close`), deep in the room, with the player pinned there.
	_spawn_event(Vector3(cx, floor_y + 0.9, cz + 2.9), Vector3(3.0, 2.4, 1.6),
		func() -> void:
			ScreenText.scrawl(get_tree(), CELLAR_HINT, CELLAR_CAPTION_TIME))

	# ⚠️ NO corner Watcher down here any more, and do not add one back.
	#
	# The atmosphere pass put one in the deepest corner. Playtest 2026-07-29, on the run where
	# the cellar sequence finally worked: *"there is both the shadow and the child jumpscare.
	# Let's leave only the child jumpscare."* Two figures in one 7x7 m room split the moment
	# in half — the corner one is a mood piece and the child is an event, and the mood piece
	# was arriving first and spending the surprise.


func _spawn_bathroom_mirror() -> void:
	# North wall — the west wall (Vector2(-1,0)) is the bathroom's only doorway, and the
	# mirror's collider there blocks the entrance.
	# ⚠️ 0.22 — see the note on the Lab's observation mirror. The figure hangs 0.05
	# behind the glass, so the glass needs clearance for the figure as well or the
	# figure ends up inside the wall and is never visible.
	var pos: Vector3 = _builder.wall_point("Bathroom", Vector2(0, 1), 1.5, 0.22)
	var mirror := LivingMirror.new()
	mirror.emission_scale = EM_MIRROR_SCALE
	mirror.position = pos
	mirror.rotation.y = 0.0   # LivingMirror faces local -Z → into the room (-z)
	add_child(mirror)


# The Kitchen was 42 m² — the joint-largest room in the level — holding ONE counter.
#
# ⚠️ Two doorways constrain everything here and both have a test watching them:
#   * the cellar ramp at (5, z=3), width 1.6, i.e. x 4.2..5.8. check_cellar_key.gd
#     raycasts (5, 1.2, 3 +/- 1.2), so nothing may stand in z 1.8..4.2 near x=5.
#   * Hallway <-> Kitchen at (x=1.5, z=6), width 1.4, i.e. z 5.3..6.7.
# Everything below is placed clear of both, and check_doorways.gd re-asserts it.
func _furnish_kitchen(kc: Vector3) -> void:
	# ⚠️ No sink unit. There was a 1.1 x 0.9 x 0.7 pale box here standing in for one, and it
	# read as exactly that — a featureless slab, made worse by sitting next to a fridge that
	# now has a door, a handle and an interior. Cut 2026-07-29 with the cellar boxes.

	# The drawer, set into the counter's south face — the side you approach from. It carries
	# the KONTUR Gate 1 hint; see kitchen_drawer.gd for why this level gets a second one.
	var drawer := KitchenDrawer.new()
	drawer.name = "KitchenDrawer"
	# Counter front face is at kc.z + 2.4 - 0.35; sit the panel just proud of it.
	drawer.position = Vector3(kc.x - 1.0, 0.58, kc.z + 2.4 - 0.36)
	add_child(drawer)

	# ⚠️ A table and two chairs built from REAL PARTS, not single boxes.
	#
	# The first version used `_make_prop` for all three, which is the project's flat-tinted
	# BACKGROUND DRESSING helper — one CSGBox, one colour. Playtest 2026-07-28 photographed
	# the result and called it what it was: *"these boxes … are completely useless."* A
	# 0.44 m cube is not a chair. Issue 35 already says the silhouette carries a prop here and
	# art does not; `intro_room.gd:_build_wheelchair()` and `kontur_mailbox.gd` are the
	# precedent — a dozen cheap primitives that add up to a recognisable object.
	_build_table(Vector3(kc.x - 0.4, 0.0, kc.z + 0.4))
	_build_chair(Vector3(kc.x - 1.5, 0.0, kc.z + 0.4), PI / 2.0)
	_build_chair(Vector3(kc.x + 0.7, 0.0, kc.z + 0.4), -PI / 2.0)

	# The fridge, against the east wall. x=7.9 leaves its face at 8.28, clear of the wall's
	# inner face at 8.4 — the >= 2 cm rule check_wall_overlap.gd asserts.
	var fridge := HouseFridge.new()
	fridge.name = "Fridge"
	fridge.position = Vector3(7.9, 0.0, kc.z + 0.9)
	fridge.rotation.y = -PI / 2.0     # its door faces -x, into the room
	fridge.opened.connect(_on_fridge_opened)
	fridge.chain_tried.connect(_on_fridge_chain_tried)   # H2
	add_child(fridge)


# A table: top plus four legs. `house_wood_stairs.png` is the House's own timber texture and
# is already in the level, so the top reads as wood without a new asset.
func _build_table(base: Vector3) -> void:
	var top := _make_prop(base + Vector3(0, 0.74, 0), Vector3(1.5, 0.07, 0.95),
		Color(0.42, 0.31, 0.21), 0.0, TEX + "house_wood_stairs.png")
	top.name = "KitchenTable"
	var leg := Color(0.24, 0.17, 0.12)
	for dx in [-0.65, 0.65]:
		for dz in [-0.40, 0.40]:
			_make_prop(base + Vector3(dx, 0.37, dz), Vector3(0.07, 0.74, 0.07), leg)


# A bed: frame, four legs, mattress, pillow, and a headboard.
#
# ⚠️ Both beds used to be a SINGLE flat box — 2.2 x 0.5 x 1.5, one flat colour. Playtest
# 2026-07-29 photographed the child's one and asked "still do not understand what this box is
# for?", which is the correct reaction to a slab on a floor. My earlier reasoning that a
# bed-shaped box in a bedroom reads as a bed was simply wrong: what makes a bed legible is the
# headboard and the mattress sitting proud of a frame, not the footprint. Same lesson as the
# kitchen chairs, and the same fix — a handful of cheap primitives (Issue 35).
func _build_bed(base: Vector3, size: Vector2, y_rot: float = 0.0) -> void:
	var frame_col := Color(0.26, 0.19, 0.14)
	var sheet_col := Color(0.52, 0.49, 0.44)
	var w: float = size.y
	var l: float = size.x
	# Every part is placed in bed-space and then rotated as a group, so `y_rot` turns the
	# whole thing — headboard, pillow and all — rather than just spinning the slabs in place.
	var at := func(off: Vector3) -> Vector3:
		return base + off.rotated(Vector3.UP, y_rot)

	var frame := _make_prop(at.call(Vector3(0, 0.22, 0)), Vector3(l, 0.16, w),
		frame_col, y_rot)
	frame.name = "BedFrame"
	for dx in [-l / 2.0 + 0.09, l / 2.0 - 0.09]:
		for dz in [-w / 2.0 + 0.09, w / 2.0 - 0.09]:
			_make_prop(at.call(Vector3(dx, 0.07, dz)), Vector3(0.09, 0.14, 0.09),
				frame_col, y_rot)
	# The mattress sits PROUD of the frame — that overhang is most of the read.
	_make_prop(at.call(Vector3(0, 0.36, 0)), Vector3(l - 0.06, 0.14, w - 0.04),
		sheet_col, y_rot)
	# Pillow at the head end.
	_make_prop(at.call(Vector3(-l / 2.0 + 0.26, 0.46, 0)),
		Vector3(0.42, 0.09, w * 0.62), Color(0.60, 0.58, 0.53), y_rot)
	# Headboard — the single most identifying part of the silhouette.
	_make_prop(at.call(Vector3(-l / 2.0 - 0.03, 0.44, 0)), Vector3(0.07, 0.72, w),
		frame_col, y_rot)


# A chair: seat, four legs, and a back — the back is what makes the silhouette read as a
# chair rather than as a crate, so it is the one part that must never be dropped.
func _build_chair(base: Vector3, y_rot: float) -> void:
	var wood := Color(0.30, 0.22, 0.16)
	var seat := _make_prop(base + Vector3(0, 0.45, 0), Vector3(0.44, 0.06, 0.44), wood, y_rot)
	seat.name = "KitchenChair"
	var back_offset := Vector3(sin(y_rot), 0.0, cos(y_rot)) * -0.19
	_make_prop(base + Vector3(0, 0.74, 0) + back_offset,
		Vector3(0.44, 0.52, 0.05), wood, y_rot)
	for dx in [-0.17, 0.17]:
		for dz in [-0.17, 0.17]:
			var off := Vector3(dx, 0.0, dz).rotated(Vector3.UP, y_rot)
			_make_prop(base + Vector3(0, 0.22, 0) + off, Vector3(0.05, 0.45, 0.05), wood)


# The level owns the consequence, not the prop. A voluntary, optional, one-shot 10 —
# see the header of house_fridge.gd for why this is the one place panic is spent.
func _on_fridge_opened() -> void:
	_fridge_opened = true
	var p := _player()
	if not p:
		return
	p.jolt_camera(0.08, 0.45)
	p.add_panic(FRIDGE_PANIC)


# The child's music box, as a real object.
#
# ⚠️ It used to be a bare looping AudioStreamPlayer3D at the ChildRoom's centre with NO
# physical object at all — the level's most distinctive sound had no source you could ever
# find. Giving it a body matters for its own sake, and it is also what makes The Guest's
# last beat possible: the loop is a CHILD of the body, so when MovedProp carries the body
# into the Hallway the sound goes with it, and the level's soundtrack becomes retroactively
# suspicious. See _arm_guest().
func _spawn_music_box() -> void:
	var cc: Vector3 = _builder.room_center("ChildRoom")
	# On the floor by the west wall, clear of the small bed at x+1.5 and of both doorways
	# (ChildRoom is entered at (0, z=14); the exit lock is on its north wall).
	var pos := Vector3(cc.x - 1.6, 0.11, cc.z - 1.2)
	_music_box = _make_prop(pos, Vector3(0.30, 0.22, 0.24), Color(0.42, 0.26, 0.14),
		0.0, TEX + "house_music_box.png")
	_music_box.name = "MusicBox"

	# ⚠️ It has to READ as a music box, not as a cube. Playtest 2026-07-29 pointed at it and
	# asked what the box was for — which matters more here than anywhere else in the level,
	# because this object IS The Guest's payoff: finding it in the Hallway only lands if the
	# player recognises it as the thing that was playing in the child's room.
	# So: a lid standing half-open, brass feet, and a crank on the side.
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.62, 0.50, 0.22)
	brass.metallic = 0.7
	brass.roughness = 0.35

	var lid := CSGBox3D.new()
	lid.name = "MusicBoxLid"
	lid.size = Vector3(0.32, 0.03, 0.26)
	# Hinged at the back and tipped open, so the silhouette has a wedge in it.
	lid.position = Vector3(0, 0.19, -0.09)
	lid.rotation.x = deg_to_rad(-52.0)
	lid.material = brass
	_music_box.add_child(lid)

	# Four small feet — they lift it off the floor, which is what stops it reading as a crate.
	for dx in [-0.12, 0.12]:
		for dz in [-0.09, 0.09]:
			var foot := CSGBox3D.new()
			foot.size = Vector3(0.03, 0.04, 0.03)
			foot.position = Vector3(dx, -0.13, dz)
			foot.material = brass
			_music_box.add_child(foot)

	# The crank, on a pivot so winding it actually turns. The stub lies along X (the cylinder
	# is rotated a quarter-turn about Z), so the handle sweeps the YZ plane when the pivot
	# spins about X — which is what `MusicBoxProp.interact()` tweens.
	var crank_pivot := Node3D.new()
	crank_pivot.name = "CrankPivot"
	crank_pivot.position = Vector3(0.18, 0.02, 0)
	_music_box.add_child(crank_pivot)
	var stub := CSGCylinder3D.new()
	stub.radius = 0.012
	stub.height = 0.07
	stub.rotation.z = PI / 2.0
	stub.material = brass
	crank_pivot.add_child(stub)
	var handle := CSGBox3D.new()
	handle.size = Vector3(0.012, 0.07, 0.012)
	handle.position = Vector3(0.035, 0.035, 0)
	handle.material = brass
	crank_pivot.add_child(handle)

	var audio: AudioStreamPlayer3D = null
	var s := GameState.load_audio("music_box")
	if s:
		audio = AudioStreamPlayer3D.new()
		audio.name = "MusicBoxAudio"
		audio.stream = s
		audio.volume_db = -13.0
		audio.unit_size = 6.0
		audio.max_db = 6.0
		audio.bus = AudioBuses.AMBIENCE
		audio.position = Vector3(0, 0.2, 0)
		_music_box.add_child(audio)      # a child, so it travels with the box
		audio.finished.connect(audio.play)
		audio.play()

	# You can wind it (playtest 2026-07-29: "it would be cool if you can play the music using
	# this box"). The interactable body is a separate child rather than the CSG box itself,
	# because `_make_prop` returns a plain CSGBox3D with no script and the interact raycast
	# needs something that answers `interact()`.
	var box := MusicBoxProp.new()
	box.name = "MusicBoxCrank"
	box.position = Vector3.ZERO
	_music_box.add_child(box)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.42, 0.34, 0.34)
	col.shape = shape
	col.position = Vector3(0, 0.05, 0)
	box.add_child(col)

	# The WIND payoff is a second, separate stream — the recording the user supplied
	# (2026-08-16). `audio` above stays the room's quiet bed and is NOT what a wind plays; see
	# the ⚠️ at the top of `music_box.gd`. Also a child of `_music_box`, so THE GUEST's final
	# stage still carries the sound with the box when the house moves it.
	var tune_audio: AudioStreamPlayer3D = null
	var tune := GameState.load_audio("music_box_tune")
	if tune:
		tune_audio = AudioStreamPlayer3D.new()
		tune_audio.name = "MusicBoxTuneAudio"
		tune_audio.stream = tune
		tune_audio.volume_db = -40.0     # silent until wound
		tune_audio.unit_size = 6.0
		tune_audio.max_db = 6.0
		tune_audio.bus = AudioBuses.AMBIENCE
		tune_audio.position = Vector3(0, 0.2, 0)
		_music_box.add_child(tune_audio)
		tune_audio.finished.connect(tune_audio.play)   # every .wav/.ogg here is loop_mode=0

	box.attach_parts(audio, crank_pivot, tune_audio)


# Solid furniture so each room reads as a place. No panic — these are just props.
# A solid CSG prop. `tex_path` is optional and guarded, so a prop keeps its
# flat-colour look until art for it exists — same contract as level_1.gd.
func _make_prop(pos: Vector3, size: Vector3, color: Color, y_rot := 0.0,
		tex_path := "") -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.rotation.y = y_rot
	b.use_collision = true
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if tex_path != "" and ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
		m.albedo_color = Color(1, 1, 1)
	b.material = m
	add_child(b)
	return b


func _spawn_room_props() -> void:
	# Kitchen: a counter along the NORTH wall (z-2.4 would sit across the cellar-ramp
	# doorway at z=3 and re-block the descent).
	var kc: Vector3 = _builder.room_center("Kitchen")
	_make_prop(Vector3(kc.x, 0.45, kc.z + 2.4), Vector3(4.0, 0.9, 0.7), Color(0.35, 0.3, 0.24))
	_furnish_kitchen(kc)
	# Bathroom: a bathtub.
	var bc: Vector3 = _builder.room_center("Bathroom")
	_make_prop(Vector3(bc.x + 1.4, 0.3, bc.z), Vector3(0.9, 0.6, 2.2), Color(0.7, 0.72, 0.72))
	_spawn_bathroom_map(bc)
	# Bedroom: a bed, plus the child's crayon drawing — which swapped places with the falling
	# painting on 2026-08-16 (capture B4; see _spawn_cursed_props for why). SOUTH wall: the
	# east wall is the Bedroom's only doorway, the note with digit 2 is on the north, the bed
	# is on the west.
	var bd: Vector3 = _builder.room_center("Bedroom")
	_build_bed(Vector3(bd.x - 1.6, 0.0, bd.z), Vector2(2.0, 1.4))
	# ⭐ 2026-09-24: nothing under the bed any more. The bolt cutters are inside the watermelon
	# behind the falling painting and come out on the porch's guillotine (the Porch pass).
	var drawing := TEX + "child_drawing.png"
	if ResourceLoader.exists(drawing):
		_make_cursed_body(_builder.wall_point("Bedroom", Vector2(0, -1), 1.5, 0.06),
			Vector2(0.7, 0.7), 0.0, 0.6, Color(0.6, 0.55, 0.5), drawing)
	# Child's room: a small bed. The falling painting is on its NORTH wall, beside the exit door.
	var cc: Vector3 = _builder.room_center("ChildRoom")
	# Turned 180° on request (playtest 2026-07-29) — the headboard now faces the other way.
	_build_bed(Vector3(cc.x + 1.5, 0.0, cc.z), Vector2(1.7, 0.95), PI)


# The Bathroom map-and-chase minigame (new feature, replaces the Landing 2-drawer
# search — briefly lived on the Kitchen counter first, moved here per playtest:
# "this room has nothing except the [trap] note, put the map there"). The trap
# note ("it got in it got in...") is on the east wall; the bathtub occupies
# roughly x:7.45-8.35, z:11.4-13.6. One small stand sits clear of both and of the
# west-wall doorway's swing (x=4, z:11.8-13.2). Playtest: "once I pass the maze,
# the map should disappear and the key spawn instead of it" — HouseMap now
# queue_frees itself on a win (house_map_prop.gd), so the key reuses this exact
# stand/position rather than a separate one.
func _spawn_bathroom_map(bc: Vector3) -> void:
	var map_pos := Vector3(bc.x - 1.0, 0.65, bc.z - 1.5)
	_build_stool(Vector3(map_pos.x, 0.0, map_pos.z))
	var map := HouseMap.new()
	map.position = map_pos
	map.name = "HouseMap"
	map.won.connect(func() -> void:
		_map_solved = true
		_build_cellar_key(map_pos)
		_advance_guest(1)
	)
	add_child(map)


# The stand the map — and then the cellar key — sits on.
#
# ⚠️ BUILT FROM PARTS (2026-08-16, playtest capture A2). It was one call to `_make_prop`, i.e.
# a single flat-tinted 0.5 x 0.6 x 0.4 CSGBox: a featureless grey cube, and the frame the
# *"Collect the key."* payoff is delivered in. Issue 35 in furniture form, and the same note
# the kitchen chairs, the table and the music box each earned in turn — the SILHOUETTE carries
# a prop here, art does not. A stool is legible because it has legs and a rail under a seat.
#
# ⚠️ The seat's TOP SURFACE must land at 0.60, exactly where the old box's did, because the
# map and the key that replaces it are placed at y=0.65 and `check_wall_overlap.gd` fails any
# QuadMesh within MIN_CLEAR (2 cm) of a CSG box. 0.60 keeps the same 5 cm the shipped prop had.
# STOOL_TOP_Y is the seat's CENTRE, so top = STOOL_TOP_Y + STOOL_SEAT_T / 2.
const STOOL_TOP_Y := 0.57
const STOOL_SEAT_T := 0.06
const STOOL_SEAT := Vector2(0.46, 0.38)

func _build_stool(base: Vector3) -> void:
	var wood := Color(0.32, 0.24, 0.16)
	var dark := Color(0.24, 0.18, 0.12)
	_make_prop(base + Vector3(0, STOOL_TOP_Y, 0),
		Vector3(STOOL_SEAT.x, STOOL_SEAT_T, STOOL_SEAT.y), wood)
	# A lip under the seat, so the edge reads as a board rather than as the top of a box.
	_make_prop(base + Vector3(0, STOOL_TOP_Y - 0.05, 0),
		Vector3(STOOL_SEAT.x - 0.07, 0.04, STOOL_SEAT.y - 0.06), dark)
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			_make_prop(base + Vector3(dx * (STOOL_SEAT.x / 2.0 - 0.05),
					(STOOL_TOP_Y - STOOL_SEAT_T / 2.0) / 2.0,
					dz * (STOOL_SEAT.y / 2.0 - 0.05)),
				Vector3(0.05, STOOL_TOP_Y - STOOL_SEAT_T / 2.0, 0.05), dark)
	# Cross rails near the floor — the detail that stops four legs reading as one block.
	_make_prop(base + Vector3(0, 0.16, -(STOOL_SEAT.y / 2.0 - 0.05)),
		Vector3(STOOL_SEAT.x - 0.10, 0.035, 0.035), dark)
	_make_prop(base + Vector3(0, 0.16, STOOL_SEAT.y / 2.0 - 0.05),
		Vector3(STOOL_SEAT.x - 0.10, 0.035, 0.035), dark)


func _spawn_cellar_contents() -> void:
	var c := CELLAR_CENTER
	# ⭐ DREAD ONLY — the cellar's `DarkZone` IS GONE (2026-09-03, D4), and this was the urgent one.
	#
	# ⚠️ THE MEASUREMENT. The two zones overlapped exactly, and `player.gd` adds dark-zone tax ON
	# TOP of dread pressure while the dark branch ALSO suppresses decay: **+5/s with no way down**.
	# In a house that is now black by default the torch is not optional down here, so the tax only
	# ever fired when the player had no say — and the cellar contains the one sequence that takes
	# the torch away on purpose (`_begin_cellar_blackout()` force-kills it for CHILD_APPEAR_DELAY
	# + CHILD_HOLD = 8.5 s) plus a beartrap on the entry line. That sequence survived only because
	# `set_smiler_active(true)` suspends the dark branch for its duration; nothing suspended it for
	# the searching, the note-reading or the beartrap escape either side of it.
	#
	# ⚠️ THE DREAD ZONE STAYS. It is the cellar's actual pressure signature (decay and pressure
	# cancel, so panic holds rather than draining) and it does not depend on the torch.
	# ⚠️ `check_house_guest.gd` asserts the whole cellar sequence costs ZERO panic; removing this
	# makes that more robust, not less.
	for maker in [func() -> Area3D: return DreadZone.new()]:
		var zone: Area3D = maker.call()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(CELLAR_SIZE.x, CELLAR_H, CELLAR_SIZE.y)
		col.shape = shape
		zone.add_child(col)
		zone.position = Vector3(c.x, CELLAR_Y + CELLAR_H / 2.0, c.y)
		add_child(zone)
	# Water drips ambience.
	_loop_audio("water_drip", Vector3(c.x, CELLAR_Y + 1.0, c.y), -10.0)
	# A beartrap waiting in the dark.
	#
	# ⚠️ DELIBERATE (2026-08-16). This trap sits 1.6 m past the cellar blackout trigger
	# (`_spawn_cellar_props`'s event box spans x 3.5..6.5, z -3.9..-2.3) on the only heading
	# into the room, inside an 8.5 s window in which `_begin_cellar_blackout()` kills every
	# lamp AND calls `force_flashlight_off()`. It fired in BOTH playtest sessions on
	# 2026-08-16 — `ESCAPE_INITIAL_PANIC` 15 at (6.30, -1.50, -4.90) and at
	# (6.20, -1.50, -4.30), each within ~1.2 m of it and within 3 s of the torch dying.
	#
	# The analysis pass proposed moving it off that line (backlog 02-house item A6). The user
	# was shown the measurement and chose to LEAVE IT WHERE IT IS. Do not re-file this as a
	# bug and do not "fix" it in a later session.
	#
	# What it does change: `_cellar_child_appear()`'s postponement guard is the only thing
	# standing between this trap and the user's original complaint ("will I always see that
	# doll"), because a QTE and the child's appearance will keep colliding. Read the ⚠️ there
	# before touching either.
	var trap := Beartrap.new()
	trap.position = Vector3(c.x + 1.5, CELLAR_Y, c.y + 0.5)
	add_child(trap)

	# The cellar gate. Blocks the ramp opening (1.7 x 3.0 fills it completely — no
	# transom leak) until the player UNLOCKS it themselves with the key; see
	# cellar_gate.gd and _on_cellar_gate_used() below.
	_cellar_gate = CellarGate.new()
	_cellar_gate.name = "CellarGate"
	_cellar_gate.position = Vector3(5.0, 1.5, 3.0)
	_cellar_gate.used.connect(_on_cellar_gate_used)
	add_child(_cellar_gate)

	_spawn_nightmare_hint(c)

	# The key itself is no longer a straight pickup — see _spawn_bathroom_map(), a 2D
	# map-and-chase minigame on a stand in the Bathroom. Winning it calls
	# _build_cellar_key() below directly; the Landing 2-drawer search from an earlier
	# pass has been removed (Landing reverts to being an empty pass-through — a
	# deliberate trade for this bigger quest). The map lived on the Kitchen counter
	# briefly in between; that is why some comments still said "Kitchen".


# NIGHTMARE HINT 2/3 — a candle stub on a cellar shelf with a scrawl over it
# (DUNGEON_NIGHTMARES.md §B2). It teaches the ONE number a player of THE NIGHTMARE
# needs and is never told in that level: a candle burns for sixty seconds.
#
# The cellar is the right place for it — it is already a DreadZone + DarkZone the
# player enters carrying a light they are watching the battery of, so a note about
# a light running out reads as atmosphere here and as instructions later. Same
# plant-it-early logic as the four KONTUR hints.
func _spawn_nightmare_hint(c: Vector2) -> void:
	var shelf := CSGBox3D.new()
	shelf.name = "CellarShelf"
	shelf.size = Vector3(0.9, 0.06, 0.3)
	shelf.position = Vector3(c.x - 2.6, CELLAR_Y + 1.15, c.y - 1.8)
	shelf.use_collision = true
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.15, 0.11, 0.07)
	wood.roughness = 0.9
	shelf.material = wood
	add_child(shelf)

	# A burned-down stub. Unlit, dark albedo, NO emission: this is a clue to find
	# with the flashlight, not a beacon (Issues 27/33 — a prop with real presence
	# does not also wear a findability glow).
	var stub := MeshInstance3D.new()
	stub.name = "CandleStub"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.028
	cm.bottom_radius = 0.032
	cm.height = 0.09
	stub.mesh = cm
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.52, 0.50, 0.44)
	wax.roughness = 0.9
	stub.set_surface_override_material(0, wax)
	stub.position = shelf.position + Vector3(0.0, 0.08, 0.0)
	add_child(stub)

	# ⚠️ REWRITTEN 2026-07-28 on playtest feedback: *"Why would I count these sixty seconds?
	# Does not make sense to me."* The old text ("SIXTY SECONDS. COUNT THEM.") is the
	# cross-level hint for THE NIGHTMARE, where a candle burns for sixty seconds — but it
	# gave the player nothing to act on in the House and nothing to attach it to, so it read
	# as noise rather than as foreshadowing. It now NAMES the level it is about, which is what
	# makes it a hint instead of a riddle, and it is also delivered as an on-screen line when
	# the player enters the cellar (see _spawn_cellar_caption) rather than depending on them
	# happening to point a torch at this shelf.
	# ⚠️ NO WALL SCRAWL HERE, and do not put one back.
	#
	# There used to be a `Label3D` over this shelf reading "SIXTY SECONDS. COUNT THEM.".
	# Playtest 2026-07-28 first found it meaningless ("why would I count these sixty
	# seconds?") and then, once the text was rewritten and also thrown to the screen on
	# entering the cellar, asked for the wall copy to go: *"we do not need this text here —
	# appearing it on the screen is enough."*
	#
	# The candle stub above stays. It is the diegetic half — an object you find with the
	# torch — and the sentence is now delivered once, on screen, by _spawn_cellar_caption().
	# Saying it twice in one room made the shelf read as a label rather than as a thing
	# somebody left behind.


# The key's own visual — an alpha-cutout quad lying flat, same trick as the
# apparition billboard, with a gold-box fallback if the art is missing. Unchanged
# from the version that used to sit on a Kitchen stand; only the calling site and
# position moved.
func _build_cellar_key(pos: Vector3) -> void:
	var key := KeyItem.new()
	key.label_text = "Cellar key"
	key.position = pos
	key.picked_up.connect(_on_cellar_key_taken)
	add_child(key)
	var key_tex := TEX + "house_cellar_key.png"
	if ResourceLoader.exists(key_tex):
		var kq := MeshInstance3D.new()
		var qm := QuadMesh.new()
		# ⚠️ Must match the art's aspect or the key renders squashed. house_cellar_key.png
		# is cropped to its own alpha bounds at 1435x381 = 3.77:1; a 20 cm key is
		# therefore 0.053 m tall. Re-crop the art and this number has to move with it.
		qm.size = Vector2(0.20, 0.053)
		kq.mesh = qm
		var qmat := StandardMaterial3D.new()
		var tex := load(key_tex)
		qmat.albedo_texture = tex
		# ALPHA_SCISSOR, not ALPHA: a scissored cutout still writes depth, so the key
		# sorts correctly against the drawer and the room gloom instead of blending.
		qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		qmat.alpha_scissor_threshold = 0.5
		qmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		qmat.emission_enabled = true
		qmat.emission_texture = tex
		qmat.emission_energy_multiplier = EM_KEYCARD   # findable, not a beacon
		kq.set_surface_override_material(0, qmat)
		kq.rotation = Vector3(-PI / 2.0, 0, 0)  # lie flat, face up
		key.add_child(kq)
	else:
		var km := MeshInstance3D.new()
		var kb := BoxMesh.new()
		kb.size = Vector3(0.18, 0.04, 0.07)
		km.mesh = kb
		var kmat := StandardMaterial3D.new()
		kmat.albedo_color = Color(0.85, 0.7, 0.2)
		kmat.metallic = 0.8
		kmat.emission_enabled = true
		kmat.emission = Color(0.6, 0.5, 0.1)
		kmat.emission_energy_multiplier = EM_KEYCARD
		km.set_surface_override_material(0, kmat)
		key.add_child(km)
	var kcol := CollisionShape3D.new()
	var ks := BoxShape3D.new()
	ks.size = Vector3(0.32, 0.24, 0.32)
	kcol.shape = ks
	key.add_child(kcol)
	# ⚠️⚠️ THE KEY CARRIED ITS OWN LIGHT, AND `_drive_lights()` COULD NOT SEE IT (turned off
	# 2026-09-07, D3). This `OmniLight3D` is created as a CHILD OF THE KEY and never appended to
	# `_lights` — only `_add_lamp()` does that — so the one function that holds this level's ten
	# lamps at zero has no idea it exists. From the moment the map minigame is won until the key
	# is picked up it burned at 0.35 energy over a 2.5 m radius in a house measured at ambient
	# 0.02, i.e. it was the only real light source in the building.
	#
	# ⚠️ KEPT AT ZERO RATHER THAN DELETED, deliberately: the node is the record of the decision,
	# and the alternative — a light that quietly reappears the next time someone "restores the
	# key's glow" — is how X64 happened in the first place. The key is found by torchlight now,
	# on a stool the minigame's own payoff toast points you at.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.9, 0.75, 0.3)
	glow.light_energy = 0.0
	glow.omni_range = 2.5
	key.add_child(glow)


# ⚠️ BACKLOG #16. This used to be wired straight to the key's `picked_up`, so winning
# the map minigame in the Bathroom flung the cellar open from across the house and the
# key was a formality. Now taking the key only means you are CARRYING it; the door is
# a separate act, at the door.
func _on_cellar_key_taken() -> void:
	_has_cellar_key = true
	_refresh_carried()
	GameState.set_objective(OBJ_UNLOCK_CELLAR)
	_advance_guest(2)


# ------------------------------------------------------------------------- THE GUEST
#
# Four stages, one per quest milestone. Each one is a MovedProp: the delta is applied the
# first time the player is more than 6 m away AND facing elsewhere, so the change always
# happens off-screen and is always discovered rather than witnessed.
#
# ⚠️ Stages are IDEMPOTENT and monotonic. `_advance_guest(n)` is a no-op if stage n is
# already applied, because the milestones that drive it are not strictly ordered — a player
# can re-enter the level through a back door with the key already taken.
#
# ⚠️ Deliberately only FOUR authored moves, and the chair moves at most twice. A prop that
# keeps moving is a mechanic; this has to stay an anomaly. Do not add a repeating cycle.
func _advance_guest(stage: int) -> void:
	if stage <= _guest_stage:
		return
	# Playtest instrumentation only (2026-08-16). THE GUEST's stages left no trace in the log,
	# so a session could not be told apart from one where the house never rearranged at all.
	var _dbg := get_node_or_null("/root/DebugLog")
	if _dbg:
		_dbg.note("GUEST stage %d (was %d)" % [stage, _guest_stage])
	# Apply every stage up to `stage`, so a restored snapshot lands in the right state even
	# if it skipped one (e.g. the key was taken but the map's stage never fired).
	for s in range(_guest_stage + 1, stage + 1):
		_apply_guest_stage(s)
	_guest_stage = stage


func _apply_guest_stage(stage: int) -> void:
	match stage:
		1:
			# ⭐ 2026-09-24: THE MAP NO LONGER ARMS THE PAINTING — the first porch visit does
			# (`_on_first_porch_visit()` -> `_arm_painting()`), because the painting now hides the
			# watermelon the porch's guillotine is waiting for (the user: "after you go to the
			# room which has an escape only after that the painting will fall"). The stage is
			# kept, empty, so `guest_stage` keeps its numbering.
			#
			# It still falls WHILE THE PLAYER IS LOOKING (playtest 2026-07-29, _tick_painting()):
			# in rooms this dark an anomaly nobody witnesses is an anomaly nobody gets.
			pass
		2:
			pass    # the key itself is the beat; nothing changes in the house here
		3:
			# ⚠️ THE GUEST SHOWS ITSELF — once, and only once, in the whole level.
			#
			# This stage used to relocate a kitchen chair. Playtest 2026-07-28 saw it and
			# reported *"the objects that are appearing on the floor look just like brown
			# boxes… it should look like a creepy boy or something like that, accompanied by
			# the weird noise"* — and the screenshot proved the point: `_make_prop` builds a
			# single flat-shaded CSGBox, so the "chair" was a 0.44 m cube.
			#
			# Rather than model a better chair, the user's call was to make the thing that
			# appears a FIGURE. So the house's rearrangement is now bracketed by one
			# sighting: the painting goes down, then the child is standing in the Hallway,
			# then the music box has moved. It is a `Watcher` — no panic, no collider, no
			# kill radius, no rule — so it costs the level's tuned budget nothing.
			pass    # the child is owned by the cellar sequence, not by this ladder
		4:
			# The payoff. The music box — the level's signature sound, which until this
			# pass had no object at all — is sitting in the Hallway, playing, between the
			# player and the exit. The loop is a child of the body, so the sound moved too.
			_move_guest_prop(_music_box, "music_box_hallway", GUEST_HALLWAY_SPOT)


# The child, standing in the Hallway, facing you. Once per run.
#
# Placed at the Landing end of the 3 m-wide, 8 m-long Hallway, which is the corridor every
# route back from the cellar has to pass through — so it is framed by the walls and cannot be
# missed the way a prop in the corner of a room can.
#
# ⚠️ A `Watcher`, deliberately: zero panic, no `ScaryObject` ancestor, no collider, no kill
# radius, nothing to learn and no way to fail. It is an image. The whole House rearrangement
# is worth 0 panic and this keeps it that way — the fridge remains the level's only new cost.
#
# ⚠️ `vanish_within` 4.0 so it is gone if the player walks up to it, and `Watcher`'s own
# look-away-then-look-back roll may take it sooner. That is the intent: it is not a thing you
# get to inspect.
# THE CHILD — a scripted three-beat sequence in the cellar, specified by the user on the
# 2026-07-29 playtest after two earlier placements failed to land:
#
#   1. the moment you reach the bottom of the ramp, every light dies AND the torch goes out
#   2. ~5.5 s of nothing but the dark
#   3. the child, screaming, three metres in front of you
#   4. ~3 s later the lights come back and it is gone
#
# Both earlier versions put it in the Hallway and both missed: the first spawned it two rooms
# from the player (the LOS check failed and silently ate the whole beat), the second waited
# for the player to walk back into the Hallway, which happened long after they had left the
# cellar — "the light off actually happened, but after I got away from the cellar".
#
# ⚠️ The dark-zone and standstill taxes are SUSPENDED for the whole sequence
# (`set_smiler_active`, which exists to do exactly this). The cellar is a DarkZone, so forcing
# the torch off would otherwise charge +3/s for a scripted event the player cannot avoid or
# react to — Issue 18, and the player died here at 99 % panic on the run that prompted this.
# The bedroom painting comes off the wall in front of you.
#
# ⚠️ It requires BOTH proximity and a facing check, so it cannot happen behind your back —
# the opposite of the MovedProp rule this level started with, and the explicit request.
func _tick_painting() -> void:
	if not _painting_armed or _painting_fallen:
		return
	if not _bedroom_painting or not is_instance_valid(_bedroom_painting):
		return
	var pl := _player()
	if not pl:
		return
	var cam := pl.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return
	var to_it := _bedroom_painting.position - cam.global_position
	if to_it.length() > PAINTING_TRIGGER_DIST:
		return
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	to_it.y = 0.0
	if fwd.length() < 0.01 or to_it.length() < 0.01:
		return
	if fwd.normalized().dot(to_it.normalized()) < PAINTING_TRIGGER_DOT:
		return
	# ⚠️ AND YOU MUST ACTUALLY BE ABLE TO SEE IT (added 2026-08-16). Distance + facing alone is
	# not "in front of you", it is "within 4.5 m and pointed roughly that way" — and walls do
	# not enter into it. Measured on the replay log: THE GUEST reached stage 2 (key taken, at
	# the Bathroom stand) at t = 146.8 and the painting fell at t = 148.26, ~130 s before the
	# player first entered the ChildRoom. It went down through the Landing's south wall, to an
	# empty room, and the beat — whose whole point is that it happens while you watch — was
	# spent on a bang from behind a wall. A single ray fixes it and costs nothing.
	if not _painting_in_sight(cam):
		return
	_drop_painting(true)


# Line of sight from the eye to the panel, excluding the panel's own body (it is on layer 1,
# so without the exclusion the ray always stops on the thing it is asking about) and the
# player. Any other solid in between means the player cannot see it fall.
func _painting_in_sight(cam: Camera3D) -> bool:
	var space := get_world_3d().direct_space_state
	if not space:
		return true
	var q := PhysicsRayQueryParameters3D.create(
		cam.global_position, _bedroom_painting.global_position)
	q.collision_mask = 1
	var skip: Array[RID] = [_bedroom_painting.get_rid()]
	var pl := _player()
	if pl:
		skip.append(pl.get_rid())
	q.exclude = skip
	return space.intersect_ray(q).is_empty()


# `animate` false is the restore path — a player returning through a back door should find it
# already down, not watch it fall a second time.
func _drop_painting(animate: bool) -> void:
	if _painting_fallen or not _bedroom_painting:
		return
	_painting_fallen = true
	var _dbgp := get_node_or_null("/root/DebugLog")
	if _dbgp:
		_dbgp.note("GUEST painting fell")   # instrumentation only
	# ⭐ 2026-09-24: and behind it, the hole with the fruit in it.
	_reveal_niche()
	var p: Vector3 = _bedroom_painting.position
	# -90° pitch lays it flat with the picture facing UP; +90° would point the quad's own +Z
	# at the floor and backface culling would erase it (Issue 28, and it shipped that way
	# once). The small yaw stops it landing squarely.
	#
	# ⚠️ THE LANDING OFFSET RUNS ALONG THE PANEL'S OWN FORWARD (fixed 2026-08-16). It was a
	# hard-coded `p.z + 0.55`, correct only for a panel facing +z — which was true of every
	# painting this level had ever had. The falling painting is now on the ChildRoom's EAST
	# wall at `y_rot = -PI/2`, where +z is sideways: the picture would have slid a metre along
	# the wall and ended up half inside it. A QuadMesh faces its own +Z, so `basis.z` is the
	# direction "out into the room" for any yaw, and for the old bedroom panel it is exactly
	# (0,0,1) — this changes nothing about the beat that shipped.
	var out: Vector3 = _bedroom_painting.global_transform.basis.z
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3(0, 0, 1)
	var end_pos: Vector3 = Vector3(p.x, 0.06, p.z) + out * 0.55
	var end_rot := _bedroom_painting.rotation \
		+ Vector3(deg_to_rad(-90.0), deg_to_rad(14.0), 0.0)
	# ⚠️ THE PANEL ON THE FLOOR MUST NOT BE A WALL (2026-08-16, Issue 76's second head).
	# Pitched flat it is a 0.8 x 1.0 footprint standing 11 cm proud of the boards, and
	# `move_and_slide` cannot step up. MEASURED with the player's own capsule, with this fix
	# disabled: the north end of the child's room — the end the exit lock is on — split from
	# ONE free lane `x -1.95..1.95` into `[-1.95..0.15]` and `[1.40..1.95]` at z 17.8, 18.0
	# and 18.3, the second of which is a cul-de-sac. Nothing was made unreachable that had been
	# reachable, so the flood fill above stays green; this is the NARROWING half, and after the
	# 2026-08-16 report there is no appetite for a prop of this level's dropping a solid into a
	# walking line. Layer 2 is this project's existing "raycast-hittable, invisible to movement"
	# convention (`note.gd`), and the gaze ray uses the default all-layers mask, so the picture
	# still feeds panic when you look at it on the floor.
	_bedroom_painting.collision_layer = 2
	_bedroom_painting.collision_mask = 0
	if not animate:
		_bedroom_painting.position = end_pos
		_bedroom_painting.rotation = end_rot
		return

	# `painting_fall` is a shared asset RandomAmbient already uses; loud and local here.
	var s := GameState.load_audio("painting_fall")
	if s:
		var a := AudioStreamPlayer3D.new()
		a.stream = s
		a.volume_db = PAINTING_FALL_DB
		a.max_db = 20.0
		a.unit_size = 10.0
		a.position = p
		add_child(a)
		a.finished.connect(a.queue_free)
		a.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_bedroom_painting, "position", end_pos, PAINTING_FALL_TIME)
	tw.tween_property(_bedroom_painting, "rotation", end_rot, PAINTING_FALL_TIME)
	var pl := _player()
	if pl:
		pl.jolt_camera(0.05, 0.3)


# H4: the note is OPEN when `read` fires (it fires on open); the beat waits for the page to
# come down, then takes the lights and pins the player where they stand — at the note.
func _arm_child_on_note_close() -> void:
	if _guest_child_done or _child_armed_on_note:
		return
	_child_armed_on_note = true
	var nu := get_node_or_null("/root/NoteUI")
	if nu == null or not nu.has_signal("closed"):
		_begin_cellar_blackout()
		return
	nu.connect("closed", func() -> void: _begin_cellar_blackout(), CONNECT_ONE_SHOT)


func _begin_cellar_blackout() -> void:
	if _guest_child_done:
		return
	_guest_child_done = true
	_child_dark = true
	_child_postponed = 0.0
	var pl := _player()
	if pl:
		pl.force_flashlight_off()
		pl.set_smiler_active(true)
		# H2 (2026-09-16, the user: "avoid the situation when the player can escape the cellar
		# before he even sees the doll — block the player's movement for several seconds"): the
		# blackout PINS you where you stand, in the dark, until the child has come and gone.
		# Velocity zeroed by hand (Issue 49); `_end_cellar_blackout` releases it.
		pl.velocity.x = 0.0
		pl.velocity.z = 0.0
		pl.freeze_input()
		_child_frozen = true
	get_tree().create_timer(CELLAR_WHERE_AT).timeout.connect(func() -> void:
		if _child_dark and is_inside_tree():
			# at the BOTTOM: the ramp-foot hint (CELLAR_HINT, 4 s) can still be up in the centre
			ScreenText.scrawl(get_tree(), CELLAR_WHERE_TEXT, CELLAR_WHERE_HOLD, 54, true))
	get_tree().create_timer(CHILD_APPEAR_DELAY).timeout.connect(_cellar_child_appear)


# ⚠️ IT MUST NOT APPEAR WHILE THE PLAYER CANNOT LOOK (2026-08-16).
#
# Playtest capture A3: *"Please double check that I will always see that doll."* The log said
# why, exactly: the 15-point spike at t=205.48 is `Beartrap.ESCAPE_INITIAL_PANIC`, 0.63 m from
# the cellar beartrap, and the child spawned at t=206.98 and was freed at 209.98 — the ENTIRE
# appearance sat inside a 7-second beartrap QTE, with a countdown UI over the screen and
# `begin_qte()` holding the player. The placement code did what it was told: 3.20 m dead ahead,
# exactly `CHILD_DIST`. What it was not told is that the player was pinned.
#
# `_begin_cellar_blackout()` armed a bare `SceneTreeTimer`, which defaults to
# `process_always = true` and therefore fires straight THROUGH a tree pause — so an open note
# or the journal would have done the same thing. `apparition_director.gd:100-108` refuses on
# exactly these three conditions and is the only thing in the project that did; the level's own
# scripted beat checked none of them.
#
# ⚠️ This guard is now LOAD-BEARING, not belt-and-braces. The beartrap sits 1.6 m past the
# blackout trigger on the only heading in, and the user's decision on 2026-08-16 is that it
# STAYS there (see _spawn_cellar_contents) — so the collision will keep happening, and this is
# the only thing preventing it.
#
# ⚠️ And it must not postpone FOREVER: the blackout's end is armed by _cellar_child_appear(),
# so a beat that never fires leaves the player with no lamps and no torch, which is a worse bug
# than the one being fixed. All three conditions are transient and player-resolvable (a QTE
# lasts ESCAPE_TIME 7 s; a note and the journal close on a keypress), but CHILD_POSTPONE_MAX is
# the safety valve: past it, give up on the figure and hand the lights back.
const CHILD_RETRY := 0.25
const CHILD_POSTPONE_MAX := 45.0

var _child_postponed: float = 0.0
var _child_frozen: bool = false      # WE pinned the player for the appearance (2026-09-10)


func _can_show_child() -> bool:
	if NoteUI.is_open:
		return false
	if get_tree().paused:
		return false
	var pl := _player()
	# H2: OUR own pin (the blackout) is not a reason to wait — a beartrap's or a note's is.
	if pl and pl.has_method("is_input_frozen") and pl.is_input_frozen() and not _child_frozen:
		return false
	return true


func _cellar_child_appear() -> void:
	if not _can_show_child():
		if _child_postponed >= CHILD_POSTPONE_MAX:
			var _dbgx := get_node_or_null("/root/DebugLog")
			if _dbgx:
				_dbgx.note("CELLAR child ABANDONED after %.1fs of postponement" % _child_postponed)
			_end_cellar_blackout()
			return
		if _child_postponed <= 0.0:
			var _dbgp := get_node_or_null("/root/DebugLog")
			if _dbgp:
				_dbgp.note("CELLAR child postponed (player cannot look)")
		_child_postponed += CHILD_RETRY
		get_tree().create_timer(CHILD_RETRY).timeout.connect(_cellar_child_appear)
		return

	var pl := _player()
	if not pl:
		_end_cellar_blackout()
		return
	var cam := pl.get_node_or_null("Camera3D") as Camera3D
	var fwd := -cam.global_basis.z if cam else Vector3.FORWARD
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()

	# ⭐⭐ CLOSE, AND THE CAMERA IS BROUGHT TO IT (2026-09-10, the user's replay: *"the doll
	# should appear the same way as the creature in the lab — your camera needs to be forced in
	# that direction, and the doll should appear very close to you"*). The ladder is
	# player-relative and NEAR-FIRST — `level_1.gd:_place_nook_figure()`'s shape, which solved
	# the same "I never saw it" report there — then a fan either side, then a step further,
	# then BEHIND (the camera turn makes a figure behind you a legitimate placement rather than
	# a wasted one), then the room centre as the last resort. Every candidate goes through
	# `Watcher.spawn()`, whose ray-only `_fits()` + line-of-sight probe is the validation.
	#
	# ⚠️ `require_los` IS TRUE (2026-08-16). It was passed FALSE, which `watcher.gd:98-109`
	# and CLAUDE.md both restrict to `congregation.gd` — because the line-of-sight ray is also
	# the ONLY probe that catches "this point is inside a wall". `_fits()`'s other three tests
	# (head room, top-down column, 16-ray fan) all ORIGINATE inside the slab for an embedded
	# candidate and, against a concave CSG trimesh, cross no faces and report clear (Issue 40 /
	# Issue 59). With the check live, the ladder does its job and a spot that will not work
	# is refused rather than buried in a wall with the scream still playing.
	var here := pl.global_position
	var side := fwd.rotated(Vector3.UP, deg_to_rad(CHILD_FAN_DEG))
	var side2 := fwd.rotated(Vector3.UP, deg_to_rad(-CHILD_FAN_DEG))
	var candidates: Array = []
	for d in CHILD_NEAR:
		candidates.append([fwd * d, "ahead %.1f" % d])
	candidates.append([side * CHILD_NEAR[1], "fan +%.0f" % CHILD_FAN_DEG])
	candidates.append([side2 * CHILD_NEAR[1], "fan -%.0f" % CHILD_FAN_DEG])
	candidates.append([fwd * CHILD_DIST, "ahead %.1f" % CHILD_DIST])
	candidates.append([-fwd * CHILD_NEAR[1], "behind %.1f" % CHILD_NEAR[1]])
	candidates.append([-fwd * (CHILD_NEAR[2] + 0.2), "behind %.1f" % (CHILD_NEAR[2] + 0.2)])
	var taken := "room centre"
	for c in candidates:
		var off: Vector3 = c[0]
		var cand := Vector3(here.x + off.x, CELLAR_Y, here.z + off.z)
		_child_node = Watcher.spawn(self, cand, TEX + "house_child.png", 0.0, true, CHILD_HEIGHT)
		if _child_node:
			taken = String(c[1])
			break
	if not _child_node:
		_child_node = Watcher.spawn(self,
			Vector3(CELLAR_CENTER.x, CELLAR_Y, CELLAR_CENTER.y),
			TEX + "house_child.png", 0.0, true, CHILD_HEIGHT)
	if _child_node:
		# Only this sequence decides when it goes — no lifetime, no look-away roll.
		_child_node.persistent = true
		# Named so it is distinguishable from the cellar's OTHER Watcher (the one in the far
		# corner). Two anonymous "Watcher" nodes in one room made the test's count ambiguous.
		_child_node.name = "GuestChild"
		# ⚠️ THE PIN AND THE TURN — `level_1.gd:_nook_reveal()` verbatim. The velocity must be
		# zeroed by hand: `_apply_movement()` only RETURNS on `_input_frozen`, and
		# `_physics_process` still calls `move_and_slide()`, so a frozen walker coasts (Issue
		# 49). `turn_to_face()`, never `ai_look_at()` (it writes `_pitch` as well as yaw).
		# Released by `_end_cellar_blackout()` with the lights, CHILD_HOLD later. Zero panic.
		pl.velocity.x = 0.0
		pl.velocity.z = 0.0
		pl.freeze_input()
		_child_frozen = true
		pl.turn_to_face(_child_node.global_position + Vector3(0, 1.35, 0), CHILD_TURN_TIME)
		HoldBreath.dip(get_tree(), CHILD_DIP)
	_spawn_guest_child()
	var _dbgt := get_node_or_null("/root/DebugLog")
	if _dbgt:
		_dbgt.note("CELLAR child placement: %s" % taken)
	# Instrumentation only — logs WHERE the figure went and where the player was standing, so
	# "I heard it but never saw it" can be diagnosed instead of guessed at.
	var _dbgc := get_node_or_null("/root/DebugLog")
	if _dbgc:
		var _pl := _player()
		if _child_node and is_instance_valid(_child_node):
			_dbgc.note("CELLAR child spawned at %s  player at %s" % [
				_child_node.global_position,
				_pl.global_position if _pl else Vector3.ZERO])
		else:
			_dbgc.note("CELLAR child NOT spawned (Watcher.spawn returned null)")
	get_tree().create_timer(CHILD_HOLD).timeout.connect(_end_cellar_blackout)


func _end_cellar_blackout() -> void:
	_child_dark = false
	var pl := _player()
	if pl:
		pl.restore_flashlight()
		pl.set_smiler_active(false)
		# The pin the appearance put on (2026-09-10). Only if WE froze them: the ABANDONED path
		# never did, and a QTE or a locker push owns its own freeze.
		if _child_frozen:
			_child_frozen = false
			pl.unfreeze_input()
	if is_instance_valid(_child_node):
		_child_node.queue_free()
		_child_node = null


# Just the scream — the figure and the darkness are owned by the cellar sequence above.
#
# VERY loud, by request. The figure itself has no rules, no collider and costs no panic, so
# sound and darkness are the only two channels this thing has.
func _spawn_guest_child() -> void:
	# H4 (2026-09-16, the user: "make the doll sound the same as baba yaga, the default
	# jumpscare sound for the House") — `screamer_house`, the level's own fatal sting. It sits
	# at full scale already, so the +18 dB the re-mastered child scream needed is not applied.
	var s := GameState.load_audio("screamer_house")
	var baba: bool = s != null
	if not s:
		s = GameState.load_audio("childe_scream")
	if not s:
		s = GameState.load_audio("guest_child")
	if not s:
		s = GameState.load_audio("music_box")
	if not s:
		return
	var p := AudioStreamPlayer3D.new()
	p.name = "GuestChildAudio"
	p.stream = s
	p.volume_db = 0.0 if baba else CHILD_VOLUME_DB
	p.max_db = 6.0 if baba else 24.0   # default is 3; the gain above is clamped without this
	p.unit_size = 18.0
	p.bus = AudioBuses.AMBIENCE
	# At the figure if there is one, otherwise at the player — the scream must never be
	# stranded at a fixed world point the sequence no longer uses.
	p.position = (_child_node.global_position + Vector3(0, 1.0, 0)) \
		if is_instance_valid(_child_node) else _player().global_position
	add_child(p)
	p.finished.connect(p.queue_free)
	# H3 (2026-09-13, capture #6: "more loud"): the file is re-mastered to the project's loud
	# target and the Ambience dip already fired with the figure; the scream now LEADS by nothing
	# and LANDS 0.3 s into that silence, so it arrives into a hole rather than over the bed.
	var tw := p.create_tween()
	tw.tween_interval(CHILD_SCREAM_LEAD)
	tw.tween_callback(p.play)


# `target_or_delta` is an ABSOLUTE position for props being relocated across the house, and
# MovedProp wants a delta — so convert here, once, rather than at four call sites.
func _move_guest_prop(prop: Node3D, key: String, target: Vector3,
		rot: Vector3 = Vector3.ZERO, absolute: bool = true) -> void:
	if not prop or not is_instance_valid(prop):
		return
	var delta: Vector3 = (target - prop.position) if absolute else target
	var mp := MovedProp.attach(prop, key, delta, rot)
	mp.arm()
	_guest_props.append(mp)


# Restoring a snapshot must not re-arm the wait — the player already SAW these moved before
# they walked back through the door, so re-arming would silently un-move them until they
# happened to look away again. apply_now() is MovedProp's restore path.
#
# ⚠️ Delegates to _advance_guest() rather than looping _apply_guest_stage() itself. The first
# version did the latter and DOUBLE-APPLIED every delta that _advance_guest had already
# attached: the chair's Landing move is (-3.9, 0, +6.1), and applying it twice put the chair
# at (-2.3, 18.6) — outside the house, through two walls. Caught by
# tests/check_house_guest.gd. `_advance_guest` is the only thing that may attach, precisely
# because it is the only thing that tracks what has already been attached.
func _force_guest_stages(stage: int) -> void:
	_advance_guest(stage)
	# ⭐ 2026-09-24: the painting is NOT forced from the stage any more — `painting_armed` /
	# `painting_fallen` travel on their own keys (`_restore_porch()`), because the porch arms it.
	for mp in _guest_props:
		mp.apply_now()


func _on_cellar_gate_used() -> void:
	if not _cellar_gate:
		return
	if not _has_cellar_key:
		ScreenText.toast(get_tree(), "It is locked. Something holds it from the other side.",
			Color(0.9, 0.85, 0.75), 2.0)
		return
	_has_cellar_key = false
	_refresh_carried()
	_cellar_gate.open()
	_play_at("creak", Vector3(5, 1.2, 3), 2.0)
	GameState.set_objective(OBJ_CODE)
	_advance_guest(3)


# ---------------------------------------------------------------- apparition
#
# H2 (2026-09-16, the user: "block the creature from appearing at the doll level"): the cellar's
# scripted HOLD apparition is GONE — on the 2026-09-15 run it appeared 5 s before the child and
# spent the beat. The ApparitionDirector's random one (RANDOM_APPARITIONS) stays, upstairs.


# ---------------------------------------------------------------- events

func _spawn_events() -> void:
	_spawn_event(Vector3(0, 1.5, 1.5), Vector3(3, 3, 1.5), _ev_front_door_slam)
	_spawn_event(Vector3(0, 1.5, 8.0), Vector3(3, 3, 1.5), _ev_footsteps_above)
	_spawn_event(_builder.room_center("Bedroom") + Vector3(0, 1.5, -2.4), Vector3(2, 3, 1.2), _ev_bedroom_dark)


func _spawn_event(pos: Vector3, size: Vector3, callback: Callable) -> void:
	var ev := CorridorEvent.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	ev.add_child(col)
	ev.position = pos
	ev.fired.connect(callback)
	add_child(ev)


func _ev_front_door_slam() -> void:
	_play_at("door_slam", Vector3(0, 1.2, -3.0), 2.0)
	var p := _player()
	if p:
		p.add_panic(8.0)


func _ev_footsteps_above() -> void:
	_play_at("footsteps_above", Vector3(0, 3.2, 8.0), 3.0)
	var p := _player()
	if p:
		p.add_panic(6.0)
	# ⚠️ And from now on they come back, at ZERO panic, on a 40-70 s gap.
	#
	# This fired exactly once, for 6 panic, and never again — in a house that is entirely
	# SINGLE-STOREY (every room's floor is at y=0; the only vertical element is the cellar
	# ramp). One footstep event is a noise; a recurring one makes an upstairs that does not
	# exist into a permanent resident. The panic stays on the first one only, because the
	# point is presence, not pressure.
	_overhead_timer = randf_range(OVERHEAD_MIN, OVERHEAD_MAX)


# Footsteps on the ceiling of whichever room the player is standing in — so they track,
# rather than always coming from the fixed Hallway spot the one-shot used.
func _tick_overhead(delta: float) -> void:
	if _overhead_timer <= 0.0:
		return
	_overhead_timer -= delta
	if _overhead_timer > 0.0:
		return
	var p := _player()
	if p:
		var above := p.global_position + Vector3(randf_range(-1.5, 1.5), 3.2,
			randf_range(-1.5, 1.5))
		_play_at("footsteps_above", above, 1.0)
	_overhead_timer = randf_range(OVERHEAD_MIN, OVERHEAD_MAX)


func _ev_bedroom_dark() -> void:
	var lamp: OmniLight3D = get_node_or_null("Lamp_Bedroom")
	if lamp:
		var t := create_tween()
		t.tween_property(lamp, "light_energy", 1.2, 0.12)
		t.tween_property(lamp, "light_energy", 0.05, 0.1)
		t.tween_property(lamp, "light_energy", 0.0, 0.25)
		for entry in _lights:
			if entry[0] == lamp:
				entry[1] = 0.0
	# ⚠️ THE BEDROOM'S `DarkZone` IS GONE TOO (2026-09-03, D4). This event kills `Lamp_Bedroom`
	# permanently and used to drop a 6x3x6 tax box on the room to go with it — the lamp dying was
	# the cause and the +3/s was the consequence. In a house that starts black the lamp was never
	# burning, so the kill above is already a no-op for LIGHT and the zone was charging for a
	# darkness the level had imposed before the player arrived.
	# ⚠️ The BEAT is untouched: the tween still runs (so a restored house still loses this lamp),
	# the creak still plays, and the event still costs its panic at the call site.
	_play_at("creak", _builder.room_center("Bedroom") + Vector3(0, 2.5, 0), 2.0)
	var p := _player()
	if p:
		p.add_panic(6.0)


# ---------------------------------------------------------------- ambience / ticks

# See level_1.gd: duplicate the SHARED Environment resource before retuning it, so
# the changes don't bleed into the other levels.
func _boost_ambient(energy: float) -> void:
	var we: WorldEnvironment = get_node_or_null("Environment/WorldEnvironment")
	if not we or not we.environment:
		return
	var env: Environment = we.environment.duplicate()
	env.ambient_light_energy = energy
	env.ambient_light_color = Color(0.12, 0.1, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Black background instead of the procedural sky: any geometry gap (e.g. above the
	# cellar) reads as darkness, not jarring blue sky — the right call for an interior.
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	we.environment = env


func _start_ambience() -> void:
	var ambient: AudioStreamPlayer = get_node_or_null("AmbientPlayer")
	if ambient:
		ambient.bus = AudioBuses.AMBIENCE   # duckable — see audio_buses.gd
		var s := GameState.load_audio("ambient_house")
		if s:
			ambient.stream = s
		if ambient.stream:
			ambient.finished.connect(ambient.play)
			ambient.play()
	var creak: AudioStreamPlayer = get_node_or_null("CreakPlayer")
	if creak:
		var cs := GameState.load_audio("creak")
		if cs:
			creak.stream = cs


func _process(delta: float) -> void:
	_tick_forest()
	_tick_timers(delta)
	_tick_head_digit(delta)
	_drive_lights()
	_tick_tv_card(delta)
	_tick_overhead(delta)
	_tick_painting()
	# ⭐ THE PORCH (2026-09-24)
	_tick_porch(delta)
	_tick_forest_clock(delta)
	_tick_ghosts(delta)
	_tick_witch(delta)
	_tick_outdoor_audio(delta)


const TV_CARD_HOLD := 8.0  # BUG_FIX.md 2.2: was 4.5 — playtest read it as gone too fast
const TV_CARD_GAP_MIN := 16.0
const TV_CARD_GAP_MAX := 26.0


func _tick_tv_card(delta: float) -> void:
	if not _tv_card:
		return
	if _tv_card_hold > 0.0:
		_tv_card_hold -= delta
		# Fade out over the last second so it reads as the signal slipping away.
		var a: float = clampf(_tv_card_hold, 0.0, 1.0)
		_tv_card.modulate.a = a if _tv_card_hold < 1.0 else 1.0
		if _tv_card_hold <= 0.0:
			_tv_card.modulate.a = 0.0
			_tv_card_clock = randf_range(TV_CARD_GAP_MIN, TV_CARD_GAP_MAX)
		return
	_tv_card_clock -= delta
	if _tv_card_clock <= 0.0:
		_tv_card_hold = TV_CARD_HOLD


func _spawn_apparition_director() -> void:
	if not RANDOM_APPARITIONS:
		return
	var d := ApparitionDirector.new()
	d.name = "ApparitionDirector"
	add_child(d)


func _tick_forest() -> void:
	if _forest_fired:
		return
	var p := _player()
	if not p:
		return
	var d := Vector2(p.global_position.x - _window_pos.x, p.global_position.z - _window_pos.z)
	if d.length() <= FOREST_SCARE_DIST:
		_forest_fired = true
		Screamer.flash_scare(FOREST_SCARE_PATH, "screamer_forest", FOREST_SCARE_HOLD)
		p.jolt_camera(0.08, 0.5)
		p.add_panic(FOREST_SCARE_PANIC)
		_log("PORCH window scare fired at %s" % p.global_position.snappedf(0.01))
		# She was out there, beyond the glass. The face replaces her.
		if is_instance_valid(_witch_node) and _witch_node.name == "Witch1":
			_witch_node.queue_free()
			_witch_node = null
		# ⭐ 2026-09-24: …and a beat after the face clears, the glass comes in. The timer does NOT
		# run through a pause (`process_always` false), so an open note or the journal holds it.
		get_tree().create_timer(FOREST_SCARE_HOLD + WINDOW_BREAK_DELAY, false).timeout.connect(_burst_window)


func _tick_timers(delta: float) -> void:
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(CREAK_MIN, CREAK_MAX)
		var creak: AudioStreamPlayer = get_node_or_null("CreakPlayer")
		if creak and creak.stream:
			creak.play()

	_pipe_timer -= delta
	if _pipe_timer <= 0.0:
		_pipe_timer = randf_range(PIPE_MIN, PIPE_MAX)
		_play_at("pipe_groan", _random_room_point(1.6), 0.0)

	_blackout_timer = maxf(0.0, _blackout_timer - delta)
	_blackout_clock -= delta
	if _blackout_clock <= 0.0:
		_blackout_clock = randf_range(BLACKOUT_MIN, BLACKOUT_MAX)
		_blackout_timer = 1.4
		var p := _player()
		if p:
			p.add_panic(4.0)


# ⭐ THE ONE LAMP. Every safe note read -> the wall lamp beside the exit lock fades up, alone,
# with a sting. The rest of the house stays black.
#
# ⚠️ Counted by NODE NAME, not by an int++. `note.gd` emits `read` on every open, so a player who
# re-reads the living-room note three times would otherwise light the house without ever having
# gone down to the cellar for the third digit.
func _on_safe_note_read(n: Node) -> void:
	if n == null:
		return
	var key := String(n.name)
	# ⚠️ A HARD REFUSAL, not a fallback. If a safe note ever loses its explicit name it goes back
	# to `@StaticBody3D@NNN`, and the counter silently starts accepting keys that will not survive
	# a back-door return — which is precisely the bug this naming exists to prevent, arriving
	# quietly. Better to warn and let the lamp never fire than to let it fire early.
	if not key.begins_with("SafeNote_"):
		push_warning("level_2: a safe note has no stable name ('%s') — the lock lamp counter "
			% key + "keys on it and will not survive a resume. See _make_note().")
		return
	_mark_safe_note(key)


# One of the three digits has been learned (a page opened, or the head's forehead read).
func _mark_safe_note(key: String) -> void:
	if _safe_notes_read.has(key):
		return
	_safe_notes_read.append(key)
	if _safe_notes_read.size() >= SAFE_NOTES_TOTAL:
		_light_the_lock()


# H2: the digit on the head. Read by LOOKING — within HEAD_READ_DIST, the camera on it, for
# HEAD_READ_TIME accumulated — after the fridge is open. Archived to the journal as text.
const HEAD_READ_DIST := 2.2
const HEAD_READ_TIME := 1.0
const HEAD_READ_DOT := 0.94
const HEAD_NOTE_TEXT := "On its forehead, in something dark: 7."
var _head_read_t: float = 0.0
func _tick_head_digit(delta: float) -> void:
	if _safe_notes_read.has("SafeNote_Head"):
		return
	var fridge := get_node_or_null("Fridge")
	if fridge == null or not bool(fridge.call("is_open")):
		return
	var p := _player()
	if p == null:
		return
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var head: Vector3 = fridge.call("thing_position")
	var to: Vector3 = head - cam.global_position
	if to.length() > HEAD_READ_DIST or (-cam.global_transform.basis.z).dot(to.normalized()) < HEAD_READ_DOT:
		return
	_head_read_t += delta
	if _head_read_t < HEAD_READ_TIME:
		return
	_mark_safe_note("SafeNote_Head")
	GameState.record_note(HEAD_NOTE_TEXT, 2)
	ScreenText.caption(get_tree(), HEAD_NOTE_TEXT, 3.0)


# ⭐ 2026-09-24: `_cutters_held` means the cutters have been TAKEN from the guillotine's basket.
# The old torch-aimed-at-the-floor rule under the Bedroom bed (`_tick_cutters`, `_spawn_cutters`,
# CUTTERS_PITCH_DEG, CUTTERS_DIST) is deleted with the bed hiding place.
var _cutters_held: bool = false


func _on_fridge_chain_tried() -> void:
	var fridge := get_node_or_null("Fridge")
	if fridge == null or not _cutters_held:
		return
	fridge.call("unchain")
	_log("PORCH fridge chain cut with the bolt cutters")
	_refresh_carried()


func _light_the_lock() -> void:
	if _lock_lamp_on:
		return
	_lock_lamp_on = true
	# ⚠️ Tween the GAIN, never the lamp. `_drive_lights()` writes `light_energy` every frame from
	# `base * flicker * _lock_lamp_gain`, so a tween on the lamp itself is simply overwritten on
	# the next frame — see the note there. This is the only fade the player ever sees here.
	var tw := create_tween()
	tw.tween_property(self, "_lock_lamp_gain", 1.0, LAMP_ON_FADE)
	# ⚠️ POSITIONAL, AT THE LAMP, so it is a sound from the far end of a dark house rather than an
	# announcement in your ear — and it is what tells a player standing in the cellar that
	# something happened somewhere else.
	_play_at("lamp_wake", Vector3(-0.7, 1.5, 18.75), 0.0)
	GameState.set_objective(OBJ_LOCK_LIT)


func _drive_lights() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for entry in _lights:
		var lamp: OmniLight3D = entry[0]
		var base: float = entry[1]
		# ⚠️ THE HOUSE IS DARK UNTIL EVERY NOTE IS FOUND, and then only ONE lamp answers. The
		# fitting's emission goes to zero with it — emission is most of a surface's colour in
		# this project, so an unlit diffuser left at FIXTURE_EMISSION would be the brightest
		# thing in a black room (Issue 21).
		# ⚠️⚠️ `_lock_lamp_gain`, NOT the flag, and `LAMP_ON_FADE` WAS DEAD WITHOUT IT
		# (2026-09-03). `_light_the_lock()` set `_lock_lamp_on = true` and THEN started a 2.2 s
		# tween on the lamp — but this function runs every frame and is the last writer, so from
		# the very next frame it wrote the full flicker value and the lamp snapped on in one
		# frame. Measured 0.4129 at t+0.4 s of a 2.2 s fade, i.e. 103 % of a 0.40 target, which
		# can only be `base * (1.0 + sin(...))` — this function, not the tween.
		# ⚠️ The tween now drives a 0..1 GAIN that this function multiplies in, so there is
		# exactly ONE writer of `light_energy` and the fade is real. The Lab's wing had the same
		# collision and resolved it the other way (a flag plus its own base); the shape to avoid
		# is two writers, whichever wins.
		if not _lock_lamp_on or lamp.name != "Lamp_Lock":
			lamp.light_energy = 0.0
			if entry.size() > 2 and entry[2] != null:
				(entry[2] as StandardMaterial3D).emission_energy_multiplier = 0.0
			continue
		if _child_dark:
			# THE GUEST is present: total darkness, no flicker, no exceptions. Checked before
			# the blackout branch so the two cannot fight over the same lamp.
			lamp.light_energy = 0.0
		elif _blackout_timer > 0.0:
			lamp.light_energy = base * _lock_lamp_gain \
				* (0.05 + maxf(0.0, sin(t * 33.0) * sin(t * 9.0)) * 0.15)
		else:
			# ⚠️⚠️ `* _lock_lamp_gain` IS THE FADE, AND IT WAS MISSING FOR THE WHOLE LIFE OF THE
			# FEATURE. The gain was declared, tweened 0 → 1 over `LAMP_ON_FADE`, and documented
			# twice as the thing that makes the fade real — and this function, the only writer of
			# `light_energy`, never read it. Measured: the lamp was at 0.4117 on the FIRST FRAME
			# while the gain was still 0.0031, i.e. the 2.2 s ramp drove nothing and the lamp
			# snapped on. ⚠️ The comment below still describes the design correctly; what was
			# wrong was that nothing implemented it. A tween on a variable no function reads is
			# indistinguishable from a working fade unless you sample DURING it — and
			# `check_dark_payoffs.gd` samples 3 s later, when both behaviours are identical.
			lamp.light_energy = base * _lock_lamp_gain \
				* (1.0 + sin(t * 7.0 + lamp.position.x) * 0.04)
		# Keep the visible bulb in step with the light it stands for.
		if entry.size() > 2 and entry[2] != null:
			var fixture: StandardMaterial3D = entry[2]
			var ratio: float = lamp.light_energy / base if base > 0.0 else 0.0
			fixture.emission_energy_multiplier = FIXTURE_EMISSION * ratio


func _random_room_point(y: float) -> Vector3:
	var r: Dictionary = ROOMS[randi() % ROOMS.size()]
	var c: Vector3 = _builder.room_center(r["name"])
	return Vector3(c.x, y, c.z)


func _loop_audio(base_name: String, pos: Vector3, volume_db: float) -> void:
	var stream := GameState.load_audio(base_name)
	if not stream:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = stream
	pl.volume_db = volume_db
	pl.unit_size = 6.0
	pl.max_db = 0.0
	add_child(pl)
	pl.position = pos
	pl.finished.connect(pl.play)
	pl.play()


func _play_at(base_name: String, pos: Vector3, volume_db: float = 0.0) -> void:
	var stream := GameState.load_audio(base_name)
	if not stream:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = stream
	pl.volume_db = volume_db
	pl.unit_size = 8.0
	pl.max_db = 6.0
	add_child(pl)
	pl.position = pos
	pl.finished.connect(pl.queue_free)
	pl.play()


func _box(box_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := CSGBox3D.new()
	b.name = box_name
	b.size = size
	b.position = pos
	b.use_collision = true
	if mat:
		b.material = mat
	add_child(b)
