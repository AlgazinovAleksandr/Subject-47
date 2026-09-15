extends SceneTree
# BACKLOG_Sep_15 renders (2026-09-15): C1 the door figure standing in the MIDDLE of the hall past
# the ajar door at 124; C2 the regenerated Manager at the telegraph + its lunge; C4 the bell nook
# after the lights return with the 217 key on the desk. Run WITHOUT --headless.
# Self-terminating: a hard frame cap and a `current_scene == null` gate (a hung harness costs trust).
# Output: /tmp/sep15_shots/
const OUT := "/tmp/sep15_shots/"
var _lvl: Node
var _p: CharacterBody3D
var _f := 0
var _total := 0
var _step := 0
var _t := 0.0
var _shot3 := false
var _shot4 := false
var _shot5 := false
var _shot6 := false
var _shot7 := false
var _shot8 := false   # ⚠️ seconds, not frames: this display runs at 120 Hz, so a frame count is not a clock


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/corridor.tscn")


func _shoot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("shot: ", n)


func _pt(d: float) -> Dictionary:
	return _lvl.call("_path_point", d)


func _stand(d: float, look_ahead: float, y_look: float = 1.2) -> void:
	var pt := _pt(d)
	_p.global_position = (pt["pos"] as Vector3) + Vector3(0, 0.1, 0)
	_p.velocity = Vector3.ZERO
	_p.call("ai_look_at", (pt["pos"] as Vector3) + (pt["dir"] as Vector3) * look_ahead + Vector3(0, y_look, 0))


func _process(delta: float) -> bool:
	_total += 1
	_t += delta
	if _total > 1500:
		print("RESULT: FAIL (timeout at step %d)" % _step)
		quit(1)
		return true
	if current_scene == null:
		return false
	_f += 1
	if _lvl == null:
		if _f < 20:
			return false
		_lvl = current_scene
		_p = _lvl.get_node("Player")
		_p.set("ai_active", true)
		for n in _lvl.get_children():
			if n is Area3D and n.get_script() != null and String(n.get_script().resource_path).ends_with("beartrap.gd"):
				(n as Area3D).monitoring = false
		var ra := root.get_node_or_null("/root/RandomAmbient")
		if ra:
			ra.set_process(false)
		_f = 0
	var cs: Dictionary = (_lvl.get_script() as GDScript).get_script_constant_map()
	match _step:
		0:
			# C1: approach the 124 door from 10 m back; _tick_break_door spawns the figure in this band
			_stand(float(cs["BREAK_DOOR_AT"]) - 10.0, 12.0, 0.9)
			_step = 1
			_f = 0
		1:
			if _f == 25:
				_shoot("1_break_door_figure_mid_hall")
				_stand(float(cs["BREAK_DOOR_AT"]) - 6.0, 8.0, 0.9)
			if _f == 45:
				_shoot("2_break_door_figure_closer")
				# C2: the Manager. Stand 6 m before the second telegraph and fire the payoff directly.
				var tele: Array = cs["TELEGRAPH_AT"]
				_stand(float(tele[1]) - 1.0, 10.0, 1.1)
				_step = 2
				_f = 0
				_t = 0.0
		2:
			if _f == 10:
				_lvl.call("_ev_manager")
			if _f == 11:
				_t = 0.0
			if _f > 11 and _t > 0.2 and _f == int(_f) and not _shot3:
				_shot3 = true
				_shoot("3_manager_telegraph")
			if _t > 0.55 and not _shot4:
				_shot4 = true
				_shoot("4_manager_lunge")
			if _t > 2.2 and not _shot5:
				_shot5 = true
				_shoot("5_manager_flees")
				_p.call("unfreeze_input")
				# C4: the bell nook — ring, wait out the blackout, photograph the key
				var spurs: Array = _lvl.call("spurs")
				var e: Dictionary = spurs[1]
				var desk: Node3D = _lvl.get_node("Spur1Desk")
				var bell: Node3D = _lvl.get_node("Spur1Bell")
				_p.global_position = desk.global_position - (e["dir"] as Vector3) * 1.4 + Vector3(0, 0.1, 0)
				_p.velocity = Vector3.ZERO
				_p.call("ai_look_at", bell.global_position)
				(bell as Node).call("interact")
				_step = 3
				_f = 0
				_t = 0.0
		3:
			if _t > 0.4 and not _shot6:
				_shot6 = true
				_shoot("6_bell_rung")
			if _t > 3.0 and not _shot7:
				_shot7 = true
				_shoot("7_bell_blackout")
			if _t > 7.0 and not _shot8:
				_shot8 = true
				var key := _lvl.get_node_or_null("Spur1Key") as Node3D
				if key:
					_p.call("ai_look_at", key.global_position)
			if _t > 7.4:
				_shoot("8_bell_key_on_desk")
				print("RESULT: PASS")
				quit(0)
				return true
	return false
