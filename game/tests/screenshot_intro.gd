extends SceneTree

# Dev tool: a photographed tour of the Intake Wing (2026-09-24) — cell wake, straps, sink and
# mirror, cell door, the dream corridor, the observation hall (the glass from both sides, WITH the
# occupant and after it has gone), the torch tray, the ward after the blackout, the lit ward and
# the airlock exit, SERIES D from the chair and the patient at the airlock hatch (2026-09-25). It
# drives the level's own beats (the torch KeyItem, the ward
# entry door, the stuck switch pressed `presses_needed` times) rather than faking their state, and
# prints a few physics-proof CHECK lines alongside the PNGs.
#
# Usage: Godot --path game --script res://tests/screenshot_intro.gd -- <out_dir>
# Needs a window (not --headless).

var _out := "/tmp/intro_shots/"
var _player: CharacterBody3D
var _room: Node3D
var _t := 0.0
var _i := 0
var _steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_out = args[0]
	if not _out.ends_with("/"):
		_out += "/"
	DirAccess.make_dir_recursive_absolute(_out)
	var gs := root.get_node_or_null("GameState")
	if gs:
		gs.set("intro_note_read", false)
		gs.set("is_ending", false)
	change_scene_to_file("res://scenes/intro_room.tscn")
	_steps = [
		# ⭐ No buckling (2026-09-25): lie → sit → stand in ~3.3 s, no input; VO1, then the door.
		[0.35, func(): _shot("01_cell_lying")],
		[1.6, func(): _shot("02_cell_sitting_up")],
		[1.7, func(): _shot("03_cell_standing")],
		[0.1, func(): _pose(Vector3(-5.2, 0, 21.4), 1.95, -0.55)],
		[0.4, func(): _shot("04_restraints_hanging_open")],
		[0.1, func(): _pose(Vector3(-5.45, 0, 22.9), -PI / 2.0, -0.05)],
		[5.5, func(): _shot("05_cell_door_open")],
		[0.1, func(): _pose(Vector3(-5.2, 0, 21.3), 1.9, -0.5)],
		[0.5, func(): _shot("06_bed_and_straps")],
		[0.1, func(): _pose(Vector3(-6.95, 0, 21.0), PI / 2.0, -0.35)],
		[0.5, func(): _shot("07_sink")],
		[0.1, func(): _use("Tap")],
		[1.2, func(): _shot("08_tap_rust")],
		[0.1, func(): _pose(Vector3(-7.45, 0, 22.0), 2.69, -0.35)],
		[0.5, func(): _shot("09_tally_bedside")],
		[0.1, func(): _pose(Vector3(-5.3, 0, 23.3), 0.27, -0.12)],
		[0.5, func(): _shot("10_glass_from_cell")],
		[0.1, func(): _pose(Vector3(-3.0, 0, 9.9), PI, -0.03)],
		[0.5, func(): _shot("11_corridor_north")],
		# Into the hall — the occupant appears the first time the body is 0.6 m inside.
		[0.1, func(): _pose(Vector3(-5.2, 0, 15.2), PI / 2.0, -0.05)],
		[0.5, func(): _pose(Vector3(-9.6, 0, 14.7), -2.45, -0.12)],
		[0.5, func(): _shot("12_hall_overview")],
		[0.1, func(): _pose(Vector3(-6.4, 0, 17.6), PI, -0.12)],
		[0.5, func(): _check_occupant("present")],
		[0.05, func(): _shot("13_glass_from_hall_occupied")],
		[0.1, func(): _measure_glass("13_glass_from_hall_occupied")],
		[0.1, func(): _pose(Vector3(-6.0, 0, 15.45), 0.0, -0.6)],
		[0.5, func(): _shot("14_torch_trolley")],
		[0.1, func(): _take_torch()],
		[0.1, func(): _pose(Vector3(-4.9, 0, 16.2), 2.0, -0.2)],
		[0.5, func(): _shot("15_torch_trolley_side")],
		[0.1, func(): _pose(Vector3(-3.0, 0, 15.0), PI, 0.0)],
		[0.4, func(): _check_occupant("gone")],
		[0.1, func(): _pose(Vector3(-3.0, 0, 10.8), 0.0, -0.05)],
		[0.3, func(): _use("WardEntryDoor")],
		[1.6, func(): _pose(Vector3(-3.0, 0, 8.2), 0.25, -0.1)],
		[0.5, func(): _shot("16_ward_blackout")],
		[0.1, func(): _flip_switch()],
		[3.0, func(): _pose(Vector3(-2.6, 0, 8.0), -0.25, -0.15)],
		[0.3, func(): _shot("17_ward_lit_from_entry")],
		[0.1, func(): _pose(Vector3(4.9, 0, -7.9), 2.55, -0.12)],
		[0.4, func(): _shot("18_ward_lit_from_back")],
		[0.1, func(): _pose(Vector3(2.4, 0, -1.2), 1.3, -0.15)],
		[0.4, func(): _shot("19_ward_left_wall")],
		[0.1, func(): _pose(Vector3(0.0, 0, 1.4), 0.0, -0.6)],
		[0.4, func(): _shot("20_note_table")],
		[0.1, func(): _pose(Vector3(-3.9, 0, -6.6), 0.0, -0.25)],
		[0.4, func(): _shot("21_ward_cabinets")],
		[0.1, func(): _pose(Vector3(1.2, 0, 4.2), PI - 0.1, -0.1)],
		[0.4, func(): _shot("22_ward_screen_chairs")],
		[0.1, func(): _read_note()],
		[0.2, func(): _pose(Vector3(0.0, 0, -10.2), 0.0, 0.0)],
		# VO3 (~3.5 s) then the projector.
		[4.4, func(): _pose(Vector3(-2.6, 0, -11.2), 2.8 - PI, -0.05)],
		[0.4, func(): _shot("23_calibration_chair_on_the_mark")],
		[0.1, func(): _pose(Vector3(-0.8, 0, -17.4), -0.6, -0.35)],
		[0.3, func(): _use("SubjectChair")],
		# Seated: pinned by the QTE, the look is free. Do NOT _pose() here — it would unseat you.
		[1.3, func(): _shot("24_seated_facing_screen")],
		[2.6, func(): _shot("25_seated_slide1")],
		[4.0, func(): _shot("26_seated_slide2_ward_photo")],
		[4.0, func(): _shot("27_seated_slide3_portrait")],
		# ⭐ SERIES D (fourth hand playtest, 2026-09-25): GOOD. keeps you seated; the projector comes
		# back 3.0 s later — title 2.5 s, then five figures at 1.6 s, each closer. Still seated.
		[0.1, func(): _room.call("_finish_gaze", "GOOD.")],
		[3.6, func(): _shot("28_series_d_title")],
		[2.6, func(): _shot("29_series_d_fig1_ward_end")],
		[1.6, func(): _shot("30_series_d_fig2_curtain")],
		[1.6, func(): _shot("31_series_d_fig3_bed")],
		[1.6, func(): _shot("32_series_d_fig4_glass")],
		[1.6, func(): _shot("33_series_d_fig5_lens")],
		[2.2, func(): _pose(Vector3(1.8, 0, -16.4), -0.84, -0.5)],
		[0.4, func(): _shot("34_forbidden_tray")],
		[0.1, func(): _pose(Vector3(0.0, 0, -17.2), 0.0, -0.5)],
		[0.3, func(): _shot("35_chair_and_dark_screen")],
		[0.1, func(): _room.call("_on_calibrated")],
		# ⭐ The patient at the hatch: from where you open the door, then closer, then the shutter.
		[0.1, func(): _pose(Vector3(-3.0, 0, -18.5), PI / 2.0, -0.02)],
		[0.3, func(): _use("AirlockDoor")],
		# slam + SCREAM at 0.35 s (one frame), the WORDS from ~2.8 s, dragged back ~5.2 s, shutter ~6.3 s
		[0.6, func(): _shot("36_hatch_from_the_doorway_scream")],
		[0.1, func(): _pose(Vector3(-5.0, 0, -18.5), PI / 2.0, -0.08)],
		[0.8, func(): _shot("37_hatch_close_scream")],
		[2.2, func(): _shot("38_hatch_close_words")],
		[1.75, func(): _shot("39_hatch_dragged_back")],
		[1.3, func(): _shot("40_hatch_shutter_down")],
		[0.1, func(): _pose(Vector3(-6.5, 0, -17.5), -0.4, -0.05)],
		[0.4, func(): _shot("41_airlock")],
	]


func _process(delta: float) -> bool:
	_t += delta
	if not _room:
		_room = current_scene
		return false
	if not _player:
		_player = _room.get_node_or_null("Player") as CharacterBody3D
		return false
	if _i >= _steps.size():
		print("TOUR DONE — %d steps" % _steps.size())
		return true
	var step: Array = _steps[_i]
	if _t < float(step[0]):
		return false
	_t = 0.0
	_i += 1
	(step[1] as Callable).call()
	return false


# ---------------------------------------------------------------- actions

func _pose(feet: Vector3, yaw: float, pitch: float) -> void:
	_player.set("_input_frozen", false)
	_player.global_position = feet + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = yaw
	_player.camera.position.y = 1.65
	_player.camera.rotation.x = pitch
	_player.set("_pitch", pitch)


func _use(n: String) -> void:
	var node := _room.get_node_or_null(n)
	if node and node.has_method("interact"):
		node.interact()
	else:
		print("CHECK use %s: FAIL — not found" % n)


func _take_torch() -> void:
	var t := _room.get_node_or_null("IssuedTorch")
	if t:
		t.interact()
	print("CHECK torch_taken: %s" % ("PASS" if t else "FAIL — no IssuedTorch"))


func _flip_switch() -> void:
	var sw := _room.get_node_or_null("LightSwitch")
	if sw:
		for _k in int(sw.get("presses_needed")):
			sw.interact()


func _check_occupant(want: String) -> void:
	var occ := _room.get_node_or_null("CellOccupant")
	var ok := (occ != null) == (want == "present")
	print("CHECK occupant %s: %s" % [want, "PASS" if ok else "FAIL"])


func _read_note() -> void:
	var n := _room.get_node_or_null("Note")
	if n:
		n.interact()
		root.get_node("NoteUI").call("_close")


# Glass contrast, measured in the shot just taken: the cell seen through the glass against the
# hall wall beside it (mean 0-255). The coordinator's floor is 5x.
func _measure_glass(shot_name: String) -> void:
	var img := Image.load_from_file(_out + shot_name + ".png")
	if img == null:
		return
	var w := img.get_width()
	var h := img.get_height()
	var inner := _mean(img, Rect2i(int(w * 0.34), int(h * 0.36), int(w * 0.26), int(h * 0.2)))
	var wall := _mean(img, Rect2i(int(w * 0.03), int(h * 0.22), int(w * 0.17), int(h * 0.28)))
	print("CHECK glass contrast: cell %.1f / hall wall %.1f = %.1fx (floor 5x) %s"
		% [inner, wall, inner / maxf(wall, 0.01), "PASS" if inner / maxf(wall, 0.01) >= 5.0 else "FAIL"])


func _mean(img: Image, r: Rect2i) -> float:
	var sum := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			sum += img.get_pixel(x, y).get_luminance() * 255.0
			n += 1
	return sum / maxf(n, 1)


func _shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(_out + shot_name + ".png")
	print("shot: ", shot_name, " @ ", _player.global_position if _player else "no player")
