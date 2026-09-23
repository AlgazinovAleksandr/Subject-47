extends SceneTree
# THROWAWAY (K-CELL 2026-09-23). Windowed: the BREACHED tank in an empty lit room.
var OUT := "/tmp/"
var _t := 0.0
var _i := 0
var _cam: Camera3D
var _cell: Node3D
var _root: Node3D
var _views := [
	["20_breached_three_quarter", Vector3(-1.9, 1.6, -3.3), Vector3(0, 1.1, 0)],
	["21_breached_front", Vector3(0.0, 1.62, -3.1), Vector3(0, 1.25, 0)],
	["22_breached_shards", Vector3(1.0, 1.35, -2.9), Vector3(0, 0.15, -1.5)],
	["23_breached_inside_out", Vector3(0.1, 1.72, 0.35), Vector3(0, 1.3, -2.5)],
	["24_breached_collar", Vector3(-0.9, 1.7, -2.0), Vector3(0, 1.6, 0.1)],
]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: OUT = a[0].trim_suffix("/") + "/"
	_root = Node3D.new()
	root.add_child(_root)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.7)
	env.ambient_light_energy = 0.12
	we.environment = env
	_root.add_child(we)
	var fl := CSGBox3D.new()
	fl.size = Vector3(10, 0.2, 10)
	fl.position = Vector3(0, -0.1, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.31, 0.29)
	fl.material = fm
	fl.use_collision = true
	_root.add_child(fl)
	var wall := CSGBox3D.new()
	wall.size = Vector3(10, 3.2, 0.2)
	wall.position = Vector3(0, 1.6, 1.35)
	wall.material = fm
	_root.add_child(wall)
	for p in [Vector3(-1.5, 2.9, -2.0), Vector3(1.8, 2.9, 0.5)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_energy = 0.7
		l.omni_range = 7.0
		l.shadow_enabled = true
		_root.add_child(l)
	_cell = load("res://scripts/containment_cell.gd").new()
	_cell.set("state", "breached")
	_root.add_child(_cell)
	_cam = Camera3D.new()
	_cam.fov = 75
	_root.add_child(_cam)
	_cam.current = true
	var torch := SpotLight3D.new()
	torch.light_energy = 1.2
	torch.spot_range = 14
	torch.spot_angle = 30
	_cam.add_child(torch)
func _process(d: float) -> bool:
	_t += d
	var v = _views[_i]
	_cam.global_position = v[1]
	_cam.look_at(v[2], Vector3.UP)
	if _t > 1.0:
		root.get_viewport().get_texture().get_image().save_png(OUT + v[0] + ".png")
		print("wrote ", v[0])
		_i += 1
		_t = 0.0
		if _i >= _views.size():
			print("shards ", _cell.call("breach_shard_counts"), " occupant ", _cell.get_node_or_null("Object12"))
			quit(0)
			return true
	return false
