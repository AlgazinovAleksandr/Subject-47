extends SceneTree

# K2 (2026-09-13, the user's design): a wrong action in KONTUR is FATAL after ~20 s of rising
# dread — no 2D flash, no three-strike ledger. Asserts the shape: the sentence on screen, the
# objective rewritten, decay pinned, NO Screamer black panel at the moment of the wrong action,
# panic on an ease-in curve (well under half at 10 s), death between 19 and 21 s, and a control:
# a RIGHT action never condemns.
#
#   Godot --headless --path game --script res://tests/check_kontur_condemn.gd
#
# ⚠️ TIME-SCALED x4 after the first second so the 20 s costs ~5 s of wall clock.

const Scenes = preload("res://tests/lib/scenes.gd")

var _fails := 0
var _checks := 0
var _t := 0.0
var _phase := 0
var _k: Node = null
var _p: Node = null
var _saw_black := false
var _saw_flash_layer := false
var _saw_dark := false
var _dark_leak := false
var _saw_lunger := false
var _saw_edge_figure := false
var _saw_scrawl := false
var _panic_10 := -1.0
var _died_at := -1.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	Scenes.pin_rng(7)
	change_scene_to_file("res://scenes/kontur.tscn")


func _scrawl_on_screen() -> bool:
	for n in root.get_children():
		for c in n.get_children():
			if c is Label and (c as Label).text.contains("YOU WILL PAY"):
				return true
	return false


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	_t += delta
	var scr := root.get_node_or_null("Screamer")
	match _phase:
		0:
			if _t < 1.0:
				return false
			_k = current_scene
			_p = _k.get_node("Player")
			_ok("scene + player", _k != null and _p != null)
			# CONTROL first: a right action never condemns.
			_k.call("_pass_gate", "dark")
			_ok("CONTROL: passing a gate does not condemn", not bool(_k.get("_condemned")))
			_ok("nothing on the level references the retired flash", not _k.get_script().source_code.contains("flash_scare(FLASH_PATH"))
			# The wrong action.
			_k.call("_strike", "TEST — A WRONG BOTTLE")
			_ok("a wrong action condemns", bool(_k.get("_condemned")))
			_ok("the objective reads the sentence", String(root.get_node("GameState").get("current_objective")).contains("PAY"))
			_ok("decay is pinned for the rest of the run", bool(_p.call("has_no_decay")))
			_ok("a drone is playing on Master", _k.get_node_or_null("CondemnDrone") != null and (_k.get_node("CondemnDrone") as AudioStreamPlayer).playing)
			_t = 0.0
			_phase = 1
		1:
			# Watch the first real second: no Screamer black panel (the old flash), the scrawl up.
			if scr and scr.get("_black_panel") != null and (scr.get("_black_panel") as CanvasItem).visible:
				_saw_black = true
			if _scrawl_on_screen():
				_saw_scrawl = true
			if _t > 1.0:
				_ok("NO fullscreen flash at the moment of the wrong action", not _saw_black)
				_ok("the sentence is on the screen in red", _saw_scrawl)
				Engine.time_scale = 4.0
				_phase = 2
		2:
			var ct: float = float(_k.get("_condemn_t"))
			if _panic_10 < 0.0 and ct >= 10.0:
				_panic_10 = float(_p.call("get_panic_ratio"))
				_ok("panic is still well under half at 10 s (ease-in, not a ramp)", _panic_10 < 0.45, "%.2f" % _panic_10)
			if _k.get_node_or_null("CondemnFlash") != null:
				_saw_flash_layer = true
			if _k.get_node_or_null("CondemnFigure") != null:
				_saw_edge_figure = true
			# K2: the finale — every lamp at zero and the torch off while dark, then a
			# DeathLunger in the world when they return.
			if bool(_k.get("_condemn_dark")):
				_saw_dark = true
				var all_zero := true
				for entry in _k.get("_lights"):
					var lamp: OmniLight3D = entry[0]
					if is_instance_valid(lamp) and lamp.light_energy > 0.001:
						all_zero = false
				if not all_zero:
					_dark_leak = true
				if bool(_p.call("is_flashlight_on")):
					_dark_leak = true
			if _k.get_node_or_null("DeathLunger") != null:
				_saw_lunger = true
			if _died_at < 0.0 and scr and bool(scr.get("_is_triggering")):
				_died_at = ct
				Engine.time_scale = 1.0
				_ok("the run ends between 18.5 and 22 s", _died_at >= 18.5 and _died_at <= 22.0, "%.1f s" % _died_at)
				# K3 (2026-09-13): the sentence is STAGED — every channel fired on its clock.
				var b: Dictionary = _k.call("condemn_beats")
				_ok("K3: the whisper + roll landed in the first seconds", float(b.get("whisper", -1.0)) >= 0.0 and float(b.get("whisper", 99.0)) < 3.0, str(b))
				_ok("K3: the discordant bed came in at ~6 s", float(b.get("bed", -1.0)) >= 5.5 and float(b.get("bed", 99.0)) < 9.0)
				_ok("K3: figures stood at the room's edges (>= 2 spawned)", int(b.get("figures", 0)) >= 2, "%d" % int(b.get("figures", 0)))
				_ok("K3: ...and one was seen standing (CondemnFigure existed)", _saw_edge_figure)
				_ok("K3: the black/red cuts came, quickening (>= 4)", int(b.get("flashes", 0)) >= 4, "%d" % int(b.get("flashes", 0)))
				_ok("K3: ...and the cut overlay was on screen at some point", _saw_flash_layer)
				_ok("K3: the final figure at arm's length was attempted", bool(b.get("final", false)))
				_ok("K3: no fullscreen Screamer panel before the kill", not _saw_black)
				_ok("K2: the lights DIED at the finale (every lamp 0, torch off)", _saw_dark and not _dark_leak)
				_ok("K2: ...and RETURNED before the kill", bool(b.get("returned", false)))
				_ok("K2: ...with the figure standing in the world (DeathLunger)", _saw_lunger)
				_ok("K2: the kill came from the lunge, not the bar (died before the fallback)", _died_at < float(_k.get("CONDEMN_TIME")) + float(_k.get("CONDEMN_FALLBACK")) - 0.2)
				return _done()
			if ct > 26.0:
				Engine.time_scale = 1.0
				_ok("the bar kills between 19 and 21 s", false, "still alive at %.1f s" % ct)
				return _done()
	return false


func _done() -> bool:
	print("  %d checks, %d failed" % [_checks, _fails])
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true
