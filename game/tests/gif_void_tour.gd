extends "res://tests/screenshot_scene.gd"

# Dev tool: a SHORT, watchable version of the Void screenshot probe, for recording.
#
# `screenshot_scene.gd -- level_3` walks 101 curated vantage points and takes ~49 s. That is the
# right tool for reviewing a level and the wrong length for anything anyone will watch. This one
# reuses that file's OWN pose list — picked by name, never re-typed — and plays ten of them at a
# fixed cadence so the whole run is exactly 150 frames.
#
# Run it under Godot's movie writer so the output is deterministic and independent of how fast
# this machine happens to be:
#
#   Godot --path game -w --resolution 1280x720 --position 60,60 \
#         --write-movie <dir>/f.png --fixed-fps 30 --disable-vsync --audio-driver Dummy \
#         --script res://tests/gif_void_tour.gd -- <out_dir_for_the_real_screenshots>
#
# ⚠️ THE SAVED SCREENSHOTS DO NOT GO TO `/tmp/shots/`. The parent writes there, 3024 x 1701, and
# 101 of those files exist. Running the parent's `_capture()` from a 1280 x 720 window would
# silently overwrite the lot with smaller ones. `_capture()` is overridden for exactly that reason.
#
# ⚠️ THE OVERLAY IS NOT IN THE SAVED PNG. The counter hides two frames before each capture and the
# flash starts on the capture frame, so the files on disk are what the real probe produces and the
# flash marks the moment it happened. A staged flash over a screenshot nobody took would be the one
# dishonest frame in an article about honest measurement.

# ⚠️ PICKED BY LOOKING, NOT BY NAME. The first cut of this list was chosen from the shot names
# alone and half of it came back as unlit empty rooms — a drawer bank, a dark corner, and a
# creature close-up that reads as a pile of rubble at gif size. All 101 renders were then put on
# contact sheets and judged as images. What survives has colour, a readable shape, or a face.
const TOUR := [
	"void_exit_door",          # a door with red glowing cracks — the hook
	"void_ward_gurney",        # a gurney hung nose-down
	"void_view_window",        # a teal window frame floating in blackness
	# ⚠️ `open_secret` MUST COME BEFORE THE FRAME-HALL SHOTS. The parent says so in one line —
	# "open_secret FIRST, or every shot below is of a wall" — and the first cut of this tour had
	# the room before the door that reveals it.
	"void_secret_doorway",     # the secret door opens                       (action)
	"void_room_stage3",        # the recurring room, its frames corrupting   (action)
	"void_room_wrong_figure",  # a pale face leaning in beside them          (action)
	"void_morgue_note_moved",  # a warm glowing page
	"void_cradle_fire_peak",   # THE CRADLE BURNS — the one orange frame     (action)
	"void_figure_C",           # a stalker, full height
	# ⚠️ THESE TWO ARE A PAIR AND MUST STAY ADJACENT, in this order. See BEFORE below.
	"void_charge_stands",      # the charge starts down the corridor         (action)
	"void_charge_peak",        # THE SCREAM, filling the frame               (action)  FINAL
]

# ⚠️ SOME BEATS MUST BE PUT BACK. `snap_cradle_fire()` drives the level's `_shadow_dark()`, which
# takes the room AND the torch out; the parent restores them with a `cradle_shadow_end` shot two
# entries later. Picking the fire without the restore left the last two stops pitch black, which
# is exactly how the first cut of this tour ended. The teardown runs at the START of the next
# stop, through the parent's own action arm rather than a hand-rolled imitation of it.
const AFTER := {
	"void_cradle_fire_peak": "cradle_shadow_end",
}

# ⚠️ `void_charge_peak` CANNOT STAND ALONE, and two runs were spent finding that out. `charge_rush`
# reads as self-contained — it fires the charge if no `ChargeFigure` exists — but
# `_fire_corridor_charge()` does not produce the node in the same frame, so the next line finds
# null and `snap_to_strike()` never runs. The result is a photograph of an empty corridor. Firing
# the charge a stop early was tried and also failed; the beat wants the whole preceding shot.
# So the parent's own adjacent pair is reproduced verbatim: `charge_stands` fires it, and
# `charge_peak` fourteen frames later freezes the figure 0.6 m from the camera.

# ⚠️ THE CAPTURE STEP IS FIXED AT 12 FOR EVERY SHOT, INCLUDING THE LONGER FINAL ONE. Six of the
# ten stops run an `_action()` first, and the parent's actions are timed against being captured
# exactly twelve frames after they fire — `snap_cradle_fire(2.5)`, `charge_rush`, the frame-hall
# stages. Stretching the final shot by moving its capture would photograph the beat at the wrong
# moment. The final shot is longer AFTER the capture instead, which is free: `charge_rush` calls
# `snap_to_strike()`, which deliberately FREEZES the figure 0.6 m from the camera.
const STOP_FRAMES := 14
const FINAL_FRAMES := 24
const CAPTURE_STEP := 12
const FLASH_FRAMES := 3
const HIDE_BEFORE := 2  # frames before the capture that the counter goes away

var _out_dir := "user://void_tour/"
var _overlay: Control
var _flash: ColorRect
var _label: Label
var _flash_left := 0
var _first_shot_frame := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if not _out_dir.ends_with("/"):
		_out_dir += "/"
	_scene = "level_3"

	var by_name := {}
	for s in SHOTS["level_3"]:
		by_name[String(s[2])] = s
	_shots = []
	for n in TOUR:
		# ⚠️ Fail loudly. A missing name would silently shorten the tour, and a 4-second video
		# that was supposed to be 5 is not something anyone notices until it is published.
		if not by_name.has(n):
			printerr("gif_void_tour: no such shot in screenshot_scene.SHOTS['level_3']: ", n)
			quit(1)
			return
		_shots.append(by_name[n])

	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("gif_void_tour: %d stops, screenshots -> %s" % [_shots.size(), _out_dir])
	change_scene_to_file("res://scenes/level_3.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 11:
		_freeze_threats()
		# ⚠️ Undo GameState._fit_render_to_display(). It renders 3D at half scale on a Retina
		# display to keep memory down (Issue 203); for a five-second 1280 x 720 clip that trade
		# is not worth making, and the softness is visible in a still.
		root.scaling_3d_scale = 1.0
		_build_overlay()
	if _frame < 12:
		return false

	if _first_shot_frame < 0:
		_first_shot_frame = _frame
		# The movie writer records the scene build too. This is the frame to start the encode at.
		print("gif_void_tour: first shot frame = %d" % _first_shot_frame)

	if _step == 0:
		if _idx >= _shots.size():
			print("gif_void_tour: done after %d stops, last frame %d" % [_shots.size(), _frame])
			return true
		var shot: Array = _shots[_idx]
		_cycle = FINAL_FRAMES if _idx == _shots.size() - 1 else STOP_FRAMES
		if _idx > 0:
			var prev := String(_shots[_idx - 1][2])
			if AFTER.has(prev):
				_action(String(AFTER[prev]))
		if shot.size() > 3:
			_action(String(shot[3]))
		_place(shot)
		_set_label(_idx, String(shot[2]))
	elif _step == CAPTURE_STEP - HIDE_BEFORE:
		if _overlay:
			_overlay.visible = false
	elif _step == CAPTURE_STEP:
		# The counter went away at step 10, so the framebuffer this reads was rendered without it.
		_capture(String(_shots[_idx][2]))
		if _overlay:
			_overlay.visible = true
		_flash_left = FLASH_FRAMES

	_tick_flash()
	_step += 1
	if _step >= _cycle:
		_step = 0
		_idx += 1
	return false


func _capture(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var file := "%02d_%s.png" % [_idx + 1, shot_name]
	img.save_png(_out_dir + file)
	print("gif_void_tour: shot %d/%d -> %s" % [_idx + 1, _shots.size(), file])


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_flash)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position = Vector2(28, -74)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 8)
	_overlay.add_child(_label)


func _set_label(idx: int, shot_name: String) -> void:
	if _label == null:
		return
	_label.text = "СНИМОК %d / %d\n%02d_%s.png" % [idx + 1, _shots.size(), idx + 1, shot_name]


func _tick_flash() -> void:
	if _flash == null:
		return
	if _flash_left > 0:
		_flash.color = Color(1, 1, 1, 0.35 * float(_flash_left) / float(FLASH_FRAMES))
		_flash_left -= 1
	elif _flash.color.a != 0.0:
		_flash.color = Color(1, 1, 1, 0)
