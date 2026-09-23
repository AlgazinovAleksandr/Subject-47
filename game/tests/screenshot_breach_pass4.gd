extends SceneTree

# Render the Breach approach's pass 4 (2026-09-23) for a human to READ as images. Needs a render
# target — run WITHOUT --headless:
#   Godot --path game --script res://tests/screenshot_breach_pass4.gd [-- OUT_DIR]
#
# Staging, not asserting: the player is placed and aimed, and every beat fires through its own code —
# the shutter through its looked-at cycle, the drop through its position trigger, the technician
# through `ai_interact()`, the seal race through a HELD interact action. check_breach_pass4.gd,
# check_breach_porthole.gd and check_breach_seal_race.gd are what prove the behaviour.
const SCENE := "res://scenes/level_6_breach.tscn"
var _out := "res://../backlogs/captures/breach-2026-09-23-pass4/"
var _level: Node
var _player: CharacterBody3D
var _approach: Node
var _shots: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_out = ProjectSettings.globalize_path(_out)
	if not _out.ends_with("/"):
		_out += "/"
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file(SCENE)
	_run.call_deferred()


func _bind() -> void:
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_approach = _level.get("_approach")


func _place(pos: Vector3, look: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.call("ai_look_at", look)


func _secs(s: float) -> void:
	await create_timer(s).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out + label + ".png"
	root.get_texture().get_image().save_png(path)
	_shots.append(path)
	print("shot: ", path)


func _has(beat: String) -> bool:
	return Array(_approach.call("beat_names")).has(beat)


func _wait_beat(beat: String, limit: float) -> void:
	var start := Time.get_ticks_msec()
	while not _has(beat) and Time.get_ticks_msec() - start < limit * 1000.0:
		await process_frame


func _wait_until(cond: Callable, limit: float) -> void:
	var start := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - start < limit * 1000.0:
		await process_frame


func _run() -> void:
	await _secs(1.6)
	_bind()
	# ---- 1. the shutter: an empty cycle, then the face on a looked-at one
	var niche: Vector3 = _approach.get("_niche_centre")
	_place(Vector3(-60.5, 0.1, -48.0), niche)
	await _wait_beat("shutter", 2.0)
	await _secs(1.2)
	await _shot("01a_shutter_rolling_up_first_cycle")
	await _secs(2.4)
	await _shot("01b_shutter_open_EMPTY_first_cycle")
	await _wait_beat("shutter_face", 30.0)
	await _secs(3.1)
	await _shot("01c_shutter_open_FACE_from_the_corridor")
	# closer, at the glass, during the 2.5 s hold (the corridor view is where a player stands)
	_place(Vector3(-62.4, 0.1, -46.0), niche)
	await _secs(0.5)
	await _shot("01d_shutter_FACE_at_the_glass")
	await _secs(1.4)
	await _shot("01e_shutter_rolling_down_over_it")
	await _wait_beat("shutter_face_gone", 6.0)
	await _secs(0.2)
	await _shot("01f_shutter_down_face_gone")
	# ---- 2. the ceiling drop: crossing x -9.2 in Containment, looking down the lane
	_place(Vector3(-11.5, 0.1, -26.0), Vector3(-2.0, 1.6, -26.0))
	await _secs(0.5)
	await _shot("02a_containment_before_the_drop_hatch_shut")
	_place(Vector3(-9.1, 0.1, -26.0), Vector3(-4.0, 1.5, -25.6))
	await _wait_beat("ceiling_drop", 2.0)
	await _secs(0.12)
	await _shot("02b_drop_mid_fall")
	await _secs(0.35)
	await _shot("02c_drop_chain_snaps_taut")
	await _secs(0.9)
	await _shot("02d_drop_mid_swing")
	await _secs(1.4)
	await _shot("02e_drop_twisting")
	_place(Vector3(-8.6, 0.1, -26.1), Vector3(-6.9, 1.2, -24.8))
	await _secs(0.4)
	await _shot("02f_drop_close_cocoon_and_arm")
	_place(Vector3(-4.2, 0.1, -26.3), Vector3(-6.9, 1.3, -25.0))
	await _secs(0.4)
	await _shot("02g_drop_from_past_it_lane_clear")
	await _secs(12.0)
	_place(Vector3(-9.8, 0.1, -26.2), Vector3(-6.9, 1.3, -24.9))
	await _secs(0.4)
	await _shot("02h_drop_settled")
	# ---- 3. the fused technician (a fresh run), and the porthole door's bare spindle first
	change_scene_to_file(SCENE)
	await _secs(1.6)
	_bind()
	_place(Vector3(-44.5, 0.1, -31.0), Vector3(-44.5, 1.05, -32.9))
	await _secs(0.5)
	await _shot("05a_porthole_door_BARE_SPINDLE")
	var tech: Node3D = _approach.get_node("DeadTechnician")
	var head: Vector3 = _approach.get("_tech_head")
	var chest := (_approach.get("_tech_wheel") as Node3D).global_position
	_place(Vector3(-36.0, 0.1, -27.0), chest + Vector3(0, 0.1, 0))
	await _secs(0.5)
	await _shot("03a_fused_technician_across_the_plenum_8m")
	_place(tech.to_global(Vector3(0.6, 0.1, 4.0)), chest + Vector3(0, 0.15, 0))
	await _secs(0.4)
	await _shot("03b_fused_technician_4m")
	var stop: Vector3 = _approach.get_script().get_script_constant_map()["TECH_STOP"]
	_place(stop, head + Vector3(0, -0.3, 0))
	# entering the Plenum starts the victim beat behind the porthole door (12.3 s), and he keeps silent
	# until the story channel is idle: wait for his prompt, as a player would
	await _wait_until(func(): return _player.call("ai_interact_target") != null, 25.0)
	var near := tech.to_global(Vector3(0.15, 0.1, 1.5))
	_place(near, head + Vector3(0, -0.35, 0))
	await _secs(0.4)
	await _shot("03c_fused_technician_1p5m_eyes_CLOSED_wheel_on_chest")
	_place(near, head)
	await _secs(0.3)
	await _shot("03d_fused_face_1p5m_eyes_CLOSED")
	# SIDE VIEWS: 45° and near-grazing along the wall — does he have real depth and cast shadows?
	_place(tech.to_global(Vector3(-1.25, 0.1, 1.25)), tech.to_global(Vector3(0.0, 1.2, 0.1)))
	await _secs(0.3)
	await _shot("03i_fused_technician_45deg")
	_place(tech.to_global(Vector3(-1.7, 0.1, 0.42)), tech.to_global(Vector3(0.0, 1.2, 0.08)))
	await _secs(0.3)
	await _shot("03j_fused_technician_grazing")
	_place(stop, head)
	await _secs(0.2)
	_player.call("ai_interact")
	await _secs(0.3)
	_place(near, head)
	await _secs(0.5)
	await _shot("03e_fused_face_1p5m_eyes_OPEN")
	_place(near, head + Vector3(0, -0.3, 0))
	await _secs(0.4)
	await _shot("03f_fused_technician_1p5m_eyes_OPEN_grip")
	await _wait_beat("technician_eyes_closed", 6.0)
	await _secs(0.3)
	await _shot("03g_fused_technician_eyes_closed_wheel_gone")
	_place(tech.to_global(Vector3(-0.9, 0.1, 1.2)), chest)
	await _secs(0.3)
	await _shot("03h_fused_technician_45deg_wheel_gone")
	# ---- 5b. the wheel fitted on the door
	_place(Vector3(-44.5, 0.1, -31.2), Vector3(-44.5, 1.05, -32.87))
	await _secs(0.3)
	_player.call("ai_interact")
	await _secs(0.4)
	await _shot("05b_porthole_door_WHEEL_FITTED")
	_player.call("ai_interact")    # let go
	await _secs(0.2)
	# ---- 4. the seal race, mid-close, from ArchiveC (the hunt, the creature lured deep)
	change_scene_to_file(SCENE)
	await _secs(1.6)
	_bind()
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(_level)
	var creature: Node = _level.get("_creature")
	var purge: Node = _level.get("_purge_chamber")
	_player.call("lock_flashlight")
	_place(Vector3(-7.0, 0.1, 45.6), Vector3(-7.0, 1.2, 50.0))
	creature.call("set_present", true)
	creature.call("place_body", Vector3(-7.0, 0.0, 53.2), Vector3(-7.0, 0.0, 40.0))
	creature.call("activate")
	await _secs(0.2)
	creature.call("place_body", Vector3(-7.0, 0.0, 53.2), Vector3(-7.0, 0.0, 40.0))
	_place(Vector3(-7.0, 0.1, 46.4), Vector3(-7.0, 1.3, 50.0))
	await physics_frame
	await physics_frame
	Input.action_press("interact")
	_player.call("_try_interact")
	await _secs(0.4)
	await _shot("04a_seal_race_grinding_shut_creature_frozen")
	await _secs(0.5)
	await _shot("04b_seal_race_creature_charging")
	await _wait_until(func(): return purge.get("_used") == true, 2.0)
	Input.action_release("interact")
	await _secs(0.2)
	await _shot("04c_seal_race_shut")
	print("RACE LOG ", purge.get("race_log"))
	print("SCREENSHOTS %d -> %s" % [_shots.size(), _out])
	quit(0)
