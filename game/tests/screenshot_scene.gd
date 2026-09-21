extends SceneTree

# Dev tool: drop the player camera at fixed vantage points in a level and dump
# screenshots, so visual fixes can be checked without hand-playing.
#
# Run (note: NO --headless, it needs a render target):
#   Godot --path game --script res://tests/screenshot_scene.gd -- <scene_name>
# e.g. ... -- level_1     ... -- intro_room     ... -- level_2_1
#
# Shots are [feet_position, look_at_target, name] and, optionally, a fourth element: the name
# of a one-shot ACTION to run on the level before the shot (2026-09-20 pass 3). Several things
# worth photographing do not exist until the level has been played into a state — a seated
# keystone, an open drawer, the exit door assembled — and a screenshot of the state nobody can
# see is the one that has to be read. See `_action()`.

const OUT := "/tmp/shots/"

const SHOTS := {
	"intro_room": [
		[Vector3(0, 0, 0.5), Vector3(-2.5, 2.9, -2.5), "intro_web_back_left"],
		[Vector3(0, 0, 0.5), Vector3(2.5, 2.9, -2.5), "intro_web_back_right"],
		[Vector3(0, 0, -0.5), Vector3(0, 2.9, 0), "intro_ceiling_up"],
	],
	"level_1": [
		[Vector3(-3.5, 0, -2.4), Vector3(-3.5, 0.85, -4.55), "lab_bench_cluster"],
		[Vector3(-3.9, 0, -3.2), Vector3(-4.4, 0.95, -4.55), "lab_monitor"],
		[Vector3(-2.9, 0, -3.4), Vector3(-2.6, 0.82, -4.55), "lab_tray_keycard"],
		[Vector3(-3.5, 0, 2.9), Vector3(-3.5, 0.9, 0.9), "lab_exam_note3"],
		[Vector3(0.4, 0, -1.1), Vector3(1.49, 1.5, -1.1), "lab_note1_wall"],
		[Vector3(-0.4, 0, -1.0), Vector3(-1.49, 1.5, -1.0), "lab_note2_wall"],
	],
	"level_2_1": [
		# The rebuilt beartrap (BACKLOG #18), in the cellar where one actually sits.
		# Two angles on purpose: a floor prop looks passable from directly above and
		# gives itself away at a shallow angle, which is the angle you meet it at.
		[Vector3(6.5, -1.5, -4.0), Vector3(6.5, -1.35, -5.5), "beartrap_approach"],
		[Vector3(7.6, -1.5, -4.6), Vector3(6.5, -1.42, -5.5), "beartrap_angle"],
		[Vector3(-0.8, 0, 5.8), Vector3(-0.8, 1.6, 7.96), "house_window_forest"],
		[Vector3(0.6, 0, 6.4), Vector3(-0.8, 1.6, 7.96), "house_window_angle"],
		[Vector3(-0.7, 0, 16.5), Vector3(-0.7, 0.9, 18.9), "house_lock_on_door"],
		[Vector3(-0.7, 0, 15.5), Vector3(-0.7, 1.2, 18.9), "house_exit_door_wide"],
	],
	"level_3": [
		[Vector3(0, 0, -2), Vector3(0, 1.4, 8.0), "void_quiet_threshold"],
		# 2026-09-20: the fractured doors — the back door behind the spawn, the exit from the Sanctum.
		[Vector3(0, 0, -1.2), Vector3(0, 1.1, -4.0), "void_back_door"],
		[Vector3(-14, 0, 22.6), Vector3(-14, 1.1, 19.5), "void_exit_door"],
		[Vector3(-13.2, 0, 22.2), Vector3(-14, 1.3, 19.6), "void_exit_door_angle"],
		[Vector3(-1.0, 0, 16.0), Vector3(-3.6, 1.2, 16.2), "void_creature_near"],
		# The rebuilt Void (2026-09-12): the ward fragment, the loop corridor seen up its
		# length, the floating tiles over the pit, the morgue fragment, the child's room.
		[Vector3(0, 0, 11.5), Vector3(0, 1.2, 15.5), "void_ward_frames"],
		[Vector3(12.5, 0, 16.0), Vector3(12.5, 1.4, 40.0), "void_loop_corridor"],
		[Vector3(2.0, 0, 45.5), Vector3(-4.0, 0.3, 45.5), "void_tile_hall"],
		[Vector3(-1.8, 0, 47.0), Vector3(-7.7, 0.0, 45.5), "void_tiles_from_the_branch"],
		[Vector3(-10.4, 0, 45.5), Vector3(-13.5, 1.0, 46.5), "void_morgue_fragment"],
		[Vector3(-14, 0, 36.0), Vector3(-15.2, 0.8, 34.0), "void_fractured_cradle"],
		# ── 2026-09-20 pass 2: the three MEMORIES, each from its own tile, aimed at that
		# shape's canvas centre (void_alignment.VIEWS). These are the frames the puzzle is
		# judged on: if the shape does not read as a door / a bed / a window here, the
		# tolerance sweep passing means nothing.
		[Vector3(-3.6, 0, 45.5), Vector3(-7.30, 1.65, 45.500), "void_view_door"],
		[Vector3(1.4, 0, 45.5), Vector3(1.635, 1.65, 48.532), "void_view_bed"],
		[Vector3(-3.6, 0, 42.8), Vector3(-1.944, 1.83, 41.292), "void_view_window"],
		# …and each from the tile NEXT DOOR, where it must not assemble.
		[Vector3(-1.8, 0, 47.0), Vector3(-7.30, 1.65, 45.500), "void_view_door_wrong_tile"],
		[Vector3(-0.2, 0, 45.5), Vector3(1.635, 1.65, 48.532), "void_view_bed_wrong_tile"],
		[Vector3(-18.5, 0, 48.2), Vector3(-18.5, 1.0, 52.1), "void_drawer_bank"],
		[Vector3(-18.4, 0, 48.9), Vector3(-20.0, 0.25, 50.6), "void_long_drawer"],
		[Vector3(-13.0, 0, 43.9), Vector3(-13.1, 1.84, 45.5), "void_slab_underside"],
		# ── 2026-09-20 pass 3: the quest's states, each one set up by its own action ──
		[Vector3(-4.6, 0, 6.9), Vector3(-5.2, 0.14, 7.55), "void_anchor_handle"],
		[Vector3(-2.5, 0, 12.6), Vector3(-2.52, 0.10, 13.60), "void_anchor_slat"],
		[Vector3(7.0, 0, 43.9), Vector3(7.08, 0.11, 44.62), "void_anchor_latch"],
		[Vector3(8.0, 0, 13.2), Vector3(8.0, 0.1, 15.3), "void_loopin_frame"],
		# ⭐ pass 5: the shard is WEDGED and visible from frame 0, and a look-away frees it into
		# the basin. Both states, from the stance the Archive is entered on.
		[Vector3(-3.4, 0, 20.6), Vector3(-3.19, 0.74, 21.66), "void_shard_wedged"],
		[Vector3(-2.2, 0, 20.9), Vector3(-3.19, 0.74, 21.66), "void_shard_wedged_angle"],
		[Vector3(-3.4, 0, 20.6), Vector3(-3.4, 0.42, 22.0), "void_shard_basin", "free_shard"],
		[Vector3(-19.4, 0, 50.4), Vector3(-19.4, 0.9, 51.6), "void_open_drawer", "open_page_drawer"],
		[Vector3(-14, 0, 36.0), Vector3(-15.2, 0.8, 34.0), "void_child_room_wide"],
		[Vector3(-17.4, 0, 30.4), Vector3(-11.0, 1.4, 35.6), "void_child_room_corner"],
		# The three seated keystones, from their own tiles — the frames the quest is judged on.
		[Vector3(-3.6, 0, 45.5), Vector3(-7.30, 1.65, 45.500), "void_keystone_handle", "seat_anchors"],
		[Vector3(1.4, 0, 45.5), Vector3(1.635, 1.65, 48.532), "void_keystone_slat"],
		[Vector3(-3.6, 0, 42.8), Vector3(-1.944, 1.83, 41.292), "void_keystone_latch"],
		# ⚠️ The exit door mid-tween is not shootable — a tween is a race with the capture — so
		# the ASSEMBLED end state is set directly and photographed against the pass-2 shots of
		# the same door broken (`void_exit_door` above).
		[Vector3(-14, 0, 22.6), Vector3(-14, 1.1, 19.5), "void_exit_door_assembled", "assemble_exit"],
		[Vector3(-13.2, 0, 22.2), Vector3(-14, 1.3, 19.6), "void_exit_door_assembled_angle"],
		[Vector3(-16.2, 0, 25.6), Vector3(-17.74, 1.3, 24.5), "void_sanctum_plate"],
		# ⭐ pass 5: the 0.90 x 1.10 plate face-on, and from the grazing stance along the west
		# wall that capture 8 was taken from — the one where the page used to show beside it.
		[Vector3(-16.4, 0, 24.5), Vector3(-17.84, 1.3, 24.5), "void_plate_face_on"],
		[Vector3(-17.5, 0, 22.2), Vector3(-17.84, 1.3, 24.5), "void_plate_grazing"],
		[Vector3(-17.5, 0, 20.9), Vector3(-17.84, 1.3, 24.5), "void_plate_grazing_far"],
		# ⭐ pass 5: the Ward's hanging gurney, before and after the touch drops it 0.10 m.
		# ⚠️ 2.4 m BACK, not 1.5: the prop is 2 m long and at interact range it fills the frame
		# with one rail. The first pose was the complaint it answers, in a bigger size.
		[Vector3(-2.6, 0, 10.9), Vector3(-2.6, 1.3, 13.3), "void_ward_gurney"],
		[Vector3(-1.0, 0, 12.2), Vector3(-2.6, 1.4, 13.3), "void_ward_gurney_angle"],
		[Vector3(0.2, 0, 10.6), Vector3(-2.6, 1.3, 13.3), "void_ward_gurney_from_the_door"],
		[Vector3(-2.6, 0, 10.9), Vector3(-2.6, 1.3, 13.3), "void_ward_gurney_touched", "gurney_receipt"],
		# ⭐ pass 5: the corridor charge, from the north end looking down all 25 m of it — the
		# figure standing under the dead lamp, and the last frame of its rush.
		[Vector3(12.5, 0, 41.5), Vector3(12.5, 1.5, 16.5), "void_corridor_south_view"],
		[Vector3(12.5, 0, 41.5), Vector3(12.5, 1.5, 16.5), "void_charge_rush", "charge_fire"],
		[Vector3(12.5, 0, 41.5), Vector3(12.5, 1.5, 16.5), "void_charge_peak", "charge_rush"],
		# ⭐ pass 5: the cradle figure at the peak of its lunge, rising from the cradle's own
		# centre instead of from the floor in front of it.
		[Vector3(-14.9, 0, 33.4), Vector3(-15.75, 1.0, 34.3), "void_cradle_before_lunge"],
		[Vector3(-14.9, 0, 33.4), Vector3(-15.75, 1.0, 34.3), "void_cradle_figure_peak", "cradle_peak"],
		# ── 2026-09-20 pass 4: the sixteenth room, the frames, the figure, the new tells ──
		# ⚠️ `open_secret` FIRST, or every shot below is of a wall.
		[Vector3(-20.0, 0, 47.5), Vector3(-25.0, 1.4, 47.5), "void_secret_doorway", "open_secret"],
		[Vector3(-22.6, 0, 47.5), Vector3(-26.4, 1.3, 46.6), "void_frame_hall_wide"],
		[Vector3(-24.4, 0, 45.4), Vector3(-25.7, 1.2, 45.4), "void_frame_west_0"],
		[Vector3(-24.4, 0, 47.0), Vector3(-25.7, 1.2, 47.0), "void_frame_west_1"],
		[Vector3(-24.4, 0, 48.6), Vector3(-25.7, 1.2, 48.6), "void_frame_west_2"],
		[Vector3(-23.5, 0, 44.9), Vector3(-22.3, 1.2, 44.9), "void_frame_east_0"],
		[Vector3(-23.5, 0, 49.1), Vector3(-22.3, 1.2, 49.1), "void_frame_east_1"],
		# A figure standing in a diorama — the wrong step's answer, watched.
		[Vector3(-24.4, 0, 47.0), Vector3(-25.7, 1.1, 47.0), "void_frame_figure", "frame_figure"],
		# …and the settled corridor with the page at its end.
		[Vector3(-24.0, 0, 44.6), Vector3(-24.0, 1.3, 49.84), "void_frame_corridor", "settle_frames"],
		[Vector3(-24.0, 0, 48.5), Vector3(-24.0, 1.3, 49.84), "void_hidden_note"],
		# The drawing before and after it becomes a plan.
		[Vector3(-11.6, 0, 33.0), Vector3(-10.16, 1.5, 33.0), "void_child_drawing"],
		[Vector3(-11.6, 0, 33.0), Vector3(-10.16, 1.5, 33.0), "void_child_plan", "swap_drawing"],
		# The Ward frame that answers, before and after.
		[Vector3(0.0, 0, 13.6), Vector3(2.6, 1.3, 14.5), "void_ward_right_before"],
		[Vector3(0.0, 0, 13.6), Vector3(2.6, 1.3, 14.5), "void_ward_right_after", "ward_answer"],
		# The bank with one front already out, and the Morgue note on its new stretch of wall.
		[Vector3(-17.6, 0, 50.6), Vector3(-17.6, 1.0, 52.1), "void_drawer_open_at_start"],
		[Vector3(-19.6, 0, 45.0), Vector3(-20.84, 1.3, 45.0), "void_morgue_note_moved"],
		# The wall texture, filling the frame, so the watermark can be read off the picture.
		[Vector3(-24.0, 0, 46.0), Vector3(-26.9, 1.6, 46.0), "void_wall_texture"],
		[Vector3(0, 0, 5.0), Vector3(1.0, 2.6, 7.4), "void_ceiling_stair"],
		[Vector3(7.0, 0, 46.6), Vector3(7.0, 0.1, 44.7), "void_flat_doorframe"],
		[Vector3(8.0, 0, 14.9), Vector3(8.0, 0.7, 16.8), "void_fused_chairs"],
		[Vector3(-2.0, 0, 20.1), Vector3(-3.4, 0.5, 22.0), "void_inverted_table"],
		[Vector3(-14.3, 0, 37.2), Vector3(-12.95, 1.2, 39.5), "void_door_heap"],
		[Vector3(2.4, 0, -0.7), Vector3(2.4, 2.6, 1.4), "void_hung_shards"],
		# ── one near pose per creature, i.e. per figure variant (B..F -> 3/4/0/1/2) ──
		[Vector3(-1.5, 0, 16.6), Vector3(-3.6, 1.5, 16.2), "void_figure_B"],
		[Vector3(-2.6, 0, 16.4), Vector3(-3.6, 2.05, 16.2), "void_figure_B_head"],
		# 2026-09-20: the FACE, from in front (B faces +z; its head is at ~2.1 m).
		[Vector3(-3.3, 0, 17.55), Vector3(-3.62, 2.05, 16.25), "void_figure_B_face"],
		# ⭐ 2026-09-20 pass 2: THE MASK, front-on at 2.5 m and 5 m — the two distances the
		# 13:10 playtester photographed the old recessed face at and could not read it. C is
		# used, not B: it stands at (13.15, 41) facing -z down a 30 m corridor, so there is
		# room to back off; B has a wall 1.8 m behind it.
		[Vector3(13.15, 0, 38.6), Vector3(13.15, 2.13, 41.1), "void_mask_2m5"],
		[Vector3(13.15, 0, 36.1), Vector3(13.15, 2.13, 41.1), "void_mask_5m"],
		[Vector3(12.6, 0, 38.9), Vector3(13.15, 1.5, 41.0), "void_figure_C"],
		[Vector3(-11.6, 0, 44.9), Vector3(-11.2, 1.5, 47.0), "void_figure_D"],
		[Vector3(-13.9, 0, 31.4), Vector3(-12.0, 1.5, 32.2), "void_figure_E"],
		[Vector3(-14.2, 0, 25.4), Vector3(-16.0, 1.5, 24.5), "void_figure_F"],
	],
	# The two props rebuilt from flat decals into real geometry (playtest 2026-07-25,
	# captures #4 and #5). Head-on AND from an angle: a billboard/decal looks passable
	# straight on and gives itself away off-axis, which is how both survived this long.
	"kontur": [
		[Vector3(-1.2, 0, 0.0), Vector3(-2.78, 1.5, 0.0), "kontur_mailbox_head_on"],
		[Vector3(-1.4, 0, 1.6), Vector3(-2.78, 1.4, 0.0), "kontur_mailbox_angle"],
		[Vector3(2.2, 0, 31.0), Vector3(3.6, 1.3, 31.0), "kontur_roster_lock_head_on"],
		[Vector3(2.4, 0, 32.4), Vector3(3.6, 1.3, 31.0), "kontur_roster_lock_angle"],
	],
}

var _scene := "intro_room"
var _shots: Array = []
var _frame := 0
var _idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene = args[0]
	_shots = SHOTS.get(_scene, [])
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/%s.tscn" % _scene)


# ⚠️ THE VOID HAS FIVE LETHAL PURSUERS IN IT. This tool teleports the camera around a live
# level; without freezing them, one of them reaches the parked player somewhere in the middle
# of a 30-shot run, the scene reloads, and every later shot is of a different world. Only the
# AI is stopped — the VISUAL is untouched, and a watched stalker is frozen in game anyway, so
# these are the poses a player actually sees.
func _freeze_threats() -> void:
	if _scene != "level_3":
		return
	var lvl := current_scene
	if lvl == null or not lvl.has_method("get_stalkers"):
		return
	var frozen := 0
	for s in (lvl.call("get_stalkers") as Dictionary).values():
		if is_instance_valid(s):
			s.set_physics_process(false)
			frozen += 1
	print("screenshot: froze %d Void stalkers" % frozen)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 11:
		_freeze_threats()
	if _frame < 12:
		return false
	var step := (_frame - 12) % 14
	if step == 0:
		_idx = (_frame - 12) / 14
		if _idx >= _shots.size():
			return true
		if (_shots[_idx] as Array).size() > 3:
			_action(String(_shots[_idx][3]))
		_place(_shots[_idx])
	elif step == 12:
		_capture(_shots[_idx][2])
	return false


# One-shot setups, run on the live level immediately before the shot that needs them. ⚠️ Each
# drives the LEVEL'S OWN method, never a hand-built imitation of the state: a screenshot of a
# state the game cannot reach is worth nothing.
func _action(what: String) -> void:
	var lvl := current_scene
	if lvl == null:
		return
	match what:
		"free_shard":
			var sh = lvl.call("shard")
			if sh:
				sh.call("free_into_basin", false)
		"gurney_receipt":
			var wf2 = lvl.get_node_or_null("WardFragment")
			if wf2:
				wf2.call("interact")
		# ⚠️ FIRED THROUGH THE LEVEL'S OWN ONE-SHOT, and the camera is already parked by the
		# PRECEDING shot — `_action()` runs before `_place()`, so a beat that aims at the camera
		# must be set up one shot after the pose it is judged from.
		"charge_fire":
			lvl.set("_charge_done", false)
			lvl.call("_fire_corridor_charge")
		"charge_rush":
			var cf = lvl.get_node_or_null("ChargeFigure")
			if cf == null:
				lvl.set("_charge_done", false)
				lvl.call("_fire_corridor_charge")
				cf = lvl.get_node_or_null("ChargeFigure")
			if cf:
				cf.call("snap_to_strike")
		"cradle_peak":
			lvl.call("_fire_cradle_lunge")
			var kf = lvl.get_node_or_null("CradleFigure")
			if kf:
				kf.call("snap_to_strike")
		"open_page_drawer":
			var d = lvl.call("page_drawer")
			if d:
				d.call("open_instantly")
		"seat_anchors":
			var puzzle := lvl.get_node_or_null("AlignmentKeystone")
			if puzzle:
				for v in 3:
					puzzle.call("place_anchor", v, true)
		"open_secret":
			if lvl.has_method("_open_secret_door"):
				lvl.call("_open_secret_door")
		"frame_figure":
			var hall = lvl.call("frame_hall")
			if hall:
				hall.set("_wrong", 1)
				hall.call("_place_diorama_figure")
		"settle_frames":
			var hall2 = lvl.call("frame_hall")
			if hall2:
				hall2.call("settle_instantly")
		"swap_drawing":
			if lvl.has_method("_apply_drawing_plan"):
				lvl.call("_apply_drawing_plan")
		"ward_answer":
			var wf = lvl.get_node_or_null("WardFragment")
			if wf:
				wf.set("armed", true)
				wf.set("spent", true)
				wf.call("_apply_configuration")
		"assemble_exit":
			var door := lvl.get_node_or_null("ExitDoor")
			if door and door.has_method("snap_assembled"):
				door.call("snap_assembled")
	print("screenshot: action ", what)


func _place(shot: Array) -> void:
	var player: CharacterBody3D = current_scene.get_node_or_null("Player")
	if not player:
		return
	player.global_position = shot[0]
	var cam: Camera3D = player.get_node("Camera3D")
	var eye: Vector3 = shot[0] + Vector3(0, 1.65, 0)
	var to: Vector3 = (shot[1] as Vector3) - eye
	player.rotation.y = atan2(-to.x, -to.z)  # player forward = -basis.z
	cam.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _capture(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + _scene + "_" + shot_name + ".png")
	print("shot: ", _scene, " / ", shot_name)
