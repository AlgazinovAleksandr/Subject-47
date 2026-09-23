extends SceneTree

# CONTAINED XOR KILLED (2026-09-24, Breach pass 5). The user: "it was told that the object contained
# get out but at the same time I was killed and the level was not finished … It is either contained
# and you can get out or you get killed". The playtest log had `KILL BLACK / FATAL FUNNEL` at 314.58,
# then `SEALED … LEAVE` at 316.93, then the restart: the player was killed INSIDE ExitVault while the
# held race close ran on, and the purge's timers completed the win under the death.
#
#   Godot --headless --path game --script res://tests/check_breach_contained_xor_killed.gd
#
# Through the REAL player (the E ray, the key held with `Input.action_press`) and Object 12's own chase.
# Each scenario must end in EXACTLY ONE outcome:
#   A. contact DURING a race close (the player inside the vault, it charges and reaches them before the
#      door shuts): a death, the close aborted, and NO "SEALED", no `creature_defeated`, no trap signal;
#   B. the seal COMPLETING as it lunges (deep enough that the leaf shuts first, the creature ~1.5 m
#      short): SEALED, contained, and NO death afterwards — it is purge-frozen at the shut;
#   C. a death claimed AFTER the shut, while the confirm and purge timers are pending: those timers do
#      nothing, and no SEALED follows.
const SCENE := "res://scenes/level_6_breach.tscn"
const PLAYER_IN := Vector3(-7.0, 0.1, 50.2)      # inside ExitVault, 2.2 m past the door plane, facing it
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
	if Time.get_ticks_msec() - _started > 300000:
		print("FAIL contained-xor-killed test timed out")
		quit(1)
	return false


func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])


func _stage(creature_z: float) -> void:
	change_scene_to_file(SCENE)
	await create_timer(1.6).timeout
	_level = current_scene
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(_level)
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_creature = _level.get("_creature")
	_purge = _level.get("_purge_chamber")
	_player.global_position = PLAYER_IN
	_player.rotation.y = 0.0                         # face -z, at the blast door
	_player.velocity = Vector3.ZERO
	_creature.call("set_present", true)
	_creature.call("place_body", Vector3(-7.0, 0.0, creature_z), PLAYER_IN)
	_creature.call("activate")
	var e := 0.0
	while e < 0.15:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
	_creature.call("place_body", Vector3(-7.0, 0.0, creature_z), PLAYER_IN)


# Hold E on the blast door through the real ray. Returns false if the ray is not on it.
func _hold_e() -> bool:
	var t: Node = _player.call("ai_interact_target")
	if t != _purge:
		print("  interact target was %s, not the purge chamber" % [t])
		return false
	Input.action_press("interact")
	_player.call("_try_interact")
	return true


# Watch for `seconds` (or until the scene reloads). Returns {killed_at, shut_at, sealed, defeated,
# trapped, dist_at_shut}.
func _watch(seconds: float) -> Dictionary:
	var out := {"killed_at": -1.0, "shut_at": -1.0, "sealed": false, "defeated": false, "trapped": 0,
		"dist_at_shut": -1.0}
	var trapped := [0]
	_purge.connect("creature_trapped", func(): trapped[0] += 1)
	var level := _level
	var e := 0.0
	while e < seconds:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
		if current_scene != level or not is_instance_valid(level):
			break
		if out["killed_at"] < 0.0 and level.get("_kill_sequence") != null:
			out["killed_at"] = e
		var log: Array = _purge.get("race_log")
		if out["shut_at"] < 0.0:
			for entry in log:
				if entry[0] == "shut":
					out["shut_at"] = e
					var c: Vector3 = _creature.call("get_creature_position")
					out["dist_at_shut"] = Vector2(c.x - _player.global_position.x, c.z - _player.global_position.z).length()
		if String(root.get_node("GameState").get("current_objective")).begins_with("SEALED"):
			out["sealed"] = true
		if level.get("_creature_defeated") == true:
			out["defeated"] = true
	out["trapped"] = trapped[0]
	Input.action_release("interact")
	return out


func _run() -> void:
	var gs := root.get_node("GameState")
	# ---- A. contact during the race close
	await _stage(52.0)
	var pressed := _hold_e()
	var a: Dictionary = await _watch(5.5)
	print("  A: %s" % str(a))
	_ok("A: the E ray reaches the blast door from inside the vault", pressed)
	_ok("A: it reaches the player during the held close: a DEATH (kill at %.2f s)" % a["killed_at"], a["killed_at"] > 0.0)
	_ok("A: …and ONLY a death: the close never shut, no SEALED, not contained, no trap signal",
		a["shut_at"] < 0.0 and not a["sealed"] and not a["defeated"] and a["trapped"] == 0)
	await create_timer(1.5).timeout      # let the death's own restart finish before the next stage
	# ---- B. the seal completes as it lunges
	await _stage(54.2)
	pressed = _hold_e()
	var b: Dictionary = await _watch(6.0)
	print("  B: %s" % str(b))
	_ok("B: the leaf shuts while it is lunging at the player (%.2f m away at the shut)" % b["dist_at_shut"],
		pressed and b["shut_at"] > 0.0 and b["dist_at_shut"] > 1.0 and b["dist_at_shut"] < 2.6)
	_ok("B: SEALED and contained, and ONLY that: no death after the shut",
		b["sealed"] and b["defeated"] and b["trapped"] == 1 and b["killed_at"] < 0.0)
	# ---- C. a death claimed while the confirm and purge timers are pending
	await _stage(54.2)
	pressed = _hold_e()
	var e := 0.0
	var shut := false
	while e < 3.0 and not shut:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
		for entry in _purge.get("race_log"):
			if entry[0] == "shut":
				shut = true
	Input.action_release("interact")
	await create_timer(0.4).timeout
	# a death arrives by another route (a panic death takes the same transition), inside the 1.2 s confirm
	_level.call("_on_contact_death")
	var aborted_now: bool = _purge.call("is_aborted")
	var c: Dictionary = await _watch(4.5)
	print("  C: %s" % str(c))
	_ok("C: the door had shut with it inside, and the death was claimed before the confirm (the chamber aborted)", shut and aborted_now)
	_ok("C: the pending confirm and purge do NOTHING: no SEALED, not contained, no trap signal",
		not c["sealed"] and not c["defeated"] and c["trapped"] == 0)
	print("BREACH CONTAINED XOR KILLED: %d checks, %d failed" % [_checks, _fails])
	if current_scene:
		current_scene.queue_free()
	await process_frame
	gs.call("invalidate_transition")
	quit(1 if _fails else 0)
