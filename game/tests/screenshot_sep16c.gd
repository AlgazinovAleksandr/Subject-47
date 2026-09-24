extends SceneTree
# C7 + H4 (2026-09-16) renders: the closet at the cupboard spur (door open from the spur, the
# slam, the shadow under the door, the release) and the cellar note beat (read, close, dark and
# pinned, the doll with the House screamer, lights back). Run WITHOUT --headless. Self-terminating.
# Output: /tmp/sep16c_shots/
const OUT := "/tmp/sep16c_shots/"
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
func _where_on_screen() -> bool:
	for n in _all(root, []):
		if n is Label and String((n as Label).text) == "WHERE AM I?" and (n as Label).modulate.a > 0.05:
			return true
	return false
func _all(n: Node, acc: Array) -> Array:
	for c in n.get_children():
		acc.append(c)
		_all(c, acc)
	return acc
func _process(delta: float) -> bool:
	_total += 1
	_t += delta
	if _total > 4000:
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
		var ra := root.get_node_or_null("/root/RandomAmbient")
		if ra:
			ra.set_process(false)
		_f = 0
		_t = 0.0
		_step = 0 if _scene_i == 0 else 10
		return false
	match _step:
		0:
			var e: Dictionary = (_lvl.call("spurs") as Array)[2]
			var dir3: Vector3 = e["dir"]
			var door: Node3D = _lvl.get_node("Spur2ClosetDoor")
			_p.global_position = (e["mouth"] as Vector3) + dir3 * 3.0 + Vector3(0, 0.1, 0)
			_p.velocity = Vector3.ZERO
			_p.call("ai_look_at", door.global_position + Vector3(0, 1.1, 0))
			_step = 1
			_t = 0.0
		1:
			if _t > 0.4:
				_shoot("1_closet_door_open_from_spur")
				var cup: Node3D = _lvl.get_node("Spur2Cupboard")
				var e: Dictionary = (_lvl.call("spurs") as Array)[2]
				_p.global_position = cup.global_position + Vector3(0, 0.1, 0)
				_p.velocity = Vector3.ZERO
				# look at the door's SILL — the strip and the shadow are at the floor
				_p.call("ai_look_at", (_lvl.get_node("Spur2ClosetStrip") as Node3D).global_position + Vector3(0, 0.25, 0))
				_step = 2
				_t = 0.0
		2:
			if _t > 0.6:
				_shoot("2_closet_sealed")
			var beat: Node = _lvl.get_node("Spur2CupboardBeat")
			if _t > 0.6 and _lvl.get_node_or_null("ClosetShadow") != null:
				_shoot("3_closet_shadow_under_door")
			if _t > 12.0 and bool(beat.call("is_released")):
				_shoot("4_closet_released")
				print("closet: sealed=%s released=%s" % [beat.call("is_sealed"), beat.call("is_released")])
				_scene_i = 1
				_f = 0
				change_scene_to_file("res://scenes/level_2_1.tscn")
				_step = 9
			elif _t > 30.0:
				print("closet: NOT released by %.0f s (sealed=%s)" % [_t, beat.call("is_sealed")])
				_scene_i = 1
				_f = 0
				change_scene_to_file("res://scenes/level_2_1.tscn")
				_step = 9
		10:
			var note: Node3D = _lvl.get_node("SafeNote_Cellar")
			_p.global_position = note.global_position * Vector3(1, 0, 1) + Vector3(0, -1.4, 1.4)
			_p.velocity = Vector3.ZERO
			_p.call("ai_look_at", note.global_position)
			_step = 11
			_t = 0.0
		11:
			if _t > 0.5:
				_shoot("5_cellar_note")
				var note: Node = _lvl.get_node("SafeNote_Cellar")
				note.call("interact")
				_step = 12
				_t = 0.0
		12:
			if _t > 0.6:
				root.get_node("/root/NoteUI").call("_close")
				_step = 13
				_t = 0.0
		13:
			if _t > 1.0:
				_shoot("6_cellar_dark_pinned")
			if _t > 2.0:
				_shoot("6b_cellar_where_am_i")
				if not _shots.has("_where_logged"):
					_shots["_where_logged"] = true
					print("at 2.0 s: WHERE AM I? on screen = %s; dark=%s pinned=%s torch=%s" % [_where_on_screen(), _lvl.get("_child_dark"), _p.is_input_frozen(), _p.call("is_flashlight_on")])
			# ⭐ 2026-09-24 (c): the doll comes at CHILD_APPEAR_DELAY 4.5 (was 5.5) and WHERE AM I? is
			# gone by 3.9 s (0.7 + 0.6 + hold 1.2 + 1.4); the lights return at 7.5 s (was 8.5).
			if _t > 4.2 and not _shots.has("_where_gone"):
				_shots["_where_gone"] = true
				print("at 4.2 s (before the doll at 4.5): WHERE AM I? on screen = %s" % _where_on_screen())
			if _t > 5.6:
				_shoot("7_cellar_doll")
				var audio := _lvl.get_node_or_null("GuestChildAudio") as AudioStreamPlayer3D
				print("doll: %s, scream stream %s" % [_lvl.get_node_or_null("GuestChild") != null, (audio.stream.resource_path.get_file() if audio and audio.stream else "none")])
			if _t > 8.6:
				_shoot("8_cellar_lights_back")
				print("after: dark=%s pinned=%s torch=%s" % [_lvl.get("_child_dark"), _p.is_input_frozen(), _p.call("is_flashlight_on")])
				print("RESULT: PASS")
				quit(0)
				return true
	return false
