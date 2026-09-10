extends RefCounted
class_name CreatureAnim

# The one place that knows how to make the creature model move.
#
# Used by `creature_stalker.gd` (the Void's four, and the Dungeon's Still Ones),
# `creature_object12.gd` (the Breach's Object 12, and the Dungeon's Matron) and
# `containment_cell.gd` (KONTUR's caged specimen). Before this file existed there was NO
# animation anywhere in the project — `grep -rn "AnimationPlayer" game/` returned one hit, in a
# test asserting that nothing was playing — and all three of those creatures rendered a T-pose.
#
# ⚠️ `RefCounted`, deliberately NOT a Node. Every one of these creatures already has a fragile
# transform chain (`ScaryObject` is a plain Node with no transform, so the world transform has
# to live on the inner `StaticBody3D` — Issue 10). Adding a fourth node to that chain to hold a
# helper would be inviting the next instance of that bug. The `AnimationPlayer` inside the
# instantiated GLB ticks itself; this object just holds references and decides what to play.
#
# ⚠️ IT DEGRADES TO NOTHING. `build()` returns null if the GLB is missing or malformed, and
# every call site already has a procedural-capsule fallback. A missing model must not crash a
# level — but `check_creature_model.gd` asserts the model is there, so a silent fallback shows
# up as a red test rather than as a mysteriously capsule-shaped monster.

const GLB_PATH := "res://assets/models/hollow_crown.glb"

const CLIP_WALK := "walk"
const CLIP_SHAMBLE := "shamble"
const CLIP_UNSTEADY := "unsteady"
const CLIP_RUN := "run"
const CLIP_SPRINT := "sprint"
const CLIP_CHARGE := "charge"

const ALL_CLIPS := [CLIP_WALK, CLIP_SHAMBLE, CLIP_UNSTEADY, CLIP_RUN, CLIP_SPRINT, CLIP_CHARGE]

# ⭐ HOW FAST EACH GAIT LOOKS LIKE IT IS TRAVELLING, in m/s.
#
# ⚠️ MEASURED, NEVER TYPED. Every clip is in-place, so there is no root translation to read a
# speed off — but a walk cycle still states its own speed: during the stance phase the planted
# foot travels BACKWARD relative to the hips at exactly the rate the body would be moving
# forward. `tests/probe_creature_gait.gd` samples toe-minus-hips along +Z, takes the longest
# monotone backward run, and divides.
#
# ⚠️ AND IT IS ANCHORED, which is what makes it trustworthy rather than plausible. `charge` is
# the one clip whose true speed is known independently: it shipped with 2.279 m of baked root
# motion over 0.8333 s = 2.849 m/s, which `tools/merge_creature_glb.py` strips and prints. The
# stance estimator returns 2.799 for that same clip — a 1.7 % error — so the method is
# calibrated against ground truth before any of the other five numbers are believed.
const CLIP_SPEED := {
	CLIP_WALK: 1.825,
	CLIP_SHAMBLE: 0.390,
	# ⚠️⚠️ 0.84, NOT the 1.489 the stance estimator returned (corrected 2026-09-03 by a play-test
	# probe). `probe_creature_gait.gd` finds the stance phase by looking for the longest monotone
	# backward run of toe-minus-hips, and on a DRUNKEN clip that heuristic picks the wrong window:
	# `unsteady` sways the whole body, so a stretch where the hips lurch forward past a foot that
	# is not actually planted reads as a long clean stance. The estimator was validated against
	# `charge` (2.799 measured vs 2.849 true, 1.7 % error) and it is right for every gait with a
	# clean contact phase; it is wrong for this one, which is the value of having had a control.
	#
	# The corrected figure comes from the opposite direction — measure the planted toe's residual
	# WORLD drift at three different `speed_scale`s and solve `feet = world - drift`, which needs
	# no stance detection at all. At 1.489 the Void stalker's feet moved 0.90 m/s while its body
	# moved 1.25, i.e. **it skated forward at 27.6 % of its own speed**. At 0.84 the scale becomes
	# 1.49, still inside the 0.6-1.8 band.
	# ⚠️ Only the stalker's ADVANCING gait was affected: Object 12's SEARCH-scan, its STAGGERED
	# reel and KONTUR's caged idle all play `unsteady` at a FIXED rate with nothing travelling.
	CLIP_UNSTEADY: 0.84,
	CLIP_RUN: 5.487,
	CLIP_SPRINT: 9.271,
	CLIP_CHARGE: 2.849,
}

# ⚠️ Outside this band the gait stops reading as the same creature — under 0.6 it is
# slow-motion, over 1.8 it is a cartoon. A caller whose world speed falls outside it should
# pick a DIFFERENT CLIP rather than push the scale, which is why `locomotion_clip()` exists.
const SPEED_SCALE_MIN := 0.6
const SPEED_SCALE_MAX := 1.8

# Cross-fade. Short enough that a PATROL -> CHASE transition is not a visible dissolve, long
# enough that it is not a snap.
const CROSSFADE := 0.18

# ⚠️ THE RIG FACES +Z, AND SO DOES THE CODE. `creature_stalker.gd`, `creature_object12.gd` and
# `containment_cell.gd` all compute yaw as `atan2(dir.x, dir.z)` and forward as
# `Vector3(sin(y), 0, cos(y))`, i.e. they already treat +Z as forward — and the rig's own
# `headfront` bone sits at +Z relative to `Head` while `head_end` sits at -Z. So the offset is
# ZERO. It is a named constant rather than an absent line because "the model runs backwards" is
# a bug this project has shipped once already (corridor.gd, Issue 102), and when it happens
# again this is the single place to flip.
const MODEL_YAW := 0.0

var _root: Node3D
var _player: AnimationPlayer
var _skel: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _lib := ""
var _clip := ""
var _frozen := false


# Instantiate the model under `parent` and return a driver, or null if the asset is unusable.
static func build(parent: Node3D) -> CreatureAnim:
	if not ResourceLoader.exists(GLB_PATH):
		return null
	var packed: PackedScene = load(GLB_PATH)
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	parent.add_child(inst)
	var a := CreatureAnim.new()
	a._root = inst
	a._collect(inst)
	if a._player == null or a._meshes.is_empty():
		inst.queue_free()
		return null
	a._name_library()
	a._make_everything_loop()
	return a


func _collect(n: Node) -> void:
	if n is AnimationPlayer and _player == null:
		_player = n
	elif n is Skeleton3D and _skel == null:
		_skel = n
	elif n is MeshInstance3D:
		_meshes.append(n)
	for c in n.get_children():
		_collect(c)


# Godot namespaces imported clips under a library ("" or "Animation/"), and which one you get
# depends on import settings — so resolve it once instead of guessing at every call.
func _name_library() -> void:
	for a in _player.get_animation_list():
		if String(a).contains("/"):
			_lib = String(a).get_slice("/", 0) + "/"
			return


# ⚠️ Loop mode is set HERE, not in the .import's `_subresources`, so there is exactly one source
# of truth. Every one of these clips is a cycle; a non-looping walk plays once and then the
# creature slides along in a frozen pose, which reads as the old T-pose bug returning.
func _make_everything_loop() -> void:
	for clip in ALL_CLIPS:
		var full: String = _lib + String(clip)
		if _player.has_animation(full):
			_player.get_animation(full).loop_mode = Animation.LOOP_LINEAR


func is_valid() -> bool:
	return _player != null and is_instance_valid(_root)


func visual_root() -> Node3D:
	return _root


func skeleton() -> Skeleton3D:
	return _skel


func mesh_instances() -> Array[MeshInstance3D]:
	return _meshes


func current_clip() -> String:
	return _clip


func has_clip(clip: String) -> bool:
	return _player != null and _player.has_animation(_lib + clip)


# Play `clip` at `speed`, cross-fading from whatever was playing.
#
# ⚠️ Re-calling with the same clip only retunes the SPEED; it does not restart the cycle. A
# creature whose gait restarted every frame the level re-asserted its state would stand still
# with its legs twitching, and the state tick functions do re-assert constantly.
func play(clip: String, speed: float = 1.0, blend: float = CROSSFADE) -> void:
	if _player == null:
		return
	var full: String = _lib + clip
	if not _player.has_animation(full):
		return
	if _clip == clip:
		# ⚠️ Clear `_frozen` here too. `hold_pose()` sets it, and `activate()` resumes through
		# THIS branch (same clip, new speed) — without the reset the object would report itself
		# frozen for ever and a later `freeze(true)` would no-op. Harmless for Object 12, which
		# never calls freeze; a trap for the next caller that mixes the two.
		_player.speed_scale = speed
		if speed != 0.0:
			_frozen = false
		return
	_clip = clip
	_player.speed_scale = speed
	_player.play(full, blend)
	_frozen = false


# Which gait best represents travelling at `world_speed`, by log-ratio so a 2x error costs the
# same whether it is too fast or too slow.
static func locomotion_clip(world_speed: float) -> String:
	var best := CLIP_WALK
	var best_err := INF
	for clip in [CLIP_SHAMBLE, CLIP_UNSTEADY, CLIP_WALK, CLIP_CHARGE, CLIP_RUN, CLIP_SPRINT]:
		var s: float = CLIP_SPEED[clip]
		if s <= 0.0:
			continue
		var err: float = absf(log(maxf(0.01, world_speed) / s))
		if err < best_err:
			best_err = err
			best = clip
	return best


# Play `clip` scaled so its feet keep up with `world_speed` m/s.
func play_locomotion(clip: String, world_speed: float, blend: float = CROSSFADE) -> void:
	var ref: float = CLIP_SPEED.get(clip, 1.0)
	var scale: float = clampf(world_speed / maxf(0.01, ref), SPEED_SCALE_MIN, SPEED_SCALE_MAX)
	play(clip, scale, blend)


func set_speed(s: float) -> void:
	if _player:
		_player.speed_scale = s


# ⭐ Stop dead, mid-stride, without losing the pose.
#
# ⚠️ THIS IS THE VOID'S WHOLE MECHANIC. `creature_stalker.gd` is a Weeping Angel: it moves only
# while it is NOT being looked at. Until now that was invisible — a T-posed statue looks the
# same watched or not — and with a real gait, a creature whose legs kept cycling while you
# stared at it would actively contradict the rule it is built on. `speed_scale = 0` holds the
# exact frame it was on, so looking away resumes the same stride rather than resetting it.
func freeze(on: bool) -> void:
	if _player == null or _frozen == on:
		return
	_frozen = on
	_player.speed_scale = 0.0 if on else 1.0


func is_frozen() -> bool:
	return _frozen


# ⭐ A HELD POSE — a creature STANDING STILL, which this class could not previously express.
#
# ⚠️ THE PROBLEM IT SOLVES. `creature_object12.gd` played `shamble` at 0.5x while dormant, and
# `shamble` is by a wide margin the most mobile clip in the asset: 0.515 m of hip excursion and a
# 57.9 deg arm swing per cycle, ten times `walk`'s drift. In THE NIGHTMARE that is invisible —
# `dungeon.gd:902` keeps the Matron `visible = false` until she spawns. In THE BREACH the creature
# stands 16.0 m dead ahead of the player spawn on heading 0.0 with unobstructed line of sight,
# under its own lamp, inside the torch beam, at ~9.4 % of screen height, casting a moving shadow.
# The player's first frame in the level looks straight at it, and they reported it: *"the creature
# is moving even when it is not active."*
#
# ⚠️⚠️ AND IT MUST NOT BE `halt()`. That calls `AnimationPlayer.stop()`, which drops the skeleton
# to BIND POSE — `check_creature_anim.gd` documents that in as many words. A T-posed statue 16 m
# ahead of the spawn point is a worse bug than the sway, and it is the obvious thing to reach for.
#
# The mechanism is the one `freeze()` already proves in the Void: `speed_scale = 0` holds the exact
# frame. The only addition is choosing WHICH frame, up front, instead of whichever one you happened
# to stop on.
#
# ⚠️ Idempotent on purpose. `_refresh_clip()` is re-asserted on several edges, and a `play()` that
# restarted the animation each time would make the pose jitter between two adjacent frames.
func hold_pose(clip: String, at: float = 0.0) -> void:
	if _player == null:
		return
	var full: String = _lib + clip
	if not _player.has_animation(full):
		return
	if _clip == clip and _frozen and absf(_player.current_animation_position - at) < 0.02:
		return
	_clip = clip
	# blend 0: there is nothing to cross-fade INTO a still pose from.
	_player.play(full, 0.0)
	_player.seek(at, true)
	_player.speed_scale = 0.0
	_frozen = true


# Stop entirely — for a toppled dud and for the purge collapse. Distinct from `freeze()`:
# ⚠️ a corpse that keeps walking on its face is what happens if `lure_into_trap()` rotates the
# visual to -90 deg without stopping the player first.
func halt() -> void:
	if _player:
		_player.stop()
	_clip = ""
	_frozen = false


# ---------------------------------------------------------------------------- materials
#
# ⚠️ DUPLICATE THE IMPORTED MATERIAL; DO NOT BUILD A NEW ONE. The code this replaces created a
# fresh `StandardMaterial3D` and assigned it as `material_override`, which threw the model's
# own textures away wholesale. That was survivable when the model was an untextured T-pose and
# is not now: the whole point of the new asset is the 1024 skin. Duplicating keeps
# `albedo_texture` and lets `albedo_color` MULTIPLY it, so the existing per-level tints keep
# their numbers and change meaning from "replace the skin" to "35 % of the skin".
#
# ⚠️ `duplicate()`, never `duplicate(true)` — a deep copy would clone the texture per creature,
# i.e. four copies of a 2 MB map in the Void for no reason.
static func tinted_material(src: StandardMaterial3D, tint: Color, dim: float,
		specular: float, emission_color: Color, emission_energy: float,
		roughness: float = 0.9) -> StandardMaterial3D:
	var m: StandardMaterial3D = src.duplicate() if src else StandardMaterial3D.new()
	m.albedo_color = Color(tint.r * dim, tint.g * dim, tint.b * dim, 1.0)
	m.metallic = 0.0
	m.metallic_specular = specular
	m.roughness = roughness
	m.emission_enabled = emission_energy > 0.0
	m.emission = emission_color
	m.emission_energy_multiplier = emission_energy
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


# Apply one material to every surface and return it, so a caller can keep mutating it (the
# Breach's wound flash tweens this exact object as the creature's shield drains).
func apply_tint(tint: Color, dim: float, specular: float,
		emission_color: Color, emission_energy: float) -> StandardMaterial3D:
	var src: StandardMaterial3D = null
	if not _meshes.is_empty() and _meshes[0].mesh and _meshes[0].mesh.get_surface_count() > 0:
		src = _meshes[0].mesh.surface_get_material(0) as StandardMaterial3D
	var mat := tinted_material(src, tint, dim, specular, emission_color, emission_energy)
	for mi in _meshes:
		mi.material_override = mat
	return mat
