class_name DungeonRooms
extends RefCounted

# ⭐ THE NIGHTMARE's ROOM ARCHETYPES (2026-09-12, the user's structure: "let's not have ladders —
# more variety in terms of rooms instead"). `dungeon_gen.gd:_deal_kinds()` deals every chamber one
# of eight KINDS; this file builds the props for a kind and owns the ONE scare each kind fires —
# when that room's sconce is lit, or when the player first steps in. The sconce COUNT keeps only
# two gates (`dungeon.gd`: the hunter wakes at 3, the finale at 7). Nothing here charges panic
# except through props that already had a price (the Child, gaze on a statue or the kneeler).
#
#   gallery      (sconce)  framed paintings; the one opposite the sconce drops off the wall
#   scriptorium  (both)    desk, lectern, shelves; writing bleeds onto the wall over 2.5 s
#   cells        (entry)   a barred niche with a leashed Still One that can never leave
#   well         (entry)   a stone well; the Child peeks over the rim
#   chapel       (sconce)  pews and an altar; the Kneeling Man appears kneeling at it
#   crypt        (sconce)  sarcophagi; a lid slides and the statue inside is awake
#   cistern      (entry)   ankle water that slows you; something wades away in the dark
#   larder       (sconce)  hooks and hanging shapes; THE HUNTER'S LAIR — it stands up behind you
#
# ⚠️ Every prop is built from PARTS under ONE StaticBody3D collider (Issue 35: one flat box reads
# as a box), flat-tinted and never emissive (§8.8: no glowing anomalies — at 0.045 ambient a
# self-lit prop is the brightest thing in the level). Wall props go on `free_sides()` (a doorway
# sits at the wall centre) at the 0.16 `wall_point()` inset (Issues 11/26). Floor props sit at the
# room centre, where a >= 6 m chamber leaves >= 2 m to every wall.
#
# ⚠️ `RefCounted` and `static`, like `CreatureAnim`: `dungeon.gd` is already 1500 lines and
# `dungeon_gen.gd` must stay pure data. The level passes itself in; the callbacks a scare needs
# (`gallery_drop`, `child_peek_at`, `spawn_kneeler_at`, `wake_statue_in`, `lair_beat`,
# `cistern_set`) live on the level, so this file never reaches into its privates.

const KIND_SCONCE := ["gallery", "chapel", "crypt", "larder", "scriptorium"]
const KIND_ENTRY := ["cells", "well", "cistern", "scriptorium"]

const SCRAWLS := [
	"THERE IS NO WAY OUT",
	"I FEEL I AM\nLOSING MY MIND",
	"WHO LIT\nTHE OTHERS",
	"DO NOT SLEEP HERE",
	"IT IS ALL LIT\nAND STILL DARK",
]

const WOOD := Color(0.14, 0.10, 0.07)
const STONE := Color(0.27, 0.26, 0.25)
const IRON := Color(0.10, 0.10, 0.11)
const CLOTH := Color(0.30, 0.27, 0.24)
const WAX := Color(0.86, 0.83, 0.72)
const BONE := Color(0.58, 0.54, 0.46)
const BLOOD := Color(0.62, 0.05, 0.05)

const CELL_DEPTH := 1.6       # how far the barred niche reaches into the room
const CELL_WIDTH := 2.4       # the niche's opening, spanned by the bars
const CELL_BAR_GAP := 0.28    # centre to centre; a 0.8 m capsule cannot pass a 0.22 m slot
const SCRAWL_FADE := 2.5
const SIDE_CLEAR := 1.25      # a walkable lane past every back-wall prop, each side


# ── helpers ────────────────────────────────────────────────────────────────────
static func _mat(c: Color, rough: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		nm: String = "") -> MeshInstance3D:
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


static func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3,
		mat: Material, nm: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if nm != "":
		mi.name = nm
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)
	return mi


# One body, one collider, layer 1 (blocks the walk, answers the gaze ray for nothing).
static func _prop(level: Node3D, nm: String, pos: Vector3, yaw: float,
		col_size: Vector3, col_offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	level.add_child(body)
	if col_size != Vector3.ZERO:
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = col_size
		col.shape = sh
		col.position = col_offset
		body.add_child(col)
	return body


static func _yaw_for(side: Vector2) -> float:
	return atan2(-side.x, -side.y)


# A doorway-free side that the sconce is NOT on, else any free side, else (0,1).
static func _back_side(gen, room: String, rng: RandomNumberGenerator) -> Vector2:
	var taken: Variant = null
	for sp in gen.sconce_spots:
		if sp["room"] == room:
			taken = sp["side"]
	# prop_sides: doorway-free AND no side-wall doorway whose line runs along the props.
	var sides: Array = gen.prop_sides(room)
	if sides.is_empty():
		sides = gen.free_sides(room)
	var choices: Array = []
	for sd in sides:
		if taken == null or sd != taken:
			choices.append(sd)
	if choices.is_empty():
		choices = sides
	if choices.is_empty():
		return Vector2(0, 1)
	return choices[rng.randi() % choices.size()]


static func _play_at(level: Node3D, base: String, pos: Vector3, db: float, unit: float = 8.0) -> void:
	var s := GameState.load_audio(base)
	if s == null:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = s
	pl.unit_size = unit
	pl.max_db = 6.0
	pl.volume_db = db
	pl.position = pos
	level.add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)


# ── build ──────────────────────────────────────────────────────────────────────
# Returns the handles the scare needs later: {kind, room, statue_pos?, leash?, ...}.
static func build(kind: String, level: Node3D, builder: RoomBuilder, gen, room: String,
		rng: RandomNumberGenerator) -> Dictionary:
	var h := {"kind": kind, "room": room}
	var c: Vector3 = gen.room_center_world(room)
	var back: Vector2 = _back_side(gen, room, rng)
	if not ["cistern", "gallery", "crypt"].has(kind) and gen.prop_sides(room).is_empty():
		# The generator deals four-door chambers to "cistern" for exactly this reason; anything
		# else here will stand a prop in a doorway (seed 606, Lectern_Chamber12).
		push_warning("DungeonRooms: %s is a '%s' with no doorway-free wall" % [room, kind])
	h["back"] = back
	h["centre"] = c
	var inward := Vector3(-back.x, 0, -back.y)
	var along := Vector3(-back.y, 0, back.x)   # runs along the back wall
	# ⚠️ FLOOR PROPS HUG THE DOORWAY-FREE WALL AND STAY CLEAR OF THE ROOM CENTRE (2026-09-12).
	# Two measurements: the walkers aim door to door and a well dead-centre stalled 21 legs; and
	# `_finish_transition()` puts the player ON the spawn room's centre, so a prop within ~0.5 m
	# of any centre is a spawn inside furniture (check_reachable's fill read 0 cells). The
	# smallest chamber is 6 m, centre 3 m from the wall: no prop may extend past 2.4 m from it.
	var wall_pt: Vector3 = builder.wall_point(room, back, 0.0, 0.1)
	# ⚠️ AND CLEAR OF THE SIDE WALLS. A doorway in a side wall can sit right at the back corner,
	# and the eye-height doorway ray does not see a 0.8 m sarcophagus standing across it — the
	# geometry walker did (21 legs stalled on seed 101). Nothing along the back wall may come
	# within SIDE_CLEAR of either side wall; `side_limit` is how far from the centre line a
	# prop's outer edge may reach.
	var rect: Rect2i = gen.room_rect(room)
	var w_along: float = (rect.size.x if absf(back.y) > 0.5 else rect.size.y) * DungeonGen.CELL
	var side_limit: float = w_along * 0.5 - SIDE_CLEAR
	match kind:
		"gallery":
			_build_gallery(level, builder, room, wall_pt + inward * 1.6, back, h,
				not gen.prop_sides(room).is_empty())
		"scriptorium":
			_build_scriptorium(level, builder, gen, room, wall_pt + inward * 1.5, back, inward, along, rng, h, side_limit)
		"cells":
			_build_cells(level, builder, room, c, back, inward, along, h)
		"well":
			_build_well(level, room, wall_pt + inward * 1.3, h)
		"chapel":
			_build_chapel(level, builder, room, c, back, inward, along, h, side_limit)
		"crypt":
			_build_crypt(level, room, wall_pt + inward * 1.25, along, inward, h, room == gen.bed_room, side_limit,
				not gen.prop_sides(room).is_empty())
		"cistern":
			_build_cistern(level, gen, room, c, h)
		"larder":
			_build_larder(level, room, wall_pt + inward * 1.6, inward, along, h, side_limit)
	return h


# A lateral offset for a prop of half-width `half`, clamped so its outer edge stays inside the
# side limit. Sign is kept.
static func _lateral(want: float, half: float, side_limit: float) -> float:
	var lim: float = maxf(0.0, side_limit - half)
	return clampf(want, -lim, lim)


static func _build_gallery(level: Node3D, builder: RoomBuilder, room: String, c: Vector3,
		back: Vector2, h: Dictionary, with_bench: bool = true) -> void:
	# The paintings themselves are WeepingFrames the level spawns from gen.frame_spots; the room
	# gets a viewing bench — unless no wall is prop-safe (a doorway's line would cross it).
	if not with_bench:
		return
	var bench := _prop(level, "Bench_" + room, c, _yaw_for(back), Vector3(1.8, 0.5, 0.5),
		Vector3(0, 0.25, 0))
	var wood := _mat(WOOD)
	_box(bench, Vector3(1.8, 0.06, 0.42), Vector3(0, 0.46, 0), wood)
	for x in [-0.75, 0.75]:
		_box(bench, Vector3(0.08, 0.44, 0.38), Vector3(x, 0.22, 0), wood)
	h["bench"] = bench


static func _build_scriptorium(level: Node3D, builder: RoomBuilder, gen, room: String,
		c: Vector3, back: Vector2, inward: Vector3, along: Vector3,
		rng: RandomNumberGenerator, h: Dictionary, side_limit: float = 9.0) -> void:
	var wood := _mat(WOOD)
	var paper := _mat(Color(0.42, 0.39, 0.32), 0.95)   # dark: near-white is the brightest paint here
	# Desk: top on four legs, an inkpot, a stack of pages.
	var desk_pos: Vector3 = c
	var desk := _prop(level, "Desk_" + room, desk_pos, _yaw_for(back), Vector3(1.4, 0.8, 0.8),
		Vector3(0, 0.4, 0))
	_box(desk, Vector3(1.4, 0.05, 0.8), Vector3(0, 0.76, 0), wood)
	for x in [-0.62, 0.62]:
		for z in [-0.32, 0.32]:
			_box(desk, Vector3(0.07, 0.74, 0.07), Vector3(x, 0.37, z), wood)
	_box(desk, Vector3(0.3, 0.012, 0.42), Vector3(-0.3, 0.79, 0.05), paper)
	_cyl(desk, 0.04, 0.05, 0.08, Vector3(0.45, 0.83, -0.2), _mat(IRON, 0.5))
	# Stool.
	var stool := _prop(level, "Stool_" + room, desk_pos + inward * -0.8, _yaw_for(back),
		Vector3(0.4, 0.5, 0.4), Vector3(0, 0.25, 0))
	_box(stool, Vector3(0.4, 0.05, 0.4), Vector3(0, 0.47, 0), wood)
	for x in [-0.15, 0.15]:
		for z in [-0.15, 0.15]:
			_box(stool, Vector3(0.05, 0.45, 0.05), Vector3(x, 0.22, z), wood)
	# Lectern against the back wall, off-centre so the scrawl has the wall centre.
	var lect_pos: Vector3 = builder.wall_point(room, back, 0.0, 0.55) + along * _lateral(1.6, 0.3, side_limit)
	var lect := _prop(level, "Lectern_" + room, lect_pos, _yaw_for(back), Vector3(0.6, 1.2, 0.5),
		Vector3(0, 0.6, 0))
	_box(lect, Vector3(0.14, 1.05, 0.14), Vector3(0, 0.52, 0), wood)
	var top := _box(lect, Vector3(0.6, 0.04, 0.5), Vector3(0, 1.12, 0.05), wood)
	top.rotation.x = deg_to_rad(-22)
	_box(lect, Vector3(0.5, 0.012, 0.38), Vector3(0, 1.16, 0.06), paper).rotation.x = deg_to_rad(-22)
	# Shelves on the back wall, the other side of the centre.
	var shelf_pos: Vector3 = builder.wall_point(room, back, 0.0, 0.22) + along * _lateral(-1.6, 0.7, side_limit)
	var shelf := _prop(level, "Shelf_" + room, shelf_pos, _yaw_for(back), Vector3(1.4, 2.0, 0.34),
		Vector3(0, 1.0, 0))
	for y in [0.5, 1.0, 1.5, 1.95]:
		_box(shelf, Vector3(1.4, 0.04, 0.32), Vector3(0, y, 0), wood)
	for x in [-0.68, 0.68]:
		_box(shelf, Vector3(0.05, 2.0, 0.32), Vector3(x, 1.0, 0), wood)
	for i in range(7):
		var bx: float = -0.55 + i * 0.18
		_box(shelf, Vector3(0.12, 0.3, 0.22), Vector3(bx, 0.68 + (0.5 if i % 2 == 0 else 0.0), 0.02),
			_mat(Color(0.2 + 0.05 * (i % 3), 0.12, 0.09), 0.9))
	# The writing, hidden until the scare: a shaded Label3D on the wall centre.
	var lbl := Label3D.new()
	lbl.name = "Scrawl_" + room
	lbl.text = SCRAWLS[rng.randi() % SCRAWLS.size()]
	lbl.font_size = 72
	lbl.pixel_size = 0.0032
	lbl.modulate = Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.0)
	lbl.outline_size = 0
	lbl.shaded = true
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.position = builder.wall_point(room, back, 1.75, 0.16)
	lbl.rotation.y = _yaw_for(back)
	level.add_child(lbl)
	h["scrawl"] = lbl


static func _build_cells(level: Node3D, builder: RoomBuilder, room: String, c: Vector3,
		back: Vector2, inward: Vector3, along: Vector3, h: Dictionary) -> void:
	var stone := _mat(STONE)
	var iron := _mat(IRON, 0.6)
	var wall_pt: Vector3 = builder.wall_point(room, back, 0.0, 0.1)   # ON the wall face
	var bars_pt: Vector3 = wall_pt + inward * CELL_DEPTH
	# Two stone piers close the ends of the niche; the bars span between them.
	for sgn in [-1.0, 1.0]:
		var pier_pos: Vector3 = wall_pt + inward * (CELL_DEPTH * 0.5) + along * (sgn * (CELL_WIDTH * 0.5 + 0.3))
		var pier := _prop(level, "Pier_%s_%d" % [room, int(sgn)], pier_pos, _yaw_for(back),
			Vector3(0.6, 3.0, CELL_DEPTH), Vector3(0, 1.5, 0))
		_box(pier, Vector3(0.6, 3.0, CELL_DEPTH), Vector3(0, 1.5, 0), stone)
	# The bars: individual thin colliders so the gaze ray still finds the thing behind them.
	var n: int = int(floor(CELL_WIDTH / CELL_BAR_GAP)) + 1
	var bars := _prop(level, "Bars_" + room, bars_pt, _yaw_for(back), Vector3.ZERO, Vector3.ZERO)
	for i in range(n):
		var x: float = -CELL_WIDTH * 0.5 + i * CELL_BAR_GAP
		_cyl(bars, 0.035, 0.035, 3.0, Vector3(x, 1.5, 0), iron)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.07, 3.0, 0.07)
		col.shape = sh
		col.position = Vector3(x, 1.5, 0)
		bars.add_child(col)
	for y in [0.4, 1.5, 2.6]:
		_box(bars, Vector3(CELL_WIDTH + 0.2, 0.08, 0.06), Vector3(0, y, 0), iron)
	# A pallet and a chain in the niche.
	var pallet := _box(bars, Vector3(1.2, 0.12, 0.7), Vector3(0.5, 0.06, -CELL_DEPTH * 0.55), _mat(WOOD))
	pallet.rotation.y = 0.0
	# The statue stands in the niche, leashed to it. World-space XZ rect, wall-aligned.
	var statue_pos: Vector3 = wall_pt + inward * (CELL_DEPTH * 0.55)
	var a: Vector3 = wall_pt + inward * 0.45 - along * (CELL_WIDTH * 0.5 - 0.35)
	var b: Vector3 = wall_pt + inward * (CELL_DEPTH - 0.45) + along * (CELL_WIDTH * 0.5 - 0.35)
	var leash := Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2.ZERO)
	leash.end = Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
	h["statue_pos"] = statue_pos
	h["leash"] = leash
	h["bars_pos"] = bars_pt
	h["bars"] = bars


static func _build_well(level: Node3D, room: String, c: Vector3, h: Dictionary) -> void:
	var stone := _mat(STONE)
	var well := _prop(level, "Well_" + room, c, 0.0, Vector3(1.7, 0.8, 1.7), Vector3(0, 0.4, 0))
	var segs := 10
	for i in range(segs):
		var ang: float = TAU * float(i) / float(segs)
		var seg := _box(well, Vector3(0.55, 0.75, 0.28), Vector3(sin(ang) * 0.72, 0.375, cos(ang) * 0.72), stone)
		seg.rotation.y = ang
	# Two posts and a crossbar with a rope and bucket.
	for x in [-0.55, 0.55]:
		_box(well, Vector3(0.1, 1.9, 0.1), Vector3(x, 0.95, 0), _mat(WOOD))
	_box(well, Vector3(1.3, 0.08, 0.1), Vector3(0, 1.85, 0), _mat(WOOD))
	_cyl(well, 0.012, 0.012, 0.9, Vector3(0, 1.4, 0), _mat(Color(0.3, 0.25, 0.18)))
	_cyl(well, 0.14, 0.11, 0.24, Vector3(0, 0.95, 0), _mat(IRON, 0.6))
	h["rim_pos"] = c + Vector3(0, 0.0, -0.9)
	h["well"] = well


static func _build_chapel(level: Node3D, builder: RoomBuilder, room: String, c: Vector3,
		back: Vector2, inward: Vector3, along: Vector3, h: Dictionary, side_limit: float = 9.0) -> void:
	var stone := _mat(STONE)
	var wood := _mat(WOOD)
	var altar_pos: Vector3 = builder.wall_point(room, back, 0.0, 1.1)
	var altar := _prop(level, "Altar_" + room, altar_pos, _yaw_for(back), Vector3(1.7, 1.0, 0.8),
		Vector3(0, 0.5, 0))
	_box(altar, Vector3(1.5, 0.9, 0.7), Vector3(0, 0.45, 0), stone)
	_box(altar, Vector3(1.7, 0.08, 0.8), Vector3(0, 0.94, 0), stone)
	_box(altar, Vector3(1.4, 0.02, 0.6), Vector3(0, 0.99, 0), _mat(CLOTH))
	for x in [-0.55, 0.55]:
		_cyl(altar, 0.03, 0.035, 0.28, Vector3(x, 1.13, 0), _mat(WAX))
	# A cross on the wall above.
	var cross_pos: Vector3 = builder.wall_point(room, back, 2.1, 0.14)
	var cross := _prop(level, "Cross_" + room, cross_pos, _yaw_for(back), Vector3.ZERO, Vector3.ZERO)
	_box(cross, Vector3(0.12, 1.3, 0.06), Vector3(0, 0, 0), wood)
	_box(cross, Vector3(0.8, 0.12, 0.06), Vector3(0, 0.3, 0), wood)
	# One pew facing the altar, off the centre line — the room's crossing lines stay clear.
	var pew_pos: Vector3 = altar_pos + inward * 1.4 + along * _lateral(1.9, 1.0, side_limit)
	var pew := _prop(level, "Pew_" + room, pew_pos, _yaw_for(back), Vector3(2.0, 1.0, 0.6),
		Vector3(0, 0.5, 0))
	_box(pew, Vector3(2.0, 0.06, 0.45), Vector3(0, 0.46, 0.05), wood)
	_box(pew, Vector3(2.0, 0.5, 0.06), Vector3(0, 0.72, 0.26), wood)
	for x in [-0.9, 0.9]:
		_box(pew, Vector3(0.08, 0.44, 0.45), Vector3(x, 0.22, 0.05), wood)
	h["kneel_pos"] = altar_pos + inward * 1.0 - along * 0.6
	h["altar"] = altar


static func _build_crypt(level: Node3D, room: String, c: Vector3, along: Vector3, inward: Vector3,
		h: Dictionary, is_bed_room: bool, side_limit: float = 9.0, prop_safe: bool = true) -> void:
	var stone := _mat(STONE)
	# As many sarcophagi (1.5 m apart, 0.48 half-width) as fit inside the side limit, 1..3.
	# ⚠️ None at all when no wall is prop-safe — only the BED chamber is ever a crypt in that
	# state (a side doorway's line would run along the row; Issue 194's second half).
	var fit: int = int(floor((side_limit - 0.48) / 0.75)) + 1
	var count: int = clampi(fit, 1, 2 if is_bed_room else 3) if prop_safe else 0
	var lids: Array = []
	var first_pos := Vector3.ZERO
	for i in range(count):
		var off: float = (float(i) - float(count - 1) * 0.5) * 1.5
		var pos: Vector3 = c + along * off
		var sarc := _prop(level, "Sarcophagus_%s_%d" % [room, i], pos, atan2(inward.x, inward.z),
			Vector3(0.95, 0.8, 2.05), Vector3(0, 0.4, 0))
		_box(sarc, Vector3(0.9, 0.7, 2.0), Vector3(0, 0.35, 0), stone)
		var lid := _box(sarc, Vector3(0.96, 0.12, 2.06), Vector3(0, 0.76, 0), _mat(Color(0.22, 0.21, 0.2)),
			"Lid")
		lids.append(lid)
		if i == 0:
			first_pos = pos
	h["lids"] = lids
	h["statue_pos"] = first_pos
	h["lid_slide"] = along


static func _build_cistern(level: Node3D, gen, room: String, c: Vector3, h: Dictionary) -> void:
	var r: Rect2i = gen.room_rect(room)
	var w: float = r.size.x * DungeonGen.CELL - 0.3
	var d: float = r.size.y * DungeonGen.CELL - 0.3
	# The water: a dark, faintly reflective sheet just above the flags. No collider.
	var water := MeshInstance3D.new()
	water.name = "Water_" + room
	var qm := QuadMesh.new()
	qm.size = Vector2(w, d)
	water.mesh = qm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.02, 0.03, 0.05, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08
	wm.metallic = 0.0
	wm.metallic_specular = 0.7
	water.set_surface_override_material(0, wm)
	water.position = c + Vector3(0, 0.12, 0)
	water.rotation.x = -PI / 2.0
	level.add_child(water)
	# A drain grate in the middle of the floor (the old teaching-alcove art, which is exactly a grate).
	var grate := MeshInstance3D.new()
	grate.name = "Drain_" + room
	var gq := QuadMesh.new()
	gq.size = Vector2(1.1, 1.1)
	grate.mesh = gq
	var gm := StandardMaterial3D.new()
	var gp := "res://assets/textures/level_9_dungeon/dungeon_grate.png"
	if ResourceLoader.exists(gp):
		gm.albedo_texture = load(gp)
	else:
		gm.albedo_color = IRON
	gm.roughness = 0.9
	grate.set_surface_override_material(0, gm)
	grate.position = c + Vector3(0, 0.03, 0)
	grate.rotation.x = -PI / 2.0
	level.add_child(grate)
	# The wading zone: the level re-applies `apply_slow` every frame the player is inside.
	var area := Area3D.new()
	area.name = "Cistern_" + room
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, 2.0, d)
	col.shape = sh
	area.add_child(col)
	area.position = c + Vector3(0, 1.0, 0)
	area.collision_layer = 0
	area.collision_mask = 1
	level.add_child(area)
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			level.call("cistern_set", room, true))
	area.body_exited.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			level.call("cistern_set", room, false))
	h["water"] = water
	h["area"] = area


static func _build_larder(level: Node3D, room: String, c: Vector3, inward: Vector3,
		along: Vector3, h: Dictionary, side_limit: float = 9.0) -> void:
	var iron := _mat(IRON, 0.6)
	var cloth := _mat(CLOTH)
	var wood := _mat(WOOD)
	var yaw: float = atan2(along.x, along.z) + PI / 2.0
	# Hooks hang from a beam under the ceiling along the back wall; two sheeted shapes hang.
	var rig := _prop(level, "Hooks_" + room, c, yaw, Vector3.ZERO, Vector3.ZERO)
	_box(rig, Vector3(3.2, 0.14, 0.14), Vector3(0, 2.95, 0), wood)
	for i in range(4):
		var x: float = -1.2 + i * 0.8
		_box(rig, Vector3(0.03, 0.55, 0.03), Vector3(x, 2.6, 0), iron)
		_box(rig, Vector3(0.12, 0.03, 0.03), Vector3(x + 0.05, 2.33, 0), iron)
	for i in [0, 2]:
		var x: float = _lateral(-1.2 + i * 0.8, 0.25, side_limit)
		var shape := _prop(level, "Hung_%s_%d" % [room, i], c + along * x, yaw,
			Vector3(0.5, 1.5, 0.4), Vector3(0, 1.55, 0))
		_box(shape, Vector3(0.48, 1.45, 0.38), Vector3(0, 1.55, 0), cloth)
		_box(shape, Vector3(0.3, 0.25, 0.28), Vector3(0.02, 0.72, 0.02), cloth)
	# The block, a little further into the room than the hooks, off to one side.
	var block := _prop(level, "Block_" + room, c + inward * 0.5 + along * _lateral(1.8, 0.6, side_limit), yaw,
		Vector3(1.2, 0.9, 0.7), Vector3(0, 0.45, 0))
	_box(block, Vector3(1.2, 0.2, 0.7), Vector3(0, 0.8, 0), wood)
	for x in [-0.5, 0.5]:
		for z in [-0.25, 0.25]:
			_box(block, Vector3(0.1, 0.7, 0.1), Vector3(x, 0.35, z), wood)
	_box(block, Vector3(0.28, 0.02, 0.12), Vector3(0.25, 0.91, 0.1), iron)   # the cleaver blade
	_box(block, Vector3(0.14, 0.03, 0.03), Vector3(0.45, 0.92, 0.1), wood)
	h["spawn_pos"] = c + along * -1.2
	h["block"] = block


# ── fire ───────────────────────────────────────────────────────────────────────
# The kind's one scare. One-shot enforcement, pause/note/freeze gating and the retry timer are
# the level's (`_fire_room_scare`); this only performs.
static func fire(kind: String, h: Dictionary, level: Node3D, player: CharacterBody3D) -> void:
	var room: String = h.get("room", "")
	match kind:
		"gallery":
			level.call("gallery_drop", room)
		"scriptorium":
			var lbl: Label3D = h.get("scrawl", null)
			if lbl:
				var tw := level.create_tween()
				tw.tween_property(lbl, "modulate:a", 1.0, SCRAWL_FADE)
				_play_at(level, "whisper_dungeon", lbl.global_position, -6.0, 6.0)
		"cells":
			var bp: Vector3 = h.get("bars_pos", player.global_position)
			_play_at(level, "door_batter", bp, -2.0, 7.0)
		"well":
			level.call("child_peek_at", h.get("rim_pos", player.global_position))
		"chapel":
			level.call("spawn_kneeler_at", h.get("kneel_pos", player.global_position))
		"crypt":
			var lids: Array = h.get("lids", [])
			if not lids.is_empty():
				var lid: MeshInstance3D = lids[0]
				_play_at(level, "bone_scrape", lid.global_position, 2.0, 9.0)
				var tw := level.create_tween()
				tw.set_parallel(true)
				tw.tween_property(lid, "position", lid.position + Vector3(0.95, -0.66, 0.15), 0.9) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_property(lid, "rotation:z", deg_to_rad(-70.0), 0.9) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			level.call("wake_statue_in", room)
		"cistern":
			# Something wades away from you, out of the light and into the dark.
			var s := GameState.load_audio("wade_distant")
			if s:
				var pl := AudioStreamPlayer3D.new()
				pl.stream = s
				pl.unit_size = 9.0
				pl.max_db = 3.0
				pl.volume_db = -4.0
				var fwd: Vector3 = -player.global_transform.basis.z
				fwd.y = 0.0
				var start: Vector3 = player.global_position + fwd.normalized() * 5.0
				pl.position = start
				level.add_child(pl)
				pl.play()
				var tw := level.create_tween()
				tw.tween_property(pl, "position", start + fwd.normalized() * 9.0, 6.0)
				tw.tween_callback(pl.queue_free)
		"larder":
			level.call("lair_beat", room, h.get("spawn_pos", player.global_position))
