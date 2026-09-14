class_name WeepingFrame
extends Node3D

# THE WEEPING FRAMES — DN's paintings (DUNGEON_NIGHTMARES.md §B4.6).
#
# Three tiers, driven by the SCONCE COUNT rather than by DN's night number:
#
#   0-2 sconces  Harmless. They hang there. They make no sound. Purely decorative.
#   3-4 sconces  Within 4 m they weep, and staring feeds panic. Still not fatal.
#   5+  sconces  Three seconds of continuous gaze IGNITES the frame — it burns out and is
#                inert afterwards. ⚠️ It used to be FATAL at this tier (DN's rule) and stopped
#                being so on 2026-09-12: THE NIGHTMARE is "hard to lose" by the user's call, and
#                the panic bar is its only death. `lethal` keeps the old branch reachable.
#
# This is the best teaching structure in the source material, and it is a BETTER
# implementation of "a rule's first encounter must be survivable" than the usual
# one — because the teaching encounter is not a softened version of the trap, it is
# THE IDENTICAL OBJECT. By the time it can kill you, you have already learned its
# silhouette, its position class and its voice. The sound arriving one tier before
# the danger is the tell arriving before the rule.

const GAZE_INTENSITY := 0.9
const FATAL_GAZE_TIME := 3.0
const WEEP_RANGE := 4.0
# ⚠️ The ignition tween must stay UNDER 1.0. Above it the surface clamps to flat
# pure white with no detail — Linear tonemap, exposure 1.0, and no glow anywhere in
# this project (Issue 21). §B4.6 calls out 0.9 explicitly.
const IGNITE_EMISSION_MAX := 0.9

@export var art_path: String = ""
@export var open_eyes_path: String = ""
# ⚠️ false by default since 2026-09-12: the fatal tier burns the painting out instead of the
# player. Gaze panic (GAZE_INTENSITY 0.9 = 18/s inside the player's 3 m gaze range) is the
# whole cost, and no extra term is charged at the burn — the user's decision, not a tuning.
@export var lethal: bool = false

var audible: bool = false
var fatal: bool = false

var _scary: ScaryObject = null
var _body: StaticBody3D = null
var _quad: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _weep: AudioStreamPlayer3D = null
var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _gaze_t: float = 0.0
var _igniting: bool = false
var _fired: bool = false


func _ready() -> void:
	# ⚠️ ScaryObject -> StaticBody3D -> collider. player.gd:_find_scary_object()
	# walks UP from the ray-hit body, so the ScaryObject must be an ANCESTOR.
	# ScaryObject extends Node and has no transform, which BREAKS the Node3D
	# spatial chain — so the world transform is seeded on the BODY (Issue 10).
	# Nesting ScaryObject under the body instead registers exactly zero panic.
	_scary = ScaryObject.new()
	_scary.scare_intensity = 0.0    # tier 0-2: harmless, and silent
	add_child(_scary)

	_body = StaticBody3D.new()
	_body.name = "FrameBody"
	_scary.add_child(_body)
	_body.global_transform = global_transform

	_quad = MeshInstance3D.new()
	_quad.name = "FrameArt"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.85, 1.1)
	if art_path != "" and ResourceLoader.exists(art_path):
		var tex: Texture2D = load(art_path)
		if tex != null:
			var aspect: float = float(tex.get_width()) / float(tex.get_height())
			var h := 1.1
			qm.size = Vector2(h * aspect, h)
	_quad.mesh = qm
	_mat = _make_mat(art_path)
	_quad.set_surface_override_material(0, _mat)
	_body.add_child(_quad)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(qm.size.x, qm.size.y, 0.1)
	col.shape = sh
	_body.add_child(col)

	_weep = AudioStreamPlayer3D.new()
	_weep.name = "FrameWeep"
	var s := GameState.load_audio("frame_weep")
	if s:
		_weep.stream = s
		# ⚠️ loop_mode=0 on every .wav.import here — loop by reconnecting finished.
		_weep.finished.connect(_weep.play)
	_weep.unit_size = 4.0
	_weep.volume_db = -10.0
	_body.add_child(_weep)


func _make_mat(path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			mat.albedo_texture = tex
			# A little emission so a picture on a wall is findable at 0.02 ambient.
			mat.emission_enabled = true
			mat.emission_texture = tex
			mat.emission_energy_multiplier = 0.18
			return mat
	mat.albedo_color = Color(0.16, 0.12, 0.1)
	return mat


# Tier 2 (3 sconces): they become audible and start feeding panic.
func set_audible(on: bool) -> void:
	if audible == on:
		return
	audible = on
	_scary.scare_intensity = GAZE_INTENSITY if on else 0.0


# Tier 3 (5 sconces): staring for three seconds ignites the frame (fatal only if `lethal`).
func set_ignites(on: bool) -> void:
	fatal = on


# Kept as an alias for the old name; the tier it names is the same one.
func set_fatal(on: bool) -> void:
	set_ignites(on)


func is_burnt() -> bool:
	return _fired and not lethal


func _process(delta: float) -> void:
	if _fired:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player == null:
			return
		_camera = _player.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		return

	var d: float = _body.global_position.distance_to(_player.global_position)

	if audible and _weep and _weep.stream:
		if d <= WEEP_RANGE and not _weep.playing:
			_weep.play()
		elif d > WEEP_RANGE * 1.5 and _weep.playing:
			_weep.stop()

	if not fatal:
		return

	# The fatal tier runs its own gaze clock rather than using trigger_object.gd's,
	# because the ignition wind-up has to be able to ABORT when the player looks
	# away — a fail state with no visible, reversible warning is the thing §B4.6's
	# escalation exists to avoid.
	var to: Vector3 = _body.global_position - _camera.global_position
	var looking: bool = d <= 6.0 \
		and (-_camera.global_transform.basis.z).dot(to.normalized()) > 0.9
	if looking:
		_gaze_t += delta
		if not _igniting and _gaze_t > 0.6:
			_begin_ignite()
		if _gaze_t >= FATAL_GAZE_TIME:
			_fired = true
			if lethal:
				Screamer.trigger()
			else:
				_burn_out()
	else:
		if _igniting:
			_abort_ignite()
		_gaze_t = 0.0


# ⭐ The Gallery archetype's scare (2026-09-12): the painting drops off its wall behind the
# player — a crash in the dark, a frame face-down on the flags, and the wall bare. Inert
# afterwards (no gaze panic, no weeping, no ignition). Zero panic of its own.
func fall() -> void:
	if _fired:
		return
	_fired = true
	if _scary:
		_scary.scare_intensity = 0.0
	if _weep and _weep.playing:
		_weep.stop()
	var s := GameState.load_audio("painting_fall")
	if s:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = s
		pl.unit_size = 10.0
		pl.max_db = 6.0
		pl.volume_db = 4.0
		_body.add_child(pl)
		pl.play()
		pl.finished.connect(pl.queue_free)
	# Pitch forward off the hook and drop; the landing slides ~0.5 m out along the frame's own
	# forward (`basis.z`, the House painting's lesson — never a hard-coded axis).
	var out: Vector3 = _body.global_transform.basis.z.normalized() * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_body, "rotation:x", deg_to_rad(-84.0), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_body, "global_position",
		Vector3(_body.global_position.x + out.x, 0.07, _body.global_position.z + out.z), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func has_fallen() -> bool:
	return _fired


func _begin_ignite() -> void:
	_igniting = true
	if open_eyes_path != "" and ResourceLoader.exists(open_eyes_path):
		var tex: Texture2D = load(open_eyes_path)
		if tex != null:
			_mat.albedo_texture = tex
			_mat.emission_texture = tex
	var s := GameState.load_audio("frame_ignite")
	if s:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = s
		pl.unit_size = 8.0
		_body.add_child(pl)
		pl.play()
		pl.finished.connect(pl.queue_free)
	var tw := create_tween()
	tw.tween_property(_mat, "emission_energy_multiplier", IGNITE_EMISSION_MAX,
		FATAL_GAZE_TIME - 0.6)


# The non-lethal end of the wind-up: the canvas blackens, the weeping stops, and the frame is
# inert for the rest of the night. No panic term here — the three seconds of gaze already cost
# 18/s if the player was inside gaze range, and a burn that also charged would be a second fee
# for one act.
func _burn_out() -> void:
	_fired = true
	_igniting = false
	if _weep and _weep.playing:
		_weep.stop()
	if _scary:
		_scary.scare_intensity = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mat, "emission_energy_multiplier", 0.0, 1.5)
	tw.tween_property(_mat, "albedo_color", Color(0.12, 0.1, 0.09), 1.5)


func _abort_ignite() -> void:
	_igniting = false
	if art_path != "" and ResourceLoader.exists(art_path):
		var tex: Texture2D = load(art_path)
		if tex != null:
			_mat.albedo_texture = tex
			_mat.emission_texture = tex
	var tw := create_tween()
	tw.tween_property(_mat, "emission_energy_multiplier", 0.18, 0.4)
