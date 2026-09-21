extends Node3D

# One fixed pickup in an existing hiding cabinet. No collider or independent interact verb.
var _torch: Node3D
var _glow: OmniLight3D
var _slit: MeshInstance3D
var _taken := false
var _time := 0.0

func _ready() -> void:
	_torch = Node3D.new()
	_torch.name = "MissingFlashlight"
	_torch.position = Vector3(0, 0.7, 0.05)
	add_child(_torch)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.045, 0.05, 0.045)
	metal.metallic = 0.65
	metal.roughness = 0.38
	for part in [[0.028, 0.028, 0.21, 0.0], [0.047, 0.035, 0.065, 0.135], [0.031, 0.031, 0.025, -0.115]]:
		var mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = part[0]
		cylinder.bottom_radius = part[1]
		cylinder.height = part[2]
		mesh.mesh = cylinder
		mesh.position.y = part[3]
		mesh.material_override = metal
		_torch.add_child(mesh)
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.025, 0.028, 0.025)
	rubber.roughness = 0.85
	for y in [-0.07, -0.035, 0.0, 0.035]:
		var grip := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 0.031
		ring.bottom_radius = 0.031
		ring.height = 0.012
		grip.mesh = ring
		grip.position.y = y
		grip.material_override = rubber
		_torch.add_child(grip)
	var lens := MeshInstance3D.new()
	var glass := SphereMesh.new()
	glass.radius = 0.038
	glass.height = 0.018
	lens.mesh = glass
	lens.position.y = 0.17
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.48, 0.58, 0.57)
	lens_mat.metallic = 0.4
	lens_mat.roughness = 0.16
	lens.material_override = lens_mat
	_torch.add_child(lens)
	# A narrow leak over the door seam, with a faint pool on the floor beside the cabinet.
	_slit = MeshInstance3D.new()
	var strip := QuadMesh.new()
	strip.size = Vector2(0.012, 0.20)
	_slit.mesh = strip
	_slit.position = Vector3(0.0, 0.66, 0.267)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.44, 0.58, 0.51)
	_slit.material_override = glow_mat
	add_child(_slit)
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, 0.35, 0.45)
	_glow.omni_range = 2.0
	_glow.light_color = Color(0.62, 0.75, 0.64)
	_glow.light_energy = 0.25
	add_child(_glow)

func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	var lit := fmod(_time, 3.8) < 1.2
	_glow.visible = lit
	_slit.visible = lit

func collect(player: Node3D, show_pickup: bool) -> void:
	if _taken:
		return
	_taken = true
	_glow.visible = false
	_slit.visible = false
	if not show_pickup:
		_torch.queue_free()
		return
	# Briefly lift the actual prop into view while the player stays safely hidden.
	_torch.reparent(player.get_node("Camera3D"))
	_torch.position = Vector3(0.13, -0.025, -0.65)
	_torch.rotation = Vector3(0.75, 0.0, -0.35)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.1, 0.1, 0.1)
	fill.light_energy = 0.35
	fill.omni_range = 0.6
	_torch.add_child(fill)
	var tween := create_tween()
	tween.tween_property(_torch, "rotation:z", -0.1, 0.22)
	tween.tween_interval(0.65)
	tween.tween_property(_torch, "position:y", -0.6, 0.2)
	tween.tween_callback(_torch.queue_free)
