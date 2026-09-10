extends SceneTree

# ADVERSARIAL PROBE — the 2026-09-07 portal router (`set_portals`/`_steer`/`_move_toward`).
#
#   Godot --headless --path game --script res://tests/probe_breach_router.gd
#
# HYPOTHESIS (from reading, to be falsified):
#   `_move_toward()` early-returns on `dir.length() < 0.01`. Before routing, `dir` was the
#   vector to the PLAYER, so that guard only fired when the creature was on top of you and
#   `_check_contact()` had already resolved it. With routing, `dir` is the vector to a FIXED
#   DOORWAY POINT. A step that happens to land inside that 1 cm disc while still on the
#   from-side of the boundary leaves `_room_at(here)` == from, so `_steer()` returns the same
#   portal on the next frame, `dir` is the same sub-centimetre vector, and the creature never
#   moves again. In PATROL that is permanent (the waypoint never arrives, so `_wp_index` never
#   advances); in CHASE it persists until the player changes room.
#
# The window is 0.01 m against a per-frame step of speed*delta, so the predicted stall rate is
# ~0.01/(speed*delta): ~33 % per portal at patrol speed 60 fps, ~12 % at chase speed, and ~100 %
# at the small deltas an uncapped/headless or high-refresh client produces.
#
# The mover is driven DIRECTLY with a fixed delta rather than by the engine clock, because the
# thing under test is a per-step arithmetic race and a variable delta would make it unreproducible.
# The creature is left dormant (`_active == false`), so its own `_process()` returns immediately
# and cannot interfere.

const SCENE := "res://scenes/level_6_breach.tscn"

var _stage := 0
var _t := 0.0
var _creature: Node = null


func _initialize() -> void:
	seed(7)
	change_scene_to_file(SCENE)



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


func _find_creature() -> Node:
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if _is_script(x, "creature_object12.gd"):
			return x
	return null


func _put(p: Vector3) -> void:
	_creature._body.global_position = p


func _pos() -> Vector3:
	return _creature.get_creature_position()


# One straight run at `target`, fixed delta. Returns a report dict.
func _run(start: Vector3, target: Vector3, speed: float, dt: float, max_steps: int) -> Dictionary:
	_put(start)
	var last := _pos()
	var still := 0
	var worst_still := 0
	var stall_at := Vector3.ZERO
	var arrived := false
	var steps := 0
	for i in range(max_steps):
		steps = i + 1
		_creature._move_toward(target, speed, dt)
		var now := _pos()
		if now.distance_to(last) < 1e-6:
			still += 1
			if still > worst_still:
				worst_still = still
				stall_at = now
		else:
			still = 0
		last = now
		var flat := Vector2(now.x - target.x, now.z - target.z).length()
		if flat <= 0.6:
			arrived = true
			break
	return {
		"arrived": arrived, "steps": steps, "worst_still": worst_still,
		"stall_at": stall_at, "end": last,
		"end_dist": Vector2(last.x - target.x, last.z - target.z).length(),
	}


func _process(_d: float) -> bool:
	_t += _d
	if _stage == 0:
		if _t < 0.6:
			return false
		_creature = _find_creature()
		if _creature == null:
			print("FATAL: no CreatureObject12 in scene")
			return true
		print("=== probe_breach_router ===")
		print("creature at ", _pos(), "  portals=", _creature._portals.size(),
			"  rooms=", _creature._rooms.size(), "  waypoints=", _creature._waypoints.size())
		_stage = 1
		return false

	if _stage == 1:
		_test_stall_sweep()
		_test_boundary()
		_test_patrol_laps()
		_test_chase_routes()
		_test_reachability()
		return true
	return false


# ---------------------------------------------------------------- 1. the stall sweep

func _test_stall_sweep() -> void:
	print("\n--- 1. PORTAL STALL SWEEP (patrol leg Junction1 -> Atrium, portal at z=17) ---")
	print("   a stall = position unchanged for >=200 consecutive steps while still >0.6 m from target")
	var target := Vector3(0, 0, 22)     # Atrium centre = the patrol waypoint
	var cases := [
		["patrol 1.8 @60fps", 1.8, 1.0 / 60.0],
		["patrol 1.8 @144fps", 1.8, 1.0 / 144.0],
		["chase  5.0 @60fps", 5.0, 1.0 / 60.0],
		["chase  5.0 @144fps", 5.0, 1.0 / 144.0],
		["chase  5.0 @240fps", 5.0, 1.0 / 240.0],
		["invest 2.6 @60fps", 2.6, 1.0 / 60.0],
	]
	for c in cases:
		var label: String = c[0]
		var speed: float = c[1]
		var dt: float = c[2]
		var stalls := 0
		var trials := 0
		var example := ""
		# Sweep the starting z across one whole step length, in 200 slices — that is exactly
		# the phase of the approach, which is the only free variable in the race.
		var step: float = speed * dt
		for k in range(200):
			trials += 1
			var z0: float = 14.0 + step * float(k) / 200.0
			var r := _run(Vector3(0, 0, z0), target, speed, dt, 20000)
			if r["worst_still"] >= 200:
				stalls += 1
				if example == "":
					example = "start z=%.5f  stalled at %s  (%.4f m short of the portal)" % [
						z0, str(r["stall_at"]), 17.0 - (r["stall_at"] as Vector3).z]
		print("  %-20s step=%.5f m   stalled %d/%d (%.1f %%)" % [
			label, step, stalls, trials, 100.0 * float(stalls) / float(trials)])
		if example != "":
			print("        e.g. ", example)


# ---------------------------------------------------------------- 2. exactly on the boundary

func _test_boundary() -> void:
	print("\n--- 2. STANDING EXACTLY ON A ROOM BOUNDARY ---")
	var probes := [
		["portal z=17 exactly", Vector3(0, 0, 17.0), Vector3(0, 0, 22)],
		["1 mm short of z=17", Vector3(0, 0, 16.999), Vector3(0, 0, 22)],
		["1 mm past z=17", Vector3(0, 0, 17.001), Vector3(0, 0, 22)],
		["portal x=4 exactly (Atrium|WardA)", Vector3(4.0, 0, 21.0), Vector3(7, 0, 25)],
		["portal x=-4 exactly (J1|Records)", Vector3(-4.0, 0, 14.0), Vector3(-7, 0, 14)],
	]
	for p in probes:
		var here: Vector3 = p[1]
		var target: Vector3 = p[2]
		_put(here)
		var room_here: int = _creature._room_at(here)
		var room_target: int = _creature._room_at(target)
		var steer: Vector3 = _creature._steer(target)
		var d := Vector2(steer.x - here.x, steer.z - here.z).length()
		var r := _run(here, target, 5.0, 1.0 / 60.0, 4000)
		print("  %-36s room(here)=%2d room(tgt)=%2d steer=%s |dir|=%.5f  %s (still %d, end %.2f m)" % [
			p[0], room_here, room_target, str(steer), d,
			"ARRIVED" if r["arrived"] else "*** NEVER ARRIVED ***",
			r["worst_still"], r["end_dist"]])


# ---------------------------------------------------------------- 3. can it still patrol?

func _test_patrol_laps() -> void:
	print("\n--- 3. FULL PATROL LOOP, mover driven directly (does it complete laps?) ---")
	var wps: PackedVector3Array = _creature._waypoints
	for dt in [1.0 / 60.0, 1.0 / 144.0]:
		_put(wps[0])
		var idx := 0
		var laps := 0
		var stuck_at := -1
		var still := 0
		var last := _pos()
		var steps := int(600.0 / dt)   # 600 s of simulated patrol
		for i in range(steps):
			_creature._move_toward(wps[idx], 1.8, dt)
			var now := _pos()
			if now.distance_to(last) < 1e-6:
				still += 1
				if still > 400 and stuck_at < 0:
					stuck_at = idx
					break
			else:
				still = 0
			last = now
			if Vector2(now.x - wps[idx].x, now.z - wps[idx].z).length() <= 0.6:
				idx = (idx + 1) % wps.size()
				if idx == 0:
					laps += 1
		print("  dt=%.5f  laps in 600 s = %d   %s" % [dt, laps,
			"STUCK heading to waypoint %d at %s" % [stuck_at, str(_pos())] if stuck_at >= 0 else "no stall"])


# ---------------------------------------------------------------- 4. cross-room chase routes

func _test_chase_routes() -> void:
	print("\n--- 4. CROSS-ROOM CHASE ROUTES (does the router reach, and at what cost?) ---")
	var legs := [
		["Atrium -> WardA (the wall it used to cross)", Vector3(0, 0, 22), Vector3(7, 0, 25)],
		["Junction1 -> Records", Vector3(0, 0, 14), Vector3(-7, 0, 14)],
		["Junction2 -> ArchiveB (west loop)", Vector3(0, 0, 30), Vector3(-7, 0, 37.5)],
		["Entry -> Incinerator (whole spine)", Vector3(0, 0, 0), Vector3(0, 0, 58.5)],
		["WardA -> ArchiveA (opposite loops)", Vector3(7, 0, 25), Vector3(-7, 0, 30.5)],
		["Incinerator -> Entry (reverse)", Vector3(0, 0, 58.5), Vector3(0, 0, 0)],
	]
	var dt := 1.0 / 60.0
	for leg in legs:
		var start: Vector3 = leg[1]
		var target: Vector3 = leg[2]
		var r := _run(start, target, 5.0, dt, 200000)
		var travelled := float(r["steps"]) * 5.0 * dt
		var beeline := Vector2(target.x - start.x, target.z - start.z).length()
		print("  %-44s %s  travelled %.1f m  beeline %.1f m  ratio %.2fx  (still %d)" % [
			leg[0], "OK " if r["arrived"] else "*** FAIL ***", travelled, beeline,
			travelled / maxf(beeline, 0.001), r["worst_still"]])


# ---------------------------------------------------------------- 5. every room reachable

func _test_reachability() -> void:
	print("\n--- 5. EVERY ROOM REACHABLE FROM EVERY ROOM ---")
	var centres: Array = []
	for r in _creature._rooms:
		centres.append(r["c"])
	var fails := 0
	var pairs := 0
	var dt := 1.0 / 60.0
	for i in range(centres.size()):
		for j in range(centres.size()):
			if i == j:
				continue
			pairs += 1
			var res := _run(centres[i], centres[j], 5.0, dt, 60000)
			if not res["arrived"]:
				fails += 1
				print("    *** %d -> %d FAILED, ended %.2f m away at %s (still %d)" % [
					i, j, res["end_dist"], str(res["end"]), res["worst_still"]])
	print("  %d/%d ordered room pairs reachable" % [pairs - fails, pairs])
