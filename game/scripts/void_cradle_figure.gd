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
# ⚠️ NOT `screamer_void`. Reusing a FATAL sting for a survivable scare teaches that the fatal
# sound is free — the Backrooms crate-shriek lesson. `cradle_sting` is its own file.
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

signal lunged
signal finished

var _phase := 0                   # 0 dip · 1 rise · 2 lunge · 3 spent
var _t := 0.0
var _visual: Node3D = null
var _player: CharacterBody3D = null
var _sting: AudioStreamPlayer3D = null
var _home := Vector3.ZERO
var _from := Vector3.ZERO
var _to := Vector3.ZERO


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


# `at` is the cradle's own world position. `sting` is an emitter owned by the LEVEL, not by this
# node: `cradle_sting` is 0.90 s long and this node is freed at 1.32 s, so a child emitter would
# be cut off mid-scream by its own parent.
func arm(player: CharacterBody3D, at: Vector3, sting: AudioStreamPlayer3D) -> void:
	_player = player
	_sting = sting
	_home = at
	global_position = at + Vector3(0, SINK_Y, 0)
	_visual = _VOID_VISUAL.new() as Node3D
	_visual.name = "CradleFigure"
	add_child(_visual)
	visible = false
	HoldBreath.dip(get_tree(), DIP)


func _process(delta: float) -> void:
	if _phase >= 3:
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
				_phase = 3
				finished.emit()
				queue_free()


# The host owns every animation tick on a `VoidCreatureVisual` — that is the level's rule, and
# it is why a watched stalker is frozen. This one has no watcher, so it always advances.
func _tick_visual(delta: float) -> void:
	if _visual and _visual.has_method("tick_gait"):
		_visual.call("tick_gait", delta, _VOID_VISUAL.Gait.ADVANCING)


func _begin_lunge() -> void:
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
	_to = cam.global_position + fwd * LUNGE_DIST
	_to.y = _player.global_position.y - LUNGE_EYE_DROP if is_instance_valid(_player) else _home.y
	if _visual and _visual.has_method("attack"):
		_visual.call("attack")
	if _sting and is_instance_valid(_sting) and _sting.stream:
		_sting.global_position = _to + Vector3(0, 1.6, 0)
		_sting.play()
	_dbg("VOID cradle figure LUNGED to %.2f m in front of the camera" % LUNGE_DIST)
	lunged.emit()


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


# ── test surface ────────────────────────────────────────────────────────────────
func phase() -> int:
	return _phase


func has_lunged() -> bool:
	return _phase >= 2
