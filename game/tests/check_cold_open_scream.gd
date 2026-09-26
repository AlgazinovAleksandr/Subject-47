extends SceneTree

# The cold open's scream must not bleed into the intro (2026-09-24).
#
# main_menu.gd flashes `nightmare_face` + `nightmare_scream` for 0.8 s and changes scene.
# The scream is 10.28 s long and `flash_scare()` never stopped `_audio`, so it played on
# ~9 s into the wake-up — probed before the fix: still playing at 2.8 s of a 0.8 s flash.
# `flash_scare(..., cut_audio = true)` fades it out after the hold. The CONTROL keeps the
# default path honest: every other caller still lets its sting's tail ring.
#
#   Godot --headless --path game --script res://tests/check_cold_open_scream.gd

const HOLD := 0.8

var _t := 0.0
var _stage := 0
var _stage_at := 0.0
var _fails: Array[String] = []
var _checks := 0
var _s: Node = null


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _advance(next: int) -> void:
	_stage = next
	_stage_at = _t


func _audio() -> AudioStreamPlayer:
	return _s.get("_audio") as AudioStreamPlayer


func _process(delta: float) -> bool:
	_t += delta
	if _s == null:
		_s = root.get_node_or_null("Screamer")
		if _s == null:
			return false
	var el := _t - _stage_at
	match _stage:
		0:
			_ok("main_menu.gd's cold open passes cut_audio",
				FileAccess.get_file_as_string("res://scripts/main_menu.gd").contains(
					"\"nightmare_scream\", 0.8, true)"))
			_s.flash_scare("res://assets/textures/intro/nightmare_face.png", "nightmare_scream",
				HOLD, true)
			_advance(1)
		1:
			if el < 0.3:
				return false
			_ok("the scream plays during the flash", _audio().playing)
			_advance(2)
		2:
			if el < HOLD + 0.6:
				return false
			_ok("cut_audio: the scream has stopped shortly after the hold", not _audio().playing,
				"pos %.2f" % _audio().get_playback_position())
			_ok("cut_audio: the player's level is restored for the next sting",
				_audio().volume_db > -1.0, "%.1f dB" % _audio().volume_db)
			_s.flash_scare("res://assets/textures/intro/nightmare_face.png", "nightmare_scream", HOLD)
			_advance(3)
		3:
			if el < HOLD + 0.6:
				return false
			_ok("CONTROL: without cut_audio the sting's tail still rings", _audio().playing)
			_audio().stop()
			return _finish()
	return false


func _finish() -> bool:
	print("")
	if _fails.is_empty():
		print("COLD OPEN SCREAM PASS — %d checks" % _checks)
		quit(0)
	else:
		print("COLD OPEN SCREAM FAIL — %d/%d: %s" % [_fails.size(), _checks, ", ".join(_fails)])
		quit(1)
	return true
