extends Node3D

# Breach-owned industrial approach. The parent appends these cells to its single
# RoomBuilder build, but keeps them OUT of Object 12's hunt navigation graph.
# The 271.8 m authored centreline takes about 68 seconds at the normal 4 m/s walk.
# Machinery is harmless; there are no panic zones, pursuit cues or timed locks.
signal committed

const START_SPAWN := Vector3(-97, 0.1, -68)
const START_YAW := -PI / 2.0
const BACK_DOOR_POS := Vector3(-99.75, 1.2, -68)
const ROOMS := [
	{ "name": "ApproachService", "pos": Vector2(-70, -68), "size": Vector2(60, 6), "h": 3.6 },
	{ "name": "ApproachPumpReturn", "pos": Vector2(-43, -55), "size": Vector2(6, 20), "h": 4.0 },
	{ "name": "ApproachObservation", "pos": Vector2(-73, -48), "size": Vector2(54, 6), "h": 3.4 },
	{ "name": "ApproachInspectionTurn", "pos": Vector2(-97, -34), "size": Vector2(6, 22), "h": 3.4 },
	{ "name": "ApproachDamaged", "pos": Vector2(-78, -26), "size": Vector2(32, 6), "h": 3.8, "skin": "ruptured" },
	{ "name": "ApproachPlenum", "pos": Vector2(-44, -28), "size": Vector2(36, 10), "h": 5.2 },
	{ "name": "ApproachContainment", "pos": Vector2(-11.5, -26), "size": Vector2(29, 6), "h": 3.4, "skin": "organic" },
	{ "name": "ApproachThreshold", "pos": Vector2(0, -13), "size": Vector2(6, 20), "h": 3.0 },
	{ "name": "ApproachBayA", "pos": Vector2(-80, -41.5), "size": Vector2(10, 7), "h": 3.4 },
	{ "name": "ApproachBayB", "pos": Vector2(-63, -41.5), "size": Vector2(10, 7), "h": 3.4 },
]
const DOORS := [
	{ "pos": Vector2(-43, -65), "width": 2.4, "dir": "z", "h": 2.8 },
	{ "pos": Vector2(-46, -48), "width": 2.4, "dir": "x", "h": 2.8 },
	{ "pos": Vector2(-97, -45), "width": 2.4, "dir": "z", "h": 2.8 },
	{ "pos": Vector2(-94, -26), "width": 2.4, "dir": "x", "h": 2.8 },
	{ "pos": Vector2(-62, -26), "width": 2.4, "dir": "x", "h": 2.8 },
	{ "pos": Vector2(-26, -26), "width": 2.4, "dir": "x", "h": 2.8 },
	{ "pos": Vector2(0, -23), "width": 2.4, "dir": "z", "h": 2.8 },
	{ "pos": Vector2(0, -3), "width": 1.8, "dir": "z", "h": 2.5 },
	# These openings are sealed inspection windows, not alternate player routes.
	{ "pos": Vector2(-80, -45), "width": 7.0, "dir": "z", "h": 2.8 },
	{ "pos": Vector2(-63, -45), "width": 7.0, "dir": "z", "h": 2.8 },
]
const WALK_POINTS: Array[Vector3] = [
	START_SPAWN, Vector3(-43, 0.1, -68), Vector3(-43, 0.1, -48),
	Vector3(-97, 0.1, -48), Vector3(-97, 0.1, -26),
	Vector3(-78, 0.1, -26), Vector3(-44, 0.1, -26),
	Vector3(0, 0.1, -26), Vector3(0, 0.1, -1.2),
]

var completed := false
var _player: CharacterBody3D
var _gate: Node3D
var _gate_blocker: CollisionShape3D
var _gate_sound: AudioStreamPlayer3D
var _steel: StandardMaterial3D
var _rust: StandardMaterial3D
var _dark: StandardMaterial3D
var _indicator: StandardMaterial3D
var _beats: Array[Dictionary] = []
var _time := 0.0
var _configured := false


func configure(_builder: RoomBuilder, player: CharacterBody3D, already_completed: bool) -> void:
	_player = player
	_steel = _material(Color(0.25, 0.29, 0.28), 0.65)
	_dark = _material(Color(0.075, 0.09, 0.095), 0.5)
	_rust = RoomBuilder.make_material("res://assets/textures/level_6_breach/breach_wall_ruptured.png",
		Vector3(0.45, 0.45, 0.45), Color(0.27, 0.16, 0.1))
	_indicator = _material(Color(0.36, 0.5, 0.45), 0.0)
	_indicator.emission_enabled = true
	_indicator.emission = Color(0.16, 0.29, 0.22)
	_indicator.emission_energy_multiplier = 0.4
	_build_service()
	_build_observation()
	_build_damaged()
	_build_threshold()
	_configured = true
	if already_completed:
		seal_immediate()


func _build_service() -> void:
	# Exposed plenum and its retaining straps give the long first view a purpose.
	_box("ServiceDuct", Vector3(-70, 2.92, -69.4), Vector3(58, 0.72, 1.05), _steel)
	for x in range(-95, -42, 8):
		_box("DuctClamp", Vector3(x, 2.92, -69.4), Vector3(0.13, 0.84, 1.17), _dark)
		_box("CableTray", Vector3(x, 2.35, -65.38), Vector3(6.2, 0.13, 0.42), _dark)
		_lamp(Vector3(x, 2.65, -67.0), Color(0.52, 0.7, 0.73), 0.8, 8.5)
		_box("ServiceFloorJoint", Vector3(x, 0.012, -68), Vector3(0.06, 0.018, 5.5), _dark)
	# The first sound has an identifiable loose metal source, with a short rattle.
	var fitting := _box("LooseDuctFitting", Vector3(-76, 2.48, -69.3), Vector3(0.8, 0.12, 0.8), _rust)
	_beat(Vector3(-76, 1.0, -68), "res://assets/audio/level_1_lab/metal_creak.ogg", fitting, null, 7.0, -13.0)
	_sign("UTILITY INTAKE   /   06", Vector3(-91, 2.05, -65.18), PI, 0.009)
	_sign("PRESSURE RETURN  →", Vector3(-43, 2.2, -70.79), 0.0, 0.007)
	for z in [-60.0, -51.0]:
		_pressure_vessel(Vector3(-44.8, 0.0, z), 0.62, 2.35)
		_lamp(Vector3(-41.2, 2.8, z), Color(0.68, 0.59, 0.38), 0.8, 8.0)
	# Small gauge and a connected manifold communicate pressure, not a puzzle.
	var manifold := _box("PressureManifold", Vector3(-44.85, 1.75, -55.5), Vector3(0.35, 0.6, 1.8), _steel)
	_beat(Vector3(-43, 1.0, -56), "res://assets/audio/shared/pipe_groan.wav", manifold, null, 5.0, -15.0)


func _build_observation() -> void:
	for x in range(-94, -47, 9):
		_lamp(Vector3(x, 2.8, -49.4), Color(0.5, 0.66, 0.65), 0.65, 8.0)
		_box("ObservationTray", Vector3(x, 2.95, -50.35), Vector3(8.5, 0.16, 0.55), _dark)
	for x in [-80.0, -63.0]:
		# Clear enough to read the empty bay. Opaque dirt streaks leave the machines visible.
		var glass := _material(Color(0.22, 0.32, 0.3, 0.16), 0.1)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_box("InspectionGlass", Vector3(x, 1.9, -45.01), Vector3(6.85, 1.65, 0.04), glass)
		_solid("InspectionWindowBarrier", Vector3(x, 1.4, -45.0), Vector3(7.0, 2.8, 0.1))
		_box("InspectionWindowSill", Vector3(x, 0.52, -45.05), Vector3(7.0, 1.04, 0.23), _steel)
		_box("InspectionHeader", Vector3(x, 2.77, -45.1), Vector3(7.05, 0.12, 0.2), _dark)
		for offset in [-3.45, 0.0, 3.45]:
			_box("InspectionMullion", Vector3(x + offset, 1.92, -45.1), Vector3(0.09, 1.65, 0.19), _steel)
		for offset in [-2.2, 1.25, 2.8]:
			_box("WindowResidue", Vector3(x + offset, 2.1, -45.045), Vector3(0.055, 0.84, 0.018), _rust)
		_pressure_vessel(Vector3(x - 2.0, 0, -40.4), 0.75, 2.35)
		_box("EmptyInspectionRack", Vector3(x + 2.0, 0.65, -40.2), Vector3(2.0, 1.3, 0.8), _dark)
		for offset in [-0.7, 0.0, 0.7]:
			_box("RackSlot", Vector3(x + 2.0 + offset, 1.18, -40.68), Vector3(0.14, 0.7, 0.05), _steel)
		var bay_light := _lamp(Vector3(x, 2.7, -40.8), Color(0.43, 0.65, 0.56), 1.1, 6.5)
		if x == -63.0:
			_beat(Vector3(x, 1, -48), "res://assets/audio/level_1_lab/metal_creak.ogg", null, bay_light, 5.0, -18.0)
		_sign("INSPECTION   /   ISOLATED", Vector3(x, 0.78, -45.2), PI, 0.006)
	_lamp(Vector3(-97, 2.7, -40), Color(0.56, 0.67, 0.6), 0.7, 8.0)
	_lamp(Vector3(-97, 2.7, -30), Color(0.73, 0.48, 0.28), 0.7, 8.0)
	_box("ReturnRiser", Vector3(-99.35, 1.5, -35), Vector3(0.6, 3.0, 9.0), _steel)
	_sign("CONTAINMENT SERVICES  →", Vector3(-97, 2.15, -23.2), PI, 0.007)


func _build_damaged() -> void:
	# Bent ducts and wall-fastened material, all above/beside the clear walking lane.
	for x in range(-89, -62, 8):
		var broken := _box("DisplacedDuct", Vector3(x, 2.85, -27.8), Vector3(6.7, 0.8, 0.7), _rust)
		broken.rotation.z = -0.06 if x % 2 == 0 else 0.09
		_lamp(Vector3(x, 2.55, -24.0), Color(0.74, 0.48, 0.27), 0.85, 8.0)
		_box("CableDrop", Vector3(x + 1.1, 2.8, -28.3), Vector3(0.035, 1.5, 0.035), _dark)
	# The enlarged volume interrupts the corridor rhythm: a low walking lane
	# beside tall receivers, under a roof-sized ventilation assembly.
	_box("MainVentilationPlenum", Vector3(-44, 4.4, -28.8), Vector3(33.0, 1.05, 3.8), _steel)
	for x in [-58.0, -49.0, -40.0, -31.0]:
		_pressure_vessel(Vector3(x, 0.0, -30.6), 1.0, 3.25)
		_box("PlenumSuspension", Vector3(x, 4.65, -26.5), Vector3(0.1, 1.0, 0.1), _dark)
		_lamp(Vector3(x, 3.25, -24.1), Color(0.66, 0.49, 0.3), 1.0, 9.0)
	var duct := _box("PressureReleaseHousing", Vector3(-41, 2.5, -29.4), Vector3(1.0, 0.6, 0.7), _rust)
	_beat(Vector3(-41, 1.0, -26), "res://assets/audio/shared/pipe_groan.wav", duct, null, 8.0, -10.0)
	_sign("RECEIVER BANK   /   PRESSURE LOST", Vector3(-44, 2.1, -23.18), PI, 0.008)
	var organic := RoomBuilder.make_material("res://assets/textures/level_6_breach/breach_wall_organic.png",
		Vector3(0.4, 0.4, 0.4), Color(0.2, 0.16, 0.08))
	for x in [-21.0, -13.0, -5.0]:
		_box("ContainmentWallDamage", Vector3(x, 1.5, -28.78), Vector3(5.2, 2.6, 0.12), organic)
		_lamp(Vector3(x, 2.5, -24.05), Color(0.7, 0.38, 0.22), 0.65, 7.5)
		_box("DamagedCableTray", Vector3(x, 2.8, -28.0), Vector3(6.7, 0.15, 0.5), _rust)


func _build_threshold() -> void:
	# Last dogleg is intentionally quiet; it conceals the existing hunt wing.
	for z in [-19.0, -10.0, -4.5]:
		_lamp(Vector3(1.6, 2.55, z), Color(0.54, 0.65, 0.58), 0.7, 7.0)
		_box("ThresholdCableTray", Vector3(-2.5, 2.7, z), Vector3(0.55, 0.15, 5.5), _dark)
	_sign("OBJECT 12\nCONTAINMENT WING", Vector3(0, 2.58, -3.17), PI, 0.006)
	for x in [-1.02, 1.02]:
		_box("BulkheadRail", Vector3(x, 1.35, -3.06), Vector3(0.16, 2.7, 0.34), _steel)
	_gate = Node3D.new()
	_gate.name = "ContainmentBulkheadLeaf"
	add_child(_gate)
	_gate.position = Vector3(0, 4.05, -3)
	_box("BulkheadSteel", Vector3.ZERO, Vector3(1.84, 2.54, 0.24), _steel, _gate)
	var door_mat := _material(Color.WHITE, 0.45)
	door_mat.albedo_texture = load("res://assets/textures/level_6_breach/breach_door.png")
	for side in [-1.0, 1.0]:
		var face := MeshInstance3D.new()
		face.name = "BulkheadBreachFace"
		var quad := QuadMesh.new()
		quad.size = Vector2(1.82, 2.52)
		face.mesh = quad
		face.material_override = door_mat
		_gate.add_child(face)
		face.position.z = side * 0.125
		face.rotation.y = PI if side < 0 else 0.0
	for y in [-0.85, -0.3, 0.3, 0.85]:
		_box("BulkheadReinforcement", Vector3(0, y, -0.17), Vector3(1.68, 0.12, 0.1), _dark, _gate)
		_box("BulkheadInsideReinforcement", Vector3(0, y, 0.17), Vector3(1.68, 0.12, 0.1), _dark, _gate)
	_gate_blocker = _solid("ContainmentBulkheadBlocker", Vector3(0, 1.3, -3), Vector3(1.86, 2.6, 0.32))
	_gate_blocker.disabled = true
	_gate_sound = _audio(Vector3(0, 1.3, -3), "res://assets/audio/level_6_breach/blast_door_slam.wav", -7.0, 22.0)


func seal_immediate() -> void:
	completed = true
	_gate.position.y = 1.27
	_gate_blocker.set_deferred("disabled", false)
	_stop_machinery()


func _process(delta: float) -> void:
	if not _configured or completed or not is_instance_valid(_player):
		return
	_time += delta
	var p := _player.global_position
	if p.z >= -1.5 and absf(p.x) < 2.0:
		# Player is fully clear before the blocker activates. No camera/input lock.
		completed = true
		_gate_blocker.set_deferred("disabled", false)
		_stop_machinery()
		var tween := create_tween()
		tween.tween_property(_gate, "position:y", 1.27, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_gate_sound.play)
		committed.emit()
		return
	for beat in _beats:
		if not beat.fired and p.distance_to(beat.pos) < beat.radius:
			beat.fired = true
			beat.started = _time
			beat.audio.play()
		if beat.fired:
			var elapsed: float = _time - beat.started
			if is_instance_valid(beat.prop):
				beat.prop.rotation.z = sin(elapsed * 33.0) * 0.065 * maxf(0.0, 1.0 - elapsed / 1.1)
			if is_instance_valid(beat.lamp):
				# Brief faulty circuit, returning to precisely the same empty bay.
				beat.lamp.visible = not (elapsed > 0.18 and elapsed < 0.8)


func _stop_machinery() -> void:
	for beat in _beats:
		beat.audio.stop()
		if is_instance_valid(beat.lamp):
			beat.lamp.visible = true


func _beat(pos: Vector3, path: String, prop: Node3D, lamp: OmniLight3D, radius: float, gain: float) -> void:
	_beats.append({"pos": pos, "audio": _audio(pos, path, gain, 17.0), "prop": prop,
		"lamp": lamp, "radius": radius, "fired": false, "started": 0.0})


func _audio(pos: Vector3, path: String, gain: float, distance: float) -> AudioStreamPlayer3D:
	var speaker := AudioStreamPlayer3D.new()
	speaker.name = "ApproachMachineryAudio"
	speaker.stream = load(path)
	speaker.volume_db = gain
	speaker.max_distance = distance
	speaker.unit_size = 4.0
	speaker.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(speaker)
	speaker.position = pos
	return speaker


func _pressure_vessel(pos: Vector3, radius: float, height: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 16
	var body := MeshInstance3D.new()
	body.name = "PressureReceiver"
	body.mesh = cylinder
	body.material_override = _rust
	add_child(body)
	body.position = pos + Vector3(0, height * 0.5 + 0.12, 0)
	for y in [0.32, height - 0.1]:
		var band := TorusMesh.new()
		band.inner_radius = radius - 0.04
		band.outer_radius = radius + 0.07
		band.rings = 16
		band.ring_segments = 8
		var mesh := MeshInstance3D.new()
		mesh.mesh = band
		mesh.material_override = _steel
		add_child(mesh)
		mesh.position = pos + Vector3(0, y, 0)
	_box("ReceiverFoot", pos + Vector3(0, 0.1, 0), Vector3(radius * 1.7, 0.2, radius * 1.7), _dark)
	_box("PressureGauge", pos + Vector3(0, height * 0.65, radius + 0.02), Vector3(0.23, 0.25, 0.09), _steel)
	_box("GaugeFace", pos + Vector3(0, height * 0.65, radius + 0.073), Vector3(0.16, 0.17, 0.01), _indicator)


func _lamp(pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	_box("EmergencyFitting", pos, Vector3(0.65, 0.07, 0.19), _indicator)
	var light := OmniLight3D.new()
	light.name = "ApproachEmergencyLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	add_child(light)
	light.position = pos - Vector3(0, 0.13, 0)
	return light


func _sign(text: String, pos: Vector3, yaw: float, scale: float) -> void:
	var label := Label3D.new()
	label.name = "IndustrialWayfinding"
	label.text = text
	label.font_size = 36
	label.pixel_size = scale
	label.modulate = Color(0.57, 0.64, 0.57)
	label.no_depth_test = false
	label.shaded = true
	label.outline_size = 0
	add_child(label)
	label.position = pos
	label.rotation.y = yaw


func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.85
	return mat


func _box(label: String, pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	(parent if parent != null else self).add_child(mesh)
	mesh.position = pos
	return mesh


func _solid(label: String, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return shape
