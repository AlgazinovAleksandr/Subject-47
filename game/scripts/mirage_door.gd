extends StaticBody3D
class_name MirageDoor

# An old-house yellowed panel door (B1, 2026-09-13; it was a blood-red back-door lookalike).
# The player's instinct says "a way out." Open it and it swings onto blank yellow wallpaper,
# mocking the hope of retreat and spiking panic. Builds its own mesh; backrooms.gd
# only places + orients it flush on a wall, facing inward.

const PANIC := 10.0
const SIZE := Vector2(1.0, 2.1)
const CREAK_VOLUME_DB := -4.0   # was an unset 0 dB, which sat on top of the score

var _opened: bool = false
var _creak: AudioStreamPlayer3D
var _hinge: Node3D


const TEX := "res://assets/textures/level_backrooms/backrooms_door_yellow.png"


func _ready() -> void:
	# hinge at the left edge so the door swings into the corridor
	_hinge = Node3D.new()
	_hinge.position = Vector3(-SIZE.x / 2.0, 0, 0)
	add_child(_hinge)

	# ⭐ B1 (2026-09-13, capture #13, the user's call): an OLD-HOUSE YELLOWED PANEL DOOR, not the
	# blood-red back-door lookalike — the red stays exclusive to the Lobby's real back door.
	# Art on QuadMesh faces (never a BoxMesh face, Issue 24), sized from its own aspect; a thin
	# dark slab carries the edge; a brass knob is real geometry. No emission (Issues 21/27/33).
	var w: float = SIZE.x
	if ResourceLoader.exists(TEX):
		var t: Texture2D = load(TEX)
		if t and t.get_height() > 0:
			w = SIZE.y * float(t.get_width()) / float(t.get_height())
	var door := MeshInstance3D.new()
	door.name = "Leaf"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, SIZE.y, 0.06)
	door.mesh = mesh
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.32, 0.27, 0.12)
	edge.roughness = 0.9
	door.set_surface_override_material(0, edge)
	door.position = Vector3(w / 2.0, SIZE.y / 2.0, 0)
	_hinge.add_child(door)
	if ResourceLoader.exists(TEX):
		var art := StandardMaterial3D.new()
		art.albedo_texture = load(TEX)
		art.roughness = 0.85
		for side in [1.0, -1.0]:
			var q := MeshInstance3D.new()
			q.name = "LeafArt"
			var qm := QuadMesh.new()
			qm.size = Vector2(w, SIZE.y)
			q.mesh = qm
			q.material_override = art
			q.position = Vector3(w / 2.0, SIZE.y / 2.0, side * 0.031)
			if side < 0.0:
				q.rotation.y = PI
			_hinge.add_child(q)
	var knob := MeshInstance3D.new()
	knob.name = "Knob"
	var sph := SphereMesh.new()
	sph.radius = 0.035
	sph.height = 0.07
	knob.mesh = sph
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.42, 0.34, 0.14)
	brass.metallic = 0.6
	brass.roughness = 0.45
	knob.material_override = brass
	knob.position = Vector3(w - 0.12, 1.02, 0.06)
	_hinge.add_child(knob)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, SIZE.y, 0.12)
	col.shape = shape
	col.position = Vector3(0, SIZE.y / 2.0, 0)
	add_child(col)

	_creak = AudioStreamPlayer3D.new()
	var s := GameState.load_audio("creak")
	if s:
		_creak.stream = s
	_creak.unit_size = 5.0
	_creak.volume_db = CREAK_VOLUME_DB
	add_child(_creak)


func interact() -> void:
	if _opened:
		return
	_opened = true
	if _creak.stream:
		_creak.play()
	# swing open onto the blank wall behind
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation:y", deg_to_rad(105.0), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# ⚠️ This used to be `get_parent().get_node_or_null("Player")`, which only ever
	# worked in Zone 1, where the parent IS the scene root. The Sprawl's two mirage
	# doors are parented to `ZoneSprawl`, which has no Player child, so they silently
	# dealt ZERO panic for the whole life of Zone 2. The group lookup is the fallback
	# living_mirror.gd:89-91 already uses, and player.gd:78 joins "player" in _ready().
	var player := get_parent().get_node_or_null("Player") as CharacterBody3D
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and player.has_method("add_panic"):
		player.add_panic(PANIC)
