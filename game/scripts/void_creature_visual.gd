extends Node3D
class_name VoidCreatureVisual

# A standing fault in the stone: the silhouette is human, but none of the pieces touch.
# +Z is forward, matching CreatureStalker. The host owns every animation tick so that looking
# at the creature freezes even an unfinished attack.
#
# ⭐ REBUILT 2026-09-20 ("*Shall we make the creature more creepy also*"). Capture #2
# photographed what it was: a 1.85 m mannequin, every fragment touching its neighbour, a
# uniform mid-grey, standing straight with its arms at its sides. It read as a shop dummy.
# What changed, item by item:
#   * 2.2 m tall — it is a head and a half taller than the player, not a person's size.
#   * ape-long arms: the fingertips hang at KNEE height.
#   * the head is DETACHED. There is a 12 cm hole of nothing between the neck splinter and
#     the skull, and the skull is rolled 22 degrees onto one shoulder.
#   * a RECESSED face, 4 cm behind the brow, that carries the generated broken face
#     (`void_face.png`, a shattered stone head with one socket caved in) and, in front of it,
#     a jumble of the level's own broken objects — the user's call, added mid-build: *"a very
#     ugly broken face… not even recognizable as a face anymore… representing different
#     objects but you cannot understand them"*. `void_face.gd` owns the recipe. No emission
#     anywhere on the figure — this project has no glow or tonemapping, so any emission
#     above ~1.0 would clamp to a flat white blob.
#   * 4-8 cm of black between every fragment in the vertical stack and at every joint, and
#     joints that do not line up: the shoulders are at different heights, the arms are
#     different lengths, the hips are askew.
#   * albedo ~0.25 stone (it was 0.43). Pale is now reserved for small EDGE chips.
#   * the rest pose is a lean-forward mid-stride REACH. It is never caught standing neutrally;
#     it is always caught in the middle of coming for you.
#   * five variants, keyed deterministically off the owning stalker's node name.
#
# ⚠️ THE HEAD TRACKS THE PLAYER ONLY IN UNOBSERVED TICKS. `tick_gait()` returns before any of
# it when the gait is WATCHED, which is the level's entire mechanic and what
# `check_stalker_motion.gd` measures (zero mesh-transform drift in a watched frame). Look away
# and look back and it is facing you; watch it and nothing moves by a millimetre.
enum Gait { DORMANT, WATCHED, ADVANCING }

const _VOID_FACE := preload("res://scripts/void_face.gd")
const ATTACK_DURATION := 0.46
const STEP_RATE := 5.4
const HEAD_TRACK_RATE := 2.2          # how fast the head swings round while unobserved
const HEAD_TRACK_LIMIT := 1.45        # radians either side of rest; it cannot spin

const STONE := Color(0.25, 0.23, 0.30)
const PALE := Color(0.44, 0.41, 0.49)
const DARK := Color(0.06, 0.055, 0.075)

var _gait: int = Gait.DORMANT
var _phase: float = 0.0
var _attack_time: float = -1.0
var _variant: int = 0
var _parts: Array[Node3D] = []
var _rests: Array[Transform3D] = []
var _meshes: Array[MeshInstance3D] = []
var _chest: Node3D
var _head: Node3D
var _hips: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_knee: Node3D
var _right_knee: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_hand: Node3D
var _right_hand: Node3D
var _chest_shard: MeshInstance3D
var _jaw_shard: MeshInstance3D
var _head_rest_yaw := 0.0
var _head_yaw := 0.0
var _camera: Camera3D


func _ready() -> void:
	_variant = _variant_for(_owner_label())
	_build()
	_remember_pose(self)


# Deterministic per creature: the same stalker wears the same wrongness every load, so a
# player who meets D twice meets the SAME thing twice. B/C/D/E/F map to 3/4/0/1/2.
static func _variant_for(label: String) -> int:
	var total := 0
	for i in range(label.length()):
		total += label.unicode_at(i)
	return total % 5


# The visual is a child of the stalker's inner body, which is a child of the stalker node.
func _owner_label() -> String:
	var body := get_parent()
	if body == null:
		return "Void"
	var host := body.get_parent()
	return String(host.name) if host != null else String(body.name)


func variant() -> int:
	return _variant


func set_gait(gait: int) -> void:
	_gait = gait


func tick_gait(delta: float, gait: int) -> void:
	set_gait(gait)
	# ⚠️ EVERYTHING below this line is unobserved-only. Do not move it above the guard.
	if _gait == Gait.WATCHED or _chest == null:
		return
	_track_head(delta)
	# The first encounter presents a completely inert sculpture. When movement stops,
	# preserve the broken pose instead of visibly snapping to a rest pose — but the head
	# still finds you, because that is the one thing this level is about.
	if _gait != Gait.ADVANCING and _attack_time < 0.0:
		_apply_head_yaw()
		return
	_phase += maxf(delta, 0.0) * STEP_RATE
	_restore_pose()
	_pose_stride()
	if _attack_time >= 0.0:
		_attack_time = minf(_attack_time + maxf(delta, 0.0), ATTACK_DURATION)
		_pose_attack()
		if _attack_time >= ATTACK_DURATION:
			_attack_time = -1.0
	_apply_head_yaw()


func attack() -> void:
	# No tween or AnimationPlayer can continue outside the gaze-controlled tick.
	_attack_time = 0.0


func mesh_instances() -> Array[MeshInstance3D]:
	return _meshes


# ── the head ───────────────────────────────────────────────────────────────────
func _player_camera() -> Camera3D:
	if is_instance_valid(_camera):
		return _camera
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	_camera = player.get_node_or_null("Camera3D") as Camera3D
	return _camera


func _track_head(delta: float) -> void:
	if _head == null:
		return
	var camera := _player_camera()
	if camera == null:
		return
	var parent := _head.get_parent() as Node3D
	if parent == null:
		return
	var local: Vector3 = parent.global_transform.basis.inverse() * (camera.global_position - _head.global_position)
	if Vector2(local.x, local.z).length() < 0.05:
		return
	var want: float = atan2(local.x, local.z)
	var target: float = clampf(angle_difference(_head_rest_yaw, want), -HEAD_TRACK_LIMIT, HEAD_TRACK_LIMIT)
	_head_yaw = lerp_angle(_head_yaw, target, clampf(maxf(delta, 0.0) * HEAD_TRACK_RATE, 0.0, 1.0))


func _apply_head_yaw() -> void:
	if _head:
		_head.rotation.y = _head_rest_yaw + _head_yaw


# ── construction ───────────────────────────────────────────────────────────────
func _build() -> void:
	var stone := _material(STONE)
	var pale := _material(PALE)
	var dark := _material(DARK)

	# ── pelvis: askew, and not under the middle of the chest ──
	_hips = _pivot(self, "Pelvis", Vector3(0, 1.04, 0))
	_fragment(_hips, "BrokenHip", Vector3(0.36, 0.14, 0.26),
		Vector3(0.02, -0.06, -0.03), Vector3(-8, 14, -7), 0.70, stone)

	# ── torso: five separated masses with 5-8 cm of nothing between them ──
	_chest = _pivot(self, "Thorax", Vector3(0, 1.52, 0))
	_fragment(_chest, "LeftBreastplate", Vector3(0.26, 0.36, 0.22),
		Vector3(-0.17, 0.08, 0.02), Vector3(-10, -13, -9), 0.71, stone)
	_fragment(_chest, "RightBreastplate", Vector3(0.23, 0.30, 0.20),
		Vector3(0.135, 0.11, -0.04), Vector3(13, 15, 12), 0.81, stone)
	_fragment(_chest, "HollowBack", Vector3(0.12, 0.32, 0.11),
		Vector3(0.04, 0.02, -0.19), Vector3(6, -15, -17), 0.66, dark)
	_chest_shard = _fragment(_chest, "LooseRib", Vector3(0.28, 0.10, 0.15),
		Vector3(-0.02, -0.23, 0.02), Vector3(10, -17, 13), 0.62, pale)
	_fragment(_chest, "Abdomen", Vector3(0.22, 0.13, 0.18),
		Vector3(0.03, -0.395, -0.02), Vector3(-14, 19, -11), 0.69, stone)
	# ⚠️ Different heights on purpose: the shoulders do not agree about where they are.
	_fragment(_chest, "LeftShoulder", Vector3(0.17, 0.15, 0.22),
		Vector3(-0.42, 0.22, -0.02), Vector3(7, -19, 16), 0.87, stone)
	_fragment(_chest, "RightShoulder", Vector3(0.14, 0.13, 0.19),
		Vector3(0.40, 0.14, 0.015), Vector3(-16, 21, -23), 0.74, stone)
	_fragment(_chest, "NeckSplinter", Vector3(0.07, 0.10, 0.08),
		Vector3(0.05, 0.30, -0.05), Vector3(11, 11, -16), 0.60, dark)

	# ── the head: 12 cm of nothing above the neck, rolled onto one shoulder ──
	_head = _pivot(self, "Head", Vector3(-0.045, 2.10, -0.01))
	_head.rotation_degrees = Vector3(-9, -14, -22)
	_head_rest_yaw = _head.rotation.y
	_build_face(stone, pale, dark)
	_jaw_shard = _fragment(_head, "DetachedJaw", Vector3(0.12, 0.07, 0.14),
		Vector3(-0.04, -0.20, 0.05), Vector3(-11, 21, 16), 0.72, stone)

	# ── legs: short for the body, and the knees are not level ──
	_left_leg = _pivot(self, "LeftLeg", Vector3(-0.13, 1.00, 0))
	_right_leg = _pivot(self, "RightLeg", Vector3(0.135, 0.99, -0.02))
	_left_knee = _build_leg(_left_leg, "Left", -1.0, stone, pale)
	_right_knee = _build_leg(_right_leg, "Right", 1.0, stone, pale)

	# ── arms: 1.28 m of arm, fingertips at knee height ──
	_left_arm = _pivot(self, "LeftArm", Vector3(-0.42, 1.70, -0.01))
	_right_arm = _pivot(self, "RightArm", Vector3(0.40, 1.66, 0.01))
	_left_hand = _build_arm(_left_arm, "Left", -1.0, stone, pale, _variant != 0)
	_right_hand = _build_arm(_right_arm, "Right", 1.0, stone, pale, true)

	_apply_variant(stone, pale, dark)
	_apply_rest_pose()


# A brow, two cheek rims and a dark face plane set 4 cm BACK from them, and then THE MASK:
# an oversized stone slab hanging 8 cm in front of the whole skull, carrying the broken face
# and its jumble of wrong objects (void_face.gd). The torch finds the mask first.
#
# ⭐ THE MASK (2026-09-20 pass 2). What this was: the generated face painted onto a 10 x 15 cm
# quad inside a 4 cm recess, BEHIND the brow and both cheek rims, on a head that rests yawed
# 14° away from the player. The 13:10 playtester photographed it at 2.5 m (capture #7) and
# wrote *"they still do not have horror terrible wrong-looking faces"* — at that distance the
# whole head is ~20 px and the art was occluded by its own skull for most of them. It could
# not read, and no amount of re-generating the texture was going to change that.
# Now: a 0.32 x 0.46 x 0.05 slab — BIGGER THAN THE HEAD (0.21 x 0.24) — floating 8 cm clear of
# the brow, with the face art at albedo ~0.95 against the body's 0.25, so it is the brightest
# thing on the figure by a wide margin. ⚠️ NO EMISSION anywhere on it: this project has no
# tonemapping or glow, so an emissive face clamps to a flat white blob (Issue 21).
# ⚠️ It is a child of `_head`, so it inherits the head's rule for free — it turns to face you
# ONLY in unobserved ticks, and `check_stalker_motion`'s watched-drift stays at zero.
const MASK_SIZE := Vector3(0.32, 0.46, 0.05)
const MASK_Z := 0.20              # mask centre in the head's frame; its back face is at 0.175
const FACE_QUAD := Vector2(0.28, 0.42)   # 2 : 3, matching void_face.png's 667 x 1000


func _build_face(stone: Material, pale: Material, dark: Material) -> void:
	_fragment(_head, "FaceRimL", Vector3(0.055, 0.24, 0.19),
		Vector3(-0.076, 0.0, 0.0), Vector3(2, -4, 3), 0.80, stone)
	_fragment(_head, "FaceRimR", Vector3(0.055, 0.24, 0.19),
		Vector3(0.076, 0.005, -0.008), Vector3(-3, 5, -4), 0.78, stone)
	_fragment(_head, "FaceBrow", Vector3(0.21, 0.05, 0.19),
		Vector3(0.0, 0.098, 0.0), Vector3(4, 0, -2), 0.84, stone)
	_fragment(_head, "FaceRecess", Vector3(0.105, 0.20, 0.02),
		Vector3(0.004, -0.012, 0.042), Vector3(-2, 0, 1), 0.95, dark)
	_fragment(_head, "Crown", Vector3(0.17, 0.045, 0.15),
		Vector3(-0.01, 0.135, -0.012), Vector3(-5, 8, 6), 0.72, stone)
	# The mask pivot. ⚠️ Its own node, not a bare mesh, so void_face.gd's offsets are measured
	# from the SLAB and stay correct if the slab ever moves.
	var mask := Node3D.new()
	mask.name = "Mask"
	mask.position = Vector3(0.006, 0.02, MASK_Z)
	mask.rotation_degrees = Vector3(3, 4, -7)   # it hangs askew, like everything else here
	_head.add_child(mask)
	_fragment(mask, "MaskSlab", MASK_SIZE, Vector3.ZERO, Vector3.ZERO, 0.94, dark)
	# ⭐ The art 8 mm proud of the slab's front face (never coplanar with it — two visible
	# surfaces in one plane is this project's most common bug class), the jumble 1–3 cm in
	# front of that, the socket punched through it. Everything static under the head pivot.
	for mi in _VOID_FACE.build(mask, Vector3(0.0, 0.0, MASK_SIZE.z * 0.5 + 0.008),
			FACE_QUAD, _variant, stone, pale, dark):
		_meshes.append(mi)


func _build_leg(parent: Node3D, label: String, side: float,
		stone: Material, pale: Material) -> Node3D:
	_fragment(parent, label + "Thigh", Vector3(0.15, 0.34, 0.17),
		Vector3(side * 0.016, -0.31, 0), Vector3(4, side * 12, side * -6), 0.67, stone)
	var knee := _pivot(parent, label + "Knee", Vector3(side * 0.017, -0.60, 0.015))
	_fragment(knee, label + "KneeChip", Vector3(0.12, 0.09, 0.15),
		Vector3(-side * 0.022, 0.02, 0.05), Vector3(-16, side * 17, 12), 0.77, pale)
	_fragment(knee, label + "Shin", Vector3(0.115, 0.20, 0.125),
		Vector3(side * 0.012, -0.17, -0.005), Vector3(-3, -side * 11, side * 5), 0.63, stone)
	_fragment(knee, label + "Foot", Vector3(0.15, 0.08, 0.27),
		Vector3(side * 0.008, -0.345, 0.07), Vector3(0, side * -9, 0), 0.75, stone)
	return knee


func _build_arm(parent: Node3D, label: String, side: float,
		stone: Material, pale: Material, full: bool) -> Node3D:
	_fragment(parent, label + "UpperArm", Vector3(0.115, 0.34, 0.13),
		Vector3(side * 0.015, -0.25, -0.02), Vector3(8, side * 18, side * 8), 0.75, stone)
	_fragment(parent, label + "Elbow", Vector3(0.09, 0.08, 0.11),
		Vector3(side * 0.035, -0.50, 0.015), Vector3(-14, side * -21, 19), 0.70, pale)
	if not full:
		# Variant 0: the forearm and everything under it is simply not there.
		return _pivot(parent, label + "Hand", Vector3(side * 0.045, -0.62, 0.05))
	_fragment(parent, label + "Forearm", Vector3(0.09, 0.34, 0.105),
		Vector3(side * 0.04, -0.77, 0.04), Vector3(-10, side * -11, -side * 6), 0.58, stone)
	var hand := _pivot(parent, label + "Hand", Vector3(side * 0.045, -1.06, 0.075))
	_fragment(hand, label + "Palm", Vector3(0.095, 0.15, 0.07),
		Vector3.ZERO, Vector3(-11, side * 15, side * 11), 0.63, stone)
	# Two unequal blades imply fingers without making ordinary human hands.
	for index in range(2):
		_fragment(hand, label + "Finger" + str(index), Vector3(0.028, 0.13 - index * 0.03, 0.045),
			Vector3(-0.024 + index * 0.046, -0.145, 0.008),
			Vector3(-13, 0, -side * (5 + index * 8)), 0.45, pale)
	return hand


# ⭐ FIVE WRONGNESSES. Every one is subtractive or additive geometry, never a colour swap:
# the player has to see the SHAPE differ, because at this light level colour does not carry.
func _apply_variant(stone: Material, pale: Material, dark: Material) -> void:
	match _variant:
		0:
			# The left arm ends at the elbow. A stump chip hangs where the forearm was.
			_fragment(_left_arm, "SeveredStump", Vector3(0.075, 0.09, 0.08),
				Vector3(-0.05, -0.63, 0.02), Vector3(22, -34, 18), 0.55, dark)
		1:
			# A second right forearm, offset, growing out of the same elbow.
			_fragment(_right_arm, "SpareForearm", Vector3(0.08, 0.31, 0.095),
				Vector3(0.115, -0.74, -0.03), Vector3(-9, -24, 17), 0.56, stone)
			_fragment(_right_arm, "SpareKnuckle", Vector3(0.07, 0.09, 0.06),
				Vector3(0.14, -0.94, -0.05), Vector3(-14, -30, 22), 0.5, pale)
		2:
			# A second jaw, on the wrong side, lower than the first.
			_fragment(_head, "SecondJaw", Vector3(0.11, 0.065, 0.13),
				Vector3(0.09, -0.29, 0.01), Vector3(14, -26, -19), 0.68, stone)
		3:
			# A spare skull, carried on the shoulder where the head is not.
			_fragment(_chest, "SpareSkull", Vector3(0.16, 0.19, 0.145),
				Vector3(0.40, 0.42, -0.04), Vector3(-18, 27, 31), 0.71, stone)
			_fragment(_chest, "SpareSkullRecess", Vector3(0.075, 0.14, 0.02),
				Vector3(0.44, 0.40, 0.045), Vector3(-18, 27, 31), 0.95, dark)
		4:
			# An extra vertebra floating in the gap the spine should fill.
			_fragment(_chest, "ExtraVertebra", Vector3(0.11, 0.09, 0.10),
				Vector3(-0.07, -0.55, -0.06), Vector3(23, -19, 28), 0.58, pale)
			_fragment(_hips, "FloatingSacrum", Vector3(0.13, 0.08, 0.11),
				Vector3(-0.12, 0.17, -0.09), Vector3(-21, 16, -25), 0.6, stone)


# ⚠️ NEVER A NEUTRAL STAND. The rest pose — the pose it is frozen in when you look at it — is
# mid-stride, leaning in, reaching. A watched creature should look INTERRUPTED, not parked.
func _apply_rest_pose() -> void:
	_hips.rotation_degrees = Vector3(5, -4, 2)
	_chest.rotation_degrees = Vector3(14, 6, -3)
	# ⚠️ ONE FOOT PLANTED. Swinging BOTH legs made the whole figure hover a hand off the floor,
	# which reads as a bug rather than as a stride. The trailing leg is near-vertical; the
	# leading leg is in the air, which is what "caught mid-step" looks like.
	_left_leg.rotation_degrees = Vector3(-23, 3, 0)
	_left_knee.rotation_degrees = Vector3(-14, 0, 0)
	_right_leg.rotation_degrees = Vector3(7, -4, 0)
	_right_knee.rotation_degrees = Vector3(-11, 0, 0)
	_left_arm.rotation_degrees = Vector3(-35, 6, 4)
	_right_arm.rotation_degrees = Vector3(-21, -9, -8)
	if _left_hand:
		_left_hand.rotation_degrees = Vector3(-19, 8, 0)
	if _right_hand:
		_right_hand.rotation_degrees = Vector3(-12, -6, 0)


# ── animation ──────────────────────────────────────────────────────────────────
func _pose_stride() -> void:
	var stride := sin(_phase)
	var weight := sin(_phase * 2.0)
	_hips.position.y += absf(stride) * 0.018
	_hips.rotation.z += stride * 0.025
	_chest.position.x += stride * 0.013
	_chest.rotation.y += stride * 0.055
	_chest.rotation.z += sin(_phase - 0.5) * 0.022
	_head.rotation.z += sin(_phase - 0.8) * 0.025
	_head.position.z += weight * 0.008
	_left_leg.rotation.x += stride * 0.31
	_right_leg.rotation.x -= stride * 0.31
	_left_knee.rotation.x -= maxf(-stride, 0.0) * 0.42
	_right_knee.rotation.x -= maxf(stride, 0.0) * 0.42
	_left_arm.rotation.x -= sin(_phase - 0.25) * 0.18
	_right_arm.rotation.x += sin(_phase + 0.40) * 0.13
	if _left_hand:
		_left_hand.rotation.y += weight * 0.09
	if _right_hand:
		_right_hand.rotation.y -= weight * 0.075
	_chest_shard.position.x += sin(_phase - 0.9) * 0.014
	_chest_shard.rotation.z += weight * 0.045
	_jaw_shard.position.y += sin(_phase + 0.7) * 0.007


func _pose_attack() -> void:
	var progress := _attack_time / ATTACK_DURATION
	var reach := smoothstep(0.0, 0.40, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
	_chest.position.z += reach * 0.20
	_chest.rotation.x += reach * 0.17
	_head.position.z += reach * 0.38
	_head.position.y -= reach * 0.10
	_head.rotation.x += reach * 0.23
	_left_arm.rotation.x -= reach * 1.45
	_right_arm.rotation.x -= reach * 1.23
	if _left_hand:
		_left_hand.rotation.x -= reach * 0.35
	if _right_hand:
		_right_hand.rotation.x -= reach * 0.50
	_chest_shard.position.z += reach * 0.08
	_jaw_shard.position.y -= reach * 0.055


func _remember_pose(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is Node3D:
			_parts.append(child)
			_rests.append(child.transform)
			_remember_pose(child)


func _restore_pose() -> void:
	for index in range(_parts.size()):
		_parts[index].transform = _rests[index]


func _pivot(parent: Node3D, label: String, origin: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = origin
	parent.add_child(pivot)
	return pivot


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = VoidFragments.stone_grain()
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(3, 3, 3)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material.metallic = 0.0
	return material


func _fragment(parent: Node3D, label: String, size: Vector3, origin: Vector3,
		angles: Vector3, taper: float, material: Material) -> MeshInstance3D:
	var fragment := MeshInstance3D.new()
	fragment.name = label
	fragment.mesh = _stone_mesh(size, taper)
	fragment.material_override = material
	fragment.position = origin
	fragment.rotation_degrees = angles
	parent.add_child(fragment)
	_meshes.append(fragment)
	return fragment


# Four uneven octagonal rings make a tapered slab with chipped end bevels.
# Flat normals preserve the stone facets; the long front is an unmarked plane.
func _stone_mesh(size: Vector3, taper: float) -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-0.33, -0.5), Vector2(0.32, -0.5),
		Vector2(0.5, -0.28), Vector2(0.5, 0.30),
		Vector2(0.31, 0.5), Vector2(-0.35, 0.5),
		Vector2(-0.5, 0.26), Vector2(-0.5, -0.32),
	])
	var heights := [-0.5, -0.40, 0.40, 0.5]
	var widths := [taper * 0.77, taper, 1.0, 0.79]
	var rings: Array[PackedVector3Array] = []
	for ring_index in range(4):
		var ring := PackedVector3Array()
		for point in outline:
			var lean: float = heights[ring_index] * 0.10
			ring.append(Vector3(
				(point.x * widths[ring_index] + lean) * size.x,
				(heights[ring_index] + point.x * 0.08 + point.y * 0.04) * size.y,
				(point.y * widths[ring_index] - lean * 0.3) * size.z))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(3):
		for side in range(8):
			var next := (side + 1) % 8
			# ⚠️ The pale band is the EDGE now, not the whole face: a stone at albedo 0.25
			# needs its chipped corners to catch the torch, but a bright flank turns the
			# fragment back into the flat grey mannequin the 2026-09-20 capture showed.
			var shade := 0.74 + float((side * 3 + ring_index) % 5) * 0.022
			if ring_index != 1:
				shade = minf(shade + 0.09, 1.0)
			var color := Color(shade, shade, shade)
			_face(surface, rings[ring_index][side], rings[ring_index + 1][next], rings[ring_index][next], color)
			_face(surface, rings[ring_index][side], rings[ring_index + 1][side], rings[ring_index + 1][next], color)
	for cap in [0, 3]:
		var center := Vector3.ZERO
		for vertex in rings[cap]:
			center += vertex / 8.0
		for side in range(8):
			var next := (side + 1) % 8
			if cap == 0:
				_face(surface, center, rings[cap][side], rings[cap][next], Color(0.72, 0.72, 0.72))
			else:
				_face(surface, center, rings[cap][next], rings[cap][side], Color(1.0, 1.0, 1.0))
	return surface.commit()


func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	# Godot front faces use clockwise winding. Explicit normals face outward.
	for vertex in [a, c, b]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(vertex)
