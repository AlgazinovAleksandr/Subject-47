extends SceneTree

# A ScaryObject at intensity 0 must not stop panic from healing (Issue 196, 2026-09-12).
#
# `player.gd:_update_panic()` takes the GAZE branch whenever the ray lands on anything under a
# ScaryObject and only the `else` branch decays. THE NIGHTMARE's Weeping Frames carry intensity
# 0.0 below three sconces and again once burnt out, so a player who looked at a harmless painting
# had their panic frozen — the four-seed bot held 38 % for 30 s with no entity present and died at
# 90 %. This drives the shipping gaze ray at a real frame in a real dungeon:
#   * intensity 0: panic DECAYS while staring at it
#   * CONTROL, the same frame at intensity 1.0: panic CLIMBS while staring at it
#
# Usage: Godot --headless --path game --script res://tests/check_gaze_decay.gd

const SEED := 303
const START_PANIC := 20.0
const HOLD_TICKS := 60      # one second of physics

var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _p: CharacterBody3D = null
var _frame: Node3D = null
var _stage := 0
var _tick0 := 0
var _panic0 := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _panic() -> float:
	return float(_p.call("get_panic_ratio")) * 50.0


func _aim_at_frame() -> bool:
	# Stand 1.2 m off whichever face of the frame answers the shipping ray.
	var cam := _p.get_node_or_null("Camera3D") as Camera3D
	for sgn in [1.0, -1.0]:
		var n: Vector3 = _frame.global_transform.basis.z.normalized() * sgn
		_p.global_position = _frame.global_position + n * 1.2 - Vector3(0, _frame.global_position.y - 0.1, 0)
		_p.force_update_transform()
		_p.call("ai_look_at", _frame.global_position)
		if cam:
			cam.force_update_transform()
		# ⚠️ Not ai_interact_target(): a frame has no interact verb, so that returns null even
		# when the ray lands on it. Cast the same ray ourselves and walk the hit up to the frame.
		if cam == null:
			return false
		var space := _p.get_world_3d().direct_space_state
		var from: Vector3 = cam.global_position
		var to: Vector3 = from - cam.global_transform.basis.z * 3.0
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [_p.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var c: Node = hit["collider"]
			if c == _frame or _frame.is_ancestor_of(c):
				return true
	return false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		root.get_node("GameState").call("save_level_progress", 7, {"layout_seed": SEED, "content_seed": SEED * 31 + 7})
		change_scene_to_file("res://scenes/dungeon.tscn")
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or _level.get("_frames") == null:
			print("  FAIL dungeon.tscn did not load, or dungeon.gd failed to parse")
			_fails += 1
			return _report()
		_p = _level.get_node_or_null("Player") as CharacterBody3D
		var frames: Array = _level.get("_frames")
		_ok("the dungeon has Weeping Frames", not frames.is_empty(), "%d" % frames.size())
		if frames.is_empty() or _p == null:
			return _report()
		_frame = frames[0]
		# Entities out of the way: this is about the frame alone.
		for c in _level.get_children():
			if c.name.begins_with("StillOne_") or c.name == "TheHunter" or c.name == "TheChild" or c.name == "TheKneelingMan":
				_level.remove_child(c)
				c.queue_free()
		_ok("the frame starts at intensity 0 (harmless tier)", float(_frame.get("_scary").get("scare_intensity")) == 0.0)
		_ok("the shipping ray lands on the frame", _aim_at_frame())
		_p.call("add_panic", START_PANIC)
		_panic0 = _panic()
		_tick0 = Engine.get_physics_frames()
		_stage = 1
		return false
	var ticks: int = Engine.get_physics_frames() - _tick0
	if _stage == 1 and ticks >= HOLD_TICKS:
		var now := _panic()
		_ok("panic DECAYS while gazing at an intensity-0 ScaryObject",
			now < _panic0 - 2.0, "%.1f -> %.1f over %d ticks" % [_panic0, now, ticks])
		# CONTROL: the same stare at intensity 1.0 must climb.
		_frame.get("_scary").set("scare_intensity", 1.0)
		_p.call("add_panic", 0.0)
		_panic0 = _panic()
		_tick0 = Engine.get_physics_frames()
		_stage = 2
		return false
	if _stage == 2 and ticks >= 30:
		var now := _panic()
		_ok("CONTROL: at intensity 1.0 the same stare CLIMBS", now > _panic0 + 2.0,
			"%.1f -> %.1f over %d ticks" % [_panic0, now, ticks])
		return _report()
	return false


func _report() -> bool:
	if _checks < 5:
		print("  FAIL only %d checks ran" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
