extends SceneTree
# C2 (2026-09-13): photograph fork 0 — the mouth from the hall (dead torch, no carpet), the loop's
# far corner with the figure, and the door onto the hall after the corner. Run WITHOUT --headless.
const OUT := "/tmp/fork_shots/"
var _lvl: Node
var _p: CharacterBody3D
var _f := 0
var _step := 0
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/corridor.tscn")
func _shoot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("shot: ", n)
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
		for n in _lvl.get_children():
			if n is Area3D and n.get_script() != null and String(n.get_script().resource_path).ends_with("beartrap.gd"):
				(n as Area3D).monitoring = false
		_f = 0
	if _f > 400:
		print("TIMEOUT at step %d" % _step)
		quit(1)
		return true
	var e: Dictionary = (_lvl.call("forks") as Array)[0]
	var mA: Vector3 = e["mouthA"]
	var dir3: Vector3 = e["dir"]
	var fwd: Vector3 = e["fwd"]
	match _step:
		0:
			var pt: Dictionary = _lvl.call("_path_point", 112.0)
			_p.global_position = (pt["pos"] as Vector3) + Vector3(0, 0.1, 0)
			_p.velocity = Vector3.ZERO
			_p.call("ai_look_at", mA + dir3 * 2.0 + Vector3(0, 1.3, 0))
			_step = 1
			_f = 0
		1:
			if _f == 18:
				_shoot("1_mouth_from_hall")
				_p.global_position = mA + dir3 * 1.6 + Vector3(0, 0.1, 0)   # springs the enter trigger
				_p.call("ai_look_at", (e["cornerA"] as Vector3) + Vector3(0, 1.4, 0))
				_step = 2
				_f = 0
		2:
			if _f == 30:
				_p.global_position = (e["cornerA"] as Vector3) + Vector3(0, 0.1, 0)
				_p.call("ai_look_at", (e["cornerC"] as Vector3) + Vector3(0, 1.4, 0))
			if _f == 48:
				_shoot("2_along_B_figure")
				_p.global_position = (e["cornerC"] as Vector3) + Vector3(0, 0.1, 0)   # opens the door
				_p.call("ai_look_at", (e["mouthC"] as Vector3) + Vector3(0, 1.2, 0))
			if _f == 90:
				_shoot("3_door_open_onto_hall")
				quit(0)
				return true
	return false
