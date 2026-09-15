extends Node3D

# ═══════════════════════════════════════════════════════════════════════════════════════
# THE VOID — level 8 (the scene is still `level_3.tscn`; its name has never matched its index).
#
# ⭐ REBUILT 2026-09-12 (the user: *"the level itself is too small, not packed with actions at
# all, so we need to restructure it completely"* — and *"I like the textures, I like the music, I
# like the vibe"*). What it was: a 15 x 15 m ring of four identical 6 x 6 rooms, ~77 m² standable,
# one room sealed off by a stray wall (a safe note, a trap note and a creature unreachable), eight
# gaps at the corridor junctions open to the sky, no loops, no floating tiles, no floor text — none
# of what `SCARY.md` §6 promised for "broken geometry" — and a camera shake every 20-60 s as the
# only scripted event.
#
# What it is now: a RoomBuilder complex (the Lab / House / KONTUR pattern, so every geometry guard
# enrols it for free) of ~14 rooms over ~40 x 45 m in the SAME skin, music and vignette, with three
# impossible spaces the doc promised and never got:
#   1. THE LOOP — a 30 m corridor that seamlessly returns you to its start until you have read the
#      note inside it. Each lap the creature at its far end is two metres closer and one more torn
#      page lies on the floor.
#   2. THE TILE HALL — the floor is gone; a causeway of floating tiles crosses the abyss, and the
#      creature waiting on the far side WATCHES but cannot step while you are on it.
#   3. THE FRAGMENTS — rooms rebuilt from earlier levels in void skin (the intro ward's gurneys,
#      the Lab morgue, the House child's room), a stalker standing where the prop stood.
# Six stalkers with the scrape tell (a fairness upgrade the dungeon already had), notes on a real
# route, the twist note in the last room. The Void KEEPS its deaths (the user's call): a stalker's
# touch, the abyss, a trap note read to the end, and the panic bar.
#
# ⚠️ The escalating-unreality pillar: this is the last unreal level before the loop ending. Nothing
# here may become coherent; the fragments are wrong on purpose (a ward with no walls, a morgue at
# the bottom of a black corridor).
# ═══════════════════════════════════════════════════════════════════════════════════════

const _NOTE_SCRIPT := preload("res://scripts/note.gd")
const _DOOR_SCRIPT := preload("res://scripts/door.gd")
const _STALKER_SCRIPT := preload("res://scripts/creature_stalker.gd")
const _FRAGMENTS := preload("res://scripts/void_fragments.gd")

const PRESERVE := ["Environment", "AmbientPlayer", "HUDCanvas", "Player"]
const TEX := "res://assets/textures/level_4_void/"

# ⚠️ AUTHORED ON AN INTEGER GRID so abutment is exact by construction (the Breach's rule): every
# room is an axis-aligned rectangle, connected rooms share an EXACT wall plane, and every doorway
# sits on it. `# x a..b  z a..b` on each row so the two invariants can be eyeballed.
const ROOMS := [
	{"name": "Threshold",    "pos": Vector2(0, 0),        "size": Vector2(8, 8)},    # x -4..4      z -4..4
	{"name": "Hall1",        "pos": Vector2(0, 7),        "size": Vector2(3, 6)},    # x -1.5..1.5  z 4..10
	{"name": "PocketA",      "pos": Vector2(-3.5, 7),     "size": Vector2(4, 3)},    # x -5.5..-1.5 z 5.5..8.5  (dead end)
	{"name": "Ward",         "pos": Vector2(0, 14),       "size": Vector2(10, 8)},   # x -5..5      z 10..18
	{"name": "Archive",      "pos": Vector2(-2, 22),      "size": Vector2(6, 8)},    # x -5..1      z 18..26    (dead end)
	{"name": "LoopIn",       "pos": Vector2(8, 15.5),     "size": Vector2(6, 3)},    # x 5..11      z 14..17
	{"name": "LoopStraight", "pos": Vector2(12.5, 29),    "size": Vector2(3, 30)},   # x 11..14     z 14..44
	{"name": "LoopOut",      "pos": Vector2(13, 46),      "size": Vector2(4, 4)},    # x 11..15     z 44..48
	{"name": "Hall2",        "pos": Vector2(7, 46),       "size": Vector2(8, 4)},    # x 3..11      z 44..48
	{"name": "TileHall",     "pos": Vector2(-3, 45.5),    "size": Vector2(12, 10)},  # x -9..3      z 40.5..50.5
	# ⚠️ x -17..-9, ABUTTING the tile hall's west wall at x = -9. The first draft put it at -18..-10,
	# a metre short: the doorway cut the hall's wall and left the morgue's own wall whole, and the
	# whole far wing measured unreachable. check_doorways now has the table and would say so.
	{"name": "Morgue",       "pos": Vector2(-13, 45.5),   "size": Vector2(8, 6)},    # x -17..-9    z 42.5..48.5
	{"name": "Hall3",        "pos": Vector2(-14, 39.5),   "size": Vector2(3, 6)},    # x -15.5..-12.5 z 36.5..42.5
	{"name": "PocketB",      "pos": Vector2(-18.5, 39.5), "size": Vector2(6, 4)},    # x -21.5..-15.5 z 37.5..41.5 (dead end)
	{"name": "ChildRoom",    "pos": Vector2(-14, 33),     "size": Vector2(6, 7)},    # x -17..-11   z 29.5..36.5
	{"name": "Sanctum",      "pos": Vector2(-14, 24.5),   "size": Vector2(8, 10)},   # x -18..-10   z 19.5..29.5
]

const DOORS := [
	{"pos": Vector2(0, 4),        "width": 1.8, "dir": "z"},   # Threshold <-> Hall1
	{"pos": Vector2(-1.5, 7),     "width": 1.6, "dir": "x"},   # Hall1 <-> PocketA
	{"pos": Vector2(0, 10),       "width": 1.8, "dir": "z"},   # Hall1 <-> Ward
	{"pos": Vector2(-2, 18),      "width": 1.8, "dir": "z"},   # Ward <-> Archive
	{"pos": Vector2(5, 15.5),     "width": 1.8, "dir": "x"},   # Ward <-> LoopIn
	{"pos": Vector2(11, 15.5),    "width": 1.8, "dir": "x"},   # LoopIn <-> LoopStraight
	{"pos": Vector2(12.5, 44),    "width": 1.8, "dir": "z"},   # LoopStraight <-> LoopOut
	# ⚠️ 46.7, not the wall centre: LoopOut's two doorways are 1.5 m from a shared corner and their
	# floor bridges (1.3 m each side) overlapped coplanar (Issue 43's shape). Moving this one
	# north takes the two bridges out of each other's footprint.
	{"pos": Vector2(11, 46.7),    "width": 1.8, "dir": "x"},   # LoopOut <-> Hall2
	{"pos": Vector2(3, 45.5),     "width": 1.8, "dir": "x"},   # Hall2 <-> TileHall
	{"pos": Vector2(-9, 45.5),    "width": 1.8, "dir": "x"},   # TileHall <-> Morgue
	{"pos": Vector2(-14, 42.5),   "width": 1.8, "dir": "z"},   # Morgue <-> Hall3
	{"pos": Vector2(-15.5, 39.5), "width": 1.6, "dir": "x"},   # Hall3 <-> PocketB
	{"pos": Vector2(-14, 36.5),   "width": 1.8, "dir": "z"},   # Hall3 <-> ChildRoom
	{"pos": Vector2(-14, 29.5),   "width": 1.8, "dir": "z"},   # ChildRoom <-> Sanctum
]

const ROOM_H := 3.3
const SHAKE_MIN := 20.0
const SHAKE_MAX := 60.0

# ── the loop ──
const LOOP_PERIOD := 15.0       # the corridor repeats every 15 m; the seam sends you back exactly one period
const LOOP_TRIGGER_Z := 32.0    # 60 % of the 30 m run
const LOOP_NOTE_Z := 23.0
const LOOP_CREEP := 2.0         # how much closer the far-end stalker is after each lap
const LOOP_STALKER_Z := 41.0

# ── the tile hall ──
const TILE := 1.6
const TILE_T := 0.3
const BEAM_W := 1.0
const ABYSS_Y := -8.0
const FALL_Y := -4.0

var _builder: RoomBuilder
var _stalkers: Dictionary = {}       # "A".."F" -> CreatureStalker
var _notes_read: Array = []
var _loop_broken := false
var _loop_laps := 0
var _loop_stalker_z: float = LOOP_STALKER_Z
var _tile_rect := Rect2()
var _shake_timer := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _world_env: WorldEnvironment = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.current_level = 8
	_clear_old_scene()
	_black_background()
	_build_geometry()
	_build_tile_hall()
	_build_loop()
	_build_fragments()
	_spawn_lights()
	_spawn_notes()
	_spawn_stalkers()
	_spawn_zones()
	_spawn_level_doors()
	_place_player()
	_start_ambience()
	_reset_shake_timer()
	Vignette.spawn(self, Color(0.65, 0.55, 1.0, 1.0), 2.0)
	RandomAmbient.register_player(_player())
	GameState.set_objective("Find the truth — read the note that doesn't belong")
	_restore_progress()


func _player() -> CharacterBody3D:
	return get_node_or_null("Player") as CharacterBody3D


func _clear_old_scene() -> void:
	for child in get_children():
		if PRESERVE.has(child.name):
			continue
		# ⚠️ remove_child BEFORE queue_free (Issue 17): the dying node still owns its NAME.
		remove_child(child)
		child.queue_free()


# ── geometry ────────────────────────────────────────────────────────────────────
func _build_geometry() -> void:
	_builder = RoomBuilder.new()
	_builder.name = "Rooms"
	_builder.wall_height = ROOM_H
	# The user's textures, kept: black stone with violet cracks on every wall AND the ceilings
	# (which were untextured before), the void floor underfoot. Triplanar, so nothing stretches.
	_builder.wall_mat = RoomBuilder.make_material(TEX + "wall_void.png", Vector3(0.28, 0.28, 0.28), Color(0.06, 0.05, 0.08))
	_builder.floor_mat = RoomBuilder.make_material(TEX + "floor_void.png", Vector3(0.3, 0.3, 0.3), Color(0.05, 0.05, 0.07))
	_builder.ceil_mat = RoomBuilder.make_material(TEX + "wall_void.png", Vector3(0.28, 0.28, 0.28), Color(0.05, 0.04, 0.07))
	add_child(_builder)
	_builder.build(ROOMS, DOORS)


# ⭐ THE TILE HALL. RoomBuilder builds the room normally; its floor slab is then FREED (the
# `_break_room_c_floor()` precedent, and the builder names floors `<room>_Floor`) and a causeway
# of tiles joined by beams crosses the abyss from door to door, forking round a central island.
# ⚠️ The player cannot jump, so the route is EDGE-CONNECTED; the abyss lies beside it. A black
# slab at ABYSS_Y stops rays (no sky, no shell exemption) while `_check_void_fall()` fires at
# FALL_Y first. The doorway floor bridges (`DoorFloor`) stay as landing pads.
func _build_tile_hall() -> void:
	var fl := _builder.get_node_or_null("TileHall_Floor")
	if fl:
		fl.free()
	var r := _room_rect("TileHall")
	_tile_rect = r
	# The causeway, in world XZ: east pad -> spine -> fork -> west pad.
	var spine := [Vector2(1.4, 45.5), Vector2(-0.2, 45.5)]
	var north := [Vector2(-1.8, 47.0), Vector2(-3.6, 48.2), Vector2(-5.6, 47.4), Vector2(-7.0, 46.5)]
	var south := [Vector2(-1.8, 44.0), Vector2(-3.6, 42.8), Vector2(-5.6, 43.6), Vector2(-7.0, 44.5)]
	var island := [Vector2(-3.8, 45.4)]
	var tiles: Array = spine + north + south + island
	var i := 0
	for t in tiles:
		_tile(t, "Tile_%d" % i)
		i += 1
	# Beams between consecutive tiles on each branch (the pads at x 1.7 and -7.7 are the bridges).
	var chains := [
		[Vector2(1.7, 45.5)] + spine + [north[0]], north, [north[3], Vector2(-7.7, 45.5)],
		[spine[1], south[0]], south, [south[3], Vector2(-7.7, 45.5)],
	]
	var j := 0
	for chain in chains:
		for k in range(chain.size() - 1):
			_beam(chain[k], chain[k + 1], "Beam_%d" % j)
			j += 1
	# The abyss: a black PIT under the hall — floor far below and four black walls from the room's
	# floor level down to it, INSIDE the room's footprint, so every ray from anywhere in the pit is
	# stopped and check_shell_sealed's sweep (which treats that floor as a storey) sees a sealed box.
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0, 0, 0)
	am.roughness = 1.0
	var cx: float = r.position.x + r.size.x * 0.5
	var cz: float = r.position.y + r.size.y * 0.5
	var w: float = r.size.x - 0.2
	var d: float = r.size.y - 0.2
	var depth: float = -ABYSS_Y
	var pit := [
		["Abyss_TileHall", Vector3(w, 0.3, d), Vector3(cx, ABYSS_Y, cz)],
		["AbyssWall_W", Vector3(0.2, depth, d), Vector3(cx - w * 0.5 - 0.1, ABYSS_Y * 0.5, cz)],
		["AbyssWall_E", Vector3(0.2, depth, d), Vector3(cx + w * 0.5 + 0.1, ABYSS_Y * 0.5, cz)],
		["AbyssWall_S", Vector3(w + 0.4, depth, 0.2), Vector3(cx, ABYSS_Y * 0.5, cz - d * 0.5 - 0.1)],
		["AbyssWall_N", Vector3(w + 0.4, depth, 0.2), Vector3(cx, ABYSS_Y * 0.5, cz + d * 0.5 + 0.1)],
	]
	for spec in pit:
		var b := CSGBox3D.new()
		b.name = spec[0]
		b.size = spec[1]
		b.position = spec[2]
		b.use_collision = true
		b.material = am
		add_child(b)


func _tile(at: Vector2, nm: String) -> void:
	var t := CSGBox3D.new()
	t.name = nm
	t.size = Vector3(TILE, TILE_T, TILE)
	t.position = Vector3(at.x, -TILE_T * 0.5, at.y)
	t.use_collision = true
	t.material = _builder.floor_mat
	add_child(t)


# ⚠️ A beam spans only the GAP plus 0.4 m into each tile, and its top sits BEAM_SINK under the
# tiles': two beams meeting at a tile no longer overlap each other, and a beam never shares its
# top plane with a tile (28 z-fights on the first build). 6 mm is far under a step.
const BEAM_SINK := 0.006


func _beam(a: Vector2, b: Vector2, nm: String) -> void:
	var d := b - a
	var beam := CSGBox3D.new()
	beam.name = nm
	beam.size = Vector3(maxf(0.6, d.length() - 0.8), TILE_T, BEAM_W)
	var mid := (a + b) * 0.5
	beam.position = Vector3(mid.x, -TILE_T * 0.5 - BEAM_SINK, mid.y)
	beam.rotation.y = -atan2(d.y, d.x)
	beam.use_collision = true
	beam.material = _builder.floor_mat
	add_child(beam)


# ⭐ THE LOOP. `LoopStraight` runs 30 m north (z 14..44). A seam at LOOP_TRIGGER_Z sends the
# player back exactly one LOOP_PERIOD, PRESERVING heading and velocity (unlike backrooms.gd's
# `_teleport()`, which zeroes it — seamlessness needs the stride to continue), while the note at
# LOOP_NOTE_Z is unread. The dressing repeats every LOOP_PERIOD so the view after the seam matches
# the view before it. The stalker at the far end is LOOP_CREEP closer after every lap.
func _build_loop() -> void:
	var seam := Area3D.new()
	seam.name = "LoopSeam"
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.0, ROOM_H, 0.8)
	col.shape = sh
	seam.add_child(col)
	seam.position = Vector3(12.5, ROOM_H * 0.5, LOOP_TRIGGER_Z)
	seam.collision_layer = 0
	seam.collision_mask = 1
	add_child(seam)
	seam.body_entered.connect(_on_loop_seam)
	# The dressing: a stain and a pipe stub on the east wall every 5 m, identical per period.
	var stain := StandardMaterial3D.new()
	stain.albedo_color = Color(0.03, 0.02, 0.05)
	stain.roughness = 1.0
	var pipe := StandardMaterial3D.new()
	pipe.albedo_color = Color(0.18, 0.16, 0.22)
	pipe.roughness = 0.6
	pipe.metallic = 0.3
	for z in [17.0, 22.0, 27.0, 32.0, 37.0, 42.0]:
		var mi := MeshInstance3D.new()
		mi.name = "LoopStain_%d" % int(z)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.9, 1.3)
		mi.mesh = qm
		mi.set_surface_override_material(0, stain)
		mi.position = Vector3(14.0 - 0.1 - 0.03, 1.5, z)
		mi.rotation.y = -PI / 2.0
		add_child(mi)
		var p := MeshInstance3D.new()
		p.name = "LoopPipe_%d" % int(z)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 1.2
		p.mesh = cm
		p.set_surface_override_material(0, pipe)
		p.position = Vector3(11.0 + 0.1 + 0.08, 2.6, z + 2.5)
		p.rotation.z = PI / 2.0
		p.rotation.y = PI / 2.0
		add_child(p)


func _on_loop_seam(body: Node) -> void:
	var p := _player()
	if body != p or _loop_broken or p == null:
		return
	if p.velocity.z <= 0.0:
		return   # walking back out of the loop is allowed
	p.global_position.z -= LOOP_PERIOD
	_loop_laps += 1
	# The far-end stalker creeps closer: it is the corridor's clock.
	var c = _stalkers.get("C", null)
	if c and is_instance_valid(c) and not bool(c.call("has_fallen")):
		_loop_stalker_z = maxf(LOOP_NOTE_Z + 4.0, _loop_stalker_z - LOOP_CREEP)
		var body3: Node3D = c.get("_body")
		if body3:
			body3.global_position = Vector3(12.5, 0.0, _loop_stalker_z)
	_drop_torn_page(_loop_laps)
	if _loop_laps == 2:
		ScreenText.scrawl(get_tree(), "AGAIN.", 3.0)


func _drop_torn_page(n: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "TornPage_%d" % n
	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.24)
	mi.mesh = qm
	mi.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(false))
	mi.position = Vector3(12.5 + (0.6 if n % 2 == 0 else -0.6), 0.012, LOOP_NOTE_Z - 1.2 - 0.5 * n)
	mi.rotation.x = -PI / 2.0
	mi.rotation.z = 0.4 * n
	add_child(mi)


func _on_loop_note_read() -> void:
	_loop_broken = true
	_mark_note("LoopNote")


# ⭐ THE FRAGMENTS (void_fragments.gd): the ward, the morgue, the child's room.
func _build_fragments() -> void:
	# The Ward: two gurneys where the intro's stood, in a room with no ward round them.
	_FRAGMENTS.gurney(self, Vector3(-2.6, 0, 14.5), 0.0, "Gurney_Ward_L")
	_FRAGMENTS.gurney(self, Vector3(2.6, 0, 14.5), 0.0, "Gurney_Ward_R")
	# The Morgue: the exam table, the dead monitor on the far wall.
	_FRAGMENTS.exam_table(self, Vector3(-13, 0, 45.5), PI / 2.0, "ExamTable_Morgue")
	var mon: Vector3 = _builder.wall_point("Morgue", Vector2(0, 1), 0.0, 0.5)
	_FRAGMENTS.monitor(self, mon, PI, "Monitor_Morgue")
	# The child's room: the small bed, the drawing on the wall, the music box on its stool.
	_FRAGMENTS.child_bed(self, Vector3(-15.2, 0, 34.0), PI / 2.0, "Bed_ChildRoom")
	var draw: Vector3 = _builder.wall_point("ChildRoom", Vector2(1, 0), 1.5, 0.16)
	_FRAGMENTS.crayon_drawing(self, draw, -PI / 2.0, "Drawing_ChildRoom")
	_FRAGMENTS.music_box(self, Vector3(-12.2, 0, 31.5), 0.0, "MusicBox_ChildRoom")


# ── lights: one cold point per room, the same palette the old ring used ─────────
func _spawn_lights() -> void:
	var palette := {
		"Threshold": [Color(0.6, 0.7, 1.0), 0.40, 6.0],
		"Hall1": [Color(0.6, 0.65, 1.0), 0.25, 5.0],
		"PocketA": [Color(0.7, 0.6, 1.0), 0.2, 4.0],
		"Ward": [Color(0.8, 0.6, 1.0), 0.35, 7.0],
		"Archive": [Color(0.7, 0.6, 1.0), 0.28, 5.0],
		"LoopIn": [Color(0.6, 0.65, 1.0), 0.25, 5.0],
		"LoopOut": [Color(0.6, 0.65, 1.0), 0.25, 5.0],
		"Hall2": [Color(0.6, 0.65, 1.0), 0.22, 5.0],
		"TileHall": [Color(1.0, 0.6, 0.6), 0.18, 7.0],
		"Morgue": [Color(0.6, 1.0, 0.7), 0.3, 6.0],
		"Hall3": [Color(0.6, 0.65, 1.0), 0.2, 5.0],
		"PocketB": [Color(0.7, 0.6, 1.0), 0.2, 4.0],
		"ChildRoom": [Color(1.0, 0.6, 0.6), 0.25, 5.0],
		"Sanctum": [Color(0.75, 0.55, 1.0), 0.35, 7.0],
	}
	for nm in palette:
		var spec: Array = palette[nm]
		var l := OmniLight3D.new()
		l.name = "Light_" + nm
		l.light_color = spec[0]
		l.light_energy = spec[1]
		l.omni_range = spec[2]
		l.position = _builder.room_center(nm) + Vector3(0, 2.8, 0)
		add_child(l)
	# The loop corridor: three identical lamps, one per period, so the seam is invisible.
	for z in [19.0, 34.0]:
		var l := OmniLight3D.new()
		l.name = "Light_Loop_%d" % int(z)
		l.light_color = Color(0.6, 0.65, 1.0)
		l.light_energy = 0.22
		l.omni_range = 6.0
		l.position = Vector3(12.5, 2.8, z)
		add_child(l)
	# Two candles by the spawn: the level's only warm light and its recovery anchor.
	for x in [-1.5, 1.5]:
		_spawn_candle(Vector3(x, 0.0, -1.5))


func _spawn_candle(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "CandleLight_%d" % int(pos.x * 10)
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.position = pos + Vector3(0, 0.8, 0)
	add_child(light)
	var candle := MeshInstance3D.new()
	candle.name = "Candle_%d" % int(pos.x * 10)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.025
	mesh.height = 0.15
	candle.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.4)
	# ⚠️ 0.9, not the 1.5 the old scene shipped: above 1.0 emission clamps to a flat white blob
	# (Issue 21, filed as V-T3 in backlogs/08-void.md).
	mat.emission_energy_multiplier = 0.9
	candle.set_surface_override_material(0, mat)
	candle.position = pos + Vector3(0, 0.075, 0)
	add_child(candle)


# ── notes: 5 safe (one the loop breaker), 3 trap, the twist ─────────────────────
func _spawn_notes() -> void:
	var n: StaticBody3D
	n = _make_note("NoteThreshold", _builder.wall_point("Threshold", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"You have been here before.\n\nNot this room. This is not a room. But you have stood at a door like the one behind you and told yourself the next one would be the last.\n\nCount the doors. The number will not stay the same.", false)
	n = _make_note("NoteWard", _builder.wall_point("Ward", Vector2(0, 1), 1.3, 0.16), PI,
		"Trial 1. The ward. Subject 47 woke, read, and walked.\n\nWe kept the beds. We could not keep the walls.", false)
	var lp: Vector3 = _builder.wall_point("LoopStraight", Vector2(-1, 0), 1.3, 0.16)
	lp.z = LOOP_NOTE_Z
	n = _make_note("LoopNote", lp, PI / 2.0,
		"This corridor is thirty metres long.\n\nYou have walked more than that. You will walk more than that again.\n\nIt is not the corridor that turns back. Read this, and it stops.", false)
	n.read.connect(_on_loop_note_read)
	# ⚠️ WEST wall. The first draft hung this on the south wall's centre, which is exactly where
	# the Morgue -> Hall3 doorway sits (the Records-sign lesson): its collider sealed the whole
	# far wing — five interactables unreachable, measured by check_reachable.
	n = _make_note("NoteMorgue", _builder.wall_point("Morgue", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"Trial 1, room 4. The keycard was on the cart between the tray and the screen.\n\nThe screen is still on. Do not look at it for long.", false)
	n = _make_note("NoteArchive", _builder.wall_point("Archive", Vector2(0, 1), 1.3, 0.16), PI,
		"The handwriting on the wall is yours.\n\nWe compared it. Every trial, the same hand, the same sentence: THERE IS NO WAY OUT.\n\nYou were never told the sentence.", false)
	# Traps: read to the end and the void takes you.
	n = _make_note("TrapPocketA", _builder.wall_point("PocketA", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me help me", true)
	n = _make_note("TrapChildRoom", _builder.wall_point("ChildRoom", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47 47", true)
	n = _make_note("TrapPocketB", _builder.wall_point("PocketB", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit. The exit is not an exit.", true)
	# The twist.
	n = _make_note("TwistNote", _builder.wall_point("Sanctum", Vector2(-1, 0), 1.3, 0.16), PI / 2.0,
		"There is no end condition.\n\nThe door at the end of this room opens onto the first room. It always has. Subject 47 has completed the trial eleven times and remembers none of them, which is the result.\n\nWe are not watching. There is nobody at the glass. We stopped watching after the fourth.\n\nGo through the door. We will see you at the beginning.", false)
	n.is_twist_note = true


func _make_note(nm: String, pos: Vector3, y_rot: float, text: String, trap: bool) -> StaticBody3D:
	var note := StaticBody3D.new()
	note.name = nm
	note.set_script(_NOTE_SCRIPT)
	note.note_text = text
	note.is_trap = trap
	note.position = pos
	note.rotation.y = y_rot
	add_child(note)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.42, 0.01)
	mesh.mesh = bm
	mesh.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(trap))
	note.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.5, 0.12)
	col.shape = shape
	note.add_child(col)
	if not trap:
		note.read.connect(_mark_note.bind(nm))
	return note


func _mark_note(nm: String) -> void:
	if not _notes_read.has(nm):
		_notes_read.append(nm)


# ── the six stalkers ────────────────────────────────────────────────────────────
# A: dead ahead of the spawn (the teaching beat, unchanged). B: beside the ward gurney. C: at the
# far end of the loop, closer every lap. D: on the far landing pad of the tile hall, watch-only
# while you are on the tiles. E: in the child's bed. F: guarding the twist note.
func _spawn_stalkers() -> void:
	_spawn_stalker("A", Vector3(0, 0, 1.0), PI)
	_spawn_stalker("B", Vector3(3.6, 0, 16.2), 0.0)
	_spawn_stalker("C", Vector3(12.5, 0, LOOP_STALKER_Z), PI)
	# ⚠️ Inside the Morgue, off the doorway's line (its capsule on the landing pad sealed the
	# TileHall -> Morgue doorway for check_doorways). Seen through the door from the causeway.
	_spawn_stalker("D", Vector3(-11.2, 0, 47.0), PI / 2.0)
	_spawn_stalker("E", Vector3(-15.2, 0, 34.0), PI / 2.0)
	_spawn_stalker("F", Vector3(-16.0, 0, 24.5), -PI / 2.0)


func _spawn_stalker(id: String, pos: Vector3, yaw: float) -> void:
	var s = _STALKER_SCRIPT.new()
	s.name = "Creature" + id
	s.position = pos
	s.rotation.y = yaw
	# ⭐ The scrape tell, back-ported from THE NIGHTMARE as its own header proposed: a dry drag
	# whenever one is advancing, so a player who cannot see it can still hear it.
	s.scrape_tell = true
	add_child(s)
	_stalkers[id] = s


# ── zones ───────────────────────────────────────────────────────────────────────
func _spawn_zones() -> void:
	# The spawn's calm anchor: ONE box covering both candles and the spawn (the old two left a
	# 0.5 m gap exactly where the player stood).
	_add_zone(CalmZone.new(), "CalmThreshold", Vector3(0, 1.0, -1.5), Vector3(6.0, 3.0, 4.0))
	# Dread over the far wing: decay and pressure cancel, the walk to the note is an endurance.
	_add_zone(DreadZone.new(), "DreadFarWing", Vector3(-15.75, 1.65, 31.0), Vector3(11.5, 3.3, 23.0))
	# Dark rooms: the torch is the only light and having it off costs.
	_add_zone(DarkZone.new(), "DarkTileHall", Vector3(-3, 1.5, 45.5), Vector3(12, 3, 10))
	_add_zone(DarkZone.new(), "DarkMorgue", Vector3(-13, 1.5, 45.5), Vector3(8, 3, 6))
	_add_zone(DarkZone.new(), "DarkChildRoom", Vector3(-14, 1.5, 33), Vector3(6, 3, 7))


func _add_zone(zone: Area3D, nm: String, pos: Vector3, size: Vector3) -> void:
	zone.name = nm
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)
	zone.position = pos
	add_child(zone)


# ── doors ───────────────────────────────────────────────────────────────────────
func _spawn_level_doors() -> void:
	var back := _make_door("BackDoor", false, true)
	back.position = Vector3(0, 1.1, -4.0 + 0.1 + 0.075)
	back.rotation.y = 0.0
	var exit := _make_door("ExitDoor", true, false)
	exit.unlock_condition = _DOOR_SCRIPT.UnlockCondition.TWIST_READ
	exit.position = Vector3(-14, 1.1, 19.5 + 0.1 + 0.075)
	exit.rotation.y = 0.0


func _make_door(door_name: String, advances: bool, back: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = door_name
	body.set_script(_DOOR_SCRIPT)
	body.advances_level = advances
	body.goes_back = back
	_DOOR_SCRIPT.build_visual(body, Vector3(1.0, 2.2, 0.15), "")
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 2.2, 0.15)
	col.shape = sh
	body.add_child(col)
	add_child(body)
	return body


# ── player ──────────────────────────────────────────────────────────────────────
func _place_player() -> void:
	var p := _player()
	if p == null:
		return
	if GameState.entered_from_ahead:
		# Came back through the ending's door: stand by the exit in the Sanctum, facing in.
		p.global_position = Vector3(-14, 0.1, 21.5)
		p.rotation = Vector3(0, PI, 0)
	else:
		p.global_position = Vector3(0, 0.1, -2.0)
		p.rotation = Vector3(0, PI, 0)   # face +z, at CreatureA


func _start_ambience() -> void:
	var ambient: AudioStreamPlayer = get_node_or_null("AmbientPlayer")
	if ambient:
		var s := GameState.load_audio("ambient_void")
		if s:
			ambient.stream = s
		if ambient.stream:
			ambient.play()


# ── per frame ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_tick_shake(delta)
	_check_void_fall()
	_tick_tile_watch()


# Fall off the broken geometry and the void claims you.
func _check_void_fall() -> void:
	var p := _player()
	if p and p.global_position.y < FALL_Y:
		Screamer.trigger()


# CreatureD watches from the far pad while you are on the tiles and never steps; the moment you
# are off them it stalks like the others.
func _tick_tile_watch() -> void:
	var p := _player()
	var d = _stalkers.get("D", null)
	if p == null or d == null or not is_instance_valid(d):
		return
	var inside: bool = _tile_rect.has_point(Vector2(p.global_position.x, p.global_position.z))
	if bool(d.get("watch_only")) != inside:
		d.set("watch_only", inside)


func _tick_shake(delta: float) -> void:
	if _shake_duration > 0.0:
		_shake_duration -= delta
		var p := _player()
		if p:
			var cam: Camera3D = p.get_node_or_null("Camera3D")
			if cam:
				cam.rotation.z = sin(Time.get_ticks_msec() * 0.05) * _shake_strength * (_shake_duration / 0.4)
		return
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		_reset_shake_timer()
		_shake_duration = 0.4
		_shake_strength = 0.008


func _reset_shake_timer() -> void:
	_shake_timer = randf_range(SHAKE_MIN, SHAKE_MAX)


# ── progress ────────────────────────────────────────────────────────────────────
func save_progress() -> Dictionary:
	return {"notes_read": _notes_read.duplicate(), "loop_broken": _loop_broken, "loop_laps": _loop_laps}


func _restore_progress() -> void:
	var data := GameState.get_level_progress(8)
	if data.is_empty():
		return
	_notes_read = (data.get("notes_read", []) as Array).duplicate()
	_loop_broken = bool(data.get("loop_broken", false))
	_loop_laps = int(data.get("loop_laps", 0))


# ── helpers ─────────────────────────────────────────────────────────────────────
func _room_rect(nm: String) -> Rect2:
	for r in ROOMS:
		if r["name"] == nm:
			var pos: Vector2 = r["pos"]
			var size: Vector2 = r["size"]
			return Rect2(pos - size * 0.5, size)
	return Rect2()


# ⭐ THE VOID WAS RENDERING A DAYLIT PROCEDURAL SKY (2026-09-03). `environment.tscn` is `BG_SKY`
# over a `ProceduralSkyMaterial`; every hole in a shell shows blue. The shell is CLOSED now (the
# rebuild replaced the eight junction gaps), but the abyss under the tile hall is a hole on
# purpose and must show BLACK. ⚠️ DUPLICATE FIRST: the resource is shared by every level.
func _black_background() -> void:
	var env_root := get_node_or_null("Environment")
	if env_root and env_root.get_child_count() > 0:
		_world_env = env_root.get_child(0) as WorldEnvironment
	if _world_env == null or _world_env.environment == null:
		return
	var env: Environment = _world_env.environment.duplicate()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world_env.environment = env


# ── test surface ────────────────────────────────────────────────────────────────
func get_stalkers() -> Dictionary:
	return _stalkers


func loop_laps() -> int:
	return _loop_laps


func loop_broken() -> bool:
	return _loop_broken


func tile_rect() -> Rect2:
	return _tile_rect
