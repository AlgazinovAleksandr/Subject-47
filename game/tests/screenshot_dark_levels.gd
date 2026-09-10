extends SceneTree

# Photograph each darkened level at its spawn point, torch ON and torch OFF.
# **Run WITHOUT --headless** — it needs a render target. Writes to /tmp/dark_shots/.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_dark_levels.gd
#
# ⚠️ `check_darkness.gd` asserts the NUMBERS (ambient <= 0.03, no lamp burning, no DarkZone).
# This is the other half: what a beam in a black building actually looks like, which is the only
# way to tell "atmospheric" from "unplayable". Both are needed — the numbers cannot see whether
# the player can find a door, and a screenshot cannot prove a DarkZone is gone.
#
# ⚠️ SETTING A NODE'S STATE AND CAPTURING IN THE SAME PASS PHOTOGRAPHS THE OLD STATE. The frame
# has already been submitted by the time `_process` runs, so the first version of this harness
# produced "notorch" images with the torch plainly on in them. Every change waits a full frame.
const OUT := "/tmp/dark_shots/"
const SETTLE := 3.5      # levels build a lot in _ready()

var _q := [
	{"scene": "res://scenes/level_1.tscn", "n": "lab_spawn"},
	{"scene": "res://scenes/level_2_1.tscn", "n": "house_spawn"},
	{"scene": "res://scenes/kontur.tscn", "n": "kontur_spawn"},
]
var _i := 0
var _t := 0.0
var _torch := true
var _armed := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file(String(_q[0]["scene"]))


func _process(d: float) -> bool:
	_t += d
	if _t < SETTLE or current_scene == null:
		return false
	var p := get_first_node_in_group("player")
	if p == null:
		return false
	if not _armed:
		# Set the state this frame; capture on the NEXT one.
		var hud := p.get_node_or_null("InteractUI")
		if hud:
			hud.visible = false
		var torch := p.get_node_or_null("Camera3D/Flashlight") as SpotLight3D
		if torch:
			torch.visible = _torch
		_armed = true
		return false

	var img := root.get_texture().get_image()
	var tag: String = "torch" if _torch else "notorch"
	img.save_png("%s%s_%s.png" % [OUT, _q[_i]["n"], tag])
	print("shot %s %s" % [_q[_i]["n"], tag])
	_armed = false
	if _torch:
		_torch = false
		return false
	_torch = true
	_i += 1
	if _i >= _q.size():
		print("== %d shots in %s ==" % [_q.size() * 2, OUT])
		quit(0)
		return true
	_t = 0.0
	change_scene_to_file(String(_q[_i]["scene"]))
	return false
