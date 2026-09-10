extends SceneTree

# ADVERSARIAL PROBE — `force_block()` no longer suppressing contact, plus the BATTER_REACH gate.
#
#   Godot --headless --path game --script res://tests/probe_breach_doors.gd
#
#   G  contact at exactly `contact_dist` through a CLOSED, battering door — is a slammed door
#      now lethal to the player who slammed it, and with no line-of-sight term?
#   H  slam while STAGGERED (the new exclusion) — does the door batter anyway?
#   I  slam / break / re-slam at the RESLAM_COOLDOWN 8 s boundary — total block per wall-clock
#   J  two doors within BATTER_REACH of one creature — does `force_block` chain past batter_time?
#   K  can every one of the four doors still be made to batter at all?  (the "a creature that
#      can no longer be delayed is as bad as the stunlock" half)
#
# ⚠️ G lets a REAL `contact_fatal` fire, which calls `Screamer.trigger()` and reloads the scene.
# It therefore runs LAST and the probe quits on the signal. Everything before it must not put the
# creature within `contact_dist` of the player.

const SCENE := "res://scenes/level_6_breach.tscn"

var _stage := 0
var _t := 0.0
var _sub := 0
var _mark := 0.0
var _creature: Node = null
var _level: Node = null
var _player: CharacterBody3D = null
var _doors: Dictionary = {}
var _contact := false
var _block_hist: Array = []


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
		elif _is_script(x, "slam_door.gd"):
			_doors[x.name] = x
		elif x is CharacterBody3D and x.is_in_group("player"):
			_player = x


func _process(d: float) -> bool:
	_t += d
	match _stage:
		0:
			if _t < 0.7:
				return false
			_grab()
			if _creature == null or _player == null:
				print("FATAL creature=%s player=%s" % [str(_creature), str(_player)])
				return true
			_creature.contact_fatal.connect(func(): _contact = true)
			print("=== probe_breach_doors ===")
			print("doors: ", _doors.keys())
			print("contact_dist=%.2f  BATTER_REACH=%.1f  RESLAM_COOLDOWN=%.1f  batter_time=%.1f" % [
				_creature.contact_dist, 4.0, 8.0,
				_doors.values()[0].batter_time])
			# Park the player far away for every test but G.
			_player.global_position = Vector3(0, 0.1, -2)
			_creature._active = true
			_creature.activate()
			_stage = 1
			_sub = 0
			_mark = _t
		1:
			_test_h()
		2:
			_test_k()
		3:
			_test_i()
		4:
			_test_j()
		5:
			_test_g()
		6:
			return true
	return false


# ---------------------------------------------------------------- H: slam while staggered

func _test_h() -> void:
	var door = _doors.get("Slam_WardB_WardC")
	if _sub == 0:
		print("\nH. SLAM A DOOR WHILE THE CREATURE IS STAGGERED")
		_creature._body.global_position = Vector3(0, 0, 39.5)
		_creature._state = 2
		_creature._shield = 0.0
		_creature._enter_stagger()
		if door._closed:
			door.interact()
		door.interact()   # slam
		print("   creature state=%d (4=STAGGERED)  door closed=%s" % [_creature.get_state(), str(door._closed)])
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 1.5:
		print("   after %.2f s of the level's own _tick_slam_doors: battering=%s block_t=%.2f" % [
			_t - _mark, str(door._battering), _creature._block_t])
		print("   verdict: %s" % ("STAGGERED correctly excluded — no batter"
			if not door._battering else "*** door battered a creature that was already down ***"))
		# clean up
		_creature._stagger_t = 999.0
		_sub = 2
		_mark = _t
	elif _sub == 2 and _t - _mark > 0.6:
		if door._battering:
			door._break_open()
		if door._closed:
			door.interact()
		door._reslam_lock_t = 0.0
		_creature._block_t = 0.0
		_stage = 2
		_sub = 0
		_mark = _t


# ---------------------------------------------------------------- K: can each door still batter

func _test_k() -> void:
	if _sub != 0:
		return
	print("\nK. CAN EACH DOOR STILL BE MADE TO BATTER?  (BATTER_REACH gate not over-tight)")
	# Approach positions: 1 m short of the door on the creature's side, target 6 m beyond.
	var cases := {
		"Slam_Corridor1_Junction1": [Vector3(0, 0, 12.0), Vector3(0, 0, 5.0)],
		"Slam_Atrium_WardA":        [Vector3(5.0, 0, 21.0), Vector3(0, 0, 22.0)],
		"Slam_ArchiveB_WardB":      [Vector3(-2.5, 0, 37.0), Vector3(-7, 0, 37.5)],
		"Slam_WardB_WardC":         [Vector3(0, 0, 39.5), Vector3(0, 0, 45.0)],
	}
	for nm in cases.keys():
		var door = _doors.get(nm)
		if door == null:
			print("   %-28s MISSING" % nm)
			continue
		if not door._closed:
			door.interact()
		door._battering = false
		_creature._block_t = 0.0
		_creature._state = 2
		# Sweep the creature's distance from the door along the approach.
		var here0: Vector3 = cases[nm][0]
		var target: Vector3 = cases[nm][1]
		var dirv: Vector3 = (here0 - door.global_position)
		dirv.y = 0.0
		dirv = dirv.normalized()
		var first_reach := -1.0
		var blocks_at := []
		for k in range(1, 121):
			var dist := 0.1 * float(k)
			var here: Vector3 = door.global_position + dirv * dist
			var seg_blocked: bool = door.check_blocks_path(here, target)
			var in_reach: bool = here.distance_to(door.global_position) <= 4.0
			if seg_blocked and in_reach and first_reach < 0.0:
				first_reach = dist
			if seg_blocked:
				blocks_at.append(dist)
		var span := "none"
		if not blocks_at.is_empty():
			span = "%.1f..%.1f m" % [blocks_at[0], blocks_at[-1]]
		print("   %-28s blocks_path over %s ; first batter-eligible at %.1f m %s" % [
			nm, span, first_reach,
			"" if first_reach > 0.0 else "  *** NEVER BATTERS ***"])
		if door._closed:
			door.interact()
	_stage = 3
	_sub = 0
	_mark = _t


# ---------------------------------------------------------------- I: re-slam at the boundary

func _test_i() -> void:
	var door = _doors.get("Slam_WardB_WardC")
	if _sub == 0:
		print("\nI. SLAM / BREAK / RE-SLAM AT THE 8 s COOLDOWN BOUNDARY")
		print("   ⚠️ FIRST VERSION OF THIS TEST MEASURED NOTHING: the player was parked at the level")
		print("   entrance (z = -2), so `get_current_target()` pointed AWAY from the door and")
		print("   `check_blocks_path` was correctly false — 0 s of block over 30 s, with the door")
		print("   never battering at all. The player has to be BEYOND the door.")
		_player.global_position = Vector3(0, 0.1, 45.5)   # WardC side, 4.5 m past the door
		_creature._body.global_position = Vector3(0, 0, 38.0)
		_creature._state = 2
		_creature._block_t = 0.0
		door._reslam_lock_t = 0.0
		if not door._closed:
			door.interact()
		_block_hist = []
		_sub = 1
		_mark = _t
	elif _sub == 1:
		_block_hist.append([_t - _mark, _creature._block_t, door._battering, door._closed,
			door._reslam_lock_t])
		# Keep the creature pinned so it cannot walk away and lose the door, and keep it in
		# CHASE so `_tick_slam_doors` does not skip it.
		_creature._body.global_position = Vector3(0, 0, 38.0)
		_creature._state = 2
		if _t - _mark > 30.0:
			var blocked := 0.0
			var prev := 0.0
			for row in _block_hist:
				if row[1] > 0.0:
					blocked += float(row[0]) - prev
				prev = float(row[0])
			print("   over 30 s of holding E on every cooldown expiry the creature was blocked")
			print("   for %.1f s (%.0f %%)." % [blocked, 100.0 * blocked / 30.0])
			var reslams := 0
			for row in _block_hist:
				if row[3]:
					reslams += 1
			print("   samples with the door CLOSED: %d of %d" % [reslams, _block_hist.size()])
			_stage = 4
			_sub = 0
			_mark = _t
			return
		# The attack: press E the instant the lock expires.
		if not door._closed and door._reslam_lock_t <= 0.0:
			door.interact()
			if door._closed:
				print("   t+%.2f  RE-SLAMMED" % (_t - _mark))


# ---------------------------------------------------------------- J: two doors at once

func _test_j() -> void:
	var a = _doors.get("Slam_ArchiveB_WardB")   # (-4, 37)
	var b = _doors.get("Slam_WardB_WardC")      # (0, 41)
	if _sub == 0:
		print("\nJ. TWO DOORS INSIDE BATTER_REACH OF ONE CREATURE")
		var here := Vector3(-2.0, 0, 39.0)
		print("   creature at %s: %.2f m from A, %.2f m from B (both < 4.0)" % [
			str(here), here.distance_to(a.global_position), here.distance_to(b.global_position)])
		_creature._body.global_position = here
		_creature._state = 2
		_creature._block_t = 0.0
		for dd in [a, b]:
			dd._battering = false
			dd._reslam_lock_t = 0.0
			if not dd._closed:
				dd.interact()
		# door A batters now
		a.start_battering(_creature)
		print("   A battering. block_t=%.2f" % _creature._block_t)
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 5.0:
		print("   t+%.1f  block_t=%.2f  (A batter_t=%.2f)" % [
			_t - _mark, _creature._block_t, a._batter_t])
		b.start_battering(_creature)
		print("   ...now B batters too -> block_t=%.2f  (force_block uses maxf)" % _creature._block_t)
		_sub = 2
	elif _sub == 2 and _t - _mark > 11.0:
		print("   t+%.1f  block_t=%.2f  A closed=%s  B closed=%s" % [
			_t - _mark, _creature._block_t, str(a._closed), str(b._closed)])
		_sub = 3
	elif _sub == 3 and _t - _mark > 17.0:
		print("   t+%.1f  block_t=%.2f  A closed=%s  B closed=%s" % [
			_t - _mark, _creature._block_t, str(a._closed), str(b._closed)])
		print("   -> total block from one creature standing between two doors: see above;")
		print("      chaining a second door EXTENDS the block past batter_time by design of maxf().")
		for dd in [a, b]:
			if dd._battering:
				dd._break_open()
			dd._reslam_lock_t = 0.0
		_creature._block_t = 0.0
		_stage = 5
		_sub = 0
		_mark = _t


# ---------------------------------------------------------------- G: contact through a closed door

func _test_g() -> void:
	var door = _doors.get("Slam_WardB_WardC")   # plane z = 41, yaw 0
	if _sub == 0:
		print("\nG. CONTACT THROUGH A CLOSED, BATTERING DOOR")
		if not door._closed:
			door.interact()
		# Player as close to the door as their own capsule allows: blocker spans z 40.95..41.05,
		# player radius 0.4 -> centre at 41.45 on the WardC side.
		_player.global_position = Vector3(0, 0.1, 41.45)
		_creature._body.global_position = Vector3(0, 0, 40.90)   # 0.10 m the other side
		_creature._state = 2
		_creature._block_t = 0.0
		var flat := Vector2(
			_creature.get_creature_position().x - _player.global_position.x,
			_creature.get_creature_position().z - _player.global_position.z).length()
		print("   player z=%.2f  creature z=%.2f  separation %.3f m  contact_dist %.2f" % [
			_player.global_position.z, _creature.get_creature_position().z, flat,
			_creature.contact_dist])
		print("   door closed=%s  blocker disabled=%s" % [str(door._closed), str(door._block_collider.disabled)])
		door.start_battering(_creature)
		print("   battering -> block_t=%.2f. one frame of the creature's _process follows." % _creature._block_t)
		_sub = 1
		_mark = _t
	elif _sub == 1 and _t - _mark > 0.4:
		print("   contact_fatal fired: %s" % str(_contact))
		print("   verdict: %s" % (
			"*** A CLOSED, BATTERING SLAM DOOR IS LETHAL THROUGH ITS OWN LEAF ***" if _contact
			else "no contact — the door still shields"))
		_stage = 6
