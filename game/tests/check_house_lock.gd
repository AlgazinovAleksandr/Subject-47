extends SceneTree

# H4 (2026-09-13, capture #10): the correct code makes the lock FALL off the exit door and go,
# and the door asks "ARE YOU SURE YOU WANT TO GO IN THERE?" in blood. Zero panic.
#
#   Godot --headless --path game --script res://tests/check_house_lock.gd
#
# The beat is wired to `CombinationLock.unlocked`, so it is driven by emitting that signal on the
# real lock node (the dial UI itself is `check_lock_input.gd`'s business).

var _fails := 0
var _checks := 0
var _t := 0.0
var _phase := 0
var _level: Node = null
var _lock: Node = null
var _door: Node3D = null
var _seen_scrawl := false
var _panic0 := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _scrawl_on_screen() -> bool:
	for n in root.get_children():
		for c in n.get_children():
			if c is Label and (c as Label).text.contains("ARE YOU SURE"):
				return true
	return false


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	_t += delta
	match _phase:
		0:
			if _t < 0.8:
				return false
			_level = current_scene
			_door = _level.get_node_or_null("ExitDoor")
			_lock = _door.get_node_or_null("ExitLock") if _door else null
			_ok("the exit door carries the lock as ExitLock", _lock != null)
			if _lock == null:
				return _done()
			_ok("the lock is wired to the level", _lock.is_connected("unlocked", Callable(_level, "_on_exit_lock_unlocked")))
			_ok("the lock answers the interact ray before the code", int(_lock.get("collision_layer")) != 0)
			var p := _level.get_node("Player")
			_panic0 = float(p.call("get_panic_ratio"))
			_lock.emit_signal("unlocked")
			_t = 0.0
			_phase = 1
		1:
			if _scrawl_on_screen():
				_seen_scrawl = true
			if _t > 0.35 and is_instance_valid(_lock):
				_ok("the lock is falling (it moved down and stopped answering the ray)",
					(_lock as Node3D).position.y < -0.35 - 0.05 and int(_lock.get("collision_layer")) == 0,
					"y %.2f" % (_lock as Node3D).position.y)
				_phase = 2
			elif _t > 0.35:
				_ok("the lock is falling (it moved down and stopped answering the ray)", false, "already gone")
				_phase = 2
		2:
			if _scrawl_on_screen():
				_seen_scrawl = true
			if _t > 1.5:
				_ok("the lock is GONE within 1.5 s", not is_instance_valid(_lock))
				_ok("the door asked: ARE YOU SURE YOU WANT TO GO IN THERE?", _seen_scrawl)
				var p := _level.get_node("Player")
				_ok("zero panic", absf(float(p.call("get_panic_ratio")) - _panic0) < 0.001)
				_ok("the exit door itself is still there", is_instance_valid(_door))
				return _done()
	return false


func _done() -> bool:
	print("  %d checks, %d failed" % [_checks, _fails])
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true
