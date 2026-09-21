extends Node3D

# ═══════════════════════════════════════════════════════════════════════════════════════
# THE VOID — level 8 (the scene is still `level_3.tscn`; its name has never matched its index).
#
# ⭐ REBUILT 2026-09-12 (the user: *"the level itself is too small, not packed with actions at
# all, so we need to restructure it completely"* — and *"I like the textures, I like the music, I
# like the vibe"*). What it was: a 15 x 15 m ring of four identical 6 x 6 rooms, ~77 m² standable,
# one room sealed off by a stray wall (a safe note, a trap note and a creature unreachable), eight
# gaps at the corridor junctions open to the sky, no loops, no floating tiles, no floor text — none
# of what `SCARY.md` §6 promised for "broken geometry" — and a camera shake every 20-60 s as the
# only scripted event.
#
# Current layout: 15 RoomBuilder rooms / 14 doorways, the original skin/music/vignette,
# a 30 m loop, and a floating causeway with a perspective-alignment island. Five fractured
# humanoids begin in the Ward; the entrance is quiet. The custom suspended furniture and
# abyss reply follow the approved 2026-09-19 human playtest. See spec/levels/08-void.md.
# Contact, the abyss, trap notes and full panic retain their lethal consequences.
#
# ⚠️ The escalating-unreality pillar: this is the last unreal level before the loop ending. Nothing
# here may become coherent; the fragments are wrong on purpose (a ward with no walls, a morgue at
# the bottom of a black corridor).
# ═══════════════════════════════════════════════════════════════════════════════════════

const _NOTE_SCRIPT := preload("res://scripts/note.gd")
const _DOOR_SCRIPT := preload("res://scripts/door.gd")
const _STALKER_SCRIPT := preload("res://scripts/creature_stalker.gd")
const _FRAGMENTS := preload("res://scripts/void_fragments.gd")
const _ALIGNMENT := preload("res://scripts/void_alignment.gd")
const _REARRANGEMENT := preload("res://scripts/void_rearrangement.gd")
const _VOID_VISUAL := preload("res://scripts/void_creature_visual.gd")
const _LOOP_NOTE_SCRIPT := preload("res://scripts/void_loop_note.gd")
const _SHARD_SCRIPT := preload("res://scripts/void_shard.gd")
const _CRADLE_SCRIPT := preload("res://scripts/void_cradle.gd")
const _PLATE_SCRIPT := preload("res://scripts/void_sanctum_plate.gd")
const _DOOR_VISUAL := preload("res://scripts/void_door_visual.gd")
const _STARE_DIRECTOR := preload("res://scripts/void_stare_director.gd")
const _ANCHOR_SCRIPT := preload("res://scripts/void_anchor.gd")
const _DRAWER_SCRIPT := preload("res://scripts/void_drawer.gd")
const _EXIT_DOOR_SCRIPT := preload("res://scripts/void_exit_door.gd")
# ⭐ 2026-09-20 pass 4: the cradle's giving scare, the secret room behind the Morgue's west
# wall, and the page at the end of it that finally moves the stone.
const _CRADLE_FIGURE := preload("res://scripts/void_cradle_figure.gd")
const _FRAME_HALL := preload("res://scripts/void_frame_hall.gd")
const _HIDDEN_NOTE_SCRIPT := preload("res://scripts/void_hidden_note.gd")
# ⭐ 2026-09-20 pass 5: the twist note's own refusal, the receipt on the Ward's gurney, and the
# rule-less figure that charges the loop corridor on the way back.
const _TWIST_NOTE_SCRIPT := preload("res://scripts/void_twist_note.gd")

const PRESERVE := ["Environment", "AmbientPlayer", "HUDCanvas", "Player"]
const TEX := "res://assets/textures/level_4_void/"

# ⚠️ AUTHORED ON AN INTEGER GRID so abutment is exact by construction (the Breach's rule): every
# room is an axis-aligned rectangle, connected rooms share an EXACT wall plane, and every doorway
# sits on it. `# x a..b  z a..b` on each row so the two invariants can be eyeballed.
const ROOMS := [
	{"name": "Threshold",    "pos": Vector2(0, 0),        "size": Vector2(8, 8)},    # x -4..4      z -4..4
	{"name": "Hall1",        "pos": Vector2(0, 7),        "size": Vector2(3, 6)},    # x -1.5..1.5  z 4..10
	{"name": "PocketA",      "pos": Vector2(-3.5, 7),     "size": Vector2(4, 3)},    # x -5.5..-1.5 z 5.5..8.5  (dead end)
	{"name": "Ward",         "pos": Vector2(0, 14),       "size": Vector2(10, 8)},   # x -5..5      z 10..18
	{"name": "Archive",      "pos": Vector2(-2, 22),      "size": Vector2(6, 8)},    # x -5..1      z 18..26    (dead end)
	{"name": "LoopIn",       "pos": Vector2(8, 15.5),     "size": Vector2(6, 3)},    # x 5..11      z 14..17
	{"name": "LoopStraight", "pos": Vector2(12.5, 29),    "size": Vector2(3, 30)},   # x 11..14     z 14..44
	{"name": "LoopOut",      "pos": Vector2(13, 46),      "size": Vector2(4, 4)},    # x 11..15     z 44..48
	{"name": "Hall2",        "pos": Vector2(7, 46),       "size": Vector2(8, 4)},    # x 3..11      z 44..48
	{"name": "TileHall",     "pos": Vector2(-3, 45.5),    "size": Vector2(12, 10)},  # x -9..3      z 40.5..50.5
	# ⚠️ x -21..-9, ABUTTING the tile hall's west wall at x = -9. The first draft put it at -18..-10,
	# a metre short: the doorway cut the hall's wall and left the morgue's own wall whole, and the
	# whole far wing measured unreachable. check_doorways now has the table and would say so.
	# ⭐ GREW 8 x 6 -> 12 x 10 on 2026-09-20 (capture #5: *"This room has basically nothing besides
	# the note. Shall we make it bigger and introduce some action here?"*). Abutment re-checked by
	# hand AND by the guards: TileHall owns x = -9 over z 40.5..50.5 and builds first, so the
	# Morgue only emits z 50.5..52.5 there (RoomBuilder dedups by INTERVAL, not by exact span);
	# the Morgue owns z = 42.5 over x -21..-9, of which Hall3's north wall is a subset; PocketB
	# tops out at z 41.5, leaving a sealed 1 m band of solid. AbyssWall_W never reaches the new
	# segment. Light_Morgue, NoteMorgue, Monitor_Morgue and CreatureD's leash all follow the rect.
	{"name": "Morgue",       "pos": Vector2(-15, 47.5),   "size": Vector2(12, 10)},  # x -21..-9    z 42.5..52.5
	# ⭐ THE SECRET ROOM (2026-09-20 pass 4). A SIXTEENTH room behind the Morgue's west wall,
	# built at _ready() like every other one and then PLUGGED, so `check_shell_sealed` is green
	# at frame 0 and the wall the player sees is a real wall. It abuts the Morgue on exactly one
	# plane (x = -21) over exactly one interval (z 44..50, a strict subset of the Morgue's
	# z 42.5..52.5), which is what RoomBuilder's interval dedup requires. ⚠️ It is listed AFTER
	# the Morgue on purpose: the first room to reach a shared plane owns it, so the Morgue emits
	# the single x = -21 wall and FrameHall emits none there.
	# ⚠️ It is OUTSIDE `DreadFarWing` (z 19.5..42.5) and outside both DarkZones — Issue 18: the
	# Hall of Frames is solved by standing still, and nothing may charge for standing still.
	{"name": "FrameHall",    "pos": Vector2(-24, 47),     "size": Vector2(6, 6)},    # x -27..-21   z 44..50
	{"name": "Hall3",        "pos": Vector2(-14, 39.5),   "size": Vector2(3, 6)},    # x -15.5..-12.5 z 36.5..42.5
	{"name": "PocketB",      "pos": Vector2(-18.5, 39.5), "size": Vector2(6, 4)},    # x -21.5..-15.5 z 37.5..41.5 (dead end)
	# ⭐ GREW 6 x 7 -> 8 x 7 on 2026-09-20 pass 3 (capture #2: *"This room is too small - let's
	# make it bigger, hard to move now"* — 42 m² holding the cradle, creature E and a DarkZone).
	# x -18..-10 is the SANCTUM's span exactly, so the shared z = 29.5 plane is one interval and
	# RoomBuilder dedups it; Hall3's z = 36.5 wall (x -15.5..-12.5) is a strict subset of the new
	# north wall; PocketB starts at z 37.5 and never touches it. Light, cradle, drawing, music
	# box, trap note and creature E all keep their world positions — `pos` did not move.
	{"name": "ChildRoom",    "pos": Vector2(-14, 33),     "size": Vector2(8, 7)},    # x -18..-10   z 29.5..36.5
	{"name": "Sanctum",      "pos": Vector2(-14, 24.5),   "size": Vector2(8, 10)},   # x -18..-10   z 19.5..29.5
]

const DOORS := [
	{"pos": Vector2(0, 4),        "width": 1.8, "dir": "z"},   # Threshold <-> Hall1
	{"pos": Vector2(-1.5, 7),     "width": 1.6, "dir": "x"},   # Hall1 <-> PocketA
	{"pos": Vector2(0, 10),       "width": 1.8, "dir": "z"},   # Hall1 <-> Ward
	{"pos": Vector2(-2, 18),      "width": 1.8, "dir": "z"},   # Ward <-> Archive
	{"pos": Vector2(5, 15.5),     "width": 1.8, "dir": "x"},   # Ward <-> LoopIn
	{"pos": Vector2(11, 15.5),    "width": 1.8, "dir": "x"},   # LoopIn <-> LoopStraight
	{"pos": Vector2(12.5, 44),    "width": 1.8, "dir": "z"},   # LoopStraight <-> LoopOut
	# ⚠️ 46.7, not the wall centre: LoopOut's two doorways are 1.5 m from a shared corner and their
	# floor bridges (1.3 m each side) overlapped coplanar (Issue 43's shape). Moving this one
	# north takes the two bridges out of each other's footprint.
	{"pos": Vector2(11, 46.7),    "width": 1.8, "dir": "x"},   # LoopOut <-> Hall2
	{"pos": Vector2(3, 45.5),     "width": 1.8, "dir": "x"},   # Hall2 <-> TileHall
	{"pos": Vector2(-9, 45.5),    "width": 1.8, "dir": "x"},   # TileHall <-> Morgue
	# ⭐ The secret doorway. Filled by `SecretPlug` from _ready() until the cradle is completed.
	{"pos": Vector2(-21, 47.5),   "width": 1.8, "dir": "x"},   # Morgue <-> FrameHall (PLUGGED)
	{"pos": Vector2(-14, 42.5),   "width": 1.8, "dir": "z"},   # Morgue <-> Hall3
	{"pos": Vector2(-15.5, 39.5), "width": 1.6, "dir": "x"},   # Hall3 <-> PocketB
	{"pos": Vector2(-14, 36.5),   "width": 1.8, "dir": "z"},   # Hall3 <-> ChildRoom
	{"pos": Vector2(-14, 29.5),   "width": 1.8, "dir": "z"},   # ChildRoom <-> Sanctum
]

const ROOM_H := 3.3
const SHAKE_MIN := 20.0
const SHAKE_MAX := 60.0

# ── the loop ──
const LOOP_PERIOD := 15.0       # the corridor repeats every 15 m; the seam sends you back exactly one period
const LOOP_TRIGGER_Z := 32.0    # 60 % of the 30 m run
const LOOP_NOTE_Z := 23.0
const LOOP_CREEP := 2.0         # how much closer the far-end stalker is after each lap
const LOOP_STALKER_Z := 41.0
const LOOP_LAMP_ENERGY := 0.22  # the corridor lamps' rest level; the flicker returns them here

# ── the quest: three carried anchors (2026-09-20 pass 3) ──
#
# ⚠️ Each row's `at` is where the object LIES, and every one of them had to clear a solid
# collider for the E-ray to reach it (the ray takes the nearest hit):
#   handle  PocketA's west wall, beside the trap note, through wall_point()
#   slat    at the open mouth of FoldedFrame_Ward_L (-2.6, 14.5) — the frame's own collider is
#           1.25 x 1.85 x 1.65 centred on it, so the slat lies 5 cm clear of its south face
#   latch   inside Hall2's flat doorframe (7.0, 44.7), which has NO collider at all — and
#           which is the step-through, so the 1.2 s clock runs while you bend down for it
const ANCHORS := [
	{"id": "handle", "label": "a door handle", "family": "violet",
		"at": Vector3(0, 0.14, 0), "yaw": 1.1, "pose": Vector3(-1.35, 0.0, 0.25), "room": "PocketA"},
	{"id": "slat", "label": "a bed slat", "family": "bone",
		"at": Vector3(-2.52, 0.10, 13.60), "yaw": 0.22, "pose": Vector3(-1.5, 0.0, 0.0), "room": ""},
	{"id": "latch", "label": "a window latch", "family": "verdigris",
		"at": Vector3(7.08, 0.11, 44.62), "yaw": -0.5, "pose": Vector3(-1.45, 0.0, 0.6), "room": ""},
]

# ── STEP THROUGH: Hall2's flat doorframe drops you out of a second one in LoopIn ──
const STEP_FRAME_HALL2 := Vector3(7.0, 0, 44.7)
const STEP_FRAME_LOOPIN := Vector3(8.0, 0, 15.3)
const STEP_DWELL := 1.2          # seconds of continuous standing inside the frame

# ── SEARCH: which of the Morgue's seventeen drawers holds the page ──
# ⚠️ DETERMINISTIC AND NEVER HINTED. Column 4 of 6 counted from the doorway side, middle row:
# the bank stands along the north wall with column 0 nearest the way in, so this is the
# second-furthest column — four drawers of nothing before the one that pays, from either end.
const PAGE_DRAWER := Vector2i(4, 1)

# ⭐ ONE DRAWER STARTS PULLED (2026-09-20 pass 4). The 18:30 run pulled NONE of the seventeen in
# 413 s: the bank shows a drawer already OUT on the floor (`LongDrawer_Morgue`) but never a
# drawer that can be pulled, so nothing in the room says the fronts are a moving part. Column 2,
# middle row — visible from the way in, deterministic, and ⚠️ NEVER the page's 4_1, or the search
# is over before it starts.
const OPEN_DRAWER := Vector2i(2, 1)

# ── the secret door (2026-09-20 pass 4) ──
# ⚠️ 1.80 m, not 1.82. `LoopWallPlug` learned this the expensive way: at 1.82 the plug overlaps
# each jamb by 1 cm with coincident x-faces and `check_wall_overlap` reports it. RoomBuilder's
# doorways are full height, so 0.2 x 3.3 x 1.80 fills the opening EXACTLY and every face abuts.
const SECRET_DOOR := Vector3(-21.0, 1.65, 47.5)
const SECRET_PLUG_SIZE := Vector3(0.2, ROOM_H, 1.8)

# ── the Hall of Frames ──
# A fixed base, offset by the level's attempt count, so a fresh load scrambles differently after
# a death and a harness can pin it. The PERMUTATION is what `save_progress()` stores, not this.
const FRAME_SEED_BASE := 80920

# ── the tile hall ──
const TILE := 1.6
const TILE_T := 0.3
const BEAM_W := 1.0
const ABYSS_Y := -8.0
const FALL_Y := -4.0

var _builder: RoomBuilder
var _stalkers: Dictionary = {}       # "B".."F" -> CreatureStalker
var _notes_read: Array = []
var _loop_broken := false
var _loop_laps := 0
var _loop_stalker_z: float = LOOP_STALKER_Z
var _tile_rect := Rect2()
var _shake_timer := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _world_env: WorldEnvironment = null
var _alignment: StaticBody3D
var _ward_fragment: StaticBody3D
var _loop_note: StaticBody3D
var _loop_plug: StaticBody3D
var _shard: StaticBody3D
var _cradle: StaticBody3D
var _sanctum_plate: StaticBody3D
var _prop_fragments: Array = []      # the arm-on-sight rearrangers (door heap, inverted table)
var _shard_taken := false
var _cradle_done := false
# ⭐ THE LEVEL'S OWN INVENTORY (2026-09-20 pass 3). `GameState.carried_item` is a COMPOSED HUD
# line here ("a stone shard · a door handle"), because the shard and one anchor can be held at
# the same time — so nothing may test it for equality with a key any more. The shard, the
# cradle and the three sockets all ask this level instead.
var _carried_anchor := ""            # "" | "handle" | "slat" | "latch"
var _anchors_taken: Array = []       # ids no longer lying in the world
var _anchors: Dictionary = {}        # id -> the body still lying in the world
var _drawers: Array = []             # the Morgue's seventeen fronts
var _page_drawer: Node = null
var _drawer_page: StaticBody3D = null
var _inverted_table: Node3D = null
var _step_area: Area3D = null
var _step_dwell := 0.0
var _step_drop: AudioStreamPlayer3D = null
var _step_drops := 0
# ── the loop's return beats (2026-09-20 pass 2) ──
var _loop_slam: AudioStreamPlayer3D
var _plug_grind: AudioStreamPlayer3D
var _south_whisper: AudioStreamPlayer3D
var _echo_player: AudioStreamPlayer3D
var _flicker: Tween
var _lamp_dead: Dictionary = {}       # lamp name -> already logged
var _echo_step := 0.0                 # the player's step clock inside the corridor
var _echo_due := -1.0                 # seconds until the queued echo plays, or < 0
var _echo_at := Vector3.ZERO
var _echo_announced := false
var _loop_rect := Rect2()
# ── pass 4: the secret door, the giving scare, the Hall of Frames ──
var _secret_plug: StaticBody3D = null
var _secret_bridge: Node3D = null     # the doorway's 4 mm floor bridge, hidden until it opens
var _secret_grind: AudioStreamPlayer3D = null
var _secret_open := false
var _cradle_sting: AudioStreamPlayer3D = null
var _lunge_spent := false
var _protect_restore := -1.0          # seconds left of creature E's suppression, or < 0
var _drawing_swap_armed := false
var _drawing_swapped := false
var _frame_hall: Node3D = null
var _hidden_note: StaticBody3D = null
var _twist_note: StaticBody3D = null
# ── pass 5: the corridor charge ──
var _charge_area: Area3D = null
var _charge_sting: AudioStreamPlayer3D = null
var _charge_done := false
var _charge_protect := -1.0           # seconds left of creature C's suppression, or < 0
var _loop_swap_leg: Node3D = null     # P.T.'s one discrete change per lap, at z 27
var _loop_swap_page: Node3D = null
var _loop_swap_stage := -1
var _step_bars: Array = []            # Hall2's flat frame, the bars that lean into the dwell
var _step_bar_rest: Array = []
var _ward_grind: AudioStreamPlayer3D = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.current_level = 8
	_clear_old_scene()
	_black_background()
	_build_geometry()
	_build_secret_door()
	_build_tile_hall()
	_build_loop()
	_build_fragments()
	_spawn_lights()
	_alignment = _ALIGNMENT.new()
	_alignment.name = "AlignmentKeystone"
	add_child(_alignment)
	_spawn_notes()
	_build_frame_hall()
	_spawn_chain()
	_spawn_stalkers()
	# ⭐ THE STARE DIRECTOR (2026-09-20): the hallucination ladder for a stare held past the dismissal.
	var director: Node = _STARE_DIRECTOR.new()
	director.name = "StareDirector"
	add_child(director)
	_spawn_zones()
	_spawn_level_doors()
	_place_player()
	_start_ambience()
	_reset_shake_timer()
	Vignette.spawn(self, Color(0.65, 0.55, 1.0, 1.0), 2.0)
	RandomAmbient.register_player(_player())
	GameState.set_objective("Find the truth — read the note that doesn't belong")
	_restore_progress()


func _player() -> CharacterBody3D:
	return get_node_or_null("Player") as CharacterBody3D


# Playtest instrumentation. Nothing in level_3.gd / void_alignment.gd / creature_stalker.gd
# wrote a single line before 2026-09-20, so a log could not distinguish "the loop never fired"
# from "the loop fired and the player did not notice" — and that was exactly the question.
# Strips cleanly with the autoload.
func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _clear_old_scene() -> void:
	for child in get_children():
		if PRESERVE.has(child.name):
			continue
		# ⚠️ remove_child BEFORE queue_free (Issue 17): the dying node still owns its NAME.
		remove_child(child)
		child.queue_free()


# ── geometry ────────────────────────────────────────────────────────────────────
func _build_geometry() -> void:
	_builder = RoomBuilder.new()
	_builder.name = "Rooms"
	_builder.wall_height = ROOM_H
	# The user's textures, kept: black stone with violet cracks on every wall AND the ceilings
	# (which were untextured before), the void floor underfoot. Triplanar, so nothing stretches.
	_builder.wall_mat = RoomBuilder.make_material(TEX + "wall_void.png", Vector3(0.28, 0.28, 0.28), Color(0.06, 0.05, 0.08))
	_builder.floor_mat = RoomBuilder.make_material(TEX + "floor_void.png", Vector3(0.3, 0.3, 0.3), Color(0.05, 0.05, 0.07))
	_builder.ceil_mat = RoomBuilder.make_material(TEX + "wall_void.png", Vector3(0.28, 0.28, 0.28), Color(0.05, 0.04, 0.07))
	add_child(_builder)
	_builder.build(ROOMS, DOORS)


# ⭐ THE SECRET DOOR (2026-09-20 pass 4). *"A secret door (not in the same room, somewhere in the
# level map) opens. You could not see that door until it was opened."*
#
# ⚠️ A DOOR THAT APPEARS IS A WALL THAT WAS SOLID. The room and its doorway are built by
# `RoomBuilder` at `_ready()` exactly like the other fifteen — so the abutment, the dedup and the
# floor bridge are all the shipping path — and the OPENING is then filled with a plug in the
# wall's own material instance. `check_shell_sealed` is green from frame 0 and the Morgue's west
# wall is, physically, a wall.
# ⚠️ AND THE 4 mm FLOOR BRIDGE IS HIDDEN WITH IT. RoomBuilder sinks every doorway's bridge by
# BRIDGE_SINK so it cannot z-fight the room floors; here the two floors abut exactly at x = -21
# and cover it completely, so it is invisible by construction — but it is hidden anyway, because
# "invisible by construction" is a property of THIS pair of room footprints and a later edit to
# either one would quietly turn it into a seam that says *door here*. Collision is untouched
# (the two room floors carry it), which `check_void` proves with a downward ray in both states.
func _build_secret_door() -> void:
	_secret_bridge = _find_door_bridge(Vector2(SECRET_DOOR.x, SECRET_DOOR.z))
	if _secret_bridge:
		_secret_bridge.visible = false
	var body := StaticBody3D.new()
	body.name = "SecretPlug"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = SECRET_DOOR
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "SecretPlugFace"
	var bm := BoxMesh.new()
	bm.size = SECRET_PLUG_SIZE
	mi.mesh = bm
	mi.set_surface_override_material(0, _builder.wall_mat)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = SECRET_PLUG_SIZE
	col.shape = sh
	body.add_child(col)
	_secret_plug = body
	# The answer from three rooms away. `stone_grind` is -10.3 dBFS RMS, the level's "a wall
	# moved" sound; from the cradle at (-15.75, 34.3) to this doorway is 14.2 m, so -6.0 dB at
	# unit 8.0 lands ~-11 dB at that distance: a distant grind, not a thing in the room.
	_secret_grind = _audio_at("SecretGrind", "stone_grind", SECRET_DOOR, -6.0, 8.0)


# ⚠️ FOUND BY GEOMETRY, NEVER BY NAME — and that is a measured fact, not caution. RoomBuilder
# calls every bridge "DoorFloor", and Godot 4 does NOT suffix a duplicate name as "DoorFloor2":
# it replaces it entirely with the class-based auto name, so the fifteen bridges in this level
# are one `DoorFloor` and fourteen `@CSGBox3D@NN`. A name filter found exactly one of them (the
# Threshold's) and silently returned null here. The bridges are the only boxes the builder sinks
# below y 0 (`BRIDGE_SINK` 4 mm under a floor slab whose own centre is at -T/2), which makes
# depth the honest key.
func _find_door_bridge(at: Vector2) -> Node3D:
	var sunk := -RoomBuilder.T / 2.0 - RoomBuilder.BRIDGE_SINK
	var best: Node3D = null
	var best_d := 0.35
	for c in _builder.get_children():
		if not (c is CSGBox3D):
			continue
		var p: Vector3 = (c as Node3D).position
		if absf(p.y - sunk) > 0.001:
			continue
		var d: float = Vector2(p.x, p.z).distance_to(at)
		if d < best_d:
			best_d = d
			best = c as Node3D
	return best


# Freed by `cradle.completed`, and by nothing else. ⚠️ `move_aside_instantly()` is
# `check_reachable.gd`'s gate hook: the sweep asks the level to put itself into the state a
# player reaches instead of deleting a collider behind its back (the LabLocker rule).
func _open_secret_door() -> void:
	if _secret_open:
		return
	_secret_open = true
	if _secret_bridge and is_instance_valid(_secret_bridge):
		_secret_bridge.visible = true
	if _secret_plug and is_instance_valid(_secret_plug):
		_secret_plug.queue_free()
	_secret_plug = null
	if _secret_grind:
		_secret_grind.play()
	_dbg("VOID secret door OPENED — the Morgue's west wall at %v" % SECRET_DOOR)


func _open_secret_door_instantly() -> void:
	if _secret_open:
		return
	_secret_open = true
	if _secret_bridge and is_instance_valid(_secret_bridge):
		_secret_bridge.visible = true
	if _secret_plug and is_instance_valid(_secret_plug):
		_secret_plug.queue_free()
	_secret_plug = null


# ⭐ THE TILE HALL. RoomBuilder builds the room normally; its floor slab is then FREED (the
# `_break_room_c_floor()` precedent, and the builder names floors `<room>_Floor`) and a causeway
# of tiles joined by beams crosses the abyss from door to door, forking round a central island.
# ⚠️ The player cannot jump, so the route is EDGE-CONNECTED; the abyss lies beside it. A black
# slab at ABYSS_Y stops rays (no sky, no shell exemption) while `_check_void_fall()` fires at
# FALL_Y first. The doorway floor bridges (`DoorFloor`) stay as landing pads.
func _build_tile_hall() -> void:
	var fl := _builder.get_node_or_null("TileHall_Floor")
	if fl:
		fl.free()
	var r := _room_rect("TileHall")
	_tile_rect = r
	# The causeway, in world XZ: east pad -> spine -> fork -> west pad.
	var spine := [Vector2(1.4, 45.5), Vector2(-0.2, 45.5)]
	var north := [Vector2(-1.8, 47.0), Vector2(-3.6, 48.2), Vector2(-5.6, 47.4), Vector2(-7.0, 46.5)]
	var south := [Vector2(-1.8, 44.0), Vector2(-3.6, 42.8), Vector2(-5.6, 43.6), Vector2(-7.0, 44.5)]
	var tiles: Array = spine + north + south
	var i := 0
	for t in tiles:
		_tile(t, "Tile_%d" % i)
		i += 1
	# Beams between consecutive tiles on each branch (the pads at x 1.7 and -7.7 are the bridges).
	var chains := [
		[Vector2(1.7, 45.5)] + spine + [north[0]], north, [north[3], Vector2(-7.7, 45.5)],
		[spine[1], south[0]], south, [south[3], Vector2(-7.7, 45.5)],
	]
	# A wider, stable island, separated from the branch tiles to avoid coplanar tops.
	var platform := CSGBox3D.new()
	platform.name = "ObservationIsland"
	platform.size = Vector3(2.0, TILE_T, 2.2)
	platform.position = Vector3(-3.6, -TILE_T * 0.5, 45.5)
	platform.material = _builder.floor_mat
	platform.use_collision = true
	add_child(platform)
	chains.append([spine[1], Vector2(-3.6, 45.5)])
	chains.append([north[1], Vector2(-3.6, 45.5)])
	chains.append([south[1], Vector2(-3.6, 45.5)])
	var j := 0
	for chain in chains:
		for k in range(chain.size() - 1):
			_beam(chain[k], chain[k + 1], "Beam_%d" % j)
			j += 1
	# The abyss: a black PIT under the hall — floor far below and four black walls from the room's
	# floor level down to it, INSIDE the room's footprint, so every ray from anywhere in the pit is
	# stopped and check_shell_sealed's sweep (which treats that floor as a storey) sees a sealed box.
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0, 0, 0)
	am.roughness = 1.0
	var cx: float = r.position.x + r.size.x * 0.5
	var cz: float = r.position.y + r.size.y * 0.5
	var w: float = r.size.x - 0.2
	var d: float = r.size.y - 0.2
	var depth: float = -ABYSS_Y
	var pit := [
		["Abyss_TileHall", Vector3(w, 0.3, d), Vector3(cx, ABYSS_Y, cz)],
		["AbyssWall_W", Vector3(0.2, depth, d), Vector3(cx - w * 0.5 - 0.1, ABYSS_Y * 0.5, cz)],
		["AbyssWall_E", Vector3(0.2, depth, d), Vector3(cx + w * 0.5 + 0.1, ABYSS_Y * 0.5, cz)],
		["AbyssWall_S", Vector3(w + 0.4, depth, 0.2), Vector3(cx, ABYSS_Y * 0.5, cz - d * 0.5 - 0.1)],
		["AbyssWall_N", Vector3(w + 0.4, depth, 0.2), Vector3(cx, ABYSS_Y * 0.5, cz + d * 0.5 + 0.1)],
	]
	for spec in pit:
		var b := CSGBox3D.new()
		b.name = spec[0]
		b.size = spec[1]
		b.position = spec[2]
		b.use_collision = true
		b.material = am
		add_child(b)


func _tile(at: Vector2, nm: String) -> void:
	var t := CSGBox3D.new()
	t.name = nm
	t.size = Vector3(TILE, TILE_T, TILE)
	t.position = Vector3(at.x, -TILE_T * 0.5, at.y)
	t.use_collision = true
	t.material = _builder.floor_mat
	add_child(t)


# ⚠️ A beam spans only the GAP plus 0.4 m into each tile, and its top sits BEAM_SINK under the
# tiles': two beams meeting at a tile no longer overlap each other, and a beam never shares its
# top plane with a tile (28 z-fights on the first build). 6 mm is far under a step.
const BEAM_SINK := 0.006


func _beam(a: Vector2, b: Vector2, nm: String) -> void:
	var d := b - a
	var beam := CSGBox3D.new()
	beam.name = nm
	beam.size = Vector3(maxf(0.6, d.length() - 0.8), TILE_T, BEAM_W)
	var mid := (a + b) * 0.5
	beam.position = Vector3(mid.x, -TILE_T * 0.5 - BEAM_SINK, mid.y)
	beam.rotation.y = -atan2(d.y, d.x)
	beam.use_collision = true
	beam.material = _builder.floor_mat
	add_child(beam)


# ⭐ THE LOOP. `LoopStraight` runs 30 m north (z 14..44). A seam at LOOP_TRIGGER_Z sends the
# player back exactly one LOOP_PERIOD, PRESERVING heading and velocity (unlike backrooms.gd's
# `_teleport()`, which zeroes it — seamlessness needs the stride to continue), while the note at
# LOOP_NOTE_Z is unread. The dressing repeats every LOOP_PERIOD so the view after the seam matches
# the view before it. The stalker at the far end is LOOP_CREEP closer after every lap.
func _build_loop() -> void:
	var seam := Area3D.new()
	seam.name = "LoopSeam"
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.0, ROOM_H, 0.8)
	col.shape = sh
	seam.add_child(col)
	seam.position = Vector3(12.5, ROOM_H * 0.5, LOOP_TRIGGER_Z)
	seam.collision_layer = 0
	seam.collision_mask = 1
	add_child(seam)
	seam.body_entered.connect(_on_loop_seam)
	_loop_rect = _room_rect("LoopStraight")
	_build_loop_audio()
	_build_corridor_charge()
	# The dressing: a stain and a pipe stub on the east wall every 5 m, identical per period.
	var stain := StandardMaterial3D.new()
	stain.albedo_color = Color(0.03, 0.02, 0.05)
	stain.roughness = 1.0
	var pipe := StandardMaterial3D.new()
	pipe.albedo_color = Color(0.18, 0.16, 0.22)
	pipe.roughness = 0.6
	pipe.metallic = 0.3
	for z in [17.0, 22.0, 27.0, 32.0, 37.0, 42.0]:
		var mi := MeshInstance3D.new()
		mi.name = "LoopStain_%d" % int(z)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.9, 1.3)
		mi.mesh = qm
		mi.set_surface_override_material(0, stain)
		mi.position = Vector3(14.0 - 0.1 - 0.03, 1.5, z)
		mi.rotation.y = -PI / 2.0
		add_child(mi)
		var p := MeshInstance3D.new()
		p.name = "LoopPipe_%d" % int(z)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 1.2
		p.mesh = cm
		p.set_surface_override_material(0, pipe)
		p.position = Vector3(11.0 + 0.1 + 0.08, 2.6, z + 2.5)
		p.rotation.z = PI / 2.0
		p.rotation.y = PI / 2.0
		add_child(p)


# ⭐ THE CORRIDOR CHARGE (2026-09-20 pass 5). Capture #4, standing in the loop corridor on the
# walk back for the bed slat: *"we inevitably need to run back in this corridor… add some scary
# thing in the corridor when we go back — like a sudden jumpscare with 3d animation."* The
# corridor is 30 m long, it is walked at least three times, and after its note is read it is the
# emptiest place in the level: the loop is broken, C has stopped creeping, nothing happens.
#
# The beat: the FIRST time you enter the north end heading SOUTH with the loop already broken, a
# rule-less figure is standing 25 m away at the far end under the lamp the ladder killed, with
# its back to you. It turns over 0.25 s and covers the corridor in 1.0 s, stopping 0.6 m from
# the camera with the shared `jumpscare`, and it is gone.
#
# ⚠️ ZERO PANIC. Nothing in the beat touches `_panic`: no `ScaryObject`, no collider, no gaze
# cost, and the corridor carries no DarkZone or DreadZone to charge for standing in it.
# ⚠️ IT IS NOT A SIXTH PURSUER. SCARY.md §8.4 allows ONE chase level in twelve and this is not
# it; `check_void_frames.gd` walks the figure's subtree and asserts no collider and no
# `ScaryObject`, which is what keeps a photograph from becoming a creature.
# ⚠️ NOT ON THE FIRST (NORTHBOUND) PASS. It answers the walk BACK, which is the leg the capture
# is about — and a figure that charges you on the way in would just be the corridor's greeting.
# ⚠️ CREATURE C IS HELD OFF for the beat + 1 s, with the tile hall's own mechanism
# (`protected_player_rect`), because C stands in this corridor and a figure filling the frame
# while a lethal stalker walks up behind you is §8.11's coin flip. RESTORED to `_tile_rect`,
# never cleared (the cradle lunge's rule).
# ⚠️ ONE SHOT, saved as `corridor_charge_done`, and `_restore_progress()` never replays it.
const CHARGE_AREA_POS := Vector3(12.5, ROOM_H * 0.5, 42.0)   # x 11..14, z 41..43
const CHARGE_AREA_SIZE := Vector3(3.0, ROOM_H, 2.0)
const CHARGE_FIGURE_AT := Vector3(12.5, 0.0, 16.5)           # under Light_Loop_19, 25 m south
const CHARGE_SOUTHBOUND := -0.5                              # m/s of -z that counts as "going back"


func _build_corridor_charge() -> void:
	_charge_area = Area3D.new()
	_charge_area.name = "CorridorCharge"
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = CHARGE_AREA_SIZE
	col.shape = sh
	_charge_area.add_child(col)
	_charge_area.position = CHARGE_AREA_POS
	_charge_area.collision_layer = 0
	_charge_area.collision_mask = 1
	add_child(_charge_area)


# ⚠️ POLLED, not `body_entered`. A signal fires on the crossing and on nothing else, so a player
# who walks in northbound, turns round inside the box and walks out south would never arm it —
# and "turn round in the corridor" is exactly what this beat is about. Overlap + heading is a
# superset of "entered southbound" and cannot miss it.
func _tick_corridor_charge() -> void:
	if _charge_done or _charge_area == null or not _loop_broken:
		return
	var p := _player()
	if p == null or not _charge_area.overlaps_body(p):
		return
	if p.velocity.z > CHARGE_SOUTHBOUND:
		return
	_fire_corridor_charge()


func _fire_corridor_charge() -> void:
	if _charge_done:
		return
	_charge_done = true
	var p := _player()
	if p == null:
		return
	if _charge_sting == null:
		_charge_sting = _make_sting("ChargeSting")
	var c = _stalkers.get("C", null)
	if c and is_instance_valid(c):
		c.set("protected_player_rect", _loop_rect)
		_charge_protect = _CRADLE_FIGURE.TURN_TIME + _CRADLE_FIGURE.CHARGE_TIME \
			+ _CRADLE_FIGURE.LINGER + 1.0
	var fig := _CRADLE_FIGURE.new() as Node3D
	fig.name = "ChargeFigure"
	add_child(fig)
	fig.call("arm_charge", p, CHARGE_FIGURE_AT, _charge_sting)
	_dbg("VOID corridor charge FIRED (player at %v, figure at %v)"
		% [p.global_position, CHARGE_FIGURE_AT])


func _tick_charge_protection(delta: float) -> void:
	if _charge_protect < 0.0:
		return
	_charge_protect -= delta
	if _charge_protect > 0.0:
		return
	_charge_protect = -1.0
	var c = _stalkers.get("C", null)
	if c and is_instance_valid(c):
		c.set("protected_player_rect", _tile_rect)


# ⭐ THE RETURN BEATS (2026-09-20 pass 2). The 13:10 playtester looped twice and wrote
# *"introduce more actions when you are getting returned — weird sounds, some things related
# to lights"*. Every send-back now slams the doorway behind you and pulses both lamps; lap 2
# grinds the wall into place; lap 3 answers your own footsteps. ⚠️ ZERO PANIC on all of it —
# these are channels, not terms (GAME_MECHANICS_IDEAS' governing finding).
#
# ⚠️ Gains are set from the FILES' measured levels, not from plausible numbers:
# loop_slam RMS -17.7 dBFS, stone_grind -10.3 (the loudest of the three, so the quietest
# gain), stalker_whisper -19.2 (the same -38..-8 window creature_stalker.gd uses).
func _build_loop_audio() -> void:
	_loop_slam = _audio_at("LoopSlam", "loop_slam", Vector3(11.0, 1.5, 15.5), -3.0, 14.0)
	_plug_grind = _audio_at("PlugGrind", "stone_grind", Vector3(11.0, 1.65, 15.5), -8.0, 6.0)
	# ⭐ THE WHISPER FROM BOTH ENDS (lap 2+). Creature C is at the corridor's far end; this is
	# the same sample at the end you came IN by, riding C's own stare envelope, so a stare held
	# on the thing in front of you is answered from behind as well. It carries NO detection and
	# NO panic: `whisper_level()` is already paid for by looking.
	_south_whisper = _audio_at("LoopWhisperSouth", "stalker_whisper", Vector3(12.5, 0.9, 15.0),
		-38.0, 10.0)
	if _south_whisper and _south_whisper.stream:
		# Every .wav.import in this project is loop_mode=0 — the loop is re-triggered from
		# `finished`, the scrape's idiom (creature_stalker.gd:_tick_whisper).
		_south_whisper.finished.connect(_south_whisper.play)
	# ⚠️ unit_size 2.0 and max_db 0.0 so that at the echo's fixed 2 m the gain is exactly
	# 1.0 and the -14 dB is the level you actually hear. At the default unit_size 10 the
	# inverse-distance curve would have added +14 dB and clamped at max_db.
	_echo_player = _audio_at("LoopFootstepEcho", "footstep", Vector3.ZERO, -14.0, 2.0)
	if _echo_player:
		_echo_player.max_db = 0.0


func _audio_at(nm: String, base: String, at: Vector3, db: float, unit: float) -> AudioStreamPlayer3D:
	var s := GameState.load_audio(base)
	if s == null:
		return null
	var pl := AudioStreamPlayer3D.new()
	pl.name = nm
	pl.stream = s
	pl.position = at
	pl.volume_db = db
	pl.unit_size = unit
	pl.bus = AudioBuses.AMBIENCE
	add_child(pl)
	return pl


# Five pulses over one second on BOTH corridor lamps, whatever state the ladder has left them
# in — a lamp already killed by an earlier lap comes back for the flicker and then dies again,
# which is the beat. `_apply_loop_ladder()` is the tween's last step, so the ladder always has
# the final word on every lamp's energy.
func _flicker_loop_lamps() -> void:
	var lamps: Array[OmniLight3D] = []
	for nm in ["Light_Loop_19", "Light_Loop_34"]:
		var l := get_node_or_null(nm) as OmniLight3D
		if l:
			lamps.append(l)
	if lamps.is_empty():
		return
	if _flicker:
		_flicker.kill()
	_dbg("VOID loop lamps flicker (%d lamps, lap %d)" % [lamps.size(), _loop_laps])
	_flicker = create_tween()
	for i in range(5):
		var hi: float = 0.34 if i % 2 == 0 else 0.26
		_flicker.tween_callback(_set_lamps.bind(lamps, hi))
		_flicker.tween_interval(0.10)
		_flicker.tween_callback(_set_lamps.bind(lamps, 0.0))
		_flicker.tween_interval(0.10)
	# ⚠️ THE FLICKER MUST HAND THE LAMPS BACK. Its last pulse leaves them at 0, and
	# `_apply_loop_ladder()` only ever turns lamps OFF — so without this restore, one second
	# of stutter permanently killed `Light_Loop_19` on lap 1, four laps before it should die.
	# Measured by check_void: "the near lamp is alive again once the flicker ends" went red.
	# Restore first, then let the ladder have the final word on whichever lamps are dead.
	_flicker.tween_callback(_set_lamps.bind(lamps, LOOP_LAMP_ENERGY))
	# ⚠️ The ladder runs at the END TOO, to settle the lamps — but it also ran immediately,
	# from `_on_loop_seam`'s `call_deferred`. It must NOT be moved to only run here: the note's
	# lap counter, the wall plug and the stains all come from the ladder, and delaying them by
	# a second put the world one beat behind the beat the player just triggered.
	_flicker.tween_callback(_apply_loop_ladder)


func _set_lamps(lamps: Array, energy: float) -> void:
	for l in lamps:
		if is_instance_valid(l):
			(l as OmniLight3D).light_energy = energy


func _on_loop_seam(body: Node) -> void:
	var p := _player()
	if body != p or _loop_broken or p == null:
		return
	if p.velocity.z <= 0.0:
		return   # walking back out of the loop is allowed
	p.global_position.z -= LOOP_PERIOD
	_loop_laps += 1
	_dbg("VOID loop lap %d (seam at z %.0f)" % [_loop_laps, LOOP_TRIGGER_Z])
	# The far-end stalker creeps closer: it is the corridor's clock.
	var c = _stalkers.get("C", null)
	if c and is_instance_valid(c) and not bool(c.call("has_fallen")):
		_loop_stalker_z = maxf(LOOP_NOTE_Z + 4.0, _loop_stalker_z - LOOP_CREEP)
		var body3: Node3D = c.get("_body")
		if body3:
			c.relocate_safely(Vector3(body3.global_position.x, 0.0, _loop_stalker_z))
	_drop_torn_page(_loop_laps)
	if _loop_laps == 2:
		ScreenText.scrawl(get_tree(), "AGAIN.", 3.0)
	# ⭐ EVERY send-back, not just the first: the door you came through slams behind you and
	# both lamps stutter for a second. The ladder's lamp deaths are the flicker's last step.
	if _loop_slam:
		_loop_slam.play()
	_flicker_loop_lamps()
	# ⚠️ DEFERRED. The plug is a StaticBody3D, and adding a body from inside an Area3D's
	# `body_entered` callback is adding a collider during the physics flush.
	call_deferred("_apply_loop_ladder")


func _drop_torn_page(n: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "TornPage_%d" % n
	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.24)
	mi.mesh = qm
	mi.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(false))
	mi.position = Vector3(12.5 + (0.6 if n % 2 == 0 else -0.6), 0.012, LOOP_NOTE_Z - 1.2 - 0.5 * n)
	mi.rotation.x = -PI / 2.0
	mi.rotation.z = 0.4 * n
	add_child(mi)


# ⭐ THE LOOP LADDER (2026-09-20). Every rung is IDEMPOTENT and derived purely from
# `_loop_laps` / `_loop_broken`, so the seam, a snapshot restore and a test that sets the lap
# count by hand all converge on the same world. ⚠️ ZERO PANIC on every rung — the corridor
# charges time, not health.
#
#   lap >= 1   the far lamp dies (plus the torn page dropped by the seam itself)
#   lap >= 2   `AGAIN.`, the way back is WALLED UP, and the note becomes legible
#   lap >= 3   the near lamp dies and the wall stains rise to head height
func _apply_loop_ladder() -> void:
	if _loop_note and is_instance_valid(_loop_note):
		_loop_note.set("laps", _loop_laps)
		# ⭐ THE PAGE IS NOT THERE UNTIL LAP 2 (2026-09-20 pass 2). It used to hang at z 23
		# from the first step into the corridor with a prompt that refused it — capture #2:
		# *"weird that I can see this note but I cannot pick it up"*. It has no mesh and no
		# collider now until the corridor has actually repeated twice, and it arrives with a
		# paper-drop from its own position. `reveal()` is idempotent and derived from the lap
		# count, so a snapshot restore lands in the same world as the seam does.
		if _loop_laps >= 2:
			_loop_note.call("reveal")
	_apply_loop_swap()
	if _loop_laps >= 1:
		_kill_loop_lamp("Light_Loop_34")
	if _loop_laps >= 2 and not _loop_broken:
		_build_loop_plug()
	if _loop_laps >= 3:
		_kill_loop_lamp("Light_Loop_19")
		for child in get_children():
			if String(child.name).begins_with("LoopStain_") and child is Node3D:
				(child as Node3D).position.y = 1.75


# ⭐ P.T.'s SWAPPED OBJECT (2026-09-20 pass 4). The corridor's per-lap tells were lamps and
# stains — state changes on things already there. P.T.'s cheapest and strongest tell is ONE
# DISCRETE OBJECT SWAPPED against a remembered baseline, and this loop had none.
#
# One spot, z 27, three states: a wall stain (lap 0) → a chair leg hung on a thread (lap 1) → a
# hand-sized page pinned where the stain was (lap 2+). ⚠️ ONE change per lap, never a redress:
# the rest of the 5 m dressing is byte-identical, which is the whole reason a single swap reads.
# ⚠️ IDEMPOTENT and derived purely from `_loop_laps`, like every other rung, so the seam, a
# snapshot restore and a test that sets the lap count by hand land in the same corridor.
# ⚠️ Built LAZILY. Both objects exist only once their lap has happened — at frame 0 there is
# nothing extra in the scene for `check_art_aspect` or the geometry guards to measure, which is
# the same treatment `_drop_torn_page()` gets.
const LOOP_SWAP_Z := 27.0


func _apply_loop_swap() -> void:
	var stage: int = 0 if _loop_laps < 1 else (1 if _loop_laps < 2 else 2)
	var stain := get_node_or_null("LoopStain_%d" % int(LOOP_SWAP_Z)) as Node3D
	if stain:
		stain.visible = stage == 0
	if stage >= 1 and _loop_swap_leg == null:
		_loop_swap_leg = _build_loop_swap_leg()
	if stage >= 2 and _loop_swap_page == null:
		_loop_swap_page = _build_loop_swap_page()
	if _loop_swap_leg:
		_loop_swap_leg.visible = stage == 1
	if _loop_swap_page:
		_loop_swap_page.visible = stage >= 2
	if stage != _loop_swap_stage:
		_loop_swap_stage = stage
		if stage > 0:
			_dbg("VOID loop swap (lap %d): the z %d dressing is now %s"
				% [_loop_laps, int(LOOP_SWAP_Z), "a hung chair leg" if stage == 1 else "a page"])


# A chair leg on a thread, 0.5 m off the east wall so the thread hangs in air rather than
# through the stone. Tar, like Hall1's stair and Hall2's doorframe: it belongs to nothing here.
func _build_loop_swap_leg() -> Node3D:
	var n := Node3D.new()
	n.name = "LoopSwapLeg"
	n.position = Vector3(13.45, 0.0, LOOP_SWAP_Z)
	add_child(n)
	var thread := _FRAGMENTS._box(n, Vector3(0.012, 1.45, 0.012), Vector3(0, 2.55, 0),
		_FRAGMENTS.fmat("tar", _FRAGMENTS.DARK, 1.0), "SwapThread")
	thread.rotation.z = 0.03
	var leg := _FRAGMENTS._box(n, Vector3(0.062, 0.46, 0.062), Vector3(0.02, 1.60, 0.0),
		_FRAGMENTS.fmat("tar", _FRAGMENTS.PALE), "SwapChairLeg")
	leg.rotation = Vector3(0.12, 0.4, 0.22)
	_FRAGMENTS._box(n, Vector3(0.085, 0.055, 0.085), Vector3(0.05, 1.39, 0.01),
		_FRAGMENTS.fmat("tar", _FRAGMENTS.BASE), "SwapChairFoot")
	return n


# A hand-sized page pinned exactly where the stain was — same wall, same height, same 3 cm of
# clearance the stain quad uses.
func _build_loop_swap_page() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "LoopSwapPage"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.24)
	mi.mesh = qm
	mi.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(false))
	mi.position = Vector3(14.0 - 0.1 - 0.03, 1.5, LOOP_SWAP_Z)
	mi.rotation = Vector3(0.0, -PI / 2.0, 0.08)
	add_child(mi)
	return mi


func _kill_loop_lamp(nm: String) -> void:
	var lamp := get_node_or_null(nm) as OmniLight3D
	if lamp == null:
		return
	lamp.light_energy = 0.0
	# ⚠️ Log ONCE per lamp. The flicker deliberately brings a dead lamp back for a second, so
	# `energy > 0` is no longer a "has not died yet" test — it is true on every send-back.
	if not _lamp_dead.has(nm):
		_lamp_dead[nm] = true
		_dbg("VOID loop lamp %s is dead (lap %d)" % [nm, _loop_laps])


# The LoopIn <-> LoopStraight doorway at (11, 15.5), walled up behind the player. Built from
# `_builder.wall_mat` — the SAME triplanar material instance the rooms use, so the fill is
# seamless rather than a patch of a different stone.
#
# ⚠️ 1.80 m wide and 3.30 m tall, i.e. EXACTLY the opening RoomBuilder cut (its doorways are
# full height; there is no header). Anything wider overlaps the jambs, and two boxes that
# overlap with coincident faces is this project's most common bug class — check_wall_overlap's
# solid-prop pass reports it. Abutting is free; overlapping is not.
# ⚠️ MeshInstance3D + StaticBody3D, not a CSGBox3D: the plug appears and disappears at runtime
# and has no business in the level's CSG tree.
func _build_loop_plug() -> void:
	if _loop_plug and is_instance_valid(_loop_plug):
		return
	var body := StaticBody3D.new()
	body.name = "LoopWallPlug"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(11.0, 1.65, 15.5)
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "PlugFace"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, ROOM_H, 1.8)
	mi.mesh = bm
	mi.set_surface_override_material(0, _builder.wall_mat)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, ROOM_H, 1.8)
	col.shape = sh
	body.add_child(col)
	_loop_plug = body
	if _plug_grind:
		_plug_grind.play()
	_dbg("VOID loop doorway WALLED UP at lap %d" % _loop_laps)


func _free_loop_plug() -> void:
	if _loop_plug and is_instance_valid(_loop_plug):
		_loop_plug.queue_free()
		_dbg("VOID loop wall plug removed — the way back is open")
	_loop_plug = null


func _on_loop_note_read() -> void:
	_loop_broken = true
	_dbg("VOID loop BROKEN after %d lap(s)" % _loop_laps)
	_free_loop_plug()
	_mark_note("LoopNote")


# ⭐ THE FRAGMENTS (void_fragments.gd): the ward, the morgue, the child's room.
#
# ⭐ FIVE COLOUR FAMILIES, ONE PER ROOM (2026-09-20 pass 2). Captures #6/#7/#8: *"All the
# colours are the same and it is boring."* Every prop in the level was the same violet-grey,
# so a room was not distinguishable from the room before it by anything but its shape. The
# assignment is the user's: Ward bone, Archive rust, LoopIn verdigris, Morgue bone + rust
# (the slab is bone, the drawers are rust), child room bone, the Hall3 heap MIXED, Hall1's
# stair and Hall2's doorframe tar, the hung shards violet.
# ⚠️ The figures are excluded — `void_creature_visual.gd` keeps its own 0.25 dark stone, so
# the five creatures read as one species in five differently-coloured rooms.
func _build_fragments() -> void:
	# The Ward: suspended frames, with a single optional off-screen rearrangement.
	_FRAGMENTS.folded_frame(self, Vector3(-2.6, 0, 14.5), 0.0, "FoldedFrame_Ward_L", "bone")
	var answering := _FRAGMENTS.folded_frame(self, Vector3(2.6, 0, 14.5), 0.0, "FoldedFrame_Ward_R", "bone")
	# ⭐ THE OTHER FRAME ANSWERS (2026-09-20 pass 4). Capture #2: *"When you press touch the
	# suspended fragment — nothing changes."* It did — 57 seconds later, two rooms away, by a
	# 0.45 rad yaw, because the re-pose fired on the first look-away FROM ANYWHERE. Three fixes,
	# and the first is the user's ruling: the frame that moves is now the RIGHT one, 5.2 m across
	# the room, so you touch one thing and a DIFFERENT thing changes while you stand between
	# them; the re-pose is gated to the Ward's own rect so it cannot fire in another room; and it
	# grinds as it moves, so you hear it behind you and turn to a changed shape.
	# ⚠️ The bed slat lies at the LEFT frame's mouth and the left frame never moves — a slat that
	# can be lost is a hard softlock (all three sockets gate the Morgue seal).
	_ward_fragment = _REARRANGEMENT.new()
	_ward_fragment.name = "WardFragment"
	_ward_fragment.position = Vector3(-2.6, 1.25, 13.3)
	# ⭐ pass 5: the thing you touch is a hospital gurney hung nose-down, in the Ward's own bone
	# family — capture #1, *"they still should represent some objects. This one is too unclear."*
	# It hangs from y 2.2 down to y 0.3 and gives a visible receipt on E (void_rearrangement.gd).
	_ward_fragment.family = "bone"
	_ward_fragment.sculpture = answering
	_ward_fragment.room_rect = _room_rect("Ward")
	# A bigger transform, because "unmissable" was the point: 0.9 rad of yaw, 0.35 of tilt, and
	# the whole suspended assembly lifted 0.3 m off its supports.
	_ward_fragment.rearranged_rotation = Vector3(0.0, 0.9, 0.35)
	_ward_fragment.rearranged_offset = Vector3(0.0, 0.3, 0.0)
	add_child(_ward_fragment)
	_ward_grind = _audio_at("WardGrind", "stone_grind", Vector3(2.6, 1.3, 14.5), -8.0, 5.0)
	_ward_fragment.connect("rearranged", _on_ward_answered)
	# The Morgue: an inverted slab, a drawer bank, the drawer that came out of it, the monitor.
	var slab := _FRAGMENTS.inverted_slab(self, Vector3(-13, 0, 45.5), PI / 2.0, "InvertedSlab_Morgue", "bone")
	_spawn_slab_page(slab)
	var bank := _FRAGMENTS.drawer_bank(self, _builder.wall_point("Morgue", Vector2(0, 1), 0.0, 0.42)
		+ Vector3(-3.5, 0, 0), PI, "DrawerBank_Morgue", "rust", _DRAWER_SCRIPT, PAGE_DRAWER)
	_wire_drawers(bank)
	_FRAGMENTS.long_drawer(self, Vector3(-20.0, 0, 50.3), 0.0, "LongDrawer_Morgue", "rust")
	var mon: Vector3 = _builder.wall_point("Morgue", Vector2(0, 1), 0.0, 0.5)
	_FRAGMENTS.monitor(self, mon, PI, "Monitor_Morgue")
	# The child's room: a disconnected cradle (the shard's socket) and residual fragments.
	_cradle = _FRAGMENTS.fractured_cradle(self, Vector3(-15.75, 0, 34.3), PI / 2.0,
		"Cradle_ChildRoom", _CRADLE_SCRIPT, "bone")
	_cradle.set("level", self)
	_cradle.connect("completed", _on_cradle_completed)
	var draw: Vector3 = _builder.wall_point("ChildRoom", Vector2(1, 0), 1.5, 0.16)
	_FRAGMENTS.crayon_drawing(self, draw, -PI / 2.0, "Drawing_ChildRoom")
	_FRAGMENTS.music_box(self, Vector3(-12.2, 0, 31.5), 0.0, "MusicBox_ChildRoom", "bone")
	_build_impossible_props()


# ⭐ THE EMPTY ROOMS (2026-09-20). Hall1, Hall2, Hall3, LoopIn, LoopOut, the Threshold and both
# pockets held nothing at all — seven of fifteen rooms — and the playtester said so in capture
# #1: *"throughout the level I think we need to have more weird objects representing fear,
# broken geometry, complete nonsense and so on"*. Everything here is matte, unlit, has no
# `ScaryObject` ancestor and costs ZERO panic; two of them mutate off-screen (P11).
# ⚠️ Every wall placement goes through `wall_point()`. Nothing is hand-computed against a
# wall face, and nothing hangs on a wall that carries a doorway.
func _build_impossible_props() -> void:
	# A flight of stairs that ends 6 cm under the ceiling. East side of Hall1; the 2 m of
	# floor from x -1.4 to 0.6 is the route and stays clear.
	_FRAGMENTS.ceiling_stair(self, Vector3(1.0, 0, 7.0), 0.0, ROOM_H, "CeilingStair_Hall1", "tar")
	# A doorway lying flat on the floor of Hall2, with a hole of black inside it — and since
	# 2026-09-20 pass 3 it is a way THROUGH (see _build_step_through).
	_FRAGMENTS.flat_doorframe(self, STEP_FRAME_HALL2, 0.0, "FlatDoorframe_Hall2", "tar")
	# ⚠️ Its twin in LoopIn is the DESTINATION and carries no area: the hole is one-way.
	# Placed clear of the fused chairs on the north wall (their geometry stops at z 16.44) and
	# of both doorway jambs; like every flat frame it has no collider, so lying across the
	# room's walking line cannot block anything.
	_FRAGMENTS.flat_doorframe(self, STEP_FRAME_LOOPIN, 0.0, "FlatDoorframe_LoopIn", "tar")
	# Waiting-room chairs fused into LoopIn's north wall (which carries no doorway).
	_FRAGMENTS.fused_chairs(self, _builder.wall_point("LoopIn", Vector2(0, 1), 0.0, 0.1), 0.0,
		"FusedChairs_LoopIn", "verdigris")
	# Shards on threads, hung high enough to walk under, in the three rooms that had nothing.
	_FRAGMENTS.hung_shards(self, Vector3(2.4, 0, 1.4), "HungShards_Threshold", 7, 47, ROOM_H, "violet")
	_FRAGMENTS.hung_shards(self, Vector3(-3.2, 0, 8.0), "HungShards_PocketA", 5, 211, ROOM_H, "violet")
	_FRAGMENTS.hung_shards(self, Vector3(-18.0, 0, 40.6), "HungShards_PocketB", 6, 353, ROOM_H, "violet")
	# The two that move when nobody is looking. Both arm on SIGHT, not on touch: there is no
	# prompt and no collider on the rearranger, so the player never learns there was a switch.
	var table := _FRAGMENTS.inverted_table(self, Vector3(-3.4, 0, 22.0), 0.3,
		"InvertedTable_Archive", _REARRANGEMENT, "rust")
	_arm_on_sight(table, "TableAssembly", Vector3(0.0, 0.9, 0.28), Vector3(0.12, -0.06, -0.1))
	_inverted_table = table
	table.connect("rearranged", _on_table_rearranged)
	_spawn_archive_shard(table)
	var heap := _FRAGMENTS.door_heap(self, _builder.wall_point("Hall3", Vector2(1, 0), 0.0, 0.45),
		0.0, "DoorHeap_Hall3", _REARRANGEMENT, "mixed")
	_arm_on_sight(heap, "HeapAssembly", Vector3(0.08, -0.55, -0.16), Vector3(0.0, 0.22, 0.35))
	_build_step_through()
	_spawn_anchors()


# The rearranger rides the prop's OWN body (see void_rearrangement.gd's _ready() for why).
# Properties are plain vars read from _process, so setting them after add_child is safe.
func _arm_on_sight(prop: Node3D, child: String, rot: Vector3, offset: Vector3) -> void:
	prop.set("arm_on_sight", true)
	prop.set("sculpture", prop)
	prop.set("target_child", child)
	prop.set("rearranged_rotation", rot)
	prop.set("rearranged_offset", offset)
	_prop_fragments.append(prop)


# ⭐ THE SHARD MOVED TO THE ARCHIVE (2026-09-20 pass 3), into the legs-up basin of the
# inverted table. The Archive is a dead end off the Ward that NONE of the day's three runs
# entered; the shard used to lie seven seconds from the cradle it opens (taken 410 s, cradle
# 417 s).
# ⭐ AND IT IS VISIBLE FROM FRAME 0, WEDGED (2026-09-20 pass 5). Pass 3 made it invisible and
# collider-less until the table re-posed itself, and the 23:33 run photographed that twice:
# *"this shard did not appear immediately… we should fix that."* It is now jammed between the
# table's stretcher and one upturned leg, refusing, and the off-screen rearrangement shakes it
# down into the basin. The rule is kept and the cause is finally legible.
# ⚠️ `to_global`, never a hand-computed world point: the table is yawed 0.3 rad.
# ⚠️ Both poses are handed over AFTER add_child — the node's `_ready()` runs before the mesh and
# the collider exist and nothing set there could describe them (void_loop_note.gd's rule).
func _spawn_archive_shard(table: Node3D) -> void:
	_shard = _SHARD_SCRIPT.new()
	_shard.name = "SlabShard"
	_shard.set("level", self)
	# ⚠️ y 0.42 IS MEASURED, not chosen. The table's collider is its 0.22 m top slab (top face
	# at y 0.22) and a descending E-ray grazes that face before it reaches anything lower: at
	# y 0.38 the raw ray reported `InvertedTable_Archive` from every stance tried. 0.42 leaves
	# 0.20 m of clearance and the shard still sits inside the basin, between the legs-up legs.
	var basin: Vector3 = table.to_global(Vector3(0.0, 0.42, 0.0))
	# ⚠️ AND THE WEDGED POSE IS MEASURED TOO. Body-local (0.30, 0.74, -0.26) puts it against the
	# stretcher (local y 0.88) beside the +x pair of upturned legs, on the DOORWAY SIDE of the
	# table (world z 21.84 against the table's 22.0) so it is in view from the Archive's own
	# doorway at (-2, 18) rather than behind two legs — and 0.52 m above the table's collider,
	# which is what lets the E-ray reach it at all (Issue 230).
	var wedged: Vector3 = table.to_global(Vector3(0.30, 0.74, -0.26))
	_shard.position = wedged
	add_child(_shard)
	_shard.call("set_poses", wedged, Vector3(0.55, -0.35, 0.9), basin)
	_shard.connect("taken", _on_shard_taken)
	_sync_shard()


# The rearrangement IS the release. Derived from the rearranger's own `spent` flag rather than
# stored, so the off-screen beat, a snapshot restore and a test that sets the state by hand all
# land in the same world (the loop ladder's rule). ⚠️ `announce` is FALSE everywhere but the
# live beat: a restore must never replay a one-shot.
func _sync_shard(announce: bool = false) -> void:
	if _shard == null or not is_instance_valid(_shard):
		return
	if _shard_taken:
		_shard.queue_free()
		_shard = null
		return
	if _inverted_table and is_instance_valid(_inverted_table) and bool(_inverted_table.get("spent")):
		_shard.call("free_into_basin", announce)
	else:
		_shard.call("wedge")


func _on_table_rearranged() -> void:
	_sync_shard(true)


func _on_ward_answered() -> void:
	if _ward_grind:
		_ward_grind.play()
	_dbg("VOID ward frame answered — the RIGHT frame moved, 5.2 m from the one you touched")


# The torn page that stayed behind in the slab's hollow, so the "E under the slab, with your
# back to D" beat survives the shard leaving the Morgue. It is a fragment of the twist note:
# the Morgue tells you the number before the Sanctum does.
# ⚠️ LAID FLAT against the underside. check_note_mounting measures backing along a page's
# THIN axis and wants something solid within 0.35 m: flat at y 1.84 the slab's own collider is
# 5 cm above it, and upright it would have seven metres of air behind it and 1.8 m of drop.
func _spawn_slab_page(slab: Node3D) -> void:
	var at: Vector3 = slab.to_global(Vector3(0, 1.84, -0.10))
	var page := _make_note("SlabPage", at, PI / 2.0,
		"…a fragment, torn across:\n\n\"…completed the trial eleven times and remembers none of them, which is the result…\"\n\nThe rest of the sheet is somewhere else in this building. You have read it before.", false)
	page.rotation = Vector3(PI / 2.0, 0.0, 0.0)


func _on_shard_taken() -> void:
	_shard_taken = true
	_shard = null
	_update_carried()
	GameState.set_objective("A stone shard. Something in the far wing is missing one")


# ── SEARCH: the Morgue's seventeen drawers ───────────────────────────────────
#
# Sixteen hold nothing. One holds the page that points at the Archive, and nothing anywhere
# says which — the search is the challenge. ⚠️ The page is a CHILD of its drawer, so it slides
# out with the front and is behind the carcass until then: `check_reachable` calls that
# CONTAINED (reached by opening its host), the Lab's HintPage-in-a-drawer rule.
func _wire_drawers(bank: Node3D) -> void:
	for c in bank.get_children():
		if c.get_script() != _DRAWER_SCRIPT:
			continue
		_drawers.append(c)
		if bool(c.get("holds_page")):
			_page_drawer = c
			_drawer_page = _make_note("DrawerPage", Vector3.ZERO, 0.0,
				"We kept the shard under the table you turned over.\n\nThe handwriting is yours.", false, null, c)
			# ⚠️ IT HAS TO BE SEEN, NOT JUST HIT. Lying flat on the drawer's tray it was reachable
			# by the E-ray (which is a physics query, and the drawer's front is a MESH with no
			# collider) and INVISIBLE to the player: from eye height 1.65 m the 0.54 m front of
			# an open drawer at y 0.98 hides everything inside it — the ray clears the front's
			# top edge at y 0.89 against an edge at 1.25. Occlusion is a camera fact (Issue 229).
			# The page therefore STANDS in the drawer, wedged against the inside of the front and
			# poking 0.10 m above its top edge, where it reads from straight on.
			_drawer_page.position = Vector3(0, 0.16, -0.10)
			_drawer_page.rotation = Vector3(0.30, 0.0, 0.06)
	# ⭐ ONE FRONT STARTS OUT (pass 4). `open_instantly()` — no tween, no `drawer_pull` — so the
	# room simply contains a drawer that has been pulled, and the bank reads as a moving part
	# rather than as a wall of decoration. It is NOT the page's drawer.
	for d in _drawers:
		if int(d.get("col")) == OPEN_DRAWER.x and int(d.get("row")) == OPEN_DRAWER.y \
				and not bool(d.get("holds_page")):
			d.call("open_instantly")
			_dbg("VOID morgue drawer %d_%d starts PULLED (the bank has a moving part)"
				% [OPEN_DRAWER.x, OPEN_DRAWER.y])
	_dbg("VOID morgue drawers armed: %d fronts, the page is in %s"
		% [_drawers.size(), _page_drawer.name if _page_drawer else "NOWHERE"])


# ── the three anchors ───────────────────────────────────────────────
func _spawn_anchors() -> void:
	for spec in ANCHORS:
		var a := _ANCHOR_SCRIPT.new()
		a.name = "Anchor_" + String(spec["id"])
		a.set("anchor_id", spec["id"])
		a.set("label", spec["label"])
		a.set("family", spec["family"])
		a.set("pose", spec["pose"])
		a.set("level", self)
		var at: Vector3 = spec["at"]
		if String(spec["room"]) != "":
			# ⚠️ wall_point(), never a hand-computed wall face. PocketA's west wall carries the
			# trap note at y 1.3; the handle lies on the floor under it, 0.5 m along.
			at = _builder.wall_point(String(spec["room"]), Vector2(-1, 0), spec["at"].y, 0.30) \
				+ Vector3(0, 0, 0.55)
		a.position = at
		a.rotation.y = spec["yaw"]
		add_child(a)
		_anchors[String(spec["id"])] = a


# ── the level's inventory ──────────────────────────────────────────
#
# ⚠️ `GameState.carried_item` is a COMPOSED LINE here and nothing may test it for equality
# with a key any more. The shard and one anchor can be carried at once, so the HUD reads
# "a stone shard · a door handle"; `void_cradle.gd` and `void_alignment.gd` ask this level.
func carried_anchor() -> String:
	return _carried_anchor


func carried_label() -> String:
	return _anchor_label(_carried_anchor)


func has_shard() -> bool:
	return _shard_taken and not _cradle_done


func _anchor_label(id: String) -> String:
	for spec in ANCHORS:
		if String(spec["id"]) == id:
			return String(spec["label"])
	return id


func take_anchor(id: String) -> void:
	if _carried_anchor != "":
		return
	_carried_anchor = id
	if not _anchors_taken.has(id):
		_anchors_taken.append(id)
	_free_anchor(id)
	_update_carried()
	_dbg("VOID anchor TAKEN: %s" % id)


# ⚠️ remove_child BEFORE queue_free (Issue 17): the dying node still owns its NAME, and
# `_restore_progress()` asks for it BY NAME in the same frame it frees it.
func _free_anchor(id: String) -> void:
	_anchors.erase(id)
	var a := get_node_or_null("Anchor_" + id)
	if a != null:
		remove_child(a)
		a.queue_free()


func consume_anchor(id: String) -> void:
	if _carried_anchor != id:
		return
	_carried_anchor = ""
	_update_carried()
	_dbg("VOID anchor PLACED: %s" % id)


func take_shard() -> void:
	_shard_taken = true
	_update_carried()


# ⚠️ `_shard_taken` MEANS "OUT OF THE WORLD", NOT "IN HAND", and it is never reset. It is what
# `_sync_shard()` and `_restore_progress()` read to decide whether the Archive still has a
# shard in it — clearing it here put the shard BACK in the table's basin on the next snapshot
# restore, after the cradle had already been completed with it. Holding it is `has_shard()`,
# which is `_shard_taken and not _cradle_done`.
func consume_shard() -> void:
	_cradle_done = true
	_update_carried()


func _update_carried() -> void:
	var parts: Array = []
	if has_shard():
		parts.append("a stone shard")
	if _carried_anchor != "":
		parts.append(_anchor_label(_carried_anchor))
	GameState.set_carried(" · ".join(parts))


# ── STEP THROUGH ────────────────────────────────────────────────────
#
# Stand inside the doorway lying flat in Hall2 for 1.2 s and you come out of the one lying flat
# in LoopIn, thirty metres back, still walking. Heading and velocity are kept, the loop seam's
# own pattern. ⚠️ ONE WAY, BACKWARDS ONLY — it bypasses nothing, and it is the relief valve for
# a player who reached the far wing without the shard: the walk back is ≈ 185 m otherwise.
# ⚠️ ZERO PANIC, no fail state, and no zone charges for standing there (the tile hall's rule).
# ⚠️ It cannot strand anybody behind the corridor's lap-2 wall plug. To be in Hall2 at all you
# must have passed the seam at z 32 walking +z, which teleports you back every time until the
# loop note is read — so `_loop_broken` is always true by the time this frame can fire.
func _build_step_through() -> void:
	_step_area = Area3D.new()
	_step_area.name = "StepThrough_Hall2"
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.92, 2.2, 2.06)     # the frame's own opening, full height
	col.shape = sh
	_step_area.add_child(col)
	_step_area.position = STEP_FRAME_HALL2 + Vector3(0, 1.1, 0)
	_step_area.collision_layer = 0
	_step_area.collision_mask = 1
	add_child(_step_area)
	# frame_drop measures -16.2 dBFS RMS, the loudest of the level's one-shots, and it plays at
	# the DESTINATION, i.e. at zero distance from the player who just arrived.
	_step_drop = _audio_at("StepThroughDrop", "frame_drop",
		STEP_FRAME_LOOPIN + Vector3(0, 1.0, 0), -10.5, 4.0)
	# ⭐ THE FRAME REACTS TO THE DWELL (2026-09-20 pass 4). Nobody stood in it for 413 s — standing
	# still in a doorway on the floor is a thing nobody does by accident. Its four bars now lean
	# toward the black in proportion to 0..STEP_DWELL and snap back the moment you step out, so a
	# player who pauses on it for half a second is shown that pausing is the verb.
	# ⚠️ NOT a §8.2 readout. §8.2 bans showing progress toward a SOLUTION; this is the diegetic
	# affordance of a verb, in the world, on the prop, with no UI and no number — the same
	# distinction that kept the Backrooms' classifying instrument. The user's call, 2026-09-20.
	# ⚠️ THE LOOPIN TWIN DOES NOT REACT, and that is deliberate: it is the destination, it has no
	# area, and a frame that leans where nothing can happen is Issue 226 in mime.
	var frame := get_node_or_null("FlatDoorframe_Hall2") as Node3D
	_step_bars = []
	_step_bar_rest = []
	if frame:
		for c in frame.get_children():
			var nm := String(c.name)
			if c is Node3D and (nm.begins_with("FlatJamb") or nm.begins_with("FlatLintel")
					or nm.begins_with("FlatThreshold")):
				_step_bars.append(c)
				_step_bar_rest.append((c as Node3D).rotation)


const STEP_BAR_LEAN := 0.26      # radians at a full dwell; the bars are 0.10 m thick


func _apply_step_bars(k: float) -> void:
	for i in range(_step_bars.size()):
		var bar := _step_bars[i] as Node3D
		if not is_instance_valid(bar):
			continue
		var rest: Vector3 = _step_bar_rest[i]
		# Jambs run along local z and lean about x; the lintel and threshold run along x and
		# lean about z. Alternating the sign tips all four inwards, toward the black.
		var nm := String(bar.name)
		var lean: float = STEP_BAR_LEAN * k
		if nm.begins_with("FlatJamb"):
			bar.rotation = rest + Vector3(0.0, 0.0, lean * (1.0 if bar.position.x > 0.0 else -1.0))
		else:
			bar.rotation = rest + Vector3(lean * (1.0 if bar.position.z > 0.0 else -1.0), 0.0, 0.0)


func _tick_step_through(delta: float) -> void:
	if _step_area == null:
		return
	var p := _player()
	if p == null:
		_step_dwell = 0.0
		return
	var inside := false
	for b in _step_area.get_overlapping_bodies():
		if b == p:
			inside = true
	if not inside:
		_step_dwell = 0.0
		_apply_step_bars(0.0)
		return
	_step_dwell += delta
	_apply_step_bars(clampf(_step_dwell / STEP_DWELL, 0.0, 1.0))
	if _step_dwell < STEP_DWELL:
		return
	_step_dwell = 0.0
	_apply_step_bars(0.0)
	var keep := p.velocity
	p.global_position = STEP_FRAME_LOOPIN + Vector3(0, 0.1, 0)
	p.force_update_transform()
	p.velocity = keep
	_step_drops += 1
	if _step_drop:
		_step_drop.play()
	_dbg("VOID STEP THROUGH #%d: Hall2 frame -> LoopIn frame (kept heading %.3f rad)"
		% [_step_drops, p.rotation.y])


# ⭐ THE CRADLE GIVES (2026-09-20 pass 4). It no longer retracts the Sanctum plate — the hidden
# note behind the secret door does. One link of the chain moved and NO new unlock condition was
# added: `ExitDoor` still waits on `TWIST_READ` alone.
#
# Three things answer at once, which is what makes it read as a payoff instead of a tween:
#   1. a sixth fractured figure rises through the cradle and lunges into the camera
#      (`void_cradle_figure.gd`), after a 0.6 s HoldBreath silence — zero panic, no fail state;
#   2. the Morgue's west wall opens, three rooms away, with a distant `stone_grind`;
#   3. the child's crayon drawing two metres away becomes a PLAN with one door marked, the next
#      time you look away from it — the tell that says WHERE, in the level's own grammar.
func _on_cradle_completed() -> void:
	_cradle_done = true
	_update_carried()
	# ⚠️ The plate stays, and its prompt CHANGES: *"The stone will not move."* stated a condition
	# a player who had just done the thing could no longer act on (Issue 226's shape).
	if _sanctum_plate and is_instance_valid(_sanctum_plate):
		_sanctum_plate.set("moved_elsewhere", true)
	_open_secret_door()
	_arm_drawing_swap()
	_fire_cradle_lunge()
	GameState.set_objective("Something opened in the far wing")


# ⚠️ CREATURE E STANDS TWO METRES FROM THE CRADLE. Blinding or pinning a player beside a
# lethal-contact creature is a coin-flip death (SCARY.md §8.11), and `DreadFarWing` cancels decay
# here so anything it cost would be permanent. E is suppressed with the tile hall's own
# mechanism — `creature_stalker.protected_player_rect` — set to the child room for the beat plus
# one second. ⚠️ RESTORED to `_tile_rect`, never cleared: that rect is what stops all five
# stalkers while the player is out on the causeway, and clearing it would quietly delete E's half
# of a rule that has nothing to do with this scare.
func _fire_cradle_lunge() -> void:
	if _lunge_spent:
		return
	_lunge_spent = true
	var p := _player()
	if p == null or _cradle == null or not is_instance_valid(_cradle):
		return
	if _cradle_sting == null:
		_cradle_sting = _make_sting("CradleSting")
	var e = _stalkers.get("E", null)
	if e and is_instance_valid(e):
		e.set("protected_player_rect", _room_rect("ChildRoom"))
		_protect_restore = _CRADLE_FIGURE.DIP + _CRADLE_FIGURE.RISE_TIME \
			+ _CRADLE_FIGURE.LUNGE_TIME + 1.0
	var fig := _CRADLE_FIGURE.new() as Node3D
	fig.name = "CradleFigure"
	add_child(fig)
	# ⭐ pass 5: the CRADLE, not a point. The figure takes the centre of the cradle's own geometry
	# (every `_body()` prop in this level has its origin on the floor), so it rises out of the
	# slats instead of out of the floor in front of them — capture #5, *"make this 3d jumpscare
	# look more centralised to the middle of this object."*
	fig.call("arm", p, _cradle, _cradle_sting)


# ⭐ THE SHARED `jumpscare` ON MASTER (2026-09-20 pass 5, the user's ruling for both beats).
# ⚠️ -10.3 dB IS MEASURED, not chosen. `cradle_sting` is -10.09 dBFS RMS and sat at -3.0 dB;
# `jumpscare` is -2.83 dBFS RMS, i.e. 7.26 dB hotter, so -10.3 dB lands the shared file exactly
# where pass 4 measured the old one (-13.1 dBFS at the source). Its peak is 0.00 dBFS, so at
# -10.3 dB with the +3 dB max_db clamp the loudest sample sits 7.3 dB under the ceiling.
# ⚠️ MASTER, not `AudioBuses.AMBIENCE`: `HoldBreath.dip()` ducks Ambience to -30 dB for the
# cradle's beat, and a sting inside its own silence is the opposite of the effect.
# `screamer.gd` routes its own the same way for the same reason.
func _make_sting(nm: String) -> AudioStreamPlayer3D:
	var s := GameState.load_audio("jumpscare")
	if s == null:
		return null
	var pl := AudioStreamPlayer3D.new()
	pl.name = nm
	pl.stream = s
	pl.volume_db = -10.3
	pl.unit_size = 4.0
	add_child(pl)
	return pl


func _tick_protection(delta: float) -> void:
	if _protect_restore < 0.0:
		return
	_protect_restore -= delta
	if _protect_restore > 0.0:
		return
	_protect_restore = -1.0
	var e = _stalkers.get("E", null)
	if e and is_instance_valid(e):
		e.set("protected_player_rect", _tile_rect)


# ⭐ THE DRAWING BECOMES A PLAN. `void_rearrangement.gd`'s sight rule, applied to a prop that is
# a bare Node3D with no body to carry the script: armed by the cradle, applied on the first frame
# the player is not looking at it. Same texture size (1024 x 1024), same quad, so the aspect the
# art guard measures does not move.
func _arm_drawing_swap() -> void:
	if not _drawing_swapped:
		_drawing_swap_armed = true


func _tick_drawing_swap() -> void:
	if not _drawing_swap_armed or _drawing_swapped:
		return
	var draw := get_node_or_null("Drawing_ChildRoom") as Node3D
	var p := _player()
	if draw == null or p == null:
		return
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var to: Vector3 = draw.global_position - cam.global_position
	if to.length() < 9.0 and (-cam.global_basis.z).dot(to.normalized()) > 0.1:
		return
	_drawing_swapped = true
	_drawing_swap_armed = false
	_apply_drawing_plan()
	_dbg("VOID child drawing became a PLAN off-screen — one door marked")


func _apply_drawing_plan() -> void:
	var art := get_node_or_null("Drawing_ChildRoom/Art") as MeshInstance3D
	if art == null:
		return
	var path := TEX + "void_child_drawing_plan.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var mat := art.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		var m: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
		m.albedo_texture = tex
		art.set_surface_override_material(0, m)


# ⭐ THE HALL OF FRAMES + the page at the end of it.
func _build_frame_hall() -> void:
	var note := _make_note("HiddenNote",
		_builder.wall_point("FrameHall", Vector2(0, 1), 1.3, 0.16), PI,
		"The pieces agree when you are not holding any of them.\n\nPut it back. Put all of it back.\n\nThen the stone will move.",
		false, _HIDDEN_NOTE_SCRIPT)
	note.set("level", self)
	# ⚠️ AFTER _make_note, never in the note's own _ready(): the paper mesh and the collider are
	# added as children of a node that is ALREADY in the tree, so _ready() has run before either
	# of them exists and cannot hide them (void_loop_note.gd's rule, learned the same way).
	note.call("conceal")
	note.connect("plate_should_retract", _on_hidden_note_read)
	_hidden_note = note
	var hall := _FRAME_HALL.new() as Node3D
	hall.name = "FrameHall"
	hall.set("note", note)
	add_child(hall)
	hall.call("build", self, get_node_or_null("Light_FrameHall") as OmniLight3D,
		FRAME_SEED_BASE + GameState.get_level_attempts(8) * 101)
	_frame_hall = hall


# The one link that moved: the plate retracts for the hidden note, not for the cradle.
func _on_hidden_note_read() -> void:
	if _sanctum_plate and is_instance_valid(_sanctum_plate):
		_sanctum_plate.call("retract")
		_sanctum_plate = null
	GameState.set_objective("Find the truth — read the note that doesn't belong")


# The hidden note's condition, asked of the level. Every part of it is ALREADY mandatory for a
# player standing here — all three sockets gate the Morgue seal and the cradle gates the secret
# door — so this can never softlock; it only refuses a player whose hands are full.
func everything_put_back() -> bool:
	if _carried_anchor != "" or has_shard():
		return false
	if not _cradle_done:
		return false
	var filled: Array = _alignment.call("sockets_filled")
	for f in filled:
		if not bool(f):
			return false
	return filled.size() == 3


# The stone plate over the Sanctum's twist note. Built AFTER _spawn_notes() so it can sit in
# front of TwistNote's own collider (note front at x -17.78; the plate occupies -17.77..-17.71).
# ⚠️ The Sanctum's west wall carries no doorway — the twist note is there for exactly that
# reason — so nothing here can seal a room.
func _spawn_chain() -> void:
	if _cradle_done:
		return
	var plate := StaticBody3D.new()
	plate.name = "SanctumPlate"
	plate.set_script(_PLATE_SCRIPT)
	# ⭐ pass 5: x -17.74, not -17.72, and 0.90 × 1.10 instead of 0.60 × 0.80. Its back face sits
	# at -17.77, one centimetre in front of the note's collider face (-17.78) and 0.13 m clear of
	# the wall's own face (-17.90) — covering, never coplanar.
	plate.position = Vector3(-17.74, 1.3, 24.5)
	plate.rotation.y = PI / 2.0
	add_child(plate)
	_sanctum_plate = plate


# ── lights: one cold point per room, the same palette the old ring used ─────────
func _spawn_lights() -> void:
	var palette := {
		"Threshold": [Color(0.6, 0.7, 1.0), 0.40, 6.0],
		"Hall1": [Color(0.6, 0.65, 1.0), 0.25, 5.0],
		"PocketA": [Color(0.7, 0.6, 1.0), 0.2, 4.0],
		# ⚠️ Desaturated 2026-09-20 evening (was 0.8, 0.6, 1.0 — the most saturated violet in the level):
		# under it the Ward's BONE props rendered lavender-grey and the five-family palette was defeated
		# in the one room the player sees first. Light energy is untouched.
		"Ward": [Color(0.85, 0.75, 1.0), 0.35, 7.0],
		"Archive": [Color(0.7, 0.6, 1.0), 0.28, 5.0],
		"LoopIn": [Color(0.6, 0.65, 1.0), 0.25, 5.0],
		"LoopOut": [Color(0.6, 0.65, 1.0), 0.25, 5.0],
		"Hall2": [Color(0.6, 0.65, 1.0), 0.22, 5.0],
		"TileHall": [Color(0.72, 0.58, 0.9), 0.65, 9.0],
		"Morgue": [Color(0.6, 1.0, 0.7), 0.3, 6.0],
		"Hall3": [Color(0.6, 0.65, 1.0), 0.2, 5.0],
		"PocketB": [Color(0.7, 0.6, 1.0), 0.2, 4.0],
		"ChildRoom": [Color(1.0, 0.6, 0.6), 0.25, 5.0],
		"Sanctum": [Color(0.75, 0.55, 1.0), 0.35, 7.0],
		# ⭐ The secret room. Its energy is the Hall of Frames' only feedback channel — one step
		# brighter per right answer, out for two seconds on a wrong one — so `void_frame_hall.gd`
		# drives it from here on. 0.25 is the base it starts and restarts at.
		"FrameHall": [Color(0.72, 0.58, 1.0), 0.25, 5.0],
	}
	for nm in palette:
		var spec: Array = palette[nm]
		var l := OmniLight3D.new()
		l.name = "Light_" + nm
		l.light_color = spec[0]
		l.light_energy = spec[1]
		l.omni_range = spec[2]
		l.position = _builder.room_center(nm) + Vector3(0, 2.8, 0)
		add_child(l)
	# The loop corridor: identical lamps one period apart, preserving the seam view.
	for z in [19.0, 34.0]:
		var l := OmniLight3D.new()
		l.name = "Light_Loop_%d" % int(z)
		l.light_color = Color(0.6, 0.65, 1.0)
		l.light_energy = LOOP_LAMP_ENERGY
		l.omni_range = 6.0
		l.position = Vector3(12.5, 2.8, z)
		add_child(l)
	# Two candles by the spawn: the level's only warm light and its recovery anchor.
	for x in [-1.5, 1.5]:
		_spawn_candle(Vector3(x, 0.0, -1.5))


func _spawn_candle(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "CandleLight_%d" % int(pos.x * 10)
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.position = pos + Vector3(0, 0.8, 0)
	add_child(light)
	var candle := MeshInstance3D.new()
	candle.name = "Candle_%d" % int(pos.x * 10)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.025
	mesh.height = 0.15
	candle.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.4)
	# ⚠️ 0.9, not the 1.5 the old scene shipped: above 1.0 emission clamps to a flat white blob
	# (Issue 21, filed as V-T3 in backlogs/08-void.md).
	mat.emission_energy_multiplier = 0.9
	candle.set_surface_override_material(0, mat)
	candle.position = pos + Vector3(0, 0.075, 0)
	add_child(candle)


# ── notes: 5 safe (one the loop breaker), 3 trap, the twist ─────────────────────
func _spawn_notes() -> void:
	var n: StaticBody3D
	n = _make_note("NoteThreshold", _builder.wall_point("Threshold", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"You have been here before.\n\nNot this room. This is not a room. But you have stood at a door like the one behind you and told yourself the next one would be the last.\n\nCount the doors. The number will not stay the same.\n\nThe broken figures hold still while you watch. Listen when you turn away.", false)
	n = _make_note("NoteWard", _builder.wall_point("Ward", Vector2(0, 1), 1.3, 0.16), PI,
		"Trial 1. The ward. Subject 47 woke, read, and walked.\n\nWe kept the shape of the beds. The pieces no longer agree about where they belong.\n\nTouch one. Look away. It remembers differently.", false)
	var lp: Vector3 = _builder.wall_point("LoopStraight", Vector2(-1, 0), 1.3, 0.16)
	lp.z = LOOP_NOTE_Z
	# ⭐ A level-local note SUBCLASS (void_loop_note.gd): illegible until the corridor has
	# actually repeated twice. It hangs nine metres BEFORE the seam, and both runs of the
	# 2026-09-20 playtest read it on the first pass, skipping the whole loop beat.
	n = _make_note("LoopNote", lp, PI / 2.0,
		"This corridor is thirty metres long.\n\nYou have walked more than that. You will walk more than that again.\n\nIt is not the corridor that turns back. Read this, and it stops.", false, _LOOP_NOTE_SCRIPT)
	n.read.connect(_on_loop_note_read)
	# ⚠️ AFTER _make_note, not in the note's own _ready(): _make_note adds the paper mesh and
	# the collider as CHILDREN of a node that is already in the tree, so _ready() has run
	# before either exists and cannot hide them.
	n.call("conceal")
	_loop_note = n
	# ⚠️ WEST wall. The first draft hung this on the south wall's centre, which is exactly where
	# the Morgue -> Hall3 doorway sits (the Records-sign lesson): its collider sealed the whole
	# far wing — five interactables unreachable, measured by check_reachable.
	# ⚠️ AND IT IS 3 m NORTH OF THE WALL'S CENTRE SINCE 2026-09-20 pass 4, for the SAME reason a
	# second time. `wall_point()` returns the wall CENTRE, and the centre of the Morgue's west
	# wall is (-20.84, 47.5) — which is now the secret doorway. `check_note_mounting` caught it
	# on the first build ("is not in a doorway ... x-doorway at (-21.0, 47.5)"). The doorway is
	# the user's chosen site and does not move; the note does, along its own wall.
	# ⚠️ 2.5 m SOUTH, not north, and that is measured too: +3.0 m put it 2.03 m from the page in
	# drawer 4_1 against this guard's 2.50 m same-room separation. South it is 6.8 m from that
	# page, 7.8 m from the slab's, and 1.6 m clear of the 1.8 m opening.
	var morgue_note: Vector3 = _builder.wall_point("Morgue", Vector2(-1, 0), 1.3, 0.16)
	morgue_note.z -= 2.5
	n = _make_note("NoteMorgue", morgue_note, PI / 2.0,
		"Trial 1, room 4. We turned the table over.\n\nThe impression stayed underneath. Whatever lay here was lying on the other side of the room.", false)
	n = _make_note("NoteArchive", _builder.wall_point("Archive", Vector2(0, 1), 1.3, 0.16), PI,
		"The handwriting on the wall is yours.\n\nWe compared it. Every trial, the same hand, the same sentence: THERE IS NO WAY OUT.\n\nYou were never told the sentence.", false)
	# Traps: read to the end and the void takes you.
	n = _make_note("TrapPocketA", _builder.wall_point("PocketA", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me", true)
	n = _make_note("TrapChildRoom", _builder.wall_point("ChildRoom", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47", true)
	n = _make_note("TrapPocketB", _builder.wall_point("PocketB", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit.", true)
	# The twist. ⭐ pass 5: a note SUBCLASS (void_twist_note.gd) that refuses while the stone
	# plate stands. The plate was the only gate and it is a 3 cm-deep blocker, which a grazing
	# stance walks straight past (Issue 242) — the level's win condition was reachable without
	# the cradle, the secret door or the Hall of Frames.
	n = _make_note("TwistNote", _builder.wall_point("Sanctum", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"There is no end condition.\n\nThe door at the end of this room opens onto the first room. It always has. Subject 47 has completed the trial eleven times and remembers none of them, which is the result.\n\nWe are not watching. There is nobody at the glass. We stopped watching after the fourth.\n\nGo through the door. We will see you at the beginning.", false, _TWIST_NOTE_SCRIPT)
	n.is_twist_note = true
	n.set("level", self)
	_twist_note = n


# ⚠️ `script` is applied BEFORE add_child: a set_script() on a node already in the tree never
# runs its _ready(), and note.gd's _ready() is what sets the interact layer and the paper.
# `parent` (2026-09-20 pass 3) hangs a page inside another prop — the page in the Morgue drawer
# rides its own drawer body so it slides out with the front.
func _make_note(nm: String, pos: Vector3, y_rot: float, text: String, trap: bool,
		script: Script = null, parent: Node = null) -> StaticBody3D:
	var note := StaticBody3D.new()
	note.name = nm
	note.set_script(_NOTE_SCRIPT if script == null else script)
	note.note_text = text
	note.is_trap = trap
	note.position = pos
	note.rotation.y = y_rot
	(parent if parent != null else self).add_child(note)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.42, 0.01)
	mesh.mesh = bm
	mesh.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(trap))
	note.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.5, 0.12)
	col.shape = shape
	note.add_child(col)
	if not trap:
		note.read.connect(_mark_note.bind(nm))
	return note


func _mark_note(nm: String) -> void:
	if not _notes_read.has(nm):
		_notes_read.append(nm)


# ── five stalkers, beginning deeper in the Ward ──────────────────────────────
# B leaves the Ward's east route clear; C stands off the loop centre; D remains in the
# Morgue; E is beside the cradle; F guards the Sanctum. The entire tile hall is protected.
func _spawn_stalkers() -> void:
	_spawn_stalker("B", Vector3(-3.6, 0, 16.2), 0.0)
	_spawn_stalker("C", Vector3(13.15, 0, LOOP_STALKER_Z), PI)
	# ⚠️ Inside the Morgue, off the doorway's line (its capsule on the landing pad sealed the
	# TileHall -> Morgue doorway for check_doorways). Seen through the door from the causeway.
	_spawn_stalker("D", Vector3(-11.2, 0, 47.0), PI / 2.0)
	_spawn_stalker("E", Vector3(-12.0, 0, 32.2), PI / 2.0)
	_spawn_stalker("F", Vector3(-16.0, 0, 24.5), -PI / 2.0)


func _spawn_stalker(id: String, pos: Vector3, yaw: float) -> void:
	var s = _STALKER_SCRIPT.new()
	s.name = "Creature" + id
	s.position = pos
	s.rotation.y = yaw
	# ⭐ The scrape tell, back-ported from THE NIGHTMARE as its own header proposed: a dry drag
	# whenever one is advancing, so a player who cannot see it can still hear it.
	s.scrape_tell = true
	# ⭐ THE STARE (2026-09-20): the whisper that rises while you keep looking, from any distance.
	s.whisper = true
	# ⚠️ THE USER'S NUMBERS (2026-09-20 evening): 3.0 m/s unobserved against a 4.0 walk, a 2 m retreat.
	# Void only — the exports default to the shared 1.25 / 3.0 for the Nightmare.
	s.stalk_speed = 3.0
	s.retreat_distance = 2.0
	s.visual_script = _VOID_VISUAL
	s.protected_player_rect = _tile_rect
	var encounter := {"B": "Ward", "C": "LoopStraight", "D": "Morgue", "E": "ChildRoom", "F": "Sanctum"}
	s.leash = _room_rect(encounter[id]).grow(-0.55)
	add_child(s)
	_stalkers[id] = s


# ── zones ───────────────────────────────────────────────────────────────────────
func _spawn_zones() -> void:
	# The spawn's calm anchor: ONE box covering both candles and the spawn (the old two left a
	# 0.5 m gap exactly where the player stood).
	_add_zone(CalmZone.new(), "CalmThreshold", Vector3(0, 1.0, -1.5), Vector3(6.0, 3.0, 4.0))
	# Dread over the far wing: decay and pressure cancel, the walk to the note is an endurance.
	_add_zone(DreadZone.new(), "DreadFarWing", Vector3(-15.75, 1.65, 31.0), Vector3(11.5, 3.3, 23.0))
	# Dark rooms: the torch is the only light and having it off costs.
	# ⚠️ Follows the 12 x 10 Morgue by hand — _add_zone takes a literal, not the room rect.
	_add_zone(DarkZone.new(), "DarkMorgue", Vector3(-15, 1.5, 47.5), Vector3(12, 3, 10))
	# ⚠️ Follows the 8 x 7 ChildRoom by hand — _add_zone takes a literal, not the room rect.
	_add_zone(DarkZone.new(), "DarkChildRoom", Vector3(-14, 1.5, 33), Vector3(8, 3, 7))


func _add_zone(zone: Area3D, nm: String, pos: Vector3, size: Vector3) -> void:
	zone.name = nm
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)
	zone.position = pos
	add_child(zone)


# ── doors ───────────────────────────────────────────────────────────────────────
func _spawn_level_doors() -> void:
	var back := _make_door("BackDoor", false, true)
	back.position = Vector3(0, 1.1, -4.0 + 0.1 + 0.075)
	back.rotation.y = 0.0
	var exit := _make_door("ExitDoor", true, false)
	exit.unlock_condition = _DOOR_SCRIPT.UnlockCondition.TWIST_READ
	exit.position = Vector3(-14, 1.1, 19.5 + 0.1 + 0.075)
	exit.rotation.y = 0.0


func _make_door(door_name: String, advances: bool, back: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = door_name
	# ⭐ 2026-09-20 pass 3: the EXIT alone gets `void_exit_door.gd`, a door.gd subclass whose
	# `_open_door()` assembles its seven floating sub-rects into one whole door over 0.9 s
	# before it opens. ⚠️ Set BEFORE add_child, like every other script in this level.
	# The BackDoor keeps plain door.gd — the way back is not a payoff.
	body.set_script(_EXIT_DOOR_SCRIPT if advances else _DOOR_SCRIPT)
	body.advances_level = advances
	body.goes_back = back
	# ⭐ 2026-09-20: not build_visual() — the Void's doors are fractured slabs over the red plate
	# (void_door_visual.gd). The exit is the most broken door in the game; the back door less so.
	_DOOR_VISUAL.build(body, Vector3(1.0, 2.2, 0.15), 1.0 if advances else 0.6, 47 if advances else 48, _builder.wall_mat)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 2.2, 0.15)
	col.shape = sh
	body.add_child(col)
	add_child(body)
	return body


# ── player ──────────────────────────────────────────────────────────────────────
func _place_player() -> void:
	var p := _player()
	if p == null:
		return
	if GameState.entered_from_ahead:
		# Came back through the ending's door: stand by the exit in the Sanctum, facing in.
		p.global_position = Vector3(-14, 0.1, 21.5)
		p.rotation = Vector3(0, PI, 0)
	else:
		p.global_position = Vector3(0, 0.1, -2.0)
		p.rotation = Vector3(0, PI, 0)   # face the quiet entrance


func _start_ambience() -> void:
	var ambient: AudioStreamPlayer = get_node_or_null("AmbientPlayer")
	if ambient:
		var s := GameState.load_audio("ambient_void")
		if s:
			# ⚠️ The .import shipped with loop=false and the bed died after one play (capture #5,
			# 2026-09-20: "The music stopped playing"). Loop it in code so a re-import cannot regress it.
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			ambient.stream = s
		if ambient.stream:
			ambient.play()


# ── per frame ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_tick_shake(delta)
	_check_void_fall()
	_tick_tile_watch()
	_tick_loop_whisper(delta)
	_tick_footstep_echo(delta)
	_tick_step_through(delta)
	_tick_protection(delta)
	_tick_charge_protection(delta)
	_tick_corridor_charge()
	_tick_drawing_swap()


# ⭐ THE WHISPER FROM BOTH ENDS (lap 2+). One emitter at the corridor's south end carrying the
# SAME envelope creature C is generating at the north end, so from lap 2 a held stare is
# answered from behind you as well as in front. Silent at level 0, like C's own.
# ⚠️ No panic, no detection, no new term — it rides a cost the player is already paying.
func _tick_loop_whisper(_delta: float) -> void:
	if _south_whisper == null or _south_whisper.stream == null:
		return
	var want: float = 0.0
	if _loop_laps >= 2 and not _loop_broken:
		var c = _stalkers.get("C", null)
		if c and is_instance_valid(c) and c.has_method("whisper_level"):
			want = float(c.call("whisper_level"))
	if want <= 0.0:
		if _south_whisper.playing:
			_south_whisper.stop()
		return
	if not _south_whisper.playing:
		_south_whisper.play()
	# The same window creature_stalker.gd uses, so the two ends match in level and in pitch.
	_south_whisper.volume_db = lerpf(-38.0, -8.0, want)
	_south_whisper.pitch_scale = lerpf(1.0, 0.8, want)


# ⭐ THE FOOTSTEP ECHO (lap 3+, SCARY.md P2, Void-scoped). Your own steps come back half a beat
# late from two metres behind you, but ONLY inside the loop corridor and ONLY once the corridor
# has refused you three times. It is the one thing in the level that follows you and never
# arrives. ⚠️ Zero panic; the shared `footstep` sample; nothing is spawned.
func _tick_footstep_echo(delta: float) -> void:
	if _echo_player == null or _echo_player.stream == null:
		return
	if _echo_due >= 0.0:
		_echo_due -= delta
		if _echo_due <= 0.0:
			_echo_due = -1.0
			_echo_player.global_position = _echo_at
			_echo_player.play()
	var p := _player()
	if p == null or _loop_laps < 3:
		return
	if not _loop_rect.has_point(Vector2(p.global_position.x, p.global_position.z)):
		_echo_step = 0.0
		return
	if not bool(p.get("_is_moving")):
		_echo_step = 0.0
		return
	if not _echo_announced:
		_echo_announced = true
		_dbg("VOID loop footstep echo ARMED (lap %d, 0.35 s behind, 2 m back)" % _loop_laps)
	_echo_step -= delta
	if _echo_step <= 0.0:
		_echo_step = 0.5
		# +z is behind the player (forward is -basis.z), exactly as player.gd's own echo.
		_echo_at = p.global_position + p.global_transform.basis.z * 2.0 + Vector3(0, 0.45, 0)
		_echo_due = 0.35


# Fall off the broken geometry and the void claims you.
func _check_void_fall() -> void:
	var p := _player()
	if p and p.global_position.y < FALL_Y:
		Screamer.trigger()


# CreatureD watches from the far pad while you are on the tiles and never steps; the moment you
# are off them it stalks like the others.
func _tick_tile_watch() -> void:
	var p := _player()
	var d = _stalkers.get("D", null)
	if p == null or d == null or not is_instance_valid(d):
		return
	var inside: bool = _tile_rect.has_point(Vector2(p.global_position.x, p.global_position.z))
	if bool(d.get("watch_only")) != inside:
		d.set("watch_only", inside)


func _tick_shake(delta: float) -> void:
	# Stable footing and camera during alignment and the abyss reveal.
	var player := _player()
	if player and _tile_rect.has_point(Vector2(player.global_position.x, player.global_position.z)):
		_shake_duration = 0.0
		player.get_node("Camera3D").rotation.z = 0.0
		return
	if _shake_duration > 0.0:
		_shake_duration -= delta
		var p := _player()
		if p:
			var cam: Camera3D = p.get_node_or_null("Camera3D")
			if cam:
				cam.rotation.z = sin(Time.get_ticks_msec() * 0.05) * _shake_strength * (_shake_duration / 0.4)
		return
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		_reset_shake_timer()
		_shake_duration = 0.4
		_shake_strength = 0.008


func _reset_shake_timer() -> void:
	_shake_timer = randf_range(SHAKE_MIN, SHAKE_MAX)


# ── progress ────────────────────────────────────────────────────────────────────
func save_progress() -> Dictionary:
	var fragments := {}
	for f in _prop_fragments:
		if is_instance_valid(f):
			fragments[String(f.name)] = [bool(f.spent), bool(f.armed)]
	var drawers: Array = []
	for d in _drawers:
		if is_instance_valid(d) and bool(d.call("is_open")):
			drawers.append(String(d.name))
	return {"notes_read": _notes_read.duplicate(), "loop_broken": _loop_broken, "loop_laps": _loop_laps,
		"alignment_solved": _alignment.solved, "reveal_spent": _alignment.reveal_spent,
		"alignment_views": _alignment.call("views_solved"),
		"ward_spent": _ward_fragment.spent, "ward_armed": _ward_fragment.armed,
		"shard_taken": _shard_taken, "cradle_done": _cradle_done, "fragments_spent": fragments,
		# ⭐ pass 3: the quest's state. Without these a back-door return re-hangs three anchors
		# the player is carrying or has already seated, and re-shuts seventeen drawers.
		"anchors_taken": _anchors_taken.duplicate(), "carried_anchor": _carried_anchor,
		"sockets_filled": _alignment.call("sockets_filled"), "drawers_opened": drawers,
		# ⭐ pass 4. ⚠️ `secret_open` is named for what it means to the WORLD, not for what
		# triggered it (Issue 234): a wall is open or it is not, and a snapshot restores the wall.
		# The frames carry their own PERMUTATION as well as their seed, because the level's
		# attempt counter moves under a restart and a player who walks back in must find the room
		# they walked out of.
		"secret_open": _secret_open, "lunge_spent": _lunge_spent,
		# ⭐ pass 5. One shot, like the cradle's lunge: a restore records that it HAPPENED and
		# never replays it. The corridor is walked several more times after it fires.
		"corridor_charge_done": _charge_done,
		"drawing_swapped": _drawing_swapped,
		"frames": _frame_hall.call("save_state") if _frame_hall else {},
		"hidden_note_read": _notes_read.has("HiddenNote")}


func _restore_progress() -> void:
	var data := GameState.get_level_progress(8)
	# ⚠️ BEFORE the empty-progress early return, and that ordering is the bug this comment
	# exists for: arriving back through the ending's door with a cleared snapshot would
	# otherwise re-seal a twist note the player has demonstrably already read.
	if GameState.entered_from_ahead and GameState.twist_read:
		_unseal_sanctum_instantly()
	if data.is_empty():
		_apply_loop_ladder()
		return
	_notes_read = (data.get("notes_read", []) as Array).duplicate()
	_loop_broken = bool(data.get("loop_broken", false))
	_loop_laps = int(data.get("loop_laps", 0))
	_alignment.restore_state(bool(data.get("alignment_solved", false)),
		bool(data.get("reveal_spent", false)), data.get("alignment_views", []) as Array)
	_ward_fragment.restore_state(bool(data.get("ward_spent", false)), bool(data.get("ward_armed", false)))
	var fragments: Dictionary = data.get("fragments_spent", {})
	for f in _prop_fragments:
		if is_instance_valid(f) and fragments.has(String(f.name)):
			var pair: Array = fragments[String(f.name)]
			f.restore_state(bool(pair[0]), bool(pair[1]))
	_shard_taken = bool(data.get("shard_taken", false))
	_cradle_done = bool(data.get("cradle_done", false))
	_sync_shard()
	if _cradle_done:
		if _cradle and is_instance_valid(_cradle):
			_cradle.call("restore_state", true)
		if _sanctum_plate and is_instance_valid(_sanctum_plate):
			_sanctum_plate.set("moved_elsewhere", true)
	# ⭐ pass 4. ⚠️ THE PLATE IS NOW THE HIDDEN NOTE'S, NOT THE CRADLE'S — and a restore must
	# never replay a one-shot (the Ward frame's rule), so the lunge is marked spent, the secret
	# wall is simply gone and the drawing is simply a plan: no dip, no sting, no grind.
	_secret_open = false
	if bool(data.get("secret_open", false)):
		_open_secret_door_instantly()
	_lunge_spent = bool(data.get("lunge_spent", false))
	_charge_done = bool(data.get("corridor_charge_done", false))
	_drawing_swapped = bool(data.get("drawing_swapped", false))
	if _drawing_swapped:
		_apply_drawing_plan()
	if _frame_hall:
		_frame_hall.call("restore_state", data.get("frames", {}) as Dictionary)
	if bool(data.get("hidden_note_read", false)) or _notes_read.has("HiddenNote"):
		if _hidden_note and is_instance_valid(_hidden_note):
			_hidden_note.call("reveal")
		if not _notes_read.has("HiddenNote"):
			_notes_read.append("HiddenNote")
		_unseal_sanctum_instantly()
	# ⭐ the quest (pass 3). Anchors already taken are gone from the world; the ones seated in a
	# socket are back in their sockets; whichever one was in hand is in hand again.
	_anchors_taken = (data.get("anchors_taken", []) as Array).duplicate()
	for id in _anchors_taken:
		_free_anchor(String(id))
	_alignment.call("restore_sockets", data.get("sockets_filled", []) as Array)
	_carried_anchor = String(data.get("carried_anchor", ""))
	for nm in (data.get("drawers_opened", []) as Array):
		for d in _drawers:
			if is_instance_valid(d) and String(d.name) == String(nm):
				d.call("open_instantly")
	# ⚠️ reset_level_state() clears carried_item on every scene start, so walking back into the
	# Void holding the shard or an anchor would silently drop it and dead-end the chain.
	_update_carried()
	_apply_loop_ladder()


func _unseal_sanctum_instantly() -> void:
	if _sanctum_plate and is_instance_valid(_sanctum_plate):
		_sanctum_plate.call("move_aside_instantly")
	_sanctum_plate = null


# ── helpers ─────────────────────────────────────────────────────────────────────
func _room_rect(nm: String) -> Rect2:
	for r in ROOMS:
		if r["name"] == nm:
			var pos: Vector2 = r["pos"]
			var size: Vector2 = r["size"]
			return Rect2(pos - size * 0.5, size)
	return Rect2()


# ⭐ THE VOID WAS RENDERING A DAYLIT PROCEDURAL SKY (2026-09-03). `environment.tscn` is `BG_SKY`
# over a `ProceduralSkyMaterial`; every hole in a shell shows blue. The shell is CLOSED now (the
# rebuild replaced the eight junction gaps), but the abyss under the tile hall is a hole on
# purpose and must show BLACK. ⚠️ DUPLICATE FIRST: the resource is shared by every level.
func _black_background() -> void:
	var env_root := get_node_or_null("Environment")
	if env_root and env_root.get_child_count() > 0:
		_world_env = env_root.get_child(0) as WorldEnvironment
	if _world_env == null or _world_env.environment == null:
		return
	var env: Environment = _world_env.environment.duplicate()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world_env.environment = env


# ── test surface ────────────────────────────────────────────────────────────────
func get_stalkers() -> Dictionary:
	return _stalkers


func loop_laps() -> int:
	return _loop_laps


func loop_broken() -> bool:
	return _loop_broken


func tile_rect() -> Rect2:
	return _tile_rect


# ── test surface (pass 3) ───────────────────────────────────────────────────────
func drawers() -> Array:
	return _drawers.duplicate()


func page_drawer() -> Node:
	return _page_drawer


func anchors() -> Dictionary:
	return _anchors.duplicate()


func step_drops() -> int:
	return _step_drops


func shard() -> Node:
	return _shard


# ── test surface (pass 4) ───────────────────────────────────────────────────────
func secret_open() -> bool:
	return _secret_open


func secret_plug() -> Node:
	return _secret_plug if is_instance_valid(_secret_plug) else null


func secret_bridge() -> Node:
	return _secret_bridge if is_instance_valid(_secret_bridge) else null


func frame_hall() -> Node:
	return _frame_hall if is_instance_valid(_frame_hall) else null


func hidden_note() -> Node:
	return _hidden_note if is_instance_valid(_hidden_note) else null


# ⭐ pass 5. The ONE place that knows whether the stone over the twist note has moved, asked by
# `void_twist_note.gd` on every prompt and every E. It is the level's own reference, which
# `retract()`, `move_aside_instantly()` and `_unseal_sanctum_instantly()` all null in the same
# breath — so the gate cannot disagree with the geometry, whichever path cleared it.
func plate_stands() -> bool:
	return _sanctum_plate != null and is_instance_valid(_sanctum_plate)


func twist_note() -> Node:
	return _twist_note if is_instance_valid(_twist_note) else null


func cradle_done() -> bool:
	return _cradle_done


func lunge_spent() -> bool:
	return _lunge_spent


# ── test surface (pass 5) ───────────────────────────────────────────────────────
func corridor_charge_done() -> bool:
	return _charge_done


func charge_area() -> Area3D:
	return _charge_area if is_instance_valid(_charge_area) else null


func drawing_swapped() -> bool:
	return _drawing_swapped


func loop_swap_stage() -> int:
	return _loop_swap_stage


func step_bar_lean() -> float:
	var out := 0.0
	for i in range(_step_bars.size()):
		var bar := _step_bars[i] as Node3D
		if is_instance_valid(bar):
			out = maxf(out, (bar.rotation - (_step_bar_rest[i] as Vector3)).length())
	return out
