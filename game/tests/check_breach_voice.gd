extends SceneTree

# Stateful audio + visible door motion. -- --screenshots also records the rendered impact.
var _fails := 0
var _checks := 0
var _started := 0
var _shots := false

func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_shots = OS.get_cmdline_user_args().has("--screenshots")
	change_scene_to_file("res://scenes/level_6_breach.tscn")
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 30000:
		print("FAIL voice test timeout")
		quit(1)
	return false

func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])

func _shot(label: String) -> void:
	if _shots:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("/tmp/breach_sep20")
		root.get_texture().get_image().save_png("/tmp/breach_sep20/" + label + ".png")

func _capture(bus_name: String) -> AudioEffectCapture:
	var index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(index, bus_name)
	var effect := AudioEffectCapture.new()
	effect.buffer_length = 1.0
	AudioServer.add_bus_effect(index, effect)
	return effect

func _rms(effect: AudioEffectCapture) -> float:
	var data := effect.get_buffer(effect.get_frames_available())
	var energy := 0.0
	for sample in data:
		energy += sample.length_squared()
	return sqrt(energy / maxf(1.0, data.size() * 2.0))

func _run() -> void:
	await create_timer(1.8).timeout
	var level: Node = current_scene
	level.set_process(false)
	var creature: Node = level.get("_creature")
	creature.set_process(false)
	creature.call("_ensure_player")
	var player: CharacterBody3D = level.get_node("Player")
	player.set("ai_active", true)
	var voice: Node = level.get("_creature_voice")
	voice.set_process(false)
	var speaker: AudioStreamPlayer3D = voice.get("_voice")
	var music: AudioStreamPlayer = voice.get("_music")
	var voice_capture := _capture("BreachVoiceTest")
	var music_capture := _capture("BreachMusicTest")
	speaker.bus = "BreachVoiceTest"
	music.bus = "BreachMusicTest"
	var clips: Dictionary = voice.get("_streams")
	_ok("all three clips imported and distinct", clips.size() == 3 and clips.values()[0] != clips.values()[1] and clips.values()[1] != clips.values()[2])
	for kind in clips:
		_ok("%s has actual non-looping audio" % kind, clips[kind] is AudioStreamWAV and clips[kind].get_length() > 1.0 and clips[kind].loop_mode == AudioStreamWAV.LOOP_DISABLED)
	_ok("supplied chase recording replaces prototype", clips["chase"].resource_path.ends_with("breach_voice_scream_chase.wav") and clips["chase"].get_length() > 4.0)
	_ok("supplied batter and search recordings loaded", clips["batter"].get_length() > 6.0 and clips["search"].get_length() > 4.5)
	_ok("background is stereo with a complete loop", music.stream is AudioStreamWAV and music.stream.stereo and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and absf(music.stream.loop_end / float(music.stream.mix_rate) - music.stream.get_length()) < 0.01)
	voice.call("_process", 0.1)
	_ok("dormant creature stays silent", not speaker.playing and not music.playing)
	player.global_position = Vector3(0, 0.1, 9.3)
	var body: Node3D = creature.get("_body")
	body.global_position = Vector3(0, 0, 12.8)
	creature.call("activate")
	creature.call("force_chase")
	voice.call("_process", 0.1)
	_ok("chase starts chase voice", speaker.playing and speaker.stream == clips["chase"])
	_ok("chase starts both layers together", speaker.playing and music.playing)
	await create_timer(0.65).timeout
	var voice_rms := _rms(voice_capture)
	var music_rms := _rms(music_capture)
	print("CHASE MIX RMS voice=%.5f music=%.5f" % [voice_rms, music_rms])
	_ok("both chase layers produce decoded audio", voice_rms > 0.001 and music_rms > 0.001)
	_ok("music and scream both contribute to the mix", absf(linear_to_db(voice_rms / maxf(music_rms, 0.000001))) < 18.0)
	var calls: int = voice.get("_plays")["chase"]
	var music_position := music.get_playback_position()
	voice.call("_process", 0.1)
	_ok("a chase frame cannot restart the scream", voice.get("_plays")["chase"] == calls)
	_ok("a chase frame cannot restart the music", music.get_playback_position() >= music_position - 0.05)
	music.seek(music.stream.get_length() - 0.2)
	await create_timer(0.45).timeout
	_ok("background actually wraps across its loop", music.playing and music.get_playback_position() < 1.0)
	speaker.seek(speaker.stream.get_length() - 0.1)
	await create_timer(0.3).timeout
	voice.call("_process", 0.3)
	_ok("music continues through the gap after a scream", music.playing and not speaker.playing and voice.get("_plays")["chase"] == calls)
	creature.call("_enter", 3)
	voice.call("_process", 0.1)
	_ok("losing chase stops both layers", not music.playing and not speaker.playing)
	creature.call("force_chase")
	voice.call("_process", 0.1)
	_ok("renewed chase restarts both layers", music.playing and speaker.playing)
	body.global_position.z += 0.2
	voice.call("_process", 0.1)
	_ok("voice follows real body", speaker.global_position.distance_to(body.global_position + Vector3(0, 1.4, 0)) < 0.01)
	var door: Node3D = level.get("_slam_doors")[0]
	player.call("ai_look_at", door.global_position + Vector3(0, 1.2, 0))
	await physics_frame
	_ok("player ray finds door", player.call("ai_interact_target") == door)
	player.call("ai_interact")
	await create_timer(0.25).timeout
	await _shot("door_voice_rest")
	level.call("_tick_slam_doors")
	var hinge: Node3D = door.get("_hinge")
	var rest := hinge.position
	var blocker: Node3D = door.get("_block_body")
	var block_rest := blocker.global_transform
	voice.call("_process", 0.05)
	_ok("door battering stops the chase background", not music.playing)
	var peak_motion := 0.0
	var heard_together := false
	for frame in range(10):
		await process_frame
		heard_together = heard_together or (speaker.playing and speaker.stream == clips["batter"] and door.get("_batter_audio").playing)
		peak_motion = maxf(peak_motion, hinge.position.distance_to(rest))
		if peak_motion > 0.025:
			await _shot("door_voice_impact")
			break
	_ok("roar and thud play together", heard_together)
	_ok("impact visibly displaces the leaf", peak_motion > 0.025)
	_ok("impact does not displace collider", blocker.global_transform == block_rest)
	await create_timer(0.3).timeout
	_ok("leaf settles between blows", hinge.position.distance_to(rest) < 0.005)
	# The actual door clock reaches its silence boundary; don't emit its signal by hand.
	door.set("_batter_t", 1.21)
	await create_timer(0.05).timeout
	voice.call("_process", 0.05)
	_ok("supernatural silence cuts roar, music and thuds", not speaker.playing and not music.playing and not door.get("_batter_audio").playing)
	_ok("silence settles the visual recoil", hinge.position.distance_to(rest) < 0.005)
	door.call("force_open")
	creature.set("_block_t", 0.0)
	creature.call("_enter", 4)
	voice.call("_process", 0.1)
	_ok("stagger suppresses both layers", not speaker.playing and not music.playing)
	var spot: Node3D
	for child in level.get_children():
		if child.has_method("hide_anchor"):
			spot = child
			break
	player.call("enter_hiding", spot)
	creature.call("_enter", 2)
	creature.call("_process", 0.016)
	var target: Vector3 = creature.get("_last_seen_pos")
	voice.call("_process", 2.0)
	_ok("hidden player hears searching howl", speaker.playing and speaker.stream == clips["search"])
	_ok("hiding cannot leave chase music playing", not music.playing)
	var search_gap: float = voice.get("_cooldown") - speaker.stream.get_length() / speaker.pitch_scale
	_ok("searching leaves a gap after the supplied long howl", search_gap >= 5.0 and search_gap <= 8.0)
	_ok("howl cannot reveal hidden coordinates", creature.get("_last_seen_pos") == target and target.distance_to(player.global_position) >= 10.0)
	var state: int = creature.call("get_state")
	var old_panic: float = player.get("_panic")
	voice.call("_process", 0.1)
	_ok("voice changes neither AI state nor panic", creature.call("get_state") == state and player.get("_panic") == old_panic)
	body.global_position += Vector3(12, 0, 0)
	voice.call("_process", 0.016)
	_ok("relocation cuts continuous panning", not speaker.playing and voice.get("_cooldown") > 0.0)
	voice.call("_process", 3.0)
	_ok("search voice resumes after relocation gap", speaker.playing and speaker.stream == clips["search"])
	creature.call("freeze_for_purge")
	voice.call("_process", 0.1)
	_ok("purge silences both layers", not speaker.playing and not music.playing)
	creature.call("unfreeze_for_purge")
	player.call("exit_hiding")
	creature.call("force_chase")
	voice.call("_process", 2.0)
	_ok("chase after leaving cover restores both layers", speaker.playing and music.playing)
	# Exercise the actual fatal transition; invalidate before its awaited restart.
	root.get_node("/root/Screamer").call("trigger")
	voice.call("_process", 0.1)
	_ok("player death stops both chase layers", not speaker.playing and not music.playing)
	root.get_node("/root/GameState").call("invalidate_transition")
	await create_timer(0.3).timeout
	creature.call("lure_into_trap")
	voice.call("_process", 0.1)
	_ok("defeated creature cannot play either layer", not speaker.playing and not music.playing)
	_ok("all three voice modes actually played", voice.get("_plays")["chase"] > 0 and voice.get("_plays")["batter"] > 0 and voice.get("_plays")["search"] > 0)
	level.queue_free()
	await process_frame
	await process_frame
	_ok("scene removal frees both audio players", not is_instance_valid(speaker) and not is_instance_valid(music))
	_ok("sample size", _checks >= 40)
	print("BREACH VOICE: %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails else 0)
