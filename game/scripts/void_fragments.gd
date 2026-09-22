class_name VoidFragments
extends RefCounted

# The Void's furniture has lost the relationships that make it useful. Pieces are
# actual 3D geometry, matte violet-grey like its fractured humanoids. Existing art
# survives as loose sheets hanging between the broken frames.

const TINT := Color(0.34, 0.30, 0.40)       # the memory of a colour, under violet light
const TINT_DARK := Color(0.16, 0.14, 0.19)
const TINT_PALE := Color(0.46, 0.43, 0.50)

# ⭐ FIVE MATTE FAMILIES, ASSIGNED BY ROOM (2026-09-20 pass 2). Capture #6/#7/#8: *"All the
# colours are the same and it is boring. We need to set several colours and several colour
# scales… make objects within this colour set"*. Every prop in the level was `TINT` / `TINT_DARK`
# / `TINT_PALE`, so a chair, a drawer bank and a heap of doors were the same violet-grey.
# Each family is [base, dark, pale] and `level_3.gd` picks one per room — see its
# `_build_fragments()` / `_build_impossible_props()` for the assignment.
#
# ⚠️ ALBEDO ONLY. Nothing here is emissive and nothing may become emissive: this project has
# no glow, no fog and no tonemapping, light energy is ~0.45, and an emissive prop clamps to a
# flat white blob (Issue 21). Colour has to survive on albedo alone, which is why every family
# keeps a wide base/pale spread rather than a subtle hue shift.
# ⚠️ The FIGURES are not in here. `void_creature_visual.gd` owns its own 0.25 dark stone and
# keeps it: the creatures must read as one species wherever you meet them.
const PALETTE := {
	"bone":      [Color(0.55, 0.52, 0.46), Color(0.25, 0.23, 0.20), Color(0.70, 0.67, 0.60)],
	"rust":      [Color(0.33, 0.18, 0.12), Color(0.15, 0.08, 0.05), Color(0.47, 0.28, 0.18)],
	"verdigris": [Color(0.21, 0.31, 0.26), Color(0.09, 0.14, 0.12), Color(0.34, 0.47, 0.40)],
	"violet":    [TINT, TINT_DARK, TINT_PALE],
	"tar":       [Color(0.07, 0.065, 0.08), Color(0.035, 0.032, 0.042), Color(0.17, 0.16, 0.19)],
}
# The heap of doors takes one family per door (`family = "mixed"`), in this order.
const MIXED_ORDER := ["rust", "bone", "verdigris", "tar", "violet"]

const BASE := 0
const DARK := 1
const PALE := 2
# ⭐ VOID-NATIVE ART (2026-09-20). These three pointed at the intro's gurney pad, the House's
# child drawing and the Lab's monitor face, and the playtester photographed two of them and
# said so: *"I see that the picture is duplicated from the house level and the monitor is
# duplicated from the lab level. Let's make unique objects and decorations for this level"*
# (capture #6). The earlier-level echo survives in the NOTES' TEXT, which is where it was
# always supposed to live. ⚠️ Do not point these back at another level's folder.
const GURNEY_ART := "res://assets/textures/level_4_void/void_sheet.png"
const DRAWING_ART := "res://assets/textures/level_4_void/void_child_drawing.png"
const MONITOR_ART := "res://assets/textures/level_4_void/void_monitor_face.png"


static var _grain: NoiseTexture2D


static func stone_grain() -> Texture2D:
	if _grain == null:
		_grain = NoiseTexture2D.new()
		_grain.width = 128
		_grain.height = 128
		_grain.seamless = true
		var noise := FastNoiseLite.new()
		noise.seed = 47
		noise.frequency = 0.065
		_grain.noise = noise
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(0.48, 0.48, 0.48), Color(1, 1, 1)])
		_grain.color_ramp = ramp
	return _grain


# The colour a family answers for a slot. An unknown family falls back to violet rather than
# throwing, so a typo in level_3.gd is a wrong colour and never a broken level.
static func family_color(family: String, slot: int) -> Color:
	var row: Array = PALETTE.get(family, PALETTE["violet"])
	return row[clampi(slot, 0, 2)]


# `_mat()` by family. ⚠️ `_mat(Color)` is KEPT as-is and still takes a raw colour —
# `void_alignment.gd`, `void_keystone.gd` and `void_creature_visual.gd` all call it that way.
static func fmat(family: String, slot: int, rough: float = 0.92, metal: float = 0.0) -> StandardMaterial3D:
	return _mat(family_color(family, slot), rough, metal)


static func _mat(c: Color, rough: float = 0.92, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = stone_grain()
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.5, 2.5, 2.5)
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if nm != "":
		mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)
	return mi


# A textured quad sized from the artwork's own aspect (the long side = `long_m`), lying flat
# (`flat`) or standing (facing +Z in the parent's frame). Falls back to a tinted quad.
static func _art_quad(parent: Node3D, tex_path: String, long_m: float, pos: Vector3,
		flat: bool, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var qm := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	var size := Vector2(long_m, long_m * 0.66)
	if ResourceLoader.exists(tex_path):
		var t: Texture2D = load(tex_path)
		if t:
			m.albedo_texture = t
			var aspect: float = float(t.get_width()) / maxf(1.0, float(t.get_height()))
			if aspect >= 1.0:
				size = Vector2(long_m, long_m / aspect)
			else:
				size = Vector2(long_m * aspect, long_m)
			m.albedo_color = Color(0.55, 0.5, 0.6)   # the memory, not the print
	else:
		m.albedo_color = TINT_PALE
	qm.size = size
	mi.mesh = qm
	mi.set_surface_override_material(0, m)
	mi.position = pos
	if flat:
		mi.rotation.x = -PI / 2.0
	parent.add_child(mi)
	return mi


# ⚠️ `script` is set BEFORE `level.add_child(b)`. A `set_script()` after the node is already
# in the tree never runs `_ready()` — the cradle shipped inert for exactly one build that way.
static func _body(level: Node3D, nm: String, pos: Vector3, yaw: float, col_size: Vector3,
		col_offset: Vector3, script: Script = null) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = nm
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos
	b.rotation.y = yaw
	if script:
		b.set_script(script)
	level.add_child(b)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = col_size
	col.shape = sh
	col.position = col_offset
	b.add_child(col)
	return b


# An extra collision box on an existing body — used where one prop needs several volumes
# rather than one bounding block (the inverted slab: surface plus two supports, so the
# player and CreatureD walk UNDER the 1.91 m underside instead of into a solid brick).
static func _extra_collider(body: StaticBody3D, size: Vector3, at: Vector3) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	col.position = at
	body.add_child(col)
	return col


# Folded frame suspended clear of its disconnected supports. The collider is the
# honest footprint of the low sculpture, never an invisible room-wide barrier.
static func folded_frame(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "violet") -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(1.25, 1.85, 1.65), Vector3(0, 0.925, 0))
	var assembly := Node3D.new()
	assembly.name = "SuspendedAssembly"
	body.add_child(assembly)
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	for side in [-1.0, 1.0]:
		var rail := _box(assembly, Vector3(0.13, 0.13, 1.65), Vector3(side * 0.48, 1.2, 0), stone, "FoldedRail")
		rail.rotation.x = side * 0.44
		var upright := _box(assembly, Vector3(0.14, 0.95, 0.13), Vector3(side * 0.48, 1.65, side * 0.38), pale, "DisconnectedUpright")
		upright.rotation.z = side * 0.28
		var support := _box(body, Vector3(0.17, 0.5, 0.2), Vector3(side * 0.42, 0.31, -side * 0.53), stone, "AbandonedSupport")
		support.rotation.y = side * 0.37
	var fold := _box(assembly, Vector3(1.05, 0.18, 0.38), Vector3(0, 1.48, 0), pale, "FoldThrough")
	fold.rotation.z = 0.28
	var sheet := _art_quad(assembly, GURNEY_ART, 0.85, Vector3(0.04, 1.1, -0.12), false, "SuspendedSheet")
	sheet.rotation = Vector3(-0.25, 0.12, 0.22)
	return body


# A human-shaped hollow hangs on the UNDERSIDE of a slab. Separate rails describe
# the depression with negative space, so its shape is readable from either side.
# ⚠️ THREE COLLIDERS, NOT ONE (2026-09-20). The single 1.05 x 2.15 x 2.1 block from floor to
# surface made the slab a brick: the shard in its underside hollow could be seen and never
# reached, and CreatureD could not pass it either. The collision is now the SURFACE plus the
# two supports, so the underside at y 1.91 is real headroom.
static func inverted_slab(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "violet") -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(1.05, 0.26, 2.12), Vector3(0, 2.02, 0))
	for side in [-1.0, 1.0]:
		_extra_collider(body, Vector3(0.24, 0.72, 0.30), Vector3(side * 0.34, 0.60, side * 0.72))
	var stone := fmat(family, BASE)
	var dark := fmat(family, DARK)
	_box(body, Vector3(1.02, 0.22, 2.08), Vector3(0, 2.02, 0), stone, "InvertedSurface")
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.12, 0.18, 1.30), Vector3(side * 0.32, 1.79, -0.18), dark, "HollowTorsoEdge")
		var arm := _box(body, Vector3(0.10, 0.12, 0.70), Vector3(side * 0.39, 1.76, 0.14), dark, "HollowArm")
		arm.rotation.y = side * 0.28
		_box(body, Vector3(0.20, 0.13, 0.32), Vector3(side * 0.19, 1.77, -0.82), dark, "HollowLeg")
		var support := _box(body, Vector3(0.15, 0.68, 0.18), Vector3(side * 0.34, 0.60, side * 0.72), stone, "DisconnectedSupport")
		support.rotation.z = side * 0.3
	_box(body, Vector3(0.40, 0.12, 0.12), Vector3(0, 1.79, 0.73), dark, "HollowHeadEdge")
	return body


# The morgue's face monitor, dead, on a stand: a dark screen with the art barely legible.
static func monitor(level: Node3D, pos: Vector3, yaw: float, nm: String) -> StaticBody3D:
	var b := _body(level, nm, pos, yaw, Vector3(0.6, 1.5, 0.5), Vector3(0, 0.75, 0))
	var plastic := _mat(Color(0.12, 0.12, 0.14), 0.7)
	_box(b, Vector3(0.5, 0.05, 0.5), Vector3(0, 0.03, 0), plastic)
	_box(b, Vector3(0.06, 1.0, 0.06), Vector3(0, 0.55, 0), plastic)
	_box(b, Vector3(0.62, 0.48, 0.16), Vector3(0, 1.25, 0), plastic, "Case")
	var q := _art_quad(b, MONITOR_ART, 0.52, Vector3(0, 1.25, 0.085), false, "Screen")
	var qm: StandardMaterial3D = q.get_surface_override_material(0)
	qm.albedo_color = Color(0.22, 0.2, 0.26)   # a dead screen: the face is only just there
	return b


# Cradle-shaped slats suspended around an absence, with runners rotated away from
# the rails they once supported. The central route through the room stays clear.
static func fractured_cradle(level: Node3D, pos: Vector3, yaw: float, nm: String,
		script: Script = null, family: String = "violet") -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(1.35, 1.65, 1.45), Vector3(0, 0.825, 0), script)
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	for side in [-1.0, 1.0]:
		var runner := _box(body, Vector3(0.16, 0.16, 1.35), Vector3(side * 0.46, 0.34, 0), stone, "Runner")
		runner.rotation = Vector3(side * 0.2, side * 0.4, 0)
		for i in range(4):
			var slat := _box(body, Vector3(0.10, 0.70, 0.10), Vector3(side * 0.49, 1.04 + i * 0.07, -0.54 + i * 0.35), pale, "FloatingSlat")
			slat.rotation.z = side * (0.18 + i * 0.08)
		var rail := _box(body, Vector3(0.10, 0.10, 1.32), Vector3(side * 0.59, 1.62, 0.04), stone, "DetachedRail")
		rail.rotation.x = side * 0.15
	_box(body, Vector3(0.74, 0.10, 0.60), Vector3(-0.16, 0.86, 0.14), stone, "BrokenBed")
	return body


# The crayon drawing, on a wall (the parent is positioned at the wall point, yawed to face in).
static func crayon_drawing(level: Node3D, pos: Vector3, yaw: float, nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	n.rotation.y = yaw
	level.add_child(n)
	_art_quad(n, DRAWING_ART, 0.7, Vector3.ZERO, false, "Art")
	return n


# The music box: a small dark chest with a crank, on a stool — the object, not the tune.
static func music_box(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "violet") -> StaticBody3D:
	var b := _body(level, nm, pos, yaw, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.37, 0))
	var wood := fmat(family, DARK)
	_box(b, Vector3(0.4, 0.05, 0.4), Vector3(0, 0.47, 0), wood)
	for x in [-0.15, 0.15]:
		for z in [-0.15, 0.15]:
			_box(b, Vector3(0.05, 0.45, 0.05), Vector3(x, 0.22, z), wood)
	_box(b, Vector3(0.26, 0.16, 0.18), Vector3(0, 0.58, 0), fmat(family, BASE), "Box")
	_box(b, Vector3(0.02, 0.02, 0.09), Vector3(0.14, 0.62, 0), _mat(Color(0.35, 0.33, 0.3), 0.4, 0.5), "Crank")
	return b


# ═══════════════════════════════════════════════════════════════════════════════════════
# ⭐ VOID-NATIVE IMPOSSIBLE PROPS (2026-09-20). Capture #1: *"throughout the level I think we
# need to have more weird objects representing fear, broken geometry, complete nonsense and so
# on"*. Seven rooms held nothing at all. Every builder below is matte `_mat(TINT*)`, has NO
# emission and NO `ScaryObject` ancestor — they cost zero panic and are scenery, not a scare
# with a number on it (GAME_MECHANICS_IDEAS' governing finding).
# ═══════════════════════════════════════════════════════════════════════════════════════


# A flight of stairs that climbs into the ceiling and stops. Treads finish 3 cm under the
# slab: there is no hatch, no landing, nothing at the top.
static func ceiling_stair(level: Node3D, pos: Vector3, yaw: float, ceiling_y: float, nm: String,
		family: String = "violet") -> StaticBody3D:
	const TREADS := 10
	var top := ceiling_y - 0.03
	var body := _body(level, nm, pos, yaw, Vector3(0.80, top, 3.45), Vector3(0, top * 0.5, 0))
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	for i in range(TREADS):
		var t: float = float(i) / float(TREADS - 1)
		var tread := _box(body, Vector3(0.70, 0.06, 0.30),
			Vector3(0.0, 0.22 + t * (top - 0.28), -1.55 + t * 3.10), stone, "Tread%d" % i)
		tread.rotation.z = 0.02 * (1.0 if i % 2 == 0 else -1.0)
	# One stringer, broken in the middle: the flight is not held up by anything.
	for seg in range(2):
		var s0 := _box(body, Vector3(0.09, 0.13, 1.35),
			Vector3(0.33, 0.55 + seg * 1.55, -1.10 + seg * 1.75), pale, "Stringer%d" % seg)
		s0.rotation.x = -0.76 + seg * 0.10
	return body


# A doorframe lying FLAT on the floor with a hole of black inside it. The quad sits 3.5 cm
# proud of the slab (the wall-prop guard wants 2 cm) and nothing here collides: you walk
# over a doorway you cannot walk through.
static func flat_doorframe(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "violet") -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	n.rotation.y = yaw
	level.add_child(n)
	var stone := fmat(family, PALE)
	for side in [-1.0, 1.0]:
		_box(n, Vector3(0.12, 0.10, 2.10), Vector3(side * 0.52, 0.05, 0.0), stone, "FlatJamb")
	_box(n, Vector3(1.16, 0.10, 0.12), Vector3(0, 0.05, 1.11), stone, "FlatLintel")
	_box(n, Vector3(1.16, 0.10, 0.12), Vector3(0, 0.05, -1.11), stone, "FlatThreshold")
	var hole := MeshInstance3D.new()
	hole.name = "FlatDoorwayBlack"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.92, 2.06)
	hole.mesh = qm
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0, 0, 0)
	black.roughness = 1.0
	hole.set_surface_override_material(0, black)
	hole.position = Vector3(0, 0.035, 0)
	hole.rotation.x = -PI / 2.0
	n.add_child(hole)
	return n


# Waiting-room chairs fused INTO a wall. Only the half that protrudes is built; their backs
# stop 3 cm short of the wall face, so no two visible surfaces share a plane.
# ⚠️ `pos` is the WALL POINT and local -z points into the room. Deepest geometry stops at
# local -0.41 so the prop never reaches the 1.8 m doorway lane that runs past it.
static func fused_chairs(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "violet") -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(1.90, 0.95, 0.40), Vector3(0, 0.48, -0.22))
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	var i := 0
	for x in [-0.72, 0.02, 0.74]:
		var seat := _box(body, Vector3(0.46, 0.07, 0.38), Vector3(x, 0.44 + i * 0.03, -0.22), stone, "FusedSeat%d" % i)
		seat.rotation = Vector3(0.05 - i * 0.04, 0.06 * (i - 1), 0.03 * (1 - i))
		for leg in [-0.18, 0.18]:
			var l := _box(body, Vector3(0.06, 0.44, 0.06), Vector3(x + leg, 0.22, -0.33), pale, "FusedLeg")
			l.rotation.z = 0.05 * leg * 10.0
		var back := _box(body, Vector3(0.46, 0.55, 0.06), Vector3(x, 0.80 + i * 0.05, -0.06), stone, "FusedBack%d" % i)
		back.rotation.z = 0.08 * (i - 1)
		i += 1
	return body


# A table standing on the ceiling side of itself: the top floats 10 cm off the floor and the
# legs point up. `TableAssembly` is the child `void_rearrangement.gd` re-poses off-screen.
#
# ⚠️ THE COLLIDER IS THE TOP SLAB, NOT THE WHOLE BOUNDING BOX (2026-09-20 pass 3). It used
# to be 1.50 x 1.05 x 1.00 from the floor to above the legs, which made the basin between the
# legs a place the eye can enter and the E-ray cannot: the ray takes the nearest hit, so it
# stopped on the bounding box every time. The stone shard now lies in that basin, so the
# collision is the 0.30 m slab and the legs are open air — exactly the fix
# `inverted_slab()` needed for the hollow on its underside. The top slab still spans the whole
# footprint, so the table is not a thing you can walk into.
static func inverted_table(level: Node3D, pos: Vector3, yaw: float, nm: String,
		script: Script = null, family: String = "violet") -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(1.50, 0.22, 1.00), Vector3(0, 0.11, 0), script)
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	_box(body, Vector3(1.40, 0.08, 0.90), Vector3(0, 0.14, 0), stone, "InvertedTop")
	var assembly := Node3D.new()
	assembly.name = "TableAssembly"
	assembly.position = Vector3(0, 0.18, 0)
	body.add_child(assembly)
	var i := 0
	for x in [-0.58, 0.58]:
		for z in [-0.34, 0.34]:
			var leg := _box(assembly, Vector3(0.09, 0.76, 0.09), Vector3(x, 0.40, z), pale, "InvertedLeg%d" % i)
			leg.rotation = Vector3(0.07 * signf(z), 0.0, -0.09 * signf(x))
			i += 1
	_box(assembly, Vector3(1.10, 0.05, 0.05), Vector3(0, 0.70, 0.30), stone, "InvertedStretcher")
	return body


# A heap of doors that cannot have come from anywhere: this wing has fourteen doorways and
# none of them ever had a door. `HeapAssembly` is the off-screen rearrangement target.
static func door_heap(level: Node3D, pos: Vector3, yaw: float, nm: String,
		script: Script = null, family: String = "violet") -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(0.62, 2.20, 2.20), Vector3(0, 1.05, 0), script)
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	var assembly := Node3D.new()
	assembly.name = "HeapAssembly"
	body.add_child(assembly)
	var leans := [
		[Vector3(0.02, 1.02, -0.55), Vector3(0.10, 0.22, -0.28)],
		[Vector3(-0.06, 0.96, 0.18), Vector3(-0.08, -0.31, 0.24)],
		[Vector3(0.05, 1.28, 0.72), Vector3(0.16, 0.12, -0.44)],
		[Vector3(-0.02, 0.52, -0.05), Vector3(-0.22, 0.44, 0.33)],
		[Vector3(0.03, 1.66, -0.30), Vector3(0.06, -0.18, -0.52)],
	]
	var i := 0
	for lean in leans:
		# ⭐ "mixed" gives every door in the heap its OWN family (2026-09-20 pass 2): the joke
		# is that fourteen doorways in this wing never had a door, so the doors that turned up
		# came from somewhere else — and they do not match each other.
		if family == "mixed":
			var f: String = MIXED_ORDER[i % MIXED_ORDER.size()]
			stone = fmat(f, BASE)
			pale = fmat(f, PALE)
		var slab := _box(assembly, Vector3(0.07, 1.98, 0.86), lean[0], stone if i % 2 == 0 else pale, "HeapDoor%d" % i)
		slab.rotation = lean[1]
		# ⚠️ A flat slab reads as a plank, not as a door (Issue 35: silhouette carries a prop).
		# Two raised panels and a knob, each carried in the SLAB'S OWN frame so they stay on
		# its face however it leans (local -X is the side that faces the corridor), and each
		# only ~2 cm proud so the heap still fits the
		# 0.62 m envelope that keeps it out of Hall3's doorway lane.
		var face := Basis.from_euler(lean[1])
		for panel in [0.44, -0.44]:
			var pl := _box(assembly, Vector3(0.02, 0.74, 0.58),
				lean[0] + face * Vector3(-0.046, panel, 0.0),
				fmat(MIXED_ORDER[i % MIXED_ORDER.size()] if family == "mixed" else family, DARK),
				"HeapPanel")
			pl.rotation = lean[1]
		var knob := _box(assembly, Vector3(0.09, 0.07, 0.07),
			lean[0] + face * Vector3(-0.05, -0.16, 0.30), pale, "HeapKnob%d" % i)
		knob.rotation = lean[1]
		i += 1
	return body


# ⭐ THE THREE ANCHORS (2026-09-20 pass 3): a door HANDLE, a bed SLAT and a window LATCH.
#
# One silhouette builder, called twice for each object — once by `void_anchor.gd` where the
# thing lies in the world, and once by `void_alignment.gd` when it is seated in a socket and
# BECOMES that viewpoint's keystone. Identical geometry in both places, on purpose: the thing
# you pick up is the thing you see in the socket, which is the only evidence the player gets
# that they carried it there.
#
# ⚠️ THE SIZES ARE MEASURED AGAINST THE SHAPE EACH ONE GATES (Issue 229 — two props hidden by
# their own geometry). A keystone hangs at `eye + f·1.1`, so a 0.16 m width subtends ±4.2°
# and a 0.34 m height ±8.8°. The door's opening is ±12.2° wide, so the handle hangs INSIDE it,
# where a handle belongs; the bed's silhouette spans −28.6°..+6.1° and its socket sits at
# +19.1°, so the slat (±2.6° wide) clears it by 10°; the window spans −26.1°..+5.7° against a
# socket at +20.0°, and the latch (±4.2°) clears by 10°. Do not grow any of these without
# re-checking those three numbers and re-shooting the three `void_view_*` screenshots.
#
# Canonical frame: +Y up, +Z toward the viewer. `kind` is "handle" / "slat" / "latch".
static func anchor_mesh(parent: Node3D, kind: String, family: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Anchor" + kind.capitalize()
	parent.add_child(root)
	var base := fmat(family, BASE)
	var pale := fmat(family, PALE)
	var dark := fmat(family, DARK)
	match kind:
		"handle":
			# A lever handle off a door that never existed: a rose, a stub of spindle, and the
			# lever dropped out of true. ~0.13 wide x 0.22 tall.
			var rose := _box(root, Vector3(0.115, 0.145, 0.028), Vector3(0, 0.045, -0.02), dark, "HandleRose")
			rose.rotation.z = 0.06
			_box(root, Vector3(0.05, 0.05, 0.075), Vector3(0, 0.045, 0.015), base, "HandleSpindle")
			var lever := _box(root, Vector3(0.055, 0.175, 0.05), Vector3(0.012, -0.035, 0.045), pale, "HandleLever")
			lever.rotation = Vector3(0.0, 0.0, 0.34)
			var tip := _box(root, Vector3(0.07, 0.05, 0.05), Vector3(0.062, -0.115, 0.045), base, "HandleTip")
			tip.rotation.z = 0.34
		"slat":
			# A bed slat: a board with a peg block at each end, one of them broken short.
			var board := _box(root, Vector3(0.095, 0.30, 0.032), Vector3.ZERO, pale, "SlatBoard")
			board.rotation.z = 0.05
			_box(root, Vector3(0.125, 0.045, 0.05), Vector3(0.008, 0.155, 0.004), base, "SlatPegTop")
			var foot := _box(root, Vector3(0.125, 0.045, 0.05), Vector3(-0.008, -0.155, 0.004), base, "SlatPegFoot")
			foot.rotation.z = 0.22
			_box(root, Vector3(0.05, 0.075, 0.042), Vector3(-0.055, 0.06, 0.006), dark, "SlatSplit")
		_:
			# A window latch: a backplate, the pivot, and the hook swung open.
			var plate := _box(root, Vector3(0.055, 0.145, 0.03), Vector3(-0.045, 0.0, -0.015), dark, "LatchPlate")
			plate.rotation.z = -0.08
			_box(root, Vector3(0.045, 0.045, 0.06), Vector3(-0.045, 0.045, 0.02), base, "LatchPivot")
			var arm := _box(root, Vector3(0.155, 0.042, 0.042), Vector3(0.03, 0.005, 0.03), pale, "LatchArm")
			arm.rotation.z = -0.42
			var hook := _box(root, Vector3(0.042, 0.085, 0.042), Vector3(0.093, -0.075, 0.03), pale, "LatchHook")
			hook.rotation.z = 0.30
			_box(root, Vector3(0.05, 0.05, 0.036), Vector3(-0.045, -0.075, 0.015), base, "LatchKeeper")
	return root


# The empty stone SOCKET a viewpoint carries before its anchor is set in it: a base and two
# jaws with nothing between them. In the VIEW'S OWN TINT, so the three sockets are three
# colours and a placed keystone keeps the colour of the memory it completes.
static func anchor_socket(parent: Node3D, tint: Color, nm: String) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	parent.add_child(root)
	var stone := _mat(tint)
	var dark := _mat(tint.darkened(0.45))
	_box(root, Vector3(0.22, 0.05, 0.16), Vector3(0, -0.13, 0), stone, "SocketBase")
	for side in [-1.0, 1.0]:
		var jaw := _box(root, Vector3(0.035, 0.17, 0.13), Vector3(side * 0.085, -0.04, 0), stone, "SocketJaw")
		jaw.rotation.z = side * -0.09
	_box(root, Vector3(0.12, 0.03, 0.09), Vector3(0, -0.10, 0), dark, "SocketWell")
	return root


# Stone shards hung from the ceiling on threads. High enough to walk under (lowest tip 2.15 m),
# so they need no collision and cannot wedge anyone. Deterministic per `seed_value`.
static func hung_shards(level: Node3D, pos: Vector3, nm: String, count: int,
		seed_value: int, ceiling_y: float, family: String = "violet") -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	level.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var thread_mat := fmat(family, DARK, 1.0)
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	for i in range(count):
		var ox := rng.randf_range(-0.85, 0.85)
		var oz := rng.randf_range(-0.85, 0.85)
		var drop := rng.randf_range(0.32, 0.95)          # thread length
		var top := ceiling_y - 0.02                      # 3.28 at ROOM_H 3.3
		var shard_y := top - drop - 0.14
		var thread := _box(n, Vector3(0.014, drop, 0.014),
			Vector3(ox, top - drop * 0.5, oz), thread_mat, "Thread%d" % i)
		thread.rotation = Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
		var shard := _box(n, Vector3(rng.randf_range(0.10, 0.22), rng.randf_range(0.16, 0.30),
			rng.randf_range(0.07, 0.15)), Vector3(ox, shard_y, oz),
			stone if i % 3 else pale, "Shard%d" % i)
		shard.rotation = Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-1.5, 1.5),
			rng.randf_range(-0.7, 0.7))
	return n


# The morgue's drawer bank: six columns, three rows, one front missing.
#
# ⭐ THE SEVENTEEN FRONTS OPEN (2026-09-20 pass 3). They were scenery — "nothing opens, which
# is the joke" — and the 15:00 playtester asked for sub-challenges in a level whose verbs were
# walk, look and press E once. Each surviving front is now its own layer-2 body carrying
# `void_drawer.gd`: E slides it out 0.35 m, once, with a `drawer_pull`. Sixteen hold nothing.
# ⚠️ THE INTERACT VOLUME MUST STAND PROUD OF THE CARCASS COLLIDER. The carcass is one
# 3.62 x 1.92 x 0.52 block whose front face is at local z +0.26, and the player's E-ray takes
# the CLOSEST hit — an interact box flush with or behind that face is a box the ray never
# reaches. Each drawer's own box sits at local z +0.35, i.e. 0.09 m in front of it.
# ⚠️ `_body()` is not used: these are layer-2 (walk-through) bodies, not solid props.
static func drawer_bank(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "violet", drawer_script: Script = null,
		page_at: Vector2i = Vector2i(-1, -1)) -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(3.62, 1.92, 0.52), Vector3(0, 0.99, 0))
	var stone := fmat(family, DARK)
	var steel := fmat(family, BASE, 0.55, 0.25)
	var pale := fmat(family, PALE, 0.5, 0.3)
	_box(body, Vector3(3.60, 1.90, 0.50), Vector3(0, 0.98, 0), stone, "DrawerCarcass")
	var missing := Vector2i(5, 0)     # column 5, bottom row: the long drawer came out of it
	for col in range(6):
		for row in range(3):
			var at := Vector3(-1.5 + col * 0.6, 0.35 + row * 0.63, 0.265)
			if Vector2i(col, row) == missing:
				_box(body, Vector3(0.54, 0.54, 0.02), at + Vector3(0, 0, -0.16),
					_mat(Color(0.02, 0.02, 0.03), 1.0), "DrawerHole")
				continue
			if drawer_script == null:
				var plain := _box(body, Vector3(0.54, 0.54, 0.04), at, steel, "DrawerFront%d_%d" % [col, row])
				plain.rotation.z = 0.012 * float((col + row) % 3 - 1)
				_box(body, Vector3(0.22, 0.035, 0.035), at + Vector3(0, -0.15, 0.04), pale, "DrawerHandle")
				continue
			# ⚠️ script BEFORE add_child, or _ready() never runs (the _make_note rule).
			var drawer := StaticBody3D.new()
			drawer.name = "Drawer%d_%d" % [col, row]
			drawer.set_script(drawer_script)
			drawer.set("col", col)
			drawer.set("row", row)
			drawer.set("holds_page", Vector2i(col, row) == page_at)
			drawer.position = at
			body.add_child(drawer)
			var front := _box(drawer, Vector3(0.54, 0.54, 0.04), Vector3.ZERO, steel,
				"DrawerFront%d_%d" % [col, row])
			front.rotation.z = 0.012 * float((col + row) % 3 - 1)
			_box(drawer, Vector3(0.22, 0.035, 0.035), Vector3(0, -0.15, 0.04), pale, "DrawerHandle")
			# The tray inside: invisible while shut behind its own front, and the thing a page
			# lying in the drawer RESTS on. ⚠️ It needs a COLLIDER, not just a mesh —
			# check_note_mounting measures support with a physics ray, and a page resting on a
			# mesh with no collider is a page resting on nothing, 0.8 m above the floor.
			_box(drawer, Vector3(0.50, 0.02, 0.42), Vector3(0, -0.21, -0.23), stone, "DrawerTray")
			var tray := CollisionShape3D.new()
			tray.name = "TrayShape"
			var tb := BoxShape3D.new()
			tb.size = Vector3(0.50, 0.02, 0.42)
			tray.shape = tb
			tray.position = Vector3(0, -0.21, -0.23)
			drawer.add_child(tray)
	return body


# The drawer that came out of it. 3.9 m of drawer from a 0.5 m cabinet.
static func long_drawer(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "violet") -> StaticBody3D:
	var body := _body(level, nm, pos, yaw, Vector3(0.52, 0.22, 3.90), Vector3(0, 0.12, 0))
	var steel := fmat(family, BASE, 0.55, 0.25)
	var dark := fmat(family, DARK)
	_box(body, Vector3(0.50, 0.04, 3.88), Vector3(0, 0.03, 0), dark, "DrawerFloor")
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.03, 0.20, 3.88), Vector3(side * 0.235, 0.12, 0), steel, "DrawerWall")
	_box(body, Vector3(0.54, 0.26, 0.04), Vector3(0, 0.13, -1.97), steel, "DrawerFace")
	_box(body, Vector3(0.22, 0.035, 0.035), Vector3(0, 0.13, -2.00), fmat(family, PALE, 0.5, 0.3), "DrawerLongHandle")
	return body


# ⭐ THE HANGING GURNEY (2026-09-20 pass 5). The Ward's touchable fragment used to be a 0.24 m
# pale box — capture #1: *"Objects in this level, even though they should be broken and
# corrupted, they still should represent some objects. This one is too unclear."* It is now a
# hospital gurney hung NOSE-DOWN BY ONE CORNER in the middle of the ward: a thing you recognise
# from the first glance, in the wrong orientation, with nothing holding it up.
#
# ⚠️ BOXES ONLY and BONE family — the Ward's own palette, no emission, no `ScaryObject`, zero
# panic. The silhouette is what carries it (Issue 35): two side rails, a head board, four legs
# ending in caster discs, a mattress slab standing PROUD of the frame, and two straps, one of
# which hangs loose. A flat box would read as a box, which is exactly the complaint.
# ⚠️ The tilt lives on the inner `GurneyHang` node, not on the parent, so a caller can rock the
# whole thing (the touch receipt drops it 0.10 m and yaws it 6°) without touching the pose.
# ⚠️ THE POSE IS SET FROM THE PICTURE, not from the number. At 77 degrees the thing is almost
# vertical and the mattress fills the frame as a pale rectangle — the complaint it exists to
# answer, in a bigger size. At 49 degrees, turned broadside to the room, you see the rails, the
# four legs, the casters and the slumped pad: a gurney, tipped, hanging by one corner.
# ⚠️ THE YAW IS PART OF THE POSE, and it is also what keeps the footprint out of the way: the
# long axis runs along X, where the Ward is 10 m wide, so the prop spans z 12.61..13.68.
# ⭐ 2026-09-22: what it clears there is now the WARD BOX (z 14.13..14.89), 0.45 m north of it —
# `FoldedFrame_Ward_L` is gone. The two are deliberately close: the gurney is the button and the
# box is what it opens, and a cause and an effect 1.2 m apart are in the same glance.
const GURNEY_TILT := 0.85        # radians, nose-down
const GURNEY_YAW := 1.72         # PI/2 + 0.15: broadside to the room, but not square to it
const GURNEY_ROLL := 0.22        # …and it hangs off one corner


static func gurney(parent: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "bone") -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var hang := Node3D.new()
	hang.name = "GurneyHang"
	hang.rotation = Vector3(GURNEY_TILT, GURNEY_YAW, GURNEY_ROLL)
	# ⚠️ 12 cm off the pivot in -z, measured: at 0 the low end reaches z 13.80, and what stands
	# to the north of it is the Ward box (its runners start at z 14.13). Two props sharing space
	# is how this project's most common bug class starts (Issues 19/20/23/24/25/26), and neither
	# of them is a CSG box, so `check_wall_overlap` would never have said a word about it.
	hang.position.z = -0.12
	root.add_child(hang)
	var steel := fmat(family, BASE, 0.6, 0.2)
	var pale := fmat(family, PALE)
	var dark := fmat(family, DARK)
	# ⚠️ EVERY PART HAS A UNIQUE NAME. Godot 4 does not suffix a duplicate node name, it REPLACES
	# it with the class-based auto name (Issue 237) — four legs called "GurneyLeg" are one
	# `GurneyLeg` and three `@MeshInstance3D@NN`, and a guard counting them finds one.
	var i := 0
	# The frame: two side rails and a head board that is still recognisably a head board.
	for side in [-1.0, 1.0]:
		_box(hang, Vector3(0.07, 0.09, 1.90), Vector3(side * 0.36, 0.02, 0.0), steel,
			"GurneyRail%d" % i)
		# Legs, one pair splayed — it has been dropped, not parked.
		for zi in [-1.0, 1.0]:
			var leg := _box(hang, Vector3(0.06, 0.60, 0.06),
				Vector3(side * 0.33, -0.32, zi * 0.78), steel, "GurneyLeg%d_%d" % [i, int(zi)])
			leg.rotation.z = side * 0.06 * zi
			# A caster as a thin box: a disc read at this size, and still box geometry.
			var wheel := _box(hang, Vector3(0.17, 0.17, 0.045),
				Vector3(side * 0.33, -0.645, zi * 0.78), dark, "GurneyWheel%d_%d" % [i, int(zi)])
			wheel.rotation.y = 0.18 * side
		i += 1
	_box(hang, Vector3(0.78, 0.07, 0.07), Vector3(0, 0.02, 0.92), steel, "GurneyFootBar")
	var board := _box(hang, Vector3(0.74, 0.34, 0.06), Vector3(0, 0.17, -0.94), pale, "GurneyHeadBoard")
	board.rotation.x = -0.16
	# The mattress stands PROUD of the frame and has slumped toward the low end.
	var pad := _box(hang, Vector3(0.70, 0.13, 1.66), Vector3(0.02, 0.11, 0.06), pale, "GurneyMattress")
	pad.rotation = Vector3(0.03, 0.02, -0.04)
	# Two straps: one still across the pad, one hanging off the low side.
	var strap := _box(hang, Vector3(0.80, 0.025, 0.11), Vector3(0, 0.17, -0.34), dark, "GurneyStrap0")
	strap.rotation.z = 0.05
	var loose := _box(hang, Vector3(0.10, 0.44, 0.025), Vector3(0.40, -0.06, 0.40), dark, "GurneyStrap1Loose")
	loose.rotation = Vector3(0.0, 0.0, -0.35)
	return root


# ⭐ THE WARD BOX (2026-09-22 pass 6). `FoldedFrame_Ward_L` was the second of the Ward's two
# suspended frames, and capture #1 of the 23:47 run photographed it: *"the object closer to the
# monster looks like a bed, but the one … further away … still does not remind anything … like a
# gift box"*. The player named the shape they wanted. It is now a sealed strapped stone box, and
# the bed slat is INSIDE it — capture #2: *"Should it be like a magical button that will open the
# magical box having this piece?"*
#
# ⚠️ BOXES ONLY, BONE FAMILY, NO EMISSION, NO `ScaryObject` — the Ward's own palette and the
# level's rules. Silhouette carries it (Issue 35): two plinth runners proud of the carcass, a
# base slab, four walls that leave a real open interior, a lid slab standing 2.5 cm CLEAR of the
# rim (never coplanar — Issues 19/20/23/24/25/26), two straps over the lid and two more strapped
# down the front with buckles. A flat box would read as a box, which is exactly the complaint.
#
# ⚠️ THE COLLISION IS THE WALLS, NOT THE BOUNDING BOX (Issue 230, the inverted slab's lesson). A
# single block would make the interior a place the eye can enter and the E-ray cannot, and the
# slat lives in there. Base + four walls + the LID'S OWN body, which rides the hinge: while the
# lid is shut it is what a descending ray finds, and when it swings back the interior is open to
# the ray. That is the gate, physically — `void_ward_box.gd` also refuses on the target itself,
# because a blocker guards one viewing angle and a refusal guards all of them (Issue 242).
const BOX_L := 1.90              # along local x
const BOX_D := 0.66              # along local z (the carcass; the runners and lid overhang)
const BOX_WALL := 0.07
const BOX_FLOOR_Y := 0.22        # the interior floor — the top face of the base slab
# ⚠️ A SHALLOW TRAY, NOT A CHEST, and the number is measured. The first build gave it 0.40 m of
# interior with a 0.62 m rim, and the bed slat inside it was reachable from exactly ONE stance
# out of six: the north wall's top edge cut the descending E-ray everywhere else. That is
# Issue 232 again — from eye height you cannot see into a deep open box at all, and here you
# could not aim into one either. At a 0.42 m rim the ray clears the wall by 7 cm from 2.4 m
# back, and the slat lying on the floor pokes above the rim where it can be SEEN.
const BOX_RIM_Y := 0.42          # the top of the four walls
const BOX_LID_Y := 0.48          # the hinge, 2.5 cm of air over the rim at the slab's underside
const BOX_HINGE_Z := -0.35       # the far side: the lid swings AWAY from the approach


static func strapped_box(level: Node3D, pos: Vector3, yaw: float, nm: String,
		family: String = "bone", script: Script = null) -> StaticBody3D:
	# The base slab is the collider `_body()` gives us; the walls and the lid are added on top.
	var body := _body(level, nm, pos, yaw,
		Vector3(BOX_L, BOX_FLOOR_Y, BOX_D), Vector3(0, BOX_FLOOR_Y * 0.5, 0), script)
	var stone := fmat(family, BASE)
	var pale := fmat(family, PALE)
	var dark := fmat(family, DARK)
	# Two plinth runners, proud of the carcass in z so the box does not read as one slab.
	var i := 0
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.32, 0.10, BOX_D + 0.06), Vector3(side * 0.60, 0.05, 0.0), dark,
			"WardBoxRunner%d" % i)
		i += 1
	_box(body, Vector3(BOX_L, 0.12, BOX_D), Vector3(0, 0.16, 0), stone, "WardBoxBase")
	var wall_h: float = BOX_RIM_Y - BOX_FLOOR_Y
	var wall_y: float = (BOX_RIM_Y + BOX_FLOOR_Y) * 0.5
	i = 0
	for side in [-1.0, 1.0]:
		_box(body, Vector3(BOX_L, wall_h, BOX_WALL),
			Vector3(0, wall_y, side * (BOX_D * 0.5 - BOX_WALL * 0.5)), stone,
			"WardBoxSide%d" % i)
		_extra_collider(body, Vector3(BOX_L, wall_h, BOX_WALL),
			Vector3(0, wall_y, side * (BOX_D * 0.5 - BOX_WALL * 0.5)))
		_box(body, Vector3(BOX_WALL, wall_h, BOX_D - BOX_WALL * 2.0),
			Vector3(side * (BOX_L * 0.5 - BOX_WALL * 0.5), wall_y, 0), pale,
			"WardBoxEnd%d" % i)
		_extra_collider(body, Vector3(BOX_WALL, wall_h, BOX_D - BOX_WALL * 2.0),
			Vector3(side * (BOX_L * 0.5 - BOX_WALL * 0.5), wall_y, 0))
		# The two straps that are still buckled down the front of the carcass. Their top runs
		# ride the LID and go with it, which is what makes an opened box read as undone.
		_box(body, Vector3(0.13, 0.34, 0.03),
			Vector3(side * 0.45, 0.44, BOX_D * 0.5 + 0.005), dark, "WardBoxStrapFront%d" % i)
		_box(body, Vector3(0.17, 0.10, 0.05),
			Vector3(side * 0.45, 0.33, BOX_D * 0.5 + 0.02), pale, "WardBoxBuckle%d" % i)
		i += 1
	# ── the lid: a hinge node at the far edge, with the slab and its own body hung off it ──
	var pivot := Node3D.new()
	pivot.name = "WardBoxLid"
	pivot.position = Vector3(0, BOX_LID_Y, BOX_HINGE_Z)
	body.add_child(pivot)
	var slab_at := Vector3(0, 0, -BOX_HINGE_Z + 0.01)
	_box(pivot, Vector3(BOX_L + 0.04, 0.07, BOX_D + 0.06), slab_at, stone, "WardBoxLidSlab")
	i = 0
	for side in [-1.0, 1.0]:
		_box(pivot, Vector3(0.13, 0.05, BOX_D + 0.10), slab_at + Vector3(side * 0.45, 0.055, 0.0),
			dark, "WardBoxStrapTop%d" % i)
		i += 1
	# ⚠️ THE LID'S COLLIDER BELONGS TO THE BOX'S OWN BODY, and that is a fix, not a shortcut. The
	# first build hung it on a StaticBody3D of its own under the hinge so it would swing with the
	# slab — and measured `ai_interact_target -> nothing` from every stance, because the ray DID
	# hit it and a body with no script is not interactable: `player.gd:_is_interactable()` throws
	# the hit away and the box's own *"The box is sealed."* could never appear. A collider that
	# swallows a ray on behalf of a prop must be ON that prop. `void_ward_box.gd` disables this
	# shape when the lid opens; the slab itself still swings, on the pivot, for the picture.
	var lid_col := _extra_collider(body, Vector3(BOX_L + 0.04, 0.07, BOX_D + 0.06),
		Vector3(0, BOX_LID_Y, BOX_HINGE_Z) + slab_at)
	lid_col.name = "WardBoxLidShape"
	return body
