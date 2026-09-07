extends SceneTree

# Photograph the creature. **Run WITHOUT --headless** — it needs a render target.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_creature.gd
#
# Writes to user://creature_shots/ — printed at the end.
#
# ⚠️ THIS IS THE ONLY THING THAT CAN ANSWER THE QUESTION THAT MATTERS. `check_creature_model.gd`
# proves the clips exist and do not translate the root; `check_creature_anim.gd` proves each
# state picks the right one. Neither can tell you whether the thing is legible in a torch beam
# at 0.02 ambient, whether the tint is right, whether the feet slide, or whether it is facing
# you. Those are pixels, and the levels are about to get very dark.
#
# ⚠️ IT LIGHTS THE SCENE THE WAY THE GAME DOES: near-zero ambient plus ONE SpotLight3D with the
# player's own post-darkness-pass settings. Shooting this under editor lighting would produce a
# reassuring picture of a model that is invisible in the actual game.

const GLB := "res://assets/models/hollow_crown.glb"
const OUT_DIR := "user://creature_shots"

# The darkness pass's values (player.gd writes these into the Flashlight node in _ready).
const TORCH_ENERGY := 1.6
const TORCH_RANGE := 18.0
const TORCH_ANGLE := 30.0
const AMBIENT := 0.02

# distance -> what it is for
const DISTANCES := [3.0, 8.0, 15.0]
const CLIPS := ["walk", "shamble", "unsteady", "run", "sprint", "charge"]

var _stage := 0
var _t := 0.0
var _cam: Camera3D
var _torch: SpotLight3D
var _inst: Node3D
var _ap: AnimationPlayer
var _lib := ""
var _shots: Array[String] = []
var _queue: Array = []


func _find(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find(c, cls, out)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var world := Node3D.new()
	root.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.11, 0.12)
	env.ambient_light_energy = AMBIENT
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	# A floor, so the feet have something to be on and the torch has something to pool on.
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.18, 0.17, 0.16)
	fm.roughness = 1.0
	floor_mi.material_override = fm
	world.add_child(floor_mi)

	_cam = Camera3D.new()
	_cam.fov = 75.0            # the player camera's own fov
	world.add_child(_cam)
	_torch = SpotLight3D.new()
	_torch.light_energy = TORCH_ENERGY
	_torch.spot_range = TORCH_RANGE
	_torch.spot_angle = TORCH_ANGLE
	_torch.spot_angle_attenuation = 0.3
	_torch.shadow_enabled = true
	_cam.add_child(_torch)

	var packed: PackedScene = load(GLB)
	_inst = packed.instantiate()
	world.add_child(_inst)
	_inst.global_position = Vector3.ZERO
	var aps: Array = []
	_find(_inst, "AnimationPlayer", aps)
	_ap = aps[0]
	for a in _ap.get_animation_list():
		if String(a).contains("/"):
			_lib = String(a).get_slice("/", 0) + "/"
			break

	# Tint it the way `creature_stalker.gd` does — this is the picture that decides whether
	# TINT (0.55) is right for a near-black level.
	var mis: Array = []
	_find(_inst, "MeshInstance3D", mis)
	for mi in mis:
		if mi == floor_mi:
			continue
		var src := (mi as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
		if src:
			var m: StandardMaterial3D = src.duplicate()
			m.albedo_color = Color(0.55, 0.55, 0.58)
			m.metallic = 0.0
			m.roughness = 0.9
			m.emission_enabled = false
			(mi as MeshInstance3D).material_override = m

	# Build the shot list: every clip at mid-phase from 3 m, plus a distance sweep and a rear
	# view on the walk.
	for clip in CLIPS:
		_queue.append({"clip": clip, "dist": 3.0, "yaw": 0.0, "phase": 0.5,
			"name": "clip_%s" % clip})
	for d in DISTANCES:
		_queue.append({"clip": "run", "dist": d, "yaw": 0.0, "phase": 0.35,
			"name": "dist_%02dm" % int(d)})
	_queue.append({"clip": "walk", "dist": 4.0, "yaw": PI, "phase": 0.5, "name": "rear_walk"})
	_queue.append({"clip": "walk", "dist": 4.0, "yaw": PI * 0.5, "phase": 0.5,
		"name": "side_walk"})


func _place(shot: Dictionary) -> void:
	var d: float = shot["dist"]
	var yaw: float = shot["yaw"]
	# The creature faces +Z (asserted by check_creature_model.gd), so the camera stands in
	# front of it at +Z and looks back.
	var eye := Vector3(sin(yaw) * d, 1.65, cos(yaw) * d)
	_cam.global_position = eye
	_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	var full: String = _lib + String(shot["clip"])
	_ap.play(full)
	_ap.seek(_ap.get_animation(full).length * float(shot["phase"]), true)
	_ap.pause()


func _process(delta: float) -> bool:
	_t += delta
	if _t < 0.35:
		return false
	_t = 0.0
	if _stage >= _queue.size():
		print("\n== %d shots written to %s ==" % [_shots.size(),
			ProjectSettings.globalize_path(OUT_DIR)])
		for s in _shots:
			print("   " + s)
		quit(0)
		return true
	var shot: Dictionary = _queue[_stage]
	if not shot.has("_placed"):
		_place(shot)
		shot["_placed"] = true
		return false   # give the renderer a frame with the new pose before capturing
	var img := root.get_texture().get_image()
	var path := "%s/%02d_%s.png" % [OUT_DIR, _stage, shot["name"]]
	img.save_png(path)
	_shots.append(ProjectSettings.globalize_path(path))
	print("  shot %-16s clip=%-8s d=%.0fm yaw=%.0f deg"
		% [shot["name"], shot["clip"], shot["dist"], rad_to_deg(shot["yaw"])])
	_stage += 1
	return false
