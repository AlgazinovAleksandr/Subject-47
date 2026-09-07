extends SceneTree

# ADVERSARIAL PROBE — the ROUTER and the SLAM DOORS now disagree about where the creature goes.
#
#   Godot --headless --path game --script res://tests/probe_breach_doorbypass.gd
#
# HYPOTHESIS. `creature_object12.gd` moves by assigning `_body.global_position` directly — a
# StaticBody3D, no sweep, no collision — so a closed SlamDoor has never physically stopped it.
# The ONLY thing that stops it is `level_6_breach.gd:_tick_slam_doors()` calling
# `door.check_blocks_path(here, target)` and, on a hit, `force_block()`.
#
# `target` there is `get_current_target()`, i.e. in CHASE the PLAYER'S RAW POSITION. Until
# 2026-09-07 that was also exactly the line the creature walked, so the test and the travel were
# the same segment. `_steer()` broke that identity: the creature now walks a DOGLEG through
# doorways while the door test still measures the STRAIGHT LINE.
#
# So a door that the routed path goes through, but which is not on the straight line, is never
# told to batter — and because nothing else can stop the creature, it walks through a closed
# steel door with no block, no thud and no delay.
#
#   B1  enumerate (creature room, player room) pairs where the ROUTE crosses a closed door but
#       `check_blocks_path(here, player)` is false
#   B2  drive it: does the creature's own mover physically cross the plane of a CLOSED door
#       whose `_battering` is false?
#   B3  the control — the head-on case that the level's own tests use, which must still batter

const SCENE := "res://scenes/level_6_breach.tscn"
const DT := 1.0 / 60.0

var _stage := 0
var _t := 0.0
var _creature: Node = null
var _doors: Array = []
var _rooms: Array = []
# ⚠️ A MEMBER, NOT A LOCAL. GDScript lambdas capture locals BY VALUE, so `var fired := false`
# followed by `signal.connect(func(): fired = true)` mutates the lambda's own copy and the outer
# variable never changes. The first run of B4 printed "hiding also blocks contact" off exactly
# that — a probe that could only ever report false.
var _b4_fired := false


func _initialize() -> void:
	seed(7)
	change_scene_to_file(SCENE)


func _is_script(n: Node, base: String) -> bool:
	var s = n.get_script()
	return s != null and String(s.resource_path).ends_with(base)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _grab() -> void:
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if _is_script(x, "creature_object12.gd"):
			_creature = x
		elif _is_script(x, "slam_door.gd"):
			_doors.append(x)
	_rooms = _creature._rooms


# Does the segment a->b pass through this door's OPENING (the block collider's own footprint)?
func _crosses_opening(door: Node, a: Vector3, b: Vector3) -> bool:
	var bc: CollisionShape3D = door._block_collider
	var shp: BoxShape3D = bc.shape as BoxShape3D
	var la: Vector3 = door.to_local(a)
	var lb: Vector3 = door.to_local(b)
	la.y -= bc.position.y
	lb.y -= bc.position.y
	# generous in z (a step can jump the 0.1 m slab), exact in x
	var half := Vector3(shp.size.x * 0.5, shp.size.y * 0.5, 0.30)
	var aabb := AABB(-half, half * 2.0)
	return aabb.intersects_segment(la, lb) != null


func _process(d: float) -> bool:
	_t += d
	if _stage == 0:
		if _t < 0.8:
			return false
		_grab()
		if _creature == null:
			print("FATAL: no creature")
			return true
		print("=== probe_breach_doorbypass ===  doors=%d" % _doors.size())
		_stage = 1
		return false
	if _stage == 1:
		_b1_b2()
		return true
	return false


func _b1_b2() -> void:
	print("\nB1/B2. ROUTED PATH vs `check_blocks_path(here, raw_target)`")
	print("       every ordered room pair; creature at room centre, player at room centre")
	print("       BATTER_REACH is 4.0 m and the level only calls check_blocks_path inside it.\n")
	var bypasses := 0
	var pairs := 0
	# ⚠️ THE CONTROL. "0 bypasses" is meaningless unless the creature actually crossed closed
	# doors on these legs — a probe whose `crossed` set is always empty reports 0 for ever.
	var pairs_that_crossed := 0
	var pairs_told := 0
	var lines: Array = []
	for door in _doors:
		if not door._closed:
			door.interact()          # slam every door shut
		door._battering = false
		door._reslam_lock_t = 0.0
	for i in range(_rooms.size()):
		for j in range(_rooms.size()):
			if i == j:
				continue
			pairs += 1
			var start: Vector3 = _rooms[i]["c"]
			var target: Vector3 = _rooms[j]["c"]
			# Walk the real mover, recording which closed doors the body physically crosses
			# and whether the level would ever have told them to batter.
			_creature._body.global_position = start
			_creature._state = 2                 # CHASE
			_creature._block_t = 0.0
			var prev := start
			var crossed := {}
			var told := {}
			for k in range(40000):
				_creature._move_toward(target, 5.0, DT)
				var now: Vector3 = _creature.get_creature_position()
				for door in _doors:
					var dn: String = door.name
					if _crosses_opening(door, prev, now):
						crossed[dn] = true
					# the level's own per-frame test, verbatim
					if now.distance_to(door.global_position) <= 4.0 \
							and door.check_blocks_path(now, target):
						told[dn] = true
				prev = now
				if Vector2(now.x - target.x, now.z - target.z).length() <= 0.6:
					break
			if not crossed.is_empty():
				pairs_that_crossed += 1
			if not told.is_empty():
				pairs_told += 1
			for dn in crossed.keys():
				if not told.has(dn):
					bypasses += 1
					if lines.size() < 14:
						lines.append("  room %2d -> %2d : walked THROUGH closed %s, never told to batter"
							% [i, j, dn])
	print("  CONTROL: %d of %d pairs physically crossed at least one CLOSED door" % [
		pairs_that_crossed, pairs])
	print("  CONTROL: %d of %d pairs were told to batter at least one door" % [pairs_told, pairs])
	print("  %d of %d ordered room pairs walk through a CLOSED slam door with no block" % [
		bypasses, pairs])
	for l in lines:
		print(l)

	print("\nB3. CONTROL — the head-on case the level's own tests use")
	var door2 = null
	for door in _doors:
		if door.name == "Slam_WardB_WardC":
			door2 = door
	if door2 == null:
		print("  (missing)")
		return
	_creature._body.global_position = Vector3(0, 0, 39.0)
	_creature._state = 2
	var tgt := Vector3(0, 0, 45.0)
	print("  creature (0,0,39) -> player (0,0,45), door at (0,0,41): dist %.2f  blocks=%s" % [
		_creature.get_creature_position().distance_to(door2.global_position),
		str(door2.check_blocks_path(_creature.get_creature_position(), tgt))])
	print("  -> the control must be TRUE, or this probe is measuring nothing")
	_b4()


# B4 — hiding does NOT stop contact. `_detect_player()` short-circuits on `is_hidden()`, but
# `_tick_chase()` calls `_check_contact()` FIRST and that check has no such guard. So a player
# who ducks into a locker with the creature already inside `contact_dist` is still killed, and
# `enter_hiding()` TELEPORTS them to `hide_anchor()` — 0.4 m out into the room — which can move
# them toward it. Runs last: a real contact fires Screamer and reloads the scene.
func _b4() -> void:
	print("\nB4. DOES HIDING STOP CONTACT?")
	var player: Node = get_first_node_in_group("player")
	var spot = null
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if _is_script(x, "hiding_spot.gd"):
			spot = x
			break
	if spot == null or player == null:
		print("  (no hiding spot / player)")
		return
	# ⚠️ MY OWN FIRST VERSION OF THIS TEST MEASURED NOTHING: `_creature._player` had never been
	# resolved (the creature had not run a single `_process` frame), so `_detect_player()` and
	# `_check_contact()` both threw on a null and the probe printed "hiding also blocks contact"
	# off the back of two SCRIPT ERRORs. Resolve the player first.
	if not _creature._ensure_player():
		print("  (could not resolve the player on the creature)")
		return
	var anchor: Vector3 = spot.hide_anchor()
	player.global_position = anchor
	spot.interact()
	print("  hidden=%s at %v (anchor %v)" % [str(player.is_hidden()), player.global_position, anchor])
	_creature._body.global_position = anchor + Vector3(0.7, 0, 0)
	_creature._state = 2      # CHASE
	_creature._active = true
	_creature._block_t = 0.0
	_b4_fired = false
	_creature.contact_fatal.connect(func(): _b4_fired = true)
	print("  creature 0.70 m away, in CHASE. detect_player()=%s" % str(_creature._detect_player()))
	_creature._tick_chase(0.016)
	print("  after one _tick_chase: contact_fatal=%s" % str(_b4_fired))
	print("  verdict: %s" % ("*** A HIDDEN PLAYER IS STILL KILLED BY CONTACT ***" if _b4_fired
		else "hiding also blocks contact"))
