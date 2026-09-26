extends SceneTree

# THE TWIST ENDING'S ROOM — the ward ALONE, sealed (the Intake Wing, 2026-09-24).
#
# The ending reloads intro_room.tscn with GameState.is_ending. Since the wing, intro_room.gd builds
# `[WARD]` with no doorways in that case, so the corrupted ward is exactly the sealed room it always
# was, and `_corrupt_room()` runs unchanged. What this proves, by physics wherever physics can:
#   * both of the ward's wing doorways — the corridor's (-3, 9) and calibration's (0, -9) — are
#     SOLID WALL, by ray, at two heights
#   * none of the wing exists: no cell, no hall, no calibration, no airlock, no wing doors, no
#     finds, no projector
#   * the ending note is the ending's, the exit door is gone, the planks and the red throb are there
#   * the ward is still unloseable (the panic ceiling) and there is no switch to press
# The plank placement itself stays in check_intro_geometry.gd.
#
#   Godot --headless --path game --script res://tests/check_intro_ending.gd

const SETTLE := 2.0

var _t := 0.0
var _fails: Array[String] = []
var _checks := 0
var _done := false


func _initialize() -> void:
	var gs := root.get_node_or_null("GameState")
	gs.set("is_ending", true)
	gs.set("entered_from_ahead", false)
	change_scene_to_file("res://scenes/intro_room.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _ray(scene: Node, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.hit_from_inside = true
	return (scene.get_node("Player") as Node3D).get_world_3d().direct_space_state.intersect_ray(q)


func _process(delta: float) -> bool:
	_t += delta
	if _done or _t < SETTLE:
		return _done
	_done = true
	var s := current_scene
	for spec in [["the corridor doorway (-3, 9)", Vector3(-3.0, 0, 7.5), Vector3(-3.0, 0, 10.5)],
			["the calibration doorway (0, -9)", Vector3(0.9, 0, -7.5), Vector3(0.9, 0, -10.5)],
			["the calibration doorway's centre", Vector3(0.0, 0, -7.2), Vector3(0.0, 0, -10.5)]]:
		for y in [0.8, 2.4]:
			var a: Vector3 = spec[1] + Vector3(0, y, 0)
			var b: Vector3 = spec[2] + Vector3(0, y, 0)
			var h := _ray(s, a, b)
			var who: String = str(h["collider"].name) if not h.is_empty() else "NOTHING"
			_ok("%s is sealed at y %.1f" % [spec[0], y], not h.is_empty() and h["collider"] is CSGShape3D, "hit %s" % who)
	for n in ["CellDoor", "HallDoor", "WardEntryDoor", "WardDoor", "AirlockDoor", "Strap_0", "IssuedTorch",
			"HallCabinet", "WardCabinet0", "ProjectorScary", "ForbiddenTray", "CorridorDoor_0", "LightSwitch"]:
		_ok("the wing is not built: no %s" % n, s.get_node_or_null(n) == null)
	var rooms := 0
	for c in s.get_node("WingBuilder").get_children():
		if String(c.name).ends_with("_Floor"):
			rooms += 1
	_ok("RoomBuilder built exactly ONE room (the ward)", rooms == 1, "%d floors" % rooms)
	var note := s.get_node_or_null("Note")
	_ok("the note on the table is the ENDING's", note != null
		and String(note.get("note_text")).begins_with("This is not an experiment."))
	_ok("the exit door is gone (boarded)", s.get_node_or_null("ExitDoor") == null)
	_ok("…its casing survives for the planks", s.get_node_or_null("DoorJambL") != null)
	_ok("the red throb is running", s.get("_red_light") != null)
	var player := s.get_node("Player")
	_ok("the ending ward is still unloseable (the 0.6 ceiling)",
		is_equal_approx(float(player.call("get_panic_ceiling")), 0.6))
	root.get_node("GameState").set("is_ending", false)
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
