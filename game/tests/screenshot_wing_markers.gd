extends SceneTree

# Dev tool: photograph the 2026-09-10 Lab changes — Records lit before the power, and the
# photoluminescent doorway strips in the dark wing.
#
#   Godot --path game --script res://tests/screenshot_wing_markers.gd
#
# Not headless — it needs a real render. Writes PNGs to OUT (override with --out=<dir>).
# Poses:
#   records      Records' centre, looking west at the wing's entrance (lit room, spill)
#   corridor     inside the DarkCorridor at x -14, looking west (torch locked by the zone)
#   junction_w   the Junction, looking west down the WestCorridor (three marked doorways)
#   junction_n   the Junction, looking north up the NorthSpur

var OUT := "/tmp/wing_markers/"
var _t := 0.0
var _stage := 0
var _scene: Node
var _player: CharacterBody3D
const POSES := [
	["records", Vector3(-9.0, 0.1, 12.5), Vector3(-13.0, 1.4, 12.5)],
	["corridor", Vector3(-14.0, 0.1, 12.5), Vector3(-19.0, 1.4, 12.5)],
	["junction_w", Vector3(-21.0, 0.1, 12.5), Vector3(-25.0, 1.4, 12.5)],
	["junction_n", Vector3(-21.0, 0.1, 12.5), Vector3(-21.0, 1.4, 17.0)],
	["southhall", Vector3(-24.0, 0.1, 7.7), Vector3(-30.0, 1.4, 7.7)],
]
var _pose := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			OUT = String(a).trim_prefix("--out=").trim_suffix("/") + "/"
	change_scene_to_file("res://scenes/level_1.tscn")


func _shoot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("shot: " + OUT + name + ".png")


func _process(delta: float) -> bool:
	_t += delta
	if current_scene == null or _t < 2.0:
		return false
	if _scene == null:
		_scene = current_scene
		_player = _scene.get_node_or_null("Player") as CharacterBody3D
		if not _player:
			print("FAIL: no Player")
			quit(1)
			return true
		# Hide the crosshair/prompt layer so the frame is the world alone.
		for n in _scene.get_children():
			if n is CanvasLayer and String(n.name) != "HUDCanvas":
				n.visible = false
	if _stage == 0:
		_pose += 1
		if _pose >= POSES.size():
			quit(0)
			return true
		var p: Array = POSES[_pose]
		_player.global_position = p[1]
		_player.velocity = Vector3.ZERO
		var cam := _player.get_node_or_null("Camera3D") as Camera3D
		var to: Vector3 = (p[2] as Vector3) - (p[1] as Vector3 + Vector3(0, 1.6, 0))
		_player.rotation.y = atan2(-to.x, -to.z)
		if cam:
			cam.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		_t = 0.0
		_stage = 1
		return false
	if _stage == 1 and _t > 0.9:
		var torch := "on" if _player.is_flashlight_on() else "off"
		_shoot("%s_torch_%s" % [POSES[_pose][0], torch])
		_stage = 0
	return false
