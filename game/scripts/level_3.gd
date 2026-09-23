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
# ⭐ 2026-09-23 pass 8: the fire the figure rises out of.
const _CRADLE_FIRE := preload("res://scripts/void_cradle_fire.gd")
const _FRAME_HALL := preload("res://scripts/void_frame_hall.gd")
const _HIDDEN_NOTE_SCRIPT := preload("res://scripts/void_hidden_note.gd")
# ⭐ 2026-09-20 pass 5: the twist note's own refusal, the receipt on the Ward's gurney, and the
# rule-less figure that charges the loop corridor on the way back.
const _TWIST_NOTE_SCRIPT := preload("res://scripts/void_twist_note.gd")
# ⭐ 2026-09-22 pass 6: the Ward's sealed strapped box, which the gurney's touch grinds open in
# plain view — the one prop in this level that changes while you are looking at it.
const _WARD_BOX_SCRIPT := preload("res://scripts/void_ward_box.gd")

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
#   slat    ⭐ INSIDE THE WARD BOX since pass 6 (-2.6, 14.5). The box's interior floor is at
#           y 0.22 and its walls top out at 0.62; the slat lies on that floor and the shut lid
#           is a real collider a descending E-ray stops on. It ALSO refuses by name while the
#           lid is down (`container` / `sealed_text`), because a blocker guards one viewing
#           angle and a refusal on the target guards all of them (Issue 242)
#   latch   inside Hall2's flat doorframe (7.0, 44.7), which has NO collider at all — and
#           which is the step-through, so the 1.2 s clock runs while you bend down for it
const ANCHORS := [
	{"id": "handle", "label": "a door handle", "family": "violet",
		"at": Vector3(0, 0.14, 0), "yaw": 1.1, "pose": Vector3(-1.35, 0.0, 0.25), "room": "PocketA"},
	{"id": "slat", "label": "a bed slat", "family": "bone",
		"at": Vector3(-2.33, 0.30, 14.56), "yaw": 0.22, "pose": Vector3(-1.45, 0.35, 0.05), "room": ""},
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
# ⭐ pass 7. The recurring room HOLDS the camera at a small roll; `_tick_shake()` shakes about
# this value instead of about zero, and restores it rather than leaving its last sine sample
# behind. One owner of `camera.rotation.z` in this level, and this is it.
var _camera_roll := 0.0
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
# ⭐ pass 7's cradle beat. `_shadow_lamp_energy` is [[Light3D, energy], …] captured when the
# room goes dark, so the restore hands back what was actually burning rather than a constant.
var _cradle_light: OmniLight3D = null
# ⭐ pass 8: the fire OWNS that light now — `_cradle_light` is the `CradleFire`'s own omni, so
# freeing the fire is what puts it out, and `_child_room_lights()` never sees it (it is a
# grandchild of the level, and that scan walks direct children only).
var _cradle_fire: Node3D = null
var _shadow_dark_on := false
var _shadow_lamp_energy: Array = []
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
# ── pass 6: the Ward box and the recurring room's cut to black ──
var _ward_box: StaticBody3D = null
var _ward_box_open := false
var _cut_layer: CanvasLayer = null
var _cut_rect: ColorRect = null
var _cut_depth := 0


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
# ⭐ THE TRIGGER MOVED TO z 26 ON 2026-09-22 (pass 6). Capture #3 of the 23:47 run: *"The
# jumpscare … appears too early. Let it be when around 60 % of the corridor is passed"*. It fired
# at z 43.2 — the corridor's north END, one step after the player turned round — and then spent a
# full second crossing 24.4 m of empty corridor, which reads as a cutscene. The walk back runs
# z 44 -> 14, so 60 % of it is z 26: the figure is 9.5 m ahead when it turns, and
# `void_cradle_figure.CHARGE_TIME` is 0.6 s.
const CHARGE_AREA_POS := Vector3(12.5, ROOM_H * 0.5, 26.0)   # x 11..14, z 25..27
const CHARGE_AREA_SIZE := Vector3(3.0, ROOM_H, 2.0)
const CHARGE_FIGURE_AT := Vector3(12.5, 0.0, 16.5)           # under Light_Loop_19, 9.5 m south
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
	# ⭐ THE CHARGE OWNS THE CAMERA (2026-09-22 pass 7, Issue 255). Capture 1 of the 02:13 run:
	# *"I was going backwards and I did not see the jumpscare — let's use our standard camera turn
	# move that we used multiple times."* The beat fired at z 27.2 exactly as designed and the
	# player was walking backwards, so the whole thing happened behind their head. Every other
	# in-world figure in the game takes the camera first — the Corridor's lunger at 0.18 s, the
	# Backrooms runner at 0.45 s, the HOLD apparitions — and this one did not.
	# ⚠️ `turn_to_face()`, never `ai_look_at()`: the former writes `player.gd`'s own `_pitch`, so
	# the turn survives the next mouse motion; `ai_look_at()` writes the camera node and snaps
	# back the instant the player twitches (which is its own header's warning, and it is test-only
	# for that reason). It also kills its own previous tween, so a second call cannot fight it.
	# ⚠️ INPUT IS NOT FROZEN. This level freezes only for hold-breath beats and for the recurring
	# room's cut; a 0.85 s freeze here would be a cutscene, which is the note capture 4 of the
	# previous run already made about this corridor.
	# ⚠️ AND THE RUSH STARTS WHEN THE TURN LANDS, without a signal: the figure's own
	# `TURN_TIME` (0.25 s) is the same 0.25 s, so `_begin_charge()` fires on the first frame after
	# the camera has arrived. The two clocks are deliberately equal and `check_void` measures the
	# yaw at the moment the rush begins rather than trusting that.
	p.call("turn_to_face", CHARGE_FIGURE_AT + Vector3(0, 1.35, 0), _CRADLE_FIGURE.TURN_TIME)
	var fig := _CRADLE_FIGURE.new() as Node3D
	fig.name = "ChargeFigure"
	add_child(fig)
	fig.call("arm_charge", p, CHARGE_FIGURE_AT, _charge_sting)
	_dbg("VOID corridor charge FIRED (player at %v, figure at %v, camera turned in %.2f s)"
		% [p.global_position, CHARGE_FIGURE_AT, _CRADLE_FIGURE.TURN_TIME])


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
	# ⭐ THE WARD BOX (2026-09-22 pass 6) replaces `FoldedFrame_Ward_L`. Capture #1 of the 23:47
	# run, photographing exactly this prop: *"the object closer to the monster looks like a bed,
	# but the one … further away … still does not remind anything … like a gift box"*. It is a
	# gift box now — sealed, strapped, with the bed slat inside it — and capture #2 asked for the
	# button: *"Should it be like a magical button that will open the magical box …?"* The button
	# is the gurney 1.2 m south of it, and the lid grinds back IN VIEW.
	_ward_box = _FRAGMENTS.strapped_box(self, Vector3(-2.6, 0, 14.5), 0.0, "WardBox", "bone",
		_WARD_BOX_SCRIPT)
	var answering := _FRAGMENTS.folded_frame(self, Vector3(2.6, 0, 14.5), 0.0, "FoldedFrame_Ward_R", "bone")
	# ⭐ THE OTHER FRAME ANSWERS (2026-09-20 pass 4). Capture #2: *"When you press touch the
	# suspended fragment — nothing changes."* It did — 57 seconds later, two rooms away, by a
	# 0.45 rad yaw, because the re-pose fired on the first look-away FROM ANYWHERE. Three fixes,
	# and the first is the user's ruling: the frame that moves is now the RIGHT one, 5.2 m across
	# the room, so you touch one thing and a DIFFERENT thing changes while you stand between
	# them; the re-pose is gated to the Ward's own rect so it cannot fire in another room; and it
	# grinds as it moves, so you hear it behind you and turn to a changed shape.
	# ⚠️ The bed slat is inside the Ward BOX and the box never moves — a slat that can be lost is
	# a hard softlock (all three sockets gate the Morgue seal), and the gurney's touch that opens
	# the box is a plain E with no precondition, so it can never be taken away either.
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
	# ⭐ THE ON-SCREEN half of the same press (pass 6). `rearranged` is the off-screen answer from
	# the right frame; `touched` is the box opening under the player's own eyes.
	_ward_fragment.connect("touched", _on_ward_touched)
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
# ⭐ AND IT IS TAKEABLE FROM FRAME 0 (2026-09-22 pass 6). Pass 3 hid it until the table re-posed
# itself; pass 5 showed it but WEDGED, refusing until the same look-away. Capture #4 of the 23:47
# run: refused five times over seven seconds, freed off-screen two seconds after the player left
# the room, taken on the way back — *"when I entered the room for the first time — I could not
# take the shard. And now … second time — I can. Should not be that way."* The receipt read as a
# lock. It now simply lies in the basin offering E, and the table's off-screen rearrangement
# survives as a PURE SCARE that gates nothing.
# ⚠️ `to_global`, never a hand-computed world point: the table is yawed 0.3 rad.
# ⚠️ The basin is handed over AFTER add_child — the node's `_ready()` runs before the mesh and
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
	_shard.position = basin
	add_child(_shard)
	_shard.call("set_basin", basin)
	_shard.connect("taken", _on_shard_taken)
	_sync_shard()


# ⭐ THE SHARD IS NO LONGER GATED BY ANYTHING (pass 6). All this does now is remove it from the
# world once it has been taken — `_shard_taken` means OUT OF THE WORLD and is never reset
# (Issue 234). The table's `rearranged` no longer touches it.
func _sync_shard() -> void:
	if _shard == null or not is_instance_valid(_shard):
		return
	if _shard_taken:
		_shard.queue_free()
		_shard = null


# ⚠️ THE TABLE STILL REARRANGES, AND IT STILL GIVES NOTHING. It is a pure P11 scare: a piece of
# furniture that is a different shape when you turn round. Hanging the shard's availability on it
# is what capture #4 read as a bug, and the beat itself was never the problem.
func _on_table_rearranged() -> void:
	_dbg("VOID archive table rearranged off-screen (a scare, nothing more)")


func _on_ward_answered() -> void:
	if _ward_grind:
		_ward_grind.play()
	_dbg("VOID ward frame answered — the RIGHT frame moved, 5.2 m from the one you touched")


# ⭐ THE BOX OPENS IN PLAIN VIEW (pass 6, and it deliberately breaks the level's own P11 rule for
# this ONE prop — Issue 243, twice photographed as "nothing happened"). The gurney is 1.2 m from
# the box, so the cause and the effect are in the same glance.
func _on_ward_touched() -> void:
	open_ward_box()


func open_ward_box() -> void:
	if _ward_box_open:
		return
	_ward_box_open = true
	if _ward_box and is_instance_valid(_ward_box):
		_ward_box.call("open", true)
	_dbg("VOID ward box OPENED — the lid grinds back and the bed slat is reachable")


# The slat's gate, asked of the level (void_anchor.gd `container` / `container_method`).
func ward_box_open() -> bool:
	return _ward_box_open


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
		# ⭐ THE SLAT IS SEALED IN THE WARD BOX (pass 6). Set BEFORE add_child, like every other
		# property here: `void_anchor.gd:_ready()` builds the mesh from these and a value set on
		# the line after `add_child` is a value set after `_ready()` (Issue 244).
		if String(spec["id"]) == "slat":
			a.set("container", self)
			a.set("container_method", "ward_box_open")
			a.set("sealed_text", "The box is sealed.")
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
#   1. ⭐ pass 7/8 — THE CRADLE BURNS AND THE FACE RISES OUT OF IT. See `_fire_cradle_shadow()`:
#      the camera is turned to the cradle, every light in the room and the torch go out, a fire
#      starts in the crib and grows for three seconds, and then the face comes up through the
#      flames on the user's `void_fire_jumpscare` at -2.0 dB and holds, mask at the rim, head tracking you.
#      Zero panic, no fail state;
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
	_fire_cradle_shadow()
	GameState.set_objective("Something opened in the far wing")


# ⚠️ CREATURE E STANDS TWO METRES FROM THE CRADLE. Blinding or pinning a player beside a
# lethal-contact creature is a coin-flip death (SCARY.md §8.11), and `DreadFarWing` cancels decay
# here so anything it cost would be permanent. E is suppressed with the tile hall's own
# mechanism — `creature_stalker.protected_player_rect` — set to the child room for the beat plus
# one second. ⚠️ RESTORED to `_tile_rect`, never cleared: that rect is what stops all five
# stalkers while the player is out on the causeway, and clearing it would quietly delete E's half
# of a rule that has nothing to do with this scare.
# ⭐ THE CRADLE BEAT (2026-09-22 pass 7). Capture 2 of the 02:13 run, standing over the completed
# cradle: *"The jumpscare is the same as the one in the corridor… a shadow will spawn inside this
# object for several seconds while all the light will be removed and in the complete darkness you
# will see only it and it will be a creepy sound."* It was: pass 4/5's rush to 0.6 m with the
# shared `jumpscare`, the same figure, the same rush and the same sound as the corridor charge
# forty metres away. The corridor keeps its rush. This one is the opposite of a rush.
#
# ⭐ AND IT BURNS SINCE PASS 8 — the full clock is on `SHADOW_FIRE` below. In one line: the
# camera comes round (0.3 s), the room and the torch go out, a fire grows in the crib for 3 s,
# the face rises through it over 0.5 s with the snarl, it holds 2 s, and fire, light and figure
# fade out together in 0.3 s before the room comes back 0.4 s later.
#
# ⚠️ ZERO PANIC, AND THAT COSTS A GUARD. `DarkChildRoom` is a `DarkZone` over this room, and
# `player.gd` charges DARK_PANIC_RATE 3/s while the torch is off inside one — 6.2 s of blackout
# is 18.6 points of panic for doing the thing the puzzle asked, and pass 8 made the beat LONGER,
# so this matters more than it did. That is Issue 18's shape exactly
# (never tax the posture a beat requires), so the zone is held off for the beat and handed back
# after. `check_void` proves `_panic` unchanged across the whole thing with `RandomAmbient`
# unregistered (Issue 240).
# ⚠️ `force_flashlight_off()` / `restore_flashlight()`, the DEPTH-COUNTED blackout pair — never
# `kill_flashlight()`, which is the Corridor's permanent one and would end the level in the dark.
# ⚠️ CREATURE E STANDS TWO METRES AWAY and the player is about to be blinded. It is suppressed
# with the tile hall's own mechanism (`protected_player_rect`) for the beat plus a second, and
# RESTORED to `_tile_rect`, never cleared: that rect is what stops all five stalkers while the
# player is out on the causeway.
# ⚠️ ONE SHOT, saved as `lunge_spent`, and `_restore_progress()` never replays it.
# ⭐ AND SINCE 2026-09-23 (pass 8) THE CRADLE BURNS. Capture #3 of the 23:10 run, standing over
# the completed cradle: *"make this visual of the monster showing up as a jumpscare more brutal.
# Firstly, the jumpscare itself should be louder. Secondly, maybe add animation like there is
# fire for like 3 seconds and then this face appears from fire?"* Both halves, exactly:
#
#   t 0.0   the camera is TURNED to the cradle (0.3 s); every light in the room goes to 0 and
#           the torch is put out — pass 7's opening, unchanged
#   t 0.0   …and a FIRE starts in the crib. `void_cradle_fire.gd`: six additive billboarded
#           flame quads on their own phases, an orange omni ramping 0 -> 0.9 over the first
#           second and then flickering, and `cradle_fire` looping under it. Pass 7's second of
#           nothing becomes three seconds of a fire growing, which is the only thing in the
#           world and the only warm colour in this level
#   t 3.0   the FACE COMES UP THROUGH THE FLAMES over 0.5 s, the user's `void_fire_jumpscare` with it at
#           -2.0 dB — 6.6 dB hotter than pass 7, and near the file's ceiling
#   t 3.5   it holds, mask at the rim, head tracking you
#   t 5.5   fire, light and figure die together over 0.3 s
#   t 5.8   black
#   t 6.2   the lamps and the torch come back
#
# ⚠️ THE VIOLET `CradleLight` IS GONE and its constants with it (`CRADLE_LIGHT_COLOR` 0.6/0.5/0.9,
# `CRADLE_LIGHT_ENERGY` 0.40, `CRADLE_LIGHT_DROP` 0.45, `CRADLE_LIGHT_RANGE` 1.8). A dead constant
# beside a live one is how a later pass re-prices the wrong beat. The fire's own omni is the only
# light in the room now, and `void_cradle_fire.gd` holds its arithmetic — including why 0.9 energy
# cannot clamp the mask (`omni_attenuation` 0.0: a fire is a volume, not a point).
const SHADOW_TURN := 0.3        # the camera comes round to the cradle
const SHADOW_FIRE := 3.0        # …and the fire grows, alone, for three seconds
const SHADOW_RISE := 0.5        # the face comes up out of it
const SHADOW_HOLD := 2.0        # …and stands there
const SHADOW_FADE := 0.3        # fire, light and figure die together
const SHADOW_TAIL := 0.4        # black again, before the room comes back
# How far below its final pose the figure starts. The cradle's broken bed is at local y 0.91 and
# the rim at 1.768: 0.80 m puts the mask down in the flames and brings it out of them.
const SHADOW_RISE_FROM := 0.80
# ⚠️ THE FLAMES STAND ON THE CRADLE'S OWN BROKEN BED, handed to the fire in WORLD space by
# `_cradle.to_global()` — never hand-computed, and never the bbox centre. `void_fragments`
# builds `BrokenBed` as a 0.74 x 0.10 x 0.60 slab at local (-0.16, 0.86, 0.14), so its top face
# is local y 0.91 and that is where a fire in a crib starts.
const CRADLE_FIRE_BASE := Vector3(-0.16, 0.91, 0.14)


func _fire_cradle_shadow() -> void:
	if _lunge_spent:
		return
	_lunge_spent = true
	var p := _player()
	if p == null or _cradle == null or not is_instance_valid(_cradle):
		return
	var e = _stalkers.get("E", null)
	if e and is_instance_valid(e):
		e.set("protected_player_rect", _room_rect("ChildRoom"))
		_protect_restore = _shadow_beat_length() + 1.0
	# ⭐ pass 5's ruling survives the rewrite: the target is the CRADLE'S OWN geometry, not the
	# node origin, which sits on the floor like every `_body()` prop in this level.
	p.call("turn_to_face", _cradle_bbox().position + _cradle_bbox().size * 0.5
		+ Vector3(0, 0.9, 0), SHADOW_TURN)
	_run_cradle_shadow()


# The whole beat, turn excluded: three seconds of fire, the rise, the hold, the shared fade and
# the black tail. ⚠️ ONE EXPRESSION, read by the beat AND by E's suppression window — pass 7 had
# the same sum written out twice and a later pass changing one of them would have left a blinded
# player standing next to a live creature.
func _shadow_beat_length() -> float:
	return SHADOW_FIRE + SHADOW_RISE + SHADOW_HOLD + SHADOW_FADE + SHADOW_TAIL


func _run_cradle_shadow() -> void:
	_shadow_dark()
	await get_tree().create_timer(SHADOW_FIRE, true, false, false).timeout
	if not is_instance_valid(self):
		return
	_shadow_show()
	await get_tree().create_timer(SHADOW_RISE + SHADOW_HOLD, true, false, false).timeout
	if not is_instance_valid(self):
		return
	_shadow_hide()
	await get_tree().create_timer(SHADOW_FADE, true, false, false).timeout
	if not is_instance_valid(self):
		return
	_shadow_gone()
	await get_tree().create_timer(SHADOW_TAIL, true, false, false).timeout
	if not is_instance_valid(self):
		return
	_shadow_restore()


# Every light whose position is inside the child room's rect, found by geometry rather than by
# name: a later pass that adds a second fitting in here must not leave one lamp burning through
# the one beat whose whole premise is that there is no light but the cradle's.
# ⚠️ THE BEAT'S OWN LIGHT IS NOT A ROOM LAMP. `CradleLight` is an OmniLight3D sitting inside this
# very rect, so the first draft of this counted it, tried to put it out in `_shadow_dark()` (it
# does not exist yet) and then "restored" it in `_shadow_restore()` — and the guard caught it as
# "1 of 2 lamps back". The room's lamps are the ones that were burning before the beat began.
# ⭐ pass 8 made that structural rather than careful: the beat's light is now a CHILD of
# `CradleFire`, and this scan walks the level's DIRECT children, so it cannot be reached at all.
# The `!= _cradle_light` test is kept anyway — it costs nothing and it is the invariant, not the
# implementation, that matters here.
func _child_room_lights() -> Array:
	var out: Array = []
	var rect := _room_rect("ChildRoom")
	for c in get_children():
		if c is Light3D and c != _cradle_light:
			var l := c as Light3D
			if rect.has_point(Vector2(l.global_position.x, l.global_position.z)):
				out.append(l)
	return out


func _cradle_bbox() -> AABB:
	var box := AABB()
	var found := false
	var stack: Array = [_cradle]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var w: AABB = mi.global_transform * mi.get_aabb()
			box = w if not found else box.merge(w)
			found = true
		for c in n.get_children():
			stack.append(c)
	return box if found else AABB(_cradle.global_position, Vector3.ONE)


func _shadow_dark() -> void:
	if _shadow_dark_on:
		return
	_shadow_dark_on = true
	_shadow_lamp_energy = []
	for l in _child_room_lights():
		_shadow_lamp_energy.append([l, float((l as Light3D).light_energy)])
		(l as Light3D).light_energy = 0.0
	_hold_child_dark(true)
	var p := _player()
	if p and is_instance_valid(p):
		p.call("force_flashlight_off")
	_dbg("VOID cradle shadow — the room and the torch go out")
	_light_cradle_fire()


# ⭐ pass 8. The fire is lit in the SAME breath as the blackout — there is no second of nothing
# any more, there are three seconds of a fire growing in a black room.
# ⚠️ THE LIGHT IS THE FIRE'S. `_cradle_light` points at `CradleFire`'s own omni, so there is
# exactly one light source in this beat and freeing the fire is what puts it out. Nothing here
# creates a lamp of its own, and `_child_room_lights()` cannot see it (that scan walks the
# level's DIRECT children and this is a grandchild) — which is the fix for the trap pass 7
# documented, not a new hazard.
func _light_cradle_fire() -> void:
	if _cradle == null or not is_instance_valid(_cradle):
		return
	if _cradle_fire and is_instance_valid(_cradle_fire):
		return
	_cradle_fire = _CRADLE_FIRE.new() as Node3D
	_cradle_fire.name = "CradleFire"
	add_child(_cradle_fire)
	# ⚠️ THE LIGHT LEANS TOWARD THE PLAYER (Issue 258). The flames stay on the bed; the fire's
	# lamp is handed the direction the face will be looked at from, or the rising mask is a
	# silhouette against its own fire — measured on the first 2.5 m render of this beat.
	var pl := _player()
	var toward: Vector3 = Vector3.ZERO
	if pl and is_instance_valid(pl):
		toward = pl.global_position - _cradle.global_position
	_cradle_fire.call("ignite", _cradle.to_global(CRADLE_FIRE_BASE), toward)
	_cradle_light = _cradle_fire.call("light") as OmniLight3D


func _shadow_show() -> void:
	var p := _player()
	if p == null or _cradle == null or not is_instance_valid(_cradle):
		return
	var box := _cradle_bbox()
	var centre: Vector3 = box.position + box.size * 0.5
	if _cradle_sting == null:
		_cradle_sting = _make_snarl("CradleSnarl")
	var fig := _CRADLE_FIGURE.new() as Node3D
	fig.name = "CradleFigure"
	add_child(fig)
	# ⚠️ IT RISES, and it rises THROUGH the flames rather than beside them: the fire stands on
	# the cradle's broken bed and the figure starts 0.80 m below the pose it ends in, which is
	# the same bed. The end pose is pass 7's exactly — mask at the rim, nothing towering.
	fig.call("arm_shadow", p, _cradle, SHADOW_RISE_FROM, SHADOW_RISE)
	if _cradle_sting and is_instance_valid(_cradle_sting) and _cradle_sting.stream:
		_cradle_sting.global_position = centre + Vector3(0, 0.9, 0)
		_cradle_sting.play()
	_dbg("VOID cradle fire — the face rises (%.2f m over %.2f s, snarl at %.1f dB)"
		% [SHADOW_RISE_FROM, SHADOW_RISE, SNARL_DB])


# ⭐ pass 8: this only STARTS the shared fade. The figure is visible by the fire's light and by
# nothing else, so fading the fire IS fading the figure — they die together because they are
# lit together, not because three tweens were synchronised.
func _shadow_hide() -> void:
	if _cradle_fire and is_instance_valid(_cradle_fire):
		_cradle_fire.call("extinguish", SHADOW_FADE)


# …and this is the end of that fade: everything the beat built leaves the world.
func _shadow_gone() -> void:
	if _cradle_fire and is_instance_valid(_cradle_fire):
		_cradle_fire.queue_free()
	_cradle_fire = null
	_cradle_light = null
	var fig := get_node_or_null("CradleFigure")
	if fig and is_instance_valid(fig):
		fig.call("dismiss")
	_dbg("VOID cradle fire OUT — the fire, the light and the figure are gone")


func _shadow_restore() -> void:
	if not _shadow_dark_on:
		return
	_shadow_dark_on = false
	for pair in _shadow_lamp_energy:
		var l = pair[0]
		if is_instance_valid(l):
			(l as Light3D).light_energy = float(pair[1])
	_shadow_lamp_energy = []
	var p := _player()
	if p and is_instance_valid(p):
		p.call("restore_flashlight")
	_hold_child_dark(false)
	_dbg("VOID cradle shadow — the room and the torch come back")


# ⚠️ THE AREA3D DOES THE COUNTER ARITHMETIC, NOT US, and that is measured rather than assumed.
# `player.gd` tracks `_dark_zones` as a COUNT of overlapping zones, incremented from
# `DarkZone._on_body_entered`; a beat that decremented it by hand and re-incremented afterwards
# would leave it permanently wrong for any player who walked out of the room mid-beat. Measured
# in Godot 4.6.3 with a throwaway probe: writing `monitoring = false` emits `body_exited` for
# everything inside IN THE SAME FRAME, and writing it back to true emits `body_entered` for
# whatever is inside THEN. So the zone corrects itself whichever side of the doorway the player
# is standing on when the beat ends, and nothing here touches the counter.
# ⚠️ EVERY DarkZone, not just the child room's, and that is measured rather than cautious. The
# beat does not freeze input — the player can walk during the 6.2 s — and `DarkMorgue` is six
# metres away through Hall3, which is two seconds at walking speed. Holding only the room the
# beat happens in would charge 3/s to anyone who walked out of it while the LEVEL was holding
# their torch off, which is Issue 18 with a longer fuse. The zones come back together.
func _hold_child_dark(off: bool) -> void:
	for c in get_children():
		if c is DarkZone and is_instance_valid(c):
			(c as Area3D).monitoring = not off


# ⭐ THE SOUND WAS `apparition_snarl` (2026-09-22 pass 7) and is now the USER'S `void_fire_jumpscare`
# (2026-09-23 — see `_make_snarl`); the pass-7 arithmetic below is kept as the record of how the
# gain was first set. Not the shared `jumpscare`: capture 2's
# complaint was sameness, and the corridor charge 40 m away keeps the jumpscare.
# ⚠️ -8.6 dB IS ARITHMETIC, not a plausible number. Measured with ffmpeg volumedetect:
# `apparition_snarl.ogg` is 6.26 s, mean -4.5 dBFS, peak 0.0. The sting it replaces was
# `jumpscare.wav` (mean -2.8 dBFS) at -10.3 dB, i.e. -13.1 dBFS delivered at the source. To land
# the snarl at the same delivered mean: -13.1 - (-4.5) = **-8.6 dB**. Its peak then sits at
# -8.6 dBFS, and with the +3 dB `max_db` clamp at the 0.9 m the beat plays it from, the loudest
# sample is -5.6 dBFS — under the ceiling.
# ⚠️ MASTER, like every sting in this level: `HoldBreath.dip()` ducks Ambience, and a sting on
# Ambience lands inside somebody else's silence. `screamer.gd` routes its own the same way.
# ⚠️ Its body is the first ~3.5 s (per-second means -1.0 / -1.2 / -2.1 / -12.6 / -23.8 / -44.8),
# which is the 0.5 s rise plus the 2.0 s hold plus the 0.3 s fade plus the 0.4 s tail almost
# exactly; the tail rings out under the restored room rather than being cut off.
#
# ⭐ -8.6 -> -2.0 dB ON 2026-09-23 (pass 8), AND IT IS THE USER'S CALL, NOT THE BUILDER'S.
# Capture #3 of the 23:10 run: *"the jumpscare itself should be louder"*. -2.0 is 6.6 dB hotter
# than the delivered-level match pass 7 computed, and it is deliberately near the ceiling rather
# than at it: `apparition_snarl.ogg` PEAKS at 0.0 dBFS, so at -2.0 dB the loudest sample sits at
# -2.0 dBFS, and with `AudioStreamPlayer3D`'s +3 dB `max_db` clamp at the 0.9 m this is played
# from it is the clamp, not the file, that is the last stop. There is no room above this: the
# next step up is distortion.
const SNARL_DB := -2.0


# ⭐ 2026-09-23: the USER SUPPLIED the fire's sting — `void_fire_jumpscare.mp3` (10.1 s, mean -6.1 dBFS,
# peak 0.0; it hits at -1..0 dBFS from its first frame and decays to silence over ten seconds), so it
# starts the moment the face rises and its tail rings past the beat's end. SNARL_DB stays -2.0: the
# file peaks at 0 dBFS, so that is the ceiling. `apparition_snarl` is no longer loaded here.
func _make_snarl(nm: String) -> AudioStreamPlayer3D:
	var s := GameState.load_audio("void_fire_jumpscare")
	if s == null:
		return null
	var pl := AudioStreamPlayer3D.new()
	pl.name = nm
	pl.stream = s
	pl.volume_db = SNARL_DB
	pl.unit_size = 4.0
	add_child(pl)
	return pl


# ⚠️ SCREENSHOT / TEST HOOK, the pattern `void_exit_door.gd:snap_assembled()` set: a timed beat
# is a RACE with a capture and the capture always loses — the frame worth reading is 1.0 s in,
# and the screenshot tool captures 12 frames after it sets up. This drives the SAME two steps
# the beat drives, in the same order, with the waits taken out, and then simply does not run
# the rest. Nothing is faked.
func snap_cradle_shadow() -> void:
	_lunge_spent = true
	_shadow_dark()
	_shadow_show()


# ⭐ pass 8. Two frames are worth reading in this beat and neither is reachable by waiting: the
# FIRE at its peak (t ~2.5 s, before anything rises out of it) and the FACE in the flames (the
# rise complete). Both drive the level's own `_shadow_dark()` / `_light_cradle_fire()` /
# `_shadow_show()`; only the clock is taken out, by `advance_to()` on the fire and by driving the
# figure's own rise to its end.
func snap_cradle_fire(at_age: float) -> void:
	_lunge_spent = true
	_shadow_dark()
	if _cradle_fire and is_instance_valid(_cradle_fire):
		_cradle_fire.call("advance_to", at_age)


func snap_cradle_face() -> void:
	snap_cradle_fire(SHADOW_FIRE)
	_shadow_show()
	var fig := get_node_or_null("CradleFigure")
	if fig and is_instance_valid(fig):
		fig.call("_process", SHADOW_RISE)


# ⭐ 2026-09-23: the USER SUPPLIED the corridor's sting — `void_corridor_jumpscare.wav` (2.17 s,
# 24-bit stereo, mean -0.8 dBFS, peak 0.0, silent after 2 s). It replaces the shared `jumpscare`
# (pass 5) on MASTER. ⚠️ CHARGE_STING_DB -12.3 IS MEASURED, not chosen: the shared file delivered
# -13.1 dBFS at the source (-2.83 dBFS RMS at -10.3 dB), and the new file's mean is -0.8 dBFS, so
# -12.3 dB lands it exactly there. Its peak is 0.0 dBFS: the gain cannot rise without clipping.
# ⚠️ MASTER, not `AudioBuses.AMBIENCE`: `HoldBreath.dip()` ducks Ambience to -30 dB for the
# cradle's beat, and a sting inside its own silence is the opposite of the effect.
# `screamer.gd` routes its own the same way for the same reason.
const CHARGE_STING_DB := -12.3


func _make_sting(nm: String) -> AudioStreamPlayer3D:
	var s := GameState.load_audio("void_corridor_jumpscare")
	if s == null:
		return null
	var pl := AudioStreamPlayer3D.new()
	pl.name = nm
	pl.stream = s
	pl.volume_db = CHARGE_STING_DB
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


# ⭐ THE CUT TO BLACK (2026-09-22 pass 6) — the recurring room's only transition.
#
# ⚠️ THE LEVEL OWNS IT, not `void_frame_hall.gd`, for two reasons: the panel is a CanvasLayer and
# the hall is a Node3D full of geometry, and the player is the level's node. It is deliberately
# NOT `Screamer.flash_scare()` (a fullscreen image and a scream) and NOT `HoldBreath` (a bus dip):
# it is 0.3 s of literally nothing, which is the only medium in which "the room changed" can be
# true and unwitnessed at the same time (Issue 241's real fix).
#
# `while_black` runs with the panel UP and the player frozen. That ordering is the whole point:
# the caller's mutation is invisible by construction rather than by a line-of-sight test that a
# five-frame room cannot satisfy.
# ⚠️ PROCESS_MODE_ALWAYS on the layer, and the timer is created with `process_always` — a note or
# the journal opening mid-cut would otherwise pause the tree and leave the screen black forever.
# ⚠️ `_cut_depth` counts, so two overlapping cuts cannot leave the panel up (HoldBreath's
# `_active` lesson, in the form a level can actually hit: the hall is re-entrant across an await).
# ⚠️ ZERO PANIC, and `freeze_input()` is safe here because nothing in this level charges for
# standing still — Issue 182's standstill term is Backrooms-only and opt-in.
const CUT_LAYER := 80


func _build_cut_layer() -> void:
	_cut_layer = CanvasLayer.new()
	_cut_layer.name = "VoidCutLayer"
	_cut_layer.layer = CUT_LAYER
	_cut_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_cut_layer)
	_cut_rect = ColorRect.new()
	_cut_rect.name = "CutRect"
	_cut_rect.color = Color(0, 0, 0, 1)
	_cut_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cut_rect.visible = false
	_cut_layer.add_child(_cut_rect)


func cut_to_black(seconds: float, while_black: Callable = Callable()) -> void:
	if _cut_rect == null or not is_instance_valid(_cut_rect):
		if while_black.is_valid():
			while_black.call()
		return
	_cut_depth += 1
	_cut_rect.visible = true
	var p := _player()
	if p and is_instance_valid(p):
		p.velocity = Vector3.ZERO
		p.call("freeze_input")
	if while_black.is_valid():
		while_black.call()
	await get_tree().create_timer(seconds, true, false, false).timeout
	if not is_instance_valid(self):
		return
	_cut_depth = maxi(0, _cut_depth - 1)
	if _cut_depth == 0 and is_instance_valid(_cut_rect):
		_cut_rect.visible = false
	var p2 := _player()
	if p2 and is_instance_valid(p2):
		p2.call("unfreeze_input")


func cut_is_black() -> bool:
	return _cut_rect != null and is_instance_valid(_cut_rect) and _cut_rect.visible


# ⭐ THE RECURRING ROOM + the page at the end of it.
func _build_frame_hall() -> void:
	_build_cut_layer()
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
		# ⭐ The secret room's lamp, owned by `void_frame_hall.gd` from here on: this is only the
		# state it is BUILT in and drops back to on a wrong door. ⚠️ The pass-4 comment that used
		# to sit here ("one step brighter per right answer, out for two seconds on a wrong one")
		# had been a fossil since pass 6 replaced that with a single 0.25 -> 0.12 drop, and the
		# pass-7 ladder moves even that to stage 3 and adds two colour notches — the lamp is the
		# one channel in this room the player's own torch drowns out ten to one (Issue 256), so
		# it is deliberately NOT where the ladder is spent. See `void_frame_hall.gd`'s ladder
		# header for the light-budget arithmetic.
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


# ⚠️ THE SHAKE AND THE RECURRING ROOM'S HELD ROLL ARE TWO OWNERS OF `camera.rotation.z`, and
# this is where they are reconciled (2026-09-22 pass 7). The shake used to write an absolute sine
# about ZERO and then simply stop writing when its 0.4 s ran out, which (a) wiped the room's roll
# for the length of every shake and (b) left a residue of whatever the last sample happened to be
# — measured at -0.0012 rad with no roll in play at all, and it is why the settle's "roll is
# zeroed" assert went red the first time it was written. Both halves are fixed by making the
# shake a DISPLACEMENT about `_camera_roll` and by restoring that base on the frame it ends.
func _tick_shake(delta: float) -> void:
	# Stable footing and camera during alignment and the abyss reveal.
	var player := _player()
	if player and _tile_rect.has_point(Vector2(player.global_position.x, player.global_position.z)):
		if _shake_duration > 0.0:
			_shake_duration = 0.0
			player.get_node("Camera3D").rotation.z = _camera_roll
		return
	if _shake_duration > 0.0:
		_shake_duration -= delta
		var p := _player()
		if p:
			var cam: Camera3D = p.get_node_or_null("Camera3D")
			if cam:
				if _shake_duration <= 0.0:
					cam.rotation.z = _camera_roll
				else:
					cam.rotation.z = _camera_roll + sin(Time.get_ticks_msec() * 0.05) \
						* _shake_strength * (_shake_duration / 0.4)
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
		# ⭐ pass 6. `frame_stage` is how strange the room is; the hall stores the same number as
		# its own `progress`, and `frames` carries the permutation with it because the level's
		# attempt counter moves under a restart. `ward_box_open` is a state of the WORLD — a lid
		# is up or it is not — so a restore opens it silently, with no tween and no grind.
		"frame_stage": int(_frame_hall.call("progress")) if _frame_hall else 0,
		"ward_box_open": _ward_box_open,
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
	# ⭐ pass 6: the lid is simply up, with no grind and no tween — a snapshot must never replay
	# a one-shot beat (the Ward frame's rule).
	_ward_box_open = bool(data.get("ward_box_open", false))
	if _ward_box_open and _ward_box and is_instance_valid(_ward_box):
		_ward_box.call("open", false)
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
	# ⚠️ THE SNAPSHOT IS THE WHOLE SET, NOT A LIST OF THINGS TO DO (pass 8). Drawers close again
	# since the 23:10 playtest, so "not in the list" means SHUT, and a restore that only opened
	# the named ones would hand back `OPEN_DRAWER` standing out for a player who had pushed it
	# in — `_wire_drawers()` pulls that one at build time, every time.
	var open_set: Array = (data.get("drawers_opened", []) as Array)
	for d in _drawers:
		if not is_instance_valid(d):
			continue
		if open_set.has(String(d.name)):
			d.call("open_instantly")
		else:
			d.call("close_instantly")
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


func ward_box() -> Node:
	return _ward_box if is_instance_valid(_ward_box) else null


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


# ⭐ THE ROOM'S HELD ROLL (pass 7), routed through the level so the ambient shake can see it.
# ⚠️ `player.gd` is NOT touched: `_rotate_camera()` writes only `camera.rotation.x` (through
# `_pitch`), so z belongs to this level — but it belongs to ALL of this level, which is the whole
# reason this is a level method and not a line in `void_frame_hall.gd`.
func set_camera_roll(v: float) -> void:
	_camera_roll = v
	var p := _player()
	var cam: Camera3D = p.get_node_or_null("Camera3D") if p else null
	if cam and _shake_duration <= 0.0:
		cam.rotation.z = v


func camera_roll_base() -> float:
	return _camera_roll


# ── test surface (pass 7: the cradle beat) ──────────────────────────────────────
func cradle_light() -> OmniLight3D:
	return _cradle_light if is_instance_valid(_cradle_light) else null


func cradle_light_on() -> bool:
	return is_instance_valid(_cradle_light) and _cradle_light.visible \
		and _cradle_light.light_energy > 0.0


func shadow_dark() -> bool:
	return _shadow_dark_on


func child_room_lights() -> Array:
	return _child_room_lights()


# ⚠️ The ZONE's own state, not the player's counter: the claim being proved is that the level
# held the zone off, and `player.gd:_dark_zones` is the thing that must be seen to come back.
func child_dark_zone_live() -> bool:
	var z := get_node_or_null("DarkChildRoom") as Area3D
	return z != null and z.monitoring


# …and every one of them, so a guard can prove the beat did not leave a zone switched off.
func dark_zones_live() -> int:
	var n := 0
	for c in get_children():
		if c is DarkZone and (c as Area3D).monitoring:
			n += 1
	return n


func cradle_bbox() -> AABB:
	return _cradle_bbox()
