extends SceneTree

# K4 (2026-09-13, capture #013): the Blackout figure appears WHERE THE CAMERA POINTS when the
# torch goes off, at BLACKOUT_FIG_AHEAD, whatever way the player happens to be facing — or, if
# no in-frame spot is clear, the camera is brought to it. Run headless.
#   Godot --headless --path game --script res://tests/check_kontur_figure_frame.gd

const Scenes = preload("res://tests/lib/scenes.gd")

var _t := 0.0
var _k: Node = null
var _p: Node = null
var _phase := 0
var _checks := 0
var _fails := 0
var _poses: Array = [
	# [eye, look-at]: facing the seams, facing the east wall, facing back at the doorway
	[Vector3(0.0, 0.1, 52.4), Vector3(0.0, 1.6, 59.0)],
	[Vector3(-1.5, 0.1, 53.0), Vector3(3.5, 1.6, 53.0)],
	[Vector3(1.0, 0.1, 55.0), Vector3(1.0, 1.6, 51.0)],
]
var _i := 0


func _initialize() -> void:
	Scenes.pin_rng(7)
	change_scene_to_file("res://scenes/kontur.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	if not cond:
		_fails += 1
	print("  %s  %s%s" % ["PASS" if cond else "FAIL", label, ("   " + detail) if detail != "" else ""])


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	_t += delta
	match _phase:
		0:
			if _t < 1.5:
				return false
			_k = current_scene
			_p = _k.get_node("Player")
			_p.set("ai_active", true)
			_phase = 1
			_t = 0.0
		1:
			if _i >= _poses.size():
				print("%d checks, %d failed" % [_checks, _fails])
				print("FIGURE-FRAME PASS" if _fails == 0 else "FIGURE-FRAME FAIL")
				quit(1 if _fails > 0 else 0)
				return true
			# reset the one-shot, pose, torch ON first (so the reveal is a fresh torch-off)
			_k.set("_blackout_fig_stung", false)
			_k.set("_blackout_fig_stung_played", false)
			_p.set("velocity", Vector3.ZERO)
			_p.global_position = _poses[_i][0]
			_p.call("ai_look_at", _poses[_i][1])
			if _p.has_method("restore_flashlight"):
				_p.call("restore_flashlight")
			_phase = 2
			_t = 0.0
		2:
			if _t < 0.3:
				return false
			_p.call("force_flashlight_off")
			_phase = 3
			_t = 0.0
		3:
			if _t < 0.6:
				return false
			var fig := _k.get("_blackout_fig") as Node3D
			var cam := _p.get_node("Camera3D") as Camera3D
			var visible: bool = fig != null and fig.visible
			var in_frame: bool = fig != null and cam.is_position_in_frustum(fig.global_position)
			var dist: float = fig.global_position.distance_to(_p.global_position) if fig else 99.0
			var dark_x: float = float(_k.get("_dark_x"))
			_ok("pose %d: the figure is shown when the torch goes off" % _i, visible)
			_ok("pose %d: ...and it is IN FRAME" % _i, in_frame, "fig %s" % str(fig.global_position.round()) if fig else "")
			_ok("pose %d: ...at arm's length (<= 3.2 m)" % _i, dist <= 3.2, "%.2f m" % dist)
			_ok("pose %d: ...and never on the real seam's x" % _i, fig != null and absf(fig.global_position.x - dark_x) >= 0.9)
			_i += 1
			_phase = 1
			_t = 0.0
	return false
