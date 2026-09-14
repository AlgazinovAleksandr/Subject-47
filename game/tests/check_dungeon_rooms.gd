extends SceneTree

# THE NIGHTMARE's room archetypes (dungeon_rooms.gd, 2026-09-12), on two seeds.
#
#   Godot --headless --path game --script res://tests/check_dungeon_rooms.gd
#
# What it asserts per seed: every chamber got handles; every archetype prop body sits INSIDE its
# own room's footprint; no doorway is blocked at eye height (a prop in a jamb seals a room, the
# Records-sign lesson); exactly one Larder; the Larder beat puts the hunter 2-4.5 m from the
# player WITH line of sight and holds it there before it charges; a room's scare fires once and
# only once; the scriptorium's writing actually appears; the cistern's wading flag toggles.

const SEEDS := [101, 202]

var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _seed_i := 0
var _stage := 0
var _t := 0.0
var _scrawl: Label3D = null
var _scr_room := ""


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _load(s: int) -> void:
	_settle = 0
	_level = null
	_stage = 0
	var gs := root.get_node_or_null("GameState")
	if gs:
		gs.call("save_level_progress", 7, {"layout_seed": s, "content_seed": s * 31 + 7})
	change_scene_to_file("res://scenes/dungeon.tscn")


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_load(SEEDS[0])
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_gen"):
			print("  FAIL dungeon.tscn did not load")
			_fails += 1
			return _report()
		_audit_static(SEEDS[_seed_i])
		_stage = 1
		_t = 0.0
		return false
	_t += delta
	match _stage:
		1:
			_lair(SEEDS[_seed_i])
			_scriptorium_begin(SEEDS[_seed_i])
			_stage = 2
			_t = 0.0
		2:
			if _t >= 3.0:
				if _scrawl:
					_ok("seed %d: the scriptorium's writing appeared (alpha %.2f)" % [SEEDS[_seed_i], _scrawl.modulate.a],
						_scrawl.modulate.a > 0.6)
				_seed_i += 1
				if _seed_i < SEEDS.size():
					_load(SEEDS[_seed_i])
					return false
				return _report()
	return false


func _audit_static(s: int) -> void:
	var gen = _level.call("get_gen")
	var handles: Dictionary = _level.call("room_handles")
	var chambers: Array = gen.chamber_names
	_ok("seed %d: every chamber has archetype handles" % s, handles.size() == chambers.size(),
		"%d / %d" % [handles.size(), chambers.size()])

	# Every prop body inside its room. Props are named <Part>_<room> or <Part>_<room>_<i>.
	var outside := 0
	var props := 0
	for n in _level.get_children():
		if not (n is StaticBody3D) or n.get_script() != null:
			continue
		var nm: String = String(n.name)
		var room := ""
		for c in chambers:
			if nm.ends_with("_" + c) or nm.contains("_" + c + "_"):
				room = c
				break
		if room == "":
			continue
		props += 1
		var r: Rect2i = gen.room_rect(room)
		var x0: float = (r.position.x - DungeonGen.GRID * 0.5) * DungeonGen.CELL
		var x1: float = x0 + r.size.x * DungeonGen.CELL
		var z0: float = (r.position.y - DungeonGen.GRID * 0.5) * DungeonGen.CELL
		var z1: float = z0 + r.size.y * DungeonGen.CELL
		var col := n.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var half := Vector3.ZERO
		if col and col.shape is BoxShape3D:
			half = (col.shape as BoxShape3D).size * 0.5
		var gp: Vector3 = (n as Node3D).global_position
		var ext: float = maxf(half.x, half.z)
		if gp.x - ext < x0 - 0.05 or gp.x + ext > x1 + 0.05 or gp.z - ext < z0 - 0.05 or gp.z + ext > z1 + 0.05:
			outside += 1
			print("    outside: %s at %s (room %s)" % [nm, str(gp), room])
	_ok("seed %d: %d archetype props, all inside their rooms" % [s, props], props >= 8 and outside == 0,
		"%d outside" % outside)

	# No doorway blocked at eye height (mask 1) by a PROP. Entities are excluded: a statue that
	# has crept to a doorway is the level working, not a prop in a jamb (walk_dungeon.gd removes
	# them for the same reason).
	var space := _level.get_viewport().world_3d.direct_space_state
	var excl: Array[RID] = []
	for n in _level.get_children():
		var nm: String = String(n.name)
		if nm.begins_with("StillOne_") or nm == "TheHunter" or nm == "TheKneelingMan" or nm == "TheChild":
			for b in n.find_children("*", "StaticBody3D", true, false):
				excl.append((b as StaticBody3D).get_rid())
	var blocked := 0
	for d in gen.doorways:
		var p: Vector2 = d["pos"]
		var nrm: Vector3 = Vector3(1, 0, 0) if d["dir"] == "x" else Vector3(0, 0, 1)
		# ⚠️ Two heights. At the eye a ray flies over a sarcophagus; the knee ray is the one that
		# catches a prop standing across a doorway's approach.
		var hit := {}
		for hy in [1.6, 0.5]:
			var mid := Vector3(p.x, hy, p.y)
			var q := PhysicsRayQueryParameters3D.create(mid - nrm * 1.7, mid + nrm * 1.7)
			q.collision_mask = 1
			q.exclude = excl
			hit = space.intersect_ray(q)
			if not hit.is_empty():
				break
		if not hit.is_empty():
			blocked += 1
			var col_n: Node = hit["collider"]
			var chain := str(col_n.name)
			var up: Node = col_n.get_parent()
			while up != null and up != _level:
				chain = str(up.name) + "/" + chain
				up = up.get_parent()
			print("    doorway at %s blocked by %s at %s" % [str(p), chain, str(hit["position"])])
	_ok("seed %d: no doorway is blocked by a prop" % s, blocked == 0, "%d of %d" % [blocked, gen.doorways.size()])

	var larders := 0
	for c in chambers:
		if gen.kind_of(c) == "larder":
			larders += 1
	_ok("seed %d: exactly one larder" % s, larders == 1 and gen.lair_room != "")

	# One-shot: a scare fires once.
	var well := ""
	for c in chambers:
		if gen.kind_of(c) == "cistern":
			well = c
			break
	if well != "":
		_level.set("_in_dungeon", true)
		_level.call("_fire_room_scare", well)
		_level.call("_fire_room_scare", well)
		var fired: Array = _level.call("scares_fired")
		_ok("seed %d: a room's scare fires exactly once" % s, fired.count(well) == 1)
		_level.call("cistern_set", well, true)
		_ok("seed %d: the cistern sets the wading flag" % s, bool(_level.get("_in_cistern")))
		_level.call("cistern_set", well, false)


func _lair(s: int) -> void:
	var gen = _level.call("get_gen")
	var p := _level.get_node("Player") as CharacterBody3D
	var handles: Dictionary = _level.call("room_handles")
	var h: Dictionary = handles.get(gen.lair_room, {})
	var c: Vector3 = gen.room_center_world(gen.lair_room)
	_level.set("_in_dungeon", true)
	p.global_position = c + Vector3(0, 0.1, 1.0)
	p.force_update_transform()
	_level.call("lair_beat", gen.lair_room, h.get("spawn_pos", c))
	var hunter = _level.call("get_hunter")
	var d: float = (hunter.call("get_creature_position") as Vector3).distance_to(p.global_position)
	_ok("seed %d: the lair beat puts the hunter 2-4.5 m from the player" % s, d >= 2.0 and d <= 4.5, "%.2f m" % d)
	_ok("seed %d: ...with line of sight" % s, bool(hunter.call("has_line_of_sight")))
	_ok("seed %d: ...already chasing" % s, int(hunter.call("get_state")) == 2)
	_ok("seed %d: ...and held for the rise before it comes" % s, float(hunter.get("_block_t")) > 1.0,
		"block %.2f s" % float(hunter.get("_block_t")))
	_ok("seed %d: the wave is on" % s, bool(_level.call("hunter_present")))
	_level.call("_despawn_matron")
	if bool(p.call("is_input_frozen")):
		p.call("unfreeze_input")


func _scriptorium_begin(s: int) -> void:
	var gen = _level.call("get_gen")
	_scrawl = null
	_scr_room = gen.spawn_room   # always a scriptorium
	_ok("seed %d: the spawn chamber is a scriptorium" % s, gen.kind_of(_scr_room) == "scriptorium")
	_scrawl = _level.get_node_or_null("Scrawl_" + _scr_room) as Label3D
	_ok("seed %d: its writing exists and is invisible before the scare" % s,
		_scrawl != null and _scrawl.modulate.a < 0.01)
	_level.call("_fire_room_scare", _scr_room)


func _report() -> bool:
	if _checks < SEEDS.size() * 12:
		print("  FAIL only %d checks ran" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
