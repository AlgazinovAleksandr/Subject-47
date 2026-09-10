extends SceneTree

# Photograph KONTUR's Recovery Archive after the 2026-09-10 texture pass. **Run WITHOUT
# --headless.**
#
#   Godot --path game --script res://tests/screenshot_kontur_archive.gd -- --out=<dir>
#
# Three frames from the aisle with the torch on: the west rack, the east rack, and the
# keycard once the key lot has been searched. Frames are captured INTO MEMORY and written at
# the end (`screenshot_false_door.gd`'s lesson: a 5 MP save stalls the frame it runs in).
# `check_kontur.gd` asserts the textures EXIST; this is the only thing that can say whether
# they read under a torch in a room at ambient 0.02, and whether the racks are once again the
# brightest thing in the room (the ⚠️ at `_spawn_recovery_archive`).

var OUT := "/tmp/kontur_archive/"

var _t := 0.0
var _stage := 0
var _pending: Array = []
var _scene: Node
var _player: CharacterBody3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			OUT = String(a).trim_prefix("--out=").trim_suffix("/") + "/"
	seed(7)
	change_scene_to_file("res://scenes/kontur.tscn")


func _shoot(name: String) -> void:
	_pending.append([name, get_root().get_viewport().get_texture().get_image()])


func _flush() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for p in _pending:
		(p[1] as Image).save_png(OUT + String(p[0]) + ".png")
	print("wrote %d frames to %s" % [_pending.size(), OUT])


func _pose(at: Vector3, look: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	_player.call("ai_look_at", look)


func _process(delta: float) -> bool:
	_t += delta
	if current_scene == null:
		return false
	if _scene == null and _t < 3.0:
		return false
	match _stage:
		0:
			_scene = current_scene
			_player = _scene.get_node_or_null("Player") as CharacterBody3D
			if _player == null:
				print("FAIL: no player")
				quit(1)
				return true
			for n in _player.get_children():
				if n is CanvasLayer:
					n.visible = false
			_player.set("ai_active", true)
			# West rack (x = -2.3), from the aisle 1.6 m off its front face, mid-shelf height.
			_pose(Vector3(-0.35, 0.1, 39.5), Vector3(-2.3, 1.05, 39.5))
			_t = 0.0
			_stage = 1
		1:
			if _t < 0.8:
				return false
			_shoot("west_rack")
			_pose(Vector3(0.35, 0.1, 39.5), Vector3(2.3, 1.05, 39.5))
			_t = 0.0
			_stage = 2
		2:
			if _t < 0.8:
				return false
			_shoot("east_rack")
			# The 217 plate close up (east rack, shelf 2, z 37.9).
			_pose(Vector3(0.9, 0.1, 37.9), Vector3(2.2, 1.72, 37.9))
			_t = 0.0
			_stage = 3
		3:
			if _t < 0.8:
				return false
			_shoot("plate_217")
			# Search the key lot so the keycard exists.
			var key_lot: Node = null
			for c in _scene.get_children():
				if String(c.name).begins_with("Lot_") and bool(c.get("has_key")):
					key_lot = c
			if key_lot == null:
				print("FAIL: no key lot")
				_flush()
				quit(1)
				return true
			key_lot.call("interact")
			_t = 0.0
			_stage = 4
		4:
			if _t < 0.6:
				return false
			var card := _scene.get_node_or_null("ArchiveKeycard") as Node3D
			if card == null:
				print("FAIL: no keycard revealed")
				_flush()
				quit(1)
				return true
			var cp: Vector3 = card.global_position
			var side: float = signf(cp.x)
			_pose(Vector3(cp.x - side * 0.9, 0.1, cp.z), cp)
			_t = 0.0
			_stage = 5
		5:
			if _t < 0.8:
				return false
			_shoot("keycard")
			_flush()
			quit(0)
			return true
	return false
