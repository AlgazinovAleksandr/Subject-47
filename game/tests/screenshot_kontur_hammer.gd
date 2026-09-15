extends SceneTree
# K1 (2026-09-13): photograph the part-built hammer on its bench, from the spawn side and from
# the side. Run WITHOUT --headless. Output /tmp/kontur_b/00_hammer_*.png
const OUT := "/tmp/kontur_b/"
var _k: Node = null
var _p: Node3D = null
var _t := 0.0
var _phase := 0
func _initialize() -> void:
	seed(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/kontur.tscn")
func _look(eye: Vector3, target: Vector3) -> void:
	_p.set("velocity", Vector3.ZERO)
	_p.global_position = eye
	_p.call("ai_look_at", target)
func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	print("wrote ", name)
func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 1.6:
				return false
			_k = current_scene
			_p = _k.get_node("Player")
			_p.set_physics_process(false)
			_look(Vector3(-0.9, 0.1, -0.4), Vector3(-1.8, 0.78, -1.5))
			_phase = 1
			_t = 0.0
		1:
			if _t > 0.5:
				_shot("00_hammer_front")
				_look(Vector3(-1.7, 0.1, -0.3), Vector3(-1.8, 0.78, -1.5))
				_phase = 2
				_t = 0.0
		2:
			if _t > 0.5:
				_shot("00_hammer_side")
				quit(0)
				return true
	return false
