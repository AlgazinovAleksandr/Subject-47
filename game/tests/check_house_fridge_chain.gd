extends SceneTree

# H2 (2026-09-13): the House's third digit is on the head in the CHAINED fridge.
# ⭐ 2026-09-24 (the Porch pass): the bolt cutters are no longer under the Bedroom bed — they come
# out of the watermelon the porch guillotine cuts, onto the deck boards (no basket since
# 2026-09-24 c, and the guillotine needs its blade from the forest first). This file only needs
# the cutters IN HAND, so it puts the guillotine in its CUT state by the level's own restore path
# (blade mounted — a cut fruit implies it) and then takes the cutters through the shipping E ray;
# `check_house_porch.gd` walks the whole chain that gets them there, blade walk included.
#
#   Godot --headless --path game --script res://tests/check_house_fridge_chain.gd
#
#   * the Bedroom wall note is gone; SAFE_NOTES_TOTAL is still 3
#   * E on the chained fridge opens nothing (and the chain is still there)
#   * nothing is under the Bedroom bed any more; the cutters lie on the deck in front of the
#     guillotine once the fruit is cut, and the shipping ray takes them from there
#   * with the cutters in hand E cuts the chain; the fridge then opens; looking at the head for
#     HEAD_READ_TIME registers SafeNote_Head and archives it
#   * a snapshot round trip carries fridge_chained / cutters_held / the head digit

const Scenes = preload("res://tests/lib/scenes.gd")

var _fails := 0
var _checks := 0
var _t := 0.0
var _phase := 0
var _lvl: Node = null
var _p: Node = null
var _fridge: Node = null


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	Scenes.pin_rng(3)
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _stand(pos: Vector3, look: Vector3) -> void:
	_p.set("velocity", Vector3.ZERO)
	_p.global_position = pos
	_p.call("ai_look_at", look)


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	_t += delta
	match _phase:
		0:
			if _t < 1.0:
				return false
			_lvl = current_scene
			_p = _lvl.get_node("Player")
			_fridge = _lvl.get_node_or_null("Fridge")
			_ok("scene, player, fridge", _lvl != null and _p != null and _fridge != null)
			_ok("the Bedroom wall note is gone", _lvl.get_node_or_null("SafeNote_Bedroom") == null)
			_ok("SAFE_NOTES_TOTAL is still 3", int(_lvl.get("SAFE_NOTES_TOTAL")) == 3)
			_ok("the fridge starts chained", bool(_fridge.call("is_chained")) and _fridge.get_node_or_null("Chain") != null)
			_ok("the chain has links and a padlock",
				_fridge.get_node_or_null("Chain/Padlock") != null and _fridge.get_node("Chain").get_child_count() >= 9)
			_ok("the head carries the digit texture",
				ResourceLoader.exists(String(_fridge.get("THING_TEX_DIGIT"))))
			# E on the chained fridge: nothing opens.
			_fridge.call("interact")
			_ok("E on the chained fridge opens nothing", not bool(_fridge.call("is_open")))
			_ok("…and the chain is still on it", _fridge.get_node_or_null("Chain") != null)
			# The cutters: not under the bed any more (the Porch pass).
			_ok("nothing lies under the Bedroom bed any more", _lvl.get_node_or_null("BoltCutters") == null)
			var g := _lvl.get_node_or_null("Guillotine")
			_ok("the porch guillotine exists", g != null)
			if g == null:
				return _done()
			# Put the porch in the state the chain leaves it in — the level's own restore path
			# (window burst silently, blade mounted, fruit cut, cutters on the deck), never a
			# hand-built copy.
			_lvl.get_node("HouseWindow").call("break_pane", false)
			_lvl.set("_melon_state", "cut")
			_lvl.set("_blade_state", "mounted")
			g.call("restore", "cut", false, true)
			var c := g.call("cutters_node") as Node3D
			_ok("the cutters lie on the deck in front of the guillotine", c != null
				and c.global_position.y < 0.05, str(c.global_position.snappedf(0.01)) if c else "none")
			if c == null:
				return _done()
			# From the front of the guillotine, on the deck, looking down at them.
			var front: Vector3 = (g as Node3D).global_transform.basis.z
			_stand((g as Node3D).global_position + front * 1.2 + Vector3(0, 0.1, 0), c.global_position)
			var tgt = _p.call("ai_interact_target")
			_ok("…and the shipping ray finds them (or the guillotine that hands them over)",
				tgt == c or tgt == g, str(tgt))
			_p.call("ai_interact")
			_t = 0.0
			_phase = 1
		1:
			if _t < 0.3:
				return false
			_ok("E takes them and the HUD carries them", bool(_lvl.get("_cutters_held"))
				and String(root.get_node("GameState").get("carried_item")) == "bolt cutters",
				"carried '%s'" % root.get_node("GameState").get("carried_item"))
			# Cut the chain.
			_fridge.call("interact")
			_ok("with the cutters, E cuts the chain", not bool(_fridge.call("is_chained")))
			_ok("…and the carried line clears", String(root.get_node("GameState").get("carried_item")) == "")
			_t = 0.0
			_phase = 2
		2:
			if _t < 0.8:
				return false
			_ok("the chain is gone from the fridge", _fridge.get_node_or_null("Chain") == null)
			_fridge.call("interact")
			_ok("the fridge now opens", bool(_fridge.call("is_open")))
			_t = 0.0
			_phase = 3
		3:
			if _t < 1.2:
				return false
			# Read the head: stand in front of the open fridge looking at the head.
			var head: Vector3 = _fridge.call("thing_position")
			# Toward the middle of the Kitchen — that is the side the door opens onto.
			var kc: Vector3 = (_lvl.get("_builder") as RoomBuilder).room_center("Kitchen")
			var fwd: Vector3 = Vector3(kc.x - head.x, 0.0, kc.z - head.z).normalized()
			_stand(head + fwd * 1.2 - Vector3(0, head.y - 0.1, 0), head)
			_t = 0.0
			_phase = 4
		4:
			_lvl.call("_tick_head_digit", delta)
			if _t < 1.6:
				return false
			_ok("looking at the head for a second registers the digit",
				(_lvl.get("_safe_notes_read") as Array).has("SafeNote_Head"))
			var journal: Array = root.get_node("GameState").get("journal")
			var archived := false
			for e in journal:
				if str(e).contains("forehead"):
					archived = true
			_ok("…and it is archived in the journal", archived)
			# Snapshot round trip.
			var snap: Dictionary = _lvl.call("save_progress")
			_ok("the snapshot says the fridge is unchained", snap.get("fridge_chained", true) == false)
			_ok("…and the head digit is in the notes list", (snap.get("safe_notes", []) as Array).has("SafeNote_Head"))
			return _done()
	return false


func _done() -> bool:
	print("  %d checks, %d failed" % [_checks, _fails])
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true
