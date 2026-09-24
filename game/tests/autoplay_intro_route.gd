extends SceneTree

# THE WHOLE INTRO, END TO END, ON THE SHIPPING PATHS — cell to the Lab's scene change.
#
# One driver, no teleports: the player WALKS every metre on ai_move_dir (move_and_slide, the real
# collision), turns with ai_look_at, and every door, strap, pickup, switch, note and exit goes
# through the real interact ray (ai_interact_target / ai_interact). The straps are released with
# `Input.action_press("interact")`, which is what the level's own poll reads while the player is
# frozen. The route is timed and logged; the report at the end gives the driven time per room and
# the total, plus an ESTIMATE for a human (reading, listening and looking time added per stop —
# the constants are named below so the estimate's assumptions are visible).
#
#   Godot --headless --path game --script res://tests/autoplay_intro_route.gd

const TIMEOUT := 420.0
const ARRIVE := 0.3
# Human-time assumptions (seconds), added to the driven time for the estimate only.
const HUMAN_READ_NOTE := 20.0          # per note opened
const HUMAN_NOTES := 5                 # wristband, file, log, the ward note, one ward find
const HUMAN_TAPE := 40.0               # SESSION 46, if they listen to it through
const HUMAN_LOOK_ROOM := 15.0          # per room, looking around before moving on
const HUMAN_ROOMS := 6
const HUMAN_DARK_FUMBLE := 25.0        # the blind walk to the switch is slower than a bot's line

var _t := 0.0
var _scene: Node = null
var _player: CharacterBody3D = null
var _steps: Array = []
var _i := 0
var _step_t := 0.0
var _log: Array = []
var _room_t := {}
var _last_mark := 0.0
var _last_room := "cell"
var _done := false
var _fails: Array[String] = []
var _press_frames := 0


func _initialize() -> void:
	var gs := root.get_node("GameState")
	gs.set("is_ending", false)
	gs.set("entered_from_ahead", false)
	gs.set("intro_note_read", false)
	gs.set("level_progress", {})
	gs.set("current_level", 0)
	change_scene_to_file("res://scenes/intro_room.tscn")
	_steps = [
		["strap", 0], ["strap", 1], ["strap", 2],
		["wait_until", "_cell_open"],
		["room", "corridor"],
		["go", Vector3(-4.8, 0, 22.2)], ["go", Vector3(-2.6, 0, 22.2)], ["go", Vector3(-2.6, 0, 15.0)],
		["use", "HallDoor", Vector3(0, 1.3, 0)], ["wait", 1.4],
		["room", "hall"],
		["go", Vector3(-4.7, 0, 15.0)], ["go", Vector3(-6.0, 0, 15.45)],
		["use", "IssuedTorch", Vector3.ZERO],
		["go", Vector3(-4.7, 0, 15.0)], ["go", Vector3(-2.6, 0, 15.0)], ["go", Vector3(-3.0, 0, 10.4)],
		["use", "WardEntryDoor", Vector3(0, 1.3, 0)], ["wait", 1.4],
		["room", "ward"],
		["go", Vector3(-3.0, 0, 8.0)], ["go", Vector3(-4.9, 0, -1.0)],
		["use", "LightSwitch", Vector3.ZERO], ["wait", 1.0], ["use", "LightSwitch", Vector3.ZERO], ["wait", 1.5],
		["go", Vector3(-1.2, 0, -0.2)], ["go", Vector3(0.0, 0, 1.0)],
		["read", "Note"],
		["go", Vector3(-1.2, 0, 1.0)], ["go", Vector3(-1.2, 0, -6.4)], ["go", Vector3(0.0, 0, -7.9)],
		["use", "WardDoor", Vector3(0, 1.3, 0)], ["wait", 1.4],
		["room", "calibration"],
		["go", Vector3(0.0, 0, -10.4)], ["go", Vector3(0.0, 0, -18.6)],
		["watch_screen"], ["look_away"],
		["wait_caption", "WALK TO THE LINE."],
		["go", Vector3(0.0, 0, -10.3)],
		["wait_until", "_airlock_open"],
		["go", Vector3(-3.0, 0, -18.5)],
		["use", "AirlockDoor", Vector3(0, 1.3, 0)], ["wait", 1.4],
		["room", "airlock"],
		["go", Vector3(-5.5, 0, -18.45)],
		["wait_until", "_exit_open"],
		["use", "ExitDoor", Vector3.ZERO],
		["wait_scene_change"],
	]


func _note(msg: String) -> void:
	var line := "[%6.1f s] %s" % [_t, msg]
	_log.append(line)
	print(line)


func _fail(msg: String) -> bool:
	_fails.append(msg)
	_note("FAIL " + msg)
	return _report()


func _cell_open() -> bool:
	return _scene.get_node("CellDoor").call("is_open") == true and not _player.is_input_frozen()


func _airlock_open() -> bool:
	return _scene.get_node("AirlockDoor").get("locked") == false


func _exit_open() -> bool:
	return _scene.get_node("ExitDoor").call("_is_unlocked") == true


func _clear_cam_yaw() -> void:
	var cam := _player.get_node("Camera3D") as Camera3D
	cam.rotation = Vector3(cam.rotation.x, 0.0, 0.0)


func _look(at: Vector3) -> void:
	_clear_cam_yaw()
	_player.ai_look_at(at)
	_player.set("_pitch", (_player.get_node("Camera3D") as Camera3D).rotation.x)


func _process(delta: float) -> bool:
	if _done:
		return true
	_t += delta
	if _scene == null:
		_scene = current_scene
		_player = _scene.get_node_or_null("Player") as CharacterBody3D if _scene else null
		_last_mark = _t
		return false
	if _press_frames > 0:
		_press_frames -= 1
		if _press_frames == 0:
			Input.action_release("interact")
	if _t > TIMEOUT:
		return _fail("timed out at step %d %s" % [_i, str(_steps[_i]) if _i < _steps.size() else ""])
	if _i >= _steps.size():
		return _report()
	var st: Array = _steps[_i]
	_step_t += delta
	match String(st[0]):
		"strap":
			var s: Node = _scene.get_node("Strap_%d" % int(st[1]))
			if _player.ai_interact_target() == s and _press_frames == 0:
				# The real key, through the level's own poll (player.gd ignores E while frozen).
				Input.action_press("interact")
				_press_frames = 2
				_next("strap %d released through the level's E poll" % int(st[1]))
			elif _step_t > 20.0:
				return _fail("strap %d never came under the crosshair" % int(st[1]))
		"wait_until":
			if bool(call(String(st[1]))):
				_next("%s" % st[1])
			elif _step_t > 30.0:
				return _fail("waited 30 s for %s" % st[1])
		"room":
			_room_t[_last_room] = _t - _last_mark
			_last_mark = _t
			_last_room = String(st[1])
			_next("-> %s" % st[1])
		"go":
			var target: Vector3 = st[1]
			var p := _player.global_position
			var flat := Vector2(target.x - p.x, target.z - p.z)
			if flat.length() < ARRIVE:
				_player.ai_move_dir = Vector2.ZERO
				_next("at %v" % target.snappedf(0.1))
			else:
				_clear_cam_yaw()
				_player.ai_active = true
				_player.ai_sprint = false
				_player.rotation.y = atan2(-flat.x, -flat.y)
				_player.ai_move_dir = Vector2(0, -1)
				if _step_t > 25.0:
					return _fail("stuck walking to %v at %v" % [target, p])
		"use":
			var node := _scene.get_node_or_null(String(st[1])) as Node3D
			if node == null:
				return _fail("no %s" % st[1])
			var aim: Vector3 = node.global_position + (st[2] as Vector3)
			_look(aim)
			var tgt: Node = _player.ai_interact_target()
			if tgt != null and (tgt == node or node.is_ancestor_of(tgt)):
				_player.ai_interact()
				_next("used %s" % st[1])
			elif _step_t > 2.0:
				return _fail("%s never answered the interact ray (target %s)" % [st[1], tgt.name if tgt else "nothing"])
		"read":
			var n := _scene.get_node(String(st[1])) as Node3D
			_look(n.global_position)
			if _player.ai_interact_target() == n:
				_player.ai_interact()
				root.get_node("NoteUI").call("_close")
				_next("read %s" % st[1])
			elif _step_t > 2.0:
				return _fail("the note never answered the interact ray")
		"watch_screen":
			var sp: Vector3 = _scene.get_script().get_script_constant_map()["SCREEN_POS"]
			_look(sp)
			if (_scene.get("_captions") as Array).has("LOOK AWAY."):
				_next("LOOK AWAY. at panic %.2f after watching %.1f s" % [_player.get_panic_ratio(), _step_t])
			elif _step_t > 60.0:
				return _fail("never told to look away")
		"look_away":
			_look(_player.global_position + Vector3(0, 1.5, 6.0))
			if (_scene.get("_captions") as Array).has("GOOD."):
				_next("GOOD. — looked away")
			elif _step_t > 6.0:
				return _fail("looking away was never acknowledged")
		"wait_caption":
			if (_scene.get("_captions") as Array).has(String(st[1])):
				_next("caption: %s" % st[1])
			elif _step_t > 15.0:
				return _fail("no caption %s" % st[1])
		"wait":
			if _step_t >= float(st[1]):
				_next("")
		"wait_scene_change":
			if current_scene != _scene and current_scene != null:
				_room_t[_last_room] = _t - _last_mark
				_note("SCENE CHANGE -> %s" % current_scene.scene_file_path)
				if not String(current_scene.scene_file_path).ends_with("level_1.tscn"):
					_fails.append("the exit led to %s, not the Lab" % current_scene.scene_file_path)
				return _report()
			elif _step_t > 10.0:
				return _fail("the exit never changed the scene")
	return false


func _next(msg: String) -> void:
	if msg != "":
		_note(msg)
	_i += 1
	_step_t = 0.0


func _report() -> bool:
	_done = true
	print("")
	print("--- INTRO ROUTE, driven ---")
	var total := 0.0
	for k in _room_t:
		print("  %-12s %6.1f s" % [k, float(_room_t[k])])
		total += float(_room_t[k])
	print("  %-12s %6.1f s  (%.1f min) driven, wall-clock of the game" % ["TOTAL", _t, _t / 60.0])
	var human := _t + HUMAN_READ_NOTE * HUMAN_NOTES + HUMAN_TAPE + HUMAN_LOOK_ROOM * HUMAN_ROOMS + HUMAN_DARK_FUMBLE
	print("  %-12s %6.1f s  (%.1f min) estimated for a human — +%d notes × %.0f s, the tape %.0f s,"
		% ["HUMAN est.", human, human / 60.0, HUMAN_NOTES, HUMAN_READ_NOTE, HUMAN_TAPE]
		+ " %d rooms × %.0f s looking, %.0f s of dark fumble" % [HUMAN_ROOMS, HUMAN_LOOK_ROOM, HUMAN_DARK_FUMBLE])
	if _fails.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for f in _fails:
			print("  FAIL: " + f)
		print("RESULT: FAIL")
		quit(1)
	return true
