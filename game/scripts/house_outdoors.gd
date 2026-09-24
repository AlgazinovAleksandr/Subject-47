extends Node3D
class_name HouseOutdoors

# THE PORCH, THE YARD AND THE FOREST (2026-09-24, the Porch pass — the user's design, Granny-
# referenced: *"it will be the actual forest nearby, but you cannot walk for a long time because
# your panic will strike and you will die"*). Geometry, sky and moon only; every BEAT out here —
# the forest clock, the ghosts, the witch, the first-visit scrawl — is `level_2.gd`'s.
#
#   * THE PORCH — a deck at x -12..-8.6, z 3..9, LEVEL WITH THE HOUSE FLOOR (y = 0: no lip,
#     `move_and_slide` cannot step up — the cellar-ramp lesson). A roof on posts, board screens
#     closing its north and south ends, and a rail along its west edge with a GAP facing the yard.
#   * THE YARD — walkable x -40..-12, z -12..24 (28 x 36 m), a leaf-litter floor flush with the
#     deck. Trunks with colliders inside it; a dense ring of trunks just inside its edge and
#     invisible walls just outside that; a tall fence along x = -12 either side of the porch.
#   * THE SKY — an unshaded, inward-facing dome (`night_sky.png`), and the MOON: a low-energy,
#     shadow-casting `DirectionalLight3D` whose `light_cull_mask` is ONLY render layer 2.
#
# ⚠️⚠️ THE HOUSE MUST STAY BLACK (ambient 0.0 — the 2026-09-03/09-07 darkness passes). A
# directional light reaches every surface it faces unless something shadows it, and a 0.2 m
# ceiling slab is a thin thing to trust a shadow map with. So the moon is not trusted to be
# shadowed out: it is CULLED out. Everything built here is put on render layer 2 as well as 1
# (`moonlit()`), the moon lights layer 2 and nothing else, and no RoomBuilder surface is ever on
# layer 2 — so no interior surface can receive moonlight by construction, whatever the shadow
# map does. `level_2.gd:_drive_lights()` never sees the moon either: it is not in `_lights`.
#
# ⚠️ The yard's GROUND and every trunk are bodies + MeshInstances, not CSG. The deck and the roof
# are CSG, because they abut the house's own CSG and `check_wall_overlap.gd` must see those
# junctions. (It also keeps `check_shell_sealed.gd`'s derived bounds — every CSGBox3D — ending at
# the porch rail; the yard's shell is asserted by `check_house_porch.gd` instead.)

const TEX := "res://assets/textures/level_2_house/"

const MOON_LAYER := 2               # render-layer BIT VALUE the moon's cull mask selects
const RAIL_X := -12.0               # the deck's west edge — the forest clock's zero
const WALL_X := -8.6                # the living room's west wall, outer face
const DECK_Z := Vector2(3.0, 9.0)
const ROOF_Y := 2.75
const GAP_Z := Vector2(5.1, 6.9)    # the rail's opening onto the yard (between two posts)
const POST_X := -11.93
const POST_Z := [3.12, 5.1, 6.9, 8.88]
const YARD_X := Vector2(-40.0, -12.0)   # walkable
const YARD_Z := Vector2(-12.0, 24.0)
const GROUND_X := Vector2(-66.0, -12.0) # the visible floor runs on past the boundary
const GROUND_Z := Vector2(-36.0, 48.0)
const FENCE_H := 2.4                # over eye height (1.65): the space behind it is never seen
const BOUNDARY_H := 6.0

const MOON_ENERGY := 0.32
const MOON_COLOR := Color(0.62, 0.70, 0.92)
# Direction the light TRAVELS: from the west-south-west, 29 degrees up — where the moon is
# painted on the dome once it is yawed by SKY_YAW (measured off `night_sky.png`: u 0.36, v 0.34).
const MOON_DIR := Vector3(0.83, -0.48, 0.28)
const SKY_RADIUS := 100.0
const SKY_CENTRE := Vector3(-30.0, 0.0, 6.0)
const SKY_YAW_DEG := 122.0
const SKY_TINT := Color(0.8, 0.8, 0.85)

# Trunks never stand here. The witch's tree-line spots (Watcher needs 0.9 m of clear air all
# round), the ghosts' guaranteed first lane, and the arrival apron in front of the rail gap.
const CLEAR_SPOTS := [
	Vector2(-18.5, 6.0), Vector2(-20.5, 5.0), Vector2(-21.0, 7.5), Vector2(-17.0, 9.5),
	Vector2(-17.5, 12.5), Vector2(-16.5, 4.0), Vector2(-17.0, 1.0), Vector2(-18.0, 7.0),
]
const CLEAR_R := 1.7
const ARRIVAL := Rect2(-16.0, 1.5, 4.0, 9.0)      # x -16..-12, z 1.5..10.5
const TRUNK_GAP := 2.4
const TRUNK_MAX := 85
const TREE_SEED := 2409

var trunks: Array[Vector2] = []     # the walkable yard's trunks (with colliders), for tests


static func on_deck(p: Vector3) -> bool:
	return p.x > RAIL_X and p.x < WALL_X and p.z > DECK_Z.x and p.z < DECK_Z.y and p.y > -1.0


static func in_yard(p: Vector3) -> bool:
	return p.x <= RAIL_X and p.x >= YARD_X.x and p.z >= YARD_Z.x and p.z <= YARD_Z.y


# Metres past the porch rail, outward from the house. Zero on the deck and indoors.
static func forest_depth(p: Vector3) -> float:
	return maxf(0.0, RAIL_X - p.x)


static func moonlit(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers |= MOON_LAYER
	for c in n.get_children():
		moonlit(c)


func build() -> void:
	var planks := _mat(TEX + "house_wood_stairs.png", Vector3(0.5, 0.5, 0.5),
		Color(0.24, 0.18, 0.13), Color(0.5, 0.46, 0.42))
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.17, 0.12, 0.08)
	dark_wood.roughness = 0.9
	_build_deck(planks, dark_wood)
	_build_fence(planks, dark_wood)
	_build_ground()
	_build_boundary()
	_build_trees()
	_build_sky()
	moonlit(self)
	_build_moon()


# ------------------------------------------------------------------ the porch

func _build_deck(planks: Material, dark_wood: Material) -> void:
	# The deck: top face at y = 0, flush with the house floor and the doorway bridge (which is
	# sunk 4 mm under it — the two top faces are 4 mm apart, not coplanar).
	var deck := _csg("PorchDeck", Vector3((RAIL_X + WALL_X) / 2.0, -0.15, (DECK_Z.x + DECK_Z.y) / 2.0),
		Vector3(WALL_X - RAIL_X, 0.3, DECK_Z.y - DECK_Z.x), planks)
	deck.use_collision = true
	var body := StaticBody3D.new()
	body.name = "PorchRailBody"
	add_child(body)
	# The roof, on posts, overhanging the rail. Its east face ABUTS the wall's outer face.
	# ⚠️ A BoxMesh + collider, NOT CSG, and that is measured rather than taste:
	# `check_shell_sealed.gd` derives its sampling grid from every CSGBox3D's extent, and a CSG
	# roof reaching x = -12.35 moved the grid's phase so that no 1.5 m sample landed on the
	# 1.2 m standable band of the cellar ramp — the "y = -0.8" floor level measured 0 points
	# and the sweep went red for a level nobody had touched. The deck stays CSG (its junction
	# with the window's floor bridge is exactly what `check_wall_overlap.gd` must see).
	var roof_size := Vector3(WALL_X - (RAIL_X - 0.35), 0.15, (DECK_Z.y - DECK_Z.x) + 0.4)
	var roof_at := Vector3((RAIL_X - 0.35 + WALL_X) / 2.0, ROOF_Y + 0.075, (DECK_Z.x + DECK_Z.y) / 2.0)
	_mesh_box("PorchRoof", roof_size, roof_at, dark_wood)
	_shape(body, roof_size, roof_at)
	# Posts: the two corners and the two either side of the gap. They carry the roof.
	for z in POST_Z:
		_mesh_box("PorchPost", Vector3(0.12, ROOF_Y, 0.12), Vector3(POST_X, ROOF_Y / 2.0, z), dark_wood)
		_shape(body, Vector3(0.12, ROOF_Y, 0.12), Vector3(POST_X, ROOF_Y / 2.0, z))
	# The rail: two runs, with the gap between posts 5.1 and 6.9 facing the yard.
	for run in [[POST_Z[0] + 0.06, POST_Z[1] - 0.06], [POST_Z[2] + 0.06, POST_Z[3] - 0.06]]:
		var z0: float = run[0]
		var z1: float = run[1]
		var zc := (z0 + z1) / 2.0
		var ln := z1 - z0
		_mesh_box("RailTop", Vector3(0.08, 0.07, ln), Vector3(POST_X, 0.955, zc), dark_wood)
		_mesh_box("RailLow", Vector3(0.06, 0.06, ln), Vector3(POST_X, 0.13, zc), dark_wood)
		var n := int(ln / 0.14)
		for i in range(n):
			var bz := z0 + (float(i) + 0.5) * ln / float(n)
			_mesh_box("Baluster", Vector3(0.035, 0.76, 0.035), Vector3(POST_X, 0.54, bz), dark_wood)
		_shape(body, Vector3(0.12, 1.0, ln), Vector3(POST_X, 0.5, zc))
	# The two ends are closed by board screens, floor to roof — the porch looks out one way only.
	for zs in [[DECK_Z.x + 0.03, "PorchScreenS"], [DECK_Z.y - 0.03, "PorchScreenN"]]:
		var z: float = zs[0]
		var x0 := RAIL_X + 0.01
		var x1 := WALL_X - 0.005
		var boards := int((x1 - x0) / 0.132)
		for i in range(boards):
			var bx := x0 + (float(i) + 0.5) * (x1 - x0) / float(boards)
			_mesh_box(String(zs[1]), Vector3(0.12, ROOF_Y - 0.01, 0.05), Vector3(bx, ROOF_Y / 2.0, z), planks)
		_shape(body, Vector3(x1 - x0, ROOF_Y, 0.06), Vector3((x0 + x1) / 2.0, ROOF_Y / 2.0, z))
	# Weatherboards over the house wall behind the deck, so a torch on it finds siding rather than
	# the living room's wallpaper. 1.25 cm off the wall's outer face; split round the window.
	for span in [[DECK_Z.x + 0.06, 5.3], [6.7, DECK_Z.y - 0.06]]:
		var za: float = span[0]
		var zb: float = span[1]
		var y := 0.005
		while y < ROOF_Y - 0.1:
			_mesh_box("Weatherboard", Vector3(0.025, 0.19, zb - za),
				Vector3(WALL_X - 0.025, y + 0.095, (za + zb) / 2.0), planks)
			y += 0.2


func _build_fence(planks: Material, dark_wood: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "YardFence"
	add_child(body)
	for run in [[GROUND_Z.x, DECK_Z.x], [DECK_Z.y, GROUND_Z.y]]:
		var z0: float = run[0]
		var z1: float = run[1]
		var zc := (z0 + z1) / 2.0
		_mesh_box("FencePanel", Vector3(0.05, FENCE_H, z1 - z0), Vector3(RAIL_X - 0.04, FENCE_H / 2.0, zc), planks)
		# ⚠️ The COLLIDER runs 0.3 m past the panel into the deck's end zone, overlapping the
		# board screen's collider. With the two ending flush there was a 1 cm slot between the
		# fence (x <= -12.0) and the screen (x >= -11.99) that `check_shell_sealed.gd` threaded
		# three rays through from the yard at (-12.2, 7) — too thin to walk, open to the eye.
		var cz0 := z0 - (0.3 if z0 >= DECK_Z.y else 0.0)
		var cz1 := z1 + (0.3 if z1 <= DECK_Z.x else 0.0)
		_shape(body, Vector3(0.1, BOUNDARY_H, cz1 - cz0), Vector3(RAIL_X - 0.05, BOUNDARY_H / 2.0, (cz0 + cz1) / 2.0))
		var z := z0 + 1.2
		while z < z1 - 0.5:
			_mesh_box("FencePost", Vector3(0.1, FENCE_H + 0.1, 0.1), Vector3(RAIL_X - 0.12, (FENCE_H + 0.1) / 2.0, z), dark_wood)
			z += 2.5


# ------------------------------------------------------------------ the yard

func _build_ground() -> void:
	var floor_mat := _mat(TEX + "forest_floor.png", Vector3(0.25, 0.25, 0.25),
		Color(0.14, 0.12, 0.09), Color(1, 1, 1))
	(floor_mat as StandardMaterial3D).uv1_world_triplanar = true
	var size := Vector3(GROUND_X.y - GROUND_X.x, 0.3, GROUND_Z.y - GROUND_Z.x)
	var centre := Vector3((GROUND_X.x + GROUND_X.y) / 2.0, -0.15, (GROUND_Z.x + GROUND_Z.y) / 2.0)
	var mi := _mesh_box("YardGround", size, centre, floor_mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := StaticBody3D.new()
	body.name = "YardGroundBody"
	add_child(body)
	_shape(body, size, centre)


# Invisible walls just outside the trunk ring, on the three open sides. The fence is the fourth.
func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "YardBoundary"
	add_child(body)
	var zc := (YARD_Z.x + YARD_Z.y) / 2.0
	var xc := (YARD_X.x + YARD_X.y) / 2.0
	_shape(body, Vector3(0.4, BOUNDARY_H, YARD_Z.y - YARD_Z.x + 0.8), Vector3(YARD_X.x - 0.2, BOUNDARY_H / 2.0, zc))
	_shape(body, Vector3(YARD_X.y - YARD_X.x + 0.4, BOUNDARY_H, 0.4), Vector3(xc, BOUNDARY_H / 2.0, YARD_Z.x - 0.2))
	_shape(body, Vector3(YARD_X.y - YARD_X.x + 0.4, BOUNDARY_H, 0.4), Vector3(xc, BOUNDARY_H / 2.0, YARD_Z.y + 0.2))


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var bark := _mat(TEX + "forest_bark.png", Vector3(2.0, 5.0, 1.0),
		Color(0.16, 0.13, 0.10), Color(0.85, 0.82, 0.8))
	(bark as StandardMaterial3D).uv1_triplanar = false   # a cylinder's own UVs wrap the bark
	var pine_tex: Texture2D = load(TEX + "forest_pine.png") if ResourceLoader.exists(TEX + "forest_pine.png") else null
	var body := StaticBody3D.new()
	body.name = "YardTrunks"
	add_child(body)

	# 1. The walkable yard: trunks with colliders and a canopy each.
	var tries := 0
	while trunks.size() < TRUNK_MAX and tries < 1200:
		tries += 1
		var p := Vector2(rng.randf_range(YARD_X.x + 1.4, YARD_X.y - 0.8),
			rng.randf_range(YARD_Z.x + 1.4, YARD_Z.y - 1.4))
		if ARRIVAL.has_point(p):
			continue
		var ok := true
		for c in CLEAR_SPOTS:
			if p.distance_to(c) < CLEAR_R:
				ok = false
				break
		if ok:
			for t in trunks:
				if p.distance_to(t) < TRUNK_GAP:
					ok = false
					break
		if not ok:
			continue
		trunks.append(p)
		var r := rng.randf_range(0.16, 0.32)
		_trunk(p, r, bark)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(p.x, 1.5, p.y)
		body.add_child(cs)
		_pine(pine_tex, Vector3(p.x, 0, p.y), rng.randf_range(7.0, 11.0), rng.randf_range(2.4, 3.2))

	# 2. The ring: dense trunks just inside the invisible walls, so the edge reads as forest.
	var ring: Array[Vector2] = []
	var z := YARD_Z.x + 0.6
	while z <= YARD_Z.y - 0.6:
		ring.append(Vector2(YARD_X.x + 0.55 + rng.randf_range(-0.25, 0.25), z))
		z += rng.randf_range(1.0, 1.5)
	var x := YARD_X.x + 1.6
	while x <= YARD_X.y - 1.2:
		ring.append(Vector2(x, YARD_Z.x + 0.55 + rng.randf_range(-0.25, 0.25)))
		ring.append(Vector2(x + rng.randf_range(-0.4, 0.4), YARD_Z.y - 0.55 + rng.randf_range(-0.25, 0.25)))
		x += rng.randf_range(1.0, 1.5)
	for p in ring:
		var r := rng.randf_range(0.18, 0.34)
		_trunk(p, r, bark)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(p.x, 1.5, p.y)
		body.add_child(cs)
		if rng.randf() < 0.6:
			_pine(pine_tex, Vector3(p.x, 0, p.y), rng.randf_range(8.0, 12.0), rng.randf_range(1.8, 2.8))

	# 3. Beyond the boundary: whole silhouettes standing on the ground out to its edge.
	for i in range(110):
		var q := Vector2.ZERO
		var band := rng.randi() % 3
		if band == 0:
			q = Vector2(rng.randf_range(GROUND_X.x + 2.0, YARD_X.x - 1.5), rng.randf_range(GROUND_Z.x + 2.0, GROUND_Z.y - 2.0))
		elif band == 1:
			q = Vector2(rng.randf_range(YARD_X.x - 1.0, RAIL_X - 1.0), rng.randf_range(GROUND_Z.x + 2.0, YARD_Z.x - 1.5))
		else:
			q = Vector2(rng.randf_range(YARD_X.x - 1.0, RAIL_X - 1.0), rng.randf_range(YARD_Z.y + 1.5, GROUND_Z.y - 2.0))
		_pine(pine_tex, Vector3(q.x, 0, q.y), rng.randf_range(9.0, 16.0), 0.0)


func _trunk(p: Vector2, r: float, bark: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Trunk"
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.55
	cm.bottom_radius = r
	cm.height = 14.0
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.set_surface_override_material(0, bark)
	mi.position = Vector3(p.x, 7.0, p.y)
	add_child(mi)


# A pine silhouette on a fixed-Y billboard. Unshaded and dark on purpose: against the dome it is
# a SHAPE, and the moon does not light a painted tree (it would light the quad, not the tree).
func _pine(tex: Texture2D, foot: Vector3, height: float, lift: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Pine"
	var qm := QuadMesh.new()
	var aspect := 0.47
	if tex and tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	qm.size = Vector2(height * aspect, height)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex:
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.albedo_color = Color(0.55, 0.6, 0.6)
	else:
		m.albedo_color = Color(0.02, 0.03, 0.03)
	mi.set_surface_override_material(0, m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = foot + Vector3(0, lift + height / 2.0, 0)
	add_child(mi)


# ------------------------------------------------------------------ the sky and the moon

func _build_sky() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "SkyDome"
	var sm := SphereMesh.new()
	sm.radius = SKY_RADIUS
	sm.height = SKY_RADIUS * 2.0
	sm.radial_segments = 48
	sm.rings = 24
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT          # seen from inside
	if ResourceLoader.exists(TEX + "night_sky.png"):
		m.albedo_texture = load(TEX + "night_sky.png")
		m.albedo_color = SKY_TINT
	else:
		m.albedo_color = Color(0.02, 0.025, 0.04)
	mi.set_surface_override_material(0, m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = SKY_CENTRE
	mi.rotation.y = deg_to_rad(SKY_YAW_DEG)
	add_child(mi)


func _build_moon() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_energy = MOON_ENERGY
	moon.light_color = MOON_COLOR
	moon.light_cull_mask = MOON_LAYER
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	add_child(moon)
	moon.basis = Basis.looking_at(MOON_DIR.normalized(), Vector3.UP)


# ------------------------------------------------------------------ helpers

func _mat(tex_path: String, uv: Vector3, fallback: Color, tint: Color) -> StandardMaterial3D:
	var m := RoomBuilder.make_material(tex_path, uv, fallback)
	if m.albedo_texture:
		m.albedo_color = tint
	return m


func _csg(n: String, pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = n
	b.size = size
	b.position = pos
	b.use_collision = true
	b.material = mat
	add_child(b)
	return b


func _mesh_box(n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)
	return mi


func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	body.add_child(cs)
