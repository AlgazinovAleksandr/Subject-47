extends SceneTree

# When does the Lab's taught apparition actually appear?
#
#   Godot --headless --path game --script res://tests/check_lab_apparition_timing.gd
#
# ⚠️ IT USED TO BE ~1.7 SECONDS. `level_1.gd:_spawn_apparition()` planted a `CorridorEvent` box
# at z = 6.0 with a 3 x 3 x 1.5 extent, so its NEAR FACE was at z = 5.25 — and the player spawns
# at z = -1.5 facing +z down an unobstructed 3 m corridor. 6.75 m of straight line at
# `player.gd:SPEED` 4.0 is 1.7 s of holding W, so the game's designed teaching beat for the HOLD
# rule fired before the player had touched anything, identically, every run. The user's report
# was "the monster appears immediately once the player starts the lab level ... too predictable".
#
# ⚠️ WHAT THIS ASSERTS IS THE SHAPE, NOT THE NUMBER. A test that checked "fires at 45 s" would
# fail on the randomisation that makes the beat unpredictable in the first place. So: nothing
# before the window opens, something by the hard deadline, and the window is genuinely random
# across runs.
#
# ⚠️ TIME-SCALED. `Engine.time_scale = 20` so a 65 s deadline costs ~4 s of wall clock. The
# apparition's own clock is driven from `_process(delta)`, which scales with it; anything read
# off a wall clock here would be meaningless (`check_audio_buses.gd` carries the same note about
# frame counts).

const SPEED := 20.0
const EARLIEST_ALLOWED := 30.0    # nothing may fire before this, ever
const DEADLINE := 70.0            # something must have fired by here

var _fails: Array[String] = []
var _checks := 0
var _t := 0.0
var _wall := 0.0
var _fired_at := -1.0
var _level: Node = null
var _phase := 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _initialize() -> void:
	Engine.time_scale = SPEED
	change_scene_to_file("res://scenes/level_1.tscn")


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
		# ---------------------------------------------------------------- the tripwire is gone
		# ⚠️ Asserted by SEARCHING THE SCENE, not by reading the source: a `CorridorEvent` added
		# by any other path would be just as bad, and the point is that no volume near the spawn
		# can fire this beat.
		var events: Array = []
		_collect(current_scene, "CorridorEvent", events)
		var near_spawn := 0
		for e in events:
			if (e as Node3D).global_position.distance_to(Vector3(0, 1.5, -1.5)) < 12.0:
				near_spawn += 1
		_ok("no trigger volume sits near the Lab spawn", near_spawn == 0,
			("%d CorridorEvent(s) within 12 m of (0, -1.5) — the old one was 6.75 m ahead, "
			+ "i.e. 1.7 s of walking") % near_spawn)
		var ap = current_scene.get("_apparition")
		_ok("the apparition still exists (it was delayed, not deleted)", ap != null)
		var due: float = float(current_scene.get("_apparition_due"))
		_ok("its window opens well after the level starts", due >= EARLIEST_ALLOWED,
			"armed at %.1f s" % due)
		_ok("...and the window is a RANGE, not a constant",
			Vector2(current_scene.get("APPARITION_AT")).x
				< Vector2(current_scene.get("APPARITION_AT")).y,
			"APPARITION_AT %s — two runs must not agree"
				% str(current_scene.get("APPARITION_AT")))
		return false

	_t += delta
	if _fired_at < 0.0 and bool(_level.get("_apparition_fired")):
		_fired_at = float(_level.get("_apparition_clock"))
		_ok("it fires, and not before %.0f s" % EARLIEST_ALLOWED, _fired_at >= EARLIEST_ALLOWED,
			"fired at %.1f s of level time" % _fired_at)
		_ok("...and by the hard deadline", _fired_at <= DEADLINE,
			("fired at %.1f s — the beat teaches a rule the player is KILLED by later (the "
			+ "House cellar, the Backrooms Flood), so it may be delayed but never cancelled")
				% _fired_at)
		_finish()
		return true

	if _t > DEADLINE + 10.0:
		_ok("it fires at all", false,
			("nothing after %.0f s of level time — `_tick_apparition`'s deadline override is "
			+ "what stops the fairness gates cancelling the beat outright") % _t)
		_finish()
		return true
	return false


func _collect(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls or (n.get_script() != null
			and String(n.get_script().resource_path).get_file() == cls.to_snake_case() + ".gd"):
		out.append(n)
	for c in n.get_children():
		_collect(c, cls, out)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("== %d checks, %d failed ==" % [_checks, _fails.size()])
	for f in _fails:
		print("   FAILED: " + f)
	quit(1 if _fails.size() > 0 else 0)
