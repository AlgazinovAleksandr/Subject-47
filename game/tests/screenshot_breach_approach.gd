extends SceneTree

# Render every approach beat (2026-09-23 redesign) for a human to READ as images.
# Needs a render target — run WITHOUT --headless:
#   Godot --path game --script res://tests/screenshot_breach_approach.gd [-- OUT_DIR]
#
# Staging, not asserting: the player is moved through the REAL trigger zones (so the beats fire
# through their own code) and the camera is aimed at each one. check_breach_approach.gd is the
# walk that proves order and timing; this proves what the beats LOOK like.
const SCENE := "res://scenes/level_6_breach.tscn"
var _out := "res://../backlogs/captures/breach-2026-09-23-approach/"
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


func _place(pos: Vector3, look: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.call("ai_look_at", look)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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


func _run() -> void:
	await _secs(1.5)
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_approach = _level.get("_approach")
	# 1. Room 1's lamp rhythm: walk the clusters on, then look back along the first leg.
	_place(Vector3(-97, 0.1, -68), Vector3(-80, 2.2, -68))
	await _secs(0.6)
	await _shot("01a_service_arrival_forward")
	for x in [-94.0, -89.0, -85.0, -82.0]:
		_place(Vector3(x, 0.1, -68), Vector3(x + 10, 1.75, -68))
		await _secs(0.35)
	_place(Vector3(-80.6, 0.1, -66.4), Vector3(-100, 2.4, -68.6))
	await _secs(0.5)
	await _shot("01b_service_lamp_rhythm_lookback")
	# 2. The self-waking lamp, ~20 m ahead down the jog, at its hold.
	_place(Vector3(-80, 0.1, -63.6), Vector3(-80, 1.75, -60))
	await _secs(0.3)
	_place(Vector3(-78.2, 0.1, -62), Vector3(-59, 2.6, -62))
	await _secs(0.9)
	await _shot("02a_self_waking_lamp_lit")
	await _secs(2.0)
	await _shot("02b_self_waking_lamp_dead")
	# The torn barrier tape, from the jog side where it can be read.
	_place(Vector3(-79.2, 0.1, -61.8), Vector3(-80, 0.9, -65))
	await _secs(0.3)
	await _shot("02c_barrier_tape_facing_inward")
	# 3. The door tell's dark phase in PumpReturn.
	_place(Vector3(-43, 0.1, -66.5), Vector3(-43, 1.75, -60))
	await _secs(0.2)
	_place(Vector3(-43, 0.1, -62.5), Vector3(-41, 2.0, -52))
	var t := 0.0
	while not _has("door_tell_dark") and t < 12.0:
		await _secs(0.05)
		t += 0.05
	await _secs(0.3)
	await _shot("03_door_tell_lamps_dipped")
	await _secs(1.2)
	# 4. Observation: pools and residue, the 98 % panel, the gouged cabinet, the shutter.
	_place(Vector3(-44.5, 0.1, -48), Vector3(-70, 1.2, -48))
	await _secs(0.4)
	await _shot("04a_observation_entry_seal98")
	_place(Vector3(-49.5, 0.1, -48.6), Vector3(-51, 1.6, -51))
	await _secs(0.3)
	await _shot("04b_seal_panel_98")
	# Both frames from in front of the bay B glass: the trigger fires on arrival, so the first
	# is the instant before the roll starts and the second is the shutter fully up.
	_place(Vector3(-63.0, 0.1, -47.6), Vector3(-62.4, 1.3, -38.2))
	await _secs(0.05)
	await _shot("05a_bay_b_shutter_closed")
	await _secs(3.2)
	await _shot("05b_bay_b_shutter_open")
	# ~6 m from the near edge of the -76 pool (its edge is at x -73): the distance the contract names
	_place(Vector3(-67.0, 0.1, -48.3), Vector3(-74.8, 0.1, -48.0))
	await _secs(1.2)
	await _shot("04c_residue_stops_at_light")
	_place(Vector3(-71.2, 0.1, -48.3), Vector3(-75.5, 0.0, -48.0))
	await _secs(0.3)
	await _shot("04d_residue_edge_closeup")
	_place(Vector3(-77.8, 0.1, -48.2), Vector3(-81.2, 1.1, -50.6))
	await _secs(0.3)
	await _shot("06_gouged_cabinet_tallies")
	# The services sign (A11) and the Damaged doorway lintel.
	_place(Vector3(-97, 0.1, -29.5), Vector3(-97, 2.0, -23.2))
	await _secs(0.3)
	await _shot("07a_services_sign")
	_place(Vector3(-97, 0.1, -26), Vector3(-80, 1.7, -26))
	await _secs(0.3)
	await _shot("07b_damaged_low_ceiling")
	# 5. It hears you: step on the grating, look up the duct for the knocks and the dust.
	_place(Vector3(-88, 0.1, -26), Vector3(-80, 1.9, -27.3))
	t = 0.0
	while not _has("duct_knocks") and t < 5.0:
		await _secs(0.05)
		t += 0.05
	await _secs(0.5)
	await _shot("08_duct_knocks_dust")
	await _secs(2.5)
	# 6. The porthole door in the Plenum, before and after the victim.
	_place(Vector3(-44.5, 0.1, -26.2), Vector3(-44.5, 1.4, -32.9))
	await _secs(0.4)
	await _shot("09a_porthole_door")
	_place(Vector3(-60.5, 0.1, -26), Vector3(-44.5, 1.4, -32.9))
	t = 0.0
	while not _has("victim_roar") and t < 10.0:
		await _secs(0.1)
		t += 0.1
	_place(Vector3(-44.5, 0.1, -28.8), Vector3(-44.5, 0.6, -32.9))
	await _secs(0.3)
	await _shot("09b_porthole_during_roar")
	t = 0.0
	while not _has("victim_drag") and t < 12.0:
		await _secs(0.1)
		t += 0.1
	await _secs(5.0)
	await _shot("09c_residue_grown_under_door")
	# 7. Object 12's breached cell.
	# from the west, the way the player comes: the hanging leaf's folded face and the punched plate
	_place(Vector3(-18.5, 0.1, -25.4), Vector3(-13.6, 1.8, -29.0))
	await _secs(0.4)
	await _shot("10a_cell_door_bent_outward")
	# from the east side: the lit cell through the part of the doorway the leaf no longer covers
	_place(Vector3(-11.8, 0.1, -24.2), Vector3(-13.5, 1.7, -29.5))
	await _secs(0.3)
	await _shot("10a2_cell_doorway_lit")
	# from the clear side of the doorway, past the hanging leaf, at the restraints and the pool
	_place(Vector3(-12.95, 0.1, -28.4), Vector3(-13.6, 1.1, -33.3))
	await _secs(0.3)
	await _shot("10b_inside_the_cell")
	_place(Vector3(-15.0, 0.1, -25.0), Vector3(0.0, 0.2, -24.0))
	await _secs(0.3)
	await _shot("10c_drag_marks_to_threshold")
	# 8. The glimpse: turn the corner, look up the Threshold, capture the hand at its peak.
	# 4.6 m from the hand, inside the 3–5 m window, looking at it
	_place(Vector3(0.2, 0.1, -20.6), Vector3(-2.15, 1.7, -16.5))
	t = 0.0
	while not _has("hand") and t < 20.0:
		await process_frame
		t += 1.0 / 60.0
	await _secs(0.05)
	await _shot("11a_hand_peak")
	await _secs(0.3)
	await _shot("11b_hand_withdrawing")
	await _secs(0.5)
	await _shot("11c_hand_gone")
	# One frame per height-step lintel, each seen from the taller room.
	for spec in [[Vector3(-43, 0.1, -60.5), Vector3(-43, 3.4, -65), "13a_lintel_pumpreturn_south"],
			[Vector3(-42.8, 0.1, -48), Vector3(-46, 3.6, -48), "13b_lintel_pumpreturn_west"],
			[Vector3(-31, 0.1, -25.5), Vector3(-26, 3.9, -26), "13c_lintel_plenum_east"],
			[Vector3(-0.4, 0.1, -27.3), Vector3(0, 2.8, -23), "13d_lintel_threshold"],
			[Vector3(-97, 0.1, -28.5), Vector3(-94, 2.9, -26), "13e_lintel_damaged_west"]]:
		_place(spec[0], spec[1])
		await _secs(0.3)
		await _shot(spec[2])
	# The wing sign beside the bulkhead (A11), before the seal.
	_place(Vector3(0.2, 0.1, -6.5), Vector3(1.98, 1.95, -3.18))
	await _secs(0.3)
	await _shot("12_containment_wing_sign")
	print("SCREENSHOTS %d -> %s" % [_shots.size(), _out])
	print("BEATS ", _approach.call("beat_names"))
	quit(0)
