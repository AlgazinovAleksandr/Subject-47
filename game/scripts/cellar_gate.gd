extends StaticBody3D
class_name CellarGate

# The boarded door sealing the House's cellar ramp. Press E to try it; the LEVEL
# decides whether the player is carrying the key and reacts. Same division of labour as
# fungal_barrier.gd (KONTUR gate 2): the prop knows how to be a prop and emits, the
# level owns the puzzle.
#
# ⚠️ BACKLOG #16: "when you collect the cellar key, the cellar is opened automatically.
# The player needs to open it himself by using the key." It used to be a bare CSGBox3D
# with no script at all, and level_2.gd wired `key.picked_up` straight to
# _open_cellar_gate() — so finding the key WAS opening the door, from wherever in the
# house you happened to be standing. The walk back down to the cellar, which is the
# only thing that made the key feel like a key, never existed.
#
# Layer 1, one body — unlike slam_door.gd's two-body split (Issue 30). That split
# exists because a SlamDoor must be raycast-hittable while NOT blocking movement; this
# gate is solid whenever it is interactable, and player.gd's interact ray uses the
# default mask, so a plain layer-1 body is both.

signal used     # E was pressed on it; the level checks what the player is carrying

const WIDTH := 1.7
const HEIGHT := 3.0
const THICK := 0.2

var _opened: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build()


func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.12, 0.08, 0.05)
	wood.roughness = 0.85

	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDTH, HEIGHT, THICK)
	slab.mesh = bm
	slab.set_surface_override_material(0, wood)
	add_child(slab)

	# Three nailed planks across it, so it reads as "sealed" rather than as a wall the
	# builder forgot to cut a doorway in. Flat-tinted, no texture: Issue 35's lesson is
	# that silhouette carries a prop in this project and art does not.
	#
	# ⚠️⚠️ THE `HEIGHT * 0.5` TERM WAS A DOUBLE-COUNT AND IT PUT TWO OF THESE THREE PLANKS
	# OUTSIDE THE DOOR (fixed 2026-09-07). `slab` is a `BoxMesh` CENTRED on the body origin and
	# the body sits at y = 1.5, so local y = 0 is already the leaf's MID-HEIGHT, not its base —
	# adding another half-height lifted every child 1.5 m. Computed from the shipped constants:
	# plank 1 landed at world y 2.04-2.26 (on the leaf, the only one you ever saw), plank 2 at
	# 2.94-3.16 — above the leaf's 3.00 top edge and buried inside `CellarShaftCap` (2.85-3.15)
	# — and plank 3 at 3.84-4.06, in the sealed void above the kitchen ceiling. The padlock
	# below was ~75 % inside the cap, leaving a 6 cm sliver 1.1 m above the player's eye line.
	#
	# So the prop's entire stated purpose — the sentence directly above this one — was
	# two-thirds absent, on a zero-emission slab in a house at ambient 0.02. The player reported
	# it as a door that might not work; it worked perfectly and did not look like a door.
	#
	# ⚠️ `intro_room.gd:_build_boarded_door()` builds the same three-plank prop correctly, and
	# the reason it never had this bug is that it positions from an ABSOLUTE world y rather than
	# from a body-local offset. When a prop's mesh is centred on its own origin, a child's local
	# y IS its offset from the centre. Nothing else to add.
	#
	# ⚠️ NO EMISSION, deliberately, even now that the House is darker. The padlock is
	# `metallic 0.7 / roughness 0.45` and catches the torch; that is how a prop is made findable
	# here. A glowing door is anti-pattern §8.8 and would undo the darkness pass it sits inside.
	var plank_mat := StandardMaterial3D.new()
	plank_mat.albedo_color = Color(0.20, 0.14, 0.09)
	plank_mat.roughness = 0.9
	for entry in [[-0.85, 6.0], [0.05, -4.0], [0.95, 3.0]]:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(WIDTH * 1.05, 0.22, 0.06)
		plank.mesh = pm
		plank.position = Vector3(0, entry[0], THICK * 0.5 + 0.03)
		plank.rotation_degrees.z = entry[1]
		plank.set_surface_override_material(0, plank_mat)
		add_child(plank)

	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.30, 0.28, 0.26)
	lock_mat.metallic = 0.7
	lock_mat.roughness = 0.45
	var lock := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.16, 0.22, 0.07)
	lock.mesh = lm
	# ⚠️ Same double-count as the planks — see the block above. World y 1.40, i.e. hand height
	# on the leaf's latch edge, which is where the eye goes and where the torch lands.
	lock.position = Vector3(WIDTH * 0.5 - 0.25, -0.1, THICK * 0.5 + 0.04)
	lock.set_surface_override_material(0, lock_mat)
	add_child(lock)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, THICK)
	col.shape = shape
	add_child(col)


func interact() -> void:
	if _opened:
		return
	used.emit()


# Called by the level once it has confirmed the player is carrying the key.
func open() -> void:
	if _opened:
		return
	_opened = true
	var t := create_tween()
	t.tween_property(self, "position:y", position.y + 3.1, 0.9).set_trans(Tween.TRANS_QUAD)
	# Collision goes away only at the END of the slide, so the player can't clip
	# through the gate while it is still visibly in the doorway.
	t.tween_callback(func() -> void:
		for c in get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", true)
	)
