extends SceneTree

# THE MAP CANNOT KILL YOU WHILE YOU PLAY IT — ONLY THE THIRD CATCH IN A ROW DOES (2026-09-24 e).
#
#   Godot --headless --path game --script res://tests/check_maze_no_death.gd
#
# The third House playtest's one death was a panic death INSIDE the map, and the user's rule
# (capture #1): *"there can be no way you die from the level screamer while you are still playing
# the game. Only after you lost it several times in a row from the monster."* So:
#   * every map panic write (drip, proximity, snare, CATCH_PANIC) is clamped below PANIC_MAX;
#   * catches 1 and 2 are not deaths — even at 90 % panic — and the ejected player survives
#     the 3D frames that follow;
#   * ESC is not an attempt: the streak does not move;
#   * a win resets the streak;
#   * the 3rd catch in a row fires `Screamer.trigger()`.
#
# ⚠️ Everything runs in the real House, through the real `HouseMap.interact()` and the UI's own
# `_process()` across real frames. Nothing emits `caught` or `won`: a catch is the icon walked
# onto the hunter, a win is the hammer, the pane and the key through `_check_fragments()` and
# `_is_won()`. The death is read off `Screamer._is_triggering`, the funnel every death takes.

const TIMEOUT := 60.0

var _t := 0.0
var _total := 0.0
var _stage := 0
var _checks := 0
var _fails: Array[String] = []
var _scene: Node = null
var _player: Node = null
var _map: Node = null
var _ui: Node = null
var _solo: Node = null
var _solo_ui: Node = null
var _screamer: Node = null
var _seed_a := -1
var _peak := 0.0
var _streak_at_win := -1
var _won_seen := false


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _dying() -> bool:
	return _screamer != null and _screamer.get("_is_triggering") == true


func _panic() -> float:
	return float(_player.call("get_panic_ratio"))


# Walk the icon onto the hunter; the UI's own catch test closes the overlay and emits.
func _walk_into_hunter(ui: Node) -> void:
	ui.set("_monster_start_timer", 0.0)
	ui.set("_player_pos", ui.get("_monster_pos"))


func _press_esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = "ui_cancel"
	up.pressed = false
	Input.parse_input_event(up)


func _process(delta: float) -> bool:
	_t += delta
	_total += delta
	# ⚠️ FIRST, before anything touches a node. An unexpected death reloads the level after
	# RESTART_DELAY and frees every node this test holds; a stage that then calls into one
	# throws, the frame aborts before any timeout check below it, and the run hangs forever
	# (it did — the mutation with the clamp removed ran into the 900 s wall). So: a reload or
	# a freed map is a FAIL, reported and quit, and the timeout is checked up here.
	if _stage > 0 and _stage < 8 and (not is_instance_valid(_scene) or current_scene != _scene \
			or not is_instance_valid(_ui)):
		_ok("the House was NOT reloaded under the test (a death reloads it) — stage %d" % _stage, false)
		return _finish()
	if _total > TIMEOUT:
		_ok("timed out at stage %d" % _stage, false)
		return _finish()

	if _stage == 0 and _t > 1.2:
		_scene = current_scene
		_screamer = root.get_node_or_null("Screamer")
		_player = _scene.get_node_or_null("Player")
		_map = _scene.get_node_or_null("HouseMap")
		_ok("the House has its Player, its HouseMap and the Screamer autoload",
			_player != null and _map != null and _screamer != null)
		if _player == null or _map == null or _screamer == null:
			return _finish()
		_ui = _map.get("_ui")
		# ---- A. at 49 of 50, the drip + proximity + a snare must not kill -----------------
		_player.call("set_panic_ratio", 0.98)
		_map.call("interact")
		_seed_a = int(_ui.get("_layout_seed"))
		_ok("interacting opens the map on a CURATED layout",
			_ui.get("_ui_open") == true
				and (_ui.get_script() as Script).get("CURATED_SEEDS").has(_seed_a),
			"seed %d" % _seed_a)
		# The head start is over, so the drip runs from the first frame.
		_ui.set("_monster_start_timer", 0.0)
		_ui.set("_patrol_pos", Vector2(-99999.0, -99999.0))
		# A snare right under the icon: +SNARE_PANIC on the next frame.
		var under: Array[Vector2] = [_ui.get("_player_pos") as Vector2]
		_ui.set("_snares", under)
		_peak = 0.0
		_stage = 1
		_t = 0.0

	elif _stage == 1:
		# Hold the hunter 60 px off the icon every frame: inside PROXIMITY_RANGE (a real
		# proximity term, ~1.0 /s on top of the 0.4 drip), outside CATCH_RADIUS. It closes at
		# most ~3 px a frame, so it can never reach the icon between two of these writes.
		_ui.set("_monster_pos", (_ui.get("_player_pos") as Vector2) + Vector2(60.0, 0.0))
		_peak = maxf(_peak, _panic())
		if _t > 4.0:
			# Unclamped this is 49 + 3 (snare) + ~5.5 (drip + proximity over 4 s) = dead.
			_ok("at 98 % panic, 4 s of drip + proximity + a snare fire NO screamer", not _dying())
			_ok("…the map is still open", _ui.get("_ui_open") == true)
			_ok("…panic is held below the bar", _panic() < 1.0, "%.4f" % _panic())
			_ok("…and it really was pushed: it sits at the cap, not below it",
				_peak >= 0.975, "peak %.4f" % _peak)
			_ok("…the snare did spring (the sample is real)",
				(_ui.get("_snares") as Array).is_empty())
			# ---- B. catch 1, at 90 % panic ----------------------------------------------------
			_player.call("set_panic_ratio", 0.90)
			_walk_into_hunter(_ui)
			_stage = 2
			_t = 0.0

	elif _stage == 2 and _t > 0.3:
		_ok("catch 1 closes the map", _ui.get("_ui_open") == false)
		_ok("catch 1 at 90 % panic (+CATCH_PANIC 18 of 50) is NOT a death", not _dying())
		_ok("…streak 1", int(_map.get("_catch_streak")) == 1, "%d" % int(_map.get("_catch_streak")))
		_ok("…panic clamped below the bar", _panic() < 1.0, "%.4f" % _panic())
		_stage = 3
		_t = 0.0

	elif _stage == 3 and _t > 2.0:
		# Two seconds of the 3D House with the ejected player at the cap.
		_ok("the ejected player survives 2 s of 3D frames at the cap", not _dying(),
			"panic %.3f" % _panic())
		# ---- C. ESC is not an attempt -----------------------------------------------------
		_map.call("interact")
		_ok("the retry is a DIFFERENT curated layout (never the same twice in a row)",
			int(_ui.get("_layout_seed")) != _seed_a
				and (_ui.get_script() as Script).get("CURATED_SEEDS").has(int(_ui.get("_layout_seed"))),
			"%d after %d" % [int(_ui.get("_layout_seed")), _seed_a])
		_stage = 4
		_t = 0.0

	elif _stage == 4 and _t > 0.2:
		_press_esc()
		_stage = 5
		_t = 0.0

	elif _stage == 5 and _t > 0.3:
		_ok("ESC closes the map", _ui.get("_ui_open") == false)
		_ok("…without retiring the instance", _ui.get("_instance_live") == true)
		_ok("…and ESC does NOT count as a catch (streak still 1)",
			int(_map.get("_catch_streak")) == 1, "%d" % int(_map.get("_catch_streak")))
		# ---- D. catch 2 ----------------------------------------------------------------------
		_map.call("interact")
		_player.call("set_panic_ratio", 0.90)
		_walk_into_hunter(_ui)
		_stage = 6
		_t = 0.0

	elif _stage == 6 and _t > 0.3:
		_ok("catch 2 is NOT a death", not _dying())
		_ok("…streak 2", int(_map.get("_catch_streak")) == 2, "%d" % int(_map.get("_catch_streak")))
		# ---- E. a win resets the streak (a second, standalone HouseMap) ---------------------
		var map_script: GDScript = load("res://scripts/house_map_prop.gd")
		_solo = map_script.new()
		_solo.name = "SoloHouseMap"
		_scene.add_child(_solo)
		_solo_ui = _solo.get("_ui")
		_solo.set("_catch_streak", 2)
		# `_on_won()` zeroes the streak BEFORE it emits and queue_frees, so read it inside the
		# emission — the last moment the prop exists.
		_solo.connect("won", func() -> void:
			_won_seen = true
			_streak_at_win = int(_solo.get("_catch_streak")))
		_solo.call("interact")
		_solo_ui.set("_monster_start_timer", 999.0)
		var far := Vector2(-99999.0, -99999.0)
		_solo_ui.set("_monster_pos", far)
		_solo_ui.set("_patrol_pos", far)
		var none: Array[Vector2] = []
		_solo_ui.set("_snares", none)
		_stage = 7
		_t = 0.0

	elif _stage == 7:
		# Hammer → pane → key, each through the real `_check_fragments()` / `_is_won()` path.
		if not _won_seen:
			var frags: Array = _solo_ui.get("_fragments")
			if not frags.is_empty():
				_solo_ui.set("_player_pos", frags[0])
			elif _solo_ui.get("_glass_broken") != true:
				_solo_ui.set("_player_pos", ((_solo_ui.get("_pane_rects") as Array)[0] as Rect2).get_center())
			else:
				_solo_ui.set("_player_pos", _solo_ui.get("_target_pos"))
		if _won_seen or _t > 8.0:
			_ok("the standalone map was WON through the real path", _won_seen)
			_ok("…and the win reset the streak 2 → 0", _streak_at_win == 0, "%d" % _streak_at_win)
			_ok("…and a win is not a death", not _dying())
			# ---- F. catch 3 on the level's map: the ONE death ------------------------------
			_player.call("set_panic_ratio", 0.0)
			_map.call("interact")
			_walk_into_hunter(_ui)
			_stage = 8
			_t = 0.0

	elif _stage == 8 and _t > 0.3:
		_ok("catch 3 IN A ROW fires the screamer (at 0 % panic — it is the count, not the bar)",
			_dying(), "streak %d" % int(_map.get("_catch_streak")) if is_instance_valid(_map) else "")
		return _finish()

	return false


func _finish() -> bool:
	if _checks < 20:
		_fails.append("only %d checks ran" % _checks)
	print("--------------------------------------------------")
	print("MAZE-NO-DEATH %d checks, %d failed" % [_checks, _fails.size()])
	print("RESULT: ", "PASS" if _fails.is_empty() else "FAIL (%s)" % ", ".join(_fails))
	print("--------------------------------------------------")
	quit(0 if _fails.is_empty() else 1)
	return true
