extends Node3D
class_name CreatureObject12

# Level 6 — THE BREACH. Object 12, KONTUR's subject, loose. A persistent Nemesis/Mr.X
# -style pursuer: dormant until the level calls activate() (the familiarization window
# is owned by level_6_breach.gd, not here), then patrols a level-supplied waypoint
# loop, escalates to INVESTIGATE on noise, and once it has line-of-sight on the player
# it CLOSES DISTANCE EVERY FRAME in CHASE regardless of whether it is being watched —
# the deliberate opposite of creature_stalker.gd's Weeping-Angel "freeze while
# observed" rule, which would let a persistent chaser be cheesed by simply staring at
# it. Losing the player doesn't reset to PATROL: it walks to the last-seen position and
# scans there for a while first (SEARCH) — the one Mr.X/Alien:Isolation lesson worth
# stealing, because it's what makes hiding feel tense instead of a free reset.
#
# Contact is instant-fatal, exactly like every other creature in the game — no grab or
# struggle QTE. Sustained aimed flashlight (apply_light_damage(), driven every frame by
# the level orchestrator, which owns the "is the player actually aiming at it" check)
# drains a shield and stops it in STAGGERED for STAGGER_MIN..STAGGER_MAX seconds — a
# temporary repel,
# not a kill. The only permanent defeat is being lured into the level's PurgeChamber,
# which calls lure_into_trap() directly.

signal state_changed(old: int, new: int)
signal staggered(duration: float)
signal recovered()
signal contact_fatal()

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, STAGGERED }

# ⚠️ These five are @export rather than const so THE NIGHTMARE's Matron can be a
# RETUNE of this creature instead of a fork (DUNGEON_NIGHTMARES.md §B4.2/§B13).
# EVERY DEFAULT IS THE LEVEL 6 VALUE, unchanged — Level 6 sets none of them and
# therefore behaves exactly as it always has.
#
# The Nightmare overrides chase_speed to 3.4, which is BELOW the player's 4.0 walk,
# not between walk and sprint like the value here. That is the whole resolution of
# that level's central problem: walking away always works, so sprinting is a
# shortcut you MAY buy with panic and never the answer (§B1 rule 1).
@export var patrol_speed: float = 1.8
@export var investigate_speed: float = 2.6
# Must beat the player's walk (player.gd SPEED = 4.0) or it's not a threat; must lose
# to the player's sprint (SPEED * SPRINT_MULTIPLIER = 6.4) or sprinting is pointless.
@export var chase_speed: float = 5.0
@export var contact_dist: float = 1.0
@export var detect_range: float = 10.0
const FOV_DOT := 0.5           # wide cone (~120 deg) — this creature actively hunts
const CHEST := 0.9
const SEARCH_TIME := 8.0
const INVESTIGATE_GIVEUP_TIME := 6.0
const WAYPOINT_ARRIVE_DIST := 0.6
const LOS_LOSS_GRACE := 0.4    # forgiveness window before CHASE -> SEARCH
const SEARCH_SCAN_SPEED_DEG := 40.0
const SHIELD_MAX := 100.0
const SHIELD_DRAIN_RATE := 40.0   # ~2.5s of sustained aimed light to stagger
const SHIELD_REGEN_DELAY := 3.0
const SHIELD_REGEN_RATE := 15.0
# ⚠️ Was a flat STAGGER_DURATION := 25.0. BACKLOG #26 asked for "only 5 seconds or
# something like that (can be random from 3-7)", and the user confirmed 5-7 with the
# blind restricted to an active chase. Randomised so the window can't be counted out:
# a fixed number turns a panicked escape into arithmetic.
#
# Note what the backlog item actually described — "it is inactive for the very short
# period" — was NOT this constant. 25 s was real. What was broken is in
# apply_light_damage(): the stagger could only trigger from CHASE or INVESTIGATE, so
# emptying the shield of a creature that was PATROLling or SEARCHing did nothing at all
# and it just kept coming. That reads as "the blind lasted no time"; it had never
# started. The condition is now CHASE-only and explicit, and the shield does not drain
# outside a chase, so light is never silently wasted.
const STAGGER_MIN := 5.0
const STAGGER_MAX := 7.0
const STAGGER_TILT_DEG := 35.0

var _player: CharacterBody3D
var _camera: Camera3D
var _body: StaticBody3D
var _body_collider: CollisionShape3D
var _visual_root: Node3D
var _space: PhysicsDirectSpaceState3D

var _state: int = State.PATROL
var _active: bool = false

var _waypoints: PackedVector3Array = PackedVector3Array()
var _wp_index: int = 0
var _investigate_target: Vector3 = Vector3.ZERO
var _investigate_t: float = 0.0
var _last_seen_pos: Vector3 = Vector3.ZERO
var _search_t: float = 0.0
var _los_lost_t: float = 0.0
var _stagger_t: float = 0.0
var _stagger_len: float = STAGGER_MAX   # rolled per stagger, see STAGGER_MIN/MAX
var _block_t: float = 0.0   # set by force_block(); pauses movement under any state
# ⚠️ SEPARATE FROM `_block_t`, AND THAT SEPARATION IS THE FIX (2026-09-07). See the block above
# `freeze_for_purge()` for the 2-hour-46-minute bug the shared counter caused.
var _purge_frozen: bool = false

var _shield: float = SHIELD_MAX
var _shield_idle_t: float = 0.0
var _material: StandardMaterial3D   # shared retint material, tweened for the wound flash


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()

	# Same transform-chain discipline as creature_stalker.gd (Issue 10): ScaryObject
	# is a plain Node with no transform, so the world position lives on _body, not
	# on the ScaryObject or this outer Node3D. scare_intensity is 0 — this creature's
	# fail states are driven directly (contact, detection), not gaze-panic.
	var scary := ScaryObject.new()
	scary.scare_intensity = 0.0
	add_child(scary)
	_body = StaticBody3D.new()
	scary.add_child(_body)
	_body.global_transform = global_transform
	_body_collider = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	_body_collider.shape = shape
	_body_collider.position.y = 0.85
	_body.add_child(_body_collider)

	_build_visual()


# ⭐ THE ANIMATED MODEL (2026-09-03). Was `Void_creature.glb`, which contained **zero animation
# tracks** — so this creature chased the player across two levels in a rigid T-pose for the whole
# life of the feature. The `_pose_arms_down()` / `_rotate_bone()` pair that used to live here
# (and in `creature_stalker.gd` and `containment_cell.gd`, byte-identical) was measured in
# 2026-08 to move nothing at all, and is deleted rather than ported.
#
# ⚠️ The `get_node_or_null("Cube")` strip went with it — that stray cube was an artefact of the
# old Blender export and does not exist in the merged asset. `tools/merge_creature_glb.py`
# builds the replacement; `tests/check_creature_model.gd` asserts what it must contain.
var _anim: CreatureAnim = null

func _build_visual() -> void:
	_anim = CreatureAnim.build(_body)
	if _anim:
		_visual_root = _anim.visual_root()
	else:
		_build_visual_procedural()
	_apply_retint()
	_refresh_clip()


func _build_visual_procedural() -> void:
	_visual_root = Node3D.new()
	_body.add_child(_visual_root)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.02)
	dark.roughness = 1.0

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.15
	torso_mesh.height = 2.2
	torso.mesh = torso_mesh
	torso.position.y = 1.2
	torso.set_surface_override_material(0, dark)
	_visual_root.add_child(torso)

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.38, 0.06, 0.07)
		arm.mesh = arm_mesh
		arm.set_surface_override_material(0, dark)
		arm.position = Vector3(side * 0.24, 1.7, 0.0)
		arm.rotation_degrees.z = -side * 18.0
		_visual_root.add_child(arm)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head.mesh = head_mesh
	head.position.y = 2.45
	head.set_surface_override_material(0, dark)
	_visual_root.add_child(head)


# Distinguishes Object 12 from the Void's stalkers by palette. This same material is what
# apply_light_damage()'s wound flash tweens.
#
# ⚠️ IT DUPLICATES THE MODEL'S OWN MATERIAL NOW, instead of building a fresh one (2026-09-03).
# The old version assigned a brand-new `StandardMaterial3D` as `material_override`, which threw
# the model's textures away wholesale — survivable when the model was an untextured T-pose,
# wrong now that it carries a real 1024 skin. `albedo_color` MULTIPLIES that texture, so the
# three palette numbers below are unchanged and only their meaning moved: from "replace the
# skin with grey-green" to "the skin at 35/40/32 %".
#
# ⚠️ `EMISSION_BASE` dropped 0.35 -> 0.12. Two reasons, both measured: the model is no longer a
# flat untextured blob that needed a vein glow to read at all, and the levels this creature
# lives in are about to run at ~0.02 ambient — at 0.35 it would be visible from across a dark
# room without the torch, which is the one thing the darkness pass exists to prevent. The wound
# flash still climbs to `WOUND_EMISSION` — see `_update_wound_tint()`, which is where that
# number lives and where the stale copy of THIS one was found.
const EMISSION_BASE := 0.12
const ALBEDO_TINT := Color(0.35, 0.4, 0.32)
const EMISSION_TINT := Color(0.4, 0.05, 0.05)

func _apply_retint() -> void:
	if _anim:
		_material = _anim.apply_tint(ALBEDO_TINT, 1.0, 0.2, EMISSION_TINT, EMISSION_BASE)
		return
	# Procedural fallback: no imported material to duplicate.
	_material = CreatureAnim.tinted_material(
		null, ALBEDO_TINT, 1.0, 0.2, EMISSION_TINT, EMISSION_BASE)
	for mi in _find_mesh_instances(_visual_root):
		mi.material_override = _material


# ---------------------------------------------------------------- gait
#
# ⚠️ DRIVEN OFF `_state` AND `_active` ONLY — never off a private of some caller — so the state
# machine itself is untouched and `tests/test_creature_object12.gd` (which asserts through
# signals alone) keeps passing byte-for-byte.
#
# ⚠️ THE CHASE CLIP IS CHOSEN BY SPEED, and that is what makes one script serve two creatures.
# `chase_speed` is 5.0 for the Breach's Object 12 and 3.4 for THE NIGHTMARE's Matron. Played on
# one clip, the slower of the two lands at a 0.62 speed_scale — visibly slow-motion running.
# `charge` (measured 2.849 m/s) covers the Matron at 1.19 and `run` (5.487) covers the Breach at
# 0.91, so both sit near 1.0 and neither looks retimed. See CreatureAnim.CLIP_SPEED for how
# those reference speeds were measured.
const CHASE_CLIP_SPLIT := 4.2

# ⭐ DORMANT IS A HELD POSE, NOT A SWAY (2026-09-07, the user's call: *"the creature is moving
# even when it is not active. It should not be like this. First it stands still, then when it is
# active it starts walking, and only after it sees you it starts running."*).
#
# ⚠️ It used to be `CLIP_SHAMBLE` at `DORMANT_RATE 0.5`, described here as "a barely-moving
# standing sway". Measured, it is nothing of the kind: `shamble` carries **0.515 m of hip
# excursion and a 57.9 deg arm swing** over its cycle, ten times `walk`'s 0.061 m drift, and at
# 0.5x that is an 11 s pendulum. It is the most mobile clip in the asset and it was on the one
# creature the player is invited to stand and stare at.
#
# ⚠️ WHY THIS IS NOT PURELY COSMETIC. `level_6_breach.gd` spawns Object 12 at `(0, 0, 14)` and the
# player at `(0, 0.1, -2)` facing +Z: 16.0 m, heading 0.0 deg, unobstructed line of sight through
# two doorways both centred on x = 0, lit by its own lamp, inside the 18 m torch beam, ~9.4 % of
# screen height, throwing a moving shadow. Whatever the dormant creature does is the first thing
# the level shows you, for 30 seconds, and a swaying one reads as *awake and ignoring you* — which
# is exactly the wrong lesson before the thing starts hunting.
#
# ⚠️ THE CLIP IS `walk` AND THE TRANSITION IS THE REASON. `activate()` calls `_refresh_clip()`,
# which asks for `play_locomotion(CLIP_WALK, patrol_speed)`; `CreatureAnim.play()`'s same-clip
# branch then only retunes the speed, so the statue starts walking **out of the exact pose it was
# standing in**, with no crossfade and no restart. Any other held clip would pop.
#
# ⚠️ `DORMANT_POSE_AT` WAS CHOSEN BY LOOKING, AND THE FIRST GUESS WAS WRONG. The reasoning was
# "a walk cycle's neutral frame is the passing phase, about a quarter in" — which is true of a
# textbook cycle and NOT of this clip. Photographed at 4 m by
# `tests/screenshot_dormant_creature.gd` across six phases of `walk` plus `unsteady` and
# `shamble`: at **0.26 s the creature is plainly mid-stride**, one leg lifted and the torso
# twisted, which reads as *walking on the spot*. At **0.00 s the legs are together and the arms
# hang at the sides** — the most neutral, most statue-like frame in the set. `unsteady` at 1.50 s
# is a good second, but its arms are held out from the body.
#
# ⚠️ AND 0.00 IS ALSO THE RIGHT PLACE TO START WALKING FROM. `activate()` resumes through
# `CreatureAnim.play()`'s same-clip branch, which only retunes the speed — so the creature steps
# off from the frame it was standing on, and frame 0 is the natural head of the cycle.
#
# ⚠️ If the asset is ever re-merged, RE-TAKE THE SHOT. Do not re-derive this number from theory;
# that is exactly what produced 0.26.
const DORMANT_POSE_CLIP := CreatureAnim.CLIP_WALK
const DORMANT_POSE_AT := 0.0

# Fixed rates for the clips that are not travelling anywhere.
const SCAN_RATE := 0.35        # searching in place
const STAGGER_RATE := 0.5      # blinded and reeling

var _search_arrived := false

func _refresh_clip() -> void:
	if _anim == null or not _anim.is_valid():
		return
	if not _active:
		# Dormant during the familiarization window: STANDING STILL. See DORMANT_POSE_AT above
		# for why this is a held frame of `walk` rather than a slow idle, and why it must not be
		# `halt()` (which would drop the skeleton to bind pose — a T-posed statue).
		_anim.hold_pose(DORMANT_POSE_CLIP, DORMANT_POSE_AT)
		return
	match _state:
		State.PATROL:
			_anim.play_locomotion(CreatureAnim.CLIP_WALK, patrol_speed)
		State.INVESTIGATE:
			_anim.play_locomotion(CreatureAnim.CLIP_WALK, investigate_speed)
		State.CHASE:
			var clip := CreatureAnim.CLIP_CHARGE if chase_speed < CHASE_CLIP_SPLIT \
				else CreatureAnim.CLIP_RUN
			_anim.play_locomotion(clip, chase_speed)
		State.SEARCH:
			if _search_arrived:
				_anim.play(CreatureAnim.CLIP_UNSTEADY, SCAN_RATE)
			else:
				_anim.play_locomotion(CreatureAnim.CLIP_WALK, investigate_speed)
		State.STAGGERED:
			_anim.play(CreatureAnim.CLIP_UNSTEADY, STAGGER_RATE)


func _find_mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_mesh_instances(child))
	return out


# ------------------------------------------------------------------ level wiring

# Called once by level_6_breach.gd after RoomBuilder.build() — keeps this script
# graph-agnostic, matching how no existing creature ever reads RoomBuilder directly.
func set_waypoints(points: PackedVector3Array) -> void:
	_waypoints = points
	_wp_index = 0


# The familiarization window is level-owned (see level_6_breach.gd); until this is
# called the creature stays motionless at its spawn point.
func activate() -> void:
	_active = true
	# Out of the dormant sway and into whatever _state says. Without this the creature would
	# patrol the level still playing its standing-idle at half speed.
	_refresh_clip()


func get_state() -> int:
	return _state


func get_shield_ratio() -> float:
	return _shield / SHIELD_MAX


func get_creature_position() -> Vector3:
	return _body.global_position if _body else global_position


# Used by the level's light-weapon raycast so it excludes the creature's own
# collider (otherwise the ray from camera to creature hits the creature itself
# just short of the endpoint and reads as "blocked").
func get_body_rid() -> RID:
	return _body.get_rid() if _body else RID()


# Where the creature is currently headed — used by SlamDoor's path-block scan.
func get_current_target() -> Vector3:
	match _state:
		State.CHASE:
			return _player.global_position if _player else get_creature_position()
		State.INVESTIGATE:
			return _investigate_target
		State.SEARCH:
			return _last_seen_pos
		_:
			return get_creature_position()


# Player sprinting or a slammed door within earshot — escalates PATROL -> INVESTIGATE.
func notify_noise(pos: Vector3, radius: float) -> void:
	if not _active or _state != State.PATROL:
		return
	if get_creature_position().distance_to(pos) > radius:
		return
	_investigate_target = pos
	_investigate_t = 0.0
	_enter(State.INVESTIGATE)


# Called every frame by the level orchestrator while it determines the player is
# aiming a lit flashlight at this creature within FOV+LOS (mirrors _detect_player's
# raycast shape, camera -> creature instead of creature -> camera).
func apply_light_damage(delta: float) -> void:
	if not _active:
		return
	# ⚠️ CHASE only, and the guard is FIRST so the shield isn't drained in states that
	# could never pay out. Previously the drain happened in every state while the
	# stagger could only fire from CHASE/INVESTIGATE, so a player lighting up a
	# patrolling or searching creature emptied the whole pool for no effect, then
	# watched it refill at SHIELD_REGEN_RATE — indistinguishable, from the outside,
	# from a blind that lasted no time at all (BACKLOG #26). Confirmed with the user:
	# you can only blind it while it is actually chasing you.
	if _state != State.CHASE:
		return
	_shield_idle_t = 0.0
	_shield = maxf(0.0, _shield - SHIELD_DRAIN_RATE * delta)
	_update_wound_tint()
	if _shield <= 0.0:
		_enter_stagger()


# A SlamDoor blocking the creature's current path calls this. Movement pauses under
# WHATEVER state is active without changing state — a chased player who breaks LOS
# while the door is being battered should still transition CHASE -> SEARCH the instant
# the door timer ends, not get reset to CHASE blindly.
func force_block(seconds: float) -> void:
	_block_t = maxf(_block_t, seconds)
	# ⚠️ Slowed, never stopped. force_block() is what a slammed door does to it: it is
	# BATTERING the door, not standing still, so the legs keep working at a quarter rate. A
	# hard freeze here would read as the creature having lost interest.
	if _anim:
		_anim.set_speed(0.25)


# PurgeChamber calls this the INSTANT the player seals the blast door — before its
# own confirmation delay, not after. Reuses force_block()'s pause (all ticking,
# including the contact check, stops) with a large sentinel duration.
#
# ⚠️ This one exists because a walk-to-win test caught a real bug: PurgeChamber
# used to wait ~1.2s to confirm the creature was inside, then another ~2.5s for the
# purge sequence, before ever calling lure_into_trap() — CHASE_SPEED (5.0) closes a
# few metres in well under a second, so a player who successfully lured the
# creature in and sealed the door was still getting killed by it before the win
# ever registered. Freezing on interact(), not on confirmation, is what actually
# fixes that: the creature can't hurt you starting the moment you commit to
# sealing it in, regardless of how long the confirm/purge sequence takes.
# ⚠️⚠️ THIS WAS A 9999-SECOND COUNTDOWN AND IT FROZE THE CREATURE FOR 2 h 46 m (fixed 2026-09-07,
# Issue 173, reported as *"I stopped the creature using the flashlight and it did not start moving
# again even after several minutes"*).
#
# `freeze_for_purge()` set `_block_t = _PURGE_FREEZE` (9999.0) and `unfreeze_for_purge()` cleared
# it only `if _block_t >= _PURGE_FREEZE` — while `_process()` DECREMENTED `_block_t` every frame.
# `purge_chamber.gd` freezes the instant the blast door seals and only checks whether the creature
# is actually inside `CLOSE_TO_CONFIRM_DELAY` 1.2 s later, by which time `_block_t` was ~9997.8 and
# the guard was false. **The unfreeze silently did nothing.** Measured by
# `tests/probe_purge_freeze.gd` before the fix:
#
#     _block_t 0.00 -> 9999.00 on the press
#     t+2 s   9996.50   moved 0.00 m
#     t+10 s  9989.00   moved 0.00 m
#     t+30 s  9968.98   moved 0.00 m
#     retry:  9966.36 -> 9999.00     <- and the retry RE-FREEZES it
#
# ⚠️ THE LEVEL'S ONLY WIN CONDITION IS LURING THIS CREATURE INTO THAT CHAMBER, so one failed lure
# made the run unwinnable — while `_reopen_failed()` set `_used = false` and presented the attempt
# as retryable. Every retry deepened the freeze.
#
# ⚠️ THE FIX IS NOT A WIDER COMPARISON. A float sentinel raced against a decrementing counter is
# the defect; a looser `>=` would just move the failure to a longer confirm delay. The freeze is a
# FLAG, it decrements nothing, and the unfreeze is unconditional.
#
# ⚠️ AND IT IS DELIBERATELY NOT `force_block()`. The two look alike and need opposite behaviour:
# a door being battered must NOT stop the creature killing you (that was half of the door-slam
# stunlock), while the purge freeze must — the whole reason it exists is that `CHASE_SPEED` closes
# a few metres in under a second, so a player who sealed the door was still being killed before
# the win registered.
func freeze_for_purge() -> void:
	_purge_frozen = true
	if _anim:
		_anim.set_speed(0.25)


# Called by PurgeChamber if the lure attempt failed (creature wasn't inside) — lets
# it resume the chase instead of staying inexplicably frozen after the door reopens.
func unfreeze_for_purge() -> void:
	if not _purge_frozen:
		return
	_purge_frozen = false
	_refresh_clip()


# Called only by PurgeChamber after its own physics-position confirmation. Permanent.
func lure_into_trap() -> void:
	_active = false
	set_process(false)
	# ⚠️ HALT BEFORE TILTING. The visual is rotated 90 deg onto its face here, and an
	# AnimationPlayer left running would keep driving the legs — a corpse walking on its face
	# through the incinerator floor. `set_process(false)` stops THIS script, not the model's
	# own AnimationPlayer, which ticks itself.
	if _anim:
		_anim.halt()
	if _visual_root:
		_visual_root.rotation.x = deg_to_rad(-90.0)


# ------------------------------------------------------------------ state machine

func _process(delta: float) -> void:
	if not _active:
		return
	if not _ensure_player():
		return

	# ⚠️ THE PURGE FREEZE STOPS EVERYTHING, INCLUDING THE CONTACT CHECK. That is its entire
	# purpose — see `freeze_for_purge()`. It is a flag and it counts nothing down.
	if _purge_frozen:
		return

	if _block_t > 0.0:
		_block_t = maxf(0.0, _block_t - delta)
		if _block_t <= 0.0:
			# The door gave way. Back to the state's own gait and full rate.
			_refresh_clip()
		# ⚠️⚠️ TWO THINGS STILL RUN WHILE A DOOR IS BEING BATTERED, and neither used to
		# (fixed 2026-09-07):
		#
		#   * THE CONTACT CHECK. This early return sat above the whole `match`, so a battering
		#     creature could not kill you at any range — including zero. Combined with a door
		#     the player can re-slam the instant it breaks, that was a free, indefinite
		#     stunlock: stand at a slam door, press E every ~10 s, and Object 12 can never
		#     reach you. ⚠️ It is only fair alongside the proximity gate in
		#     `level_6_breach.gd:_tick_slam_doors()` — with that gate, "battering" and "on top
		#     of you" are the same place. Do not ship one without the other.
		#   * THE STAGGER CLOCK. A staggered creature is not battering anything, and freezing
		#     its recovery behind a door timer silently added 10 s to a beat whose duration the
		#     level ANNOUNCES ("IT RECOILS — 6 SECONDS").
		if _state == State.STAGGERED:
			_tick_staggered(delta)
		elif _state == State.CHASE:
			_check_contact()
		_regen_shield(delta)
		return

	match _state:
		State.PATROL:
			_tick_patrol(delta)
		State.INVESTIGATE:
			_tick_investigate(delta)
		State.CHASE:
			_tick_chase(delta)
		State.SEARCH:
			_tick_search(delta)
		State.STAGGERED:
			_tick_staggered(delta)

	_regen_shield(delta)


func _ensure_player() -> bool:
	if _player and is_instance_valid(_player):
		return true
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not _player:
		return false
	_camera = _player.get_node_or_null("Camera3D") as Camera3D
	return _camera != null


func _enter(new_state: int) -> void:
	var old := _state
	_state = new_state
	# ⚠️ Reset BEFORE _refresh_clip(): SEARCH has two gaits (walking to the last-known position,
	# then scanning in place) and entering SEARCH always starts on the travelling half.
	_search_arrived = false
	_refresh_clip()
	state_changed.emit(old, new_state)


func _tick_patrol(delta: float) -> void:
	if _detect_player():
		_last_seen_pos = _player.global_position
		_enter(State.CHASE)
		return
	_follow_waypoints(delta, patrol_speed)


func _tick_investigate(delta: float) -> void:
	if _detect_player():
		_last_seen_pos = _player.global_position
		_enter(State.CHASE)
		return
	_investigate_t += delta
	if _investigate_t >= INVESTIGATE_GIVEUP_TIME:
		_enter(State.PATROL)
		return
	_move_toward(_investigate_target, investigate_speed, delta)


# Extracted 2026-09-07 so a door-blocked creature can still reach you — see `_process()`.
# Returns true if contact fired, in which case the caller must stop.
func _check_contact() -> bool:
	var here := get_creature_position()
	var flat := Vector2(here.x - _player.global_position.x,
		here.z - _player.global_position.z).length()
	if flat > contact_dist:
		return false
	# ⚠️⚠️ CONTACT NEEDS LINE OF SIGHT, OR IT KILLS THROUGH THE DOOR YOU JUST SLAMMED
	# (2026-09-07, Issue 180). Contact was a pure horizontal distance test, which was harmless
	# while `force_block()` suppressed the whole state dispatch — and became a fairness bug the
	# moment that suppression was lifted to close the door-slam stunlock (Issue 176). Measured
	# by an adversarial pass: player at z = 41.45 and creature at z = 40.90 with a CLOSED,
	# battering slam door between them (blocker spanning 40.95–41.05) — separation 0.550 m,
	# under `contact_dist` 1.0, and it killed. A 0.4 m capsule cannot stand further back than
	# that, so slamming a door in its face was a death sentence rather than the counter-play.
	# ⚠️ The two changes are ONE decision and must not be separated: live contact during a block
	# is what stops the stunlock, and this is what stops live contact reaching through steel.
	# `_has_los()` masks to layer 1, and a shut `SlamDoor`/`PurgeChamber` blocker is on it.
	if not _has_los(here + Vector3(0, CHEST, 0), _camera.global_position):
		return false
	_contact()
	return true


func _tick_chase(delta: float) -> void:
	if _check_contact():
		return
	_move_toward(_player.global_position, chase_speed, delta)
	if _detect_player():
		_last_seen_pos = _player.global_position
		_los_lost_t = 0.0
	else:
		_los_lost_t += delta
		if _los_lost_t >= LOS_LOSS_GRACE:
			_search_t = 0.0
			_enter(State.SEARCH)


func _tick_search(delta: float) -> void:
	if _detect_player():
		_last_seen_pos = _player.global_position
		_enter(State.CHASE)
		return
	var here := get_creature_position()
	var to_target := Vector2(_last_seen_pos.x - here.x, _last_seen_pos.z - here.z)
	if to_target.length() > WAYPOINT_ARRIVE_DIST:
		_move_toward(_last_seen_pos, investigate_speed, delta)
		return
	# Arrived at the last-known position — scan in place for the rest of SEARCH_TIME
	# before giving up. This is the one Mr.X/Alien:Isolation lesson worth keeping:
	# losing the player must not read as a free reset.
	#
	# ⚠️ The gait switches on the EDGE, not every frame: `_refresh_clip()` is cheap but
	# `CreatureAnim.play()` deliberately treats a repeat of the current clip as a speed change
	# rather than a restart, and relying on that here would hide a real bug if it ever changed.
	if not _search_arrived:
		_search_arrived = true
		_refresh_clip()
	_search_t += delta
	_body.rotation.y += deg_to_rad(SEARCH_SCAN_SPEED_DEG) * delta
	if _search_t >= SEARCH_TIME:
		_wp_index = _nearest_waypoint_index()
		_enter(State.PATROL)


func _tick_staggered(delta: float) -> void:
	_stagger_t += delta
	if _stagger_t >= _stagger_len:
		_shield = SHIELD_MAX
		_update_wound_tint()
		if _body_collider:
			_body_collider.disabled = false
		if _visual_root:
			_visual_root.rotation.x = 0.0
		# ⚠️⚠️ A PLACE, NOT ITS OWN FEET (fixed 2026-09-07). This used to be
		# `_last_seen_pos = get_creature_position()`, which guarantees `_tick_search()` measures
		# a zero-length vector, declares itself "arrived" on the first frame, and then ROTATES IN
		# PLACE for the whole of `SEARCH_TIME` 8.0 s before entering PATROL. So the advertised
		# 5-7 s stagger was really **13-15 s of a creature that does not move** — 23-25 s if a
		# slam door also blocked it — against a toast that names the number out loud.
		#
		# ⚠️ The stated intent is kept: it must NOT come straight back at the player standing
		# next to it. A patrol waypoint is a place rather than a person, so SEARCH still
		# re-detects fairly — it just walks somewhere while doing it. **No difficulty constant
		# moved:** `SEARCH_TIME`, `STAGGER_MIN/MAX` and `chase_speed` are untouched.
		_last_seen_pos = _recovery_target()
		_search_t = 0.0
		_enter(State.SEARCH)
		recovered.emit()


func _enter_stagger() -> void:
	_enter(State.STAGGERED)
	_stagger_t = 0.0
	_stagger_len = randf_range(STAGGER_MIN, STAGGER_MAX)
	# ⚠️ Non-solid while staggered (found 2026-07-24 playtest): the capsule (radius 0.3)
	# stops wherever it happened to be walking, which can be dead-center in a doorway
	# (width as low as 1.6-1.8 m). Each side gap then shrinks to ~0.6 m — less than the
	# player's own capsule diameter (radius 0.4 -> 0.8 m) — so a staggered creature could
	# permanently wall off a corridor. contact_fatal is a pure distance check (CONTACT_DIST,
	# see _detect_player/_contact), never physics collision, so disabling this collider
	# only removes the "solid obstacle" side-effect, not the danger.
	if _body_collider:
		_body_collider.disabled = true
	if _visual_root:
		_visual_root.rotation.x = deg_to_rad(-STAGGER_TILT_DEG)
	staggered.emit(_stagger_len)


func _contact() -> void:
	if not _active:
		return
	_active = false
	contact_fatal.emit()
	Screamer.trigger()


func _regen_shield(delta: float) -> void:
	if _state == State.STAGGERED:
		return
	_shield_idle_t += delta
	if _shield_idle_t >= SHIELD_REGEN_DELAY and _shield < SHIELD_MAX:
		_shield = minf(SHIELD_MAX, _shield + SHIELD_REGEN_RATE * delta)
		_update_wound_tint()


# ⚠️⚠️ THE FLOOR AND THE TINT ARE THE CONSTANTS, NOT LITERALS (fixed 2026-09-03, found by a
# play-test probe rather than by any assertion).
#
# This function used to read `lerp(0.35, 0.9, wound)` and `Color(0.4, 0.05, 0.05).lerp(...)` —
# both hand-copied from `_apply_retint()`. When `EMISSION_BASE` dropped 0.35 -> 0.12 for the
# darkness pass, THIS floor did not move with it, and the result was worse than a stale number:
# `_update_wound_tint()` is called from three places (draining, stagger recovery, regen), so
# **the first time the player pointed a torch at Object 12 its resting glow became 0.35 and never
# came back**. Measured live in the Breach: 0.120 as spawned, 0.350 after one call at full
# shield. Silent, permanent, and invisible to every test in the suite.
#
# ⚠️ `WOUND_EMISSION` is 0.5, NOT the old 0.9, and this is a VISUAL call rather than a difficulty
# one. Photographed at four shield levels: at 0.12 the creature is a warm figure with its
# ribcage, crown, claws and muscle striation all reading — the 1024 skin doing its job; at 0.35
# the legs and lower torso are already a solid red mass; **at 0.90 it is a flat, fully saturated
# silhouette with essentially no internal detail.** That is the moment of maximum attention, on
# the asset this whole swap exists to show. 0.12 -> 0.5 is still a **4.2x** swing — a bigger
# proportional change than the old 0.35 -> 0.9 (2.6x) — so the wound reads MORE clearly, not less.
# ⚠️ Nothing about the light weapon's timing, drain rate or stagger moved.
const WOUND_EMISSION := 0.5
const WOUND_TINT := Color(1.0, 0.25, 0.15)

func _update_wound_tint() -> void:
	if not _material:
		return
	var wound: float = 1.0 - (_shield / SHIELD_MAX)
	_material.emission = EMISSION_TINT.lerp(WOUND_TINT, wound)
	_material.emission_energy_multiplier = lerp(EMISSION_BASE, WOUND_EMISSION, wound)


# ------------------------------------------------------------------ movement / detection

func _follow_waypoints(delta: float, speed: float) -> void:
	if _waypoints.is_empty():
		return
	var target: Vector3 = _waypoints[_wp_index]
	_move_toward(target, speed, delta)
	var here := get_creature_position()
	if Vector2(here.x - target.x, here.z - target.z).length() <= WAYPOINT_ARRIVE_DIST:
		_wp_index = (_wp_index + 1) % _waypoints.size()


func _move_toward(raw_target: Vector3, speed: float, delta: float) -> void:
	# ⚠️ ROUTED HERE, so every caller gets it: PATROL's waypoints, INVESTIGATE's noise position,
	# CHASE's player and SEARCH's last-known spot. Arrival is still measured against the CALLER's
	# own target — routing changes the direction of travel, never the destination.
	var target := _steer(raw_target)
	var here := get_creature_position()
	var dir := Vector3(target.x - here.x, 0, target.z - here.z)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	_body.global_position = here + dir * speed * delta
	_body.rotation.y = atan2(dir.x, dir.z)


# Somewhere to walk to after a stagger: the nearest patrol waypoint that is actually far enough
# away to be walked to. If it collapsed ON a waypoint, take the next one round the loop; with no
# waypoints at all (the Matron sets none), fall back to the old behaviour.
func _recovery_target() -> Vector3:
	if _waypoints.is_empty():
		return get_creature_position()
	var here := get_creature_position()
	var i := _nearest_waypoint_index()
	if here.distance_to(_waypoints[i]) <= WAYPOINT_ARRIVE_DIST * 2.0:
		i = (i + 1) % _waypoints.size()
	return _waypoints[i]


# ---------------------------------------------------------------- routing (2026-09-07)
#
# ⭐⭐ IT USED TO WALK THROUGH WALLS, and `probe_breach_creature_path.gd` proved it: a chase into
# WardA crossed the wall at (3.92, 0, 28.75), against **0 crossings in 899 patrol steps**.
# `_move_toward()` assigns `_body.global_position` directly and `_body` is a `StaticBody3D` —
# no sweep, no resolution, no navmesh anywhere in this file.
#
# ⚠️ WHY IT NEVER SHOWED UP. `level_6_breach.gd:PATROL_LOOP` is five room centres that are ALL on
# x = 0, and every spine doorway is on x = 0 too, so patrolling is one 30 m straight line down an
# unobstructed corridor — the mover is never asked a question it could get wrong. That is also the
# real reason both bypass loops are unpatrolled: not an oversight, a constraint.
#
# ⚠️ NOT A NAVMESH AND NOT A*. Thirteen axis-aligned rooms and fourteen known doorways. The level
# already hands this class geometry through `set_waypoints()`; `set_portals()` is the same
# graph-agnostic contract — the creature is told the shape of the world and never reads the level.
#
# ⚠️⚠️ AND IT FALLS BACK. If either end is outside every room, or no path joins them, `_steer()`
# returns the raw target and the creature beelines exactly as it always did. That fallback is what
# makes this safe for the OTHER consumer: `dungeon.gd` runs this same script as the Matron in a
# GENERATED maze, and it is deliberately NOT given portals in this pass — an unfed router must be
# a no-op, not a creature orbiting a wall for ever.
# How far past a doorway to aim. Big enough to carry the body clear of the jamb and flip
# `_room_at()` to the next room; small enough that the detour is invisible.
# ⚠️ How close counts as "standing in the doorway". It must clear `_move_toward()`'s 0.01 m
# bail by a wide margin AND stay inside the opening's half-width (Breach doorways are 1.8 m, so
# 0.9) — at 0.35 the creature is provably within the opening, which is what makes the segment to
# the NEXT hop cross the shared plane inside the hole rather than beside it.
const PORTAL_ARRIVE := 0.35
# ⚠️ Half a wall thickness (`RoomBuilder.T` is 0.2). Connected rooms ABUT, so a point ON the
# shared plane belongs to both; anything further than half a wall is genuinely next door. This
# was 0.6 and that was three times too wide — measured, targets 0.21–0.60 m past the plane were
# treated as same-room and the creature walked at them through the masonry.
const SAME_ROOM_PAD := 0.1
var _rooms: Array = []      # [{c: Vector3, half: Vector2}]
var _portals: Array = []    # [{pos: Vector3, a: int, b: int}]
var _adj: Array = []        # room index -> [portal index]


func set_portals(rooms: Array, doors: Array) -> void:
	_rooms.clear()
	_portals.clear()
	_adj.clear()
	for r in rooms:
		var pos: Vector2 = r["pos"]
		_rooms.append({"c": Vector3(pos.x, 0.0, pos.y), "half": (r["size"] as Vector2) * 0.5})
	for i in range(_rooms.size()):
		_adj.append([])
	for d in doors:
		var dp: Vector2 = d["pos"]
		var wp := Vector3(dp.x, 0.0, dp.y)
		# A doorway sits ON the shared boundary, so both rooms contain it once padded.
		var touching: Array = []
		for i in range(_rooms.size()):
			if _inside(_rooms[i], wp, 0.35):
				touching.append(i)
		if touching.size() < 2:
			continue
		# Exactly two, and if a corner produced more, the two nearest centres are the pair.
		touching.sort_custom(func(x, y):
			return wp.distance_to(_rooms[x]["c"]) < wp.distance_to(_rooms[y]["c"]))
		var pi := _portals.size()
		_portals.append({"pos": wp, "a": int(touching[0]), "b": int(touching[1])})
		_adj[int(touching[0])].append(pi)
		_adj[int(touching[1])].append(pi)


func _inside(room: Dictionary, p: Vector3, pad: float) -> bool:
	var c: Vector3 = room["c"]
	var h: Vector2 = room["half"]
	return absf(p.x - c.x) <= h.x + pad and absf(p.z - c.z) <= h.y + pad


func _room_at(p: Vector3) -> int:
	for i in range(_rooms.size()):
		if _inside(_rooms[i], p, 0.0):
			return i
	return -1


# The point to actually walk at: the next doorway on the way to `target`, or `target` itself when
# it is in this room — or when anything about the query is unanswerable.
func _steer(target: Vector3) -> Vector3:
	if _portals.is_empty():
		return target
	var here := get_creature_position()
	var from := _room_at(here)
	if from < 0:
		return target
	# ⚠️⚠️ IF THE TARGET IS IN MY OWN ROOM, WALK AT IT — and "my own room" is padded, because
	# connected rooms in this project ABUT (they share an exact wall plane), so a target standing
	# ON that plane belongs to both and `_room_at()` returns whichever comes first in the table.
	# Measured consequence of getting this wrong: `walk_level6_breach.gd` puts the player at
	# exactly z = 55.0 to seal the blast door (its collider is only 0.15 m thick, so a pose off the
	# plane cannot be hit by the interact ray) — and the creature, already INSIDE the trap,
	# classified that player as being in the room next door and **walked back out through the
	# doorway to reach them**, so the lure never confirmed and the level could not be won.
	#
	# The pad is HALF a wall thickness — see `SAME_ROOM_PAD`.
	if _inside(_rooms[from], target, SAME_ROOM_PAD):
		return target
	var to := _room_at(target)
	if to < 0 or from == to:
		return target
	# BFS over the doorway graph. Thirteen rooms — an unvisited-set scan is not worth the code.
	var prev_room := {}
	var prev_portal := {}
	var queue: Array = [from]
	prev_room[from] = -1
	var found := false
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to:
			found = true
			break
		for pi in _adj[cur]:
			var pd: Dictionary = _portals[pi]
			var nxt: int = int(pd["b"]) if int(pd["a"]) == cur else int(pd["a"])
			if prev_room.has(nxt):
				continue
			prev_room[nxt] = cur
			prev_portal[nxt] = pi
			queue.append(nxt)
	if not found:
		return target
	# Walk the chain back to the room we are standing in; its portal is the next hop.
	# Walk the chain back into travel order: every doorway between here and the target room.
	var chain: Array = []
	var step: int = to
	while step != from:
		if not prev_portal.has(step):
			return target
		chain.push_front(int(prev_portal[step]))
		step = int(prev_room[step])

	# ⚠️⚠️ AIM AT THE DOORWAY, AND WHEN YOU ARE IN IT, AIM AT THE NEXT ONE. Two earlier versions
	# of this each fixed one half and broke the other, so keep both reasons:
	#
	#   aiming AT the portal and stopping there DEADLOCKS — `_move_toward()` bails once the
	#   target is within 0.01 m and `_room_at()` still reports the room it started in, so it
	#   re-picks the same portal for ever. Measured: `walk_level6_breach.gd` failed with the
	#   creature parked at z = 54.99995 against a trap boundary at 55.0.
	#
	#   aiming 0.8 m PAST the portal un-deadlocks and then walks through the wall BESIDE the
	#   opening, because the steer point is no longer on the boundary and the travel line crosses
	#   the plane wherever it likes. Measured by an adversarial sweep: 98 of 391 traversals still
	#   clipped masonry, worst 2.37 m off the doorway centre.
	#
	# Aiming at the portal CENTRE is what makes the crossing point the hole itself: these rooms
	# are convex axis-aligned boxes, so a segment from any interior point to a point ON the
	# boundary cannot leave the room, and a segment between two boundary points of one convex
	# room stays inside it. The deadlock was never about the aim — it was about arriving and
	# having nowhere else to go. So skip any doorway already reached and aim at the next.
	for pi in chain:
		var pos: Vector3 = _portals[int(pi)]["pos"]
		if Vector2(pos.x - here.x, pos.z - here.z).length() > PORTAL_ARRIVE:
			return pos
	# Every doorway on the route is behind us: the target room is this one. Walk at it.
	return target


func _nearest_waypoint_index() -> int:
	if _waypoints.is_empty():
		return 0
	var here := get_creature_position()
	var best := 0
	var best_dist := INF
	for i in range(_waypoints.size()):
		var d: float = here.distance_to(_waypoints[i])
		if d < best_dist:
			best_dist = d
			best = i
	return best


# The creature as observer: ray from its chest to the player's camera, FOV cone
# centered on the creature's own facing direction. This is the mirror direction of
# every existing gaze check in the codebase (which is always player -> prop).
func _detect_player() -> bool:
	if _player.has_method("is_hidden") and _player.is_hidden():
		return false
	var here := get_creature_position() + Vector3(0, CHEST, 0)
	var target := _camera.global_position
	var to_player := target - here
	if to_player.length() > detect_range:
		return false
	if not _has_los(here, target):
		return false
	# The FOV check compares against the creature's FACING, which is horizontal
	# only (_body.rotation.y). Dotting that against the FULL 3D to-player vector
	# mixes in whatever vertical gap exists between chest height and camera height
	# (CHEST=0.9 vs. the player's ~1.65 eye height) — at close range that vertical
	# component can dominate the vector and fail the dot-product test regardless of
	# facing, making the creature blind to a player standing right next to it (e.g.
	# converged on by a SEARCH scan). Flatten to horizontal for the facing check;
	# height only matters for range/LOS above.
	var flat := Vector2(to_player.x, to_player.z)
	if flat.length() < 0.3:
		return true   # point-blank horizontally — no meaningful facing to check
	var flat_dir := Vector3(flat.x, 0, flat.y).normalized()
	var forward := Vector3(sin(_body.rotation.y), 0, cos(_body.rotation.y))
	return forward.dot(flat_dir) >= FOV_DOT


func _has_los(from: Vector3, to: Vector3) -> bool:
	if not _space:
		_space = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player.get_rid(), _body.get_rid()]
	# Layer 1 only — the default "solid world geometry" layer. SlamDoor/PurgeChamber
	# expose an ALWAYS-enabled interact collider on layer 2 (note.gd's pass-through
	# convention) so E can always find them; without this mask, that collider would
	# block detection through an open doorway, which a real door wouldn't do.
	query.collision_mask = 1
	return _space.intersect_ray(query).is_empty()
