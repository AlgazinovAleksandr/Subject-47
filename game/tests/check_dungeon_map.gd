extends SceneTree

# THE NIGHTMARE's found map (dungeon_map_ui.gd, 2026-09-12).
#
#   Godot --headless --path game --script res://tests/check_dungeon_map.gd
#
# What it asserts: the M action exists; the map is inert until the folded plan is taken through
# the SHIPPING interact ray in the Antechamber; it opens without pausing; it draws exactly the
# rooms the player has stood in and grows as they walk; it refuses while a note is open; the
# UI source never reads the player's position (the whole reason it is allowed to exist — the
# design doc rejected a GPS map); the snapshot carries it.

const SEED := 101

var _fails := 0
var _checks := 0
var _stage := 0
var _settle := 0
var _level: Node = null
var _p: CharacterBody3D = null
var _map = null
var _started := false
var _ante := Vector3.ZERO
var _drawn_before := 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var gs := root.get_node_or_null("GameState")
		if gs:
			gs.call("save_level_progress", 7, {"layout_seed": SEED, "content_seed": SEED * 31 + 7})
		change_scene_to_file("res://scenes/dungeon.tscn")
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_map"):
			print("  FAIL dungeon.tscn did not load")
			_fails += 1
			return _report()
		_p = _level.get_node("Player")
		_map = _level.call("get_map")
		_ante = _level.get("ANTE_ORIGIN")
		_stage = 1
		_settle = 0
		return false

	match _stage:
		1:
			_ok("the M action exists", InputMap.has_action("map"))
			_ok("the map UI exists", _map != null)
			_source_check()
			# Inert before the pickup.
			_map.call("toggle")
			_ok("M does nothing before the plan is found", not bool(_map.call("is_open")))
			# Take it through the shipping ray: stand at the rack, aim at the sheet.
			var sheet: Vector3 = _ante + Vector3(2.6, 0.93, -2.4) + Vector3(0.55, 0, 0.1)
			_place(_ante + Vector3(1.4, 0.1, -1.0), sheet)
			_stage = 2
			_settle = 0
		2:
			if _settle < 4:
				return false
			var tgt = _p.call("ai_interact_target")
			_ok("the shipping ray finds the folded plan", tgt != null and String(tgt.name) == "MapPickup",
				"hit %s" % (str(tgt.name) if tgt else "nothing"))
			_p.call("ai_interact")
			_stage = 3
			_settle = 0
		3:
			if _settle < 3:
				return false
			_ok("the plan is found", bool(_level.get("_map_found")) and bool(_map.call("is_found")))
			_ok("the pickup is gone", not is_instance_valid(_level.get_node_or_null("MapPickup")))
			# Into the dungeon: rooms are drawn as they are walked.
			var gen = _level.call("get_gen")
			_level.set("_in_dungeon", true)
			_p.global_position = gen.room_center_world(gen.spawn_room) + Vector3(0, 0.1, 0)
			_p.force_update_transform()
			_stage = 4
			_settle = 0
		4:
			if _settle < 4:
				return false
			_map.call("toggle")
			_ok("M opens the map after the pickup", bool(_map.call("is_open")))
			_ok("...without pausing the tree", not paused)
			var seen: Array = _level.call("rooms_seen")
			_drawn_before = int(_map.call("drawn_room_count"))
			_ok("it draws exactly the rooms walked so far", _drawn_before == seen.size() and seen.size() >= 1,
				"%d drawn, %d seen" % [_drawn_before, seen.size()])
			# Walk into a neighbouring room.
			var gen = _level.call("get_gen")
			var adj: Dictionary = gen.adjacency()
			var nxt: String = (adj.get(gen.spawn_room, []) as Array)[0]
			_p.global_position = gen.room_center_world(nxt) + Vector3(0, 0.1, 0)
			_p.force_update_transform()
			_stage = 5
			_settle = 0
		5:
			if _settle < 4:
				return false
			var seen: Array = _level.call("rooms_seen")
			var drawn: int = int(_map.call("drawn_room_count"))
			_ok("a new room walked is a new room drawn", drawn == _drawn_before + 1 and drawn == seen.size(),
				"%d -> %d" % [_drawn_before, drawn])
			_map.call("close")
			# Refused while a note is open.
			root.get_node("NoteUI").call("show_note", "test")
			_ok("refused while a note is open", not bool(_map.call("can_toggle")))
			root.get_node("NoteUI").call("_close")
			_stage = 6
			_settle = 0
		6:
			if _settle < 3:
				return false
			_ok("...and allowed again once it is closed", bool(_map.call("can_toggle")))
			var snap: Dictionary = _level.call("save_progress")
			_ok("the snapshot carries map_found", bool(snap.get("map_found", false)))
			_ok("the snapshot carries rooms_seen", (snap.get("rooms_seen", []) as Array).size() >= 2)
			return _report()
	return false


func _source_check() -> void:
	var f := FileAccess.open("res://scripts/dungeon_map_ui.gd", FileAccess.READ)
	var txt: String = f.get_as_text() if f else ""
	_ok("the map UI never reads a world position (no GPS: the design doc's Issue 34)",
		txt != "" and not txt.contains("global_position") and not txt.contains("global_transform")
		and not txt.contains("get_node(\"Player\")") and not txt.contains("room_at("))


func _place(feet: Vector3, look_at: Vector3) -> void:
	_p.global_position = feet
	_p.velocity = Vector3.ZERO
	var cam := _p.get_node("Camera3D") as Camera3D
	var eye: Vector3 = feet + Vector3(0, 1.55, 0)
	var to: Vector3 = look_at - eye
	_p.rotation.y = atan2(-to.x, -to.z)
	cam.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	_p.set("_pitch", cam.rotation.x)
	_p.force_update_transform()


func _report() -> bool:
	if _checks < 12:
		print("  FAIL only %d checks ran" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
