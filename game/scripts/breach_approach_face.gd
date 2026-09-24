extends Node3D

# The approach's THIRD glimpse (2026-09-23 pass 4, the user: "Maybe the face of the creature should
# appear behind this room which first opens and then closes?"). A QUIET STARE, the user's choice over
# "the face slams in". Bay B's roller shutter rolls up on its dark niche, and on its FIRST opening (which
# waits for the player's look; the user reversed the order 2026-09-24), Object 12's head and crown are
# in the niche, still, turned to the player. Then
# the shutter rolls down over it, and the next cycle is empty again.
#
# ⚠️ A PUPPET, NEVER THE CREATURE — `breach_approach_hand.gd`'s contract, verbatim:
#   * `CreatureAnim.build()` on a plain Node3D (the pursuer's own GLB, skin and rig);
#   * a DUPLICATE of the creature's material with emission OFF (SCARY.md §8.8);
#   * `hold_pose()`, NEVER `halt()`;
#   * shadows off, its own layer (1 << 16, render layer 17), and a fill light culled to that layer;
#   * no CollisionShape3D and no ScaryObject anywhere: zero panic, no contact. Freed when it is gone.
#
# ⭐ "HEAD AND CROWN ONLY" IS DONE WITH LIGHT, NOT BY CUTTING THE MESH. The whole rig stands in a
# black niche, and the only light that touches its layer is a small fill in front of the face, so the
# body stays black-on-black and only the face and crown read, faintly.

# ⚠️ LAYER 17, NOT 20 (2026-09-23, found by the first render). This was `1 << 19`, which is render
# layer 20 — `player.gd:MIRROR_ONLY_LAYER`, which the player's camera CULLS (`cull_mask` 0x7FFFF). The
# face was revealed, visible, lit by a fill culled to its layer, and passed every state check, and the
# render showed an empty niche. `breach_kill_sequence.gd:ACTOR_LAYER` carries the same warning.
# `check_breach_pass4.gd` now asserts the player's camera can SEE the puppet's layer.
const LAYER := 1 << 16
const CLIP := CreatureAnim.CLIP_WALK
const CLIP_AT := 0.05
const BODY_ALBEDO := 0.3
const FILL_GAIN := 3.0
# The fill sits ABOVE and in front of the Head bone (which is the base of the skull), with a short
# range, so it reaches the face and crown and falls off before the chest.
const FILL_UP := 0.22
const FILL_OUT := 0.34
const FILL_RANGE := 0.62

var actor: Node3D
var rig: CreatureAnim
var material: StandardMaterial3D
var _fill: OmniLight3D
var _placed := 0
var _look_at := Vector3.ZERO


func setup(source: StandardMaterial3D, stand: Vector3) -> bool:
	actor = Node3D.new()
	actor.name = "Object12FacePuppet"
	add_child(actor)
	rig = CreatureAnim.build(actor)
	if rig == null:
		return false
	material = (source.duplicate() if source else StandardMaterial3D.new()) as StandardMaterial3D
	material.emission_enabled = false
	material.emission_energy_multiplier = 0.0
	# ⭐ DARKENED, and the fill made brighter to match (2026-09-23, the first render that showed it at
	# all). The level's ambient (`_boost_ambient(0.28)`) lights EVERY layer — no cull mask reaches it —
	# so at full albedo the whole body stood grey in the black niche: a figure in a doorway, not a face
	# in the dark. At BODY_ALBEDO the ambient term falls to ~a third and the body sinks into the black,
	# while the fill (×FILL_GAIN) keeps the face where it was.
	material.albedo_color = material.albedo_color * Color(BODY_ALBEDO, BODY_ALBEDO, BODY_ALBEDO, 1.0)
	for mesh in rig.mesh_instances():
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = LAYER
	rig.hold_pose(CLIP, CLIP_AT)
	actor.position = stand
	_fill = OmniLight3D.new()
	_fill.name = "FaceFill"
	_fill.light_color = Color(0.62, 0.68, 0.62)
	_fill.light_energy = 1.0 * FILL_GAIN
	_fill.omni_range = FILL_RANGE
	_fill.shadow_enabled = false
	_fill.light_cull_mask = LAYER
	add_child(_fill)
	visible = false
	return true


# Show it, turned to face `toward` (the player's camera), and light the face from the front.
func reveal(toward: Vector3) -> void:
	_look_at = toward
	var to := toward - actor.global_position
	actor.rotation.y = atan2(to.x, to.z)     # the model faces its parent's +z
	visible = true
	_placed = 0


func _process(_delta: float) -> void:
	if rig == null or not visible or _placed >= 2:
		return
	_placed += 1
	var sk := rig.skeleton()
	if sk == null:
		return
	var head := sk.find_bone("Head")
	if head < 0:
		return
	var p := sk.to_global(sk.get_bone_global_pose(head).origin)
	var fwd := (_look_at - p)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
	_fill.global_position = p + fwd * FILL_OUT + Vector3(0, FILL_UP, 0)


func head_point() -> Vector3:
	if rig == null or rig.skeleton() == null:
		return global_position
	var sk := rig.skeleton()
	var i := sk.find_bone("Head")
	return sk.to_global(sk.get_bone_global_pose(i).origin) if i >= 0 else actor.global_position
