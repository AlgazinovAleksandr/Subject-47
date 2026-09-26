extends SceneTree

# The intro is UNLOSEABLE BY CONSTRUCTION — the panic CEILING (2026-09-24, the Intake Wing).
#
# The intro used to be "unloseable" by the absence of panic sources, and it was not: sprint
# charges +6/s with decay suppressed and nothing exempted level 0, so ~8.3 s of Shift fired
# the screamer. check_intro_beats.gd could not see it because it never sprinted. The wing now
# lets panic MOVE (calibration teaches it) and `player.set_panic_ceiling(0.6)` pins it below
# PANIC_MAX. This proves the ceiling holds against the real input path, and that it is not
# vacuous: the sprint must actually reach the ceiling (≥ 0.55), or this proves nothing.
#
# Stages:
#   1. the real intro scene sets the ceiling (read back off the player)
#   2. 20 s of AI sprint on the shipping movement path: peak in [0.55, 0.60], no screamer,
#      the same scene instance still current
#   3. add_panic(PANIC_MAX) → exactly the ceiling, no screamer
#   4. CONTROL — with the ceiling lifted to 1.0, add_panic(0.9 × MAX) reads 0.9, i.e. the
#      clamp is the ceiling and not something else capping panic
#
#   Godot --headless --path game --script res://tests/check_intro_panic_ceiling.gd

const SPRINT_TIME := 20.0
const CEILING := 0.6

var _t := 0.0
var _stage := 0
var _stage_at := 0.0
var _fails: Array[String] = []
var _checks := 0
var _scene: Node = null
var _player: CharacterBody3D = null
var _peak := 0.0
var _screamed := false


func _initialize() -> void:
	change_scene_to_file("res://scenes/intro_room.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _advance(next: int) -> void:
	_stage = next
	_stage_at = _t


func _watch_screamer() -> void:
	var s := root.get_node_or_null("Screamer")
	if s and (bool(s.get("_is_triggering"))):
		_screamed = true


func _process(delta: float) -> bool:
	_t += delta
	if _scene == null:
		_scene = current_scene
		if _scene == null:
			return false
		_player = _scene.get_node_or_null("Player") as CharacterBody3D
		if _player == null:
			_ok("scene has a Player", false)
			return _finish()
		_advance(1)
		return false

	_watch_screamer()
	var el := _t - _stage_at
	match _stage:
		1:
			# Let the wake-up freeze release, or the sprint is (correctly) refused.
			if el < 3.5:
				return false
			_ok("the intro sets a panic ceiling of %.2f" % CEILING,
				is_equal_approx(float(_player.call("get_panic_ceiling")), CEILING),
				"got %.3f" % float(_player.call("get_panic_ceiling")))
			_player.set("_input_frozen", false)
			_player.ai_active = true
			_player.ai_sprint = true
			_player.ai_move_dir = Vector2(0, -1)
			_advance(2)
		2:
			# Sprint into whatever is ahead — a wall still counts as sprinting (direction != 0),
			# which is exactly the case a player holding Shift against a wall produces.
			_peak = maxf(_peak, _player.get_panic_ratio())
			if el < SPRINT_TIME:
				return false
			_player.ai_sprint = false
			_player.ai_move_dir = Vector2.ZERO
			_ok("20 s of sprint reaches the ceiling (not vacuous)", _peak >= CEILING - 0.05,
				"peak %.3f" % _peak)
			_ok("20 s of sprint never passes the ceiling", _peak <= CEILING + 0.001,
				"peak %.3f" % _peak)
			_ok("no screamer during the sprint", not _screamed)
			_ok("the intro scene is still the current scene", current_scene == _scene)
			_player.add_panic(50.0)
			_ok("add_panic(PANIC_MAX) lands exactly on the ceiling",
				is_equal_approx(_player.get_panic_ratio(), CEILING),
				"ratio %.3f" % _player.get_panic_ratio())
			_advance(3)
		3:
			if el < 0.3:
				return false
			_ok("no screamer after add_panic(PANIC_MAX)", not _screamed)
			_player.call("set_panic_ceiling", 1.0)
			_player.call("set_panic_ratio", 0.0)
			_player.add_panic(45.0)
			_ok("CONTROL: ceiling off → add_panic(0.9 × MAX) reads 0.9",
				is_equal_approx(_player.get_panic_ratio(), 0.9),
				"ratio %.3f" % _player.get_panic_ratio())
			_player.call("set_panic_ratio", 0.0)
			return _finish()
	return false


func _finish() -> bool:
	print("")
	if _fails.is_empty():
		print("INTRO PANIC CEILING PASS — %d checks" % _checks)
		quit(0)
	else:
		print("INTRO PANIC CEILING FAIL — %d/%d: %s" % [_fails.size(), _checks, ", ".join(_fails)])
		quit(1)
	return true
