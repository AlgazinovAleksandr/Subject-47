extends SceneTree

# The intro room's exit must stay sealed until the player has BOTH thrown the light
# switch and read the opening note (BACKLOG #12).
#   Godot --headless --path game --script res://tests/check_intro_gate.gd
#
# Why this matters more than it looks: that note is where the player is told they are
# Subject 47 (which KONTUR's roster gate used to rely on), told the rules the rest of
# the game enforces, and warned not to answer a ringing phone three levels before they
# meet one. Walking straight past it turns several later deaths into arbitrary cruelty.
#
# ⭐ 2026-09-24, THE INTAKE WING: one ledger (`intro_room.gd:_advance()` / `_refresh_doors()`) now
# decides every door. This file checks its synchronous half — the ward door rides the same switch +
# note gate as the exit, and the torch opens the ward entry. (The straps -> cell door half is timed,
# and check_intro_beats.gd walks it.)
#
# Everything below drives the real interact() path and then asks door.gd's own
# _is_unlocked() whether it would open — Issue 16's lesson restated: assert that
# FAILING the gate changes the outcome, not merely that the gate fires.

var _frame := 0
var _fails := 0
var _gs: Node
# ⚠️ The switch does not exist at scene load. intro_room.gd spawns it from
# _on_wakeup_finished(), i.e. only after the wake-up camera tween completes, so a test
# that samples at a fixed early frame finds no switch and "fails" for the wrong reason.
# Poll for it instead of guessing a frame number.
const SWITCH_WAIT_FRAMES := 900


func _initialize() -> void:
	change_scene_to_file("res://scenes/intro_room.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 10:
		return false
	var scene := current_scene
	_gs = root.get_node_or_null("/root/GameState")
	# A previous test in the same session may have left the flag set; this scene is
	# entered fresh at the start of a run, so clear it to model that.
	if _gs:
		_gs.set("intro_note_read", false)

	var door := scene.get_node_or_null("ExitDoor")
	var note := scene.get_node_or_null("Note")
	var switch_node := scene.get_node_or_null("LightSwitch")
	if switch_node == null and _frame < SWITCH_WAIT_FRAMES:
		return false     # still waking up — see SWITCH_WAIT_FRAMES
	_ok("ExitDoor exists", door != null)
	_ok("Note exists", note != null)
	_ok("light switch appears after the wake-up sequence", switch_node != null,
		"frame %d" % _frame)
	if not (door and note and switch_node):
		quit(1)
		return true

	var ward := scene.get_node_or_null("WardDoor")
	var entry := scene.get_node_or_null("WardEntryDoor")
	var torch := scene.get_node_or_null("IssuedTorch")
	_ok("the wing's WardDoor, WardEntryDoor and torch exist", ward != null and entry != null and torch != null)
	if not (ward and entry and torch):
		quit(1)
		return true

	print("--- nothing done yet ---")
	_ok("the ward entry is locked until the torch is issued", entry.get("locked") == true)
	_ok("the ward's far door is locked, pointing at the switch", ward.get("locked") == true
		and String(ward.get("locked_message")).to_lower().contains("switch"))
	torch.call("interact")
	_ok("taking the torch unlocks the ward entry", entry.get("locked") == false)
	_ok("door is locked", door.call("_is_unlocked") == false)
	_ok("message points at the switch",
		String(door.get("locked_message")).to_lower().contains("switch"),
		"'%s'" % door.get("locked_message"))

	# The switch STICKS on the first press (2026-07-28, "the ward is occupied"): one tube
	# at the far end stutters alight for 0.4 s and dies. Asserted here because it is a gate
	# behaviour, not just dressing — if a stuck press threw the switch, the beat is gone.
	print("--- switch pressed ONCE: it sticks ---")
	_ok("the switch wants more than one press",
		int(switch_node.get("presses_needed")) > 1,
		"presses_needed = %s" % switch_node.get("presses_needed"))
	switch_node.call("interact")
	_ok("a stuck press does NOT throw it", door.call("_is_unlocked") == false)
	_ok("and the message still points at the switch",
		String(door.get("locked_message")).to_lower().contains("switch"),
		"'%s'" % door.get("locked_message"))

	print("--- switch thrown, note still unread ---")
	for _i in range(int(switch_node.get("presses_needed"))):
		switch_node.call("interact")
	_ok("door is STILL locked", door.call("_is_unlocked") == false,
		"<- BACKLOG #12: this used to open here")
	_ok("message now points at the note",
		String(door.get("locked_message")).to_lower().contains("note"),
		"'%s'" % door.get("locked_message"))
	_ok("…and so does the ward's far door, still locked", ward.get("locked") == true
		and String(ward.get("locked_message")).to_lower().contains("note"))

	print("--- note read ---")
	note.call("interact")
	_ok("GameState.intro_note_read set", _gs != null and _gs.get("intro_note_read") == true)
	_ok("…the ward's far door opens", ward.get("locked") == false)
	# ⭐ Phase 5: the exit is in the AIRLOCK now, and it waits for calibration's "You may proceed."
	# (check_intro_beats.gd walks calibration on the real paths and sees it open.)
	_ok("…but the exit does NOT — calibration comes first", door.call("_is_unlocked") == false,
		"'%s'" % door.get("locked_message"))
	var airlock := scene.get_node_or_null("AirlockDoor")
	_ok("…and the airlock door is locked until the observers are satisfied",
		airlock != null and airlock.get("locked") == true)

	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
