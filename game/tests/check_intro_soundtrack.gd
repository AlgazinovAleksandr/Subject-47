extends SceneTree

# THE SOUNDTRACK PLAYS ONCE, THEN THE SECOND TRACK LOOPS (first hand playtest, 2026-09-24,
# capture #2: "when the soundtrack ends it starts again - and we hear that sound of like dreaming
# and waking up again").
#
# `ambient_asylum` opens on a dream-to-waking swell and used to self-loop, so the swell came back
# every 162 s. Now it plays once; its `finished` hands the AmbientPlayer to the user's
# `intro_second_music`, 13 dB under the first track's level (measured means −11.1 vs −24.3 dB), and
# THAT loops. Asserted:
#   * at load the first track plays and is NOT wired to replay itself
#   * after `finished`: the stream is the second track, the gain is the offset, and it self-loops
#   * a second `finished` keeps the second track — the dream never comes back
#
#   Godot --headless --path game --script res://tests/check_intro_soundtrack.gd

var _t := 0.0
var _stage := 0
var _fails: Array[String] = []
var _checks := 0
var _base := 0.0


func _initialize() -> void:
	root.get_node("GameState").set("is_ending", false)
	root.get_node("GameState").set("entered_from_ahead", false)
	change_scene_to_file("res://scenes/intro_room.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _name(p: AudioStreamPlayer) -> String:
	return "" if p.stream == null else String(p.stream.resource_path).get_file().get_basename()


func _process(delta: float) -> bool:
	_t += delta
	if _t < 1.0:
		return false
	var s := current_scene
	var amb := s.get_node("AmbientPlayer") as AudioStreamPlayer
	var consts: Dictionary = s.get_script().get_script_constant_map()
	match _stage:
		0:
			_ok("the first track is the dream opening", _name(amb) == String(consts["FIRST_MUSIC"]), _name(amb))
			_ok("…and it is NOT wired to replay itself", not amb.finished.is_connected(amb.play))
			_base = amb.volume_db
			amb.finished.emit()
			_stage = 1
			return false
		1:
			_ok("when it ends, the second track takes over", _name(amb) == String(consts["SECOND_MUSIC"]), _name(amb))
			_ok("…13 dB under the first track's level (set from the files' measured means)",
				is_equal_approx(amb.volume_db, _base + float(consts["SECOND_MUSIC_OFFSET_DB"])),
				"%.1f dB against %.1f" % [amb.volume_db, _base])
			_ok("…and it loops", amb.finished.is_connected(amb.play))
			_ok("…and is playing", amb.playing)
			amb.finished.emit()
			_stage = 2
			return false
		2:
			_ok("a second end keeps the second track — the dream never replays",
				_name(amb) == String(consts["SECOND_MUSIC"]) and amb.playing)
			print("")
			print("%d checks, %d failed" % [_checks, _fails.size()])
			print("RESULT: PASS" if _fails.is_empty() else "RESULT: FAIL")
			quit(0 if _fails.is_empty() else 1)
			return true
	return false
