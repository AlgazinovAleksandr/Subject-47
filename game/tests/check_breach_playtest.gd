extends SceneTree

# Real E-ray, physics collision and timed presentation; -- --screenshots renders evidence.
# Legacy policy is a live positive control for hidden-coordinate leakage on every run.
var _level: Node
var _player: CharacterBody3D
var _creature: Node
var _fails := 0
var _checks := 0
var _shots := false
var _started := 0
const OUT := "/tmp/breach_sep20/"

func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_shots = OS.get_cmdline_user_args().has("--screenshots")
	seed(2047)
	change_scene_to_file("res://scenes/level_6_breach.tscn")
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 60000:
		print("FAIL: playtest harness timeout")
		quit(1)
	return false

func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])

func _shot(label: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	# SlamDoor's clearance fitting runs at 1.5 s; photograph the settled geometry.
	await _wait(1.8)
	_level = current_scene
	_level.set_process(false)
	_creature = _level.get("_creature")
	_creature.set_process(false)
	_player = _level.get_node("Player")
	# This harness exercises the existing post-recovery torch/door/hiding mechanics.
	_level.call("_recover_flashlight", false)
	_player.get("flashlight").visible = true
	_player.set("ai_active", true)
	_creature.call("_ensure_player")
	DirAccess.make_dir_recursive_absolute(OUT)
	await _visuals()
	await _doors()
	await _hiding()
	_cleanup()
	_ok("session stayed in original scene", current_scene == _level)
	_ok("nonempty assertion sample", _checks >= 25)
	print("BREACH PLAYTEST: %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails else 0)

func _visuals() -> void:
	_player.global_position = Vector3(0, 0.1, 10)
	_player.call("ai_look_at", Vector3(0, 1.0, 14))
	await _wait(0.3)
	var mat: StandardMaterial3D = _creature.get("_material")
	_ok("skin texture retained", mat.albedo_texture != null)
	_ok("normal detail generated", mat.normal_enabled and mat.normal_texture.get_image() != null)
	_ok("varied roughness generated", mat.roughness_texture != null and mat.roughness_texture.get_image() != null)
	await _shot("creature_after")
	if _shots:
		var normal := mat.normal_enabled
		var rough := mat.roughness_texture
		mat.normal_enabled = false
		mat.roughness_texture = null
		mat.roughness = 0.9
		mat.metallic_specular = 0.2
		mat.emission_energy_multiplier = 0.12
		await _wait(0.1)
		await _shot("creature_before")
		mat.normal_enabled = normal
		mat.roughness_texture = rough
		mat.roughness = 0.72
		mat.metallic_specular = 0.55
		mat.emission_energy_multiplier = 0.025

func _blocked(door: Node3D) -> bool:
	var from := door.global_position + Vector3(0, 1.0, -0.5)
	var to := door.global_position + Vector3(0, 1.0, 0.5)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [_player.get_rid()]
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _doors() -> void:
	var doors: Array = _level.get("_slam_doors")
	_ok("six doors sampled", doors.size() == 6)
	var door: Node3D = doors[0]
	var director: Node = _level.get("_door_scare")
	_player.global_position = Vector3(0, 0.1, 9.3)
	_player.call("ai_look_at", door.global_position + Vector3(0, 1.3, 0))
	await _wait(0.2)
	_ok("real E-ray reaches door", _player.call("ai_interact_target") == door)
	_player.call("ai_interact")
	await physics_frame
	_ok("closed door physically blocks", _blocked(door))
	var body: Node3D = _creature.get("_body")
	body.global_position = Vector3(0, 0, 12.8)
	_creature.call("activate")
	_creature.call("_enter", 3)
	_creature.set("_last_seen_pos", _player.global_position)
	_level.call("_tick_slam_doors")
	_ok("path starts battering", door.get("_battering"))
	var duration: float = door.get("_batter_t")
	_ok("duration is 4–6 seconds", duration >= 4.0 and duration <= 6.0)
	var torch: SpotLight3D = _player.get("flashlight")
	var mask := torch.light_cull_mask
	var bed: AudioStreamPlayer = _level.get_node("AmbientPlayer")
	var volume := bed.volume_db
	var stages := {}
	var elapsed := 0.0
	while door.get("_battering") and elapsed < 7.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		var dark: bool = director.call("torch_is_interrupted")
		var quiet: bool = door.get("_silenced")
		var stage := "blackout" if dark else ("silence" if quiet else "pounding")
		if not stages.has(stage):
			stages[stage] = true
			await _shot("door_" + stage)
			if stage == "silence":
				_ok("both visible leaves stay closed", absf(door.get("_hinge").rotation.y) < 0.01 and absf(door.get("_hinge_r").rotation.y) < 0.01)
				_ok("pounding stops during silent tail", not door.get("_batter_audio").playing)
				_ok("ambience drops before lights", bed.volume_db <= volume - 30.0 and torch.light_cull_mask == mask)
			elif stage == "blackout":
				_ok("torch illuminates no surfaces in blackout", torch.light_cull_mask == 0)
				_ok("nearby lamps are extinguished", director.get("_lamp_visibility").size() > 0)
				_ok("player retains movement", not _player.get("_input_frozen"))
	await physics_frame
	_ok("all three phases actually sampled", stages.size() == 3)
	_ok("physical opening arrives within six seconds", elapsed <= 6.2 and not _blocked(door))
	_ok("torch and bed restore at breach", torch.light_cull_mask == mask and is_equal_approx(bed.volume_db, volume))
	await _shot("door_broken")
	# Composition: two simultaneous quiet tails must not restore one another's darkness.
	for d in [doors[0], doors[1]]:
		d.set("_battering", true)
		d.set("_batter_t", 0.7)
		d.set_process(false)
		director.call("_silenced", d)
	var spot: Node3D
	for child in _level.get_children():
		if child.has_method("hide_anchor"):
			spot = child
			break
	var original_energy: float = _player.get("_flash_base_energy")
	_player.call("enter_hiding", spot)
	var dimmed_energy: float = _player.get("_flash_base_energy")
	_ok("hiding during darkness still dims torch", dimmed_energy < original_energy)
	_player.get("flashlight").visible = false # player's F-off choice during the blackout
	# End the farther door first: entering this locker moves us just outside its 10 m radius.
	director.call("_ended", doors[1])
	_ok("overlapping blackout survives one ending", torch.light_cull_mask == 0)
	director.call("_ended", doors[0])
	_ok("F-off and hiding energy survive restoration", not torch.visible and _player.get("_flash_base_energy") == dimmed_energy and torch.light_cull_mask == mask)
	_player.call("exit_hiding")
	_ok("leaving hiding restores original energy", _player.get("_flash_base_energy") == original_energy)
	for d in [doors[0], doors[1]]:
		d.set("_battering", false)
		d.set_process(true)
	# Defaults are a live counterexample: non-Breach doors keep 10 s / no interruption.
	var legacy: Node3D = load("res://scripts/slam_door.gd").new()
	_level.add_child(legacy)
	legacy.call("slam_shut")
	legacy.call("start_battering", null)
	legacy.call("_process", 6.1)
	_ok("legacy door still closed after 6 seconds", legacy.call("is_closed") and not legacy.get("_silenced"))
	legacy.queue_free()
	_creature.set("_block_t", 0.0)
	_creature.set("_active", false)
	torch.visible = true

func _hiding() -> void:
	var spot: Node3D
	for child in _level.get_children():
		if child.has_method("hide_anchor"):
			spot = child
			break
	_ok("hiding spot exists", spot != null)
	_player.global_position = spot.global_position + spot.global_transform.basis.z * 1.1 + Vector3(0, 0.1, 0)
	_player.call("ai_look_at", spot.global_position + Vector3(0, 1.2, 0))
	await _wait(0.2)
	_ok("real E-ray reaches locker", _player.call("ai_interact_target") == spot)
	_player.call("ai_interact")
	_ok("E hides player", _player.call("is_hidden"))
	var body: Node3D = _creature.get("_body")
	body.global_position = Vector3(0, 0, 9)
	_creature.call("activate")
	_creature.call("_enter", 2)
	_creature.set("_last_seen_pos", _player.global_position)
	if OS.get_cmdline_user_args().has("--legacy-hiding"):
		_creature.set("forget_hidden_player", false)
	_creature.call("_process", 0.016)
	_ok("hiding immediately leaves chase", _creature.call("get_state") != 2)
	_ok("hidden location cleared from memory", _creature.get("_last_seen_pos").distance_to(_player.global_position) >= 10.0)
	var away := true
	var seen_room: int = _creature.call("_room_at", _player.global_position)
	var destinations := {}
	var relocations := 0
	for i in range(12):
		body.global_position = Vector3(-7, 0, 22)
		var before := body.global_position
		_creature.call("_relocate_near_player")
		if before.distance_to(body.global_position) > 3.0:
			relocations += 1
		var target: Vector3 = _creature.get("_last_seen_pos")
		destinations[target] = true
		away = away and target.distance_to(_player.global_position) >= 10.0
		away = away and int(_creature.call("_room_at", target)) != seen_room
	_ok("12 hidden searches never target the cabinet", away)
	_ok("random wandering visits multiple destinations", destinations.size() >= 3)
	_ok("unseen relocations actually exercised", relocations >= 3)
	_ok("hidden player not detected", not _creature.call("_detect_player"))
	# Drive two minutes of state transitions and motion, not only destination selection.
	var walked := 0.0
	var leaks := 0
	var jumps := 0
	for i in range(1200):
		var before := body.global_position
		_creature.call("_process", 0.1)
		var step := before.distance_to(body.global_position)
		if step > 3.0:
			jumps += 1
		else:
			walked += step
		if _creature.get("_last_seen_pos").distance_to(_player.global_position) < 10.0:
			leaks += 1
	_ok("120 s hidden hunt walks and relocates", walked > 30.0 and jumps >= 3)
	_ok("120 s hidden hunt has no coordinate leaks", leaks == 0)
	# A watched departure must stay continuous rather than visibly popping out.
	body.global_position = _player.global_position + Vector3(-0.5, 0, 0)
	_player.call("ai_look_at", body.global_position + Vector3(0, 0.9, 0))
	await physics_frame
	var visible: bool = _creature.call("_visible_to_player", body.global_position)
	var watched_pos := body.global_position
	_creature.call("_relocate_near_player")
	_ok("visible departure control is actually visible", visible)
	_ok("watched creature cannot teleport away", body.global_position.is_equal_approx(watched_pos))
	# Counterexample: old policy MUST reproduce exact hidden coordinate leakage.
	_creature.set("forget_hidden_player", false)
	body.global_position = Vector3(0, 0, 58)
	var relocated: bool = _creature.call("_relocate_near_player")
	_ok("legacy control reproduces hidden target leakage", relocated and _creature.get("_last_seen_pos").is_equal_approx(_player.global_position))
	_creature.set("forget_hidden_player", true)
	_player.call("ai_interact")
	_ok("E exits cover", not _player.call("is_hidden"))
	_player.global_position = Vector3(0, 0.1, 22)
	body.global_position = Vector3(0, 0, 19)
	body.rotation.y = 0
	await physics_frame
	_ok("exposed player detectable again", _creature.call("_detect_player"))

func _cleanup() -> void:
	var director: Node = _level.get("_door_scare")
	var door: Node3D = _level.get("_slam_doors")[1]
	var torch: SpotLight3D = _player.get("flashlight")
	var mask := torch.light_cull_mask
	var bed: AudioStreamPlayer = _level.get_node("AmbientPlayer")
	var volume := bed.volume_db
	door.set("_battering", true)
	door.set("_batter_t", 0.7)
	director.call("_silenced", door)
	_ok("cleanup control starts dark and quiet", torch.light_cull_mask == 0 and bed.volume_db < volume)
	_level.remove_child(director)
	_ok("scene removal restores lights and audio", torch.light_cull_mask == mask and is_equal_approx(bed.volume_db, volume))
	director.free()
