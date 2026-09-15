extends SceneTree
# C3 (2026-09-15). The 2026-09-14 run: sealed in the cupboard with the torch ON, no release for
# 88 s — the 45 s fallback never fired and nothing in the suite drove that path. This does:
# seal with the player MOVING and the torch on (the worst case), and require the release at
# FALLBACK_S; plus the seal takes the torch and the release gives it back, and the rule is said.
var _t := 0.0
var _f := 0
var _scene: Node
var _p: CharacterBody3D
var _beat: Node
var _checks := 0
var _fails := 0
var _phase := 0
var _sealed_at := -1.0
var _torch_before := true
func _ok(l: String, c: bool, d: String = "") -> void:
	_checks += 1
	print(("  OK   " if c else "  FAIL ") + l + ("  " + d if d else ""))
	if not c:
		_fails += 1
func _initialize() -> void:
	change_scene_to_file("res://scenes/corridor.tscn")
func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	_f += 1
	if _f < 20:
		return false
	if _scene == null:
		_scene = current_scene
		_p = _scene.get_node("Player")
		_p.set("ai_active", true)
		_beat = _scene.get_node_or_null("Spur2CupboardBeat")
		_ok("the cupboard beat exists", _beat != null)
		if _beat == null:
			return _done()
		_ok("the torch is on before the seal", bool(_p.call("is_flashlight_on")))
		_beat.call("seal")
		_ok("the seal takes the torch", not bool(_p.call("is_flashlight_on")))
		_ok("F cannot bring it back while sealed (locked, not merely off)", bool(_p.get("_flashlight_locked")))
		_ok("the rule is on the screen", _scrawl_on_screen())
		Engine.time_scale = 4.0
		_sealed_at = 0.0
		return false
	_t += delta
	# keep MOVING the whole time — the stillness release must never trigger
	_p.set("ai_move_dir", Vector2(0, -1 if int(_t * 2.0) % 2 == 0 else 1))
	var released: bool = bool(_beat.call("is_released"))
	var fb: float = float(_beat.get("FALLBACK_S"))
	if released:
		Engine.time_scale = 1.0
		_ok("released by the FALLBACK with the player moving (%.1f s, want ~%.0f)" % [_t, fb], _t >= fb - 1.0 and _t <= fb + 3.0)
		_ok("the release gives the torch back", bool(_p.call("is_flashlight_on")))
		_ok("...and unlocks it", not bool(_p.get("_flashlight_locked")))
		return _done()
	if _t > fb + 8.0:
		Engine.time_scale = 1.0
		_ok("released by the fallback", false, "still sealed at %.1f s (fallback %.0f)" % [_t, fb])
		return _done()
	return false
func _scrawl_on_screen() -> bool:
	for n in root.get_children():
		for c in n.get_children():
			if c is Label and String((c as Label).text).contains("MOVE"):
				return true
		if n is Label and String((n as Label).text).contains("MOVE"):
			return true
	return false
func _done() -> bool:
	print("  %d checks, %d failed" % [_checks, _fails])
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true
