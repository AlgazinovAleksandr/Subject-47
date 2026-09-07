extends StaticBody3D

enum UnlockCondition { NONE, KEYCARD, CODE_ENTERED, TWIST_READ }

@export var unlock_condition: UnlockCondition = UnlockCondition.NONE
@export var advances_level: bool = true
@export var goes_back: bool = false

# An additional lock the OWNING LEVEL controls, on top of `unlock_condition`.
#
# KONTUR needs its exit sealed until all eight gates are passed — a condition no enum
# value can express, because it lives in the level script's own state rather than in
# GameState. The level sets this true at build time and clears it when the last gate
# falls. `locked_message` lets it say WHY, which matters there: a run can be forfeit,
# and "LOCKED" would read as a bug rather than as a verdict.
@export var extra_lock: bool = false
@export var locked_message: String = "LOCKED"

var _twist_activated: bool = false


# The material an exit / back door should wear.
#
# Project convention (CLAUDE.md): exit and back doors glow blood-red so the player
# can find the way on in the dark. Levels 1 and 2 implemented that as a flat red
# emissive box with no texture at all, which read as a red brick rather than a door.
# With a texture the albedo carries the door and the emission is tinted red THROUGH
# that same texture, so the glow takes the door's shape and the blood-red signature
# survives.
#
# emission stays enabled and starts at 1.5 in both branches because _flash_unlock()
# tweens emission_energy_multiplier from wherever it is up to 10.0 and back to 3.0.
# Build a door's visible geometry under `body` and return the node _flash_unlock()
# should tween.
#
# ⚠️ The artwork goes on QUADS, not on the slab. A BoxMesh does not map the whole
# texture onto each face, so a door textured directly on the box rendered a
# magnified CROP of its own art — one hinge and a blank panel, no window, no push
# bar. The tray and monitor in the morgue use quads and show their full textures,
# which is what made the difference obvious. The slab stays as the dark edge/depth.
#
# Only the FRONT face is textured. Every door in the game is mounted against a solid
# wall, so a second quad on the back is buried in that wall — dead geometry that also
# trips the wall-prop assertion in tests/check_wall_overlap.gd. Leaving it off turns
# that assertion into a useful check: a door built facing the wrong way has its front
# quad inside the wall, and the test fails.
static func build_visual(body: Node3D, size: Vector3, tex_path: String,
		emission_scale: float = 1.0, multiply: bool = false) -> MeshInstance3D:
	var slab := MeshInstance3D.new()
	slab.name = "DoorSlab"
	var bm := BoxMesh.new()
	bm.size = size
	slab.mesh = bm
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.09, 0.08, 0.08)
	edge.roughness = 0.9
	slab.set_surface_override_material(0, edge)
	body.add_child(slab)

	var face := MeshInstance3D.new()
	face.name = "DoorMesh"   # _flash_unlock() looks this node up by name
	var qm := QuadMesh.new()
	qm.size = Vector2(size.x, size.y)
	face.mesh = qm
	var mat := door_material(tex_path, emission_scale, multiply)
	crop_uv_to_fit(mat, size.x / size.y)
	face.set_surface_override_material(0, mat)
	face.position = Vector3(0, 0, size.z / 2.0 + 0.004)
	body.add_child(face)
	return face


# ⭐ CROSS-LEVEL X47, CLOSED (2026-09-03): "door.gd's shared art quad is stretched in every level
# that has a door."
#
# ⚠️ THE MEASUREMENT. `build_visual()` sizes its quad to the DOOR and hands the artwork whatever
# shape that leaves — **1.569x in the Lab, 1.177x in the House and 1.315x in THE NIGHTMARE**.
# `check_art_aspect.gd` has measured and deferred all three for as long as it has swept the
# project; they are the oldest outstanding art defect in it.
#
# ⚠️ **KONTUR'S GATE-1 DOORS ARE NOT AMONG THEM, AND THIS COMMENT SAID THEY WERE.** X47's own
# row quotes "1.571x on both of KONTUR's Gate 1 doors", but `choice_door.gd` **does not call
# `build_visual()`** — it builds its own box and quads, and its 1.571x was already fixed in that
# level's own pass by `tools/crop_kontur_art.py` plus a `LEAF_ASPECT`-derived height. Nothing
# here reaches it. Corrected 2026-09-03 after an audit probe caught the claim; it is exactly the
# kind of thing that reads as done because a nearby thing was done.
#
# ⚠️ WHY A UV CROP AND NOT A RESIZE. A door's WIDTH is set by its doorway and its HEIGHT by the
# room — neither is free to move to suit a picture, which is exactly why this was deferred rather
# than fixed prop by prop. Sampling a centred sub-rect of the texture instead costs some of the
# artwork's edges and costs nothing else, and it is a mechanism the project already sanctions:
# `check_art_aspect.gd` compares against pixel aspect x `uv1_scale` precisely because
# `intro_room.gd`'s note deliberately crops a square, black-backed source.
#
# ⚠️ It is a NO-OP when the aspects already agree, so a door whose art was authored to fit (the
# Corridor's `hotel_door_leaf.png`, whose width is DERIVED from its texture) is untouched.
static func crop_uv_to_fit(mat: StandardMaterial3D, mesh_aspect: float) -> void:
	if mat == null or mat.albedo_texture == null or mesh_aspect <= 0.0:
		return
	var tex := mat.albedo_texture
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	if tex_aspect <= 0.0 or absf(tex_aspect - mesh_aspect) < 0.001:
		return
	if tex_aspect > mesh_aspect:
		var u: float = mesh_aspect / tex_aspect       # plate wider than leaf: vertical slice
		mat.uv1_scale = Vector3(u, 1.0, 1.0)
		mat.uv1_offset = Vector3((1.0 - u) * 0.5, 0.0, 0.0)
	else:
		var v: float = tex_aspect / mesh_aspect       # plate taller than leaf: horizontal slice
		mat.uv1_scale = Vector3(1.0, v, 1.0)
		mat.uv1_offset = Vector3(0.0, (1.0 - v) * 0.5, 0.0)


# ⭐ THE DARKENED LEVELS DIM IT (2026-09-07, cross-level X64/X65 resolved by the user).
# `emission_scale` is ADDITIVE and defaults to 1.0, so every existing caller renders byte for
# byte as before; only the Lab and the House pass anything else. With those two at ambient 0.0
# and an 11 m torch, a self-lit prop is the ONLY thing visible at distance — measured before the
# change, the House's exit door was legible at ~21 m and a note at 6 m with the torch fully off,
# which is a permanent north-star in levels that were darkened for blind exploration.
# ⚠️ DIMMED, NOT KILLED, and that was the decision: the House GATES its payoff on reading all
# three safe notes and the Lab's locker gates on one, so a note that cannot be found is a level
# that cannot be finished. Halving moves them from "visible across the building" to "visible when
# the beam is near", which is the ask.
# ⚠️ The scale reaches the UNTEXTURED branch too, on purpose. Nothing in the Lab or the House
# takes it (both have door art), but KONTUR's leaves do, at emission 1.5 — nineteen times the
# textured branch — and leaving the parameter half-wired is how the next darkness pass ships a
# beacon it thought it had turned down.
# ⚠️ `multiply` and `tint` added 2026-09-07 for THE BREACH's door pass, both ADDITIVE and both
# defaulting to today's behaviour, so the five other levels that call this are byte-identical.
#
# Godot's default emission operator is **ADD**, which lays a uniform colour floor over the WHOLE
# leaf including its dark areas; `slam_door.gd` uses **MULTIPLY**, which tints the texture's own
# shape. Same PNG, two visibly different doors — and `slam_door.gd:450` claims to be "door.gd's
# textured branch verbatim", which it is not. The Breach now asks for MULTIPLY so its exit doors
# and its slam doors share one emission rule; the red TINT stays exclusive to the exit and back
# doors, because red-means-exit is a convention across all nine levels and this is the one level
# you are being chased toward one in.
static func door_material(tex_path: String = "", emission_scale: float = 1.0,
		multiply: bool = false,
		tint: Color = Color(0.6, 0.09, 0.09)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 1.5 * emission_scale
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex := load(tex_path)
		mat.albedo_texture = tex
		mat.albedo_color = Color(1, 1, 1)
		mat.emission_texture = tex
		# Very restrained on purpose. These levels are lit at ~0.45 energy, so a
		# surface's albedo contributes far less than its emission — at 0.5 the red
		# swamped the pale steel texture and the door rendered salmon pink. The
		# glow only has to make the door findable; its shape does the rest.
		mat.emission = tint
		mat.emission_energy_multiplier = 0.08 * emission_scale
		if multiply:
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.roughness = 0.85
	else:
		mat.albedo_color = Color(0.15, 0.01, 0.01)
		mat.emission = Color(0.35, 0.02, 0.02)
	return mat


func _process(_delta: float) -> void:
	if unlock_condition == UnlockCondition.TWIST_READ and not _twist_activated and GameState.twist_read:
		_twist_activated = true
		_flash_unlock()


func _flash_unlock() -> void:
	var door_mesh: MeshInstance3D = get_node_or_null("DoorMesh")
	if not door_mesh:
		return
	var mat := door_mesh.get_surface_override_material(0)
	if not mat:
		mat = door_mesh.mesh.surface_get_material(0) if door_mesh.mesh else null
	if not mat or not mat is StandardMaterial3D:
		return
	var std_mat := mat as StandardMaterial3D
	var tween := create_tween()
	tween.tween_method(
		func(e: float): std_mat.emission_energy_multiplier = e,
		std_mat.emission_energy_multiplier, 10.0, 0.3
	)
	tween.tween_method(
		func(e: float): std_mat.emission_energy_multiplier = e,
		10.0, 3.0, 0.6
	)


func interact() -> void:
	if _is_unlocked():
		_open_door()
	else:
		_show_locked_feedback()


func _is_unlocked() -> bool:
	if extra_lock:
		return false
	match unlock_condition:
		UnlockCondition.NONE:
			return true
		UnlockCondition.KEYCARD:
			return GameState.has_keycard
		UnlockCondition.CODE_ENTERED:
			return GameState.level2_code_correct
		UnlockCondition.TWIST_READ:
			return GameState.twist_read
	return false


func _open_door() -> void:
	var open_audio: AudioStreamPlayer3D = get_node_or_null("OpenAudio")
	if open_audio and open_audio.stream:
		open_audio.play()
	if goes_back:
		await get_tree().create_timer(0.5).timeout
		GameState.go_back()
	elif advances_level:
		await get_tree().create_timer(0.5).timeout
		GameState.advance_level()


func _show_locked_feedback() -> void:
	ScreenText.toast(get_tree(), locked_message, Color(1.0, 0.2, 0.2), 1.5, 48)
