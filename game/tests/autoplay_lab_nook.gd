extends SceneTree

# HOW FAR AWAY IS THE NOOK FIGURE WHEN IT APPEARS — on the route a player actually walks?
#
#   Godot --headless --path game --script res://tests/autoplay_lab_nook.gd
#
# ⚠️ THE NUMBER THIS MEASURES DID NOT EXIST BEFORE 2026-09-07. `check_nook_figure.gd` asserts the
# figure is CLEAR of geometry and, after the scripted turn, IN FRUSTUM. Neither of those is a
# distance, and the player's report was about distance: *"the creature in the dark corridor
# appears a bit too far away."*
#
# ⚠️ WHY IT WAS FAR. `_tick_nook_watch()` fires once the player is `NOOK_TRIGGER_DIST` 3.0 m from
# the anchor — but the watch is not armed until a `SceneTreeTimer` 5 s after the breaker is
# thrown, and 5 s at the player's 4.0 m/s walk is up to 20 m. So `far_enough` is true on the very
# first tick, and `_place_nook_figure()` then tried the ANCHOR first, i.e. the one point the
# trigger had just guaranteed was distant. The ladder now tries player-relative marks first.
#
# ⚠️ IT IS A REAL WALK, NOT A TELEPORT. The player is driven through `player.gd`'s `ai_*` surface
# down the wing's own route (the same waypoints `walk_lab_wing.gd` uses), throws the breaker with
# `ai_interact()` through the shipping raycast, and then WALKS OUT — which is what makes the
# distance meaningful, because the whole defect was about where the player had got to by the time
# the beat fired.
#
# ⚠️ TWO PLAYSTYLES, because they take different branches. `walk_out` covers the player who leaves
# during the 5 s of breathing (`far_enough` on the first tick); `stand_still` covers the one who
# waits (the `NOOK_WATCH_TIMEOUT` 6 s backstop, where both world marks are rejected for being
# INSIDE `NOOK_MIN_FRAMING`). Before the fix these produced wildly different distances; they
# should now agree.

const AUTOPLAYER := preload("res://tests/autoplay/autoplayer.gd")
const BREAKER_POS := Vector3(-36.85, 1.1, 7.7)
const ROUTE := [
	Vector3(-11.5, 0.0, 12.5), Vector3(-13.0, 0.0, 12.5), Vector3(-15.5, 0.0, 12.5),
	Vector3(-21.0, 0.0, 12.5), Vector3(-21.0, 0.0, 8.5), Vector3(-23.5, 0.0, 7.7),
	Vector3(-30.0, 0.0, 7.7), Vector3(-34.5, 0.0, 7.7), Vector3(-36.0, 0.0, 7.7),
]
# Walking out again: back east down SouthHall, which is the only way there is.
const OUT_ROUTE := [Vector3(-30.0, 0.0, 7.7), Vector3(-24.0, 0.0, 7.7), Vector3(-21.5, 0.0, 9.5)]
const STYLES := ["walk_out", "stand_still"]

# What "close enough" means. The billboard is 2.3 m tall, so at 2.4 m it fills ~70 % of screen
# height, at 3.5 m ~51 %, at 6 m ~30 %. NOOK_MIN_FRAMING is 2.2, so nothing can beat that.
const WANT_MAX := 4.2
const WANT_MIN := 2.1

var _fails := 0
var _checks := 0
var _style := 0
var _t := 0.0
var _wall := 0.0
var _stage := 0
var _leg := 0
var _level: Node = null
var _player: CharacterBody3D = null
var _auto = null
var _flipped := false
var _seen_at := -1.0
var _results: Array = []


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	Engine.time_scale = 4.0
	seed(11)
	change_scene_to_file("res://scenes/level_1.tscn")


func _figure() -> Node3D:
	return _level.get_node_or_null("NookFigure") as Node3D


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 400.0:
		print("TIMEOUT at stage %d, style %s" % [_stage, STYLES[_style]])
		return _report()
	_t += delta
	if _t < 2.5 or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		if _player == null:
			print("no player")
			return _report()
		# Start at the wing's mouth, the way walk_lab_wing.gd does — the ten-room maze is
		# already proven walkable by that test and re-walking it here measures nothing new.
		_player.global_position = Vector3(-11.5, 0.2, 12.5)
		_player.force_update_transform()
		_auto = AUTOPLAYER.new(_player)
		print("\n=== style: %s ===" % STYLES[_style])

	match _stage:
		0:
			# ---- walk the wing to the breaker
			if _leg >= ROUTE.size():
				_auto.stop()
				_stage = 1
				_t = 0.0
				return false
			var w: Vector3 = ROUTE[_leg]
			w.y = _player.global_position.y
			if _auto.step_toward(w):
				_leg += 1
				_auto.reset_stuck()
			elif _auto.stuck:
				_leg += 1
				_auto.reset_stuck()
		1:
			# ---- throw it through the real interact ray
			_player.call("ai_look_at", BREAKER_POS)
			var cam := _player.get_node_or_null("Camera3D") as Camera3D
			if cam:
				cam.force_update_transform()
			var tgt = _player.call("ai_interact_target")
			_ok("%s: the shipping ray reaches the nook breaker" % STYLES[_style], tgt != null,
				"from %s" % str(_player.global_position))
			_player.call("ai_interact")
			_flipped = bool(_level.get("_nook_scare_done"))
			_ok("%s: the breaker threw" % STYLES[_style], _flipped)
			_stage = 2
			_leg = 0
			_t = 0.0
		2:
			# ---- behave, and watch for the figure
			var fig := _figure()
			if fig != null and _seen_at < 0.0:
				var d := _player.global_position.distance_to(fig.global_position)
				_seen_at = d
				print("     figure appeared at %.2f m (player %s, figure %s)"
					% [d, str(_player.global_position), str(fig.global_position)])
			if STYLES[_style] == "walk_out" and _leg < OUT_ROUTE.size():
				var w2: Vector3 = OUT_ROUTE[_leg]
				w2.y = _player.global_position.y
				if _auto.step_toward(w2):
					_leg += 1
					_auto.reset_stuck()
				elif _auto.stuck:
					_leg += 1
					_auto.reset_stuck()
			else:
				_auto.stop()
			# The reveal fires at +5 s (armed) and the figure is visible for ~0.33 s from +0.45.
			# Give the whole beat room, then judge.
			if _t > 16.0:
				_ok("%s: a figure appeared at all" % STYLES[_style], _seen_at >= 0.0,
					"_place_nook_figure() returns non-finite when nothing fits, and the beat "
					+ "then keeps the sting and drops the picture — that is a legitimate "
					+ "outcome, but not on an open route like this one")
				if _seen_at >= 0.0:
					_ok("%s: it appeared CLOSE (%.1f-%.1f m)" % [STYLES[_style], WANT_MIN, WANT_MAX],
						_seen_at >= WANT_MIN and _seen_at <= WANT_MAX,
						"%.2f m — before the ladder was reordered this measured 5-20 m on the "
						% _seen_at + "walk-out branch, because the anchor was tried first")
				_results.append({"style": STYLES[_style], "d": _seen_at})
				return _next_style()
	return false


func _next_style() -> bool:
	if _auto != null:
		_auto.release()
		_auto = null
	_style += 1
	if _style >= STYLES.size():
		return _report()
	_level = null
	_stage = 0
	_leg = 0
	_t = 0.0
	_flipped = false
	_seen_at = -1.0
	seed(11)
	change_scene_to_file("res://scenes/level_1.tscn")
	return false


func _report() -> bool:
	print("\n=== nook figure distance at reveal ===")
	for r in _results:
		print("   %-12s %.2f m" % [r["style"], r["d"]])
	print("== %d checks, %d failed ==" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return true
