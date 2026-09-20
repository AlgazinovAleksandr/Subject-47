extends SceneTree

# ⭐ THE STARE (2026-09-20, the user's call after Void capture #2). Proves the Void's stare director
# and the stalkers' whisper do what spec/levels/08-void.md says and NOTHING else:
#   * every Void stalker whispers; the level rises with continuous gaze and falls after a look-away
#   * a 7 s stare at one figure fires EXACTLY one hallucination, and the body never moves while
#     watched — the 4 s dismissal included — then retreats on the first unobserved frame
#   * real panic is untouched by a hallucination (the panic-bar LIE is a shader override only)
#   * nothing fires while the player's input is frozen (ApparitionDirector's gate)
#   * on the tiles the blink is substituted by a scrawl — never a black screen over the pit
# Godot --headless --path game --script res://tests/check_void_stare.gd

const SCENE := "res://scenes/level_3.tscn"
const DEADLINE_MS := 120000
var _checks := 0
var _fails := 0
var _started := false
var _done := false
var _t0 := 0
var _level: Node3D
var _player: CharacterBody3D
var _director: Node


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if not _done and Time.get_ticks_msec() - _t0 > DEADLINE_MS:
		_ok("finished before the deadline", false)
		_finish()
	if not _started:
		_started = true
		_run.call_deferred()
	return _done


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if _done:
		return
	_checks += 1
	print("  %s %s%s" % ["OK  " if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fails += 1


func _ticks(n: int) -> void:
	for i in range(n):
		await physics_frame


func _look(at: Vector3) -> void:
	_player.call("ai_look_at", at)
	_player.get_node("Camera3D").force_update_transform()


func _body_of(s: Node) -> Node3D:
	return s.get("_body") as Node3D


func _run() -> void:
	change_scene_to_file(SCENE)
	while current_scene == null or current_scene.get_node_or_null("Player") == null:
		await process_frame
	await process_frame
	_level = current_scene
	_player = _level.get_node("Player") as CharacterBody3D
	_director = _level.get_node_or_null("StareDirector")
	_ok("the Void has a stare director", _director != null)
	if _director == null:
		_finish()
		return
	var stalkers: Dictionary = _level.call("get_stalkers")
	var whispering := 0
	for id in stalkers:
		if bool(stalkers[id].get("whisper")):
			whispering += 1
	_ok("every Void stalker whispers", whispering == stalkers.size(), "%d of %d" % [whispering, stalkers.size()])
	var b: Node = stalkers["B"]
	var b_body := _body_of(b)
	var b_start := b_body.global_position

	# ── the stare at B from 5 m: no gaze panic (beyond GAZE_RANGE), dismissal at 4 s, effect at 6 s ──
	_player.global_position = Vector3(1.4, 0.1, 16.2)
	_player.velocity = Vector3.ZERO
	_player.force_update_transform()
	_look(b_body.global_position + Vector3(0, 0.9, 0))
	await _ticks(60)
	_ok("stare time counts continuous gaze", float(b.call("stare_time")) > 0.8, "%.2f s" % float(b.call("stare_time")))
	_ok("the whisper rises with the gaze", float(b.call("whisper_level")) > 0.1, "%.2f" % float(b.call("whisper_level")))
	var w: AudioStreamPlayer3D = b.get("_whisper")
	_ok("...on a positional loop that is playing", w != null and w.playing)
	var panic_before: float = _player.get_panic_ratio()
	_look(b_body.global_position + Vector3(0, 0.9, 0))
	# ⭐ Pass 2 (2026-09-20 evening): the blink is two eyelids, not a cut. Sample them through the wait.
	var lid_max := 0.0
	var lids_parted := false
	for i in range(60 * 6 + 30):
		await physics_frame
		var prog: float = _director.call("blink_progress")
		lid_max = maxf(lid_max, prog)
		if lid_max >= 0.45 and prog <= 0.01:
			lids_parted = true
	_ok("the eyelids met (the blink is an animation, not a cut)", lid_max >= 0.45, "max %.2f" % lid_max)
	_ok("...and parted again", lids_parted)
	_ok("no YOU BLINKED. text in the scrawls", not (_director.get("SCRAWLS") as Array).has("YOU BLINKED."))
	var fired: int = _director.call("fired_count")
	_ok("a 7 s stare fires exactly one hallucination", fired == 1, "fired %d, last %s" % [fired, String(_director.call("last_effect"))])
	_ok("the body never moved while watched — dismissal included", b_body.global_position.distance_to(b_start) < 0.001,
		"moved %.3f" % b_body.global_position.distance_to(b_start))
	_ok("the dismissal left a retreat pending", bool(b.call("retreat_pending")))
	_ok("real panic is untouched by a hallucination", _player.get_panic_ratio() <= panic_before + 0.001,
		"%.2f -> %.2f" % [panic_before, _player.get_panic_ratio()])

	# ── the panic-bar lie is a shader override, not a panic change ──
	var hud: Node = _player.call("get_panic_hud")
	_ok("the HUD carries the lie API", hud != null and hud.has_method("lie"))
	if hud and hud.has_method("lie"):
		var real_before: float = _player.get_panic_ratio()
		hud.call("lie", 0.98, 0.3)
		_ok("the lie is active", bool(hud.call("is_lying")))
		var blur_mat: ShaderMaterial = hud.get("_blur_material")
		var shown: float = float(blur_mat.get_shader_parameter("blur_amount")) / float(hud.get("max_blur_strength"))
		_ok("the shaders show the lie", absf(shown - 0.98) < 0.02, "%.2f" % shown)
		_ok("real panic did not move", is_equal_approx(_player.get_panic_ratio(), real_before))
		await create_timer(0.4).timeout
		_ok("the lie reverts on its own", not bool(hud.call("is_lying")))

	# ── look away: the retreat lands now, the stare resets, the whisper falls ──
	_look(_player.global_position + Vector3(0, 1.65, -5))
	await _ticks(3)
	_ok("the retreat lands on the first unobserved frame", b_body.global_position.distance_to(b_start) > 0.5
		and not bool(b.call("retreat_pending")), "moved %.2f" % b_body.global_position.distance_to(b_start))
	_ok("the stare resets on a look-away", float(b.call("stare_time")) == 0.0)
	# ⚠️ B was re-awakened by the stare that dismissed it, and an awake, unwatched stalker ADVANCES
	# at 1.25 m/s (the rule, and check_stalker_motion's control). The first draft of this test waited
	# here and then stared from 2.2 m — inside GAZE_RANGE — and the panic bar killed the player at
	# 15.4 s, the screamer paused the tree and reloaded the scene under the test. Step beyond
	# ENGAGE_DIST (8 m) first: from the Ward's east side B is 8.9 m off and never steps.
	_player.global_position = Vector3(4.5, 0.1, 17.5)
	_player.velocity = Vector3.ZERO
	_player.force_update_transform()
	_look(_player.global_position + Vector3(0, 1.65, -5))
	await _ticks(60 * 3)
	_ok("the whisper falls after a look-away", float(b.call("whisper_level")) < 0.05, "%.2f" % float(b.call("whisper_level")))
	_ok("CONTROL: the player is beyond the engage distance for the frozen stare", b_body.global_position.distance_to(_player.global_position) > 8.0,
		"%.1f m" % b_body.global_position.distance_to(_player.global_position))

	# ── the frozen-input gate: a stare while input is frozen fires nothing ──
	var before_frozen: int = _director.call("fired_count")
	_player.call("freeze_input")
	_look(b_body.global_position + Vector3(0, 0.9, 0))
	await _ticks(60 * 7)
	_ok("nothing fires while input is frozen", int(_director.call("fired_count")) == before_frozen)
	_player.call("unfreeze_input")
	_look(_player.global_position + Vector3(0, 1.65, -5))
	await _ticks(5)

	# ── on the tiles the blink becomes a scrawl: never a black screen over the pit ──
	_level.get_node("AlignmentKeystone").call("restore_state", true, true)
	await _ticks(2)
	var d: Node = stalkers["D"]
	_director.call("set_cycle", 0)   # next effect would be the blink
	_player.global_position = Vector3(-7.7, 0.1, 45.5)   # the west landing pad, inside the tile rect
	_player.velocity = Vector3.ZERO
	_player.force_update_transform()
	_look(_body_of(d).global_position + Vector3(0, 0.9, 0))
	await _ticks(20)
	_ok("CONTROL: the pad is inside the tile rect", (_level.call("tile_rect") as Rect2).has_point(Vector2(-7.7, 45.5)))
	_ok("CONTROL: the stare at D counts from the pad", float(d.call("stare_time")) > 0.2, "%.2f" % float(d.call("stare_time")))
	var before_tiles: int = _director.call("fired_count")
	await _ticks(60 * 7)
	_ok("a stare from the tiles still fires", int(_director.call("fired_count")) == before_tiles + 1)
	_ok("...but the blink is substituted by a scrawl on the tiles", String(_director.call("last_effect")) == "scrawl"
		and not bool(_director.call("is_blinking")), String(_director.call("last_effect")))
	_ok("no panic from the whole session's stares beyond the gaze rule", _player.get_panic_ratio() < 0.5, "%.2f" % _player.get_panic_ratio())
	_finish()


func _finish() -> void:
	print("--------------------------------------------------")
	print("VOID-STARE %s: %d checks, %d failed" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	print("--------------------------------------------------")
	_done = true
	quit(_fails)
