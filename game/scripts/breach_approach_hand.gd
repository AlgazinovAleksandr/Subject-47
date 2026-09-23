extends Node3D

# The approach's ONE glimpse of Object 12 (2026-09-23, the user's choice over "several
# hallucinations", a bay-shutter glimpse and a CCTV glimpse): a hand and forearm of the REAL
# hollow-crown model hanging out of an open hatch in a ceiling duct at the Threshold dogleg,
# yanked back up into the duct the moment the player looks at it.
#
# ⚠️ A PUPPET, NEVER THE CREATURE. `breach_approach.gd` owns when this fires; the level's
# `_creature` is never moved, shown or voiced before the seal (`check_breach_approach.gd:_quiet()`).
#
# Built exactly the way `breach_kill_sequence.gd:55-66` builds its attacker, for the same reasons:
#   * `CreatureAnim.build()` on a plain Node3D — the same GLB, skin and rig as the pursuer.
#   * each mesh gets a DUPLICATE of the creature's material, because the Breach's wound flash
#     tweens the shared one; and the duplicate has emission OFF (SCARY.md §8.8: no glowing
#     monsters — the fill light below is what makes it readable).
#   * `hold_pose()`, NEVER `halt()`, which drops the rig to a T-pose.
#   * shadows off, and a camera-visible layer (1 << 17) so the fill light touches nothing else.
#
# ⚠️ NOTHING HERE CAN HURT: no CollisionShape3D, no ScaryObject anywhere above or below it, so it
# adds zero panic and has no contact. It never faces the player (it lies face-down inside the
# duct) and never approaches (its only motion is away, upward). Freed the moment it is gone.

const PUPPET_LAYER := 1 << 17
const LOOK_HOLD := 0.15      # the look lands before it moves: long enough to register a hand
const WITHDRAW := 0.5        # the spec's ~0.5 s yank up into the duct
const RISE := 0.8
const CLIP := CreatureAnim.CLIP_WALK
const CLIP_AT := 0.62
# ⚠️ THE RIG HAS NO FINGER BONES (2026-09-23 legibility pass): `LeftHand` is one bone, so the
# modelled fingers cannot be splayed or curled one by one. The silhouette is made legible with what
# the rig allows. The hand is turned about the forearm so its fingers are seen BROADSIDE from the
# Threshold approach, and flexed at the wrist into a hook. The lights below do the rest.
# Chosen from rendered variants (0/90/180/270° × ±35°): at 90° the modelled fingers face the
# approach broadside, and a 30° flex hooks them into a claw against the lit tile behind.
var twist_deg := 90.0
var flex_deg := 30.0

var actor: Node3D
var rig: CreatureAnim
var material: StandardMaterial3D
var _fill: OmniLight3D
var _backdrop: OmniLight3D
var _hatch_glow: OmniLight3D
var _shoulder_target := Vector3.ZERO
var _placed_frames := 0
var _bones: Dictionary = {}
var _yanking := false
var _t := 0.0
var _rise_from := 0.0
var _on_done: Callable


# `source` is the creature's material, duplicated here and never touched. `shoulder` is where the
# hanging arm's shoulder joint must land (inside the duct, just above the hatch).
func setup(source: StandardMaterial3D, shoulder: Vector3) -> bool:
	_shoulder_target = shoulder
	actor = Node3D.new()
	actor.name = "Object12HandPuppet"
	add_child(actor)
	rig = CreatureAnim.build(actor)
	if rig == null:
		return false
	material = (source.duplicate() if source else StandardMaterial3D.new()) as StandardMaterial3D
	material.emission_enabled = false
	material.emission_energy_multiplier = 0.0
	for mesh in rig.mesh_instances():
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = PUPPET_LAYER
	rig.hold_pose(CLIP, CLIP_AT)
	# Face-down, head away from the corner (+z): the whole body lies along the duct and only the
	# left arm (which lands on the lane side) hangs through the hatch.
	actor.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	# A raking light from the approach side, on the puppet's layer ONLY: it models the arm's
	# edge without lighting anything else. Never emission (SCARY.md §8.8).
	_fill = OmniLight3D.new()
	_fill.name = "HandRake"
	_fill.light_color = Color(0.7, 0.74, 0.66)
	_fill.light_energy = 2.6
	_fill.omni_range = 2.2
	_fill.shadow_enabled = false
	_fill.light_cull_mask = PUPPET_LAYER
	add_child(_fill)
	# And the opposite trick: lights that touch everything EXCEPT the puppet. They put a lit patch
	# of tile behind the arm (as seen from the lane) and a glow in the hatch it comes out of, so the
	# arm reads as a dark shape against lighter surfaces, a silhouette.
	var not_puppet := 0xFFFFF & ~PUPPET_LAYER
	_backdrop = OmniLight3D.new()
	_backdrop.name = "HandBackdrop"
	_backdrop.light_color = Color(0.66, 0.72, 0.64)
	_backdrop.light_energy = 1.3
	_backdrop.omni_range = 1.5
	_backdrop.shadow_enabled = false
	_backdrop.light_cull_mask = not_puppet
	add_child(_backdrop)
	_hatch_glow = OmniLight3D.new()
	_hatch_glow.name = "HatchGlow"
	_hatch_glow.light_color = Color(0.6, 0.66, 0.6)
	_hatch_glow.light_energy = 0.7
	_hatch_glow.omni_range = 0.85
	_hatch_glow.shadow_enabled = false
	_hatch_glow.light_cull_mask = not_puppet
	add_child(_hatch_glow)
	return true


# The skeleton's global pose is only trustworthy once the tree has processed it, so placement
# happens on the first frames rather than inside setup() (the player is 100+ m away then).
func _process(delta: float) -> void:
	if rig == null:
		return
	if _placed_frames < 2:
		_placed_frames += 1
		_place()
	if not _yanking:
		return
	_t += delta
	if _t < LOOK_HOLD:
		return
	var u := clampf((_t - LOOK_HOLD) / WITHDRAW, 0.0, 1.0)
	actor.global_position.y = _rise_from + RISE * u * u
	if u >= 1.0:
		_yanking = false
		if _on_done.is_valid():
			_on_done.call()
		queue_free()


func _place() -> void:
	var sk := rig.skeleton()
	if sk == null:
		return
	for i in range(sk.get_bone_count()):
		_bones[sk.get_bone_name(i)] = i
	if not _bones.has("LeftArm"):
		return
	sk.clear_bones_global_pose_override()
	var shoulder := sk.to_global(sk.get_bone_global_pose(_bones["LeftArm"]).origin)
	actor.global_position += _shoulder_target - shoulder
	# The hanging arm: nearly straight down out of the hatch, elbow toward the lane. Then the
	# wrist is turned and hooked (see twist_deg / flex_deg).
	var solved := _reach(["LeftArm", "LeftForeArm", "LeftHand"], _shoulder_target + Vector3(0.03, -0.60, -0.04),
		Vector3(1.0, 0.0, -0.3))
	if not solved.is_empty():
		var hand: Transform3D = solved[0]
		var along: Vector3 = solved[1]
		var side := (sk.global_transform.basis.inverse() * Vector3(1, 0, 0))
		side = (side - along * side.dot(along)).normalized()
		hand.basis = Basis(along, deg_to_rad(twist_deg)) * hand.basis
		hand.basis = Basis(along.cross(side).normalized(), deg_to_rad(flex_deg)) * hand.basis
		sk.set_bone_global_pose_override(_bones["LeftHand"], hand, 1.0, true)
	# The other arm stays inside the duct, folded up along it toward the head — ONE hand is seen
	# (the first render showed its fingers poking out of the duct floor).
	var right := sk.to_global(sk.get_bone_global_pose(_bones["RightArm"]).origin)
	_reach(["RightArm", "RightForeArm", "RightHand"], right + Vector3(0.08, 0.28, 0.4), Vector3(0.0, 1.0, 0.0))
	# ⚠️ And the LEGS lie flat along the duct. The walk pose's forward knee points along the
	# model's +z, which face-down is straight DOWN: the second render showed a clawed foot
	# hanging through the duct floor next to the hand, reading as a second hand.
	for side in ["Left", "Right"]:
		var hip := sk.to_global(sk.get_bone_global_pose(_bones[side + "UpLeg"]).origin) if _bones.has(side + "UpLeg") else Vector3.ZERO
		_reach([side + "UpLeg", side + "Leg", side + "Foot"], hip + Vector3(0.0, 0.12, -0.9), Vector3(0.0, 1.0, 0.0))
	_fill.global_position = _shoulder_target + Vector3(0.55, -0.55, -0.85)
	_backdrop.global_position = _shoulder_target + Vector3(-0.42, -0.6, 1.05)
	_hatch_glow.global_position = _shoulder_target + Vector3(-0.1, 0.25, 0.0)


# Two-bone arm solve over the existing rig — `breach_kill_sequence.gd:_grip()`, plus one thing it
# did not need: the HAND is turned to continue the forearm, or a hanging arm ends in fingers
# pointing sideways (the walk pose's hand orientation, rotated face-down).
# Returns [end-bone transform, direction of the second segment] in skeleton space, or [] if the
# chain is missing, so a caller can layer a wrist twist on top.
func _reach(names: Array, goal_world: Vector3, bend_world: Vector3) -> Array:
	var sk := rig.skeleton()
	for n in names:
		if not _bones.has(n):
			return []
	var upper := sk.get_bone_global_pose(_bones[names[0]])
	var lower := sk.get_bone_global_pose(_bones[names[1]])
	var hand := sk.get_bone_global_pose(_bones[names[2]])
	var a := upper.origin
	var b := lower.origin
	var c := hand.origin
	var goal := sk.to_local(goal_world)
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var dir := (goal - a).normalized()
	var distance := clampf(a.distance_to(goal), absf(first - second) + 0.001, first + second - 0.001)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var bend := sk.global_transform.basis.inverse() * bend_world
	bend = (bend - dir * bend.dot(dir)).normalized()
	var elbow := a + dir * along + bend * sqrt(maxf(0.0, first * first - along * along))
	var wrist := a + dir * distance
	upper.basis = Basis(Quaternion((b - a).normalized(), (elbow - a).normalized())) * upper.basis
	var turn := Basis(Quaternion((c - b).normalized(), (wrist - elbow).normalized()))
	lower.basis = turn * lower.basis
	lower.origin = elbow
	hand.basis = turn * hand.basis
	hand.origin = wrist
	for entry in [[names[0], upper], [names[1], lower], [names[2], hand]]:
		sk.set_bone_global_pose_override(_bones[entry[0]], entry[1], 1.0, true)
	return [hand, (wrist - elbow).normalized()]


func hand_point() -> Vector3:
	if rig == null or rig.skeleton() == null or not _bones.has("LeftHand"):
		return global_position
	var sk := rig.skeleton()
	return sk.to_global(sk.get_bone_global_pose(_bones["LeftHand"]).origin)


# The look landed: hold for a beat, then yank up into the duct and free everything.
func yank(on_done: Callable = Callable()) -> void:
	if _yanking or actor == null:
		return
	_on_done = on_done
	_rise_from = actor.global_position.y
	_t = 0.0
	_yanking = true


func is_yanking() -> bool:
	return _yanking
