extends SceneTree

# MEMORY PROBE (2026-09-13, after macOS killed the game for low memory in the dungeon).
# Runs WITHOUT --headless. Loads a scene, waits for it to settle, prints Godot's own
# memory monitors at the shipped 3D scale and again at 0.5, then quits itself.
#   Godot --path game --script res://tests/probe_memory.gd -- res://scenes/dungeon.tscn
# Numbers are what the RENDERER accounts for; the OS footprint is larger (Metal
# framebuffers, decoded audio), but the DELTA between the two scales is the lever.

var _scene := "res://scenes/dungeon.tscn"
var _t := 0.0
var _stage := 0
var _started := false


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("res://"):
				_scene = a
		var gs := root.get_node_or_null("GameState")
		if gs:
			gs.call("save_level_progress", 7, {"layout_seed": 404, "content_seed": 404 * 31 + 7})
		change_scene_to_file(_scene)
		return false
	_t += delta
	if _stage == 0 and _t > 6.0:
		_report("scale=%.2f" % root.scaling_3d_scale)
		root.scaling_3d_scale = 0.5
		_stage = 1
	elif _stage == 1 and _t > 12.0:
		_report("scale=%.2f" % root.scaling_3d_scale)
		_stage = 2
		quit(0)
	return false


func _report(tag: String) -> void:
	var win := DisplayServer.window_get_size()
	print("MEMPROBE %s %s window=%dx%d screen_scale=%.1f static=%.0fMB video=%.0fMB tex=%.0fMB buf=%.0fMB objects=%d" % [
		_scene.get_file(), tag, win.x, win.y, DisplayServer.screen_get_scale(),
		OS.get_static_memory_usage() / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT)])
