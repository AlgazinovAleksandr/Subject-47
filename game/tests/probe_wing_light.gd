extends SceneTree
# Does _light_the_wing() actually leave the wing lit, PAST the fade?
# ⚠️ Sample AFTER WING_LIGHT_FADE (1.5 s), not during — the bug this exists for is that a tween
# won for 1.5 s and _drive_lights() re-zeroed everything the moment it finished.
var _t := 0.0
var _stage := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/level_1.tscn")
func _lamps() -> Array:
	var out: Array = []
	for c in current_scene.get_children():
		if c is OmniLight3D and String(c.name).begins_with("Lamp_"):
			out.append(c)
	return out
func _wing() -> Array:
	var wr: Array = current_scene.get("WING_ROOMS")
	var out: Array = []
	for l in _lamps():
		if wr.has(String(l.name).trim_prefix("Lamp_")): out.append(l)
	return out
func _process(d: float) -> bool:
	_t += d
	if current_scene == null: return false
	match _stage:
		0:
			if _t < 3.0: return false
			print("power_on=%s  wing lamps=%d" % [current_scene.get("_power_on"), _wing().size()])
			current_scene.call("_light_the_wing")
			_t = 0.0; _stage = 1
		1:
			if _t < 0.5: return false
			var lit := 0
			for l in _wing(): if l.light_energy > 0.01: lit += 1
			print("t+0.5s (mid-fade): %d of %d wing lamps burning" % [lit, _wing().size()])
			_t = 0.0; _stage = 2
		2:
			if _t < 4.0: return false
			var lit2 := 0
			var worst := 999.0
			for l in _wing():
				if l.light_energy > 0.01: lit2 += 1
				worst = minf(worst, l.light_energy)
			print("t+4.5s (PAST the 1.5s fade): %d of %d burning, dimmest %.4f"
				% [lit2, _wing().size(), worst])
			# and the morgue must still be black
			var morgue := current_scene.get_node_or_null("Lamp_Morgue")
			print("Morgue lamp: %.4f (must stay 0)" % (morgue.light_energy if morgue else -1.0))
			quit(0); return true
	return false
