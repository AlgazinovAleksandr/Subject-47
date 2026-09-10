extends SceneTree

# DOES OBJECT 12 WALK THROUGH WALLS?
#
#   Godot --headless --path game --script res://tests/probe_breach_creature_path.gd
#
# A `probe_*`: it measures and prints, it does not assert. Whether a wall-passing chaser is a
# defect or an accepted simplification is a design call, not this file's.
#
# ⚠️ THE HYPOTHESIS. `creature_object12.gd:_move_toward()` writes `_body.global_position`
# directly, and `_body` is a **StaticBody3D** (`:111`). A static body does not sweep and does not
# resolve; there is no `move_and_slide`, no `test_move` and no navmesh anywhere in that file. So
# every target that is not on the creature's own axis should produce a beeline through masonry.
#
# ⚠️ WHY IT HAS NEVER SHOWN UP. `level_6_breach.gd:PATROL_LOOP` is five room centres that are ALL
# on x = 0 (Corridor1 z7, Junction1 z14, Atrium z22, Junction2 z30, WardB z37), and every spine
# doorway is on x = 0 too. Patrolling is one 30 m straight line down an unobstructed corridor, so
# the mover is never asked a question it could get wrong. The bypass loops (WardA east,
# ArchiveA/B west) are the only off-axis geometry in the level and nothing patrols them.
#
# ⚠️ THE PLAYER IS WALKED THERE, NOT TELEPORTED. `AutoPlayer` drives `player.gd`'s `ai_*` surface,
# so gravity, collision and `move_and_slide` all run — the creature is chasing a body that got to
# WardA the way a person would, through the Atrium doorway at (4, 21).
#
# ⚠️ CHASE IS FORCED AND RE-FORCED. `_tick_chase()` drops to SEARCH after `LOS_LOSS_GRACE` 0.4 s
# without line of sight, and a player behind a wall has none by definition — so an un-re-forced
# chase would end before the mover had been asked anything. Re-entering CHASE every frame is
# honest here precisely because it isolates the MOVER, which is the thing under test.
#
# ⚠️ TWO CONTROLS, because a probe that only ever reports hits is a probe that cannot tell you
# anything. Phase A runs the shipped PATROL loop and must report ZERO crossings (it is the
# on-axis case); phase C re-runs the chase segment test against a segment that is known to be
# clear. If A reports crossings the probe itself is wrong.

const SCENE := "res://scenes/level_6_breach.tscn"
const AUTOPLAYER := preload("res://tests/autoplay/autoplayer.gd")

# Deep inside WardA (x 4..10, z 17..33) — reached through the Atrium<->WardA doorway at (4, 21).
const WARDA_WAY := [Vector3(0, 0, 8.0), Vector3(0, 0, 19.0), Vector3(4.0, 0, 21.0), Vector3(7.0, 0, 26.0)]
const CHEST := 0.9
const PATROL_FRAMES := 900      # ~15 s: enough for a full spine leg
const CHASE_FRAMES := 600
const STOP_AT := 2.2            # stop before contact_dist 1.0 fires Screamer.trigger()

var _t := 0.0
var _stage := 0
var _frames := 0
var _level: Node = null
var _creature: Node = null
var _player: CharacterBody3D = null
var _auto = null
var _leg := 0
var _prev := Vector3.ZERO
var _have_prev := false

var _patrol_cross := 0
var _patrol_steps := 0
var _chase_cross := 0
var _chase_steps := 0
var _chase_dist := 0.0
var _first_cross := Vector3.ZERO
var _cross_names := {}


func _initialize() -> void:
	seed(7)
	change_scene_to_file(SCENE)


func _body_of(c: Node) -> Node3D:
	var nodes: Array = []
	_all(c, nodes)
	for x in nodes:
		if x is StaticBody3D:
			return x as Node3D
	return null


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _find_creature() -> Node:
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		var s = x.get_script()
		if s and String(s.resource_path).ends_with("creature_object12.gd"):
			return x
	return null


# Ray the creature's own step. Excludes its body and the player, so the only thing left to hit is
# the level. Mask 1 is the solid layer; interact volumes live on 2 and are walk-through.
func _blocked(a: Vector3, b: Vector3) -> Dictionary:
	if a.distance_to(b) < 0.0005:
		return {}
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, CHEST, 0), b + Vector3(0, CHEST, 0))
	q.collision_mask = 1
	q.exclude = [_player.get_rid(), _creature.call("get_body_rid")]
	return space.intersect_ray(q)


func _process(delta: float) -> bool:
	_t += delta
	if _t < 2.5 or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_creature = _find_creature()
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		if _creature == null or _player == null:
			print("FAILED to find creature (%s) or player (%s)" % [str(_creature), str(_player)])
			quit(1)
			return true
		print("== THE BREACH: does Object 12's mover respect walls? ==")
		print("   creature spawn %s   player spawn %s"
			% [str(_creature.call("get_creature_position")), str(_player.global_position)])
		_creature.call("activate")
		_auto = AUTOPLAYER.new(_player)

	match _stage:
		0:
			# ---- PHASE A (CONTROL): the shipped patrol loop, which is entirely on x = 0.
			_frames += 1
			var here: Vector3 = _creature.call("get_creature_position")
			if _have_prev:
				_patrol_steps += 1
				if not _blocked(_prev, here).is_empty():
					_patrol_cross += 1
			_prev = here
			_have_prev = true
			if _frames >= PATROL_FRAMES:
				print("\n-- PHASE A (control): PATROL, %d steps, %d wall crossings --"
					% [_patrol_steps, _patrol_cross])
				print("   state %d, at %s" % [int(_creature.call("get_state")), str(here)])
				if _patrol_cross > 0:
					print("   ⚠️ the CONTROL crossed a wall — the probe itself is suspect")
				_stage = 1
				_frames = 0
				_have_prev = false
		1:
			# ---- Walk the player into WardA the way a person would.
			if _leg >= WARDA_WAY.size():
				print("\n-- player walked to WardA: %s --" % str(_player.global_position))
				# ⚠️⚠️ PUT THE CREATURE BACK BEFORE MEASURING. The first version let it be
				# wherever patrol (or, once the router landed, an actual successful chase) had
				# taken it — and on the routed build it was already 0.70 m away, so phase B
				# measured **0 steps** and the verdict logic cheerfully reported "no wall
				# crossings". A probe whose pass condition is satisfied by measuring nothing is
				# the exact vacuity this project keeps finding in its own guards.
				var b := _body_of(_creature)
				if b:
					b.global_position = Vector3(0, 0, 22.0)   # Atrium centre, a wall away
					b.force_update_transform()
				_stage = 2
				_have_prev = false
				_frames = 0
				_auto.stop()
				return false
			var tgt: Vector3 = WARDA_WAY[_leg]
			tgt.y = _player.global_position.y
			if _auto.step_toward(tgt):
				_leg += 1
				_auto.reset_stuck()
			elif _auto.stuck:
				print("   ⚠️ player stuck heading for %s at %s" % [str(tgt), str(_player.global_position)])
				_leg += 1
				_auto.reset_stuck()
			_frames += 1
			if _frames > 3000:
				print("   ⚠️ walk budget exhausted at %s" % str(_player.global_position))
				_stage = 2
				_have_prev = false
				_frames = 0
		2:
			# ---- PHASE B: chase a player standing behind a wall.
			_frames += 1
			if int(_creature.call("get_state")) != 2:
				_creature.call("_enter", 2)
			var c: Vector3 = _creature.call("get_creature_position")
			if _have_prev:
				_chase_steps += 1
				_chase_dist += _prev.distance_to(c)
				var hit := _blocked(_prev, c)
				if not hit.is_empty():
					_chase_cross += 1
					if _first_cross == Vector3.ZERO:
						_first_cross = c
					var nm := "?"
					if hit.has("collider") and hit["collider"] != null:
						nm = String((hit["collider"] as Node).name)
					_cross_names[nm] = int(_cross_names.get(nm, 0)) + 1
			_prev = c
			_have_prev = true
			var gap := Vector2(c.x - _player.global_position.x, c.z - _player.global_position.z).length()
			if gap <= STOP_AT or _frames >= CHASE_FRAMES:
				print("\n-- PHASE B: CHASE toward a player in WardA --")
				print("   creature travelled %.2f m over %d steps, ending %.2f m from the player"
					% [_chase_dist, _chase_steps, gap])
				print("   WALL CROSSINGS: %d of %d steps" % [_chase_cross, _chase_steps])
				if _chase_cross > 0:
					print("   first crossing at %s" % str(_first_cross))
					for k in _cross_names.keys():
						print("      through %-28s %d steps" % [k, _cross_names[k]])
				_stage = 3
		3:
			# ---- PHASE C (control): a segment known to be clear must report clear.
			var a := Vector3(0, 0, 12.0)
			var b := Vector3(0, 0, 16.0)
			var clear := _blocked(a, b).is_empty()
			print("\n-- PHASE C (control): a 4 m step straight down the spine at x=0 --")
			print("   reported %s (must be CLEAR, or the ray is hitting something it should not)"
				% ("CLEAR" if clear else "BLOCKED"))
			print("\n== VERDICT ==")
			# ⚠️ SAMPLE SIZE FIRST. "no wall crossings" is trivially true of a chase that never
			# took a step — see the note in stage 1.
			if _chase_steps < 60:
				print("   INVALID: only %d chase steps measured. The creature was already on top"
					% _chase_steps)
				print("   of the player, so this run proves nothing either way.")
			elif _chase_cross > 0 and _patrol_cross == 0 and clear:
				print("   CONFIRMED: the mover ignores geometry. Patrol is clean only because")
				print("   every one of its waypoints is on x = 0.")
			elif _chase_cross == 0:
				print("   NOT REPRODUCED: the chase crossed no walls. The hypothesis is dead;")
				print("   do not build a fix for it.")
			else:
				print("   INCONCLUSIVE — a control misbehaved; read the phases above.")
			_auto.release()
			quit(0)
			return true
	return false
