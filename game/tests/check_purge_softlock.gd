extends SceneTree

# AFTER YOU WIN, CAN YOU REACH THE EXIT?
#
#   Godot --headless --path game --script res://tests/check_purge_softlock.gd
#
# The Incinerator is z 55..62, `trap_bounds` is that whole room, and the EXIT DOOR IS INSIDE IT
# (`EXIT_SPAWN` (0, 0.1, 59.5) is "just inside the exit"). `_finish_purge()` does not reopen the
# blast door and `_block_collider` stays enabled — so a player who does exactly what the level's
# own note says, *"Lead it inside. Seal the door behind it"*, wins the level from the WRONG SIDE
# of a permanently sealed door.
#
# ⚠️ INFERRED FROM SOURCE BY AN ADVERSARIAL PASS, NOT OBSERVED IN PLAY — which is precisely why
# this exists before any fix does. `walk_level6_breach.gd` seals from exactly z = 55.0, standing
# ON the doorway plane, so it cannot distinguish the two sides and has never asked this.

const LEVEL := "res://scenes/level_6_breach.tscn"
# ⚠️ 2026-09-09 (cap #4): the seal room is ExitVault (west-wing dead-end) and the exit is at the
# spine's end (Incinerator) — so the exit is never behind the blast door and the original softlock
# is structurally impossible. This now verifies the blast door still vents AND the (separate) exit is
# reachable and unlocked after winning. Seal from the ArchiveC side of the door at z=48.
const OUTSIDE_Z := 46.5

var _t := 0.0
var _wall := 0.0
var _phase := -1
var _level: Node = null
var _player: CharacterBody3D = null
var _purge: Node = null
var _creature: Node = null
var _exit: Node3D = null
var _started := false
var _sealed_during := false
var _fails := 0
var _checks := 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _report() -> bool:
	print("== %d checks, %d failed ==" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return true


func _initialize() -> void:
	Engine.time_scale = 2.0
	seed(21)
	change_scene_to_file(LEVEL)


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 180.0:
		print("TIMEOUT in phase %d" % _phase)
		quit(1)
		return true
	_t += delta
	if current_scene == null or _t < 2.5:
		return false

	# ⚠️ A FREED NODE COMPARES `== null`, so without this the setup silently re-enters every
	# frame after a death reloads the scene — which is exactly what the first run did, printing
	# its header ten times and timing out.
	if _started and (not is_instance_valid(_level) or current_scene != _level):
		print("!! the scene reloaded — the player DIED before the probe could finish")
		quit(1)
		return true

	if _level == null:
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		_purge = _level.get("_purge_chamber")
		_creature = _level.get("_creature")
		if _player == null or _purge == null or _creature == null:
			print("missing node(s)")
			quit(1)
			return true
		for n in _level.find_children("*", "Node3D", true, false):
			if String(n.name).begins_with("ExitDoor"):
				_exit = n as Node3D
				break
		print("== PURGE SOFT-LOCK ==  exit at %s" % (str(_exit.global_position) if _exit else "?"))

		# Put the creature INSIDE the trap and the player OUTSIDE it, which is the arrangement
		# the level's note describes.
		# ⚠️ PLACED, NOT ACTIVATED. `_confirm_trap()` only reads `get_creature_position()` against
		# `trap_bounds`, so an inert creature confirms exactly the same — and an ACTIVE one
		# detected the parked player at 4.2 m, chased, and stood 0.79 m in front of them, which
		# is what blocked the interact ray for four runs of this probe. What is under test here
		# is the DOOR, not the chase.
		_creature.get("_body").global_position = Vector3(-7, 0, 51.0)   # inside ExitVault trap_bounds
		_player.global_position = Vector3(-7, 0.1, OUTSIDE_Z)           # ArchiveC side of the blast door
		# ⚠️ A Node3D's forward is −Z, so facing +z is PI, not 0. At 0 the interact ray pointed
		# back down the corridor, found NOTHING, the door was never sealed, and the creature —
		# which `interact()` would have frozen — chased the parked player down and killed them.
		_player.rotation.y = PI                   # face +z, at the door
		_player.velocity = Vector3.ZERO
		_started = true
		_phase = 0
		_t = 0.0
		return false

	# ⚠️ POLL `_interact_target` AND PRESS THROUGH `_try_interact()` — the idiom
	# `walk_level6_breach.gd` proved. The raycast needs a few `_physics_process` frames to
	# resolve, and a single sample 0.4 s in is not the same thing as waiting for it.
	if _phase == 0:
		var tgt = _player.get("_interact_target")
		if tgt == null or not tgt.has_method("interact"):
			if _t < 3.0:
				return false
			print("   ray from z=%.1f never resolved to anything — DIAGNOSTICS:" % OUTSIDE_Z)
			print("     player at %s  yaw %.2f  frozen=%s" % [str(_player.global_position),
				_player.rotation.y, str(_player.get("_input_frozen"))])
			print("     purge at  %s  used=%s" % [str((_purge as Node3D).global_position),
				str(_purge.get("_used"))])
			var cam := _player.get_node_or_null("Camera3D") as Camera3D
			if cam:
				var from: Vector3 = cam.global_position
				var fwd: Vector3 = -cam.global_transform.basis.z
				var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 3.0)
				q.collision_mask = 0xFFFFFFFF
				q.exclude = [_player.get_rid()]
				var hit: Dictionary = _level.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.is_empty():
					print("     manual ray -> NOTHING")
				else:
					var c: Node = hit["collider"]
					var chain := ""
					var n: Node = c
					while n != null and n != _level:
						chain = String(n.name) + ("/" + chain if chain != "" else "")
						n = n.get_parent()
					print("     manual ray -> %s   layer=%d  has interact()=%s  dist=%.2f"
						% [chain, (c.get("collision_layer") if c.get("collision_layer") != null else -1),
							str(c.has_method("interact")), from.distance_to(hit["position"])])
			quit(1)
			return true
		print("   ray from z=%.1f resolved to: %s (t=%.2f)" % [OUTSIDE_Z, tgt.name, _t])
		_player.call("_try_interact")
		var b0 = _purge.get("_block_collider")
		_sealed_during = b0 != null and not bool(b0.disabled)
		_phase = 1
		_t = 0.0
		return false

	# Wait past CLOSE_TO_CONFIRM_DELAY (1.2) + the purge sequence (~2.5), with slack.
	if _phase == 1:
		if _t < 8.0:
			return false
		var won := bool(_level.get("_creature_defeated"))
		var blocker = _purge.get("_block_collider")
		var sealed := blocker != null and not bool(blocker.disabled)
		var pz: float = _player.global_position.z
		_ok("CONTROL — the lure registered, so this run is measuring a WON level", won,
			"if this fails everything below is vacuous")
		_ok("the door SEALED on the press", _sealed_during,
			"if it never shut, 'it reopened' proves nothing")
		_ok("the blast door VENTS after the purge", not sealed,
			"sealed=%s (the creature is contained; the exit is elsewhere either way)" % str(sealed))
		print("   sealed player z = %.2f (ArchiveC side of the ExitVault blast door)" % pz)
		if not won:
			return _report()
		# The exit is at the spine's end (Incinerator), never behind this door — verify it is
		# genuinely reachable and unlocked after winning by standing at it and resolving the ray.
		_player.ai_active = false
		_player.global_position = Vector3(0, 0.1, 59.5)   # Incinerator, near the exit
		_player.rotation.y = PI                            # face +z toward the door at z~61.85
		_phase = 2
		_t = 0.0
		return false

	if _phase == 2:
		if _t < 3.0:
			return false
		var tgt2 = _player.get("_interact_target")
		var locked := true
		if _exit:
			locked = bool(_exit.get("extra_lock"))
		_ok("the exit (Incinerator, spine end) is reachable — its ray resolves after winning",
			tgt2 == _exit, "ray saw %s at %s" % [tgt2, str(_exit.global_position) if _exit else "?"])
		_ok("...and it is unlocked once the creature is contained", not locked)
		return _report()

	return false
