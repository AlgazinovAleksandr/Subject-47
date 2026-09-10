extends SceneTree

# Windowed (NOT --headless): photographs Increment A's Object-12 beat so it can be judged by eye.
# Drives the real player so the torch lights the scene, triggers the blackout via the real gate-1
# path, and captures the darkened doors, the torch-only Passage, and the glass charge.
#
# Run:  /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_kontur_bs1.gd

const OUT := "/tmp/kontur_bs1/"

var _k: Node = null
var _p: Node3D = null
var _cell: Node3D = null
var _phase := 0
var _t := 0.0


func _initialize() -> void:
	seed(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/kontur.tscn")


func _look(eye: Vector3, target: Vector3) -> void:
	if _p == null:
		return
	# Body on the FLOOR (camera child sits +1.65 above), physics already frozen so it does not
	# fall between plant and capture. look_at the REAL subject point so the camera (and its child
	# torch) aim at it; the small body tilt is invisible in the shot.
	_p.set("velocity", Vector3.ZERO)
	_p.global_position = eye
	if eye.distance_to(target) > 0.01:
		_p.look_at(target, Vector3.UP)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("wrote ", OUT, name, ".png")


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 1.6:
				return false
			_k = current_scene
			_p = _k.get_node_or_null("Player")
			_cell = _k.get("_cell")
			if _p:
				_p.set_physics_process(false)   # stop gravity so plant-and-aim holds
			_next(1)
		1:
			# Both choice doors, head-on: the black leaf should now read BLACK, the red RED.
			_look(Vector3(0, 0.1, 5.5), Vector3(0, 1.4, 10.0))
			if _t > 0.4:
				_shot("01_doors")
				_next(2)
		2:
			# Pass gate 1 the way the black door does -> the lamp blows, the room goes torch-only.
			_k.call("_on_gate1_chosen", true)
			_next(3)
		3:
			# The dark Passage, torch only, the booth ahead-right (still outside charge range).
			_look(Vector3(0, 0.1, 13.5), Vector3(2.75, 1.4, 16.9))
			if _t > 0.7:
				_shot("02_dark_passage")
				_next(4)
		4:
			# Close in: the charge fires (distance < CELL_CHARGE_DIST 3.5).
			_look(Vector3(1.2, 0.1, 15.8), Vector3(2.75, 1.4, 16.9))
			if _t > 0.15:
				_shot("03_charge_a")
				_next(5)
		5:
			if _t > 0.18:
				_shot("04_charge_b")
				_next(6)
		6:
			if _t > 0.5:
				_shot("05_charge_settle")
				print("done")
				quit(0)
				return true
	return false


func _next(p: int) -> void:
	_phase = p
	_t = 0.0
