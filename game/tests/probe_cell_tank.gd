extends SceneTree
# THROWAWAY (K-CELL 2026-09-23). Windowed: renders KONTUR's tank on the approach, lit and through
# the blackout charge, and measures the lunge reach + collar tracking. Output dir = first user arg.
var OUT := "/tmp/cell_tank/"
var _k: Node
var _p: CharacterBody3D
var _cam: Camera3D
var _cell: Node3D
var _phase := 0
var _t := 0.0
var _minz := 9.0
var _collar_err := 0.0
var _shots := [
	["01_arrive_east", Vector3(2.0, 0.1, 13.5), Vector3(2.75, 1.3, 16.9)],
	["02_arrive_west", Vector3(-1.6, 0.1, 13.6), Vector3(2.75, 1.4, 16.9)],
	["03_walkline", Vector3(0.2, 0.1, 15.2), Vector3(2.75, 1.4, 16.9)],
	["04_front", Vector3(-0.2, 0.1, 16.9), Vector3(2.75, 1.45, 16.9)],
	["05_front_close", Vector3(0.9, 0.1, 16.6), Vector3(2.75, 1.5, 16.9)],
	["06_north", Vector3(0.9, 0.1, 19.4), Vector3(2.75, 1.4, 16.9)],
	["07_drain", Vector3(0.1, 0.1, 17.6), Vector3(1.3, 0.2, 16.9)],
]
var _si := 0
var _f := 0
var _south := false

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		OUT = a[0].trim_suffix("/") + "/"
	_south = a.size() > 1 and a[1] == "south"
	if _south:
		_shots = []
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(7)
	change_scene_to_file("res://scenes/kontur.tscn")

func _look(eye: Vector3, at: Vector3) -> void:
	_p.global_position = eye
	_p.velocity = Vector3.ZERO
	var to := at - (eye + Vector3(0, 1.65, 0))
	var flat := Vector3(to.x, 0, to.z)
	_p.rotation.y = atan2(-flat.x, -flat.z)
	_cam.rotation.x = atan2(to.y, flat.length())

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("wrote ", n)

func _bones_minz() -> float:
	var anim = _cell.get("_anim")
	var sk: Skeleton3D = anim.skeleton()
	var m := 9.0
	for nm in ["LeftHand", "RightHand", "Head", "head_end", "headfront", "LeftForeArm", "RightForeArm"]:
		var i := sk.find_bone(nm)
		var p: Vector3 = _cell.to_local(sk.global_transform * sk.get_bone_global_pose(i).origin)
		m = minf(m, p.z)
	return m

func _collar_off() -> float:
	var anim = _cell.get("_anim")
	var sk: Skeleton3D = anim.skeleton()
	var nk: Vector3 = _cell.to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("neck")).origin)
	var col: Node3D = _cell.get_node("Collar")
	return Vector2(col.position.x - nk.x, col.position.z - nk.z).length()

func _process(d: float) -> bool:
	_t += d
	match _phase:
		0:
			if _t < 1.8: return false
			_k = current_scene
			_p = _k.get_node("Player")
			_cam = _p.get_node("Camera3D")
			_cell = _k.get("_cell")
			_p.set_physics_process(false)
			_next(1)
		1:
			if _shots.is_empty():
				_next(2)
				return false
			var s = _shots[_si]
			_look(s[1], s[2])
			if _t > 1.2:   # let the head come round
				_shot(s[0])
				_si += 1
				if _si >= _shots.size():
					_next(2)
				else:
					_t = 0.0
		2:
			# blackout via the real gate-1 path; wait out the forced torch-off
			_look(Vector3(0.0, 0.1, 11.0), Vector3(2.75, 1.4, 16.9))
			_k.call("_on_gate1_chosen", true)
			_next(3)
		3:
			# in the Passage, 5 m from the tank: outside CELL_CHARGE_DIST (3.5)
			_look(Vector3(-1.5, 0.1, 14.2), Vector3(2.75, 1.4, 16.9))
			if _t > 4.2:
				_shot("10_blackout_approach")
				_next(4)
		4:
			# 3.18 m from the tank centre (west) or 3.23 m (south, the AnteEast walk): the level's
			# own _tick_cell_charge fires it
			if _south:
				_look(Vector3(2.3, 0.1, 13.7), Vector3(2.75, 1.5, 16.9))
			else:
				_look(Vector3(-0.3, 0.1, 16.0), Vector3(2.75, 1.5, 16.9))
			_minz = minf(_minz, _bones_minz())
			_collar_err = maxf(_collar_err, _collar_off())
			_f += 1
			if _f in [3, 5, 7, 9, 12, 16]:
				_shot("%s11_charge_f%02d_%.2fs" % ["S" if _south else "", _f, _t])
			if _t > 1.6:
				_shot(("S" if _south else "") + "14_after_charge_cracked")
				print("charged=", _k.get("_cell_charged"), " cracked=", _cell.call("cracked_face"), " dir=", _cell.get("_lunge_dir"), " dist=", _cell.get("_lunge_dist"))
				print("LUNGE min bone z (local) = %.3f  (front glass inner face at -0.935)" % _minz)
				print("collar-to-neck horizontal offset max = %.3f m" % _collar_err)
				_next(5)
		5:
			_k.call("_end_cell_blackout")
			_look(Vector3(0.3, 0.1, 16.2), Vector3(2.75, 1.5, 16.9))
			if _t > 1.0:
				_shot("15_after_restored")
				quit(0)
				return true
	return false

func _next(p: int) -> void:
	_phase = p
	_t = 0.0
