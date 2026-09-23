extends Node3D

# Breach-only presentation after confirmed contact. No range checks or damage rules here.
const ART := "res://assets/textures/level_6_breach/object12_kill_closeup.png"
const KILL_SOUND := "res://assets/audio/level_6_breach/level_6_jumpscare.wav"
const DURATION := 1.45
const ACTOR_LAYER := 1 << 17 # layer 20 is reserved for mirror-only art and camera-culled
var elapsed := 0.0
var impacts := 0
var finished := false
var actor: Node3D
var rig: CreatureAnim
var _camera: Camera3D
var _player: CharacterBody3D
var _creature: Node
var _door: Node3D
var _token := -1
var _head_origin := Vector3.ZERO
var _base_fov := 75.0
var _base_camera := Transform3D.IDENTITY
var _bones: Dictionary = {}
var _overlay: CanvasLayer
var _insert: TextureRect
var _shade: ShaderMaterial
var _voice: AudioStreamPlayer
var _hit: AudioStreamPlayer
var _original_visual: Node3D
var _torch: Light3D
var _torch_mask := 0
var _hud_visibility: Dictionary = {}

func start(player: CharacterBody3D, creature: Node, door: Node3D, token: int) -> void:
	_player = player
	_creature = creature
	_door = door
	_token = token
	_camera = player.get_node("Camera3D")
	_base_fov = _camera.fov
	_base_camera = _camera.transform
	player.freeze_input()
	player.velocity = Vector3.ZERO
	creature.set_process(false)
	creature.set("_active", false)
	_original_visual = creature.get("_visual_root")
	_original_visual.visible = false
	_torch = player.get("flashlight")
	if _torch:
		_torch_mask = _torch.light_cull_mask
		_torch.light_cull_mask &= ~ACTOR_LAYER
	for child in get_tree().current_scene.get_children() + player.get_children():
		if child is CanvasLayer:
			_hud_visibility[child] = child.visible
			child.visible = false
	# The same GLB, material and rig as the pursuer; no unrelated stock monster.
	actor = Node3D.new()
	actor.name = "Object12Attack"
	add_child(actor)
	rig = CreatureAnim.build(actor)
	if rig == null:
		_complete()
		return
	for mesh in rig.mesh_instances():
		mesh.material_override = creature.get("_material")
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = ACTOR_LAYER
	rig.hold_pose(CreatureAnim.CLIP_CHARGE, 0.25)
	var skeleton := rig.skeleton()
	for i in range(skeleton.get_bone_count()):
		_bones[skeleton.get_bone_name(i)] = [i, skeleton.get_bone_global_pose(i)]
	_head_origin = actor.to_local(skeleton.to_global(_bones["Head"][1].origin))
	# A local fill makes the silhouette readable even when the torch was off.
	var light := OmniLight3D.new()
	light.position = Vector3(-0.35, 0.25, -0.15)
	light.light_color = Color(0.68, 0.75, 0.66)
	light.light_energy = 0.8
	light.light_cull_mask = ACTOR_LAYER
	light.omni_range = 2.0
	add_child(light)
	_build_insert()
	_voice = AudioStreamPlayer.new()
	_voice.stream = load(KILL_SOUND)
	# This recording is much hotter than the chase vocal. Leave headroom for the
	# two impacts; Master retains the shared limiter, outside the ambience dip.
	_voice.volume_db = -8.0
	_voice.bus = "Master"
	add_child(_voice)
	_voice.play()
	_hit = AudioStreamPlayer.new()
	_hit.stream = GameState.load_audio("impact_thud")
	_hit.volume_db = -3.0
	add_child(_hit)
	HoldBreath.dip(get_tree(), DURATION + 0.3)
	_pose(0.0)
	_note("SURGE")

func _build_insert() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 90
	add_child(_overlay)
	_insert = TextureRect.new()
	_insert.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_insert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insert.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_insert.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_insert.texture = load(ART)
	_insert.visible = false
	_overlay.add_child(_insert)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float punch = 0.0;
uniform float phase = 0.0;
void fragment() {
    vec2 p = UV - vec2(0.5);
    float angle = sin(phase * 41.0) * 0.028 * punch;
    p = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p;
    p /= 1.0 + punch * 0.16;
    p.x += sin(phase * 73.0) * 0.009 * punch;
    vec4 c = texture(TEXTURE, clamp(p + vec2(0.5), vec2(0.001), vec2(0.999)));
    c.rgb *= 1.0 - smoothstep(0.3, 0.78, length(p)) * 0.6;
    COLOR = c;
}"""
	_shade = ShaderMaterial.new()
	_shade.shader = shader
	_insert.material = _shade

func _process(delta: float) -> void:
	if finished:
		return
	if not GameState.transition_is_current(_token):
		finished = true
		queue_free()
		return
	if rig == null:
		return
	elapsed += delta
	_pose(elapsed)
	if elapsed >= 0.48 and impacts == 0:
		_impact()
	if elapsed >= 0.98 and impacts == 1:
		_impact()
	if elapsed >= DURATION:
		_complete()

func _pose(t: float) -> void:
	var surge := smoothstep(0.06, 0.42, t)
	var recoil := sin(clampf((t - 0.62) / 0.34, 0.0, 1.0) * PI)
	var second := smoothstep(0.91, 1.07, t)
	actor.position = Vector3(0.025 * sin(t * 13.0), 0.07, lerpf(-1.25, -0.61, surge) - recoil * 0.16 + second * 0.11) - _head_origin
	actor.rotation = Vector3(-0.025 * sin(t * 19.0), 0.04 * sin(t * 11.0), 0.025 * sin(t * 17.0))
	_grip("Left", Vector3(0.29, -0.12, -0.22), surge)
	_grip("Right", Vector3(-0.29, -0.12, -0.22), surge)
	var impact := maxf(_pulse(t, 0.48), _pulse(t, 0.98))
	_camera.fov = lerpf(_base_fov, 64.0, surge) + impact * 16.0
	_camera.rotation.z = _base_camera.basis.get_euler().z + sin(t * 55.0) * impact * 0.12
	_camera.position = _base_camera.origin + Vector3(0.025 * sin(t * 61.0), -0.065, 0.025) * impact
	_insert.visible = (t >= 0.48 and t < 0.64) or (t >= 0.98 and t < 1.24)
	_shade.set_shader_parameter("phase", t)
	_shade.set_shader_parameter("punch", impact)

func _pulse(t: float, at: float) -> float:
	return exp(-maxf(t - at, 0.0) * 12.0) if t >= at else 0.0

func _grip(side: String, target: Vector3, weight: float) -> void:
	# Two-bone arm solve over the existing rig: both claws actually reach for the lens.
	var skel := rig.skeleton()
	var upper: Transform3D = _bones[side + "Arm"][1]
	var lower: Transform3D = _bones[side + "ForeArm"][1]
	var hand: Transform3D = _bones[side + "Hand"][1]
	var a := upper.origin
	var b := lower.origin
	var c := hand.origin
	var goal := skel.to_local(to_global(target))
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var dir := (goal - a).normalized()
	var distance := clampf(a.distance_to(goal), absf(first - second) + 0.001, first + second - 0.001)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var bend := Vector3(1 if side == "Left" else -1, -0.5, 0)
	bend = (bend - dir * bend.dot(dir)).normalized()
	var elbow := a + dir * along + bend * sqrt(maxf(0.0, first * first - along * along))
	var wrist := a + dir * distance
	upper.basis = Basis(Quaternion((b - a).normalized(), (elbow - a).normalized())) * upper.basis
	lower.basis = Basis(Quaternion((c - b).normalized(), (wrist - elbow).normalized())) * lower.basis
	lower.origin = elbow
	hand.origin = wrist
	for entry in [[side + "Arm", upper], [side + "ForeArm", lower], [side + "Hand", hand]]:
		skel.set_bone_global_pose_override(_bones[entry[0]][0], entry[1], weight, true)

func _impact() -> void:
	impacts += 1
	_hit.pitch_scale = 0.78 if impacts == 1 else 0.66
	_hit.play()
	if impacts == 2 and is_instance_valid(_door):
		_door.slam_shut()
	_note("IMPACT %d" % impacts)

func _complete() -> void:
	if finished:
		return
	finished = true
	if _overlay:
		_overlay.visible = false
	if actor:
		actor.visible = false
	if _voice:
		_voice.stop()
	if _hit:
		_hit.stop()
	if GameState.transition_is_current(_token):
		_note("BLACK / FATAL FUNNEL")
		# Existing scene-scoped restart; no unrelated static face after the attack.
		Screamer.set("_suppress_sting", true)
		Screamer.trigger("", false, _token)

func _exit_tree() -> void:
	if is_instance_valid(_camera):
		_camera.fov = _base_fov
		_camera.transform = _base_camera
	if is_instance_valid(_original_visual):
		_original_visual.visible = true
	if is_instance_valid(_torch):
		_torch.light_cull_mask = _torch_mask
	for hud in _hud_visibility:
		if is_instance_valid(hud):
			hud.visible = _hud_visibility[hud]

func _note(phase: String) -> void:
	var log_node := get_node_or_null("/root/DebugLog")
	if log_node:
		log_node.note("OBJECT 12 KILL " + phase)
