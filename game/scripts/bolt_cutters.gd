extends StaticBody3D
class_name BoltCutters

# H2 (2026-09-13): the House's bolt cutters — the only thing that opens the chained fridge.
# `KeyItem`'s pattern — E takes them, `picked_up` fires, the level carries them
# (`level_2.gd:_refresh_carried()`) — built from parts: two handles in a shallow V, two jaws, a
# pivot bolt. Layer 2 / mask 0 (note.gd's convention): the ray finds them, nobody trips on them.
#
# ⭐ 2026-09-24 (the Porch pass): they are NO LONGER UNDER THE BEDROOM BED. The user: *"the cutter
# is located just under the bed, which doesn't make a lot of sense for me because it's like too
# simple"*. They are inside the watermelon behind the falling painting now, and they fall into the
# guillotine's basket when the blade cuts it (`house_guillotine.gd` builds them there, at
# `size_scale` 0.55 — 0.31 m, shorter than the 0.34 m fruit they came out of). The level's old
# torch-aimed-at-the-floor visibility rule (`_tick_cutters`, `CUTTERS_PITCH_DEG`) is deleted.

signal picked_up

const LAYER := 2
var _taken := false
# Uniform scale of the whole prop, parts AND collider, applied in `_ready()`. ⚠️ Not the node's
# own `scale`: a scaled physics body is a Godot warning and an unreliable collider.
var size_scale: float = 1.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	var k := size_scale
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
		hb.size = Vector3(0.40, 0.028, 0.028) * k
		handle.mesh = hb
		handle.material_override = red
		handle.position = Vector3(-0.08, 0.02, side * 0.045) * k
		handle.rotation.y = side * 0.14
		add_child(handle)
		var jaw := MeshInstance3D.new()
		jaw.name = "Jaw"
		var jb := BoxMesh.new()
		jb.size = Vector3(0.11, 0.024, 0.05) * k
		jaw.mesh = jb
		jaw.material_override = steel
		jaw.position = Vector3(0.20, 0.02, side * 0.028) * k
		jaw.rotation.y = -side * 0.22
		add_child(jaw)
	var pivot := MeshInstance3D.new()
	pivot.name = "Pivot"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018 * k
	cyl.bottom_radius = 0.018 * k
	cyl.height = 0.06 * k
	pivot.mesh = cyl
	pivot.material_override = steel
	pivot.position = Vector3(0.13, 0.02, 0.0) * k
	add_child(pivot)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.56, 0.10, 0.22) * k
	col.shape = shape
	col.position = Vector3(0.02, 0.03, 0.0) * k
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
