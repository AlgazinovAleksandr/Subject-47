extends SceneTree

# THE SEAL RACE (2026-09-23 pass 4) behind `level_6_breach.gd:SEAL_RACE`.
#
#   Godot --headless --path game --script res://tests/check_breach_seal_race.gd [-- --sweep]
#
# Through the REAL player: the E ray (`_try_interact`, the path the key takes), with the key HELD via
# `Input.action_press("interact")` — the same action state `purge_chamber.gd` polls — and released via
# `Input.action_release`. Object 12 is ACTIVE and runs its own chase; nothing here moves it after the
# press.
#
# What it asserts:
#   * RACE OFF restores the old instant slam exactly: one press, the blocker is up the same frame, the
#     creature is purge-frozen at once, and a creature inside is purged;
#   * RACE ON, lured DEEP (the back half of ExitVault): holding E shuts the door before it arrives,
#     and the purge runs;
#   * RACE ON, SHALLOW (near the doorway): it reaches the leaf first, the door JAMS and swings back
#     open, the creature is loose (not frozen), the attempt resets (`_used` false), and the player is
#     not killed by the jam itself;
#   * letting go of E rolls the door back open and releases a creature frozen at the press;
#   * with no creature inside, a held close shuts, confirms nothing and reopens ("IT ISN'T IN THERE");
#   * a creature standing in the doorway (not inside at the press) jams the leaf as well.
# `-- --sweep` also prints the jam/seal outcome across depths (the tuning table in the spec).
const SCENE := "res://scenes/level_6_breach.tscn"
const PLAYER_AT := Vector3(-7.0, 0.1, 46.4)     # ArchiveC side of the blast door, facing +z
var _level: Node
var _player: CharacterBody3D
var _creature: Node
var _purge: Node
var _fails := 0
var _checks := 0
var _started := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _started > 420000:
		print("FAIL seal race test timed out")
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


# A fresh level, straight into the hunt (the approach sealed), creature placed at depth `d` metres
# inside ExitVault from the blast door's plane (z 48), facing the doorway, ACTIVE.
func _stage(d: float, race: bool, activate: bool = true) -> void:
	change_scene_to_file(SCENE)
	await create_timer(1.6).timeout
	_level = current_scene
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(_level)
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_creature = _level.get("_creature")
	_purge = _level.get("_purge_chamber")
	_purge.set("seal_race", race)
	_player.global_position = PLAYER_AT
	_player.rotation.y = PI
	_player.velocity = Vector3.ZERO
	_creature.call("set_present", true)
	_creature.call("place_body", Vector3(-7.0, 0.0, 48.0 + d), Vector3(-7.0, 0.0, 40.0))
	if activate:
		_creature.call("activate")
	await _secs(0.15)
	# Active for 0.15 s it has already started walking: put it back at the exact depth, facing the
	# doorway, in the same frame as the press (`_press_and_hold` follows immediately), so the depth in
	# the table is the depth at the press.
	_creature.call("place_body", Vector3(-7.0, 0.0, 48.0 + d), Vector3(-7.0, 0.0, 40.0))


func _press_and_hold() -> bool:
	var t: Node = _player.call("ai_interact_target")
	if t != _purge:
		print("  interact target was %s, not the purge chamber" % [t])
		return false
	Input.action_press("interact")
	_player.call("_try_interact")
	return true


func _release() -> void:
	Input.action_release("interact")


# Returns "jam", "shut" or "?" and how long the race ran.
func _race_outcome(limit: float) -> Array:
	var e := 0.0
	while e < limit:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
		var log: Array = _purge.get("race_log")
		for entry in log:
			if entry[0] == "jam" or entry[0] == "shut":
				return [entry[0], entry[1], log]
	return ["?", e, _purge.get("race_log")]


func _run() -> void:
	var consts: Dictionary = (load("res://scripts/level_6_breach.gd") as GDScript).get_script_constant_map()
	_ok("the switch exists and is ON in the shipped level (SEAL_RACE = %s)" % str(consts.get("SEAL_RACE")),
		consts.get("SEAL_RACE") == true)
	print("  SEAL_CLOSE_TIME %.2f s, SEAL_REACT_DELAY %.2f s, chase_speed %.1f" % [consts["SEAL_CLOSE_TIME"],
		consts["SEAL_REACT_DELAY"], consts["BREACH_CHASE_SPEED"]])

	# ---- 1. RACE OFF: the old instant slam, exactly
	await _stage(4.5, false)
	_ok("race OFF: the chamber reports seal_race false", _purge.get("seal_race") == false)
	var label: Label = _player.get("interact_label")
	_ok("race OFF: the HUD prompt is the old \"%s\"" % label.text, label.visible and label.text == "Press E")
	var pressed := _press_and_hold()
	_release()     # a single tap is all the old door ever needed
	var blocker: CollisionShape3D = _purge.get("_block_collider")
	_ok("race OFF: one E press slams it at once (blocker up, used, creature purge-frozen, same frame)",
		pressed and not blocker.disabled and _purge.get("_used") == true and _creature.get("_purge_frozen") == true
		and not bool(_purge.call("is_closing")))
	await _secs(4.5)
	_ok("race OFF: the creature inside is purged (creature_defeated)", _level.get("_creature_defeated") == true)

	# ---- 2. RACE ON, deep (back half of the vault)
	await _stage(5.2, true)
	label = _player.get("interact_label")
	_ok("race ON: the HUD prompt names the verb (\"%s\")" % label.text, label.visible and label.text.begins_with("Hold E"))
	var start_d: float = float(_creature.call("get_creature_position").z) - 48.0
	pressed = _press_and_hold()
	_ok("race ON: E does NOT slam it at once (it starts to grind shut)", pressed and blocker_disabled() and bool(_purge.call("is_closing")))
	var out: Array = await _race_outcome(4.0)
	_release()
	print("  DEEP  (%.2f m in): %s at %.2f s   log %s" % [start_d, out[0], out[1], str(out[2])])
	_ok("race ON, lured DEEP (%.1f m in): holding E shuts the door before it arrives (%s at %.2f s)" % [start_d, out[0], out[1]],
		out[0] == "shut")
	await _secs(4.5)
	_ok("…and the purge runs as before (creature_defeated)", _level.get("_creature_defeated") == true)

	# ---- 3. RACE ON, shallow (near the doorway)
	await _stage(1.6, true)
	start_d = float(_creature.call("get_creature_position").z) - 48.0
	pressed = _press_and_hold()
	out = await _race_outcome(4.0)
	print("  SHALLOW (%.2f m in): %s at %.2f s   log %s" % [start_d, out[0], out[1], str(out[2])])
	_ok("race ON, SHALLOW (%.1f m in): it reaches the leaf first and the door JAMS (%s at %.2f s)" % [start_d, out[0], out[1]],
		out[0] == "jam")
	var dead_at_jam := _level.get("_kill_sequence") != null
	_ok("the jam itself kills nobody (no kill sequence at the jam)", not dead_at_jam)
	_ok("after the jam the creature is loose (not purge-frozen) and the attempt resets (_used false)",
		_creature.get("_purge_frozen") == false and _purge.get("_used") == false and not bool(_purge.call("is_closing")))
	_release()
	_player.global_position = Vector3(-7.0, 0.1, 30.0)     # step away so the loose creature cannot matter
	await _secs(0.6)
	var hinge: Node3D = _purge.get("_hinge")
	_ok("the door swings back open (%.0f°)" % hinge.rotation_degrees.y, hinge.rotation_degrees.y < -80.0)

	# ---- 4. letting go rolls it back and frees a creature frozen at the press
	await _stage(4.0, true)
	pressed = _press_and_hold()
	await _secs(0.35)
	var frozen_mid: bool = _creature.get("_purge_frozen") == true
	_release()
	await _secs(0.1)
	_ok("letting go of E before it shuts rolls it back (the attempt ends, the creature frozen at the press is released)",
		frozen_mid and not bool(_purge.call("is_closing")) and _purge.get("_used") == false
		and _creature.get("_purge_frozen") == false)
	_player.global_position = Vector3(-7.0, 0.1, 30.0)

	# ---- 5. no creature inside: a held close shuts, confirms nothing, reopens
	await _stage(-12.0, true, false)     # parked in ArchiveC, outside the trap, inert
	pressed = _press_and_hold()
	out = await _race_outcome(3.0)
	_release()
	await _secs(2.8)
	_ok("with nothing inside, a held close shuts (%s), confirms nothing and reopens" % out[0],
		out[0] == "shut" and _level.get("_creature_defeated") == false and _purge.get("_used") == false)

	# ---- 6. a body standing IN the doorway (never inside at the press) jams the leaf too: the door
	# cannot grind shut through it, and its blocker must never switch on inside a creature
	await _stage(-0.4, true, false)     # 0.4 m on the ArchiveC side of the plane, inert
	pressed = _press_and_hold()
	out = await _race_outcome(2.0)
	_release()
	_ok("a creature standing in the doorway jams the closing leaf (%s at %.2f s)" % [out[0], out[1]],
		out[0] == "jam" and _purge.get("_used") == false)

	if OS.get_cmdline_user_args().has("--sweep"):
		print("  SWEEP depth (m from the door plane) -> outcome")
		for d in [1.0, 2.0, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 4.5, 5.5, 6.5]:
			await _stage(d, true)
			var at: float = float(_creature.call("get_creature_position").z) - 48.0
			_press_and_hold()
			var o: Array = await _race_outcome(4.0)
			_release()
			print("    %.2f m (at the press %.2f)  %-4s at %.2f s  (it was %.2f m from the doorway plane then)"
				% [d, at, o[0], o[1], float(o[2][o[2].size() - 1][2])])

	print("BREACH SEAL RACE: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	quit(1 if _fails else 0)


func blocker_disabled() -> bool:
	var b: CollisionShape3D = _purge.get("_block_collider")
	return b.disabled
