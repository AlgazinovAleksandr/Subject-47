extends SceneTree

# THE BREACH'S CREATURE BEATS, TIMED IN THE REAL LEVEL.
#
#   Godot --headless --path game --script res://tests/check_breach_creature_beats.gd
#
# ⚠️⚠️ EVERY OTHER TEST THAT TOUCHES OBJECT 12 CALLS `activate()` BY HAND ON FRAME 1, IN A BARE
# STUB WORLD, AND NEVER LETS REAL GAME TIME PASS. `test_creature_object12.gd` builds the creature
# in an empty `Node3D` with a stub player — so `_block_t` is structurally 0.0 for its whole run and
# it exercises `_tick_staggered` on the one path where nothing can interfere. That is why the
# 2026-09-07 playtest found two level-breaking bugs in code the suite reported green:
#
#   * a failed purge froze the creature for 2 h 46 m (`check_purge_interact.gd` now covers that);
#   * a slam door silently extended a stagger, because the `_block_t` early return sat above the
#     whole `match _state` dispatch.
#
# What this file adds is TIME, in the SHIPPING SCENE:
#   1. `_tick_familiarization` — nothing asserted this at all. It must NOT be awake early and it
#      must be awake after.
#   2. the light weapon's geometric gate — range, cone and line of sight, driven from a real
#      camera pose rather than by calling `apply_light_damage()` directly.
#   3. a stagger ends, and the creature **TRANSLATES** afterwards. A position delta, not a state
#      transition: `test_creature_object12.gd` asserts `staggered_to_search` and stops there, so a
#      creature that recovered into a permanent standstill would pass it.
#   4. a stagger with a door battering it still ends, and within a stated bound.

const SCENE := "res://scenes/level_6_breach.tscn"
const SETTLE := 2.5

var _fails := 0
var _checks := 0
var _t := 0.0
var _wall := 0.0
var _stage := 0
var _level: Node = null
var _player: CharacterBody3D = null
var _creature: Node = null
var _consts := {}
var _mark := Vector3.ZERO
var _recovered_at := -1.0
var _clock := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	# ⚠️ Compressed time: every timer under test is in GAME seconds, so the pacing is unchanged
	# and only the wall clock shrinks. `count_apparitions.gd` uses the same trick.
	Engine.time_scale = 8.0
	seed(7)
	change_scene_to_file(SCENE)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _find(suffix: String) -> Node:
	var nodes: Array = []
	_all(_level, nodes)
	for x in nodes:
		var sc = x.get_script()
		if sc and String(sc.resource_path).ends_with(suffix):
			return x
	return null


func _body() -> Node3D:
	var nodes: Array = []
	_all(_creature, nodes)
	for x in nodes:
		if x is StaticBody3D:
			return x as Node3D
	return null


func _pos() -> Vector3:
	return _creature.call("get_creature_position")


# Stand in front of the creature with the torch on, aimed at its chest.
# ⚠️ `force_update_transform()` on the CAMERA as well as the player: `_tick_light_weapon()` reads
# `cam.global_transform.basis.z`, and a camera whose parent moved this frame still reports the old
# basis until it is flushed. The first version of this test aimed correctly and measured nothing.
func _aim_at_creature(range_m: float) -> void:
	var cpos := _pos()
	_player.set("ai_active", true)
	# ⚠️ PICK A DIRECTION WITH A CLEAR LINE, don't assume -Z. The creature is wherever patrol took
	# it, so a fixed offset routinely lands the player inside a wall — `_tick_light_weapon()`'s LOS
	# ray then fails and the test reports "the light weapon does not work" about its own placement.
	# Measured: that is exactly what the first version did.
	var space := _player.get_world_3d().direct_space_state
	var best := Vector3(0, 0, -1)
	for dir in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var eye: Vector3 = cpos + dir * range_m + Vector3(0, 1.75, 0)
		var q := PhysicsRayQueryParameters3D.create(eye, cpos + Vector3(0, 0.9, 0))
		q.collision_mask = 1
		q.exclude = [_player.get_rid(), _creature.call("get_body_rid")]
		if space.intersect_ray(q).is_empty():
			best = dir
			break
	_player.global_position = cpos + best * range_m + Vector3(0, 0.1, 0)
	_player.call("ai_look_at", cpos + Vector3(0, 0.9, 0))
	_player.force_update_transform()
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()
	var fl := _player.get_node_or_null("Camera3D/Flashlight") as SpotLight3D
	if fl:
		fl.visible = true


# ⚠️ PIN THE CREATURE WHILE TESTING THE GATE. It is in CHASE 4 m from a stationary player, so
# without this it closes and kills them — the scene reloads and every later assertion runs on a
# different level instance. `force_block()` stops movement without changing state, and (since
# 2026-09-07) the drain has no `_block_t` guard, so the gate under test is unaffected.
func _pin(on: bool) -> void:
	if on:
		_creature.call("force_block", 60.0)
	else:
		_creature.set("_block_t", 0.0)


# Drive the LEVEL's own tick, re-asserting CHASE so a lost line of sight cannot end the test
# early. Returns the shield delta.
func _burn(iterations: int) -> float:
	var before: float = float(_creature.get("_shield"))
	for i in range(iterations):
		if int(_creature.call("get_state")) == 2:
			_level.call("_tick_light_weapon", 0.05)
		elif int(_creature.call("get_state")) != 4:
			_creature.call("_enter", 2)
		else:
			break
	return before - float(_creature.get("_shield"))


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 300.0:
		_ok("the run finished inside its budget", false, "TIMEOUT at stage %d" % _stage)
		return _report()
	_t += delta
	_clock += delta
	if _t < SETTLE or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		_creature = _find("creature_object12.gd")
		_consts = _level.get_script().get_script_constant_map()
		_ok("the level, the player and Object 12 all exist",
			_level != null and _player != null and _creature != null)
		if _creature == null:
			return _report()
		if _creature.has_signal("recovered"):
			_creature.connect("recovered", func() -> void: _recovered_at = _clock)
		print("== BREACH CREATURE BEATS ==")
		_t = 0.0
		return false

	if current_scene != _level:
		_ok("the scene did not reload mid-test", false,
			"Screamer.trigger() fired — everything after this is a different level instance")
		return _report()

	match _stage:
		0:
			# ---- 1. FAMILIARIZATION. Nothing has ever asserted this.
			var window: float = float(_consts.get("FAMILIARIZATION_FIRST", 30.0))
			if _clock < window * 0.5:
				return false
			_ok("Object 12 is still DORMANT halfway through the familiarization window",
				not bool(_creature.get("_active")),
				"%.1f s of a %.0f s window — every other test calls activate() on frame 1"
					% [_clock, window])
			_mark = _pos()
			_stage = 1
		1:
			var window2: float = float(_consts.get("FAMILIARIZATION_FIRST", 30.0))
			if _clock < window2 * 0.95:
				return false
			_ok("...and it has not moved a millimetre while dormant",
				_mark.distance_to(_pos()) < 0.01,
				"drifted %.3f m" % _mark.distance_to(_pos()))
			_stage = 2
		2:
			var window3: float = float(_consts.get("FAMILIARIZATION_FIRST", 30.0))
			if _clock < window3 + 3.0:
				return false
			_ok("...and it IS awake once the window elapses", bool(_creature.get("_active")),
				"awake at %.1f s" % _clock)
			_stage = 3
			_t = 0.0
		3:
			# ---- 2. THE LIGHT WEAPON'S GEOMETRIC GATE, from a real camera pose.
			# Stand the player in front of the creature, torch on, looking at it.
			# ⚠️⚠️ ARM AND MEASURE IN THE SAME FRAME. The first version armed here and measured
			# 0.2 s later — and the LEVEL'S OWN `_process` runs `_tick_light_weapon()` every frame
			# in between, so by the time the assertion ran the shield was already at 0 and the
			# creature had staggered. It reported "the light weapon does not drain" while
			# measuring the aftermath of it draining. No frame may elapse between `_shield = 100`
			# and the burn.
			_pin(true)
			_aim_at_creature(4.0)
			# ⚠️ Drive the LEVEL's own tick, not `apply_light_damage()` — the whole point is the
			# range/cone/LOS gate in `_tick_light_weapon()`, which nothing has ever exercised.
			_creature.call("_enter", 2)   # State.CHASE — the weapon is CHASE-only by design
			_creature.set("_shield", 100.0)
			var drained := _burn(20)
			_ok("aiming the torch at a CHASING creature drains its shield", drained > 1.0,
				"shield fell %.1f through the real range/cone/LOS gate" % drained)
			# ⭐ CONTROL: turn the torch off and require the drain to stop.
			var fl2 := _player.get_node_or_null("Camera3D/Flashlight") as SpotLight3D
			if fl2:
				fl2.visible = false
			_creature.call("_enter", 2)
			_creature.set("_shield", 100.0)
			var idle := _burn(20)
			_ok("CONTROL — with the torch OFF it does not drain", absf(idle) < 0.01,
				"shield fell %.2f" % idle)
			if fl2:
				fl2.visible = true
			# ⭐ SECOND CONTROL: too far away. `LIGHT_WEAPON_RANGE` is 18 m.
			_aim_at_creature(24.0)
			_creature.call("_enter", 2)
			_creature.set("_shield", 100.0)
			var far_drain := _burn(20)
			_ok("CONTROL — out of range it does not drain either", absf(far_drain) < 0.01,
				"shield fell %.2f at 24 m against an 18 m weapon" % far_drain)
			_aim_at_creature(4.0)
			_stage = 5
			_t = 0.0
		5:
			# ---- 3. STAGGER -> RECOVERY -> IT ACTUALLY MOVES.
			_creature.call("_enter", 2)
			_creature.set("_shield", 100.0)
			_recovered_at = -1.0
			_burn(400)
			_ok("holding the beam on it staggers it", int(_creature.call("get_state")) == 4,
				"state %d" % int(_creature.call("get_state")))
			_pin(false)
			# ⚠️ GET THE PLAYER OUT OF ITS REACH before letting it recover, or it walks over and
			# kills them and the scene reloads under the assertions below.
			_player.global_position = Vector3(0, 0.1, 0)      # Entry, ~40 m up the spine
			_player.force_update_transform()
			_mark = _pos()
			_clock = 0.0
			_stage = 6
			_t = 0.0
		6:
			var smax: float = float(load("res://scripts/creature_object12.gd")
				.get("STAGGER_MAX"))
			if _t < smax + 6.0:
				return false
			_ok("the stagger ENDS", _recovered_at >= 0.0,
				"recovered at %.1f s (STAGGER_MAX is %.1f)" % [_recovered_at, smax])
			# ⭐ THE ASSERTION `test_creature_object12.gd` CANNOT MAKE: a position delta.
			_ok("...and the creature TRANSLATES afterwards", _mark.distance_to(_pos()) > 1.0,
				"moved %.2f m in %.1f s — a state transition is not movement, and before "
					% [_mark.distance_to(_pos()), _t]
				+ "2026-09-07 recovery guaranteed 8 s of rotating on the spot")
			_stage = 7
			_t = 0.0
		7:
			# ---- 4. A STAGGER WITH A DOOR BATTERING IT STILL ENDS.
			_creature.call("_enter", 2)
			_creature.set("_shield", 100.0)
			_pin(true)
			_aim_at_creature(4.0)
			_recovered_at = -1.0
			_burn(400)
			_pin(false)
			_player.global_position = Vector3(0, 0.1, 0)
			_player.force_update_transform()
			# Now block it as a battering door would.
			_creature.call("force_block", 10.0)
			_clock = 0.0
			_stage = 8
			_t = 0.0
		8:
			var smax2: float = float(load("res://scripts/creature_object12.gd")
				.get("STAGGER_MAX"))
			if _t < smax2 + 8.0:
				return false
			_ok("a stagger that overlaps a door block STILL ends", _recovered_at >= 0.0,
				"recovered at %.1f s — before 2026-09-07 the `_block_t` early return sat above "
					% _recovered_at
				+ "the whole state dispatch, so a 10 s batter silently added 10 s to a beat the "
				+ "level ANNOUNCES the length of")
			return _report()
	return false


func _report() -> bool:
	print("== %d checks, %d failed ==" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return true
