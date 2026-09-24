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

# ⭐ THE SEAL RACE (2026-09-23 pass 4, behind ONE switch — the user: "make this feature easily
# [reversible], it is likely that after testing it I will say to restore it back").
# ⚠️ OFF BY DEFAULT: with `seal_race` false, `interact()` runs the original instant slam, UNCHANGED
# below. `level_6_breach.gd:SEAL_RACE` turns it on and passes the two times in.
# With it ON:
# - E starts the blast door grinding shut, and it advances only while E is HELD. Letting go rolls it
#   back open and ends the attempt.
# - A creature inside is frozen at the press. After `seal_react_delay` it is released and
#   `force_chase`d, so it charges the doorway at the player.
# - If it comes within `SEAL_JAM_DIST` of the doorway before the door shuts, the door JAMS: it is
#   flung back open, the creature is held by the door for the 0.4 s that takes, and it is loose. That
#   is not a death by itself, and the door can be tried again.
# - Shut with it inside, the ordinary freeze → confirm → purge runs.
@export var seal_race: bool = false
@export var seal_close_time: float = 1.25
@export var seal_react_delay: float = 0.8
const SEAL_JAM_DIST := 0.8          # the creature's body this close to the doorway plane blocks the leaf
const REOPEN_TIME := 0.4            # `_set_closed()`'s own swing time; the jam holds the creature this long

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
# the race
var _closing := false
var _close_u := 0.0                 # 0 = open, 1 = shut
var _race_t := 0.0
var _race_inside := false           # was the creature inside when E was pressed?
var _race_charging := false
var _grind: AudioStreamPlayer3D
var _swing: Tween                   # the race's roll-back / jam swing, killed if E is pressed again mid-swing
var race_log: Array = []            # [event, time, creature distance to the doorway plane] for the tests
# ⭐ CONTAINED XOR KILLED (2026-09-24 pass 5, the user: "It is either contained and you can get out or
# you get killed"). The playtest log: `KILL BLACK / FATAL FUNNEL` at 314.58, then `SEALED … LEAVE` at
# 316.93, then the restart — the player was killed INSIDE ExitVault while the held race close ran on,
# the door shut, and the confirm and purge timers completed the win under the death.
# The first outcome wins: once a death is claimed, everything in flight here aborts. `death_check` is
# the level's "is a death claimed?" (a Callable, so a panic death counts too); `abort_for_death()` is
# the level's hook, called the instant its kill sequence takes the fatal transition. Every timer
# callback carries the generation it was scheduled in, and a stale one does nothing.
var death_check: Callable
var _gen := 0
var _aborted := false


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


# The level's kill sequence has claimed the death: stop whatever is in flight (a held close, a pending
# confirm, the purge sequence) and never emit `creature_trapped`. The door is left where it is.
func abort_for_death() -> void:
	if _aborted:
		return
	_aborted = true
	_gen += 1
	if _closing:
		_closing = false
		if _grind:
			_grind.stop()
		race_log.append(["death", _race_t, _plane_distance()])


func _death_claimed() -> bool:
	return _aborted or (death_check.is_valid() and bool(death_check.call()))


func is_aborted() -> bool:
	return _aborted


func interact() -> void:
	if _death_claimed():
		return
	if seal_race:
		_race_begin()
		return
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
	# ⭐ 2026-09-24 (the user's call): the purge door has its OWN slam, the user's recorded heavy door
	# with a long echoing tail (tools/prepare_breach_user_sfx.py). The approach bulkhead keeps
	# blast_door_slam. Falls back to it if the file is ever missing.
	var slam: AudioStream = GameState.load_audio("purge_door_slam")
	if slam == null:
		slam = GameState.load_audio("blast_door_slam")
	if slam:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = slam
		pl.unit_size = 8.0
		add_child(pl)
		pl.finished.connect(pl.queue_free)
		pl.play()
	get_tree().create_timer(CLOSE_TO_CONFIRM_DELAY).timeout.connect(_confirm_trap.bind(_gen))


func _confirm_trap(gen: int = -1) -> void:
	if gen != _gen or _death_claimed():
		abort_for_death()
		return
	if not _resolve_creature():
		_reopen_failed()
		return
	var pos: Vector3 = _creature.get_creature_position() if _creature.has_method("get_creature_position") else (_creature as Node3D).global_position
	if trap_bounds.has_point(pos):
		_run_purge_sequence(gen)
	else:
		if _creature.has_method("unfreeze_for_purge"):
			_creature.unfreeze_for_purge()
		_reopen_failed()


func _run_purge_sequence(gen: int = -1) -> void:
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
	get_tree().create_timer(PURGE_SEQUENCE_DELAY).timeout.connect(_finish_purge.bind(gen))


func _finish_purge(gen: int = -1) -> void:
	if gen != _gen or _death_claimed():
		abort_for_death()
		return
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
	# (`_closing` is the race's version of the same signal; it is always false with the race off.)
	get_tree().create_timer(1.0).timeout.connect(func():
		if _used or _closing:
			return
		_set_closed(false))


func _set_closed(v: bool) -> void:
	_block_collider.disabled = not v
	var target_deg := 0.0 if v else -95.0
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation_degrees:y", target_deg, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------------------------ the race

func _race_begin() -> void:
	if _used or _closing:
		return
	if _swing and _swing.is_valid():
		_swing.kill()
	_closing = true
	# E again while it is still swinging back open: the grind starts from where the leaf IS
	_close_u = clampf(inverse_lerp(-95.0, 0.0, _hinge.rotation_degrees.y), 0.0, 1.0)
	_race_t = 0.0
	_race_charging = false
	_race_inside = _resolve_creature() and trap_bounds.has_point(_creature_pos())
	if _race_inside and _creature.has_method("freeze_for_purge"):
		_creature.freeze_for_purge()            # it stops: the door is moving, it turns
	race_log.append(["begin", 0.0, _plane_distance()])
	if _grind == null:
		_grind = AudioStreamPlayer3D.new()
		_grind.name = "SealGrind"
		_grind.unit_size = 6.0
		_grind.max_db = 4.0
		add_child(_grind)
	# ⚠️ PLACEHOLDER: the approach wheel's grind, pitched down to a heavy door (the user may supply one)
	_grind.stream = GameState.load_audio("approach_wheel_grind")
	_grind.pitch_scale = 0.55
	_grind.volume_db = 0.0
	if _grind.stream:
		_grind.play()
	set_process(true)


func _process(delta: float) -> void:
	if not _closing:
		return
	if _death_claimed():
		abort_for_death()
		return
	_race_t += delta
	var held := Input.is_action_pressed("interact")
	if not held:
		race_log.append(["released", _race_t, _plane_distance()])
		_race_abort(false)
		return
	_close_u = minf(1.0, _close_u + delta / maxf(0.05, seal_close_time))
	_hinge.rotation_degrees.y = lerpf(-95.0, 0.0, _close_u)
	# ⚠️ A BLINDED CREATURE CANNOT REACT (2026-09-24, Issue 275). If the light weapon staggered it, it
	# stays purge-frozen through the whole close and the door shuts on it — the blind the player paid
	# for is honoured. (Releasing it here and force_chase-ing it is what killed the playtester at the
	# door 0.8 s into the close.) Letting go of E still releases it via `_race_abort`, still staggered.
	var blinded: bool = _race_inside and _creature.has_method("is_staggered") and _creature.is_staggered()
	if _race_inside and not _race_charging and not blinded and _race_t >= seal_react_delay:
		_race_charging = true
		race_log.append(["charge", _race_t, _plane_distance()])
		if _creature.has_method("unfreeze_for_purge"):
			_creature.unfreeze_for_purge()
		if _creature.has_method("force_chase"):
			_creature.force_chase()
	# A body in the doorway jams the leaf: the charging one, or one that was never inside (it wandered
	# up to the door while it was closing). Never the frozen one, which is deep in the vault.
	var loose := _race_charging or not _race_inside
	if loose and _plane_distance() <= SEAL_JAM_DIST and _in_doorway_span():
		race_log.append(["jam", _race_t, _plane_distance()])
		_race_abort(true)
		return
	if _close_u >= 1.0:
		race_log.append(["shut", _race_t, _plane_distance()])
		_closing = false
		if _grind:
			_grind.stop()
		# shut: exactly the old slam from here on, including the freeze if it is inside
		_used = true
		_block_collider.disabled = false
		_hinge.rotation_degrees.y = 0.0
		if _resolve_creature() and _creature.has_method("freeze_for_purge"):
			_creature.freeze_for_purge()
		var slam: AudioStream = GameState.load_audio("purge_door_slam")
		if slam == null:
			slam = GameState.load_audio("blast_door_slam")
		if slam:
			var pl := AudioStreamPlayer3D.new()
			pl.stream = slam
			pl.unit_size = 8.0
			add_child(pl)
			pl.finished.connect(pl.queue_free)
			pl.play()
		get_tree().create_timer(CLOSE_TO_CONFIRM_DELAY).timeout.connect(_confirm_trap.bind(_gen))


# The attempt ends open: E let go (it rolls back) or the creature jammed the leaf (it is flung back).
func _race_abort(jammed: bool) -> void:
	_closing = false
	_used = false
	if _grind:
		_grind.stop()
	# Only a creature THIS attempt froze is released; one outside the trap was never touched.
	if _race_inside and _resolve_creature():
		if _creature.has_method("unfreeze_for_purge"):
			_creature.unfreeze_for_purge()
		if jammed and _creature.has_method("force_block"):
			_creature.force_block(REOPEN_TIME)
	if jammed:
		var crash := GameState.load_audio("door_break")
		if crash:
			var pl := AudioStreamPlayer3D.new()
			pl.stream = crash
			pl.unit_size = 8.0
			add_child(pl)
			pl.finished.connect(pl.queue_free)
			pl.play()
	_swing = create_tween()
	_swing.tween_property(_hinge, "rotation_degrees:y", -95.0, REOPEN_TIME if jammed else 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _creature_pos() -> Vector3:
	if not _resolve_creature():
		return Vector3(INF, INF, INF)
	return _creature.get_creature_position() if _creature.has_method("get_creature_position") else (_creature as Node3D).global_position


# How far the creature is from the doorway plane, on the trap's side (the door's local +z faces
# out of the trap in the Breach: the leaf shuts across local z = 0).
func _plane_distance() -> float:
	var p := _creature_pos()
	if p.x == INF:
		return INF
	var local := to_local(p)
	return absf(local.z)


func _in_doorway_span() -> bool:
	var local := to_local(_creature_pos())
	return absf(local.x) <= LEAF.x * 0.5 + 0.4


# The HUD prompt. With the race off this is the Breach label's own "Press E", i.e. exactly what the
# prompt said before this method existed. With it on, a tap only budges the leaf, so the prompt has to
# name the verb: a player who presses E once, as the old door taught, would otherwise watch it roll
# back and not know why.
func prompt_text() -> String:
	return "Hold E — seal the door" if seal_race else "Press E"


func is_closing() -> bool:
	return _closing


func close_progress() -> float:
	return _close_u
