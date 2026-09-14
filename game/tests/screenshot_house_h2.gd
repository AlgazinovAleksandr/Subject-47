extends SceneTree

# H2 (2026-09-13): the chained fridge, the cutters under the bed (torch aimed low), the head's digit.
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_house_h2.gd
const OUT := "/tmp/house_h2/"
var _p: Node3D = null
var _l: Node = null
var _t := 0.0
var _phase := 0


func _initialize() -> void:
	seed(3)
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("wrote ", n)


func _stand(pos: Vector3, look: Vector3) -> void:
	_p.set("velocity", Vector3.ZERO)
	_p.global_position = pos
	_p.call("ai_look_at", look)


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 1.5:
				return false
			_l = current_scene
			_p = _l.get_node("Player")
			_p.set_physics_process(false)
			var f := _l.get_node("Fridge") as Node3D
			var kc: Vector3 = (_l.get("_builder") as RoomBuilder).room_center("Kitchen")
			var fwd := Vector3(kc.x - f.global_position.x, 0, kc.z - f.global_position.z).normalized()
			_stand(f.global_position + fwd * 1.9 + Vector3(0, 0.1, 0), f.global_position + Vector3(0, 1.0, 0))
			_t = 0.0
			_phase = 1
		1:
			if _t > 0.5:
				_shot("01_fridge_chained")
				var c := _l.get_node("BoltCutters") as Node3D
				_stand(c.global_position + Vector3(0.9, 0.1, 0.0), c.global_position)
				_t = 0.0
				_phase = 2
		2:
			if _t > 0.5:
				_shot("02_cutters_under_bed")
				_l.set("_cutters_held", true)
				_l.get_node("BoltCutters").queue_free()
				var f := _l.get_node("Fridge")
				f.call("interact")   # cuts (cutters held)
				_t = 0.0
				_phase = 3
		3:
			if _t > 0.25:
				var f := _l.get_node("Fridge") as Node3D
				var kc: Vector3 = (_l.get("_builder") as RoomBuilder).room_center("Kitchen")
				var fwd := Vector3(kc.x - f.global_position.x, 0, kc.z - f.global_position.z).normalized()
				_stand(f.global_position + fwd * 1.9 + Vector3(0, 0.1, 0), f.global_position + Vector3(0, 0.9, 0))
				_shot("03_chain_falling")
				_t = 0.0
				_phase = 4
		4:
			if _t > 1.0:
				_l.get_node("Fridge").call("interact")
				_t = 0.0
				_phase = 5
		5:
			if _t > 1.3:
				var f := _l.get_node("Fridge")
				var head: Vector3 = f.call("thing_position")
				var kc: Vector3 = (_l.get("_builder") as RoomBuilder).room_center("Kitchen")
				var fwd := Vector3(kc.x - head.x, 0, kc.z - head.z).normalized()
				_stand(head + fwd * 1.0 - Vector3(0, head.y - 0.1, 0), head)
				_t = 0.0
				_phase = 6
		6:
			if _t > 0.4:
				_shot("04_head_digit")
				quit(0)
				return true
	return false
