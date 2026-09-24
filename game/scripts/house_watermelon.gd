extends StaticBody3D
class_name HouseWatermelon

# THE WATERMELON BEHIND THE FALLING PAINTING (2026-09-24, the Porch pass — the user's design,
# Granny-referenced). The witch's note says *"she likes to hide things inside fruit"*; the fruit
# is here, in a ragged hole in the ChildRoom's north wall that the falling painting was hanging
# over, and the bolt cutters are inside it. The guillotine on the porch is how you open it.
#
# `KeyItem`'s pattern — E takes it, `picked_up` fires, the LEVEL carries it
# (`level_2.gd:_refresh_carried()`) — with one addition: it is COMPLETELY INERT until the painting
# is down (`reveal()`). Before that there is no prompt and no ray target, and the painting's own
# layer-1 collider stands between every standing cell and the hole anyway.
#
# Layer 2 / mask 0 (note.gd's convention): the ray finds it, nobody trips on it.
#
# The mesh builders are STATIC because the guillotine needs the same fruit in its lunette and
# the same fruit cut in two — one definition of what a watermelon looks like, three users.

signal picked_up

const LAYER := 2
const RIND_TEX := "res://assets/textures/level_2_house/watermelon_rind.png"
const FLESH_TEX := "res://assets/textures/level_2_house/watermelon_flesh.png"
const LENGTH := 0.34     # along the long axis
const GIRTH := 0.24      # diameter across it

var revealed: bool = false
var _taken: bool = false

# The reachability sweep (`check_reachable.gd`) opens documented gates through the level's own
# restore path. The melon is a gate IN TIME — it exists from frame 0 behind a painting that
# falls later — so `move_aside_instantly()` asks the level to put the painting down silently,
# exactly as `_restore_progress()` does for a returning player. Set by level_2.gd.
var on_force_reveal: Callable = Callable()


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	var whole := HouseWatermelon.build_whole()
	whole.name = "Fruit"
	# Long axis along the local X (the hole runs along the wall).
	whole.rotation.z = PI / 2.0
	add_child(whole)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LENGTH + 0.06, GIRTH + 0.06, GIRTH + 0.06)
	col.shape = box
	add_child(col)


func reveal() -> void:
	revealed = true


func move_aside_instantly() -> void:
	if on_force_reveal.is_valid():
		on_force_reveal.call()
	revealed = true


func is_taken() -> bool:
	return _taken


func can_interact() -> bool:
	return revealed and not _taken


func prompt_text() -> String:
	return "E — Take the watermelon."


func interact() -> void:
	if not can_interact():
		return
	_taken = true
	picked_up.emit()
	ScreenText.toast(get_tree(), "Watermelon", Color(0.4, 1.0, 0.4), 2.0)
	queue_free()


# ------------------------------------------------------------------ the fruit, three ways

static func rind_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.55
	if ResourceLoader.exists(RIND_TEX):
		m.albedo_texture = load(RIND_TEX)
	else:
		m.albedo_color = Color(0.12, 0.26, 0.10)
	return m


# ⚠️ OBJECT-SPACE TRIPLANAR, scaled so ONE tile is exactly the disc. `watermelon_flesh.png` is a
# picture of a whole round slice on black, and a `CylinderMesh` packs its cap into a corner of
# the UV square — UV-mapped it would show a crop (Issue 24's shape), and tiled (the first try,
# uv scale 3) it rendered four rind corners round a black star. Triplanar is a pure function of
# the mesh's own coordinates here (not `uv1_world_triplanar`), so `pos / D + 0.5` maps the disc of
# diameter D onto the slice, whichever way the half has tumbled.
static func flesh_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.35
	if ResourceLoader.exists(FLESH_TEX):
		m.albedo_texture = load(FLESH_TEX)
		m.uv1_triplanar = true
		var d := GIRTH - 0.012
		m.uv1_scale = Vector3(1.0 / d, 1.0 / d, 1.0 / d)
		m.uv1_offset = Vector3(0.5, 0.5, 0.5)
	else:
		m.albedo_color = Color(0.72, 0.08, 0.10)
	return m


# The whole fruit: an ellipsoid (a SphereMesh whose height is its LENGTH), poles along local Y
# so the rind's stripes run end to end. Callers rotate it to lie the way they need.
static func build_whole() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = GIRTH / 2.0
	sm.height = LENGTH
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.set_surface_override_material(0, rind_material())
	return mi


# One half, cut across the long axis, lying FLESH UP: a hemisphere of the ellipsoid turned dome
# down, and a red disc on its open face. The node's origin is the centre of the cut face, so a
# caller placing it at `floor + LENGTH / 2` rests the dome on the floor.
static func build_half() -> Node3D:
	var root := Node3D.new()
	var dome := MeshInstance3D.new()
	dome.name = "Rind"
	var sm := SphereMesh.new()
	sm.radius = GIRTH / 2.0
	# ⚠️ HALF the length, not the length. With `is_hemisphere` Godot scales the profile by the
	# FULL `height` (its docs: "for a regular hemisphere, height and radius must be equal"), so
	# the dome spans y 0..height — passing LENGTH made each half as long as the whole fruit.
	sm.height = LENGTH / 2.0
	sm.is_hemisphere = true
	sm.radial_segments = 24
	sm.rings = 8
	dome.mesh = sm
	dome.set_surface_override_material(0, rind_material())
	dome.rotation.x = PI           # dome down, open face up
	root.add_child(dome)
	var face := MeshInstance3D.new()
	face.name = "Flesh"
	var cm := CylinderMesh.new()
	cm.top_radius = GIRTH / 2.0 - 0.006
	cm.bottom_radius = GIRTH / 2.0 - 0.006
	cm.height = 0.008
	cm.radial_segments = 24
	face.mesh = cm
	face.set_surface_override_material(0, flesh_material())
	face.position.y = 0.002
	root.add_child(face)
	return root
