extends SceneTree

# BS2 (2026-09-09): Gate 6 is three phones — yellow / blue / green — one ringing at a time. E answers,
# Space smashes (with the hammer). Smash yellow and blue, answer or smash green. This guard drives the
# real handlers and asserts every branch, the gate completion, and that only the RINGING phone charges.
#
# ⚠️ Drives the phones' own signals/methods (the shipping paths), not fakes. Panic is read off the
# real player. It does NOT actually fire the yellow screamer (that reloads the scene); the fatal role
# is asserted structurally and covered by the hand playtest.

var _k: Node = null
var _p: Node = null
var _phase := 0
var _t := 0.0
var _fails := 0
var _panic_mark := 0.0


func _initialize() -> void:
	seed(7)
	change_scene_to_file("res://scenes/kontur.tscn")


func _ok(desc: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  OK        %s" % desc)
	else:
		_fails += 1
		print("  FAIL      %s   %s" % [desc, detail])


func _phone(colour: String) -> Node:
	return _k.get_node_or_null("Phone_" + colour) if _k else null


func _resolved(colour: String) -> bool:
	var ph := _phone(colour)
	return ph != null and bool(ph.call("is_resolved"))


func _smash(colour: String) -> void:
	var ph := _phone(colour)
	if ph:
		ph.set("smashable", true)
		ph.call("secondary_interact")


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 1.6:
				return false
			_k = current_scene
			_p = _k.get_node_or_null("Player") if _k else null
			_ok("scene + player present", _k != null and _p != null)
			if _k == null or _p == null:
				return _done()

			# Structure.
			var y := _phone("yellow"); var b := _phone("blue"); var g := _phone("green")
			_ok("three coloured phones present", y != null and b != null and g != null)
			if y == null or b == null or g == null:
				return _done()
			# ⚠️ Probe by METHOD, never `is RotaryPhone` — naming the class_name in a --script test
			# compiles rotary_phone.gd (which references the GameState autoload) before autoloads
			# exist, and the broken compile then stops the SCENE building any phones at all (X29).
			_ok("all three answer the phone API",
				y.has_method("set_ringing") and b.has_method("secondary_interact") and g.has_method("is_resolved"))
			_ok("all three are controller-driven (externally_driven)",
				bool(y.get("externally_driven")) and bool(b.get("externally_driven")) and bool(g.get("externally_driven")))
			_ok("their tints are the three distinct colours",
				(y.get("tint") as Color) != (b.get("tint") as Color) and (b.get("tint") as Color) != (g.get("tint") as Color))
			# The roles.
			_ok("yellow and blue are SMASH, green is ANSWER",
				_k.call("_slot", "yellow")["role"] == "smash" and _k.call("_slot", "blue")["role"] == "smash" and _k.call("_slot", "green")["role"] == "answer")

			# ⚠️ SPREAD ACROSS ROOMS (2026-09-09, captures #6/#7). The single Records "LINE
			# DISCIPLINE" memo was replaced with three per-colour notes, one per room (green in
			# the Passage, yellow in the Kitchen, blue in Records). Assert all three exist as real
			# note.gd pages stating each colour's fate.
			var have_green := false
			var have_yellow := false
			var have_blue := false
			for n in _k.get_children():
				var txt = n.get("note_text") if n else null
				if txt == null:
					continue
				var s := String(txt).to_upper()
				if s.find("GREEN LINE") >= 0:
					have_green = true
				if s.find("YELLOW LINE") >= 0:
					have_yellow = true
				if s.find("BLUE LINE") >= 0:
					have_blue = true
			_ok("the phone rule is three per-colour notes spread across rooms",
				have_green and have_yellow and have_blue,
				"green=%s yellow=%s blue=%s" % [have_green, have_yellow, have_blue])

			# K4: before the hammer the prompt is E only; after it, both keys are named.
			_ok("prompt before the hammer names E only", String(y.call("prompt_text")).find("SPACE") < 0,
				String(y.call("prompt_text")))
			# Arm smashing (the player has the hammer).
			_k.call("_arm_phones")
			_ok("prompt with the hammer names E AND SPACE",
				String(y.call("prompt_text")).find("E") >= 0 and String(y.call("prompt_text")).find("SPACE") >= 0,
				String(y.call("prompt_text")))
			# …and the HUD label carries it through the shipping ray.
			var ypos: Vector3 = (y as Node3D).global_position
			_p.global_position = ypos + Vector3(0, 0, 1.3) - Vector3(0, ypos.y, 0) + Vector3(0, 0.1, 0)
			_p.call("ai_look_at", ypos)
			var tgt = _p.call("ai_interact_target")
			var lbl: Label = _p.get("interact_label")
			_ok("aiming at the yellow phone puts BOTH keys on the HUD", tgt == y and lbl != null and lbl.text.find("SPACE") >= 0,
				"target=%s label=%s" % [tgt, lbl.text if lbl else "-"])

			# The ring cycle picks exactly one live phone.
			_k.call("_tick_phones", 0.1)
			_ok("the cycle rings exactly one phone", _k.get("_ring_cur") != null)
			_phase = 1
			_t = 0.0
		1:
			# GREEN answered -> resolved (the hint), gate not yet done.
			_k.call("_on_phone_answered", "green")
			_ok("answering green resolves it", _resolved("green"))
			_ok("but the gate is not passed yet (yellow/blue outstanding)", _k.get("_gates")["phone"] == false)

			# BLUE answered -> big panic, NOT resolved (must still be smashed), one-shot hallucination.
			_panic_mark = _p.call("get_panic_ratio")
			_k.call("_on_phone_answered", "blue")
			_ok("answering blue spikes panic toward ~90%", _p.call("get_panic_ratio") >= 0.5,
				"ratio %.2f" % _p.call("get_panic_ratio"))
			_ok("blue is NOT resolved by answering (it still needs smashing)", not _resolved("blue"))
			_ok("the hallucination is one-shot (flag set)", bool(_k.get("_blue_hallucinated")))
			_phase = 2
			_t = 0.0
		2:
			if _t < 0.2:
				return false
			# SMASH blue and yellow -> gate passes.
			_smash("blue")
			_ok("smashing blue resolves it", _resolved("blue"))
			_ok("gate still not done (yellow outstanding)", _k.get("_gates")["phone"] == false)
			_smash("yellow")
			_ok("smashing yellow resolves it", _resolved("yellow"))
			_ok("with all three resolved, the phone gate passes", _k.get("_gates")["phone"] == true)

			# Once resolved, the cycle rings nothing.
			_k.call("_tick_phones", 0.1)
			_ok("nothing rings once the gate is passed", _k.get("_ring_cur") == null)
			# K2 (2026-09-14): answering YELLOW is an in-world lunge that ends in the funnel.
			# Driven last, because trigger() reloads the scene. (The yellow phone is smashed
			# by now; the level's handler is what is under test, not the ring.)
			var scr := root.get_node("/root/Screamer")
			_k.call("_on_phone_answered", "yellow")
			_ok("K2: the yellow answer starts a LUNGE, not the 2D flash", bool(scr.call("is_lunging")))
			_ok("K2: the player is pinned for it", bool(_p.call("is_input_frozen")))
			_ok("K2: a DeathLunger stands in the world", _k.get_node_or_null("DeathLunger") != null)
			_ok("K2: ...with the level's sting AT it", _k.get_node_or_null("DeathLunger/LungeSting") != null)
			_ok("K2: ...glowing (it must read in a dark room)", _k.get_node_or_null("DeathLunger/LungerLight") != null)
			_ok("K2: no Screamer panel yet", not (scr.get("_black_panel") as CanvasItem).visible)
			_t = 0.0
			_phase = 99
		99:
			var scr2 := root.get_node("/root/Screamer")
			if bool(scr2.get("_is_triggering")):
				_ok("K2: the lunge ends in Screamer.trigger() within 1.5 s (%.2f s)" % _t, _t <= 1.5)
				return _done()
			if _t > 2.5:
				_ok("K2: the lunge ends in Screamer.trigger()", false, "still not triggering at %.1f s" % _t)
				return _done()
	return false


func _done() -> bool:
	print("\n--- result: %s ---" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
	return true
