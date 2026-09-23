extends Node3D

# The approach's SECOND glimpse (2026-09-23 pass 3, the user's choice: "should we see some kind of
# a real monster through it?"). Seen through PumpReturn's return-air grille: Object 12's BACK and
# CROWN, battering a steel door in the small unreachable room behind it, in time with the door
# tell's pounding. It stills in the tell's silence; the lamps die; when they come back it is gone
# and the door hangs broken open.
#
# ⚠️ A PUPPET, NEVER THE CREATURE — `breach_approach_hand.gd`'s contract, verbatim:
#   * `CreatureAnim.build()` on a plain Node3D, the same GLB, skin and rig as the pursuer;
#   * a DUPLICATE of the creature's material with emission OFF (SCARY.md §8.8);
#   * `hold_pose()`, NEVER `halt()`, which drops the rig to a T-pose;
#   * shadows off, and its own camera-visible layer so only its rim light touches it;
#   * no CollisionShape3D and no ScaryObject anywhere above or below it: zero panic, no contact.
# It faces AWAY from the player, toward the door it batters, and it is freed the moment it is gone.
#
# ⚠️ A DIFFERENT LAYER FROM THE HAND (1 << 18, not 1 << 17). PumpReturn's two lamps would otherwise
# light its back from the player's side and it would stop being a silhouette. The approach culls
# those lamps from this layer; the room's own door lamp lights everything EXCEPT it.

const LAYER := 1 << 18
const CLIP := CreatureAnim.CLIP_WALK
const CLIP_AT := 0.05
const BEAT := 0.6            # breach_approach.gd:_door_tell's thud spacing — one blow per thud
# One blow, as a fraction of BEAT: the fists land at 0, recoil, draw back and up, swing in.
const RECOIL_END := 0.14
const RAISED_AT := 0.62

var actor: Node3D
var rig: CreatureAnim
var material: StandardMaterial3D
var _rim: OmniLight3D
var _bones: Dictionary = {}
var _placed_frames := 0
var _stand := Vector3.ZERO
var _door_x := 0.0
var _hits := 0
var _t := -1.0
var _stilled := false


# `stand` is where its feet are; `door_x` is the door face it batters (it faces +x, toward it).
func setup(source: StandardMaterial3D, stand: Vector3, door_x: float) -> bool:
	_stand = stand
	_door_x = door_x
	actor = Node3D.new()
	actor.name = "Object12GrillePuppet"
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
		mesh.layers = LAYER
	rig.hold_pose(CLIP, CLIP_AT)
	# The model faces its parent's +z; +x is toward the door, i.e. away from the grille.
	actor.rotation = Vector3(0.0, PI / 2.0, 0.0)
	actor.position = stand
	# Just enough to read a back and a crown through the slats: a low rim from above and behind
	# its shoulder, on its layer ONLY. Never emission.
	_rim = OmniLight3D.new()
	_rim.name = "GrilleRim"
	_rim.light_color = Color(0.62, 0.66, 0.6)
	_rim.light_energy = 0.55
	_rim.omni_range = 2.4
	_rim.shadow_enabled = false
	_rim.light_cull_mask = LAYER
	add_child(_rim)
	_rim.position = stand + Vector3(-0.9, 2.45, -0.55)
	return true


# The pounding starts: `hits` blows, the first landing NOW (the first thud and the roar).
func batter(hits: int) -> void:
	_hits = hits
	_t = 0.0


# The tell's silence: it stops dead wherever it is — arms up after its last blow, listening.
func still() -> void:
	_stilled = true


# The lamps die: its own rim light dies with them, or its back would glow in the dark.
func lights_out() -> void:
	if _rim:
		_rim.visible = false


func is_battering() -> bool:
	return _t >= 0.0 and not _stilled


func _process(delta: float) -> void:
	if rig == null:
		return
	if _placed_frames < 2:
		_placed_frames += 1
		_index_bones()
		_pose(RAISED_AT)
		return
	if _t < 0.0 or _stilled:
		return
	_t += delta
	var last_blow := float(_hits - 1) * BEAT
	var u := RAISED_AT
	if _t <= last_blow + RAISED_AT * BEAT:
		u = fmod(_t, BEAT) / BEAT
	_pose(u)


func _index_bones() -> void:
	var sk := rig.skeleton()
	if sk == null:
		return
	for i in range(sk.get_bone_count()):
		_bones[sk.get_bone_name(i)] = i


# u in [0, 1): 0 = fists on the door. The body pitches INTO each blow, which reads through slats
# far better than arm motion alone.
func _pose(u: float) -> void:
	var sk := rig.skeleton()
	if sk == null or not _bones.has("LeftArm"):
		return
	sk.clear_bones_global_pose_override()
	var lean := 0.0
	var reach := 0.0     # 0 = fists on the door, 1 = drawn back and raised
	if u < RECOIL_END:
		reach = 0.25 * u / RECOIL_END
		lean = 0.16 * (1.0 - u / RECOIL_END)
	elif u < RAISED_AT:
		var k := (u - RECOIL_END) / (RAISED_AT - RECOIL_END)
		reach = lerpf(0.25, 1.0, sin(k * PI * 0.5))
		lean = -0.05 * k
	else:
		var k := (u - RAISED_AT) / (1.0 - RAISED_AT)
		reach = 1.0 - k * k
		lean = lerpf(-0.05, 0.16, k * k)
	actor.rotation = Vector3(0.0, PI / 2.0, 0.0)
	actor.rotate_object_local(Vector3(1, 0, 0), lean)   # about its own +x: +y tips toward +z, forward
	for side in ["Left", "Right"]:
		var sd := -1.0 if side == "Left" else 1.0
		var hit := Vector3(_door_x - 0.06, 1.38 + 0.05 * sd, _stand.z + sd * 0.19)
		var back := Vector3(_door_x - 0.62, 2.02, _stand.z + sd * 0.27)
		var goal := hit.lerp(back, reach)
		_reach([side + "Arm", side + "ForeArm", side + "Hand"], goal, Vector3(-0.3, -1.0, sd * 0.6))


# Two-bone arm solve over the rig: `breach_approach_hand.gd:_reach()`.
func _reach(names: Array, goal_world: Vector3, bend_world: Vector3) -> void:
	var sk := rig.skeleton()
	for nm in names:
		if not _bones.has(nm):
			return
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


func hand_points() -> Array:
	var sk := rig.skeleton() if rig else null
	if sk == null or not _bones.has("LeftHand"):
		return []
	return [sk.to_global(sk.get_bone_global_pose(_bones["LeftHand"]).origin),
		sk.to_global(sk.get_bone_global_pose(_bones["RightHand"]).origin)]
