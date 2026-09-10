extends SceneTree

# THE SPRAWL: are all four walls visibly wrong, does exactly one turn right, and is walking into
# a red one free?
#
#   Godot --headless --path game --script res://tests/check_sprawl_walls.gd
#
# ⚠️ WHY. `is_real` was a PURE BOOL. `check_sprawl_crate.gd` proves the crate gate WORKS — the
# whisper leads to the box, the box opens, the runner crosses the hall, the real wall unseals —
# and every one of those steps was invisible: four walls built by one loop with the same size,
# the same texture, the same shader and the same `tear_amount`, so the player could stand in
# front of the answer and learn nothing. That is what the red/yellow tell fixes, and a bool that
# drives nothing is exactly the kind of thing a test suite cannot notice on its own.
#
# ⚠️ AND THE PENALTY WENT WITH IT. Twelve panic plus a teleport across the room was a fair price
# for a 1-in-4 guess. It is not a fair price for the player checking that a wall painted WRONG
# is in fact wrong. This asserts that walking into a red wall costs nothing and moves nobody.

const TINT_PARAM := "wall_tint"

var _fails: Array[String] = []
var _checks := 0
var _stage := 0
var _t := 0.0
var _wall := 0.0
var _level: Node = null
var _z2: Node = null
var _panic_before := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _initialize() -> void:
	seed(7)
	change_scene_to_file("res://scenes/backrooms.tscn")


func _tint_of(w: Node) -> Vector3:
	var mi := w.get_node_or_null("Seam") as MeshInstance3D
	if mi == null:
		for c in w.get_children():
			if c is MeshInstance3D:
				mi = c
				break
	if mi == null:
		return Vector3(-1, -1, -1)
	var mat := mi.material_override as ShaderMaterial
	if mat == null:
		return Vector3(-1, -1, -1)
	var v = mat.get_shader_parameter(TINT_PARAM)
	return v if v is Vector3 else Vector3(-1, -1, -1)


func _walls() -> Dictionary:
	return _z2.get("_walls")


func _is_red(v: Vector3) -> bool:
	# TINT_FAKE is (1.0, 0.26, 0.22): red channel dominant by a wide margin.
	return v.x > 0.8 and v.y < 0.5 and v.z < 0.5


func _is_yellow(v: Vector3) -> bool:
	# TINT_REAL is (1, 1, 1) — the wallpaper's own colour returning, no tint at all.
	return v.x > 0.9 and v.y > 0.9 and v.z > 0.9


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 90.0:
		print("TIMEOUT at stage %d" % _stage)
		quit(1)
		return true
	_t += delta
	if _t < 3.0 or current_scene == null:
		return false
	_t = 0.0

	match _stage:
		0:
			print("== SPRAWL WALLS ==")
			_level = current_scene
			_z2 = _level.get_node_or_null("ZoneSprawl")
			_ok("the Sprawl exists", _z2 != null)
			if _z2 == null:
				quit(1)
				return true
			var walls: Dictionary = _walls()
			# 2026-09-10: four perimeter decoys plus the exit at the end of the crate's recess.
			_ok("five glitch walls (four decoys + the recess exit)", walls.size() == 5, "%d" % walls.size())

			# ⚠️ ENTER THE ZONE THROUGH THE LEVEL'S OWN PATH. The ambient dip lives in
			# `_enter_zone(2)`, not in the zone's `build()`, because all three Backrooms zones
			# share ONE scene and therefore one `Environment` — so a test that loads the scene
			# and pokes zone 2's walls directly is still standing in zone 1's lighting. The first
			# version of the ambient assertion below read 0.200 for exactly that reason, which is
			# the test being wrong rather than the game.
			_level.call("_enter_zone", 2)

			# ---------------------------------------------------- every wall is wrong
			var reds := 0
			var yellows := 0
			for s in walls.keys():
				var v := _tint_of(walls[s])
				if _is_red(v):
					reds += 1
				elif _is_yellow(v):
					yellows += 1
			_ok("ALL FIVE walls are painted wrong before the runner", reds == 5,
				"%d red, %d untinted — a wall that already looks right gives the answer away"
					% [reds, yellows])

			# ---------------------------------------------------- the real one is still sealed
			_ok("the real wall is sealed until the runner goes through it",
				bool(_z2.call("real_wall_is_sealed")),
				"an unsealed real wall makes the crate optional, which is the design this "
				+ "replaced (backlog 04 §16.4)")
			_stage = 1
		1:
			# ---------------------------------------------------- the reveal
			# Drive the zone's own gate rather than setting a tint by hand: the point is that the
			# LEVEL repaints, and `_apply_gate()` recomputes all four from `_real_side` every
			# time (a differential update would leave a yellow wall that is no longer real after
			# a re-roll).
			_z2.set("_dweller_done", true)
			_z2.call("_apply_gate")
			_z2.call("_mark_real_wall")
			var walls2: Dictionary = _walls()
			var real_side: String = String(_z2.get("_real_side"))
			var reds2 := 0
			var yellow_side := ""
			for s in walls2.keys():
				var v := _tint_of(walls2[s])
				if _is_red(v):
					reds2 += 1
				elif _is_yellow(v):
					yellow_side = String(s)
			_ok("after the run, exactly ONE wall turns", reds2 == 4,
				"%d still red" % reds2)
			_ok("...and it is the real one", yellow_side == real_side,
				"yellow on '%s', real is '%s'" % [yellow_side, real_side])
			_ok("...and it is no longer sealed", not bool(_z2.call("real_wall_is_sealed")))
			# 2026-09-10: the one that turns is a RECESS-END wall, beyond the perimeter plane.
			var half: float = float(_z2.get_script().get_script_constant_map().get("HALF", 20.0))
			var yw := walls2.get(yellow_side) as Node3D
			var reach: float = (yw.global_position - (_z2 as Node3D).global_position).length() if yw else 0.0
			_ok("...and it stands at the end of a recess, not on the perimeter", reach > half + 1.0,
				"%.1f m from the hall centre (perimeter walls sit at %.1f)" % [reach, half - 0.05])

			# ⚠️ The mark is MOTION as well as colour — `set_agitated()` raises the shader's own
			# tear. The design notes record that BRIGHTNESS was offered as this zone's mark and
			# declined (the glitch wall is already the brightest surface in its room by 2.3x), so
			# the tint must be a hue change and the tear must still be doing the other half.
			var mi := walls2[real_side].get_node_or_null("Seam") as MeshInstance3D
			if mi == null:
				for c in walls2[real_side].get_children():
					if c is MeshInstance3D:
						mi = c
						break
			var mat := mi.material_override as ShaderMaterial if mi else null
			if mat:
				var tear: float = float(mat.get_shader_parameter("tear_amount"))
				_ok("the real wall is also AGITATED, not just recoloured", tear > 0.2,
					"tear_amount %.2f (calm is 0.12)" % tear)
			_stage = 2
		2:
			# ---------------------------------------------------- a red wall costs nothing
			var pl := get_first_node_in_group("player")
			_ok("found the player", pl != null)
			if pl == null:
				quit(1)
				return true
			# ⚠️ PUT IT SOMEWHERE THAT IS NOT THE ZONE SPAWN. The first version parked the player
			# at `origin + (0, 0.1, -16)`, which IS `spawn_point` (`-HALF + 4.0` = -16) — so the
			# "were you teleported back" assertion compared the spawn against itself and failed
			# on a teleport that was not happening. Mid-hall, well clear of it.
			pl.global_position = Vector3(_z2.get("_origin")) + Vector3(6.0, 0.1, 6.0)
			_panic_before = float(pl.call("get_panic_ratio"))
			# Fire the zone's own `mistake` signal, i.e. the exact path a wrong wall takes.
			_z2.emit_signal("mistake")
			_stage = 3
			_t = 2.5   # one short beat: a teleport or a panic add would land immediately
			return false
		3:
			var pl2 := get_first_node_in_group("player")
			# ⚠️ MEASURE THE DELTA, NOT THE LEVEL. The Sprawl is a floor-wide `DreadZone` where
			# pressure and decay cancel, and the player has been standing in it; an absolute
			# reading picks that up and calls it a penalty. WRONG_WALL_PANIC is 12 of PANIC_MAX
			# 50, i.e. 0.24 of the ratio — two orders of magnitude above the drift being allowed
			# for here.
			var panic_now: float = float(pl2.call("get_panic_ratio"))
			var gained: float = panic_now - _panic_before
			_ok("walking into a red wall costs NO panic", gained < 0.05,
				("panic +%.3f — WRONG_WALL_PANIC would be +0.240, a fair price for a 1-in-4 "
				+ "guess and not for checking a wall that is painted wrong") % gained)
			# ⚠️ The player must still be in the Sprawl. A teleport back to the spawn is the other
			# half of the old penalty and is what made a wrong wall cost distance.
			var here: Vector3 = pl2.global_position
			var spawn: Vector3 = Vector3(_z2.get("spawn_point"))
			_ok("...and does not throw you back across the room",
				here.distance_to(spawn) > 4.0,
				"%.1f m from the zone spawn — if this is ~0 the teleport is still happening"
					% here.distance_to(spawn))

			# ---------------------------------------------------- the zone is darker
			# ⚠️ THIS ASSERTED `we != null` AND NOTHING ELSE. It was labelled "the Sprawl darkens
			# the level" and could not fail on any build where the scene had a WorldEnvironment —
			# i.e. it named the property and then measured the wrong thing entirely. Found by an
			# audit probe. It is the exact vacuous-pass shape `run_tests.sh`'s own header warns
			# about, written by the same hand that wrote the warning into three other files.
			var we := current_scene.get_node_or_null(
				"Environment/WorldEnvironment") as WorldEnvironment
			_ok("the scene has a WorldEnvironment to darken", we != null)
			if we and we.environment:
				var amb: float = we.environment.ambient_light_energy
				var target: float = float(current_scene.get("SPRAWL_AMBIENT"))
				var base: float = float(current_scene.get("BASE_AMBIENT"))
				_ok("the Sprawl really is darker than the rest of the Backrooms",
					amb < base - 0.05,
					"ambient %.3f against the level's own %.3f" % [amb, base])
				_ok("...and it has reached SPRAWL_AMBIENT", absf(amb - target) < 0.02,
					"ambient %.3f vs SPRAWL_AMBIENT %.3f (a %.1f s tween; if this is mid-way "
					% [amb, target, float(current_scene.get("ZONE_AMBIENT_FADE"))]
					+ "the stage timing moved, not the value)")
				_ok("...but NOT as dark as the torch-only levels", amb > 0.04,
					("ambient %.3f — the brief here was 'darker than usual, but not complete "
					+ "darkness', and this zone's puzzle is finding a crate by ear in a 40x40 m "
					+ "hall that has to keep a shape") % amb)
			print("== %d checks, %d failed ==" % [_checks, _fails.size()])
			for f in _fails:
				print("   FAILED: " + f)
			quit(1 if _fails.size() > 0 else 0)
			return true
		_:
			pass
	return false
