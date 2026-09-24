extends SceneTree

# ⭐ A BLINDED OBJECT 12 STAYS BLINDED THROUGH THE SEAL RACE (2026-09-24, the user's playtest bug:
# "when I blinded the creature with the flashlight for 7 seconds in the purge room - it killed me while
# I was closing the door, even though 7 seconds have not passed yet").
#
# Cause: `purge_chamber.gd:_process` released the creature `seal_react_delay` (0.8 s) into the close
# and called `force_chase()`, which `_enter(State.CHASE)`s unconditionally — snapping a STAGGERED
# creature out of its 5-7 s blind, with its collider still off and its body still tilted.
#
# Through the REAL player's E ray with the key HELD, and a REAL stagger (the light weapon's
# `apply_light_damage` while it chases). Object 12 is placed only 2.0 m inside ExitVault — a depth that
# JAMS the door when it is not blinded (check_breach_seal_race's sweep) — so a blind that is honoured is
# the only way this door shuts.
#   1. BLINDED at the press: it stays STAGGERED through the whole close, never charges, the door shuts,
#      it is purged, the player lives.
#   2. CONTROL, same depth, NOT blinded: it charges and the door jams (proves the depth is a real test).
#   3. Letting go of E mid-close with a blinded creature: it is released still STAGGERED, and its blind
#      runs on — it does not come out chasing.
const SCENE := "res://scenes/level_6_breach.tscn"
const PLAYER_AT := Vector3(-7.0, 0.1, 46.4)
const DEPTH := 2.0
var _level: Node
var _player: CharacterBody3D
var _creature: Node
var _purge: Node
var _fails := 0
var _checks := 0
var _started := 0
var _staggered: int


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _started > 240000:
		print("FAIL seal-stagger test timed out")
		quit(1)
	return false


func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])


func _secs(t: float) -> void:
	var e := 0.0
	while e < t:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second


func _stage(blind: bool) -> void:
	change_scene_to_file(SCENE)
	await create_timer(1.6).timeout
	_level = current_scene
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(_level)
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_creature = _level.get("_creature")
	_purge = _level.get("_purge_chamber")
	_purge.set("seal_race", true)
	_staggered = (_creature.get_script() as GDScript).get_script_constant_map()["State"]["STAGGERED"]
	_player.global_position = PLAYER_AT
	_player.rotation.y = PI
	_player.velocity = Vector3.ZERO
	_creature.call("set_present", true)
	_creature.call("activate")
	_creature.call("place_body", Vector3(-7.0, 0.0, 48.0 + DEPTH), Vector3(-7.0, 0.0, 40.0))
	if blind:
		# The real light weapon: it only bites while chasing, and drains the shield to a stagger.
		_creature.call("force_chase")
		for i in 60:
			_creature.call("apply_light_damage", 0.1)
			if int(_creature.call("get_state")) == _staggered:
				break
	await physics_frame
	_creature.call("place_body", Vector3(-7.0, 0.0, 48.0 + DEPTH), Vector3(-7.0, 0.0, 40.0))


func _press_and_hold() -> bool:
	var ok: bool = _player.call("ai_interact_target") == _purge
	Input.action_press("interact")
	_player.call("_try_interact")
	return ok


func _outcome(limit: float) -> String:
	var e := 0.0
	var started_blind: bool = int(_creature.call("get_state")) == _staggered
	var left_stagger := false
	while e < limit:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
		if started_blind and int(_creature.call("get_state")) != _staggered:
			left_stagger = true
		for entry in _purge.get("race_log"):
			if entry[0] == "jam" or entry[0] == "shut":
				return "%s%s" % [entry[0], " (left STAGGERED during the close)" if left_stagger else ""]
	return "?"


func _run() -> void:
	# ---- 1. blinded at the press
	await _stage(true)
	_ok("setup: the light weapon really staggered it (state %d)" % int(_creature.call("get_state")),
		int(_creature.call("get_state")) == _staggered)
	var pressed := _press_and_hold()
	var res := await _outcome(4.0)
	Input.action_release("interact")
	_ok("blinded: the E ray targets the purge door", pressed)
	_ok("blinded: it never charges, the door SHUTS (got \"%s\")" % res, res == "shut")
	var charged := false
	for entry in _purge.get("race_log"):
		if entry[0] == "charge":
			charged = true
	_ok("blinded: no charge was issued during the close", not charged)
	await _secs(4.5)
	_ok("blinded: it is purged (creature_defeated)", _level.get("_creature_defeated") == true)
	_ok("blinded: the player was not killed", _level.get("_kill_sequence") == null
		and not bool(_level.call("_death_claimed")))

	# ---- 2. control: same depth, not blinded -> it charges and jams
	await _stage(false)
	_press_and_hold()
	res = await _outcome(4.0)
	Input.action_release("interact")
	_ok("control (not blinded, %.1f m deep): the door JAMS (got \"%s\")" % [DEPTH, res], res.begins_with("jam"))
	await _secs(0.6)

	# ---- 3. blinded, E released mid-close: released still blind, the blind runs on
	await _stage(true)
	var st0: float = float(_creature.get("_stagger_t"))
	_press_and_hold()
	await _secs(1.0)          # past seal_react_delay 0.8
	Input.action_release("interact")
	await _secs(0.3)
	_ok("released mid-close: still STAGGERED (state %d)" % int(_creature.call("get_state")),
		int(_creature.call("get_state")) == _staggered)
	_ok("released mid-close: no longer purge-frozen", _creature.get("_purge_frozen") == false)
	await _secs(0.5)
	_ok("released mid-close: the blind clock runs on (%.2f -> %.2f s)" % [st0, float(_creature.get("_stagger_t"))],
		float(_creature.get("_stagger_t")) > st0)
	_ok("sample count", _checks >= 9)
	print("BREACH SEAL STAGGER: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	quit(1 if _fails else 0)
