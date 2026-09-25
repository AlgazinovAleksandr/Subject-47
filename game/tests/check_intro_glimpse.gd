extends SceneTree

# THE HALL GLIMPSE — someone is strapped to the bed you just left (the Intake Wing, 2026-09-24).
#
# The beat, and what each stage proves:
#   1. through the wake-up (lie, sit, stand — no buckling since 2026-09-25) the cell bed is EMPTY —
#      no `CellOccupant` node exists at all
#   2. the player opens the hall door with the SHIPPING interact path (ai_look_at + ai_interact)
#      and WALKS in (ai_move_dir, move_and_slide — no teleport across the threshold); standing in
#      the doorway there is still nobody on the bed
#   3. once properly inside the hall it is there: on the cell bed, and VISIBLE THROUGH THE GLASS —
#      a ray from the player's eye to it meets the pane first (the glass is solid) and, with the
#      pane excluded, reaches the occupant's own collider (no wall, sill or head in the way); and
#      it is inside the camera frustum when the player looks at the glass
#   4. the player walks back out into the corridor: it is GONE — the node freed, not hidden
#   5. the player walks back in: it is STILL gone. Never again
#   6. zero panic throughout, and no sound was attached to it
#
# ⚠️ PROVED TO FAIL (2026-09-24): with `_occupant.queue_free()` in intro_room.gd:_tick_hall()
# commented out, stages 4 and 5 go red ("the occupant is gone once you step out"). The sample
# sizes are asserted too — "0 frames watched … PASS" has happened in this repo.
#
#   Godot --headless --path game --script res://tests/check_intro_glimpse.gd

const WALK_SPEED_TIMEOUT := 6.0

var _t := 0.0
var _stage := 0
var _stage_at := 0.0
var _fails: Array[String] = []
var _checks := 0
var _scene: Node = null
var _player: CharacterBody3D = null
var _peak := 0.0
var _absent_frames := 0      # frames sampled with the player walking in, before the spawn
var _threshold_frames := 0   # …of which, standing in the hall doorway itself


func _initialize() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs:
		gs.set("is_ending", false)
	change_scene_to_file("res://scenes/intro_room.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _go(next: int) -> void:
	_stage = next
	_stage_at = _t


func _occ() -> Node3D:
	var o := _scene.get_node_or_null("CellOccupant") as Node3D
	if o and o.is_queued_for_deletion():
		return null
	return o


func _walk(dir_yaw: float) -> void:
	_player.rotation.y = dir_yaw
	_player.ai_active = true
	_player.ai_move_dir = Vector2(0, -1)


func _stop() -> void:
	_player.ai_move_dir = Vector2.ZERO


func _process(delta: float) -> bool:
	_t += delta
	if _player:
		_peak = maxf(_peak, _player.get_panic_ratio())
	var el := _t - _stage_at
	match _stage:
		0:
			_scene = current_scene
			_player = _scene.get_node_or_null("Player") as CharacterBody3D if _scene else null
			# ⭐ No buckling since 2026-09-25: the wake stands you up by itself in ~3 s.
			if _player and _scene.get("_beats") != null and (_scene.get("_beats") as Dictionary).has("straps"):
				_ok("the cell bed is empty through the wake-up", _occ() == null)
				_go(2)
			elif _t > 15.0:
				_ok("the wake-up stood the player up", false)
				return _finish()
		2:
			if el < 0.5:
				return false
			_ok("still nobody on the bed once you are up", _occ() == null)
			_player.global_position = Vector3(-3.0, 0.05, 15.0)
			_player.velocity = Vector3.ZERO
			_go(3)
		3:
			if el < 0.3:
				return false
			var door := _scene.get_node("HallDoor") as Node3D
			_player.ai_look_at(door.global_position + Vector3(0, 1.3, 0))
			var target: Node = _player.ai_interact_target()
			_ok("the hall door answers the real interact ray", target != null
				and (target == door or door.is_ancestor_of(target)),
				"target %s" % (target.name if target else "nothing"))
			_player.ai_interact()
			_go(4)
		4:
			if el < 1.4:      # the leaf's swing
				return false
			_ok("the hall door is open", _scene.get_node("HallDoor").call("is_open") == true)
			_walk(PI / 2.0)    # face -x, into the hall
			_go(5)
		5:
			var x := _player.global_position.x
			if _occ() == null:
				_absent_frames += 1
				if x < -4.2 and x > -4.8:
					_threshold_frames += 1
			if x < -5.6:
				_stop()
				_go(6)
			elif el > WALK_SPEED_TIMEOUT:
				_ok("the player walked into the hall", false, "stuck at x %.2f" % x)
				return _finish()
		6:
			if el < 0.2:
				return false
			_ok("walking in, the bed was watched EMPTY first", _absent_frames >= 10,
				"%d frames" % _absent_frames)
			_ok("…including while standing in the hall doorway", _threshold_frames >= 2,
				"%d frames" % _threshold_frames)
			var occ := _occ()
			_ok("inside the hall, SOMEONE IS ON YOUR BED", occ != null)
			if occ == null:
				return _finish()
			var bed: Vector3 = _scene.get_script().get_script_constant_map()["CELL_GURNEY_POS"]
			_ok("…on the cell bed", Vector2(occ.global_position.x, occ.global_position.z)
				.distance_to(Vector2(bed.x, bed.z)) < 0.2)
			_ok("…and it is not one of the ward's SheetedForm_ bodies",
				not String(occ.name).begins_with("SheetedForm_"))
			var sounds := 0
			for c in occ.get_children():
				if c is AudioStreamPlayer3D:
					sounds += 1
			_ok("…and it makes no sound", sounds == 0)
			# Through the glass, by ray.
			_player.ai_look_at(occ.global_position + Vector3(0, 0.25, 0))
			var cam := _player.get_node("Camera3D") as Camera3D
			var eye := cam.global_position
			var aim := occ.global_position + Vector3(0, 0.15, 0)
			var space := _player.get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(eye, aim)
			q.exclude = [_player.get_rid()]
			var h := space.intersect_ray(q)
			var pane := _scene.get_node_or_null("ObservationGlass_Pane") as CollisionObject3D
			_ok("the eye-line to it meets the GLASS first (the pane is solid)",
				not h.is_empty() and h["collider"] == pane,
				"hit %s" % (str(h["collider"].name) if not h.is_empty() else "nothing"))
			if pane:
				q.exclude = [_player.get_rid(), pane.get_rid()]
			var h2 := space.intersect_ray(q)
			_ok("…and past the glass, nothing but the occupant — it is VISIBLE",
				not h2.is_empty() and occ.is_ancestor_of(h2["collider"]),
				"hit %s" % (str(h2["collider"].get_path()) if not h2.is_empty() else "nothing"))
			_ok("…inside the camera's frustum when you look at the glass", cam.is_position_in_frustum(aim))
			_walk(-PI / 2.0)   # face +x, back out to the corridor
			_go(7)
		7:
			if _player.global_position.x > -3.4:
				_stop()
				_go(8)
			elif el > WALK_SPEED_TIMEOUT:
				_ok("the player walked back out", false, "stuck at x %.2f" % _player.global_position.x)
				return _finish()
		8:
			if el < 0.2:
				return false
			_ok("the occupant is GONE once you step out", _occ() == null)
			_ok("…freed, not hidden (a hidden node keeps its collider)",
				_scene.get_node_or_null("CellOccupant") == null)
			_walk(PI / 2.0)
			_go(9)
		9:
			if _player.global_position.x < -5.6:
				_stop()
				_go(10)
			elif el > WALK_SPEED_TIMEOUT:
				_ok("the player walked back in", false)
				return _finish()
		10:
			if el < 0.4:
				return false
			_ok("walking back in, the bed is EMPTY — never again", _occ() == null)
			_ok("zero panic through the whole glimpse", is_zero_approx(_peak), "peak %.4f" % _peak)
			return _finish()
	if _t > 60.0:
		_ok("finished in time", false, "stuck at stage %d" % _stage)
		return _finish()
	return false


func _finish() -> bool:
	print("")
	print("%d checks, %d failed" % [_checks, _fails.size()])
	if _fails.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for f in _fails:
			print("  FAIL: " + f)
		print("RESULT: FAIL")
		quit(1)
	return true
