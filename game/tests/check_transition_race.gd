extends SceneTree

# A real E-ray / shared door races the real fatal Screamer in both orders. Delayed
# callbacks must not restart whichever scene happened to replace the dying one.
# Godot --headless --path game --script res://tests/check_transition_race.gd
# Runtime-loaded scripts are intentional: autoload names are unavailable at preload time.

const DEADLINE_MS := 45000
var _started_at := 0
var _started := false
var _finished := false
var _checks := 0
var _fails: Array[String] = []
var _gs: Node
var _screamer: Node
var _world: Node3D
var _player: CharacterBody3D
var _door: StaticBody3D


func _initialize() -> void:
	_started_at = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	# First, before stage guards: a parse failure or dead coroutine cannot pass silently.
	if not _finished and Time.get_ticks_msec() - _started_at > DEADLINE_MS:
		_ok("global timeout did not expire", false)
		_finish()
		return true
	if not _started:
		_started = true
		_run.call_deferred()
	return _finished


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	print("  %s %s%s" % ["PASS" if condition else "FAIL", label,
		" — " + detail if detail != "" else ""])
	if not condition:
		_fails.append(label)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _make_box(parent: Node3D, where: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = where
	body.add_child(shape)
	parent.add_child(body)
	return body


func _fixture(level: int, label: String, invalidate: bool = true,
		door_script_path: String = "res://scripts/door.gd") -> void:
	if invalidate:
		_gs.call("invalidate_transition")
	var previous := current_scene
	if previous != null:
		root.remove_child(previous)
		previous.queue_free()
	_world = Node3D.new()
	_world.name = label
	root.add_child(_world)
	current_scene = _world
	_gs.set("current_level", level)
	_gs.set("is_ending", false)
	_make_box(_world, Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	# Reuse the shipping scene's Player subtree; its level script never enters the tree.
	var packed := load("res://scenes/level_3.tscn") as PackedScene
	var source := packed.instantiate()
	_player = source.get_node("Player") as CharacterBody3D
	source.remove_child(_player)
	source.free()
	_player.position = Vector3(0, 0.1, 0)
	_player.rotation = Vector3.ZERO
	_player.set("ai_active", true)
	_world.add_child(_player)
	var door_script := load(door_script_path) as Script
	_door = _make_box(_world, Vector3(0, 1.3, -2), Vector3(1.2, 2.6, 0.2))
	_door.name = "ExitDoor"
	_door.set_script(door_script)
	await physics_frame
	await physics_frame
	_player.call("ai_look_at", _door.global_position)
	_player.force_update_transform()
	_player.get_node("Camera3D").force_update_transform()


func _attempts(level: int) -> int:
	return int(_gs.call("get_level_attempts", level))


func _run() -> void:
	_gs = root.get_node_or_null("GameState")
	_screamer = root.get_node_or_null("Screamer")
	_ok("shipping transition APIs are available", _gs != null and _screamer != null
		and _gs.has_method("begin_transition") and _gs.has_method("invalidate_transition")
		and _gs.has_method("transition_is_current"))
	if _fails.size() > 0:
		_finish()
		return
	_gs.get("level_attempts").clear()
	_gs.get("level_progress").clear()

	await _fixture(8, "DoorWins")
	_ok("shipping E ray reaches the exit", _player.call("ai_interact_target") == _door)
	_player.call("ai_interact")
	_player.call("ai_interact")
	# A different door must lose too; a guard on one door instance is insufficient.
	var other := _make_box(_world, Vector3(4, 1.3, -2), Vector3(1.2, 2.6, 0.2))
	other.set_script(load("res://scripts/door.gd"))
	other.call("interact")
	_screamer.call("trigger")
	_ok("accepted door rejects death before the black panel", not bool(_screamer.get("_is_triggering")))
	_ok("losing death leaves the player active", _player.process_mode != Node.PROCESS_MODE_DISABLED)
	await _wait(0.7)
	_ok("duplicate doors advance exactly once to the ending", int(_gs.get("current_level")) == 9
		and current_scene != null and current_scene.scene_file_path == "res://scenes/ending.tscn")
	await _wait(2.8)
	_ok("ending handoff survives the obsolete death delay", current_scene != null
		and current_scene.scene_file_path == "res://scenes/intro_room.tscn"
		and int(_gs.get("current_level")) == 0)
	_ok("door victory records no death on source, ending, or destination", _attempts(8) == 0
		and _attempts(9) == 0 and _attempts(0) == 0)

	await _fixture(0, "DeathWins")
	var death_scene_id := _world.get_instance_id()
	_screamer.call("trigger")
	_screamer.call("trigger")
	# Models another interaction already queued on the dying scene in the same frame.
	_door.call("interact")
	_ok("CONTROL: a death without a prior door really starts", bool(_screamer.get("_is_triggering")))
	_ok("winning death freezes the real player", _player.process_mode == Node.PROCESS_MODE_DISABLED)
	await _wait(0.7)
	_ok("a losing door cannot advance during death", current_scene != null
		and current_scene.get_instance_id() == death_scene_id and int(_gs.get("current_level")) == 0)
	await _wait(2.2)
	_ok("death reloads the intended level once", current_scene != null
		and current_scene.scene_file_path == "res://scenes/intro_room.tscn"
		and current_scene.get_instance_id() != death_scene_id and _attempts(0) == 1)
	_ok("death releases its overlay after restart", not bool(_screamer.get("_is_triggering"))
		and not bool(_screamer.get("_black_panel").visible))

	await _fixture(0, "StaleDeath")
	_screamer.call("trigger")
	await _wait(0.3)
	# Replace current_scene directly, without the GameState helper. Scene identity must
	# independently reject the autoload's pending coroutine when it eventually resumes.
	await _fixture(0, "ExternalReplacement", false)
	var replacement_id := _world.get_instance_id()
	await _wait(2.8)
	_ok("external scene replacement cancels the stale fatal restart", current_scene != null
		and current_scene.get_instance_id() == replacement_id and _attempts(0) == 1)
	_ok("stale death clears its obsolete overlay", not bool(_screamer.get("_is_triggering"))
		and not bool(_screamer.get("_black_panel").visible))

	await _fixture(0, "ExplicitReplacement")
	_screamer.call("trigger")
	await _wait(0.3)
	_gs.call("start_current_level")
	await _wait(0.4)
	var restarted_id := current_scene.get_instance_id() if current_scene != null else 0
	await _wait(2.5)
	_ok("start_current_level invalidates the pending fatal callback", restarted_id != 0
		and current_scene != null and current_scene.get_instance_id() == restarted_id
		and _attempts(0) == 1)

	await _fixture(0, "StaleDoor")
	_door.call("interact")
	await _fixture(0, "DoorReplacement", false)
	var door_replacement_id := _world.get_instance_id()
	await _wait(0.7)
	_ok("a delayed door cannot advance an externally replaced scene", current_scene.get_instance_id() == door_replacement_id
		and int(_gs.get("current_level")) == 0)

	# ⭐ THE VOID'S EXIT ASSEMBLES ITSELF FOR 1.2 s BEFORE IT OPENS (2026-09-20 pass 3), and an
	# animation is 1.2 s in which a panic death can land. `void_exit_door.gd:_open_door()` takes
	# the transition token FIRST and animates SECOND, so the press and the death race by the
	# same shared rule as every other door. Both orders are driven here through the real E ray.
	#
	# ⚠️ THE CONTROL FOR THIS IS THE ORDER ITSELF. With the token taken AFTER the animation, the
	# second case below goes red: the death wins, the level restarts, and 1.2 s later the door's
	# coroutine wakes on the RESTARTED scene, takes a fresh token of its own and sends a player
	# who just died to the ending. (Verified by hand on 2026-09-20 by moving `begin_transition`
	# below the animation, re-running this file, and seeing THREE of these go red.)
	await _fixture(8, "VoidDoorAssembling", true, "res://scripts/void_exit_door.gd")
	_ok("shipping E ray reaches the Void's assembling exit", _player.call("ai_interact_target") == _door)
	_player.call("ai_interact")
	await _wait(0.15)
	_ok("the press starts the assembly", bool(_door.call("is_assembling")))
	_screamer.call("trigger")
	_ok("a death DURING the assembly is refused — the door already owns the transition",
		not bool(_screamer.get("_is_triggering")))
	_ok("…and the level is still the one being left", current_scene != null
		and current_scene.name == "VoidDoorAssembling")
	await _wait(1.4)
	_ok("the assembly completes and the ending loads exactly once", int(_gs.get("current_level")) == 9
		and current_scene != null and current_scene.scene_file_path == "res://scenes/ending.tscn",
		"level %d, scene %s" % [int(_gs.get("current_level")),
			current_scene.scene_file_path if current_scene else "none"])
	_ok("a door that animated for 1.2 s still records no death", _attempts(8) == 0 and _attempts(9) == 0)
	await _wait(3.0)

	await _fixture(8, "VoidDeathFirst", true, "res://scripts/void_exit_door.gd")
	_gs.get("level_attempts").clear()
	var dying_id := _world.get_instance_id()
	_screamer.call("trigger")
	_player.call("ai_interact")
	_ok("CONTROL: the death really started", bool(_screamer.get("_is_triggering")))
	_ok("the exit refuses to assemble while a death owns the transition",
		not bool(_door.call("is_assembling")))
	await _wait(1.6)
	_ok("…and 1.2 s later the ending has still not loaded", current_scene != null
		and current_scene.get_instance_id() == dying_id and int(_gs.get("current_level")) == 8)
	await _wait(2.2)
	_ok("the death reloads the Void exactly once and never reaches the ending",
		current_scene != null and current_scene.scene_file_path == "res://scenes/level_3.tscn"
		and _attempts(8) == 1,
		"scene %s, attempts %d" % [current_scene.scene_file_path if current_scene else "none", _attempts(8)])

	await _fixture(0, "TokenLifetime")
	var token := int(_gs.call("begin_transition", "door"))
	_ok("a fresh scene can acquire a transition", token >= 0 and bool(_gs.call("transition_is_current", token)))
	_gs.call("go_to_main_menu")
	await _wait(0.3)
	_ok("menu navigation invalidates pending tokens", not bool(_gs.call("transition_is_current", token))
		and current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn")
	_ok("returning to menu retains the existing attempt-reset contract", _gs.get("level_attempts").is_empty())
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _checks < 28:
		_ok("at least 28 independent assertions ran", false, "only %d" % _checks)
	for failure in _fails:
		print("  FAILED: " + failure)
	print("TRANSITION-RACE %s: %d checks, %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size()])
	quit(0 if _fails.is_empty() else 1)
