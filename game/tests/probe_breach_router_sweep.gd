extends SceneTree

# DOES OBJECT 12'S ROUTER STILL WALK THROUGH WALLS?  (adversarial, whole room graph)
#
#   Godot --headless --path game --script res://tests/probe_breach_router_sweep.gd
#
# `probe_breach_creature_path.gd` measures ONE traversal and reports 0 crossings, which is far
# weaker evidence than the claim "the router respects walls" needs — an independent adversarial
# pass over the whole graph measured **98 of 391 traversals still clipping masonry** on a build
# whose single-case probe was green. This sweeps every ordered room pair from several start
# offsets, drives the SHIPPING `_move_toward()` (so `_steer()` is exercised through its real call
# site), and raycasts between consecutive positions.
#
# ⚠️ TWO CONTROLS, because "0 crossings" is also what a broken probe prints:
#   BEELINE  the same traversals with the router disabled must report MANY crossings.
#   ARRIVAL  a traversal that never got anywhere cannot have crossed anything, so a run that
#            fails to arrive is counted separately and never as a pass.

const LEVEL := "res://scenes/level_6_breach.tscn"
const STEPS := 420
const DT := 0.05
const SPEED := 5.0
const ARRIVE := 1.2
const OFFSETS := [Vector2(0, 0), Vector2(0.35, 0.35), Vector2(-0.35, 0.35), Vector2(0.35, -0.35)]

var _t := 0.0
var _wall := 0.0
var _level: Node = null
var _creature: Node = null
var _space: PhysicsDirectSpaceState3D = null
var _rooms: Array = []
var _done := false


func _initialize() -> void:
	Engine.time_scale = 1.0
	seed(99)
	change_scene_to_file(LEVEL)


func _blocked(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0))
	q.collision_mask = 1
	q.exclude = [_creature.get("_body").get_rid()]
	return not _space.intersect_ray(q).is_empty()


# One traversal. Returns [crossings, arrived].
func _run(start: Vector3, target: Vector3, routed: bool) -> Array:
	_creature.get("_body").global_position = start
	var crossings := 0
	var arrived := false
	var prev := start
	for i in range(STEPS):
		if routed:
			_creature.call("_move_toward", target, SPEED, DT)
		else:
			# The control: bypass _steer() entirely and step straight at the target.
			var body = _creature.get("_body")
			var here: Vector3 = body.global_position
			var d := Vector3(target.x - here.x, 0.0, target.z - here.z)
			if d.length() > 0.001:
				body.global_position = here + d.normalized() * SPEED * DT
		var now: Vector3 = _creature.call("get_creature_position")
		if _blocked(prev, now):
			crossings += 1
		prev = now
		if Vector2(now.x - target.x, now.z - target.z).length() <= ARRIVE:
			arrived = true
			break
	return [crossings, arrived]


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 600.0:
		print("TIMEOUT")
		quit(1)
		return true
	_t += delta
	if current_scene == null or _t < 2.5 or _done:
		return false
	_done = true
	_level = current_scene
	_creature = _level.get("_creature")
	if _creature == null:
		print("no creature")
		quit(1)
		return true
	_space = _level.get_world_3d().direct_space_state
	_creature.set("_active", false)          # we drive it by hand; no state machine interference
	_rooms = _level.get_script().get_script_constant_map().get("ROOMS", [])
	print("== ROUTER SWEEP ==  %d rooms" % _rooms.size())

	for routed in [true, false]:
		var traversals := 0
		var clipped := 0
		var no_arrive := 0
		var worst := ""
		for a in range(_rooms.size()):
			for b in range(_rooms.size()):
				if a == b:
					continue
				var ca: Vector2 = _rooms[a]["pos"]
				var cb: Vector2 = _rooms[b]["pos"]
				for off in OFFSETS:
					var sa: Vector2 = _rooms[a]["size"]
					var st := Vector3(ca.x + off.x * sa.x * 0.5, 0.0, ca.y + off.y * sa.y * 0.5)
					var tg := Vector3(cb.x, 0.0, cb.y)
					var r := _run(st, tg, routed)
					traversals += 1
					if int(r[0]) > 0:
						clipped += 1
						if worst == "":
							worst = "%s -> %s from %s" % [_rooms[a]["name"], _rooms[b]["name"], str(st)]
					if not bool(r[1]):
						no_arrive += 1
		var label := "ROUTED " if routed else "BEELINE"
		print("%s  traversals %d   clipped a wall %d (%.1f %%)   never arrived %d"
			% [label, traversals, clipped, 100.0 * clipped / maxf(1.0, traversals), no_arrive])
		if worst != "":
			print("          first clip: %s" % worst)
	print("== the BEELINE row is the control: if it is near zero the probe is not measuring ==")
	quit(0)
	return true
