extends RefCounted

# ⭐ THE VOID'S DOORS (2026-09-20, the user: "*it looks like a typical red door but we want to make
# it more according to the level structure — broken geometry, but you can see it's a door*").
#
# The leaf is ONE generated image (`void_door.png`, a dark planked door with a keyhole and a
# handle, 1 : 2.2) sliced across six or seven separated stone slabs that hover apart with black
# gaps, and frame posts at different depths — the perspective puzzle's doorways, the ones that
# only assemble from one viewpoint, except this one never does. The blood-red convention every
# earlier level taught (`door.gd:door_material("")`, emission ×1.5) is KEPT, on a backing plate
# behind the slabs, so it shows only through the gaps. The plate is named `DoorMesh` because
# `door.gd:_flash_unlock()` looks that node up by name to flare it when the twist note is read.
#
# ⚠️ Each slab's front is a QuadMesh showing its own sub-rect of the image via uv1_offset /
# uv1_scale (Issue 24: art on a quad, never a box face), and the sub-rect has the SLAB's
# proportions, so `check_art_aspect.gd`'s pixel-aspect × uv1_scale rule holds per slab.
# ⚠️ Nothing here is coplanar with anything: the plate sits 4 mm proud of the dark door box,
# the slabs float 3–12 cm in front of the plate, the posts stand off the wall by ≥ 11 cm.
# Collider, script and unlock rule are untouched — this only replaces `build_visual()`.

const _DOOR := preload("res://scripts/door.gd")
const _FRAGMENTS := preload("res://scripts/void_fragments.gd")
const LEAF_ART := "res://assets/textures/level_4_void/void_door.png"

# `broken` 0..1 scales the gaps, the float distance and the tilt; 1.0 also removes one slab
# (the exit: the last door is the most broken). `seed` makes the wrongness stable per door.
static func build(body: Node3D, size: Vector3, broken: float, seed: int, wall_mat: Material = null) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.05, 0.045, 0.06)
	edge.roughness = 0.95
	# The dark door box: the thickness the collider already has, so the door is a solid thing.
	var box := MeshInstance3D.new()
	box.name = "DoorSlab"
	var bm := BoxMesh.new()
	bm.size = size
	box.mesh = bm
	box.set_surface_override_material(0, edge)
	body.add_child(box)
	# The red backing plate — the convention, kept. 4 mm proud of the box (build_visual's own offset).
	var plate := MeshInstance3D.new()
	plate.name = "DoorMesh"
	var pq := QuadMesh.new()
	pq.size = Vector2(size.x, size.y)
	plate.mesh = pq
	plate.set_surface_override_material(0, _DOOR.door_material(""))
	var plate_z: float = size.z / 2.0 + 0.004
	plate.position = Vector3(0, 0, plate_z)
	body.add_child(plate)

	# The slabs: an irregular 2 × 4 split of the leaf, each shrunk by its gap and floated.
	var stone := _FRAGMENTS._mat(_FRAGMENTS.TINT_DARK)
	var art := StandardMaterial3D.new()
	art.albedo_texture = load(LEAF_ART) if ResourceLoader.exists(LEAF_ART) else null
	art.albedo_color = Color(0.82, 0.80, 0.86)
	art.roughness = 0.92
	var cols := [0.46, 0.54]
	var rows := [0.50, 0.66, 0.56, 0.48]     # sums to 2.2
	# ⚠️ Measured on the first screenshot (2026-09-20): a REMOVED slab left a half-metre red square
	# and 7–13 cm gaps made the plate dominate — the door read as a red grid. Now one slab hangs
	# ASKEW instead, and the gaps stay under 4 cm so the red is seams of light, not a frame.
	var askew := -1
	if broken >= 0.99:
		askew = rng.randi_range(2, 5)
	var y_top: float = size.y / 2.0
	var index := 0
	for r in range(rows.size()):
		var h: float = rows[r]
		var x_left: float = -size.x / 2.0
		for c in range(cols.size()):
			var w: float = cols[c] * size.x
			if true:
				var gap: float = 0.012 + 0.025 * broken
				var sw: float = w - gap
				var sh: float = h - gap
				var cx: float = x_left + w / 2.0 + rng.randf_range(-0.012, 0.012) * broken
				var cy: float = y_top - h / 2.0 + rng.randf_range(-0.012, 0.012) * broken
				var cz: float = plate_z + 0.03 + rng.randf_range(0.0, 0.09) * broken
				var slab := Node3D.new()
				slab.name = "LeafSlab_%d" % index
				slab.position = Vector3(cx, cy, cz + 0.02)
				slab.rotation = Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.06, 0.06),
					rng.randf_range(-0.04, 0.04)) * broken
				if index == askew:
					# The one that has let go: hanging from a corner, a wedge of red behind it.
					slab.position += Vector3(0.02, -0.06, 0.05)
					slab.rotation.z += 0.16
					slab.rotation.y += 0.12
				# ⭐ WHERE THIS SLAB WOULD BE IF THE DOOR WERE WHOLE (2026-09-20 pass 3).
				# The sub-rect's own place on the plate, with no jitter, no float and no tilt:
				# x/y straight off the column/row grid, z = plate + 0.03 + the art's own 0.02.
				# Stored HERE because this is the only place the grid exists; `void_exit_door.gd`
				# tweens to it and `check_void` asserts against it. A recomputation in either
				# would be a second copy of the layout that could silently disagree.
				slab.set_meta("true_position", Vector3(x_left + w / 2.0, y_top - h / 2.0,
					plate_z + 0.03 + 0.02))
				slab.set_meta("true_rotation", Vector3.ZERO)
				# ⚠️ AND THE SCALE THAT CLOSES THE GAP, which position alone cannot. Each slab's
				# MESH is its cell minus `gap`, so slabs parked on their true centres still leave
				# a 3.7 cm seam between every pair — and the blood-red plate behind them turns
				# the "assembled" door into a RED GRID. That is the exact picture pass 2 rejected
				# for the broken door (7-13 cm gaps, "a red grid, not a broken door"), rebuilt by
				# accident at the other end of the animation. Growing each slab back to its full
				# cell closes every seam; `check_art_aspect` reads the MESH size, never the node
				# scale, so the sub-rect measurement is untouched.
				slab.set_meta("true_scale", Vector3(w / sw, h / sh, 1.0))
				body.add_child(slab)
				var back := MeshInstance3D.new()
				back.name = "SlabStone"
				var sb := BoxMesh.new()
				sb.size = Vector3(sw, sh, 0.04)
				back.mesh = sb
				back.set_surface_override_material(0, stone)
				slab.add_child(back)
				var face := MeshInstance3D.new()
				face.name = "SlabArt"
				var fq := QuadMesh.new()
				fq.size = Vector2(sw, sh)
				face.mesh = fq
				var m: StandardMaterial3D = art.duplicate()
				# The slab's own window onto the one leaf image, in the slab's proportions.
				var u0: float = (x_left + gap / 2.0 + size.x / 2.0) / size.x
				var v0: float = (size.y / 2.0 - (y_top - gap / 2.0)) / size.y
				m.uv1_scale = Vector3(sw / size.x, sh / size.y, 1.0)
				m.uv1_offset = Vector3(u0, v0, 0.0)
				face.set_surface_override_material(0, m)
				face.position = Vector3(0, 0, 0.02 + 0.004)
				slab.add_child(face)
			x_left += w
			index += 1
		y_top -= h

	# The frame: two posts at different depths and a lintel that has slipped — never assembling.
	var post_mat: Material = wall_mat if wall_mat else _FRAGMENTS._mat(_FRAGMENTS.TINT)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.name = "FramePost_%s" % ("L" if side < 0 else "R")
		var pb := BoxMesh.new()
		pb.size = Vector3(0.12, size.y + 0.25, 0.12)
		post.mesh = pb
		post.set_surface_override_material(0, post_mat)
		var depth: float = 0.02 + (0.16 if side > 0 else 0.05) * broken
		post.position = Vector3(side * (size.x / 2.0 + 0.11), 0.04 * side * broken, plate_z + depth)
		post.rotation.z = side * 0.04 * broken
		body.add_child(post)
	var lintel := MeshInstance3D.new()
	lintel.name = "FrameLintel"
	var lb := BoxMesh.new()
	lb.size = Vector3(size.x + 0.5, 0.13, 0.12)
	lintel.mesh = lb
	lintel.set_surface_override_material(0, post_mat)
	lintel.position = Vector3(0.06 * broken, size.y / 2.0 + 0.2, plate_z + 0.10 * broken + 0.02)
	lintel.rotation.z = -0.07 * broken
	body.add_child(lintel)
