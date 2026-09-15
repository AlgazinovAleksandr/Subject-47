extends SceneTree
# Sep 16 renders: (a) the Corridor's 124 double door standing open onto the bedroom, from the
# hall; (b) the Lab wing payoff — `_nook_reveal()` fired with the player standing in the wing's
# Shaft room, shot at the turn, the lunge and the flee. Run WITHOUT --headless. Self-terminating.
# Output: /tmp/sep16_shots/
const OUT := "/tmp/sep16_shots/"
var _lvl: Node
var _p: CharacterBody3D
var _f := 0
var _total := 0
var _t := 0.0
var _step := 0
var _shots := {}
var _scene_i := 0
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/corridor.tscn")
func _shoot(n: String) -> void:
	if _shots.has(n):
		return
	_shots[n] = true
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("shot: ", n)
func _pt(d: float) -> Dictionary:
	return _lvl.call("_path_point", d)
func _process(delta: float) -> bool:
	_total += 1
	_t += delta
	if _total > 3000:
		print("RESULT: FAIL (timeout at step %d)" % _step)
		quit(1)
		return true
	if current_scene == null:
		return false
	_f += 1
	if _lvl != current_scene:
		if _f < 25:
			return false
		_lvl = current_scene
		_p = _lvl.get_node("Player")
		_p.set("ai_active", true)
		for n in _lvl.get_children():
			if n is Area3D and n.get_script() != null and String(n.get_script().resource_path).ends_with("beartrap.gd"):
				(n as Area3D).monitoring = false
		_f = 0
		_t = 0.0
		_step = 0 if _scene_i == 0 else 10
		return false
	var cs: Dictionary = (_lvl.get_script() as GDScript).get_script_constant_map()
	match _step:
		0:
			var bat: float = float(cs["BREAK_DOOR_AT"])
			var pt := _pt(bat - 9.0)
			_p.global_position = (pt["pos"] as Vector3) + Vector3(0, 0.1, 0)
			_p.velocity = Vector3.ZERO
			_p.call("ai_look_at", (_pt(bat + 1.5)["pos"] as Vector3) + Vector3(0, 1.0, 0))
			_lvl.call("_tick_break_door")
			_step = 1
			_t = 0.0
		1:
			if _t > 0.4:
				_shoot("1_double_door_from_hall")
				var bat: float = float(cs["BREAK_DOOR_AT"])
				var pt := _pt(bat)
				var side_v: Vector3 = (pt["side"] as Vector3) * float(cs["BREAK_DOOR_SIDE"])
				# stand on the hall centreline in front of the doors, look into the bedroom —
				# with the slam disarmed, or the tick shuts them the frame we arrive
				_lvl.set("_break_done", true)
				_p.global_position = (pt["pos"] as Vector3) - side_v * 0.3 + Vector3(0, 0.1, 0)
				_p.velocity = Vector3.ZERO
				_p.call("ai_look_at", (pt["pos"] as Vector3) + side_v * 4.0 + Vector3(0, 1.1, 0))
				_step = 2
				_t = 0.0
		2:
			if _t > 0.4:
				_shoot("2_into_the_bedroom")
				_scene_i = 1
				_f = 0
				change_scene_to_file("res://scenes/level_1.tscn")
				_step = 9
		10:
			# the wing: stand in the Shaft room facing along it, torch locked as in play
			_p.global_position = Vector3(-52.0, 0.1, 8.0)
			_p.velocity = Vector3.ZERO
			_p.call("ai_look_at", Vector3(-46.0, 1.2, 8.0))
			_p.call("lock_flashlight")
			_p.get("flashlight").visible = false
			_step = 11
			_t = 0.0
		11:
			if _t > 0.5:
				_lvl.call("_nook_reveal")
				_step = 12
				_t = 0.0
		12:
			if _t > 0.3:
				_shoot("3_nook_turn")
			if _t > 0.62:
				_shoot("4_nook_lunge")
			if _t > 1.6:
				_shoot("5_nook_flee")
			if _t > 2.2:
				var fig := _lvl.get_node_or_null("NookFigure")
				print("figure node after the beat: %s" % ("present" if fig else "gone/fleeing"))
				print("RESULT: PASS")
				quit(0)
				return true
	return false
