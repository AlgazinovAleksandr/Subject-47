extends StaticBody3D
class_name ArchiveGate

# The Recovery Archive's transit door (capture #8). A full-width steel seal across the
# Archive→Switchboard doorway that stays shut until the player has found the hidden keycard among
# the inventory lots. E on it emits `used`; kontur.gd checks whether the keycard is in hand and
# calls open() or refuse().
#
# ⚠️ NOT door.gd — that script's _open_door() only fires a level transition; a non-advancing door
# opened through it does nothing and never removes its collider. This is the CellarGate/RosterSeal
# pattern instead: a solid body that physically slides out of the way, so the sealed doorway
# becomes passable. It seals the FULL 1.8 m opening (a narrow leaf would leave gaps to walk around).

signal used

var locked_message: String = "TRANSIT DOOR — AUTHORISED KEYCARD REQUIRED"

const WIDTH := 1.9       # a touch wider than the 1.8 m doorway so there is no gap to slip through
const HEIGHT := 2.6
const THICK := 0.12

var _open: bool = false
var _leaf: Node3D = null


func _ready() -> void:
	_build()


func _build() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.17, 0.19, 0.18)
	steel.metallic = 0.35
	steel.roughness = 0.6

	_leaf = Node3D.new()
	_leaf.name = "GateLeaf"
	add_child(_leaf)

	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDTH, HEIGHT, THICK)
	slab.mesh = bm
	slab.material_override = steel
	slab.position = Vector3(0, HEIGHT / 2.0, 0)
	_leaf.add_child(slab)

	# A couple of ribs + a hazard chevron band so it reads as a facility blast door, not a slab.
	var rib_mat := StandardMaterial3D.new()
	rib_mat.albedo_color = Color(0.10, 0.11, 0.10)
	rib_mat.metallic = 0.3
	for ry in [0.7, 1.9]:
		var rib := MeshInstance3D.new()
		var rbm := BoxMesh.new()
		rbm.size = Vector3(WIDTH - 0.06, 0.10, THICK + 0.03)
		rib.mesh = rbm
		rib.material_override = rib_mat
		rib.position = Vector3(0, ry, 0)
		_leaf.add_child(rib)

	var wheel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.14
	tor.outer_radius = 0.20
	wheel.mesh = tor
	wheel.material_override = rib_mat
	wheel.position = Vector3(0, 1.3, THICK / 2.0 + 0.02)
	_leaf.add_child(wheel)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, THICK + 0.1)
	col.shape = shape
	col.position = Vector3(0, HEIGHT / 2.0, 0)
	col.name = "GateCol"
	add_child(col)


func interact() -> void:
	if _open:
		return
	used.emit()          # the level decides whether the keycard is in hand


func can_interact() -> bool:
	return not _open


func refuse() -> void:
	ScreenText.toast(get_tree(), locked_message, Color(1.0, 0.2, 0.2), 1.5, 48)


# Slides up into the lintel and stops blocking. The collider is disabled the instant the slide
# starts, so the doorway is passable immediately (dissolve-then-move, like fungal_barrier.gd).
func open() -> void:
	if _open:
		return
	_open = true
	var col := get_node_or_null("GateCol")
	if col:
		(col as CollisionShape3D).disabled = true
	if is_instance_valid(_leaf):
		var t := create_tween()
		t.set_trans(Tween.TRANS_QUAD)
		t.tween_property(_leaf, "position:y", HEIGHT - 0.15, 0.9)


# The resume path: the door came back sealed on _ready(); if it was already open, remove it cleanly.
func open_instantly() -> void:
	_open = true
	var col := get_node_or_null("GateCol")
	if col:
		(col as CollisionShape3D).disabled = true
	if is_instance_valid(_leaf):
		_leaf.position.y = HEIGHT - 0.15
