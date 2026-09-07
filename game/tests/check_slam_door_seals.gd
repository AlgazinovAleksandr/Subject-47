extends SceneTree

# Does a CLOSED door actually close its doorway?
#
#   Godot --headless --path game --script res://tests/check_slam_door_seals.gd
#
# ⚠️ WHY: IT NEVER HAS. `slam_door.gd` built a 1.1 m panel and a 1.1 m blocker, hard-coded.
# Breach doorways are 1.8 m wide and Dungeon doorways 2.2 m (`dungeon_gen.gd:DOOR_WIDTH`), and
# `room_builder.gd:_emit_wall_run()` cuts them FULL HEIGHT with no lintel against 3.0 m / 3.2 m
# rooms. So slamming a door on Object 12 left a 0.35 m gap each side in the Breach and 0.55 m in
# the Dungeon — against a player capsule 0.8 m across, the Dungeon gap was very nearly walkable
# and the creature's own 0.6 m capsule fitted through both. `check_blocks_path()`'s segment/AABB
# test has always ASSUMED a seal the geometry did not provide.
#
# ⚠️ THIS SWEEPS THE DOORWAY WITH POINT QUERIES, NOT `intersect_shape`. A capsule query centred
# on a CSG box comes back CLEAR when it is wholly inside the slab (Issue 40,
# `tests/probe_shape_vs_csg.gd` is the evidence), which would silently approve exactly the case
# being tested. Points and rays are the only queries that answer this.
#
# ⚠️ AND IT CARRIES A CONTROL THAT MUST GO RED. A sweep that reported "sealed" because it was
# looking in the wrong place, or because the physics space was empty, would pass forever. So
# every run also SHRINKS a door back to the old 1.1 m and requires the same sweep to find the
# gap. If the control ever passes, the measurement means nothing.

const SAMPLE_STEP := 0.06     # lateral sample spacing across the opening
const HEIGHTS := [0.25, 0.9, 1.6, 2.05]   # ankle / knee / chest / head
# ⚠️ THE BAR IS "DOES THE LEAF SPAN ITS OPENING", not "could something squeeze through". The
# historical gaps were 0.35 m (Breach) and 0.55 m (Dungeon) per side — narrower than the
# player's 0.8 m capsule and than the creature's 0.6 m, so neither was literally walkable. What
# they WERE is a doorway with two permanent holes in it, and — the part that actually mattered —
# a `_block_body` AABB narrower than the opening, which is what `check_blocks_path()` measures
# when it decides whether a slammed door is on the creature's route.
const SEALED_MAX := 0.12      # a closed door: essentially no clear run at all
const CONTROL_MIN := 0.25     # the old 1.1 m leaf: the sweep MUST see its holes

# ⚠️ Each door gets its own patch of world. `queue_free()` is DEFERRED — freeing a door and
# building the next one in the same frame leaves BOTH in the physics space, and the first run
# of this test reported "Dungeon: an OPEN door is walkable — 0.24 m of 2.20" because it was
# scanning through the Breach door it had just CLOSED at the same coordinates.
const SPACING := 40.0

var _fails: Array[String] = []
var _checks := 0
var _stage := 0
var _t := 0.0
var _wall := 0.0
var _SLAM: GDScript
var _world: Node3D
var _space: PhysicsDirectSpaceState3D


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _initialize() -> void:
	# ⚠️ load(), not preload — slam_door.gd references GameState, which is not registered when
	# this script is parsed. Same trap as check_creature_anim.gd.
	_SLAM = load("res://scripts/slam_door.gd")
	_world = Node3D.new()
	root.add_child(_world)


# The widest run of BLOCKED lateral samples, and the widest run of CLEAR ones, across a
# doorway of `width` centred on the door's origin.
func _scan(door: Node3D, width: float) -> Dictionary:
	var half := width * 0.5
	var worst_gap := 0.0
	var blocked := 0
	var total := 0
	var run := 0.0
	var x := -half
	while x <= half + 0.0001:
		var solid_at_any_height := false
		for h in HEIGHTS:
			var p: Vector3 = door.global_position + Vector3(x, h, 0.0)
			var q := PhysicsPointQueryParameters3D.new()
			q.position = p
			q.collide_with_bodies = true
			# ⚠️ collision_mask 1 — the DEFAULT layer, i.e. what a body actually collides with.
			# SlamDoor's interact volume is on layer 2 (raycast-hittable, pass-through for
			# movement, note.gd's convention), and counting it here would report a permanently
			# sealed doorway whatever the blocker was doing.
			q.collision_mask = 1
			if not _space.intersect_point(q, 8).is_empty():
				solid_at_any_height = true
				break
		total += 1
		if solid_at_any_height:
			blocked += 1
			run = 0.0
		else:
			run += SAMPLE_STEP
			worst_gap = maxf(worst_gap, run)
		x += SAMPLE_STEP
	return {"gap": worst_gap, "blocked": blocked, "total": total}


var _slot := 0

func _make(width: float, height: float) -> Node3D:
	var d: Node3D = _SLAM.new()
	d.door_width = width
	d.door_height = height
	_world.add_child(d)
	d.global_position = Vector3(float(_slot) * SPACING, 0, 0)
	_slot += 1
	return d


# ⚠️⚠️ BUILD IN ONE FRAME, QUERY IN A LATER ONE. `PhysicsDirectSpaceState3D` reflects the state
# of the last PHYSICS step, and a `SceneTree._process` tick is not one — a body added and queried
# in the same pass is simply not in the space yet. The first working version of this test built
# each door and scanned it immediately, and reported "Dungeon: a CLOSED door ... 0 of 37 samples
# blocked" on a door that was in fact perfectly solid. Every door is created and put into its
# final state in stage 1; nothing is measured before stage 3.
var _doors: Array = []

func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 40.0:
		print("TIMEOUT at stage %d" % _stage)
		quit(1)
		return true
	_t += delta
	if _t < 0.25:
		return false
	_t = 0.0

	match _stage:
		0:
			print("== SLAM DOOR SEALS ==")
			_space = _world.get_world_3d().direct_space_state
			_ok("a physics space to query", _space != null)
			_stage = 1
		1:
			# ------------------------------------------------- build everything, measure nothing
			for spec in [{"n": "Breach", "w": 1.8, "h": 3.0},
					{"n": "Dungeon", "w": 2.2, "h": 3.2}]:
				var opened := _make(spec["w"], spec["h"])
				_doors.append({"n": spec["n"] + " OPEN", "d": opened, "w": spec["w"],
					"h": spec["h"], "shut": false})
				var shut := _make(spec["w"], spec["h"])
				shut.call("interact")
				_doors.append({"n": spec["n"], "d": shut, "w": spec["w"], "h": spec["h"],
					"shut": true})
			# ⭐ the control: the OLD hard-coded 1.1 m leaf, closed, in a real 1.8 m doorway.
			var ctrl := _make(1.1, 3.0)
			ctrl.call("interact")
			_doors.append({"n": "CONTROL", "d": ctrl, "w": 1.8, "h": 3.0, "shut": true,
				"control": true})
			_stage = 2
		2:
			# One idle frame so the physics server has stepped with the new bodies in it.
			_stage = 3
		3:
			for e in _doors:
				var scan := _scan(e["d"], e["w"])
				if e.get("control", false):
					_ok("CONTROL: the old 1.1 m leaf IS caught in a 1.8 m doorway",
						scan["gap"] >= CONTROL_MIN,
						("widest clear run %.3f m (expect ~0.35, the historical per-side hole) "
						+ "— under %.2f and the sweep is measuring nothing, which would make "
						+ "every assertion above vacuous") % [scan["gap"], CONTROL_MIN])
				elif e["shut"]:
					_ok("%s: a CLOSED door spans its whole opening" % e["n"],
						scan["gap"] < SEALED_MAX,
						"widest clear run %.3f m across a %.1f m doorway (limit %.2f)"
							% [scan["gap"], e["w"], SEALED_MAX])
					_ok("%s: and it is solid across the whole opening" % e["n"],
						float(scan["blocked"]) / float(scan["total"]) > 0.9,
						"%d of %d samples blocked" % [scan["blocked"], scan["total"]])
					# The gap ABOVE the leaf is not a route, but an open doorway running to the
					# ceiling is why these doors "look weird" — a frame with nothing over it.
					_ok("%s: the doorway is capped above the leaf" % e["n"],
						e["d"].get_node_or_null("Transom") != null,
						"a %.1f m opening over a 2.2 m leaf leaves %.1f m to cap"
							% [float(e["h"]), float(e["h"]) - 2.3])
				else:
					_ok("%s door is walkable" % e["n"], scan["gap"] > 0.8,
						"widest clear run %.2f m of %.2f" % [scan["gap"], e["w"]])
			print("== %d checks, %d failed ==" % [_checks, _fails.size()])
			for f in _fails:
				print("   FAILED: " + f)
			quit(1 if _fails.size() > 0 else 0)
			return true
		_:
			pass
	return false
