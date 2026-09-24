extends Node3D
class_name HouseWindow

# THE LIVING ROOM'S TALL WEST WINDOW (2026-09-24, the Porch pass). It replaces the north-wall
# window, whose forest was a painted quad because that wall backed onto the Bedroom 0.5 m away.
# This one is a real opening in a real outside wall: through it you see the porch, the rail, the
# yard and the trees, and after the forest scare it BURSTS INWARD and becomes the way out.
#
# ⚠️ FLOOR-LENGTH (a French window, 1.4 x 2.3 m) because the player controller cannot step over a
# sill — `move_and_slide` does not climb even 0.1 m (the cellar-ramp lesson, Session 11). The
# opening itself is a RoomBuilder cut (`level_2.gd:WALL_CUTS`, full height) with a lintel block
# filling it above 2.3 m; this node is everything IN the opening.
#
# Two groups:
#   * the CASING — jambs and head, fixed, survives the burst;
#   * the SASH — stiles, rails, the low boards at its foot, the mullion, two transoms and the
#     glass — plus `Pane`, a real layer-1 collider that blocks the player until `break_pane()`.
#
# `move_aside_instantly()` is the restore path (a back-door return, and `check_reachable.gd`'s
# gate): the same end state, silently, with no sound and no tween.
#
# Frame: this node sits at the opening's centre on the wall plane with no rotation, so local +X
# points INTO the living room and local Z runs along the wall.

signal burst(animated: bool)

const W := 1.4                    # the opening (RoomBuilder cut width)
const HEAD_Y := 2.22              # underside of the head casing; the lintel starts at 2.30
const CASING := 0.08
const DEPTH := 0.28               # casing depth — proud of both faces of the 0.2 m wall
const SASH_T := 0.05
const LEAF_BOTTOM := 0.25         # the low boards at its foot
const LEAF_TOP := 2.16
const SHARDS := 18
const SPLINTERS := 7
const DEBRIS_SEED := 2409

var _broken: bool = false
var _sash: Node3D = null
var _pane: StaticBody3D = null
var _wind: AudioStreamPlayer3D = null
var _wood: StandardMaterial3D = null
var _glass: StandardMaterial3D = null


func _ready() -> void:
	_build()


func is_broken() -> bool:
	return _broken


func pane_body() -> StaticBody3D:
	return _pane if is_instance_valid(_pane) else null


func move_aside_instantly() -> void:
	break_pane(false)


# The glass goes INWARD, toward the player who just pressed their face to it. `animate` false is
# the restore path: the debris is laid where it would have landed, and nothing is heard.
func break_pane(animate: bool) -> void:
	if _broken:
		return
	_broken = true
	if is_instance_valid(_pane):
		_pane.collision_layer = 0
		_pane.queue_free()
		_pane = null
	if is_instance_valid(_sash):
		_sash.queue_free()
		_sash = null
	var rng := RandomNumberGenerator.new()
	rng.seed = DEBRIS_SEED
	for i in range(SHARDS + SPLINTERS):
		var splinter := i >= SHARDS
		var mi := MeshInstance3D.new()
		mi.name = "WindowDebris"
		var bm := BoxMesh.new()
		if splinter:
			bm.size = Vector3(rng.randf_range(0.30, 0.85), 0.03, 0.05)
		else:
			bm.size = Vector3(rng.randf_range(0.06, 0.22), 0.004, rng.randf_range(0.05, 0.16))
		mi.mesh = bm
		mi.set_surface_override_material(0, _wood if splinter else _glass)
		add_child(mi)
		# Resting on the living-room floor: inward (+X), spread along the wall, flat, 3 mm+ clear.
		var rest := Vector3(rng.randf_range(0.35, 1.9), bm.size.y / 2.0 + 0.004,
			rng.randf_range(-0.95, 0.95))
		var rest_rot := Vector3(0.0, rng.randf_range(-PI, PI), 0.0)
		if not animate:
			mi.position = rest
			mi.rotation = rest_rot
			continue
		mi.position = Vector3(0.0, rng.randf_range(0.3, 2.1), rng.randf_range(-0.6, 0.6))
		mi.rotation = Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-PI, PI), rng.randf_range(-1.2, 1.2))
		var tw := create_tween()
		tw.set_parallel(true)
		var t := rng.randf_range(0.32, 0.62)
		tw.tween_property(mi, "position", rest, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mi, "rotation", rest_rot, t)
	if animate:
		var s := GameState.load_audio("window_burst")
		if s == null:
			s = GameState.load_audio("glass_break")
		if s:
			var p := AudioStreamPlayer3D.new()
			p.name = "BurstAudio"
			p.stream = s
			p.volume_db = 4.0
			p.max_db = 8.0
			p.unit_size = 8.0
			p.position = Vector3(0.3, 1.3, 0.0)
			add_child(p)
			p.finished.connect(p.queue_free)
			p.play()
	_start_wind()
	burst.emit(animate)


# A cold draught through the hole where the glass was — a loop at the opening, local and quiet.
func _start_wind() -> void:
	if _wind:
		return
	var s := GameState.load_audio("porch_wind_gust")
	if s == null:
		return
	_wind = AudioStreamPlayer3D.new()
	_wind.name = "WindowWind"
	_wind.stream = s
	_wind.volume_db = -10.0
	_wind.unit_size = 3.0
	_wind.max_distance = 16.0
	_wind.bus = AudioBuses.AMBIENCE
	_wind.position = Vector3(0.0, 1.4, 0.0)
	add_child(_wind)
	# Every .wav/.ogg here imports loop_mode=0: loops are restarted in code.
	_wind.finished.connect(_wind.play)
	_wind.play()


func _build() -> void:
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.16, 0.11, 0.07)
	_wood.roughness = 0.85
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.07, 0.09, 0.11, 0.18)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.metallic = 0.6
	_glass.roughness = 0.12
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	# --- the casing: fixed ----------------------------------------------------------------
	for sz in [-1.0, 1.0]:
		_box("Jamb", Vector3(DEPTH, HEAD_Y, CASING), Vector3(0, HEAD_Y / 2.0, sz * (W / 2.0 - CASING / 2.0)), _wood, self)
	# Head casing: its top face meets the lintel's underside at 2.30 exactly (touching, never
	# overlapping — `check_wall_overlap.gd` would flag a shared face plane inside an overlap).
	_box("Head", Vector3(DEPTH, 2.30 - HEAD_Y, W), Vector3(0, (HEAD_Y + 2.30) / 2.0, 0), _wood, self)

	# --- the sash: breakable ------------------------------------------------------------------
	_sash = Node3D.new()
	_sash.name = "Sash"
	add_child(_sash)
	var inner := W / 2.0 - CASING           # 0.62: the clear half-width inside the jambs
	for sz in [-1.0, 1.0]:
		_box("Stile", Vector3(SASH_T, HEAD_Y - 0.004, 0.06), Vector3(0, (HEAD_Y + 0.004) / 2.0, sz * (inner - 0.03)), _wood, _sash)
	var rail_w := inner * 2.0 - 0.12
	_box("TopRail", Vector3(SASH_T, HEAD_Y - LEAF_TOP, rail_w), Vector3(0, (HEAD_Y + LEAF_TOP) / 2.0, 0), _wood, _sash)
	_box("KickBoards", Vector3(SASH_T, LEAF_BOTTOM - 0.004, rail_w), Vector3(0, (LEAF_BOTTOM + 0.004) / 2.0, 0), _wood, _sash)
	_box("Mullion", Vector3(SASH_T, LEAF_TOP - LEAF_BOTTOM, 0.05), Vector3(0, (LEAF_TOP + LEAF_BOTTOM) / 2.0, 0), _wood, _sash)
	for ty in [0.95, 1.60]:
		_box("Transom", Vector3(SASH_T, 0.04, rail_w), Vector3(0, ty, 0), _wood, _sash)
	# Two leaves of glass on QUADS (the project rule: flat art on a QuadMesh, never a box face),
	# turned to face +X — into the room. Culling off, so the yard sees it too.
	var leaf_w := (rail_w - 0.05) / 2.0
	for sz in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		g.name = "Glass"
		var qm := QuadMesh.new()
		qm.size = Vector2(leaf_w, LEAF_TOP - LEAF_BOTTOM)
		g.mesh = qm
		g.set_surface_override_material(0, _glass)
		g.position = Vector3(0, (LEAF_TOP + LEAF_BOTTOM) / 2.0, sz * (0.025 + leaf_w / 2.0))
		g.rotation.y = PI / 2.0
		_sash.add_child(g)

	# --- the pane's collider: solid until it bursts ---------------------------------------------
	_pane = StaticBody3D.new()
	_pane.name = "Pane"
	_pane.collision_layer = 1
	_pane.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.08, 2.30, W)
	cs.shape = box
	cs.position = Vector3(0, 1.15, 0)
	_pane.add_child(cs)
	add_child(_pane)


func _box(part_name: String, size: Vector3, pos: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	parent.add_child(mi)
	return mi
