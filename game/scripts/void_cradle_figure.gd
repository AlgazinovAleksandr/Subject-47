extends Node3D

# ⭐ THE CRADLE GIVES (2026-09-20 pass 4). The 18:30 playtester stood at (-17.5, 0, 34.6) for
# 62 seconds after setting the shard and wrote: *"I put the object here but the visuals and the
# effects were too weak. We need to make something more epic... Maybe a jumpscare should appear
# in the middle of this texture. A loud 3d jumpscare appears suddenly and maybe some additional
# door opens."* What the cradle paid before was a 1.1 s slat tween and a stone plate retracting
# two rooms away, where nobody could see it.
#
# This is Visage / Layers of Fear's **scare that GIVES**: a survivable hit whose last frame
# leaves a passage that did not exist. A SIXTH fractured figure — no AI, no collider, no
# `ScaryObject`, no rule of any kind — rises through the cradle and lunges into the camera, and
# the wall of the Morgue opens (level_3.gd's `_open_secret_door()`).
#
# ⚠️ ZERO PANIC, and that is the user's ruling, not a default. `DreadFarWing` covers this room
# and cancels decay, so anything charged here would be permanent — SCARY.md §8.11's
# unavoidable-event rule with the bar as the coin flip. Nothing in this file touches `_panic`.
# ⚠️ NOT `Screamer.flash_scare()`. That is a fullscreen 2D image; the ask was for a thing in the
# room. The two are never used together.
# ⚠️ ⭐ THE SOUND IS THE SHARED `jumpscare` SINCE 2026-09-20 pass 5, and that IS the user's
# ruling ("*also use the sound of the shared jumpscares*", capture #5) — not a lapse of the rule
# below. `screamer_void` is the Void's FATAL sting and is still never borrowed: reusing a death
# sound for a survivable scare teaches that death is free (the Backrooms crate-shriek lesson).
# `jumpscare` is the shared surprise, not a death, and it is what the player has been taught a
# thing-in-your-face sounds like. `cradle_sting.wav` stays on disk, unplayed.
#
# ⭐ AND THE SAME FIGURE CHARGES THE LOOP CORRIDOR (2026-09-20 pass 5). `arm_charge()` is the
# second beat this file owns: the return leg down the 30 m corridor, one figure at the far end
# with its back turned, a 0.25 s turn and a 1.0 s rush that stops at arm's length and is gone.
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

# The beat, in seconds. Silence first (F.E.A.R.'s thesis; this level's longest telegraph before
# it was the loop's 0.0 s), then the rise, then the lunge.
const DIP := 0.6
const RISE_TIME := 0.25
const LUNGE_TIME := 0.35
const SINK_Y := -1.0              # how far under the cradle it starts
const LUNGE_DIST := 0.6           # metres in front of the camera it ends
const LUNGE_EYE_DROP := 0.40      # so the 2.05 m mask lands on the 1.65 m eye line
const LINGER := 0.12              # it is gone this long after the lunge peaks
# ⭐ THE CORRIDOR CHARGE (2026-09-20 pass 5) — the same rule-less figure, a different beat.
# Capture #4: *"we inevitably need to run back in this corridor… add some scary thing in the
# corridor when we go back — like a sudden jumpscare with 3d animation."* It stands 25 m down
# the loop corridor with its back to you, turns, and covers the whole corridor in one second.
# Visage's hallway charge, and Visage's rule with it: it never touches you and never costs
# anything. ⚠️ ZERO PANIC, no collider, no `ScaryObject`, one-shot, and it is NOT a pursuer —
# SCARY.md §8.4 allows ONE chase level in twelve and this level is not it.
const TURN_TIME := 0.25           # it notices you
const CHARGE_TIME := 1.0          # …and then it is on you
const CHARGE_DIST := 0.6          # metres in front of the camera it stops, like the lunge

signal lunged
signal finished

# Phases. 0 dip · 1 rise · 2 lunge · 3 spent are the cradle's; 5 turn · 6 rush are the
# corridor charge's. `_spent` retires both — the numbers are labels, not an order.
var _phase := 0
var _spent := false
var _struck := false
var _charge := false
var _t := 0.0
var _visual: Node3D = null
var _player: CharacterBody3D = null
var _sting: AudioStreamPlayer3D = null
var _home := Vector3.ZERO
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _turn_from := 0.0
var _turn_to := 0.0


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


# `source` is the CRADLE ITSELF, and the figure rises from the centre of its geometry.
# ⭐ THE ASSEMBLY'S BOUNDING BOX, NOT THE NODE ORIGIN (2026-09-20 pass 5). Capture #5: *"Make
# this 3d jumpscare look more centralised to the middle of this object."* `Cradle_ChildRoom`'s
# origin is on the FLOOR (every `_body()` prop in this level is authored that way), so the
# figure rose from the player's feet in front of the cradle rather than out of the cradle. The
# bbox over its MeshInstance3D children puts the start ~1 m up, inside the slats.
# `sting` is an emitter owned by the LEVEL, not by this node: the sting is ~1 s long and this
# node is freed at 1.32 s, so a child emitter would be cut off mid-scream by its own parent.
func arm(player: CharacterBody3D, source: Node3D, sting: AudioStreamPlayer3D) -> void:
	_player = player
	_sting = sting
	_home = _bbox_centre(source)
	global_position = _home + Vector3(0, SINK_Y, 0)
	_visual = _VOID_VISUAL.new() as Node3D
	_visual.name = "CradleFigure"
	add_child(_visual)
	visible = false
	HoldBreath.dip(get_tree(), DIP)


# The centre of everything the prop actually DRAWS, in world space. ⚠️ Meshes, not colliders:
# a prop's collider is its honest footprint and often only part of it (the inverted slab's is
# three boxes; the cradle's is one 1.35 x 1.65 x 1.45 block from the floor up). Falls back to
# the node's own origin so a prop with no meshes can never put the figure at (0, 0, 0).
func _bbox_centre(source: Node3D) -> Vector3:
	if source == null or not is_instance_valid(source):
		return Vector3.ZERO
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
	return (box.position + box.size * 0.5) if found else source.global_position


# ⭐ THE CORRIDOR CHARGE. `at` is where it stands — 25 m down the loop corridor, under the lamp
# the ladder killed, with its back to the player. No dip and no HoldBreath: the corridor's own
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
	_face_player()
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
		0:
			if _t >= DIP:
				_t = 0.0
				_phase = 1
				visible = true
				_face_player()
		1:
			var k: float = clampf(_t / RISE_TIME, 0.0, 1.0)
			global_position = _home + Vector3(0, SINK_Y * (1.0 - k), 0)
			_tick_visual(delta)
			if k >= 1.0:
				_t = 0.0
				_phase = 2
				_begin_lunge()
		2:
			var k2: float = clampf(_t / LUNGE_TIME, 0.0, 1.0)
			# Ease IN: it is slow for the first third and then it is on you.
			global_position = _from.lerp(_to, k2 * k2)
			_face_player()
			_tick_visual(delta)
			if _t >= LUNGE_TIME + LINGER:
				_retire()
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


func _retire() -> void:
	_spent = true
	_phase = 3
	finished.emit()
	queue_free()


# The host owns every animation tick on a `VoidCreatureVisual` — that is the level's rule, and
# it is why a watched stalker is frozen. This one has no watcher, so it always advances.
func _tick_visual(delta: float) -> void:
	if _visual and _visual.has_method("tick_gait"):
		_visual.call("tick_gait", delta, _VOID_VISUAL.Gait.ADVANCING)


func _begin_lunge() -> void:
	_strike(LUNGE_DIST)
	_dbg("VOID cradle figure LUNGED to %.2f m in front of the camera" % LUNGE_DIST)
	lunged.emit()


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
	_strike(CHARGE_DIST if _charge else LUNGE_DIST)
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
