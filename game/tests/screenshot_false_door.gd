extends SceneTree

# Dev tool: photograph the false room 217's lunge (2026-09-10) from the player's own eye —
# the figure in the doorway, at the face, and running away round the corner.
#
#   Godot --path game --script res://tests/screenshot_false_door.gd -- --out=<dir>
#
# Not headless — it needs a real render. Presses E through the shipping ray from the approach
# pose `check_corridor_events.gd` uses, then shoots at fixed offsets from that press.

var OUT := "/tmp/false_door/"
const SHOTS := [0.20, 0.40, 0.62, 1.00, 1.45, 2.10]
var _t := 0.0
var _stage := 0
var _scene: Node
var _player: CharacterBody3D
var _door: Node3D
var _next := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			OUT = String(a).trim_prefix("--out=").trim_suffix("/") + "/"
	change_scene_to_file("res://scenes/corridor.tscn")


func _find(n: Node, want: String) -> Node:
	if String(n.name) == want:
		return n
	for c in n.get_children():
		var f := _find(c, want)
		if f:
			return f
	return null


# ⚠️ CAPTURE NOW, WRITE LATER. `save_png` on a 3024x1701 frame costs ~0.5 s of wall time, and
# the game's own clock is the wall clock, so saving inside the beat made every later frame
# land half a second after its label. The readback is cheap; the encode waits until the end.
var _pending: Array = []


func _shoot(name: String) -> void:
	var img := get_root().get_viewport().get_texture().get_image()
	_pending.append([name, img, _t])


func _flush() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for p in _pending:
		(p[1] as Image).save_png(OUT + String(p[0]) + ".png")
		print("shot: %s%s.png  (captured at t=%.2f)" % [OUT, String(p[0]), float(p[2])])
	_pending.clear()


func _process(delta: float) -> bool:
	_t += delta
	if current_scene == null:
		return false
	# ⚠️ The boot wait applies ONLY before the scene is adopted. Written as `_t < 2.0` on every
	# frame it also gated every later stage, whose `_t` had been reset — so each stage waited
	# 2 s and then every shot threshold passed at once, 0.02 s apart.
	if _scene == null and _t < 2.0:
		return false
	if _scene == null:
		_scene = current_scene
		_player = _scene.get_node_or_null("Player") as CharacterBody3D
		_door = _find(_scene, "FalseExitDoor") as Node3D
		if not _player or not _door:
			print("FAIL: no player/door")
			quit(1)
			return true
		var cs: GDScript = _scene.get_script()
		var dist: float = float(cs.get("FALSE_DOOR_DIST"))
		var approach: Dictionary = _scene.call("_path_point", dist - 0.9)
		var leaf := _find(_door, "Leaf") as Node3D
		var aim: Vector3 = leaf.global_position if leaf else _door.global_position
		_player.global_position = approach["pos"] as Vector3 + Vector3(0, 0.1, 0)
		_player.velocity = Vector3.ZERO
		var to: Vector3 = aim - (_player.global_position + Vector3(0, 1.6, 0))
		_player.rotation.y = atan2(-to.x, -to.z)
		var cam := _player.get_node_or_null("Camera3D") as Camera3D
		if cam:
			cam.rotation.x = 0.0
		_player.set("ai_active", true)
		_t = 0.0
		_stage = 1
		return false
	if _stage == 1:
		if _t < 0.5:
			return false
		_shoot("before")
		_player.call("ai_look_at", (_find(_door, "Leaf") as Node3D).global_position)
		_player.call("ai_interact")
		_t = 0.0
		_stage = 2
		return false
	if _stage == 2:
		if _next < SHOTS.size() and _t >= float(SHOTS[_next]):
			_shoot("t%03d" % int(round(float(SHOTS[_next]) * 100.0)))
			_next += 1
		if _next >= SHOTS.size():
			_flush()
			quit(0)
			return true
	return false
