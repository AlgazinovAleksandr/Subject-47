extends SceneTree

# BS1 (2026-09-09): the black door blows the lights, the Passage goes torch-only, Object 12 charges
# the glass once in the dark, and the lights return at the Kitchen. This guard asserts the whole
# beat and — the property that keeps it safe — that the charge is INERT until gate 1 is passed, so
# check_kontur_entities (which never opens gate 1) still measures a still, ruleless occupant.
#
# ⚠️ It drives the real internal triggers (_on_gate1_chosen / _tick_cell_charge / _end_cell_blackout)
# rather than faking Area3D entry, because those ARE the shipping entry points. Panic is read off the
# real player, and the charge must move it by ZERO.
#
# CONTROL (runs first, on the fresh scene): standing on the cell with the blackout INACTIVE, the
# charge must not fire. If it does, the entities test's cell stare would trip it. Proven to fail:
# drop the `_blackout_active` guard in _tick_cell_charge and this control goes red.

var _k: Node = null
var _p: Node = null
var _env: Object = null
var _cell: Node = null
var _phase := 0
var _t := 0.0
var _fails := 0
var _panic_mark := 0.0


func _initialize() -> void:
	seed(7)   # KONTUR randomises; pin it like the other KONTUR guards
	change_scene_to_file("res://scenes/kontur.tscn")


func _ok(desc: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  OK        %s" % desc)
	else:
		_fails += 1
		print("  FAIL      %s   %s" % [desc, detail])


func _liner_energy() -> float:
	if _cell == null:
		return -1.0
	var liners: Array = _cell.get("_liners")
	if liners == null or liners.is_empty():
		return -1.0
	var mi: MeshInstance3D = liners[0][0]
	if not is_instance_valid(mi) or mi.material_override == null:
		return -1.0
	return mi.material_override.emission_energy_multiplier


func _ambient() -> float:
	if _env == null:
		return -1.0
	return _env.ambient_light_energy


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 1.6:
				return false
			_k = current_scene
			_p = _k.get_node_or_null("Player") if _k else null
			_env = _k.get("_env") if _k else null
			_cell = _k.get("_cell") if _k else null
			_ok("scene, player, env and cell all present",
				_k != null and _p != null and _env != null and _cell != null)
			if _p == null or _k == null or _cell == null or _env == null:
				return _done()

			# CONTROL — the charge is inert before gate 1.
			_p.set("global_position", Vector3(1.0, 0.1, 16.9))   # 1.75 m from the booth
			var pc: float = _p.call("get_panic_ratio")
			for _i in range(3):
				_k.call("_tick_cell_charge")
			_ok("CONTROL: the glass charge does NOT fire before gate 1 (entities test is safe)",
				_k.get("_cell_charged") == false)
			_ok("CONTROL: and it adds no panic while inactive",
				absf(_p.call("get_panic_ratio") - pc) < 0.0001)

			# Pre-state: the room is at its normal faint ambient and the booth is lit.
			_ok("ambient starts at DARK_AMBIENT (~0.02)", absf(_ambient() - 0.02) < 0.005,
				"ambient %.4f" % _ambient())
			_ok("a booth liner starts lit", _liner_energy() > 0.001,
				"liner energy %.3f" % _liner_energy())
			_phase = 1
			_t = 0.0
		1:
			# Fire gate 1 the way the black door does.
			_panic_mark = _p.call("get_panic_ratio")
			_k.call("_on_gate1_chosen", true)
			_phase = 2
			_t = 0.0
		2:
			if _t < 0.6:
				return false   # let the ambient tween (0.35 s) finish
			_ok("the black door armed the blackout", _k.get("_blackout_active") == true)
			_ok("every light but the torch is gone (ambient ~0)", _ambient() < 0.005,
				"ambient %.4f" % _ambient())
			_ok("the booth's own liner went dark", _liner_energy() < 0.001,
				"liner energy %.3f" % _liner_energy())
			_phase = 3
			_t = 0.0
		3:
			# The player reaches the booth in the dark; the charge fires once.
			_p.set("global_position", Vector3(1.0, 0.1, 16.9))
			_panic_mark = _p.call("get_panic_ratio")
			_k.call("_tick_cell_charge")
			_phase = 4
			_t = 0.0
		4:
			if _t < 0.3:
				return false
			_ok("Object 12 charged the glass", _k.get("_cell_charged") == true)
			_ok("the charge cost ZERO panic (cannot kill, no rule)",
				absf(_p.call("get_panic_ratio") - _panic_mark) < 0.0001,
				"delta %.4f" % (_p.call("get_panic_ratio") - _panic_mark))
			_ok("the player is still alive (no Screamer reload)", is_instance_valid(_p))
			_phase = 5
			_t = 0.0
		5:
			# Leaving the Passage for the Kitchen restores the light.
			_k.call("_end_cell_blackout")
			_phase = 6
			_t = 0.0
		6:
			if _t < 0.8:
				return false   # the restore tween is 0.6 s
			_ok("the blackout is cleared", _k.get("_blackout_active") == false)
			_ok("ambient is restored to ~0.02", absf(_ambient() - 0.02) < 0.005,
				"ambient %.4f" % _ambient())
			_ok("the booth liner is lit again", _liner_energy() > 0.001,
				"liner energy %.3f" % _liner_energy())
			return _done()
	return false


func _done() -> bool:
	print("\n--- result: %s ---" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
	return true
