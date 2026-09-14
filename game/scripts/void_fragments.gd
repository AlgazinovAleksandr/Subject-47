class_name VoidFragments
extends RefCounted

# ⭐ THE VOID IS MADE OF THE PLACES YOU HAVE BEEN (2026-09-12, the user's rebuild of level 8).
# Three rooms are rebuilt from earlier levels in the Void's own skin: the intro ward's gurneys,
# the Lab morgue's exam table and monitor, the House child's room's bed and crayon drawing. The
# stalkers stand where the original props stood.
#
# ⚠️ Re-implemented minimally rather than reusing `intro_room.gd:_build_gurney()`,
# `level_1.gd:_build_exam_table()` and `level_2.gd:_build_bed()`: none of those is static — each
# leans on its level's `add_child`, texture path and helper — and making them static would touch
# three shipped levels for a fragment that is supposed to look like a MEMORY of the room, not the
# room. Same parts, same proportions, grey-violet tint, no emission. Every prop is parts under ONE
# StaticBody3D collider (Issue 35), and every textured face is a QuadMesh sized from its artwork
# (Issue 24) — which is also what gives `check_art_aspect.gd` its first Void samples.

const TINT := Color(0.34, 0.30, 0.40)       # the memory of a colour, under violet light
const TINT_DARK := Color(0.16, 0.14, 0.19)
const TINT_PALE := Color(0.46, 0.43, 0.50)
const GURNEY_ART := "res://assets/textures/intro/gurney_intro.png"
const DRAWING_ART := "res://assets/textures/level_2_house/child_drawing.png"
const MONITOR_ART := "res://assets/textures/level_1_lab/lab_monitor_face.png"


static func _mat(c: Color, rough: float = 0.92, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
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


static func _body(level: Node3D, nm: String, pos: Vector3, yaw: float, col_size: Vector3,
		col_offset: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = nm
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos
	b.rotation.y = yaw
	level.add_child(b)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = col_size
	col.shape = sh
	col.position = col_offset
	b.add_child(col)
	return b


# The intro ward's gurney: frame, mattress proud of it, the stained pad on top, four castors.
static func gurney(level: Node3D, pos: Vector3, yaw: float, nm: String) -> StaticBody3D:
	var b := _body(level, nm, pos, yaw, Vector3(0.9, 0.7, 2.0), Vector3(0, 0.35, 0))
	var frame := _mat(TINT_DARK, 0.5, 0.4)
	_box(b, Vector3(0.9, 0.08, 2.0), Vector3(0, 0.46, 0), frame, "Frame")
	for x in [-0.4, 0.4]:
		for z in [-0.9, 0.9]:
			_box(b, Vector3(0.05, 0.42, 0.05), Vector3(x, 0.21, z), frame)
			_box(b, Vector3(0.09, 0.08, 0.09), Vector3(x, 0.04, z), _mat(Color(0.06, 0.06, 0.07)))
	_box(b, Vector3(0.85, 0.1, 1.9), Vector3(0, 0.55, 0), _mat(TINT), "Mattress")
	_box(b, Vector3(0.06, 0.5, 0.05), Vector3(-0.45, 0.6, -0.95), frame)   # the drip stand
	_art_quad(b, GURNEY_ART, 1.9, Vector3(0, 0.605, 0), true, "Pad")
	return b


# The Lab morgue's exam table: top, pad, rails, shelf, legs, castors — and the dead monitor.
static func exam_table(level: Node3D, pos: Vector3, yaw: float, nm: String) -> StaticBody3D:
	var b := _body(level, nm, pos, yaw, Vector3(0.9, 0.9, 2.0), Vector3(0, 0.45, 0))
	var steel := _mat(Color(0.20, 0.20, 0.24), 0.45, 0.4)
	_box(b, Vector3(0.78, 0.06, 1.90), Vector3(0, 0.86, 0), steel, "Top")
	_box(b, Vector3(0.70, 0.05, 1.78), Vector3(0, 0.915, 0), _mat(TINT_DARK), "Pad")
	for x in [-0.40, 0.40]:
		_box(b, Vector3(0.04, 0.05, 1.86), Vector3(x, 0.90, 0), steel)
	_box(b, Vector3(0.62, 0.04, 1.30), Vector3(0, 0.30, 0), steel, "Shelf")
	for i in range(4):
		var sx: float = -0.32 if i % 2 == 0 else 0.32
		var sz: float = -0.80 if i < 2 else 0.80
		_box(b, Vector3(0.05, 0.80, 0.05), Vector3(sx, 0.44, sz), steel)
		_box(b, Vector3(0.09, 0.08, 0.09), Vector3(sx, 0.04, sz), _mat(Color(0.05, 0.05, 0.06)))
	return b


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


# The House child's bed: frame on legs, mattress proud, pillow, headboard.
static func child_bed(level: Node3D, pos: Vector3, yaw: float, nm: String) -> StaticBody3D:
	var l := 1.7
	var w := 0.9
	var b := _body(level, nm, pos, yaw, Vector3(l, 0.7, w), Vector3(0, 0.35, 0))
	var frame := _mat(TINT_DARK)
	_box(b, Vector3(l, 0.16, w), Vector3(0, 0.22, 0), frame, "Frame")
	for dx in [-l / 2.0 + 0.09, l / 2.0 - 0.09]:
		for dz in [-w / 2.0 + 0.09, w / 2.0 - 0.09]:
			_box(b, Vector3(0.09, 0.14, 0.09), Vector3(dx, 0.07, dz), frame)
	_box(b, Vector3(l - 0.06, 0.14, w - 0.04), Vector3(0, 0.36, 0), _mat(TINT), "Mattress")
	_box(b, Vector3(0.42, 0.09, w * 0.62), Vector3(-l / 2.0 + 0.26, 0.46, 0), _mat(TINT_PALE), "Pillow")
	_box(b, Vector3(0.07, 0.72, w), Vector3(-l / 2.0 - 0.03, 0.44, 0), frame, "Headboard")
	return b


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
static func music_box(level: Node3D, pos: Vector3, yaw: float, nm: String) -> StaticBody3D:
	var b := _body(level, nm, pos, yaw, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.37, 0))
	var wood := _mat(TINT_DARK)
	_box(b, Vector3(0.4, 0.05, 0.4), Vector3(0, 0.47, 0), wood)
	for x in [-0.15, 0.15]:
		for z in [-0.15, 0.15]:
			_box(b, Vector3(0.05, 0.45, 0.05), Vector3(x, 0.22, z), wood)
	_box(b, Vector3(0.26, 0.16, 0.18), Vector3(0, 0.58, 0), _mat(Color(0.22, 0.16, 0.24)), "Box")
	_box(b, Vector3(0.02, 0.02, 0.09), Vector3(0.14, 0.62, 0), _mat(Color(0.35, 0.33, 0.3), 0.4, 0.5), "Crank")
	return b
