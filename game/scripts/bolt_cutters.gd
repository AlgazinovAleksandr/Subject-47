extends StaticBody3D
class_name BoltCutters

# H2 (2026-09-13): the bolt cutters under the Bedroom bed. `KeyItem`'s pattern — E takes them,
# `picked_up` fires, the level carries them (`GameState.set_carried`) — built from parts: two
# handles in a shallow V, two jaws, a pivot bolt. Layer 2 / mask 0 (note.gd's convention): the
# ray finds them, nobody trips on them. They lie flat, half under the bed, handles out past the
# foot, so the shipping 3 m interact ray reaches them from ~1.5 m with the torch aimed at the
# floor — the level gates `visible` on that aim (see level_2.gd:_tick_cutters).

signal picked_up

const LAYER := 2
var _taken := false


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.36, 0.08, 0.06)
	red.roughness = 0.8
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.30, 0.30, 0.32)
	steel.metallic = 0.7
	steel.roughness = 0.4
	for side in [-1.0, 1.0]:
		var handle := MeshInstance3D.new()
		handle.name = "Handle"
		var hb := BoxMesh.new()
		hb.size = Vector3(0.40, 0.028, 0.028)
		handle.mesh = hb
		handle.material_override = red
		handle.position = Vector3(-0.08, 0.02, side * 0.045)
		handle.rotation.y = side * 0.14
		add_child(handle)
		var jaw := MeshInstance3D.new()
		jaw.name = "Jaw"
		var jb := BoxMesh.new()
		jb.size = Vector3(0.11, 0.024, 0.05)
		jaw.mesh = jb
		jaw.material_override = steel
		jaw.position = Vector3(0.20, 0.02, side * 0.028)
		jaw.rotation.y = -side * 0.22
		add_child(jaw)
	var pivot := MeshInstance3D.new()
	pivot.name = "Pivot"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 0.06
	pivot.mesh = cyl
	pivot.material_override = steel
	pivot.position = Vector3(0.13, 0.02, 0.0)
	add_child(pivot)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.56, 0.10, 0.22)
	col.shape = shape
	col.position = Vector3(0.02, 0.03, 0.0)
	add_child(col)


func can_interact() -> bool:
	return visible and not _taken


func interact() -> void:
	if _taken:
		return
	_taken = true
	picked_up.emit()
	ScreenText.toast(get_tree(), "Bolt cutters", Color(0.4, 1.0, 0.4), 2.0)
	queue_free()
