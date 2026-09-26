extends Node3D
class_name WingDoor

# A hinged interior door for a `RoomBuilder` doorway — the Intake Wing's doors (2026-09-24).
#
# ⚠️ WHY NOT `door.gd`, `slam_door.gd` OR `ajar_door.gd`. `door.gd` is a level EXIT (UnlockCondition,
# advances_level, go_back) and has no hinge; `slam_door.gd` is a chase door (battering, blocking
# Object 12's path, two leaves); `ajar_door.gd` cannot be opened by the player at all. This is the
# plain thing none of them is: a single leaf that is locked until the level says otherwise and
# then swings open on E. It is built on `choice_door.gd` / `ajar_door.gd`'s skeleton — hinge at the
# leaf's edge, art on QuadMesh faces, never on the box (Issue 24) — and on `slam_door.gd:_build_frame`'s
# lesson that a RoomBuilder doorway is cut FULL HEIGHT with no lintel, so a door that stops at 2.1 m
# leaves a hole to the ceiling above it. The gap above the leaf is filled here: a lintel in the
# frame's material and an INFILL in the room's own wall material (triplanar, so its plaster lines
# up with the wall either side and it reads as wall, not as a panel).
#
# Two modes:
#   * a real doorway (`flush = false`): origin = doorway centre on the floor, local +z = the walk
#     axis. The leaf sits in the wall's thickness; the jambs straddle the wall ends and stand
#     FRAME_D proud of both faces.
#   * a decorative door on a SOLID wall (`flush = true`): origin = the wall's inner FACE, local +z =
#     into the room. Nothing opens behind it; the leaf's back bites WALL_BITE into the plaster and
#     the frame stands proud around it (intro_room.gd's `_build_door_casing()` convention). It is
#     locked forever — the dream's corridor has doors on both sides and none of them are yours.
#
# ⚠️ THE LEAF'S OWN BODY ANSWERS E. A door built as "an interact volume + a separate solid blocker"
# has the SlamDoor bug the moment the two overlap: the ray returns the blocker, which has no
# `interact()`, and `player.gd` nulls the target (slam_door.gd:88). So the solid leaf body is a
# `LeafBody` that forwards `interact()` / `can_interact()` to this node. One body,
# one answer, whatever angle the ray arrives from.

signal opened        # emitted BEFORE the leaf moves — the level blacks out the ward on this
signal rattled       # E on a locked door

const LEAF_H := 2.1
const LEAF_T := 0.06
const LEAF_GAP := 0.05          # each side: the hinge sits LEAF_T/2 clear of the jamb, so the swung leaf never cuts it
const JAMB_W := 0.10
const JAMB_LAP := 0.02          # the jamb reaches this far INTO the opening — see _build_frame
const FRAME_D := 0.26           # > RoomBuilder.T (0.2): 3 cm proud of each wall face
const LINTEL_H := 0.10
const OPEN_DEG := 92.0
const OPEN_TIME := 1.2
# Flush (decorative) mode, measured off the wall face.
const WALL_BITE := 0.02
const CASING_D := 0.12

@export var door_width: float = 1.2
@export var door_height: float = 3.0      # the doorway's height, i.e. the taller room's ceiling
@export var locked: bool = false
@export var locked_message: String = "Locked."
@export var flush: bool = false
@export var swing_sign: float = 1.0       # +1 swings into local +z, -1 into -z
@export var texture_path: String = ""
@export var infill_material: Material = null
@export var open_sound: String = "intro_door_creak"
@export var locked_sound: String = "intro_door_rattle"

var _open: bool = false
var _hinge: Node3D
var _leaf: StaticBody3D
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_build_frame()
	_build_leaf()
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "DoorAudio"
	_audio.position = Vector3(0, 1.2, 0)
	_audio.unit_size = 5.0
	add_child(_audio)


# ---------------------------------------------------------------- construction

func _frame_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.22, 0.21)
	m.roughness = 0.8
	return m


func _box(box_name: String, size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)
	return mi


func _build_frame() -> void:
	var mat := _frame_mat()
	var half := door_width * 0.5
	if flush:
		# Decorative: a casing around a leaf that stands on the wall face. Its back bites into the
		# wall, never coplanar with it (Issues 19/20/23).
		var z := -WALL_BITE + CASING_D * 0.5
		var jh := LEAF_H + LINTEL_H + WALL_BITE
		for side in [-1.0, 1.0]:
			_box("Jamb", Vector3(JAMB_W, jh, CASING_D),
				Vector3(side * (half + JAMB_W * 0.5 - JAMB_LAP), jh * 0.5 - WALL_BITE, z), mat)
		_box("Lintel", Vector3(door_width + JAMB_W * 2.0, LINTEL_H, CASING_D),
			Vector3(0, LEAF_H + LINTEL_H * 0.5 - JAMB_LAP, z), mat)
		return

	# ⚠️ THE JAMBS LAP 2 cm INTO THE OPENING. `slam_door.gd`'s jambs start exactly at the wall's
	# end face, so the jamb's inner face and the wall's end face share one plane over the whole
	# reveal — two visible surfaces in one plane, this project's most common bug class. Lapping
	# puts the wall's end face INSIDE the jamb, where it cannot be seen.
	var jh2 := LEAF_H + LINTEL_H
	for side in [-1.0, 1.0]:
		_box("Jamb", Vector3(JAMB_W + JAMB_LAP, jh2, FRAME_D),
			Vector3(side * (half + (JAMB_W - JAMB_LAP) * 0.5), jh2 * 0.5, 0.0), mat)
	_box("Lintel", Vector3(door_width + JAMB_W * 2.0, LINTEL_H, FRAME_D),
		Vector3(0, LEAF_H + LINTEL_H * 0.5, 0.0), mat)

	# The infill: wall above the lintel, to the ceiling. A CSG box in the ROOM'S wall material and
	# EXACTLY RoomBuilder.T deep, so its faces continue the wall's faces (adjacent, not overlapping
	# — no z-fight) and the triplanar plaster runs straight across it.
	var top := LEAF_H + LINTEL_H
	var gap := door_height - top
	if gap > 0.02:
		var inf := CSGBox3D.new()
		inf.name = "DoorInfill"
		inf.size = Vector3(door_width, gap, RoomBuilder.T)
		inf.position = Vector3(0, top + gap * 0.5, 0)
		inf.use_collision = true
		if infill_material:
			inf.material = infill_material
		add_child(inf)


func _build_leaf() -> void:
	var leaf_w := door_width - LEAF_GAP * 2.0
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	# Hinge on the leaf's LEFT edge (local -x). Its z is the leaf's centre plane.
	var hz := (-WALL_BITE + LEAF_T * 0.5) if flush else 0.0
	_hinge.position = Vector3(-door_width * 0.5 + LEAF_GAP, 0, hz)
	add_child(_hinge)

	_leaf = LeafBody.new()
	_leaf.name = "Leaf"
	(_leaf as LeafBody).door = self
	_hinge.add_child(_leaf)

	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.16, 0.18, 0.17)
	edge.roughness = 0.85
	_box("LeafSlab", Vector3(leaf_w, LEAF_H, LEAF_T), Vector3(leaf_w * 0.5, LEAF_H * 0.5, 0), edge, _leaf)

	var face_mat := StandardMaterial3D.new()
	face_mat.roughness = 0.8
	if texture_path != "" and ResourceLoader.exists(texture_path):
		face_mat.albedo_texture = load(texture_path)
	else:
		face_mat.albedo_color = Color(0.45, 0.5, 0.47)
	# Art on BOTH faces unless the door is flush (its back is inside the wall), 4 mm proud of the
	# slab so it never shares the slab's plane.
	for z_sign in ([1.0] if flush else [1.0, -1.0]):
		var face := MeshInstance3D.new()
		face.name = "LeafArt" if z_sign > 0.0 else "LeafArtBack"
		var qm := QuadMesh.new()
		qm.size = Vector2(leaf_w, LEAF_H)
		face.mesh = qm
		face.material_override = face_mat
		face.position = Vector3(leaf_w * 0.5, LEAF_H * 0.5, z_sign * (LEAF_T * 0.5 + 0.004))
		if z_sign < 0.0:
			face.rotation.y = PI
		_leaf.add_child(face)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(leaf_w, LEAF_H, LEAF_T)
	col.shape = shape
	col.position = Vector3(leaf_w * 0.5, LEAF_H * 0.5, 0)
	_leaf.add_child(col)


# ---------------------------------------------------------------- behaviour

func is_open() -> bool:
	return _open


func can_interact() -> bool:
	return not _open


func interact() -> void:
	if _open:
		return
	if locked or flush:
		_play(locked_sound, -4.0)
		rattled.emit()
		ScreenText.toast(get_tree(), locked_message, Color(0.85, 0.82, 0.74), 1.4, 30)
		return
	open()


# Open with the sound and the swing. `opened` goes out FIRST: a listener that changes the world
# (the ward's blackout) must do it while the leaf still hides what is behind it.
func open() -> void:
	if _open:
		return
	_open = true
	opened.emit()
	_play(open_sound, 0.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hinge, "rotation:y", swing_sign * -deg_to_rad(OPEN_DEG), OPEN_TIME)


# The restore / sweep path (check_reachable opens documented gates through this): no sound, no
# signal, no tween.
func move_aside_instantly() -> void:
	if flush:
		return
	_open = true
	locked = false
	_hinge.rotation.y = swing_sign * -deg_to_rad(OPEN_DEG)


func unlock() -> void:
	locked = false


func _play(base_name: String, db: float) -> void:
	if base_name == "":
		return
	var s := GameState.load_audio(base_name)
	if s == null:
		return
	_audio.stream = s
	_audio.volume_db = db
	_audio.play()


# The leaf's solid body, which is also what E hits. Forwards to the door.
class LeafBody extends StaticBody3D:
	var door: Node = null

	func interact() -> void:
		if door:
			door.interact()

	func can_interact() -> bool:
		return door != null and door.can_interact()
