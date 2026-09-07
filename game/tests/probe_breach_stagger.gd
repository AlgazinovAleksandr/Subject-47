extends SceneTree

# ADVERSARIAL PROBE — `_tick_staggered()` recovering toward a PATROL WAYPOINT.
#
#   Godot --headless --path game --script res://tests/probe_breach_stagger.gd
#   Godot --headless --path game --script res://tests/probe_breach_stagger.gd -- dungeon
#
#   M1  the Matron's configuration: how many waypoints does she actually get, and what does
#       `_recovery_target()` return when she is staggered ON her nearest one?
#   M2  a creature with ZERO waypoints (the documented fallback) — old behaviour intact?
#   M3  a creature with ONE waypoint — `(i + 1) % 1 == i`, so the "take the next one" escape
#       collapses back to its own feet. Is that configuration reachable in either level?
#   M4  how long does the post-stagger SEARCH actually last?  `_search_t` only accumulates
#       AFTER arrival, so a distant recovery target extends SEARCH well past SEARCH_TIME.
#   M5  the Matron has NO portals — does recovering toward a distant chamber now beeline
#       through walls for longer than the old spin-in-place did?

var _dungeon := false
var _stage := 0
var _t := 0.0
var _creature: Node = null
var _level: Node = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "dungeon":
			_dungeon = true
	Engine.time_scale = 1.0
	seed(7)
	change_scene_to_file("res://scenes/dungeon.tscn" if _dungeon else "res://scenes/level_6_breach.tscn")



# ⚠️ NO `class_name` TYPES ANYWHERE IN THESE PROBES. A `--script` SceneTree compiles its own
# dependencies BEFORE the autoloads exist, so naming `CreatureObject12` at parse time forces an
# early compile of a script that references `Screamer` and the whole probe fails to load.
# `probe_purge_freeze.gd` already avoids this by matching on the script's resource path.
func _is_script(n: Node, base: String) -> bool:
	var s = n.get_script()
	return s != null and String(s.resource_path).ends_with(base)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _grab() -> void:
	_level = current_scene
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if _is_script(x, "creature_object12.gd"):
			_creature = x
			if _dungeon and x.name == "TheMatron":
				return


func _process(d: float) -> bool:
	_t += d
	if _stage == 0:
		if _t < (2.0 if _dungeon else 0.8):
			return false
		_grab()
		if _creature == null:
			print("FATAL: no CreatureObject12")
			return true
		_stage = 1
		_run()
		return true
	return false


func _run() -> void:
	print("=== probe_breach_stagger (%s) ===" % ("dungeon/Matron" if _dungeon else "breach"))
	var wps: PackedVector3Array = _creature._waypoints
	print("waypoints: %d   portals: %d   chase_speed=%.1f  investigate_speed=%.1f" % [
		wps.size(), _creature._portals.size(), _creature.chase_speed, _creature.investigate_speed])
	for i in range(wps.size()):
		print("   wp[%d] = %s" % [i, str(wps[i])])

	print("\nM1/M3. `_recovery_target()` FROM EACH WAYPOINT (staggered exactly on one)")
	for i in range(wps.size()):
		_creature._body.global_position = wps[i]
		var rt: Vector3 = _creature._recovery_target()
		var dist: float = _creature.get_creature_position().distance_to(rt)
		print("   on wp[%d]: recovery -> %s   %.2f m away %s" % [
			i, str(rt), dist,
			"  *** ITS OWN FEET — the 8 s spin is back ***" if dist < 0.6 else ""])

	print("\nM1b. `_recovery_target()` FROM A MID-ROOM POINT")
	var mid := Vector3(0, 0, 25.0) if not _dungeon else wps[0].lerp(wps[1], 0.5)
	_creature._body.global_position = mid
	var rt2: Vector3 = _creature._recovery_target()
	print("   from %s -> %s (%.2f m)" % [str(mid), str(rt2), mid.distance_to(rt2)])

	print("\nM2. ZERO WAYPOINTS (documented fallback)")
	var keep: PackedVector3Array = _creature._waypoints
	_creature._waypoints = PackedVector3Array()
	_creature._body.global_position = mid
	var rt0: Vector3 = _creature._recovery_target()
	print("   -> %s  (own position = %s)  %s" % [
		str(rt0), str(_creature.get_creature_position()),
		"OLD BEHAVIOUR PRESERVED" if rt0.distance_to(_creature.get_creature_position()) < 0.001
		else "*** unexpected ***"])

	print("\nM3b. EXACTLY ONE WAYPOINT")
	var one := PackedVector3Array()
	one.append(mid)
	_creature._waypoints = one
	_creature._body.global_position = mid
	var rt1: Vector3 = _creature._recovery_target()
	print("   staggered ON the single waypoint -> %s  (%.3f m away)  %s" % [
		str(rt1), rt1.distance_to(mid),
		"*** collapses to its own feet: (i+1) %% 1 == i ***" if rt1.distance_to(mid) < 0.6 else "ok"])
	_creature._waypoints = keep

	print("\nM4. HOW LONG DOES THE POST-STAGGER SEARCH LAST?")
	print("   `_search_t` only accumulates in the ARRIVED branch, so total SEARCH =")
	print("   walk(recovery_target) / investigate_speed  +  SEARCH_TIME (8.0 s).")
	var worst := 0.0
	var worst_from := Vector3.ZERO
	for i in range(wps.size()):
		_creature._body.global_position = wps[i]
		var rt: Vector3 = _creature._recovery_target()
		var walk: float = wps[i].distance_to(rt) / _creature.investigate_speed
		if walk > worst:
			worst = walk
			worst_from = wps[i]
	print("   worst walk leg from a waypoint: %.1f s (from %s), so SEARCH lasts up to %.1f s" % [
		worst, str(worst_from), worst + 8.0])
	print("   (the OLD behaviour was a fixed 8.0 s spin in place)")

	print("\nM5. DOES THE RECOVERY WALK CROSS WALLS?  (raycast on layer 1 along the straight line)")
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var crossings := 0
	var checked := 0
	for i in range(wps.size()):
		_creature._body.global_position = wps[i]
		var rt: Vector3 = _creature._recovery_target()
		if rt.distance_to(wps[i]) < 0.6:
			continue
		checked += 1
		var q := PhysicsRayQueryParameters3D.create(wps[i] + Vector3(0, 0.9, 0), rt + Vector3(0, 0.9, 0))
		q.collision_mask = 1
		q.exclude = [_creature._body.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			crossings += 1
			print("   wp[%d] -> recovery: straight line hits %s at %s" % [
				i, str(hit["collider"].name if hit.has("collider") else "?"), str(hit["position"])])
	print("   %d of %d recovery legs are blocked by geometry on a straight line" % [crossings, checked])
	if _creature._portals.is_empty():
		print("   -> this creature has NO PORTALS, so `_steer()` is a no-op and it walks that line.")
	else:
		print("   -> this creature HAS portals, so `_steer()` routes around them.")
