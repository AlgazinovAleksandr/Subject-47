extends SceneTree

# Walk the shipping approach, cross its physical trigger, and push back against
# the bulkhead. No completion signal or level helper is invoked to reach the hunt.
const SCENE := "res://scenes/level_6_breach.tscn"
const OUT := "/tmp/breach_approach/"
var _level: Node
var _player: CharacterBody3D
var _creature: Node
var _approach: Node
var _fails := 0
var _checks := 0
var _started := 0
var _shots := false
var _walk_seconds := 0.0

func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_shots = OS.get_cmdline_user_args().has("--screenshots")
	change_scene_to_file(SCENE)
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 200000:
		print("FAIL approach test timed out")
		quit(1)
	return false

func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])

func _bind() -> void:
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_creature = _level.get("_creature")
	_approach = _level.get("_approach")

func _shot(label: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	root.get_texture().get_image().save_png(OUT + label + ".png")

func _walk(target: Vector3) -> void:
	var elapsed := 0.0
	while Vector2(_player.position.x - target.x, _player.position.z - target.z).length() > 0.3:
		_player.call("ai_look_at", Vector3(target.x, 1.75, target.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		var delta := 1.0 / Engine.physics_ticks_per_second
		elapsed += delta
		_walk_seconds += delta
		if elapsed > 23.0:
			_ok("walk reaches %s (stopped at %s)" % [target, _player.position], false)
			_player.set("ai_move_dir", Vector2.ZERO)
			return
	_player.set("ai_move_dir", Vector2.ZERO)
	await physics_frame
	_ok("physical route reaches %s" % target, true)

func _quiet() -> bool:
	var voice: Node = _level.get("_creature_voice")
	return not _creature.get("_active") and not _creature.get("_body").visible \
		and not voice.get("_voice").playing and not voice.get("_music").playing \
		and _level.get("_kill_sequence") == null

func _run() -> void:
	await create_timer(1.8).timeout
	_bind()
	var gs := root.get_node("GameState")
	var constants: Dictionary = _approach.get_script().get_script_constant_map()
	var start: Vector3 = constants["START_SPAWN"]
	_ok("first visit starts in the approach", _player.position.distance_to(start) < 0.3 and not _level.get("_approach_complete"))
	_ok("approach objective is distinct from flashlight search", "CONTAINMENT" in String(gs.get("current_objective")))
	_ok("torch remains missing", _player.get("_flashlight_locked") and not _player.call("is_flashlight_on"))
	_ok("creature is absent from view and silent", _quiet())
	await _shot("01_service_arrival")
	# Deliberately wait longer than the hunt grace. It must not run during the approach.
	await create_timer(8.2).timeout
	_ok("waiting in approach cannot activate the creature", _quiet() and is_zero_approx(float(_level.get("_familiarization_t"))))
	_level.call("_on_contact_death")
	_ok("approach cannot start Object12's kill presentation", _level.get("_kill_sequence") == null)
	# A death before the checkpoint must replay the approach.
	gs.call("restart_current_level")
	await create_timer(1.8).timeout
	_bind()
	_ok("pre-threshold death stays at approach entrance", not _level.get("_approach_complete") and _player.position.distance_to(start) < 0.3)
	var points: Array = constants["WALK_POINTS"]
	var index := 0
	for point in points:
		await _walk(point)
		index += 1
		if index < points.size():
			_ok("no creature throughout approach segment %d" % index, _quiet())
			_player.call("ai_look_at", points[index] + Vector3(0, 1.65, 0))
			await create_timer(0.1).timeout
			await _shot("route_%02d" % index)
	_ok("nonempty multi-room physical traversal", points.size() >= 7)
	print("APPROACH WALK GAME SECONDS %.2f" % _walk_seconds)
	_ok("walking time lies within agreed 60–90 seconds", _walk_seconds >= 60 and _walk_seconds <= 90)
	var machinery: Array = _approach.get("_beats")
	_ok("the walk encounters the environmental beats", machinery.size() >= 3 and machinery.all(func(beat): return beat.fired))
	_ok("machinery and darkness add no panic on the walk", is_zero_approx(float(_player.get("_panic"))))
	await create_timer(0.5).timeout
	_ok("walking across threshold begins the hunt", _level.get("_approach_complete") and _approach.get("completed"))
	_ok("threshold exposes dormant creature with full grace", _creature.get("_body").visible and not _creature.get("_active") and _level.get("_familiarization_t") < 2.0)
	_ok("search objective begins at the threshold", "FLASHLIGHT" in String(gs.get("current_objective")))
	_player.call("ai_look_at", Vector3(0, 1.4, -3))
	await _shot("02_bulkhead_sealed")
	_player.set("ai_move_dir", Vector2(0, -1))
	await create_timer(0.9).timeout
	_player.set("ai_move_dir", Vector2.ZERO)
	_ok("closed bulkhead physically stops retreat", _player.position.z > -2.8)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, -1), Vector3(0, 1.5, -5), 1)
	query.exclude = [_player.get_rid()]
	_ok("bulkhead blocks a real world ray", not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	# Live negative control: the shell opening must be open when this leaf is disabled.
	var blocker: CollisionShape3D = _approach.get("_gate_blocker")
	blocker.set_deferred("disabled", true)
	await physics_frame
	await physics_frame
	_ok("disabling gate removes the obstruction (positive control)", _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	blocker.set_deferred("disabled", false)
	await create_timer(7.1).timeout
	_ok("creature activates only after post-entry grace", _creature.get("_active"))
	_creature.set_process(false)
	gs.get("level_progress")[6] = _level.call("save_progress")
	change_scene_to_file(SCENE)
	await create_timer(1.8).timeout
	_bind()
	_ok("normal return retains sealed hunt checkpoint", _level.get("_approach_complete") and _approach.get("completed") and _player.position.z > -3)
	gs.call("restart_current_level")
	await create_timer(1.8).timeout
	_bind()
	_ok("death after entry skips approach", _level.get("_approach_complete") and _player.position.distance_to(Vector3(0, 0, -2)) < 0.3)
	_ok("hunt retry still resets flashlight", not _level.get("_flashlight_found") and _player.get("_flashlight_locked"))
	# The menu reset is the real new-run path: static scene state must not survive it.
	gs.call("go_to_main_menu")
	await create_timer(0.5).timeout
	change_scene_to_file(SCENE)
	await create_timer(1.8).timeout
	_bind()
	_ok("new run restores the entire approach", not _level.get("_approach_complete") and _player.position.distance_to(start) < 0.3 and _quiet())
	_ok("new run has no completed approach snapshot", not _level.call("save_progress")["approach_complete"])
	_ok("sample count is meaningful", _checks >= 30)
	print("BREACH APPROACH: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if _fails else 0)
