extends Node3D

# ⭐ THE CRADLE GIVES (2026-09-20 pass 4). The 18:30 playtester stood at (-17.5, 0, 34.6) for
# 62 seconds after setting the shard and wrote: *"I put the object here but the visuals and the
# effects were too weak. We need to make something more epic."* What the cradle paid before was a
# 1.1 s slat tween and a stone plate retracting two rooms away, where nobody could see it.
#
# This is Visage / Layers of Fear's **scare that GIVES**: a survivable hit whose last frame
# leaves a passage that did not exist. A SIXTH fractured figure — no AI, no collider, no
# `ScaryObject`, no rule of any kind — appears in the cradle, and the wall of the Morgue opens
# (level_3.gd's `_open_secret_door()`).
#
# ⭐ ⚠️ WHAT THE CRADLE DOES CHANGED ON 2026-09-22 (pass 7), AND THE REASON IS SAMENESS, NOT
# STRENGTH. Passes 4-5 had the figure rise through the slats and RUSH to 0.6 m with the shared
# `jumpscare` — the same figure, the same rush and the same sound as the corridor charge forty
# metres away, which is exactly what the 02:13 playtester photographed: *"The jumpscare is the
# same as the one in the corridor … a shadow will spawn inside this object for several seconds
# while all the light will be removed and in the complete darkness you will see only it and it
# will be a creepy sound."* So the cradle's beat is now `arm_shadow()`: it does not rush, it makes
# no sound of its own, and the level puts every light in the room out for it. The CORRIDOR keeps
# the rush. Two beats that were one beat are now two.
# ⭐ PASS 8 (2026-09-23) GAVE IT ONE MOVEMENT AND ONLY ONE: it RISES 0.80 m over 0.5 s, up out of
# the fire the level lights in the cradle, and stops at the pose pass 7 specified. That is not a
# rush — it ends 2 m away, at the rim, standing still — and it is what capture #3 asked for.
#
# ⚠️ ZERO PANIC, and that is the user's ruling, not a default. `DreadFarWing` covers this room
# and cancels decay, so anything charged here would be permanent — SCARY.md §8.11's
# unavoidable-event rule with the bar as the coin flip. Nothing in this file touches `_panic`.
# ⚠️ NOT `Screamer.flash_scare()`. That is a fullscreen 2D image; the ask was for a thing in the
# room. The two are never used together.
# ⚠️ ⭐ THE CORRIDOR'S SOUND IS THE SHARED `jumpscare` (2026-09-20 pass 5, the user's ruling:
# "*also use the sound of the shared jumpscares*"). `screamer_void` is the Void's FATAL sting and
# is still never borrowed: reusing a death sound for a survivable scare teaches that death is
# free (the Backrooms crate-shriek lesson). The CRADLE's is `apparition_snarl`, chosen in pass 7
# for the same reason the staging changed. `cradle_sting.wav` stays on disk, unplayed.
#
# ⭐ AND THE SAME FIGURE CHARGES THE LOOP CORRIDOR (2026-09-20 pass 5). `arm_charge()` is the
# second beat this file owns: the return leg down the 30 m corridor, one figure standing ahead of
# you with its back turned, a 0.25 s turn and a 0.6 s rush that stops at arm's length and is gone.
# Since pass 7 the LEVEL turns the player's camera onto it over the same 0.25 s (Issue 255), so
# the rush starts in view instead of behind your head.
# Same guarantees, in the same file, because they are the same photograph: no collider, no
# `ScaryObject`, no AI, no panic, one shot, never replayed by a restore.
# ⚠️ THE STING IS ON **Master**, not on `AudioBuses.AMBIENCE` like every other one-shot in this
# level, and that is load-bearing: `HoldBreath.dip()` ducks Ambience to -30 dB and then takes
# 0.4 s to fade it back. A sting on Ambience would land inside its own silence, at a fraction of
# the level it was measured for. Screamer.gd routes its sting the same way for the same reason.
# ⚠️ NO COLLIDER AND NO ScaryObject: `check_void_frames.gd` walks this subtree and asserts both,
# because the one thing a rule-less photograph must never become is a sixth creature (SCARY.md
# §8.3 — one chase level in twelve, and the Void already has five stalkers).

const _VOID_VISUAL := preload("res://scripts/void_creature_visual.gd")

# ⚠️ THE CRADLE'S RISE-AND-LUNGE IS RETIRED (2026-09-22 pass 7) and its constants are gone with
# it: `DIP` 0.6, `RISE_TIME` 0.25, `LUNGE_TIME` 0.35, `SINK_Y` -1.0 and `LUNGE_DIST` 0.6 had no
# remaining caller once `level_3.gd:_fire_cradle_shadow()` replaced `_fire_cradle_lunge()`, and a
# dead constant beside a live one is how a later pass re-prices the wrong beat. What the cradle
# does now is `arm_shadow()`, below. The CORRIDOR keeps its rush — the complaint capture 2 made
# was that the two were the same, not that either was wrong.
const LUNGE_EYE_DROP := 0.40      # so the 2.05 m mask lands on the 1.65 m eye line
const LINGER := 0.12              # it is gone this long after the rush peaks
# ⭐ THE CORRIDOR CHARGE (2026-09-20 pass 5) — the same rule-less figure, a different beat.
# Capture #4: *"we inevitably need to run back in this corridor… add some scary thing in the
# corridor when we go back — like a sudden jumpscare with 3d animation."* It stands down the
# loop corridor with its back to you, turns, and covers the ground between you in 0.6 s.
# Visage's hallway charge, and Visage's rule with it: it never touches you and never costs
# anything. ⚠️ ZERO PANIC, no collider, no `ScaryObject`, one-shot, and it is NOT a pursuer —
# SCARY.md §8.4 allows ONE chase level in twelve and this level is not it.
# ⚠️ CHARGE_TIME IS THE **CHARGE'S** CLOCK, NOT THE CRADLE'S. `LUNGE_TIME` (0.35 s) above is the
# cradle lunge's and is untouched by this; the two beats share a file and nothing else.
# ⭐ 1.0 -> 0.6 s ON 2026-09-22 (pass 6), together with the trigger moving from z 42 to z 26.
# Capture #3 of the 23:47 run: *"The jumpscare … appears too early. Let it be when around 60 % of
# the corridor is passed"*. It fired at z 43.2 — the corridor's north END — and then took a full
# second to cover 24.4 m, which reads as a cutscene you are watching rather than a thing arriving.
# From z 26 (60 % of the way back down z 44 -> 14) the run is ~9.5 m, and 0.6 s of it is the same
# closing speed with a quarter of the run-up.
const TURN_TIME := 0.25           # it notices you
const CHARGE_TIME := 0.6          # …and then it is on you
const CHARGE_DIST := 0.6          # metres in front of the camera it stops, like the lunge

signal lunged
signal finished

# Phases. 0 dip · 1 rise · 2 lunge · 3 spent were the cradle LUNGE's (retired in pass 7 and kept
# only because `snap_to_strike()` and the charge share the code); 5 turn · 6 rush are the corridor
# charge's; 10 is the cradle shadow COMING UP THROUGH THE FIRE (pass 8) and 9 is the same figure
# once it has arrived, which does nothing at all but track you. `_spent` retires all of them —
# the numbers are labels, not an order, and 10 running before 9 is the proof of that.
var _phase := 0
var _spent := false
var _struck := false
var _charge := false
var _shadow := false
var _t := 0.0
var _visual: Node3D = null
var _player: CharacterBody3D = null
var _sting: AudioStreamPlayer3D = null
var _home := Vector3.ZERO
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _turn_from := 0.0
var _turn_to := 0.0
var _rise_from := 0.0
var _rise_time := 0.0


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


# The centre of everything the prop actually DRAWS, in world space. ⚠️ Meshes, not colliders:
# a prop's collider is its honest footprint and often only part of it (the inverted slab's is
# three boxes; the cradle's is one 1.35 x 1.65 x 1.45 block from the floor up). Falls back to
# the node's own origin so a prop with no meshes can never put the figure at (0, 0, 0).
func _bbox_centre(source: Node3D) -> Vector3:
	var b := _bbox(source)
	return b.position + b.size * 0.5


func _bbox(source: Node3D) -> AABB:
	if source == null or not is_instance_valid(source):
		return AABB()
	var box := AABB()
	var found := false
	var stack: Array = [source]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var world: AABB = mi.global_transform * mi.get_aabb()
			box = world if not found else box.merge(world)
			found = true
		for c in n.get_children():
			stack.append(c)
	return box if found else AABB(source.global_position, Vector3.ZERO)


# ⭐ THE CRADLE'S SHADOW (2026-09-22 pass 7) — the third beat this file owns, and the only one
# that never moves. The 02:13 playtester's capture 2 asked for it in these words: *"a shadow will
# spawn inside this object for several seconds while all the light will be removed and in the
# complete darkness you will see only it."* So: no dip, no rise, no lunge, no `HoldBreath` — the
# LEVEL owns the blackout, the light and the clock (`level_3.gd:_run_cradle_shadow()`), and this
# node's whole job is to stand in the cradle and track you with its head.
#
# ⚠️ CROUCHED IS A PLACEMENT, NOT A POSE. `VoidCreatureVisual` has no crouch — it is a 2.2 m
# standing figure whose mask hangs at local y ~2.12 (`Head` at 2.10 plus the mask pivot's 0.02).
# Sinking its origin to `rim - MASK_Y` puts the MASK exactly at the cradle's rim and everything
# below it inside the slats or under the floor, which is the image: a face at the lip of a crib
# with no body you can account for. Measured against the cradle's own mesh bounding box (top
# y 1.768), never a hand-typed height — the prop has been re-posed twice already.
# ⚠️ THE HEAD STILL TRACKS. `tick_gait(delta, DORMANT)` runs `_track_head()` + `_apply_head_yaw()`
# and returns before the stride, so it turns to look at you without ever taking a step. That is
# the level's whole grammar and `check_stalker_motion` is unaffected (this figure has no watcher).
# ⚠️ Same guarantees as the other two: no collider, no `ScaryObject`, no AI, no rule, no panic,
# one shot, never replayed by a restore. `check_void_frames.gd` walks the subtree.
const MASK_Y := 2.12

# ⭐ AND SINCE 2026-09-23 (pass 8) IT RISES THROUGH THE FIRE. Capture #3 of the 23:10 run asked
# for it in these words: *"maybe add animation like there is fire for like 3 seconds and then
# this face appears from fire?"* The end state is pass 7's exactly — mask at the rim, head
# tracking — but it gets there over `rise_time`, starting `rise_from` metres lower, which puts
# the mask down among the flames on the cradle's broken bed and brings it up out of them.
# ⚠️ EASE OUT, not linear and not ease in: a face that accelerates out of a fire reads as a
# lunge (the beat pass 7 deliberately retired). This one surfaces and stops.
# ⚠️ Phase 10, and `_process` must not treat phase numbers as an ORDER — see its own warning.
const RISE_EASE := 2.0


func arm_shadow(player: CharacterBody3D, source: Node3D,
		rise_from: float = 0.0, rise_time: float = 0.0) -> void:
	_player = player
	_shadow = true
	var box := _bbox(source)
	var centre: Vector3 = box.position + box.size * 0.5
	var rim: float = box.position.y + box.size.y
	_home = Vector3(centre.x, rim - MASK_Y, centre.z)
	_rise_from = maxf(rise_from, 0.0)
	_rise_time = maxf(rise_time, 0.0)
	global_position = _home - Vector3(0, _rise_from, 0)
	_visual = _VOID_VISUAL.new() as Node3D
	_visual.name = "CradleShadow"
	add_child(_visual)
	visible = true
	_face_player()
	_phase = 10 if (_rise_from > 0.0 and _rise_time > 0.0) else 9
	_t = 0.0
	_dbg("VOID cradle shadow SHOWN at %v, rising %.2f m over %.2f s to the rim (y %.3f)"
		% [global_position, _rise_from, _rise_time, rim])


# Where the rise has got to, 0..1 — the level's guard reads this rather than a clock.
func rise_progress() -> float:
	if _rise_from <= 0.0:
		return 1.0
	return clampf(1.0 - (_home.y - global_position.y) / _rise_from, 0.0, 1.0)


# The level takes it away again; nothing here decides when.
func dismiss() -> void:
	if _spent:
		return
	_dbg("VOID cradle shadow GONE")
	_retire()


# ⭐ THE CORRIDOR CHARGE. `at` is where it stands — at z 16.5, under the lamp the ladder killed,
# with its back to the player; since pass 6 the trigger is at z 26, so that is ~9.5 m ahead. No dip and no HoldBreath: the corridor's own
# ambience is the silence, and the beat is over in 1.25 s.
func arm_charge(player: CharacterBody3D, at: Vector3, sting: AudioStreamPlayer3D) -> void:
	_player = player
	_sting = sting
	_home = at
	global_position = at
	_visual = _VOID_VISUAL.new() as Node3D
	_visual.name = "ChargeFigure"
	add_child(_visual)
	visible = true
	_charge = true
	# ⚠️ FACING THE PLAYER'S POSITION, NOT BACK DOWN THE CAMERA'S AXIS (2026-09-22 pass 7).
	# `_face_player()` turns the figure along the camera's own forward vector, which is correct
	# once the camera is pointed at it and WRONG at the moment this is armed: since pass 7 the
	# level fires this beat while the player may be walking backwards, and taking the yaw from a
	# camera that is looking the other way stood the figure facing 180 degrees off for the whole
	# turn. The player's position cannot be facing the wrong way.
	_face_point(player.global_position if is_instance_valid(player) else at)
	_turn_to = rotation.y
	# Facing AWAY to start with: the turn is the tell, and it is the only one.
	_turn_from = _turn_to + PI
	rotation.y = _turn_from
	_phase = 5
	_t = 0.0
	_dbg("VOID charge figure STANDING at %v, facing away" % at)


func _process(delta: float) -> void:
	# ⚠️ `_spent`, NOT `_phase >= 3`. The charge's phases are 5 and 6, which are numerically
	# greater than the cradle's spent marker — the first draft of the charge stood frozen in the
	# corridor forever for exactly that reason. A retirement test must not be an ordering test.
	if _spent:
		return
	_t += delta
	match _phase:
		5:
			var kt: float = clampf(_t / TURN_TIME, 0.0, 1.0)
			rotation.y = lerp_angle(_turn_from, _turn_to, kt)
			_tick_visual(delta)
			if kt >= 1.0:
				_t = 0.0
				_phase = 6
				_begin_charge()
		6:
			var k3: float = clampf(_t / CHARGE_TIME, 0.0, 1.0)
			# Ease IN again: it is a long way off and then it is not.
			global_position = _from.lerp(_to, k3 * k3)
			_face_player()
			_tick_visual(delta)
			if _t >= CHARGE_TIME + LINGER:
				_retire()
		9:
			# The shadow in the cradle. It never moves and it never retires itself — only the
			# head turns, and only the level says when it is over.
			_tick_visual(delta)
		10:
			# ⭐ pass 8: coming up through the flames, and then it is phase 9 forever.
			var rk: float = clampf(_t / maxf(_rise_time, 0.0001), 0.0, 1.0)
			var eased: float = 1.0 - pow(1.0 - rk, RISE_EASE)
			global_position = Vector3(_home.x, _home.y - _rise_from * (1.0 - eased), _home.z)
			_face_player()
			_tick_visual(delta)
			if rk >= 1.0:
				global_position = _home
				_phase = 9
				_t = 0.0


func _retire() -> void:
	_spent = true
	_phase = 3
	finished.emit()
	queue_free()


# The host owns every animation tick on a `VoidCreatureVisual` — that is the level's rule, and
# it is why a watched stalker is frozen. This one has no watcher, so it always advances.
# ⚠️ THE SHADOW TICKS `DORMANT`, NOT `ADVANCING`, and the difference is the whole beat:
# `tick_gait()` runs `_track_head()` for both, but only `ADVANCING` advances `_phase` into the
# stride. A crouched thing in a crib that was walking on the spot would be a different scare.
func _tick_visual(delta: float) -> void:
	if _visual and _visual.has_method("tick_gait"):
		_visual.call("tick_gait", delta,
			_VOID_VISUAL.Gait.DORMANT if _shadow else _VOID_VISUAL.Gait.ADVANCING)


func _begin_charge() -> void:
	_strike(CHARGE_DIST)
	_dbg("VOID charge figure RUSHING %.1f m to %.2f m in front of the camera"
		% [_from.distance_to(_to), CHARGE_DIST])
	lunged.emit()


# Aim at a point `dist` metres in front of the camera, at eye height, and start the sound there.
# ⚠️ The sting is positioned at the DESTINATION, not at the figure: it is the arrival that is
# loud, and at 0.6 m the distance gain clamps anyway.
func _strike(dist: float) -> void:
	_struck = true
	_from = global_position
	_to = _from
	var cam := _camera()
	if cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	_to = cam.global_position + fwd * dist
	_to.y = _player.global_position.y - LUNGE_EYE_DROP if is_instance_valid(_player) else _home.y
	if _visual and _visual.has_method("attack"):
		_visual.call("attack")
	if _sting and is_instance_valid(_sting) and _sting.stream:
		_sting.global_position = _to + Vector3(0, 1.6, 0)
		_sting.play()


func _face_player() -> void:
	var cam := _camera()
	if cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	# VoidCreatureVisual's forward is +Z; this turns it back down the camera's own axis, the
	# same expression void_stare_director.gd uses for its one-frame watcher.
	rotation.y = atan2(-fwd.x, -fwd.z)


# …and the same thing done from a POINT rather than from the camera's heading, for the one
# moment the camera is not yet pointed at us.
func _face_point(at: Vector3) -> void:
	var to := at - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	to = to.normalized()
	rotation.y = atan2(to.x, to.z)


func _camera() -> Camera3D:
	if not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("Camera3D") as Camera3D


# ⚠️ SCREENSHOT / TEST HOOK, the pattern `void_exit_door.gd:snap_assembled()` set: a beat is a
# RACE with a capture, and the frame this has to be judged on is the last one. It drives the
# same `_strike()` the beat drives — nothing is faked — and then FREEZES the node, because a
# figure that retires 0.12 s later is a photograph of an empty room.
func snap_to_strike() -> void:
	if _visual == null:
		return
	visible = true
	_strike(CHARGE_DIST)
	global_position = _to
	_face_player()
	_tick_visual(0.016)
	_spent = true


# ── test surface ────────────────────────────────────────────────────────────────
func phase() -> int:
	return _phase


func has_lunged() -> bool:
	return _struck


func home() -> Vector3:
	return _home
