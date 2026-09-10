extends Node3D
class_name RitualPiece

# THE SIX RITUAL PIECES of the Backrooms Flood (2026-09-10, the user's design — playtest
# capture #12: *"same pattern - like candle, old book, a skull"*). Until this pass every one of
# THE DROWNED's six objects held the SAME thing: a grey enamel shard with a pale broken edge,
# and the plate table was six identical recesses. Six containers with six different
# silhouettes handing over six identical pieces is a set nobody remembers, and a puzzle whose
# assembly point cannot tell you what it is missing.
#
# Now: a candle · an old book · a skull · a bell · an iron key · a doll. `build(kind)` is the
# ONE builder, called by both `sunken_item.gd` (the piece lying in the thing you hauled open)
# and `flood_plate.gd` (the same piece, hidden in its outlined slot on the altar until it is
# set) — so the object seen and the object set are the same mesh, byte for byte.
#
# ⚠️ PARTS AND TEXTURES, NEVER A BILLBOARD. The altar is looked at from above by a player
# walking round it, and a card is a card from that angle. The skull is a mesh (cranium, jaw,
# sockets, nasal wedge) for exactly that reason. Textures are flux close-ups graded by
# `tools/grade_ritual_textures.py` and applied TRIPLANAR at a per-kind scale, because a 6 cm
# object under a torch needs a few tiles across it, not 6 % of one.
#
# ⚠️ NO EMISSION ANYWHERE, EVER. This zone's puzzle is solved with the torch OFF and
# `check_flood_drowned.gd` asserts that nothing down here is self-lit (§5.2(8)). A piece that
# glowed would be found by light, which is the one thing the Flood must not teach.
#
# ⚠️ NO COLLIDER AND NO RULES. The grab volume belongs to `SunkenPiece`; the altar copy is
# scenery. Zero panic, no `ScaryObject`, no `interact()`.

const KINDS := ["candle", "book", "skull", "bell", "key", "doll"]

const TEX_DIR := "res://assets/textures/level_backrooms/"

# Outline shape the altar draws for each kind: a ring, or a rectangular bar frame.
const OUTLINE := {
	"candle": {"shape": "ring", "r": 0.050},
	"book":   {"shape": "bar",  "w": 0.22, "d": 0.17},
	"skull":  {"shape": "ring", "r": 0.080},
	"bell":   {"shape": "ring", "r": 0.080},
	"key":    {"shape": "bar",  "w": 0.22, "d": 0.08},
	"doll":   {"shape": "bar",  "w": 0.30, "d": 0.12},
}


static func build(kind: String, parent: Node = null, piece_name: String = "") -> RitualPiece:
	var p := RitualPiece.new()
	p.name = piece_name if piece_name != "" else "Piece_%s" % kind
	match kind:
		"candle": p._build_candle()
		"book": p._build_book()
		"skull": p._build_skull()
		"bell": p._build_bell()
		"key": p._build_key()
		"doll": p._build_doll()
		_:
			push_warning("RitualPiece: unknown kind '%s' — building a candle" % kind)
			p._build_candle()
	if parent != null:
		parent.add_child(p)
	return p


# ------------------------------------------------------------------------ materials

# Triplanar, world-scaled, negative V (the project's wall convention — a positive V renders
# the texture upside-down, Issue 19), no emission. `fallback` is the flat tint used when the
# texture is missing, so a deleted PNG degrades to a dark shape rather than a magenta one.
static func _tex(file: String, scale: float, fallback: Color, rough: float = 0.85,
		metallic: float = 0.0, tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = rough
	m.metallic = metallic
	var path := TEX_DIR + file
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.albedo_color = tint
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(scale, -scale, scale)
	else:
		m.albedo_color = fallback
	return m


static func _flat(color: Color, rough: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m


# `door.gd:crop_uv_to_fit()`'s rule, repeated here rather than imported (door.gd has no
# class_name): sample a centred sub-rect of the texture so the artwork is never stretched.
# `check_art_aspect.gd` compares mesh aspect against pixel aspect x uv1_scale, which is
# exactly what this produces.
static func _crop_uv(mat: StandardMaterial3D, mesh_aspect: float) -> void:
	if mat.albedo_texture == null or mesh_aspect <= 0.0:
		return
	var tex := mat.albedo_texture
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	if absf(tex_aspect - mesh_aspect) < 0.001:
		return
	if tex_aspect > mesh_aspect:
		var u: float = mesh_aspect / tex_aspect
		mat.uv1_scale = Vector3(u, 1.0, 1.0)
		mat.uv1_offset = Vector3((1.0 - u) * 0.5, 0.0, 0.0)
	else:
		var v: float = tex_aspect / mesh_aspect
		mat.uv1_scale = Vector3(1.0, v, 1.0)
		mat.uv1_offset = Vector3(0.0, (1.0 - v) * 0.5, 0.0)


# ------------------------------------------------------------------------ primitives

func _box(n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _cyl(n: String, top_r: float, bot_r: float, h: float, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _sphere(n: String, r: float, pos: Vector3, mat: Material,
		scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	add_child(mi)
	return mi


# A torus lies flat (axis Y) by default.
func _torus(n: String, inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 24
	tm.ring_segments = 12
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _capsule(n: String, r: float, h: float, pos: Vector3, rot: Vector3,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


# ------------------------------------------------------------------------ the six

# Every builder puts the piece's BASE at local y = 0 so a caller places it on a surface.

func _build_candle() -> void:
	var wax := _tex("ritual_wax.png", 9.0, Color(0.42, 0.36, 0.20), 0.6)
	# A pooled base, the shaft, a drip collar two thirds up, and a black wick. The pool is
	# what says "burned down" rather than "a yellow cylinder".
	_cyl("Pool", 0.048, 0.052, 0.010, Vector3(0, 0.005, 0), wax)
	_cyl("Shaft", 0.026, 0.030, 0.150, Vector3(0, 0.085, 0), wax)
	_torus("Drip", 0.022, 0.038, Vector3(0.004, 0.118, 0.003), wax)
	_cyl("Wick", 0.0025, 0.0025, 0.020, Vector3(0, 0.168, 0), _flat(Color(0.03, 0.02, 0.02)))


func _build_book() -> void:
	var leather := _tex("ritual_leather.png", 5.0, Color(0.09, 0.07, 0.06), 0.8)
	var pages := _tex("ritual_pages.png", 6.0, Color(0.42, 0.36, 0.24), 0.95)
	# Two leather covers with a block of page edges between them and a spine on -x. Cover
	# art lies on the top cover as a quad 1 mm proud of it (art on a quad, never a box face —
	# Issue 24), cropped to the quad's aspect rather than stretched.
	_box("CoverBottom", Vector3(0.200, 0.006, 0.150), Vector3(0, 0.003, 0), leather)
	_box("Pages", Vector3(0.186, 0.038, 0.140), Vector3(0.006, 0.025, 0), pages)
	_box("CoverTop", Vector3(0.200, 0.006, 0.150), Vector3(0, 0.047, 0), leather)
	_box("Spine", Vector3(0.012, 0.050, 0.150), Vector3(-0.100, 0.025, 0), leather)
	var art := MeshInstance3D.new()
	art.name = "CoverArt"
	var q := QuadMesh.new()
	q.size = Vector2(0.184, 0.136)
	art.mesh = q
	var am := StandardMaterial3D.new()
	am.roughness = 0.85
	var path := TEX_DIR + "ritual_book_cover.png"
	if ResourceLoader.exists(path):
		am.albedo_texture = load(path)
		_crop_uv(am, q.size.x / q.size.y)
	else:
		am.albedo_color = Color(0.08, 0.07, 0.06)
	art.material_override = am
	# A quad faces +Z; lay it flat facing UP with its top edge toward the spine's opposite
	# side (+x), i.e. the book reads the right way from the front of the altar.
	art.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	art.position = Vector3(0.004, 0.051, 0)
	add_child(art)


func _build_skull() -> void:
	var bone := _tex("ritual_bone.png", 6.0, Color(0.36, 0.33, 0.26), 0.9)
	var dark := _flat(Color(0.03, 0.03, 0.03), 1.0)
	# Cranium (a squashed sphere, longer front to back), a jaw block under the front, two
	# sunken sockets, a nasal wedge and two cheekbones. It faces -Z.
	_sphere("Cranium", 0.062, Vector3(0, 0.078, 0.008), bone, Vector3(1.0, 0.92, 1.12))
	_box("Jaw", Vector3(0.070, 0.030, 0.050), Vector3(0, 0.020, -0.035), bone)
	_box("TeethRow", Vector3(0.060, 0.008, 0.010), Vector3(0, 0.038, -0.062), bone)
	for sx in [-1.0, 1.0]:
		_sphere("Socket", 0.015, Vector3(sx * 0.024, 0.086, -0.052), dark)
		_box("Cheek", Vector3(0.018, 0.020, 0.024), Vector3(sx * 0.044, 0.060, -0.040), bone)
	_box("Nasal", Vector3(0.012, 0.024, 0.014), Vector3(0, 0.062, -0.060), dark)


func _build_bell() -> void:
	var brass := _tex("ritual_brass.png", 7.0, Color(0.30, 0.26, 0.14), 0.55, 0.6)
	var iron := _flat(Color(0.06, 0.06, 0.06), 0.7, 0.3)
	# The body flares to a lip; a clapper hangs inside just above the floor; a ring on top.
	_cyl("Body", 0.030, 0.070, 0.110, Vector3(0, 0.060, 0), brass)
	_torus("Lip", 0.060, 0.076, Vector3(0, 0.008, 0), brass)
	_sphere("Clapper", 0.012, Vector3(0, 0.014, 0), iron)
	_cyl("Crown", 0.018, 0.030, 0.020, Vector3(0, 0.125, 0), brass)
	var ring := _torus("Ring", 0.010, 0.018, Vector3(0, 0.145, 0), brass)
	ring.rotation.x = PI / 2.0


func _build_key() -> void:
	var iron := _tex("ritual_iron.png", 8.0, Color(0.08, 0.08, 0.08), 0.7, 0.4)
	# Lying flat along X: a bow ring at -x, a shaft, and two bit teeth hanging toward -z.
	_torus("Bow", 0.018, 0.034, Vector3(-0.070, 0.006, 0), iron)
	_box("Shaft", Vector3(0.150, 0.012, 0.012), Vector3(0.022, 0.006, 0), iron)
	_box("Bit", Vector3(0.036, 0.012, 0.030), Vector3(0.080, 0.006, -0.015), iron)
	_box("BitNotch", Vector3(0.012, 0.012, 0.016), Vector3(0.060, 0.006, -0.008), iron)


func _build_doll() -> void:
	var porcelain := _tex("ritual_porcelain.png", 10.0, Color(0.50, 0.46, 0.40), 0.5)
	var cloth := _tex("ritual_cloth.png", 8.0, Color(0.22, 0.21, 0.19), 1.0)
	var dark := _flat(Color(0.02, 0.02, 0.02), 1.0)
	# Lying on its back, head toward +z, face up. Porcelain head and hands, a cloth torso
	# and dress, capsule limbs, and one eye — the other is missing.
	_sphere("Head", 0.035, Vector3(0, 0.034, 0.100), porcelain)
	_sphere("Eye", 0.006, Vector3(-0.012, 0.062, 0.088), dark)
	_box("Torso", Vector3(0.060, 0.040, 0.080), Vector3(0, 0.020, 0.025), cloth)
	_box("Dress", Vector3(0.095, 0.036, 0.070), Vector3(0, 0.018, -0.045), cloth)
	for sx in [-1.0, 1.0]:
		_capsule("Arm", 0.011, 0.075, Vector3(sx * 0.046, 0.016, 0.020),
			Vector3(PI / 2.0, 0, sx * 0.25), cloth)
		_sphere("Hand", 0.010, Vector3(sx * 0.052, 0.016, -0.018), porcelain)
		_capsule("Leg", 0.012, 0.080, Vector3(sx * 0.020, 0.014, -0.110),
			Vector3(PI / 2.0, 0, 0), cloth)


# Rough overall footprint (x, y, z) of a piece, for tests and for callers sizing a recess.
static func footprint(kind: String) -> Vector3:
	match kind:
		"candle": return Vector3(0.10, 0.18, 0.10)
		"book": return Vector3(0.21, 0.052, 0.15)
		"skull": return Vector3(0.14, 0.14, 0.16)
		"bell": return Vector3(0.15, 0.16, 0.15)
		"key": return Vector3(0.21, 0.012, 0.07)
		"doll": return Vector3(0.10, 0.07, 0.29)
	return Vector3(0.2, 0.2, 0.2)
