extends SceneTree
# R1 (2026-09-16): photograph the dressed blind room with the torch ON, from the mouth and from
# the lever corner, so the furniture can be judged. Run WITHOUT --headless. /tmp/blind_shots/
# Self-terminating (frame cap + current_scene gate).
const OUT := "/tmp/blind_shots/"
var _lvl: Node
var _p: CharacterBody3D
var _f := 0
var _total := 0
var _step := 0
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/corridor.tscn")
func _shoot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("shot: ", n)
func _process(_d: float) -> bool:
	_total += 1
	if _total > 900:
		print("RESULT: FAIL (timeout)")
		quit(1)
		return true
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
		# the seal area must not fire: disable it so the torch stays on for the pictures
		var e: Area3D = _lvl.get_node_or_null("Blind1Enter")
		if e:
			e.monitoring = false
		_f = 0
	var br: Array = _lvl.call("corner_branches")
	var e2: Dictionary = br[1]
	var dir3: Vector3 = e2["dir"]
	var lat3: Vector3 = e2["lat"] if e2.has("lat") else dir3.cross(Vector3.UP)
	var room: Node3D = e2["room"]
	var rl: float = float(e2["len"]) - 6.0
	match _step:
		0:
			# from the mouth, looking in
			_p.global_position = (e2["mouth"] as Vector3) + dir3 * (rl + 0.6) + Vector3(0, 0.1, 0)
			_p.velocity = Vector3.ZERO
			_p.call("ai_look_at", room.global_position + Vector3(0, 1.0, 0))
			_step = 1
			_f = 0
		1:
			if _f == 25:
				_shoot("1_from_mouth")
				# from the right wall, looking across at the rack and the lever
				_p.global_position = room.global_position + lat3 * 2.2 - dir3 * 1.5 + Vector3(0, 0.1, 0)
				_p.velocity = Vector3.ZERO
				var lever: Node3D = _lvl.get_node("Blind1Lever")
				_p.call("ai_look_at", lever.global_position)
			if _f == 50:
				_shoot("2_lever_and_rack")
				_p.global_position = room.global_position - lat3 * 2.0 - dir3 * 1.0 + Vector3(0, 0.1, 0)
				_p.velocity = Vector3.ZERO
				var boiler: Node3D = _lvl.get_node("Blind1Boiler")
				_p.call("ai_look_at", boiler.global_position + Vector3(0, 1.0, 0))
			if _f == 75:
				_shoot("3_boiler_and_cart")
				print("RESULT: PASS")
				quit(0)
				return true
	return false
