extends SceneTree

var _fails := 0
var _checks := 0
var _shots := false
var _start := 0

func _capture(bus_name: String) -> AudioEffectCapture:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	var effect := AudioEffectCapture.new()
	effect.buffer_length = 3.0
	AudioServer.add_bus_effect(index, effect)
	return effect

func _levels(effect: AudioEffectCapture) -> Vector3:
	var data := effect.get_buffer(effect.get_frames_available())
	var energy := 0.0
	var peak := 0.0
	for sample in data:
		energy += sample.length_squared()
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return Vector3(sqrt(energy / maxf(1.0, data.size() * 2.0)), peak, data.size())

func _initialize() -> void:
	_shots = OS.get_cmdline_user_args().has("--screenshots")
	_start = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/level_6_breach.tscn")
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start > 30000:
		print("FAIL kill sequence timed out")
		quit(1)
	return false

func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])

func _shot(name: String) -> void:
	if _shots:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("/tmp/breach_attack")
		root.get_texture().get_image().save_png("/tmp/breach_attack/" + name + ".png")

func _run() -> void:
	await create_timer(1.8).timeout
	var level: Node = current_scene
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(level)
	level.set_process(false)
	var player: CharacterBody3D = level.get_node("Player")
	player.set("ai_active", true)
	var creature: Node = level.get("_creature")
	creature.set_process(false)
	creature.call("_ensure_player")
	var body: Node3D = creature.get("_body")
	var door: Node3D = level.get("_slam_doors")[0]
	player.global_position = Vector3(0, 0.1, 10.6)
	body.global_position = Vector3(0, 0, 11.3)
	creature.call("activate")
	creature.call("force_chase")
	door.call("interact")
	await create_timer(0.25).timeout
	creature.call("_check_contact")
	_ok("closed door blocks a kill inside contact radius", level.get("_kill_sequence") == null and not player.call("is_input_frozen"))
	door.call("interact")
	await create_timer(0.25).timeout
	player.global_position = Vector3(0, 0.1, 21)
	body.global_position = Vector3(0, 0, 23)
	await physics_frame
	creature.call("_check_contact")
	_ok("approach outside contact range cannot start a kill", level.get("_kill_sequence") == null)
	body.global_position = Vector3(0, 0, 21.7)
	player.call("ai_look_at", body.global_position + Vector3(0, 1.5, 0))
	creature.call("activate")
	creature.call("force_chase")
	await physics_frame
	# Cover is safe even inside the contact radius.
	player.set("_hidden", true)
	creature.call("_check_contact")
	_ok("hidden contact cannot start a kill", level.get("_kill_sequence") == null)
	player.set("_hidden", false)
	var master_capture := _capture("Master") # after the real output limiter
	var voice_capture := _capture("BreachKillTest")
	# Drive confirmed contact, not the presentation helper.
	creature.call("_check_contact")
	var kill: Node = level.get("_kill_sequence")
	_ok("confirmed contact starts a rigged kill", is_instance_valid(kill))
	if kill == null:
		quit(1)
		return
	var scream: AudioStreamPlayer = kill.get("_voice")
	_ok("contact uses the requested kill recording", scream.stream.resource_path == "res://assets/audio/level_6_breach/level_6_jumpscare.wav")
	_ok("kill scream routes directly to Master", scream.bus == "Master")
	scream.bus = "BreachKillTest" # unity tap, same Master send
	_ok("player is frozen only after contact", player.call("is_input_frozen"))
	var token: int = kill.get("_token")
	_ok("death reserves scene ownership before animation", root.get_node("GameState").call("transition_is_current", token))
	level.call("_on_contact_death")
	_ok("duplicate contact cannot spawn another kill", level.get("_kill_sequence") == kill)
	root.get_node("Screamer").call("trigger")
	_ok("competing panic death cannot interrupt the attack", not root.get_node("Screamer").get("_is_triggering"))
	_ok("actual creature model and skin used", kill.get("rig").model() == "hollow_crown" and kill.get("rig").mesh_instances()[0].material_override == creature.get("_material"))
	var voice: Node = level.get("_creature_voice")
	voice.call("_process", 0.1)
	_ok("chase music and calls stop for the kill", not voice.get("_music").playing and not voice.get("_voice").playing)
	var cam: Camera3D = player.get_node("Camera3D")
	_ok("attack mesh belongs to a visible camera layer", (kill.get("rig").mesh_instances()[0].layers & cam.cull_mask) != 0)
	_ok("HUD is hidden during the attack", not player.get("_panic_hud").visible and not player.get_node("InteractUI").visible)
	var first_fov := cam.fov
	var actor: Node3D = kill.get("actor")
	var first_position := actor.position
	var skel: Skeleton3D = kill.get("rig").skeleton()
	var hand := skel.find_bone("LeftHand")
	var first_hand := skel.get_bone_global_pose(hand).origin
	await _shot("00_surge_start")
	await create_timer(0.35).timeout
	var scream_levels := _levels(voice_capture)
	print("KILL SCREAM RMS=%.5f peak=%.5f samples=%d ambience=%.1fdB" % [scream_levels.x, scream_levels.y, scream_levels.z, AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))])
	_ok("kill recording remains audible during ambience dip", scream_levels.z > 2000 and scream_levels.x > 0.15 and AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")) < -20.0)
	_ok("model surges toward the lens", actor.position.z > first_position.z + 0.25)
	_ok("camera framing animates", absf(cam.fov - first_fov) > 3.0)
	_ok("claws animate on the skeleton", skel.get_bone_global_pose(hand).origin.distance_to(first_hand) > 0.08)
	await _shot("01_claws")
	while kill.get("elapsed") < 0.50:
		await process_frame
	_ok("first impact fires", kill.get("impacts") == 1)
	_ok("matching artwork is shown at impact", kill.get("_insert").visible and kill.get("_insert").texture != null)
	await _shot("02_impact_art")
	while kill.get("elapsed") < 0.76:
		await process_frame
	_ok("impact artwork gives way to moving rig", not kill.get("_insert").visible)
	await _shot("03_recoil")
	while kill.get("elapsed") < 1.05:
		await process_frame
	_ok("second impact fires", kill.get("impacts") == 2)
	await _shot("04_second_impact")
	while not kill.get("finished"):
		await process_frame
	var output := _levels(master_capture)
	print("KILL MASTER RMS=%.5f peak=%.5f samples=%d" % [output.x, output.y, output.z])
	_ok("complete kill mix has decoded audio and no clipped output", output.z > 20000 and output.x > 0.1 and output.y <= 0.95)
	var scr := root.get_node("Screamer")
	_ok("animation enters fatal funnel", scr.get("_is_triggering"))
	_ok("blackout has no static face", scr.get("_black_panel").visible and not scr.get("_screamer_image").visible)
	_ok("attack sound and art stop on blackout", not kill.get("_voice").playing and not kill.get("_overlay").visible)
	await _shot("05_black")
	await create_timer(0.3).timeout
	_ok("static face stays disabled after black hold", not scr.get("_screamer_image").visible)
	_ok("no second unrelated scream after the impacts", not scr.get("_audio").playing)
	var old_id := level.get_instance_id()
	await create_timer(2.5).timeout
	_ok("fatal funnel restarts Breach", current_scene != null and current_scene.get_instance_id() != old_id and current_scene.scene_file_path.ends_with("level_6_breach.tscn"))
	_ok("old kill rig is freed on restart", not is_instance_valid(kill))
	_ok("new player regains input", not current_scene.get_node("Player").call("is_input_frozen"))
	# Explicit navigation during another wind-up must cancel its future death callback.
	current_scene.call("_on_contact_death")
	var cancelled: Node = current_scene.get("_kill_sequence")
	_ok("cancellation control has a live attack", is_instance_valid(cancelled))
	var state := root.get_node("GameState")
	var attempts: int = state.call("get_level_attempts", 6)
	state.call("start_current_level")
	await process_frame
	await process_frame
	var replacement := current_scene.get_instance_id()
	await create_timer(1.9).timeout
	_ok("old attack is freed when navigating", not is_instance_valid(cancelled))
	_ok("stale attack cannot restart the replacement scene", current_scene.get_instance_id() == replacement and not scr.get("_is_triggering"))
	_ok("cancelled attack cannot count an extra death", state.call("get_level_attempts", 6) == attempts)
	print("BREACH KILL: %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails else 0)
