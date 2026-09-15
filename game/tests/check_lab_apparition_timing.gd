extends SceneTree

# When does the Lab's taught apparition actually appear?
#
#   Godot --headless --path game --script res://tests/check_lab_apparition_timing.gd
#
# ⚠️ IT USED TO BE ~1.7 SECONDS (a tripwire at z = 6), then 42–50 s on a clock from the level
# start — and on 2026-09-13 the user met it INSIDE THE DARK WING at t = 162 s (capture #2:
# "this creature should not appear while we are in the dark room … only after you take a
# card"). Since L2 it arms from `on_keycard_taken()`: `APPARITION_AT` seconds after the pickup,
# `APPARITION_DEADLINE` as the backstop, and NEVER while the player is in a WING_ROOMS room —
# that refusal outlives the deadline.
#
# ⚠️ WHAT THIS ASSERTS IS THE SHAPE, NOT THE NUMBER: nothing before the keycard however long
# you wait, nothing before the window opens, something by the deadline, a window that is a range,
# and the wing refusal with a control outside the wing.
#
# ⚠️ TIME-SCALED. `Engine.time_scale = 20` so the waits cost seconds of wall clock.

const SPEED := 20.0
const WAIT_BEFORE_KEYCARD := 80.0   # longer than the OLD clock's 65 s deadline: nothing may fire

var _fails: Array[String] = []
var _checks := 0
var _t := 0.0
var _wall := 0.0
var _level: Node = null
var _phase := 0
var _fired_at := -1.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _initialize() -> void:
	Engine.time_scale = SPEED
	change_scene_to_file("res://scenes/level_1.tscn")


func _collect(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls or (n.get_script() != null
			and String(n.get_script().resource_path).get_file() == cls.to_snake_case() + ".gd"):
		out.append(n)
	for c in n.get_children():
		_collect(c, cls, out)


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 400.0:
		print("TIMEOUT")
		quit(1)
		return true
	if current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		print("== LAB APPARITION TIMING ==")
		var events: Array = []
		_collect(current_scene, "CorridorEvent", events)
		var near_spawn := 0
		for e in events:
			if (e as Node3D).global_position.distance_to(Vector3(0, 1.5, -1.5)) < 12.0:
				near_spawn += 1
		_ok("no trigger volume sits near the Lab spawn", near_spawn == 0, "%d" % near_spawn)
		_ok("the apparition exists (it was delayed, not deleted)", current_scene.get("_apparition") != null)
		_ok("it is NOT armed before the first breaker", not bool(current_scene.get("_apparition_armed")))
		var at: Vector2 = current_scene.get("APPARITION_AT")
		_ok("the window is 3 s after breaker 1 (L1, 2026-09-15)", is_equal_approx(at.x, 3.0) and is_equal_approx(at.y, 3.0), str(at))
		# The wing refusal, with a control. Junction is the wing's first decision point.
		var p: Node3D = current_scene.get_node("Player")
		var home: Vector3 = p.global_position
		p.global_position = Vector3(-21.0, 0.1, 12.5)
		_ok("standing in the wing (Junction) is refused by _apparition_is_fair()",
			not bool(current_scene.call("_apparition_is_fair")))
		_ok("…and _in_wing() says so", bool(current_scene.call("_in_wing")))
		p.global_position = home
		_ok("CONTROL: back at the spawn it is fair again",
			bool(current_scene.call("_apparition_is_fair")) and not bool(current_scene.call("_in_wing")))
		return false

	_t += delta
	match _phase:
		0:
			if bool(_level.get("_apparition_fired")):
				_ok("nothing fires before the first breaker", false, "fired at %.1f s with no breaker" % _t)
				_finish()
				return true
			if _t >= WAIT_BEFORE_KEYCARD:
				_ok("nothing fired in %.0f s without a breaker" % WAIT_BEFORE_KEYCARD, true)
				_level.call("_on_breaker_flipped", "Breaker_Exam1")
				_ok("the FIRST breaker arms it", bool(_level.get("_apparition_armed")))
				var due: float = float(_level.get("_apparition_due"))
				var at: Vector2 = _level.get("APPARITION_AT")
				_ok("the window opens %.0f–%.0f s after the breaker" % [at.x, at.y],
					due >= at.x and due <= at.y, "due %.1f" % due)
				_t = 0.0
				_phase = 1
		1:
			if _fired_at < 0.0 and bool(_level.get("_apparition_fired")):
				_fired_at = float(_level.get("_apparition_clock"))
				var at: Vector2 = _level.get("APPARITION_AT")
				_ok("it fires, and not before the window opens", _fired_at >= at.x - 0.5,
					"fired %.1f s after the breaker" % _fired_at)
				_ok("…and by the deadline", _fired_at <= float(_level.get("APPARITION_DEADLINE")) + 1.0,
					"deadline %.0f" % float(_level.get("APPARITION_DEADLINE")))
				_finish()
				return true
			if _t > float(_level.get("APPARITION_DEADLINE")) + 12.0:
				_ok("it fires at all after the breaker", false, "nothing after %.0f s" % _t)
				_finish()
				return true
	return false


func _finish() -> void:
	Engine.time_scale = 1.0
	print("== %d checks, %d failed ==" % [_checks, _fails.size()])
	for f in _fails:
		print("   FAILED: " + f)
	quit(1 if _fails.size() > 0 else 0)
