extends SceneTree

# Geometry/prop probe for Level 6 — THE BREACH.
#   Godot --headless --path game --script res://tests/check_level6_breach.gd
#
# 1. Doorway clearance @ y=1.6 for every DOORS entry in level_6_breach.gd — the
#    recurring "a prop silently seals the opening" bug class (check_doorways.gd's
#    pattern, reused here).
# 2. Prop counts: exactly 6 HidingSpot, 4 SlamDoor, 1 PurgeChamber.
# 3. A floor exists under the PurgeChamber's configured trap_bounds (catches a
#    future edit that resizes one but not the other).

const DOORS := [
	[0.0, 3.0, "z", "Entry<->Corridor1"],
	[0.0, 11.0, "z", "Corridor1<->Junction1"],
	[-4.0, 14.0, "x", "Junction1<->Records"],
	[0.0, 17.0, "z", "Junction1<->Atrium"],
	[4.0, 21.0, "x", "Atrium<->WardA"],
	[0.0, 27.0, "z", "Atrium<->Junction2"],
	[4.0, 30.0, "x", "WardA<->Junction2"],
	[-4.0, 30.0, "x", "Junction2<->ArchiveA"],
	[0.0, 33.0, "z", "Junction2<->WardB"],
	[-7.0, 34.0, "z", "ArchiveA<->ArchiveB"],
	[-4.0, 37.0, "x", "ArchiveB<->WardB"],
	[0.0, 41.0, "z", "WardB<->WardC"],
	[0.0, 49.0, "z", "WardC<->PurgeAnte"],
	[0.0, 55.0, "z", "PurgeAnte<->Incinerator"],
]

var _frame := 0
var _fails := 0
# X1 (2026-09-14): the grab through the door, driven after the single-frame checks.
var _phase := 0
var _t := 0.0
var _grab_door: Node3D = null
var _grab_player: CharacterBody3D = null
var _hand_min: float = INF
var _frozen_seen := false
var _hiding_script: GDScript
var _slam_script: GDScript
var _purge_script: GDScript


func _initialize() -> void:
	# Referencing HidingSpot/SlamDoor/PurgeChamber by static type (`is SlamDoor`) here
	# would force Godot to eagerly compile those scripts before autoloads (GameState)
	# are registered — the "Identifier not found: GameState" trap test_apparition.gd
	# already documents for exactly this reason. Load as plain GDScript resources at
	# runtime instead and compare by script identity (same pattern as player.gd's
	# _find_scary_object).
	_hiding_script = load("res://scripts/hiding_spot.gd")
	_slam_script = load("res://scripts/slam_door.gd")
	_purge_script = load("res://scripts/purge_chamber.gd")
	change_scene_to_file("res://scenes/level_6_breach.tscn")


func _process(delta: float) -> bool:
	_frame += 1
	if _frame < 8:
		return false
	if _phase >= 1:
		return _tick_grab(delta)

	var player := current_scene.get_node_or_null("Player") as CharacterBody3D
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(current_scene)
	if not player:
		print("FAIL: no Player node found")
		quit(1)
		return true
	var space := player.get_world_3d().direct_space_state

	print("--- doorway clearance @ y=1.6 (BLOCKED = a prop is in the opening) ---")
	for d in DOORS:
		var c := Vector3(d[0], 1.6, d[1])
		var dir: Vector3 = Vector3(0, 0, 1) if d[2] == "z" else Vector3(1, 0, 0)
		var from := c - dir * 1.6
		var to := c + dir * 1.6
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [player.get_rid()]
		# Layer 1 only — SlamDoor/PurgeChamber intentionally sit in 4 of these
		# doorways with an ALWAYS-enabled interact collider on the pass-through
		# layer (2), so E can reach them regardless of open/closed state (see
		# Issue "interact deadlock", 2026-07-24). This check exists to catch a
		# GENUINE physical obstruction, not the intended interactable.
		q.collision_mask = 1
		var r := space.intersect_ray(q)
		if r.is_empty():
			print("  OK      %s" % d[3])
		else:
			var n: Object = r.collider
			var nm: String = (n as Node).name if n is Node else "?"
			var hit: Vector3 = r.position
			print("  BLOCKED %s  <- %s @ %v" % [d[3], nm, hit.snappedf(0.01)])
			_fails += 1

	print("--- prop counts ---")
	var counts := _count_props(current_scene)
	# ⚠️ 8 / 6 since the 2026-09-09 maze rework (was 6 / 4): a bigger map with a teleporting hunter
	# gets more hiding spots and more chokepoint slam doors.
	_check("HidingSpot count == 8", counts["hiding"] == 8, "%d" % counts["hiding"])
	_check("SlamDoor count == 6", counts["slam"] == 6, "%d" % counts["slam"])
	_check("PurgeChamber count == 1", counts["purge"] == 1, "%d" % counts["purge"])

	# The four SlamDoors crashed the level for the life of the feature: line 189 of
	# slam_door.gd returned AABB.intersects_segment() — a Variant (Vector3 | null) —
	# from a `-> bool` function, so the FIRST call after a door was closed and Object 12
	# left PATROL raised a fatal type error and dropped the window. Nothing here ever
	# CLOSED a door, and walk_level6_breach.gd never touches a SlamDoor at all, so the
	# whole code path was untested. Drive the real interact() to close, then assert both
	# the type and both answers. (2026-07-27)
	print("--- SlamDoor.check_blocks_path (closed) returns a real bool ---")
	var slam_doors: Array[Node] = []
	_collect(current_scene, _slam_script, slam_doors)
	for door in slam_doors:
		var d3 := door as Node3D
		var nrm: Vector3 = d3.global_transform.basis.z.normalized()
		var mid: Vector3 = d3.global_position + Vector3(0, 1.1, 0)
		door.call("interact")   # the real close path, not a private setter
		var crossing: Variant = door.call("check_blocks_path", mid - nrm * 1.0, mid + nrm * 1.0)
		var clear: Variant = door.call("check_blocks_path", mid + nrm * 1.0, mid + nrm * 3.0)
		var tag := "%s @ %v" % [d3.name, d3.global_position.snappedf(0.1)]
		_check("bool return (crossing) %s" % tag, typeof(crossing) == TYPE_BOOL,
			"got %s" % type_string(typeof(crossing)))
		_check("bool return (clear) %s" % tag, typeof(clear) == TYPE_BOOL,
			"got %s" % type_string(typeof(clear)))
		_check("blocks a crossing segment %s" % tag, crossing == true, "")
		_check("ignores a clear segment %s" % tag, clear == false, "")
		door.call("interact")   # reopen so the doorway-clearance state is left as found

	print("--- floor present under the purge chamber's trap bounds ---")
	var probe_from := Vector3(0.0, 1.0, 58.5)
	var probe_to := Vector3(0.0, -1.0, 58.5)
	var q2 := PhysicsRayQueryParameters3D.create(probe_from, probe_to)
	q2.exclude = [player.get_rid()]
	var r2 := space.intersect_ray(q2)
	_check("Incinerator floor present", not r2.is_empty(), "")

	# ---- X1: the grab through the door ---------------------------------------------
	print("--- X1: contact at a slam door is a GRAB, then the funnel ---")
	var lvl := current_scene
	_grab_player = player
	_grab_door = slam_doors[0] as Node3D
	var nrm3: Vector3 = _grab_door.global_transform.basis.z.normalized()
	var near_pos: Vector3 = _grab_door.global_position + nrm3 * 0.9
	near_pos.y = 0.1
	# A point genuinely away from EVERY door: the room centre with the largest door clearance
	# (6 m along one door's normal lands beside the next chokepoint — measured).
	var far_pos: Vector3 = Vector3.ZERO
	var far_clear: float = -1.0
	for room in lvl.get("ROOMS"):
		var c: Vector3 = lvl.get("_builder").room_center(room["name"])
		var nearest: float = INF
		for d in slam_doors:
			nearest = minf(nearest, Vector2(c.x - (d as Node3D).global_position.x, c.z - (d as Node3D).global_position.z).length())
		if nearest > far_clear:
			far_clear = nearest
			far_pos = c
	_check("X1: a room centre >= 1.5 m from every door exists (%.1f m)" % far_clear, far_clear >= 1.5, "")
	# The pure half: which door, if any, is "the door you are at".
	_check("X1: a door 0.9 m away is found", lvl.call("_nearest_slam_door", near_pos, 1.5) == _grab_door, "")
	_check("X1: CONTROL — away from every door none is found (plain death path)", lvl.call("_nearest_slam_door", far_pos, 1.5) == null, "")
	var scr := root.get_node("/root/Screamer")
	_check("X1: nothing is triggering before the contact", not bool(scr.get("_is_triggering")), "")
	player.global_position = near_pos
	player.velocity = Vector3.ZERO
	# Drive the creature's own death hook, exactly as _contact() does.
	var creature: Node = lvl.get("_creature")
	var cb: Callable = creature.get("death_override")
	_check("X1: the creature's death is overridden by the level", cb.is_valid(), "")
	cb.call()
	_check("X1: the player is pinned for it", bool(player.call("is_input_frozen")), "")
	_check("Breach: rigged kill replaces the primitive arm", lvl.get("_kill_sequence") != null, "")
	_check("X1: no Screamer panel yet (the grab comes first)", not bool(scr.get("_is_triggering")), "")
	_phase = 1
	_t = 0.0
	return false


func _tick_grab(delta: float) -> bool:
	_t += delta
	var scr := root.get_node("/root/Screamer")
	var kill: Node = current_scene.get("_kill_sequence")
	var arm := kill.get("actor") as Node3D if kill else null
	var cam := _grab_player.get_node_or_null("Camera3D") as Camera3D
	if arm and cam:
		_hand_min = minf(_hand_min, arm.global_position.distance_to(cam.global_position))
	if bool(_grab_player.call("is_input_frozen")):
		_frozen_seen = true
	if bool(scr.get("_is_triggering")):
		_check("Breach: both physical impacts fired", kill.get("impacts") == 2, "")
		_check("Breach: the door closes at the second impact", bool(_grab_door.call("is_closed")), "")
		_check("Breach: pinned throughout", _frozen_seen, "")
		_check("Breach: rigged kill reaches the funnel within 1.8 s", _t <= 1.8, "%.2f s" % _t)
		return _finish()
	if _t > 2.5:
		_check("X1: the grab ends in Screamer.trigger()", false, "still not triggering at %.1f s" % _t)
		return _finish()
	return false


func _finish() -> bool:
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true


func _check(label: String, cond: bool, detail: String) -> void:
	if cond:
		print("  OK   %s %s" % [label, detail])
	else:
		print("  FAIL %s %s" % [label, detail])
		_fails += 1


func _count_props(node: Node) -> Dictionary:
	var counts := {"hiding": 0, "slam": 0, "purge": 0}
	_walk_count(node, counts)
	return counts


func _collect(node: Node, script: GDScript, out: Array[Node]) -> void:
	if node.get_script() == script:
		out.append(node)
	for child in node.get_children():
		_collect(child, script, out)


func _walk_count(node: Node, counts: Dictionary) -> void:
	if node.get_script() == _hiding_script:
		counts["hiding"] += 1
	elif node.get_script() == _slam_script:
		counts["slam"] += 1
	elif node.get_script() == _purge_script:
		counts["purge"] += 1
	for child in node.get_children():
		_walk_count(child, counts)
