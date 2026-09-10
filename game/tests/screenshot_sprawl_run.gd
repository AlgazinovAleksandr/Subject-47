extends SceneTree

# Photograph THE SPRAWL's crate run from the player's own eye (2026-09-10). **Run WITHOUT
# --headless.**
#
#   Godot --path game --script res://tests/screenshot_sprawl_run.gd -- --out=<dir>
#
# The user's replay: *"When the creature escapes the box it runs very far away through one of
# the yellow blocks, I cannot see it well."* The run is now ~7 m straight down the crate's own
# recess, away from the player at its mouth, through the wall at its end. This tool stands
# where a player who followed the whisper stands, presses E through the shipping ray, and
# captures a frame every 0.1 s for 5 s — INTO MEMORY, written after the beat, because a 5 MP
# `save_png` stalls the frame it runs in (`screenshot_false_door.gd`'s lesson). It also
# accumulates the seconds the runner is in frustum while running and FAILS under 1.6 s, so
# the pictures come with a number.

var OUT := "/tmp/sprawl_run/"
const FRAME_DT := 0.1
const RUN_WATCH := 5.5

var _t := 0.0
var _stage := 0
var _next_frame := 0.0
var _frames := 0
var _pending: Array = []
var _seen_t := 0.0
var _scene: Node
var _player: CharacterBody3D
var _z2: Node
var _crate: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			OUT = String(a).trim_prefix("--out=").trim_suffix("/") + "/"
	seed(7)
	change_scene_to_file("res://scenes/backrooms.tscn")


func _all(n: Node, acc: Array) -> Array:
	for c in n.get_children():
		acc.append(c)
		_all(c, acc)
	return acc


func _shoot(name: String) -> void:
	_pending.append([name, get_root().get_viewport().get_texture().get_image()])


func _flush() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for p in _pending:
		(p[1] as Image).save_png(OUT + String(p[0]) + ".png")
	print("wrote %d frames to %s" % [_pending.size(), OUT])
	_pending.clear()


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
			_z2 = _scene.get_node_or_null("ZoneSprawl")
			if _player == null or _z2 == null:
				print("FAIL: no player/zone")
				quit(1)
				return true
			_scene.call("_enter_zone", 2)
			# Disarm what would end the run: traps, the Smiler, apparitions.
			for n in _all(_scene, []):
				var s: Script = n.get_script()
				if s == null:
					continue
				var g := String(s.get_global_name())
				if g == "CreatureSmiler" or g == "Beartrap" or g == "Apparition":
					n.queue_free()
			_player.set_smiler_active(true)
			for n in _player.get_children():
				if n is CanvasLayer:
					n.visible = false
			_crate = _z2.get_node_or_null("SprawlCrate") as Node3D
			if _crate == null:
				print("FAIL: no crate")
				quit(1)
				return true
			# Stand 1.6 m in front of the box, on the hall side, looking at it.
			var axis: Vector3 = _z2.call("exit_axis")
			var stand: Vector3 = _crate.global_position - axis * 1.6
			_player.global_position = Vector3(stand.x, 0.1, stand.z)
			_player.velocity = Vector3.ZERO
			_player.set("ai_active", true)
			_player.call("ai_look_at", _crate.global_position + Vector3(0, 0.5, 0))
			_t = 0.0
			_stage = 1
			return false
		1:
			if _t < 0.8:
				return false
			_shoot("before")
			var target: Node = _player.call("ai_interact_target")
			print("interact target: %s" % [target])
			_player.call("ai_interact")
			_t = 0.0
			_next_frame = 0.0
			_stage = 2
			return false
		2:
			var runner := _z2.get_node_or_null("SprawlDweller") as Node3D
			var cam := _player.get_node_or_null("Camera3D") as Camera3D
			if runner and cam and bool(runner.get("_running")) \
					and cam.is_position_in_frustum(runner.global_position + Vector3(0, 1.1, 0)):
				_seen_t += delta
			if _t >= _next_frame:
				_shoot("run_%02d" % _frames)
				_frames += 1
				_next_frame += FRAME_DT
			if _t < RUN_WATCH:
				return false
			# The payoff: the wall it went through, from 3 m in front of it.
			var wall := _z2.call("exit_wall") as Node3D
			var axis: Vector3 = _z2.call("exit_axis")
			var at: Vector3 = wall.global_position - axis * 3.0
			_player.global_position = Vector3(at.x, 0.1, at.z)
			_player.velocity = Vector3.ZERO
			_player.call("ai_look_at", Vector3(wall.global_position.x, 1.4, wall.global_position.z))
			_t = 0.0
			_stage = 3
			return false
		3:
			if _t < 0.6:
				return false
			_shoot("after")
			_flush()
			print("runner in frustum while running: %.2f s (need >= 1.6)" % _seen_t)
			print("SPRAWL-RUN " + ("PASS" if _seen_t >= 1.6 else "FAIL"))
			quit(0 if _seen_t >= 1.6 else 1)
			return true
	return false
