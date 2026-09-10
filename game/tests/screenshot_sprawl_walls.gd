extends SceneTree

# Photograph THE SPRAWL's walls before and after the runner. **Run WITHOUT --headless.**
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_sprawl_walls.gd
#
# ⚠️ `check_sprawl_walls.gd` asserts the shader UNIFORM. This is the only thing that can say
# whether red actually reads as "wrong" and the reveal actually reads as "that one" in a zone
# that is now darker than the rest of the level.
const OUT := "/tmp/sprawl_shots/"

var _stage := 0
var _t := 0.0
var _armed := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(7)
	change_scene_to_file("res://scenes/backrooms.tscn")


func _process(d: float) -> bool:
	_t += d
	if _t < 3.0 or current_scene == null:
		return false
	var z2 := current_scene.get_node_or_null("ZoneSprawl")
	var pl := get_first_node_in_group("player")
	if z2 == null or pl == null:
		return false
	if not _armed:
		# Enter the zone properly so the ambient dip and the objective land too.
		if _stage == 0:
			current_scene.call("_enter_zone", 2)
		if _stage == 1:
			z2.set("_dweller_done", true)
			z2.call("_apply_gate")
			z2.call("_mark_real_wall")
		# Stand mid-hall looking at the real wall, so both a red wall and the revealed one are
		# in frame at once.
		var origin: Vector3 = z2.get("_origin")
		pl.global_position = origin + Vector3(0, 1.6, 0)
		var cam := pl.get_node_or_null("Camera3D") as Camera3D
		# 2026-09-10: the real wall is the end of the crate's recess, not a compass side —
		# look at the wall NODE, wherever it stands.
		var wall := z2.call("exit_wall") as Node3D
		var aim: Vector3 = wall.global_position if wall else origin + Vector3(0, 1.2, 20.0)
		if cam:
			cam.look_at(Vector3(aim.x, 1.2, aim.z), Vector3.UP)
		var hud := pl.get_node_or_null("InteractUI")
		if hud:
			hud.visible = false
		_armed = true
		return false
	var img := root.get_texture().get_image()
	var tag := "before_run" if _stage == 0 else "after_run"
	img.save_png("%s%s.png" % [OUT, tag])
	print("shot %s" % tag)
	_armed = false
	_stage += 1
	if _stage >= 2:
		print("== 2 shots in %s ==" % OUT)
		quit(0)
		return true
	return false
