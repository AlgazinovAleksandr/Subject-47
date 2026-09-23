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
		# ⭐ pass 6: the bed slat is inside the Ward box; both shots are of the box.
		[Vector3(-2.6, 0, 15.9), Vector3(-2.33, 0.30, 14.56), "void_ward_box_shut"],
		[Vector3(-1.2, 0, 16.4), Vector3(-2.6, 0.35, 14.5), "void_ward_box_shut_angle"],
		[Vector3(-2.6, 0, 12.0), Vector3(-2.6, 0.5, 14.5), "void_ward_box_from_the_gurney"],
		[Vector3(-2.6, 0, 15.9), Vector3(-2.33, 0.30, 14.56), "void_ward_box_open", "open_box"],
		[Vector3(-1.2, 0, 16.4), Vector3(-2.6, 0.35, 14.5), "void_ward_box_open_angle"],
		[Vector3(-2.6, 0, 15.9), Vector3(-2.33, 0.30, 14.56), "void_anchor_slat"],
		[Vector3(7.0, 0, 43.9), Vector3(7.08, 0.11, 44.62), "void_anchor_latch"],
		[Vector3(8.0, 0, 13.2), Vector3(8.0, 0.1, 15.3), "void_loopin_frame"],
		# ⭐ pass 6: the shard simply lies in the table's basin, takeable, from frame 0.
		[Vector3(-3.4, 0, 20.6), Vector3(-3.4, 0.42, 22.0), "void_shard_basin"],
		[Vector3(-2.2, 0, 20.9), Vector3(-3.4, 0.42, 22.0), "void_shard_basin_angle"],
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
		# ⭐ pass 6: the trigger is at z 26 — 60 % of the way back — and the figure is 9.5 m off,
		# not 25. Both shots are from the stance the beat actually fires at.
		[Vector3(12.5, 0, 26.0), Vector3(12.5, 1.5, 16.5), "void_corridor_south_view"],
		[Vector3(12.5, 0, 26.0), Vector3(12.5, 1.5, 16.5), "void_charge_stands", "charge_fire"],
		[Vector3(12.5, 0, 26.0), Vector3(12.5, 1.5, 16.5), "void_charge_peak", "charge_rush"],
		# ⭐ pass 7: fired from a player facing AWAY, with the camera left to the level's own
		# `turn_to_face()`. `hold` — this shot's pose is the thing being measured.
		[Vector3.ZERO, Vector3.ZERO, "void_charge_turned", "charge_turn", "hold"],
		# ⭐ pass 7: the cradle's beat — the room and the torch out, and something crouched in the
		# cradle with its mask at the rim.
		# ⭐ pass 8: …and the cradle BURNS first. Three frames, in the order the beat reaches them:
		# the fire at its peak (t = 2.5 s, nothing risen yet), the face come up through the flames,
		# and the room afterwards.
		[Vector3(-14.9, 0, 33.4), Vector3(-15.75, 1.0, 34.3), "void_cradle_before_shadow"],
		[Vector3(-14.9, 0, 33.4), Vector3(-15.75, 1.4, 34.3), "void_cradle_fire_peak", "cradle_fire"],
		[Vector3(-14.9, 0, 34.9), Vector3(-15.75, 1.4, 34.3), "void_cradle_fire_angle"],
		# ⚠️ AND FROM 2.5 m, which is where a player who has just pressed E actually stands. The
		# pass-7 pose is 1.2 m out and the cradle's own rail crosses the frame at that range —
		# fine for "is the mask lit", useless for "what does this beat look like".
		[Vector3(-14.2, 0, 32.3), Vector3(-15.75, 1.45, 34.3), "void_cradle_fire_2m5"],
		[Vector3(-14.9, 0, 33.4), Vector3(-15.75, 1.4, 34.3), "void_cradle_shadow", "cradle_face"],
		[Vector3(-14.9, 0, 34.9), Vector3(-15.75, 1.4, 34.3), "void_cradle_shadow_angle"],
		[Vector3(-14.2, 0, 32.3), Vector3(-15.75, 1.75, 34.3), "void_cradle_face_2m5"],
		[Vector3(-14.9, 0, 33.4), Vector3(-15.75, 1.0, 34.3), "void_cradle_after_shadow",
			"cradle_shadow_end"],
		# ⭐ pass 8: a drawer that has been pulled and can be pushed back, with its prompt up.
		# ⚠️ A `hold` shot: the whole point is where the E-RAY is pointed, and `_place()` would
		# overwrite the pose one line after the action set it.
		[Vector3.ZERO, Vector3.ZERO, "void_drawer_closable", "aim_open_drawer", "hold"],
		# ── 2026-09-20 pass 4: the sixteenth room, the frames, the figure, the new tells ──
		# ⚠️ `open_secret` FIRST, or every shot below is of a wall.
		[Vector3(-20.0, 0, 47.5), Vector3(-25.0, 1.4, 47.5), "void_secret_doorway", "open_secret"],
		# ⭐ pass 6: THE RECURRING ROOM. Every shot from the entrance the room always puts you
		# back at, because that is the frame the player actually judges each stage on.
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_stage0"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_stage1", "room_stage1"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_stage2", "room_stage2"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_stage3", "room_stage3"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_stage4", "room_stage4"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_stage5", "room_stage5"],
		[Vector3(-24.0, 0, 46.2), Vector3(-26.7, 1.6, 46.2), "void_room_wall_corrupt"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_stage0_again", "room_stage0"],
		[Vector3(-22.6, 0, 47.5), Vector3(-26.4, 1.3, 46.6), "void_frame_hall_wide"],
		[Vector3(-24.4, 0, 45.4), Vector3(-25.7, 1.2, 45.4), "void_frame_west_0"],
		[Vector3(-24.4, 0, 47.0), Vector3(-25.7, 1.2, 47.0), "void_frame_west_1"],
		[Vector3(-24.4, 0, 48.6), Vector3(-25.7, 1.2, 48.6), "void_frame_west_2"],
		[Vector3(-22.2, 0, 44.9), Vector3(-23.4, 1.2, 44.9), "void_frame_east_0"],
		[Vector3(-22.2, 0, 49.1), Vector3(-23.4, 1.2, 49.1), "void_frame_east_1"],
		# ⭐ pass 6: the wrong door's answer — a figure 0.6 m in front of the camera on the
		# fade-in — and stage 3's figure standing in a doorway that is not the answer.
		# ⚠️ `_action()` runs BEFORE `_place()`, so a beat aimed at the CAMERA has to be set up
		# one shot after the pose it is judged from.
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_before_wrong"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_wrong_figure", "wrong_figure"],
		[Vector3(-21.9, 0, 47.5), Vector3(-25.2, 1.2, 47.0), "void_room_doorway_figure", "doorway_figure"],
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


# ⚠️ THE CYCLE IS PER SHOT SINCE 2026-09-22, and the reason is measured. Twelve frames used to
# be assumed to be 0.2 s; windowed at 3024 x 1701 on this machine it is closer to 0.4 s, and
# neither number is a property of the tool. That did not matter while every shot was a static
# pose — but a `hold` shot photographs a 0.25 s camera TWEEN, and the first run caught the Void's
# charge turn 54 % of the way through a 180-degree sweep, i.e. pointed at the side wall. A
# beat-driven shot gets a whole second instead. ⚠️ The capture still lands two frames before the
# cycle ends, exactly as it did at 12 of 14.
var _step := 0
var _cycle := 14
const CYCLE_STATIC := 14
const CYCLE_HOLD := 40


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 11:
		_freeze_threats()
	if _frame < 12:
		return false
	if _step == 0:
		if _idx >= _shots.size():
			return true
		var shot: Array = _shots[_idx]
		_cycle = CYCLE_HOLD if (shot.size() > 4 and String(shot[4]) == "hold") \
			else CYCLE_STATIC
		if shot.size() > 3:
			_action(String(shot[3]))
		_place(shot)
	elif _step == _cycle - 2:
		_capture(_shots[_idx][2])
	_step += 1
	if _step >= _cycle:
		_step = 0
		_idx += 1
	return false


# One-shot setups, run on the live level immediately before the shot that needs them. ⚠️ Each
# drives the LEVEL'S OWN method, never a hand-built imitation of the state: a screenshot of a
# state the game cannot reach is worth nothing.
func _action(what: String) -> void:
	var lvl := current_scene
	if lvl == null:
		return
	match what:
		"open_box":
			# ⚠️ THE SILENT FORM FIRST. `open_ward_box()` runs the 0.18 s lead + 0.8 s tween, and
			# a capture twelve frames later photographs a lid that has not started moving — the
			# first run of this shot was byte-for-byte the shut one with a different prompt.
			var bx = lvl.call("ward_box")
			if bx:
				bx.call("open", false)
			lvl.set("_ward_box_open", true)
		"room_stage0", "room_stage1", "room_stage2", "room_stage3", "room_stage4", "room_stage5":
			var rh = lvl.call("frame_hall")
			if rh:
				rh.call("apply_stage", int(what.substr(10)))
		"wrong_figure":
			var wh = lvl.call("frame_hall")
			if wh:
				wh.call("snap_arms_length_figure")
		"doorway_figure":
			var dh = lvl.call("frame_hall")
			if dh:
				dh.call("hide_snap_figures")     # the previous shot's figure is still held
				dh.call("snap_doorway_figure")
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
		# ⭐ pass 7: the charge TURNS THE CAMERA. This one is a `hold` shot — `_place()` is
		# skipped for it, because the whole thing being photographed is where the camera ends up,
		# and placing it would be photographing the tool instead of the beat. The player is put
		# down facing NORTH, away from the figure, exactly as capture 1 described, and the level's
		# own `turn_to_face()` brings the view round inside the 12 frames before the capture.
		"charge_turn":
			# ⚠️ CLEAR THE PREVIOUS SHOT'S FIGURE FIRST. `charge_rush` calls `snap_to_strike()`,
			# which deliberately FREEZES its figure 0.6 m in front of the camera so the peak can
			# be photographed — and it is still standing there. The first run of this shot was a
			# close-up of that corpse's chest, filling the frame, one metre from the new stance.
			var stale := lvl.get_node_or_null("ChargeFigure")
			if stale:
				lvl.remove_child(stale)
				stale.queue_free()
			var pl := lvl.get_node_or_null("Player") as CharacterBody3D
			if pl:
				pl.global_position = Vector3(12.5, 0.1, 26.6)
				pl.rotation.y = PI          # forward is -basis.z, so this faces +z: AWAY
				var pc := pl.get_node_or_null("Camera3D") as Camera3D
				if pc:
					pc.rotation.x = 0.0
				pl.force_update_transform()
			lvl.set("_loop_broken", true)
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
		# ⭐ pass 8: the cradle's beat is a FIRE the face rises out of. Both actions drive the
		# level's own `_shadow_dark()` / `_light_cradle_fire()` / `_shadow_show()` with the waits
		# taken out — the frames worth reading are 2.5 s and 3.5 s in, and this tool captures
		# twelve frames after it sets up, so the timed form photographs an empty black room.
		# (pass 7's `"cradle_shadow"` arm is gone with its shot; `snap_cradle_shadow()` on the
		# level remains as the beat's plain two-step form.)
		# The fire at its peak — `advance_to(2.5)` drives the fire's own `_apply()`,
		# which is the SAME function the live beat drives every frame; only the wait is taken out.
		"cradle_fire":
			lvl.call("snap_cradle_fire", 2.5)
		"cradle_face":
			lvl.call("snap_cradle_face")
		"cradle_shadow_end":
			lvl.call("_shadow_hide")
			lvl.call("_shadow_gone")
			lvl.call("_shadow_restore")
		# ⭐ pass 8: pull the bank's page drawer and put the player's own E-ray on its handle, so
		# the shot carries the CLOSE prompt rather than a picture of an open box.
		"aim_open_drawer":
			var od := lvl.call("page_drawer") as Node3D
			if od:
				od.call("open_instantly")
				var apl := lvl.get_node_or_null("Player") as CharacterBody3D
				if apl:
					var aim: Vector3 = od.to_global(Vector3(0, -0.17, 0.12))
					var stand: Vector3 = aim + od.global_transform.basis.z * 1.0
					apl.global_position = Vector3(stand.x, 0.1, stand.z)
					apl.force_update_transform()
					apl.call("ai_look_at", aim)
					var apc := apl.get_node_or_null("Camera3D") as Camera3D
					if apc:
						apc.force_update_transform()
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


# ⚠️ A `hold` shot places NOTHING. A beat whose subject is the camera's own heading cannot be
# photographed by a tool that overwrites the camera's heading one line later; those shots carry
# a fifth element and their action owns the pose.
func _place(shot: Array) -> void:
	if shot.size() > 4 and String(shot[4]) == "hold":
		return
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
