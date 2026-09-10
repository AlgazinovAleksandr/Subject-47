extends SceneTree

# Windowed (NOT --headless): photographs Increment B so it can be judged by eye — the three coloured
# phones + desk, the hidden-vinegar notice before/after tearing it, the Blackout figure (torch off),
# and the Archive lot filling with strikes.
#
# Run:  /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_kontur_b.gd

const OUT := "/tmp/kontur_b/"

var _k: Node = null
var _p: Node3D = null
var _phase := 0
var _t := 0.0


func _initialize() -> void:
	seed(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/kontur.tscn")


func _torch(on: bool) -> void:
	if _p == null:
		return
	var fl := _p.get_node_or_null("Camera3D/Flashlight")
	if fl:
		fl.visible = on


func _look(eye: Vector3, target: Vector3) -> void:
	if _p == null:
		return
	_p.set("velocity", Vector3.ZERO)
	_p.global_position = eye
	if eye.distance_to(target) > 0.01:
		_p.look_at(target, Vector3.UP)


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
			_p = _k.get_node_or_null("Player")
			if _p:
				_p.set_physics_process(false)
			_next(1)
		1:
			# The three phones on the switchboard desk (mimic site is random; the coloured trio is
			# always there). Torch on.
			_torch(true)
			_look(Vector3(-1.5, 0.1, 45.9), Vector3(-2.4, 0.86, 45.9))
			if _t > 0.5:
				_shot("01_phones")
				_next(2)
		2:
			# The vinegar notice in the kitchen, pinned over the ledge.
			_look(Vector3(2.7, 0.1, 26.0), Vector3(3.4, 1.12, 26.0))
			if _t > 0.5:
				_shot("02_vinegar_sheet")
				# Tear it.
				var sheet = _k.get_node_or_null("VinegarSign")
				if sheet:
					sheet.call("interact")
				_next(3)
		3:
			if _t > 0.7:
				_look(Vector3(2.7, 0.1, 26.0), Vector3(3.4, 1.0, 26.0))
				_shot("03_vinegar_revealed")
				_next(4)
		4:
			# The Blackout figure — torch OFF, standing in the gate-7 room.
			var dx: float = float(_k.get("_dark_x"))
			_torch(false)
			_look(Vector3(dx, 0.1, 52.5), Vector3(dx + (-1.6 if dx >= 0.0 else 1.6), 1.1, 56.0))
			if _t > 0.6:
				_shot("04_blackout_figure_dark")
				_torch(true)
				_shot("05_blackout_figure_lit")   # same view, torch on — the figure is gone
				_next(5)
		5:
			# The Archive lot filling with strikes.
			_k.call("_strike", "TEST 1")
			_k.call("_strike", "TEST 2")
			if _p:
				_p.set("_panic", 0.0)   # clear the HUD blur so the lot reads
			_next(6)
		6:
			if _t > 1.4:   # let the strike flash clear
				_torch(true)
				_look(Vector3(0.2, 0.1, 41.6), Vector3(2.3, 1.0, 41.6))
				_shot("06_archive_lot")
				print("done")
				quit(0)
				return true
	return false


func _next(p: int) -> void:
	_phase = p
	_t = 0.0
