extends RefCounted

# ⭐ THE FACE (2026-09-20, the user: "*its face should look like horror and terrifying… a very ugly
# broken face… not even recognizable as a face anymore… representing different objects but you
# cannot understand them*").
#
# Two layers, on the mask. BEHIND: `void_face.png` — a pale human face with a fixed stare and a
# subtle wrongness, at albedo ~0.95 against the body's 0.25, so it is by a wide margin the
# brightest thing on the figure. IN FRONT: a jumble of chunky fragments of the level's OWN
# objects — a drawer handle, a cot slat, a tile corner, a hinge, a torn page, a wedge — jammed
# around the mask's RIM at angles that do not agree, plus one deeper socket at a temple.
# A different jumble per variant. Everything matte; nothing glows (SCARY.md §8.8 — emission is
# most of a surface's colour in this project).
#
# ⭐ THE FACE READS AS A FACE FIRST (2026-09-20 pass 2, the user's call mid-build). The jumble
# used to be scattered across the whole plane, including dead centre, so whatever the art
# showed was broken up before the eye could resolve it. THE CENTRAL REGION IS NOW RESERVED:
# nothing may cover the middle `CLEAR_W` of the width or the middle `CLEAR_H` of the height —
# the eyes, the nose and the mouth. `check_void.gd` measures every jumble piece's box in the
# mask's own frame and fails if one intrudes. The wrongness comes from debris crowding the
# EDGES of a face that is otherwise looking straight at you, which is worse than debris
# hiding it.
#
# ⚠️ Pieces are sized as a FRACTION of the face they are jammed into (`REF_H` is the height
# this catalogue was authored against), because the figure is only ever seen FROZEN, under the
# torch, at 2–8 m: anything finer vanishes at distance. When the 2026-09-20 pass-2 mask made
# the face 2.8x bigger, absolute sizes would have left a jumble of specks on a dinner plate.
#
# ⭐ 2026-09-20 pass 2: `head` is now the MASK pivot, not the skull — the whole assembly hangs
# 8 cm in front of the head on a slab bigger than it (`void_creature_visual.gd:_build_face`).
# It is still a descendant of the head pivot, so the host's watched-freeze covers it for free
# and nothing here ticks.

const FACE_ART := "res://assets/textures/level_4_void/void_face.png"

const REF_H := 0.15    # the face height this jumble catalogue was authored against
# ⚠️ NOT `size.y / REF_H`. At the pass-2 mask that is 2.8, and at 2.8 a single "tile" fragment
# is 0.30 of the face's width — there is no position on a 0.28 m face where it clears the
# reserved centre. 1.6 keeps the pieces chunky enough to read at 2–8 m and small enough to
# live on the rim. Measured against CLEAR_W / CLEAR_H, not guessed.
const JUMBLE_SCALE := 1.6
# The reserved centre, as a fraction of the face's full width / height.
const CLEAR_W := 0.60
const CLEAR_H := 0.70

# `head`: the mask (or head) pivot, +z forward. `centre`: the art plane's local position.
# `size`: the face (w, h) — pass 2 : 3 so the art's pixel aspect matches the quad, which is
# what `check_art_aspect` measures. Returns every mesh it added so the host can register them
# with its `mesh_instances()`.
static func build(head: Node3D, centre: Vector3, size: Vector2, variant: int,
		stone: Material, pale: Material, dark: Material) -> Array[MeshInstance3D]:
	var made: Array[MeshInstance3D] = []
	var scale_k: float = JUMBLE_SCALE
	# The broken face itself, on the recess plane.
	var art := MeshInstance3D.new()
	art.name = "BrokenFace"
	var q := QuadMesh.new()
	q.size = size
	art.mesh = q
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(FACE_ART):
		m.albedo_texture = load(FACE_ART)
	# ⚠️ ~0.95, not 0.78. The figure's stone is 0.25 and there is no emission anywhere in this
	# project's levels, so albedo is the only lever the face has to be the thing you look at.
	m.albedo_color = Color(0.95, 0.92, 1.0)
	m.roughness = 0.96
	art.set_surface_override_material(0, m)
	art.position = centre
	head.add_child(art)
	made.append(art)

	# The jumble. Each entry: [kind, local offset within the face (x, y) as a fraction of the
	# FULL width / height, depth in front, yaw/pitch/roll].
	# ⚠️ EVERY POSITION IS ON THE RIM. |x| >= 0.30 or |y| >= 0.35 for the whole box, so the
	# reserved centre stays empty; some pieces deliberately overhang the mask's edge, which
	# reads as debris jammed into it rather than as decoration laid on it.
	var w: float = size.x
	var h: float = size.y
	var catalogue := [
		["handle", Vector2(-0.46, 0.40), 0.018, Vector3(0.2, 0.0, 0.9)],     # top-left rim
		["slat", Vector2(0.47, -0.02), 0.022, Vector3(0.0, 0.35, 0.3)],      # right rim
		["tile", Vector2(0.06, 0.48), 0.012, Vector3(0.1, 0.0, 0.78)],       # top rim
		["hinge", Vector2(-0.56, -0.18), 0.016, Vector3(0.0, -0.4, 0.25)],   # left rim
		["page", Vector2(0.34, 0.46), 0.010, Vector3(0.0, 0.15, -0.5)],      # top-right corner
		["wedge", Vector2(-0.08, -0.50), 0.030, Vector3(0.6, 0.3, 0.0)],     # bottom rim, jaw
		["slat", Vector2(0.36, -0.52), 0.020, Vector3(0.0, -0.2, 1.2)],      # bottom-right corner
		["tile", Vector2(-0.48, 0.04), 0.014, Vector3(0.0, 0.5, 0.2)],       # left rim
	]
	# Per variant: rotate the list, drop one, mirror the odd ones.
	var mirror: float = -1.0 if variant % 2 == 1 else 1.0
	var start: int = variant % catalogue.size()
	var dropped: int = (variant * 3) % catalogue.size()
	for i in range(catalogue.size()):
		var k: int = (start + i) % catalogue.size()
		if k == dropped:
			continue
		var entry: Array = catalogue[k]
		var kind: String = entry[0]
		var at: Vector2 = entry[1]
		var depth: float = entry[2]
		var angles: Vector3 = entry[3]
		var pos := centre + Vector3(at.x * w * mirror, at.y * h, depth * scale_k)
		var rot := Vector3(angles.x, angles.y * mirror, angles.z * mirror)
		match kind:
			"handle":
				var bar := _box(head, Vector3(0.062, 0.011, 0.011) * scale_k, pos + Vector3(0, 0, 0.012 * scale_k), rot, pale, "FaceHandle")
				made.append(bar)
				for s in [-1.0, 1.0]:
					made.append(_box(head, Vector3(0.009, 0.009, 0.016) * scale_k, pos + Vector3(s * 0.024 * mirror * scale_k, 0, 0.004 * scale_k), rot, pale, "FaceHandleStub"))
			"slat":
				made.append(_box(head, Vector3(0.014, 0.085, 0.018) * scale_k, pos, rot, stone, "FaceSlat"))
			"tile":
				made.append(_box(head, Vector3(0.042, 0.042, 0.006) * scale_k, pos, rot, pale, "FaceTile"))
			"hinge":
				made.append(_box(head, Vector3(0.030, 0.020, 0.004) * scale_k, pos, rot, dark, "FaceHingeLeaf"))
				made.append(_box(head, Vector3(0.028, 0.019, 0.004) * scale_k, pos + Vector3(0.018 * mirror * scale_k, 0.004 * scale_k, 0.006 * scale_k), rot + Vector3(0, 0.8 * mirror, 0), dark, "FaceHingeLeaf"))
				var pin := MeshInstance3D.new()
				pin.name = "FaceHingePin"
				var cm := CylinderMesh.new()
				cm.top_radius = 0.004 * scale_k
				cm.bottom_radius = 0.004 * scale_k
				cm.height = 0.034 * scale_k
				pin.mesh = cm
				pin.material_override = pale
				pin.position = pos + Vector3(0.004 * mirror * scale_k, 0, 0.005 * scale_k)
				pin.rotation = rot
				head.add_child(pin)
				made.append(pin)
			"page":
				made.append(_box(head, Vector3(0.030, 0.040, 0.003) * scale_k, pos, rot, pale, "FacePage"))
			"wedge":
				made.append(_box(head, Vector3(0.036, 0.028, 0.050) * scale_k, pos, rot, stone, "FaceWedge"))
	# The socket: a hole punched at the TEMPLE, clear of the reserved centre — the face keeps
	# both its eyes and something else has gone through the side of its head.
	# ⚠️ Its FRONT sits 6 mm proud of the art plane and it runs backwards INTO the mask. Before
	# pass 2 it was sunk 2 cm behind the plane — i.e. entirely occluded by the opaque art quad
	# in front of it, on every variant, for its whole life. A hole you cannot see is not a hole.
	# ⚠️ The DEPTH does not scale with the face: the pass-2 mask slab is only 5 cm thick and a
	# socket scaled 2.8x would come straight out of the back of it. Cross-section scales, depth
	# is fixed at 4.5 cm.
	# ⚠️ Its own scale, narrower than the jumble's: the clear band between the reserved centre
	# (0.084 m) and the mask's own edge (0.16 m) is only 7.6 cm wide, and at JUMBLE_SCALE the
	# socket does not fit in it. Measured by check_void's reserved-centre sweep.
	var socket_d := 0.045
	var socket := _box(head, Vector3(0.048 * 1.25, 0.044 * 1.25, socket_d),
		centre + Vector3(0.48 * w * mirror, 0.34 * h, 0.006 - socket_d * 0.5),
		Vector3(0.1, 0.0, 0.3 * mirror), dark, "FaceSocket")
	made.append(socket)
	return made


static func _box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
