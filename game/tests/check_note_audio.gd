extends SceneTree

# A note (and the TAB journal) keeps the level's SOUND running while the tree is paused
# (2026-09-13, the user: "while you are reading nothing can make you panic, as it is now, but
# you will hear the level sounds. And make it applicable to notes on every level").
#
#   * open a note in the House: the tree is paused, every stream player that was playing is
#     still playing and its playback position ADVANCES over a real second
#   * the player's panic does not move while the page is up (the pause still owns that)
#   * close: process modes restored, tree unpaused
#   * a player that was NOT playing is never touched (control)
#   * the journal round-trips the same way
#
# Usage: Godot --headless --path game --script res://tests/check_note_audio.gd

var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _p: CharacterBody3D = null
var _stage := 0
var _t0 := 0
var _players: Array = []
var _pos0: Array = []
var _modes0: Array = []
var _idle: AudioStreamPlayer = null
var _panic0 := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _collect() -> Array:
	var out: Array = []
	var stack: Array = [_level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.get("playing"):
			out.append(n)
	return out


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		change_scene_to_file("res://scenes/level_2_1.tscn")
		return false
	_settle += 1
	if _settle < 20:
		return false
	var note_ui := root.get_node("NoteUI")
	var journal := root.get_node("JournalUI")
	match _stage:
		0:
			_level = current_scene
			_p = _level.get_node_or_null("Player")
			_players = _collect()
			_ok("the House has stream players playing before the note", _players.size() >= 2, "%d" % _players.size())
			# CONTROL: a silent player must be left alone.
			_idle = AudioStreamPlayer.new()
			_idle.name = "IdleControl"
			_level.add_child(_idle)
			for pl in _players:
				_pos0.append(pl.get_playback_position())
				_modes0.append(pl.process_mode)
			_p.call("add_panic", 10.0)
			_panic0 = float(_p.call("get_panic_ratio"))
			note_ui.call("show_note", "a page", 0.0)
			_t0 = Time.get_ticks_msec()
			_stage = 1
		1:
			if Time.get_ticks_msec() - _t0 < 1000:
				return false
			_ok("the tree is paused under the note", paused)
			var still := 0
			var advanced := 0
			for i in range(_players.size()):
				var pl = _players[i]
				if pl.get("playing"):
					still += 1
				if pl.get_playback_position() > _pos0[i] + 0.3:
					advanced += 1
			_ok("every player that was playing still is", still == _players.size(), "%d of %d" % [still, _players.size()])
			_ok("…and their playback ADVANCED over a real second", advanced == _players.size(), "%d of %d" % [advanced, _players.size()])
			_ok("CONTROL: the silent player was not touched", _idle.process_mode == Node.PROCESS_MODE_INHERIT)
			_ok("panic did not move while reading", absf(float(_p.call("get_panic_ratio")) - _panic0) < 0.001)
			note_ui.call("_close")
			_stage = 2
		2:
			_ok("closing unpauses", not paused)
			var restored := 0
			for i in range(_players.size()):
				if _players[i].process_mode == _modes0[i]:
					restored += 1
			_ok("process modes restored on close", restored == _players.size(), "%d of %d" % [restored, _players.size()])
			# The journal, same contract.
			root.get_node("GameState").call("record_note", "a recovered page", 2)
			journal.call("open_journal")
			_t0 = Time.get_ticks_msec()
			_stage = 3
		3:
			if Time.get_ticks_msec() - _t0 < 600:
				return false
			var still := 0
			for pl in _players:
				if pl.get("playing") and pl.process_mode == Node.PROCESS_MODE_ALWAYS:
					still += 1
			_ok("the journal keeps them playing too", paused and still == _players.size(), "%d of %d" % [still, _players.size()])
			journal.call("_close")
			_stage = 4
		4:
			var restored := 0
			for i in range(_players.size()):
				if _players[i].process_mode == _modes0[i]:
					restored += 1
			_ok("journal close restores the modes", not paused and restored == _players.size())
			return _report()
	return false


func _report() -> bool:
	if _checks < 9:
		print("  FAIL only %d checks ran" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
