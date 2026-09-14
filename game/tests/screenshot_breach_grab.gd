extends SceneTree
# X1 (2026-09-14): photograph the grab through the door. Run WITHOUT --headless.
# Self-terminating: quits a few frames after Screamer._is_triggering, or at 400.
const OUT := "/tmp/breach_grab/"
var _l: Node
var _p: CharacterBody3D
var _f := 0
var _step := 0
var _trig_f := -1
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/level_6_breach.tscn")
func _shoot(n: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + n + ".png")
	print("shot: %s" % n)
func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	_f += 1
	if _l == null:
		if _f < 30:
			return false
		_l = current_scene
		_p = _l.get_node("Player")
		_p.set("ai_active", true)
		var door: Node3D = _l.get("_slam_doors")[0]
		var n: Vector3 = door.global_transform.basis.z.normalized()
		var at: Vector3 = door.global_position + n * 1.0
		at.y = 0.1
		_p.global_position = at
		_p.call("ai_look_at", door.global_position + Vector3(0, 1.3, 0))
		_f = 0
		return false
	var scr := root.get_node("/root/Screamer")
	match _step:
		0:
			if _f == 20:
				_shoot("0_before")
				_l.call("_on_contact_death")
				_step = 1
				_f = 0
		1:
			if _f in [6, 14, 22, 30, 40]:
				_shoot("1_grab_f%02d" % _f)
			if _trig_f < 0 and bool(scr.get("_is_triggering")):
				_trig_f = _f
				print("triggering at frame %d" % _f)
			if _trig_f > 0 and _f >= _trig_f + 20:
				_shoot("2_funnel")
				quit(0)
				return true
	if _f > 400:
		print("TIMEOUT")
		quit(1)
		return true
	return false
