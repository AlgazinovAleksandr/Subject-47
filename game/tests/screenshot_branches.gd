extends SceneTree
# C4 (2026-09-14): photograph the corner branches — the trail before the corner, the branch mouth
# straight ahead, the blind room's map flash. Run WITHOUT --headless. /tmp/branch_shots/
const OUT := "/tmp/branch_shots/"
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
func _pt(d: float) -> Dictionary:
	return _lvl.call("_path_point", d)
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
	if _f > 500:
		quit(1)
		return true
	var br: Array = _lvl.call("corner_branches")
	match _step:
		0:
			var pt := _pt(312.0)
			_p.global_position = (pt["pos"] as Vector3) + Vector3(0, 0.1, 0)
			_p.velocity = Vector3.ZERO
			_p.call("ai_look_at", (pt["pos"] as Vector3) + (pt["dir"] as Vector3) * 8.0 + Vector3(0, 0.6, 0))
			_step = 1
			_f = 0
		1:
			if _f == 18:
				_shoot("1_trail_before_320")
				var e: Dictionary = br[0]
				_p.global_position = (e["mouth"] as Vector3) - (e["dir"] as Vector3) * 3.0 + Vector3(0, 0.1, 0)
				_p.call("ai_look_at", (e["mouth"] as Vector3) + (e["dir"] as Vector3) * 6.0 + Vector3(0, 1.2, 0))
			if _f == 36:
				_shoot("2_branch_320_mouth")
				var e2: Dictionary = br[1]
				var room: Node3D = e2["room"]
				_p.global_position = (e2["mouth"] as Vector3) + (e2["dir"] as Vector3) * (float(e2["len"]) - 6.0 + 1.6) + Vector3(0, 0.1, 0)
				_p.call("ai_look_at", room.global_position + Vector3(0, 1.4, 0))
				_step = 2
				_f = 0
		2:
			# the room seals on entry; the map flashes 1.2 s later for 0.4 s — look back at it
			if _f == 30:
				var e2: Dictionary = br[1]
				var mp: Node3D = _lvl.get_node("Blind1Map")
				_p.call("ai_look_at", mp.global_position)
			if _f == 80:
				_shoot("3_blind_room_map_flash")
			if _f == 140:
				var lever: Node3D = _lvl.get_node("Blind1Lever")
				_p.call("ai_look_at", lever.global_position)
				_p.call("restore_flashlight")
			if _f == 160:
				_shoot("4_blind_room_lever")
				quit(0)
				return true
	return false
