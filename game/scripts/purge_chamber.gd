extends StaticBody3D
class_name PurgeChamber

# The one-shot, permanent escalation of SlamDoor — the level's ONLY true win
# condition. Sits at the PurgeAnte -> Incinerator threshold. interact() slams a heavy
# blast door, then checks the creature's ACTUAL position against the Incinerator
# room's bounds — never a flag, the same "physics-driven, not speculative" discipline
# this project's own tests hold themselves to (Issue 16's lesson, applied to real game
# logic here rather than just a test). If the creature is inside, it's purged for
# good; if not, the door reopens so a mistimed lure is retryable, not a run-ender.

signal creature_trapped

@export var creature_path: NodePath
@export var trap_bounds: AABB = AABB(Vector3(-3.5, -0.5, -3.5), Vector3(7.0, 4.0, 7.0))

const CLOSE_TO_CONFIRM_DELAY := 1.2
const PURGE_SEQUENCE_DELAY := 2.5
const INTERACTABLE_LAYER := 2   # matches note.gd — raycast-hittable, pass-through for movement
# How long the sealed chamber holds after the purge before venting. Long enough that the
# purge reads as a sequence, short enough that nobody thinks they are stuck.
const REOPEN_AFTER_PURGE := 2.0
const _DOOR_SCRIPT := preload("res://scripts/door.gd")
# The neutral warm-grey `slam_door.gd` uses. ⚠️ NOT the red — that tint is reserved for doors that
# are actually the way out, and this one is a furnace.
const ART_TINT := Color(0.35, 0.33, 0.30)

var _used: bool = false
var _creature: Node = null
var _hinge: Node3D
var _panel: MeshInstance3D
var _collider: CollisionShape3D
var _block_body: StaticBody3D
var _block_collider: CollisionShape3D


func _ready() -> void:
	_build_frame()
	_build_visual()

	# Same fix as slam_door.gd, and the exact same bug it fixes — see that file for
	# the full story. This body's collider is always enabled, on the pass-through
	# interactable layer, purely so E always finds this door regardless of open/
	# closed state. Physical blocking (and creature LOS through the open doorway)
	# is owned by the separate body below.
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# ⚠️ Widened 2026-07-24 playtest: the raycast-hittable box used to match the physical
	# panel exactly (2.2 x 3.0 x 0.15) — a razor-thin slab at the doorway plane. This is
	# the level's ONLY permanent win condition and it's meant to be triggered while being
	# chased, so a player glancing back at the creature or approaching off-axis would miss
	# the 0.15 m z-depth entirely. Depth alone increased (not width/height, which were
	# already generous) so the interact ray has real margin along the approach axis.
	#
	# ⚠️ 2026-08-15 — that fix was only half of it, and the other half survived another
	# three weeks because no test aimed where a player aims. The box is centred on the
	# DOORWAY, but `_build_visual()` parks the blast door at -95°, which puts the visible
	# panel about 1.2 m to -x and 1.1 m to +z — outside this volume on both axes. So a
	# player looking at the enormous open blast door and pressing E got nothing; only a
	# player aiming at the empty doorway beside it was answered. On the level's ONLY
	# permanent win condition, triggered while being chased.
	#
	# The volume now spans the doorway AND the swung-open panel. `check_interact_reach.gd`
	# aims at the mesh, which is what caught it and what stops it coming back.
	shape.size = Vector3(3.6, 3.0, 2.4)
	_collider.shape = shape
	_collider.position = Vector3(-0.7, 1.5, 0.6)
	add_child(_collider)

	_block_body = StaticBody3D.new()
	add_child(_block_body)
	_block_collider = CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(2.2, 3.0, 0.15)
	_block_collider.shape = bshape
	_block_collider.position.y = 1.5
	_block_collider.disabled = true
	_block_body.add_child(_block_collider)


# Static (not part of the hinge) — same fix as slam_door.gd's _build_frame(), scaled
# up for this door's larger 2.2x3.0 panel. See that file for why: without it, a
# swung-open panel has nothing anchoring it to the wall it's supposedly hinged to.
func _build_frame() -> void:
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.1, 0.1, 0.11)
	frame_mat.metallic = 0.6
	frame_mat.roughness = 0.4

	# ⚠️ THE FRAME USED TO POKE THROUGH THE CEILING (fixed 2026-09-03). Breach rooms are 3.0 m
	# tall (`RoomBuilder.DEFAULT_H`) and these jambs were **3.1 m** with a lintel whose top edge
	# sat at 3.05 + 0.06 = **3.11 m** — so 11 cm of blast-door frame stood inside the ceiling
	# slab, on the level's one-shot win condition. `check_wall_overlap.gd` sweeps this scene and
	# did not catch it, because a prop INSIDE a slab is legitimately how a flush fitting or a
	# closed drawer looks and the guard forgives that class by design.
	#
	# The leaf is 3.0 m, so the frame has to be shorter than the room, not taller than the door.
	# Jambs stop 4 cm under the ceiling and the lintel sits inside that.
	const ROOM_H := 3.0
	const JAMB_H := ROOM_H - 0.04
	# ⚠️⚠️ DEPTH 0.26, NOT 0.16 — the jambs were 100 % BURIED (2026-09-03). `RoomBuilder.T` is 0.2,
	# so the wall spans z -0.1..+0.1 about the doorway plane and a 0.16-deep jamb centred there
	# spans -0.08..+0.08: entirely inside the masonry, on both faces. The 2026-09-03 pass moved
	# these jambs in X (they were at +/-1.18 against a 2.2 m opening, i.e. buried sideways too)
	# and that half was right — but moving them sideways cannot make something visible that is
	# too shallow to reach either wall face. Same class as `slam_door.gd:FRAME_D`.
	# ⚠️ It must EXCEED 0.2, never equal it, or the faces are coplanar and z-fight (Issue 11).
	const JAMB_D := 0.26
	var jamb_size := Vector3(0.1, JAMB_H, JAMB_D)
	for side in [-1.0, 1.0]:
		var jamb := MeshInstance3D.new()
		var jm := BoxMesh.new()
		jm.size = jamb_size
		jamb.mesh = jm
		# ⚠️ AND THEY SAT INSIDE THE WALL. The doorway at Vector2(0,55) is 2.2 m wide, i.e. it
		# spans +/-1.1 — jambs centred at +/-1.18 with a half-width of 0.05 ran 1.13..1.23, so
		# both of them were buried in the masonry either side of the opening rather than
		# standing on its edges. They now abut the opening exactly.
		jamb.position = Vector3(side * (1.1 + jamb_size.x * 0.5), jamb_size.y * 0.5, 0.0)
		jamb.set_surface_override_material(0, frame_mat)
		add_child(jamb)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(2.2 + 0.1 * 2.0, 0.12, JAMB_D)
	lintel.mesh = lm
	lintel.position = Vector3(0.0, JAMB_H - 0.06, 0.0)
	lintel.set_surface_override_material(0, frame_mat)
	add_child(lintel)


# ⚠️⚠️ THIS WAS THE ONLY UNTEXTURED DOOR IN THE LEVEL (fixed 2026-09-07, from the user's
# *"make sure all the doors look the same"*). A flat-tinted `BoxMesh(2.2, 3.0, 0.15)` at
# `Color(0.14, 0.14, 0.15)`, metallic 0.7 — beside two exit doors and eight slam-door leaves that
# all carry `breach_door.png`. It is the BIGGEST door in the level and the only permanent win
# condition, and it looked like grey packaging next to six industrial blast doors.
#
# ⚠️ AND NO GUARD COULD SEE IT. `check_art_aspect.gd` returns early on a mesh that is not a
# `QuadMesh`/`PlaneMesh`, and again on a null `albedo_texture` — so **a prop with no artwork at all
# is invisible to the one guard that exists for artwork**. The stretched things get caught; the
# missing thing does not. `check_breach_doors.gd` is the answer to that.
#
# ⚠️ ART ON A `QuadMesh`, NEVER ON THE `BoxMesh` FACE (Issue 24) — a textured box renders a
# magnified crop of its own art. The box stays as the leaf's edge and depth, exactly as
# `door.gd:build_visual()` does it, with the picture on a quad a millimetre proud of each face.
const LEAF := Vector3(2.2, 3.0, 0.15)
const TEX := "res://assets/textures/level_6_breach/breach_door.png"


func _build_visual() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.14, 0.14, 0.15)
	steel.metallic = 0.7
	steel.roughness = 0.4

	_hinge = Node3D.new()
	_hinge.position = Vector3(-1.1, 0.0, 0.0)
	_hinge.rotation_degrees.y = -95.0
	add_child(_hinge)

	_panel = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = LEAF
	_panel.mesh = pm
	_panel.position = Vector3(1.1, 1.5, 0.0)
	_panel.set_surface_override_material(0, steel)
	_hinge.add_child(_panel)

	# ⚠️ BOTH FACES. This leaf swings 95 deg into the Incinerator and the player walks past its
	# back to bait the trap, so an art-on-the-front-only treatment (which is right for `door.gd`,
	# whose doors are always flat against a solid wall) would show bare steel from the side the
	# player actually approaches from.
	if not ResourceLoader.exists(TEX):
		return
	for face in [1.0, -1.0]:
		var art := MeshInstance3D.new()
		art.name = "PurgeDoorArt%s" % ("Front" if face > 0.0 else "Back")
		var qm := QuadMesh.new()
		qm.size = Vector2(LEAF.x, LEAF.y)
		art.mesh = qm
		var mat := _DOOR_SCRIPT.door_material(TEX, 1.0, true, ART_TINT)
		# The same centred-sub-rect crop every other door in the level uses, so one plate reads
		# undistorted on leaves of three different aspects.
		_DOOR_SCRIPT.crop_uv_to_fit(mat, LEAF.x / LEAF.y)
		art.set_surface_override_material(0, mat)
		art.position = Vector3(0, 0, face * (LEAF.z * 0.5 + 0.004))
		if face < 0.0:
			art.rotation.y = PI
		_panel.add_child(art)


func _resolve_creature() -> bool:
	if _creature and is_instance_valid(_creature):
		return true
	if creature_path.is_empty():
		return false
	_creature = get_node_or_null(creature_path)
	return _creature != null


func interact() -> void:
	if _used:
		return
	_used = true
	_set_closed(true)
	# Freeze the creature the INSTANT the door seals, not after the confirm/purge
	# delays below — CHASE_SPEED closes a few metres in well under a second, so a
	# player who successfully lured it in and sealed the door was still getting
	# killed before the win ever registered (found by tests/walk_level6_breach.gd).
	if _resolve_creature() and _creature.has_method("freeze_for_purge"):
		_creature.freeze_for_purge()
	var slam := GameState.load_audio("blast_door_slam")
	if slam:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = slam
		pl.unit_size = 8.0
		add_child(pl)
		pl.finished.connect(pl.queue_free)
		pl.play()
	get_tree().create_timer(CLOSE_TO_CONFIRM_DELAY).timeout.connect(_confirm_trap)


func _confirm_trap() -> void:
	if not _resolve_creature():
		_reopen_failed()
		return
	var pos: Vector3 = _creature.get_creature_position() if _creature.has_method("get_creature_position") else (_creature as Node3D).global_position
	if trap_bounds.has_point(pos):
		_run_purge_sequence()
	else:
		if _creature.has_method("unfreeze_for_purge"):
			_creature.unfreeze_for_purge()
		_reopen_failed()


func _run_purge_sequence() -> void:
	# Reuses acid_hiss.wav from level_5_kontur — GameState.load_audio() already scans
	# every audio subdir, so no file copy is needed.
	var hiss := GameState.load_audio("acid_hiss")
	if hiss:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = hiss
		pl.unit_size = 8.0
		add_child(pl)
		pl.finished.connect(pl.queue_free)
		pl.play()
	get_tree().create_timer(PURGE_SEQUENCE_DELAY).timeout.connect(_finish_purge)


func _finish_purge() -> void:
	if _creature and _creature.has_method("lure_into_trap"):
		_creature.lure_into_trap()
	creature_trapped.emit()
	# ⚠️⚠️ REOPEN, OR WINNING THE LEVEL LOCKS YOU OUT OF IT (2026-09-07, Issue 181). The exit
	# door is at z = 61.85 — INSIDE the Incinerator, which is the same room as `trap_bounds` —
	# and this blast door is the only way in. The entry note says *"Lead it inside. Seal the
	# door behind it"* and the PurgeAnte sign says *"LURE IT IN — SEAL THE DOOR"*, so the
	# described play is to seal it from PurgeAnte. Measured (`probe_purge_softlock.gd`): press
	# E from z = 53.5 with the creature in the trap and `creature_defeated` goes true, the door
	# stays shut, and walking at the exit for six seconds ends at **z = 54.52, 7.42 m short of
	# it, for ever**. The level is WON and cannot be left.
	# There is nothing left to contain — `lure_into_trap()` is permanent — so venting the
	# chamber is both correct and the only thing that makes the win reachable from either side.
	get_tree().create_timer(REOPEN_AFTER_PURGE).timeout.connect(func():
		_set_closed(false))


func _reopen_failed() -> void:
	_used = false
	ScreenText.toast(get_tree(), "IT ISN'T IN THERE")
	# ⚠️ THE TIMER OUTLIVES THE ATTEMPT IT BELONGS TO. `_used` is cleared on the line above, so
	# the player can press E again well inside this 1.0 s — and the stale callback then opened
	# the blast door in the middle of the new attempt. Measured: E accepted at t+1.35 with the
	# door shut, blocker disabled at t+2.62 with `_used == true` and the lure live. Not a
	# soft-lock (the confirm reads the creature's real position, so a win still registers), but
	# the level could end with its win-condition door standing open. A new attempt sets `_used`,
	# which is exactly the "someone else owns the door now" signal.
	get_tree().create_timer(1.0).timeout.connect(func():
		if _used:
			return
		_set_closed(false))


func _set_closed(v: bool) -> void:
	_block_collider.disabled = not v
	var target_deg := 0.0 if v else -95.0
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation_degrees:y", target_deg, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
