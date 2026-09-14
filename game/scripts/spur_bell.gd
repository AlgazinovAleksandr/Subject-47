extends Node3D
class_name SpurBell

# C2 (2026-09-14, the user: "always pressing Space is boring, need something else"). The second
# Corridor spur is a RECEPTION NOOK: a desk and a counter bell at its end. E rings the bell; the
# door across the mouth slams; footsteps start far down the hall and come up the spur behind you,
# and stop a metre from your back. The only decision is where you LOOK:
#   * turn round to face them → they stop dead, the door gives, nothing else;
#   * keep facing the desk (≥ BELL_SERVE_S) → the door gives AND the guest's card is on the desk.
# No mash, no timer bar, zero panic. `SPUR_SHUT_TIME` (the door's batter clock) is the fallback.
# The Convenience Store / The Closing Shift's counter beat (see BACKLOG_Sep_14 appendix).

signal rung
signal served(turned: bool)

const APPROACH_FROM := 22.0     # m down the hall the steps start
const APPROACH_S := 9.0         # s for the whole approach
const STOP_BEHIND := 1.0        # m behind the player's back where they stop
const TURN_DOT := 0.35          # facing the steps this much = "turned round"
const STEP_DB := 2.0
const CARD_TEXT := """HOTEL VESPER — GUEST CARD

Rm 217. Checked in under your name.
Served at the desk by night staff.

The guest did not turn round. Good.
The guest may proceed."""

var _door: Node = null
var _desk_pos: Vector3 = Vector3.ZERO
var _mouth: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.ZERO
var _player: CharacterBody3D = null
var _steps: AudioStreamPlayer3D = null
var _t: float = -1.0
var _done: bool = false
var _rung: bool = false
var _card: Node = null
var _level: Node = null


func setup(level: Node, door: Node, desk_pos: Vector3, mouth: Vector3, dir: Vector3) -> void:
	_level = level
	_door = door
	_desk_pos = desk_pos
	_mouth = mouth
	_dir = dir


func is_rung() -> bool:
	return _rung


func is_done() -> bool:
	return _done


## The bell prop calls this (E).
func ring() -> void:
	if _rung:
		return
	_rung = true
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	rung.emit()
	_play("bell_ding", _desk_pos + Vector3(0, 1.0, 0), 0.0)
	if is_instance_valid(_door):
		for h in _door.get_children():
			if h is Node3D and String(h.name).begins_with("Hinge"):
				(h as Node3D).visible = true
		_door.call("_set_closed", true)
		_door.call("start_battering", null)
		_play("door_slam", _mouth + Vector3(0, 1.2, 0), 2.0)
		if _door.has_signal("broken_open"):
			_door.broken_open.connect(_on_door_gave, CONNECT_ONE_SHOT)
	# the steps: a looping footstep emitter walking up the hall and into the spur
	var s: AudioStream = GameState.load_audio("footstep")
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "BellSteps"
	if s:
		_steps.stream = s
	_steps.unit_size = 10.0
	_steps.max_db = 4.0
	_steps.volume_db = STEP_DB
	_steps.bus = AudioBuses.AMBIENCE
	add_child(_steps)
	_steps.global_position = _mouth - _dir * APPROACH_FROM + Vector3(0, 0.3, 0)
	_steps.finished.connect(_steps.play)
	_steps.play()
	_t = 0.0


func _behind_point() -> Vector3:
	if _player == null:
		return _mouth
	# a metre behind the player's BACK, i.e. toward the mouth
	var to_mouth: Vector3 = _mouth - _player.global_position
	to_mouth.y = 0.0
	return _player.global_position + to_mouth.normalized() * STOP_BEHIND


func _process(delta: float) -> void:
	if _t < 0.0 or _done:
		return
	_t += delta
	var r: float = clampf(_t / APPROACH_S, 0.0, 1.0)
	var from: Vector3 = _mouth - _dir * APPROACH_FROM
	var to: Vector3 = _behind_point()
	if is_instance_valid(_steps):
		_steps.global_position = from.lerp(to, r) + Vector3(0, 0.3, 0)
		# slower cadence as they close in: pitch the loop down a little
		_steps.pitch_scale = lerpf(1.0, 0.82, r)
	# Did the player turn to look at the steps?
	if _player and r > 0.15:
		var cam := _player.get_node_or_null("Camera3D") as Camera3D
		if cam:
			var fwd: Vector3 = -cam.global_transform.basis.z
			fwd.y = 0.0
			var to_steps: Vector3 = _steps.global_position - cam.global_position
			to_steps.y = 0.0
			if fwd.length() > 0.01 and to_steps.length() > 0.01 and fwd.normalized().dot(to_steps.normalized()) > TURN_DOT:
				_finish(true)
				return
	if r >= 1.0:
		_finish(false)


func _finish(turned: bool) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_steps):
		if _steps.finished.is_connected(_steps.play):
			_steps.finished.disconnect(_steps.play)
		_steps.stop()
		_steps.queue_free()
	if not turned:
		_card = _spawn_card()
		_play("latch_release", _desk_pos + Vector3(0, 0.9, 0), -2.0)
	served.emit(turned)
	if is_instance_valid(_door) and _door.has_method("force_open"):
		_door.call("force_open")
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("BELL served — player %s" % ("TURNED (nothing left)" if turned else "held (card on the desk)"))


func _on_door_gave() -> void:
	# the fallback clock ran out before either outcome
	if not _done:
		_finish(true)


# The guest card: a readable page lying flat on the desk.
func _spawn_card() -> Node:
	if _level == null or not _level.has_method("_spawn_wall_page"):
		return null
	var basis := Basis(Vector3.UP, atan2(-_dir.x, -_dir.z)) * Basis(Vector3.RIGHT, -PI / 2.0)
	var xform := Transform3D(basis, _desk_pos + Vector3(0, 0.03, 0))
	var page: Node = _level.call("_spawn_wall_page", "BellCard", xform,
		"res://assets/textures/level_3_corridor/bell_card.png", 0.3, CARD_TEXT)
	return page


func _play(base: String, pos: Vector3, db: float) -> void:
	var s: AudioStream = GameState.load_audio(base)
	if s == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.volume_db = db
	a.unit_size = 8.0
	a.bus = AudioBuses.AMBIENCE
	add_child(a)
	a.global_position = pos
	a.finished.connect(a.queue_free)
	a.play()
