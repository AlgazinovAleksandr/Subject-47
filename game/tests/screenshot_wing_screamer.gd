extends SceneTree
# L2 (2026-09-14): photograph the wing screamer at its lunge — is it VISIBLE with the torch locked
# off? Run WITHOUT --headless. Fires `_fire_wing_screamer()` directly with the player in SouthHall.
const OUT := "/tmp/wing_screamer/"
var _lvl: Node
var _p: CharacterBody3D
var _f := 0
var _step := 0
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/level_1.tscn")
func _shoot(n: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + n + ".png")
	# measure: mean luminance of the centre 40 % of the frame
	var w := img.get_width(); var h := img.get_height(); var sum := 0.0; var cnt := 0
	for y in range(int(h * 0.3), int(h * 0.7), 6):
		for x in range(int(w * 0.3), int(w * 0.7), 6):
			sum += img.get_pixel(x, y).get_luminance(); cnt += 1
	print("shot: %s  centre luminance %.4f" % [n, sum / maxf(1.0, cnt)])
func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	_f += 1
	if _lvl == null:
		if _f < 20:
			return false
		_lvl = current_scene
		_p = _lvl.get_node("Player")
		_p.set("ai_active", true)
		_p.global_position = Vector3(-26.0, 0.1, 7.7)   # SouthHall
		_p.call("ai_look_at", Vector3(-31.0, 1.6, 7.7))
		_p.call("lock_flashlight")
		_f = 0
		return false
	match _step:
		0:
			if _f == 20:
				_shoot("0_before")
				_lvl.call("_fire_wing_screamer")
				_step = 1
				_f = 0
		1:
			if _f == 40:
				_shoot("1_lunge")
			if _f == 70:
				_shoot("2_hold")
			if _f == 130:
				_shoot("3_flee")
				quit(0)
				return true
	if _f > 400:
		quit(1)
		return true
	return false
