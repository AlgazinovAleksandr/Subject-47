extends SceneTree

# Isolated, safe check: does the player's REAL interact raycast (the E-key path,
# not a direct interact() call) actually find the Purge Chamber and the interior
# SlamDoors at all?
#   Godot --headless --path game --script res://tests/check_purge_interact.gd
#
# ⚠️⚠️ AND WHAT HAPPENS TO THE CREATURE AFTERWARDS — added 2026-09-07, because this file
# set up the worst bug in the level and then quit before it happened.
#
# `PurgeChamber.interact()` freezes the creature the instant the blast door seals and only checks
# whether it is actually inside `CLOSE_TO_CONFIRM_DELAY` 1.2 s later. This test pressed E with
# "no creature anywhere near", asserted only that `_used` flipped, and finished in ~0.3 s —
# **before the confirm timer fired.** So it drove the exact defect and reported ALL PASS, for the
# whole life of the bug: the failed-lure branch containing `unfreeze_for_purge()` was executed by
# no test in this repo.
#
# The freeze was `_block_t = 9999.0` against an unfreeze guarded on `_block_t >= 9999.0` — while
# `_process()` decremented `_block_t` every frame, so by the confirm the guard was false and the
# creature stayed blocked for ~9997 s. Measured before the fix: 0.00 m of movement at t+2, t+10
# and t+30 s, and a retry that reset the counter to 9999. **The level's only win condition is
# luring that creature into that chamber, so one failed lure made the run unwinnable.** Issue 173.
#
# ⚠️ THE ASSERTION HAS TO OUTLIVE THE TIMER. A test that finishes inside 1.2 s of the press cannot
# see this no matter what it checks.

var _level: Node
var _player: CharacterBody3D
var _purge: Node
var _slam_doors: Array = []
var _phase := 0
var _t := 0.0
var _fails := 0
var _results: Dictionary = {}
var _creature: Node = null
var _freeze_from := Vector3.ZERO


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _find_creature() -> Node:
	var nodes: Array = []
	_all(_level, nodes)
	for x in nodes:
		var sc = x.get_script()
		if sc and String(sc.resource_path).ends_with("creature_object12.gd"):
			return x
	return null


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_6_breach.tscn")


func _process(delta: float) -> bool:
	if not _level:
		if not current_scene:
			return false
		_level = current_scene
		_player = _level.get_node_or_null("Player")
		return false

	_t += delta

	match _phase:
		0:
			_purge = _level.get("_purge_chamber")
			var doors: Array = _level.get("_slam_doors")
			if not _purge or doors == null:
				return false
			_slam_doors = doors
			# Face the Purge Chamber, well within INTERACT_RANGE, no creature near — purely testing
			# the raycast + prompt path. ⚠️ 2026-09-09 (cap #4): the chamber moved to the ExitVault
			# entrance (-7, 0, 48); press it from the ArchiveC side (z<48), facing +z.
			_player.global_position = Vector3(-7, 0.1, 46.5)
			_player.rotation.y = PI
			_phase = 1
			_t = 0.0

		1:
			if _t < 0.15:
				return false   # let a couple of physics frames resolve _interact_target
			var target = _player.get("_interact_target")
			_results["purge_chamber_targetable"] = target != null and target.has_method("interact")
			if target != null and target.has_method("interact"):
				_player.call("_try_interact")
				print("check: purge chamber interact() fired via real E-press path")
			_phase = 2
			_t = 0.0

		2:
			# interact() should have slammed the door shut (visually + the block
			# collider enabling) even though the creature isn't inside — confirm the
			# call actually went through by checking _used flipped true.
			_results["purge_chamber_used_after_press"] = _purge.get("_used") == true
			# ⭐ The lure just FAILED (no creature in the bounds). Wait past the confirm and
			# watch what the creature does — see the header.
			_creature = _find_creature()
			if _creature != null:
				_creature.call("activate")
				_freeze_from = _creature.call("get_creature_position")
			_phase = 20
			_t = 0.0

		20:
			# ⚠️ Past CLOSE_TO_CONFIRM_DELAY 1.2 s, with margin, plus real time to walk.
			if _t < 5.0:
				return false
			if _creature == null:
				_results["creature_found_for_purge_check"] = false
				_phase = 3
				_t = 0.0
				return false
			var moved: float = _freeze_from.distance_to(_creature.call("get_creature_position"))
			_results["a_FAILED_purge_does_not_freeze_the_creature"] = moved > 0.5
			_results["...and it is not left purge-frozen"] = _creature.get("_purge_frozen") == false
			print("check: creature moved %.2f m in %.1f s after a failed lure (frozen=%s)"
				% [moved, _t, str(_creature.get("_purge_frozen"))])
			# ⭐ THE RETRY. `_reopen_failed()` sets `_used = false` and presents the attempt as
			# retryable — and the old code re-froze on every press, so trying to recover made it
			# worse. Press again and require it to still be moving.
			_purge.call("interact")
			_freeze_from = _creature.call("get_creature_position")
			_phase = 21
			_t = 0.0

		21:
			if _t < 5.0:
				return false
			var moved2: float = _freeze_from.distance_to(_creature.call("get_creature_position"))
			# ⚠️ THE RETRY CAN LEGITIMATELY SUCCEED. Between the two presses the creature is free
			# and walking, and PurgeAnte adjoins the Incinerator — so it can wander INTO
			# `trap_bounds` and the second attempt confirms, which runs `lure_into_trap()` and
			# clears `_active` deliberately and for ever. A stationary creature is then the WIN,
			# not the bug. Without this the assertion flakes on exactly the outcome the level
			# wants. (Observed once in a full-suite run.)
			var won: bool = not bool(_creature.get("_active"))
			_results["a RETRIED failed purge does not freeze it either"] = moved2 > 0.5 or won
			if won:
				print("check: the retry LANDED (creature lured) — movement not required")
			print("check: creature moved %.2f m in %.1f s after RETRYING the failed lure"
				% [moved2, _t])
			_phase = 3
			_t = 0.0
			# Now check a SlamDoor the same way.
			if _slam_doors.size() > 0:
				var door = _slam_doors[0]
				var dpos: Vector3 = door.global_position
				_player.global_position = dpos + Vector3(0, 0.1, 0.3)
				_player.rotation.y = 0.0
				_phase = 4
			else:
				_results["slam_door_exists"] = false
				_phase = 9

		4:
			if _t < 0.15:
				return false
			var door = _slam_doors[0]
			var target = _player.get("_interact_target")
			_results["slam_door_targetable"] = target != null and target.has_method("interact")
			if target != null and target.has_method("interact"):
				_player.call("_try_interact")
				print("check: slam door interact() fired via real E-press path")
			_phase = 5
			_t = 0.0

		5:
			var door = _slam_doors[0]
			_results["slam_door_closed_after_press"] = door.get("_closed") == true
			_phase = 9

		9:
			return _finish()

	return false


func _finish() -> bool:
	print("--------------------------------------------------")
	var all_ok := true
	for key in _results:
		var ok: bool = _results[key]
		all_ok = all_ok and ok
		print("  %-32s %s" % [key, "PASS" if ok else "FAIL"])
	print("RESULT: ", "ALL PASS" if all_ok else "FAILURE")
	print("--------------------------------------------------")
	quit(0 if all_ok else 1)
	return true
