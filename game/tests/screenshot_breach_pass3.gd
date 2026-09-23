extends SceneTree

# Render the Breach approach's pass 3 (2026-09-23) for a human to READ as images. Needs a render
# target — run WITHOUT --headless:
#   Godot --path game --script res://tests/screenshot_breach_pass3.gd [-- OUT_DIR]
#
# Staging, not asserting: the player is placed and aimed, but every beat fires through its own code —
# the door tell through its trigger, the technician and the wheel through `ai_interact()` and pushed
# mouse motion. check_breach_porthole.gd and check_breach_approach.gd are what prove the behaviour.
const SCENE := "res://scenes/level_6_breach.tscn"
var _out := "res://../backlogs/captures/breach-2026-09-23-pass3/"
var _level: Node
var _player: CharacterBody3D
var _approach: Node
var _shots: Array[String] = []
var _th := 0.0


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


# ⚠️ REAL time, never a frame count: at 120 fps a "16 s" frame-counted limit expired after 8 s,
# before the victim's drag, and the technician was then pressed while still refusing.
func _wait_beat(beat: String, limit: float) -> void:
	var start := Time.get_ticks_msec()
	while not _has(beat) and Time.get_ticks_msec() - start < limit * 1000.0:
		await process_frame


func _circle(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var dt := 1.0 / 60.0
		var w := TAU * 0.7
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(-sin(_th), cos(_th)) * 60.0 * w * dt
		root.push_input(mm)
		_th += w * dt
		await process_frame
		t += dt


func _run() -> void:
	await _secs(1.6)
	_bind()
	# ---- 1. the grille, the door tell, three-quarter view (the route's own angle, slowed down)
	_place(Vector3(-42.9, 0.1, -57.0), Vector3(-38.3, 1.5, -53.8))
	await _wait_beat("door_tell_grille_batter", 5.0)
	await _secs(0.3)
	await _shot("01a_grille_mid_batter_raised")
	await _secs(0.3)
	await _shot("01b_grille_mid_batter_impact")
	await _secs(2.55)
	await _shot("01c_grille_still_in_the_silence")
	await _secs(0.45)
	await _shot("01d_grille_lamps_dead")
	await _wait_beat("door_tell_grille_gone", 3.0)
	await _secs(0.3)
	await _shot("01e_grille_empty_door_broken")
	# frontal, close: what the slats are
	_place(Vector3(-41.3, 0.1, -55.1), Vector3(-40.0, 1.7, -55.0))
	await _secs(0.3)
	await _shot("01f_grille_closeup_slats")
	# a second run for the oblique walking view, mid-batter
	change_scene_to_file(SCENE)
	await _secs(1.6)
	_bind()
	_place(Vector3(-43.2, 0.1, -60.0), Vector3(-39.6, 1.6, -54.6))
	await _wait_beat("door_tell_grille_batter", 5.0)
	await _secs(0.85)
	await _shot("01g_grille_from_the_lane_mid_batter")
	await _secs(4.0)
	# ---- 2. the blocked doorway, both sides
	_place(Vector3(-31.5, 0.1, -26.4), Vector3(-26.0, 1.4, -26.0))
	await _secs(0.4)
	await _shot("02a_blocked_doorway_plenum_side")
	_place(Vector3(-20.5, 0.1, -25.4), Vector3(-26.0, 1.3, -26.0))
	await _secs(0.3)
	await _shot("02b_blocked_doorway_containment_side")
	# ---- 3. the porthole door and the technician: the victim must be heard out first
	_place(Vector3(-60.5, 0.1, -26.0), Vector3(-44.5, 1.4, -32.9))
	await _wait_beat("victim", 4.0)
	_place(Vector3(-44.5, 0.1, -28.4), Vector3(-45.3, 1.0, -33.0))
	await _secs(0.4)
	await _shot("03a_porthole_door_and_technician")
	await _wait_beat("victim_drag", 25.0)
	_place(Vector3(-45.85, 0.1, -31.15), Vector3(-46.62, 0.85, -32.25))
	var start := Time.get_ticks_msec()
	while _player.call("ai_interact_target") == null and Time.get_ticks_msec() - start < 12000:
		await process_frame
	await _shot("03b_technician_eyes_closed")
	_player.call("ai_interact")
	await _secs(0.75)
	await _shot("03c_technician_eyes_open")
	await _secs(1.2)
	await _shot("03d_technician_whispering")
	await _wait_beat("technician_eyes_closed", 5.0)
	await _secs(0.3)
	await _shot("03e_technician_eyes_closed_again_handle_gone")
	# ---- 4. the wheel
	_place(Vector3(-44.5, 0.1, -31.3), Vector3(-44.5, 1.05, -32.87))
	await _secs(0.2)
	_player.call("ai_interact")
	await _circle(3.0)
	await _shot("04a_wheel_mid_turn")
	var guard := 0.0
	while not _approach.get("porthole_open") and guard < 25.0:
		await _circle(0.25)
		guard += 0.25
	await _secs(1.6)
	_place(Vector3(-44.2, 0.1, -30.2), Vector3(-44.8, 1.2, -34.5))
	await _shot("04b_porthole_heaving_open")
	await _secs(2.6)
	await _shot("04c_porthole_open_dark_beyond")
	# ---- 5. the dark room: spark snapshots from three places, and one in the dark
	var light: OmniLight3D = _approach.call("spark_light")
	var views := [[Vector3(-44.0, 0.1, -34.4), Vector3(-38.6, 0.8, -39.3), "05a_dark_room_spark_chair_from_the_door"],
		[Vector3(-41.5, 0.1, -36.8), Vector3(-45.6, 1.1, -39.6), "05b_dark_room_spark_vials"],
		[Vector3(-34.2, 0.1, -36.4), Vector3(-37.4, 1.2, -42.6), "05c_dark_room_spark_trolley_and_box"]]
	for v in views:
		_place(v[0], v[1])
		var t0 := Time.get_ticks_msec()
		while light.visible and Time.get_ticks_msec() - t0 < 3000:
			await process_frame
		await _shot(String(v[2]).replace("spark", "unlit"))
		t0 = Time.get_ticks_msec()
		while not light.visible and Time.get_ticks_msec() - t0 < 6000:
			await process_frame
		await _shot(v[2])
	# ---- 6. the cell chamber
	_place(Vector3(-19.4, 0.1, -36.6), Vector3(-13.0, 0.9, -33.6))
	await _secs(1.0)
	await _shot("06a_cell_chamber_from_the_passage")
	_place(Vector3(-15.4, 0.1, -33.8), Vector3(-17.6, 0.95, -29.55))
	await _secs(0.8)
	await _shot("06b_cctv_monitor_and_guard")
	_place(Vector3(-17.2, 0.1, -30.6), Vector3(-17.55, 1.0, -29.55))
	await _secs(0.5)
	await _shot("06c_cctv_screen_closeup")
	_place(Vector3(-14.8, 0.1, -30.4), Vector3(-16.8, 0.0, -32.5))
	await _secs(0.3)
	await _shot("06d_body_facedown_in_the_glass")
	# the breached tank itself, from just inside the chamber entrance, and closer, at its burst front
	_place(Vector3(-19.2, 0.1, -35.9), Vector3(-11.2, 1.2, -34.8))
	await _secs(0.4)
	await _shot("06e_breached_tank_from_the_entrance")
	_place(Vector3(-15.2, 0.1, -34.4), Vector3(-11.0, 1.3, -34.8))
	await _secs(0.3)
	await _shot("06f_breached_tank_front")
	print("SCREENSHOTS %d -> %s" % [_shots.size(), _out])
	print("BEATS ", _approach.call("beat_names"))
	quit(0)
