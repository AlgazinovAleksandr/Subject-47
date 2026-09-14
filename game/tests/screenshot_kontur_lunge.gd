extends SceneTree
# K2 (2026-09-14): photograph the in-world death — the yellow phone's answer. Run WITHOUT
# --headless. Self-terminating: quits a few frames after Screamer._is_triggering, or at 400.
const OUT := "/tmp/kontur_lunge/"
var _k: Node
var _p: CharacterBody3D
var _f := 0
var _step := 0
var _trig_f := -1
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/kontur.tscn")
func _shoot(n: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + n + ".png")
	var w := img.get_width(); var h := img.get_height(); var sum := 0.0; var cnt := 0
	for y in range(int(h * 0.3), int(h * 0.7), 6):
		for x in range(int(w * 0.3), int(w * 0.7), 6):
			sum += img.get_pixel(x, y).get_luminance(); cnt += 1
	print("shot: %s  centre luminance %.4f" % [n, sum / maxf(1.0, cnt)])
func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	_f += 1
	if _k == null:
		if _f < 30:
			return false
		_k = current_scene
		_p = _k.get_node("Player")
		_p.set("ai_active", true)
		var yellow: Node3D = null
		for slot in _k.get("_phone_slots"):
			if slot["colour"] == "yellow":
				yellow = slot["phone"]
		# The desk runs along z at the phone's x; the player stands on the ROOM side (+x).
		var at: Vector3 = yellow.global_position + Vector3(1.4, 0, 0)
		at.y = 0.1
		_p.global_position = at
		_p.call("ai_look_at", yellow.global_position + Vector3(0, 0.6, 0))
		_f = 0
		return false
	var scr := root.get_node("/root/Screamer")
	match _step:
		0:
			if _f == 20:
				_shoot("0_before")
				_k.call("_on_phone_answered", "yellow")
				_step = 1
				_f = 0
		1:
			if _f in [6, 14, 22, 30, 40, 55]:
				_shoot("1_lunge_f%02d" % _f)
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
