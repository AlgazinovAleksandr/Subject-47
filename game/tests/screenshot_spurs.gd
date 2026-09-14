extends SceneTree

# C1 (2026-09-13): photograph the Corridor's three DIFFERENT dead-end spurs through the real
# shut-in — the end wall before the door slams, the beat at the second forced bar, the door
# after the escape. Run WITHOUT --headless:
#   Godot --path game --script res://tests/screenshot_spurs.gd
# Output: /tmp/spur_shots/spur<i>_<kind>_<moment>.png

const OUT := "/tmp/spur_shots/"
const HOLD := 18

var _lvl: Node = null
var _p: CharacterBody3D = null
var _i := 0
var _step := 0
var _f := 0
var _started := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/corridor.tscn")


func _spur() -> Dictionary:
	return (_lvl.call("spurs") as Array)[_i]


func _look(at: Vector3) -> void:
	_p.call("ai_look_at", at)


func _shoot(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var e := _spur()
	img.save_png(OUT + "spur%d_%s_%s.png" % [_i, String(e["kind"]), tag])
	print("shot: spur%d_%s_%s" % [_i, String(e["kind"]), tag])


func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	if not _started:
		_f += 1
		if _f < 20:
			return false
		_started = true
		_lvl = current_scene
		_p = _lvl.get_node("Player")
		_p.set("ai_active", true)
		for n in _lvl.get_children():
			if n is Area3D and n.get_script() != null and String(n.get_script().resource_path).ends_with("beartrap.gd"):
				(n as Area3D).monitoring = false
		_f = 0
	if _i >= (_lvl.call("spurs") as Array).size():
		print("SPUR-SHOTS DONE")
		quit(0)
		return true
	var e := _spur()
	var mouth: Vector3 = e["mouth"]
	var dir3: Vector3 = e["dir"]
	var L: float = float(e["len"])
	var end_face: Vector3 = mouth + dir3 * L
	_f += 1
	match _step:
		0:
			# Stand 2.5 m short of the end (outside the trap), look at the end wall.
			_p.global_position = mouth + dir3 * (L - 3.6) + Vector3(0, 0.1, 0)
			_p.velocity = Vector3.ZERO
			_look(end_face + Vector3(0, 1.45, 0))
			_f = 0
			_step = 1
		1:
			if _f == HOLD:
				_shoot("1_endwall")
				# Walk into the trap: place the body inside it.
				_p.global_position = mouth + dir3 * (L - 1.2) + Vector3(0, 0.1, 0)
				_f = 0
				_step = 2
		2:
			if _f == 30:
				var kind := String(e["kind"])
				if kind == "bell":
					var bell: Node3D = _lvl.get_node("Spur%dBell" % _i)
					_p.global_position = (_lvl.get_node("Spur%dDesk" % _i) as Node3D).global_position - dir3 * 1.4 + Vector3(0, 0.1, 0)
					_p.call("ai_look_at", bell.global_position)
					(bell as Node).call("interact")
					_step = 7
					_f = 0
					return false
				if kind == "cupboard":
					var cup: Node3D = _lvl.get_node("Spur%dCupboard" % _i)
					_p.global_position = cup.global_position + Vector3(0, 0.1, 0)
					_p.call("force_flashlight_off")
					_p.call("ai_look_at", mouth + Vector3(0, 1.3, 0))
					_step = 8
					_f = 0
					return false
				var esc: Node = _lvl.get_node_or_null("Spur%dEscape" % _i)
				if esc == null:
					print("no escape node for spur %d" % _i)
					_step = 6
					return false
				# Two bars.
				var guard := 0
				while int(esc.call("bars")) < 2 and guard < 40:
					esc.call("press")
					guard += 1
				_look(end_face + Vector3(0, 1.5, 0))
				_f = 0
				_step = 3
		3:
			if _f == 14:
				_shoot("2_bar2_endwall")
				_look(mouth + Vector3(0, 0.9, 0))
			if _f == 4 + HOLD:
				_shoot("3_bar2_door")
				var esc: Node = _lvl.get_node_or_null("Spur%dEscape" % _i)
				var guard := 0
				while esc != null and bool(esc.call("is_active")) and guard < 20:
					esc.call("press")
					guard += 1
				_f = 0
				_step = 4
		4:
			if _f == 25:
				_look(end_face + Vector3(0, 1.35, 0) if String(e["kind"]) == "plea" else mouth + Vector3(0, 1.25, 0))
			if _f == 25 + HOLD:
				_shoot("4_after_escape")
				_f = 0
				_step = 5
		5:
			# leave the spur before moving on (the next spur's trap is elsewhere anyway)
			_p.global_position = mouth - dir3 * 1.5 + Vector3(0, 0.1, 0)
			_step = 6
		6:
			_i += 1
			_step = 0
		7:
			if _f == 30:
				_shoot("2_bell_rung_desk")
			if _f == 80:
				_shoot("3_bell_steps_behind")
			if _f == 200:
				_shoot("4_bell_card")
				_p.call("restore_flashlight")
				_step = 5
		8:
			if _f == 60:
				_shoot("2_cupboard_sealed")
			if _f == 140:
				_shoot("3_cupboard_passby")
			if _f == 260:
				_shoot("4_cupboard_released")
				_p.call("restore_flashlight")
				_step = 5
	return false
