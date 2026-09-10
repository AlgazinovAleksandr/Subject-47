extends SceneTree

# The House's cellar gate: it must refuse without the key, open WITH it, and — the half that was
# missing — actually let the player through afterwards, on the real walking path.
#
#   Godot --headless --path game --script res://tests/check_cellar_key.gd
#
# BACKLOG #16: the cellar must not open by itself when the key is found. `level_2.gd` used to wire
# the KeyItem's `picked_up` straight to `_open_cellar_gate()`, so winning the Bathroom map
# minigame flung the door open from the other end of the house. The key was a formality and the
# walk back down — the only thing that made it feel like a key — never happened.
#
# Asserted with a PHYSICS QUERY, not a flag: `_opened` being true says nothing about whether the
# doorway is walkable, and this project has been caught by exactly that before (Issue 13 — a wall
# whose `is_solid()` returned true was a hole in the world for its entire life).
#
# ⚠️⚠️ TWO THINGS THIS FILE USED TO MISS, BOTH FOUND ON 2026-09-07 AFTER A PLAYER REPORTED THE
# DOOR AS POSSIBLY BROKEN. It was not broken. But:
#
#   1. **It never re-ran the doorway query after a successful key-open.** It asserted blocked,
#      blocked, blocked, then `_opened == true` and stopped. The one direction that matters to a
#      player — *can I now get through* — was never asked, by the file whose own header says a ray
#      through the ramp opening is the real question.
#   2. **It called `_gate.interact()` directly**, which is the anti-pattern `player.gd:830` warns
#      about by name: Issue 30 was a level that was unwinnable for every real player while its
#      test passed, precisely because the test called `interact()` instead of going through the
#      raycast. So the "press E" assertions proved the signal wiring and nothing about reach.
#
# Both are closed below: the gate is opened by walking to it and driving `ai_interact()` through
# the shipping ray, and the player then walks down the ramp and back out under gravity.
#
# ⚠️ AND A THIRD, which is why `_gate_geometry_ok()` exists. The planks and padlock were built at
# `HEIGHT * 0.5 + offset` on a mesh already centred on a body at y = 1.5, so two of three planks
# and most of the lock sat ABOVE the leaf, inside the shaft cap. Every guard in the project was
# blind to it: `check_wall_overlap` found 0 findings, `check_prop_mounting` does not classify
# these as wall panels, `check_doorways` only asks whether the opening is gated, and this file's
# own ray flies at y = 1.2 and never looks at a mesh. A prop's decoration being ON the prop is
# assertable, and now it is.

const GATE_POS := Vector3(5.0, 1.5, 3.0)
const AUTOPLAYER := preload("res://tests/autoplay/autoplayer.gd")

# Spawn (0, 0.1, -2) -> EntryHall -> Hallway -> Kitchen doorway -> stand off the gate.
# ⚠️ THROUGH THE DOORWAY, NOT PAST IT. The Hallway<->Kitchen opening is at (1.5, 6) on the x
# plane, 1.4 m wide, so the route must cross x = 1.5 at z = 6.0. The first draft cut the corner
# from (2.4, 6.4) to (4.6, 6.0) and wedged on the jamb at (3.46, 5.78) — AutoPlayer steers, it
# does not path, and that is deliberate (see its header): a harness with pathfinding stops
# measuring whether the level's own doorways are walkable.
const TO_GATE := [
	Vector3(0.0, 0.0, 2.0), Vector3(0.0, 0.0, 5.2), Vector3(0.0, 0.0, 6.0),
	Vector3(2.8, 0.0, 6.0), Vector3(4.9, 0.0, 5.6), Vector3(5.0, 0.0, 4.4),
]
# Down the ramp: the doorway, the flat bridge, then the cellar floor at y = -1.5.
const DOWN = [Vector3(5.0, 0.0, 2.0), Vector3(5.0, -0.7, 0.0), Vector3(5.0, -1.5, -3.5)]
# ⚠️ -1.30, not -1.00. The cellar floor is at y = -1.5 and the ramp descends to it, so a -1.0
# threshold is satisfied HALFWAY DOWN THE RAMP — the first run passed at -1.01, which proves the
# gate opened and proves nothing about arriving. This value is inside the room.
const CELLAR_Y_MAX := -1.30
const TWEEN_WAIT := 1.4        # cellar_gate.gd's slide is 0.9 s; the collider dies at the END

var _t := 0.0
var _stage := 0
var _leg := 0
var _fails := 0
var _checks := 0
var _scene: Node
var _gate: Node3D
var _gs: Node
var _player: CharacterBody3D
var _auto = null
var _deepest := 99.0
var _climbed := false


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


# Can the player actually get through the ramp opening? Cast across the doorway at chest height;
# a hit means the gate is still physically in the way.
func _doorway_blocked() -> bool:
	var space := _player.get_world_3d().direct_space_state
	var from := Vector3(GATE_POS.x, 1.2, GATE_POS.z - 1.2)
	var to := Vector3(GATE_POS.x, 1.2, GATE_POS.z + 1.2)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [_player.get_rid()]
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


# Is every visible part of the gate actually ON the gate? The leaf is the tallest child; nothing
# may stand proud of its vertical span, in either direction.
func _gate_geometry_ok() -> Array:
	var leaf_lo := 99.0
	var leaf_hi := -99.0
	var parts: Array = []
	for c in _gate.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi := c as MeshInstance3D
		var ab: AABB = mi.get_aabb()
		# The child's own transform, then the gate's. Both are axis-aligned here.
		var lo: float = mi.position.y + ab.position.y
		var hi: float = lo + ab.size.y
		var h: float = ab.size.y
		parts.append({"name": String(mi.name), "lo": lo, "hi": hi, "h": h})
		if h > leaf_hi - leaf_lo:
			leaf_lo = lo
			leaf_hi = hi
	var strays: Array = []
	for pt in parts:
		# ⚠️ 5 mm, NOT 2 cm. The planks are deliberately a touch wider than the leaf in X, but
		# nothing is meant to overhang it VERTICALLY at all — and the tolerance is load-bearing:
		# at 2 cm this sweep caught the two displaced planks (1.5 m out) and let the PADLOCK
		# through, because that one happened to clear the leaf's top edge by exactly 0.01 m while
		# sitting 1.1 m above the player's eye line with three quarters of it inside the shaft
		# cap. A guard that catches the obvious two thirds of a defect is how the last third
		# ships.
		if float(pt["lo"]) < leaf_lo - 0.005 or float(pt["hi"]) > leaf_hi + 0.005:
			strays.append("%s at local y %.2f..%.2f (leaf %.2f..%.2f)"
				% [pt["name"], pt["lo"], pt["hi"], leaf_lo, leaf_hi])
	return strays


func _process(delta: float) -> bool:
	_t += delta
	if _t < 0.4 or current_scene == null:
		return false
	if _scene == null:
		_scene = current_scene
		_gs = root.get_node_or_null("/root/GameState")
		_gate = _scene.get_node_or_null("CellarGate") as Node3D
		_player = _scene.get_node_or_null("Player") as CharacterBody3D
		_ok("CellarGate exists", _gate != null)
		_ok("a live player to drive", _player != null)
		if not _gate or not _player:
			return _finish()
		_auto = AUTOPLAYER.new(_player)

	match _stage:
		0:
			print("--- the prop itself ---")
			_ok("gate is interactable (has interact())", _gate.has_method("interact"))
			var strays := _gate_geometry_ok()
			_ok("every plank and the padlock are ON the leaf, not above it",
				strays.is_empty(),
				"; ".join(strays) if not strays.is_empty()
					else "all children inside the leaf's vertical span")
			# ⭐ CONTROL. "nothing overhangs" is trivially true if the sweep collects nothing —
			# it must find the parts before it can clear them.
			var n := 0
			for c in _gate.get_children():
				if c is MeshInstance3D:
					n += 1
			_ok("CONTROL — the sweep actually saw the gate's parts", n >= 5,
				"%d MeshInstance3D children (slab + 3 planks + lock)" % n)

			print("--- at level start ---")
			_ok("ramp doorway is blocked", _doorway_blocked())
			print("--- press E with empty hands ---")
			_gate.call("interact")
			_ok("still blocked", _doorway_blocked(), "<- refuses without the key")
			_ok("level did not mark it opened", _scene.get("_has_cellar_key") == false)

			print("--- the key is found (the map minigame's payoff) ---")
			# The key node only exists after the minigame is won, so call the level's own handler
			# — which is what KeyItem.picked_up is wired to. The assertion that matters is what
			# does NOT happen.
			_scene.call("_on_cellar_key_taken")
			_ok("player is now carrying the key", _scene.get("_has_cellar_key") == true)
			_ok("HUD shows it", _gs != null and _gs.get("carried_item") == "cellar key")
			_ok("ramp is STILL blocked", _doorway_blocked(),
				"<- BACKLOG #16: finding the key used to open the door by itself")
			print("--- walk to the gate and press E through the REAL interact ray ---")
			_stage = 1
			_t = 0.0
		1:
			if _leg >= TO_GATE.size():
				_auto.stop()
				var tgt := _gate.global_position
				_player.call("ai_look_at", Vector3(tgt.x, 1.4, tgt.z))
				var cam := _player.get_node_or_null("Camera3D") as Camera3D
				if cam:
					cam.force_update_transform()
				var seen = _player.call("ai_interact_target")
				_ok("the shipping ray reaches the gate from the walking approach",
					seen != null and _is_gate(seen),
					"ray saw %s from %s" % [str(seen), str(_player.global_position)])
				_player.call("ai_interact")
				_ok("gate reports opened", _gate.get("_opened") == true)
				_ok("carried item cleared", _gs != null and _gs.get("carried_item") == "")
				_stage = 2
				_t = 0.0
				return false
			var w: Vector3 = TO_GATE[_leg]
			w.y = _player.global_position.y
			if _auto.step_toward(w):
				_leg += 1
				_auto.reset_stuck()
			elif _auto.stuck:
				_ok("player reached waypoint %d without wedging" % _leg, false,
					"stuck at %s heading for %s" % [str(_player.global_position), str(w)])
				_leg += 1
				_auto.reset_stuck()
			if _t > 25.0:
				_ok("the walk to the gate completed in time", false)
				return _finish()
		2:
			# ⚠️ WAIT PAST THE TWEEN. `open()` slides for 0.9 s and disables the collider in the
			# tween's FINAL callback, so querying in the same frame reads a door that has not
			# moved — the Tween-in-the-same-frame mistake this project has made three times.
			if _t < TWEEN_WAIT:
				return false
			print("--- %.1f s later: is the doorway actually clear? ---" % TWEEN_WAIT)
			_ok("THE DOORWAY IS CLEAR once the key has been used",
				not _doorway_blocked(),
				"<- nothing asserted this before 2026-09-07")
			_stage = 3
			_leg = 0
			_t = 0.0
		3:
			# ---- and can a real body actually walk down it, under gravity?
			_deepest = minf(_deepest, _player.global_position.y)
			if _leg >= DOWN.size() or _player.global_position.y <= CELLAR_Y_MAX:
				_auto.stop()
				_ok("the player walks THROUGH the opened gate into the cellar",
					_player.global_position.y <= CELLAR_Y_MAX,
					"deepest y %.2f (cellar floor is -1.5)" % _deepest)
				_stage = 4
				_leg = 0
				_t = 0.0
				return false
			var d: Vector3 = DOWN[_leg]
			if _auto.step_toward(d):
				_leg += 1
				_auto.reset_stuck()
			elif _auto.stuck:
				_leg += 1
				_auto.reset_stuck()
			if _t > 25.0:
				_ok("the descent completed in time", false, "stopped at %.2f" % _deepest)
				_stage = 4
				_t = 0.0
		4:
			# ---- and back out, because a one-way cellar is a soft-lock.
			var up := Vector3(GATE_POS.x, 0.0, 6.0)
			up.y = _player.global_position.y
			if _player.global_position.y > -0.3 and _player.global_position.z > 4.0:
				_climbed = true
			if _climbed or _t > 25.0:
				_auto.stop()
				_ok("...and back out again", _climbed,
					"ended at %s" % str(_player.global_position))
				return _finish()
			_auto.step_toward(up)
			if _auto.stuck:
				_auto.reset_stuck()
	return false


func _is_gate(n) -> bool:
	var x := n as Node
	while x != null:
		if x == _gate:
			return true
		x = x.get_parent()
	return false


func _finish() -> bool:
	if _auto != null:
		_auto.release()
	print("--------------------------------------------------")
	print("RESULT: ", "PASS (%d checks)" % _checks if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
