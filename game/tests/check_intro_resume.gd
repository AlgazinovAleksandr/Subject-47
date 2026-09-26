extends SceneTree

# COMING BACK FROM THE LAB — the intro's back-door restore (the Intake Wing, 2026-09-24).
#
# spec/levels/README.md's contract: `save_progress()` on the way out, `_restore_progress()` on the
# way back. The intro implements it so that walking back through the Lab's back door does not
# replay the wake-up: the wing is built SOLVED and you stand in the airlock, facing the wing.
# Proves, with GameState set exactly as `go_back()` leaves it:
#   * the player is in the AIRLOCK, facing east (into calibration), on their feet and free
#   * all five wing doors stand open; every bulb burns; the ward's two tubes are lit; the torch is
#     usable; the exit is open
#   * nothing replays: no straps on the bed (they hang), no occupant, no breathing, no path glow,
#     no observer line spoken, the projector dark
#   * the level still sets the panic ceiling
#   * ⭐ (fourth hand playtest, 2026-09-25) the airlock hatch is SHUT and dark, nobody behind it, and
#     the patient does not replay — not even if the AirlockDoor's `opened` arrived again; calibration's
#     round two (SERIES D) is not replayed either
# Plus the other half: `save_progress()` returns the beats the level really passed.
#
#   Godot --headless --path game --script res://tests/check_intro_resume.gd

const SETTLE := 2.5

var _t := 0.0
var _fails: Array[String] = []
var _checks := 0
var _done := false
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_gs.set("is_ending", false)
	_gs.set("level_progress", {0: {"beats": ["straps", "torch", "blackout", "calibrated", "proceed"], "note_read": true}})
	_gs.set("entered_from_ahead", true)
	_gs.set("current_level", 0)
	change_scene_to_file("res://scenes/intro_room.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


var _phase := 0


func _process(delta: float) -> bool:
	_t += delta
	if _done or _t < SETTLE:
		return _done
	if _phase == 1:
		if _t < SETTLE + 1.6:
			return false
		var s2 := current_scene
		_ok("…and even a second `opened` does not replay the patient (no slam, no words, no scream)",
			(s2.get("_hatch_log") as Array).is_empty(), str(s2.get("_hatch_log")))
		return _finish()
	_phase = 1
	var s := current_scene
	var p := s.get_node("Player") as CharacterBody3D
	var pos := p.global_position
	_ok("you come back IN THE AIRLOCK", pos.x > -7.0 and pos.x < -4.0 and pos.z > -20.0 and pos.z < -17.0, "at %v" % pos)
	var fwd := -p.global_basis.z
	_ok("…facing the wing (east, into calibration)", fwd.x > 0.9, "forward %v" % fwd)
	_ok("…on your feet and free", not p.is_input_frozen() and pos.y < 0.3)
	for n in ["CellDoor", "HallDoor", "WardEntryDoor", "WardDoor", "AirlockDoor"]:
		_ok("%s stands open" % n, s.get_node(n).call("is_open") == true)
	var dark := 0
	for b in s.get("_bulbs"):
		if (b[0] as Light3D).light_energy < 0.05:
			dark += 1
	_ok("every bulb in the wing burns", dark == 0, "%d dark" % dark)
	var lit := 0
	for c in s.get_children():
		if c is OmniLight3D and String(c.name).begins_with("CeilingLight") and (c as OmniLight3D).light_energy > 0.1:
			lit += 1
	_ok("the ward is lit (two tubes; the one over the table stays dead)", lit == 2, "%d lit" % lit)
	_ok("the torch is yours", p.get("_flashlight_locked") == false)
	_ok("the exit is open", s.get_node("ExitDoor").call("_is_unlocked") == true)
	_ok("no occupant on your bed", s.get_node_or_null("CellOccupant") == null)
	_ok("no breathing in the ward", s.get_node_or_null("FarBreath") == null)
	_ok("no path glow", (s.get("_path_glow_lights") as Array).is_empty())
	_ok("the observer says NOTHING", (s.get("_captions") as Array).is_empty(), str(s.get("_captions")))
	_ok("the projector is dark", float(s.get_node("ProjectorScary").get("scare_intensity")) == 0.0)
	var hung := 0
	for pv in (s.get("_strap_visuals") as Array):
		for e in pv:
			if absf((e[0] as Node3D).rotation.z) > 3.0:
				hung += 1
	_ok("the straps hang off the bed, released (4 loose ends)", hung == 4, "%d hung" % hung)
	_ok("the glimpse bed is already empty", (s.get_children().filter(func(c): return String(c.name).begins_with("SheetedForm_"))).size() == 1)
	_ok("the panic ceiling is still set", is_equal_approx(float(p.call("get_panic_ceiling")), 0.6))
	var saved: Dictionary = s.call("save_progress")
	_ok("save_progress() reports the beats", (saved.get("beats", []) as Array).has("proceed"), str(saved))
	var c: Dictionary = s.get_script().get_script_constant_map()
	_ok("the airlock hatch is SHUT — the shutter down over the bars",
		absf((s.get_node("HatchShutter") as Node3D).position.y - float(c["HATCH_MID"])) < 0.01,
		"shutter y %.2f" % (s.get_node("HatchShutter") as Node3D).position.y)
	_ok("…dark, and nobody behind it", (s.get_node("HatchLight") as OmniLight3D).light_energy == 0.0
		and not (s.get_node("PatientFace") as Node3D).visible)
	_ok("…settled: it will not fire", int(s.get("_hatch_state")) == 3 and (s.get("_hatch_log") as Array).is_empty())
	_ok("calibration's round two is not replayed (SERIES D)", int(s.get("_calib_state")) == 5
		and not bool(s.get("_series_d_running")) and int(s.get("_slide_i")) < 0
		and s.get_node_or_null("StandHint") == null)
	s.call("_on_airlock_opened")
	return false


func _finish() -> bool:
	_done = true
	_gs.set("entered_from_ahead", false)
	_gs.set("level_progress", {})
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
