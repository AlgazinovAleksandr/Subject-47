extends SceneTree

# THE BREACH — what Object 12 LOOKS LIKE at each shield level, and whether EMISSION_BASE
# survives contact with the light weapon.  Run WITHOUT --headless.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/probe_breach_wound.gd
#
# The chase probe photographed a flat, fully-saturated red silhouette with no skin detail at
# all. This isolates why: `_update_wound_tint()` (creature_object12.gd:575) writes
# `lerp(0.35, 0.9, wound)` into emission_energy — a hard-coded 0.35 FLOOR that was not moved
# when EMISSION_BASE dropped 0.35 -> 0.12.

const OUT := "user://breach_wound"

var _t := 0.0
var _stage := 0
var _sub := 0
var _lvl: Node
var _player: CharacterBody3D
var _cam: Camera3D
var _c: Node
var _body: StaticBody3D
var _mat: StandardMaterial3D
var _log: Array[String] = []
var _atrium := Vector3.ZERO
var _shields := [100.0, 100.0, 60.0, 20.0, 0.0]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file("res://scenes/level_6_breach.tscn")


func _say(s: String) -> void:
	_log.append(s)
	print("  " + s)


func _find_script(n: Node, s: String, out: Array) -> void:
	var sc: Variant = n.get_script()
	if sc and String(sc.resource_path).ends_with(s):
		out.append(n)
	for c in n.get_children():
		_find_script(c, s, out)


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, n])
	print("   [shot] " + n)


func _look(from: Vector3, at: Vector3) -> void:
	_player.global_position = from
	_player.velocity = Vector3.ZERO
	var d := at - from
	_player.rotation.y = atan2(-d.x, -d.z)
	_cam.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.5, 1.5)


func _describe() -> String:
	return "albedo=%s  emission=%s  energy=%.3f" % [_mat.albedo_color, _mat.emission,
		_mat.emission_energy_multiplier]


func _process(delta: float) -> bool:
	_t += delta
	if _t < 0.03:
		return false

	if _stage == 0:
		if _t < 2.5:
			return false
		_lvl = current_scene
		_player = get_first_node_in_group("player") as CharacterBody3D
		_cam = _player.get_node_or_null("Camera3D")
		_player.set("ai_active", true)
		var out: Array = []
		_find_script(_lvl, "creature_object12.gd", out)
		_c = out[0]
		_body = _c.get("_body")
		_mat = _c.get("_material")
		_c.set("contact_dist", 0.02)
		var b: Node = _lvl.get("_builder")
		_atrium = b.call("room_center", "Atrium")
		_say("AS SPAWNED (never lit): %s" % _describe())
		_say("   -> creature_object12.gd:199 EMISSION_BASE = 0.12")
		_stage = 1
		_t = 0.0
		return false

	if _stage == 1:
		var i: int = _sub / 2
		if i >= _shields.size():
			print("\n===== BREACH WOUND SUMMARY =====")
			for l in _log:
				print(l)
			print("\n%s" % ProjectSettings.globalize_path(OUT))
			quit(0)
			return true
		if _sub % 2 == 0:
			_c.call("activate")
			_c.call("_enter", 0)             # PATROL, so nothing moves it
			_c.set("_block_t", 5.0)          # and nothing walks it away
			_body.global_position = _atrium + Vector3(0, 0, 0.5)
			_body.rotation.y = PI
			_look(_atrium + Vector3(0, 0.1, -3.5), _atrium + Vector3(0, 1.0, 0.5))
			_c.set("_shield", _shields[i])
			# i==0 is the pristine control: DO NOT call the updater at all.
			if i > 0:
				_c.call("_update_wound_tint")
			_sub += 1
			_t = 0.0
			return false
		var tag := "pristine (updater never called)" if i == 0 \
			else "shield %3.0f/100" % _shields[i]
		_shot("2%d_shield_%03d%s" % [i, int(_shields[i]), "_pristine" if i == 0 else ""])
		_say("%-34s %s" % [tag, _describe()])
		_sub += 1
		_t = 0.0
		return false
	return false
