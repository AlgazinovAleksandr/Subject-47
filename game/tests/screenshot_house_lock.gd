extends SceneTree

# H4 (2026-09-13): photographs the lock falling off the exit door and the scrawl. Windowed:
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_house_lock.gd

const OUT := "/tmp/house_lock/"
var _p: Node3D = null
var _t := 0.0
var _phase := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("wrote ", n)


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 1.5:
				return false
			_p = current_scene.get_node("Player")
			_p.set_physics_process(false)
			_p.global_position = Vector3(-0.7, 0.1, 17.2)
			_p.call("ai_look_at", Vector3(-0.7, 0.9, 18.9))
			# The house is dark until the notes are read; light the lock lamp so the beat is legible.
			current_scene.set("_lock_lamp_gain", 1.0)
			current_scene.set("_lock_lamp_on", true)
			_t = 0.0
			_phase = 1
		1:
			if _t > 0.5:
				_shot("01_lock_on_door")
				current_scene.get_node("ExitDoor/ExitLock").emit_signal("unlocked")
				_t = 0.0
				_phase = 2
		2:
			if _t > 0.3:
				_shot("02_lock_falling")
				_phase = 3
		3:
			if _t > 0.75:
				_shot("03_lock_down_scrawl")
				_phase = 4
		4:
			if _t > 1.8:
				_shot("04_lock_gone")
				quit(0)
				return true
	return false
