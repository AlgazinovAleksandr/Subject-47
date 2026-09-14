extends SceneTree

# C1 (2026-09-13): the Corridor is 455 m with three blind side passages, each of which shuts you
# in for ten seconds. This drives the REAL player (ai_* surface) from the spawn to the exit door,
# turning into every spur, walking to its end (the shut-in), waiting it out, and walking back —
# so the geometry, the mouths, the doors and the traps are proved by a body under gravity.
#
#   Godot --headless --path game --script res://tests/walk_corridor.gd
#
# ⚠️ The beartraps are disarmed for the walk (they pin the body for 7 s and then charge 40, and
# a walker that steps on four of them dies): this test is about the corridor, not the traps —
# `check_corridor_doors.gd` and friends own those. The noclip fall is not reached (it stops 20 m
# short of the door), and events that add panic are tolerated up to the bar.

const SPEED := 4.0
const MAX_SECONDS := 700.0   # 2026-09-13: three mash escapes + two fork loops on top of the 455 m

var _scene: Node
var _p: CharacterBody3D
var _route: Array = []
var _leg := 0
var _t := 0.0
var _fails := 0
var _checks := 0
var _wait_until := -1.0
var _stall := 0
var _stall_t := 0.0
var _last := Vector3.ZERO
var _shut_seen := 0
var _mash_spur = null
var _shut_at := 0.0
var _mash_t := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/corridor.tscn")


func _pt(d: float) -> Vector3:
	return (_scene.call("_path_point", d) as Dictionary)["pos"]


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	_t += delta
	if _scene == null:
		if _t < 1.0:
			return false
		_scene = current_scene
		_p = _scene.get_node("Player")
		_p.set("ai_active", true)
		for n in _scene.get_children():
			if n is Area3D and n.get_script() != null and String(n.get_script().resource_path).ends_with("beartrap.gd"):
				(n as Area3D).monitoring = false
		# The route: every 10 m of path, with a detour into each spur.
		var spurs: Array = _scene.call("spurs")
		var total: float = float(_scene.get("_total_len"))
		# ⚠️ EVERY CORNER IS A WAYPOINT. A 10 m cadence alone aims the walker diagonally across
		# a corner into the wall beside it (the first run pinned itself against Seg0WallA and the
		# clock at d 47, aiming at d 54 round the 50 m corner).
		var ds: Array[float] = []
		var d := 4.0
		while d < total - 20.0:
			ds.append(d)
			d += 10.0
		for seg in (_scene.get("_segments") as Array):
			var sd: float = float(seg["start_d"])
			if sd > 0.5 and sd < total - 20.0:
				ds.append(sd)
		for e in spurs:
			ds.append(float((_scene.get("SIDE_PASSAGES") as Array)[int(e["index"])]["at"]))
		var forks: Array = _scene.call("forks")
		for f in forks:
			ds.append(float((_scene.get("FORKS") as Array)[int(f["index"])]["at"]))
		# C4: the corner branches are keyed by their corner, which is already a waypoint (a
		# segment start); the detour legs are inserted when that waypoint is reached.
		ds.sort()
		for dd in ds:
			var spur_here = null
			for e in spurs:
				if is_equal_approx(float((_scene.get("SIDE_PASSAGES") as Array)[int(e["index"])]["at"]), dd):
					spur_here = e
			if spur_here != null:
				var e2: Dictionary = spur_here
				_route.append({"pos": _pt(dd), "note": "spur %d mouth" % int(e2["index"])})
				var deep: Vector3 = (e2["mouth"] as Vector3) + (e2["dir"] as Vector3) * (float(e2["len"]) - 1.0)
				_route.append({"pos": deep, "note": "spur %d end" % int(e2["index"]), "wait_spur": e2})
				_route.append({"pos": _pt(dd), "note": "spur %d out" % int(e2["index"])})
			else:
				var fork_here = null
				for f in forks:
					if is_equal_approx(float((_scene.get("FORKS") as Array)[int(f["index"])]["at"]), dd):
						fork_here = f
				if fork_here != null:
					# C2: walk the WRONG branch round its loop and back out through the door.
					var f2: Dictionary = fork_here
					var dir3: Vector3 = f2["dir"]
					_route.append({"pos": _pt(dd), "note": "fork %d mouth" % int(f2["index"])})
					_route.append({"pos": (f2["mouthA"] as Vector3) + dir3 * 1.6, "note": "fork %d in" % int(f2["index"]), "fork_enter": f2})
					_route.append({"pos": f2["cornerA"], "note": "fork %d corner A" % int(f2["index"])})
					_route.append({"pos": f2["cornerC"], "note": "fork %d corner C" % int(f2["index"]), "fork_corner": f2})
					_route.append({"pos": (f2["mouthC"] as Vector3) + dir3 * 1.2, "note": "fork %d door" % int(f2["index"])})
					_route.append({"pos": (f2["mouthC"] as Vector3) - dir3 * 1.2, "note": "fork %d out" % int(f2["index"])})
				else:
					_route.append({"pos": _pt(dd), "note": "d=%.0f" % dd})
					for cb in (_scene.call("corner_branches") as Array):
						var c: Dictionary = cb
						if not is_equal_approx(float(c["corner"]), dd):
							continue
						var dir3: Vector3 = c["dir"]
						var m3: Vector3 = c["mouth"]
						if String(c["kind"]) == "loop":
							# walk to the branch's end: the loop-back puts us at the previous corner
							_route.append({"pos": m3 + dir3 * (float(c["len"]) - 1.0), "note": "branch %d loop end" % int(c["index"]), "branch_loop": c})
						else:
							var rl: float = float(c["len"]) - 6.0
							_route.append({"pos": m3 + dir3 * (rl + 1.6), "note": "branch %d blind room" % int(c["index"]), "branch_blind": c})
							_route.append({"pos": (_scene.get_node("Blind%dLever" % int(c["index"])) as Node3D).global_position * Vector3(1, 0, 1) - dir3 * 0.6, "note": "branch %d lever" % int(c["index"]), "branch_lever": c})
							_route.append({"pos": m3 - dir3 * 1.5, "note": "branch %d out" % int(c["index"])})
		_route.append({"pos": _pt(total - 20.0), "note": "20 m short of 217"})
		_last = _p.global_position
		return false
	if _t > MAX_SECONDS:
		_ok("walked the whole corridor in time", false, "stalled at leg %d of %d (%s)" % [_leg, _route.size(), _route[_leg]["note"] if _leg < _route.size() else "-"])
		return _finish()
	if _wait_until > 0.0:
		_p.set("ai_move_dir", Vector2.ZERO)
		# C1 (2026-09-13): the shut-in is a Space-mash escape. On the "note" and "plea" spurs
		# mash through the shipping SpurEscape.press() (Input is dead headless) and expect the
		# door to give well before the fallback clock; on the "mirror" spur do nothing and
		# expect the fallback (SPUR_SHUT_TIME) to open it.
		if _mash_spur != null:
			var e3: Dictionary = _mash_spur
			var kind3 := String(e3["kind"])
			if kind3 == "bell":
				var beat: Node = _scene.get_node_or_null("Spur%dBellBeat" % int(e3["index"]))
				if beat != null and bool(beat.call("is_done")):
					_ok("spur %d (bell): the steps arrived and the door gave" % int(e3["index"]), not bool((e3["door"] as Node).get("_closed")))
					_ok("spur %d (bell): the guest's card is on the desk (never turned round)" % int(e3["index"]), _scene.get_node_or_null("BellCard") != null)
					_mash_spur = null
					_wait_until = -1.0
					_p.call("restore_flashlight")
					_leg += 1
					return false
				return false
			if kind3 == "cupboard":
				var cb: Node = _scene.get_node_or_null("Spur%dCupboardBeat" % int(e3["index"]))
				if cb != null and bool(cb.call("is_released")):
					_ok("spur %d (cupboard): sealed, held still, released" % int(e3["index"]), bool(cb.call("is_sealed")))
					_ok("spur %d (cupboard): ...on stillness, not the fallback" % int(e3["index"]), _t - _shut_at < 14.0)
					_mash_spur = null
					_wait_until = -1.0
					_p.call("restore_flashlight")
					_leg += 1
					return false
				return false
			var esc: Node = _scene.get_node_or_null("Spur%dEscape" % int(e3["index"]))
			var door3: Node = e3["door"]
			if String(e3["kind"]) != "mirror" and esc != null and bool(esc.call("is_active")):
				_mash_t += delta
				if _mash_t >= 0.12:
					_mash_t = 0.0
					esc.call("press")
			if not bool(door3.get("_closed")):
				var took: float = _t - _shut_at
				if String(e3["kind"]) == "mirror":
					_ok("spur %d (%s): the FALLBACK clock opened it (~SPUR_SHUT_TIME)" % [int(e3["index"]), e3["kind"]],
						took >= float(_scene.get("SPUR_SHUT_TIME")) - 0.5, "%.1f s" % took)
				else:
					_ok("spur %d (%s): mashing forced the door long before the fallback" % [int(e3["index"]), e3["kind"]],
						took < float(_scene.get("SPUR_SHUT_TIME")) * 0.6, "%.1f s" % took)
				_ok("spur %d: the escape UI is gone once the door gives" % int(e3["index"]),
					esc == null or not bool(esc.call("is_active")))
				_mash_spur = null
				_wait_until = -1.0
				_leg += 1
				return false
		if _t < _wait_until:
			return false
		_wait_until = -1.0
		if _mash_spur != null:
			_ok("spur %d: the door gave within the wait" % int((_mash_spur as Dictionary)["index"]), false, "still shut after the fallback")
			_mash_spur = null
			_leg += 1
			return false
	if _leg >= _route.size():
		_ok("the player reached 20 m short of room 217", true)
		_ok("every spur shut the player in once", _shut_seen == 3, "%d of 3" % _shut_seen)
		_ok("the player is alive (no Screamer reload)", is_instance_valid(_p) and _p.get_panic_ratio() < 1.0)
		return _finish()
	var target: Vector3 = _route[_leg]["pos"]
	var here := _p.global_position
	var to := Vector3(target.x - here.x, 0.0, target.z - here.z)
	# The loop-back trap's box catches the body ~1.4 m before the leg's target, so a loop-end
	# leg "arrives" the moment the level has thrown us back — never by distance.
	var bl_early = _route[_leg].get("branch_loop", null)
	if bl_early != null and int(bl_early["loops"]) >= 1:
		to = Vector3.ZERO
	if to.length() < 0.6:
		var bl = _route[_leg].get("branch_loop", null)
		if bl != null:
			# the loop-back fired as we arrived: we are now at the previous corner
			var here2 := _p.global_position
			var d_now: float = float(_scene.call("_nearest_path_distance", here2))
			_ok("branch %d: the loop-back put us at the previous corner (d %.0f, expected ~%.0f)" % [int(bl["index"]), d_now, float(bl["corner"]) - 45.0],
				absf(d_now - (float(bl["corner"]) - 45.0)) < 6.0)
			_ok("branch %d: ...and it counts its loops" % int(bl["index"]), int(bl["loops"]) >= 1)
			# resume the walk from here — VIA THE CORNER. The next waypoint is past the corner,
			# and a straight line from the previous corner to it hugs the side wall and snags
			# on the ajar door at d 300 (measured: 6 s stalled at (38.9, 161.7)). A player walks
			# the centreline; so does the walker.
			_route.insert(_leg + 1, {"pos": _pt(float(bl["corner"])), "note": "back at corner %.0f" % float(bl["corner"])})
			_leg += 1
			return false
		var bb = _route[_leg].get("branch_blind", null)
		if bb != null:
			var room: Node = bb["room"]
			_ok("branch %d: stepping into the blind room seals it" % int(bb["index"]), bool(room.call("is_sealed")))
			_ok("branch %d: ...and the torch is locked" % int(bb["index"]), not bool(_p.call("is_flashlight_on")))
			# Stand in the dark for the map flash (MAP_FLASH_DELAY 1.2 s + MAP_FLASH_S) before
			# going for the lever — a walker that knows where the lever is reaches it in ~1 s,
			# before the beat a player would be finding their bearings from.
			_wait_until = _t + float(room.get("MAP_FLASH_DELAY")) + float(room.get("MAP_FLASH_S")) + 0.4
			_leg += 1
			return false
		var blv = _route[_leg].get("branch_lever", null)
		if blv != null:
			var room2: Node = blv["room"]
			_ok("branch %d: the map flashed once on the way in" % int(blv["index"]), bool(room2.call("map_shown")))
			(_scene.get_node("Blind%dLever" % int(blv["index"])) as Node).call("interact")
			_ok("branch %d: the lever releases the room" % int(blv["index"]), bool(room2.call("is_released")))
			_ok("branch %d: ...and the torch is back" % int(blv["index"]), bool(_p.call("is_flashlight_on")))
		var fe = _route[_leg].get("fork_enter", null)
		if fe != null:
			_ok("fork %d: entering the wrong branch fires its scare" % int(fe["index"]), bool(fe["scared"]))
			_ok("fork %d: the door back onto the hall is SHUT before the far corner" % int(fe["index"]),
				bool((fe["door"] as Node).get("_closed")))
		var fc = _route[_leg].get("fork_corner", null)
		if fc != null:
			_ok("fork %d: reaching the far corner opens the door onto the hall" % int(fc["index"]),
				bool(fc["opened"]) and not bool((fc["door"] as Node).get("_closed")))
		var e = _route[_leg].get("wait_spur", null)
		if e != null and String(e["kind"]) == "bell":
			# C2: ring, keep facing the desk, wait for the steps to arrive — the card outcome.
			var bell: Node3D = _scene.get_node("Spur%dBell" % int(e["index"]))
			_p.call("ai_look_at", bell.global_position)
			(bell as Node).call("interact")
			_ok("spur %d (bell): the bell rings and shuts the door" % int(e["index"]), bool((e["door"] as Node).get("_closed")))
			_mash_spur = e
			_shut_at = _t
			_shut_seen += 1
			_wait_until = _t + 14.0
			return false
		if e != null and String(e["kind"]) == "cupboard":
			# C3: step in, torch off, hold still.
			var cup: Node3D = _scene.get_node("Spur%dCupboard" % int(e["index"]))
			_p.global_position = cup.global_position + Vector3(0, 0.1, 0)
			_p.velocity = Vector3.ZERO
			_p.call("force_flashlight_off")
			_mash_spur = e
			_shut_at = _t
			_shut_seen += 1
			_wait_until = _t + 14.0
			return false
		if e != null:
			var door: Node = e["door"]
			var sprung: bool = bool((e["trap"] as Node).call("is_sprung"))
			_ok("spur %d: walking to its end springs the shut-in" % int(e["index"]), sprung)
			_ok("spur %d: the door is closed across the mouth" % int(e["index"]), bool(door.get("_closed")))
			if sprung:
				_shut_seen += 1
				_mash_spur = e
				_shut_at = _t
				_mash_t = 0.0
				_ok("spur %d: a SpurEscape is live behind the shut door" % int(e["index"]),
					_scene.get_node_or_null("Spur%dEscape" % int(e["index"])) != null)
				_wait_until = _t + float(_scene.get("SPUR_SHUT_TIME")) + 3.0
				return false
			# not sprung: nothing to wait for — move on (and the shut-in count will say so)
		_leg += 1
		return false
	# Stall guard, TIME-BASED (headless frames are uncapped, so a per-frame distance is not a
	# speed): once a second, if the body moved under 0.4 m in that second, that is a wall.
	_stall_t += delta
	if _stall_t >= 1.0:
		_stall_t = 0.0
		if here.distance_to(_last) < 0.4:
			_stall += 1
		else:
			_stall = 0
		_last = here
		print("      t=%.0f leg %d at %v" % [_t, _leg, here.snappedf(0.1)])
	if _stall >= 6:
		var hits: Array = []
		for ci in range(_p.get_slide_collision_count()):
			var c := _p.get_slide_collision(ci)
			if c and c.get_collider():
				hits.append("%s(%s)" % [c.get_collider().name, c.get_collider().get_class()])
		_ok("stalled at leg %d (%s) near %v, touching %s, frozen=%s" % [_leg, _route[_leg]["note"], here.snappedf(0.1), hits, _p.call("is_input_frozen")], false)
		return _finish()
	var dir := to.normalized()
	# ai_move_dir is in the player's own frame; aim the body at the target and walk forward.
	_p.call("ai_look_at", target + Vector3(0, 1.6, 0))
	_p.set("ai_move_dir", Vector2(0, -1))
	return false


func _finish() -> bool:
	print("  %d checks, %d failed" % [_checks, _fails])
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true
