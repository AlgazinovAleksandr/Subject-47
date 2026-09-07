extends SceneTree

# DOES A FAILED PURGE ATTEMPT FREEZE OBJECT 12 FOR EVER?
#
#   Godot --headless --path game --script res://tests/probe_purge_freeze.gd
#
# A `probe_*`: it measures and prints. Written BEFORE the fix, as a prediction to be falsified.
#
# ⚠️ THE HYPOTHESIS, from reading. `freeze_for_purge()` sets `_block_t = _PURGE_FREEZE` (9999.0)
# and `unfreeze_for_purge()` only clears it `if _block_t >= _PURGE_FREEZE` — while `_process()`
# DECREMENTS `_block_t` every frame. `purge_chamber.gd` freezes the instant the blast door seals
# and only checks whether the creature is actually inside `CLOSE_TO_CONFIRM_DELAY = 1.2 s` later,
# by which time `_block_t` is ~9997.8 and the guard is false. The unfreeze silently does nothing
# and the creature is blocked for the remaining ~9997 s ≈ 2 h 46 m.
#
# ⚠️ AND THE LEVEL'S ONLY WIN CONDITION IS LURING THAT CREATURE INTO THAT CHAMBER, so if this
# reproduces, one failed lure makes the run unwinnable — while `_reopen_failed()` sets
# `_used = false` and presents the attempt as retryable.
#
# PREDICTED (if the hypothesis holds):
#   t+2 s   _block_t ~9997   displacement 0.00 m
#   t+10 s  _block_t ~9989   displacement 0.00 m
#   t+30 s  _block_t ~9969   displacement 0.00 m
#   and pressing E a SECOND time resets _block_t to 9999 — the retry deepens the freeze.
#
# ⚠️ THE CREATURE IS PARKED WELL SHORT OF THE TRAP. `trap_bounds` is z 55..62; at `chase_speed`
# 5.0 the 1.2 s confirm window covers 6 m, so starting it at z=44 cannot accidentally take the
# SUCCESS branch. Getting that wrong would measure the opposite of the thing under test.
#
# ⚠️ E IS PRESSED THROUGH THE REAL RAYCAST (`player._try_interact()`), from the pose
# `walk_level6_breach.gd` proved reaches this door — never `purge.interact()` directly. Issue 30
# was a level unwinnable for every real player while its test passed, because the test called
# `interact()` instead of going through the ray.

const SCENE := "res://scenes/level_6_breach.tscn"
const SEAL_POS := Vector3(1.8, 0.1, 55.0)   # proven pose; the door's collider is 0.15 m thin in z
const SEAL_YAW := PI / 2.0                  # faces -x, at the door
const CREATURE_START := Vector3(0, 0, 44.0) # WardC — 11 m short of trap_bounds
const SAMPLES := [2.0, 10.0, 30.0]

var _t := 0.0
var _wall := 0.0
var _stage := 0
var _level: Node = null
var _player: CharacterBody3D = null
var _creature: Node = null
var _purge: Node = null
var _at_seal := Vector3.ZERO
var _sample_i := 0
var _recovered := false
var _rows: Array = []


func _initialize() -> void:
	Engine.time_scale = 10.0
	seed(7)
	change_scene_to_file(SCENE)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _find_creature() -> Node:
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		var s = x.get_script()
		if s and String(s.resource_path).ends_with("creature_object12.gd"):
			return x
	return null


func _body_of(c: Node) -> Node3D:
	var nodes: Array = []
	_all(c, nodes)
	for x in nodes:
		if x is StaticBody3D:
			return x
	return null


func _block_t() -> float:
	return float(_creature.get("_block_t"))


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 300.0:
		print("TIMEOUT at stage %d" % _stage)
		quit(1)
		return true
	_t += delta
	if _t < 2.5 or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		_creature = _find_creature()
		_purge = _level.get("_purge_chamber")
		if _player == null or _creature == null or _purge == null:
			print("FAILED to resolve player/creature/purge: %s %s %s"
				% [str(_player), str(_creature), str(_purge)])
			quit(1)
			return true
		print("== THE BREACH: does a FAILED purge freeze Object 12 permanently? ==")
		var b: AABB = _purge.get("trap_bounds")
		print("   trap_bounds %s  (z %.1f .. %.1f)" % [str(b), b.position.z, b.position.z + b.size.z])
		# Activate, then park the creature clear of the trap. ⚠️ The world transform lives on the
		# inner StaticBody3D — setting the outer node's position moves nothing (Issue 10).
		_creature.call("activate")
		var body := _body_of(_creature)
		if body:
			body.global_position = CREATURE_START
		_player.global_position = SEAL_POS
		_player.rotation.y = SEAL_YAW
		_player.force_update_transform()
		_t = 0.0
		return false

	match _stage:
		0:
			# Let the raycast resolve, then press E for real.
			var target = _player.get("_interact_target")
			if target != null and target.has_method("interact"):
				print("\n-- interact target resolved to %s; pressing E --" % target.name)
				print("   creature at %s, state %d, _block_t %.2f BEFORE the press"
					% [str(_creature.call("get_creature_position")),
						int(_creature.call("get_state")), _block_t()])
				_player.call("_try_interact")
				_at_seal = _creature.call("get_creature_position")
				print("   _block_t %.2f immediately AFTER the press" % _block_t())
				if _creature.has_signal("recovered"):
					_creature.connect("recovered", func() -> void: _recovered = true)
				_stage = 1
				_t = 0.0
			elif _t > 4.0:
				print("FAILED: the interact ray never resolved to the purge chamber (target=%s)"
					% [target])
				quit(1)
				return true
		1:
			if _sample_i >= SAMPLES.size():
				_stage = 2
				_t = 0.0
				return false
			if _t < float(SAMPLES[_sample_i]):
				return false
			var pos: Vector3 = _creature.call("get_creature_position")
			var moved := _at_seal.distance_to(pos)
			print("   t+%-5.0f s   _block_t %9.2f   moved %.2f m   state %d   recovered=%s"
				% [SAMPLES[_sample_i], _block_t(), moved,
					int(_creature.call("get_state")), str(_recovered)])
			_rows.append({"t": SAMPLES[_sample_i], "block": _block_t(), "moved": moved})
			_sample_i += 1
		2:
			# ---- THE RETRY. `_reopen_failed()` sets `_used = false`, so E works again.
			print("\n-- the game says it is retryable; pressing E again --")
			var before := _block_t()
			var t2 = _player.get("_interact_target")
			if t2 != null and t2.has_method("interact"):
				_player.call("_try_interact")
			else:
				_purge.call("interact")   # the ray may not resolve while the door is mid-reopen
			print("   _block_t %.2f -> %.2f" % [before, _block_t()])
			_rows.append({"t": -1.0, "block": _block_t(), "moved": 0.0})
			_stage = 3
			_t = 0.0
		3:
			if _t < 3.0:
				return false
			print("\n== VERDICT ==")
			var frozen := true
			for r in _rows:
				if float(r["t"]) > 0.0 and float(r["moved"]) > 0.05:
					frozen = false
			if frozen and _block_t() > 100.0:
				print("   CONFIRMED. A failed purge leaves the creature blocked for %.0f more"
					% _block_t())
				print("   seconds (%.2f hours) and it has not moved. The level's only win" % (_block_t() / 3600.0))
				print("   condition is luring it into that chamber, so the run is unwinnable.")
			elif not frozen:
				print("   NOT REPRODUCED: the creature moved. The hypothesis is dead; do not")
				print("   build a fix for it.")
			else:
				print("   INCONCLUSIVE — read the rows above.")
			quit(0)
			return true
	return false
