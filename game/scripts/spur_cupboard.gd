extends Node3D
class_name SpurCupboard

# C3 (2026-09-14): the PASS-BY. The third Corridor spur ends in a slatted linen cupboard. Step
# inside and the slat door swings shut behind you; the Manager comes up the spur and walks past
# the slats, slowly. The rule is FAITH's / The Bunker's: HOLD STILL, TORCH OFF. Move, or light the
# torch, and it stops outside the door and stands there (a growl), and the clock resets. Keep
# still for CUPBOARD_HOLD_S of accumulated stillness and it passes, fades, and the latch releases.
# No death, zero panic. CUPBOARD_FALLBACK_S releases you whatever you did.

signal sealed
signal released(reason: String)

const HOLD_S := 8.0
const FALLBACK_S := 45.0
const WALK_SPEED := 0.9
const MOVE_EPS := 0.35

var _door_hinge: Node3D = null
var _door_open_deg: float = 0.0
var _figure: Node = null
var _t_still: float = 0.0
var _t_total: float = 0.0
var _sealed: bool = false
var _released: bool = false
var _paused_figure: bool = false
var _player: CharacterBody3D = null
var _path_from: Vector3 = Vector3.ZERO
var _path_to: Vector3 = Vector3.ZERO
var _figure_tex: String = ""
var _figure_height: float = 2.0


func setup(door_hinge: Node3D, open_deg: float, path_from: Vector3, path_to: Vector3, figure_tex: String, figure_height: float) -> void:
	_door_hinge = door_hinge
	_door_open_deg = open_deg
	_path_from = path_from
	_path_to = path_to
	_figure_tex = figure_tex
	_figure_height = figure_height


func is_sealed() -> bool:
	return _sealed


func is_released() -> bool:
	return _released


func still_time() -> float:
	return _t_still


## The cupboard's Area3D calls this when the player steps in.
func seal() -> void:
	if _sealed:
		return
	_sealed = true
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _door_hinge:
		var tw := create_tween()
		tw.tween_property(_door_hinge, "rotation:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_play("door_slam", _door_hinge.global_position if _door_hinge else global_position, -4.0)
	sealed.emit()
	# the Manager comes up the spur
	_figure = DoorLunger.build(get_parent(), _path_from, _figure_tex, _figure_height)
	_figure.name = "CupboardFigure"
	_figure.walk_to(_path_to, WALK_SPEED)
	_figure.walked.connect(_on_figure_passed)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("CUPBOARD sealed — the pass-by begins")


func _process(delta: float) -> void:
	if not _sealed or _released:
		return
	_t_total += delta
	var still := true
	if _player:
		if _player.has_method("get_horizontal_speed") and float(_player.call("get_horizontal_speed")) > MOVE_EPS:
			still = false
		if _player.has_method("is_flashlight_on") and bool(_player.call("is_flashlight_on")):
			still = false
	if still:
		_t_still += delta
		if _paused_figure and is_instance_valid(_figure):
			_figure.set_walk_paused(false)
			_paused_figure = false
	else:
		_t_still = 0.0
		if not _paused_figure and is_instance_valid(_figure):
			_figure.set_walk_paused(true)
			_paused_figure = true
			_play("cupboard_growl", _figure.global_position + Vector3(0, 1.3, 0), 0.0)
	if _t_still >= HOLD_S:
		_release("held still")
	elif _t_total >= FALLBACK_S:
		_release("fallback")


func _on_figure_passed() -> void:
	if is_instance_valid(_figure):
		var away: Vector3 = _path_to - _path_from
		away.y = 0.0
		_figure.flee_to(_path_to + away.normalized() * 6.0, 2.5, 4.0)
	_figure = null


func _release(reason: String) -> void:
	if _released:
		return
	_released = true
	if is_instance_valid(_figure):
		_figure.set_walk_paused(false)
		var away: Vector3 = _path_to - _path_from
		away.y = 0.0
		_figure.flee_to(_path_to + away.normalized() * 6.0, 3.0, 4.0)
		_figure = null
	_play("latch_release", _door_hinge.global_position if _door_hinge else global_position, 0.0)
	if _door_hinge:
		var tw := create_tween()
		tw.tween_property(_door_hinge, "rotation:y", deg_to_rad(_door_open_deg), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	released.emit(reason)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("CUPBOARD released (%s) after %.1f s" % [reason, _t_total])


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
