extends SceneTree

# THE VOID (level_3.tscn) is physically completable: spawn -> five safe notes -> the loop
# corridor (which must send you back at least once and never again once its note is read)
# -> across the floating tiles -> the twist note -> the exit door, unlocked.
#
# ⚠️ Every note is read through the SHIPPING raycast (ai_interact_target / ai_interact),
# never by calling interact() on the node, and the loop is walked, never signalled: the
# seam is an Area3D that only fires for a body moving +z through it, which is precisely
# the thing a call to _on_loop_seam() would not prove. walk_backrooms.gd's lesson.
#
# The six stalkers are removed first — this is a test of GEOMETRY and of the notes'
# reachability; check_void.gd covers the creatures. Budgets count PHYSICS TICKS, not
# render frames (headless idle frames are uncapped and say nothing about distance walked).
#
# Usage: Godot --headless --path game --script res://tests/walk_void.gd

const AUTOPLAYER := preload("res://tests/autoplay/autoplayer.gd")
const SCENE := "res://scenes/level_3.tscn"
const TICKS_PER_HOP := 700       # 11.7 s of movement at 60 Hz
const TICK_CAP := 24000          # hang guard over the whole route
const ARRIVE := 1.2
const TILE_ARRIVE := 0.9         # = AutoPlayer.ARRIVE_DIST; a beam is 1.0 m wide

# "walk": a waypoint. "read": approach point already reached; look at the note and press E.
# "lap": walk +z up the loop until a teleport has happened. "check": a named assertion.
var _steps: Array = [
	{"walk": Vector3(-2.7, 0, 0.0)},
	{"read": "NoteThreshold"},
	{"walk": Vector3(0, 0, 4.0)}, {"walk": Vector3(0, 0, 5.6)},
	{"walk": Vector3(0, 0, 10.0)}, {"walk": Vector3(0, 0, 11.6)},
	{"walk": Vector3(0, 0, 16.6)},
	{"read": "NoteWard"},
	# Round the right-hand gurney (2.6, 14.5): a straight line from the note to the east
	# doorway at z 15.5 clips its foot end.
	{"walk": Vector3(3.4, 0, 17.0)},
	{"walk": Vector3(5.0, 0, 15.5)}, {"walk": Vector3(6.6, 0, 15.5)},
	{"walk": Vector3(11.0, 0, 15.5)}, {"walk": Vector3(12.5, 0, 15.5)},
	{"lap": Vector3(12.5, 0, 40.0)},
	{"walk": Vector3(12.2, 0, 23.0)},
	{"read": "LoopNote"},
	{"check": "loop_broken"},
	{"walk": Vector3(12.5, 0, 43.0)},
	{"check": "no_more_laps"},
	{"walk": Vector3(12.5, 0, 44.0)}, {"walk": Vector3(12.5, 0, 45.6)},
	{"walk": Vector3(11.0, 0, 46.7)}, {"walk": Vector3(9.4, 0, 46.7)},
	{"walk": Vector3(3.0, 0, 45.5)}, {"walk": Vector3(1.7, 0, 45.5)},
	# The causeway: east pad -> spine -> the north branch -> west pad. Tile centres, as built.
	{"walk": Vector3(-0.2, 0, 45.5), "tile": true},
	{"walk": Vector3(-1.8, 0, 47.0), "tile": true},
	{"walk": Vector3(-3.6, 0, 48.2), "tile": true},
	{"walk": Vector3(-5.6, 0, 47.4), "tile": true},
	{"walk": Vector3(-7.0, 0, 46.5), "tile": true},
	{"walk": Vector3(-7.7, 0, 45.5), "tile": true},
	{"check": "still_on_the_tiles"},
	{"walk": Vector3(-9.0, 0, 45.5)}, {"walk": Vector3(-10.6, 0, 45.5)},
	# Round the exam table (-13, 45.5), which stands on the line from the doorway to the note.
	{"walk": Vector3(-11.6, 0, 47.2)}, {"walk": Vector3(-14.6, 0, 47.2)},
	{"walk": Vector3(-15.7, 0, 46.3)},
	{"read": "NoteMorgue"},
	{"walk": Vector3(-14.0, 0, 42.5)}, {"walk": Vector3(-14.0, 0, 40.9)},
	{"walk": Vector3(-14.0, 0, 36.5)}, {"walk": Vector3(-14.0, 0, 34.9)},
	{"walk": Vector3(-14.0, 0, 29.5)}, {"walk": Vector3(-14.0, 0, 27.9)},
	{"check": "exit_locked_before_twist"},
	{"walk": Vector3(-16.7, 0, 24.5)},
	{"read": "TwistNote"},
	{"check": "twist_read"},
	{"walk": Vector3(-14.0, 0, 21.2)},
	{"check": "exit_unlocked_and_found"},
]

var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _auto = null
var _step := 0
var _hop := 0
var _total := 0
var _last_phys := -1
var _retried: Dictionary = {}     # step index -> already backed up once
var _stalls := 0
var _removed := 0
var _read_pending := false      # a note is open and must be closed next frame
var _lap_start_z := 0.0
var _min_y := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		Engine.time_scale = 6.0
		change_scene_to_file(SCENE)
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_stalkers"):
			print("  FAIL level_3.tscn did not load, or level_3.gd failed to parse")
			_fails += 1
			return _report()
		var p := _level.get_node_or_null("Player") as CharacterBody3D
		if p == null:
			_ok("player exists", false)
			return _report()
		for s in (_level.call("get_stalkers") as Dictionary).values():
			if is_instance_valid(s):
				_level.remove_child(s)
				s.queue_free()
				_removed += 1
		_ok("six stalkers removed before the walk", _removed == 6, "%d removed" % _removed)
		_auto = AUTOPLAYER.new(p)
		_min_y = p.global_position.y
		return false

	# The scene reloading under us means the player died (a fall or a trap note read out).
	if current_scene != _level:
		_ok("the level did not reload mid-route (a death)", false, "at step %d" % _step)
		return _report()

	var pf := Engine.get_physics_frames()
	var ticks: int = 1 if _last_phys < 0 else maxi(0, pf - _last_phys)
	_last_phys = pf
	_total += ticks
	if _total > TICK_CAP:
		_ok("route finished inside the tick cap", false, "capped at step %d of %d" % [_step, _steps.size()])
		return _report()

	var p: CharacterBody3D = _auto.player
	_min_y = minf(_min_y, p.global_position.y)

	if _read_pending:
		var note_ui := root.get_node("NoteUI")
		_ok("a note opened through the ray", bool(note_ui.get("is_open")))
		note_ui.call("_close")
		_read_pending = false
		_step += 1
		return false

	if _step >= _steps.size():
		return _finish()
	var st: Dictionary = _steps[_step]

	if st.has("read"):
		_read_note(st["read"])
		return false
	if st.has("check"):
		_check(st["check"])
		_step += 1
		return false

	var target: Vector3 = st.get("walk", st.get("lap", Vector3.ZERO))
	var arrive: float = TILE_ARRIVE if st.get("tile", false) else ARRIVE
	if st.has("lap"):
		var laps: int = int(_level.call("loop_laps"))
		if laps >= 1:
			_ok("the loop corridor sent the player back at least once",
				true, "%d lap(s), z %.1f -> %.1f" % [laps, _lap_start_z, p.global_position.z])
			_step += 1
			_hop = 0
			_auto.reset_stuck()
			return false
		if _lap_start_z == 0.0:
			_lap_start_z = p.global_position.z
	else:
		var flat := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
		if flat.length() <= arrive:
			_step += 1
			_hop = 0
			_auto.reset_stuck()
			return false

	_auto.step_toward(target)
	_hop += ticks
	if _hop > TICKS_PER_HOP:
		if st.has("lap"):
			_ok("the loop corridor sent the player back at least once", false,
				"walked %d ticks up the loop, laps still %d" % [_hop, int(_level.call("loop_laps"))])
			_step += 1
			_hop = 0
			return false
		# One retry by backing to the previous waypoint (walk_dungeon.gd's rule): straight-line
		# steering can wedge on a jamb, and that is the harness, not the level.
		if not _retried.has(_step) and _step > 0 and _steps[_step - 1].has("walk"):
			_retried[_step] = true
			_step -= 1
			_hop = 0
			_auto.reset_stuck()
			return false
		_stalls += 1
		_ok("leg %d reached %s" % [_step, target], false, "timed out twice")
		_step += 1
		_hop = 0
		_auto.reset_stuck()
	return false


func _read_note(nm: String) -> void:
	var p: CharacterBody3D = _auto.player
	var note := _level.get_node_or_null(nm) as Node3D
	if note == null:
		_ok("note %s exists" % nm, false)
		_step += 1
		return
	_auto.stop()
	p.velocity = Vector3.ZERO
	p.call("ai_look_at", note.global_position)
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()
	var t: Node = p.call("ai_interact_target")
	var hit: bool = t == note or (t != null and note.is_ancestor_of(t))
	_ok("the interact ray finds %s from the walked approach" % nm, hit,
		"from %s, ray hit %s" % [p.global_position, t.name if t else "nothing"])
	if not hit:
		_step += 1
		return
	p.call("ai_interact")
	_read_pending = true


func _check(what: String) -> void:
	var p: CharacterBody3D = _auto.player
	match what:
		"loop_broken":
			_ok("reading the corridor note breaks the loop", bool(_level.call("loop_broken")))
		"no_more_laps":
			_ok("no further teleport after the note (walked to z %.1f)" % p.global_position.z,
				int(_level.call("loop_laps")) == 1 and p.global_position.z > 40.0,
				"laps %d" % int(_level.call("loop_laps")))
		"still_on_the_tiles":
			_ok("crossed the causeway without falling", _min_y > -0.6, "lowest y %.2f" % _min_y)
		"exit_locked_before_twist":
			var d := _level.get_node_or_null("ExitDoor")
			_ok("the exit is LOCKED before the twist note", d != null and not bool(d.call("_is_unlocked")))
		"twist_read":
			_ok("the twist note set GameState.twist_read",
				bool(root.get_node("GameState").get("twist_read")))
		"exit_unlocked_and_found":
			var d := _level.get_node_or_null("ExitDoor") as Node3D
			if d == null:
				_ok("ExitDoor exists", false)
				return
			_auto.stop()
			p.velocity = Vector3.ZERO
			p.call("ai_look_at", d.global_position)
			var cam := p.get_node_or_null("Camera3D") as Camera3D
			if cam:
				cam.force_update_transform()
			var t: Node = p.call("ai_interact_target")
			_ok("the interact ray finds the ExitDoor from the walked approach",
				t == d or (t != null and d.is_ancestor_of(t)), "hit %s" % (t.name if t else "nothing"))
			_ok("…and it is unlocked", bool(d.call("_is_unlocked")))
		_:
			_ok("unknown check " + what, false)


func _finish() -> bool:
	_ok("every leg walked under gravity", _stalls == 0, "%d stalls, %d physics ticks" % [_stalls, _total])
	if _auto:
		_auto.release()
	return _report()


func _report() -> bool:
	if _checks < 14:
		print("  FAIL only %d checks ran — did the route abort early?" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
