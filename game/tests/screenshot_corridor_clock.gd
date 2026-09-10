extends SceneTree

# Dev tool: photograph the grandfather clock at d = 48 (2026-09-10) from the centreline and
# from close up, so the pendulum behind the glass, the dial and the wood can be judged.
#
#   Godot --path game --script res://tests/screenshot_corridor_clock.gd -- --out=<dir>
#
# Not headless — it needs a real render.

var OUT := "/tmp/corridor_clock/"
var _t := 0.0
var _stage := 0
var _pose := -1
var _scene: Node
var _player: CharacterBody3D
const POSES := [
	["far", Vector3(0.0, 0.1, 43.5), Vector3(1.3, 1.2, 48.0)],
	["near", Vector3(0.3, 0.1, 46.9), Vector3(1.3, 1.3, 48.0)],
	["dial", Vector3(0.5, 0.1, 47.6), Vector3(1.3, 1.75, 48.0)],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			OUT = String(a).trim_prefix("--out=").trim_suffix("/") + "/"
	change_scene_to_file("res://scenes/corridor.tscn")


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
			quit(1)
			return true
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
		_shoot(POSES[_pose][0])
		_stage = 0
	return false
