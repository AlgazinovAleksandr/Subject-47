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
const SCRAWL := "DON'T MOVE.\nDON'T BREATHE."
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
# C7 (2026-09-16): the closet door's threshold — the strip of light under the door and the
# shadow that crosses it as the Manager passes. Set by `set_threshold()`.
var _threshold: Vector3 = Vector3.ZERO
var _thr_dir: Vector3 = Vector3.ZERO
var _thr_lat: Vector3 = Vector3.ZERO
var _shadow_done: bool = false
const SHADOW_AT_M := 1.6


func set_threshold(pos: Vector3, dir3: Vector3, lat3: Vector3) -> void:
	_threshold = pos
	_thr_dir = dir3
	_thr_lat = lat3


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
	if _door_hinge and _door_hinge.has_method("slam"):
		_door_hinge.call("slam")            # C7: a real AjarDoor leaf
	elif _door_hinge:
		var tw := create_tween()
		tw.tween_property(_door_hinge, "rotation:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_play("door_slam", _door_hinge.global_position if _door_hinge else global_position, -4.0)
	# C3 (2026-09-15, the user shut in with the torch ON for 88 s: "how do I get away?"). The
	# seal TAKES the torch (force/restore pair — Issue 212's lesson) and SAYS the rule.
	if _player and _player.has_method("force_flashlight_off"):
		_player.call("force_flashlight_off")
	ScreenText.scrawl(get_tree(), SCRAWL, 3.5, 46)
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
	# C7: as he reaches the door his shadow crosses the strip of light under it
	if not _shadow_done and is_instance_valid(_figure) and _thr_dir != Vector3.ZERO:
		var fp: Vector3 = (_figure as Node3D).global_position
		if Vector2(fp.x - _threshold.x, fp.z - _threshold.z).length() <= SHADOW_AT_M:
			_shadow_done = true
			_shadow_cross()
	if _t_still >= HOLD_S:
		_release("held still")
	elif _t_total >= FALLBACK_S:
		_release("fallback")


# A black quad standing just inside the door at the sill, tweened across the strip's width
# in 1.4 s, then freed (corridor.gd's `_spur_shadow_cross` idiom). No sound of its own — the
# footsteps and the growl are the Manager's.
func _shadow_cross() -> void:
	var sh := MeshInstance3D.new()
	sh.name = "ClosetShadow"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.26)
	sh.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	sh.set_surface_override_material(0, m)
	var basis := Basis(Vector3.UP, atan2(_thr_dir.x, _thr_dir.z))
	var from := _threshold + _thr_dir * 0.03 + _thr_lat * 0.9 + Vector3(0, 0.08, 0)
	var to := _threshold + _thr_dir * 0.03 - _thr_lat * 0.9 + Vector3(0, 0.08, 0)
	sh.transform = Transform3D(basis, from)
	get_parent().add_child(sh)
	var tw := create_tween()
	tw.tween_property(sh, "position", to, 1.4).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(sh.queue_free)


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
	if _player and _player.has_method("restore_flashlight"):
		_player.call("restore_flashlight")
	if _door_hinge and _door_hinge.has_method("swing_ajar"):
		_door_hinge.call("swing_ajar", _door_open_deg, 0.6, 170.0)   # C7: the leaf swings back open
	elif _door_hinge:
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
