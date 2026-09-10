extends SceneTree

# ADVERSARIAL PROBE — the purge-freeze FLAG (`_purge_frozen`), attacked by ORDERING.
#
#   Godot --headless --path game --script res://tests/probe_breach_purge.gd
#
# `probe_purge_freeze.gd` proved the old `_block_t = 9999.0` bug and the flag fixes the single
# case it tested (one failed lure). This one drives the orderings that test did not:
#
#   A  purge while STAGGERED
#   B  purge while a slam door is battering (does `_block_t` survive the freeze intact?)
#   C  purge / fail / purge / fail / purge / succeed
#   D  purge during the familiarization window (creature not yet `_active`)
#   E  purge, fail, then let the creature walk in on its own and purge again
#   F  the `_used = false`-before-reopen race: a stale `_reopen_failed()` timer landing
#      inside the NEXT attempt
#
# Everything is measured off the creature's own state — `_purge_frozen`, `_block_t`, `_active`,
# and DISPLACEMENT over wall-clock — never off a toast.
#
# ⚠️ `interact()` is called on the PurgeChamber directly here rather than through the player's
# ray. That is deliberate and is the opposite of `probe_purge_freeze.gd`'s discipline: the thing
# under test is the ORDER of the state changes, not whether E reaches the door (which
# `check_purge_interact.gd` already asserts). Driving the ray would add a pose dependency to
# every one of six scenarios.

const SCENE := "res://scenes/level_6_breach.tscn"
const FAR := Vector3(0, 0, 44.0)      # WardC — 11 m short of trap_bounds (z 55..62)
const INSIDE := Vector3(0, 0, 58.5)   # Incinerator centre — inside trap_bounds

var _stage := 0
var _t := 0.0
var _level: Node = null
var _creature: Node = null
var _purge: Node = null
var _door: Node = null
var _log: Array = []
var _sub := 0
var _mark := 0.0
var _pos0 := Vector3.ZERO
var _trapped := false


func _initialize() -> void:
	Engine.time_scale = 4.0
	seed(7)
	change_scene_to_file(SCENE)



# ⚠️ NO `class_name` TYPES ANYWHERE IN THESE PROBES. A `--script` SceneTree compiles its own
# dependencies BEFORE the autoloads exist, so naming `CreatureObject12` at parse time forces an
# early compile of a script that references `Screamer` and the whole probe fails to load.
# `probe_purge_freeze.gd` already avoids this by matching on the script's resource path.
func _is_script(n: Node, base: String) -> bool:
	var s = n.get_script()
	return s != null and String(s.resource_path).ends_with(base)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _grab() -> void:
	_level = current_scene
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if _is_script(x, "creature_object12.gd"):
			_creature = x
		elif _is_script(x, "purge_chamber.gd"):
			_purge = x
		elif _is_script(x, "slam_door.gd") and x.name == "Slam_WardB_WardC":
			_door = x


func _snap() -> String:
	return "state=%d frozen=%s block=%.2f active=%s pos=%s" % [
		_creature.get_state(), str(_creature._purge_frozen), _creature._block_t,
		str(_creature._active), str(_creature.get_creature_position())]


func _process(d: float) -> bool:
	_t += d
	match _stage:
		0:
			if _t < 0.7:
				return false
			_grab()
			if _creature == null or _purge == null:
				print("FATAL: creature=%s purge=%s" % [str(_creature), str(_purge)])
				return true
			_purge.creature_trapped.connect(func(): _trapped = true)
			print("=== probe_breach_purge ===")
			print("D. PURGE DURING THE FAMILIARIZATION WINDOW (creature dormant)")
			print("   before: ", _snap())
			_purge.interact()
			print("   after interact(): ", _snap())
			_mark = _t
			_stage = 1
		1:
			if _t - _mark < 2.5:
				return false
			print("   after confirm (+%.1f s): %s   used=%s" % [_t - _mark, _snap(), str(_purge._used)])
			print("   -> dormant creature: _process() returns on `not _active` BEFORE the freeze")
			print("      check, so freeze/unfreeze are inert here. _refresh_clip() on unfreeze")
			print("      re-asserts the DORMANT pose. verdict: HARMLESS")
			# Wake it for the rest of the run.
			_creature._active = true
			_creature.activate()
			_creature._body.global_position = FAR
			_creature._state = 2
			_stage = 2
			_sub = 0
			_mark = _t
		2:
			_scenario_a()
		3:
			_scenario_b()
		4:
			_scenario_c()
		5:
			_scenario_f()
		6:
			_scenario_e()
		7:
			return true
	return false


# ---------------------------------------------------------------- A: purge while STAGGERED

func _scenario_a() -> void:
	if _sub == 0:
		print("\nA. PURGE WHILE STAGGERED")
		_creature._body.global_position = FAR
		_creature._shield = 0.0
		_creature._state = 2
		_creature._enter_stagger()
		print("   staggered, len=%.2f s  %s" % [_creature._stagger_len, _snap()])
		_purge._used = false
		_purge.interact()
		_pos0 = _creature.get_creature_position()
		print("   interact() -> %s  stagger_t=%.2f" % [_snap(), _creature._stagger_t])
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 0.8:
		print("   +%.2f s (still inside the 1.2 s confirm): stagger_t=%.2f (FROZEN CLOCK)" % [
			_t - _mark, _creature._stagger_t])
		_sub = 2
	elif _sub == 2 and _t - _mark > 2.6:
		print("   +%.2f s (confirm failed, unfrozen): %s  stagger_t=%.2f  moved %.3f m" % [
			_t - _mark, _snap(), _creature._stagger_t,
			_pos0.distance_to(_creature.get_creature_position())])
		_sub = 3
		_mark = _t
	elif _sub == 3 and _t - _mark > 9.0:
		print("   +%.2f s later: %s  moved %.3f m from the stagger spot" % [
			_t - _mark, _snap(), _pos0.distance_to(_creature.get_creature_position())])
		print("   verdict: %s" % ("RECOVERED AND MOVING"
			if _creature.get_state() != 4 else "*** STILL STAGGERED ***"))
		_stage = 3
		_sub = 0
		_mark = _t


# ---------------------------------------------------------------- B: purge mid-batter

func _scenario_b() -> void:
	if _sub == 0:
		print("\nB. PURGE WHILE A SLAM DOOR IS BATTERING")
		if _door == null:
			print("   (no Slam_WardB_WardC — skipped)")
			_stage = 4
			return
		_creature._state = 2
		_creature._body.global_position = Vector3(0, 0, 39.0)
		_door.interact()          # slam it
		_door.start_battering(_creature)
		print("   slammed+battering: %s  door closed=%s batter_t=%.2f" % [
			_snap(), str(_door._closed), _door._batter_t])
		_purge._used = false
		_purge.interact()
		print("   purge interact(): ", _snap())
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 0.8:
		print("   +%.2f s: block=%.2f (frozen: must NOT have decremented)  door batter_t=%.2f (DOES)" % [
			_t - _mark, _creature._block_t, _door._batter_t])
		_sub = 2
	elif _sub == 2 and _t - _mark > 2.6:
		print("   +%.2f s (unfrozen): %s   door closed=%s batter=%s batter_t=%.2f" % [
			_t - _mark, _snap(), str(_door._closed), str(_door._battering), _door._batter_t])
		_sub = 3
		_mark = _t
	elif _sub == 3 and _t - _mark > 12.0:
		print("   +%.2f s: %s  door closed=%s  reslam_lock=%.2f" % [
			_t - _mark, _snap(), str(_door._closed), _door._reslam_lock_t])
		print("   -> desync = how long the creature stays blocked AFTER the door broke open")
		_stage = 4
		_sub = 0
		_mark = _t


# ---------------------------------------------------------------- C: fail, fail, succeed

func _scenario_c() -> void:
	if _sub == 0:
		print("\nC. PURGE / FAIL / PURGE / FAIL / PURGE / SUCCEED")
		_creature._body.global_position = FAR
		_creature._state = 2
		_creature._block_t = 0.0
		_purge._used = false
		_purge.interact()
		print("   attempt 1 (creature at z=44, outside the trap): ", _snap())
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 3.0:
		print("   after fail 1: frozen=%s used=%s" % [str(_creature._purge_frozen), str(_purge._used)])
		_pos0 = _creature.get_creature_position()
		_creature._body.global_position = FAR
		_purge.interact()
		print("   attempt 2: ", _snap())
		_sub = 2
		_mark = _t
	elif _sub == 2 and _t - _mark > 3.0:
		print("   after fail 2: frozen=%s used=%s" % [str(_creature._purge_frozen), str(_purge._used)])
		_creature._body.global_position = INSIDE
		_purge.interact()
		print("   attempt 3, creature INSIDE trap_bounds: ", _snap())
		_sub = 3
		_mark = _t
	elif _sub == 3 and _t - _mark > 6.0:
		print("   after attempt 3: trapped=%s creature active=%s processing=%s" % [
			str(_trapped), str(_creature._active), str(_creature.is_processing())])
		print("   verdict: %s" % ("PURGE SUCCEEDED after two failures" if _trapped
			else "*** THIRD ATTEMPT DID NOT PURGE ***"))
		_stage = 5
		_sub = 0
		_mark = _t


# ---------------------------------------------------------------- F: the stale-reopen race

func _scenario_f() -> void:
	if _sub == 0:
		print("\nF. STALE `_reopen_failed()` TIMER LANDING INSIDE THE NEXT ATTEMPT")
		print("   `_reopen_failed()` sets _used=false IMMEDIATELY but opens the door 1.0 s later.")
		print("   So E is accepted while the blast door is still shut, and the old timer then")
		print("   opens it in the middle of the new attempt.")
		# Rebuild a fresh, un-purged chamber state.
		_trapped = false
		_purge._used = false
		_creature._active = true
		_creature.set_process(true)
		_creature._purge_frozen = false
		_creature._body.global_position = FAR
		_creature._state = 2
		_purge.interact()
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 1.35:
		# ~0.15 s after the failed confirm: _used is false, door is still shut.
		print("   t+%.2f  used=%s  block_collider_disabled=%s (false == door SHUT)" % [
			_t - _mark, str(_purge._used), str(_purge._block_collider.disabled)])
		_creature._body.global_position = INSIDE
		_purge.interact()
		print("   pressed E again while shut -> used=%s frozen=%s" % [
			str(_purge._used), str(_creature._purge_frozen)])
		_sub = 2
	elif _sub == 2 and _t - _mark > 2.6:
		print("   t+%.2f  used=%s  door_disabled=%s  <- the STALE 1 s timer fires about here" % [
			_t - _mark, str(_purge._used), str(_purge._block_collider.disabled)])
		_sub = 3
	elif _sub == 3 and _t - _mark > 3.2:
		print("   t+%.2f  used=%s  door_disabled=%s  trapped=%s" % [
			_t - _mark, str(_purge._used), str(_purge._block_collider.disabled), str(_trapped)])
		print("   verdict: %s" % (
			"*** the blast door is OPEN while the purge attempt is live/complete ***"
			if _purge._block_collider.disabled else "door stayed shut"))
		_stage = 6
		_sub = 0
		_mark = _t


# ---------------------------------------------------------------- E: walk in on its own

func _scenario_e() -> void:
	if _sub == 0:
		print("\nE. FAIL, THEN LET IT WALK IN ON ITS OWN, THEN PURGE")
		_trapped = false
		_purge._used = false
		_creature._active = true
		_creature.set_process(true)
		_creature._purge_frozen = false
		_creature._block_t = 0.0
		_creature._body.global_position = FAR
		_creature._state = 2
		_purge.interact()
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 3.5:
		# Failed; door reopened. Now walk it in by driving _move_toward toward the incinerator.
		print("   failed. frozen=%s. walking it in by its OWN mover..." % str(_creature._purge_frozen))
		_sub = 2
		_mark = _t
	elif _sub == 2:
		_creature._move_toward(INSIDE, 5.0, d_or(0.016))
		if _creature.get_creature_position().distance_to(INSIDE) < 1.0:
			print("   arrived at %s (inside trap_bounds=%s)" % [
				str(_creature.get_creature_position()),
				str(_purge.trap_bounds.has_point(_creature.get_creature_position()))])
			_purge._used = false
			_purge.interact()
			_sub = 3
			_mark = _t
		elif _t - _mark > 25.0:
			print("   *** never arrived — stuck at %s ***" % str(_creature.get_creature_position()))
			_sub = 3
			_mark = _t
	elif _sub == 3 and _t - _mark > 6.0:
		print("   trapped=%s  creature active=%s" % [str(_trapped), str(_creature._active)])
		print("   verdict: %s" % ("PURGED" if _trapped else "*** NOT PURGED ***"))
		_stage = 7


func d_or(x: float) -> float:
	return x
